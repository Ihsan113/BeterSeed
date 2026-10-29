# BetterSeed Batch 03 — manual acceptance checklist

## Functionality

- [ ] GitHub Actions `flutter analyze` returns 0 issues.
- [ ] GitHub Actions `flutter test` returns 0 failures.
- [ ] GitHub Actions debug APK builds and installs.
- [ ] All 3 bottom tabs work, active tab highlights, and back button behavior is sensible.
- [ ] One tick adds exactly one water; same-day untick/retick adds zero extra.
- [ ] Next day resets the daily checkbox but permits fresh award.
- [ ] Tap Water consumes 1 drop and gives 10 XP; cannot go negative.
- [ ] Tree changes stage after crossing XP boundary; XP and water survive app relaunch.
- [ ] A previously upgraded v0.2.1 install preserves existing habit names and XP.
- [ ] Statistics reflect only credited daily completions and use local calendar days.

## Layout / animation

- [ ] 360x640, 393x873 and 432x960 display comfortably without overflow.
- [ ] Tree roots stay fixed when watering, changing stages, opening Settings, and switching tabs.
- [ ] Water stream visually reaches the tree roots; background remains visible on Garden.
- [ ] Checklist with 0, 3, 20 items scrolls without covering bottom tabs.
- [ ] Stats works with 0 and with many completed habits.
- [ ] Reduced-motion mode disables wind, particles and watering animation but rewards still work.

## Audio

- [ ] Music persists across Garden → Checklist → Stats → Garden and opening/closing Settings.
- [ ] SFX on checkbox and Water does not pause/stop music.
- [ ] Repeated toggling of Music/SFX does not crash or deadlock.
- [ ] Backgrounding app pauses music; returning resumes from the current position.
- [ ] Other apps' incoming calls/focus changes work as expected on test device.
- [ ] Mute settings remain after close and restart.

## Packaging

- [ ] All 6 tree stages and the forest backdrop are bundled and visible.
- [ ] `assets/audio/water.ogg` present and plays when watering.
- [ ] Build job prints actual APK size; verify size on device.
