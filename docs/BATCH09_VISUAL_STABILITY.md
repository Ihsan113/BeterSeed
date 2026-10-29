# Batch 09 — Visual Stability & Asset Integration

Version: `0.8.1+13` (source package only; APK still requires CI build).

## Defects from v0.8.0 corrected

1. **Stage 3 had an opaque black background.** `stage_3_young.webp` was accidentally stored as RGB during the prior asset replacement. It is now alpha-capable RGBA WebP again. The original transparency matte was carefully reused against the corrected illustrated tree. The CI check rejects a future opaque replacement.
2. **Some CustomPaint layers could be zero-size.** The ambient and water painters were placed in nested Stack widgets where a non-positioned CustomPaint may choose its default Size.zero. `StackFit.expand` now makes each painter fill the bounded Garden scene. Without this, butterflies might appear but fireflies and water would not draw.
3. **Watering could miss the tree base.** Water-drop stream now begins at the watering-can sprite's nozzle and ends at a root contact point computed by a single geometry source shared with the actual tree placement. The tree isn't translated during watering.
4. **Shop integrity check.** Added an explicit navigation test that visits the Shop placeholder and returns to Garden.
5. **Butterfly visual motion.** Uses the realistic transparent image assets from v0.8.0, and updates the repeat period to 28 complete wing-shrink cycles per 14-second ambience loop (the image itself is still one illustration, not a true skeletal/3D butterfly rig).

## CI and tests

- Added `scripts/verify_visual_assets.py`: standard-library-only preflight check that stage 3 contains WebP alpha and the butterfly/watering images have PNG alpha channels.
- Added `test/garden_scene_geometry_test.dart`.
- Extended `test/assets_test.dart` and `test/navigation_test.dart`.
- Added dimensions assertion to ambient painter widget test.
- Existing reminder, widget, audio, and game state code remains intact.

## Testing instructions

1. Upload *all files inside the ZIP* to the **repository root** (including `.github`, `native`, and `scripts`).
2. Run GitHub Actions `BetterSeed Android APK`.
3. Check `Verify transparent garden assets`, `Static analysis`, `Unit tests`, then `Build installable debug APK`.
4. On device: check stage 3 against the forest (no black backdrop); turn on Living Garden, check fireflies and butterflies; earn water and make sure it flows from the watering can nozzle toward the rooted tree; switch between the four navigation tabs; test reminder/widget settings.

## Limitations

Flutter SDK isn't installed in the current build environment; the local run validated Python preflight, native source presence, package structure, and Dart delimiter balance, **not** `flutter analyze`, widget tests, or Android installation.
