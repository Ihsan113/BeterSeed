import '../data/habit.dart';
import 'checklist_data.dart';

enum LibraryStatus { all, active, archived }

enum LibrarySort { manual, name, time }

ChecklistData libraryData(Habit habit, DateTime now) {
  if (habit.checklist != null) return habit.checklist!;
  final data = ChecklistData(start: checklistDay(now));
  return data.record(
      now, data.today(now).change(value: habit.completed ? 1 : 0));
}

List<Habit> libraryHabits(
  List<Habit> habits,
  DateTime now, {
  String query = '',
  String? category,
  int? weekday,
  LibraryStatus status = LibraryStatus.all,
  LibrarySort sort = LibrarySort.manual,
}) {
  final needle = query.trim().toLowerCase();
  final positions = {for (var i = 0; i < habits.length; i++) habits[i].id: i};
  final result = habits.where((h) {
    final d = libraryData(h, now);
    return (needle.isEmpty || h.title.toLowerCase().contains(needle)) &&
        (category == null || d.category == category) &&
        (weekday == null ||
            d.planOn(checklistDay(now)).weekdays.contains(weekday)) &&
        (status == LibraryStatus.all ||
            (status == LibraryStatus.archived) == d.archived);
  }).toList();
  result.sort((a, b) {
    final da = libraryData(a, now), db = libraryData(b, now);
    final comparison = switch (sort) {
      LibrarySort.manual => da.order.compareTo(db.order),
      LibrarySort.name =>
        a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      LibrarySort.time => (da.planOn(checklistDay(now)).activityMinute ?? 1440)
          .compareTo(db.planOn(checklistDay(now)).activityMinute ?? 1440),
    };
    return comparison != 0
        ? comparison
        : positions[a.id]!.compareTo(positions[b.id]!);
  });
  return result;
}

Habit archiveLibraryHabit(Habit habit, DateTime now, bool archived) {
  final original = libraryData(habit, now);
  if (original.archived == archived) return habit;
  if (archived)
    return habit.copyWith(
        checklist: original.advance(now).copy(archived: true));
  // Insert today's occurrence BEFORE advance. Archived gaps are unknown/neutral,
  // not missed active days. Retain existing same-day work and frozen old plans.
  final day = checklistDay(now);
  final existing = original.records[day];
  final plan = existing?.plan ?? original.planOn(day);
  final record = HabitRecord(
      plan: plan,
      scheduled: day.compareTo(original.start) >= 0 &&
          plan.weekdays.contains(now.weekday),
      rest: existing?.rest ?? false,
      value: existing?.value ?? 0,
      focusSeconds: existing?.focusSeconds);
  final data = original.copy(archived: false).record(now, record);
  return habit.copyWith(checklist: data, completed: record.done);
}

Habit scheduleLibraryHabit(Habit habit, Set<int> weekdays, DateTime now) {
  if (weekdays.isEmpty || weekdays.any((day) => day < 1 || day > 7)) {
    throw ArgumentError('Invalid weekdays');
  }
  final data = libraryData(habit, now).advance(now);
  final p = data.today(now).plan;
  final next = data.editToday(
      HabitPlan(
          type: p.type,
          target: p.target,
          unit: p.unit,
          activityMinute: p.activityMinute,
          weekdays: weekdays.toList()..sort()),
      now);
  return habit.copyWith(checklist: next, completed: next.today(now).done);
}

List<Habit> orderLibraryHabits(
    List<Habit> latest, List<String> ids, DateTime now) {
  if (ids.length != latest.length ||
      ids.toSet().length != ids.length ||
      !ids.toSet().containsAll(latest.map((h) => h.id))) {
    throw StateError('Habit collection changed');
  }
  final order = {for (var i = 0; i < ids.length; i++) ids[i]: i};
  // Keep input membership and the freshest records; change only persisted order.
  return [
    for (final h in latest)
      h.copyWith(checklist: libraryData(h, now).copy(order: order[h.id]))
  ];
}
