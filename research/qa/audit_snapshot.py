"""Independent read-only snapshot audit; outputs only to research/qa/.
No converter, game, project test, build or git is invoked.
"""
from pathlib import Path
from collections import Counter
import datetime
import hashlib
import json
import re
import struct
import check_textures as refs

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
PATHS = {'source': ROOT, 'build': ROOT / '_Build/DialogueUI',
         'installed': Path(r'D:\World of Warcraft 3.3.5a\interface\addons\DialogueUI'),
         'patch': Path(r'D:\!sirus_addons\patch-ruRU-i\DF\Interface')}
EXT = {'.blp', '.tga', '.png', '.jpg', '.jpeg', '.dds'}
THEMES = ['Theme_Brown', 'Theme_Dark', 'Theme_Shared']

def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()

def key(p):
    return p.with_suffix('').as_posix().lower()

def header(p, pixels=True):
    result = {'path': str(p), 'issues': [], 'warnings': []}
    with p.open('rb') as f:
        h = f.read(148)
    n = p.stat().st_size
    ext = p.suffix.lower()
    alpha = None
    try:
        if ext == '.blp':
            if h[:4] != b'BLP2' or len(h) < 148:
                result['warnings'].append('BLP1/unknown: not assessed for compatibility')
                return result
            typ = struct.unpack_from('<I', h, 4)[0]
            enc, depth, aenc, mips = h[8:12]
            w, ht = struct.unpack_from('<II', h, 12)
            offsets = struct.unpack_from('<16I', h, 20)
            sizes = struct.unpack_from('<16I', h, 84)
            result.update(format='BLP2', encoding=enc, alpha_bits=depth, alpha_encoding=aenc,
                          mip_flag=mips, mip_count=sum(bool(x) for x in sizes))
            if typ != 1 or enc not in (1, 2, 3) or depth not in (0, 1, 4, 8):
                result['issues'].append('unsupported BLP2 fields')
            for off, size in zip(offsets, sizes):
                if size and (off < 148 or off + size > n):
                    result['issues'].append('mip outside file')
            if enc == 3:
                if sizes[0] != w * ht * 4:
                    result['issues'].append('BGRA level zero byte count')
                if pixels and offsets[0] + sizes[0] <= n:
                    with p.open('rb') as f:
                        f.seek(offsets[0]); alpha = f.read(sizes[0])[3::4]
            expected = max(w, ht).bit_length()
            if result['mip_count'] != expected:
                result['warnings'].append('incomplete mip chain')
        elif ext == '.tga':
            if len(h) < 18:
                raise ValueError('short TGA header')
            ident, cmap, kind = h[:3]
            w, ht, bits, desc = struct.unpack_from('<HHBB', h, 12)
            result.update(format='TGA', image_type=kind, pixel_bits=bits, alpha_bits=desc & 15,
                          origin_top=bool(desc & 32))
            if cmap or kind not in (2, 10) or bits not in (24, 32):
                result['issues'].append('unsupported TGA layout')
            if kind == 10:
                result['warnings'].append('RLE TGA: legacy client compatibility requires runtime check')
            if bits == 32 and (desc & 15) != 8:
                result['warnings'].append('32-bit TGA without declared 8-bit alpha')
            if pixels and not cmap and kind in (2, 10) and bits in (24, 32):
                raw = p.read_bytes()[18 + ident:]
                step = bits // 8
                count = w * ht
                if kind == 2:
                    if len(raw) < count * step:
                        raise ValueError('truncated TGA pixels')
                    if bits == 32:
                        alpha = raw[:count * step][3::4]
                else:
                    pos, done, values = 0, 0, bytearray()
                    while done < count:
                        packet = raw[pos]; pos += 1
                        length = (packet & 127) + 1
                        if done + length > count:
                            raise ValueError('TGA RLE pixel overflow')
                        take = step if packet & 128 else length * step
                        chunk = raw[pos:pos + take]; pos += take
                        if len(chunk) != take:
                            raise ValueError('truncated TGA RLE')
                        if bits == 32:
                            values.extend(bytes([chunk[3]]) * length if packet & 128 else chunk[3::4])
                        done += length
                    if bits == 32:
                        alpha = values
        else:
            result['issues'].append('not BLP/TGA: not accepted by audit compatibility contract')
            return result
        result['dimensions'] = [w, ht]
        if not w or not ht or w > 2048 or ht > 2048 or w & (w - 1) or ht & (ht - 1):
            result['issues'].append('dimensions zero/non-power-of-two/above 2048')
        if alpha is not None and len(alpha):
            result['alpha_range'] = [min(alpha), max(alpha)]
            result['transparent_pixels'] = alpha.count(0)
            result['opaque_pixels'] = alpha.count(255)
            if max(alpha) == 0:
                result['warnings'].append('fully transparent: may be intentional mask')
    except (ValueError, struct.error, IndexError) as e:
        result['issues'].append(str(e))
    return result

