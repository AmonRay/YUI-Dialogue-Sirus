"""Read-only addon audit; isolated Lua 5.1 probes, not WoW verification."""
from pathlib import Path
import hashlib
import json
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
FILES = ['Code/Compat/Compat_335.lua', 'Code/Compat/TextureSizes_335.lua',
         'Code/Utility/ThemeUtil.lua', 'Code/Utility/TextureSlice.lua', 'API.lua', 'Initialization.lua']
result = {'scope': 'isolated draft only', 'sha256': {}, 'compile': {}, 'probes': {}}
texts = {}
for name in FILES:
    raw = (ROOT / name).read_bytes()
    result['sha256'][name] = hashlib.sha256(raw).hexdigest()
    texts[name] = raw.decode('utf-8-sig')
manifest = dict(re.findall(r'S\["([^"]+)"\] = \{(\d+, \d+)\}', texts[FILES[1]]))
assets = {p.relative_to(ROOT / 'Art').with_suffix('').as_posix().lower() for p in (ROOT / 'Art').rglob('*.blp')}
result['manifest'] = {'entries': len(manifest), 'assets': len(assets),
                      'missing': sorted(set(manifest) - assets), 'unlisted': sorted(assets - set(manifest))}
try:
    from lupa.lua51 import LuaRuntime
except ImportError as exc:
    result['runtime_error'] = str(exc)
    print('Lua 5.1 unavailable:', exc)
