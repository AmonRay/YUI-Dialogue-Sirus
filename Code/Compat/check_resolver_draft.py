"""Read-only isolated checks for this worker's draft, not game verification."""
from pathlib import Path
import re
from collections import Counter

ROOT = Path(__file__).resolve().parents[2]
source = (ROOT / 'Code/Compat/TextureSizes_335.lua').read_text(encoding='utf-8-sig')
sizes = {k: (int(w), int(h)) for k, w, h in re.findall(r'S\["([^"]+)"\] = \{(\d+), (\d+)\}', source)}
assets = {p.relative_to(ROOT / 'Art').with_suffix('').as_posix().lower() for p in (ROOT / 'Art').rglob('*') if p.suffix.lower() in {'.blp', '.tga', '.png', '.jpg', '.jpeg', '.dds'}}
missing, stale = sorted(assets - sizes.keys()), sorted(sizes.keys() - assets)
print('Manifest:', len(sizes), 'entries;', len(assets), 'asset names; missing:', len(missing), 'stale:', len(stale))
for key in missing:
    print('MISSING SIZE', key)
for key in stale:
    print('STALE SIZE', key)
assert not missing and not stale
assert all(w > 0 and h > 0 for w, h in sizes.values())
print('Categories:', dict(sorted(Counter(k.split('/')[0] for k in sizes).items())))
try:
    from lupa.lua51 import LuaRuntime
except ImportError:
    print('Lua 5.1 runtime unavailable; execution checks NOT RUN')
    raise SystemExit(0)
lua = LuaRuntime(unpack_returned_tuples=True)
compile_lua = lua.eval('function(s) local f,e=loadstring(s); assert(f,e) end')
compat = (ROOT / 'Code/Compat/Compat_335.lua').read_text(encoding='utf-8-sig')
theme = (ROOT / 'Code/Utility/ThemeUtil.lua').read_text(encoding='utf-8-sig')
for text in (source, compat, theme):
    compile_lua(text)
print('Lua 5.1 compile: 3 assigned files passed')
load = lua.eval('function(s) assert(loadstring(s))("DialogueUI", addon) end')
lua.execute('addon={API={},CallbackRegistry={Register=function() end,Trigger=function() end}}')
load(source)
load(theme)
check_asset = lua.eval('''function(key)
 local t=addon.ThemeUtil
 local file,w,h=t:FindTextureFile(key)
 assert(file and w and h,key)
 local fw,fh=t:GetTextureSize(file..'.blp')
 assert(fw==w and fh==h,key)
 assert(not string.find(file,'%.blp$'),key)
end''')
for key in sorted(sizes):
    check_asset(key)
lua.execute(r'''
local t=addon.ThemeUtil
local root='Interface\\AddOns\\DialogueUI\\Art\\'
for _,id in ipairs({1,2}) do
 t:SetThemeByID(id)
 local dir=id==1 and 'Theme_Brown' or 'Theme_Dark'
 assert(t:GetTextureFile('Parchment')==root..dir..'\\Parchment')
 for _,prefix in ipairs({'PS-', 'XBOX-', 'SWITCH-'}) do
  for _,name in ipairs({'PAD1','PAD2','PAD3','PAD4'}) do
   assert(t:GetTextureFile(prefix..name)==root..dir..'\\'..prefix..name)
   assert(t:GetTextureFile('Keys/'..prefix..name)==root..'Keys\\'..prefix..name)
  end
 end
 for _,name in ipairs({'Alliance','Horde','TWW-Candle'}) do
  assert(t:GetTextureFile('ParchmentDecor/'..name)==root..'ParchmentDecor\\'..name)
 end
end
assert(t:GetTextureFile('Shared/TTSButton.dds')==root..'Theme_Shared\\TTSButton')
assert(t:GetTextureFile('Interface/Icons/INV_Misc_Note_02.blp')=='Interface\\Icons\\INV_Misc_Note_02')
assert(t:FindTextureFile('not-a-real-asset')==nil)
addon.TextureFileSizes['theme_brown/only-brown']={17,19}
assert(t:GetTextureFile('only-brown')==root..'Theme_Brown\\only-brown')
assert(t:GetTextureSize('only-brown')==17)
assert(t:GetTextureFile('not-a-real-asset')==root..'Theme_Shared\\ClipboardBackground')
''')
print('Resolver: all manifest paths/size roundtrips, themes, dynamic keys/decor, alias, external, other-theme and missing fallback passed')
# Execute exact changed shim sections against minimal texture doubles.
gradient = compat[compat.index('    local textureIndex = Index(texture)'):compat.index('    Add(textureIndex, "SetMask", noop)')]
atlas = compat[compat.index('    if textureIndex and not textureIndex.SetAtlas then'):compat.index('    local fsIndex = Index(fontString)')]
lua.execute('''
function noop() end
Region={}
function Index(t) return t end
function Add(t,k,f) if t and not t[k] then t[k]=f end end
function makeTexture()
 return {SetTexture=function(s,f) s.file=f end,SetTexCoord=function(s,...) s.coords={...} end,
 SetSize=function(s,w,h) s.width=w s.height=h end,
 SetVertexColor=function(s,...) s.color={...} end}
end
texture=makeTexture()
''')
# ColorRGB is lexical in the actual file; include the same observed helper.
color_helper = compat[compat.index('    local function ColorRGB'):compat.index('    --Retail Model:SetLight')]
lua.execute(color_helper + gradient + atlas + '''
texture:SetGradientAlpha('VERTICAL',1,0,0,0,0,1,0,1)
assert(texture.color[4]==0.5)
local m={}
texture:AddMaskTexture(m) texture:AddMaskTexture(m)
assert(texture:GetNumMaskTextures()==1 and texture:GetMaskTexture(1)==m)
texture:RemoveMaskTexture(m)
assert(texture:GetNumMaskTextures()==0 and texture:GetMaskTexture(1)==nil)
texture:SetAtlas('Keys/PC-TAB',true)
assert(texture.width==64 and texture.height==32)
texture:SetAtlas(nil)
assert(texture.file==nil)
local saved=addon.ThemeUtil addon.ThemeUtil=nil
texture:SetAtlas('Book/TextureKit-Parchment',true)
assert(texture.width==1024 and texture.height==2048)
GetAtlasInfo=function() return {file='native-atlas',width=22,height=33} end
texture:SetAtlas('native-only',true)
assert(texture.file=='native-atlas' and texture.width==22)
addon.ThemeUtil=saved
texture:SetAtlas('native-only',true)
assert(texture.file=='native-atlas')
GetAtlasInfo=nil
texture:SetAtlas('unknown-atlas',true)
assert(texture.width==128 and texture.height==128)
''')
print('Compat isolated doubles: alpha reserve, mask references, atlas clear/size/early/native/missing passed')
