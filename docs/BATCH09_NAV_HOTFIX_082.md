# BetterSeed v0.8.2 — Navigation overflow hotfix

## GitHub Actions failure being addressed
Job `120875501275` in run `40095077692` failed at `flutter test --reporter expanded`:

- `lib/main.dart:743` → `_navItem` Column
- `A RenderFlex overflowed by 2.0 pixels on the bottom`
- failing test: `Settings exposes sound, reminders and widget on short screens`
- `flutter analyze` succeeded; 30 tests passed before this single test failed.

## Root cause
The four-tab navigation bar used a fixed 64px height. Its interior is smaller due to the border and becomes too tight for its icon, label, and spacing under compact layouts and device text scaling.

## Correction
- Navigation container height is now responsive to `MediaQuery.textScalerOf(context)` with a safe 72px minimum.
- Tab icons are sized at 22px; labels are single-line with ellipsis and centered.
- Preserves all 4 tabs and their original `ValueKey` IDs; no state/permission changes.
- Added compact-screen and enlarged-text regression widget tests.

## Verification
Run `flutter analyze`, `flutter test --reporter expanded` and `flutter build apk --debug` in GitHub Actions. Flutter SDK was not installed in the artifact-creation environment; build result is not yet verified.
