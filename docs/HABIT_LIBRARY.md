# Semua Kebiasaan — BetterSeed 1.11.0+64

## Scope and audit

Base: GitHub main `3daa04f74186415c710864718f850a323e15be33` (1.10.1+63),
fetched before implementation. Read root `AGENTS.md`, Checklist 2.1 contract,
existing editor, daily filtering, archive representation, reward gate,
persistence queue, backup serialization and Android reminder scheduler.
The former Manage habits sheet excluded archived habits and offered editing only.

Entry: **Daftar Harian → Kelola Semua**. The daily checklist continues showing
only habits scheduled for the selected date. The management page defaults to
all habits, including other weekdays and archived habits.

### Available actions

- Search by habit name; combine status, category and activity-day filters.
- Sort by saved custom order, name, or activity time (Anytime last).
- Reorder all habits by dragging; save explicitly or cancel/back without saving.
  The daily checklist still groups routines by category, preserving custom order
  inside each group. Name/time sort and filters are view preferences for the
  current visit; only saved custom order changes the stored data.
- Tap a row to edit through the existing two-step editor.
- Long press a row or use the selection button for multiple selection.
  “Select visible” selects the entire filtered result, including rows below
  the viewport. Changing search/filter/sort clears selection.
- Bulk category, activity days, reminders OFF, archive, and restore. Each action
  previews its count and up to five names, followed by explicit Apply/Cancel.
  Individual reminder time/offset and activity time remain in the editor.
- Archive hides a habit from daily use without deleting its records. Restore
  makes it active again according to its schedule.

### Focus Timer follow-up

Reset remains visible in the expanded HUD, with muted disabled styling and no
callback once the daily target is reached. The action handler and session model
also guard this state; a recovered target or failed Finish save cannot discard
completed time through Reset. Finish remains available to save/retry. Before
the target, Reset retains its existing confirmation and preserves saved time.
Minimal HUD retains its existing Show controls action.

## Data contract and invariants

**No new cloud fields, snapshot version, SQL migration or server behavior.**
Uses existing `checklist.category`, `order`, `archived`, `plan.weekdays` and
`reminderEnabled`. Existing Snapshot v3 handles activity time and precise
focus seconds; its existing legacy downgrade protection is unchanged.
A server already supporting v3/backend 1.4.0 needs no additional update for
this feature. Production current state unverified; no VPS/CDN/billing changes.

- Restoring inserts today's record before normal advancement, so the archived
  gap is not backfilled as missed days. Existing history, today's recorded
  progress, exact seconds and old custom count units remain intact.
- Schedule edits use `editToday`: update today's schedule and the future plan;
  earlier records remain frozen. A newly unscheduled day retains its raw
  progress but contributes no failure/completion to that day's scheduled totals.
- Management never awards water. The root callback disables reward evaluation;
  ordinary progress still uses the existing once-per-habit/date ledger.
- Reordering changes only order on the latest habit objects. A membership change
  cancels the draft rather than dropping newly added or restored data.
- Dialog actions reread the latest list; an editor refuses to overwrite a habit
  changed while the editor was open. Account scope changes block saving.
- Saves await the existing local/cloud-capture persistence queue. A failure
  reports failure, not success. The root keeps its in-memory edit after a disk
  failure, matching existing retry semantics; this is not an atomic rollback.
- Legacy habits without checklist metadata preserve their completed flag when
  normalized for management.
- Archive/reminder-off changes flow through the existing Android rescheduler;
  archived and disabled reminders are already excluded by ReminderScheduler.

## Files

- `lib/checklist/habit_library.dart`: filtering, order and safe archive/restore.
- `lib/checklist/habit_manager_page.dart`: page, review sheets, selection and guards.
- `lib/checklist/checklist_page.dart`: clear management entry and live list feed.
- `lib/focus/focus_hud.dart`, `focus_session.dart`: reached-target reset guard.
- `lib/main.dart`: awaitable management saves, failure propagation, reward isolation.
- Seven localization catalogs; app version/build and GardenPackRegistry.appBuild.
- `test/habit_library_test.dart`, root integration tests, real Flutter render tool.

## Validation

See [the release QA report](HABIT_LIBRARY_QA.md) for final command results and artifacts. Coverage:
filter/sort combinations; off-day/archive visibility; filtered multi-selection;
confirmation cancellation; category/day/reminder bulk actions; same-day goal
editing; concurrent edit protection; failed saves and account scope; reordering;
320 dp/200% text with keyboard; archive gaps and exact seconds; v3 backup roundtrip;
root app archive/restore, persisted cold restart and unchanged water ledger.
Existing Focus/Garden, statistics and other Flutter tests also run.

Previews are rendered by Flutter with actual widgets/fonts, using fictional
fixtures in Indonesian. No device/emulator is available in this workspace;
APK compilation and widget interaction tests do not certify physical Android
alarms, TalkBack, OEM lifecycle, battery or thermal behavior. On-device release
smoke testing remains necessary.
