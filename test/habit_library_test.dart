import 'dart:async';
import 'dart:convert';
import 'package:betterseed/backup/backup_snapshot.dart';
import 'package:betterseed/checklist/checklist_data.dart';
import 'package:betterseed/checklist/checklist_reward.dart';
import 'package:betterseed/checklist/checklist_style.dart';
import 'package:betterseed/checklist/habit_library.dart';
import 'package:betterseed/checklist/habit_manager_page.dart';
import 'package:betterseed/logic/water_progress.dart';
import 'package:betterseed/data/habit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Habit fixture(String id,
    {bool archived = false,
    String category = 'Morning',
    HabitPlan plan = const HabitPlan(),
    int order = 0,
    int value = 0}) {
  final now = DateTime.now();
  var data = ChecklistData(
      start: checklistDay(now),
      plan: plan,
      category: category,
      order: order,
      archived: archived);
  data = data.record(now, data.today(now).change(value: value));
  return Habit(id: id, title: id, checklist: data, reminderEnabled: true);
}

Future<void> mount(WidgetTester tester, ValueNotifier<List<Habit>> source,
    {Future<void> Function(List<Habit>)? save,
    String Function()? scope,
    double scale = 1}) async {
  await tester.pumpWidget(MaterialApp(
    builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!),
    home: HabitManagerPage(
        habits: source,
        onChanged: save ??
            (next) async {
              source.value = next;
            },
        masterEnabled: () => false,
        onEnableMaster: () async => false,
        scope: scope ?? () => 'guest'),
  ));
  await tester.pumpAndSettle();
}

Future<void> tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Finder key(String s) => find.byKey(ValueKey(s));

