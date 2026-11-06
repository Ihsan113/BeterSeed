/// Versioned checklist metadata travels inside its owning habit in local,
/// backup and cloud storage. Dates are local calendar dates, never UTC offsets.
String checklistDay(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class HabitPlan {
  const HabitPlan(
      {this.type = 'checkbox',
      this.target = 1,
      this.unit = '',
      this.activityMinute,
      this.weekdays = const [1, 2, 3, 4, 5, 6, 7]});
  final String type, unit;
  final int target;
  final int? activityMinute;
  final List<int> weekdays;
  Map<String, dynamic> toJson() => {
        'type': type,
        'target': target,
        'unit': unit,
        'weekdays': weekdays,
        if (activityMinute != null) 'activityMinute': activityMinute
      };
  factory HabitPlan.fromJson(Map<String, dynamic> j) {
    final type = j['type'];
    final target = j['target'];
    final days = (j['weekdays'] as List).cast<int>();
    if (!['checkbox', 'count', 'duration'].contains(type) ||
        target is! int ||
        target < 1 ||
        target > 100000 ||
        (j['activityMinute'] != null &&
            (j['activityMinute'] is! int ||
                j['activityMinute'] < 0 ||
                j['activityMinute'] > 1439)) ||
        (type == 'checkbox' && target != 1) ||
        j['unit'] is! String ||
        (j['unit'] as String).length > 40 ||
        (type == 'count' && (j['unit'] as String).trim().isEmpty) ||
        days.isEmpty ||
        days.length > 7 ||
        days.toSet().length != days.length ||
        days.any((d) => d < 1 || d > 7))
      throw const FormatException('Invalid habit plan');
    return HabitPlan(
        type: type,
        target: target,
        unit: j['unit'] as String,
        weekdays: days,
        activityMinute: j['activityMinute'] as int?);
  }
}

class HabitRecord {
  const HabitRecord(
      {required this.plan,
      required this.scheduled,
      this.value = 0,
      this.focusSeconds,
      this.rest = false});
  final HabitPlan plan;
  final bool scheduled, rest;
  final int value;
  final int? focusSeconds;
  int get durationSeconds =>
      plan.type == 'duration' ? (focusSeconds ?? value * 60) : 0;
  bool get done => scheduled && !rest && value >= plan.target;
  String get status => !scheduled
      ? 'Not scheduled'
      : rest
          ? 'Rest'
          : done
              ? 'Done'
              : value > 0 || durationSeconds > 0
                  ? 'Partial'
                  : 'Missed';
  HabitRecord change({int? value, bool? rest, int? focusSeconds}) =>
      HabitRecord(
          plan: plan,
          scheduled: scheduled,
          value: value ?? this.value,
          focusSeconds: focusSeconds ??
              (value != null && this.focusSeconds != null
                  ? value * 60
                  : this.focusSeconds),
          rest: rest ?? this.rest);
  Map<String, dynamic> toJson() => {
        'plan': plan.toJson(),
        'scheduled': scheduled,
        'value': value,
        'rest': rest,
        if (focusSeconds != null) 'focusSeconds': focusSeconds,
      };
  factory HabitRecord.fromJson(Map<String, dynamic> j) {
    final plan = HabitPlan.fromJson(Map<String, dynamic>.from(j['plan']));
    final value = j['value'];
    final seconds = j['focusSeconds'];
    if (value is! int ||
        value < 0 ||
        value > 100000 ||
        (seconds != null &&
            (seconds is! int ||
                seconds < 0 ||
                seconds > 6000000 ||
                plan.type != 'duration' ||
                value != seconds ~/ 60))) {
      throw const FormatException('Invalid habit progress');
    }
    return HabitRecord(
        plan: plan,
        scheduled: j['scheduled'] == true,
        value: value,
        focusSeconds: seconds as int?,
        rest: j['rest'] == true);
  }
}

class ChecklistData {
  const ChecklistData(
      {required this.start,
      this.plan = const HabitPlan(),
      this.category = 'Morning',
      this.order = 0,
      this.archived = false,
      this.pending,
      this.effective,
      this.records = const {},
      this.carriedStreak = 0,
      this.bestStreak = 0});
  final String start, category;
  final HabitPlan plan;
  final HabitPlan? pending;
  final String? effective;
  final int order, carriedStreak, bestStreak;
  final bool archived;
  final Map<String, HabitRecord> records;
  HabitPlan planOn(String day) =>
      pending != null && effective != null && day.compareTo(effective!) >= 0
          ? pending!
          : plan;
  HabitRecord today(DateTime now) {
    final day = checklistDay(now);
    final p = planOn(day);
    return records[day] ??
        HabitRecord(
            plan: p,
            scheduled: !archived &&
                day.compareTo(start) >= 0 &&
                p.weekdays.contains(now.weekday));
  }

  ChecklistData advance(DateTime now) {
    if (archived) return this;
    final end = checklistDay(now);
    final keys = records.keys.toList()..sort();
    var cursor = DateTime.parse(keys.isEmpty ? start : keys.last);
    if (checklistDay(cursor).compareTo(end) > 0) return this;
    var result = this;
    // A long absence includes missed scheduled occurrences. Bound work while
    // keeping the historical maximum and a broken current streak.
    if (now.difference(cursor).inDays > 367) {
      result = copy(
          carriedStreak: 0, bestStreak: streak(now, best: true), records: {});
      cursor = DateTime(now.year, now.month, now.day - 366);
    }
    while (checklistDay(cursor).compareTo(end) <= 0) {
      result = result.record(cursor, result.today(cursor));
      cursor = DateTime(cursor.year, cursor.month, cursor.day + 1);
    }
    final current = result.today(now);
    // Repair old over-target counts only for today; historic records stay intact.
    return result.record(
        now,
        current.plan.type == 'count' && current.value > current.plan.target
            ? current.change(value: current.plan.target)
            : current);
  }

  ChecklistData copy(
          {HabitPlan? plan,
          HabitPlan? pending,
          String? effective,
          String? category,
          int? order,
          bool? archived,
          Map<String, HabitRecord>? records,
          int? carriedStreak,
          int? bestStreak}) =>
      ChecklistData(
          start: start,
          plan: plan ?? this.plan,
          pending: pending ?? this.pending,
          effective: effective ?? this.effective,
          category: category ?? this.category,
          order: order ?? this.order,
          archived: archived ?? this.archived,
          records: records ?? this.records,
          carriedStreak: carriedStreak ?? this.carriedStreak,
          bestStreak: bestStreak ?? this.bestStreak);
  ChecklistData edit(HabitPlan next, DateTime now) => copy(
      plan: planOn(checklistDay(now)),
      pending: next,
      effective: checklistDay(DateTime(now.year, now.month, now.day + 1)),
      records: {...records, checklistDay(now): today(now)});

  /// Editor changes apply to the selected occurrence today and future plans.
  /// Different goal types have incompatible units; only today's value resets.
  /// Earlier records and legacy pending plans remain readable without migration.
  ChecklistData editToday(HabitPlan next, DateTime now) {
    final current = today(now);
    final compatible = current.plan.type == next.type;
    final value = compatible
        ? (next.type == 'count'
            ? current.value.clamp(0, next.target)
            : current.value)
        : 0;
    return ChecklistData(
        start: start,
        plan: next,
        category: category,
        order: order,
        archived: archived,
        carriedStreak: carriedStreak,
        bestStreak: bestStreak,
        records: {
          ...records,
          checklistDay(now): HabitRecord(
              plan: next,
              scheduled: !archived &&
                  checklistDay(now).compareTo(start) >= 0 &&
                  next.weekdays.contains(now.weekday),
              rest: current.rest,
              value: value,
              focusSeconds: compatible ? current.focusSeconds : null)
        });
  }

  ChecklistData record(DateTime now, HabitRecord record) {
    final all = {...records, checklistDay(now): record};
    final cutoff = checklistDay(DateTime(now.year, now.month, now.day - 365));
    var carried = carriedStreak;
    var best = bestStreak;
    for (final key in (all.keys.toList()..sort())) {
      if (key.compareTo(cutoff) >= 0) break;
      final r = all.remove(key)!;
      if (r.scheduled && !r.rest) carried = r.done ? carried + 1 : 0;
      if (carried > best) best = carried;
    }
    final next = copy(records: all, carriedStreak: carried, bestStreak: best);
    return next.copy(bestStreak: next.streak(now, best: true));
  }

  int streak(DateTime now, {bool best = false}) {
    var current = carriedStreak;
    var maximum = bestStreak;
    final todayKey = checklistDay(now);
    for (final key in (records.keys.toList()..sort())) {
      final r = records[key]!;
      if (key.compareTo(todayKey) > 0) continue;
      if (r.scheduled && !r.rest) {
        if (r.done) {
          current++;
        } else if (key != todayKey) {
          current = 0;
        }
      }
      if (current > maximum) maximum = current;
    }
    return best ? maximum : current;
  }

  Map<String, dynamic> toJson() => {
        'start': start,
        'plan': plan.toJson(),
        'category': category,
        'order': order,
        'archived': archived,
        'pending': pending?.toJson(),
        'effective': effective,
        'records': records.map((k, v) => MapEntry(k, v.toJson())),
        'carriedStreak': carriedStreak,
        'bestStreak': bestStreak
      };
  factory ChecklistData.fromJson(Map<String, dynamic> j) => ChecklistData(
      start: j['start'],
      plan: HabitPlan.fromJson(Map<String, dynamic>.from(j['plan'])),
      category: j['category'],
      order: j['order'],
      archived: j['archived'] == true,
      pending: j['pending'] == null
          ? null
          : HabitPlan.fromJson(Map<String, dynamic>.from(j['pending'])),
      effective: j['effective'],
      records: (j['records'] as Map).map((k, v) => MapEntry(
          k as String, HabitRecord.fromJson(Map<String, dynamic>.from(v)))),
      carriedStreak: j['carriedStreak'] ?? 0,
      bestStreak: j['bestStreak'] ?? 0);
}
