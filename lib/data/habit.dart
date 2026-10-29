/// An offline habit with an optional independent daily reminder.
/// Older JSON without reminder settings safely defaults to no reminder.
class Habit {
  const Habit({
    required this.id,
    required this.title,
    this.completed = false,
    this.iconKey = 'leaf',
    this.reminderEnabled = false,
    this.reminderHour = 20,
    this.reminderMinute = 0,
  });

  final String id;
  final String title;
  final bool completed;
  final String iconKey;
  final bool reminderEnabled;
  final int reminderHour;
  final int reminderMinute;

  Habit copyWith({
    String? title,
    bool? completed,
    String? iconKey,
    bool? reminderEnabled,
    int? reminderHour,
    int? reminderMinute,
  }) => Habit(
    id: id,
    title: title ?? this.title,
    completed: completed ?? this.completed,
    iconKey: iconKey ?? this.iconKey,
    reminderEnabled: reminderEnabled ?? this.reminderEnabled,
    reminderHour: reminderHour ?? this.reminderHour,
    reminderMinute: reminderMinute ?? this.reminderMinute,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'title': title, 'completed': completed, 'iconKey': iconKey,
    'reminderEnabled': reminderEnabled,
    'reminderHour': reminderHour, 'reminderMinute': reminderMinute,
  };

  factory Habit.fromJson(Map<String, dynamic> json) => Habit(
    id: json['id'] as String,
    title: json['title'] as String,
    completed: json['completed'] as bool? ?? false,
    iconKey: json['iconKey'] as String? ?? 'leaf',
    reminderEnabled: json['reminderEnabled'] == true,
    reminderHour: ((json['reminderHour'] as num?)?.toInt() ?? 20).clamp(0, 23).toInt(),
    reminderMinute: ((json['reminderMinute'] as num?)?.toInt() ?? 0).clamp(0, 59).toInt(),
  );
}
