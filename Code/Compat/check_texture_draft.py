"""Isolated draft checks only; not a client or project verification."""
from pathlib import Path
from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parents[2]
lua = LuaRuntime(unpack_returned_tuples=True)
paths = ['Code/Compat/Compat_335.lua', 'Code/Compat/TextureSizes_335.lua', 'Code/Utility/ThemeUtil.lua', 'Code/Utility/TextureSlice.lua', 'Code/Utility/FontUtil.lua']
compile_lua = lua.eval('function(s) local f,e=loadstring(s); assert(f,e); return true end')
for name in paths:
    compile_lua((root / name).read_text(encoding='utf-8-sig'))
print('Lua 5.1 compile: 5 files passed')
lua.execute('''
addon = {API={}, CallbackRegistry={Register=function() end, Trigger=function() end}}
setmetatable(_G, {__index=function(t,k)
 if string.find(k, '^DUIFont_') then return {SetTextColor=function() end} end
end})
''')
load = lua.eval('function(s) local f=assert(loadstring(s)); f("DialogueUI", addon) end')
load((root / paths[1]).read_text())
load((root / paths[2]).read_text())
lua.execute('''
local t=addon.ThemeUtil
assert(t:GetTextureFile('Parchment') == 'Interface\\\\AddOns\\\\DialogueUI\\\\Art\\\\Theme_Brown\\\\Parchment')
assert(t:GetTextureFile('TTSButton.tga') == 'Interface\\\\AddOns\\\\DialogueUI\\\\Art\\\\Theme_Shared\\\\TTSButton')
t:SetThemeByID(2)
assert(t:GetTextureFile('Parchment') == 'Interface\\\\AddOns\\\\DialogueUI\\\\Art\\\\Theme_Dark\\\\Parchment')
assert(t:GetTextureFile('Theme_Shared/TTSButton.blp') == 'Interface\\\\AddOns\\\\DialogueUI\\\\Art\\\\Theme_Shared\\\\TTSButton')
''')
print('Theme path draft checks: Brown, Dark, Shared fallback, explicit Shared passed')
try:
    from PIL import Image
except ImportError:
    print('Pillow unavailable; alpha pixel inspection skipped')
else:
    for name in ['Theme_Brown/Parchment', 'Theme_Dark/Parchment', 'Theme_Shared/TTSButton']:
        path = root / '_Build/DialogueUI/Art' / (name + '.tga')
        img = Image.open(path).convert('RGBA')
        print('Alpha', name, img.getchannel('A').getextrema())
