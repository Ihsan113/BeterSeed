"""Contract tests for signed Google Play AAB upload-ready Actions workflow."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]


class PlayWorkflowTests(unittest.TestCase):
    def test_aab_uses_persistent_signing_and_verifies_before_upload(self):
        workflow = (ROOT / '.github/workflows/android-apk.yml').read_text()
        order = [
            'python3 scripts/configure_android_signing.py',
            'flutter build appbundle --release',
            'python3 scripts/verify_signed_aab.py',
            'name: BetterSeed-GooglePlay-release-aab',
        ]
        positions = [workflow.index(needle) for needle in order]
        self.assertEqual(positions, sorted(positions))
        self.assertIn('BETTERSEED_KEYSTORE_BASE64: ${{ secrets.BETTERSEED_KEYSTORE_BASE64 }}', workflow)
        self.assertIn('BETTERSEED_PINNED_SHA1: ${{ vars.BETTERSEED_PINNED_SHA1 }}', workflow)
        self.assertIn("if: github.event_name != 'pull_request'", workflow)
        self.assertIn('build/app/outputs/bundle/release/app-release.aab', workflow)
        self.assertIn('if-no-files-found: error', workflow)

    def test_existing_apk_pipeline_kept(self):
        workflow = (ROOT / '.github/workflows/android-apk.yml').read_text()
        self.assertIn('flutter build apk --release', workflow)
        self.assertIn('python3 scripts/verify_signed_apk.py', workflow)
        self.assertIn('name: BetterSeed-stable-release-apk', workflow)

    def test_play_bundle_and_target_are_consistent(self):
        pubspec = (ROOT / 'pubspec.yaml').read_text()
        self.assertRegex(pubspec, r'(?m)^version:\s*1\.7\.0\+58\s*$')
        readme = (ROOT / 'README.md').read_text()
        self.assertIn('1.7.0+58', readme)
        configure = (ROOT / 'scripts/configure_play_sdk.py').read_text()
        self.assertIn('PLAY_API_LEVEL = 36', configure)
        workflow = (ROOT / '.github/workflows/android-apk.yml').read_text()
        self.assertIn('python3 scripts/configure_play_sdk.py', workflow)


if __name__ == '__main__':
    unittest.main()
