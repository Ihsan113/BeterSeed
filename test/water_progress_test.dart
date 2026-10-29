import 'package:betterseed/logic/water_progress.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Earn and spend water', () {
    test('checking once earns one, toggling same habit does not farm water', () {
      final progress = WaterProgress();
      expect(progress.earnForHabit('2026-10-24', 'read'), isTrue);
      expect(progress.earnForHabit('2026-10-24', 'read'), isFalse);
      expect(progress.waterBalance, 1);
      expect(progress.totalEarned, 1);
      expect(progress.xp, 0, reason: 'Checking alone must not grow tree');
    });

    test('same habit can earn again tomorrow, but only once per day', () {
      final progress = WaterProgress();
      expect(progress.earnForHabit('2026-10-24', 'read'), isTrue);
      expect(progress.earnForHabit('2026-10-25', 'read'), isTrue);
      expect(progress.earnForHabit('2026-10-25', 'read'), isFalse);
      expect(progress.waterBalance, 2);
    });

    test('watering spends one drop, adds ten XP, cannot overdraft', () {
      final progress = WaterProgress();
      expect(progress.waterTree(), isFalse);
      expect(progress.earnForHabit('2026-10-24', 'read'), isTrue);
      expect(progress.earnForHabit('2026-10-24', 'walk'), isTrue);
      expect(progress.waterTree(), isTrue);
      expect(progress.waterBalance, 1);
      expect(progress.xp, 10);
      expect(progress.waterTree(), isTrue);
      expect(progress.waterTree(), isFalse);
      expect(progress.xp, 20);
      expect(progress.treeStage, 1);
    });

    test('ledger survives a JSON round trip', () {
      final progress = WaterProgress();
      progress.earnForHabit('2026-10-24', 'read');
      progress.earnForHabit('2026-10-24', 'walk');
      progress.waterTree();
      final restored = WaterProgress.fromJson(progress.toJson());
      expect(restored.waterBalance, 1);
      expect(restored.totalEarned, 2);
      expect(restored.totalSpent, 1);
      expect(restored.xp, 10);
      expect(restored.wasCredited('2026-10-24', 'read'), isTrue);
      expect(restored.earnForHabit('2026-10-24', 'walk'), isFalse);
    });

    test('past XP migration keeps existing tree stage without fake water', () {
      final progress = WaterProgress(xp: 100);
      expect(progress.treeStage, 3);
      expect(progress.waterBalance, 0);
    });

    test('streak correctly counts adjacent days and skips empty today', () {
      final progress = WaterProgress();
      progress.earnForHabit('2026-10-21', 'a');
      progress.earnForHabit('2026-10-22', 'a');
      progress.earnForHabit('2026-10-23', 'a');
      expect(progress.dayStreak(DateTime(2026, 10, 24)), 3);
      progress.earnForHabit('2026-10-24', 'a');
      expect(progress.dayStreak(DateTime(2026, 10, 24)), 4);
    });

    test('bad persisted balances are clamped to safe values', () {
      final restored = WaterProgress.fromJson({
        'earned': -20,
        'spent': 1000,
        'xp': -5,
        'credited': <String, dynamic>{},
      });
      expect(restored.waterBalance, 0);
      expect(restored.xp, 0);
      expect(restored.waterTree(), isFalse);
    });
  });
}
