"""Guards for merged CI fixes, wallpaper layout and new Play identity."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class ReleaseIntegrationGuards(unittest.TestCase):
    def test_static_wallpaper_uses_per_pack_non_overlapping_butterflies(self):
        scene = (ROOT / 'lib/main.dart').read_text()
        geometry = (ROOT / 'lib/logic/garden_scene_geometry.dart').read_text()
        self.assertIn('GardenSceneGeometry.stillButterflies(', scene)
        self.assertIn('_buildStillButterflySprites(w, h)', scene)
        for key in ('sakura_butterfly', 'cosmic_butterfly', 'amber_butterfly'):
            self.assertIn(key, geometry)
        self.assertIn('class ButterflySpriteLayout', geometry)
        self.assertTrue((ROOT / 'test/wallpaper_butterfly_layout_test.dart').is_file())

    def test_branding_and_premium_contracts_coexist(self):
        main = (ROOT / 'lib/main.dart').read_text()
        shop = (ROOT / 'lib/widgets/shop_page.dart').read_text()
        self.assertIn('BetterSeedCoinStorePage(', main)
        self.assertIn('Icons.spa_rounded', main)
        self.assertIn('PREMIUM', shop)
        self.assertIn('com.betterseed.app',
                      (ROOT / 'scripts/generate_android.py').read_text())
        self.assertTrue((ROOT / 'assets/play_store_icon_512.png').is_file())


if __name__ == '__main__':
    unittest.main()
