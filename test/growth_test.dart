import 'package:betterseed/data/habit.dart';
import 'package:betterseed/logic/growth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Growth stages have correct boundaries', () {
    expect(treeStageForXp(-5), 0);
    expect(treeStageForXp(0), 0);
    expect(treeStageForXp(19), 0);
    expect(treeStageForXp(20), 1);
    expect(treeStageForXp(50), 2);
    expect(treeStageForXp(100), 3);
    expect(treeStageForXp(180), 4);
    expect(treeStageForXp(300), 5);
    expect(treeStageForXp(9000), 5);
  });

  test('Growth progress stays in range', () {
    expect(progressToNextStage(0), 0);
    expect(progressToNextStage(10), 0.5);
    expect(progressToNextStage(300), 1);
  });

  test('Date key is local calendar date', () {
    expect(todayLocalKey(DateTime(2026, 10, 24)), '2026-10-24');
  });

  test('Habit JSON round trip', () {
    const original = Habit(id: 'x', title: 'Read', completed: true);
    final restored = Habit.fromJson(original.toJson());
    expect(restored.id, original.id);
    expect(restored.title, original.title);
    expect(restored.completed, isTrue);
  });
}
