#!/usr/bin/env python3
"""Verify release APK signature and require the pinned signing certificate.

Trust apksigner for cryptographic APK signature validation, then compare the
single signing certificate's SHA-1 fingerprint with the pinned keystore SHA-1.
Supports both apksigner's digest output and its official PEM fallback.

No private key or keystore is read here; no fingerprint mismatch is ignored.
"""
from __future__ import annotations

import base64
import hashlib
import os
from pathlib import Path
import re
import subprocess
import sys


class SignatureVerificationError(RuntimeError):
    pass


_DIGEST_LINE = re.compile(
    r'^[ \t]*Signer[ \t]*#[ \t]*(\d+)[ \t]+certificate[ \t]+'
    r'SHA[ \t_-]*1[ \t]+digest[ \t]*:[ \t]*([A-Fa-f0-9: \t]+?)[ \t]*$',
    re.IGNORECASE | re.MULTILINE,
)
_PEM_CERT = re.compile(
    r'-----BEGIN CERTIFICATE-----\s*([A-Za-z0-9+/=\s]+?)\s*-----END CERTIFICATE-----',
    re.MULTILINE,
)


def _normalize_sha1(fingerprint: str) -> str:
    cleaned = re.sub(r'[^0-9a-fA-F]', '', fingerprint).upper()
    if len(cleaned) != 40:
        raise SignatureVerificationError('Invalid SHA-1 fingerprint (must be 40 hexadecimal characters).')
    return cleaned


def parse_signer_sha1(output: str) -> str | None:
    """Get ONE signer cert digest from apksigner output, or None for PEM fallback.

    Repeated lines for the same signer/certificate are accepted; different
    signing identities or conflicting digests are rejected rather than guessed.
    """
    found: dict[str, str] = {}
    for match in _DIGEST_LINE.finditer(output):
        signer_id = match.group(1)
        sha1 = _normalize_sha1(match.group(2))
        previous = found.get(signer_id)
        if previous is not None and previous != sha1:
            raise SignatureVerificationError('APK certificate report has conflicting SHA-1 values for one signer.')
        found[signer_id] = sha1
    if not found:
        return None
    if len(found) != 1:
        raise SignatureVerificationError(
            f'Expected one APK signer, found {len(found)} signer identities. Refusing to publish.'
        )
    return next(iter(found.values()))


def parse_single_pem_sha1(output: str) -> str:
    """Compute fingerprint directly from DER bytes in apksigner's verified PEM."""
    certificates = _PEM_CERT.findall(output)
    if len(certificates) != 1:
        raise SignatureVerificationError(
            f'Could not identify exactly one APK signing certificate: PEM output has '
            f'{len(certificates)} certificate(s).'
        )
    try:
        der = base64.b64decode(''.join(certificates[0].split()), validate=True)
    except ValueError as exc:
        raise SignatureVerificationError('Invalid certificate PEM returned by apksigner.') from exc
    if len(der) < 100:
        raise SignatureVerificationError('Certificate PEM returned by apksigner is incomplete.')
    return hashlib.sha1(der).hexdigest().upper()


def _run_apksigner(signer: Path, apk: Path, *, pem: bool = False) -> str:
    option = '--print-certs-pem' if pem else '--print-certs'
    result = subprocess.run(
        [str(signer), 'verify', '--verbose', option, str(apk)],
        capture_output=True, text=True, check=False,
    )
    output = '\n'.join(part for part in (result.stdout, result.stderr) if part)
    if result.returncode != 0:
        # Certificate digests are public; avoid echoing arbitrary command output.
        detail = ' (PEM fallback)' if pem else ''
        raise SignatureVerificationError(
            f'APK cryptographic signature verification failed{detail} '
            f'(apksigner exit code {result.returncode}).'
        )
    return output


def verify_apk(apk: Path, signer: Path, expected: str) -> tuple[str, str]:
    """Return (SHA-1, extraction method); never allow unverified/mismatched APKs."""
    expected = _normalize_sha1(expected)
    output = _run_apksigner(signer, apk)
    actual = parse_signer_sha1(output)
    method = 'digest'
    if actual is None:
        # Fallback uses Android's official --print-certs-pem option and computes
        # SHA-1 over the certificate bytes, independently of localized labels.
        pem_output = _run_apksigner(signer, apk, pem=True)
        actual = parse_single_pem_sha1(pem_output)
        method = 'certificate PEM'
    if actual != expected:
        raise SignatureVerificationError(
            'APK signing SHA-1 differs from the configured permanent keystore SHA-1; '
            f'expected {_display(expected)}, found {_display(actual)}. '
            'Artifact was NOT published.'
        )
    return actual, method


