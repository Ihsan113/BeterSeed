import 'growth.dart';

/// Local, offline progression. Completing a habit awards water at most once
/// per LOCAL calendar day, even if a checkbox is unchecked/rechecked.
/// Water only becomes tree XP when the user explicitly waters the garden.
class WaterProgress {
  WaterProgress({
    int totalEarned = 0,
    int totalSpent = 0,
    int xp = 0,
    Map<String, Set<String>>? credited,
  })  : _totalEarned = totalEarned < 0 ? 0 : totalEarned,
        _totalSpent = totalSpent < 0 ? 0 : totalSpent,
        _xp = xp < 0 ? 0 : xp,
        _credited = credited ?? <String, Set<String>>{} {
    if (_totalSpent > _totalEarned) _totalSpent = _totalEarned;
  }

  int _totalEarned;
  int _totalSpent;
  int _xp;
  final Map<String, Set<String>> _credited;

  int get totalEarned => _totalEarned;
  int get totalSpent => _totalSpent;
  int get xp => _xp;
  int get waterBalance => _totalEarned - _totalSpent;
  int get treeStage => treeStageForXp(_xp);

  bool wasCredited(String dayKey, String habitId) =>
      _credited[dayKey]?.contains(habitId) ?? false;

  /// Returns true only when a *new* water drop is earned.
  bool earnForHabit(String dayKey, String habitId) {
    if (habitId.isEmpty || dayKey.isEmpty) return false;
    final ids = _credited.putIfAbsent(dayKey, () => <String>{});
    if (!ids.add(habitId)) return false;
    _totalEarned += 1;
    return true;
  }

  /// Each drop = 10 XP. Returns false without mutating if no water is left.
  bool waterTree() {
    if (waterBalance <= 0) return false;
    _totalSpent += 1;
    _xp += 10;
    return true;
  }

  /// Reset only the plant's stage/XP. Previously earned and spent water, the
  /// daily credit ledger, streaks and checklist records remain intact.
  /// Spent water is deliberately not refunded or re-awarded.
  void resetTreeGrowth() {
    _xp = 0;
  }

  int earnedOn(String key) => _credited[key]?.length ?? 0;

  /// Counts consecutive days with at least one credited habit. An incomplete
  /// current day doesn't break yesterday's streak prematurely.
  int dayStreak(DateTime today) {
    var current = DateTime(today.year, today.month, today.day);
    if (earnedOn(todayLocalKey(current)) == 0) {
      current = DateTime(current.year, current.month, current.day - 1);
    }
    var streak = 0;
    while (earnedOn(todayLocalKey(current)) > 0) {
      streak++;
      current = DateTime(current.year, current.month, current.day - 1);
    }
    return streak;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'version': 3,
        'earned': _totalEarned,
        'spent': _totalSpent,
        'xp': _xp,
        'credited': _credited.map((key, ids) => MapEntry(key, ids.toList())),
      };

  factory WaterProgress.fromJson(Map<String, dynamic> json) {
    final days = <String, Set<String>>{};
    final raw = json['credited'];
    if (raw is Map) {
      for (final entry in raw.entries) {
        if (entry.key is String && entry.value is List) {
          days[entry.key as String] = (entry.value as List)
              .whereType<String>()
              .toSet();
        }
      }
    }
    final creditedCount = days.values.fold<int>(0, (sum, ids) => sum + ids.length);
    final earned = json['earned'] is int ? json['earned'] as int : 0;
    return WaterProgress(
      totalEarned: earned > creditedCount ? earned : creditedCount,
      totalSpent: json['spent'] is int ? json['spent'] as int : 0,
      xp: json['xp'] is int ? json['xp'] as int : 0,
      credited: days,
    );
  }
}
