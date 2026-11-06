import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:betterseed/main.dart';
import 'package:betterseed/checklist/checklist_data.dart';
import 'package:betterseed/data/habit.dart';
import 'package:betterseed/logic/water_progress.dart';
import '../test/garden_test_helpers.dart';
import 'package:betterseed/focus/focus_session.dart';
import 'package:betterseed/focus/focus_hud.dart';
import 'package:betterseed/checklist/checklist_page.dart';

void main() {
  testWidgets('render redesigned checklist screens', (tester) async {
    const flutterSdk = String.fromEnvironment('FLUTTER_SDK');
    const outputDir = String.fromEnvironment('PREVIEW_OUTPUT',
        defaultValue: 'build/planner_preview');
    await tester.runAsync(() => Directory(outputDir).create(recursive: true));
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final name in [
      'xyz.luan/audioplayers.global',
      'xyz.luan/audioplayers.global/events'
    ]) {
      messenger.setMockMethodCallHandler(
          MethodChannel(name), (_) async => null);
    }
    messenger.setMockMethodCallHandler(
        const MethodChannel('xyz.luan/audioplayers'), (call) async {
      final id = (call.arguments as Map?)?['playerId'];
      if (id != null)
        messenger.setMockMethodCallHandler(
            MethodChannel('xyz.luan/audioplayers/events/$id'),
            (_) async => null);
      return null;
    });
    await tester.runAsync(() async {
      for (final e in {
        'Ahem': 'Roboto-Regular.ttf',
        'Roboto': 'Roboto-Regular.ttf',
        'MaterialIcons': 'MaterialIcons-Regular.otf'
      }.entries) {
        final loader = FontLoader(e.key)
          ..addFont(Future.value(ByteData.sublistView(
              File('$flutterSdk/bin/cache/artifacts/material_fonts/${e.value}')
                  .readAsBytesSync())));
        await loader.load();
      }
    });
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    final now = DateTime.now();
    final day = checklistDay(now);
    final key = GlobalKey();
    final water = WaterProgress(xp: 180, totalEarned: 28, totalSpent: 18)
      ..earnForHabit(day, 'stretch');
    ChecklistData history(HabitPlan plan, String category, int todayValue) {
      var data = ChecklistData(
          start: checklistDay(DateTime(now.year, now.month, now.day - 13)),
          plan: plan,
          category: category);
      for (var i = 13; i >= 0; i--) {
        final date = DateTime(now.year, now.month, now.day - i);
        final value = i == 0
            ? todayValue
            : i % 5 == 0
                ? 0
                : plan.target;
        data = data.record(
            date, data.today(date).change(value: value, rest: i == 8));
      }
      return data;
    }

    final habits = [
      Habit(
          id: 'drink',
          title: 'Drink more water',
          iconKey: 'water',
          checklist: history(
              const HabitPlan(type: 'count', target: 8, unit: 'count'),
              'Morning',
              3)),
      Habit(
          id: 'stretch',
          title: 'Morning stretch',
          iconKey: 'stretch',
          completed: true,
          checklist: history(const HabitPlan(), 'Morning', 1)),
      Habit(
          id: 'read',
          title: 'Read a good book',
          iconKey: 'book',
          checklist: history(
              const HabitPlan(
                  type: 'duration', target: 20, activityMinute: 1140),
              'Evening',
              5)),
    ];
    // Explicit render test, invoked separately from the normal test directory.
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({
      'betterseed_music_v2': false,
      'betterseed_sfx_v2': false,
      'betterseed_motion_v2': false,
      'betterseed_day_v1': day,
      'betterseed_habits_v1':
          jsonEncode(habits.map((h) => h.toJson()).toList()),
      'betterseed_water_progress_v3': jsonEncode(water.toJson())
    });
    final session = FocusSession(
        habitId: 'read',
        day: day,
        targetMinutes: 20,
        baseSeconds: 300,
        elapsedMilliseconds: 300000);
    await FocusSessionStore('guest').save(session);
    session.dispose();
    await tester.pumpWidget(RepaintBoundary(
        key: key, child: const BetterSeedApp(showLaunchFlow: false)));
    await waitForGardenReady(tester);
    Future<void> capture(String name) async {
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final boundary =
          key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final output = await boundary.toImage(pixelRatio: 2);
        final bytes = await output.toByteData(format: ui.ImageByteFormat.png);
        await File('$outputDir/$name.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
      });
    }

    await tester.tap(find.byKey(const ValueKey('tab-1')));
    await tester.pumpAndSettle();
    await capture('BetterSeed_2_1_Checklist');
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('focus-read')), 150,
        scrollable: find
            .descendant(
                of: find.byType(ChecklistPage),
                matching: find.byType(Scrollable))
            .first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('focus-read')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('focus-toggle')));
    await tester.pumpAndSettle();
    await capture('BetterSeed_2_1_Focus');
    await tester.tap(find.byKey(const ValueKey('focus-toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('focus-finish')));
    for (var i = 0;
        i < 60 && find.byType(FocusHud).evaluate().isNotEmpty;
        i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (i % 8 == 0)
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)));
    }
    expect(find.byType(FocusHud), findsNothing);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tab-2')));
    await tester.pumpAndSettle();
    await capture('BetterSeed_2_1_Statistics');
    await tester.tap(find.byKey(const ValueKey('stats-section-1')));
    await tester.pumpAndSettle();
    await capture('BetterSeed_2_1_Insights');
    await tester.tap(find.byKey(const ValueKey('tab-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add a daily habit'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextFormField).first, 'Read a good book');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('goal-type-duration')));
    await tester.pumpAndSettle();
    await capture('BetterSeed_2_1_Goal_Picker');
    await tester.scrollUntilVisible(find.text('Activity time'), 150,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Activity time'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await capture('BetterSeed_2_1_Schedule');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 400));
  });
}
