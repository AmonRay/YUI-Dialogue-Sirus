"""Read-only static triage; writes reports only beside this script. No game execution."""
from pathlib import Path
import re, json, hashlib, zlib, struct, difflib, xml.etree.ElementTree as ET
ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
FILES = ['Code/Dialogue/DialogueUI.lua', 'Code/Dialogue/DialogueUI.xml',
         'Code/Dialogue/UITemplates.lua', 'Code/Dialogue/QuestHeaderWidget.lua',
         'Code/SharedUITemplates/SharedUITemplates.lua',
         'Code/SharedUITemplates/SharedUITemplates.xml', 'Code/Widget/WidgetManager.lua']

# Minimal, read-only Git object reader, including packed deltas. No git subprocess.
class Objects:
    def __init__(self):
        self.cache, self.offsets, self.packs = {}, {}, {}
        for idx in (ROOT / '.git/objects/pack').glob('*.idx'):
            b = idx.read_bytes()
            if b[:8] != b'\xfftOc\x00\x00\x00\x02':
                continue
            n = struct.unpack_from('>I', b, 8 + 255*4)[0]
            names, offsets = 1032, 1032 + n*24
            for i in range(n):
                oid = b[names+i*20:names+(i+1)*20].hex()
                off = struct.unpack_from('>I', b, offsets+i*4)[0]
                if off & 0x80000000:
                    off = struct.unpack_from('>Q', b, offsets+n*4+(off & 0x7fffffff)*8)[0]
                self.offsets[oid] = (idx.with_suffix('.pack'), off)
    def get(self, oid):
        if oid in self.cache:
            return self.cache[oid]
        p = ROOT / '.git/objects' / oid[:2] / oid[2:]
        if p.exists():
            raw = zlib.decompress(p.read_bytes())
            header, data = raw.split(b'\0', 1)
            result = (header.split()[0].decode(), data)
        else:
            result = self.packed(*self.offsets[oid])
        self.cache[oid] = result
        return result
    def packed(self, path, start):
        if path not in self.packs:
            self.packs[path] = path.read_bytes()
        b = self.packs[path]
        pos = start
        c = b[pos]; pos += 1
        typ = (c >> 4) & 7
        while c & 128:
            c = b[pos]; pos += 1
        base = None
        if typ == 6:
            c = b[pos]; pos += 1; distance = c & 127
            while c & 128:
                c = b[pos]; pos += 1
                distance = ((distance+1) << 7) | (c & 127)
            base = self.packed(path, start-distance)
        elif typ == 7:
            base = self.get(b[pos:pos+20].hex()); pos += 20
        data = zlib.decompress(b[pos:])
        if base:
            data = self.delta(base[1], data)
            return base[0], data
        return {1:'commit', 2:'tree', 3:'blob', 4:'tag'}[typ], data
    @staticmethod
    def delta(base, delta):
        pos = 0
        def varint():
            nonlocal pos
            value = shift = 0
            while True:
                c = delta[pos]; pos += 1
                value |= (c & 127) << shift
                if not c & 128: return value
                shift += 7
        assert varint() == len(base)
        size = varint(); out = bytearray()
        while pos < len(delta):
            c = delta[pos]; pos += 1
            if c & 128:
                offset = count = 0
                for i in range(4):
                    if c & (1 << i):
                        offset |= delta[pos] << (i*8); pos += 1
                for i in range(3):
                    if c & (1 << (i+4)):
                        count |= delta[pos] << (i*8); pos += 1
                count = count or 65536
                out.extend(base[offset:offset+count])
            elif c:
                out.extend(delta[pos:pos+c]); pos += c
            else:
                raise ValueError('invalid delta')
        assert len(out) == size
        return bytes(out)
    def file(self, commit, path):
        tree = self.get(commit)[1].splitlines()[0].split()[1].decode()
        for part in path.split('/'):
            b = self.get(tree)[1]; pos = 0; found = None
            while pos < len(b):
                end = b.index(b'\0', pos)
                name = b[pos:end].split(b' ', 1)[1].decode()
                oid = b[end+1:end+21].hex(); pos = end+21
                if name == part: found = oid; break
            if found is None: return ''
            tree = found
        return self.get(tree)[1].decode('utf-8-sig')

