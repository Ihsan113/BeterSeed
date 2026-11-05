# Checklist UI/UX redesign — 1.9.0+61

## Changes

- One Checklist heading and date; calendar and settings remain directly accessible.
- Solid deep green background, restrained mint accent, consistent type sizes, spacing,
  rounded surfaces and controls. The Checklist navigation bar now has a flat top border.
- Seven date cells distinguish selection from progress. Selecting a date never creates
  a completion checkmark. A completed day has one small check; other states have a dot
  or rest marker with an accessible status label.
- A single ring summarizes completion; water and global streak sit underneath the count.
- Compact habit cards show the goal or status once. Check-in habits use a real rounded
  checkbox with its own touch target. Count/duration controls wrap when space is limited.
- Category tabs use an underline. Drag handles appear only in reorder mode. The add
  button stays above navigation while the routine list scrolls.
- Calendar, template preview, two-step habit editor and detail share a local theme.
  Icon search retains all 60 stable icon identifiers; the picker has a scroll indicator.
  Seven schedule buttons stay together in a scrollable row at larger font sizes.
- Habit detail separates progress, schedule, streak milestones and dated history.
  Opening an old date shows that date's record and disables edits.
- New labels are translated in all seven supported languages.

## Version and data

`pubspec.yaml` is **1.9.0+61** and `GardenPackRegistry.appBuild` is **61**.
The version contract test checks that pubspec, README, changelog and app build agree.
AGENTS.md records the user's requirement to increase the app version for each update.

This update retains the Checklist 2 data model and approved snapshot v2 contract.
It does not change backend source, database migrations or deploy production.

## Validation

Automated UI coverage includes date selection versus completion, checkbox toggle
callbacks, historical detail remaining read-only, calendar/detail at 320 dp and 200%
text, and editor at 320/360/393/600 dp with 200% text and keyboard insets.
Navigation and completion-to-water regression tests remain in the full Flutter suite.

Actual Flutter widget renders were inspected at 393 × 852 logical pixels for the
Checklist, calendar, detail, icon picker and goal/schedule editor. These are rendered
app widgets with fixture data, not design mockups or physical-device screenshots.

Results:

- `flutter analyze --no-pub`: no issues.
- `flutter test --no-pub`: 204 tests passed.
- Final focused UI/render run: 9 tests passed, including the temporary render harness.
- `python3 -m unittest discover -s scripts -p 'test_*.py'`: 67 tests passed.
- Debug APK builds successfully; release signing and physical-device testing are outside
  this local validation. The APK is intended for testing, not Play Store publication.

Preview files delivered with this update: `BetterSeed_1_9_Checklist.png`,
`BetterSeed_1_9_Calendar.png`, `BetterSeed_1_9_Detail.png`,
`BetterSeed_1_9_Editor.png`, and `BetterSeed_1_9_Goal.png`.
The temporary screenshot harness is excluded from the source package.
