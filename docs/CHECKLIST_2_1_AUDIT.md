# Checklist & Statistics 2.1 — audit and implementation plan

Audit date: 2026-11-06. Fetched GitHub `main`: `18ff8c23f637f1b625549162f90c69332f8b8b4a`.
No newer commit was present. App baseline: 1.9.0+61; planned release: 1.10.0+62.
The pre-existing local `analysis_options.yaml` exclusion is preserved separately.

## Findings and risks

1. **Confirmed creation bug:** `HabitEditor.save` calls `advance(now)` on a default
   checkbox plan before copying the chosen goal. `today()` prefers the existing
   daily record, so the new count/duration plan is hidden by a checkbox record.
   New habits must construct the final plan before recording their first day.
   Existing edits must continue to freeze previous records.
2. **Schedule:** HabitPlan currently stores ISO weekdays only. Reminder clock is
   independent but there is no activity time or lead time. Android scheduling
   evaluates weekdays/rest/archive, uses inexact AlarmManager, and rearms after
   boot/timezone changes. Lead times crossing midnight must evaluate the activity
   date, not the notification's date. Permission/master-off must remain respected.
3. **Storage:** Habit JSON is shared by local preferences, backup and cloud.
   Snapshot v2 strictly rejects unknown fields; adding clock/seconds data to v2
   would break sync. Existing v2 capability and downgrade guards can be extended.
4. **Garden:** main.dart already owns appearance, installed-pack fallback, tree
   placement/geometry, background video, wind and ambient audio. Habit focus will
   reuse these builders in the same root scene, with separate timer state and HUD.
   It will not create another Garden route with a second decoder/audio player.
5. **Timer:** use a monotonic Stopwatch for foreground elapsed time. Pause on
   lifecycle interruption; persist bounded checkpoints and recover paused. Do not
   derive elapsed time from DateTime differences or animation frame counts.
   Saved seconds become daily duration progress; the existing ID/date water ledger
   remains the reward authority. A session crossing a local date boundary pauses.
6. **Statistics:** the existing Stats screen mostly displays water-ledger totals.
   Completion insights must instead use known scheduled, non-rest HabitRecords.
   Unknown/future/unscheduled/rest data cannot become failures. Retained details
   cover at most 366 days; old aggregate water is not a completion count.
7. **Validation limits:** this workspace can build Android and run Flutter renders,
   tests and performance instrumentation. Physical-device temperature/battery,
   OEM alarm delivery and production connectivity require separate evidence.
   Production current state unverified; no production changes are authorized.

## Planned file groups / sequence

1. `lib/checklist/checklist_data.dart`, `lib/data/habit.dart`, editor and new
   `checklist_pickers.dart`; regression tests for creation, plans and serialization.
2. Checklist page/detail plus time-status logic and Android reminder source.
3. `lib/focus/` monotonic session model/store/HUD; integrate with existing root
   Garden builders/lifecycle in `lib/main.dart`, preserve Garden viewing focus.
4. `lib/statistics/` record-based calculations, summary/insights/garden screens.
5. Backup/cloud capability gates, seven locales, version files, docs, full tests,
   real widget renders, Android debug build and clean source ZIP.

## Approved cloud/backup contract

User approved Snapshot v3 and local backend implementation/tests on 2026-11-06.
Production deployment remains separately gated.

Use **Snapshot v3**, keeping v1/v2 parsing intact:

- HabitPlan optional `activityMinute`: null/absent = anytime, otherwise 0–1439
  minutes on the local civil day. It is copied into each historical record.
- Habit optional `reminderLeadMinutes`: 0/5/15/30/60. Existing reminderEnabled,
  reminderHour and reminderMinute stay valid. Anytime uses the independent clock;
  timed activity derives its alarm from activityMinute minus lead time.
- Duration HabitRecord optional `focusSeconds`: integer 0–6,000,000, reflecting
  saved activity duration. `value` remains whole minutes; old records without
  seconds retain their recorded minute value. Count units remain nonempty using
  a neutral default for newly created habits; historical units are untouched.
- Active timer checkpoints remain device-local and account-scoped; they are not
  live sessions shared between devices. Only saved daily results travel in v3.
- New server advertises `[1,2,3]`, accepts legacy accounts and refuses a lower
  version write once an account contains a newer version, under the writer lock.
- New client gates uploads by the exact supported version, including queued
  retries. With an old server, v3 changes remain safely local with a clear status.
- New backups read 1/2/3; v3 backup metadata prevents old APKs silently dropping
  new fields. No SQL migration is required; existing size/retention limits remain.

Proposed backend tests: valid v1/v2/v3, field/range rejection, v3-only fields cannot
hide in v2, capability response, downgrade rejection preserving snapshot/revision,
conflict/outbox retry and backup round trips. No VPS deployment or production DB
access forms part of this proposal.
