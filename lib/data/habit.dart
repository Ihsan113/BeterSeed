import '../checklist/checklist_data.dart';

/// An offline habit with an optional independent daily reminder.
/// Older JSON without reminder settings safely defaults to no reminder.
class Habit {
  const Habit({
    required this.id,
    required this.title,
    this.completed = false,
    this.checklist,
    this.iconKey = 'leaf',
    this.reminderEnabled = false,
    this.reminderHour = 20,
    this.reminderMinute = 0,
    this.reminderLeadMinutes = 0,
  });

  final ChecklistData? checklist;
  final String id;
  final String title;
  final bool completed;
  final String iconKey;
  final bool reminderEnabled;
  final int reminderHour;
  final int reminderMinute;
  final int reminderLeadMinutes;
  bool get requiresPlannerV3 =>
      reminderLeadMinutes != 0 ||
      checklist?.plan.activityMinute != null ||
      checklist?.pending?.activityMinute != null ||
      (checklist?.records.values.any(
              (r) => r.plan.activityMinute != null || r.focusSeconds != null) ??
          false);

  Habit copyWith({
    ChecklistData? checklist,
    String? title,
    bool? completed,
    String? iconKey,
    bool? reminderEnabled,
    int? reminderHour,
    int? reminderMinute,
    int? reminderLeadMinutes,
  }) =>
      Habit(
        id: id,
        checklist: checklist ?? this.checklist,
        title: title ?? this.title,
        completed: completed ?? this.completed,
        iconKey: iconKey ?? this.iconKey,
        reminderEnabled: reminderEnabled ?? this.reminderEnabled,
        reminderHour: reminderHour ?? this.reminderHour,
        reminderMinute: reminderMinute ?? this.reminderMinute,
        reminderLeadMinutes: reminderLeadMinutes ?? this.reminderLeadMinutes,
      );

  Map<String, dynamic> toJson() => {
        if (checklist != null) 'checklist': checklist!.toJson(),
        'id': id,
        'title': title,
        'completed': completed,
        'iconKey': iconKey,
        'reminderEnabled': reminderEnabled,
        'reminderHour': reminderHour,
        'reminderMinute': reminderMinute,
        if (reminderLeadMinutes != 0)
          'reminderLeadMinutes': reminderLeadMinutes,
      };

  factory Habit.fromJson(Map<String, dynamic> json) => Habit(
        id: json['id'] as String,
        checklist: json['checklist'] is Map
            ? ChecklistData.fromJson(
                Map<String, dynamic>.from(json['checklist']))
            : null,
        title: json['title'] as String,
        completed: json['completed'] as bool? ?? false,
        iconKey: json['iconKey'] as String? ?? 'leaf',
        reminderEnabled: json['reminderEnabled'] == true,
        reminderLeadMinutes:
            [0, 5, 15, 30, 60].contains(json['reminderLeadMinutes'])
                ? json['reminderLeadMinutes'] as int
                : 0,
        reminderHour: ((json['reminderHour'] as num?)?.toInt() ?? 20)
            .clamp(0, 23)
            .toInt(),
        reminderMinute: ((json['reminderMinute'] as num?)?.toInt() ?? 0)
            .clamp(0, 59)
            .toInt(),
      );
}

/// Removing the final planner habit must not downgrade an existing cloud account.
int habitSnapshotVersion(Iterable<Habit> habits, {int previous = 1}) =>
    previous >= 3 || habits.any((h) => h.requiresPlannerV3)
        ? 3
        : previous >= 2 || habits.any((h) => h.checklist != null)
            ? 2
            : 1;