else:
    lua = LuaRuntime(unpack_returned_tuples=True)
    print('Runtime:', lua.eval('_VERSION'))
    compile_lua = lua.eval('function(s,n) local f,e=loadstring(s,n); return f ~= nil,e end')
    for name, text in texts.items():
        ok, err = compile_lua(text, '@' + name)
        result['compile'][name] = {'ok': ok, 'error': err}
        print('COMPILE', name, 'PASS' if ok else err)
    # No magical __index/no-op for arbitrary methods: explicit native surface only.
    lua.execute(r'''
addon = {API={}, CallbackRegistry={Register=function() end, Trigger=function() end}}
local function noop() end
native = {}
for _,name in ipairs({'Hide','Show','SetPoint','ClearAllPoints','SetWidth','SetHeight','SetDrawLayer',
'SetVertexColor','SetAlpha','SetDesaturated','SetBlendMode','RegisterEvent','UnregisterEvent','SetScript',
'SetAllPoints','SetChange','SetScale'}) do native[name]=noop end
function native:SetTexture(file) self.file=file end
function native:GetTexture() return self.file end
function native:SetTexCoord(...) self.coords={...} end
function native:GetTexCoord() return 0,0,0,1,1,0,1,1 end
function native:GetVertexColor() return 1,1,1,1 end
function native:GetAlpha() return 1 end
function native:GetDrawLayer() return 'ARTWORK',0 end
function native:IsShown() return true end
function native:GetEffectiveScale() return 1 end
function native:GetParent() return self.parent end
function native:CreateTexture() return setmetatable({parent=self},{__index=native}) end
native.CreateFontString=native.CreateTexture
native.CreateAnimationGroup=native.CreateTexture
native.CreateAnimation=native.CreateTexture
function CreateFrame() return setmetatable({},{__index=native}) end
function GetTime() return 0 end
function GetCVar() return '1920x1080' end
function GetPhysicalScreenSize() return 1920,1080 end
function GetAddOnMetadata() return 'Wrath' end
function GetBuildInfo() return '3.3.5','12340','',30300 end
function UnitExists() return true end
function GetLocale() return 'enUS' end
UIParent=CreateFrame()
WorldFrame=CreateFrame()
function WorldFrame:GetSize() return 1920,1080 end
''')
    load = lua.eval('function(s,n) return assert(loadstring(s,n))("DialogueUI",addon) end')
    def probe(name, action):
        try:
            action()
            result['probes'][name] = 'PASS'
            print('PROBE', name, 'PASS')
        except Exception as exc:
            result['probes'][name] = str(exc)
            print('PROBE', name, 'FAIL:', exc)
    probe('compat load on explicit native surface', lambda: load(texts[FILES[0]], '@'+FILES[0]))
    probe('manifest load', lambda: load(texts[FILES[1]], '@'+FILES[1]))
    probe('early atlas before ThemeUtil', lambda: lua.execute(r'''
local t=CreateFrame():CreateTexture()
t:SetAtlas('Parchment',true)
assert(t:GetTexture():lower():find('theme_brown',1,true))
t:SetAtlas('Shared/TTSButton.blp')
assert(t:GetTexture():lower():find('theme_shared',1,true))
t:SetAtlas('missing')
assert(t:GetTexture():find('ClipboardBackground',1,true))
'''))
    probe('ThemeUtil load without XML fonts', lambda: load(texts[FILES[2]], '@'+FILES[2]))
    probe('all manifest keys both themes and Shared alias', lambda: lua.execute(r'''
debug.sethook(function() error('instruction budget exceeded') end,'',2000000)
local t=addon.ThemeUtil
for theme=1,2 do
 t:SetThemeByID(theme)
 for key in pairs(addon.TextureFileSizes) do
  local file,w,h=t:FindTextureFile(key..'.blp')
  assert(file and w and h,key)
  if key:find('theme_shared/',1,true)==1 then
   assert(t:FindTextureFile('Shared/'..key:sub(14)),key)
  end
 end
end
assert(t:GetTextureFile(nil)==nil)
assert(t:GetTextureFile('')==nil)
assert(t:GetTextureFile(123)==nil)
assert(t:GetTextureFile('not-an-asset'):find('ClipboardBackground',1,true))
assert(t:GetTextureFile('Interface/Icons/Test')=='Interface\\Icons\\Test')
addon.TextureFileSizes=nil
assert(t:GetTextureFile('Parchment'))
assert(t:GetTextureFile('Theme_Shared/TTSButton'))
assert(t:GetTextureFile('Shared/TTSButton'):find('ClipboardBackground',1,true))
debug.sethook()
'''))
    load(texts[FILES[1]], '@'+FILES[1])
    probe('pseudo slice first texture and unknown fallback', lambda: (
        lua.execute('addon.API.GetPixelForScale=function() return 1 end; addon.API.Mixin=Mixin'),
        load(texts[FILES[3]], '@'+FILES[3]),
        lua.execute("local f=addon.CreateSliceTexture(UIParent); f:SetTexture('HotkeyBackground'); f:SetTexture('Shared/TTSButton'); f:SetTexture(nil)")))
    probe('Initialization load', lambda: load(texts['Initialization.lua'], '@Initialization.lua'))
    # Execute actual API file with the explicit native surface; retain the first missing API.
    probe('API load minimal 3.3.5 surface', lambda: load(texts['API.lua'], '@API.lua'))
    # Isolate the color block to demonstrate the exact legacy ITEM_QUALITY_COLORS contract.
    color_block = texts['API.lua'].split('do  -- Color',1)[1].split('do  -- Currency',1)[0]
    probe('legacy quality color nil reproduction', lambda: lua.execute('''
function CreateColor(r,g,b,a) return {GetRGB=function() return r,g,b end} end
ITEM_QUALITY_COLORS={[2]={r=0.12,g=1,b=0,hex='ff1eff00'}}
''') or load('local _,addon=...; local API=addon.API; do '+color_block, '@API-color-block'))
    probe('quality 2 returned color', lambda: lua.execute('assert(addon.API.GetItemQualityColor(2),"legacy quality 2 returns nil")'))
    focus_block = texts['API.lua'].split('    local GetCurrentKeyBoardFocus = GetCurrentKeyBoardFocus;', 1)[1].split('    if StaticPopup_FindVisible then', 1)[0]
    probe('show callback without modern focus API', lambda: (
        load('local _,addon=...; local API=addon.API; local CallbackRegistry=addon.CallbackRegistry; local GetCurrentKeyBoardFocus=GetCurrentKeyBoardFocus; '+focus_block, '@API-focus-block'),
        lua.execute('addon.API.ClearEditBoxFocus()')))
    # A compile success here is deliberate: this typo is valid Lua (two statements).
    probe('waypoint typo is syntactically valid Lua 5.1', lambda: lua.execute('local C_Map={GetUserWaypoint=function() return {} end}; local oldWaypoint C_Map.GetUserWaypoint(); assert(oldWaypoint==nil)'))
print('MANIFEST', json.dumps(result['manifest'], ensure_ascii=True))
(OUT / 'results.json').write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf-8')
print('Saved research/back-regression/results.json')
