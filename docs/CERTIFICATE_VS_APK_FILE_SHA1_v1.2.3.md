> **Historical documentation:** Since BetterSeed **v1.4.14+51** the new Android package ID is `com.betterseed.app`, not `com.example.betterseed`. Previous upgrade examples for the old package apply only to earlier builds. See `docs/PLAY_STORE_BRANDING_v1.4.14.md`.

# BetterSeed v1.2.3 — Certificate SHA-1 vs. APK File SHA-1

## Diagnosis of GitHub Actions run 40160645238

The latest build **passed** Flutter tests and cryptographic release APK verification. The log reports:

`Signed release APK verified using 37.0.0 (certificate PEM); SHA-1: 34:9A:50:D0:1E:15:96:4B:B3:FE:CE:51:B9:B7:0B:6F:04:B6:CD:81`

**This is the correct permanent Android signing certificate fingerprint.**

The SHA-1 shown by MT Manager's *Checksum* dialog is a SHA-1 hash **of the full APK file bytes**. It changes when the APK changes between builds even if signing remains identical. This is not an Android OAuth SHA-1.

## What changed

- GitHub Actions exports `CERTIFICATE_SHA1_README.txt` next to the release APK.
- The report clearly distinguishes signing certificate SHA-1 from file checksum SHA-1 and SHA-256.
- GitHub Actions Job Summary displays the **signing certificate SHA-1** to copy into Google Cloud.
- No signing configuration, keystore, alias, or private credentials have been changed.
- The workflow still refuses to publish if the verified signing certificate differs from the pinned SHA-1.

## How to verify on Android

Use an APK-signature inspection tool to view the **Signer Certificate SHA-1**. Don't use file managers' Checksum / MD5 / SHA1 menus for Android OAuth.

## OAuth configuration

Google Cloud Console -> OAuth Android client:

- Package: `com.example.betterseed`
- **Certificate SHA-1**: `34:9A:50:D0:1E:15:96:4B:B3:FE:CE:51:B9:B7:0B:6F:04:B6:CD:81`

Keep the original `betterseed-release.jks` and the existing GitHub Secrets. **Do not create a new keystore or rotate the pinned fingerprint.**

If Google Drive login still fails, investigate Android OAuth registration, release Web client ID in the build, Drive API and test-user consent status separately — SHA-1 file checksums don't diagnose those failures.
