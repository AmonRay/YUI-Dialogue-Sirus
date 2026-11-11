"""Read-only verification of texture_report.json produced by check_textures.py.
Prints: syntax check, reference kinds, unresolved-expression summary,
dynamic-name coverage (prefix..name, table decor/keys, embedded strings),
and existence of Icons/NPCType-* assets. Writes nothing.
"""
import json
import hashlib
import re
from pathlib import Path
from collections import Counter, defaultdict

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[1]

raw = (OUT / 'texture_report.json').read_text(encoding='utf-8')
report = json.loads(raw)  # raises on invalid syntax
print('JSON SYNTAX: OK')
print('top-level keys:', sorted(report))
refs = report['references']
paths = {r['path'] for r in refs}
assert report['counts']['reference_occurrences'] == len(refs)
assert report['counts']['unique_paths'] == len(paths)
assert report['counts']['broken_unique_paths'] == len(report['broken_paths'])
assert report['counts']['broken_occurrences'] == sum(r['path'] in report['broken_paths'] for r in refs)
assert report['methodology']['coverage'] == dict(Counter(r['kind'] for r in refs))
for kind in ('decor-table', 'hotkey-table', 'inline-texture', 'locale-key', 'npc-type-table'):
    assert report['methodology']['coverage'].get(kind, 0) > 0, kind
assert not any(p.endswith(('-', '_')) for p in paths)
print('REPORT CONSISTENCY: OK')
stale = []
for name, expected in report['source_hashes'].items():
    current = (ROOT / name).read_text(encoding='utf-8-sig')
    if hashlib.sha256(current.encode()).hexdigest() != expected:
        stale.append(name)
print('SOURCE SNAPSHOT:', 'CURRENT' if not stale else 'STALE: ' + ', '.join(stale))
print('BROKEN PATHS:', report['broken_paths'])

counts = report['counts']
print('\nCOUNTS:')
for k, v in counts.items():
    print(f'  {k}: {v}')

kinds = Counter(r['kind'] for r in report['references'])
print('\nREFERENCE KINDS:')
for k, v in kinds.most_common():
    print(f'  {k}: {v}')

unresolved = report.get('unresolved', [])
print(f'\nUNRESOLVED EXPRESSIONS: {len(unresolved)}')
by_source = Counter(u['source'] for u in unresolved)
for src, n in by_source.most_common():
    print(f'  {src}: {n}')

# Dynamic-name coverage probes.
probes = {
    'bgName': re.compile(r'bgName', re.I),
    'decor': re.compile(r'decor', re.I),
    'key names': re.compile(r'\bKeys/', re.I),
    'embedded strings in expressions': re.compile(r'"'),
}
hits = defaultdict(list)
for u in unresolved:
    for label, rx in probes.items():
        if rx.search(u.get('expression', '')):
            hits[label].append(u)
print('\nUNRESOLVED PROBES:')
for label in probes:
    rows = hits[label]
    print(f'  {label}: {len(rows)}')
    for u in rows[:8]:
        print(f"    {u['source']}:{u['line']} [{u['kind']}] {u['expression'][:120]}")

# Sample of unresolved expressions overall (first 25).
print('\nUNRESOLVED SAMPLE (first 25):')
for u in unresolved[:25]:
    print(f"  {u['source']}:{u['line']} [{u['kind']}] {u['expression'][:110]}")

# NPCType assets on disk.
for base in ('Art', '_Build/DialogueUI/Art'):
    folder = ROOT / base / 'Icons'
    found = sorted(p.name for p in folder.glob('NPCType*')) if folder.is_dir() else []
    print(f'\n{base}/Icons NPCType-*: {found or "NONE"}')
    ask = sorted(p.name for p in folder.glob('AskDirection*')) if folder.is_dir() else []
    print(f'{base}/Icons AskDirection*: {ask or "NONE"}')

# Which unique paths reference NPCType / AskDirection.
for r in report['references']:
    if 'NPCType' in r['path'] or 'AskDirection' in r['path']:
        print('REF:', r)
