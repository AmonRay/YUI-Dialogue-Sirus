from pathlib import Path
import hashlib
root = Path(__file__).resolve().parents[2]
paths = ['Code/Camera.lua', 'Code/Compat/Compat_335.lua', 'Code/Dialogue/UITemplates.lua', 'Code/Dialogue/DialogueUI.lua', 'Code/Book/BookUI.xml', 'DialogueUI.toc']
for name in paths:
    assert (root / name).read_bytes() == (root / '_Build/DialogueUI' / name).read_bytes(), name
print('Build sync: 6 changed runtime files match source byte-for-byte')
