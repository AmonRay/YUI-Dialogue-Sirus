-- DialogueUI: compatibility layer for WoW 3.3.5a (Sirus interface patch)
-- Loaded first. Provides retail APIs used by the addon on top of 3.3.5 functions,
-- safe stubs for systems that do not exist in 3.3.5 and helpers used by converted XML.

local addonName, addon = ...
local _G = _G
local type, select, pairs, ipairs, tonumber, tostring = type, select, pairs, ipairs, tonumber, tostring
local function noop() end

addon.IS_335 = true

-- Private environment: every DialogueUI file runs with setfenv(1, addon.Env).
-- Retail shims (C_* namespaces, Enum, WOW_PROJECT_*) live here instead of _G,
-- so other addons' feature detection is not affected. Writes still go to _G.
local Env = setmetatable({}, {__index = _G, __newindex = _G})
addon.Env = Env
setfenv(1, Env)

-- P.X = v stores X privately in Env (Env.X = v would leak into _G through __newindex).
-- Leaking Enum / WOW_PROJECT_ID into _G broke Sirus FrameXML (nameplates) and other addons,
-- and made NativeEnum recurse forever ("error in error handling" at load).
local P = setmetatable({}, {__index = Env, __newindex = function(_, k, v) rawset(Env, k, v) end})


-- ---------------------------------------------------------------------------
-- Project constants (Initialization.lua compares WOW_PROJECT_ID with these)
-- ---------------------------------------------------------------------------
P.WOW_PROJECT_MAINLINE = rawget(_G, "WOW_PROJECT_MAINLINE") or 1
P.WOW_PROJECT_CLASSIC = rawget(_G, "WOW_PROJECT_CLASSIC") or 2
P.WOW_PROJECT_BURNING_CRUSADE_CLASSIC = rawget(_G, "WOW_PROJECT_BURNING_CRUSADE_CLASSIC") or 5
P.WOW_PROJECT_WRATH_CLASSIC = rawget(_G, "WOW_PROJECT_WRATH_CLASSIC") or 11
P.WOW_PROJECT_CATACLYSM_CLASSIC = rawget(_G, "WOW_PROJECT_CATACLYSM_CLASSIC") or 14
P.WOW_PROJECT_MISTS_CLASSIC = rawget(_G, "WOW_PROJECT_MISTS_CLASSIC") or 19
P.WOW_PROJECT_CAMELOT = rawget(_G, "WOW_PROJECT_CAMELOT") or 1001
P.WOW_PROJECT_ID = rawget(_G, "WOW_PROJECT_ID") or rawget(Env, "WOW_PROJECT_WRATH_CLASSIC")


-- ---------------------------------------------------------------------------
-- Generic helpers
-- ---------------------------------------------------------------------------
if not Mixin then
    function Mixin(object, ...)
        for i = 1, select("#", ...) do
            local mixin = select(i, ...)
            if mixin then
                for k, v in pairs(mixin) do
                    object[k] = v
                end
            end
        end
        return object
    end
end

if not CreateFromMixins then
    function CreateFromMixins(...)
        return Mixin({}, ...)
    end
end

if not CreateAndInitFromMixin then
    function CreateAndInitFromMixin(mixin, ...)
        local object = CreateFromMixins(mixin)
        object:Init(...)
        return object
    end
end

local MissingMixins = {}

-- Replacement for XML mixin="..." (called from converted OnLoad scripts)
function DUI_ApplyMixin(object, mixinName)
    local mixin = _G[mixinName]
    if mixin then
        if not (object.__duiMixins and object.__duiMixins[mixinName]) then
            for k, v in pairs(mixin) do
                object[k] = v
            end
            object.__duiMixins = object.__duiMixins or {}
            object.__duiMixins[mixinName] = true
        end
    elseif not MissingMixins[mixinName] then
        MissingMixins[mixinName] = true
        print("|cffff8800DialogueUI:|r missing mixin "..tostring(mixinName))
    end
end

-- Replacement for XML handlers that 3.3.5 does not accept on this widget type
function DUI_SetScriptSafe(object, scriptName, handler)
    if type(handler) == "string" then
        local method = handler
        handler = function(self, ...)
            if self[method] then
                return self[method](self, ...)
            end
        end
    end
    if object.HasScript and object:HasScript(scriptName) then
        object:SetScript(scriptName, handler)
    end
end

--Sound file muting does not exist in 3.3.5a (Sound.lua mutes the "target lost" / menu open sounds)
if not MuteSoundFile then P.MuteSoundFile = noop end
if not UnmuteSoundFile then P.UnmuteSoundFile = noop end

if not GetTimePreciseSec then
    function P.GetTimePreciseSec()
        return debugprofilestop() / 1000
    end
end

if not CreateVector3D then
    local Vector3DMixin = {}
    function Vector3DMixin:GetXYZ() return self.x, self.y, self.z end
    function Vector3DMixin:SetXYZ(x, y, z) self.x, self.y, self.z = x, y, z end
    function Vector3DMixin:Clone() return CreateVector3D(self.x, self.y, self.z) end
    function Vector3DMixin:ScaleBy(s) self.x, self.y, self.z = self.x * s, self.y * s, self.z * s end
    function Vector3DMixin:Add(o) self.x, self.y, self.z = self.x + o.x, self.y + o.y, self.z + o.z end
    function Vector3DMixin:Subtract(o) self.x, self.y, self.z = self.x - o.x, self.y - o.y, self.z - o.z end
    function CreateVector3D(x, y, z)
        local v = CreateFromMixins(Vector3DMixin)
        v:SetXYZ(x or 0, y or 0, z or 0)
        return v
    end
end

if not GetMaxPlayerLevel then
    function P.GetMaxPlayerLevel() return MAX_PLAYER_LEVEL or 80 end
end

if not GetMaxLevelForPlayerExpansion then
    function P.GetMaxLevelForPlayerExpansion() return GetMaxPlayerLevel() end
end

if not UnitHasVehiclePlayerFrameUI then
    function P.UnitHasVehiclePlayerFrameUI(unit)
        return UnitHasVehicleUI and UnitHasVehicleUI(unit) or false
    end
end


-- ---------------------------------------------------------------------------
-- Retail globals that the dialog / quest / widget code calls without a guard.
-- All of them are nil on 3.3.5a ("attempt to call global ... (a nil value)").
-- ---------------------------------------------------------------------------
-- API.lua UnitPortraitSetter: 3.3.5a builds unit portraits synchronously,
-- so the model is "ready" as soon as the unit exists.
if not IsUnitModelReadyForUI then
    function P.IsUnitModelReadyForUI(unit)
        return (unit ~= nil and UnitExists(unit)) and true or false
    end
end

-- DialogueUI.lua quest layouts: no quest currencies, hidden quest items or quest portraits on 3.3.5a
if not GetNumQuestCurrencies then function P.GetNumQuestCurrencies() return 0 end end
if not IsQuestItemHidden then function P.IsQuestItemHidden() return 0 end end       --callers test "hidden == 0"
if not GetQuestPortraitGiver then function P.GetQuestPortraitGiver() return 0 end end
if not GetQuestCurrencyInfo then P.GetQuestCurrencyInfo = noop end
if not GetQuestCurrencyID then P.GetQuestCurrencyID = noop end
if not GetNumRewardCurrencies then function P.GetNumRewardCurrencies() return 0 end end
if not GetRewardSkillLineID then P.GetRewardSkillLineID = noop end
if not IsCharacterNewlyBoosted then function P.IsCharacterNewlyBoosted() return false end end
if not IsSpellKnownOrOverridesKnown then
    function P.IsSpellKnownOrOverridesKnown(spellID)
        return (spellID and IsSpellKnown and IsSpellKnown(spellID)) and true or false
    end
end

-- API.lua GetInteractType: no cursor-type query on 3.3.5a, report "no type"
if not SetUnitCursorTexture then
    function P.SetUnitCursorTexture(texture)
        if texture and texture.SetTexture then texture:SetTexture(nil) end
        return false
    end
end

-- BookUI.lua
if not ItemTextIsFullPage then function P.ItemTextIsFullPage() return false end end

-- QuestAreaTrigger.lua (nil = use its map-position fallback)
if not UnitPosition then P.UnitPosition = noop end

-- API.lua (clear keyboard focus)
if not securecallfunction then
    function P.securecallfunction(func, ...)
        return securecall(func, ...)
    end
end

-- UITemplates.lua item buttons (Ctrl+Click = dressing room)
if not DressUpLink then
    function P.DressUpLink(link)
        if link and DressUpItemLink then
            return DressUpItemLink(link)
        end
    end
end

-- Widget_QuestPopup.lua: auto-accept quest popups arrived in 4.0
if not AddAutoQuestPopUp then function P.AddAutoQuestPopUp() return false end end
if not RemoveAutoQuestPopUp then P.RemoveAutoQuestPopUp = noop end
if not ShowQuestOffer then P.ShowQuestOffer = noop end

