"""Tests for release APK signing verification (no keystores or credentials)."""
import base64
import hashlib
import tempfile
from pathlib import Path
import subprocess
import unittest
from unittest.mock import patch

from verify_signed_apk import (
    SignatureVerificationError,
    parse_signer_sha1,
    parse_single_pem_sha1,
    verify_apk,
    _build_tools_version,
    _file_digests,
    format_signing_report,
    _write_signing_report,
)

SHA = '349A50D01E15964BB3FECE51B9B70B6F04B6CD81'
OTHER = 'A' * 40


class SigningVerifierTests(unittest.TestCase):
    def test_standard_apksigner_digest(self):
        output = f'''Verifies\nVerified using v2 scheme (APK Signature Scheme v2): true\nSigner #1 certificate DN: CN=BetterSeed\nSigner #1 certificate SHA-1 digest: {SHA.lower()}\n'''
        self.assertEqual(parse_signer_sha1(output), SHA)

    def test_compatible_digest_variants(self):
        spaced = ':'.join(SHA[i:i+2] for i in range(0,40,2))
        self.assertEqual(parse_signer_sha1(f'Signer #1 certificate SHA1 digest: {spaced}\n'), SHA)
        self.assertEqual(parse_signer_sha1(f'SIGNER #1 CERTIFICATE SHA-1 DIGEST: {SHA}\n'), SHA)

    def test_repeated_same_signer_is_not_mistaken_for_multiple_signers(self):
        line = f'Signer #1 certificate SHA-1 digest: {SHA}\n'
        self.assertEqual(parse_signer_sha1(line * 2), SHA)

    def test_reject_multiple_signers(self):
        with self.assertRaisesRegex(SignatureVerificationError, 'one APK signer'):
            parse_signer_sha1(f'Signer #1 certificate SHA-1 digest: {SHA}\nSigner #2 certificate SHA-1 digest: {OTHER}\n')

    def test_reject_conflicting_digest_report(self):
        with self.assertRaisesRegex(SignatureVerificationError, 'conflicting'):
            parse_signer_sha1(f'Signer #1 certificate SHA-1 digest: {SHA}\nSigner #1 certificate SHA-1 digest: {OTHER}\n')

    def test_pem_fallback_computes_sha1_over_certificate_der(self):
        fake_der = bytes(range(256))
        pem = '-----BEGIN CERTIFICATE-----\n' + base64.b64encode(fake_der).decode() + '\n-----END CERTIFICATE-----'
        self.assertEqual(parse_single_pem_sha1(pem), hashlib.sha1(fake_der).hexdigest().upper())
        with self.assertRaises(SignatureVerificationError):
            parse_single_pem_sha1(pem + '\n' + pem)

    def test_verified_single_signer_with_pinned_fingerprint(self):
        output = f'Signer #1 certificate SHA-1 digest: {SHA}\n'
        with patch('verify_signed_apk.subprocess.run', return_value=subprocess.CompletedProcess([], 0, output, '')) as proc:
            self.assertEqual(verify_apk(Path('/fake.apk'), Path('/apksigner'), SHA), (SHA, 'digest'))
            self.assertEqual(proc.call_count, 1)

    def test_failure_on_wrong_certificate(self):
        output = f'Signer #1 certificate SHA-1 digest: {OTHER}\n'
        with patch('verify_signed_apk.subprocess.run', return_value=subprocess.CompletedProcess([], 0, output, '')):
            with self.assertRaisesRegex(SignatureVerificationError, 'differs'):
                verify_apk(Path('/fake.apk'), Path('/apksigner'), SHA)

    def test_unsigned_apk_does_not_pass_even_with_matching_sha1_text(self):
        output = f'Signer #1 certificate SHA-1 digest: {SHA}\n'
        with patch('verify_signed_apk.subprocess.run', return_value=subprocess.CompletedProcess([], 1, output, 'bad signature')):
            with self.assertRaisesRegex(SignatureVerificationError, 'cryptographic'):
                verify_apk(Path('/fake.apk'), Path('/apksigner'), SHA)

    def test_fallback_if_digest_line_unrecognized(self):
        der = b'\x30' + bytes([48] * 255)
        fingerprint = hashlib.sha1(der).hexdigest().upper()
        pem = '-----BEGIN CERTIFICATE-----\n' + base64.b64encode(der).decode() + '\n-----END CERTIFICATE-----'
        mock_outputs = [subprocess.CompletedProcess([], 0, 'Verifier output without digest line', ''),
                        subprocess.CompletedProcess([], 0, pem, '')]
        with patch('verify_signed_apk.subprocess.run', side_effect=mock_outputs) as proc:
            self.assertEqual(verify_apk(Path('/fake.apk'), Path('/apksigner'), fingerprint),
                             (fingerprint, 'certificate PEM'))
            self.assertEqual(proc.call_count, 2)
            self.assertIn('--print-certs-pem', proc.call_args_list[-1].args[0])

    def test_fallback_rejects_missing_certificate(self):
        mock_outputs = [subprocess.CompletedProcess([], 0, 'no recognized certificate digest', ''),
                        subprocess.CompletedProcess([], 0, 'no PEM certificates', '')]
        with patch('verify_signed_apk.subprocess.run', side_effect=mock_outputs):
            with self.assertRaisesRegex(SignatureVerificationError, '0 certificate'):
                verify_apk(Path('/fake.apk'), Path('/apksigner'), SHA)

    def test_certificate_vs_apk_checksum_are_not_confused(self):
        file_sha1 = 'A' * 40
        file_sha256 = 'B' * 64
        report = format_signing_report(SHA, file_sha1, file_sha256)
        self.assertIn('APK SIGNING CERTIFICATE SHA-1 (Google OAuth): 34:9A:50:', report)
        self.assertIn('APK FILE CHECKSUM SHA-1 (changes when file changes): ' + file_sha1, report)
        self.assertIn('not the APK file checksum', report)
        self.assertNotIn('BETTERSEED_KEYSTORE_PASSWORD=', report)

    def test_report_uses_verified_certificate_and_actual_file_bytes(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / 'app-release.apk'
            payload = b'example test artifact bytes'
            path.write_bytes(payload)
            sha1, sha256 = _file_digests(path)
            self.assertEqual(sha1, hashlib.sha1(payload).hexdigest().upper())
            self.assertEqual(sha256, hashlib.sha256(payload).hexdigest().upper())
            summary = Path(temp) / 'summary.md'
            with patch.dict('os.environ', {'GITHUB_STEP_SUMMARY': str(summary)}):
                _write_signing_report(path, SHA)
            report = (Path(temp) / 'CERTIFICATE_SHA1_README.txt').read_text()
            self.assertIn(':'.join(SHA[i:i+2] for i in range(0, 40, 2)), report)
            self.assertIn(sha1, report)
            self.assertIn('changes when file changes', report)
            self.assertIn('Google Cloud Android OAuth', summary.read_text())

    def test_select_numerically_latest_sdk_tool(self):
        self.assertGreater(_build_tools_version(Path('/sdk/build-tools/35.0.0/apksigner')),
                           _build_tools_version(Path('/sdk/build-tools/9.0.0/apksigner')))


if __name__ == '__main__':
    unittest.main()
