#!/usr/bin/env python3
"""DialogueUI 3.3.5a (Sirus) texture conversion.

The 3.3.5a client cannot load PNG/JPG and draws nothing for textures whose size is not a power of two.
Every image under Art/ is converted to BLP2 with uncompressed BGRA pixels (encoding 3, 8-bit alpha)
and a full mipmap chain down to 1x1 - the same layout as the uncompressed BLP files shipped by
ElvUI-for-Sirus (e.g. Media/Textures/PVP-Icons.blp). The client samples the smaller mip levels whenever
a texture is drawn smaller than its file (key icons, parchment, option buttons); the BLP files of
1.0.8 had no mip levels and stayed invisible in game. Images whose size is not a power of two are scaled
up to the next power of two (texture coordinates are normalized, so every SetTexCoord stays valid). The
original pixel sizes are written to Code/Compat/TextureSizes_335.lua (used by the 9-slice emulation in
Compat_335.lua). A file is replaced only after its BLP has been written and read back pixel-exact.
Re-running is safe: BLP files in the current layout are kept, BLP files written by an older version of
this script (no mip levels) are rebuilt losslessly from their own pixels.

    python scripts/convert_textures_335.py          # convert Art/ and rewrite TextureSizes_335.lua
    python scripts/convert_textures_335.py --refs   # also strip image extensions from Lua/XML references
                                                    # ("X.tga" -> "X": the client then resolves X.blp)
"""
import os
import re
import struct
import sys

from PIL import Image

RESAMPLING = getattr(Image, 'Resampling', Image)
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ART = os.path.join(ROOT, 'Art')
SIZES_LUA = os.path.join(ROOT, 'Code', 'Compat', 'TextureSizes_335.lua')
SRC_EXT = ('.tga', '.jpg', '.jpeg', '.png', '.blp')
HEADER_SIZE = 1172          # 148-byte BLP2 header + 256-entry palette (unused by encoding 3)
MAX_SIZE = 2048
SKIP_TOP = {'.git', '.github', '.idea', '.vscode', 'dist', '_Build', '_Dev', 'scripts', 'node_modules',
            'Art', 'Fonts', 'Sound'}
REF_RE = re.compile(r'\.(?:tga|jpe?g|png|blp)(?=["\':|])', re.I)


def next_pot(n):
    p = 1
    while p < n:
        p <<= 1
    return min(p, MAX_SIZE)


def mip_levels(w, h):
    """Sizes of the full mip chain: (w, h), (w/2, h/2), ... (1, 1)."""
    levels = [(w, h)]
    while w > 1 or h > 1:
        w, h = max(1, w >> 1), max(1, h >> 1)
        levels.append((w, h))
    return levels


def blp_state(head, file_size):
    """'current' (our layout with mip levels), 'nomips' (older output of this script) or None."""
    if len(head) < 148 or head[:4] != b'BLP2' or struct.unpack('<I', head[4:8])[0] != 1:
        return None
    if head[8] != 3 or head[9] != 8:
        return None
    w, h = struct.unpack('<II', head[12:20])
    offs = struct.unpack('<16I', head[20:84])
    sizes = struct.unpack('<16I', head[84:148])
    if w < 1 or h < 1:
        return None
    if head[11] == 0:
        if offs[0] == HEADER_SIZE and sizes[0] == w * h * 4 and file_size == HEADER_SIZE + w * h * 4:
            return 'nomips'
        return None
    levels = mip_levels(w, h)
    if len(levels) > 16:
        return None
    off = HEADER_SIZE
    for i, (lw, lh) in enumerate(levels):
        if offs[i] != off or sizes[i] != lw * lh * 4:
            return None
        off += lw * lh * 4
    if any(offs[len(levels):]) or any(sizes[len(levels):]) or file_size != off:
        return None
    return 'current'


def read_header(path):
    with open(path, 'rb') as f:
        head = f.read(148)
    state = blp_state(head, os.path.getsize(path))
    size = struct.unpack('<II', head[12:20]) if state else (0, 0)
    return state, size