def load_order(root):
    seq, missing, cycles, inherited, definitions = [], [], [], [], set()
    def walk(p, stack):
        if not p.is_file():
            missing.append(str(p.relative_to(root))); return
        if p in stack:
            cycles.append(str(p)); return
        rel = p.relative_to(root).as_posix()
        seq.append(rel)
        text = p.read_text(encoding='utf-8-sig')
        if p.suffix.lower() == '.toc':
            for line in text.splitlines():
                line = line.strip()
                if line and not line.startswith('#'):
                    walk(root / line.replace('\\', '/'), stack + [p])
        elif p.suffix.lower() == '.xml':
            text = re.sub(r'<!--[\s\S]*?-->', '', text)
            for m in re.finditer(r'<([\w:]+)\b([^<>]*)>', text):
                tag, attr = m.groups()
                attrs = dict(re.findall(r'(\w+)="([^"]*)"', attr))
                if tag in ('Script', 'Include') and 'file' in attrs:
                    walk(p.parent / attrs['file'].replace('\\', '/'), stack + [p])
                for name in attrs.get('inherits', '').split(','):
                    name = name.strip()
                    if name.startswith('DUI') and name not in definitions:
                        inherited.append({'source': rel, 'line': text.count('\n', 0, m.start()) + 1,
                                          'template': name})
                if attrs.get('virtual') == 'true' and 'name' in attrs:
                    definitions.add(attrs['name'])
    walk(root / 'DialogueUI.toc', [])
    positions = {p: i for i, p in enumerate(seq)}
    required = ['Code/Compat/Compat_335.lua', 'Code/Compat/TextureSizes_335.lua',
                'Initialization.lua', 'Code/Utility/ThemeUtil.lua', 'Code/Utility/TextureSlice.lua',
                'Code/SharedUITemplates/SharedUITemplates.xml', 'Code/Dialogue/DialogueUI.xml', 'Code/Book/BookUI.xml']
    return dict(files=len(seq), sequence=seq, missing=missing, cycles=cycles,
                dui_inherits_before_definition=inherited,
                required_positions={p: positions.get(p) for p in required})

def compare(a, b):
    common = sorted(set(a) & set(b))
    changed = [p for p in common if a[p] != b[p]]
    return dict(compared=len(common), different=len(changed), different_paths=changed,
                missing_in_target=sorted(set(a) - set(b)), extra_in_target=sorted(set(b) - set(a)))

