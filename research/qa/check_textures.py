"""Read-only static asset audit. Writes reports only beside this script.
No Lua execution; unresolved runtime expressions are explicitly retained.
Counts are syntactic occurrences, not runtime calls. Inventory != reachability.
"""
from pathlib import Path
import re
import json
import hashlib
from collections import defaultdict, Counter
from difflib import get_close_matches

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
EXTS = {'.blp', '.tga', '.png', '.dds', '.jpg'}
PREFIX = 'Interface/AddOns/DialogueUI/Art/'
STRING = re.compile(r'"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'|\[\[.*?\]\]', re.S)


def decode(token):
    if token.startswith('[['):
        return token[2:-2]
    return re.sub(r'\\([\\"\'])', r'\1', token[1:-1])


def strip_comments(text, xml=False):
    # Preserve newlines and strings so source locations remain valid.
    pattern = r'<!--[\s\S]*?-->' if xml else r'--\[\[[\s\S]*?\]\]|--[^\n]*'
    combined = re.compile(STRING.pattern + '|' + pattern, re.S)
    return combined.sub(lambda m: m[0] if STRING.fullmatch(m[0]) else re.sub(r'[^\n]', ' ', m[0]), text)


def normal(value):
    value = value.replace('\\', '/')
    value = re.sub('/+', '/', value)
    if value.lower().startswith(PREFIX.lower()):
        value = value[len(PREFIX):]
    if Path(value).suffix.lower() in EXTS:
        value = value[:value.rfind('.')]
    return value


def inventory(folder):
    return sorted(p.relative_to(folder).as_posix() for p in folder.rglob('*')
                  if p.is_file() and p.suffix.lower() in EXTS)


def main():
    for folder in ('Code', 'Art', '_Build/DialogueUI/Art'):
        if not (ROOT / folder).is_dir():
            raise SystemExit('Required directory missing: ' + folder)
    src = inventory(ROOT / 'Art')
    build = inventory(ROOT / '_Build/DialogueUI/Art')
    lookup = defaultdict(list)
    for p in build:
        lookup[normal(p).lower()].append(p)
    source_keys = {normal(p).lower(): p for p in src}
    files = sorted(set((ROOT / 'Code').rglob('*.lua')) | set((ROOT / 'Code').rglob('*.xml'))
                   | set(ROOT.glob('*.lua')) | set(ROOT.glob('*.xml')))
    refs, unresolved, external, numeric, hashes = [], [], [], [], {}
    seen = set()

    def add(path, file, text, pos, kind):
        path = normal(path)
        if not path or path.endswith('/') or '%' in path:
            return
        key = (str(file), pos, path)
        if key in seen:
            return
        seen.add(key)
        refs.append(dict(path=path, source=file.relative_to(ROOT).as_posix(),
                         line=text.count('\n', 0, pos) + 1, kind=kind))

    def theme(name, file, text, pos, kind):
        name = normal(name)
        if name.lower().startswith('theme_'):
            add(name, file, text, pos, kind)
            return
        if name.endswith(('-', '_')):
            add(name, file, text, pos, 'dynamic-prefix')
            return
        for folder in ('Theme_Brown', 'Theme_Dark'):
            candidate = folder + '/' + name
            # Match ThemeUtil shared fallback against its manifest, not build existence.
            shared = 'Theme_Shared/' + name
            if candidate.lower() not in manifest and shared.lower() in manifest:
                candidate = shared
            else:
                # ThemeUtil searches the remaining categories for bare names.
                for category in ('Icons', 'Keys', 'GameAssets', 'Book', 'BasicShapes',
                                 'ParchmentDecor', 'PreviewPicture'):
                    if (category + '/' + name).lower() in manifest:
                        candidate = category + '/' + name
                        break
            add(candidate, file, text, pos, kind)

    manifest_text = (ROOT / 'Code/Compat/TextureSizes_335.lua').read_text(encoding='utf-8-sig')
    manifest = {normal(decode(m[0])).lower() for m in STRING.finditer(manifest_text)}
    for file in files:
        raw = file.read_text(encoding='utf-8-sig')
        hashes[file.relative_to(ROOT).as_posix()] = hashlib.sha256(raw.encode()).hexdigest()
        text = strip_comments(raw, file.suffix == '.xml')
        tokens = list(STRING.finditer(text))
        variables = {}
        # A small constant propagator, deliberately not an interpreter.
        assignments = list(re.finditer(r'\b(?:local\s+)?(\w+)\s*=\s*([^;\n]+)', text))
        for _ in range(4):
            for a in assignments:
                expr = a[2].strip()
                parts = re.split(r'\s*\.\.\s*', expr)
                values = []
                for part in parts:
                    if STRING.fullmatch(part):
                        values.append(decode(part))
                    elif part in variables:
                        values.append(variables[part])
                    elif re.fullmatch(r'(?:addon\.)?ThemeUtil:GetTexturePath\(\)', part):
                        values.append('@THEME/')
                    else:
                        break
                else:
                    variables[a[1]] = ''.join(values)
        # Literal absolute addon paths, including XML file attributes.
        for token in tokens:
            value = decode(token[0]).replace('\\', '/')
            tail = text[token.end():].lstrip()
            if value.lower().startswith(PREFIX.lower()):
                if tail.startswith('..') or value.endswith('/'):
                    continue  # Prefix, not a complete filename.
                add(value, file, text, token.start(), 'literal-art')
        # Theme, shared helpers and XML wrapper names.
        for m in re.finditer(r'(GetTextureFile|GetSharedTextureFile|DUI_SetSharedTexture)\s*\(\s*', text):
            offset = m.end()
            if m[1] == 'DUI_SetSharedTexture':
                comma = text.find(',', offset)
                if comma < 0:
                    continue
                offset = comma + 1
                while offset < len(text) and text[offset].isspace():
                    offset += 1
            token = STRING.match(text, offset)
            if token:
                name = decode(token[0])
                if m[1] == 'GetTextureFile':
                    theme(name, file, text, token.start(), 'theme-helper')
                else:
                    add('Theme_Shared/' + name, file, text, token.start(), 'shared-helper')
        # Resolve constant path-prefix concatenation anywhere (tables included).
        for m in re.finditer(r'\b(\w+)\s*\.\.\s*(' + STRING.pattern + ')', text):
            prefix = variables.get(m[1], '')
            name = decode(m[2])
            if prefix.startswith('@THEME/'):
                theme(name, file, text, m.start(), 'theme-concat')
            elif prefix.lower().startswith(PREFIX.lower()):
                add(prefix + name, file, text, m.start(), 'constant-concat')
        # Structured table fields that feed theme helpers through variables.
        for m in re.finditer(r'\b(file|fileID|frontTexture|backTexture)\s*=\s*(' + STRING.pattern + ')', text):
            name = decode(m[2])
            if '/' in name or '\\' in name:
                continue
            if file.name == 'BookUI.lua' and m[1] == 'file':
                theme_block = text.rfind('local TextureKit =', 0, m.start())
                if theme_block >= 0 and m.start() - theme_block < 1000:
                    add('Book/TextureKit-' + name, file, text, m.start(), 'book-texturekit')
                    continue
            if m[1] in ('frontTexture', 'backTexture') or (file.name == 'GenericFrame.lua' and m[1] == 'file'):
                theme(name, file, text, m.start(), 'theme-table')
        # Every texture API / fileID expression is captured, even when unresolved.
        for m in re.finditer(r'\b(SetTexture|SetAtlas|SetUITexture|fileID)\s*(?:\(\s*|=\s*)([^\n;]+)', text):
            expr = m[2].strip()
            row = dict(source=file.relative_to(ROOT).as_posix(), line=text.count('\n', 0, m.start()) + 1,
                       kind=m[1], expression=expr[:300])
            first = STRING.match(expr)
            if first:
                value = decode(first[0])
                if value.lower().startswith('interface') and not value.lower().startswith(PREFIX.lower()):
                    external.append(dict(row, path=value))
                    continue
            if re.match(r'\d+(?:\s*[,)]|$)', expr):
                numeric.append(row)
            elif not first and not expr.startswith('nil'):
                unresolved.append(row)
        # RedirectTextureKit keys form dynamic GameAssets filenames.
        for block in re.finditer(r'local RedirectTextureKit\s*=\s*\{([^}]+)\}', text):
            for m in re.finditer(r'(\w+)\s*=\s*true', block[1]):
                add('GameAssets/ui_majorfactions_' + m[1], file, text,
                    block.start(1) + m.start(), 'redirect-texturekit')
    unique = sorted({r['path'] for r in refs})
    dynamic_prefixes = [p for p in unique if p.endswith(('-', '_'))]
    missing = [p for p in unique if p.lower() not in lookup and not p.endswith(('-', '_'))]
    case = [{'reference': p, 'files': lookup[p.lower()]} for p in unique
            if p.lower() in lookup and not any(normal(f) == p for f in lookup[p.lower()])]
    used = {p.lower() for p in unique}
    unused = [p for p in build if normal(p).lower() not in used]
    build_keys = {normal(p).lower() for p in build}
    missing_conversion = [p for p in src if normal(p).lower() not in build_keys]
    suggestions = {p: get_close_matches(p.lower(), sorted(set(lookup) | set(source_keys)), n=3, cutoff=0.65)
                   for p in missing}
    counts = dict(scanned_files=len(files), reference_occurrences=len(refs), unique_paths=len(unique),
                  broken_unique_paths=len(missing), broken_occurrences=sum(r['path'] in missing for r in refs),
                  source_assets=len(src), build_assets=len(build),
                  sources_missing_in_build=len(missing_conversion), unmentioned_build_assets=len(unused),
                  case_mismatches=len(case), unresolved_expressions=len(unresolved),
                  numeric_expressions=len(numeric), external_literals=len(external),
                  dynamic_prefixes=len(dynamic_prefixes))
    report = dict(counts=counts, references=refs, broken_paths=missing, case_mismatches=case,
                  suffix_or_name_candidates=suggestions, unmentioned_build_assets=unused,
                  sources_missing_in_build=missing_conversion, unresolved=unresolved,                  numeric=numeric, external=external, source_hashes=hashes)
    (OUT / 'texture_report.json').write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding='utf-8')
    lines = ['# Статический аудит текстур (не игровая проверка)', '',
             'Сканируются Code/** и корневые .lua/.xml; комментарии исключаются.',
             'Ссылки = извлечённые статические упоминания; ThemeUtil раскрывается в две темы.',
             'Недостающий путь = нет файла любого поддерживаемого расширения без учёта регистра.',
             'Отсутствующие в сборке исходники перечислены независимо от ссылок.',
             'Неупомянутые TGA не равнозначны неиспользуемым: динамические выражения не исполняются.',
             'Числовые fileID/SetTexture могут быть цветовыми аргументами; требуется ручная оценка.',
             'Кандидаты похожих имён — эвристика, не доказанные замены.', '']
    lines += [f'- {k}: **{v}**' for k, v in counts.items()]
    for title, paths in [('Битые пути по темам', missing), ('Динамические префиксы (конкатенация, не файлы)', dynamic_prefixes),
                         ('Исходники без файла в сборке', missing_conversion),
                         ('Ассеты сборки без статических упоминаний', unused)]:
        lines += ['', '## ' + title]
        groups = defaultdict(list)
        for p in paths:
            groups[p.split('/')[0]].append(p)
        if not groups:
            lines.append('Нет.')
        for group, entries in sorted(groups.items()):
            lines += ['', f'### {group} ({len(entries)})'] + ['- `' + p + '`' for p in entries]
    lines += ['', '## Регистр', '```json', json.dumps(case, ensure_ascii=False, indent=2), '```',
              '', '## Похожие имена / суффиксы', '```json', json.dumps(suggestions, ensure_ascii=False, indent=2), '```',
              '', 'Полные ссылки, места вызовов, динамические выражения и хеши входных файлов: texture_report.json.']
    (OUT / 'texture_report.md').write_text('\n'.join(lines) + '\n', encoding='utf-8')
    print(json.dumps(counts, indent=2))
    print('BROKEN PATHS:')
    for p in missing:
        print(p)
    print('Reports: research/qa/texture_report.md, research/qa/texture_report.json')


if __name__ == '__main__':
    main()
