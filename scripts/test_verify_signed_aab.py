"""AAB verification regressions: reject missing signatures, signer changes."""
import tempfile
from pathlib import Path
import unittest
import zipfile

from verify_signed_aab import (
    AppBundleVerificationError, inspect_bundle, normalize_sha1,
    parse_jar_verification, parse_upload_certificate,
)

FINGERPRINT = '0A:' * 19 + '0A'
SAMPLE_CERT = f'''Signer #1:

Certificate #1:
Owner: CN=BetterSeed Upload
Issuer: CN=BetterSeed Upload
Certificate fingerprints:
\t SHA1: {FINGERPRINT}
\t SHA256: 00:11
'''


class VerifySignedAabTests(unittest.TestCase):
    def test_accepts_verified_jar_and_one_upload_signer(self):
        parse_jar_verification(' s = signature was verified\njar verified.\n', 0)
        self.assertEqual(parse_upload_certificate(SAMPLE_CERT), normalize_sha1(FINGERPRINT))

    def test_rejects_unsigned_aab_even_when_jarsigner_exits_zero(self):
        with self.assertRaises(AppBundleVerificationError):
            parse_jar_verification('jar is unsigned.\n', 0)
        with self.assertRaises(AppBundleVerificationError):
            parse_jar_verification('jar verified.\n', 0)
        with self.assertRaises(AppBundleVerificationError):
            parse_jar_verification(' s = signature was verified\njar verified.\nThis jar contains unsigned entries which have not been integrity-checked.\n', 0)

    def test_rejects_second_signer_or_bad_fingerprint(self):
        with self.assertRaises(AppBundleVerificationError):
            parse_upload_certificate(SAMPLE_CERT + '\nSigner #2:\n')
        with self.assertRaises(AppBundleVerificationError):
            parse_upload_certificate(SAMPLE_CERT.replace('SHA1: ' + FINGERPRINT, 'SHA1: ABCD'))

    def test_rejects_invalid_aab_structure(self):
        with tempfile.TemporaryDirectory() as temp:
            file = Path(temp) / 'app-release.aab'
            with zipfile.ZipFile(file, 'w') as z:
                z.writestr('some-file', 'x' * 8192)
            with self.assertRaises(AppBundleVerificationError):
                inspect_bundle(file)


if __name__ == '__main__':
    unittest.main()
