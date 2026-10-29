# BetterSeed v0.7.0 — Feature implementation notes

## Reminders
- Replaced the one global reminder time with a global master enable/disable switch and optional reminder times stored in each Habit.
- New Habit properties: `reminderEnabled` (default false), `reminderHour` (20), `reminderMinute` (0). Old JSON migrates with no data loss; original title, icon, completion status stay intact.
- Create/Edit dialog lets users opt in and select a time. Settings provides the master switch only.
- Android MethodChannel `syncHabitReminders` sends the complete persisted habit snapshot and today's local date.
- Native `ReminderScheduler` uses independent identity (`Intent.data`) per habit; cancels removed/edited alarms, schedules opt-in habits, and reschedules after reboot/device time changes.
- A habit completed earlier today suppresses that day's notification. On the next local calendar day, it becomes eligible again until completed.
- The notification permission is requested on master enabling for Android 13+; inexact alarms, no exact-alarm special privilege.

## Widget
- Replaced text-only native widget with BetterSeed-themed card and 6 WebP stage sprites.
- Stage artwork is selected by Android RemoteViews; water count, habits done, and horizontal progress update dynamically.
- Template adapts through weighted horizontal layout; native preview is included. Target 4x2 launcher cells with resizing supported.
- 7 new widget images are bundled in `native/android/res/drawable-nodpi`.
- Native source/resource verifier expanded for these new files.

## Quality
- New unit tests: per-habit JSON migration, independent reminders, platform-channel sync, and existing widget-channel behavior.
- Android file copier and manifest integration validated twice for idempotence in a clean simulated generated Android directory.
- Flutter analyze/test/build must still run on GitHub Actions; native Android alarm/widget behavior requires on-device validation.
