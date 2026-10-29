# Batch 02 QA checklist

## CI
- [ ] GitHub Actions: Android platform scaffolding generation succeeds.
- [ ] `flutter pub get` resolves the `audioplayers` dependency.
- [ ] `flutter analyze` passes.
- [ ] `flutter test` passes, including asset/signature checks.
- [ ] `flutter build apk --debug` produces installable artifact; APK size reported in job log.

## Layout, scene and lifecycle
- [ ] On 360x640 and 393x873 screens: header, tree and short dock remain visible with no overflow.
- [ ] Tree mound visually contacts soil/foreground and does **not** bob vertically.
- [ ] Main landscape and waterfall remain visible behind the tree, not covered by a full-height checklist card.
- [ ] Expand **View all**: all habits are shown and scrolling works when there are many.
- [ ] Add a habit, dismiss composer, and repeat: no Flutter red screen / `_dependents.isEmpty` assertion.
- [ ] Check/uncheck: XP changes by 10, stage progress reflects stage thresholds.
- [ ] Add/remove then force-close/reopen: data persists.
- [ ] Cross local calendar day: checkboxes reset without wiping XP.

## Sound and accessibility
- [ ] Ambient music plays at low volume and loops while app is foregrounded.
- [ ] Background or device lock pauses music; returning to app resumes if music enabled.
- [ ] Music OFF remains OFF after restart.
- [ ] SFX OFF silences clicks, completions, planting, growth, without affecting checklist logic.
- [ ] Animated garden OFF and Android **Reduce motion** disable the wind/particle animation.
- [ ] Entire app works offline/airplane mode, including local audio.
- [ ] Test with ringer silent, Bluetooth headphones, and incoming call audio interruption.

**Status:** Source prepared, not yet verified on a real Android device or by Actions.
