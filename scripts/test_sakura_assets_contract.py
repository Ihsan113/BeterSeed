"""Sakura remains content-complete after moving art out of the AAB."""
import io
import json
import struct
import unittest
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
NAMES = ('seed', 'sprout', 'sapling', 'young', 'mature', 'legendary')

class SakuraAssetsContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.manifest = json.loads((ROOT / 'assets/pack_downloads.json').read_text())['packs']['sakura']
        # Uploaded CDN payloads are in the separate delivery archive, not in the app sources.

    def test_six_sprite_paths_registered_for_on_demand_download(self):
        registry = (ROOT/'lib/data/garden_pack_registry.dart').read_text()
        self.assertIn("id: 'sakura'", registry)
        self.assertIn("treeFolder: 'assets/images/trees/skins/sakura'", registry)
        self.assertIn('sakura_pack_thumbnail.webp', registry)
        self.assertEqual(len(self.manifest['sha256']), 64)
        for i, name in enumerate(NAMES):
            self.assertFalse((ROOT/f'assets/images/trees/skins/sakura/stage_{i}_{name}.png').exists())

    def test_android_widget_supports_private_pack_images(self):
        source = (ROOT/'native/android/kotlin/BetterSeedWidget.kt').read_text()
        self.assertIn('garden_packs/$pack', source)
        self.assertIn('installed.json', source)
        for i in range(6):
            self.assertFalse((ROOT/f'native/android/res/drawable-nodpi/widget_sakura_tree_{i}.webp').exists())

    def test_video_and_static_background_are_remote_but_thumbnail_bundled(self):
        self.assertFalse((ROOT/'assets/videos/sakura_loop_5s.mp4').exists())
        self.assertFalse((ROOT/'assets/images/backgrounds/sakura_garden.webp').exists())
        self.assertTrue((ROOT/'assets/images/shop/sakura_pack_thumbnail.webp').exists())
        player = (ROOT/'lib/widgets/local_pack_video_background.dart').read_text()
        self.assertIn('VideoPlayerController.file', player)
        self.assertIn('GardenPackFiles.provider', player)

    def test_backup_editor_and_shop_still_support_sakura(self):
        main = (ROOT/'lib/main.dart').read_text()
        shop = (ROOT/'lib/widgets/shop_page.dart').read_text()
        self.assertIn('_storageOwnedSakura', main)
        self.assertIn('ShopLoadout.sakuraPack', (ROOT/'lib/data/garden_pack_registry.dart').read_text())
        self.assertIn('ownedSakura', (ROOT/'lib/backup/backup_snapshot.dart').read_text())
        self.assertIn('downloadSize', shop)
        self.assertIn('video_player:', (ROOT/'pubspec.yaml').read_text())

if __name__ == '__main__':
    unittest.main()
