#!/usr/bin/env python3
"""CI guard: catch black/opaque stage-3 sprites and missing effect art."""
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parent.parent
stage = ROOT / 'assets/images/trees/stage_3_young.webp'
blob = stage.read_bytes()
assert blob[:4] == b'RIFF' and blob[8:12] == b'WEBP', f'Invalid WebP: {stage}'

# Both extended VP8X and lossless VP8L can carry an alpha channel.  In VP8L,
# bit 28 of the lossless image header marks the presence of alpha samples.
chunk = blob[12:16]
if chunk == b'VP8L':
    assert len(blob) >= 25 and blob[20] == 0x2F, 'Invalid VP8L bitstream'
    header = struct.unpack_from('<I', blob, 21)[0]
    assert (header >> 28) & 1, 'stage_3_young.webp lost transparency (VP8L alpha flag)'
elif chunk == b'VP8X':
    assert len(blob) >= 21 and (blob[20] & 0x10), 'stage_3_young.webp lost transparency (VP8X alpha flag)'
else:
    raise AssertionError('stage_3_young.webp must use an alpha-capable WebP encoding')

for name in ('butterfly_realistic.png', 'watering_can_realistic.png'):
    path = ROOT / 'assets/images/effects' / name
    data = path.read_bytes()
    assert data[:8] == b'\x89PNG\r\n\x1a\n', f'Invalid PNG: {path}'
    assert len(data) > 26 and data[25] in (4, 6), f'Effect asset lacks alpha: {path}'
    assert path.stat().st_size > 1000, f'Effect asset looks empty: {path}'
print('Visual assets verified: transparent stage 3 + RGBA effect sprites')
