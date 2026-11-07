import 'dart:convert';
import 'package:betterseed/checklist/checklist_data.dart';
import 'package:betterseed/checklist/checklist_page.dart';
import 'package:betterseed/checklist/checklist_pickers.dart';
import 'package:betterseed/checklist/checklist_reward.dart';
import 'package:betterseed/checklist/checklist_style.dart';
import 'package:betterseed/data/garden_pack_registry.dart';
import 'package:betterseed/data/habit.dart';
import 'package:betterseed/focus/focus_hud.dart';
import 'package:betterseed/focus/focus_session.dart';
import 'package:betterseed/logic/water_progress.dart';
import 'package:betterseed/statistics/garden_milestones.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.now();
  final yesterday = DateTime(now.year, now.month, now.day - 1);
  for (final from in ['checkbox', 'count', 'duration']) {
    for (final to
        in ['checkbox', 'count', 'duration'].where((v) => v != from)) {
      testWidgets('edit $from to $to applies today and survives reopening',
          (tester) async {
        final plan = HabitPlan(
            type: from,
            target: from == 'checkbox' ? 1 : 10,
            unit: from == 'count' ? 'glasses' : '');
        var data = ChecklistData(start: checklistDay(yesterday), plan: plan);
        data = data.record(
            yesterday, data.today(yesterday).change(value: plan.target));
        data = data.record(now, data.today(now).change(value: plan.target));
        final before =
            Habit(id: 'edit', title: 'Read', completed: true, checklist: data);
        Habit? result;
        await tester.pumpWidget(MaterialApp(
            home: Builder(
                builder: (context) => Scaffold(
                    body: FilledButton(
                        onPressed: () async {
                          result = await Navigator.push<Habit>(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => HabitEditor(
                                      initial: before,
                                      creating: false,
                                      masterEnabled: false,
                                      onEnableMaster: () async => false)));
                        },
                        child: const Text('Edit'))))));
        await tester.tap(find.text('Edit'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(ValueKey('goal-type-$to')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save habit'));
        await tester.pumpAndSettle();
        expect(result, isNotNull);
        final restored =
            Habit.fromJson(jsonDecode(jsonEncode(result!.toJson())));
        expect(restored.checklist!.today(now).plan.type, to);
        expect(restored.checklist!.today(now).value, 0);
        expect(restored.completed, false);
        expect(restored.checklist!.pending, isNull);
        expect(restored.checklist!.records[checklistDay(yesterday)]!.toJson(),
            data.records[checklistDay(yesterday)]!.toJson());
        expect(crossesChecklistTarget(before, restored, now), false);
        expect(tester.takeException(), isNull);
      });
    }
  }

  test(
      'same-kind edit preserves seconds, replaces pending, and freezes prior days',
      () {
    const old = HabitPlan(type: 'duration', target: 15, activityMinute: 420);
    var data = ChecklistData(start: checklistDay(yesterday), plan: old);
    data = data.record(
        yesterday, data.today(yesterday).change(value: 4, focusSeconds: 270));
    data =
        data.record(now, data.today(now).change(value: 5, focusSeconds: 359));
    data = data.edit(const HabitPlan(), now); // previous APK's tomorrow plan
    final updated = data.editToday(
        const HabitPlan(type: 'duration', target: 10, activityMinute: 1185),
        now);
    final restored = ChecklistData.fromJson(updated.toJson());
    expect(restored.today(now).durationSeconds, 359);
    expect(restored.today(now).plan.activityMinute, 1185);
    expect(
        restored.today(DateTime(now.year, now.month, now.day + 1)).plan.target,
        10);
    expect(restored.records[checklistDay(yesterday)]!.durationSeconds, 270);
    expect(restored.records[checklistDay(yesterday)]!.plan.activityMinute, 420);
  });

  test(
      'old excess counts normalize today without rewriting prior history or awarding water',
      () {
    const plan = HabitPlan(type: 'count', target: 10, unit: 'count');
    var data = ChecklistData(start: checklistDay(yesterday), plan: plan);
    data = data.record(yesterday, data.today(yesterday).change(value: 1000));
    data = data.record(now, data.today(now).change(value: 1000));
    final before = Habit(id: 'h', title: 'Count', checklist: data);
    final after = before.copyWith(checklist: data.advance(now));
    expect(after.checklist!.today(now).value, 10);
    expect(after.checklist!.records[checklistDay(yesterday)]!.value, 1000);
    expect(crossesChecklistTarget(before, after, now), false);
  });

  testWidgets(
      'activity clock retains draft across keyboard and validates hour/minute',
      (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    int? value;
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: FilledButton(
                    onPressed: () async {
                      value = await ActivityTimePicker.show(context, null);
                    },
                    child: const Text('Open'))))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('time-hour')));
    final hour = tester
        .widget<TextFormField>(find.byKey(const ValueKey('time-hour')))
        .controller!;
    expect(hour.selection, const TextSelection(baseOffset: 0, extentOffset: 2));
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('time-hour')), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('time-hour')), '24');
    await tester.enterText(find.byKey(const ValueKey('time-minute')), '60');
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Invalid time'), findsNWidgets(2));
    expect(value, isNull);
    await tester.enterText(find.byKey(const ValueKey('time-hour')), '19');
    await tester.enterText(find.byKey(const ValueKey('time-minute')), '45');
    tester.view.viewInsets = const FakeViewPadding();
    await tester.pumpAndSettle();
    expect(hour.text, '19');
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(value, 1185);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'reminder stays enabled after nested clock keyboard opens and closes',
      (tester) async {
    addTearDown(tester.view.resetViewInsets);
    ReminderChoice? result;
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: FilledButton(
                    onPressed: () async {
                      result = await ReminderPicker.show(
                          context, const ReminderChoice(false, 420, 0), null);
                    },
                    child: const Text('Open'))))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reminder time'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 200);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('time-hour')), '6');
    await tester.enterText(find.byKey(const ValueKey('time-minute')), '35');
    await tester.ensureVisible(find.text('Save').last);
    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding();
    await tester.pumpAndSettle();
    expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value, true);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(result!.enabled, true);
    expect(result!.minute, 395);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'count stops at target and quick input rejects excessive progress',
      (tester) async {
    var data = ChecklistData(
        start: checklistDay(now),
        plan: const HabitPlan(type: 'count', target: 10, unit: 'count'));
    data = data.record(now, data.today(now).change(value: 9));
    var habits = [Habit(id: 'count', title: 'Drink', checklist: data)];
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: StatefulBuilder(
                builder: (context, update) => ChecklistPage(
                    habits: habits,
                    progress: WaterProgress(),
                    masterEnabled: false,
                    onEnableMaster: () async => false,
                    onChanged: (next) => update(() => habits = next))))));
    final plus = find.byKey(const ValueKey('increment-count'));
    await tester.ensureVisible(plus);
    await tester.pumpAndSettle();
    await tester.tap(plus);
    await tester.pumpAndSettle();
    expect(habits.single.checklist!.today(now).value, 10);
    expect(tester.widget<IconButton>(plus).onPressed, isNull);
    await tester.longPress(find.text('Drink'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Set progress'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('numeric-value')), '1000');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a value from 0 to 10'), findsOneWidget);
    expect(habits.single.checklist!.today(now).value, 10);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unscheduled habit is hidden but remains editable in manager',
      (tester) async {
    final otherDay = now.weekday % 7 + 1;
    final data = ChecklistData(
        start: checklistDay(now),
        plan: HabitPlan(weekdays: [otherDay])).advance(now);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ChecklistPage(
                habits: [
          Habit(id: 'hidden', title: 'Weekend walk', checklist: data)
        ],
                progress: WaterProgress(),
                masterEnabled: false,
                onEnableMaster: () async => false,
                onChanged: (_) {}))));
    expect(find.text('Weekend walk'), findsNothing);
    await tester.ensureVisible(find.byKey(const ValueKey('manage-habits')));
    await tester.tap(find.byKey(const ValueKey('manage-habits')));
    await tester.pumpAndSettle();
    expect(find.text('Weekend walk'), findsOneWidget);
    await tester.tap(find.text('Weekend walk'));
    await tester.pumpAndSettle();
    expect(find.byType(HabitEditor), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('focus auto pauses exactly at target and cannot resume beyond it',
      (tester) async {
    var ms = 0, cues = 0, checkpoints = 0;
    final session = FocusSession(
        habitId: 'h',
        day: checklistDay(now),
        targetMinutes: 1,
        baseSeconds: 59,
        monotonicMilliseconds: () => ms);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: FocusHud(
                session: session,
                title: 'Read',
                motion: false,
                onCheckpoint: () async {
                  checkpoints++;
                },
                onFinish: () async {},
                onExit: () async {},
                onTarget: () => cues++))));
    await tester.tap(find.byKey(const ValueKey('focus-toggle')));
    await tester.pump();
    ms = 5900;
    await tester.pump(const Duration(seconds: 6));
    expect(session.running, false);
    expect(session.totalSeconds, 60);
    expect(cues, 1);
    expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('focus-toggle')))
            .onPressed,
        isNull);
    ms += 60000;
    await tester.pump(const Duration(seconds: 60));
    expect(session.totalSeconds, 60);
    expect(cues, 1);
    expect(checkpoints, greaterThan(0));
    expect(find.text('Target reached'), findsOneWidget);
    final reset = find.byKey(const ValueKey('focus-reset'));
    expect(reset, findsOneWidget);
    expect(tester.widget<IconButton>(reset).onPressed, isNull);
    expect(
        tester
            .widget<OutlinedButton>(find.byKey(const ValueKey('focus-finish')))
            .onPressed,
        isNotNull);
    await tester.tap(reset);
    await tester.pump();
    expect(find.text('Reset this session?'), findsNothing);
    session.reset(); // Model guard also preserves reached progress.
    expect(session.totalSeconds, 60);
    await tester.pumpWidget(const SizedBox());
    session.dispose();
  });

  testWidgets(
      'recovered completed focus keeps Reset visible and disabled on save failure',
      (tester) async {
    final session = FocusSession(
        habitId: 'h',
        day: checklistDay(DateTime.now()),
        targetMinutes: 5,
        baseSeconds: 300);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: FocusHud(
      session: session,
      title: 'Read',
      motion: false,
      onCheckpoint: () async {},
      onFinish: () async => throw StateError('disk failure'),
      onExit: () async {},
      onTarget: () => fail('Do not replay the target cue on recovery'),
    ))));
    await tester.pump();
    final reset = find.byKey(const ValueKey('focus-reset'));
    expect(reset, findsOneWidget);
    expect(tester.widget<IconButton>(reset).onPressed, isNull);
    await tester.tap(find.byKey(const ValueKey('focus-finish')));
    await tester.pumpAndSettle();
    expect(find.text('Progress could not be saved. Please retry.'),
        findsOneWidget);
    expect(tester.widget<IconButton>(reset).onPressed, isNull);
    expect(session.totalSeconds, 300);
    expect(
        tester
            .widget<OutlinedButton>(find.byKey(const ValueKey('focus-finish')))
            .onPressed,
        isNotNull);
    await tester.pumpWidget(const SizedBox());
    session.dispose();
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('milestones show six real trees in one row at 320 dp / $scale',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!),
          home: Scaffold(
              body: ChecklistSurface(
                  child: GardenMilestones(
                      xp: 180,
                      treeImages: GardenPackRegistry.packs.first.trees)))));
      await tester.pumpAndSettle();
      final tops = <double>[];
      for (var i = 0; i < 6; i++) {
        final tree = find.byKey(ValueKey('milestone-tree-$i'));
        expect(tester.widget<Image>(tree).image,
            AssetImage(GardenPackRegistry.packs.first.trees[i]));
        tops.add(tester.getTopLeft(tree).dy);
      }
      expect(tops.toSet().length, 1);
      final current =
          tester.getRect(find.byKey(const ValueKey('milestone-stage-4')));
      expect(current.left, greaterThanOrEqualTo(0));
      expect(current.right, lessThanOrEqualTo(320));
      expect(tester.takeException(), isNull);
    });
  }
}
