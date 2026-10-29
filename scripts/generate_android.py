"""Generate Flutter's Android platform without touching BetterSeed's Dart sources.

The temporary project is called `app` so Flutter generates the permanent
Android application ID `com.betterseed.app` under organization `com.betterseed`.

Why: running `flutter create .` in this source-only repository can generate
Flutter's stock `test/widget_test.dart` (which references `MyApp`) even though
BetterSeed's entry widget is `BetterSeedApp`.  Generate into a disposable app
and copy only the `android/` platform folder into our project instead.
"""

from pathlib import Path
import shutil
import re
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[1]


def generate_android(root: Path = ROOT, flutter: str = 'flutter') -> Path:
    """Create Android scaffold; refuse to overwrite any existing platform."""
    root = Path(root).resolve()
    destination = root / 'android'
    if destination.exists():
        raise FileExistsError(
            f'{destination} already exists. Remove the generated Android folder '
            'explicitly before re-running platform generation.'
        )

    # Flutter may create more than just android/ (lib/main.dart, widget tests,
    # pubspec.yaml, etc.) even when --platforms=android is requested.
    with tempfile.TemporaryDirectory(prefix='betterseed-android-scaffold-') as temp:
        staging = Path(temp) / 'betterseed'
        subprocess.run(
            [flutter, 'create', '--no-pub', '--project-name', 'app',
             '--org', 'com.betterseed', '--platforms=android', str(staging)],
            cwd=root,
            check=True,
        )
        android_source = staging / 'android'
        if not (android_source / 'app/src/main/AndroidManifest.xml').is_file():
            raise RuntimeError('Flutter create did not generate a valid Android platform')
        gradle = android_source / 'app/build.gradle.kts'
        if not gradle.is_file():
            raise RuntimeError('Flutter did not produce the expected Kotlin DSL Android Gradle file')
        gradle_source = gradle.read_text(encoding='utf-8')
        for field in ('namespace', 'applicationId'):
            if not re.search(r'\b' + field + r'\s*=\s*[\"\']com\.betterseed\.app[\"\']', gradle_source):
                raise RuntimeError('Generated Android ' + field + ' is not com.betterseed.app')
        shutil.copytree(android_source, destination)

    print('Android scaffold generated in isolation; BetterSeed lib/ and test/ preserved.')
    return destination


if __name__ == '__main__':
    generate_android()
