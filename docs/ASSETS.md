# BetterSeed — art & audio assets (Batch 02)

## Included

- `art_source/source_sprite_sheet.png`: editable/reference 3x2 progression atlas (not shipped in APK).
- `assets/images/trees/stage_0_seed.webp` .. `stage_5_legendary.webp`: six transparent 512x512 tree stages.
- `assets/images/backgrounds/enchanted_valley.webp`: optimized fantasy valley scenery.
- `assets/icon_512.png`, `assets/android_icons/mipmap-*`: app launcher icons.
- `assets/audio/forest_piano.ogg`: user-provided music compressed from 8.2 MB MP3 to approximately 2.58 MB OGG Vorbis, 266s long.
- `assets/audio/tap.ogg`, `complete.ogg`, `plant.ogg`, `growth.ogg`: original synthesized sound-effect samples.

## Placement, scaling and motion

- Background fills available screen via cover; it is *not* a foreground UI panel.
- Tree is sized from the scene's **real** BoxConstraints. The whole image is bottom aligned: its roots contact a ground-shadow gradient and the grass-paint foreground.
- No vertical bouncing. Sway rotation pivots at the bottom of the sprite to preserve root contact.
- Checklist dock shows up to two habits, one on short devices. Everything else is under **View all** to keep the landscape visible.
- Wind sway and low-density particle animation are optional; Flutter/system reduced-motion settings are respected.

## Ownership and licensing

- Generated game-art is an early prototype; verify trademark, art and visual identity before publishing.
- The ambient soundtrack was supplied by the user for this prototype. Confirm its music license and any required creator attribution before releasing a public APK or posting to an app store.
- Do not include audio source MP3 in the APK; only the compressed OGG is bundled.
