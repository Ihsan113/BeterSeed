"""Regression contracts: stable Play ID, native alignment and launcher icon specs."""
import unittest
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
APP_ID = 'com.betterseed.app'


class BrandingContracts(unittest.TestCase):
    def test_permanent_app_id_in_generator_and_native(self):
        generator = (ROOT / 'scripts/generate_android.py').read_text()
        self.assertIn("'--project-name', 'app'", generator)
        self.assertIn("'--org', 'com.betterseed'", generator)
        prepare = (ROOT / 'scripts/prepare_android.py').read_text()
        self.assertIn('kotlin/com/betterseed/app', prepare)
        for src in (ROOT / 'native/android/kotlin').glob('*.kt'):
            self.assertTrue(src.read_text().startswith(f'package {APP_ID}\n'), src.name)
        self.assertIn('com.betterseed.app.HABIT_REMINDER', (ROOT / 'native/android/kotlin/ReminderScheduler.kt').read_text())

    def test_adaptive_icon_resources(self):
        icon_dir = ROOT / 'assets/android_icons'
        xml_dir = icon_dir / 'mipmap-anydpi-v26'
        for filename in ['ic_launcher.xml', 'ic_launcher_round.xml']:
            data = ET.parse(xml_dir / filename).getroot()
            self.assertEqual(data.tag, 'adaptive-icon')
            self.assertEqual([child.tag for child in data], ['background', 'foreground', 'monochrome'])
        for icon_name in ('ic_launcher_foreground.png','ic_launcher_background.png','ic_launcher_monochrome.png'):
            self.assertTrue((icon_dir / 'drawable-nodpi' / icon_name).is_file())
        for density in ('mdpi','hdpi','xhdpi','xxhdpi','xxxhdpi'):
            for icon in ('ic_launcher.png','ic_launcher_round.png'):
                self.assertTrue((icon_dir / ('mipmap-' + density) / icon).is_file())

    def test_store_icon_and_three_design_options_exist(self):
        import struct
        png = (ROOT / 'assets/play_store_icon_512.png').read_bytes()
        self.assertEqual(png[:8], b'\x89PNG\r\n\x1a\n')
        self.assertEqual(png[12:16], b'IHDR')
        self.assertEqual(struct.unpack('>II', png[16:24]), (512,512))
        for name in ('emerald', 'sunrise', 'ivory'):
            for suffix in ('full_square','rounded'):
                self.assertTrue((ROOT / 'assets/branding' / f'concept_{name}_{suffix}.png').exists())


if __name__ == '__main__':
    unittest.main()
