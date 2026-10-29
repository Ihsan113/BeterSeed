# BetterSeed v1.1.0 — Theme Bundles

## Flow
Shop -> Claim Moonlight Night Pack (FREE) -> My Collection -> Use -> Garden.
Original Garden is always owned, and can be equipped again at any time.
Claim does NOT equip automatically.

## Moonlight pack includes
- 6 moonlight growth sprites
- Night backdrop with independent 9:16 framed ground
- Cosmic butterfly, celestial watering can, prism firefly palette
- Gentle cyclic moonlight ambience (ripples, drifting leaves)
- Android widget art + background for all six growth stages

## Stage up
Water is earned through habits, spent on a tree. On reaching a threshold,
the tree crossfades/scales from the rooted bottom anchor; a congratulatory
modal appears. Disabling Living garden minimizes motion.

## Migration
Previous isolated cosmetics are converted to full Moonlight Pack ownership.
Existing user habits/water/XP/reminders remain on device.
All prototype packs are FREE; no real Play Billing is connected.

## Technical note
Android home-screen widgets are event-driven snapshots. They update their
background and stage when saved from the app, but do not render continuous
Flutter animation. Real-time loops are confined to the in-app Garden.

## Build
Extract ZIP contents to repository root, git add -A to remove unused assets,
run GitHub Actions for flutter analyze, flutter test, and APK build.