def main():
    started = datetime.datetime.now().astimezone().isoformat()
    refs.main()
    extracted = json.loads((OUT / 'texture_report.json').read_text(encoding='utf-8'))
    report = {'started': started, 'paths': {}, 'inventories': {}, 'load_order': {}, 'comparisons': {}}
    hashes, asset_keys = {}, {}
    for label, root in PATHS.items():
        entry = {'path': str(root), 'accessible': root.is_dir()}
        report['paths'][label] = entry
        if not root.is_dir():
            continue
        art = root if label == 'patch' else root / 'Art'
        files = sorted(p for p in art.rglob('*') if p.is_file() and p.suffix.lower() in EXT)
        rows = []
        for p in files:
            row = header(p, pixels=label != 'patch')
            row['path'] = p.relative_to(art).as_posix()
            rows.append(row)
        asset_keys[label] = {key(Path(r['path'])) for r in rows}
        report['inventories'][label] = dict(total=len(rows),
            incompatible=sum(bool(r['issues']) for r in rows), warnings=sum(bool(r['warnings']) for r in rows),
            formats=dict(Counter(Path(r['path']).suffix.lower() for r in rows)),
            theme_counts={t: sum(r['path'].startswith(t + '/') for r in rows) for t in THEMES}, rows=rows)
        if label == 'patch':
            continue
        report['load_order'][label] = load_order(root)
        selected = set(root.glob('*.toc')) | set(root.glob('*.lua')) | set(root.glob('*.xml'))
        selected |= {p for p in (root / 'Code').rglob('*') if p.is_file() and p.suffix.lower() in ('.lua', '.xml')}
        selected |= set(files)
        hashes[label] = {p.relative_to(root).as_posix(): sha(p) for p in sorted(selected)}
    for target in ('build', 'installed'):
        if target in hashes:
            report['comparisons']['source_to_' + target] = compare(hashes['source'], hashes[target])
            report['comparisons']['art_names_source_to_' + target] = dict(
                missing=sorted(asset_keys['source'] - asset_keys[target]), extra=sorted(asset_keys[target] - asset_keys['source']))
    if 'installed' in hashes and 'build' in hashes:
        report['comparisons']['build_to_installed'] = compare(hashes['build'], hashes['installed'])
    for label in ('source', 'build', 'installed'):
        if label in asset_keys:
            report['inventories'][label]['missing_static_references'] = sorted(
                {r['path'] for r in extracted['references'] if r['path'].lower() not in asset_keys[label]})
    manifest = {m[1]: [int(m[2]), int(m[3])] for m in re.finditer(
        r'S\["([^"]+)"\]\s*=\s*\{(\d+),\s*(\d+)\}',
        (ROOT / 'Code/Compat/TextureSizes_335.lua').read_text(encoding='utf-8-sig'))}
    report['manifest_dimensions'] = {label: [dict(path=r['path'], dimensions=r['dimensions'],
        manifest=manifest.get(key(Path(r['path'])))) for r in inv['rows'] if 'dimensions' in r
        and manifest.get(key(Path(r['path']))) != r['dimensions']]
        for label, inv in report['inventories'].items() if label != 'patch'}
    report['reference_counts'] = extracted['counts']
    report['input_hashes'] = hashes
    report['theme_extension_violations'] = []
    for p in sorted(set((ROOT / 'Code').rglob('*.lua')) | set((ROOT / 'Code').rglob('*.xml'))):
        text = refs.strip_comments(p.read_text(encoding='utf-8-sig'), p.suffix == '.xml')
        for m in refs.STRING.finditer(text):
            value = refs.decode(m[0]).replace('\\', '/')
            if value.lower().startswith(refs.PREFIX.lower() + 'theme_') and Path(value).suffix.lower() in EXT:
                report['theme_extension_violations'].append(dict(source=p.relative_to(ROOT).as_posix(),
                    line=text.count('\n', 0, m.start()) + 1, value=value))
    report['finished'] = datetime.datetime.now().astimezone().isoformat()
    (OUT / 'snapshot_report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
    lines = ['# Независимый статический аудит текущего снимка', '', 'Начало: ' + started,
        'Конец: ' + report['finished'], '',
        'Это непроверенная в игре передача ведущему. Код, ресурсы, сборка и внешние папки не изменялись.',
        'Снимок не атомарный: параллельные правки могли произойти во время чтения; хеши прочитанных файлов сохранены.',
        'Проверены заголовки BLP2/TGA, границы mip-уровней, размеры, объявленная альфа; для BGRA/TGA также диапазон альфы.',
        'BLP1 не считается автоматически несовместимым: требует отдельного анализа. RLE TGA — риск, не доказанный отказ.',
        'Другие форматы помечаются несовместимыми по консервативному контракту BLP/TGA.',
        'Размеры manifest исходные; отличие от размера после масштабирования само по себе не дефект.',
        'Хеш-сравнение выполняется для Art, Code, корневых TOC/Lua/XML; Fonts/Sound и служебные папки не включены.',
        'Ссылки извлекаются эвристически; динамические выражения и сторонние Interface пути не считаются доказанно исправными.',
        'ThemeUtil раскрывается в Brown/Dark с Shared fallback по manifest; нетематические пути не переносятся.', '', '## Доступность']
    for label, entry in report['paths'].items():
        lines.append(f"- {label}: `{entry['path']}` — {'доступен' if entry['accessible'] else 'НЕДОСТУПЕН'}")
    lines += ['', '## Ссылки', '```json', json.dumps(extracted['counts'], indent=2), '```',
              'Нарушения расширений в прямых тематических ссылках: ' + str(len(report['theme_extension_violations']))]
    for label, inv in report['inventories'].items():
        lines += ['', '## ' + label, f"Файлов: {inv['total']}; несовместимых по статическим правилам: {inv['incompatible']}; с предупреждениями: {inv['warnings']}.",
                  'Покрытие тем: ' + json.dumps(inv['theme_counts']), 'Форматы: ' + json.dumps(inv['formats'])]
        if label != 'patch':
            missing = inv['missing_static_references']
            lines += [f'Отсутствующих уникальных статических ссылок: {len(missing)}.'] + ['- `' + p + '`' for p in missing]
        for row in inv['rows']:
            if row['issues']:
                lines.append('- Несовместим: `' + row['path'] + '` — ' + '; '.join(row['issues']))
    for name, data in report['comparisons'].items():
        lines += ['', '## ' + name]
        if 'compared' in data:
            lines += [f"Сопоставлено {data['compared']}; различаются {data['different']}; отсутствуют {len(data['missing_in_target'])}; лишние {len(data['extra_in_target'])}.",
                      'Различающиеся файлы:'] + ['- `' + p + '`' for p in data['different_paths']]
        else:
            lines += [f"Относительные имена без расширений: отсутствуют {len(data['missing'])}; лишние {len(data['extra'])}."] + ['- Нет: `' + p + '`' for p in data['missing']]
    for label, order in report['load_order'].items():
        lines += ['', '## Порядок загрузки: ' + label, f"Прочитано в порядке загрузки: {order['files']}; отсутствует {len(order['missing'])}; циклов {len(order['cycles'])}; DUI inherits до определения {len(order['dui_inherits_before_definition'])}.",
                  '```json', json.dumps({k: v for k, v in order.items() if k != 'sequence'}, ensure_ascii=False, indent=2), '```']
    lines += ['', '## Ограничения и следующий шаг',
        'Полные заголовки, диапазоны альфы, размеры, последовательности загрузки и различия: snapshot_report.json.',
        'Все исходные ссылки, динамические выражения и битые пути по темам: texture_report.md / texture_report.json.',
        'Слои, нарезка, выбор расширения клиентом, ранняя инициализация и отображение в Sirus не доказаны статикой.',
        'Нужны интеграция ведущим, повтор этой проверки после пересборки и проверка обеих тем, книги и общих окон в игре.',
        'Коммит, push, пересборка и обновление релиза в этом задании не выполнялись.']
    (OUT / 'snapshot_report.md').write_text('\n'.join(lines) + '\n', encoding='utf-8')
    print('SNAPSHOT SUMMARY')
    for label, inv in report['inventories'].items():
        print(label, json.dumps({k: v for k, v in inv.items() if k != 'rows'}))
    for name, data in report['comparisons'].items():
        print(name, json.dumps({k: len(v) if isinstance(v, list) else v for k, v in data.items()}))
    print('Paths:', json.dumps(report['paths']))
    print('Reports: research/qa/snapshot_report.md, research/qa/snapshot_report.json')

if __name__ == '__main__':
    main()
