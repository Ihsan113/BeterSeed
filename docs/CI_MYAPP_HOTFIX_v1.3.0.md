# BetterSeed CI hotfix — Flutter `MyApp` test regression

## Root cause

`lib/main.dart` declares `BetterSeedApp`, but Flutter's default generated
widget test invokes `MyApp()`.  The source ZIP already contained a custom
unit-only test at `test/widget_test.dart`; an older GitHub checkout or repeated
`flutter create .` may leave/generate the template test.

## Fix

1. Replace `test/widget_test.dart` with a smoke test that imports
   `package:betterseed/main.dart` and pumps `const BetterSeedApp()`.
2. Generate only Android platform sources via `scripts/generate_android.py`
   using a temporary scaffold, never `flutter create ... .` in project root.
3. Assert Git-tracked Dart sources remain unmodified after generation.
4. Cover source preservation with `scripts/test_generate_android.py`.

## Verification

- Automated Python tests: `python3 -m unittest discover -s scripts -p 'test_*.py' -v`
- Static integration checks: `python3 scripts/verify_android_integration.py --sources`
- After Android scaffold generation on a Flutter-equipped machine, run:

  ```bash
  python3 scripts/generate_android.py
  python3 scripts/prepare_android.py
  flutter pub get
  flutter analyze
  flutter test --reporter expanded
  ```

`flutter analyze` and `flutter test` require a working Flutter SDK; passing
Python tests alone does not prove the Flutter build has passed.

Keep the previous signing secrets and pinned certificate fingerprint for
upgrading installed BetterSeed versions without data loss. Do not uninstall
an existing app merely to fix a CI analyzer error.
