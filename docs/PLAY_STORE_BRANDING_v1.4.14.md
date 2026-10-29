# BetterSeed v1.4.14 — Package ID & app icons

## Identity

- **Name:** BetterSeed
- **Application ID / Android namespace:** `com.betterseed.app`
- **Generator:** `python3 scripts/generate_android.py` creates Android in an isolated Flutter temporary project via `--project-name app --org com.betterseed`, then copies only the Android scaffold. Do not run `flutter create .` at project root.
- **Kotlin package:** `com.betterseed.app` (native Android reminder, widget, wallpaper, file/backup channels)

**IMPORTANT:** Confirm the app ID is unique and matches the intended Google Play listing before your *first* upload. A published Google Play listing cannot change application ID; a different ID is a separate app. Changing `com.example.betterseed` to `com.betterseed.app` also makes Android treat it as a different app, so locally stored habits and owned pack flags do NOT migrate automatically. Export a SAF backup before switching IDs and restore it after installing the newly identified app where supported. In-app purchase verification and production security are a separate task and not solved by an identity change.

## Icon choices

See `assets/branding/PILIHAN_ICON_BETTERSEED.jpg` for a comparison.

1. **Emerald (applied)** — mint sprout with dark emerald gradient, premium natural theme.
2. **Sunrise (optional)** — mint sprout on a sunset-lilac background.
3. **Minimal Ivory (optional)** — green sprout on a light ivory gradient.

Each has two variations: `concept_<name>_rounded.png` (legacy/preview rounded-square) and `concept_<name>_full_square.png` (unrounded full bleed).

## Launcher Android

- `assets/android_icons/mipmap-*` has density-specific `ic_launcher.png` and `ic_launcher_round.png` for legacy devices.
- `assets/android_icons/mipmap-anydpi-v26/` has both adaptive launcher XML definitions.
- `assets/android_icons/drawable-nodpi/` has independent background, foreground, and monochrome icon layers. The system/launcher masks them into a circle or rounded-square depending on OS, launcher and theme.
- `scripts/prepare_android.py` copies all icon resources, including adaptive XML, and declares `android:roundIcon`.

## Google Play Store artwork

Upload **`assets/play_store_icon_512.png`** to Play Console as the listing icon (512×512, full bleed square, RGB/PNG). **Do not bake rounded corners into Play listing art:** Play applies the final shape and shadow.

## Verification

```bash
python3 -m unittest discover -s scripts -p 'test_*.py' -v
python3 scripts/verify_android_integration.py --sources
python3 scripts/generate_android.py
python3 scripts/prepare_android.py
python3 scripts/verify_android_integration.py
flutter pub get
flutter analyze
flutter test
```

Generate a new Android platform when starting from this source-only ZIP (the generated `android/` is intentionally not in the ZIP). The existing Android signing keystore is preserved, with no new key generated automatically.
