# BetterSeed v0.7.1 — Independent Garden motion

## Why Garden animation disappeared
`MediaQuery.disableAnimationsOf(context)` was used as a hard stop for all Garden effects. Android with system animations switched off can signal disabled animation to Flutter.

## Fix
- Preserve both looping wind/ambient effects and one-shot watering controllers through `AnimationBehavior.preserve`.
- Preserve Android reduced motion **by default**.
- Add independent explicit opt-in under Settings → **Keep Garden effects animated**.
- Keep the existing **Living garden** switch as the absolute kill switch.
- Store the override in `SharedPreferences` key `betterseed_game_motion_override_v1`.
- No Android permissions, server, or extra asset packages required.

## Testing on a phone
1. In Android developer settings, change Animator duration scale and other system animation scales to Off (0x).
2. Open BetterSeed, Garden, and Settings. With Living garden ON and override OFF, expected behavior when reduced-motion flag is delivered: static Garden.
3. Turn ON **Keep Garden effects animated**. Go to Garden and check butterflies, fireflies, and wind; water a tree and check the watering animation.
4. Turn OFF Living garden: no motion even when override is enabled.
5. Reopen the app: preferences should be saved. Switch tabs; audio and progress must remain unchanged.

These scenarios require a real Android build/device. `flutter analyze`, `flutter test`, and APK build are performed by GitHub Actions, not verified here.
