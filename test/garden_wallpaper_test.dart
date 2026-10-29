import 'garden_test_helpers.dart';
import 'dart:async';

import 'package:betterseed/main.dart';
import 'package:betterseed/platform/garden_wallpaper.dart';
import 'package:betterseed/widgets/garden_wallpaper_page.dart';
import 'package:betterseed/widgets/local_pack_video_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = GardenWallpaper.channel;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('Missing native host reports unsupported rather than success', () async {
    final caps = await GardenWallpaper.capabilities();
    expect(caps.supported, isFalse);
    expect(caps.allowed, isFalse);
  });

  for (final target in WallpaperTarget.values) {
    test('${target.name} sends only the chosen image and target to Android',
        () async {
      final png = Uint8List.fromList([137, 80, 78, 71]);
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'setWallpaper');
        expect(call.arguments, {'png': png, 'target': target.name});
        return true;
      });
      await GardenWallpaper.setImage(png, target);
    });
  }

  test('Denied or failed native writes never report wallpaper success',
      () async {
    final png = Uint8List.fromList([1]);
    messenger.setMockMethodCallHandler(channel, (_) async => false);
    await expectLater(GardenWallpaper.setImage(png, WallpaperTarget.home),
        throwsA(isA<PlatformException>()));
    messenger.setMockMethodCallHandler(channel,
        (_) async => throw PlatformException(code: 'WALLPAPER_NOT_ALLOWED'));
    await expectLater(GardenWallpaper.setImage(png, WallpaperTarget.lock),
        throwsA(isA<PlatformException>()));
    await expectLater(
        GardenWallpaper.setImage(Uint8List(0), WallpaperTarget.both),
        throwsA(isA<PlatformException>()));
  });

  Future<void> launch(WidgetTester tester) => tester.pumpWidget(MaterialApp(
          home: GardenWallpaperPage(
        viewport: const Size(180, 320),
        mediaQuery:
            const MediaQueryData(size: Size(180, 320), devicePixelRatio: 2),
        assets: const [],
        garden: const ColoredBox(color: Colors.green),
      )));

  testWidgets('Unavailable or restricted phones cannot apply a wallpaper',
      (tester) async {
    messenger.setMockMethodCallHandler(channel,
        (_) async => {'supported': true, 'allowed': false, 'lockScreen': true});
    await launch(tester);
    await tester.pumpAndSettle();
    expect(find.text('Wallpaper changes are disabled by your device settings.'),
        findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('wallpaper-apply')))
            .onPressed,
        isNull);
  });

  testWidgets('Devices without lock-screen support only offer Home screen',
      (tester) async {
    messenger.setMockMethodCallHandler(channel,
        (_) async => {'supported': true, 'allowed': true, 'lockScreen': false});
    await launch(tester);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('wallpaper-target-home')), findsOneWidget);
    expect(find.byKey(const ValueKey('wallpaper-target-lock')), findsNothing);
    expect(find.byKey(const ValueKey('wallpaper-target-both')), findsNothing);
  });

  testWidgets(
      'Actual PNG capture excludes controls; apply is single-flight and confirms native success',
      (tester) async {
    final received = Completer<Map<dynamic, dynamic>>();
    final finish = Completer<bool>();
    var calls = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'capabilities')
        return {'supported': true, 'allowed': true, 'lockScreen': true};
      calls++;
      received.complete(call.arguments as Map);
      return finish.future;
    });
    await launch(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('wallpaper-target-both')));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('wallpaper-apply')));
      await tester.pump();
    });
    // Image encoding uses the real engine; mocked platform messages need the
    // test's fake microtask queue pumped after the engine returns its bytes.
    for (var i = 0; i < 100 && !received.isCompleted; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    expect(received.isCompleted, isTrue,
        reason: 'The captured PNG must reach Android');
    final args = await received.future;
    expect(args['target'], 'both');
    final bytes = args['png'] as Uint8List;
    expect(bytes.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10]);
    final data = ByteData.sublistView(bytes);
    // Exact garden bounds at 2x, excluding the route's app bar and controls.
    expect(data.getUint32(16), 360);
    expect(data.getUint32(20), 640);
    expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('wallpaper-apply')))
            .onPressed,
        isNull);
    await tester.tap(find.byKey(const ValueKey('wallpaper-apply')));
    await tester.pump();
    expect(calls, 1);
    expect(
        find.text('Garden set on your home and lock screens.'), findsNothing);
    finish.complete(true);
    await tester.pumpAndSettle();
    expect(
        find.text('Garden set on your home and lock screens.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Settings opens a still, clean wallpaper of the saved garden',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'betterseed_music_v2': false,
      'betterseed_sfx_v2': false,
      'betterseed_motion_v2': false,
      // Premium assets are downloaded on demand in 1.7; use the bundled
      // garden so this test exercises the saved placement, not a fallback.
      'betterseed_active_bundle_v1': 'default',
      'betterseed_xp_v1': 100,
      'betterseed_tree_placements_v1':
          '{"default":{"dx":0.1,"dy":-0.1,"scale":1.2}}',
    });
    messenger.setMockMethodCallHandler(channel,
        (_) async => {'supported': true, 'allowed': true, 'lockScreen': true});
    await tester.pumpWidget(const BetterSeedApp(showLaunchFlow: false));
    await waitForGardenReady(tester);
    await pumpGardenTransition(tester);
    final originalTree = tester.renderObject<RenderBox>(
        find.byKey(const ValueKey('editor-draggable-tree')));
    final screen = tester.renderObject<RenderBox>(find.byType(Scaffold));
    final expected = MatrixUtils.transformRect(
        originalTree.getTransformTo(screen), Offset.zero & originalTree.size);
    await tester.tap(find.byTooltip('Settings'));
    await pumpGardenTransition(tester);
    final category = find.byKey(const ValueKey('settings-menu-widget'));
    await tester.ensureVisible(category);
    await tester.tap(category);
    await pumpGardenTransition(tester);
    final entry = find.byKey(const ValueKey('settings-garden-wallpaper'));
    await tester.ensureVisible(entry);
    await tester.tap(entry);
    await pumpGardenTransition(tester);
    final wallpaperPage = find.byType(GardenWallpaperPage);
    expect(wallpaperPage, findsOneWidget);
    final wallpaperViewport = find.descendant(
      of: wallpaperPage,
      matching: find.byKey(const ValueKey('wallpaper-garden-viewport')),
    );
    expect(wallpaperViewport, findsOneWidget);
    // The outgoing Garden and incoming wallpaper can both remain mounted
    // during the route transition. Compare the tree inside the capture viewport,
    // not whichever matching tree happens to come first in the entire app.
    final wallpaperTree = find.descendant(
      of: wallpaperViewport,
      matching: find.byKey(const ValueKey('editor-draggable-tree')),
    );
    expect(wallpaperTree, findsOneWidget);
    expect(
        find.descendant(
            of: wallpaperViewport,
            matching: find.byType(LocalPackVideoBackground)),
        findsNothing);
    final tree = tester.renderObject<RenderBox>(wallpaperTree);
    final viewport = tester.renderObject<RenderBox>(wallpaperViewport);
    final actual = MatrixUtils.transformRect(
        tree.getTransformTo(viewport), Offset.zero & tree.size);
    expect(actual.left, closeTo(expected.left, .01));
    expect(actual.top, closeTo(expected.top, .01));
    expect(actual.size, expected.size);
    expect(find.text('Small steps. Brighter tomorrows. ✨'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
