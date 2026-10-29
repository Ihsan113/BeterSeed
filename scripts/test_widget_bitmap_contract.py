"""Regression contract for native Android widget CDN tree decoding.

This source check protects the bug fixed after on-device Golden Autumn tests.
It complements, but does not replace, the real Android widget test.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]

class NativeWidgetBitmapContract(unittest.TestCase):
    def test_sample_size_is_nonzero_before_dividing(self):
        src = (ROOT/'native/android/kotlin/BetterSeedWidget.kt').read_text()
        self.assertRegex(src, r'val options\s*=\s*BitmapFactory\.Options\(\)\.apply\s*\{\s*inSampleSize\s*=\s*1\s*\}')
        first_use = src.index('bounds.outWidth / options.inSampleSize')
        init = src.index('val options = BitmapFactory.Options().apply { inSampleSize = 1 }')
        self.assertLess(init, first_use)
    def test_installed_tree_and_stage_remain_independent(self):
        src = (ROOT/'native/android/kotlin/BetterSeedWidget.kt').read_text()
        self.assertIn('pref.getString("widget_tree_asset", "")', src)
        self.assertIn('pref.getString("widget_tree_file", "")', src)
        self.assertIn('File(context.filesDir, "garden_packs").canonicalFile', src)
        self.assertIn('File(folder, "installed.json").isFile', src)
        self.assertIn('treeArt[stage - 1]', src)
        self.assertIn('Log.w("BetterSeedWidget"', src)

if __name__=='__main__':
    unittest.main()