void main() {
  final now = DateTime.now();
  test(
      'global query includes archived/off-day, filters intersect and sorts are stable',
      () {
    final all = [
      fixture('zeta', order: 1),
      fixture('Alpha',
          archived: true,
          category: 'Evening',
          order: 1,
          plan: const HabitPlan(weekdays: [7], activityMinute: 1140)),
      fixture('beta', order: 0, plan: const HabitPlan(activityMinute: 420))
    ];
    expect(libraryHabits(all, now).map((h) => h.id), ['beta', 'zeta', 'Alpha']);
    expect(
        libraryHabits(all, now,
                query: ' ALP ',
                category: 'Evening',
                weekday: 7,
                status: LibraryStatus.archived)
            .single
            .id,
        'Alpha');
    expect(libraryHabits(all, now, weekday: 1, status: LibraryStatus.archived),
        isEmpty);
    expect(libraryHabits(all, now, sort: LibrarySort.name).map((h) => h.id),
        ['Alpha', 'beta', 'zeta']);
    expect(libraryHabits(all, now, sort: LibrarySort.time).map((h) => h.id),
        ['beta', 'Alpha', 'zeta']);
  });
  test('legacy completion survives management normalization', () {
    const h = Habit(id: 'legacy', title: 'Legacy', completed: true);
    expect(libraryData(h, now).today(now).done, true);
    expect(archiveLibraryHabit(h, now, true).checklist!.today(now).value, 1);
  });
  test(
      'restore preserves partial seconds and leaves archived dates unavailable',
      () {
    final past = DateTime(now.year, now.month, now.day - 5);
    var data = ChecklistData(
        start: checklistDay(past),
        plan:
            const HabitPlan(type: 'duration', target: 10, activityMinute: 420));
    data =
        data.record(past, data.today(past).change(value: 3, focusSeconds: 219));
    final original = Habit(id: 'h', title: 'Read', checklist: data);
    final archived = archiveLibraryHabit(original, past, true);
    final restored = archiveLibraryHabit(archived, now, false);
    expect(restored.checklist!.records.length, 2);
    expect(
        restored.checklist!.records[checklistDay(past)]!.durationSeconds, 219);
    expect(restored.checklist!.today(now).scheduled, true);
    expect(restored.checklist!.advance(now).records.length, 2);
    expect(crossesChecklistTarget(archived, restored, now), false);
    final sameDay = archiveLibraryHabit(archived, past, false);
    expect(sameDay.checklist!.today(past).durationSeconds, 219);
  });
  test(
      'schedule/order/archive survive backup v3 without changing history or reward',
      () {
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    const plan = HabitPlan(type: 'duration', target: 10, activityMinute: 420);
    var d = ChecklistData(start: checklistDay(yesterday), plan: plan);
    d = d.record(
        yesterday, d.today(yesterday).change(value: 7, focusSeconds: 459));
    d = d.record(now, d.today(now).change(value: 3, focusSeconds: 199));
    final before =
        Habit(id: 'read', title: 'Read', checklist: d, reminderLeadMinutes: 15);
    final after = scheduleLibraryHabit(before, {now.weekday}, now);
    final updated = orderLibraryHabits(
        [archiveLibraryHabit(after, now, true), fixture('other')],
        ['other', 'read'],
        now);
    final water = WaterProgress()
      ..earnForHabit(checklistDay(yesterday), 'read');
    final backup = BackupSnapshot(
        habits: updated,
        progress: water,
        day: checklistDay(now),
        packId: 'default',
        ownedMoonlight: false,
        savedAtUtc: now);
    final restored = BackupSnapshot.decode(backup.encode());
    final h = restored.habits.first;
    expect(backup.toJson()['version'], 3);
    expect(h.checklist!.archived, true);
    expect(h.checklist!.order, 1);
    expect(h.checklist!.today(now).durationSeconds, 199);
    expect(h.checklist!.plan.activityMinute, 420);
    expect(h.checklist!.plan.weekdays, [now.weekday]);
    expect(h.checklist!.records[checklistDay(yesterday)]!.toJson(),
        d.records[checklistDay(yesterday)]!.toJson());
    expect(restored.progress.toJson(), water.toJson());
    expect(crossesChecklistTarget(before, after, now), false);
    expect(() => scheduleLibraryHabit(before, {}, now), throwsArgumentError);
  });
  test(
      'ordering refuses stale membership and preserves latest count and historical unit',
      () {
    final a = fixture('a',
        value: 4,
        plan: const HabitPlan(type: 'count', target: 8, unit: 'glasses'));
    final list = [a, fixture('b')];
    expect(() => orderLibraryHabits(list, ['a'], now), throwsStateError);
    expect(() => orderLibraryHabits(list, ['a', 'a'], now), throwsStateError);
    final ordered = orderLibraryHabits(list, ['b', 'a'], now);
    expect(ordered.first.checklist!.today(now).value, 4);
    expect(ordered.first.checklist!.plan.unit, 'glasses');
    expect(libraryHabits(ordered, now).first.id, 'b');
    final rescheduled = scheduleLibraryHabit(a, {1, 7}, now);
    expect(rescheduled.checklist!.plan.unit, 'glasses');
    expect(rescheduled.checklist!.today(now).value, 4);
  });

  testWidgets(
      'search, active/archive filters, select results and archive/restore with confirmation',
      (tester) async {
    final source = ValueNotifier(
        [fixture('Read'), fixture('Run', archived: true), fixture('Water')]);
    await mount(tester, source);
    expect(find.text('3 habits'), findsOneWidget);
    await tap(tester, key('library-status-archived'));
    expect(find.text('1 habits'), findsOneWidget);
    await tap(tester, key('library-actions-Run'));
    await tap(tester, find.text('Restore habits'));
    await tap(tester, find.text('Apply'));
    expect(source.value[1].checklist!.archived, false);
    await tap(tester, key('library-status-all'));
    await tester.enterText(key('library-search'), 'Rea');
    await tester.pumpAndSettle();
    await tap(tester, key('library-selection-mode'));
    await tap(tester, key('library-select-visible'));
    await tap(tester, key('library-bulk-actions'));
    await tap(tester, find.text('Archive habits'));
    await tap(tester, find.text('Cancel'));
    expect(source.value.first.checklist!.archived, false);
    await tap(tester, key('library-bulk-actions'));
    await tap(tester, find.text('Archive habits'));
    await tap(tester, find.text('Apply'));
    expect(source.value.first.checklist!.archived, true);
    expect(source.value.skip(1).every((h) => !h.checklist!.archived), true);
    expect(tester.takeException(), isNull);
  });

  for (final action in ['Category', 'Activity days', 'Turn off reminders']) {
    testWidgets('bulk $action applies only selected IDs and preserves progress',
        (tester) async {
      final source = ValueNotifier([
        fixture('Read',
            value: 3,
            plan: const HabitPlan(
                type: 'duration', target: 10, activityMinute: 420)),
        fixture('Water')
      ]);
      final other = jsonEncode(source.value[1].toJson());
      await mount(tester, source);
      await tap(tester, key('library-selection-mode'));
      await tap(tester, key('library-select-Read'));
      await tap(tester, key('library-bulk-actions'));
      await tap(tester, find.text(action));
      if (action == 'Category') {
        await tap(tester, find.text('Evening'));
        await tap(tester, find.text('Save'));
      } else if (action == 'Activity days') {
        await tap(tester, find.text('Weekends'));
        await tap(tester, find.text('Save'));
      }
      await tap(tester, find.text('Apply'));
      expect(jsonEncode(source.value[1].toJson()), other);
      final first = source.value.first;
      expect(first.checklist!.today(now).value, 3);
      expect(first.checklist!.plan.activityMinute, 420);
      if (action == 'Category') expect(first.checklist!.category, 'Evening');
      if (action == 'Activity days')
        expect(first.checklist!.plan.weekdays, [6, 7]);
      if (action == 'Turn off reminders') expect(first.reminderEnabled, false);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'changing filters clears hidden selection; category/day filters combine',
      (tester) async {
    final source = ValueNotifier([
      fixture('Read'),
      fixture('Weekend',
          category: 'Evening', plan: const HabitPlan(weekdays: [6, 7]))
    ]);
    await mount(tester, source);
    await tap(tester, key('library-selection-mode'));
    await tap(tester, key('library-select-visible'));
    await tap(tester, key('library-filters'));
    expect(
        DefaultTextStyle.of(tester.element(find.text('Filter habits')))
            .style
            .color,
        checklistText);
    await tap(tester, find.text('Evening').last);
    await tap(tester, find.text('Sat'));
    await tap(tester, find.text('Save'));
    expect(find.text('1 habits'), findsOneWidget);
    expect(key('library-bulk-actions'), findsNothing);
    await tap(tester, key('library-selection-mode'));
    final button = tester.widget<FilledButton>(key('library-bulk-actions'));
    expect(button.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('editor saves new type and rejects stale concurrent edit',
      (tester) async {
    final source = ValueNotifier([fixture('Read')]);
    await mount(tester, source);
    await tap(tester, find.text('Read'));
    await tap(tester, find.text('Continue'));
    await tap(tester, key('goal-type-duration'));
    await tap(tester, find.text('Save habit'));
    expect(source.value.single.checklist!.plan.type, 'duration');
    await tap(tester, find.text('Read'));
    source.value = [source.value.single.copyWith(title: 'Remote update')];
    await tester.pumpAndSettle();
    await tap(tester, find.text('Continue'));
    await tap(tester, find.text('Save habit'));
    expect(source.value.single.title, 'Remote update');
    expect(find.text('This habit changed. Reopen it before editing.'),
        findsOneWidget);
  });

  testWidgets(
      'failed save reports failure, busy blocks back, scope change blocks writes',
      (tester) async {
    final source = ValueNotifier([fixture('Read')]);
    final pending = Completer<void>();
    var calls = 0, owner = 'first';
    await mount(tester, source,
        scope: () => owner,
        save: (_) {
          calls++;
          return pending.future;
        });
    await tap(tester, key('library-actions-Read'));
    await tap(tester, find.text('Archive habits'));
    await tester.tap(find.text('Apply'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final scope =
        tester.widget<PopScope>(find.byWidgetPredicate((w) => w is PopScope));
    expect(scope.canPop, false);
    pending.completeError(StateError('disk failure'));
    await tester.pumpAndSettle();
    expect(find.text('Changes saved'), findsNothing);
    expect(find.text('Changes could not be saved. Please try again.'),
        findsOneWidget);
    owner = 'other';
    source.value = List.of(source.value);
    await tester.pumpAndSettle();
    expect(find.text('Account changed. Reopen All habits.'), findsOneWidget);
    expect(calls, 1);
  });

  testWidgets(
      'reorder saves explicit order; collection change cancels stale draft',
      (tester) async {
    final source = ValueNotifier([fixture('Alpha'), fixture('Beta')]);
    await mount(tester, source);
    await tap(tester, key('library-sort'));
    await tap(tester, find.text('Reorder habits'));
    final start = tester.getCenter(key('library-drag-Alpha'));
    final destination = tester.getCenter(key('library-drag-Beta'));
    final gesture = await tester.startGesture(start);
    await tester.pump();
    // Continuous pointer samples cross the insertion zones like a real drag.
    for (var step = 1; step <= 12; step++) {
      await gesture.moveTo(
          Offset.lerp(start, destination + const Offset(0, 122), step / 12)!);
      await tester.pump(const Duration(milliseconds: 30));
    }
    await gesture.up();
    await tester.pumpAndSettle();
    expect(source.value.first.checklist!.order, 0); // still an unsaved draft

    await tap(tester, find.text('Save order'));
    expect(libraryHabits(source.value, now).first.id, 'Beta');
    await tap(tester, key('library-sort'));
    await tap(tester, find.text('Reorder habits'));
    source.value = [...source.value, fixture('Added')];
    await tester.pumpAndSettle();
    expect(find.text('Save order'), findsNothing);
    expect(source.value.length, 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'small display at 200% supports search keyboard, filters and bulk confirmation',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    final source =
        ValueNotifier([fixture('A long but readable habit name for testing')]);
    await mount(tester, source, scale: 2);
    await tester.enterText(key('library-search'), 'readable');
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    tester.view.viewInsets = const FakeViewPadding();
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tap(tester, key('library-filters'));
    await tap(tester, find.text('Save'));
    expect(tester.takeException(), isNull);
    await tap(tester, key('library-selection-mode'));
    await tester.scrollUntilVisible(key('library-select-visible'), 120,
        scrollable: find.byType(Scrollable).first);
    await tap(tester, key('library-select-visible'));
    await tap(tester, key('library-bulk-actions'));
    await tap(tester, find.text('Archive habits'));
    await tap(tester, find.text('Apply'));
    expect(source.value.single.checklist!.archived, true);
    expect(tester.takeException(), isNull);
  });
}
