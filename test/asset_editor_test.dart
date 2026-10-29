import 'garden_test_helpers.dart';
import 'dart:convert';

import 'package:betterseed/logic/garden_scene_geometry.dart';
import 'package:betterseed/main.dart';
import 'package:betterseed/widgets/shop_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> openEditor(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('tab-3')));
  await tester.pump();
  // The new leaf-coin balance card makes Shop taller. Mimic a user
  // scrolling to the Collection tab on small devices before tapping it.
  final collection = find.byKey(const ValueKey('shop-collection-tab'));
  await tester.ensureVisible(collection);
  await pumpGardenTransition(tester);
  await tester.tap(collection);
  await pumpGardenTransition(tester);
  final edit = find.byKey(const ValueKey('collection-edit-assets'));
  await tester.ensureVisible(edit);
  await tester.pump();
  await tester.tap(edit);
  await pumpGardenTransition(tester);
}

Rect treeInViewport(WidgetTester tester, {required bool editing}) {
  final tree = tester.renderObject<RenderBox>(
      find.byKey(const ValueKey('editor-draggable-tree')));
  final viewport = tester.renderObject<RenderBox>(editing
      ? find.byKey(const ValueKey('editor-garden-viewport'))
      : find.byType(Scaffold));
  return MatrixUtils.transformRect(
      tree.getTransformTo(viewport), Offset.zero & tree.size);
}

void expectSameTree(Rect actual, Rect expected) {
  expect(actual.left, closeTo(expected.left, .01));
  expect(actual.top, closeTo(expected.top, .01));
  expect(actual.width, closeTo(expected.width, .01));
  expect(actual.height, closeTo(expected.height, .01));
}

Future<void> launchEditorTest(
  WidgetTester tester, {
  Size size = const Size(393, 852),
  String bundle = 'default',
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPadding);
  SharedPreferences.setMockInitialValues({
    'betterseed_music_v2': false,
    'betterseed_sfx_v2': false,
    'betterseed_motion_v2': false,
    'betterseed_owned_moonlight_v1': true,
    'betterseed_owned_sakura_v1': true,
    'betterseed_active_bundle_v1': bundle,
    'betterseed_xp_v1': 100,
  });
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(const BetterSeedApp(showLaunchFlow: false));
    await waitForGardenReady(tester);
  await pumpGardenTransition(tester);
}

