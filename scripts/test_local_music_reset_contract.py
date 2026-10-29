import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


class LocalMusicResetContractTests(unittest.TestCase):
    def test_native_mp3_picker_is_private_bounded_and_offline(self):
        source = (ROOT / 'native/android/kotlin/MainActivity.kt').read_text()
        for token in ('betterseed/music_files', 'ACTION_OPEN_DOCUMENT',
                      'audio/mpeg', 'musicMaxBytes = 25 * 1024 * 1024',
                      'filesDir', 'pickMp3', 'getImportedMp3',
                      'MUSIC_IMPORT_FAILED'):
            self.assertIn(token, source)
        self.assertNotIn('READ_EXTERNAL_STORAGE', source)

    def test_music_can_switch_back_to_default_and_user_selection_remains_private(self):
        source = (ROOT / 'lib/audio/ambient_audio.dart').read_text()
        for token in ('DeviceFileSource', 'AssetSource', 'setCustomMusicPath',
                      'forceRestart', 'ReleaseMode.loop'):
            self.assertIn(token, source)
        screen = (ROOT / 'lib/main.dart').read_text()
        for token in ('music-import-mp3', 'music-source-default',
                      'music-source-custom', 'betterseed_music_mode_v1'):
            self.assertIn(token, screen)
        snapshot = (ROOT / 'lib/backup/backup_snapshot.dart').read_text()
        self.assertNotIn('custom_background.mp3', snapshot)

    def test_reset_tree_is_separate_from_checklist_and_water(self):
        source = (ROOT / 'lib/logic/water_progress.dart').read_text()
        self.assertIn('void resetTreeGrowth()', source)
        self.assertIn('_xp = 0;', source)
        screen = (ROOT / 'lib/main.dart').read_text()
        self.assertIn("ValueKey('settings-reset-tree')", screen)
        self.assertIn("ValueKey('confirm-reset-tree')", screen)
        self.assertIn('await _save(); // also refreshes', screen)

    def test_asset_editor_preserves_paid_pack_ownership(self):
        source = (ROOT / 'lib/main.dart').read_text()
        self.assertIn("'asset-background-choice'", source)
        self.assertIn("'asset-tree-choice'", source)
        self.assertIn('_buildEditorAssetsPanel()', source)
        self.assertIn('_editorChoicesFor(', source)
        # The editor used to grant a complete pack if any of its cosmetic IDs
        # were chosen. That behavior was deliberately removed once packs
        # became premium. Check the ownership-filtered save path, not the
        # obsolete `chosen.wateringCanId ==` implementation detail.
        save = source.split('void _closeAssetEditor(', 1)[1].split(
            'void _applyShopLoadout(', 1)[0]
        self.assertIn('ShopLoadout.fromMap(', save)
        self.assertIn('chosen.toJson()', save)
        for existing_entitlement in (
            'moonlightOwned: _moonlightOwned',
            'sakuraOwned: _sakuraOwned',
            'autumnOwned: _autumnOwned',
        ):
            self.assertIn(existing_entitlement, save)
        # Persisting the selected assets must not silently set ownership.
        for forbidden_assignment in (
            '_moonlightOwned = _moonlightOwned ||',
            '_sakuraOwned = _sakuraOwned ||',
            '_autumnOwned = _autumnOwned ||',
        ):
            self.assertNotIn(forbidden_assignment, save)
        # The saved loadout is still synced into the existing preference flow.
        self.assertIn('_shopLoadout = ShopLoadout.fromMap(', save)


if __name__ == '__main__':
    unittest.main()
