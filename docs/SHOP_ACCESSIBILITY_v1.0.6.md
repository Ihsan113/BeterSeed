# BetterSeed v1.0.6 — Shop Accessibility Fix

Source baseline: v1.0.5 Clean Assets, **19 image files**.

## Reproduced CI issues
- Run 40108265488, job 120914390739: `flutter analyze` passed.
- 40 widget test assertions passed, two tests failed:
  - Shop cards with enlarged text: 28px horizontal overflow at `moonlight_tree_skin`.
  - Featured banner with enlarged text: 53px horizontal overflow on `How to use` Row and 4px vertical overflow in category carousel.

## Source corrections
- `lib/widgets/shop_page.dart`: flexible How to use heading and auto-growing category strip.
- Adapt 1/2/3-column card layout based on available width and text scale.
- Constrain each product tag to its actual card width; preserve ellipsis.
- `test/shop_page_test.dart`: add full catalogue 320px × 640px / 2x scale rendering check.
- `pubspec.yaml`: version `1.0.6+22`.

## Revalidation

`flutter analyze`

`flutter test --reporter expanded`

`flutter build apk --debug`

Tests still check real Flutter rendering exceptions; no errors or assertions are suppressed. Existing app features, preferences, native Android integration, and cosmetic assets were left intact.
