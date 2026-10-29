import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'account_api.dart';
import 'pack_catalog.dart';
import '../data/garden_pack_registry.dart';

typedef GardenData = Map<String, dynamic>;
String canonicalJson(Object? value) {
  Object? sorted(Object? v) {
    if (v is Map) {
      final keys = v.keys.cast<String>().toList()..sort();
      return {for (final k in keys) k: sorted(v[k])};
    }
    if (v is List) return v.map(sorted).toList();
    return v;
  }

  return jsonEncode(sorted(value));
}

GardenData _copy(Map value) =>
    Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);

/// One serialized sync stream per account. The persisted pending mutation is
/// retried unchanged after timeouts/restarts; newer local edits remain separate.
class CloudAccount extends ChangeNotifier {
  CloudAccount({AccountApi? api, SessionStore? sessions})
      : api = api ?? AccountApi(),
        sessions = sessions ?? SecureSessionStore();
  final AccountApi api;
  final SessionStore sessions;
  static const storageKey = 'betterseed_cloud_profiles_v1';
  GardenData _disk = {'profiles': <String, dynamic>{}};
  GardenData? _session;
  GardenData? _current;
  GardenData? _fresh;
  SharedPreferences? _prefs;
  Future<void>? _syncWork;
  Future<void>? _refreshWork;
  Future<void> _writes = Future.value();
  Future<void> _sessionWrites = Future.value();
  Timer? _timer;
  int _epoch = 0;
  int _failures = 0;
  bool _disposed = false;
  bool initialized = false;
  bool switching = false;
  bool needsSignIn = false;
  String status = 'Guest · saved on this device';
  String? error;
  ValueChanged<GardenData>? onGarden;
  ValueChanged<GardenData>? onWallet;
  bool get configured => api.configured;
  GardenData? get user =>
      _session?['user'] is Map ? _copy(_session!['user'] as Map) : null;
  String? get userId => user?['id'] as String?;
  bool get signedIn => userId != null;
  bool get busy => switching || _syncWork != null;
  Map<String, dynamic> get _profiles =>
      _disk['profiles'] as Map<String, dynamic>;
  GardenData get _profile => _profiles[userId] as GardenData;
  GardenData? get conflict => signedIn && _profile['conflict'] is Map
      ? _copy(_profile['conflict'] as Map)
      : null;
  GardenData? get recoveryCopy => signedIn && _profile['recovery'] is Map
      ? _copy(_profile['recovery'] as Map)
      : null;
  GardenData? get wallet => signedIn && _profile['wallet'] is Map
      ? _copy(_profile['wallet'] as Map)
      : null;
  bool get dirty =>
      signedIn &&
      (_profile['pending'] != null ||
          canonicalJson(_profile['local']) != canonicalJson(_profile['base']));
  GardenData? get currentGarden => _current == null ? null : _copy(_current!);
  String? get lastSynced => signedIn ? _profile['syncedAt'] as String? : null;

  Future<void> initialize(GardenData current, GardenData fresh,
      {GardenData? guestWallet}) async {
    if (initialized) {
      _publish();
      return;
    }
    _prefs = await SharedPreferences.getInstance();
    _fresh = _copy(fresh);
    final saved = _prefs!.getString(storageKey);
    if (saved != null) {
      try {
        _disk = _copy(jsonDecode(saved) as Map);
      } catch (_) {
        _disk = {'profiles': <String, dynamic>{}};
      }
    }
    if (_disk['profiles'] is! Map) _disk['profiles'] = <String, dynamic>{};
    _disk['guestWallet'] ??= guestWallet ?? {'balance': 0, 'packs': <String>[]};
    if (configured) {
      try {
        _session = await sessions.read();
      } catch (_) {
        needsSignIn = true;
      }
    }
    final uid = userId;
    if (uid != null) {
      // The vault is authoritative for identity. A missing profile must not
      // discard a valid session or adopt another account's local mirror.
      if (_profiles[uid] is! Map || (_profiles[uid] as Map)['local'] is! Map) {
        _profiles[uid] = <String, dynamic>{
          'revision': 0,
          'local': _copy(_fresh!),
          'base': _copy(_fresh!)
        };
      }
      _disk['owner'] = uid;
      _current = _copy(_profile['local'] as Map);
      status = 'Ready to sync';
    } else {
      _session = null;
      // A missing secure token must never turn another account's mirror into guest data.
      _current = _disk['guest'] is Map
          ? _copy(_disk['guest'] as Map)
          : _disk['owner'] != null
              ? _copy(fresh)
              : _copy(current);
      _disk['guest'] = _current;
      _disk['owner'] = null;
    }
    initialized = true;
    await _persist();
    _publish();
    if (signedIn) schedule();
  }

  void _publish() {
    if (_current != null) onGarden?.call(_copy(_current!));
    if (wallet != null) onWallet?.call(wallet!);
    if (!signedIn && _disk['guestWallet'] is Map)
      onWallet?.call(_copy(_disk['guestWallet'] as Map));
    notifyListeners();
  }

