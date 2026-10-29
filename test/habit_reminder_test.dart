import 'package:betterseed/data/habit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('older stored habits remain valid with reminders disabled', () {
    final h = Habit.fromJson({'id': 'old', 'title': 'Drink water', 'completed': true});
    expect(h.reminderEnabled, false);
    expect(h.reminderHour, 20);
    expect(h.reminderMinute, 0);
    expect(h.completed, true);
    expect(h.iconKey, 'leaf');
  });

  test('each habit stores its own reminder, preserved after completion change', () {
    final h = Habit(id: 'read', title: 'Read', iconKey: 'book',
        reminderEnabled: true, reminderHour: 6, reminderMinute: 25);
    final stored = Habit.fromJson(h.toJson());
    expect(stored.reminderEnabled, true);
    expect(stored.reminderHour, 6);
    expect(stored.reminderMinute, 25);
    final done = stored.copyWith(completed: true);
    expect(done.completed, true);
    expect(done.reminderEnabled, true);
    expect(done.reminderHour, 6);
  });

  test('invalid reminder time in old data is clamped safely', () {
    final h = Habit.fromJson({'id': '1', 'title': 'Walk',
        'reminderEnabled': true, 'reminderHour': 200, 'reminderMinute': -8});
    expect(h.reminderHour, 23);
    expect(h.reminderMinute, 0);
  });
}
