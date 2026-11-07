# BetterSeed 1.11.0+64 — validation report

Date: 2026-11-07. Base: GitHub main `3daa04f74186415c710864718f850a323e15be33`.
QA completed before publication. The user subsequently authorized commit and
GitHub push. Production current state unverified.
No VPS, database, CDN or billing deployment was performed.

## Final command results

| Check | Result |
| --- | --- |
| `flutter analyze` | PASS — no issues |
| `flutter test --reporter expanded` | PASS — all 262 tests |
| `python3 -m unittest discover -s scripts -p 'test_*.py'` | PASS — 67 tests |
| `python3 scripts/prepare_android.py` | PASS — Android integration generated |
| `python3 scripts/verify_android_integration.py` | PASS — native sources/resources/receivers/permissions |
| `flutter build apk --debug` | PASS — debug APK produced |
| `aapt dump badging` | PASS — com.betterseed.app, versionName 1.11.0, versionCode 64 |
| Flutter render tools (2 tests) | PASS — 14 actual Flutter screenshots |
| `git diff --check` | PASS |
| `python3 scripts/package_server.py --check` | PASS — reproducible package matches source/checksum |

Environment: Flutter 3.47.8, JDK 21, Android compile SDK 36.
Commands use `/workspace/.betterseed-tools/activate.sh` in this workspace.
The full suite was rerun after the final account-owner guard; final result is 262/262.

## New behavior tested

- Search, intersecting day/category/status filters, all/off-day/archive visibility.
- Selection restricted to filtered results and cleared when filters change.
- Review + cancellation and selected-only category/day/reminder-off/archive/restore.
- Real drag gesture through the reorder handle, explicit save, and cancellation
  of stale drafts when list membership changes.
- Edit checkbox to duration through the global page; reject a stale editor result.
- Failed persistence produces an error rather than success; account scope changes
  block writes. Busy state blocks Back.
- Real root app archive/restore, local persistence and cold restart; earned-water
  ledger unchanged. Earlier records and actual duration seconds retained.
- Archive gap remains unavailable/neutral, not backfilled as missed days.
- Existing custom count units, legacy completion, saved order and v3 backup
  roundtrips remain valid.
- 320 dp, text 200%, search keyboard and scrollable review/filter sheets.
- Sheet text contrast remains readable even under a light parent theme.
- Focus Reset remains visible/disabled at target, including restored completion
  and failed Finish save; model guard retains completed time. Partial Reset
  still confirms and discards only unsaved focus time.
- Existing daily editing, time pickers, bounded counts, all Garden Pack scene
  mappings, Motion OFF/reduced motion, single video/audio ownership, old Garden
  Focus, System UI restoration, statistics, backup and cloud regressions pass.

## Rendered previews

`tool/library_preview_test.dart`: Semua_Kebiasaan, Filter_Kebiasaan,
Pilihan_Massal, Aksi_Massal, Konfirmasi_Arsip, Arsip_Kebiasaan.

`tool/planner_preview_test.dart`: Checklist, Focus, reached-target Focus with
Reset disabled, Statistics, Insights, tree milestones, Goal Picker and Schedule.

Both use real Flutter widgets/fonts and fictional fixtures at 393×852 logical
pixels (PNG output 786×1704). The management previews use Indonesian.

## Delivered artifacts

- `BetterSeed_1.11.0_64_debug.apk` — local debug/QA build, not Play signed;
  built without production API/provider defines (guest-mode QA).
- `BetterSeed_1.11.0_64_Source.zip` — clean source without generated Android,
  caches, dependencies, signing material or local environment files.
- `BetterSeed_1.11.0_64/` — screenshots.
- SHA-256 files accompany APK and source ZIP.

APK SHA-256: `e12cc19472ecbfe70fc83a1b43963b9af24a6379be6233c7f3e07b017c714565`

## Contract and limits

Existing Snapshot v3 / backend 1.4.0 contract is unchanged. No backend runtime,
SQL or native reminder source changes. The regenerated backend ZIP contains
updated documentation only (AGENTS, global management guide and this QA report);
it does not require a production redeploy.

A pre-existing local `analysis_options.yaml` exclusion for generated Android
was preserved in the workspace. It is not part of this feature; the clean source
ZIP retains the tracked analyzer configuration.

No emulator/physical Android device is available. Compilation and Flutter
interaction tests do not certify physical notification delivery, TalkBack,
OEM lifecycle, thermal or battery behavior. No live-account sync or production
server test was performed; compatibility is covered by existing offline
contracts and backup/cloud regression tests. The backend integration suite
was not rerun because its executable sources did not change.
