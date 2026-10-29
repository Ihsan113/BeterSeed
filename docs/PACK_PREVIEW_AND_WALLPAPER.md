# Pack previews and garden wallpaper

Based on GitHub `main` at `c539cf4` (1.4.11+48), including Golden Autumn.

## Preview a pack

Every Shop and My Collection card has **Preview pack**, including unowned packs.
The preview starts at the user's current growth stage. Previous/Next shows all
six stages, along with the background, butterflies, watering can and fireflies.
Sakura and Golden Autumn use their local muted videos when motion is enabled;
reduced motion and unavailable video decoding retain the bundled poster.
Closing the preview does not claim, equip, spend water, change XP or save any
cosmetics. Existing claim/equip actions remain on the cards.

`GardenAppearance` resolves the same assets for the actual garden and preview.
`ShopLoadout` now lives in `lib/data/shop_loadout.dart`; the Shop library exports
it for compatibility with existing callers.

## Set wallpaper

Open **Settings → Widget & Display → Garden wallpaper**. Review the current
garden, choose **Home screen**, **Lock screen** or **Both**, then tap
**Set wallpaper**. This is a still image; repeat the action after further growth
or cosmetic changes to update the wallpaper.

The image retains the live garden's viewport, saved tree position, scale and
mixed assets. App controls, text, navigation and transient watering effects are
excluded. Video backgrounds use their full-resolution poster. Rendering is
bounded to 2560 pixels on the longest side and uses no gallery or external files.

The Android bridge validates the PNG and dimensions, checks device policy, and
applies only the requested target with `WallpaperManager` on a worker thread.
It reports success only after Android returns a successful wallpaper ID. Double
taps are prevented. No storage or network permission is added; `SET_WALLPAPER`
is a normal Android permission integrated by `scripts/prepare_android.py`.
Wallpaper availability and final launcher crop can depend on the device.

## Validation

Run `flutter analyze`, `flutter test --reporter expanded`, and
`python3 -m unittest discover -s scripts -p 'test_*.py' -v`.
New tests cover all four packs, six stages, unchanged saved state, reduced motion,
large text, wallpaper targets and restrictions, real PNG capture without UI,
duplicate taps, native-result handling and saved tree coordinates.

Generate Android with `python3 scripts/generate_android.py` only when `android/`
is absent, then run `python3 scripts/prepare_android.py`,
`python3 scripts/verify_android_integration.py` and `flutter build apk --debug`.
Before release, check Home/Lock/Both and a restricted-device failure on physical
Android devices; a mocked platform-channel test cannot verify launcher behavior.
