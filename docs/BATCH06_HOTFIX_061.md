# BetterSeed v0.6.1 — Native Android files GitHub Actions hotfix

## What failed

`python3 scripts/verify_android_integration.py` reported:

`AssertionError: android/app/src/main/kotlin/com/example/betterseed/ReminderScheduler.kt`

The original `.gitignore` contained `android/` without a leading slash. Git
matches that ignore rule at *any* directory depth, hiding `native/android/`
(where reminder/widget Kotlin sources and XML resources live). As a result,
GitHub Checkout could lack the source files, `prepare_android.py` had nothing
to copy, and verification failed.

## Fixes

- Changed ignore rules to `/android/`, `/ios/`, etc. so only generated root
  platform folders are excluded, not `native/android/`.
- Added **Verify committed native sources** step before `flutter create` to
  give an actionable error if the files are still absent from the repository.
- `prepare_android.py` now fails fast when a required native Kotlin or XML
  file is missing instead of silently producing an incomplete Android tree.
- `verify_android_integration.py --sources` checks every native source and
  Android resource before Flutter platform generation; the normal invocation
  verifies the generated Android manifest, Kotlin and XML resources.
- No behavior changes to Garden, Checklist, Stats, reminders, widgets or audio.

## How to update your GitHub repository

1. Extract ZIP. Copy **the contents of the project folder** to your repository
   root (not the folder itself).
2. Replace `.gitignore`, `.github/workflows/android-apk.yml`, and scripts.
3. Ensure the entire `native/android/kotlin/` and `native/android/res/`
   folders are present. The five Kotlin files are `MainActivity.kt`,
   `ReminderScheduler.kt`, `ReminderReceiver.kt`, `ReminderBootReceiver.kt`,
   `BetterSeedWidget.kt`.
4. If using Git command line, run `git add -A` and confirm
   `git ls-files native/android/kotlin/ReminderScheduler.kt` after committing.
5. Re-run **BetterSeed Android APK** in GitHub Actions.

## Local checks performed

- Both Python scripts pass `py_compile`.
- `verify_android_integration.py --sources` passes.
- Against a generated-style fixture Android manifest, running prepare and
  full verify twice consecutively passes (idempotent).
- A newly initialized Git repo with patched `.gitignore` stages all 5 Kotlin
  and 4 XML resource files; generated root `android/` remains ignored.
- Full Flutter/Gradle compilation still requires GitHub Actions.
