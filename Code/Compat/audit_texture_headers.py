"""Read-only header audit for the compat draft; no asset writes."""
from pathlib import Path
import re
import struct
from collections import Counter

ROOT = Path(__file__).resolve().parents[2]
sizes = {k: (int(w), int(h)) for k, w, h in re.findall(r'S\["([^"]+)"\] = \{(\d+), (\d+)\}', (ROOT / 'Code/Compat/TextureSizes_335.lua').read_text())}
counts = Counter()
mismatches = []
for path in sorted((ROOT / '_Build/DialogueUI/Art').rglob('*.tga')):
    data = path.read_bytes()[:18]
    w, h = struct.unpack_from('<HH', data, 12)
    key = path.relative_to(ROOT / '_Build/DialogueUI/Art').with_suffix('').as_posix().lower()
    counts[(data[2], data[16], data[17])] += 1
    if sizes.get(key) != (w, h):
        mismatches.append((key, sizes.get(key), (w, h)))
print('TGA headers:', sum(counts.values()), 'size mismatches:', len(mismatches))
for item in mismatches:
    print('SIZE', item)
print('TGA (type, bits-per-pixel, descriptor):', dict(counts))
for key in ('theme_brown/parchment', 'theme_dark/parchment', 'book/texturekit-parchment'):
    p = next((ROOT / '_Build/DialogueUI/Art').glob('**/' + key.split('/')[-1] + '.tga'), None)
for path in sorted((ROOT / 'Code').rglob('*.xml')):
    text = path.read_text(encoding='utf-8-sig')
    for n, line in enumerate(text.splitlines(), 1):
        if '...' in line or re.search(r'(?<!DUI_)C_Timer', line):
            print('XML', path.relative_to(ROOT), n, line.strip())
print('Local Lua runtime libraries:', end=' ')
try:
    import lupa
    print(lupa.__version__)
except ImportError:
    print('lupa unavailable; Lua execution not performed')
