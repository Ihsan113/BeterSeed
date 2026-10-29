import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:betterseed/account/account_api.dart';
import 'package:betterseed/account/cloud_account.dart';
import 'package:betterseed/account/pack_catalog.dart';

class MemorySession implements SessionStore {
  Map<String, dynamic>? value;
  bool failClear = false;
  @override
  Future<Map<String, dynamic>?> read() async => value;
  @override
  Future<void> write(Map<String, dynamic>? session) async {
    if (session == null && failClear)
      throw const AccountException('local_storage_failed');
    value = session;
  }
}

Map<String, dynamic> session(String id) => {
      'accessToken': 'access-$id',
      'refreshToken': 'secret-refresh-$id',
      'user': {
        'id': id,
        'email': '$id@example.com',
        'provider': 'email',
        'twoFactorEnabled': false,
        'billingAccountId': 'billing-$id'
      }
    };
Map<String, dynamic> garden(int xp) => {
      'version': 1,
      'habits': <dynamic>[],
      'progress': {
        'version': 3,
        'earned': 5,
        'spent': 2,
        'xp': xp,
        'credited': <String, dynamic>{}
      },
      'day': '2026-10-27',
      'cosmetics': {
        'treeSkinId': 'default',
        'backgroundId': 'default',
        'butterflyId': 'default',
        'wateringCanId': 'default',
        'fireflyId': 'default'
      },
      'treePlacements': {
        'default': {'dx': .12, 'dy': -.04, 'scale': 1.2}
      },
      'preferences': {
        'music': true,
        'effects': false,
        'motion': true,
        'motionOverride': false
      }
    };

