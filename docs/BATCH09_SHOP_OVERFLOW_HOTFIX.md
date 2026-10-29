# BetterSeed v0.9.1 — Featured Shop banner overflow hotfix

Root cause from GitHub Actions run 40098818794, job 120886563538:
`RenderFlex overflowed by 6.0 pixels on the bottom`, `lib/widgets/shop_page.dart:341`.
The fixed 213-pixel featured card was too short for badge, two-line title, description, button and padding.
Shop's `IndexedStack` child is laid out even when other tabs are active, so one Shop overflow caused navigation tests to fail as well.

Fix: increase the card's base height to 246 px and reserve additional height with accessibility text scaling. Shop content is in a scrollable page, so it stays accessible on compact devices. Added a compact-screen card-height regression test.

Validation: source and ZIP integrity checked locally; Flutter SDK unavailable here, so `flutter analyze`, `flutter test`, and actual APK build require GitHub Actions.

No monetization or billing behavior was changed.
