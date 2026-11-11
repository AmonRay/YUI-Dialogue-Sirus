"""Isolated Lua 5.1 regressions; not a Sirus visual/taint acceptance test."""
from pathlib import Path
from lupa.lua51 import LuaRuntime
R = Path(__file__).resolve().parents[2]
lua = LuaRuntime(unpack_returned_tuples=True)
def read(p): return (R / p).read_text(encoding='utf-8-sig')
for p in ['Code/Camera.lua', 'Code/Dialogue/UITemplates.lua', 'Code/Dialogue/DialogueUI.lua', 'Code/Compat/Compat_335.lua']:
    lua.eval('function(s) assert(loadstring(s)) end')(read(p))
print('Lua 5.1 compile: 4 changed files passed')
compat = read('Code/Compat/Compat_335.lua')
block = compat[compat.index('local WidgetPatches = {}'):compat.index('-- ---------------------------------------------------------------------------\n-- Namespaces:')]
lua.execute('''
addon={} P={} function noop() end
local indices={}
function CreateFrame(kind)
 local index=indices[kind]
 if not index then
  index={Hide=noop, Show=noop, SetScript=noop,
   SetLight=function() return 'native-light' end,
   SetGradient=function() return 'native-gradient' end}
  indices[kind]=index
 end
 local o=setmetatable({}, {__index=index})
 function o:CreateTexture() return CreateFrame('Texture') end
 function o:CreateFontString() return CreateFrame('FontString') end
 function o:CreateAnimationGroup() return CreateFrame('AnimationGroup') end
 function o:CreateAnimation(k) return CreateFrame(k) end
 return o
end
native=CreateFrame('Frame')
nativeTexture=native:CreateTexture()
nativeModel=CreateFrame('PlayerModel')
oldLight=nativeModel.SetLight oldGradient=nativeTexture.SetGradient
''')
lua.execute(block)
lua.execute('''
assert(native.SetShown==nil and nativeTexture.SetAtlas==nil)
assert(nativeTexture.SetGradient==oldGradient and nativeModel.SetLight==oldLight)
local owned=P.CreateFrame('Frame')
assert(owned.SetShown and owned.SetSize)
local tex=owned:CreateTexture()
assert(tex.SetAtlas and tex.SetGradient~=oldGradient)
assert(nativeTexture.SetAtlas==nil and nativeTexture.SetGradient==oldGradient)
local model=P.CreateFrame('PlayerModel')
assert(model.SetLight~=oldLight and model:SetLight(true,1)=='native-light')
-- XML OnLoad preparation: existing regions, children and animations.
local xml=CreateFrame('Frame') local region=xml:CreateTexture()
local child=CreateFrame('Button') local ag=xml:CreateAnimationGroup()
local alpha=ag:CreateAnimation('Alpha')
function xml:GetRegions() return region end
function xml:GetChildren() return child end
function xml:GetAnimationGroups() return ag end
function ag:GetAnimations() return alpha end
addon.PrepareWidget(xml)
assert(region.SetAtlas and child.SetShown and alpha.SetFromAlpha)
local f=xml.CreateTexture addon.PrepareWidget(xml) assert(xml.CreateTexture==f)
assert(native.SetShown==nil)
''')
print('Widget isolation: native methods unchanged; own factory/XML regions/children/animations/idempotence passed')
item=read('Code/Dialogue/UITemplates.lua')
methods=item[item.index('function DUIDialogItemButtonMixin:ResetCountLayout()'):item.index('local ITEM_OVERLAYS')]
lua.execute('''
DUIDialogItemButtonMixin={} ITEMBUTTON_TEXT_WDITH_SHRINK=48
FORMAT_COUNT_OWNED_REQUIRED='%s/%s'
function IsQuestRequiredItem() return false end
function GetItemCount() return 99 end
function region()
 return {SetText=function(s,t) s.text=t end,GetStringWidth=function(s) return #(s.text or '')*7 end,
 ClearAllPoints=function(s) s.points={} end, SetPoint=function(s,...) s.points=s.points or {} table.insert(s.points,{...}) end,
 SetJustifyH=function(s,v) s.justify=v end,SetTextColor=noop}
end
button=setmetatable({Name=region(),Count=region(),Icon={},type='required',itemID=1}, {__index=DUIDialogItemButtonMixin})
function button:ResetToDefaultSize() end
function button:FitToName() self.fitted=self.textShrink end
''')
lua.execute(methods)
lua.execute('''
button:SetItemCount(2048)
assert(button.Count.text=='99/2048' and button.Count.points[1][1]=='RIGHT')
assert(button.Name.points[2][4] < -8 and button.fitted>48)
button.type='reward' button:SetItemCount(2)
assert(button.Count.text==2 and button.Count.points[1][2]==button.Icon and button.textShrink==48)
button:SetItemCount(nil) assert(button.Count.text==nil and button.Name.points[2][4]==-8)
button:SetItemCount(3,true) assert(button.Count.justify=='CENTER')
button:ResetCountLayout() assert(button.Count.justify=='RIGHT')
''')
print('Count layout: 99/2048 separate column, name reserve, reward/empty/center/reuse reset passed')
dialog=read('Code/Dialogue/DialogueUI.lua')
close=dialog[dialog.index('function DUIDialogBaseMixin:CloseDialogInteraction()'):dialog.index('function DUIDialogBaseMixin:OnHide()')]
lua.execute('''
DUIDialogBaseMixin={} API={} active=false closes=0
function API.IsInteractingWithDialogNPC() return active end
function CloseQuest() closes=closes+1 end
function CloseGossipInteraction() closes=closes+1 end
''')
lua.execute(close)
lua.execute('''
local b=setmetatable({}, {__index=DUIDialogBaseMixin})
b:CloseDialogInteraction() assert(closes==0)
active=true b:CloseDialogInteraction() assert(closes==2)
b.interactionIsContinuing=true b:CloseDialogInteraction() assert(closes==2 and not b.interactionIsContinuing)
''')
print('Dialog closure: ended interaction not closed again; active ESC and continuation passed')
cam=read('Code/Camera.lua')
camblock=cam[cam.index('if addon.IS_335 then',cam.index('--The retail code')):]
lua.execute('''
addon.IS_335=true addon.HasNativeCameraZoom=true CameraUtil={} C_CVar={} API={}
VIEW_INDEX=4 speed=0 zoom=12 saved=0 viewed=0 zoomed=0
function SaveView() saved=saved+1 end
function SetView() viewed=viewed+1 end
function GetCameraZoom() return zoom end
function GetUnitSpeed() return speed end
function CameraZoomIn(n) zoomed=zoomed-n end
function CameraZoomOut(n) zoomed=zoomed+n end
function GetCVar() return '1' end
function SetCVar() end
function UnitHasVehicleUI() return false end
FadeHelper={FadeInUI=noop}
function CameraUtil:SetScript() end
function CameraUtil:StopUpdatingForm() end
function CameraUtil:RestoreCVars() return true end
function CameraUtil:OnInteractionStop() end
function API.EvaluateNPCSize() return true end
local old=CreateFrame
function CreateFrame(k)
 local f=old(k) restorer=f
 function f:Hide() self.shown=false end
 function f:Show() self.shown=true end
 function f:IsShown() return self.shown end
 return f
end
''')
lua.execute(camblock)
lua.execute('''
CameraUtil:Intro_FocusNPC() assert(saved==1)
CameraUtil:Restore() restorer:OnUpdate(.016) restorer:OnUpdate(.016)
assert(viewed==1)
restorer:Stop() speed=7 zoom=15
CameraUtil:Intro_FocusNPC() zoom=5 CameraUtil:Restore()
restorer:OnUpdate(.016) restorer:OnUpdate(.016)
assert(viewed==1 and zoomed==10)
CameraUtil:Restore() assert(not restorer.pending)
CameraUtil:Intro_FocusNPC() assert(saved==2 and CameraUtil.view335Zoom==15)
CameraUtil:Restore() assert(restorer.restoreZoom==15)
restorer:Stop() addon.HasNativeCameraZoom=false
CameraUtil:Intro_FocusNPC() CameraUtil:Restore()
restorer:OnUpdate(.016) restorer:OnUpdate(.016)
assert(viewed==2) -- a synthetic zoom query must never select relative zoom restore
''')
print('Camera: standing SetView, moving zoom-only return, duplicate restore and quick reopen passed')
print('NOT VERIFIED: Sirus rendering, actual camera smoothness, arena taint origin/absence, installed game copy')
