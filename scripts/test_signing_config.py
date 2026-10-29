"""Portable signing safety tests; no signing passwords or key materials."""
import unittest
from configure_android_signing import patch_gradle, SigningSetupError, _java_property

STOCK = '''plugins {
    id("com.android.application")
}

android {
    namespace = "com.betterseed.app"

    defaultConfig {
        applicationId = "com.betterseed.app"
    }

    buildTypes {
        release {
            // Signing with the debug keys for now
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}
'''


class SigningConfigurationTests(unittest.TestCase):
    def test_stock_flutter_template_patched_for_release(self):
        patch = patch_gradle(STOCK)
        self.assertIn('create("betterseedRelease")', patch)
        self.assertIn('signingConfig = signingConfigs.getByName("betterseedRelease")', patch)
        self.assertNotIn('signingConfigs.getByName("debug")', patch)
        self.assertIn('rootProject.file("key.properties")', patch)

    def test_patch_is_idempotent(self):
        modified = patch_gradle(STOCK)
        self.assertEqual(patch_gradle(modified), modified)

    def test_unexpected_gradle_template_fails_closed(self):
        with self.assertRaises(SigningSetupError):
            patch_gradle(STOCK.replace('getByName("debug")', 'getByName("something")'))

    def test_java_property_password_escaping(self):
        self.assertEqual(_java_property(r'a=b:c #\\z'), r'a\=b\:c\ \#\\\\z')
        with self.assertRaises(SigningSetupError):
            _java_property('secret\nsecond line')


if __name__ == '__main__':
    unittest.main()