  Future<void> _storeSession(GardenData? data) {
    final snapshot = data == null ? null : _copy(data);
    _sessionWrites = _sessionWrites
        .catchError((Object _) {})
        .then((_) => sessions.write(snapshot));
    return _sessionWrites;
  }

  Future<void> _persist() {
    final value = jsonEncode(_disk);
    _writes = _writes.catchError((Object _) {}).then((_) async {
      if (!await _prefs!.setString(storageKey, value))
        throw const AccountException('local_storage_failed');
    });
    return _writes;
  }

  Future<void> capture(GardenData garden) async {
    if (!initialized || switching) return;
    _current = _copy(garden);
    if (signedIn) {
      _profile['local'] = _current;
    } else {
      _disk['guest'] = _current;
    }
    await _persist();
    if (signedIn && dirty) schedule();
  }

  void schedule({Duration delay = const Duration(seconds: 2)}) {
    if (_disposed ||
        !signedIn ||
        !configured ||
        needsSignIn ||
        conflict != null) return;
    _timer?.cancel();
    _timer = Timer(delay, () => unawaited(sync()));
  }

  Future<void> _refresh() async {
    if (_refreshWork != null) return _refreshWork;
    final epoch = _epoch;
    final refresh = _session?['refreshToken'];
    if (refresh == null) throw const AccountException('session_expired');
    final work = () async {
      try {
        // Persist the retry key before rotation, including across process death.
        _session!['refreshRequestId'] ??= const Uuid().v4();
        await _storeSession(_copy(_session!));
        final result = await api.send('POST', '/v1/auth/refresh', body: {
          'refreshToken': refresh,
          'requestId': _session!['refreshRequestId'],
        });
        if (epoch != _epoch) throw const AccountException('session_expired');
        _session = result;
        await _storeSession(result);
      } on AccountException catch (e) {
        if (e.code == 'session_expired' || e.code == 'unauthorized')
          needsSignIn = true;
        rethrow;
      }
    }();
    _refreshWork = work;
    try {
      await work;
    } finally {
      _refreshWork = null;
    }
  }

  Future<GardenData> authorized(String method, String path,
      {GardenData? body}) async {
    if (!signedIn || needsSignIn)
      throw const AccountException('session_expired');
    final epoch = _epoch;
    final sentAccess = _session!['accessToken'] as String;
    try {
      final result =
          await api.send(method, path, body: body, accessToken: sentAccess);
      if (epoch != _epoch) throw const AccountException('session_expired');
      return result;
    } on AccountException catch (e) {
      if (e.code != 'unauthorized' || epoch != _epoch) rethrow;
      // Another request may already have rotated the token while this old
      // response was in flight. Reuse that token instead of rotating twice.
      if (_session!['accessToken'] == sentAccess) await _refresh();
      final result = await api.send(method, path,
          body: body, accessToken: _session!['accessToken'] as String);
      if (epoch != _epoch) throw const AccountException('session_expired');
      return result;
    }
  }

  Future<void> acceptSession(GardenData session) async {
    switching = true;
    _timer?.cancel();
    notifyListeners();
    try {
      await _syncWork;
      try {
        await _refreshWork;
      } on AccountException {
        /* The new sign-in can replace an expired session. */
      }
      final candidate = _copy(_current ?? _fresh!);
      final priorId = userId;
      _epoch++;
      await _storeSession(session);
      _session = session;
      needsSignIn = false;
      final uid = userId!;
      if (_profiles[uid] == null) {
        // Guest adoption requires a choice if the cloud already has another garden.
        // Account A's garden is NEVER used as account B's initial upload.
        _profiles[uid] = <String, dynamic>{
          'revision': 0,
          'local': priorId == null ? candidate : _copy(_fresh!),
          'base': null
        };
      }
      _disk['owner'] = uid;
      _current = _copy(_profile['local'] as Map);
      await _persist();
      _publish();
    } finally {
      switching = false;
      notifyListeners();
    }
    await sync();
  }

  Future<void> refreshUser() async {
    final result = await authorized('GET', '/v1/account');
    _session!['user'] = result['user'];
    await _storeSession(_session);
    notifyListeners();
  }

  Future<void> refreshWallet() async {
    final result = await authorized('GET', '/v1/wallet');
    await acceptWallet(result);
  }

  Future<void> acceptWallet(GardenData result) async {
    if (!signedIn) return;
    // Ignore late responses from before a newer payment/unlock/refund.
    if ((result['revision'] as num? ?? 0) < (wallet?['revision'] as num? ?? 0))
      return;
    _profile['wallet'] = _copy(result);
    await _persist();
    onWallet?.call(result);
    notifyListeners();
  }

  Future<GardenData> verifyPurchase(
      String productId, String purchaseToken) async {
    final result = await authorized('POST', '/v1/billing/verify',
        body: {'productId': productId, 'purchaseToken': purchaseToken});
    await acceptWallet({...result, 'billingAvailable': true});
    return result;
  }

  Future<void> unlock(String packId, {GardenOffer? offer}) async {
    if (offer == null || offer.id != packId || !offer.supported)
      throw const AccountException('app_update_required');
    final result = await authorized('POST', '/v1/shop/unlock', body: {
      'packId': packId,
      'expectedPrice': offer.price,
      'catalogRevision': offer.revision,
      'appBuild': GardenPackRegistry.appBuild
    });
    await acceptWallet(
        {...result, 'billingAvailable': wallet?['billingAvailable'] == true});
  }

