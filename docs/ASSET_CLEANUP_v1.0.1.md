# Asset Cleanup Audit — BetterSeed v1.0.1

## Removed assets (11)

### Old Shop preview images no longer used (7)
- `assets/images/shop/ambient_effects.webp`
- `assets/images/shop/crystal_butterfly.webp`
- `assets/images/shop/garden_pass.webp`
- `assets/images/shop/golden_watering_can.webp`
- `assets/images/shop/moonlight_garden.webp`
- `assets/images/shop/season_packs.webp`
- `assets/images/shop/tree_skins.webp`

### Duplicate Shop previews replaced with references to live cosmetic assets (4)
- `assets/images/shop/butterfly_cosmic.png` → `assets/images/effects/butterfly_cosmic.png` (identical)
- `assets/images/shop/watering_can_celestial.png` → `assets/images/effects/watering_can_celestial.png` (identical)
- `assets/images/shop/moonlight_tree_skin.png` → `assets/images/trees/skins/moonlight/stage_5_legendary.png` (identical)
- `assets/images/shop/twilight_overlook.webp` → `assets/images/backgrounds/twilight_overlook.webp` (same visual, different compression)

## Kept intentionally
- All 6 default tree sprites and all 6 Moonlight Tree Skin sprites
- Both Garden backgrounds
- Default and cosmetic butterfly/watering-can image effects
- Firefly cosmetic preview, 6 OGG sound assets, app icon and 5 launcher icon densities
- All native Android widget images and sources, including CI build resources

## Source & test changes
- Shop asset references now use existing runtime files rather than duplicate previews.
- `test/shop_page_test.dart` checks the five active cosmetic preview images and all six Moonlight stages.
- Updated version to `1.0.1+17`.
- ZIP places `pubspec.yaml` and `.github/` directly at archive root for GitHub upload.

## Validation
- Image files validated with Pillow image decoder.
- Every explicit `assets/images/*` reference in Flutter source resolved to a file.
- No unreferenced images remain in `assets/images/` based on source scan.
- Native Android resource and visual assets verification scripts passed.
- `flutter analyze`, `flutter test`, and APK compilation require GitHub Actions.
