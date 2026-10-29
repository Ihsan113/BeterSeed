/// Cumulative XP thresholds for the six visual tree stages.
const treeStageThresholds = <int>[0, 20, 50, 100, 180, 300];

/// Maps XP to an index in the [0, 5] range.
int treeStageForXp(int xp) {
  final safeXp = xp < 0 ? 0 : xp;
  for (var stage = treeStageThresholds.length - 1; stage >= 0; stage--) {
    if (safeXp >= treeStageThresholds[stage]) return stage;
  }
  return 0;
}

/// Fraction of XP progress toward the next tree stage.
double progressToNextStage(int xp) {
  final stage = treeStageForXp(xp);
  if (stage >= treeStageThresholds.length - 1) return 1;
  final from = treeStageThresholds[stage];
  final to = treeStageThresholds[stage + 1];
  return ((xp - from) / (to - from)).clamp(0.0, 1.0);
}

String todayLocalKey([DateTime? when]) {
  final date = when ?? DateTime.now();
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