void main() {
  test('Sakura soil target is higher than v1.4.3 and scale is bounded', () {
    const area = Size(360, 550);
    final current = GardenSceneGeometry.groundBottom(area,
        ground: PlantingGround.sakuraGarden);
    expect(current, greaterThan(area.height * .055));
    final lift = GardenSceneGeometry.treeBottomLift(240,
        ground: PlantingGround.sakuraGarden);
    expect(lift, lessThan(240 * .115));
    final clamped = GardenTreePlacement.fromJson({
      'dx': 5.0,
      'dy': -9.0,
      'scale': 30.0,
    });
    expect(clamped.dx, .35);
    expect(clamped.dy, -.35);
    expect(clamped.scale, 1.35);
  });

  test('Garden Tree placement persists with finite bounds', () {
    final one =
        const GardenTreePlacement().copyWith(dx: -.2, dy: .12, scale: 1.1);
    final two = GardenTreePlacement.fromJson(one.toJson());
    expect(two.dx, closeTo(-.2, .0001));
    expect(two.dy, closeTo(.12, .0001));
    expect(two.scale, closeTo(1.1, .0001));
    expect(GardenTreePlacement.fromJson({'dx': double.nan}).dx, 0);
  });

  testWidgets(
      'locked assets can be previewed but saving keeps the editor and existing garden intact',
      (tester) async {
    await launchEditorTest(tester);
    await openEditor(tester);
    await tester.tap(find.byKey(const ValueKey('editor-tool-assets')));
    await pumpGardenTransition(tester);
    for (final entry in {
      'background': 'golden_autumn_garden',
      'tree': 'golden_autumn_tree_skin',
      'butterfly': 'amber_butterfly',
      'watering': 'maple_watering_can',
      'firefly': 'ember_fireflies',
    }.entries) {
      final category = find.byKey(ValueKey('editor-category-${entry.key}'));
      await tester.ensureVisible(category);
      await pumpGardenTransition(tester);
      await tester.tap(category);
      await pumpGardenTransition(tester);
      final choice =
          find.byKey(ValueKey('editor-choice-${entry.key}-${entry.value}'));
      await tester.ensureVisible(choice);
      await pumpGardenTransition(tester);
      expect(
          find.byKey(ValueKey('editor-lock-${entry.value}')), findsOneWidget);
      await tester.tap(choice);
      await pumpGardenTransition(tester);
    }
    // Uninstalled CDN packs are shown using thumbnails; the active scene
    // must fall back to the complete Default Garden instead of missing art.
    expect(find.byKey(const ValueKey('default-3')), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    final original = prefs.getString('betterseed_background_skin_v1');
    await tester.tap(find.byKey(const ValueKey('asset-editor-save')));
    await pumpGardenTransition(tester);
    expect(find.text('Unlock this look'), findsOneWidget);
    expect(prefs.getString('betterseed_background_skin_v1'), original);
    await tester.tap(find.text('Keep editing'));
    await pumpGardenTransition(tester);
    expect(find.byKey(const ValueKey('asset-editor-save')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('asset-editor-cancel')));
    await pumpGardenTransition(tester);
    expect(prefs.getString('betterseed_background_skin_v1'), original);
    expect(tester.takeException(), isNull);
  });

  testWidgets('My Collection exposes an asset editor action', (tester) async {
    var opened = false;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
      body: BetterSeedShopPage(
        moonlightOwned: true,
        sakuraOwned: true,
        onEditAssets: () => opened = true,
      ),
    )));
    final collection = find.byKey(const ValueKey('shop-collection-tab'));
    await tester.ensureVisible(collection);
    await pumpGardenTransition(tester);
    await tester.tap(collection);
    await pumpGardenTransition(tester);
    final edit = find.byKey(const ValueKey('collection-edit-assets'));
    await tester.ensureVisible(edit);
    await tester.pump();
    await tester.tap(edit);
    expect(opened, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Asset editor opens from Collection and Cancel discards changes',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'betterseed_music_v2': false,
      'betterseed_sfx_v2': false,
      'betterseed_motion_v2': false,
      'betterseed_owned_sakura_v1': true,
      'betterseed_active_bundle_v1': 'sakura',
    });
    await tester.pumpWidget(const BetterSeedApp(showLaunchFlow: false));
    await waitForGardenReady(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byKey(const ValueKey('tab-3')));
    await tester.pump();
    final collection = find.byKey(const ValueKey('shop-collection-tab'));
    await tester.ensureVisible(collection);
    await pumpGardenTransition(tester);
    await tester.tap(collection);
    await pumpGardenTransition(tester);
    final edit = find.byKey(const ValueKey('collection-edit-assets'));
    await tester.ensureVisible(edit);
    await tester.pump();
    await tester.tap(edit);
    await tester.pump();
    expect(find.byKey(const ValueKey('editor-draggable-tree')), findsOneWidget);
    expect(find.byKey(const ValueKey('asset-editor-save')), findsOneWidget);
    await tester.drag(find.byKey(const ValueKey('editor-draggable-tree')),
        const Offset(30, -40));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('asset-editor-cancel')));
    await tester.pump();
    final prefs = await SharedPreferences.getInstance();
    expect(
        prefs.getString('betterseed_tree_placements_v1'), anyOf(isNull, '{}'));
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(320, 640),
    const Size(393, 852),
    const Size(800, 1000)
  ]) {
    for (final bundle in ['default']) {
      testWidgets('$bundle preview, drag, Save and reload agree at $size',
          (tester) async {
        await launchEditorTest(tester, size: size, bundle: bundle);
        final original = treeInViewport(tester, editing: false);
        await openEditor(tester);
        expectSameTree(treeInViewport(tester, editing: true), original);

        final tree = find.byKey(const ValueKey('editor-draggable-tree'));
        final viewport = tester.renderObject<RenderBox>(
            find.byKey(const ValueKey('editor-garden-viewport')));
        final scale = (viewport.localToGlobal(const Offset(1, 0)) -
                viewport.localToGlobal(Offset.zero))
            .distance;
        final gesture = await tester.startGesture(tester.getCenter(tree));
        await gesture.moveBy(const Offset(0, -25));
        await tester.pump();
        final before = treeInViewport(tester, editing: true);
        await gesture.moveBy(const Offset(12, -8));
        await tester.pump();
        final moved = treeInViewport(tester, editing: true);
        expect(moved.center.dx - before.center.dx, closeTo(12 / scale, .1));
        expect(moved.center.dy - before.center.dy, closeTo(-8 / scale, .1));
        await gesture.up();
        // Exercise the real size control rather than calling state callbacks.
        final slider = find.byKey(const ValueKey('asset-tree-size'));
        await tester.ensureVisible(slider);
        await tester.drag(slider, const Offset(24, 0));
        await pumpGardenTransition(tester);
        final edited = treeInViewport(tester, editing: true);
        expect(edited.width, greaterThan(original.width));
        final outline = tester.renderObject<RenderBox>(
            find.byKey(const ValueKey('editor-tree-selection')));
        final selection = MatrixUtils.transformRect(
            outline.getTransformTo(viewport), Offset.zero & outline.size);
        expectSameTree(selection, edited);

        await tester.tap(find.byKey(const ValueKey('asset-editor-save')));
        await pumpGardenTransition(tester);
        expectSameTree(treeInViewport(tester, editing: false), edited);
        final prefs = await SharedPreferences.getInstance();
        final saved =
            jsonDecode(prefs.getString('betterseed_tree_placements_v1')!)
                as Map;
        expect(saved, isNotEmpty);

        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(const BetterSeedApp(showLaunchFlow: false));
    await waitForGardenReady(tester);
        await pumpGardenTransition(tester);
        expectSameTree(treeInViewport(tester, editing: false), edited);
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final packId in ['moonlight', 'sakura']) {
    testWidgets('Owned $packId requires download before saving garden edits',
        (tester) async {
      await launchEditorTest(tester, bundle: packId);
      await openEditor(tester);
      expect(find.byKey(const ValueKey('editor-draggable-tree')), findsOneWidget);
      // Ownership is not proof that an optional pack is installed.
      // The scene must remain renderable from Default Garden art.
      expect(find.byKey(const ValueKey('default-3')), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      final before = prefs.getString('betterseed_tree_placements_v1');
      await tester.tap(find.byKey(const ValueKey('asset-editor-save')));
      await pumpGardenTransition(tester);
      expect(find.text('Download this look'), findsOneWidget);
      expect(prefs.getString('betterseed_tree_placements_v1'), before);
      await tester.tap(find.text('Keep editing'));
      await pumpGardenTransition(tester);
      await tester.tap(find.byKey(const ValueKey('asset-editor-cancel')));
      await pumpGardenTransition(tester);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Preview is read-only and changing tools preserves tree geometry',
      (tester) async {
    await launchEditorTest(tester);
    await openEditor(tester);
    final expected = treeInViewport(tester, editing: true);
    for (final tool in ['preview', 'assets', 'position']) {
      await tester.tap(find.byKey(ValueKey('editor-tool-$tool')));
      await pumpGardenTransition(tester);
      expectSameTree(treeInViewport(tester, editing: true), expected);
      if (tool != 'position') {
        await tester.drag(find.byKey(const ValueKey('editor-draggable-tree')),
            const Offset(20, -30));
        await pumpGardenTransition(tester);
        expectSameTree(treeInViewport(tester, editing: true), expected);
      }
    }
    await tester.tap(find.byKey(const ValueKey('asset-editor-cancel')));
    await pumpGardenTransition(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Unavailable CDN choice cannot overwrite saved placements',
      (tester) async {
    await launchEditorTest(tester);
    await openEditor(tester);
    await tester.drag(find.byKey(const ValueKey('editor-draggable-tree')),
        const Offset(20, -30));
    await pumpGardenTransition(tester);
    final editedDefault = treeInViewport(tester, editing: true);
    await tester.tap(find.byKey(const ValueKey('editor-tool-assets')));
    await pumpGardenTransition(tester);
    final sakura = find.byKey(
        const ValueKey('editor-choice-background-sakura_garden'));
    await tester.ensureVisible(sakura);
    await tester.tap(sakura);
    await pumpGardenTransition(tester);
    // The downloadable background is not installed. Guard against exporting
    // a broken scene with an image path that was intentionally not bundled.
    expectSameTree(treeInViewport(tester, editing: true), editedDefault);
    await tester.tap(find.byKey(const ValueKey('asset-editor-save')));
    await pumpGardenTransition(tester);
    expect(find.text('Download this look'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('betterseed_tree_placements_v1'), isNull);
    await tester.tap(find.text('Keep editing'));
    await pumpGardenTransition(tester);
    final fallback = find.byKey(
        const ValueKey('editor-choice-background-default'));
    await tester.ensureVisible(fallback);
    await tester.tap(fallback);
    await pumpGardenTransition(tester);
    await tester.tap(find.byKey(const ValueKey('asset-editor-save')));
    await pumpGardenTransition(tester);
    final saved = prefs.getString('betterseed_tree_placements_v1');
    expect(saved, isNotNull);
    expect(prefs.getString('betterseed_background_skin_v1'), 'default');
    await openEditor(tester);
    await tester.drag(find.byKey(const ValueKey('editor-draggable-tree')),
        const Offset(-15, -25));
    await pumpGardenTransition(tester);
    await tester.tap(find.byKey(const ValueKey('asset-editor-cancel')));
    await pumpGardenTransition(tester);
    expect(prefs.getString('betterseed_tree_placements_v1'), saved);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Editor tools remain usable on a compact screen with large text',
      (tester) async {
    await launchEditorTest(tester, size: const Size(320, 640), textScale: 1.8);
    await openEditor(tester);
    for (final tool in ['position', 'assets', 'preview']) {
      await tester.tap(find.byKey(ValueKey('editor-tool-$tool')));
      await pumpGardenTransition(tester);
      if (tool == 'position') {
        for (final axis in ['x', 'y', 'size']) {
          final choice = find.byKey(ValueKey('editor-adjust-$axis'));
          await tester.ensureVisible(choice);
          await tester.tap(choice);
          await pumpGardenTransition(tester);
          final slider = find.byKey(ValueKey('asset-tree-$axis'));
          await tester.ensureVisible(slider);
          await tester.drag(slider, const Offset(10, 0));
          await pumpGardenTransition(tester);
        }
      }
      if (tool == 'assets') {
        for (final field in [
          'background',
          'tree',
          'butterfly',
          'watering',
          'firefly'
        ]) {
          final category = find.byKey(ValueKey('editor-category-$field'));
          await tester.ensureVisible(category);
          await tester.tap(category);
          await pumpGardenTransition(tester);
          final choice = find.byKey(ValueKey('editor-choice-$field-default'));
          await tester.ensureVisible(choice);
          await tester.tap(choice);
          await pumpGardenTransition(tester);
        }
      }
      expect(
          tester.getSize(find.byKey(const ValueKey('editor-garden-viewport'))),
          const Size(320, 640));
      expect(tester.takeException(), isNull);
    }
    await tester.tap(find.byKey(const ValueKey('asset-editor-save')));
    await pumpGardenTransition(tester);
    expect(tester.takeException(), isNull);
  });
}