-- GossipData_LFRQueue.lua
if not GetRaidDifficultyID then
    function P.GetRaidDifficultyID() return GetRaidDifficulty and GetRaidDifficulty() or 1 end
end
if not GetDungeonDifficultyID then
    function P.GetDungeonDifficultyID() return GetDungeonDifficulty and GetDungeonDifficulty() or 1 end
end

-- Retail file IDs used as default icons -> real 3.3.5a paths (SetTexture(number) shows nothing here)
P.DUI_ICON_QUESTIONMARK = "Interface\\Icons\\INV_Misc_QuestionMark"
P.DUI_ICON_NOTE = "Interface\\Icons\\INV_Misc_Note_02"
P.DUI_ICON_GOSSIP = "Interface\\GossipFrame\\GossipGossipIcon"

if not Clamp then
    function Clamp(v, a, b) if v < a then return a elseif v > b then return b end return v end
end
if not Saturate then
    function Saturate(v) return Clamp(v, 0, 1) end
end
if not Lerp then
    function Lerp(a, b, t) return a + (b - a) * t end
end
if not Round then
    function Round(v) if v < 0 then return math.ceil(v - 0.5) end return math.floor(v + 0.5) end
end
if not tInvert then
    function tInvert(t) local r = {} for k, v in pairs(t) do r[v] = k end return r end
end
if not CopyTable then
    function CopyTable(t)
        local r = {}
        for k, v in pairs(t) do
            if type(v) == "table" then r[k] = CopyTable(v) else r[k] = v end
        end
        return r
    end
end

if not GetQuestID then
    function P.GetQuestID() return 0 end
end

-- Enum: unknown enum groups resolve to empty tables so lookups return nil
local NATIVE_ENUM = rawget(_G, "Enum")
local function NativeEnum(k)
    local real = NATIVE_ENUM or rawget(_G, "Enum")
    if real == nil or real == rawget(Env, "Enum") then return end
    local g = type(real) == "table" and real[k] or nil
    if type(g) == "table" then return g end
end
addon.NativeEnum = NativeEnum
-- Private Enum: groups fall back to the client's Enum; unknown groups are empty tables.
P.Enum = setmetatable({}, {__index = function(t, k)
    local v = setmetatable({}, {__index = NativeEnum(k)})
    rawset(t, k, v)
    return v
end})
Enum.QuestFrequency = Enum.QuestFrequency or {}
Enum.QuestFrequency.Default = Enum.QuestFrequency.Default or 0
Enum.QuestFrequency.Daily = Enum.QuestFrequency.Daily or 1
Enum.QuestFrequency.Weekly = Enum.QuestFrequency.Weekly or 2

-- Quest tag IDs (same values as GetQuestTagInfo on 3.3.5)
if not NativeEnum("QuestTag") then
    Enum.QuestTag = {Group = 1, PvP = 41, Raid = 62, Dungeon = 81, Legendary = 83, Heroic = 85, Raid10 = 88, Raid25 = 89, Scenario = 98, Account = 102}
end
if not NativeEnum("QuestTagType") then
    Enum.QuestTagType = {Tag = 0, Profession = 1, Normal = 2, PvP = 3, PetBattle = 4, Bounty = 5, Dungeon = 6, Invasion = 7, Raid = 8, Contribution = 9, RatedReward = 10, InvasionWrapper = 11, FactionAssault = 12, Islands = 13, Threat = 14, CovenantCalling = 15}
end


