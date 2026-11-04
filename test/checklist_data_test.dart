import 'package:betterseed/checklist/checklist_reward.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:betterseed/checklist/checklist_data.dart';
import 'package:betterseed/data/habit.dart';
import 'package:betterseed/logic/water_progress.dart';

void main() {
  final monday = DateTime(2026, 11, 2);
  test(
      'only increasing progress across target credits, never save or rest cancellation',
      () {
    final d = ChecklistData(
        start: '2026-11-02',
        plan: const HabitPlan(type: 'count', target: 2, unit: 'glasses'));
    final before = Habit(
        id: 'h',
        title: 'Water',
        checklist: d.record(monday, d.today(monday).change(value: 1)));
    final after = before.copyWith(
        checklist: d.record(monday, d.today(monday).change(value: 2)));
    expect(crossesChecklistTarget(before, after, monday), true);
    expect(crossesChecklistTarget(after, after, monday), false);
    expect(crossesChecklistTarget(null, after, monday), false);
    final resting = before.copyWith(
        checklist:
            d.record(monday, d.today(monday).change(value: 2, rest: true)));
    expect(crossesChecklistTarget(resting, after, monday), false);
    final legacy = const Habit(id: 'h', title: 'Water', completed: true);
    expect(crossesChecklistTarget(legacy, after, monday), false);
  });

  test('legacy JSON preserves identifiers, completion and no invented history',
      () {
    final h =
        Habit.fromJson({'id': 'read', 'title': 'Read', 'completed': true});
    expect(h.checklist, isNull);
    expect(h.completed, isTrue);
    expect(h.toJson().containsKey('checklist'), false);
  });
  test(
      'target and schedule changes preserve effective current day across restart',
      () {
    var d = ChecklistData(
        start: '2026-11-02',
        plan: const HabitPlan(type: 'count', target: 8, unit: 'glasses'));
    d = d.record(monday, d.today(monday).change(value: 4));
    d = d.edit(
        const HabitPlan(
            type: 'count', target: 2, unit: 'glasses', weekdays: [2]),
        monday);
    d = ChecklistData.fromJson(d.toJson());
    expect(d.today(monday).plan.target, 8);
    expect(d.today(monday).done, false);
    expect(d.today(DateTime(2026, 11, 3)).plan.target, 2);
    expect(d.today(DateTime(2026, 11, 4)).scheduled, false);
  });
  test('reward ledger remains authoritative after undo, recheck and restart',
      () {
    var progress = WaterProgress();
    var d = ChecklistData(
        start: '2026-11-02',
        plan: const HabitPlan(type: 'duration', target: 30));
    for (final value in [15, 30, 10, 30, 30]) {
      final r = d.today(monday).change(value: value);
      d = d.record(monday, r);
      if (r.done) progress.earnForHabit('2026-11-02', 'h');
      progress = WaterProgress.fromJson(progress.toJson());
    }
    expect(progress.totalEarned, 1);
    expect(progress.xp, 0);
  });
  test(
      'rest and unscheduled occurrences are neutral; closed missed day breaks streak',
      () {
    var d = ChecklistData(
        start: '2026-11-02', plan: const HabitPlan(weekdays: [1, 2, 3, 4, 5]));
    d = d.record(monday, d.today(monday).change(value: 1));
    final tuesday = DateTime(2026, 11, 3);
    d = d.record(tuesday, d.today(tuesday).change(rest: true));
    expect(d.streak(tuesday), 1);
    d = d.advance(DateTime(2026, 11, 5));
    expect(d.streak(DateTime(2026, 11, 5)), 0);
    expect(d.records['2026-11-04']!.status, 'Missed');
  });
  test('retention bounds detailed records while carrying streak and milestones',
      () {
    var d = ChecklistData(start: '2026-11-02');
    for (var i = 0; i < 400; i++) {
      final date = DateTime(2026, 11, 2 + i);
      d = d.record(date, d.today(date).change(value: 1));
    }
    expect(d.records.length, 366);
    expect(d.streak(DateTime(2026, 11, 401)), 400);
    expect(
        ChecklistData.fromJson(d.toJson())
            .streak(DateTime(2026, 11, 401), best: true),
        400);
  });
  test('archived habits keep records and never schedule again', () {
    var d = ChecklistData(start: '2026-11-02');
    d = d.record(monday, d.today(monday).change(value: 1)).copy(archived: true);
    expect(d.records['2026-11-02']!.done, true);
    expect(d.today(DateTime(2026, 11, 3)).scheduled, false);
  });
}
