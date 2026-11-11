"""Static checks for the assigned UI draft; not a WoW client test."""
from pathlib import Path
import re
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[2]
art = root / 'Art'
errors = []
for folder in ('Code/Dialogue', 'Code/SharedUITemplates'):
    for path in sorted((root / folder).glob('*')):
        if path.suffix == '.xml':
            try:
                ET.fromstring(path.read_text(encoding='utf-8-sig'))
            except ET.ParseError as exc:
                errors.append(f'{path.relative_to(root)}: XML {exc}')
        if path.suffix != '.lua':
            continue
        text = path.read_text(encoding='utf-8-sig')
        for label, pattern in (
            ('modern texture API', r':(?:SetAtlas|SetMask|AddMaskTexture|SetTexelSnappingBias|SetSnapToPixelGrid|SetTextureSliceMargins)\s*\('),
            ('direct addon texture path', r'Interface[/\\]AddOns[/\\]DialogueUI[/\\]Art[/\\]'),
            ('fixed theme selection', r':SetTheme\([12]\)'),
        ):
            for match in re.finditer(pattern, text):
                errors.append(f'{path.relative_to(root)}:{text.count(chr(10), 0, match.start()) + 1}: {label}')
        for match in re.finditer(r'GetTextureFile\("([^"\n]+)"\)', text):
            name = match.group(1).replace('\\', '/')
            directories = ('Theme_Brown', 'Theme_Dark', 'Theme_Shared', 'Icons', 'Keys', 'GameAssets', 'Book', 'BasicShapes', 'ParchmentDecor', 'PreviewPicture')
            if '/' in name:
                candidates = [art / name]
            else:
                candidates = [art / folder / name for folder in directories]
            if not any(any(candidate.with_suffix(ext).is_file() for ext in ('.blp', '.tga', '.jpg', '.png')) for candidate in candidates):
                errors.append(f'{path.relative_to(root)}:{text.count(chr(10), 0, match.start()) + 1}: missing asset {name}')
for folder, name in (('Theme_Brown', 'GenericFrame-Tiled-Large'), ('Theme_Dark', 'GenericFrame-Tiled-Large'), ('Theme_Shared', 'HelpTip')):
    if not (art / folder / (name + '.blp')).is_file():
        errors.append(f'missing slice artwork: {folder}/{name}')
print('Assigned Lua/XML static errors:', len(errors))
for error in errors:
    print(error)
print('NOT VERIFIED: Lua execution, in-client visuals, masks, theme switching and packaging')
raise SystemExit(bool(errors))