def to_bgra(img):
    r, g, b, a = img.split()
    return Image.merge('RGBA', (b, g, r, a)).tobytes()   # BGRA byte order


def encode_blp(img):
    """RGBA image with power-of-two sides -> BLP2: uncompressed BGRA, 8-bit alpha, full mip chain."""
    w, h = img.size
    levels = mip_levels(w, h)
    premultiplied = img.convert('RGBa')   # no dark fringes around transparent pixels in the small levels
    chunks = [to_bgra(img)]
    for lw, lh in levels[1:]:
        chunks.append(to_bgra(premultiplied.resize((lw, lh), RESAMPLING.BOX).convert('RGBA')))
    header = bytearray(HEADER_SIZE)
    header[0:4] = b'BLP2'
    struct.pack_into('<I', header, 4, 1)               # type 1: raw / DirectX
    header[8] = 3                                      # encoding 3: uncompressed BGRA
    header[9] = 8                                      # alpha depth
    header[10] = 8                                     # alpha encoding (as in ElvUI-for-Sirus)
    header[11] = 1                                     # has mip levels
    struct.pack_into('<II', header, 12, w, h)
    off = HEADER_SIZE
    for i, chunk in enumerate(chunks):
        struct.pack_into('<I', header, 20 + 4 * i, off)  # mip offsets
        struct.pack_into('<I', header, 84 + 4 * i, len(chunk))  # mip sizes
        off += len(chunk)
    return bytes(header) + b''.join(chunks)


def decode_blp(raw):
    """Level 0 of a BLP written by this script (any version) -> RGBA image."""
    if blp_state(raw[:148], len(raw)) is None:
        raise ValueError('not a BLP written by this script')
    w, h = struct.unpack('<II', raw[12:20])
    b, g, r, a = Image.frombytes('RGBA', (w, h), raw[HEADER_SIZE:HEADER_SIZE + w * h * 4]).split()
    return Image.merge('RGBA', (r, g, b, a))


def write_blp(dst, img):
    """Write img to dst through a temp file; dst is replaced only after a pixel-exact read-back."""
    tmp = dst + '.tmp'
    with open(tmp, 'wb') as fh:
        fh.write(encode_blp(img))
    with open(tmp, 'rb') as fh:
        raw = fh.read()
    try:
        back = decode_blp(raw)
        if blp_state(raw[:148], len(raw)) != 'current' or back.size != img.size or back.tobytes() != img.tobytes():
            raise ValueError('read-back mismatch')
    except ValueError:
        os.remove(tmp)
        raise
    os.replace(tmp, dst)


def load_sizes():
    sizes = {}
    if os.path.exists(SIZES_LUA):
        with open(SIZES_LUA, 'r', encoding='utf-8') as f:
            for m in re.finditer(r'S\["([^"]+)"\]\s*=\s*\{(\d+),\s*(\d+)\}', f.read()):
                sizes[m.group(1)] = (int(m.group(2)), int(m.group(3)))
    return sizes


def write_sizes(sizes):
    lines = [
        '-- Generated by scripts/convert_textures_335.py - do not edit by hand.',
        '-- Original pixel size of every texture in Art/ (the BLP files are scaled to a power of two).',
        '-- Key: lower-case path relative to Art/, forward slashes, no extension.',
        'local _, addon = ...',
        'local S = {}',
        'addon.TextureFileSizes = S',
        '',
    ]
    for key in sorted(sizes):
        w, h = sizes[key]
        lines.append('S["%s"] = {%d, %d}' % (key, w, h))
    with open(SIZES_LUA, 'w', encoding='utf-8', newline='\n') as f:
        f.write('\n'.join(lines) + '\n')


