import 'package:betterseed/main.dart';
import 'package:betterseed/widgets/launch_experience.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _advanceSplash(WidgetTester tester) async {
  // Never pumpAndSettle on an animated splash or on the living garden.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1650));
  await tester.pump();
}

Future<void> _moveToNextSlide(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('onboarding-next')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 380));
  await tester.pump();
}

void main() {
  testWidgets('first launch shows animated splash and optional welcome flow',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'betterseed_music_v2': false,
      'betterseed_sfx_v2': false,
      'betterseed_motion_v2': false,
    });
    await tester.pumpWidget(const BetterSeedApp());
    expect(find.byKey(const ValueKey('launch-splash')), findsOneWidget);
    expect(find.text('Preparing your calm garden...'), findsOneWidget);
    expect(find.byKey(const ValueKey('launch-loading-dots')), findsOneWidget);

    await _advanceSplash(tester);
    expect(find.byKey(const ValueKey('launch-onboarding')), findsOneWidget);
    expect(find.text('Grow one step at a time'), findsOneWidget);
    expect(find.byKey(const ValueKey('onboarding-skip')), findsOneWidget);

    await _moveToNextSlide(tester);
    expect(find.byKey(const ValueKey('onboarding-habit-examples')), findsOneWidget);
    await _moveToNextSlide(tester);
    expect(find.text('Earn water. Nurture your tree.'), findsOneWidget);
    await _moveToNextSlide(tester);
    expect(find.byKey(const ValueKey('onboarding-headphone-tip')), findsOneWidget);
    expect(find.text('Best experienced with headphones'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('onboarding-next')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(GrowthHome), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(onboardingCompletedPreference), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('returning user sees splash but does not repeat onboarding',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      onboardingCompletedPreference: true,
      'betterseed_music_v2': false,
      'betterseed_sfx_v2': false,
      'betterseed_motion_v2': false,
    });
    await tester.pumpWidget(const BetterSeedApp());
    expect(find.byKey(const ValueKey('launch-splash')), findsOneWidget);
    await _advanceSplash(tester);
    expect(find.byType(GrowthHome), findsOneWidget);
    expect(find.byKey(const ValueKey('launch-onboarding')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('skip completes guide and saved habits are not modified',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'betterseed_music_v2': false,
      'betterseed_sfx_v2': false,
      'betterseed_motion_v2': false,
      'betterseed_xp_v1': 42,
    });
    await tester.pumpWidget(const BetterSeedApp());
    await _advanceSplash(tester);
    expect(find.byKey(const ValueKey('launch-onboarding')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('onboarding-skip')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(GrowthHome), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(onboardingCompletedPreference), isTrue);
    expect(prefs.getInt('betterseed_xp_v1'), 42);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings can reopen welcome guide for returning user',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      onboardingCompletedPreference: true,
      'betterseed_music_v2': false,
      'betterseed_sfx_v2': false,
      'betterseed_motion_v2': false,
    });
    await tester.pumpWidget(const BetterSeedApp());
    await _advanceSplash(tester);
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.byTooltip('Settings'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    final widgetMenu = find.byKey(const ValueKey('settings-menu-widget'));
    await tester.ensureVisible(widgetMenu);
    await tester.pump();
    await tester.tap(widgetMenu);
    await tester.pump();
    final replay = find.byKey(const ValueKey('settings-replay-onboarding'));
    expect(replay, findsOneWidget);
    await tester.ensureVisible(replay);
    await tester.pump();
    await tester.tap(replay);
    await tester.pump();
    expect(find.byKey(const ValueKey('launch-onboarding')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('onboarding-skip')));
    await tester.pump();
    expect(find.byType(GrowthHome), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
