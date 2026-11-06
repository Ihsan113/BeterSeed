# Checklist & Statistics 2.1 — executed validation

Date: **2026-11-06**. Baseline GitHub main: `18ff8c2` (1.9.0+61).
Candidate: **1.10.0+62**, backend source **1.4.0**. QA completed before publication.
The user subsequently authorized commit and GitHub push on 2026-11-06. No
production changes were performed. Snapshot v3/local backend work approved by
user. The audit and full data contract are in `CHECKLIST_2_1_AUDIT.md` and
`CHECKLIST_2_1_CONTRACT.md`.

## Results

| Check actually run | Result |
| --- | --- |
| `flutter analyze` | PASS — no issues |
| `flutter test --reporter expanded` | PASS — 225 tests |
| `npm run check` and `npm run build` in server | PASS |
| Backend integration suite, local MySQL 8.0.46, loopback port 33067 | PASS — 40 tests |
| `python3 -m unittest discover -s scripts -p 'test_*.py'` | PASS — 67 tests |
| `scripts/prepare_android.py` + `scripts/verify_android_integration.py` | PASS — sources, permissions, receivers, resources |
| `flutter build apk --debug` | PASS — Android debug compilation |
| Real Flutter preview harness (`tool/planner_preview_test.dart`) | PASS — six rendered screens, no widget exceptions |
| Host CPU insights benchmark (`tool/planner_performance_test.dart`) | PASS — measurements below |
| `git diff --check` | PASS |

The final full Flutter run took 54 seconds in this workspace. Prior failing runs
caught obsolete v3-as-unsupported / old Stats-title expectations, a sub-minute
history status bug, zero-motion HUD animation lifecycle issues, and video default
volume during initialization. Those issues were fixed; the counts above are the
subsequent passing runs, not a claim that every development run passed.

## Regression and integration coverage

- Save actual new editor forms for checkbox/count/duration and restore Habit JSON;
  chosen plan is applied before the first daily record.
- Activity time, reminder offset, duration seconds and frozen historical/pending
  plans survive serialization and portable v3 backup round trips. Reminder OFF
  does not remove activity time; old custom count units remain in data/UI.
- Time status before/during/after activity; Anytime has no countdown. Rest,
  unscheduled, future and missing records do not enter insight denominators.
- Five custom pickers at 320×640dp / 200% text; existing checklist/editor tests at
  320/360/393/600dp including keyboard inset. Statistics and minimal/full timer HUD
  at 320dp / 200%, including confirmed reset preserving previously saved minutes.
- Monotonic timer start/pause/resume/reset/checkpoint recovery; account-isolated
  serialized store. Actual app saves 90-second partial and 180-second complete
  sessions, retries the same result and credits one water only. 59 seconds stays
  partial in historical status. Marking a day Rest preserves actual recorded
  seconds in duration totals without adding a completion failure.
- Actual app enters old Garden Focus Mode and Habit Focus Timer with identical
  tree geometry; timer lifecycle pause, explicit recovery and edge-to-edge System
  UI restoration. No additional audio players on timer entry; Motion OFF checked.
- Video platform mock: one controller across HUD ticks, zero volume even during
  initialization, pause/poster on Motion OFF, one disposal. Existing image/video
  fallback, pack selection, editor and reduced-motion tests remain passing.
- All ten registered Garden Pack appearance mappings resolve their respective
  six stages/backgrounds. This mapping test is not a claim that every premium CDN
  video was downloaded and decoded on a phone. Actual preview uses bundled Default.
- v3 upload blocked against a v2-only server; capability restored allows intact
  upload, including a pending retry after a lost reply. Backend accepts v1/v2/v3,
  validates time/lead/seconds ranges and duration consistency, and rejects v2
  downgrade without altering stored v3 data/revision.
- Seven-language key/placeholder checks and existing localized small-screen tests
  pass. Existing backup, cloud conflicts/account isolation, Garden editor and
  billing mock suites remain passing.

## Performance evidence and limits

Host CPU stress fixture: 100 habits × 366 retained daily records, 90-day insight
window, five warm-up iterations and 25 measured samples. Median **36.299 ms**,
p95 **65.095 ms** in Flutter's host test runtime while other checks ran. This
measures statistics computation only, not device frame time. Timer ticks rebuild
only HUD; controller lifecycle tests found no additional video decoder owner.
There is no whole-screen blur or new animation asset. Background Garden motion
pauses behind planner pages and on app interruption.

**Not executed / still needs device evidence:** Android emulator or physical-device
interaction; OEM notification timing, boot delivery, permission denial and real
DST/timezone changes; premium pack media decoding on hardware; TalkBack review;
GPU frame pacing, battery drain and device temperature; production cloud end-to-end
sync; release signing/Play deployment. Android debug compilation and platform
mocks do not establish these results. Production current state unverified.

Native reminder code was reviewed for local civil dates, midnight offsets,
rest/weekday/completion filtering, boot/timezone rearming, master switch, Android
13 permission and repeated-date suppression. AlarmManager remains inexact. Timer
is deliberately foreground-only and restores paused; abrupt termination can lose
the most recent five-second checkpoint interval plus in-flight write delay.

## Preview and artifacts

Six PNGs are generated from actual app widgets at 393×852 logical pixels, 2× PNG
resolution, real Roboto/Material fonts and existing Garden artwork, using sample
history and mocked platform channels. They are not image-generation mockups or
physical-device screenshots:

- `BetterSeed_2_1_Checklist.png`
- `BetterSeed_2_1_Goal_Picker.png`
- `BetterSeed_2_1_Schedule.png`
- `BetterSeed_2_1_Focus.png`
- `BetterSeed_2_1_Statistics.png`
- `BetterSeed_2_1_Insights.png`

`tool/planner_preview_test.dart` reproduces them using `FLUTTER_SDK` and
`PREVIEW_OUTPUT` dart defines (see README). The debug APK uses local default build
configuration, not production signing/API configuration. Source ZIP omits build
caches, dependencies, local credentials and generated Android output; recreate
Android using the repository scripts. A separate deterministic backend source ZIP
includes the v3 contract and production guards; it is not a deployment action.

The pre-existing `analysis_options.yaml` Android exclusion is preserved and was
not introduced as part of this feature work.
