"""Validate narrowly scoped Android Auto Backup and offline SAF integration."""
import unittest
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]


class AndroidBackupPolicyTests(unittest.TestCase):
    def test_android_12_and_prior_select_only_flutter_prefs(self):
        old = ET.parse(ROOT / 'native/android/res/xml/betterseed_backup_rules.xml').getroot()
        self.assertEqual(old.tag, 'full-backup-content')
        self.assertEqual([(e.attrib.get('domain'), e.attrib.get('path')) for e in old.findall('include')],
                         [('sharedpref', 'FlutterSharedPreferences.xml')])
        current = ET.parse(ROOT / 'native/android/res/xml/betterseed_data_extraction_rules.xml').getroot()
        self.assertEqual(current.tag, 'data-extraction-rules')
        for section in ('cloud-backup', 'device-transfer'):
            self.assertEqual([(e.attrib.get('domain'), e.attrib.get('path')) for e in current.findall(f'{section}/include')],
                             [('sharedpref', 'FlutterSharedPreferences.xml')])

    def test_android_file_picker_is_manual_and_safe(self):
        kotlin = (ROOT / 'native/android/kotlin/MainActivity.kt').read_text()
        self.assertIn('Intent.ACTION_CREATE_DOCUMENT', kotlin)
        self.assertIn('Intent.ACTION_OPEN_DOCUMENT', kotlin)
        self.assertIn('openInputStream(uri)', kotlin)
        self.assertIn('openOutputStream(uri, "wt")', kotlin)
        self.assertIn('backupMaxBytes = 4 * 1024 * 1024', kotlin)
        self.assertNotIn('googleapis', kotlin)

    def test_google_identity_returns_without_legacy_drive_access(self):
        deps = (ROOT / 'pubspec.yaml').read_text()
        workflow = (ROOT / '.github/workflows/android-apk.yml').read_text()
        source = (ROOT / 'lib/main.dart').read_text()
        self.assertIn('google_sign_in:', deps)
        self.assertIn('BETTERSEED_GOOGLE_WEB_CLIENT_ID', workflow)
        self.assertNotIn('DriveBackupService', source)
        self.assertIn('BETTERSEED_PINNED_SHA1', workflow)


if __name__ == '__main__':
    unittest.main()
