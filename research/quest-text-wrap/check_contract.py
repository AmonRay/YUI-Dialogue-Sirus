"""Independent observation oracle, not a WoW renderer or addon execution.
python research/quest-text-wrap/check_contract.py
python research/quest-text-wrap/check_contract.py observations.json
All outputs are confined to this directory. No dependencies beyond stdlib.
"""
from pathlib import Path
import copy
import hashlib
import json
import re
import sys
import xml.etree.ElementTree as ET

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[1]
LONG = ('Благодарю тебя за проделанную работу, герой! Твоя награда ждёт тебя. '
        'Но прежде выслушай рассказ о дороге через заснеженные перевалы, '
        'о вернувшихся разведчиках и о жителях, которым ещё нужна наша защита. ') * 8 + 'КОНЕЦ_ЗАДАНИЯ_Я'
TEXTS = {
    'long_ru': LONG,
    'explicit_lf': 'Первая строка.\nВторая строка.\n\nПоследний абзац. КОНЕЦ_АБЗАЦА_Я',
    'short_after_long': 'Спасибо, герой! КОНЕЦ_Я',
    'literal_ellipsis': 'Он задумался... а затем продолжил рассказ. КОНЕЦ_Я',
    'long_token': 'Сверхдлинноесловодляпроверкипереносабезпробелов' * 8 + ' КОНЕЦ_СЛОВА_Я',
}
# UI units; effective_scale converts all geometry to physical pixels.
# Matrix is a QA dataset only, not an existing acceptance fixture.
CASES = [dict(id=f'{name}-w{width}-s{scale}-f{font}', text=text,
              width=width, effective_scale=scale, font_size=font,
              sequence='long_ru -> short_after_long -> long_ru' if name == 'short_after_long' else None)
         for name, text in TEXTS.items() for width in (220, 358, 520)
         for scale in (0.75, 1.0, 1.5) for font in (12, 18)]
BY_ID = {c['id']: c for c in CASES}


def validate(row, case):
    """Validate measured observations. Coordinates are downward-positive content UI units.
    rendered_lines must be visually verified in the client, not derived by this oracle.
    raw_text is the concatenated body source before presentation-only paragraph splitting.
    """
    errors = []
    def require(ok, name):
        if not ok:
            errors.append(name)
    require(row['raw_text'] == case['text'], 'source changed/truncated')
    require(row['last_marker_visible'] is True, 'final marker not visible')
    require(row['explicit_breaks_preserved'] is True, 'explicit line breaks lost')
    require(row['added_ellipsis'] is False, 'presentation added ellipsis')
    require(row['measured_after_layout'] is True, 'stale layout observation')
    require(abs(row['available_width'] - case['width']) < 0.01, 'wrong available width')
    require(abs(row['effective_scale'] - case['effective_scale']) < 0.001, 'wrong scale')
    require(row['font_size'] == case['font_size'], 'wrong font size')
    lines = row['rendered_lines']
    require(bool(lines), 'no rendered lines')
    require(all(0 <= line['width'] <= case['width'] + 0.5 for line in lines), 'line exceeds width')
    if case['id'].startswith(('long_ru', 'explicit_lf', 'long_token')):
        require(len(lines) > 1, 'body did not wrap')
    require(row['measured_height'] > 0, 'invalid measured height')
    require(row['allocated_height'] + 0.5 >= row['measured_height'], 'height clips text')
    require(abs(row['text_bottom'] - row['text_top'] - row['allocated_height']) <= 0.5,
            'inconsistent text rectangle')
    require(row['reward_top'] >= row['text_bottom'], 'rewards overlap body')
    require(row['reward_top'] >= row['text_top'] + row['measured_height'] - 0.5,
            'rewards overlap measured glyphs')
    require(row['content_height'] + 0.5 >= row['reward_bottom'], 'scroll content misses rewards')
    require(row['text_bottom'] * case['effective_scale'] <= row['reward_top'] * case['effective_scale'],
            'physical pixel overlap')
    require(row['reward_bottom'] >= row['reward_top'], 'invalid reward rectangle')
    if case['id'].startswith('short_after_long'):
        require(row['same_object_reused'] is True, 'pool reuse not exercised')
        require(row['prior_text'] == LONG, 'long-to-short transition not exercised')
        require(row['allocated_height'] < row['prior_allocated_height'], 'height did not shrink')
        require(row['reward_top'] < row['prior_reward_top'], 'rewards did not move upward')
    return errors


def validate_safe(row, case):
    try:
        return validate(row, case)
    except (KeyError, TypeError, ValueError) as exc:
        return ['invalid observation schema: ' + str(exc)]


