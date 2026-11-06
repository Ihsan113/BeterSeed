import 'checklist_data.dart';

class PlannerStatus {
  const PlannerStatus(this.label, [this.arguments = const {}]);
  final String label;
  final Map<String, Object?> arguments;
}

PlannerStatus plannerStatus(HabitRecord? record, DateTime date, DateTime now,
    {bool running = false}) {
  if (record == null) return const PlannerStatus('Unknown');
  if (!record.scheduled) return const PlannerStatus('Not scheduled');
  if (record.rest) return const PlannerStatus('Rest');
  if (record.done) return const PlannerStatus('Done');
  if (running) return const PlannerStatus('In progress');
  if (checklistDay(date) != checklistDay(now))
    return PlannerStatus(record.status);
  final minute = record.plan.activityMinute;
  if (minute == null)
    return PlannerStatus(record.value > 0 || record.durationSeconds > 0
        ? 'Partial'
        : 'Not completed');
  final activity =
      DateTime(now.year, now.month, now.day, minute ~/ 60, minute % 60);
  final seconds = activity.difference(now).inSeconds;
  if (seconds > 3600) return const PlannerStatus('Scheduled at {p0}');
  if (seconds > 0)
    return PlannerStatus('In {p0} min', {'p0': (seconds / 60).ceil()});
  if (seconds >= -900) return const PlannerStatus('Time to start');
  return const PlannerStatus('Past scheduled time');
}
