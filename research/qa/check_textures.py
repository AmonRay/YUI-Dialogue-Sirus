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
        if name.endswith(('-', '_')):
            return  # Incomplete expressions are not assets.
        if name.lower().startswith('theme_') or '/' in name:
            add(name, file, text, pos, kind)
            return
        for folder in ('Theme_Brown', 'Theme_Dark'):
            # Match the resolver's active-theme-first search, then shared categories.
            candidate = folder + '/' + name
            if candidate.lower() not in manifest:
                for category in ('Theme_Shared', 'Icons', 'Keys', 'GameAssets', 'Book',
                                 'BasicShapes', 'ParchmentDecor', 'PreviewPicture', 'Shared'):
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
                if tail.startswith('..') or value.endswith('/') or value.endswith(('-', '_')):
                    continue  # Prefix, not a complete filename.
                add(value, file, text, token.start(), 'literal-art')
            # Inline WoW texture escape embedded in a larger Lua string.
            for inline in re.finditer(r'\|T(Interface[/\\]AddOns[/\\]DialogueUI[/\\]Art[/\\][^:|]+)', value, re.I):
                add(inline[1], file, text, token.start() + inline.start(1), 'inline-texture')
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
        # Finite local string alternatives (including prefix..bgName patterns).
        literal_values = defaultdict(list)
        for a in re.finditer(r'\b(\w+)\s*=\s*(' + STRING.pattern + ')', text):
            literal_values[a[1]].append((decode(a[2]), a.start(2)))
        for m in re.finditer(r'\b(\w+)\s*\.\.\s*(\w+)\b', text):
            prefix = variables.get(m[1], '')
            for value, pos in literal_values.get(m[2], []):
                if prefix.startswith('@THEME/'):
                    theme(value, file, text, pos, 'theme-variable-concat')
                elif prefix.lower().startswith(PREFIX.lower()):
                    add(prefix + value, file, text, pos, 'variable-concat')
        for m in re.finditer(r'GetTextureFile\(\s*(\w+)\s*\)', text):
            for value, pos in literal_values.get(m[1], []):
                theme(value, file, text, pos, 'theme-variable')
        # Simple string-valued tables passed by indexed name to the theme resolver.
        for table_name in ('backgrounds', 'CUSTOM_ICONS'):
            if re.search(r'GetTextureFile\(\s*' + table_name + r'\[', text):
                for block in re.finditer(r'local ' + table_name + r'\s*=\s*\{([^}]+)\}', text):
                    for item in re.finditer(r'\[[^]]+\]\s*=\s*(' + STRING.pattern + ')', block[1]):
                        theme(decode(item[1]), file, text, block.start(1) + item.start(1), 'theme-index-table')
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
        # Bounded runtime domains: table values actually concatenated with an Art prefix.
        for prefix_var, table_var, table_pattern, value_pattern, kind in (
            ('TexturePrefix', 'CustomTypeTexture', r'local CustomTypeTexture\s*=\s*\{([^}]+)\}',
             r'\b\w+\s*=\s*(' + STRING.pattern + ')', 'npc-type-table'),
            ('DECOR_PATH', 'BackgroundDecors', r'local BackgroundDecors\s*=\s*\{([^}]+)\}',
             r'\[[^]]+\]\s*=\s*(' + STRING.pattern + ')', 'decor-table'),
        ):
            prefix = variables.get(prefix_var, '')
            if prefix.lower().startswith(PREFIX.lower()) and re.search(
                    rf'\b{prefix_var}\s*\.\.\s*{table_var}\s*\[', text):
                for block in re.finditer(table_pattern, text):
                    for item in re.finditer(value_pattern, block[1]):
                        add(prefix + decode(item[1]), file, text,
                            block.start(1) + item.start(1), kind)
        # Literal keys in the table consumed by ThemeUtil:GetTextureFile(iconData.file).
        if file.name == 'UITemplates.lua' and 'ThemeUtil:GetTextureFile(iconData.file)' in text:
            for block in re.finditer(r'local HotkeyIcons\s*=\s*\{(.*?)\n\};', text, re.S):
                for item in re.finditer(r'\bfile\s*=\s*(' + STRING.pattern + ')', block[1]):
                    theme(decode(item[1]), file, text, block.start(1) + item.start(1), 'hotkey-table')
        # RedirectTextureKit keys form dynamic GameAssets filenames.
        for block in re.finditer(r'local RedirectTextureKit\s*=\s*\{([^}]+)\}', text):
            for m in re.finditer(r'(\w+)\s*=\s*true', block[1]):
                add('GameAssets/ui_majorfactions_' + m[1], file, text,
                    block.start(1) + m.start(), 'redirect-texturekit')
    # Locale tokens consumed by LocaleFormatter's dynamically formatted Keys path.
    locale_files = sorted((ROOT / 'Locales').glob('*.lua'))
    for file in locale_files:
        raw = file.read_text(encoding='utf-8-sig')
        hashes[file.relative_to(ROOT).as_posix()] = hashlib.sha256(raw.encode()).hexdigest()
        text = strip_comments(raw)
        for m in re.finditer(r'\[KEY:(\w+):(\w+)\]', text):
            add('Keys/' + m[1] + '-' + m[2], file, text, m.start(), 'locale-key')
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
    counts = dict(scanned_files=len(files) + len(locale_files), reference_occurrences=len(refs), unique_paths=len(unique),
                  broken_unique_paths=len(missing), broken_occurrences=sum(r['path'] in missing for r in refs),
                  source_assets=len(src), build_assets=len(build),
                  sources_missing_in_build=len(missing_conversion), unmentioned_build_assets=len(unused),
                  case_mismatches=len(case), unresolved_expressions=len(unresolved),
                  numeric_expressions=len(numeric), external_literals=len(external),
                  dynamic_prefixes=len(dynamic_prefixes))
    report = dict(counts=counts, references=refs, broken_paths=missing, case_mismatches=case,
                  suffix_or_name_candidates=suggestions, unmentioned_build_assets=unused,
                  sources_missing_in_build=missing_conversion, unresolved=unresolved,                  numeric=numeric, external=external, source_hashes=hashes)
    report['methodology'] = {
        'status': 'UNVERIFIED draft: static scan only, no game execution',
        'count_unit': 'Unique (source file, syntactic position, resolved path); both themes expand at one position; locales count per token occurrence.',
        'scope': 'Code/** and root Lua/XML; Locales/*.lua scanned for [KEY:device:button].',
        'coverage': dict(Counter(r['kind'] for r in refs)),
        'limitations': ['Not a Lua interpreter; scope-insensitive finite constant propagation.',
                       'unresolved lists API expressions, including nested helpers already extracted separately; it is not a count of missing files.',
                       'broken_paths is complete for extracted finite paths, not a proof for arbitrary runtime input.',
                       'Inventory presence is not format compatibility or visual correctness.'],
    }
    report['manual_findings'] = [
        'API.lua concatenates TexturePrefix (Icons/NPCType-) with CustomTypeTexture.direction (AskDirection): Icons/NPCType-AskDirection, not Icons/AskDirection.',
        'The existing AskDirection asset cannot satisfy the concatenated NPCType-AskDirection filename; application code and assets were not modified.',
        'No bgName identifier exists in the scanned current code; direct helper variable alternatives and prefix..variable are covered by bounded literal propagation.',
        'After parallel source edits, lead must rerun this scan and perform in-game verification; this handoff is not project acceptance.',
    ]
    (OUT / 'texture_report.json').write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding='utf-8')
    lines = ['# Статический аудит текстур (не игровая проверка)', '',
             'Непроверенный в игре черновик для ведущего. Код приложения и ассеты не менялись.',
             'Сканируются Code/**, корневые .lua/.xml и токены клавиш Locales/*.lua; комментарии исключаются.',
             '## Программные результаты',
             'Единица счёта: файл, позиция и разрешённый путь; две темы дают два упоминания.',
             'Табличные декор, клавиши, NPC-типы и встроенные |T-строки раскрываются отдельно.',
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
    lines += ['', '## Покрытие извлечения (программные числа)']
    lines += [f'- {kind}: **{count}**' for kind, count in sorted(report['methodology']['coverage'].items())]
    lines += ['', '## Ручные выводы и ограничения (не дополнительные числа)',
              '- API.lua:547–567 собирает `Icons/NPCType-AskDirection`; `Icons/AskDirection` — другое имя. Это подтверждённая причина битого пути, а не рекомендация автоматически переименовать ассет.',
              '- В текущем коде идентификатор bgName отсутствует; варианты prefix..variable и прямые переменные helper извлекаются по конечным строковым присваиваниям без исполнения Lua.',
              '- unresolved — список выражений API, а не список отсутствующих файлов: в нём остаются и вложенные helper-вызовы, уже учтённые отдельно.',
              '- Полный список отсутствующих файлов относится только к извлечённым конечным путям. Произвольные данные игры и внешние строки статически не ограничены.',
              '- Ведущему: повторить скан после параллельных правок; проверить в Sirus декор, клавиши, две темы и сообщения DUI-TEX. Сборка и игра здесь не запускались.']
    (OUT / 'texture_report.md').write_text('\n'.join(lines) + '\n', encoding='utf-8')
    print(json.dumps(counts, indent=2))
    print('BROKEN PATHS:')
    for p in missing:
        print(p)
    print('Reports: research/qa/texture_report.md, research/qa/texture_report.json')


if __name__ == '__main__':
    main()