def main():
    sources = {p:(ROOT/p).read_text(encoding='utf-8-sig') for p in FILES}
    result = {'scope': FILES, 'hashes': {p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in FILES}}
    # Definition inventory throughout the source, not generated/build folders.
    xmls = [ROOT/'Fonts.xml', ROOT/'API.xml'] + list((ROOT/'Code').rglob('*.xml'))
    definitions = set(); errors = []
    for p in xmls:
        try:
            tree = ET.fromstring(p.read_text(encoding='utf-8-sig'))
            definitions.update(e.attrib['name'] for e in tree.iter() if 'name' in e.attrib)
        except ET.ParseError as exc:
            errors.append({'file':p.relative_to(ROOT).as_posix(), 'error':str(exc)})
    missing = []; literal = 0; inventory = []
    patterns = {'pcall':r'\b(?:p|xp)call\s*\(', 'modern_texture_api':r':(?:SetAtlas|SetTextureKit|SetTexelSnappingBias|SetSnapToPixelGrid)\s*\(',
                'texcoord':r':SetTexCoord\s*\(', 'return':r'\breturn\b'}
    for path, text in sources.items():
        for no, line in enumerate(text.splitlines(), 1):
            code = line.split('--', 1)[0]
            for kind, pattern in patterns.items():
                if re.search(pattern, code): inventory.append({'kind':kind, 'file':path, 'line':no, 'code':code.strip()})
            m = re.search(r'CreateFrame\("[^"]+",\s*[^,]+,\s*[^,]+,\s*"([^"]+)"', code)
            if m:
                literal += 1
                for template in m[1].split(','):
                    if template.strip().startswith('DUI') and template.strip() not in definitions:
                        missing.append({'file':path, 'line':no, 'template':template})
    # Check actual XML parentKey chains for every schematic entry.
    dialogue = ET.fromstring(sources['Code/Dialogue/DialogueUI.xml'])
    quest = next(e for e in dialogue if e.attrib.get('name') == 'DUIQuestFrame')
    def children_by_key(node):
        found = {}
        def visit(item):
            for child in item:
                key = child.attrib.get('parentKey')
                if key:
                    found[key] = child
                elif child.tag.rsplit('}', 1)[-1] in ('Frames', 'Layers', 'Layer', 'ScrollChild'):
                    visit(child)
        visit(node)
        return found
    schematic = sources['Code/Dialogue/DialogueUI.lua'].split('local Schematic = {', 1)[1].split('\n};', 1)[0]
    missing_chains = []
    chains = re.findall(r'\["([\w.]+)"\]', schematic)
    for chain in chains:
        node = quest
        for key in chain.split('.'):
            node = children_by_key(node).get(key)
            if node is None:
                missing_chains.append(chain)
                break
    mixins = []
    all_lua = '\n'.join(p.read_text(encoding='utf-8-sig') for p in (ROOT/'Code').rglob('*.lua'))
    for path in FILES:
        if path.endswith('.xml'):
            for match in re.finditer(r'DUI_ApplyMixin\(self, "([\w]+)"\)', sources[path]):
                name = match[1]
                mixins.append({'file':path, 'line':sources[path].count('\n', 0, match.start())+1,
                               'mixin':name, 'definition_found': bool(re.search(r'\b'+name+r'\s*=\s*\{', all_lua))})
    result.update(xml_files=len(xmls), xml_parse_errors=errors, literal_template_calls=literal,
                  missing_addon_templates=missing, inventory=inventory,
                  schematic_chains=len(chains), missing_schematic_chains=missing_chains, mixins=mixins)
    objects = Objects(); history = []; diffs = []
    commits = ['039bb746252190f3ee06f9a25255b9577bc424b9', '15e8f6c42639a77839b2f55c459d1073f22003cd']
    for commit in commits:
        raw = objects.get(commit)[1].decode()
        parent = re.search(r'^parent ([0-9a-f]+)$', raw, re.M)[1]
        changed = []
        for path in FILES:
            old, new = objects.file(parent, path), objects.file(commit, path)
            if old != new:
                changed.append(path)
                diffs.extend(difflib.unified_diff(old.splitlines(), new.splitlines(),
                             fromfile=parent[:7]+':'+path, tofile=commit[:7]+':'+path, lineterm=''))
        history.append({'commit':commit, 'parent':parent, 'changed_scope_files':changed})
    result['history'] = history
    (OUT/'recent.diff').write_text('\n'.join(diffs)+'\n', encoding='utf-8')
    (OUT/'analysis.json').write_text(json.dumps(result, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    counts = {k:sum(e['kind']==k for e in inventory) for k in patterns}
    print('Scope files:', len(FILES))
    print('XML parsed:', len(xmls), 'errors:', len(errors))
    print('Literal CreateFrame template calls:', literal, 'missing addon templates:', len(missing))
    print('Inventory:', json.dumps(counts))
    for item in history: print(item['commit'][:7], 'changed scope files:',len(item['changed_scope_files']))
    print('Reports: analysis.json, recent.diff')
    # Targeted excerpts for manual review, including portions not shown by IDE file reads.
    for path in ['Code/Dialogue/UITemplates.lua', 'Code/Dialogue/DialogueUI.lua']:
        lines = sources[path].splitlines()
        needles = ['function DUIDialogQuestPortraitMixin:OnLoad', 'function DUIDialogBaseMixin:HandleGossip(',
                   'function DUIDialogItemButtonMixin:OnLoad', 'function DUIDialogSmallItemButtonMixin:OnLoad']
        for i, line in enumerate(lines):
            if any(n in line for n in needles):
                print('\n'+path)
                for j in range(max(0,i-2), min(len(lines),i+100)):
                    print(str(j+1)+': '+lines[j])
if __name__ == '__main__':
    main()
