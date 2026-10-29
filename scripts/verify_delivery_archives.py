#!/usr/bin/env python3
"""Verify all pack ZIPs as immutable HTTPS CDN payloads with stdlib only."""
import argparse
import hashlib
import json
import sys
from pathlib import Path
from zipfile import ZipFile, BadZipFile

ROOT = Path(__file__).resolve().parents[1]
STAGES = ['seed','sprout','sapling','young','mature','legendary']

def verify(directory):
    manifest = json.loads((ROOT/'assets/pack_downloads.json').read_text())['packs']
    paths = json.loads((ROOT/'docs/pack_archive_index.json').read_text())
    if set(manifest) != set(paths) or len(manifest) != 9:
        raise AssertionError('Pack index/manifest IDs disagree')
    allowed_files = {meta['file'] for meta in manifest.values()}
    actual_files = {p.name for p in directory.glob('*.zip')}
    if actual_files != allowed_files:
        raise AssertionError(f'ZIP directory mismatch: missing={allowed_files-actual_files}, extra={actual_files-allowed_files}')
    for id, meta in manifest.items():
        target=directory/meta['file']
        raw = target.read_bytes()
        if len(raw)!=meta['sizeBytes'] or hashlib.sha256(raw).hexdigest()!=meta['sha256']:
            raise AssertionError(f'Checksum/size mismatch: {target.name}')
        item=paths[id]
        expected={item['background'], item['butterfly'],item['wateringCan'],*item['treeStages']}
        if item['video']:expected.add(item['video'])
        assert len(item['treeStages'])==6
        for i,name in enumerate(STAGES):
            assert item['treeStages'][i].endswith(f'/stage_{i}_{name}.png'), item['treeStages'][i]
        try:
            with ZipFile(target) as zipf:
                members=zipf.infolist()
                actual={m.filename for m in members}
                if actual!=expected or len(members)!=len(expected):
                    raise AssertionError(f'Unexpected missing/extra entries in {target.name}: {actual^expected}')
                for part in members:
                    if part.is_dir() or part.filename.startswith('/') or '..' in Path(part.filename).parts or '\\' in part.filename:
                        raise AssertionError(f'Invalid ZIP entry: {part.filename}')
                    data=zipf.read(part)
                    if part.filename.endswith('.png') and not data.startswith(b'\x89PNG\r\n\x1a\n'):
                        raise AssertionError(f'Invalid PNG {part.filename}')
                    if part.filename.endswith('.webp') and not (data[:4]==b'RIFF' and data[8:12]==b'WEBP'):
                        raise AssertionError(f'Invalid WebP {part.filename}')
                    if part.filename.endswith('.mp4') and data[4:8]!=b'ftyp':
                        raise AssertionError(f'Invalid MP4 {part.filename}')
        except BadZipFile as e:
            raise AssertionError(f'Corrupted ZIP: {target.name}') from e
        print(f'PASS {id:20s} {len(raw)/1024/1024:5.1f} MiB | {len(expected)} assets')
    print(f'PASS all {len(manifest)} verified ZIPs ({sum(m["sizeBytes"] for m in manifest.values())/1024/1024:.1f} MiB total)')

if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--directory',required=True,type=Path)
    args=parser.parse_args()
    try:verify(args.directory)
    except (AssertionError, OSError, KeyError, ValueError) as e:
        print(f'ERROR: {e}',file=sys.stderr)
        sys.exit(1)
