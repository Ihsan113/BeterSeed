import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/garden_pack_registry.dart';
import 'account_api.dart';

class GardenOffer {
  const GardenOffer(
      {required this.id,
      required this.name,
      required this.description,
      required this.accessType,
      required this.price,
      required this.status,
      required this.minimumBuild,
      required this.revision,
      required this.order});
  final String id, name, description, accessType, status;
  final int price, minimumBuild, revision, order;
  bool get supported =>
      GardenPackRegistry.find(id) != null &&
      minimumBuild <= GardenPackRegistry.appBuild;
  factory GardenOffer.fromJson(Map<String, dynamic> j) {
    final id = j['packId'] as String,
        price = j['priceCoins'] as int,
        rev = j['revision'] as int;
    if ((j['name'] as String).trim().isEmpty ||
        (j['name'] as String).length > 120 ||
        (j['description'] as String).length > 2000 ||
        (j['minimumAppBuild'] as int) < 1 ||
        (j['accessType'] == 'free' ? price != 0 : price == 0))
      throw const FormatException('Invalid offer');
    if (!RegExp(r'^[a-z][a-z0-9_]{0,39}$').hasMatch(id) ||
        price < 0 ||
        price > 1000000 ||
        rev < 1 ||
        !['free', 'premium'].contains(j['accessType']) ||
        !['draft', 'active', 'hidden', 'retired'].contains(j['status']))
      throw const FormatException('Invalid catalog');
    return GardenOffer(
        id: id,
        name: j['name'] as String,
        description: j['description'] as String,
        accessType: j['accessType'] as String,
        price: price,
        status: j['status'] as String,
        minimumBuild: j['minimumAppBuild'] as int,
        revision: rev,
        order: j['displayOrder'] as int);
  }
}

class PackCatalog extends ChangeNotifier {
  PackCatalog(this.api, {AssetBundle? bundle}) : bundle = bundle ?? rootBundle;
  final AssetBundle bundle;
  Set<String> _readyAssets = {};
  bool assetReady(String id) => _readyAssets.contains(id);
  final AccountApi api;
  List<GardenOffer> offers = [];
  bool online = false, loading = false, _disposed = false;
  String get _key => 'betterseed_pack_catalog_v1_${api.baseUrl}';
  Future<void> load() async {
    if (loading || _disposed) return;
    loading = true;
    notifyListeners();
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(bundle);
      final bundled = manifest.listAssets().toSet();
      // Non-default art is optional on-demand content. Thumbnail + immutable
      // manifest are bundled; ownership and download are separate states.
      Set<dynamic> remote = {};
      try {
        final downloadable = jsonDecode(
          await bundle.loadString('assets/pack_downloads.json')) as Map;
        remote = (downloadable['packs'] as Map).keys.toSet();
      } catch (_) { /* Custom/missing asset bundles must fail closed. */ }
      _readyAssets = {
        for (final pack in GardenPackRegistry.packs)
          if (pack.id == 'default'
              ? pack.assets.every(bundled.contains)
              : remote.contains(pack.id) &&
                  pack.thumbnail != null && bundled.contains(pack.thumbnail))
            pack.id
      };
      final prefs = await SharedPreferences.getInstance();
      if (offers.isEmpty) {
        try {
          final saved = prefs.getString(_key);
          if (saved != null) offers = _decode(jsonDecode(saved));
        } catch (_) {/* Ignore damaged cache. */}
      }
      final data = await api.send('GET', '/v1/shop/catalog');
      offers = _decode(data);
      online = true;
      try {
        await prefs.setString(_key, jsonEncode(data));
      } catch (_) {/* A disk failure must not replace a verified response. */}
    } catch (_) {
      online = false;
    } finally {
      loading = false;
      if (!_disposed) notifyListeners();
    }
  }

  List<GardenOffer> _decode(dynamic raw) {
    if (raw is! Map ||
        raw['version'] != 1 ||
        raw['packs'] is! List ||
        (raw['packs'] as List).length > 2000)
      throw const FormatException('Invalid catalog');
    final result = (raw['packs'] as List)
        .map((e) => GardenOffer.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    if (result.map((o) => o.id).toSet().length != result.length)
      throw const FormatException('Duplicate pack');
    result.sort((a, b) => a.order.compareTo(b.order));
    return result;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
