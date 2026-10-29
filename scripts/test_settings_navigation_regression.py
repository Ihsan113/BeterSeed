#!/usr/bin/env python3
"""Static CI guard for the Settings layout and off-screen navigation regressions."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parent.parent

class SettingsCiRegressionTests(unittest.TestCase):
    def test_settings_cards_paint_their_own_material(self):
        content = (ROOT / 'lib/main.dart').read_text(encoding='utf-8')
        section = content.split('Widget _settingsSectionCard({', 1)[1].split('\n  @override', 1)[0]
        self.assertIn('}) => Material(', section)
        self.assertNotIn('}) => _glassPanel(', section)
        self.assertIn('clipBehavior: Clip.antiAlias', section)

    def test_navigation_resets_scroll_position(self):
        content = (ROOT / 'lib/main.dart').read_text(encoding='utf-8')
        self.assertIn('scrollController.jumpTo(0)', content)

    def test_tap_tests_ensure_settings_items_are_visible(self):
        for name in ('garden_visual_settings_test.dart', 'reminder_master_guard_test.dart'):
            text = (ROOT / 'test' / name).read_text(encoding='utf-8')
            self.assertIn('await tester.ensureVisible(category)', text)
            self.assertIn('await tester.tap(category)', text)
            self.assertNotIn('warnIfMissed: false', text)

if __name__ == '__main__':
    unittest.main()
