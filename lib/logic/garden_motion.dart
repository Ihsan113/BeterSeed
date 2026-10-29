/// User controlled Garden effects, independently from Android transition speeds.
///
/// Android's accessibility request is respected by default; an explicit
/// in-app opt-in can preserve the game's ambient motion.
bool shouldAnimateGarden({
  required bool livingGardenEnabled,
  required bool systemReducedMotion,
  required bool allowWhenSystemReduced,
}) => livingGardenEnabled && (!systemReducedMotion || allowWhenSystemReduced);
