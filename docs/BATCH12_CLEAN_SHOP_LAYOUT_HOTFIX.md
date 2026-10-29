# BetterSeed v1.0.2 — Shop Layout & Test Hotfix

**Base: v1.0.1 Clean Assets** — retired images remain removed.

## GitHub Actions diagnosis

Run 40102084296, job 120896140407 failed six Flutter widget tests.
The primary failure was a `RenderFlex overflowed by 39 pixels` within
`lib/widgets/shop_page.dart` feature banner. Fixed 246-pixel height with
multi-line text, paddings and a button could not fit. Tests also referenced
old `Premium Garden Pass` text although the live Shop now uses a free cosmetic
starter catalogue; one tap was off-screen in a ListView.

## Corrections
- Replace fixed-height feature banner with minimum-height, content-sized card.
- Remove the `Spacer` that caused inflexible vertical layout overflow.
- Keep background image and tinted overlay without nested fixed-height Stack.
- Make the featured information sheet scroll if accessibility text is large.
- Increase cosmetic grid-card height and scale with accessibility text.
- Correct the navigation test to assert current Shop copy.
- Make `See all` test scroll before tapping an off-screen control.
- Add a text-scale regression case.

## Preserved
- 5 free cosmetic items and `Apply / In Use` state.
- 6 default and 6 moonlight tree stages.
- All active images and audio; the v1.0.1 asset cleanup remains intact.
- Notifications, Android widget, Garden, Checklist, Stats, local persistence.

## Verification
Run `flutter analyze`, `flutter test --reporter expanded`, and
`flutter build apk --debug` in GitHub Actions. This package has not been
compiled with Flutter locally.
