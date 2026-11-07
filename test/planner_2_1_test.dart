import 'dart:convert';
import 'package:betterseed/checklist/checklist_data.dart';
import 'package:betterseed/checklist/habit_editor.dart';
import 'package:betterseed/checklist/planner_status.dart';
import 'package:betterseed/checklist/checklist_pickers.dart';
import 'package:betterseed/data/habit.dart';
import 'package:betterseed/backup/backup_snapshot.dart';
import 'package:betterseed/logic/water_progress.dart';
import 'package:betterseed/focus/focus_session.dart';
import 'package:betterseed/statistics/planner_insights.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final now = DateTime(2026, 11, 6, 12);
  for (final type in ['checkbox', 'count', 'duration']) {
    testWidgets('new $type is recorded with its chosen first-day plan',
        (tester) async {
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
                                    creating: true,
                                    masterEnabled: false,
                                    onEnableMaster: () async => false)));
                      },
                      child: const Text('New'))))));
      await tester.tap(find.text('New'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Read carefully');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('goal-type-$type')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save habit'));
      await tester.pumpAndSettle();
      expect(result, isNotNull);
      final restored = Habit.fromJson(jsonDecode(jsonEncode(result!.toJson())));
      expect(restored.checklist!.plan.type, type);
      expect(restored.checklist!.today(DateTime.now()).plan.type, type);
      expect(restored.checklist!.today(DateTime.now()).value, 0);
      if (type == 'count') expect(restored.checklist!.plan.unit, 'count');
      expect(tester.takeException(), isNull);
    });
  }
  test(
      'activity and saved focus seconds survive backup independently of reminders',
      () {
    var d = ChecklistData(
        start: checklistDay(now),
        plan: const HabitPlan(
            type: 'duration', target: 15, activityMinute: 1140));
    d = d.record(now, d.today(now).change(value: 5, focusSeconds: 359));
    final h = Habit(
        id: 'focus',
        title: 'Read',
        checklist: d,
        reminderEnabled: false,
        reminderLeadMinutes: 30);
    final backup = BackupSnapshot(
        habits: [h],
        progress: WaterProgress(),
        day: checklistDay(now),
        packId: 'default',
        ownedMoonlight: false,
        savedAtUtc: now);
    expect(backup.toJson()['version'], 3);
    final restored = BackupSnapshot.decode(backup.encode()).habits.single;
    expect(restored.reminderEnabled, false);
    expect(restored.reminderLeadMinutes, 30);
    expect(restored.checklist!.today(now).plan.activityMinute, 1140);
    expect(restored.checklist!.today(now).durationSeconds, 359);
    expect(restored.checklist!.today(now).done, false);
    final edited = restored.checklist!.edit(
        const HabitPlan(
            type: 'count', target: 8, unit: 'count', activityMinute: 420),
        now);
    expect(ChecklistData.fromJson(edited.toJson()).today(now).plan.type,
        'duration');
    expect(edited.today(DateTime(2026, 11, 7)).plan.type, 'count');
    expect(edited.records[checklistDay(now)]!.plan.activityMinute, 1140);
  });
  test('sub-minute duration remains partial in historic records', () {
    final record = HabitRecord.fromJson({
      'plan': const HabitPlan(type: 'duration', target: 1).toJson(),
      'scheduled': true,
      'rest': false,
      'value': 0,
      'focusSeconds': 59,
    });
    expect(record.done, false);
    expect(record.status, 'Partial');
    expect(record.durationSeconds, 59);
  });
  test('time status never fails a habit merely for passing its clock', () {
    const record =
        HabitRecord(plan: HabitPlan(activityMinute: 1140), scheduled: true);
    expect(plannerStatus(record, now, DateTime(2026, 11, 6, 18, 30)).label,
        'In {p0} min');
    expect(
        plannerStatus(record, now, DateTime(2026, 11, 6, 18, 30))
            .arguments['p0'],
        30);
    expect(plannerStatus(record, now, DateTime(2026, 11, 6, 19)).label,
        'Time to start');
    expect(plannerStatus(record, now, DateTime(2026, 11, 6, 20)).label,
        'Past scheduled time');
    expect(plannerStatus(record.change(rest: true), now, now).label, 'Rest');
    expect(plannerStatus(record.change(value: 1), now, now).label, 'Done');
    expect(
        plannerStatus(
                const HabitRecord(plan: HabitPlan(), scheduled: true), now, now)
            .label,
        'Not completed');
  });
  test(
      'monotonic timer start pause resume and recover do not count stopped time',
      () {
    var ms = 0;
    final session = FocusSession(
        habitId: 'h',
        day: '2026-11-06',
        targetMinutes: 2,
        baseSeconds: 30,
        monotonicMilliseconds: () => ms);
    session.start();
    ms += 60000;
    expect(session.elapsedSeconds, 60);
    session.pause();
    ms += 900000;
    expect(session.elapsedSeconds, 60);
    session.start();
    ms += 30500;
    expect(session.reachedTarget, true);
    final restored = FocusSession.fromJson(session.toJson(),
        monotonicMilliseconds: () => ms);
    expect(restored.running, false);
    expect(restored.elapsedMilliseconds, 90000);
    ms += 86400000;
    expect(restored.elapsedMilliseconds, 90000);
    restored.reset();
    expect(restored.totalSeconds, 120);
    expect(restored.elapsedSeconds,
        90); // reached target stays locked after recovery
    session.dispose();
    restored.dispose();
  });
  test('partial focus reset still discards only unsaved time', () {
    final session = FocusSession(
        habitId: 'h',
        day: '2026-11-07',
        targetMinutes: 5,
        baseSeconds: 60,
        elapsedMilliseconds: 90000);
    session.reset();
    expect(session.totalSeconds, 60);
    expect(session.elapsedSeconds, 0);
    expect(session.running, false);
    session.dispose();
  });
  test('checkpoint storage isolates accounts and serializes save then clear',
      () async {
    SharedPreferences.setMockInitialValues({});
    final a = FocusSessionStore('account-a'),
        b = FocusSessionStore('account-b');
    final session = FocusSession(
        habitId: 'h',
        day: '2026-11-06',
        targetMinutes: 15,
        baseSeconds: 0,
        elapsedMilliseconds: 61500);
    await a.save(session);
    expect(await b.read('h'), isNull);
    final recovered = await a.read('h');
    expect(recovered!.elapsedSeconds, 61);
    expect(recovered.running, false);
    final saving = a.save(session);
    final clearing = a.clear('h');
    await saving;
    await clearing;
    expect(await a.read('h'), isNull);
    session.dispose();
    recovered.dispose();
  });
  test(
      'statistics exclude neutral failures but preserve actual time on rest days',
      () {
    const plan = HabitPlan(type: 'duration', target: 10);
    final d = ChecklistData(
        start: '2026-11-01',
        archived: true,
        plan: plan,
        records: {
          '2026-11-01': const HabitRecord(
              plan: plan, scheduled: true, value: 10, focusSeconds: 630),
          '2026-11-02': const HabitRecord(
              plan: plan, scheduled: true, value: 4, focusSeconds: 270),
          '2026-11-03': const HabitRecord(
              plan: plan,
              scheduled: true,
              rest: true,
              value: 1,
              focusSeconds: 90),
          '2026-11-04': const HabitRecord(plan: plan, scheduled: false),
          '2026-11-08': const HabitRecord(plan: plan, scheduled: true),
        });
    final stats =
        PlannerInsights([Habit(id: 'h', title: 'Read', checklist: d)], now, 7);
    expect(stats.total.scheduled, 2);
    expect(stats.total.completed, 1);
    expect(stats.total.rate, .5);
    expect(stats.total.seconds, 990);
    expect(stats.days.containsKey('2026-11-05'), false);
    expect(stats.byHabit.single.averageMinutes, 7.5);
  });
  for (final sheet in ['goal', 'days', 'time', 'reminder', 'category']) {
    testWidgets('$sheet picker at 320 dp with text 200%', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!),
          home: Builder(
              builder: (context) => Scaffold(
                  body: FilledButton(
                      child: const Text('Open'),
                      onPressed: () {
                        switch (sheet) {
                          case 'goal':
                            NumericGoalSheet.show(context, 15);
                            break;
                          case 'days':
                            ScheduleDayPicker.show(context, {1, 2, 3});
                            break;
                          case 'time':
                            ActivityTimePicker.show(context, 420);
                            break;
                          case 'reminder':
                            ReminderPicker.show(context,
                                const ReminderChoice(true, 420, 15), 420);
                            break;
                          case 'category':
                            HabitCategoryPicker.show(context, 'Morning');
                            break;
                        }
                      })))));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 400));
    });
  }
}
