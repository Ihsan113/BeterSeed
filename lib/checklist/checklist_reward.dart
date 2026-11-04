import '../data/habit.dart';

/// A save, edit, restore, rest cancellation or legacy migration cannot itself
/// mint water. Only an actual increase crossing the effective target can do so.
/// WaterProgress remains authoritative for once-per-ID/day idempotency.
bool crossesChecklistTarget(Habit? before, Habit after, DateTime now) {
  if (before == null || after.checklist == null || after.checklist!.archived)
    return false;
  final next = after.checklist!.today(now);
  final previous = before.checklist?.today(now);
  final oldValue = previous?.value ?? (before.completed ? 1 : 0);
  final oldDone = previous?.done ?? before.completed;
  if (previous?.rest == true || oldDone || !next.done || next.value <= oldValue)
    return false;
  if (previous != null &&
      (previous.plan.type != next.plan.type ||
          previous.plan.target != next.plan.target)) return false;
  return true;
}
