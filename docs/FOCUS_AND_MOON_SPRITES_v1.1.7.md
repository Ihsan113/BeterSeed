# BetterSeed v1.1.7 — Moonlight size & Focus Mode

## Tree visual repair
- Root problem: the Moonlight graphics contain large transparent margins. A CSS/widget 14% scale increase did not fix the visible sprite content.
- Every one of the six Moonlight stage sprites has been cropped to its *visible content* and normalized against the corresponding Default stage dimensions, then re-centered into the original 512×512 transparent canvas.
- Their soil/contact baseline matches that stage in Default.
- Android widget Moonlight imagery has been regenerated from the same corrected content.
- Dart no longer applies theme-specific tree scaling; both packs use one scene geometry.

## Focus Mode
- Fullscreen button is available while viewing Garden.
- Hides header, progression UI, water card and bottom navigation.
- Hides Android system bars using immersive sticky mode where supported.
- The exit button and Android Back return to standard Garden layout.
- Uses the selected pack and existing animation preferences; no separate tree stage or duplicate asset.

## QA
- Added widget tests for entering/exiting Focus Mode and a compact 320×640 screen.
- Verified the source tree asset bounds and aligned roots for all six stages.
- The native Android widget and reminder code remain unchanged except for six updated Moonlight art files.
