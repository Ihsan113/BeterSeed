import 'catalog_fixture.dart';
import 'dart:io';

import 'package:betterseed/data/garden_appearance.dart';
import 'package:betterseed/widgets/garden_pack_preview.dart';
import 'package:betterseed/widgets/shop_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late dynamic catalog;
  setUp(() async { catalog = await fixtureCatalog(); });
  tearDown(() => catalog.dispose());
  const packs = {
    'default': ShopLoadout.defaultPack,
    'moonlight': ShopLoadout.moonlightPack,
    'sakura': ShopLoadout.sakuraPack,
    'golden_autumn': ShopLoadout.autumnPack,
  };

  test('All preview stages and mixed cosmetics resolve to real bundled artwork',
      () {
    for (final pack in [ShopLoadout.defaultPack]) {
      final look = GardenAppearance(pack);
      for (final asset in [
        ...look.treeImages,
        look.background,
        look.butterfly,
        look.wateringCan
      ]) {
        expect(File(asset).existsSync(), isTrue, reason: asset);
      }
      expect(look.treeImages.toSet(), hasLength(6));
    }
    final mixed = GardenAppearance(ShopLoadout.sakuraPack.copyWith(
      backgroundId: ShopLoadout.autumnPack.backgroundId,
      wateringCanId: ShopLoadout.moonlightPack.wateringCanId,
    ));
    expect(mixed.background, contains('golden_autumn'));
    expect(mixed.treeAsset(3), contains('/sakura/'));
    expect(mixed.wateringCan, contains('celestial'));
  });

  for (final entry in packs.entries.where((e) => e.key == 'default')) {
    testWidgets(
        '${entry.key} preview works before ownership without claiming or equipping',
        (tester) async {
      var claims = 0;
      var equips = 0;
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: BetterSeedShopPage(catalog: catalog,
        currentStage: 2,
        animatePreviews: false,
        onAcquire: (_) => claims++,
        onApplyLoadout: (_) => equips++,
      ))));
      final preview = find.byKey(ValueKey('shop-preview-${entry.key}'));
      await tester.ensureVisible(preview);
      await tester.pumpAndSettle();
      await tester.tap(preview);
      await tester.pumpAndSettle();
      expect(find.byType(GardenPackPreview), findsOneWidget);
      expect(find.text('Growth stage 3 of 6'), findsOneWidget);
      for (var stage = 2; stage <= 5; stage++) {
        final tree = tester
            .widget<Image>(find.byKey(ValueKey('pack-preview-tree-$stage')));
        expect((tree.image as AssetImage).assetName,
            GardenAppearance(entry.value).treeAsset(stage));
        if (stage < 5) {
          await tester.tap(find.byKey(const ValueKey('pack-preview-next')));
          await tester.pumpAndSettle();
        }
      }
      expect(
          tester
              .widget<IconButton>(
                  find.byKey(const ValueKey('pack-preview-next')))
              .onPressed,
          isNull);
      for (var i = 0; i < 5; i++) {
        await tester.tap(find.byKey(const ValueKey('pack-preview-previous')));
        await tester.pumpAndSettle();
      }
      expect(find.text('Growth stage 1 of 6'), findsOneWidget);
      expect(
          tester
              .widget<IconButton>(
                  find.byKey(const ValueKey('pack-preview-previous')))
              .onPressed,
          isNull);
      await tester.tap(find.byKey(const ValueKey('pack-preview-close')));
      await tester.pumpAndSettle();
      expect(claims, 0);
      expect(equips, 0);
      expect(find.byType(BetterSeedShopPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Undownloaded pack cannot open missing artwork or alter state',
      (tester) async {
    var claims = 0;
    var equips = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: BetterSeedShopPage(catalog: catalog,
          currentStage: 3, animatePreviews: false,
          onAcquire: (_) => claims++, onApplyLoadout: (_) => equips++))));
    final preview = find.byKey(const ValueKey('shop-preview-golden_autumn'));
    await tester.ensureVisible(preview);
    await tester.pumpAndSettle();
    await tester.tap(preview);
    await tester.pump();
    expect(find.text('Download this pack first to preview all 6 stages.'), findsOneWidget);
    expect(find.byType(GardenPackPreview), findsNothing);
    expect(claims, 0);
    expect(equips, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Preview fits compact screens with large text and respects reduced motion',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
      data: const MediaQueryData(
          textScaler: TextScaler.linear(2), disableAnimations: true),
      child: const GardenPackPreview(
          title: 'Original Garden', loadout: ShopLoadout.defaultPack),
    )));
    await tester.pumpAndSettle();
    final next = find.byKey(const ValueKey('pack-preview-next'));
    await tester.ensureVisible(next);
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(find.text('Growth stage 2 of 6'), findsOneWidget);
    expect(find.byType(GardenPackPreview), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
