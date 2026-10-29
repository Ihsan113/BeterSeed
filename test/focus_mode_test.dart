import 'garden_test_helpers.dart';
import 'package:betterseed/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Focus mode hides panels and returns to the Garden', (tester) async {
    tester.view.physicalSize = const Size(360, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({
      'betterseed_music_v2': false,
      'betterseed_sfx_v2': false,
      'betterseed_motion_v2': false,
    });
    await tester.pumpWidget(const BetterSeedApp(showLaunchFlow: false));
    await waitForGardenReady(tester);
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byKey(const ValueKey('enter-focus-mode')), findsOneWidget);
    expect(find.byKey(const ValueKey('tab-0')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('enter-focus-mode')));
    await tester.pump();

    expect(find.byKey(const ValueKey('exit-focus-mode')), findsOneWidget);
    expect(find.byKey(const ValueKey('tab-0')), findsNothing);
    expect(find.byKey(const ValueKey('water-tree')), findsNothing);
    expect(find.byTooltip('Settings'), findsNothing);
    expect(find.byKey(const ValueKey('full-background')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('exit-focus-mode')));
    await tester.pump();
    expect(find.byKey(const ValueKey('enter-focus-mode')), findsOneWidget);
    expect(find.byKey(const ValueKey('tab-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('water-tree')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Focus mode remains accessible on a compact screen', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({
      'betterseed_music_v2': false,
      'betterseed_sfx_v2': false,
      'betterseed_motion_v2': false,
    });
    await tester.pumpWidget(const BetterSeedApp(showLaunchFlow: false));
    await waitForGardenReady(tester);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byKey(const ValueKey('enter-focus-mode')));
    await tester.pump();
    expect(find.byKey(const ValueKey('exit-focus-mode')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('exit-focus-mode')));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
