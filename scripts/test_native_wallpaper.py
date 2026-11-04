"""Run Android snapshot tests with Robolectric; no emulator/device is required.

Run after prepare_android.py and flutter pub get. Test dependencies are applied
only to the ignored generated scaffold and restored before any release build.
"""
from pathlib import Path
import shutil
import subprocess


def main():
    root = Path(__file__).resolve().parents[1]
    android = root / 'android'
    gradle = android / 'app/build.gradle.kts'
    original = gradle.read_bytes()
    tests = android / 'app/src/test/java/com/betterseed/app'
    tests.mkdir(parents=True, exist_ok=True)
    for source in (root / 'test/native_android').glob('*.kt'):
        shutil.copy2(source, tests / source.name)
    config = '''
android { testOptions { unitTests { isIncludeAndroidResources = true } } }
// Newer AGP host-test packaging consumes Flutter assets directly.
tasks.matching { it.name == "packageDebugUnitTestForUnitTest" }.configureEach {
    dependsOn("copyFlutterAssetsDebug")
}
val wallpaperTestSdk by configurations.creating
val prepareWallpaperTestSdk by tasks.registering(Copy::class) {
    from(wallpaperTestSdk)
    into(layout.buildDirectory.dir("wallpaper-test-sdk"))
}
tasks.withType<Test>().configureEach {
    dependsOn(prepareWallpaperTestSdk)
    systemProperty("robolectric.offline", "true")
    systemProperty("robolectric.dependency.dir", layout.buildDirectory.dir("wallpaper-test-sdk").get().asFile.absolutePath)
}
dependencies {
    wallpaperTestSdk("org.robolectric:android-all-instrumented:15-robolectric-12650502-i7")
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.robolectric:robolectric:4.14.1")
}
'''
    try:
        gradle.write_bytes(original + config.encode())
        subprocess.run(['./gradlew', ':app:testDebugUnitTest', '--tests',
                        'com.betterseed.app.LiveWallpaperStoreTest', '--no-daemon',
                        '--max-workers=2'], cwd=android, check=True)
    finally:
        gradle.write_bytes(original)
        for source in (root / 'test/native_android').glob('*.kt'):
            (tests / source.name).unlink(missing_ok=True)


if __name__ == '__main__':
    main()
