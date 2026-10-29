# CI follow-up — BetterSeed 1.7.0+58

Source base: `BetterSeed_CI_UnitTests_Fix_v1.7.0_58_clean.zip` (same tree as GitHub commit `10ce3daf5a993b5646c50463458b30e5d4fa3d76`).

GitHub Actions failure: run 40853806138, job 123379606315 (29 Oct 2026). `flutter analyze` succeeded, then `flutter test` reported 25 failures.

## Root causes and fixes

- 22 failures were the same `waitForGardenReady` failure (`shop-scroll` was not mounted). The initial `GrowthHome._load()` awaited the on-demand download storage scan before displaying any page; this storage access is not guaranteed to complete during fake-clock widget tests. Start CDN scan asynchronously and update automatically when it completes. Do not block the offline-first Garden on optional downloads.
- The remaining three `Shop claim` failures stemmed from `test/catalog_fixture.dart` returning a **free Default pack priced at 160**. `GardenOffer.fromJson` rejects a free item with a nonzero coin price, causing the entire catalog to be considered offline and disabling purchase buttons. Correct Default's fixture price to 0; add an explicit validity regression test and early fixture assertions.
- The readiness helper now permits platform file I/O to run briefly on a real asynchronous loop instead of just advancing FakeAsync time.

## Verified here

- Python contract tests and visual/Android source verifiers may run locally.
- The exact Flutter suite and signed AAB/APK still require Flutter + Android SDK on GitHub Actions; a passing build has **not** yet been observed.
- Backend/API/MySQL/VPS, release signing, and CDN pack content remain unchanged.

## After push

Run the existing Android workflow. `flutter analyze` then `flutter test` must pass before accepting AAB/APK artifacts. If new failures appear, use the precise step log and do not skip failing checks.

A non-blocking scan can overlap an early user-triggered download, so
`PackDownloadService.initialize()` now shares its in-flight initialization
future and resets it after an error (allowing retry). The Python regression
contracts verify these startup and fixture assumptions.
