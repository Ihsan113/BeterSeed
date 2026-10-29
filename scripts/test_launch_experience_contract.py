"""Lightweight release guards; actual Flutter rendering runs in CI."""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


class LaunchExperienceContractTests(unittest.TestCase):
    def test_release_number_matches_changelog(self):
        pubspec = (ROOT / 'pubspec.yaml').read_text()
        versions = re.findall(r'(?m)^version:\s*(\d+\.\d+\.\d+\+\d+)\s*$', pubspec)
        self.assertEqual(len(versions), 1, 'pubspec must declare one valid app version')
        changelog = (ROOT / 'CHANGELOG.md').read_text()
        headers = re.findall(r'(?m)^## v(\d+\.\d+\.\d+\+\d+)\b', changelog)
        self.assertTrue(headers, 'CHANGELOG must include a version heading')
        self.assertEqual(headers[0], versions[0], 'Newest CHANGELOG release must match pubspec')

    def test_local_assets_used_by_splash_and_onboarding_exist(self):
        code = (ROOT / 'lib/widgets/launch_experience.dart').read_text()
        for filename in re.findall(r"['\"](assets/[^'\"]+\.(?:webp|png))['\"]", code):
            self.assertTrue((ROOT / filename).is_file(), filename)
        self.assertNotIn('http://', code)
        self.assertNotIn('https://', code)

    def test_replay_and_persistence_are_separate_from_garden_progress(self):
        code = (ROOT / 'lib/widgets/launch_experience.dart').read_text()
        main = (ROOT / 'lib/main.dart').read_text()
        self.assertIn('betterseed_onboarding_completed_v1', code)
        self.assertIn('Future<void> _finish()', code)
        self.assertIn('onShowWelcomeGuide', main)
        self.assertIn("ValueKey('settings-replay-onboarding')", main)
        self.assertIn('showLaunchFlow = true', main)
        self.assertIn('testWidgets(', (ROOT / 'test/launch_experience_test.dart').read_text())


if __name__ == '__main__':
    unittest.main()
