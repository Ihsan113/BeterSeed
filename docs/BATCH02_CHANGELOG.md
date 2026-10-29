# Batch 02 — Responsive Tree Scene & Calming Audio

## User feedback addressed

- Old dashboard card could occupy up to **45% of the device height**. Replaced with a short preview dock; all habits stay available in a swipeable modal sheet.
- Old tree used center alignment and **vertical floating translation**, visually detaching the roots from the background. Replaced with bottom-anchored sprite, bottom-pivot wind sway, custom contact shadow and foreground grass strokes.
- Background previously had heavy dark fade; replaced with a lighter gradient to reveal landscape scenery.
- Settings now include music toggle, gentle SFX toggle and reduced-motion toggle. Preferences persist across restarts.
- Music automatically pauses when the app leaves foreground; resumes on return if enabled.
- Fixed likely text-controller lifetime bug: modal now owns/disposes its own controller after its exit animation instead of disposing while widget dependents remain mounted.
- Upgraded package with **audioplayers** to play fully local ambient music and SFX; no API key/backend needed.

## Source and audio

- User-supplied sample `piano-in-the-forest-308945.mp3` (~8.2 MB, 266 seconds) compressed for local use as `assets/audio/forest_piano.ogg` (~2.58 MB).
- Four synthesized original, light SFX `tap`, `complete`, `plant`, `growth` are bundled as short OGG clips.
- All six growth sprites retained as individual WebP files for automatic stage transitions.
- Audio is silent when switched off or in the background; playback failures are non-fatal.

## Known limitations

- Flutter SDK is **not installed in this editing environment**; CI build and on-device performance/appearance not yet verified for this revision.
- Tree is a 2.5D layered graphic; it does not have skeletal branch motion or a real-time Unreal-like engine.
- No savings goals, multiple gardens, stats, reminders, monetization, or cloud synchronization yet.
- Check rights for the user-provided soundtrack before public distribution. Prototype inclusion does not establish redistribution rights.
