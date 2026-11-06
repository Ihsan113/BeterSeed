# BetterSeed 1.10.1+63 — focused planner corrections

Baseline: GitHub main `1d384a6`. User requested immediate edit, reliable time
controls, automatic timer stopping, Garden animation parity, bounded count
progress, scheduled-only daily lists, tree milestones and UI interaction QA.
QA completed before publication; the user subsequently authorized commit and
GitHub push. No production deployment is included in this work.

## Changes and behavior

1. Editor uses `ChecklistData.editToday`. Today and the active plan change together,
   with pending tomorrow edits cleared. Previous dates remain byte-for-byte intact.
   Changing goal type starts today's value at zero because counts, checkmarks and
   minutes are incompatible. The form explains this before Save. Same-type edits
   preserve duration seconds and count progress within the new target. Earned
   water is retained; editing cannot award new water. A same-day paused session
   is cleared when changing type, so obsolete minutes cannot reappear later.
2. Time/day/category/reminder drafts live outside the bottom-sheet rebuild closure.
   Keyboard MediaQuery changes no longer reset Anytime, selected days or reminder
   enabled state. Hour/minute select their current text on tap, accept digits and
   validate 0–23 / 0–59. Activity time remains independent of notifications.
3. Focus elapsed time caps at the **remaining** daily target, even if a display
   tick is late. The HUD pauses, checkpoints and signals completion once; resume
   is disabled. Finish saves the capped result. Background behavior remains pause
   and paused recovery. Previously saved historical duration is not truncated.
4. Focus shares the existing Garden scene, butterflies and ambient painter. It now
   uses the same explicit motion override as the main Garden; Motion OFF and
   reduced-motion without an override remain off. No second video/audio owner.
5. Count + stops at target. Card/detail/quick-input paths enforce the limit. Old
   over-target counts are normalized only for today on advance/load; previous
   dates stay unchanged. This is a client input rule, not a new server constraint
   that would reject existing historical snapshots.
6. Daily lists show only scheduled records for the selected date. Scheduled Rest
   days remain visible. Manage habits retains access to off-day habits for editing.
   Empty state distinguishes no scheduled habits from a new user's first habit.
7. Milestones use the active installed Garden's six stage sprites in one horizontal
   row, with small check/dot markers. Whole cells fit the initial viewport; it
   scrolls to the current stage and supports large text. No new Garden artwork.

## Data / release impact

App 1.10.1+63; GardenPackRegistry build 63. Snapshot v3 fields and backend source
1.4.0 stay compatible. No VPS, SQL, CDN, purchase or production service changes.
Legacy pending plans remain readable. A compatible v3 backend is still required
for planner cloud sync, as before; this fix does not require another backend API.

Changed modules: checklist model/editor/pickers/page/detail, focus session/HUD,
root scene preference and checkpoint handling, Statistics + GardenMilestones,
seven locale catalogs, regression/render tests, version files and documentation.

## User-flow QA

Automated Flutter UI interactions cover all six goal-type edit transitions,
saving/reopening, frozen earlier records, real app persistence/restart, stale
session cleanup, numeric overflow rejection, hour/minute replacement and invalid
values, keyboard open/close, nested reminder editing, unscheduled hiding and
manager access, capped timer stop/single feedback, and aligned stage sprites at
320dp with normal / 200% text. Motion tests inspect the actual root Garden scene
and advancing butterfly/ambient animation with normal, reduced, override and OFF
preferences. Existing reward-idempotency, backup, cloud, localization and video
lifecycle regression suites are retained.

PNG previews are actual Flutter renders with bundled assets and sample data.
The test harness preloads stage sprites before capture so asynchronous decoding
cannot leave blank trees in a preview. Physical-device Android keyboard/OEM alarm,
thermal/battery and production sync validation remain outside this environment;
there is no emulator/system image or attached phone here. No production-readiness
claim is based solely on platform mocks or an Android compilation.

## Executed results — 2026-11-06

| Check | Result |
| --- | --- |
| Flutter analyze | PASS, no issues |
| Complete Flutter suite | PASS, 245 tests, 59 seconds |
| Python release/native/localization contracts | PASS, 67 tests |
| Android prepare + integration verification | PASS |
| Android debug compilation | PASS; APK metadata: 1.10.1, versionCode 63 |
| Real Flutter preview harness | PASS, seven renders including tree milestones |
| Git whitespace check | PASS |

The full suite includes 20 additional hotfix cases beyond the preceding 225-test
baseline. All six edit direction combinations are covered. The final full run
passed after correcting the test harness to await actual preference/locale I/O
and model audio channels; these checks retain their persistence/UI assertions.
Backend executable code/schema is unchanged; backend integration tests were not
rerun for this frontend correction. The previous backend report remains historical.
The pre-existing local `analysis_options.yaml` Android exclusion is retained.
