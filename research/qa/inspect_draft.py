"""QA draft helper: reads texture_report.json / snapshot_report.json and prints
exact numbers by contract category, broken paths with file:line, and dynamic
extraction completeness. Read-only; writes nothing.
"""
import json
import re
from collections import Counter, defaultdict
from pathlib import Path

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[1]
report = json.loads((OUT / 'texture_report.json').read_text(encoding='utf-8'))
snapshot = json.loads((OUT / 'snapshot_report.json').read_text(encoding='utf-8'))

print('=== COUNTS ===')
for k, v in report['counts'].items():
    print(f'{k}: {v}')

print('\n=== BROKEN PATHS (with file:line) ===')
broken = {r['path'] for r in report['references'] if r['path'] in report['broken_paths']}
for p in sorted(broken):
    print(f'PATH {p}')
    for r in report['references']:
        if r['path'] == p:
            print(f"  {r['source']}:{r['line']} kind={r['kind']}")

print('\n=== UNIQUE PATHS BY CATEGORY ===')
def category(path):
    top = path.split('/')[0]
    return top
cats = Counter(category(p) for p in {r['path'] for r in report['references']})
for c, n in sorted(cats.items()):
    print(f'{c}: {n}')

print('\n=== THEME CATEGORY DETAIL (Brown/Dark/Shared) ===')
theme_paths = defaultdict(list)
for p in sorted({r['path'] for r in report['references']}):
    if p.startswith('Theme_'):
        theme_paths[p.split('/')[1] if '/' in p else p].append(p)
print('unique theme paths:', sum(len(v) for v in theme_paths.values()))

print('\n=== UNRESOLVED EXPRESSIONS BY KIND/FILE (dynamic extraction check) ===')
unres = report['unresolved']
by_kind = Counter(r['kind'] for r in unres)
print('by kind:', dict(by_kind))
by_file = Counter(r['source'] for r in unres)
for f, n in by_file.most_common():
    print(f'{f}: {n}')

print('\n=== UNRESOLVED EXPRESSIONS (all, truncated) ===')
for r in unres:
    print(f"{r['source']}:{r['line']} [{r['kind']}] {r['expression'][:120]}")

print('\n=== EXTERNAL / NUMERIC ===')
print('external:', len(report['external']), 'numeric:', len(report['numeric']))

print('\n=== MISSING-ASSET MARKERS IN CODE ===')
markers = []
for p in sorted(set(ROOT.glob('Code/**/*.lua')) | set(ROOT.glob('Code/**/*.xml'))):
    text = p.read_text(encoding='utf-8-sig', errors='replace')
    for m in re.finditer(r'MISSING-ASSET:([^\s*]+)', text):
        markers.append((p.relative_to(ROOT).as_posix(), text.count('\n', 0, m.start()) + 1, m[1]))
print('count:', len(markers))
for src, line, name in markers:
    print(f'{src}:{line} {name}')

print('\n=== SNAPSHOT: missing static references per inventory ===')
for label, inv in snapshot['inventories'].items():
    print(label, 'missing_static_references:', inv.get('missing_static_references'))

print('\n=== SNAPSHOT: build incompatible/warnings ===')
for label, inv in snapshot['inventories'].items():
    print(label, 'total', inv['total'], 'incompatible', inv['incompatible'], 'warnings', inv['warnings'], 'formats', inv['formats'])

print('\n=== SNAPSHOT: manifest dimension mismatches ===')
for label, rows in snapshot.get('manifest_dimensions', {}).items():
    print(label, len(rows))
    for r in rows[:10]:
        print(' ', r)

print('\n=== SNAPSHOT: theme extension violations ===')
print(len(snapshot.get('theme_extension_violations', [])))
