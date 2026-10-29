# v1.0.5 Shop stability fix

## Why v1.0.4 failed

`test/shop_page_test.dart:76` called `tester.ensureVisible()` on a `ValueKey('shop-see-all')` that was not mounted. A `ListView` builds only children within its viewport/cache area; on a small screen, the Shop button is lower than that initial area. The test (not the app's normal tap interaction) therefore threw `Bad state: No element`.

## Structural changes

The current Shop contains only 5 cosmetics and does not need lazy building:

1. Outer vertical `SingleChildScrollView` and eager `Column` ensure the See all control is instantiated.
2. Responsive `Wrap` eagerly builds all 5 cards, and each card determines its own height. No nested lazy `GridView.builder` nor hardcoded grid row height.
3. The horizontal category strip stays independently scrollable (the only nested scrolling is horizontal, not vertical).
4. Regression tests validate all five items at 320×640, plus a 1.6× text scale. They continue to check `tester.takeException()` after layout and scrolling.

Do not replace those overflow tests with `warnIfMissed: false` or suppressing exceptions. The tests should fail when rendering genuinely overflows.

## CI boundary

The Flutter SDK is not installed in the artifact workspace, so only statically verifiable checks can run here. Final acceptance requires a successful GitHub Actions `flutter analyze`, `flutter test`, and debug APK build.