def selftest():
    """Synthetic observations test the validator only, never the addon."""
    case = next(c for c in CASES if c['id'].startswith('short_after_long'))
    row = dict(raw_text=case['text'], last_marker_visible=True, explicit_breaks_preserved=True,
               added_ellipsis=False, measured_after_layout=True, available_width=case['width'],
               effective_scale=case['effective_scale'], font_size=case['font_size'],
               rendered_lines=[dict(width=150)], measured_height=15, allocated_height=15,
               text_top=10, text_bottom=25, reward_top=40, reward_bottom=100, content_height=120,
               same_object_reused=True, prior_text=LONG, prior_allocated_height=200, prior_reward_top=225)
    assert validate(row, case) == []
    mutants = [('raw_text', 'cut...'), ('last_marker_visible', False),
               ('explicit_breaks_preserved', False), ('added_ellipsis', True),
               ('measured_after_layout', False), ('available_width', 1),
               ('effective_scale', 9), ('font_size', 99),
               ('rendered_lines', [dict(width=999)]), ('allocated_height', 1),
               ('text_bottom', 999), ('reward_top', 0), ('content_height', 10),
               ('same_object_reused', False), ('prior_text', 'short'),
               ('prior_allocated_height', 1), ('prior_reward_top', 1)]
    for key, value in mutants:
        bad = copy.deepcopy(row)
        bad[key] = value
        assert validate(bad, case), key
    return f'ORACLE SELFTEST ONLY: valid synthetic row accepted; {len(mutants)} mutations rejected'


def inventory():
    paths = ['Code/Dialogue/DialogueUI.lua', 'Code/Dialogue/DialogueUI.xml', 'Code/Dialogue/UITemplates.lua']
    result = {}
    for path in paths:
        data = (ROOT / path).read_bytes()
        result[path] = dict(sha256=hashlib.sha256(data).hexdigest())
    xml = ET.parse(ROOT / paths[1])
    result['xml_names'] = sorted(e.attrib['name'] for e in xml.iter() if 'name' in e.attrib)
    lua = (ROOT / paths[0]).read_text(encoding='utf-8-sig')
    expected_api = ('AcquireLeftFontString', 'InsertText', 'InsertParagraph', 'FormatParagraph',
                    'FormatDualParagraph', 'FormatRewards', 'HandleQuestComplete')
    expected_xml = ('DUIQuestFrame', 'DUIDialogItemButtonTemplate', 'DUIDialogOptionButtonTemplate')
    result['required_api_present'] = {name: bool(re.search(
        r'function DUIDialogBaseMixin:' + name + r'\s*\(', lua)) for name in expected_api}
    result['required_xml_names_present'] = {name: name in result['xml_names'] for name in expected_xml}
    # Partial inventory only: there is no frozen full baseline for compatibility.
    return result


def main():
    result = dict(status='NOT VERIFIED IN SIRUS', selftest=selftest(), case_count=len(CASES),
                  sources=inventory(), observations_checked=0, failures=[], missing_cases=[])
    (OUT / 'cases.json').write_text(json.dumps(CASES, ensure_ascii=False, indent=2), encoding='utf-8')
    if len(sys.argv) > 1:
        # Only accept observations from this research folder.
        input_path = Path(sys.argv[1]).resolve()
        if input_path.parent != OUT:
            raise ValueError('observations must live in research/quest-text-wrap/')
        rows = json.loads(input_path.read_text(encoding='utf-8-sig'))
        seen = set()
        for row in rows:
            cid = row.get('id')
            if cid not in BY_ID or cid in seen:
                result['failures'].append(dict(id=cid, errors=['unknown or duplicate case']))
                continue
            seen.add(cid)
            errors = validate_safe(row, BY_ID[cid])
            result['observations_checked'] += 1
            if errors:
                result['failures'].append(dict(id=cid, errors=errors))
        result['missing_cases'] = sorted(set(BY_ID) - seen)
        by_id = {row['id']: row for row in rows if row.get('id') in seen
                 and not validate_safe(row, BY_ID[row['id']])}
        for case in CASES:
            row = by_id.get(case['id'])
            if row is None:
                continue
            comparable = [other for other in CASES if other['id'] in by_id
                          and other['text'] == case['text'] and other['font_size'] == case['font_size']
                          and other['effective_scale'] == case['effective_scale'] and other['width'] < case['width']]
            for other in comparable:
                smaller = by_id[other['id']]
                if row['measured_height'] > smaller['measured_height'] + 0.5:
                    result['failures'].append(dict(id=case['id'], errors=['wider body grew taller than narrower body']))
                if row['reward_top'] > smaller['reward_top'] + 0.5:
                    result['failures'].append(dict(id=case['id'], errors=['wider body moved rewards downward']))
            smaller_font_id = case['id'].rsplit('-f', 1)[0] + '-f12'
            smaller_font = by_id.get(smaller_font_id)
            if case['font_size'] == 18 and smaller_font:
                if row['measured_height'] + 0.5 < smaller_font['measured_height']:
                    result['failures'].append(dict(id=case['id'], errors=['larger font measured shorter']))
    else:
        result['missing_cases'] = sorted(BY_ID)
    (OUT / 'results.json').write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf-8')
    print(result['selftest'])
    print('API/XML PRESENCE INVENTORY:', result['sources']['required_api_present'], result['sources']['required_xml_names_present'])
    print(f"CASES: {len(CASES)}; observations checked: {result['observations_checked']}; failures: {len(result['failures'])}; missing: {len(result['missing_cases'])}")
    print('NOT VERIFIED: actual FontString wrapping, dynamic relayout, compatibility, Sirus visuals')
    return 1 if result['failures'] else (2 if result['missing_cases'] else 0)


if __name__ == '__main__':
    raise SystemExit(main())
