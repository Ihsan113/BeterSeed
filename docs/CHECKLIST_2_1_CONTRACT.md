# Checklist & Statistics 2.1 — Snapshot v3 contract

App candidate **1.10.1+63**; backend source **1.4.0**. User approved Snapshot v3
and backend implementation/local testing on 2026-11-06. No production deployment,
SQL migration, CDN, billing or production credentials are part of this change.
Production current state unverified.

## Additions

| Path | Meaning / validation | Legacy default |
| --- | --- | --- |
| `habits[].checklist.plan.activityMinute` | Integer 0–1439, local civil time, or null | Anytime |
| `habits[].checklist.pending.activityMinute` | Same; effective plan rules unchanged | Anytime |
| `habits[].checklist.records[date].plan.activityMinute` | Frozen occurrence time | Anytime |
| `habits[].reminderLeadMinutes` | Integer 0, 5, 15, 30 or 60 | 0 |
| `habits[].checklist.records[date].focusSeconds` | Integer 0–6,000,000; duration records only | Existing `value * 60` |

When seconds are present, `value == floor(focusSeconds / 60)` is required. Target
completion compares against target minutes; 59 seconds toward a one-minute goal
is partial. Old records retain their existing minute precision. Count targets
retain a nonempty unit; new count habits use the neutral internal unit `count`.
Historical custom units are preserved and displayed. The editor has no unit input.

Example duration record:

```json
{
  "plan": {"type":"duration","target":15,"unit":"","weekdays":[1,2,3,4,5,6,7],"activityMinute":1140},
  "scheduled":true,"value":5,"rest":false,"focusSeconds":359
}
```

Existing limits remain: 366 retained records/habit, 2,000 habits, target/value
at most 100,000, strict unknown-field rejection and existing snapshot byte limit.
No additional database columns are needed.

## Version negotiation and old APKs

- Backend GET `/v1/garden` advertises `supportedSnapshotVersions: [1,2,3]`.
- v1/v2 payloads remain valid, but v3 fields (including explicit null time / zero
  lead fields) must not be sent under v1/v2. New client omits unused fields.
- Client writes v3 when planner data needs it; once the current account snapshot
  is v3 it retains v3 even if that data is subsequently removed.
- Every v2/v3 upload, including a persisted pending retry, checks the exact
  advertised version. An incompatible server leaves changes local and reports
  `Checklist saved locally; server update required`. It never strips fields.
- Under the existing writer lock, a lower snapshot version than the stored
  version receives HTTP 409 `app_update_required`. Stored revision/data remain
  intact. This prevents an older APK overwriting v3 data. Old APKs must update
  before continuing cloud writes to an upgraded account.
- Whole-snapshot conflict resolution and idempotent mutation IDs are unchanged.
  This is not live cross-device timer synchronization.
- Backups decode versions 1/2/3 and emit v3 when needed. Old apps reject v3 backups
  rather than silently importing incomplete planner data.
- Deploying a compatible backend is a separate authorized operation. Do not roll
  back to a server lacking v3 validation/downgrade protection after storing v3.

## Activity schedule and notification semantics

Activity weekdays, activity time and reminders are separate. An Anytime habit
has no countdown; its optional reminder uses `reminderHour` / `reminderMinute`.
A timed activity derives notification time from its frozen plan minus lead.
For 00:15 with 30 minutes lead, the 23:45 alarm checks **the following activity
calendar date**, including its weekday/rest/completion state. Category does not
supply a clock. New plans are installed before first-day creation; editor changes apply today and retain earlier records. Same-type progress is
preserved (counts capped at the target); changing type starts today at zero.
Legacy next-day pending plans still decode, but an explicit new edit supersedes them.

Native scheduling uses local Calendar and inexact AlarmManager; nonexistent DST
wall times normalize using Calendar, repeated wall times yield one occurrence.
Boot/date/timezone broadcasts reschedule. Master switch and notification
permission remain required for delivery. Delivered-date suppression prevents a
clock rewind from notifying twice for the same habit/date. A stale earlier-date
alarm is suppressed; an ahead-of-midnight reminder can refer to tomorrow.
Passing activity time only changes the UI status; it does not mark a habit failed.
These are implementation semantics, not a guarantee of exact OEM alarm delivery.

## Focus sessions and recovery

`FocusSessionStore` persists an account/guest + habit-scoped local checkpoint:
`habitId`, `day`, `targetMinutes`, `baseSeconds`, `elapsedMilliseconds`.
It never enters cloud/portable backup. Writes/clear are serialized. Foreground
elapsed time comes from Stopwatch, not wall time, animation ticks or rebuilds.

- Start/pause/resume preserve actual foreground time. From 1.10.1, the timer
  caps elapsed time at the remaining daily target and pauses automatically.
  Target reached disables resume; Finish saves the result. Existing saved duration
  history is retained. This follows the user's updated automatic-stop requirement.
- App lifecycle interruption pauses immediately. Resume is explicit. A new local
  day pauses the old session; save it before beginning a new day.
- Every five running seconds and at explicit transitions a checkpoint is saved.
  Abrupt process death can lose up to the last checkpoint interval plus any
  in-flight storage delay. Background work is not credited.
- Recovery is always paused. A recoverable earlier-date session saves to its
  original retained occurrence. A checkpoint whose occurrence has aged out of
  retention is discarded; unavailable historical detail is not invented.
- Finish writes `max(existing durationSeconds, baseSeconds + elapsedSeconds)`.
  Retrying after interruption between data save and checkpoint clear is idempotent.
  Finish before target preserves partial progress. Reset only clears this session's
  unsaved time, with confirmation; saved base progress stays.
- Existing habit/date reward ledger is authoritative. Crossing target can credit
  one water. Repeated sessions, resets, excess duration and retries cannot credit
  additional water for that date.

## Garden rendering / performance boundaries

The same root backdrop and `_buildTreeScene` serve Garden viewing focus and habit
focus. They have separate state and Back handling. Existing pack selection,
installed-asset fallback, geometry, stages and editor placement are retained.
Opening a timer does not download a pack. Background remains mounted across tabs;
its animation pauses behind planner screens. The HUD alone rebuilds on the
one-second tick. One existing video controller and audio owner are reused. Video
is muted before initialization; ambient audio and completion SFX obey preferences.
Motion OFF / system reduced motion are respected for habit focus; the explicit
in-app motion override follows the same user choice as the main Garden. System UI
returns to edge-to-edge on exit. No whole-screen blur or new graphical assets.

## Statistics definitions

7/30/90-day completion is completed / known scheduled non-rest occurrences through
today. Missing, future, unscheduled and rest dates are excluded. Active habit
streak is the largest current streak among unarchived habits; best includes known
historical streaks. Duration sums saved seconds (legacy minutes converted), including time recorded
before a day was marked Rest; rest remains excluded from completion denominators
and the average per scheduled day. No wall time or target values are substituted. Category breakdown uses each habit's current
category, since historical category was never frozen. Weekday breakdown uses the
record date. Garden water totals use the ledger and are not completion counts;
per-habit contributions only show retained identifiable ledger credits. XP/stage
milestones use the existing growth thresholds, not a new reward system.
