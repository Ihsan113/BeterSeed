# BetterSeed v0.2.1 — GitHub Actions analyzer hotfix

## Reported failure

```
error • The constructor being called isn't a const constructor. Try removing 'const' from the constructor invocation • lib/audio/ambient_audio.dart:33:27 • const_with_non_const
```

## Resolution

In `lib/audio/ambient_audio.dart`, change `const AssetSource('audio/forest_piano.ogg')` to `AssetSource('audio/forest_piano.ogg')`. `AssetSource` is not a const constructor in the pinned dependency constraints (`audioplayers: ^6.8.1`). No audio behavior is changed.

Version bumped to `0.2.1+3` to distinguish this ZIP from the broken one.

## Validation

The source code was checked for remaining `const AssetSource(...)` calls and the packaged ZIP contents were verified. Flutter/Dart SDK is not installed in this container, so compilation, `flutter analyze`, tests and APK build are **not** locally verified. GitHub Actions will run `flutter analyze`, `flutter test` and `flutter build apk --debug` using its Flutter install.
