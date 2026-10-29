import 'dart:convert';
import 'dart:io';
import 'package:betterseed/account/account_api.dart';
import 'package:betterseed/account/pack_catalog.dart';
import 'package:betterseed/backup/backup_snapshot.dart';
import 'package:betterseed/data/garden_pack_registry.dart';
import 'package:betterseed/data/garden_appearance.dart';
import 'package:betterseed/logic/water_progress.dart';
import 'package:betterseed/widgets/shop_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> entry(String id,
        {String status = 'active', int price = 93, int build = 57}) =>
    {
      'packId': id,
      'name': 'Dynamic $id',
      'description': 'A garden from the catalog',
      'accessType': price == 0 ? 'free' : 'premium',
      'priceCoins': price,
      'status': status,
      'minimumAppBuild': build,
      'revision': 4,
      'displayOrder': 10
    };

class MissingAssets extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      const StandardMessageCodec().encodeMessage(<String, dynamic>{})!;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
      'all registered packs have complete bundled assets and six stages; cosmetic fields are isolated',
      () async {
    expect(File('pubspec.yaml').readAsStringSync(),
        contains('+${GardenPackRegistry.appBuild}'));
    for (final field in ShopLoadout.defaultPack.toJson().keys) {
      expect(
          GardenPackRegistry.packs
              .map((p) => p.loadout.toJson()[field])
              .toSet()
              .length,
          GardenPackRegistry.packs.length,
          reason: 'Each asset must have one owner per field: $field');
    }
    final manifest = (await AssetManifest.loadFromAssetBundle(rootBundle))
        .listAssets()
        .toSet();
    expect(GardenPackRegistry.packs.map((p) => p.id).toSet().length,
        GardenPackRegistry.packs.length);
    for (final pack in GardenPackRegistry.packs) {
      expect(pack.trees.length, 6);
      if (pack.id == 'default') {
        for (final path in pack.assets) {
          expect(manifest.contains(path), true, reason: path);
        }
      } else {
        expect(manifest.contains(pack.thumbnail), true);
        for (final path in pack.assets.where((p) => p != pack.thumbnail)) {
          expect(manifest.contains(path), false, reason: 'Remote pack leaked into APK: $path');
        }
      }
      expect(
          ShopLoadout.fromMap(pack.loadout.toJson(), ownedPacks: {pack.id})
              .matches(pack.loadout),
          true);
      expect(GardenAppearance(pack.loadout).treeImages, pack.trees);
    }
    expect(
        ShopLoadout.fromMap({'treeSkinId': 'cosmic_butterfly'},
            ownedPacks: {'moonlight'}).treeSkinId,
        'default');
  });
  test(
      'legacy backup flags never grant ownership, but verified old packs restore and future IDs survive decoding',
      () {
    final backup = BackupSnapshot(
        habits: const [],
        progress: WaterProgress(),
        day: '2026-10-28',
        packId: 'sakura',
        ownedMoonlight: false,
        ownedSakura: true,
        cosmetics: ShopLoadout.sakuraPack.toJson(),
        savedAtUtc: DateTime.utc(2026));
    final restored = BackupSnapshot.decode(backup.encode());
    expect(restored.loadoutFor({}).packId, 'default');
    expect(restored.loadoutFor({'sakura'}).packId, 'sakura');
    final data = backup.toJson();
    (data['data'] as Map)['packId'] = 'crystal_forest';
    expect(BackupSnapshot.decode(jsonEncode(data)).packId, 'crystal_forest');
  });
  test(
      'cache survives an offline restart; malformed API and a different server cannot replace trusted metadata',
      () async {
    var offline = false, malformed = false;
    final api = AccountApi(
        baseUrl: 'https://catalog.test',
        client: MockClient((_) async {
          if (offline) throw const AccountException('offline');
          return http.Response(
              jsonEncode({
                'version': 1,
                'packs': [
                  entry('moonlight', price: 321),
                  if (malformed) entry('moonlight')
                ]
              }),
              200);
        }));
    final first = PackCatalog(api);
    await first.load();
    expect(first.online, true);
    expect(first.offers.single.price, 321);
    malformed = true;
    await first.load();
    expect(first.online, false);
    expect(first.offers.single.price, 321);
    offline = true;
    final reopened = PackCatalog(api);
    await reopened.load();
    expect(reopened.online, false);
    expect(reopened.offers.single.price, 321);
    expect(reopened.assetReady('moonlight'), true);
    final other = PackCatalog(AccountApi(
        baseUrl: 'https://other.test',
        client:
            MockClient((_) async => throw const AccountException('offline'))));
    await other.load();
    expect(other.offers, isEmpty);
    first.dispose();
    reopened.dispose();
    other.dispose();
  });
  testWidgets(
      'only supported active complete packs are buyable; offline owners retain hidden/retired collection',
      (tester) async {
    var online = true, claims = 0;
    ShopLoadout? equipped;
    final c = PackCatalog(AccountApi(
        baseUrl: 'https://catalog.test',
        client: MockClient((_) async {
          if (!online) throw const AccountException('offline');
          return http.Response(
              jsonEncode({
                'version': 1,
                'packs': [
                  entry('moonlight', price: 93),
                  entry('sakura', status: 'hidden'),
                  entry('golden_autumn', build: 999),
                  entry('crystal_forest')
                ]
              }),
              200);
        })));
    await tester.runAsync(() => c.load());
    Widget page() => MaterialApp(
        home: Scaffold(
            body: BetterSeedShopPage(
                catalog: c,
                ownedPacks: const {'sakura'},
                leafCoins: 1000,
                onAcquire: (offer) {
                  expect(offer.price, 93);
                  expect(offer.revision, 4);
                  claims++;
                },
                onApplyLoadout: (value) => equipped = value)));
    await tester.pumpWidget(page());
    expect(
        find.byKey(const ValueKey('shop-pack-crystal_forest')), findsNothing);
    expect(find.byKey(const ValueKey('shop-pack-golden_autumn')), findsOneWidget);
    expect(find.byKey(const ValueKey('shop-pack-sakura')), findsOneWidget);
    final buy = find.byKey(const ValueKey('shop-action-moonlight'));
    await tester.ensureVisible(buy);
    await tester.tap(buy);
    expect(claims, 1);
    online = false;
    await tester.runAsync(() => c.load());
    await tester.pumpWidget(page());
    await tester.pump();
    expect(tester.widget<FilledButton>(buy).onPressed, isNull);
    final tab = find.byKey(const ValueKey('shop-collection-tab'));
    await tester.ensureVisible(tab);
    await tester.tap(tab);
    await tester.pump();
    final own = find.byKey(const ValueKey('shop-action-owned-sakura'));
    await tester.ensureVisible(own);
    await tester.tap(own);
    expect(equipped, isNull, reason: 'Owned but not downloaded must not equip');
    c.dispose();
  });
  testWidgets('an incomplete APK mapping cannot offer a purchase',
      (tester) async {
    final c = PackCatalog(
        AccountApi(
            baseUrl: 'https://catalog.test',
            client: MockClient((_) async => http.Response(
                jsonEncode({
                  'version': 1,
                  'packs': [entry('moonlight')]
                }),
                200))),
        bundle: MissingAssets());
    await tester.runAsync(() => c.load());
    expect(c.online, true);
    expect(c.assetReady('moonlight'), false);
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: BetterSeedShopPage(catalog: c))));
    final locked = tester.widget<FilledButton>(
      find.byKey(const ValueKey('shop-action-moonlight')));
    expect(locked.onPressed, isNull);
    c.dispose();
  });
  testWidgets('free claims remain available with a negative refund balance',
      (tester) async {
    var claims = 0;
    final c = PackCatalog(AccountApi(
        baseUrl: 'https://catalog.test',
        client: MockClient((_) async => http.Response(
            jsonEncode({
              'version': 1,
              'packs': [entry('moonlight', price: 0)]
            }),
            200))));
    await tester.runAsync(() => c.load());
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: BetterSeedShopPage(
                catalog: c, leafCoins: -10, onAcquire: (_) => claims++))));
    final claim = find.byKey(const ValueKey('shop-action-moonlight'));
    await tester.ensureVisible(claim);
    await tester.tap(claim);
    expect(claims, 1);
    c.dispose();
  });
}