class FakeCloudServer {
  final Map<String, Map<String, dynamic>> gardens = {};
  final Map<String, Map<String, dynamic>> mutations = {};
  final List<Map<String, dynamic>> writes = [];
  Map<String,dynamic>? unlockBody;
  bool rejectQuote = false;
  bool loseNextReply = false;
  Completer<void>? holdWrite;
  Completer<void>? writeStarted;
  int refreshes = 0;
  bool expireAccess = false;
  bool loseNextRefreshReply = false;
  final refreshRequestIds = <String>[];
  Completer<void>? delayedUnauthorized;
  Future<http.Response> handle(http.Request r) async {
    final id = (r.headers['authorization'] ?? 'access-a')
        .replaceFirst('Bearer ', '')
        .replaceFirst('access-', '')
        .replaceFirst('renewed-', '');
    final path = r.url.path;
    http.Response response(Object body, [int status = 200]) =>
        http.Response(jsonEncode(body), status,
            headers: {'content-type': 'application/json'});
    if (path == '/v1/auth/refresh') {
      refreshes++;
      final requestId = jsonDecode(r.body)['requestId'] as String;
      refreshRequestIds.add(requestId);
      if (loseNextRefreshReply) {
        loseNextRefreshReply = false;
        throw const AccountException('offline');
      }
      final user = (jsonDecode(r.body)['refreshToken'] as String)
          .replaceFirst('secret-refresh-', '');
      return response({...session(user), 'accessToken': 'renewed-$user'});
    }
    if (expireAccess &&
        (r.headers['authorization'] ?? '').contains('access-')) {
      if (path == '/v1/account') await delayedUnauthorized?.future;
      return response({'error': 'unauthorized'}, 401);
    }
    if (path == '/v1/shop/unlock') {
      unlockBody=jsonDecode(r.body) as Map<String,dynamic>;
      return rejectQuote ? response({'error':'catalog_changed'},409) : response({'balance':207,'revision':4,'packs':['sakura','moonlight']});
    }
    if (path == '/v1/wallet')
      return response({
        'balance': 300,
        'packs': id == 'b' ? <String>[] : ['sakura'],
        'billingAvailable': true
      });
    if (path == '/v1/auth/logout') return response({'ok': true});
    if (path == '/v1/account') return response({'user': session(id)['user']});
    if (path == '/v1/garden') {
      if (r.method == 'GET')
        return response(gardens[id] ?? {'revision': 0, 'snapshot': null});
      final b = Map<String, dynamic>.from(jsonDecode(r.body) as Map);
      writes.add(b);
      writeStarted?.complete();
      writeStarted = null;
      await holdWrite?.future;
      if (mutations['$id:${b['mutationId']}'] != null)
        return response(mutations['$id:${b['mutationId']}']!);
      final revision = gardens[id]?['revision'] ?? 0;
      if (b['baseRevision'] != revision)
        return response(
            {'error': 'sync_conflict', 'details': gardens[id]}, 409);
      final next = {'revision': revision + 1};
      gardens[id] = {...next, 'snapshot': b['snapshot']};
      mutations['$id:${b['mutationId']}'] = next;
      if (loseNextReply) {
        loseNextReply = false;
        throw const AccountException('offline');
      }
      return response(next);
    }
    return response({'ok': true});
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MemorySession vault;
  late FakeCloudServer server;
  late CloudAccount account;
  CloudAccount create() => CloudAccount(
      api: AccountApi(
          baseUrl: 'https://api.example.com',
          client: MockClient(server.handle)),
      sessions: vault);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    vault = MemorySession();
    server = FakeCloudServer();
    account = create();
  });
  tearDown(() {
    account.dispose();
  });

  test('unlock sends exact reviewed quote and never grants on a price conflict', () async {
    await account.initialize(garden(5),garden(0));
    await account.acceptSession(session('a'));
    const offer=GardenOffer(id:'moonlight',name:'Moonlight',description:'',accessType:'premium',price:93,status:'active',minimumBuild:57,revision:4,order:1);
    server.rejectQuote=true;
    await expectLater(account.unlock('moonlight',offer:offer),throwsA(isA<AccountException>().having((e)=>e.code,'code','catalog_changed')));
    expect(server.unlockBody,{'packId':'moonlight','expectedPrice':93,'catalogRevision':4,'appBuild':57});
    expect(account.wallet!['packs'],['sakura']);expect(account.wallet!['balance'],300);
    server.rejectQuote=false;
    await account.unlock('moonlight',offer:offer);
    expect(account.wallet!['packs'],['sakura','moonlight']);expect(account.wallet!['balance'],207);
  });

  test('reopening offline restores identity and garden without another login',
      () async {
    await account.initialize(garden(12), garden(0));
    await account.acceptSession(session('a'));
    await account.capture(garden(42));
    account.dispose();
    account = CloudAccount(
        api: AccountApi(
            baseUrl: 'https://api.example.com',
            client: MockClient(
                (_) async => throw const AccountException('offline'))),
        sessions: vault);
    await account.initialize(garden(0), garden(0));
    expect(account.signedIn, true);
    expect(account.userId, 'a');
    expect(account.currentGarden!['progress']['xp'], 42);
    await account.sync();
    expect(account.needsSignIn, false);
    expect(vault.value!['refreshToken'], 'secret-refresh-a');
  });

  test(
      'a valid vault session survives missing profile and never adopts another mirror',
      () async {
    vault.value = session('a');
    server.gardens['a'] = {'revision': 3, 'snapshot': garden(75)};
    await account.initialize(garden(999), garden(0));
    expect(account.signedIn, true);
    expect(account.currentGarden!['progress']['xp'], 0);
    await account.sync();
    expect(account.currentGarden!['progress']['xp'], 75);
    expect(server.writes, isEmpty);
  });

  test('refresh retry key persists through network loss and process restart',
      () async {
    await account.initialize(garden(12), garden(0));
    await account.acceptSession(session('a'));
    server.expireAccess = true;
    server.loseNextRefreshReply = true;
    await expectLater(account.authorized('GET', '/v1/wallet'),
        throwsA(isA<AccountException>()));
    expect(account.needsSignIn, false);
    final savedKey = vault.value!['refreshRequestId'];
    expect(savedKey, isNotEmpty);
    account.dispose();
    account = create();
    await account.initialize(garden(12), garden(0));
    await account.authorized('GET', '/v1/wallet');
    expect(server.refreshRequestIds, [savedKey, savedKey]);
    expect(vault.value!.containsKey('refreshRequestId'), false);
    expect(account.needsSignIn, false);
  });

  test(
      'failed credential deletion keeps account identity until logout can complete',
      () async {
    await account.initialize(garden(5), garden(0));
    await account.acceptSession(session('a'));
    await account.capture(garden(77));
    vault.failClear = true;
    await expectLater(account.signOut(), throwsA(isA<AccountException>()));
    expect(account.signedIn, true);
    expect(account.currentGarden!['progress']['xp'], 77);
    vault.failClear = false;
    await account.signOut();
    expect(account.signedIn, false);
    expect(account.currentGarden!['progress']['xp'], 5);
  });

  test(
      'guest is offline; adopts guest garden without putting credentials in preferences',
      () async {
    await account.initialize(garden(20), garden(0));
    expect(server.writes, isEmpty);
    await account.acceptSession(session('a'));
    expect(server.gardens['a']!['snapshot']['progress']['xp'], 20);
    expect(account.dirty, false);
    expect(account.wallet!['balance'], 300);
    final stored = (await SharedPreferences.getInstance())
        .getString(CloudAccount.storageKey)!;
    expect(stored, isNot(contains('secret-refresh')));
    expect(stored, isNot(contains('access-a')));
    expect(server.writes.single['snapshot'], isNot(contains('balance')));
  });
  test('lost upload reply retries the same mutation even after restart',
      () async {
    await account.initialize(garden(10), garden(0));
    server.loseNextReply = true;
    await account.acceptSession(session('a'));
    expect(account.dirty, true);
    final mutationId = server.writes.single['mutationId'];
    account.dispose();
    account = create();
    await account.initialize(garden(10), garden(0));
    await account.sync();
    expect(server.writes.last['mutationId'], mutationId);
    expect(server.gardens['a']!['revision'], 1);
    expect(account.dirty, false);
  });
  test('edits during an in-flight upload survive its response and upload next',
      () async {
    await account.initialize(garden(10), garden(0));
    await account.acceptSession(session('a'));
    await account.capture(garden(20));
    server.holdWrite = Completer<void>();
    server.writeStarted = Completer<void>();
    final started = server.writeStarted!.future;
    final sync = account.sync();
    await started;
    await account.capture(garden(30));
    server.holdWrite!.complete();
    await sync;
    expect(account.currentGarden!['progress']['xp'], 30);
    expect(server.gardens['a']!['snapshot']['progress']['xp'], 20);
    expect(account.dirty, true);
    server.holdWrite = null;
    await account.sync();
    expect(server.gardens['a']!['snapshot']['progress']['xp'], 30);
  });
  test(
      'two devices produce a conflict and choosing cloud keeps a recovery copy',
      () async {
    await account.initialize(garden(10), garden(0));
    await account.acceptSession(session('a'));
    await account.capture(garden(20));
    server.gardens['a'] = {'revision': 2, 'snapshot': garden(40)};
    await account.sync();
    expect(account.conflict!['revision'], 2);
    expect(account.currentGarden!['progress']['xp'], 20);
    await account.resolveConflict(useCloud: true);
    expect(account.currentGarden!['progress']['xp'], 40);
    expect(account.recoveryCopy!['device']['progress']['xp'], 20);
    expect(account.recoveryCopy!['cloud']['progress']['xp'], 40);
    expect(account.conflict, isNull);
  });
  test(
      'switching accounts cannot upload account A as account B; signout restores guest',
      () async {
    await account.initialize(garden(5), garden(0));
    await account.acceptSession(session('a'));
    await account.capture(garden(55));
    await account.sync();
    await account.acceptSession(session('b'));
    expect(server.gardens['b']!['snapshot']['progress']['xp'], 0);
    expect(account.wallet!['packs'], isEmpty);
    await account.signOut();
    expect(account.currentGarden!['progress']['xp'], 5);
    await account.acceptSession(session('a'));
    expect(account.currentGarden!['progress']['xp'], 55);
  });
  test(
      'missing secure credentials restore guest instead of leaking the last account',
      () async {
    await account.initialize(garden(5), garden(0));
    await account.acceptSession(session('a'));
    await account.capture(garden(99));
    await account.sync();
    account.dispose();
    vault.value = null;
    account = create();
    await account.initialize(garden(99), garden(0));
    expect(account.signedIn, false);
    expect(account.currentGarden!['progress']['xp'], 5);
  });
  test('parallel unauthorized requests share one refresh rotation', () async {
    await account.initialize(garden(0), garden(0));
    await account.acceptSession(session('a'));
    server.expireAccess = true;
    await Future.wait([
      account.authorized('GET', '/v1/account'),
      account.authorized('GET', '/v1/wallet')
    ]);
    expect(server.refreshes, 1);
  });
  test('late unauthorized response reuses the already refreshed session',
      () async {
    await account.initialize(garden(0), garden(0));
    await account.acceptSession(session('a'));
    server.expireAccess = true;
    server.delayedUnauthorized = Completer<void>();
    final delayed = account.authorized('GET', '/v1/account');
    await account.authorized('GET', '/v1/wallet');
    server.delayedUnauthorized!.complete();
    await delayed;
    expect(server.refreshes, 1);
    expect(account.needsSignIn, false);
  });
  test('deletion removes account recovery and checkpoint, retains guest',
      () async {
    await account.initialize(garden(5), garden(0));
    await account.acceptSession(session('a'));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('betterseed_pre_restore_checkpoint_v1_a', 'private');
    await account.signOut(deleted: true);
    expect(vault.value, isNull);
    expect(prefs.getString('betterseed_pre_restore_checkpoint_v1_a'), isNull);
    expect(jsonDecode(prefs.getString(CloudAccount.storageKey)!)['profiles'],
        isEmpty);
    expect(account.currentGarden!['progress']['xp'], 5);
  });
  test(
      'late wallet responses cannot overwrite newer verified purchase balances',
      () async {
    await account.initialize(garden(0), garden(0));
    await account.acceptSession(session('a'));
    await account.acceptWallet({
      'balance': 600,
      'revision': 4,
      'packs': ['sakura']
    });
    await account.acceptWallet({'balance': 300, 'revision': 3, 'packs': []});
    expect(account.wallet!['balance'], 600);
    expect(account.wallet!['packs'], ['sakura']);
  });
  test('API rejects cleartext and authenticated redirects', () async {
    final cleartext = AccountApi(baseUrl: 'http://api.example.com');
    expect(cleartext.configured, false);
    expect(() => cleartext.send('GET', '/v1/account'),
        throwsA(isA<AccountException>()));
    final redirect = AccountApi(
        baseUrl: 'https://api.example.com',
        client: MockClient((r) async {
          expect(r.followRedirects, false);
          return http.Response('{"error":"redirect_blocked"}', 302);
        }));
    expect(() => redirect.send('GET', '/v1/account', accessToken: 'secret'),
        throwsA(isA<AccountException>()));
  });
}
