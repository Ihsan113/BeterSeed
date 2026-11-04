"""Translation completeness and placeholder safety without hitting a network."""
import json
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

class LocalizationContract(unittest.TestCase):
    def test_all_languages_have_every_message_and_keep_placeholders(self):
        english = json.loads((ROOT / 'assets/l10n/en.json').read_text())
        self.assertGreater(len(english), 450)
        for language in ('id', 'ja', 'de', 'fr', 'es', 'pt'):
            translated = json.loads((ROOT / f'assets/l10n/{language}.json').read_text())
            self.assertEqual(english.keys(), translated.keys(), language)
            for key, value in translated.items():
                self.assertTrue(value.strip(), (language, key))
                self.assertEqual(set(re.findall(r'\{p\d+\}', key)), set(re.findall(r'\{p\d+\}', value)), (language, key))
                if 'Leaf Coins' in key:
                    self.assertIn('Leaf Coins', value, (language, key))

    def test_static_ui_messages_are_in_catalog(self):
        import ast
        english = json.loads((ROOT / 'assets/l10n/en.json').read_text())
        pattern = re.compile(r'\.tr\(\s*("(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\')', re.S)
        for file in (ROOT / 'lib').rglob('*.dart'):
            for match in pattern.finditer(file.read_text()):
                key = ast.literal_eval(match.group(1))
                self.assertIn(key, english, f'{file.relative_to(ROOT)}: {key}')

if __name__ == '__main__':
    unittest.main()
