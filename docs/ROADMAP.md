# BetterSeed — 12 batch delivery roadmap

## Product principles

1. **Working APK first.** Each batch changes one coherent feature group and ideally produces a testable artifact.
2. **Offline-first.** No mandatory account, online API, cloud sync, or subscriptions in the early batches.
3. **Game-quality look without a heavy game engine.** Central animated tree, ambient particles, layered scene, 30/60 FPS options later.
4. **No punitive streak mechanics.** Missing a day pauses growth; the tree does not die or erase earned XP.
5. **Financial goals are manual notes**, not bank transactions, financial advice, or proof that money was saved.
6. **Accessibility and adaptability** for smaller Android screens, text scale, and low-end devices.
7. **Monetization belongs in the final phase** only after the free experience is dependable.

| Batch | Deliverable | Must-pass acceptance criteria |
|---|---|---|
| 01 — Prototype + CI | Flutter source, 6 tree sprites, background, Android icon, local checklist XP, GitHub Actions debug APK | Checkout → analyze → test → debug APK uploaded; create/complete/check progress works on an actual phone |
| 02 — Living Scene | Better layer ordering, tree wobble and breathing, subtle light/fireflies, reduced motion toggle | Smooth and no UI overlap on small/large screens; motion stops when disabled |
| 03 — Habits & Goals CRUD | Create/edit/archive habits, target frequency, goals, SQLite migration | User input persists after force-close/reboot; validation and deletions tested |
| 04 — Growth Engine v2 | XP ledger, thresholds, milestones, staged transformation effects | No duplicate XP exploits; progress consistent across dates/timezones |
| 05 — Daily Routine | Daily/weekly schedules, resets, streak history and gentle recovery | Reset deterministic after midnight; timezone behavior tested |
| 06 — Savings Tracker | Target amounts, manual deposits, withdrawals, currency preference, separate goal tree | Totals accurate to cents; no false bank integration claims |
| 07 — Personal Garden | Multiple plant slots/goals, scene switching, save slot | Independent per-goal XP and garden state; efficient asset loading |
| 08 — Insights | Calendar, weekly/monthly charts, history, milestone log | Charts match activity data and empty states make sense |
| 09 — Reminders & Settings | Local notifications, scheduling, language structure, data export | Permissions requested appropriately; reminders work offline |
| 10 — Game-Art Polish | Refined stages, ambient scene, sounds (optional), smooth transitions, app icon | Low memory use, proper safe areas, reduced motion and mute support |
| 11 — Stabilization & Release | Error handling, accessibility, QA, performance profiling, signed build prep | Test matrix passes; stable signed build only after keystore configured |
| 12 — Monetization (LAST) | Optional cosmetic themes, fair Pro purchase, Play Store readiness | Free core remains useful; billing and restoration validated; policy review complete |

## Batch 01 handoff

- [x] Product roadmap and functional scope documented
- [x] Initial images generated and 6 tree stages separated
- [x] Flutter source prototype written
- [x] CI YAML and Android icon preparation script written
- [x] Basic unit tests drafted
- [ ] Real GitHub Actions build **not run** (requires committing to a repo)
- [ ] Android install / visual QA **not run**

Batch 01 is considered technically verified only once CI succeeds and the APK is installed and tested on a device.

## Batch 01 → 02 next steps

1. Upload ZIP contents to GitHub and trigger workflow.
2. Capture CI errors, if any, fix before adding features.
3. Install APK, test short/small screens, keyboard overlay, app resume, persistence.
4. Then start the living tree scene, movement settings, and layered parallax.

## Implementation update — Batch 03

Three-tab Garden / Checklist / Stats navigation, an offline one-drop-per-habit-per-day ledger, manual animated watering, weekly stats, a unique watering SFX, and audio-focus stabilization have been implemented in the source package. This advances a subset of the original habit, growth and statistics batches early for usability; deeper goals/savings and production polish remain planned. Monetization is still deferred.
