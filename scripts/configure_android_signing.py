#!/usr/bin/env python3
"""Restore a persistent Android keystore from GitHub Secrets and wire Flutter's
regenerated Kotlin-DSL Android project to sign release builds with that key.

Never creates a new key in CI. If secrets are absent or invalid, fails closed.
The JKS/PKCS12 keystore and key.properties are kept off the source ZIP.
"""
from __future__ import annotations

import base64
import binascii
import os
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
GRADLE = ROOT / 'android' / 'app' / 'build.gradle.kts'
PROPERTIES = ROOT / 'android' / 'key.properties'
REQUIRED = (
    'BETTERSEED_KEYSTORE_BASE64',
    'BETTERSEED_KEYSTORE_PASSWORD',
    'BETTERSEED_KEY_ALIAS',
    'BETTERSEED_KEY_PASSWORD',
)


class SigningSetupError(Exception):
    pass


def _java_property(value: str) -> str:
    """Escape a literal value to keep Java properties syntax valid."""
    if not value or any(ord(c) < 32 for c in value):
        raise SigningSetupError('A signing property is empty or contains a forbidden newline.')
    # Properties.load(InputStream) interprets ISO-8859-1 and \\uXXXX escapes.
    out = []
    for c in value:
        if c in '\\=:# !':
            out.append('\\' + c)
        elif ord(c) > 0x7E:
            out.extend('\\u%04X' % int.from_bytes(c.encode('utf-16-be')[i:i+2], 'big') for i in range(0, len(c.encode('utf-16-be')), 2))
        else:
            out.append(c)
    return ''.join(out)


def patch_gradle(original: str) -> str:
    """Patch the stock Flutter Kotlin Gradle template; idempotent, fail closed."""
    marker = '// BetterSeed persistent release signing configuration'
    if marker in original:
        if 'signingConfigs.getByName("betterseedRelease")' not in original:
            raise SigningSetupError('A partial/modified BetterSeed signing block was found.')
        return original

    if not re.search(r'^android\s*\{', original, re.M):
        raise SigningSetupError('Flutter did not generate the expected Kotlin Android block.')
    if not re.search(r'^\s{4}buildTypes\s*\{', original, re.M):
        raise SigningSetupError('Cannot safely locate the Android buildTypes block.')

    # Flutter 2026's generated release build uses the debug signing config.
    debug_pattern = r'signingConfig\s*=\s*signingConfigs\.getByName\("debug"\)'
    if len(re.findall(debug_pattern, original)) != 1:
        raise SigningSetupError('Unexpected Gradle template: cannot uniquely replace debug release signing.')

    header = '''import java.io.FileInputStream
import java.util.Properties

'''
    properties = '''// BetterSeed persistent release signing configuration
val betterseedKeyProperties = Properties()
val betterseedKeyFile = rootProject.file("key.properties")
if (betterseedKeyFile.isFile) {
    FileInputStream(betterseedKeyFile).use { betterseedKeyProperties.load(it) }
}

'''
    signing = '''    signingConfigs {
        create("betterseedRelease") {
            keyAlias = betterseedKeyProperties.getProperty("keyAlias")
            keyPassword = betterseedKeyProperties.getProperty("keyPassword")
            storePassword = betterseedKeyProperties.getProperty("storePassword")
            storeFile = betterseedKeyProperties.getProperty("storeFile")?.let { file(it) }
        }
    }

'''
    updated = header + original
    updated = re.sub(r'^(android\s*\{)', properties + r'\1', updated, count=1, flags=re.M)
    updated = re.sub(r'^(\s{4}buildTypes\s*\{)', lambda m: signing + m.group(1), updated, count=1, flags=re.M)
    updated = re.sub(debug_pattern, 'signingConfig = signingConfigs.getByName("betterseedRelease")', updated, count=1)
    if updated.count('create("betterseedRelease")') != 1:
        raise SigningSetupError('Generated Gradle patch is inconsistent.')
    return updated


