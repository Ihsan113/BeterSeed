import 'catalog_fixture.dart';
import 'package:betterseed/data/garden_pack_registry.dart';
import 'dart:convert';
import 'dart:io';
import 'package:betterseed/widgets/shop_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late dynamic catalog;
  setUp(() async { catalog = await fixtureCatalog(); });
  tearDown(() => catalog.dispose());
  test('Only Default artwork and every pack thumbnail ship in the app', () {
    final bundled = File('pubspec.yaml').readAsStringSync();
    expect(GardenPackRegistry.packs, hasLength(10));
    expect(bundled, contains('- assets/images/shop/'));
    expect(bundled, isNot(contains('- assets/videos/')));
    final downloadable = (jsonDecode(File('assets/pack_downloads.json').readAsStringSync())
        as Map<String, dynamic>)['packs'] as Map<String, dynamic>;
    expect(downloadable.length, 9);
    for (final pack in GardenPackRegistry.packs) {
      expect(File(pack.thumbnail!).existsSync(), isTrue);
      expect(pack.trees, hasLength(6));
      if (pack.id != 'default') {
        expect(downloadable.containsKey(pack.id), isTrue);
        for (final path in [...pack.trees, pack.background, pack.wateringCan, pack.butterfly,
          if (pack.video != null) pack.video!]) {
          expect(File(path).existsSync(), isFalse, reason: 'Must download, not bundle: $path');
        }
      } else {
        for (final path in [...pack.trees, pack.background, pack.wateringCan, pack.butterfly]) {
          expect(File(path).existsSync(), isTrue);
        }
      }
    }
    expect(File('native/android/res/drawable/widget_background.xml').existsSync(), isTrue);
    for (var i = 0; i < 6; i++) {
      expect(File('native/android/res/drawable-nodpi/widget_tree_$i.webp').existsSync(), isTrue);
      expect(File('native/android/res/drawable-nodpi/widget_moon_tree_$i.webp').existsSync(), isFalse);
    }
  });

  test('Asset editor loadouts respect pack ownership and independent cosmetic IDs', () {
    final mixed = ShopLoadout.sakuraPack.copyWith(backgroundId: 'twilight_overlook');
    expect(mixed.treeSkinId, 'sakura_tree_skin');
    expect(mixed.backgroundId, 'twilight_overlook');
    final restored = ShopLoadout.fromMap(mixed.toJson(),
        moonlightOwned: true, sakuraOwned: true);
    expect(restored.backgroundId, 'twilight_overlook');
    final locked = ShopLoadout.fromMap(mixed.toJson(),
        moonlightOwned: false, sakuraOwned: false);
    expect(locked.treeSkinId, 'default');
    expect(locked.backgroundId, 'default');
  });

  test('A bundle applies all five cosmetics together', () {
    expect(ShopLoadout.defaultPack.packId, 'default');
    expect(ShopLoadout.moonlightPack.packId, 'moonlight');
    expect(ShopLoadout.moonlightPack.treeSkinId, 'moonlight_tree_skin');
    expect(ShopLoadout.moonlightPack.backgroundId, 'twilight_overlook');
    expect(ShopLoadout.moonlightPack.butterflyId, 'cosmic_butterfly');
    expect(ShopLoadout.moonlightPack.wateringCanId, 'celestial_watering_can');
    expect(ShopLoadout.moonlightPack.fireflyId, 'prism_fireflies');
    expect(ShopLoadout.autumnPack.packId, 'golden_autumn');
    expect(ShopLoadout.autumnPack.treeSkinId, 'golden_autumn_tree_skin');
    expect(ShopLoadout.autumnPack.backgroundId, 'golden_autumn_garden');
    expect(ShopLoadout.autumnPack.butterflyId, 'amber_butterfly');
    expect(ShopLoadout.autumnPack.wateringCanId, 'maple_watering_can');
    expect(ShopLoadout.autumnPack.fireflyId, 'ember_fireflies');
  });

  for (final scale in <double>[1, 1.6, 2]) {
    testWidgets('Shop and Collection fit a 320x640 screen at text scale $scale', (tester) async {
      tester.view.physicalSize = const Size(320,640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: const Size(320,640),
            textScaler: TextScaler.linear(scale)),
          child: Scaffold(body: BetterSeedShopPage(catalog: catalog,moonlightOwned: true)),
        ),
      ));
      await tester.pump();
      expect(find.byKey(const ValueKey('shop-pack-default')), findsOneWidget);
      expect(find.byKey(const ValueKey('shop-pack-moonlight')), findsOneWidget);
      expect(tester.takeException(), isNull);
      final collectionTab = find.byKey(const ValueKey('shop-collection-tab'));
      await tester.ensureVisible(collectionTab);
      await tester.pumpAndSettle();
      await tester.tap(collectionTab);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('shop-pack-owned-default')), findsOneWidget);
      expect(find.byKey(const ValueKey('shop-pack-owned-moonlight')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Claim once, equip from collection, and return to default', (tester) async {
    var owned = false;
    var loadout = ShopLoadout.defaultPack;
    await tester.pumpWidget(MaterialApp(home: StatefulBuilder(
      builder: (ctx, setLocal) => Scaffold(
        body: BetterSeedShopPage(catalog: catalog,
          moonlightOwned: owned, loadout: loadout, leafCoins: 999,
          onAcquire: (_) => setLocal(() => owned = true),
          onApplyLoadout: (newLoadout) => setLocal(() => loadout = newLoadout),
        ),
      ),
    )));
    final claim = find.byKey(const ValueKey('shop-action-moonlight'));
    await tester.ensureVisible(claim);
    await tester.pump();
    await tester.tap(claim);
    await tester.pump();
    expect(owned, isTrue);
    expect(loadout.packId, 'default'); // Claim never auto-equips.
    await tester.ensureVisible(find.byKey(const ValueKey('shop-collection-tab')));
    await tester.tap(find.byKey(const ValueKey('shop-collection-tab')));
    await tester.pump();
    final downloadAction = find.byKey(const ValueKey('shop-action-owned-moonlight'));
    expect(downloadAction, findsOneWidget);
    final downloadButton = tester.widget<FilledButton>(downloadAction);
    expect(downloadButton.onPressed, isNotNull);
    expect(loadout.packId, 'default'); // Cannot equip undownloaded art.
    expect(tester.takeException(), isNull);
  });

  testWidgets('Sakura claim, use, and return to default', (tester) async {
    var sakuraOwned = false;
    var loadout = ShopLoadout.defaultPack;
    await tester.pumpWidget(MaterialApp(home: StatefulBuilder(
      builder: (ctx, refresh) => Scaffold(
        body: BetterSeedShopPage(catalog: catalog,
          loadout: loadout, sakuraOwned: sakuraOwned, leafCoins: 999,
          onAcquire: (_) => refresh(() => sakuraOwned = true),
          onApplyLoadout: (value) => refresh(() => loadout = value),
        ),
      ),
    )));
    final claim = find.byKey(const ValueKey('shop-action-sakura'));
    await tester.ensureVisible(claim);
    await tester.pump();
    await tester.tap(claim);
    await tester.pump();
    expect(sakuraOwned, isTrue);
    expect(loadout.packId, 'default');
    await tester.ensureVisible(find.byKey(const ValueKey('shop-collection-tab')));
    await tester.tap(find.byKey(const ValueKey('shop-collection-tab')));
    await tester.pump();
    final downloadAction = find.byKey(const ValueKey('shop-action-owned-sakura'));
    expect(downloadAction, findsOneWidget);
    final downloadButton = tester.widget<FilledButton>(downloadAction);
    expect(downloadButton.onPressed, isNotNull);
    expect(loadout.packId, 'default'); // Cannot equip undownloaded art.
    expect(tester.takeException(), isNull);
  });

  testWidgets('Golden Autumn claim, use, and return to default', (tester) async {
    var autumnOwned = false;
    var loadout = ShopLoadout.defaultPack;
    await tester.pumpWidget(MaterialApp(home: StatefulBuilder(
      builder: (ctx, refresh) => Scaffold(
        body: BetterSeedShopPage(catalog: catalog,
          loadout: loadout, autumnOwned: autumnOwned, leafCoins: 999,
          onAcquire: (_) => refresh(() => autumnOwned = true),
          onApplyLoadout: (value) => refresh(() => loadout = value),
        ),
      ),
    )));
    final claim = find.byKey(const ValueKey('shop-action-golden_autumn'));
    await tester.ensureVisible(claim);
    await tester.pump();
    await tester.tap(claim);
    await tester.pump();
    expect(autumnOwned, isTrue);
    expect(loadout.packId, 'default');
    await tester.ensureVisible(find.byKey(const ValueKey('shop-collection-tab')));
    await tester.tap(find.byKey(const ValueKey('shop-collection-tab')));
    await tester.pump();
    final downloadAction = find.byKey(const ValueKey('shop-action-owned-golden_autumn'));
    expect(downloadAction, findsOneWidget);
    final downloadButton = tester.widget<FilledButton>(downloadAction);
    expect(downloadButton.onPressed, isNotNull);
    expect(loadout.packId, 'default'); // Cannot equip undownloaded art.
    expect(tester.takeException(), isNull);
  });
}
