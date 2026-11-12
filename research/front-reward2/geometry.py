"""Analytical geometry only; does not execute Lua or inspect image pixels."""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[2]
xml = (root / 'Code/Dialogue/DialogueUI.xml').read_text(encoding='utf-8-sig')
lua = (root / 'Code/Dialogue/UITemplates.lua').read_text(encoding='utf-8-sig')
area = float(re.search(r'parentKey="AreaDefinitionItemBorder">\s*<Size x="([\d.]+)"', xml).group(1))
shrink = float(re.search(r'local iconShrink = ([\d.]+)', lua).group(1))
button = re.search(r'name="DUIDialogItemButtonTemplate"[^>]*>[^<]*\s*<Size x="([\d.]+)" y="([\d.]+)"', xml)
w, h = map(float, button.groups())
print(f'XML button={w:g}x{h:g}, area={area:g}x{area:g}, inset={shrink:g} physical px per side')
print('q = effectiveScale * screenHeight / 768; physical icon side = area*q - 2*inset')
for q in (1, 1.5, 1.8, 2):
    offset = shrink / q
    side = area*q - 2*shrink
    count_right = (area-offset-1)*q
    count_bottom_up = (offset+1)*q
    print(f'q={q:.2f}: offset_UI={offset:.4f}; button_px={w*q:.1f}x{h*q:.1f}; icon_px={side:.1f}x{side:.1f}; count_right_px={count_right:.1f}; count_bottom_above_button_px={count_bottom_up:.1f}')
print('UV span = 0.9275 - 0.0625 = 0.865 on BOTH axes; UV aspect = 1.0')
print('No screenshot calibration or client execution performed.')
