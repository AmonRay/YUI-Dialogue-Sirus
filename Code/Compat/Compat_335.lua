-- DialogueUI: compatibility layer for WoW 3.3.5a (Sirus interface patch)
-- Loaded first. Provides retail APIs used by the addon on top of 3.3.5 functions,
-- safe stubs for systems that do not exist in 3.3.5 and helpers used by converted XML.

local addonName, addon = ...
local _G = _G
local type, select, pairs, ipairs, tonumber, tostring = type, select, pairs, ipairs, tonumber, tostring
local function noop() end

addon.IS_335 = true


-- ---------------------------------------------------------------------------
-- Project constants (Initialization.lua compares WOW_PROJECT_ID with these)
-- ---------------------------------------------------------------------------
WOW_PROJECT_MAINLINE = WOW_PROJECT_MAINLINE or 1
WOW_PROJECT_CLASSIC = WOW_PROJECT_CLASSIC or 2
WOW_PROJECT_BURNING_CRUSADE_CLASSIC = WOW_PROJECT_BURNING_CRUSADE_CLASSIC or 5
WOW_PROJECT_WRATH_CLASSIC = WOW_PROJECT_WRATH_CLASSIC or 11
WOW_PROJECT_CATACLYSM_CLASSIC = WOW_PROJECT_CATACLYSM_CLASSIC or 14
WOW_PROJECT_MISTS_CLASSIC = WOW_PROJECT_MISTS_CLASSIC or 19
WOW_PROJECT_CAMELOT = WOW_PROJECT_CAMELOT or 1001
WOW_PROJECT_ID = WOW_PROJECT_ID or WOW_PROJECT_WRATH_CLASSIC


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

if not GetTimePreciseSec then
    function GetTimePreciseSec()
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
    function GetMaxPlayerLevel() return MAX_PLAYER_LEVEL or 80 end
end

if not GetMaxLevelForPlayerExpansion then
    function GetMaxLevelForPlayerExpansion() return GetMaxPlayerLevel() end
end

if not UnitHasVehiclePlayerFrameUI then
    function UnitHasVehiclePlayerFrameUI(unit)
        return UnitHasVehicleUI and UnitHasVehicleUI(unit) or false
    end
end

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
    function GetQuestID() return 0 end
end

-- Enum: unknown enum groups resolve to empty tables so lookups return nil
Enum = Enum or {}
if not getmetatable(Enum) then
    setmetatable(Enum, {__index = function(t, k)
        local v = {}
        rawset(t, k, v)
        return v
    end})
end
Enum.QuestFrequency = Enum.QuestFrequency or {}
Enum.QuestFrequency.Default = Enum.QuestFrequency.Default or 0
Enum.QuestFrequency.Daily = Enum.QuestFrequency.Daily or 1
Enum.QuestFrequency.Weekly = Enum.QuestFrequency.Weekly or 2


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
    }

    local frameIndex = Index(frame)
    for k, v in pairs(Region) do Add(frameIndex, k, v) end
    for _, widget in ipairs({"Button", "CheckButton", "EditBox", "ScrollFrame", "Slider", "StatusBar", "Cooldown", "Model", "PlayerModel", "MessageFrame", "ScrollingMessageFrame", "SimpleHTML", "GameTooltip", "ColorSelect"}) do
        local ok, obj = pcall(CreateFrame, widget, nil, nil, widget == "GameTooltip" and "GameTooltipTemplate" or nil)
        if ok and obj then
            local index = Index(obj)
            for k, v in pairs(Region) do Add(index, k, v) end
            obj:Hide()
        end
    end

    local textureIndex = Index(texture)
    for k, v in pairs(Region) do Add(textureIndex, k, v) end
    Add(textureIndex, "SetColorTexture", function(self, r, g, b, a) self:SetTexture(r, g, b, a) end)
    Add(textureIndex, "AddMaskTexture", noop)
    Add(textureIndex, "RemoveMaskTexture", noop)
    Add(textureIndex, "GetNumMaskTextures", function() return 0 end)
    Add(textureIndex, "SetMask", noop)
    Add(textureIndex, "SetTextureSliceMargins", noop)
    Add(textureIndex, "SetTextureSliceMode", noop)
    Add(textureIndex, "ClearTextureSlice", noop)
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
    Add(fsIndex, "SetFormattedText", function(self, fmt, ...) self:SetText(string.format(fmt, ...)) end)

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
local function Namespace(name)
    local ns = _G[name]
    if type(ns) ~= "table" then
        ns = {}
        _G[name] = ns
    end
    if not getmetatable(ns) then
        setmetatable(ns, {__index = function() return noop end})
    end
    return ns
end
addon.CompatNamespace = Namespace

for _, name in ipairs({
    "C_AddOns", "C_AdventureMap", "C_ArtifactUI", "C_CVar", "C_CampaignInfo", "C_Container", "C_CurrencyInfo",
    "C_GossipInfo", "C_Item", "C_Map", "C_MajorFactions", "C_QuestInfoSystem", "C_QuestLine", "C_QuestLog",
    "C_QuestOffer", "C_Reputation", "C_Spell", "C_SuperTrack", "C_TaskQuest", "C_TooltipInfo", "C_TTSSettings",
    "C_VoiceChat", "C_Timer", "C_PlayerInfo", "C_UnitAuras", "C_QuestItemUse", "C_PlayerInteractionManager",
    "C_ClassColor", "C_Texture", "C_Covenants", "C_Garrison", "C_TransmogCollection", "C_MountJournal",
    "C_PetJournal", "C_ToyBox", "C_Heirloom", "C_LFGList", "C_QuestSession", "C_ContentTracking", "C_GameRules",
    "C_Seasons", "C_DateAndTime", "C_ScenarioInfo", "C_SpellBook", "C_AzeriteEmpoweredItem", "C_ItemUpgrade",
    "C_NamePlate", "C_Minimap", "C_EncodingUtil", "C_Navigation", "C_Housing", "C_StringUtil", "C_Bank",
}) do
    Namespace(name)
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
    if rawget(C_CVar, "GetCVar") == nil then C_CVar.GetCVar = GetCVar end
    if rawget(C_CVar, "SetCVar") == nil then C_CVar.SetCVar = function(k, v) return SetCVar(k, v) end end
    if rawget(C_CVar, "GetCVarBool") == nil then C_CVar.GetCVarBool = function(k) return GetCVarBool and GetCVarBool(k) or GetCVar(k) == "1" end end
    if rawget(C_CVar, "GetCVarDefault") == nil then C_CVar.GetCVarDefault = GetCVarDefault or noop end

    local C_Timer = C_Timer
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

    Set("GetOptions", function()
        local options = {}
        for i, v in ipairs(Collect(2, GetGossipOptions())) do
            local gossipType = v[2] or "gossip"
            options[i] = {
                name = v[1],
                icon = "Interface\\GossipFrame\\"..gossipType.."GossipIcon",
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
