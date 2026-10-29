# BetterSeed - Flutter widget-test CI hotfix (2026-10-25)

GitHub Actions diagnostic source: https://github.com/Ihsan113/BeterSeed/actions/runs/40182352371/job/121135862684

## Observed failure

- `flutter analyze` succeeds: `No issues found!`.
- `flutter test` fails specifically for two Settings navigation tests:
  `test/reminder_master_guard_test.dart` and `test/garden_visual_settings_test.dart`.
- Flutter reports `ListTile background color or ink splashes may be invisible` because the Settings card uses a colored `DecoratedBox` between `ListTile` and its Material ancestor.
- The tests call `tap()` on `settings-menu-backup` and `settings-menu-widget` while those cards are outside the viewport. As a result, the target pages are not opened and later expectations fail.

## Fix

1. Replace `_settingsSectionCard`'s glass `Container/DecoratedBox` with a shaped `Material` having equivalent visual treatment and clipped ink response.
2. Reset the Settings sheet scroll position when switching categories, keeping the back button and header reachable.
3. Make the test tap helpers call `tester.ensureVisible(...)` before a real pointer tap, including at 360x640 screens. Never silence missed-tap warnings.
4. Add a Python regression guard for the known failure patterns.

## Verify in GitHub Actions

- `flutter analyze`
- `flutter test --reporter expanded`
- Android release signing / build, if the above checks pass.

The prior run did not reach Android build and signing steps because Flutter tests failed first. The original app's backup, assets, native widget and other features are unchanged by this hotfix.
