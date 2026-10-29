"""Create a reproducible, clean backend ZIP; never copy runtime files/secrets."""
from pathlib import Path
import argparse
import hashlib
import re
import zipfile

ROOT = Path(__file__).resolve().parents[1]
SERVER = ROOT / 'server'
OUTPUT = ROOT / 'build/server/BetterSeed-server.zip'
TOP_LEVEL = [
    '.env.example', '.dockerignore', 'package.json', 'package-lock.json',
    'tsconfig.json', 'Dockerfile', 'compose.yaml', 'Caddyfile.example', 'README.md', 'UPGRADE.md',
]
DIRECTORIES = ['src', 'migrations', 'test', 'public']


def build_bytes():
    import io
    paths = [SERVER / name for name in TOP_LEVEL]
    paths.extend(ROOT / 'docs' / name for name in ['DYNAMIC_GARDEN_PACKS.md', 'DYNAMIC_PACK_QA.md'])
    for name in DIRECTORIES:
        paths.extend(p for p in (SERVER / name).rglob('*') if p.is_file())
    stream = io.BytesIO()
    with zipfile.ZipFile(stream, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for p in sorted(paths):
            if p.is_symlink() or not p.is_file():
                raise ValueError(f'Missing/unsafe distribution source: {p.relative_to(ROOT)}')
            relative = p.relative_to(SERVER) if p.is_relative_to(SERVER) else Path(p.name)
            if any(part in {'.env', 'secrets', 'node_modules', 'dist'} for part in relative.parts):
                raise ValueError('Runtime file in distribution')
            data = p.read_bytes()
            if re.search(rb'gr_live_[A-Za-z0-9]{16,}|-----BEGIN (?:RSA |EC )?PRIVATE KEY-----', data):
                raise ValueError(f'Credential-like content in {relative}')
            info = zipfile.ZipInfo('BetterSeed-server/' + relative.as_posix(), date_time=(2026, 10, 27, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            z.writestr(info, data, compress_type=zipfile.ZIP_DEFLATED, compresslevel=9)
    return stream.getvalue()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    data = build_bytes()
    digest = hashlib.sha256(data).hexdigest()
    checksum = OUTPUT.with_suffix('.zip.sha256')
    expected = f'{digest}  {OUTPUT.name}\n'
    if args.check:
        if not OUTPUT.is_file() or OUTPUT.read_bytes() != data or not checksum.is_file() or checksum.read_text() != expected:
            raise SystemExit('Server ZIP is missing/stale. Run python3 scripts/package_server.py.')
        print('Clean backend ZIP matches its source and checksum.')
    else:
        OUTPUT.parent.mkdir(parents=True, exist_ok=True)
        OUTPUT.write_bytes(data)
        checksum.write_text(expected)
        print(f'{OUTPUT.relative_to(ROOT)}: {len(data)} bytes; SHA-256 {digest}')

if __name__ == '__main__':
    main()
