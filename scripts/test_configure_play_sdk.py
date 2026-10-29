"""Fail-closed tests for Play SDK 36 and stable Android package name."""
import unittest

from configure_play_sdk import PLAY_API_LEVEL, PlaySdkError, patch_play_sdk

STOCK = '''plugins { id("com.android.application") }
android {
    namespace = "com.betterseed.app"
    compileSdk = flutter.compileSdkVersion
    defaultConfig {
        applicationId = "com.betterseed.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
    }
}
'''


class PlaySdkConfigurationTests(unittest.TestCase):
    def test_generated_gradle_targets_google_play_api(self):
        content = patch_play_sdk(STOCK)
        self.assertIn(f'compileSdk = {PLAY_API_LEVEL}', content)
        self.assertIn(f'targetSdk = {PLAY_API_LEVEL}', content)
        self.assertIn('minSdk = flutter.minSdkVersion', content)
        self.assertEqual(patch_play_sdk(content), content)

    def test_refuses_package_name_rotation(self):
        with self.assertRaises(PlaySdkError):
            patch_play_sdk(STOCK.replace('com.betterseed.app', 'com.example.betterseed'))

    def test_refuses_unknown_gradle_layout(self):
        with self.assertRaises(PlaySdkError):
            patch_play_sdk(STOCK.replace('targetSdk = flutter.targetSdkVersion', 'targetSdkVersion(36)'))

    def test_keeps_future_higher_sdk(self):
        future = STOCK.replace('compileSdk = flutter.compileSdkVersion', 'compileSdk = 37')
        future = future.replace('targetSdk = flutter.targetSdkVersion', 'targetSdk = 37')
        out = patch_play_sdk(future)
        self.assertIn('compileSdk = 37', out)
        self.assertIn('targetSdk = 37', out)


if __name__ == '__main__':
    unittest.main()
