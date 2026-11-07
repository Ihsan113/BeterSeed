# Permanent habit deletion — BetterSeed 1.11.1+65

Baseline: GitHub main `67d156a6a7cf202ca64e3d53145efaad5e2d773f`.

## User flow

**Daily Checklist → Manage all → habit menu → Delete permanently**.
For multiple habits, enter selection mode, select results, then choose
Delete permanently from the bulk actions. Both active and archived habits can
be deleted. No real user habits are deleted by development/testing.

The custom confirmation shows the selected count and names (first five plus a
remaining count), explains removal of history/reminders and the effect on habit
statistics, and requires the explicit destructive button. Cancel, Back or sheet
dismissal does not modify data. The action uses a restrained warm warning color.
All new strings are translated in the existing seven languages.

## What is deleted / retained

- Remove selected Habit objects, including their ChecklistData and HabitRecord
  history. They no longer appear in daily lists, management or habit insights.
- Save the resulting list even if it is empty; startup does not recreate starter
  habits for a saved empty list.
- After successful persistence, clear only the removed IDs' FocusSessionStore
  entries in the original account/device scope. Other accounts are untouched.
- Send the reduced list through the existing Android `syncHabits` path, which
  cancels old reminder alarms before replacing the native list. The widget also
  receives the updated count. Android scheduling remains subject to platform
  availability; no new alarm implementation is introduced.
- Preserve WaterProgress totals, spent water, XP, tree stage and credited-ID
  ledger. Deleted habit names/plans/history are not retained in that ledger;
  IDs stay to prevent re-awarding an already credited date after an old restore.
- Habit completion/history statistics change because those records are removed.
  Garden totals remain independent of current habit count.

There is no in-app Undo/Restore for this action. An independently retained old
backup or the existing manual cloud-conflict recovery flow may still contain old
habits. Deletion does not erase external backups or introduce server tombstones.
The UI explicitly tells the user that old backups can still contain the habits.

## Data safety and compatibility

Deletion reviews a captured JSON fingerprint of each selected habit and checks
it again before saving. Changed/removed selections or changed account scope
require a fresh review. Concurrent additions and unselected items are retained.
The existing root owner and concurrent-change guards remain in force.

Persistence and cloud capture are awaited before showing success. Failures
report failure; the existing root save path can retain its in-memory change
when disk/native cleanup fails, so it is not a multi-store atomic rollback.
Focus recovery is not deleted before the habit list is persisted.

**No backend/schema/database update is required for this feature.** Snapshot
v2/v3 already allow an empty habit list and credited IDs without a corresponding
current habit. `habitSnapshotVersion` retains the previous account version even
when its final planner habit is removed; this also fixes the former v2→v1
empty-list downgrade. Existing whole-snapshot revisions, idempotent retries,
version negotiation and conflict handling remain unchanged.

No VPS, production database, CDN, Play Billing or server runtime source was
modified. Production current state unverified.

## Implementation and validation

- `habit_manager_page.dart`, `checklist_pickers.dart`: single/bulk actions and
  reviewed destructive confirmation, stale-selection/account checks.
- `main.dart`, `data/habit.dart`: persisted removal cleanup and snapshot floor.
- Seven locale catalogs, app version/build and GardenPackRegistry.appBuild.
- `habit_delete_test.dart`: cancellation, exact filtered selection, stale review,
  account change, failed save, small screen/font 200%, empty backup and version.
- Root Flutter integration: empty list survives restart, reminders receive empty
  list, own checkpoint removed/other account retained, statistics/water verified.
- Cloud regression: lost deletion reply and restart reuse the mutation ID and
  retain the deletion/water ledger.
- Offline Zod check imports only `server/src/schema.ts`; accepts empty v2/v3
  snapshots with an existing credit ledger, without contacting a database/API.
- Real Flutter Indonesian previews include the action menu, confirmation, and
  archive view after deletion, using fictional fixtures.

Final command results and device limitations: see [the QA report](HABIT_DELETE_QA.md).
