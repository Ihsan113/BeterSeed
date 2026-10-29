"""Fast static guards for editor wiring; Flutter interaction tests run in CI."""
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

class AssetEditorGuards(unittest.TestCase):
    def test_shop_edit_action_and_save_cancel(self):
        shop = (ROOT / 'lib/widgets/shop_page.dart').read_text()
        main = ((ROOT / 'lib/main.dart').read_text() +
                (ROOT / 'lib/widgets/garden_editor_frame.dart').read_text())
        for marker in ('collection-edit-assets', 'onEditAssets'):
            self.assertIn(marker, shop)
        for marker in ('asset-editor-save', 'asset-editor-cancel',
                       'editor-draggable-tree', '_storageTreePlacements',
                       '_closeAssetEditor(save: false)',
                       'asset-background-choice', 'asset-tree-choice'):
            self.assertIn(marker, main)

    def test_sakura_planting_geometry_is_preserved(self):
        geometry = (ROOT / 'lib/logic/garden_scene_geometry.dart').read_text().replace('\n', ' ')
        self.assertIn('PlantingGround.sakuraGarden', geometry)
        self.assertIn('PlantingGround.sakuraGarden => .14', geometry)
        self.assertIn('? treeSize * .02', geometry)

if __name__ == '__main__':
    unittest.main()
