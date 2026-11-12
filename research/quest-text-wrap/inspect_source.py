"""Read-only focused inventory; run from the workspace root."""
from pathlib import Path
import re
ROOT = Path(__file__).resolve().parents[2]
for name in ['Code/Dialogue/DialogueUI.lua', 'Code/Dialogue/UITemplates.lua', 'Code/Compat/Compat_335.lua', 'API.lua']:
    lines = (ROOT / name).read_text(encoding='utf-8-sig').splitlines()
    hits = set()
    for i, line in enumerate(lines):
        if re.search(r'AddParagraph|GetStringHeight|SetMaxLines|SetWordWrap|SetNonSpaceWrap|function .*GetQuestText|function .*SetFont|function .*SetText|function .*Layout', line):
            hits.update(range(max(0, i-3), min(len(lines), i+20)))
    print('\n### ' + name)
    for i in sorted(hits):
        print(f'{i+1}: {lines[i]}')
