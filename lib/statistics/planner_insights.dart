import '../checklist/checklist_data.dart';
import '../data/habit.dart';

class InsightDay {
  int scheduled = 0, completed = 0, seconds = 0, scheduledSeconds = 0;
  double? get rate => scheduled == 0 ? null : completed / scheduled;
  void include(HabitRecord record) {
    // A rest day is neutral for completion, but previously recorded activity
    // on that date is still real time and must remain in duration totals.
    seconds += record.durationSeconds;
    if (!record.scheduled || record.rest) return;
    scheduledSeconds += record.durationSeconds;
    scheduled++;
    if (record.done) completed++;
  }
}

class HabitInsight {
  HabitInsight(this.habit);
  final Habit habit;
  final total = InsightDay();
  final Map<String, InsightDay> days = {};
  double get averageMinutes =>
      total.scheduled == 0 ? 0 : total.scheduledSeconds / 60 / total.scheduled;
}

/// Only known daily observations enter denominators. Ledger credits are not
/// completions and missing/retired records are never expanded into failures.
class PlannerInsights {
  PlannerInsights(List<Habit> habits, this.now, this.period) {
    final today = checklistDay(now);
    final start =
        checklistDay(DateTime(now.year, now.month, now.day - period + 1));
    for (final habit in habits) {
      final data = habit.checklist;
      if (data == null) continue;
      final insight = HabitInsight(habit);
      final records = {...data.records};
      if (!data.archived) records.putIfAbsent(today, () => data.today(now));
      for (final entry in records.entries) {
        if (entry.key.compareTo(today) > 0 || entry.key.compareTo(start) < 0)
          continue;
        final record = entry.value;
        insight.total.include(record);
        total.include(record);
        if (!record.scheduled || record.rest) continue;
        insight.days.putIfAbsent(entry.key, InsightDay.new).include(record);
        days.putIfAbsent(entry.key, InsightDay.new).include(record);
        categories.putIfAbsent(data.category, InsightDay.new).include(record);
        weekdays
            .putIfAbsent(DateTime.parse(entry.key).weekday, InsightDay.new)
            .include(record);
      }
      if (!data.archived ||
          insight.total.scheduled > 0 ||
          insight.total.seconds > 0) byHabit.add(insight);
      final current = data.streak(now), best = data.streak(now, best: true);
      if (!data.archived && current > activeStreak) activeStreak = current;
      if (best > bestStreak) bestStreak = best;
    }
  }
  final DateTime now;
  final int period;
  final total = InsightDay();
  final Map<String, InsightDay> days = {}, categories = {};
  final Map<int, InsightDay> weekdays = {};
  final List<HabitInsight> byHabit = [];
  int activeStreak = 0, bestStreak = 0;
  List<DateTime> get dates => List.generate(
      period, (i) => DateTime(now.year, now.month, now.day - period + 1 + i));
}
