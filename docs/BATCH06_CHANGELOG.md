# Batch 06: Garden Background, Daily Reminders, Home Screen Widget

## Changes
- Restore `BoxFit.cover` at `lib/main.dart` for original immersive background.
- New `lib/platform/device_features.dart` MethodChannel Android bridge (`betterseed/device_features`).
- `native/android/kotlin/ReminderScheduler.kt` handles an inexact daily alarm and cancellation.
- `native/android/kotlin/ReminderReceiver.kt` posts local notifications and reschedules the next day.
- `native/android/kotlin/ReminderBootReceiver.kt` reschedules after boot, time or timezone change.
- `native/android/kotlin/BetterSeedWidget.kt` supplies a read-only launcher widget.
- `native/android/kotlin/MainActivity.kt` receives Flutter method calls, synchronizes the widget and handles Android 13+ runtime notification permission.
- `native/android/res/` has widget metadata, launcher widget layout, backgrounds, small notification icon.
- `scripts/prepare_android.py` modifies generated AndroidManifest, copies Kotlin classes + widget resources + launcher icons; idempotent.
- `scripts/verify_android_integration.py` asserts receiver/permission declarations and XML resources exist.
- `.github/workflows/android-apk.yml` runs the integration check before Flutter analysis and tests.
- New tests for the Dart method channel; Garden background test expects `BoxFit.cover`.

## Behaviour and tradeoffs
- Reminder = one user-chosen local time/day; inexact alarm, not exact-time guarantee.
- Widget shows stage (1–6), water, and daily checklist count, tapping opens app.
- Widget gets push updates when BetterSeed changes data; launcher also asks for periodic widget refresh every 30+ minutes (system-controlled). Previous day's completion displays zero after local midnight.
- Pin requests require Android 8+/launcher support; manual widget installation is supported otherwise.
- No new third-party dependencies. No background playing audio, no user tracking, no Internet requirement.

## Verify on device
- Install upgrade, ensure data remains.
- Turn reminder on, grant Android 13+ permission, choose a near-future test time. Check notification after app closed. Switch off and confirm cancellation.
- Add launcher widget, check updated counts after completing habits and watering.
- Confirm original crop, tree fixed root position and existing butterfly/firefly loop.

**Build verification:** Flutter SDK unavailable in authoring environment; CI must be green before this patch is considered device-tested.