  Future<void> sync() async {
    if (_syncWork != null) return _syncWork;
    if (!signedIn || switching || !configured || needsSignIn) return;
    _timer?.cancel();
    final work = _sync();
    _syncWork = work;
    notifyListeners();
    try {
      await work;
    } finally {
      _syncWork = null;
      notifyListeners();
    }
  }

  Future<void> _sync() async {
    status = 'Syncing…';
    error = null;
    notifyListeners();
    try {
      await refreshUser();
      await refreshWallet();
      if (conflict != null) {
        status = 'Choose a garden version';
        return;
      }
      // Retry an interrupted write BEFORE pulling a potentially newer version.
      if (_profile['pending'] == null) {
        final remote = await authorized('GET', '/v1/garden');
        if (remote['revision'] != _profile['revision']) {
          if (dirty) {
            _profile['conflict'] = remote;
            await _persist();
            status = 'Choose a garden version';
            return;
          }
          _profile['revision'] = remote['revision'];
          _profile['base'] = remote['snapshot'];
          if (remote['snapshot'] is Map) {
            _profile['local'] = remote['snapshot'];
            _current = _copy(remote['snapshot'] as Map);
            await _persist();
            _publish();
          }
        }
      }
      if (dirty) {
        _profile['pending'] ??= <String, dynamic>{
          'baseRevision': _profile['revision'],
          'mutationId': const Uuid().v4(),
          'snapshot': _copy(_profile['local'] as Map),
        };
        await _persist(); // Crash-safe outbox before issuing the request.
        final pending = _copy(_profile['pending'] as Map);
        final result = await authorized('PUT', '/v1/garden', body: pending);
        _profile['revision'] = result['revision'];
        _profile['base'] = pending['snapshot'];
        _profile.remove('pending');
      }
      _profile['syncedAt'] = DateTime.now().toUtc().toIso8601String();
      await _persist();
      _failures = 0;
      status = dirty ? 'Changes waiting to sync' : 'Garden synced';
      schedule(
          delay:
              dirty ? const Duration(seconds: 2) : const Duration(seconds: 60));
    } on AccountException catch (e) {
      if (e.code == 'sync_conflict' && e.details != null) {
        _profile['conflict'] = e.details;
        await _persist();
        status = 'Choose a garden version';
      } else {
        error = e.toString();
        status = needsSignIn
            ? 'Sign in to reconnect'
            : 'Saved on device · sync pending';
        _failures = (_failures + 1).clamp(1, 6);
        schedule(delay: Duration(seconds: 5 * (1 << _failures)));
      }
    } catch (_) {
      error =
          'Unable to save sync state. Your current garden is still on this device.';
      status = 'Sync paused';
    } finally {
      notifyListeners();
    }
  }

  Future<void> resolveConflict({required bool useCloud}) async {
    if (conflict == null || busy) return;
    final latest = await authorized('GET', '/v1/garden');
    _profile['recovery'] = {
      'savedAt': DateTime.now().toUtc().toIso8601String(),
      'device': _profile['local'],
      'cloud': latest['snapshot']
    };
    _profile['revision'] = latest['revision'];
    _profile['base'] = latest['snapshot'];
    _profile.remove('pending');
    _profile.remove('conflict');
    if (useCloud && latest['snapshot'] is Map) {
      _profile['local'] = _copy(latest['snapshot'] as Map);
      _current = _copy(_profile['local'] as Map);
    }
    await _persist();
    _publish();
    await sync();
  }

  Future<void> signOut({bool deleted = false}) async {
    switching = true;
    _timer?.cancel();
    notifyListeners();
    try {
      await _syncWork;
      try {
        await _refreshWork;
      } on AccountException {/* Logout still clears credentials. */}
      if (!deleted && signedIn && !needsSignIn) {
        try {
          await authorized('POST', '/v1/auth/logout');
        } on AccountException {
          /* Offline logout still clears this device's credentials. */
        }
      }
      final uid = userId;
      final previousSession = _session;
      _epoch++;
      _session = null;
      try {
        await _storeSession(null);
      } catch (_) {
        // Do not expose the account garden as a guest if the vault could not
        // clear its credentials. The user can retry signing out.
        _session = previousSession;
        rethrow;
      }
      needsSignIn = false;
      if (deleted && uid != null) {
        _profiles.remove(uid);
        await _prefs!.remove('betterseed_pre_restore_checkpoint_v1_$uid');
      }
      _disk['owner'] = null;
      _current =
          _disk['guest'] is Map ? _copy(_disk['guest'] as Map) : _copy(_fresh!);
      status = 'Guest · saved on this device';
      error = null;
      await _persist();
      // A guest never inherits an account wallet or entitlements.
      onWallet?.call(_copy(_disk['guestWallet'] as Map));
      _publish();
    } finally {
      switching = false;
      notifyListeners();
    }
  }

  void pause() {
    _timer?.cancel();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }
}
