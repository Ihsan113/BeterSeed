# BetterSeed v0.6.2 — Widget test & Settings visibility hotfix

## Reported failure

- `flutter analyze` succeeded and 19 tests passed.
- `flutter test` reported 1 failing widget test named `full bleed background, ambient renders, and settings is accessible`.
- The supplied log contained only the failed test name, not its failed assertion or stack trace, so the precise assertion cannot be established from that log alone.

## Changes

1. The Settings panel keeps its draggable, vertically scrollable behavior but uses an eagerly built `SingleChildScrollView` + `Column` instead of a lazily mounted `ListView`. The reminder-time and add-widget controls now exist in the widget tree regardless of scroll offset. A dedicated `settings-scroll` key makes tests unambiguous.
2. Split the broad test into separately named assertions for the fullscreen background, garden ambience, and Settings contents. The garden test honors the Android `reduce motion` accessibility setting.
3. The Settings test runs in a 360 × 640 logical pixel viewport and verifies that the Home Screen Widget action can be reached using `ensureVisible`, without assuming that one drag will scroll the sheet rather than resize it.
4. GitHub Actions now uses `flutter test --reporter expanded` for more informative assertion traces if another test fails.
5. Native reminder/widget implementation, animations, game progress, music and original background `BoxFit.cover` remain unchanged.

## Verification

- Native Kotlin/XML source presence check: passed using `python3 scripts/verify_android_integration.py --sources`.
- Static structural and archive integrity checks: passed.
- Flutter SDK is not installed in this build environment; `flutter analyze`, `flutter test` and Android build require GitHub Actions. **Do not assume the test passes without running CI.**

## Rebuild

Replace all files of the previous v0.6.1 project in the GitHub repository root with the contents of this archive's project folder (including hidden `.github` and `.gitignore` plus `native/`). Commit and push. Run the `BetterSeed Android APK` workflow; expanded logs will identify any remaining failure. 
