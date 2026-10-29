#!/usr/bin/env python3
"""Verify the signed Google Play release AAB before publishing Actions artifact.

AAB is a JAR-signed ZIP, unlike an APK. Do NOT use apksigner to verify AAB.
Compare the cryptographically verified signing cert with the persistent upload
key fingerprint from configure_android_signing.py. No secret material is emitted.
"""
from __future__ import annotations

import hashlib
import os
from pathlib import Path
import re
import subprocess
import sys
import zipfile

AAB = Path('build/app/outputs/bundle/release/app-release.aab')


class AppBundleVerificationError(RuntimeError):
    pass


def normalize_sha1(source: str) -> str:
    value = re.sub(r'[^0-9A-Fa-f]', '', source).upper()
    if len(value) != 40:
        raise AppBundleVerificationError('Upload certificate SHA-1 must contain 40 hex digits.')
    return value


def parse_jar_verification(output: str, exit_code: int) -> None:
    # jarsigner's exit code can be 0 for unsigned JARs; check positive proof.
    if (exit_code or 'contains unsigned entries' in output.lower()
            or not re.search(r'(?m)^jar verified\.$', output) or not re.search(
            r'(?m)^\s*s\s*=\s*signature was verified\s*$', output)):
        raise AppBundleVerificationError('AAB JAR signature is missing or failed cryptographic verification.')


def parse_upload_certificate(output: str) -> str:
    signer_ids = re.findall(r'(?m)^Signer\s+#(\d+):\s*$', output)
    if signer_ids != ['1']:
        raise AppBundleVerificationError('Expected exactly one AAB upload signing identity.')
    # Only fingerprint the first signer certificate, never a CA certificate.
    first_certificate = re.search(
        r'(?ms)^Signer\s+#1:\s*\n\s*Certificate\s+#1:\s*\n(.*?)(?=^Certificate\s+#2:|^Signer\s+#2:|\Z)',
        output,
    )
    if not first_certificate:
        raise AppBundleVerificationError('No upload signer certificate in keytool report.')
    fingerprints = re.findall(r'(?m)^\s*SHA1:\s*([0-9A-Fa-f:]+)\s*$', first_certificate.group(1))
    if len(fingerprints) != 1:
        raise AppBundleVerificationError('Could not identify one AAB upload certificate SHA-1.')
    return normalize_sha1(fingerprints[0])


def inspect_bundle(path: Path) -> None:
    if not path.is_file() or path.stat().st_size < 4096:
        raise AppBundleVerificationError(f'Release AAB missing, empty or suspiciously small: {path}')
    try:
        with zipfile.ZipFile(path) as archive:
            if archive.testzip():
                raise AppBundleVerificationError('AAB ZIP content failed integrity check.')
            names = set(archive.namelist())
    except (OSError, zipfile.BadZipFile) as exc:
        raise AppBundleVerificationError('Release AAB is not a valid ZIP archive.') from exc
    for required in ('BundleConfig.pb', 'base/manifest/AndroidManifest.xml'):
        if required not in names:
            raise AppBundleVerificationError(f'Missing required Android App Bundle member: {required}')
    if not any(name.startswith('base/dex/') or name.startswith('base/lib/') for name in names):
        raise AppBundleVerificationError('AAB base module has no compiled code or native library.')


def command(args: list[str]) -> tuple[int, str]:
    env = {**os.environ, 'LC_ALL': 'C'}
    result = subprocess.run(args, capture_output=True, text=True, check=False, env=env)
    return result.returncode, (result.stdout + '\n' + result.stderr)


def verify_bundle(path: Path, expected_sha1: str) -> str:
    expected_sha1 = normalize_sha1(expected_sha1)
    inspect_bundle(path)
    status, report = command(['jarsigner', '-verify', '-verbose', str(path)])
    parse_jar_verification(report, status)
    status, output = command(['keytool', '-printcert', '-jarfile', str(path)])
    if status:
        raise AppBundleVerificationError('Keytool failed to inspect the AAB upload certificate.')
    actual = parse_upload_certificate(output)
    if actual != expected_sha1:
        raise AppBundleVerificationError('AAB upload certificate differs from pinned release keystore. Refusing publication.')
    return actual


def main() -> None:
    expected = os.environ.get('BETTERSEED_EXPECTED_SIGNING_SHA1', '')
    if not expected:
        raise AppBundleVerificationError('Missing verified SHA-1 output from the signing configuration step.')
    actual = verify_bundle(AAB, expected)
    file_sha256 = hashlib.sha256(AAB.read_bytes()).hexdigest().upper()
    pubspec = Path('pubspec.yaml').read_text(encoding='utf-8')
    version = re.search(r'(?m)^version:\s*(\d+\.\d+\.\d+\+\d+)\s*$', pubspec)
    if not version:
        raise AppBundleVerificationError('Missing valid version in pubspec.yaml.')
    report = (f'BetterSeed Google Play Signed AAB\n'
              f'=============================\n'
              f'Package ID: com.betterseed.app\n'
              f'App version: {version.group(1)}\n'
              f'Target SDK API: 36 (set in generated Gradle; validate in Play Console)\n'
              f'Upload certificate SHA-1: {actual}\n'
              f'AAB file SHA-256: {file_sha256}\n'
              f'AAB file size: {AAB.stat().st_size} bytes\n'
              f'JAR signature validated using jarsigner and keytool.\n'
              f'Play App Signing uses its OWN app-signing certificate for distributed APKs.\n'
              f'No signing keys, passwords, or credentials are included.\n')
    report_file = AAB.parent / 'AAB_PLAY_UPLOAD_VERIFICATION.txt'
    report_file.write_text(report, encoding='utf-8')
    print(f'Google Play AAB cryptographically verified; SHA-256 {file_sha256}; size {AAB.stat().st_size} bytes')
    summary_path = os.environ.get('GITHUB_STEP_SUMMARY')
    if summary_path:
        with Path(summary_path).open('a', encoding='utf-8') as file:
            file.write('## Google Play upload AAB ready for internal testing\n\n'
                       f'`com.betterseed.app` — `{version.group(1)}`, target API 36.\n\n'
                       f'AAB SHA-256: `{file_sha256}`. Upload certificate SHA-1: `{actual}`.\n\n'
                       'Obtain **BetterSeed-GooglePlay-release-aab** from the Actions artifacts.\n')


if __name__ == '__main__':
    try:
        main()
    except AppBundleVerificationError as exc:
        print(f'::error::{exc}', file=sys.stderr)
        sys.exit(1)
