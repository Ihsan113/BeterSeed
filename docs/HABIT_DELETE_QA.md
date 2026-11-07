# Permanent deletion QA — 1.11.1+65

Date: 2026-11-07. Baseline: `67d156a6a7cf202ca64e3d53145efaad5e2d773f`.
QA recorded before publication; no production deployment was performed.

## Executed checks

| Check | Result |
| --- | --- |
| `flutter analyze` | PASS — no issues |
| `flutter test --reporter expanded` | PASS — 274 tests |
| `python3 -m unittest discover -s scripts -p 'test_*.py'` | PASS — 67 tests |
| Offline `snapshotSchema.parse`, imported with `node --import tsx` | PASS — 2 cases: v2/v3 empty habits + existing credit ledger |
| `flutter test tool/library_preview_test.dart` with SDK/output defines | PASS — 9 actual Flutter screenshots |
| `python3 scripts/prepare_android.py` | PASS |
| `python3 scripts/verify_android_integration.py` | PASS |
| `flutter build apk --debug` | PASS |
| `aapt dump badging` | PASS — com.betterseed.app, versionName 1.11.1, versionCode 65 |
| `git diff --check` | PASS |

Environment: Flutter 3.47.8, JDK 21, Android SDK 36. Flutter commands use
`/workspace/.betterseed-tools/activate.sh` in this workspace.

## Regression coverage

- Cancel leaves data unchanged; confirmation identifies names, count and effects.
- Filtered bulk delete removes only selected active/archived habits.
- Selected habits edited during confirmation require a fresh review; new and
  unselected habits survive. Changed account scope blocks deletion even before
  another UI frame. Failed save does not show a success message.
- A 320 dp screen at 200% text can scroll the review and delete the final habit.
- Root app removes the last habit, persists an empty list across restart, clears
  only its account-scoped focus checkpoint, and passes the empty list to the
  native reminder channel. The other account's same-ID checkpoint remains.
- Root Statistics sees no habit records/completions after removal while earned
  water, spent water and XP remain byte-for-byte unchanged.
- Cloud deletion with a lost reply and app restart retries the same mutation ID
  and retains the deletion. Credit ledger is unchanged.
- Empty backup roundtrip preserves Garden progression and duplicate-reward guard.
- Snapshot selection preserves v2/v3 floors after the final planner habit is
  deleted; legacy/v1 data and v3 activity-time requirements remain supported.
- Existing Checklist, Focus, Garden, statistics, account/backup/cloud and language
  regressions remain passing in the full 274-test run.

Native reminder tests verify the platform-channel payload, not real alarm
cancellation on a phone. The existing Android scheduler was inspected: it
cancels previous alarms before writing the new list. Its executable source
was not changed. The schema smoke check imports only schema/Zod, with no API
or database access; no backend integration/database test was run.

## Preview and delivery

Real Flutter renders use fictional Indonesian fixtures, 393×852 logical pixels,
output 786×1704. New previews: Hapus_Permanen_Menu, Hapus_Permanen_Konfirmasi,
and Arsip_Setelah_Hapus. Existing management/filter/bulk/archive views are also
rendered. The destructive confirmation was visually inspected.

- `BetterSeed_1.11.1_65_Source.zip`: clean source, no generated platforms,
  dependency/build caches, environment files or signing keys.
- `BetterSeed_1.11.1_65_debug.apk`: debug guest-mode QA build without production
  API/provider defines; not a Play-signed release.
- Companion SHA-256 files and `BetterSeed_1.11.1_65_QA.md`.

APK SHA-256: `4c3275e06bc90478087be6d610a16762ccee2aafc575ad177bda3a40da3e510d`

The workspace's pre-existing `analysis_options.yaml` Android exclusion is kept
locally and excluded from this feature; source ZIP uses the tracked version.

## Practical limits

No emulator/physical Android phone is available here. On-device notification,
TalkBack, OEM lifecycle and battery/thermal behavior were not certified. No live
account, production VPS, MySQL, CDN or billing change/test was performed.
Production current state unverified. No extra backend update is required beyond
the app's existing snapshot compatibility requirements. Backend distribution
changes are documentation only.

Deletion does not erase independent old backups or existing manual conflict
recovery copies. It keeps the credit-ID ledger and Garden progression. Existing
persistence failure behavior is documented in HABIT_DELETE.md; it is not a
transaction spanning local preferences, native scheduling and cloud transport.
