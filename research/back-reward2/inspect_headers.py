"""Read-only BLP headers and source references; Python stdlib only."""
from pathlib import Path
import struct
import re
import hashlib

ROOT = Path(__file__).resolve().parents[2]
sizes = {k: (int(w), int(h)) for k, w, h in re.findall(r'S\["([^"]+)"\] = \{(\d+), (\d+)\}', (ROOT / 'Code/Compat/TextureSizes_335.lua').read_text(encoding='utf-8-sig'))}
names = ['Theme_Brown/QuestItemDisplay-UI', 'PreviewPicture/QuestItemDisplay', 'Theme_Brown/ItemButtonBackground', 'Theme_Brown/ItemBorder']
for name in names:
    for prefix in ['Art', '_Build/DialogueUI/Art']:
        path = ROOT / prefix / (name + '.blp')
        if not path.exists():
            print('MISSING', path.relative_to(ROOT).as_posix())
            continue
        data = path.read_bytes()
        magic = data[:4]
        assert magic == b'BLP2', (name, magic)
        kind = struct.unpack_from('<I', data, 4)[0]
        enc, alpha, alpha_enc, mips = data[8:12]
        w, h = struct.unpack_from('<II', data, 12)
        offsets = struct.unpack_from('<16I', data, 20)
        lengths = struct.unpack_from('<16I', data, 84)
        lw, lh, end, levels = w, h, offsets[0], []
        while True:
            levels.append((lw, lh))
            if lw == 1 and lh == 1:
                break
            lw, lh = max(1, lw // 2), max(1, lh // 2)
        valid = kind == 1 and enc == 3 and alpha == 8 and mips == 1
        for i, (lw, lh) in enumerate(levels):
            valid = valid and offsets[i] == end and lengths[i] == lw * lh * 4
            end += lengths[i]
        valid = valid and end == len(data) and not any(offsets[len(levels):]) and not any(lengths[len(levels):])
        print(f'{path.relative_to(ROOT).as_posix()}: BLP2 type={kind} encoding={enc} alpha={alpha} alphaEncoding={alpha_enc} mipsFlag={mips} size={w}x{h} manifest={sizes[name.lower()]} levels={len(levels)} offset0={offsets[0]} length0={lengths[0]} bytes={len(data)} layout_valid={bool(valid)} sha256={hashlib.sha256(data).hexdigest()}')
        assert valid
        assert (w, h) == sizes[name.lower()]
print('UI sheet crops at 512x512: background=128x128; shadow=128x128; iconBorder=80x80; title=416x64; button=256x32; queue=32x32')
print('Unsliced 64x64 background mapped to default 174x36 button: xScale=2.718750 yScale=0.562500 anisotropy=4.833333')
for path in sorted((ROOT / 'Code').rglob('*.lua')):
    text = path.read_text(encoding='utf-8-sig')
    for n, line in enumerate(text.splitlines(), 1):
        if ('CreateLegacyPanel' in line and ('function' in line or 'addon.CreateLegacyPanel =' in line)) or ('QuestItemDisplay' in line and 'PreviewPicture' in line):
            print(f'REF {path.relative_to(ROOT).as_posix()}:{n}: {line.strip()}')
print('Header draft checks passed; no Lua/client execution.')
