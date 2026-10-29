"""Regression tests for the MyApp/BetterSeedApp flutter create CI failure."""
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from generate_android import generate_android, ROOT


class AndroidScaffoldTests(unittest.TestCase):
    def test_isolated_scaffold_preserves_existing_sources_and_tests(self):
        with tempfile.TemporaryDirectory() as scratch:
            project = Path(scratch)
            (project / 'lib').mkdir()
            (project / 'test').mkdir()
            (project / 'lib/main.dart').write_text('class BetterSeedApp {}\n')
            (project / 'test/widget_test.dart').write_text('uses BetterSeedApp\n')
            (project / 'pubspec.yaml').write_text('name: betterseed\n')

            def mock_flutter_create(command, **kwargs):
                # Model Flutter's ability to produce its *own* example sources.
                self.assertEqual(command[1:3], ['create', '--no-pub'])
                self.assertIn('--platforms=android', command)
                self.assertEqual(command[command.index('--project-name') + 1], 'app')
                self.assertEqual(command[command.index('--org') + 1], 'com.betterseed')
                self.assertEqual(kwargs['cwd'], project.resolve())
                staging = Path(command[-1])
                self.assertNotEqual(staging, project)
                (staging / 'lib').mkdir(parents=True)
                (staging / 'test').mkdir()
                (staging / 'lib/main.dart').write_text('class MyApp {}\n')
                (staging / 'test/widget_test.dart').write_text('const MyApp()\n')
                manifest = staging / 'android/app/src/main/AndroidManifest.xml'
                manifest.parent.mkdir(parents=True)
                manifest.write_text('<manifest />\n')
                gradle = staging / 'android/app/build.gradle.kts'
                gradle.write_text('android {\n namespace = "com.betterseed.app"\n defaultConfig {\n applicationId = "com.betterseed.app"\n }\n}\n')

            with patch('generate_android.subprocess.run', side_effect=mock_flutter_create) as run:
                result = generate_android(project)
                run.assert_called_once()
            self.assertEqual(result, project / 'android')
            self.assertTrue((result / 'app/src/main/AndroidManifest.xml').is_file())
            self.assertEqual((project / 'lib/main.dart').read_text(), 'class BetterSeedApp {}\n')
            self.assertEqual((project / 'test/widget_test.dart').read_text(), 'uses BetterSeedApp\n')
            self.assertEqual((project / 'pubspec.yaml').read_text(), 'name: betterseed\n')

    def test_existing_android_platform_is_not_overwritten(self):
        with tempfile.TemporaryDirectory() as scratch:
            project = Path(scratch)
            (project / 'android').mkdir()
            with patch('generate_android.subprocess.run') as run:
                with self.assertRaises(FileExistsError):
                    generate_android(project)
                run.assert_not_called()

    def test_current_repository_has_no_stock_myapp_widget_test(self):
        app = (ROOT / 'lib/main.dart').read_text(encoding='utf-8')
        widget_test = (ROOT / 'test/widget_test.dart').read_text(encoding='utf-8')
        self.assertIn('class BetterSeedApp', app)
        self.assertIn('BetterSeedApp', widget_test)
        self.assertNotIn('MyApp(', widget_test)


if __name__ == '__main__':
    unittest.main()