-- ---------------------------------------------------------------------------
-- Widget methods missing in 3.3.5
-- ---------------------------------------------------------------------------
do
    local frame = CreateFrame("Frame")
    local texture = frame:CreateTexture()
    local fontString = frame:CreateFontString()
    local animGroup = frame:CreateAnimationGroup()
    local alpha = animGroup:CreateAnimation("Alpha")
    local scale = animGroup:CreateAnimation("Scale")
    local translation = animGroup:CreateAnimation("Translation")

    local function Index(object)
        local mt = getmetatable(object)
        return mt and type(mt.__index) == "table" and mt.__index
    end

    local function Add(index, name, func)
        if index and not index[name] then
            index[name] = func
        end
    end

    local Region = {
        SetShown = function(self, shown) if shown then self:Show() else self:Hide() end end,
        SetIgnoreParentAlpha = noop,
        SetIgnoreParentScale = noop,
        IsIgnoringParentAlpha = function() return false end,
        SetSnapToPixelGrid = noop,
        SetTexelSnappingBias = noop,
        GetScaledRect = function(self)
            local l, b, w, h = self:GetRect()
            if not l then return end
            local s = self:GetEffectiveScale()
            return l * s, b * s, w * s, h * s
        end,
        SetPassThroughButtons = noop,
        IsMouseMotionFocus = function(self) return GetMouseFocus() == self end,
        SetMouseClickEnabled = function(self, v) if v then self:EnableMouse(true) end end,
        SetMouseMotionEnabled = function(self, v) if v then self:EnableMouse(true) end end,
        SetPropagateKeyboardInput = noop,
        SetHyperlinksEnabled = noop,
        SetClipsChildren = noop,
        DoesClipChildren = function() return false end,
        SetFixedFrameStrata = noop,
        SetFixedFrameLevel = noop,
        SetFlattensRenderLayers = noop,
        SetObeyStepOnDrag = noop,
        SetUsingParentLevel = noop,
        SetIsFrameBuffer = noop,
        SetDrawLayerEnabled = noop,
        SetSize = function(self, w, h) self:SetWidth(w) self:SetHeight(h or w) end,
        GetSize = function(self) return self:GetWidth(), self:GetHeight() end,
        EnableMouseMotion = function(self, v) if v and self.EnableMouse then self:EnableMouse(true) end end,
        EnableGamePadButton = noop,
        EnableGamePadStick = noop,
        --No masks in 3.3.5: hand out a hidden texture so AddMaskTexture/SetTexture calls stay valid
        CreateMaskTexture = function(self, name, layer, inherits, sublevel)
            local mask = self:CreateTexture(name, layer or "ARTWORK")
            mask:Hide()
            mask.Show = noop
            mask.SetShown = noop
            return mask
        end,
    }

    local frameIndex = Index(frame)
    for k, v in pairs(Region) do Add(frameIndex, k, v) end
    for _, widget in ipairs({"Button", "CheckButton", "EditBox", "ScrollFrame", "Slider", "StatusBar", "Cooldown", "Model", "PlayerModel", "MessageFrame", "ScrollingMessageFrame", "SimpleHTML", "GameTooltip", "ColorSelect"}) do
        --No template: GameTooltipTemplate's OnLoad concatenates self:GetName() and errors on unnamed frames.
        --The widget metatable is shared regardless of template, so a bare probe is enough.
        local ok, obj = pcall(CreateFrame, widget)
        if ok and obj then
            local index = Index(obj)
            for k, v in pairs(Region) do Add(index, k, v) end
            obj:Hide()
        end
    end

    -- Model widgets: retail-only setters become no-ops
    local ModelExtras = {
        SetKeepModelOnHide = noop,
        SetModelDrawLayer = noop,
        SetAutoDress = noop,
        SetDoBlend = noop,
        SetParticlesEnabled = noop,
        SetViewTranslation = noop,
        SetViewInsets = noop,
        SetDesaturation = noop,
        SetPaused = noop,
        SetAnimation = noop,
        SetDisplayInfo = noop,
        SetCreature = noop,
        SetItemAppearance = noop,
        TryOn = noop,
        Undress = noop,
        UndressSlot = noop,
        FreezeAnimation = noop,
        SetModelAlpha = noop,
        SetUseTransmogSkin = noop,
        SetPortraitZoom = noop,
        SetCamDistanceScale = noop,
        SetPitch = noop,
        SetRoll = noop,
        SetModelByFileID = noop,
        SetPreferModelCollisionBounds = noop,
        SetModelByCreatureDisplayID = function(self, displayID)
            if displayID and self.SetDisplayInfo then self:SetDisplayInfo(displayID) end
        end,
        GetActiveBoundingBox = function() return -0.5, -0.5, 0, 0.5, 0.5, 2 end,
    }

    local function ColorRGB(c, r, g, b)
        if type(c) == "table" then
            if c.GetRGB then return c:GetRGB() end
            return c.r or r, c.g or g, c.b or b
        end
        return r, g, b
    end

    --Retail Model:SetLight(enabled, lightTable); 3.3.5 only accepts positional numbers:
    --SetLight(enabled, omni, dirX, dirY, dirZ, ambIntensity, ambR, ambG, ambB, dirIntensity, dirR, dirG, dirB)
    local function WrapSetLight(index)
        local orig = index and rawget(index, "SetLight")
        if type(orig) ~= "function" or rawget(index, "__duiSetLight") then return end
        rawset(index, "__duiSetLight", true)
        rawset(index, "SetLight", function(self, enabled, light, ...)
            if type(light) ~= "table" then
                return orig(self, enabled, light, ...)
            end
            local x, y, z = 0, 0, -1
            local p = light.point
            if type(p) == "table" then
                if p.GetXYZ then x, y, z = p:GetXYZ() else x, y, z = p.x or x, p.y or y, p.z or z end
            end
            local ar, ag, ab = ColorRGB(light.ambientColor, 1, 1, 1)
            local dr, dg, db = ColorRGB(light.diffuseColor, 1, 1, 1)
            return orig(self, enabled and 1 or 0, light.omnidirectional and 1 or 0, x, y, z,
                light.ambientIntensity or 1, ar, ag, ab, light.diffuseIntensity or 1, dr, dg, db)
        end)
    end

    for _, widget in ipairs({"Model", "PlayerModel", "DressUpModel"}) do
        local ok, obj = pcall(CreateFrame, widget)
        if ok and obj then
            local index = Index(obj)
            for k, v in pairs(Region) do Add(index, k, v) end
            for k, v in pairs(ModelExtras) do Add(index, k, v) end
            WrapSetLight(index)
            obj:Hide()
        end
    end

    -- EditBox: ClearHighlightText does not exist in 3.3.5
    do
        local ok, eb = pcall(CreateFrame, "EditBox")
        if ok and eb then
            if eb.SetAutoFocus then eb:SetAutoFocus(false) end
            eb:Hide()
            local index = Index(eb)
            Add(index, "ClearHighlightText", function(self) self:HighlightText(0, 0) end)
            Add(index, "SetCountInvisibleLetters", noop)
            Add(index, "SetHighlightColor", noop)
            Add(index, "LockHighlight", noop)
            Add(index, "UnlockHighlight", noop)
        end
    end

    local textureIndex = Index(texture)
    for k, v in pairs(Region) do Add(textureIndex, k, v) end
    Add(textureIndex, "SetColorTexture", function(self, r, g, b, a) self:SetTexture(r, g, b, a) end)
    Add(textureIndex, "AddMaskTexture", noop)
    Add(textureIndex, "RemoveMaskTexture", noop)
    Add(textureIndex, "GetNumMaskTextures", function() return 0 end)
    Add(textureIndex, "SetMask", noop)
    -- 3.3.5a regions have no SetScale/GetScale/GetEffectiveScale (retail code rescales slice textures)
    Add(textureIndex, "SetScale", noop)
    Add(textureIndex, "GetScale", function() return 1 end)
    Add(textureIndex, "GetEffectiveScale", function(self)
        local parent = self:GetParent()
        return parent and parent:GetEffectiveScale() or 1
    end)
    -- Texture slicing (SetTextureSliceMargins) does not exist on 3.3.5a, so every panel background was a
    -- single stretched image. Emulation: the sliced texture keeps its anchors/size but draws nothing; nine
    -- sibling textures on the same parent draw corners/edges/center. Corner size: 1 texel = 1 screen pixel
    -- (same rule as the addon's own PseudoSliceTexture). Needs addon.TextureFileSizes
    -- (Code/Compat/TextureSizes_335.lua); files without a known size are drawn unsliced.
    if textureIndex and not textureIndex.SetTextureSliceMargins then
        local OrigSetTexture, OrigGetTexture, OrigSetTexCoord = textureIndex.SetTexture, textureIndex.GetTexture, textureIndex.SetTexCoord
        local OrigSetVertexColor, OrigSetAlpha = textureIndex.SetVertexColor, textureIndex.SetAlpha
        local OrigShow, OrigHide = textureIndex.Show, textureIndex.Hide
        local OrigSetDesaturated, OrigSetBlendMode, OrigSetDrawLayer = textureIndex.SetDesaturated, textureIndex.SetBlendMode, textureIndex.SetDrawLayer
        local SliceData = setmetatable({}, {__mode = "k"})
        local SlicePieces = setmetatable({}, {__mode = "k"})
        local PIECE_COL = {1, 2, 3, 1, 2, 3, 1, 2, 3}
        local PIECE_ROW = {1, 1, 1, 2, 2, 2, 3, 3, 3}

        local function FileKey(file)
            if type(file) ~= "string" or file == "" then return end
            local key = string.lower(file)
            key = string.gsub(key, "\\", "/")
            key = string.gsub(key, "^interface/addons/dialogueui/art/", "")
            key = string.gsub(key, "%.%w+$", "")
            return key
        end

        local function PixelToUnit(region)
            local h
            if GetPhysicalScreenSize then h = select(2, GetPhysicalScreenSize()) end
            if not (h and h > 0) then
                local res = GetCVar("gxResolution")
                h = tonumber(res and string.match(res, "%d+x(%d+)") or "")
            end
            if not (h and h > 0) then h = 768 end
            local parent = region:GetParent()
            local scale = parent and parent:GetEffectiveScale() or 1
            if not scale or scale <= 0 then scale = 1 end
            return 768 / h / scale
        end

        local function GetPieces(host)
            local pieces = SlicePieces[host]
            if pieces then return pieces end
            local parent = host:GetParent()
            local layer, sublevel = host:GetDrawLayer()
            layer = layer or "ARTWORK"
            pieces = {}
            for i = 1, 9 do
                local piece = parent:CreateTexture(nil, layer)
                if sublevel then pcall(OrigSetDrawLayer, piece, layer, sublevel) end
                OrigHide(piece)
                pieces[i] = piece
            end
            local p = pieces
            p[1]:SetPoint("TOPLEFT", host, "TOPLEFT", 0, 0)
            p[3]:SetPoint("TOPRIGHT", host, "TOPRIGHT", 0, 0)
            p[7]:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT", 0, 0)
            p[9]:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", 0, 0)
            p[2]:SetPoint("TOPLEFT", p[1], "TOPRIGHT", 0, 0); p[2]:SetPoint("BOTTOMRIGHT", p[3], "BOTTOMLEFT", 0, 0)
            p[4]:SetPoint("TOPLEFT", p[1], "BOTTOMLEFT", 0, 0); p[4]:SetPoint("BOTTOMRIGHT", p[7], "TOPRIGHT", 0, 0)
            p[5]:SetPoint("TOPLEFT", p[1], "BOTTOMRIGHT", 0, 0); p[5]:SetPoint("BOTTOMRIGHT", p[9], "TOPLEFT", 0, 0)
            p[6]:SetPoint("TOPLEFT", p[3], "BOTTOMLEFT", 0, 0); p[6]:SetPoint("BOTTOMRIGHT", p[9], "TOPRIGHT", 0, 0)
            p[8]:SetPoint("TOPLEFT", p[7], "TOPRIGHT", 0, 0); p[8]:SetPoint("BOTTOMRIGHT", p[9], "BOTTOMLEFT", 0, 0)
            SlicePieces[host] = pieces
            return pieces
        end

        local function ApplyStyle(data, pieces)
            for i = 1, 9 do
                local piece = pieces[i]
                OrigSetVertexColor(piece, data.r or 1, data.g or 1, data.b or 1, data.a or 1)
                OrigSetAlpha(piece, data.alpha or 1)
                if OrigSetDesaturated then OrigSetDesaturated(piece, data.desaturated and true or false) end
                if OrigSetBlendMode and data.blendMode then OrigSetBlendMode(piece, data.blendMode) end
            end
        end

        local function UpdateVisibility(host, data)
            local pieces = SlicePieces[host]
            local show = data.fileWidth and host:IsShown()
            for i = 1, 9 do
                if show then OrigShow(pieces[i]) else OrigHide(pieces[i]) end
            end
        end

        local function Layout(host, data)
            local w, h = data.fileWidth, data.fileHeight
            if not w then return end
            local pieces = SlicePieces[host]
            local left, top, right, bottom = data.left, data.top, data.right, data.bottom
            local L, R, T, B = data.texL, data.texR, data.texT, data.texB
            local sx = (R >= L) and 1 or -1
            local sy = (B >= T) and 1 or -1
            local xs = {L, L + sx * left / w, R - sx * right / w, R}
            local ys = {T, T + sy * top / h, B - sy * bottom / h, B}
            local unit = PixelToUnit(host)
            local cl, cr = math.max(left * unit, 0.01), math.max(right * unit, 0.01)
            local ct, cb = math.max(top * unit, 0.01), math.max(bottom * unit, 0.01)
            pieces[1]:SetWidth(cl); pieces[1]:SetHeight(ct)
            pieces[3]:SetWidth(cr); pieces[3]:SetHeight(ct)
            pieces[7]:SetWidth(cl); pieces[7]:SetHeight(cb)
            pieces[9]:SetWidth(cr); pieces[9]:SetHeight(cb)
            for i = 1, 9 do
                local c, r = PIECE_COL[i], PIECE_ROW[i]
                OrigSetTexture(pieces[i], data.file)
                OrigSetTexCoord(pieces[i], xs[c], xs[c + 1], ys[r], ys[r + 1])
            end
        end

        local function SetFile(host, data, file, ...)
            data.file = file
            local key = FileKey(file)
            local size = key and addon.TextureFileSizes and addon.TextureFileSizes[key]
            if size then
                data.fileWidth, data.fileHeight = size[1], size[2]
                OrigSetTexture(host, nil)
                Layout(host, data)
            else
                data.fileWidth, data.fileHeight = nil, nil
                OrigSetTexture(host, file, ...)
                OrigSetTexCoord(host, data.texL, data.texR, data.texT, data.texB)
            end
            UpdateVisibility(host, data)
        end

        local Methods = {}
        function Methods.SetTexture(self, file, ...)
            local data = SliceData[self]
            if type(file) ~= "string" then
                data.file, data.fileWidth, data.fileHeight = file, nil, nil
                UpdateVisibility(self, data)
                return OrigSetTexture(self, file, ...)
            end
            SetFile(self, data, file, ...)
            return true
        end
        function Methods.GetTexture(self)
            return SliceData[self].file
        end
        function Methods.SetTexCoord(self, ...)
            local data = SliceData[self]
            if select("#", ...) >= 8 then
                local ULx, ULy, _, _, _, _, LRx, LRy = ...
                data.texL, data.texR, data.texT, data.texB = ULx, LRx, ULy, LRy
            else
                local l, r, t, b = ...
                data.texL, data.texR, data.texT, data.texB = l or 0, r or 1, t or 0, b or 1
            end
            if data.fileWidth then
                Layout(self, data)
            else
                OrigSetTexCoord(self, ...)
            end
        end
        function Methods.SetVertexColor(self, r, g, b, a)
            local data = SliceData[self]
            data.r, data.g, data.b, data.a = r, g, b, a
            OrigSetVertexColor(self, r, g, b, a)
            ApplyStyle(data, SlicePieces[self])
        end
        function Methods.SetAlpha(self, alpha)
            local data = SliceData[self]
            data.alpha = alpha
            OrigSetAlpha(self, alpha)
            ApplyStyle(data, SlicePieces[self])
        end
        function Methods.SetDesaturated(self, desaturated)
            local data = SliceData[self]
            data.desaturated = desaturated
            ApplyStyle(data, SlicePieces[self])
            if OrigSetDesaturated then return OrigSetDesaturated(self, desaturated) end
        end
        function Methods.SetBlendMode(self, mode)
            local data = SliceData[self]
            data.blendMode = mode
            OrigSetBlendMode(self, mode)
            ApplyStyle(data, SlicePieces[self])
        end
        function Methods.SetDrawLayer(self, layer, sublevel)
            OrigSetDrawLayer(self, layer, sublevel)
            local pieces = SlicePieces[self]
            for i = 1, 9 do OrigSetDrawLayer(pieces[i], layer, sublevel) end
        end
        function Methods.Show(self)
            OrigShow(self)
            UpdateVisibility(self, SliceData[self])
        end
        function Methods.Hide(self)
            OrigHide(self)
            UpdateVisibility(self, SliceData[self])
        end

        textureIndex.SetTextureSliceMargins = function(self, left, top, right, bottom)
            local data = SliceData[self]
            if not data then
                data = {}
                local ULx, ULy, _, _, _, _, LRx, LRy = self:GetTexCoord()
                data.texL, data.texR, data.texT, data.texB = ULx or 0, LRx or 1, ULy or 0, LRy or 1
                data.r, data.g, data.b, data.a = self:GetVertexColor()
                data.alpha = self:GetAlpha()
                data.blendMode = self.GetBlendMode and self:GetBlendMode() or nil
                data.desaturated = self.IsDesaturated and self:IsDesaturated() or nil
                data.file = OrigGetTexture(self)
                SliceData[self] = data
                GetPieces(self)
                for name, func in pairs(Methods) do self[name] = func end
                ApplyStyle(data, SlicePieces[self])
            end
            data.left, data.top, data.right, data.bottom = left or 0, top or 0, right or 0, bottom or 0
            SetFile(self, data, data.file)
        end
        textureIndex.SetTextureSliceMode = function(self, mode)
            local data = SliceData[self]
            if data then data.mode = mode end
        end
        textureIndex.ClearTextureSlice = function(self)
            local data = SliceData[self]
            if not data then return end
            SliceData[self] = nil
            for name in pairs(Methods) do self[name] = nil end
            local pieces = SlicePieces[self]
            for i = 1, 9 do OrigHide(pieces[i]) end
            OrigSetTexture(self, data.file)
            OrigSetTexCoord(self, data.texL, data.texR, data.texT, data.texB)
        end
    end
    Add(textureIndex, "SetRotation", noop)
    Add(textureIndex, "SetSnapToPixelGrid", noop)
    Add(textureIndex, "SetHorizTile", noop)
    Add(textureIndex, "SetVertTile", noop)
    if textureIndex and not textureIndex.SetAtlas then
        textureIndex.SetAtlas = function(self, atlas, useAtlasSize)
            if GetAtlasInfo then
                local info = GetAtlasInfo(atlas)
                if info then
                    self:SetTexture(info.file or info.filename)
                    self:SetTexCoord(info.leftTexCoord, info.rightTexCoord, info.topTexCoord, info.bottomTexCoord)
                    if useAtlasSize and info.width then
                        self:SetWidth(info.width) self:SetHeight(info.height)
                    end
                end
            end
        end
    end

    local fsIndex = Index(fontString)
    for k, v in pairs(Region) do Add(fsIndex, k, v) end
    Add(fsIndex, "SetMaxLines", noop)
    Add(fsIndex, "GetMaxLines", function() return 0 end)
    Add(fsIndex, "SetTextScale", noop)
    Add(fsIndex, "GetTextScale", function() return 1 end)
    Add(fsIndex, "IsTruncated", function(self) return (self:GetStringWidth() or 0) > (self:GetWidth() or 0) + 0.5 end)
    Add(fsIndex, "GetUnboundedStringWidth", function(self) return self:GetStringWidth() end)
    Add(fsIndex, "GetLineHeight", function(self) local _, h = self:GetFont() return h or 12 end)
    Add(fsIndex, "SetFontObjectsToTry", noop)
    Add(fsIndex, "GetWrappedWidth", function(self)
        local sw, w = self:GetStringWidth() or 0, self:GetWidth() or 0
        if w > 0 and sw > w then return w end
        return sw
    end)
    Add(fsIndex, "SetFormattedText", function(self, fmt, ...) self:SetText(string.format(fmt, ...)) end)

    --GameTooltip: retail currency setters (3.3.5 has no currency tooltips by ID)
    if GameTooltip then
        local ttIndex = Index(GameTooltip)
        Add(ttIndex, "SetCurrencyByID", noop)
        Add(ttIndex, "SetQuestCurrency", noop)
        Add(ttIndex, "SetQuestLogCurrency", noop)
    end

    local agIndex = Index(animGroup)
    Add(agIndex, "SetToFinalAlpha", noop)
    Add(agIndex, "SetPlaying", function(self, v) if v then self:Play() else self:Stop() end end)

    local alphaIndex = Index(alpha)
    if alphaIndex and not alphaIndex.SetFromAlpha then
        alphaIndex.SetFromAlpha = function(self, v) self.__fromAlpha = v; self:SetChange((self.__toAlpha or 1) - v) end
        alphaIndex.SetToAlpha = function(self, v) self.__toAlpha = v; self:SetChange(v - (self.__fromAlpha or 0)) end
        alphaIndex.GetFromAlpha = function(self) return self.__fromAlpha or 0 end
        alphaIndex.GetToAlpha = function(self) return self.__toAlpha or 1 end
    end

    local scaleIndex = Index(scale)
    if scaleIndex and not scaleIndex.SetScaleTo then
        scaleIndex.SetScaleFrom = function(self, x, y) self.__from = {x, y} end
        scaleIndex.SetScaleTo = function(self, x, y)
            local f = self.__from or {1, 1}
            self:SetScale(x / (f[1] ~= 0 and f[1] or 1), y / (f[2] ~= 0 and f[2] or 1))
        end
    end

    local trIndex = Index(translation)
    Add(trIndex, "SetSmoothProgress", noop)

    for _, idx in ipairs({alphaIndex, scaleIndex, trIndex}) do
        Add(idx, "SetTarget", noop)
        Add(idx, "SetChildKey", noop)
    end
end


-- CreateFrame: drop retail-only templates, map retail widget types
do
    local RetailTemplates = {
        BackdropTemplate = true,
        DUISetPropagateKeyboardInputTemplate = false,
    }
    local WidgetFallback = {
        ModelScene = "PlayerModel",
        CinematicModel = "PlayerModel",
        DressUpModel = "DressUpModel",
    }
    local OrigCreateFrame = CreateFrame

    local function FilterTemplates(templates)
        if type(templates) ~= "string" then return templates end
        local out
        for t in string.gmatch(templates, "[^,%s]+") do
            if not RetailTemplates[t] then
                out = out and (out..", "..t) or t
            end
        end
        return out
    end

    function addon.CreateFrame(frameType, name, parent, templates, id)
        frameType = WidgetFallback[frameType] or frameType
        return OrigCreateFrame(frameType, name, parent, FilterTemplates(templates), id)
    end
end


-- ---------------------------------------------------------------------------
-- Namespaces: unknown functions become no-ops instead of nil-call errors
-- ---------------------------------------------------------------------------
-- Private copy per namespace: native functions are copied (so rawget checks still see them),
-- later lookups fall back to the client table, anything else is a no-op. _G is never touched.
local function Namespace(name)
    local ns = rawget(Env, name)
    if ns == nil then
        ns = {}
        local real = rawget(_G, name)
        if type(real) == "table" then
            for k, v in pairs(real) do ns[k] = v end
        end
        setmetatable(ns, {__index = function(_, k)
            local native = rawget(_G, name)
            local v
            if type(native) == "table" then v = native[k] end
            if v == nil then return noop end
            return v
        end})
        rawset(Env, name, ns)
    end
    return ns
end
addon.CompatNamespace = Namespace

for _, name in ipairs({
    "C_AddOns", "C_AdventureMap", "C_ArtifactUI", "C_CVar", "C_CampaignInfo", "C_Container", "C_CurrencyInfo",
    "C_GossipInfo", "C_Item", "C_Map", "C_MajorFactions", "C_QuestInfoSystem", "C_QuestLine", "C_QuestLog",
    "C_QuestOffer", "C_Reputation", "C_Spell", "C_SuperTrack", "C_TaskQuest", "C_TooltipInfo", "C_TTSSettings",
    "C_VoiceChat", "C_PlayerInfo", "C_UnitAuras", "C_QuestItemUse", "C_PlayerInteractionManager",
    "C_ClassColor", "C_Texture", "C_Covenants", "C_Garrison", "C_TransmogCollection", "C_MountJournal",
    "C_PetJournal", "C_ToyBox", "C_Heirloom", "C_LFGList", "C_QuestSession", "C_ContentTracking", "C_GameRules",
    "C_Seasons", "C_DateAndTime", "C_ScenarioInfo", "C_SpellBook", "C_AzeriteEmpoweredItem", "C_ItemUpgrade",
    "C_NamePlate", "C_EncodingUtil", "C_Navigation", "C_Housing", "C_StringUtil", "C_Bank",
    "C_GamePad",
}) do
    Namespace(name)
end

-- Retail functions whose result is iterated or indexed without a nil check.
-- Provide safe defaults (empty list / placeholder table) when the client lacks them.
do
    local function Default(nsName, fnName, fn)
        local ns = Namespace(nsName)
        if rawget(ns, fnName) == nil then
            ns[fnName] = fn
        end
    end
    local function EmptyList() return {} end

    Default("C_GamePad", "GetAllDeviceIDs", EmptyList)
    Default("C_GamePad", "IsEnabled", function() return false end)

    Default("C_NamePlate", "GetNamePlates", function()
        -- 3.3.5 has no nameplate API; scan WorldFrame children for visible nameplates.
        local list = {}
        local n = WorldFrame and WorldFrame:GetNumChildren() or 0
        if n > 0 then
            local children = {WorldFrame:GetChildren()}
            for i = 1, n do
                local f = children[i]
                if f and f:IsShown() and not f:GetName() and f.GetRegions then
                    local region = select(2, f:GetRegions())
                    if region and region.GetTexture and region:GetTexture() == "Interface\\Tooltips\\Nameplate-Border" then
                        list[#list + 1] = f
                    end
                end
            end
        end
        return list
    end)

    Default("C_MajorFactions", "GetMajorFactionData", function(factionID)
        local name = factionID and GetFactionInfoByID and GetFactionInfoByID(factionID)
        return {name = name or "", factionID = factionID, renownLevel = 0, renownReputationEarned = 0, renownLevelThreshold = 1}
    end)
    Default("C_MajorFactions", "HasMaximumRenown", function() return false end)

    Default("C_CampaignInfo", "GetCampaignInfo", function()
        return {name = "", description = "", isWarCampaign = false}
    end)

    Default("C_Garrison", "GetFollowerInfo", function()
        return {name = "", quality = 1, level = 1, portraitIconID = DUI_ICON_QUESTIONMARK, isTroop = false}
    end)
    Default("C_Garrison", "GetFollowerAbilityInfo", function()
        return {name = "", description = "", icon = DUI_ICON_QUESTIONMARK}
    end)
    Default("C_Garrison", "GetFollowerAbilities", EmptyList)

    Default("C_QuestLine", "GetQuestLineQuests", EmptyList)
    Default("C_QuestInfoSystem", "GetQuestRewardSpells", EmptyList)
    Default("C_QuestInfoSystem", "HasQuestRewardSpells", function() return false end)
    Default("C_QuestInfoSystem", "HasQuestRewardCurrencies", function()
        return (GetNumRewardCurrencies and GetNumRewardCurrencies() or 0) > 0
    end)
    Default("C_QuestLog", "GetQuestLogMajorFactionReputationRewards", EmptyList)
    Default("C_QuestOffer", "GetQuestOfferMajorFactionReputationRewards", EmptyList)
    Default("C_Garrison", "IsFollowerCollected", function() return false end)

    Default("C_QuestLog", "IsQuestFlaggedCompleted", function(questID)
        if not questID then return false end
        if type(IsQuestFlaggedCompleted) == "function" then
            return IsQuestFlaggedCompleted(questID) and true or false
        end
        if type(GetQuestsCompleted) == "function" then
            local done = {}
            GetQuestsCompleted(done)
            return done[questID] and true or false
        end
        return false
    end)

    Default("C_Item", "IsEquippedItem", function(item)
        return IsEquippedItem and IsEquippedItem(item) and true or false
    end)
    Default("C_Item", "GetDetailedItemLevelInfo", function(item)
        local _, _, _, ilvl = GetItemInfo(item)
        return ilvl
    end)
    Default("C_Container", "GetItemCooldown", function(itemID)
        if GetItemCooldown then return GetItemCooldown(itemID) end
        return 0, 0, 0
    end)
    Default("C_CurrencyInfo", "GetCoinTextureString", function(amount)
        if GetCoinTextureString then return GetCoinTextureString(amount) end
        return tostring(amount or 0)
    end)
    Default("C_StringUtil", "StripHyperlinks", function(text)
        if type(text) ~= "string" then return text end
        text = text:gsub("|H.-|h(.-)|h", "%1")
        text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
        return text
    end)
end


-- GLOBAL_MOUSE_DOWN / GLOBAL_MOUSE_UP emulation (events don't exist on 3.3.5)
-- Used to close dropdowns, flyouts, clipboard, keybinding capture on outside click.
-- Disabled: the Sirus client fires GLOBAL_MOUSE_DOWN/UP natively (UIParent.lua, Custom_Menu register them).
-- Overriding RegisterEvent on every widget metatable hijacked those native registrations for all addons.
if false then
    local EMULATED = {GLOBAL_MOUSE_DOWN = true, GLOBAL_MOUSE_UP = true}
    local subscribers = {GLOBAL_MOUSE_DOWN = setmetatable({}, {__mode = "k"}), GLOBAL_MOUSE_UP = setmetatable({}, {__mode = "k"})}
    local BUTTONS = {"LeftButton", "RightButton", "MiddleButton"}
    local wasDown = {}

    local function Dispatch(event, button)
        for frame in pairs(subscribers[event]) do
            local handler = frame.GetScript and frame:GetScript("OnEvent")
            if handler then
                local ok, err = pcall(handler, frame, event, button)
                if not ok and geterrorhandler then geterrorhandler()(err) end
            end
        end
    end

    local poller = CreateFrame("Frame")
    poller:SetScript("OnUpdate", function()
        if not IsMouseButtonDown then return end
        for _, button in ipairs(BUTTONS) do
            local down = IsMouseButtonDown(button) and true or false
            if down ~= (wasDown[button] or false) then
                wasDown[button] = down
                Dispatch(down and "GLOBAL_MOUSE_DOWN" or "GLOBAL_MOUSE_UP", button)
            end
        end
    end)

    local patched = {}
    local function PatchWidgetType(widgetType)
        local ok, obj = pcall(CreateFrame, widgetType)
        if not ok or not obj then return end
        obj:Hide()
        local mt = getmetatable(obj)
        local index = mt and mt.__index
        if type(index) ~= "table" or patched[index] then return end
        patched[index] = true

        local origRegister, origUnregister, origUnregisterAll, origIsRegistered = index.RegisterEvent, index.UnregisterEvent, index.UnregisterAllEvents, index.IsEventRegistered
        index.RegisterEvent = function(self, event, ...)
            if EMULATED[event] then subscribers[event][self] = true return true end
            return origRegister(self, event, ...)
        end
        index.UnregisterEvent = function(self, event, ...)
            if EMULATED[event] then subscribers[event][self] = nil return end
            return origUnregister(self, event, ...)
        end
        if origUnregisterAll then
            index.UnregisterAllEvents = function(self, ...)
                subscribers.GLOBAL_MOUSE_DOWN[self] = nil
                subscribers.GLOBAL_MOUSE_UP[self] = nil
                return origUnregisterAll(self, ...)
            end
        end
        if origIsRegistered then
            index.IsEventRegistered = function(self, event, ...)
                if EMULATED[event] then return subscribers[event][self] == true end
                return origIsRegistered(self, event, ...)
            end
        end
    end

    for _, widgetType in ipairs({"Frame", "Button", "CheckButton", "ScrollFrame", "EditBox", "Slider", "StatusBar", "Model", "PlayerModel", "DressUpModel", "Cooldown", "GameTooltip", "MessageFrame", "ScrollingMessageFrame", "SimpleHTML", "ColorSelect", "Minimap"}) do
        PatchWidgetType(widgetType)
    end
end


-- C_EventUtils: 3.3.5 can't query events, so answer from a known list
do
    local C_EventUtils = Namespace("C_EventUtils")
    local ValidEvents335 = {
        CONFIRM_TALENT_WIPE = true,
        LEARNED_SPELL_IN_TAB = true,
        GOSSIP_SHOW = true, GOSSIP_CLOSED = true, GOSSIP_CONFIRM = true, GOSSIP_CONFIRM_CANCEL = true, GOSSIP_ENTER_CODE = true,
        QUEST_GREETING = true, QUEST_DETAIL = true, QUEST_PROGRESS = true, QUEST_COMPLETE = true, QUEST_FINISHED = true,
        QUEST_ITEM_UPDATE = true, QUEST_LOG_UPDATE = true, QUEST_ACCEPTED = true, QUEST_ACCEPT_CONFIRM = true,
        UNIT_PORTRAIT_UPDATE = true, ITEM_TEXT_BEGIN = true, ITEM_TEXT_READY = true, ITEM_TEXT_CLOSED = true,
        MERCHANT_SHOW = true, MERCHANT_CLOSED = true, PLAYER_ENTERING_WORLD = true, ZONE_CHANGED_NEW_AREA = true,
        PLAYER_REGEN_ENABLED = true, PLAYER_REGEN_DISABLED = true, MODIFIER_STATE_CHANGED = true, UPDATE_FACTION = true,
        PLAYER_LEVEL_UP = true, UI_ERROR_MESSAGE = true, UI_INFO_MESSAGE = true, CHAT_MSG_LOOT = true, CHAT_MSG_SYSTEM = true,
        LOOT_OPENED = true, LOOT_CLOSED = true, UPDATE_BINDINGS = true, PLAYER_TARGET_CHANGED = true, UNIT_MODEL_CHANGED = true,
        PLAYER_LOGOUT = true, PLAYER_QUITING = true, PLAYER_CAMPING = true, UPDATE_SHAPESHIFT_FORM = true, CINEMATIC_START = true,
        CINEMATIC_STOP = true, PLAY_MOVIE = true, PLAYER_EQUIPMENT_CHANGED = true, BAG_UPDATE = true, BAG_UPDATE_COOLDOWN = true,
        LFG_PROPOSAL_SHOW = true, LFG_PROPOSAL_FAILED = true, LFG_PROPOSAL_SUCCEEDED = true, UPDATE_INSTANCE_INFO = true,
        GLOBAL_MOUSE_DOWN = true, GLOBAL_MOUSE_UP = true,
    }
    if rawget(C_EventUtils, "IsEventValid") == nil then
        C_EventUtils.IsEventValid = function(event) return ValidEvents335[event] == true end
    end
end


-- C_PlayerInteractionManager: track gossip / quest-giver interaction from 3.3.5 events
do
    if not NativeEnum("PlayerInteractionType") then
        Enum.PlayerInteractionType = {Gossip = 3, QuestGiver = 4}
    end

    local TYPE_GOSSIP = Enum.PlayerInteractionType.Gossip or 3
    local TYPE_QUEST_GIVER = Enum.PlayerInteractionType.QuestGiver or 4
    local state = {}

    local tracker = CreateFrame("Frame")
    for _, e in ipairs({"GOSSIP_SHOW", "GOSSIP_CLOSED", "QUEST_GREETING", "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE", "QUEST_FINISHED", "PLAYER_ENTERING_WORLD"}) do
        tracker:RegisterEvent(e)
    end
    tracker:SetScript("OnEvent", function(self, event)
        if event == "GOSSIP_SHOW" then
            state[TYPE_GOSSIP] = true
        elseif event == "GOSSIP_CLOSED" then
            state[TYPE_GOSSIP] = nil
        elseif event == "QUEST_FINISHED" then
            state[TYPE_QUEST_GIVER] = nil
        elseif event == "PLAYER_ENTERING_WORLD" then
            state[TYPE_GOSSIP] = nil
            state[TYPE_QUEST_GIVER] = nil
        else
            state[TYPE_QUEST_GIVER] = true
        end
    end)

    local C_PlayerInteractionManager = C_PlayerInteractionManager
    if rawget(C_PlayerInteractionManager, "IsInteractingWithNpcOfType") == nil then
        C_PlayerInteractionManager.IsInteractingWithNpcOfType = function(interactionType)
            if state[interactionType] then
                if UnitExists("npc") then
                    return true
                end
                state[interactionType] = nil    --interaction ended without the closing event (walked away)
            end
            return false
        end
    end
    if rawget(C_PlayerInteractionManager, "ClearInteraction") == nil then
        C_PlayerInteractionManager.ClearInteraction = function()
            if CloseGossip then CloseGossip() end
            if CloseQuest then CloseQuest() end
        end
    end
end


-- C_AddOns / C_CVar / C_Timer fallbacks
do
    local C_AddOns = C_AddOns
    if rawget(C_AddOns, "GetAddOnMetadata") == nil then C_AddOns.GetAddOnMetadata = GetAddOnMetadata end
    if rawget(C_AddOns, "IsAddOnLoaded") == nil then C_AddOns.IsAddOnLoaded = IsAddOnLoaded end
    if rawget(C_AddOns, "LoadAddOn") == nil then C_AddOns.LoadAddOn = LoadAddOn end
    if rawget(C_AddOns, "GetAddOnInfo") == nil then C_AddOns.GetAddOnInfo = GetAddOnInfo end
    if rawget(C_AddOns, "GetNumAddOns") == nil then C_AddOns.GetNumAddOns = GetNumAddOns end

    local C_CVar = C_CVar
    --Retail-only CVars (test_cameraOverShoulder, cameraFov, Outline...) don't exist on 3.3.5: never let them throw
    local function SafeGetCVar(k)
        local ok, v = pcall(GetCVar, k)
        if ok then return v end
    end
    if rawget(C_CVar, "GetCVar") == nil then C_CVar.GetCVar = SafeGetCVar end
    if rawget(C_CVar, "SetCVar") == nil then
        C_CVar.SetCVar = function(k, v)
            if v == nil or SafeGetCVar(k) == nil then return end
            local ok, r = pcall(SetCVar, k, v)
            if ok then return r end
        end
    end
    if rawget(C_CVar, "GetCVarBool") == nil then C_CVar.GetCVarBool = function(k) return SafeGetCVar(k) == "1" end end

    if not GetCameraZoom then
        --No zoom query on 3.3.5: report the max follow distance so zoom math stays valid
        function P.GetCameraZoom()
            return tonumber(SafeGetCVar("cameraDistanceMax")) or 15
        end
    end
    if rawget(C_CVar, "GetCVarDefault") == nil then C_CVar.GetCVarDefault = GetCVarDefault or noop end

    if type(rawget(_G, "C_Timer")) ~= "table" then _G.C_Timer = {} end
    local C_Timer = _G.C_Timer
    if rawget(C_Timer, "After") == nil then
        local timerFrame = CreateFrame("Frame")
        local timers = {}
        timerFrame:SetScript("OnUpdate", function(self, elapsed)
            local now = GetTime()
            for i = #timers, 1, -1 do
                local t = timers[i]
                if t.cancelled then
                    table.remove(timers, i)
                elseif now >= t.time then
                    table.remove(timers, i)
                    t.callback(t)
                end
            end
        end)
        local function Schedule(delay, callback)
            local t = {time = GetTime() + (delay or 0), callback = callback}
            t.Cancel = function(self) self.cancelled = true end
            t.IsCancelled = function(self) return self.cancelled end
            timers[#timers + 1] = t
            return t
        end
        C_Timer.After = function(delay, callback) Schedule(delay, callback) end
        C_Timer.NewTimer = Schedule
        C_Timer.NewTicker = function(delay, callback, iterations)
            local ticker = {count = 0}
            local function Tick()
                if ticker.cancelled then return end
                ticker.count = ticker.count + 1
                callback(ticker)
                if not iterations or ticker.count < iterations then
                    ticker.timer = Schedule(delay, Tick)
                end
            end
            ticker.Cancel = function(self) self.cancelled = true end
            ticker.IsCancelled = function(self) return self.cancelled end
            ticker.timer = Schedule(delay, Tick)
            return ticker
        end
    end

    --Sirus SharedXML\C_TimerAugment.lua defines colon methods (C_Timer:After(duration, callback)),
    --while retail code calls C_Timer.After(duration, callback) ("attempt to compare number with function").
    --The addon uses its own dot-style DUI_C_Timer so the global (and Blizzard's secure timers) stay untouched.
    --NOTE: Sirus FrameXML\SecureCapsule.lua does take("C_Timer2"), so C_Timer2 is always nil for addons.
    --Detecting the call style through C_Timer2 therefore picked the dot-style branch and every
    --DUI_C_Timer.After() call crashed inside C_TimerAugment.lua:36 and never ran its callback.
    --DUI_C_Timer is now fully self-contained (own OnUpdate driver) and does not touch the Sirus C_Timer at all.
    local T = {}
    do
        local driver = CreateFrame("Frame")
        local queue = {}
        local pending = {}

        local function Cancel(self) self._cancelled = true end
        local function IsCancelled(self) return self._cancelled == true end

        local function OnUpdate(self, elapsed)
            if #pending > 0 then
                for i = 1, #pending do
                    queue[#queue + 1] = pending[i]
                    pending[i] = nil
                end
            end
            local now = GetTime()
            local i = 1
            while i <= #queue do
                local t = queue[i]
                if t._cancelled then
                    table.remove(queue, i)
                elseif now >= t._fireAt then
                    table.remove(queue, i)
                    local ok, err = pcall(t._callback, t)
                    if not ok then geterrorhandler()(err) end
                else
                    i = i + 1
                end
            end
            if #queue == 0 and #pending == 0 then
                self:Hide()
            end
        end
        driver:SetScript("OnUpdate", OnUpdate)
        driver:Hide()

        local function Schedule(t, delay)
            delay = tonumber(delay) or 0
            if delay < 0 then delay = 0 end
            t._fireAt = GetTime() + delay
            pending[#pending + 1] = t
            driver:Show()
            return t
        end

        T.NewTimer = function(delay, callback)
            if type(callback) ~= "function" then return end
            local t = {_callback = callback, Cancel = Cancel, IsCancelled = IsCancelled}
            return Schedule(t, delay)
        end

        T.After = function(delay, callback)
            T.NewTimer(delay, callback)
        end

        T.NewTicker = function(delay, callback, iterations)
            if type(callback) ~= "function" then return end
            local ticker = {Cancel = Cancel, IsCancelled = IsCancelled, _count = 0}
            ticker._callback = function(self)
                self._count = self._count + 1
                callback(self)
                if (not self._cancelled) and ((not iterations) or self._count < iterations) then
                    Schedule(self, delay)
                end
            end
            return Schedule(ticker, delay)
        end
    end
    DUI_C_Timer = T
end


-- ---------------------------------------------------------------------------
-- C_GossipInfo over the 3.3.5 gossip API
-- In 3.3.5 options and quests have no IDs: the list index is used as ID.
-- ---------------------------------------------------------------------------
do
    local G = C_GossipInfo

    local function Collect(stride, ...)
        local out = {}
        local n = select("#", ...)
        for i = 1, n, stride do
            out[#out + 1] = {select(i, ...)}
        end
        return out
    end

    local function B(v) return v == true or v == 1 end

    local function Set(name, func)
        if rawget(G, name) == nil then G[name] = func end
    end

    Set("GetText", function() return GetGossipText() end)
    Set("GetNumOptions", function() return GetNumGossipOptions() end)
    Set("GetNumAvailableQuests", function() return GetNumGossipAvailableQuests() end)
    Set("GetNumActiveQuests", function() return GetNumGossipActiveQuests() end)

    -- Retail code compares option icons with file IDs (132053 = chat bubble: sort order, auto-select) and
    -- GossipDataProvider maps these IDs to the addon's own icons; 3.3.5a only gives the gossip type.
    local GOSSIP_TYPE_FILEID = {gossip = 132053, trainer = 132058, vendor = 132060, banker = 132050, binder = 132052}

    Set("GetOptions", function()
        local options = {}
        for i, v in ipairs(Collect(2, GetGossipOptions())) do
            local gossipType = v[2] or "gossip"
            options[i] = {
                name = v[1],
                icon = GOSSIP_TYPE_FILEID[gossipType] or ("Interface\\GossipFrame\\"..gossipType.."GossipIcon"),
                type = gossipType,
                gossipOptionID = i,
                orderIndex = i,
                status = 0,
                flags = 0,
                rewards = {},
                selectOptionWhenOnlyOption = gossipType ~= "gossip",
            }
        end
        return options
    end)

    Set("GetAvailableQuests", function()
        local quests = {}
        for i, v in ipairs(Collect(5, GetGossipAvailableQuests())) do
            local isDaily, isRepeatable = B(v[4]), B(v[5])
            quests[i] = {
                title = v[1],
                questLevel = tonumber(v[2]) or 0,
                isTrivial = B(v[3]),
                frequency = isDaily and Enum.QuestFrequency.Daily or Enum.QuestFrequency.Default,
                repeatable = isRepeatable,
                isComplete = false,
                isLegendary = false,
                isIgnored = false,
                isImportant = false,
                isMeta = false,
                questID = i,
            }
        end
        return quests
    end)

    Set("GetActiveQuests", function()
        local quests = {}
        for i, v in ipairs(Collect(4, GetGossipActiveQuests())) do
            quests[i] = {
                title = v[1],
                questLevel = tonumber(v[2]) or 0,
                isTrivial = B(v[3]),
                isComplete = B(v[4]),
                frequency = Enum.QuestFrequency.Default,
                repeatable = false,
                isLegendary = false,
                isIgnored = false,
                isImportant = false,
                isMeta = false,
                questID = i,
            }
        end
        return quests
    end)

    Set("SelectOption", function(optionID) SelectGossipOption(optionID) end)
    Set("SelectOptionByIndex", function(index) SelectGossipOption(index) end)
    Set("SelectAvailableQuest", function(questID) SelectGossipAvailableQuest(questID) end)
    Set("SelectActiveQuest", function(questID) SelectGossipActiveQuest(questID) end)
    Set("CloseGossip", function() CloseGossip() end)
    Set("ForceGossip", function() return ForceGossip and ForceGossip() or false end)
    Set("GetFriendshipReputation", function() return {friendshipFactionID = 0} end)
    Set("GetFriendshipReputationRanks", function() return {currentLevel = 0, maxLevel = 0} end)
end


-- ---------------------------------------------------------------------------
-- C_QuestLog over the 3.3.5 quest log API
-- ---------------------------------------------------------------------------
do
    local Q = C_QuestLog
    local function Set(name, func)
        if rawget(Q, name) == nil then Q[name] = func end
    end

    local function LogIndex(questID)
        if not questID then return end
        if GetQuestLogIndexByID then
            local index = GetQuestLogIndexByID(questID)
            if index and index > 0 then return index end
            return
        end
        for i = 1, (GetNumQuestLogEntries()) do
            if select(9, GetQuestLogTitle(i)) == questID then
                return i
            end
        end
    end

    Set("GetLogIndexForQuestID", LogIndex)
    Set("GetNumQuestLogEntries", function() return GetNumQuestLogEntries() end)
    Set("GetQuestIDForLogIndex", function(index) return select(9, GetQuestLogTitle(index)) end)

    Set("GetInfo", function(index)
        local title, level, questTag, suggestedGroup, isHeader, isCollapsed, isComplete, isDaily, questID = GetQuestLogTitle(index)
        if not title then return end
        return {
            title = title,
            level = level,
            difficultyLevel = level,
            suggestedGroup = tonumber(suggestedGroup) or 0,
            isHeader = isHeader and true or false,
            isCollapsed = isCollapsed and true or false,
            isComplete = isComplete == 1,
            isFailed = isComplete == -1,
            frequency = isDaily and Enum.QuestFrequency.Daily or Enum.QuestFrequency.Default,
            questID = questID,
            questLogIndex = index,
            questTag = questTag,
            isOnMap = false,
            isHidden = false,
            isTask = false,
            isBounty = false,
            isStory = false,
            isScaling = false,
            hasLocalPOI = false,
            startEvent = false,
            overridesSortOrder = false,
        }
    end)

    Set("IsOnQuest", function(questID) return LogIndex(questID) ~= nil end)
    Set("IsComplete", function(questID)
        local index = LogIndex(questID)
        return index and select(7, GetQuestLogTitle(index)) == 1 or false
    end)
    Set("ReadyForTurnIn", function(questID) return Q.IsComplete(questID) end)
    Set("IsFailed", function(questID)
        local index = LogIndex(questID)
        return index and select(7, GetQuestLogTitle(index)) == -1 or false
    end)
    Set("GetTitleForQuestID", function(questID)
        local index = LogIndex(questID)
        return index and (GetQuestLogTitle(index)) or nil
    end)
    Set("GetQuestDifficultyLevel", function(questID)
        local index = LogIndex(questID)
        return index and select(2, GetQuestLogTitle(index)) or 0
    end)
    Set("GetSuggestedGroupSize", function(questID)
        local index = LogIndex(questID)
        return index and tonumber(select(4, GetQuestLogTitle(index))) or 0
    end)

    Set("GetQuestObjectives", function(questID)
        local index = LogIndex(questID)
        local objectives = {}
        if index then
            for i = 1, (GetNumQuestLeaderBoards(index) or 0) do
                local text, objectiveType, finished = GetQuestLogLeaderBoard(i, index)
                local fulfilled, required = 0, 0
                if text then
                    local a, b = string.match(text, "(%d+)%s*/%s*(%d+)")
                    fulfilled, required = tonumber(a) or 0, tonumber(b) or 0
                end
                objectives[i] = {
                    text = text,
                    type = objectiveType,
                    finished = finished and true or false,
                    numFulfilled = fulfilled,
                    numRequired = required,
                }
            end
        end
        return objectives
    end)

    Set("GetSelectedQuest", function()
        local index = GetQuestLogSelection()
        return index and index > 0 and select(9, GetQuestLogTitle(index)) or nil
    end)
    Set("SetSelectedQuest", function(questID)
        local index = LogIndex(questID)
        if index then SelectQuestLogEntry(index) end
    end)
    Set("GetRequiredMoney", function(questID)
        local index = LogIndex(questID)
        if not index then return 0 end
        local old = GetQuestLogSelection()
        SelectQuestLogEntry(index)
        local money = GetQuestLogRequiredMoney() or 0
        if old then SelectQuestLogEntry(old) end
        return money
    end)
    Set("AddQuestWatch", function(questID)
        local index = LogIndex(questID)
        if index then AddQuestWatch(index) end
    end)
    Set("RemoveQuestWatch", function(questID)
        local index = LogIndex(questID)
        if index then RemoveQuestWatch(index) end
    end)
    Set("GetNumQuestWatches", function() return GetNumQuestWatches() end)
    Set("GetMaxNumQuestsCanAccept", function() return MAX_QUESTLOG_QUESTS or 25 end)
    Set("GetMaxNumQuests", function() return MAX_QUESTLOG_QUESTS or 25 end)

    local function False() return false end
    for _, name in ipairs({
        "IsQuestFlaggedCompleted", "IsWorldQuest", "IsQuestTask", "IsThreatQuest", "IsLegendaryQuest",
        "IsImportantQuest", "IsQuestCalling", "IsRepeatableQuest", "IsQuestTrivial", "IsAccountQuest",
        "IsMetaQuest", "IsQuestReplayable", "IsQuestReplayedRecently", "IsQuestBounty", "IsQuestInvasion",
        "IsCampaignQuest", "IsQuestDisabledForSession", "IsQuestFlaggedCompletedOnAccount", "QuestHasWarModeBonus",
        "IsPushableQuest", "IsQuestRepeatableType",
    }) do
        Set(name, False)
    end

    Set("GetQuestTagInfo", noop)
    Set("GetQuestType", noop)
    Set("RequestLoadQuestByID", noop)
    Set("GetQuestsOnMap", function() return {} end)
    Set("GetQuestRewardCurrencies", function() return {} end)
end


-- C_Item fallbacks
do
    local I = C_Item
    local function Set(name, func)
        if rawget(I, name) == nil then I[name] = func end
    end
    Set("GetItemInfo", GetItemInfo)
    Set("GetItemInfoInstant", function(item)
        local name, link, quality, level, minLevel, itemType, subType, stack, equipLoc, icon = GetItemInfo(item)
        local itemID = type(item) == "number" and item or (link and tonumber(string.match(link, "item:(%d+)")))
        return itemID, itemType, subType, equipLoc, icon
    end)
    Set("GetItemIconByID", function(item) return select(10, GetItemInfo(item)) end)
    Set("GetItemNameByID", function(item) return (GetItemInfo(item)) end)
    Set("GetItemQualityByID", function(item) return select(3, GetItemInfo(item)) end)
    Set("GetItemCount", GetItemCount)
    Set("IsEquippableItem", IsEquippableItem)
    Set("GetItemSpell", GetItemSpell)
    Set("IsItemDataCachedByID", function(item) return GetItemInfo(item) ~= nil end)
    Set("RequestLoadItemDataByID", noop)
    Set("DoesItemExistByID", function() return true end)
end


-- C_Container fallbacks
do
    local C = C_Container
    local function Set(name, func)
        if rawget(C, name) == nil then C[name] = func end
    end
    Set("GetContainerNumSlots", GetContainerNumSlots)
    Set("GetContainerItemID", GetContainerItemID)
    Set("GetContainerItemLink", GetContainerItemLink)
    Set("GetContainerItemInfo", function(bag, slot)
        local icon, count, locked, quality, readable, lootable, link = GetContainerItemInfo(bag, slot)
        if not icon then return end
        return {
            iconFileID = icon, stackCount = count, isLocked = locked, quality = quality,
            isReadable = readable, hasLoot = lootable, hyperlink = link,
            itemID = link and tonumber(string.match(link, "item:(%d+)")),
        }
    end)
    Set("UseContainerItem", UseContainerItem)
end


-- C_Spell fallbacks
do
    local S = C_Spell
    if rawget(S, "GetSpellInfo") == nil then
        S.GetSpellInfo = function(spell)
            local name, rank, icon, cost, isFunnel, powerType, castTime, minRange, maxRange = GetSpellInfo(spell)
            if not name then return end
            return {name = name, iconID = icon, castTime = castTime, minRange = minRange, maxRange = maxRange, spellID = type(spell) == "number" and spell or nil}
        end
    end
    if rawget(S, "GetSpellName") == nil then S.GetSpellName = function(spell) return (GetSpellInfo(spell)) end end
    if rawget(S, "GetSpellTexture") == nil then S.GetSpellTexture = function(spell) return select(3, GetSpellInfo(spell)) end end
end


-- C_Map / C_CurrencyInfo minimal fallbacks
do
    local M = C_Map
    if rawget(M, "GetBestMapForUnit") == nil then M.GetBestMapForUnit = function() return GetCurrentMapAreaID and GetCurrentMapAreaID() or 0 end end
    if rawget(M, "GetMapInfo") == nil then M.GetMapInfo = function(mapID) return {mapID = mapID, name = GetZoneText(), mapType = 3} end end

    local CI = C_CurrencyInfo
    if rawget(CI, "GetCurrencyInfo") == nil then
        CI.GetCurrencyInfo = function(currencyID)
            if GetCurrencyInfo then
                local name, amount, icon = GetCurrencyInfo(currencyID)
                if name then return {name = name, quantity = amount or 0, iconFileID = icon} end
            end
        end
    end
    if rawget(CI, "GetCurrencyLink") == nil then CI.GetCurrencyLink = function() return nil end end
end


-- Text to speech does not exist in 3.3.5
do
    local T = C_VoiceChat
    if rawget(T, "GetTtsVoices") == nil then T.GetTtsVoices = function() return {} end end
    if rawget(T, "GetRemoteTtsVoices") == nil then T.GetRemoteTtsVoices = function() return {} end end
    if rawget(T, "SpeakText") == nil then T.SpeakText = noop end
    if rawget(T, "StopSpeakingText") == nil then T.StopSpeakingText = noop end
    addon.TTS_UNAVAILABLE = true
end


-- Tooltip data API does not exist; return nil so callers use the legacy path
do
    local TI = C_TooltipInfo
    TI.__dui335 = true
end
