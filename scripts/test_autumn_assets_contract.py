"""Golden Autumn app/delivery separation checks."""
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

class AutumnAssetsContractTests(unittest.TestCase):
    def test_remote_archive_is_recorded_but_not_in_flutter_bundle(self):
        meta = json.loads((ROOT/'assets/pack_downloads.json').read_text())['packs']['golden_autumn']
        self.assertGreater(meta['sizeBytes'], 1024 * 1024)
        self.assertEqual(len(meta['sha256']), 64)
        for rel in ('assets/videos/autumn_garden_loopy_8s.mp4',
                    'assets/images/backgrounds/golden_autumn_garden.webp',
                    'assets/images/effects/maple_watering_can.png'):
            self.assertFalse((ROOT/rel).exists(), rel)
        self.assertTrue((ROOT/'assets/images/shop/golden_autumn_pack_thumb.webp').exists())
        for i in range(6):
            self.assertFalse((ROOT/f'native/android/res/drawable-nodpi/widget_autumn_tree_{i}.webp').exists())

    def test_flutter_and_widget_wiring_present(self):
        main = (ROOT/'lib/main.dart').read_text()
        shop = (ROOT/'lib/widgets/shop_page.dart').read_text()
        backup = (ROOT/'lib/backup/backup_snapshot.dart').read_text()
        widget = (ROOT/'native/android/kotlin/BetterSeedWidget.kt').read_text()
        pub = (ROOT/'pubspec.yaml').read_text()
        self.assertIn('LocalPackVideoBackground(', main)
        self.assertIn('_storageOwnedAutumn', main)
        self.assertIn('GardenPackRegistry', shop)
        self.assertIn('ShopLoadout.autumnPack', (ROOT/'lib/data/garden_pack_registry.dart').read_text())
        self.assertIn('ownedAutumn', backup)
        self.assertIn('File(context.filesDir, "garden_packs").canonicalFile', widget)
        self.assertNotIn('- assets/videos/', pub)

if __name__ == '__main__':
    unittest.main()