def _display(fingerprint: str) -> str:
    return ':'.join(fingerprint[i:i + 2] for i in range(0, 40, 2))


def _build_tools_version(path: Path) -> tuple[int, ...]:
    return tuple(int(n) for n in re.findall(r'\d+', path.parent.name))


def _file_digests(apk: Path) -> tuple[str, str]:
    """File-content digests are NOT signing-certificate fingerprints."""
    sha1, sha256 = hashlib.sha1(), hashlib.sha256()
    with apk.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            sha1.update(chunk)
            sha256.update(chunk)
    return sha1.hexdigest().upper(), sha256.hexdigest().upper()


def format_signing_report(certificate_sha1: str, apk_file_sha1: str,
                          apk_file_sha256: str) -> str:
    """Create a safe human-readable report with clearly distinguished identities."""
    certificate_sha1 = _display(_normalize_sha1(certificate_sha1))
    return (f'BetterSeed — Signed Release APK Fingerprints\n'
            f'============================================\n'
            f'APK SIGNING CERTIFICATE SHA-1 (Google OAuth): {certificate_sha1}\n'
            f'APK FILE CHECKSUM SHA-1 (changes when file changes): {apk_file_sha1}\n'
            f'APK FILE CHECKSUM SHA-256: {apk_file_sha256}\n'
            f'\n'
            f'IMPORTANT: Google Cloud Android OAuth needs the SIGNING CERTIFICATE SHA-1, '
            f'not the APK file checksum displayed by file managers.\n'
            f'Certificate has been verified cryptographically by apksigner and compared '
            f'to BETTERSEED_PINNED_SHA1 before this report was written.\n'
            f'Package: com.betterseed.app\n'
            f'No keystore, password, private key, or Base64 credentials are included.\n')


def _write_signing_report(apk: Path, certificate_sha1: str) -> None:
    """Only called after signature verification passed; publish safe certificate info."""
    checksum_sha1, checksum_sha256 = _file_digests(apk)
    report = format_signing_report(certificate_sha1, checksum_sha1, checksum_sha256)
    report_file = apk.parent / 'CERTIFICATE_SHA1_README.txt'
    report_file.write_text(report, encoding='utf-8')
    print(f'Certificate explanation saved to {report_file}')
    summary_path = os.environ.get('GITHUB_STEP_SUMMARY', '').strip()
    if summary_path:
        summary = (f'## BetterSeed signed APK verification ✅\n\n'
                   f'**Google Cloud Android OAuth — SIGNING CERTIFICATE SHA-1**\n\n'
                   f'`{_display(_normalize_sha1(certificate_sha1))}`\n\n'
                   f'APK file checksum SHA-1: `{checksum_sha1}` '
                   f'(different from certificate SHA-1; may change on every build).\n\n'
                   f'The signing certificate matches the pinned SHA-1. '
                   f'Keep the existing keystore and GitHub Secrets.\n')
        with Path(summary_path).open('a', encoding='utf-8') as out:
            out.write(summary)


def main() -> None:
    apk = Path('build/app/outputs/flutter-apk/app-release.apk')
    if not apk.is_file():
        raise SignatureVerificationError(f'Release APK missing: {apk}')
    expected = os.environ.get('BETTERSEED_EXPECTED_SIGNING_SHA1', '')
    if not expected:
        raise SignatureVerificationError('Pinned expected SHA-1 was not set by the signing configuration step.')
    sdk = Path(os.getenv('ANDROID_HOME') or os.getenv('ANDROID_SDK_ROOT') or '/opt/android-sdk')
    binaries = [p for p in (sdk / 'build-tools').glob('*/apksigner') if p.is_file()]
    if not binaries:
        raise SignatureVerificationError('Android build-tools apksigner not found. Check Android SDK.')
    signer = max(binaries, key=_build_tools_version)
    actual, method = verify_apk(apk, signer, expected)
    print(f'Signed release APK verified using {signer.parent.name} ({method}); SHA-1: {_display(actual)}')
    print('APK size: {:.2f} MiB'.format(apk.stat().st_size / 1048576))
    _write_signing_report(apk, actual)


if __name__ == '__main__':
    try:
        main()
    except SignatureVerificationError as error:
        print(f'::error::{error}', file=sys.stderr)
        sys.exit(1)
