# Batch 03 — Three-tab navigation + Water-driven growth

## Product flow

1. Garden: tree scene, XP/stage, water count in header; Water/Earn action.
2. Checklist: recurring daily tasks; each completed habit grants exactly one water drop per local day.
3. Garden: spend each drop explicitly to animate watering (1 water -> +10 tree XP). New visual stage is cross-faded on the same rooted baseline.
4. Stats: cumulative credited completions / water, streak, calendar-day bar chart (last seven days), tree progression.

## State model

- `lib/logic/water_progress.dart` handles award deduplication, spending, XP, streak and JSON round-trip.
- New preference: `betterseed_water_progress_v3` (v3 JSON wallet + historical daily credited IDs + XP).
- Legacy `betterseed_habits_v1`, `betterseed_xp_v1`, `betterseed_day_v1` retained for migration. XP is preserved; no water is fabricated for old completions.
- Habits completion resets on local date change. Per-day awards are immutable once credited, preventing rapid untick/retick farming. Deleting a habit does not roll back or duplicate already-earned water.
- SharedPreferences snapshots are persisted through a serialized write queue.

## Audio fix details

- One `AmbientAudio` instance lives at `GrowthHome` rather than being created per page.
- The background music player and SFX player are separate.
- SFX player uses `AudioContextConfig(focus: AudioContextConfigFocus.none)` so Android SFX do not request a competing focus. Ambient audio uses the music player's own focus configuration.
- Music pause/resume operations are serialized and check current desired state. `inactive` lifecycle transitions do not interrupt the music: only paused/hidden/detached stop foreground audio.
- Tab navigation never calls audio stop/start. Sound settings still persist locally.
- Added `assets/audio/water.ogg` sound effect and extended asset tests.

## Rendering decisions

- Each tab occupies the same bounded content area with `IndexedStack`.
- Garden tree roots are anchored to the same `bottom:` world position regardless of UI changes. Wind rotation uses `Alignment.bottomCenter` pivot only; stage transitions fade rather than scale or translate the tree.
- Soil contact shadow and grass foreground overlap the same baseline; watering droplets are a `CustomPainter` overlay with no influence on layout.
- Garden controls are a short glass panel above a consistent 3-item navigation bar. Both are outside the tree canvas.

## Verification

- Added pure `WaterProgress` unit tests (once/day, next day, spending, persistence, streak, legacy XP, malformed balance).
- Added navigation widget test for tabs/checkbox/water/stats; disabled continuous animations during test.
- Asset existence tests now include water SFX. Source/asset and bracket checks performed locally.
- Flutter tools are unavailable in the preparation environment; analyzer, tests and Android APK still need CI.