def read_raw_blp2(path):
    """Level 0 of a legacy raw BLP2 (encoding 3, 8-bit alpha) -> RGBA image, or None.

    Not every Pillow release decodes encoding 3, so it is handled explicitly;
    None means "not this layout" and the caller falls back to Pillow.
    """
    with open(path, 'rb') as f:
        head = f.read(148)
    if len(head) < 148 or head[:4] != b'BLP2' or head[8] != 3 or head[9] != 8:
        return None
    if struct.unpack('<I', head[4:8])[0] != 1:
        return None
    w, h = struct.unpack('<II', head[12:20])
    if w < 1 or h < 1 or w > MAX_SIZE or h > MAX_SIZE:
        return None
    offset, length = struct.unpack_from('<II', head, 20)[0], struct.unpack_from('<II', head, 84)[0]
    if offset < 148 or length != w * h * 4:
        return None
    with open(path, 'rb') as f:
        f.seek(offset)
        raw = f.read(length)
    if len(raw) != length:
        return None
    b, g, r, a = Image.frombytes('RGBA', (w, h), raw, 'raw', 'BGRA').split()
    return Image.merge('RGBA', (r, g, b, a))


def convert():
    old_sizes = load_sizes()
    sizes, resized, failed = {}, [], []
    converted = rebuilt = kept = 0
    for dp, dn, fn in os.walk(ART):
        dn.sort()
        for f in sorted(fn):
            base, ext = os.path.splitext(f)
            if ext.lower() not in SRC_EXT:
                continue
            src = os.path.join(dp, f)
            dst = os.path.join(dp, base + '.blp')
            key = os.path.relpath(os.path.join(dp, base), ART).replace('\\', '/').lower()
            if key in sizes:
                failed.append('%s: several source images with this name' % key)
                continue
            if ext.lower() == '.blp':
                state, (w, h) = read_header(src)
                if state == 'current':
                    sizes[key] = old_sizes.get(key, (w, h))
                    kept += 1
                    continue
                if state == 'nomips':
                    # Older output of this script: already a power of two, rebuild it with mip levels.
                    try:
                        with open(src, 'rb') as fh:
                            img = decode_blp(fh.read())
                        write_blp(src, img)
                    except ValueError as e:
                        failed.append('%s: %s' % (key, e))
                        continue
                    sizes[key] = old_sizes.get(key, img.size)
                    rebuilt += 1
                    continue
            try:
                img = read_raw_blp2(src)
                if img is None:
                    img = Image.open(src)
                    img.load()
            except Exception as e:  # keep the file, report it
                failed.append('%s: cannot decode (%s)' % (key, e))
                continue
            ow, oh = img.size
            img = img.convert('RGBA')
            tw, th = next_pot(ow), next_pot(oh)
            if (tw, th) != (ow, oh):
                img = img.convert('RGBa').resize((tw, th), RESAMPLING.LANCZOS).convert('RGBA')
                resized.append('%s %dx%d -> %dx%d' % (key, ow, oh, tw, th))
            try:
                write_blp(dst, img)
            except ValueError as e:
                failed.append('%s: %s' % (key, e))
                continue
            if os.path.normcase(os.path.abspath(src)) != os.path.normcase(os.path.abspath(dst)):
                os.remove(src)
            sizes[key] = (ow, oh)
            converted += 1
    write_sizes(sizes)
    print('converted: %d, mip levels added: %d, already current: %d, sizes written: %d'
          % (converted, rebuilt, kept, len(sizes)))
    for line in resized:
        print('  resized  ' + line)
    for line in failed:
        print('  FAILED   ' + line)
    return not failed


def strip_refs():
    total = 0
    for dp, dn, fn in os.walk(ROOT):
        top = os.path.relpath(dp, ROOT).split(os.sep)[0]
        if top in SKIP_TOP:
            dn[:] = []
            continue
        for f in fn:
            if not f.lower().endswith(('.lua', '.xml')):
                continue
            path = os.path.join(dp, f)
            with open(path, 'rb') as fh:
                text = fh.read().decode('utf-8')
            new, n = REF_RE.subn('', text)
            if n:
                with open(path, 'wb') as fh:
                    fh.write(new.encode('utf-8'))
                total += n
                print('  refs     %s: %d' % (os.path.relpath(path, ROOT), n))
    print('image extensions stripped: %d' % total)


if __name__ == '__main__':
    ok = convert()
    if '--refs' in sys.argv:
        strip_refs()
    sys.exit(0 if ok else 1)
