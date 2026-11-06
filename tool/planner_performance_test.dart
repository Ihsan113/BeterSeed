import 'package:betterseed/checklist/checklist_data.dart';
import 'package:betterseed/data/habit.dart';
import 'package:betterseed/statistics/planner_insights.dart';
import 'package:flutter_test/flutter_test.dart';

/// CPU-only host benchmark. This is not Android GPU/battery/thermal evidence.
void main() {
  test('90-day insights over 100 habits with full retained history', () {
    final now = DateTime(2026, 11, 6);
    const plan = HabitPlan(type: 'duration', target: 15);
    final records = {
      for (var i = 0; i < 366; i++)
        checklistDay(DateTime(now.year, now.month, now.day - i)): HabitRecord(
            plan: plan,
            scheduled: true,
            value: i % 3 == 0 ? 5 : 15,
            focusSeconds: i % 3 == 0 ? 359 : 900),
    };
    final habits = List.generate(
        100,
        (i) => Habit(
            id: 'h$i',
            title: 'Read $i',
            checklist: ChecklistData(
                start: records.keys.last, plan: plan, records: records)));
    for (var i = 0; i < 5; i++) {
      PlannerInsights(habits, now, 90);
    }
    final timings = <int>[];
    for (var i = 0; i < 25; i++) {
      final clock = Stopwatch()..start();
      final insights = PlannerInsights(habits, now, 90);
      clock.stop();
      expect(insights.total.scheduled, 9000);
      expect(insights.total.completed, 6000);
      timings.add(clock.elapsedMicroseconds);
    }
    timings.sort();
    // Keep measurements visible without a flaky host-speed assertion.
    // ignore: avoid_print
    print('HOST CPU insights: 100 habits × 366 retained records; 90 days; '
        '25 samples; median ${timings[12] / 1000} ms; p95 ${timings[23] / 1000} ms');
  });
}
