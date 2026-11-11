# 3.3.5a has no OnGamePad* script handlers: Frame:SetScript("OnGamePadButtonDown", ...) throws
# "<frame> doesn't have a ... script". Route such calls through DUI_SetScriptSafe (Compat_335.lua),
# which only sets scripts the widget actually supports (HasScript).
import re, pathlib
root = pathlib.Path(__file__).resolve().parent.parent
pat = re.compile(r'([A-Za-z_][\w\.]*):SetScript\("(OnGamePad\w+)",\s*')
total = 0
for p in root.rglob('*.lua'):
    if any(part in ('_Build', '.git') for part in p.parts):
        continue
    raw = p.read_bytes()
    text = raw.decode('utf-8')
    new, n = pat.subn(lambda m: 'DUI_SetScriptSafe(%s, "%s", ' % (m.group(1), m.group(2)), text)
    if n:
        p.write_bytes(new.encode('utf-8'))
        print(p.relative_to(root), n)
        total += n
print('Total:', total)
