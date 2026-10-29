import 'package:betterseed/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Four navigation tabs fit on compact 360x640 screens', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({
      'betterseed_music_v2': false,
      'betterseed_sfx_v2': false,
      'betterseed_motion_v2': false,
    });
    await tester.pumpWidget(const BetterSeedApp(showLaunchFlow: false));
    await tester.pump(const Duration(milliseconds: 500));
    for (var i = 0; i < 4; i++) {
      expect(find.byKey(ValueKey('tab-$i')), findsOneWidget);
      await tester.tap(find.byKey(ValueKey('tab-$i')));
      await tester.pump();
      expect(tester.takeException(), isNull,
          reason: 'Bottom navigation must not overflow on compact screens');
    }
  });

  testWidgets('Checklist completion earns water and watering consumes it', (tester) async {
    SharedPreferences.setMockInitialValues({
      'betterseed_music_v2': false,
      'betterseed_sfx_v2': false,
      'betterseed_motion_v2': false,
    });
    await tester.pumpWidget(const BetterSeedApp(showLaunchFlow: false));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Earn'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('tab-1')));
    await tester.pump();
    expect(find.text('Today’s Checklist'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('habit-drink')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('tab-0')));
    await tester.pump();
    expect(find.text('1 water available'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('water-tree')));
    await tester.pump();
    expect(find.text('0 water available'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('tab-2')));
    await tester.pump();
    expect(find.text('Your Progress'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('tab-3')));
    await tester.pump();
    expect(find.byKey(const ValueKey('shop-pack-default')), findsOneWidget);
    expect(find.textContaining('Shop is unavailable'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('tab-0')));
    await tester.pump();
    expect(find.byKey(const ValueKey('water-tree')), findsOneWidget);
  });
}
