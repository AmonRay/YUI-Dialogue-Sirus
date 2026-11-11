"""Read-only Lua call/XML layout inventory. No addon execution or edits.
Run: python research/front-reward/analyze.py [--brief]
Writes calls.md alongside this script; dimensions are symbolic, not runtime proof.
"""
from pathlib import Path
import re
import sys
import xml.parsers.expat

ROOT = Path(__file__).resolve().parents[2]
BASE = [
    'Code/Widget/Widget_QuestItemDisplay.lua',
    'Code/Dialogue/QuestRewards.lua',
    'Code/Dialogue/QuestHeaderWidget.lua',
    'Code/SharedUITemplates/SharedUITemplates.lua',
    'Code/SharedUITemplates/SharedUITemplates.xml',
]
# Extra sources are necessary: the requested files do not implement requirements.
EXTRA = ['Code/Dialogue/UITemplates.lua', 'Code/Dialogue/DialogueUI.xml',
         'Code/Dialogue/LegacyPanel.lua']
METHODS = {'SetTexture', 'SetAtlas', 'SetTexCoord', 'SetMaskTexture',
           'AddMaskTexture', 'SetPoint', 'SetAllPoints', 'ClearAllPoints',
           'SetSize', 'SetWidth', 'SetHeight', 'SetTextureSliceMargins',
           'SetTextureSliceMode', 'CreateLegacyPanel', 'UpdateTextureSliceScale',
           'SetJustifyH', 'SetJustifyV'}


def lexical_mask(text):
    """Blank Lua comments and strings, preserving offsets/newlines.

    Handles escaped quoted strings and [=*[ long strings/comments. This is a
    lexical call parser, not a Lua AST or control-flow/dimension evaluator.
    """
    chars = list(text)
    i = 0
    while i < len(text):
        start = i
        comment = text.startswith('--', i)
        pos = i + 2 if comment else i
        long = re.match(r'\[(=*)\[', text[pos:])
        if long:
            close = ']' + long[1] + ']'
            end = text.find(close, pos + len(long[0]))
            i = len(text) if end < 0 else end + len(close)
        elif comment:
            end = text.find('\n', pos)
            i = len(text) if end < 0 else end
        elif text[i] in '\"\'':
            quote = text[i]
            i += 1
            while i < len(text):
                if text[i] == '\\':
                    i += 2
                elif text[i] == quote:
                    i += 1
                    break
                else:
                    i += 1
        else:
            i += 1
            continue
        for k in range(start, min(i, len(text))):
            if chars[k] != '\n':
                chars[k] = ' '
    return ''.join(chars)


def expected(call, method, path, line):
    if method == 'SetSize':
        return 'W,H явно: ' + call[call.find('(') + 1:-1]
    if method in {'SetWidth', 'SetHeight'}:
        return 'Одна ось явно; другая из размера/якорей'
    if 'self.Count' in call:
        return 'Ширина текста без лимита; якорь из вызова (обычно BOTTOMRIGHT Icon -1,+1)'
    if path.endswith('UITemplates.lua') and 'self.Icon' in call:
        return 'Квадрат: AreaDefinitionItemBorder (36x36) минус 2*offset'
    if 'Background' in call and path.endswith('UITemplates.lua'):
        return 'Размер кнопки; XML setAllPoints; здесь нет 9-slice'
    if method == 'SetTexCoord':
        return 'UV меняет выборку, не геометрию'
    if method in {'SetTexture', 'SetAtlas'}:
        return 'Размер не доказан этим вызовом; см. SetSize/якоря'
    if method == 'SetAllPoints':
        return 'Размер объекта-якоря'
    if method == 'ClearAllPoints':
        return 'Якоря сброшены, следующий SetPoint определит привязку'
    if method == 'CreateLegacyPanel':
        return '9 сегментов; width,height — размер исходника, не контейнера'
    return 'Символьный размер: зависит от остальных якорей/шрифта'


def lua_rows(path):
    text = (ROOT / path).read_text(encoding='utf-8-sig')
    mask = lexical_mask(text)
    pattern = r'([A-Za-z_][\w.]*)\s*[:.]\s*([A-Za-z_]\w*)\s*\('
    for match in re.finditer(pattern, mask):
        method = match[2]
        if method not in METHODS:
            continue
        # Function declarations are not calls.
        if re.search(r'\bfunction\s*$', mask[max(0, match.start()-20):match.start()]):
            continue
        start = match.end() - 1
        depth = 1
        end = start + 1
        while end < len(mask) and depth:
            depth += (mask[end] == '(') - (mask[end] == ')')
            end += 1
        if depth:
            raise ValueError(f'Unbalanced call: {path}:{text.count(chr(10), 0, start)+1}')
        line = text.count('\n', 0, match.start()) + 1
        if path.endswith('UITemplates.lua') and not 1175 <= line <= 1760:
            continue
        call = re.sub(r'\s+', ' ', text[match.start():end])
        yield line, call, expected(call, method, path, line)


def xml_rows(path):
    parser = xml.parsers.expat.ParserCreate()
    stack = []
    def start(name, attrs):
        parent = '/'.join(stack)
        label = attrs.get('parentKey', attrs.get('name', name))
        if name in {'Size', 'Anchor', 'TexCoords'} or 'setAllPoints' in attrs or 'file' in attrs:
            call = parent + '/' + name + ' ' + ' '.join(f'{k}={v}' for k, v in attrs.items())
            if name == 'Size':
                size = f"XML W={attrs.get('x', 'не задано')}, H={attrs.get('y', 'не задано')}"
            elif name == 'Anchor':
                size = 'Якорь; размер из пары якорей или Size'
            elif attrs.get('setAllPoints') == 'true':
                size = 'Размер родителя'
            else:
                size = 'Размер не задаётся'
            rows.append((parser.CurrentLineNumber, call, size))
        stack.append(label)
    def end(name):
        stack.pop()
    rows = []
    parser.StartElementHandler, parser.EndElementHandler = start, end
    parser.Parse((ROOT / path).read_bytes(), True)
    return rows


def main():
    output = ['# Статическая таблица вызовов и якорей', '',
              'Размеры символьные; Lua не исполняется. Дополнительный UITemplates.lua: только строки 1175–1760.', '',
              '| Файл:строка | Вызов / XML | Ожидаемый размер |', '|---|---|---|']
    counts = {}
    for path in BASE + EXTRA:
        rows = list(xml_rows(path) if path.endswith('.xml') else lua_rows(path))
        counts[path] = len(rows)
        for line, call, size in rows:
            cells = [f'{path}:{line}', call, size]
            output.append('| ' + ' | '.join(x.replace('|', '&#124;') for x in cells) + ' |')
    report = Path(__file__).with_name('calls.md')
    report.write_text('\n'.join(output) + '\n', encoding='utf-8')
    if '--brief' not in sys.argv:
        print('\n'.join(output))
    for path, count in counts.items():
        print(f'{path}: {count} rows')
    print(f'TOTAL: {sum(counts.values())} rows; table: research/front-reward/calls.md')
    print('Scope: static lexical inventory only; no runtime or visual verification.')


if __name__ == '__main__':
    main()