def _keytool_sha1(keystore: Path, alias: str, env: dict[str, str]) -> str:
    process = subprocess.run([
        'keytool', '-list', '-v', '-keystore', str(keystore), '-alias', alias,
        '-storepass:env', 'BETTERSEED_KEYSTORE_PASSWORD',
    ], env=env, text=True, capture_output=True, check=False)
    if process.returncode != 0:
        # Never emit process stderr which could include sensitive filesystem data.
        raise SigningSetupError('Keystore verification failed. Check keystore, alias and passwords in GitHub Secrets.')
    match = re.search(r'(?im)^\s*SHA1:\s*((?:[0-9A-F]{2}:?){20})\s*$', process.stdout)
    if not match:
        raise SigningSetupError('Could not read a SHA-1 fingerprint from the signing keystore.')
    return match.group(1).replace(':', '').upper()


def configure(environ: dict[str, str] | None = None, *, gradle_file: Path = GRADLE,
              properties_file: Path = PROPERTIES) -> str:
    env = dict(os.environ if environ is None else environ)
    missing = [item for item in REQUIRED if not env.get(item, '').strip()]
    if missing:
        raise SigningSetupError('Stable signing not configured. Create repository Actions Secrets: '
                                + ', '.join(missing) + '. NO debug fallback APK will be produced.')
    if not gradle_file.is_file():
        raise SigningSetupError('Missing android/app/build.gradle.kts. Run flutter create first.')
    temp_dir = Path(env.get('RUNNER_TEMP', '/tmp')).resolve()
    if not temp_dir.is_dir():
        raise SigningSetupError('RUNNER_TEMP directory does not exist.')
    keystore_path = temp_dir / 'betterseed-stable-release.jks'
    try:
        blob = base64.b64decode(''.join(env['BETTERSEED_KEYSTORE_BASE64'].split()), validate=True)
    except (ValueError, binascii.Error) as exc:
        raise SigningSetupError('BETTERSEED_KEYSTORE_BASE64 is invalid base64.') from exc
    if not 512 <= len(blob) <= 100_000:
        raise SigningSetupError('Keystore file size is outside the expected range.')

    try:
        # Validate template before any changes to avoid partially configured CI.
        gradle_text = patch_gradle(gradle_file.read_text(encoding='utf-8'))
        keystore_path.write_bytes(blob)
        keystore_path.chmod(0o600)
        fp = _keytool_sha1(keystore_path, env['BETTERSEED_KEY_ALIAS'], env)
        pinned = re.sub(r'[^A-Fa-f0-9]', '', env.get('BETTERSEED_PINNED_SHA1', '')).upper()
        if len(pinned) != 40:
            raise SigningSetupError('Set GitHub Actions VARIABLE BETTERSEED_PINNED_SHA1 to your permanent keystore fingerprint (not a secret).')
        if pinned != fp:
            raise SigningSetupError('Signing keystore SHA-1 differs from pinned BETTERSEED_PINNED_SHA1; refusing certificate rotation.')
        content = '\n'.join([
            'storeFile=' + _java_property(str(keystore_path)),
            'storePassword=' + _java_property(env['BETTERSEED_KEYSTORE_PASSWORD']),
            'keyAlias=' + _java_property(env['BETTERSEED_KEY_ALIAS']),
            'keyPassword=' + _java_property(env['BETTERSEED_KEY_PASSWORD']),
            '',
        ])
        properties_file.write_text(content, encoding='iso-8859-1')
        properties_file.chmod(0o600)
        gradle_file.write_text(gradle_text, encoding='utf-8')
        github_env = env.get('GITHUB_ENV')
        if github_env:
            with Path(github_env).open('a', encoding='utf-8') as file:
                file.write(f'BETTERSEED_EXPECTED_SIGNING_SHA1={fp}\n')
        print('Stable release signing configured. Expected certificate SHA-1:', ':'.join(fp[i:i+2] for i in range(0, len(fp), 2)))
        print('This SHA-1 belongs to the upload keystore; the Google Play app-signing certificate may differ.')
        return fp
    except BaseException:
        # If secrets are bad, don't leave an apparently valid, partially signed build.
        if properties_file.exists():
            properties_file.unlink()
        if keystore_path.exists():
            keystore_path.unlink()
        raise


if __name__ == '__main__':
    try:
        configure()
    except SigningSetupError as error:
        print(f'::error::{error}', file=sys.stderr)
        sys.exit(1)
