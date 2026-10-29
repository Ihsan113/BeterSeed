# BetterSeed v1.2.2 — APK Signature Verification Hotfix

## Problem
The v1.2.1 workflow could stop after a successful release APK build at
`python3 scripts/verify_signed_apk.py`, with `Expected exactly one valid signing certificate on the APK.`
That message conflated missing digest-text matches with multiple signers.

## Fix
- Validate the APK cryptographic signature using `apksigner verify --verbose --print-certs`.
- Parse the SHA-1 fingerprint in commonly used digest text formats, accepting duplicated reporting for the same signer only.
- If no parsable SHA-1 line is returned, run the supported `--print-certs-pem` mode and compute SHA-1 from the single X.509 certificate's DER bytes.
- **Fail closed** if APK verification fails, the certificate is ambiguous, multiple signers are present, or the fingerprint mismatches the pinned release keystore.
- Report expected vs actual SHA-1 when they disagree; neither is secret. No private keys or passwords are logged.
- Run additional pure-Python signing regression tests in GitHub Actions before Android build.
- Select Android SDK build tools by numeric version.

## Existing GitHub Secrets/Variables
No changes needed if they are already configured and were accepted by Configure persistent release signing.

## Important
This change does not rotate the signing key. **Never regenerate or replace the existing release JKS** for this hotfix.
Flutter analyze/test and APK verification must still be run on GitHub Actions to validate the resulting release.
