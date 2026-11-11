"""Read-only static checks for the UI template draft; not client verification."""
from pathlib import Path
import re
import xml.etree.ElementTree as ET
root = Path(__file__).resolve().parents[2]
files = ['Code/Dialogue/UITemplates.lua', 'Code/SharedUITemplates/SharedUITemplates.lua', 'Code/SharedUITemplates/GenericFrame.lua', 'Code/SharedUITemplates/SharedUITemplates.xml', 'Code/Dialogue/DialogueUI.xml', 'Code/Book/BookUI.xml', 'Code/Settings/Settings.xml', 'Code/Scroll/Scroll.xml', 'Code/Tooltip/Tooltip.xml']
errors = 0
for name in files:
    text = (root / name).read_text(encoding='utf-8-sig')
    if name.endswith('.xml'):
        try:
            ET.fromstring(text)
            print('XML OK:', name)
        except ET.ParseError as e:
            print('XML ERROR:', name, e)
            errors += 1
    if name.endswith('.lua'):
        forbidden = re.findall(r':(?:SetAtlas|SetMask|AddMaskTexture|SetTexelSnappingBias|SetSnapToPixelGrid|SetTextureSliceMargins)\s*\(', text)
        print('Unsupported direct calls:', name, len(forbidden))
        errors += len(forbidden)
for theme in ['Theme_Brown', 'Theme_Dark']:
    path = root / 'Art' / theme / 'GenericFrame-Tiled-Large.blp'
    print('Frame asset:', theme, path.exists())
print('Static errors:', errors)
print('NOT VERIFIED: Lua execution, in-client rendering, theme switching, packaging')
raise SystemExit(bool(errors))
