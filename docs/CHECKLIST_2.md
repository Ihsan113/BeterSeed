# Checklist 2.0 — local implementation and review notes

Baseline: `ebe5e217049b64bc9535a68a851e1e98eed14d1a`. Changes are uncommitted.
The user authorized all seven features and explicitly approved the v2 cloud
contract and local backend work. Production deployment and GitHub commit/push
remain separate. Production current state unverified.

## Features

- ISO weekdays 1–7, every day / weekday / weekend presets. Only scheduled,
  non-rest habits contribute to today's denominator.
- Checkbox, integer count with a user unit, and manually recorded minutes.
  Target range 1–100000. No focus timer. Completion credits the existing water
  ledger once per habit ID/local date; undo/recheck cannot credit twice.
- Seven-day selector, monthly calendar with text/icon legend, read-only daily
  results and habit history. Legacy credit only proves water was awarded; missing
  target records stay unknown. Closing a known scheduled day without completion
  records a missed occurrence. Future dates are not editable.
- Morning / Afternoon / Evening / Custom filters and persistent drag ordering
  within each category. Habit title/icon changes do not recycle IDs.
- Rest today before any water credit; cancelling rest unlocks progress. Rest
  does not give water, increment streak or break scheduled streak. A credited
  occurrence cannot be rested after undoing its checkbox.
- Six local two-habit routines with a preview and editable drafts before one
  confirmation; new habits use fresh UUIDs.
- 7/30/100 consecutive scheduled completions, shown in habit detail. Rest and
  unscheduled days are neutral. Highest earned milestone remains recorded.
  There are no extra water, XP, Leaf Coins or paid entitlement rewards.

The four main tabs, existing global water streak and explicit watering-to-XP
mechanism remain. Sixty static Material icon mappings retain all eight original
keys and glyphs. Unknown keys render the original leaf fallback without rewriting
the stored key. Labels and new interface text use the seven existing locales.
Only the sprout PNG is bundled from the design packet; other decorative assets
are optional and are not included in the app.

## Data and effective dates

`Habit.checklist` holds a plan, optional pending plan/effective date, category,
order, archive marker, local-date records and streak summaries. This lives in the
existing habit JSON, account-isolated cloud profile and backup, not a sidecar.
Legacy habits acquire daily checkbox metadata on opening Checklist, preserving
ID, completion, reminder and ledger. No old quantity/duration history is inferred.

Each record stores the effective goal and schedule result. Edits take effect on
the next local date, while today's record freezes its first effective plan. Daily
rollover uses civil calendar constructors rather than adding 24-hour durations.
Deleting archives the habit so history and ID survive. Native alarms consult the
same pending plan, weekday, rest and archive data; master-off and permission
checks remain in place, and boot/timezone broadcasts reschedule alarms.

Detailed records retain at most 366 dates per habit. Older records fold into the
carried streak and best streak; the existing water ledger is not pruned. Details
older than retention are no longer available in a new export. Back up before
upgrading if long-term detailed archival is required. The pre-existing 4 MiB API
request / backup import limit and 2000 total habit limit still apply, including
archived habits. Very large histories can exceed the byte limit before the habit
limit; the API will reject them instead of silently truncating payloads. There is
no promise of immunity to manual clock changes.

## Compatibility and rollout

| Writer / destination | Behavior |
| --- | --- |
| Existing APK / server with v2 support, account still v1 | v1 still accepted |
| New APK / old server | v2 stays local; GET capability check prevents sending it |
| New APK / server advertising `[1,2]` | v2 accepted through existing revision/mutation protocol |
| Old APK writing after account stored v2 | `409 app_update_required`, current snapshot retained |
| Old APK reading v2 | Can view legacy fields; its subsequent v1 write is rejected |
| New APK importing v1 backup | Existing fields read, metadata migrates locally |
| Old APK importing v2 backup | Unsupported version; prevents metadata-stripping restore |

`GET /v1/garden` adds `supportedSnapshotVersions`; snapshot v2 adds validated
optional per-habit checklist metadata. The downgrade guard runs under the existing
account writer lock. Sync conflicts still require choosing a version with a
recovery copy; histories are not blindly added across devices. The new client
checks capabilities even when retrying a persisted v2 outbox.

No SQL migration is needed because gardens already store JSON. Do not downgrade
the backend after v2 accounts exist: retain the compatible backend and disable
new client rollout while resolving a defect. Old backend code lacks the downgrade
guard. Production rollout must follow `AGENTS.md` and the VPS guards, with fresh
state inspection, source/database backups, staging and explicit authorization.

## Main files

- `lib/checklist/`: metadata, calendar, dashboard/editor, static icon catalog.
- `lib/main.dart`: integration, local day migration, water and serialized saving.
- `lib/data/habit.dart`, `lib/backup/backup_snapshot.dart`: portable metadata/v2.
- `lib/account/cloud_account.dart`: capability gate and retained pending data.
- `native/android/kotlin/ReminderScheduler.kt`, `ReminderReceiver.kt`: schedule.
- `server/src/schema.ts`, `sync.ts`: v1/v2 validation and downgrade protection.
- `assets/l10n/*.json`, `assets/images/checklist/`, `pubspec.yaml`: UI resources.

## Validation and release limits

See `CHECKLIST_2_VALIDATION.md` for actual run results. Debug builds and widget
screenshots do not certify Android notification delivery, TalkBack, OEM battery
restrictions, DST/timezone behavior on a device, production cloud rollout or Play
signing. Those require device/staging release QA. Source release version numbers
have not been advanced; this is a review candidate, not a published release.
