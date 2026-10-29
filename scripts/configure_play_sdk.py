#!/usr/bin/env python3
"""Set the Android 16 SDK target required by Google Play (October 2026).

Only patches the generated Flutter Kotlin DSL Gradle project. The original
Flutter sources, user data, signing keystore and release identity are untouched.
Fail closed if Flutter significantly changes the generated Gradle template.
"""
from __future__ import annotations

from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
GRADLE = ROOT / 'android/app/build.gradle.kts'
PLAY_API_LEVEL = 36


class PlaySdkError(RuntimeError):
    pass


def patch_play_sdk(source: str) -> str:
    if not re.search(r'\bapplicationId\s*=\s*"com\.betterseed\.app"', source):
        raise PlaySdkError('Unexpected Android Application ID. Expected com.betterseed.app.')
    if not re.search(r'\bnamespace\s*=\s*"com\.betterseed\.app"', source):
        raise PlaySdkError('Unexpected Android namespace. Expected com.betterseed.app.')

    updated = source
    for field in ('compileSdk', 'targetSdk'):
        pattern = re.compile(r'(?m)^(?P<indent>\s*)' + field + r'\s*=\s*(?P<value>flutter\.'
                             + field + r'Version|\d+)\s*$')
        matches = list(pattern.finditer(updated))
        if len(matches) != 1:
            raise PlaySdkError(f'Expected exactly one {field} entry in generated Android Gradle file.')
        value = matches[0].group('value')
        if value.isdigit() and int(value) > PLAY_API_LEVEL:
            # Never downgrade a future, already-compliant SDK configuration.
            continue
        updated = pattern.sub(lambda m: f'{m.group("indent")}{field} = {PLAY_API_LEVEL}', updated, count=1)

    return updated


def main() -> None:
    if not GRADLE.is_file():
        raise PlaySdkError('Missing generated android/app/build.gradle.kts')
    original = GRADLE.read_text(encoding='utf-8')
    changed = patch_play_sdk(original)
    GRADLE.write_text(changed, encoding='utf-8')
    print(f'Android Gradle configured for Play SDK API {PLAY_API_LEVEL} (com.betterseed.app).')


if __name__ == '__main__':
    try:
        main()
    except PlaySdkError as exc:
        print(f'::error::{exc}', file=sys.stderr)
        sys.exit(1)
