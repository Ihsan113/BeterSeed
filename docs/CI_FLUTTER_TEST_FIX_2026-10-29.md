# Flutter test CI diagnosis — 2026-10-29

Source baseline: GitHub commit `aa4ac4effed44f41c1ebde03500b82e9894951e6` (run 40849893234).

The Flutter static analyzer was green. The run stalled on `flutter test --reporter expanded` and reported many failures.

Fixes in this ZIP:

- Move stale fixture image to Default Garden (Moonlight now lives in optional CDN archives).
- Show thumbnail previews in the editor for remote or locked Garden Packs, and block saving uninstalled content; do not send missing sprite paths to Image.asset.
- Compare exact signing/unlock payload against the registry appBuild (58), not the old hard-coded 57.
- Ensure real app widget tests wait for asynchronous initialization before asserting UI visibility.
- Eliminate `pumpAndSettle` from animated garden/editor tests, replacing it with bounded transition pumping.
- Run catalog networking and Flutter asset bundle awaits through `tester.runAsync` in widget tests.
- Limit the entire Flutter test step to 600 seconds so future hangs fail visibly instead of blocking signing and artifacts for the whole job.

Unchanged: backend, API, database, R2 pack manifest, shipping sprites, signing secrets and code, feature flags. The only app runtime change is the editor preview/fail-safe for uninstalled Garden Packs.

IMPORTANT: Flutter SDK is not installed in the packaging environment. Test and build results must be verified in GitHub Actions, and any remaining failing assertion should be repaired from the newly collected log rather than bypassed.
