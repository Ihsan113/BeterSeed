# BetterSeed Batch 3 — v0.3.1 Analyze Hotfix

## Error received from CI
`undefined_enum_constant` at `lib/audio/ambient_audio.dart:29:59`: `AudioContextConfigFocus.none` not found.

## Fix
Replaced `AudioContextConfigFocus.none` with `AudioContextConfigFocus.mixWithOthers`.
This is a supported `audioplayers` 6.8.1 enum. On Android it maps to `AndroidAudioFocus.none` so SFX should not claim audio focus from the persistent music player.
Source: https://pub.dev/documentation/audioplayers/latest/audioplayers/AudioContextConfigFocus.html

## Verification
- Verified source replacement occurred once.
- Audited audio file references and bundled assets.
- ZIP integrity checked.
- Flutter SDK is not installed in local build environment; CI analyzer/tests/device verification outstanding.

## Build
Upload all files including hidden `.github` to the same GitHub repo. Trigger BetterSeed Android APK.
