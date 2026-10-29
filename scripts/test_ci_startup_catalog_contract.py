"""Regression guards for the 29 October Flutter CI startup/catalog failure."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class CiStartupCatalogContractTests(unittest.TestCase):
    def test_cdn_scan_does_not_gate_offline_garden_startup(self):
        code = (ROOT / 'lib/main.dart').read_text(encoding='utf-8')
        self.assertIn('unawaited(_packs.initialize().catchError', code)
        self.assertNotIn('await _packs.initialize();', code)
        download_code = (ROOT / 'lib/data/pack_downloads.dart').read_text(encoding='utf-8')
        self.assertIn('final work = _initialization ??= _scanInstalledPacks()', download_code)
        self.assertIn('if (!_disposed) super.notifyListeners();', download_code)

    def test_free_default_fixture_has_zero_coin_price(self):
        code = (ROOT / 'test/catalog_fixture.dart').read_text(encoding='utf-8')
        self.assertIn("'accessType': p.id == 'default' ? 'free' : 'premium'", code)
        self.assertIn("'default' => 0", code)
        self.assertIn('if (!catalog.online || !catalog.assetReady', code)


if __name__ == '__main__':
    unittest.main()
