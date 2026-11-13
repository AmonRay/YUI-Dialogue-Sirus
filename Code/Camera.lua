setfenv(1, select(2, ...).Env or _G) -- DUI335_ENV
local _, addon = ...
local API = addon.API;
local CallbackRegistry = addon.CallbackRegistry;

local CameraUtil = CreateFrame("Frame");
addon.CameraUtil = CameraUtil;
addon.SetCameraController(CameraUtil);

-- User Settings
local HIDE_UI = false;
local HIDE_UNIT_NAMES = false;
local CHANGE_FOV = false;
local DISABLE_IN_INSTANCE = false;
local FOV_DEFAULT = 90;
local FOV_ZOOMED_IN = 75;
local FOCUS_STRENGTH_PITCH = 1.0;
local FOCUS_SHOULDER_OFFSET_DEFAULT = 1.5;
local FOCUS_SHOULDER_OFFSET = FOCUS_SHOULDER_OFFSET_DEFAULT;
local MOUNTED_CAMERA_ENABLED = true;
local MOUNTED_CAMERA_MULTIPLIER = 4.8;  --1.85 (Netherwing)     1.25(Renewed Proto)   (update 5.725)
local HIDE_SPARKLES = false;
local ZOOM_MUTIPLIER = 1.0;
------------------
local PAN_MULTIPLIER = 1.0;
local PLAYER_IS_SHAPESHIFTER = false;
local NO_CHANGE_FLAG = 255;

local DeltaLerp = API.DeltaLerp;
local Esaing_OutSine = addon.EasingFunctions.outSine;
local IsPlayingCutscene = API.IsPlayingCutscene;

local SetCVar = C_CVar.SetCVar;     --not boolean
local GetCVar = C_CVar.GetCVar;
local IsInteractingWithNpcOfType = C_PlayerInteractionManager.IsInteractingWithNpcOfType;
local GetCameraZoom = GetCameraZoom;
local CameraZoomIn = CameraZoomIn;
local CameraZoomOut = CameraZoomOut;
local ConsoleExec = ConsoleExec;
local SetGameUIShown = SetUIVisibility;
local InCombatLockdown = InCombatLockdown;
local IsMounted = IsMounted;
local IsInInstance = IsInInstance;


local UIParent = UIParent;
UIParent:UnregisterEvent("EXPERIMENTAL_CVAR_CONFIRMATION_NEEDED");  --Disable EXPERIMENTAL_CVAR_WARNING

local FadeHelper = CreateFrame("Frame");
addon.UIParentFadeHelper = FadeHelper;

if addon.IS_335 then
    --3.3.5a (Sirus): SetUIVisibility only toggles the UI drawn in the world (names, health bars), it does not hide UIParent.
    --The game's own Alt+Z (FrameXML Bindings.xml, TOGGLEUI) hides UIParent first, so do the same here. Before this the
    --fade-out ended with UIParent:SetAlpha(1) while UIParent stayed shown, so the whole interface popped back.
    local SetUIVisibility = SetUIVisibility;
    SetGameUIShown = function(state)
        if state then
            UIParent:Show();
        else
            UIParent:Hide();
        end
        if SetUIVisibility then
            SetUIVisibility(state and true or false);
        end
    end
end

CameraUtil.isMidnight = addon.IS_MODERN;

local IsDynamicFlying; -- Avoid changing FOV when mounted to prevent FOV stuck at over normal max due to Skyriding Speed Effects

if CameraUtil.isMidnight then
    SetGameUIShown = function(state)
        UIParent:SetShown(state);
        --[[
        if state then
            UIParent:SetAlpha(1);
            Minimap:Show();
        else
            UIParent:SetAlpha(0);
            Minimap:Hide();
        end
        --]]
    end

    IsDynamicFlying = function()
        if IsMounted() then
            return true
        end

        local isGliding, canGlide = C_PlayerInfo.GetGlidingInfo();
        if isGliding or canGlide then
            return true
        end

        return false
    end
else
    IsDynamicFlying = function()
        return false
    end
end


local OFFSET_INFO = {};

local CVar_TargetFocus = {  --Can be used in combat
    test_cameraTargetFocusInteractEnable = 1,
    test_cameraTargetFocusInteractStrengthPitch = 0,
    test_cameraTargetFocusInteractStrengthYaw = 0,
    test_cameraOverShoulder = FOCUS_SHOULDER_OFFSET,
    test_cameraHeadMovementStrength = 0,
    CameraKeepCharacterCentered = 0,        --11.0.2 Fix
    CameraReduceUnexpectedMovement = 0,     --11.0.2 Fix
};

local CVar_UnitText = {     --Shouldn't be used in combat
    UnitNameOwn = 0,
	UnitNameNonCombatCreatureName = 0,
	UnitNameFriendlyPlayerName = 0,
	UnitNameFriendlyPetName = 0,
	UnitNameFriendlyMinionName = 0,
	UnitNameFriendlyGuardianName = 0,
	UnitNameFriendlySpecialNPCName = 0,
	UnitNameEnemyPlayerName = 0,
	UnitNameEnemyPetName = 0,
	UnitNameEnemyGuardianName = 0,
	UnitNameNPC = 0,
	UnitNameInteractiveNPC = 0,
	UnitNameHostleNPC = 0,
};

local CVar_Backup = {};

local function BackupAndSetCVar(cvar, value)
    if CVar_Backup[cvar] == nil then
        CVar_Backup[cvar] = GetCVar(cvar);
    end
    if (value ~= nil) and (value ~= NO_CHANGE_FLAG) then
        SetCVar(cvar, value);
    end
end

function CameraUtil:SetDefaultCameraMode(mode)
    --0: No Zoom
    --1: Zoom to NPC
    --2: Shift camear horizontally
    self.defaultCameraMode = mode;
    CallbackRegistry:Trigger("Camera.ModeChanged", mode);   --Core.lua: Affects event process delay
end
CameraUtil.defaultCameraMode = 0;


function CameraUtil:ChangeCVars()
    if self.cvarStored then return end;
    self.cvarStored = true;

    if self.cameraMode == 1 then
        --ConsoleExec("actioncam on");
        for cvar, value in pairs(CVar_TargetFocus) do
            BackupAndSetCVar(cvar, value);
        end
    elseif self.cameraMode == 2 then
        BackupAndSetCVar("test_cameraOverShoulder", nil);
        BackupAndSetCVar("CameraKeepCharacterCentered", 0);
        BackupAndSetCVar("CameraReduceUnexpectedMovement", 0);
    end

    if (not InCombatLockdown()) and (HIDE_UNIT_NAMES and HIDE_UI) then
        for cvar, value in pairs(CVar_UnitText) do
            BackupAndSetCVar(cvar, value);
        end
    end

    if CHANGE_FOV and not IsDynamicFlying() then
        FOV_DEFAULT = GetCVar("cameraFov") or 90;
        BackupAndSetCVar("cameraFov", nil);
    end

    local outline = (HIDE_UI and HIDE_SPARKLES and 0) or nil;
    BackupAndSetCVar("graphicsOutlineMode", outline);   --This hides the outline immediately. But the sparkle effects when UI is hidden is controlled by "Outline"
    BackupAndSetCVar("Outline", outline);           --This fails to hide the outline when the UI is fading

    self:ListenEvent(true);
end

function CameraUtil:RestoreCVars()
    if self.cvarStored then
        self.cvarStored = nil;

        for cvar, value in pairs(CVar_Backup) do
            SetCVar(cvar, value);
        end

        CVar_Backup = {};

        self:ListenEvent(false);

        return true
    end
end

function CameraUtil:RestoreCombatCVar()
    if self.cvarStored then
        for cvar, value in pairs(CVar_Backup) do
            if CVar_UnitText[cvar] ~= nil then
                SetCVar(cvar, value);
                CVar_Backup[cvar] = nil;
            end
        end
    end
end

function CameraUtil:RestoreCameraFOVIfMounted()
    if IsDynamicFlying() then
        local cvar = "cameraFov";
        if CVar_Backup[cvar] then
            SetCVar(cvar, CVar_UnitText[cvar]);
            CVar_UnitText[cvar] = nil;
        end
    end
end

function CameraUtil:SetHideUnitNames(state)
    --Trigger by clicking checkbox manually
    if state then
        if not InCombatLockdown() then
            self.cvarStored = true;
            for cvar, value in pairs(CVar_UnitText) do
                if CVar_Backup[cvar] == nil then
                    CVar_Backup[cvar] = GetCVar(cvar);
                    SetCVar(cvar, value);
                end
            end
        end
    else
        self:RestoreCombatCVar();
    end
end

function CameraUtil:SetHideOutlineSparkles(state)
    local cvars = {
        "graphicsOutlineMode",
        "Outline",
    };

    if state then
        for _, cvar in pairs(cvars) do
            BackupAndSetCVar(cvar, 0);
        end
    else
        for _, cvar in pairs(cvars) do
            if CVar_Backup[cvar] ~= nil then
                SetCVar(cvar, CVar_Backup[cvar]);
            end
        end
    end
end

function CameraUtil:OnEvent(event, ...)
    if event == "PLAYER_MOUNT_DISPLAY_CHANGED" then
        self:OnMountChanged();
        self:RestoreCameraFOVIfMounted();
    elseif event == "PLAYER_IS_GLIDING_CHANGED" then
        self:RestoreCameraFOVIfMounted();
    elseif event == "UPDATE_SHAPESHIFT_FORM" then
        self:RequestUpdateShapeshiftForm(0.0);
    else    --Logout
        self:RestoreCVars();
    end
end

function CameraUtil:UpdateMounted_Right()
    --UI on the right
    self.isMounted = IsMounted();
    if self.isMounted then
        if MOUNTED_CAMERA_ENABLED then
            self.offsetMultiplier = MOUNTED_CAMERA_MULTIPLIER;
        else
            self.offsetMultiplier = 1.5;
        end
    else
        self.offsetMultiplier = 1;
    end
end

function CameraUtil:UpdateMounted_Left()
    --UI on the left
    self.isMounted = IsMounted();
    if self.isMounted then
        if MOUNTED_CAMERA_ENABLED then
            self.offsetMultiplier = -0.3;
        else
            self.offsetMultiplier = -0.25;
        end
    else
        self.offsetMultiplier = -1;
    end
end

CameraUtil.UpdateMounted = CameraUtil.UpdateMounted_Right;


local function SetCameraOverShoulder(value)
    SetCVar("test_cameraOverShoulder", value);
end

local function GetMountID()
    local GetAuraDataByIndex = C_UnitAuras.GetAuraDataByIndex;
    local GetMountFromSpell = C_MountJournal.GetMountFromSpell;
    local i = 1;
    local mountID, count, duration;
    local spellID = 0;
    local aura;

    while spellID do
        aura = GetAuraDataByIndex("player", i, "HELPFUL");
        spellID = aura and aura.spellId;
        if spellID then
            count = aura.applications;
            duration = aura.duration;
            if count == 0 and duration == 0 then
                mountID = GetMountFromSpell(spellID);
                if mountID then
                    break
                else
                    i = i + 1;
                end
            else
                i = i + 1;
            end
        else
            break
        end
    end

    if mountID then
        --API.EvaluateMountScale(mountID);
        print(mountID)
    end
end

function CameraUtil:MoveCameraToFinalPosition()
    local baseOffset = (self.cameraMode == 1 and FOCUS_SHOULDER_OFFSET) or (self:GetShoulderOffsetForCurrentZoom());
    local offset = self.offsetMultiplier * baseOffset;
    self.shoulderOffset = offset;
    SetCameraOverShoulder(offset);
end

function CameraUtil:ShouldUseOffset()
    return self.isActive and self.cameraMode ~= 0
end

function CameraUtil:OnMountChanged()
    if not self:ShouldUseOffset()then return end;

    local changed;

    if IsMounted() then
        if not self.isMounted then
            self:UpdateMounted();
            changed = true;
            --GetMountID();
        end
    else
        if self.isMounted then
            self:UpdateMounted();
            changed = true;
        end
    end

    if changed then
        self:MoveCameraToFinalPosition();
    end
end

function CameraUtil:OnUIOrientationChanged()
    self:UpdateMounted();

    if self:ShouldUseOffset() then
        self:MoveCameraToFinalPosition();
    end
end


function CameraUtil:ListenEvent(state)
    if state then
        self:RegisterEvent("PLAYER_LOGOUT");
        self:RegisterEvent("PLAYER_QUITING");
        self:RegisterEvent("PLAYER_CAMPING");
        self:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED");
        if PLAYER_IS_SHAPESHIFTER then
            self:RegisterEvent("UPDATE_SHAPESHIFT_FORM");
        end
        if self.isMidnight then
            self:RegisterEvent("PLAYER_IS_GLIDING_CHANGED");
        end
        self:SetScript("OnEvent", self.OnEvent);
    else
        self:UnregisterEvent("PLAYER_LOGOUT");
        self:UnregisterEvent("PLAYER_QUITING");
        self:UnregisterEvent("PLAYER_CAMPING");
        self:UnregisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED");
        if PLAYER_IS_SHAPESHIFTER then
            self:UnregisterEvent("UPDATE_SHAPESHIFT_FORM");
        end
        if self.isMidnight then
            self:UnregisterEvent("PLAYER_IS_GLIDING_CHANGED");
        end
        self:SetScript("OnEvent", nil);
    end
end

local function GetShoulderOffsetByZoom(zoom)
	--return zoom * 0.3283 - 0.02
    return (zoom * 0.4314 + 0.1057) * PAN_MULTIPLIER
end

CameraUtil.offsetMultiplier = 1;

function CameraUtil:GetShoulderOffsetForCurrentZoom()
    return GetShoulderOffsetByZoom(GetCameraZoom())
end

function CameraUtil:ZoomTo(goal, noZoomOut)
    local current = GetCameraZoom();
    self.oldZoom = current;

    local diff = current - goal;

    if noZoomOut and diff < 0 then
        return
    end

    if diff < 0.1 and diff > -0.1 then
        return
    end

    if diff > 0 then
        CameraZoomIn(diff);
    else
        CameraZoomOut(-diff);
    end
end

function CameraUtil:GetBestZoomForNPC()
    --Unused. Zoom is driven by ModelSceneActor:OnModelLoaded()
end

function CameraUtil:OnModelEvaluationComplete(modelHeight)
    -- Used by "DUIUtilityActorMixin" in API.lua to determine zoom-in distance
    -- Unavailable in instance due to Secret in 12.0.5

    if not (self.isActive and self.cameraMode == 1) then return end;

    local zoom;

    if modelHeight < 2 then
        zoom = 2.0
    elseif modelHeight < 2.6 then    --Pandaren, Elf
        zoom = 3.0
    elseif modelHeight < 4 then
        zoom = 4.0
    elseif modelHeight < 5.1 then
        zoom = 5.0
    elseif modelHeight < 6.1 then
        zoom = 6.0
    elseif modelHeight < 8 then
        zoom = 10.0
    else
        zoom = modelHeight + 2.0;
        if zoom > 28.5 then
            zoom = nil;
        end
    end

    self.bestTargetZoom = zoom;

    if zoom then
        zoom = zoom * ZOOM_MUTIPLIER;
        self:ZoomTo(zoom, true);
    end
end

local CAMERA_MOVEMENT_DURATION = 1.0;

local function ZoomIn_Fov_OnUpdate(self, elapsed)
    self.fovChanged = true;

    local fov = Esaing_OutSine(self.t, FOV_DEFAULT,  FOV_ZOOMED_IN, CAMERA_MOVEMENT_DURATION);

    if self.t >= CAMERA_MOVEMENT_DURATION then
        fov = FOV_ZOOMED_IN;
    end

    SetCVar("cameraFov", fov);
end

local function ZoomIn_FocusNPC_OnUpdate(self, elapsed)
    self.t = self.t + elapsed;

    local pitch = Esaing_OutSine(self.t, 88,  15, CAMERA_MOVEMENT_DURATION);
    local targetStrength = Esaing_OutSine(self.t, 0.0, FOCUS_STRENGTH_PITCH, CAMERA_MOVEMENT_DURATION);

    if self.t >= CAMERA_MOVEMENT_DURATION then
        ConsoleExec("pitchlimit "..15);
        pitch = 88;
        targetStrength = FOCUS_STRENGTH_PITCH;
        self:SetScript("OnUpdate", nil);
    end

    if CHANGE_FOV and not self.isDynamicFlying then
        ZoomIn_Fov_OnUpdate(self, elapsed);
    end

    SetCVar("test_cameraTargetFocusInteractStrengthPitch", targetStrength);
    ConsoleExec("pitchlimit "..pitch);
end

local function ZoomIn_PanCamera_OnUpdate(self, elapsed)
    self.t = self.t + elapsed;
    if self.t > 0.03 then
        self.t = 0;
        self.shoulderOffset = DeltaLerp(self.shoulderOffset, self.offsetMultiplier * self:GetShoulderOffsetForCurrentZoom(), self.shoulderBlend, elapsed);
        SetCameraOverShoulder(self.shoulderOffset);
    end
end

function CameraUtil:Intro_None()
    self.cameraMode = 0;
end

function CameraUtil:Intro_FocusNPC()
    --SaveView(5)   --We can't use this to restore pitch because it breaks Camera Following Style

    self.cameraMode = 1;
    self.oldZoom = GetCameraZoom();
    self.t = 0;
    self:SetScript("OnUpdate", ZoomIn_FocusNPC_OnUpdate);

    local success = API.EvaluateNPCSize();
    if not success then
        -- Use fallback value if failed (due to unit identity being secret or other reasons)
        self:OnModelEvaluationComplete(3);
    end
end

function CameraUtil:Intro_PanCamera()
    self.cameraMode = 2;
    self.t = 0;
    self.shoulderOffset = tonumber(GetCVar("test_cameraOverShoulder"));

    local targetOffset = self:GetShoulderOffsetForCurrentZoom();
    local diff = targetOffset - self.shoulderOffset;

    if diff > 8 then
        self.shoulderBlend = 0.06;
    else
        self.shoulderBlend = 0.10;
    end

    self:SetScript("OnUpdate", ZoomIn_PanCamera_OnUpdate);
end

function CameraUtil:Intro_ZoomToObject()
    self.oldZoom = GetCameraZoom();
    self.t = 0;
    self:ZoomTo(3);
end

function CameraUtil:OnInteractionStart()
    --Reserved for DynamicCam
end

function CameraUtil:OnInteractionStop()
    --Reserved for DynamicCam
end

function CameraUtil:InitiateInteraction()
    self.isActive = true;

    self:UpdateMounted();
    self.isDynamicFlying = IsDynamicFlying();

    if PLAYER_IS_SHAPESHIFTER then
        self:UpdateShapeshiftForm();
    end

    self.bestTargetZoom = nil;

    if self.defaultCameraMode == 0 or (DISABLE_IN_INSTANCE and IsInInstance()) then
        self:Intro_None();
    else
        if (self.defaultCameraMode == 1) and API.IsQuestNPCPlayer() then
            self:Intro_FocusNPC();
        else
            self:Intro_PanCamera();
            if self.defaultCameraMode == 1 then
                self:Intro_ZoomToObject();
            end
        end
    end

    self:OnInteractionStart();
    self:ChangeCVars();

    local caller = addon.DialogueUI;
    FadeHelper:FadeOutUI(caller);

    if self.cameraMode == 1 then
        local offset = self.offsetMultiplier * FOCUS_SHOULDER_OFFSET;
        SetCameraOverShoulder(offset);
    end
end

function CameraUtil:Restore()
    self.isActive = false;
    self:SetScript("OnUpdate", nil);
    self:StopUpdatingForm();

    if not self:RestoreCVars() then
        return
    end

    --ConsoleExec("actioncam off");
    ConsoleExec("pitchlimit 88");

    if self.fovChanged then
        self.fovChanged = nil;
    end

    local caller = addon.DialogueUI;
    FadeHelper:FadeInUI(caller);

    if self.oldZoom then
        self:ZoomTo(self.oldZoom);
        self.oldZoom = nil;
    end

    self:OnInteractionStop();
end

function CameraUtil:OnFovSettingsChanged()
    if not (self.isActive and self.cameraMode == 1) then return end;

    local cvar = "cameraFov";
    self.isDynamicFlying = IsDynamicFlying();

    if CHANGE_FOV and not self.isDynamicFlying then
        if not self.fovChanged then
            self.fovChanged = true;
            BackupAndSetCVar(cvar, FOV_ZOOMED_IN);
        end
    else
        if self.fovChanged then
            self.fovChanged = nil;
            if CVar_Backup[cvar] ~= nil then
                SetCVar(cvar, CVar_Backup[cvar]);
                CVar_Backup[cvar] = nil;
            end
        end
    end
end

do  --Calibrator
    function CameraUtil:EnterCalibartorMode()
        self:SetScript("OnUpdate", nil);
    end

    function CameraUtil:ExitCalibartorMode()
        if not self.isActive then return end;
        self:InitiateInteraction();
    end
end


local MovieFrame = MovieFrame;

local function ShouldShowUIParent()
    --Trading Post, Barbershop, MoviewFrame hide UIParent
    return not ((IsPlayingCutscene()) or (IsInteractingWithNpcOfType(57)) )
end

local function ShowUIParent(state)
    if InCombatLockdown() then return end;

    if state then
        if ShouldShowUIParent() then
            SetGameUIShown(true);
        else
            MovieFrame.uiParentShown = true;
        end
        FadeHelper:RestoreAlternatePowerBar();
    else
        FadeHelper:HideUIParentInstantly();
    end
end

function FadeHelper:ShowUIParentInstantly()
    self:SnapToFadeResult();
    ShowUIParent(true);
end
CallbackRegistry:Register("PlayerInteraction.ShowUI", "ShowUIParentInstantly", FadeHelper);  --For Classic

function FadeHelper:HideUIParentInstantly()
    self:SetScript("OnUpdate", nil);
    self.t = 0;
    self.alpha = 0;

    if not InCombatLockdown() then
        self.fadeDelta = -1;
        UIParent:SetAlpha(1);
        SetGameUIShown(false);
        if HIDE_UI and HIDE_SPARKLES then
            self.t = 2;
            self:SetScript("OnUpdate", self.HideSparkles_OnUpdate);
        end
        DUI_C_Timer.After(0, function()
            FadeHelper:RestoreAlternatePowerBar();
        end);
    end
end

function FadeHelper:HideSparkles_OnUpdate(elapsed)
    --The game turns unit outline into sparkles when Alt+Z
    --We have to /console Outline 0 constantly to remove this effect
    --Frequency is affected by FPS

    self.t = self.t + elapsed;
    if self.t >= 1.0 then
        self.t = 0;
        if CameraUtil.cvarStored then   --Avoid changing this CVar during AKF Logout
            SetCVar("Outline", 0);
        end
    end
end


local ALPHA_UPDATE_INTERVAL = 1/30;

function FadeHelper:OnEvent(event, ...)
    if event == "PLAYER_REGEN_DISABLED" or event == "PLAY_MOVIE" or event == "CINEMATIC_START" then
        self:ShowUIParentInstantly();
    end
end
FadeHelper:SetScript("OnEvent", FadeHelper.OnEvent);

function FadeHelper:SnapToFadeResult(inCombat)
    self:SetScript("OnUpdate", nil);
    self.t = 0;
    self.alpha = 1;
    self:UnregisterEvent("PLAYER_REGEN_DISABLED");
    self:UnregisterEvent("PLAY_MOVIE");
    self:UnregisterEvent("CINEMATIC_START");

    if self.fadeDelta then
        UIParent:SetAlpha(1);
        if self.fadeDelta > 0 then
            ShowUIParent(true);
        elseif not inCombat then
            ShowUIParent(false);
        end
        self.fadeDelta = nil;
    end
end

function FadeHelper:FadeIn_OnUpdate(elapsed)
    self.t = self.t + elapsed;
    if self.t >= ALPHA_UPDATE_INTERVAL then
        self.alpha = self.alpha + 4*self.t;
        self.t = self.t - ALPHA_UPDATE_INTERVAL;
        if self.alpha >= 1 then
           self:SnapToFadeResult();
        else
            UIParent:SetAlpha(self.alpha);
        end
    end
end

function FadeHelper:FadeOut_OnUpdate(elapsed)
    self.t = self.t + elapsed;
    if self.t >= ALPHA_UPDATE_INTERVAL then
        self.alpha = self.alpha - 2*self.t;
        self.t = self.t - ALPHA_UPDATE_INTERVAL;
        if self.alpha <= 0 then
           self:SnapToFadeResult();
        else
            UIParent:SetAlpha(self.alpha);
        end
    end
end

function FadeHelper:FadeOutUI(caller)
    if not HIDE_UI then return end;

    self.owner = caller;

    --UI: UIParent
    if self.fadeDelta == -1 or (not UIParent:IsShown()) then
        return
    end
    self.fadeDelta = -1;

    local inCombat = InCombatLockdown();

    if inCombat then
        self:SnapToFadeResult(inCombat);
    else
        self.alpha = UIParent:GetAlpha();
        self.t = 0;
        self:RegisterEvent("PLAYER_REGEN_DISABLED");
        self:RegisterEvent("PLAY_MOVIE");
        self:RegisterEvent("CINEMATIC_START");
        self:SetScript("OnUpdate", self.FadeOut_OnUpdate);
    end
end

function FadeHelper:FadeInUI(caller)
    if caller and caller ~= self.owner then
        return
    end

    if self.fadeDelta == 1 then
        return
    end
    self.fadeDelta = 1;

    local inCombat = InCombatLockdown();

    if inCombat or UIParent:IsVisible() then
        self:SnapToFadeResult(inCombat);
    else
        self.alpha = UIParent:GetAlpha();
        if self.alpha >= 0.999 then
            self.alpha = 0;
        end
        self.t = 0;
        UIParent:SetAlpha(self.alpha);
        ShowUIParent(true);
        self:RegisterEvent("PLAYER_REGEN_DISABLED");
        self:RegisterEvent("PLAY_MOVIE");
        self:RegisterEvent("CINEMATIC_START");
        self:SetScript("OnUpdate", self.FadeIn_OnUpdate);
    end
end

function FadeHelper:SetOwner(owner)
    self.owner = owner;
end

function FadeHelper:RestoreAlternatePowerBar()
    --Due to SecureFrame, SetUIVisibility in a timer causes the AlternatePowerBar to disappear

    local f = AlternatePowerBar;
    local hasVehicleUI = UnitHasVehiclePlayerFrameUI and UnitHasVehiclePlayerFrameUI("player")

    if InCombatLockdown() or (not f) or f:IsShown() or API.DoesValueExist(hasVehicleUI) then
        return
    end

    if f.isEnabled then
        f:Show();
    end
end


function CameraUtil:OnEnterCombatDuringInteraction()
    self:RestoreCombatCVar()
    if ShouldShowUIParent() then
        ShowUIParent(true);
    end
end


do
    local function Settings_CameraMovement(dbValue)
        CameraUtil:SetDefaultCameraMode(dbValue)
    end
    CallbackRegistry:Register("SettingChanged.CameraMovement", Settings_CameraMovement);

    local function Settings_CameraChangeFov(dbValue)
        CHANGE_FOV = dbValue == true;
        CameraUtil:OnFovSettingsChanged()
    end
    CallbackRegistry:Register("SettingChanged.CameraChangeFov", Settings_CameraChangeFov);

    local function Settings_CameraMovementMountedCamera(dbValue)
        MOUNTED_CAMERA_ENABLED = dbValue == true;
    end
    CallbackRegistry:Register("SettingChanged.CameraMovementMountedCamera", Settings_CameraMovementMountedCamera);

    local function Settings_HideUI(dbValue, userInput)
        HIDE_UI = dbValue == true;
        if userInput and CameraUtil.isActive then
            if HIDE_UI then
                FadeHelper:HideUIParentInstantly();
                CameraUtil:SetHideUnitNames(HIDE_UNIT_NAMES);
                if addon.DialogueUI:IsShown() then
                    FadeHelper.owner = addon.DialogueUI;
                elseif addon.BookUI:IsShown() then
                    FadeHelper.owner = addon.BookUI;
                end
            else
                FadeHelper:ShowUIParentInstantly();
                CameraUtil:SetHideUnitNames(false);
            end
        end
    end
    CallbackRegistry:Register("SettingChanged.HideUI", Settings_HideUI);

    local function Settings_HideUnitNames(dbValue, userInput)
        HIDE_UNIT_NAMES = dbValue == true;
        if userInput and CameraUtil.isActive then
            CameraUtil:SetHideUnitNames(HIDE_UNIT_NAMES);
        end
    end
    CallbackRegistry:Register("SettingChanged.HideUnitNames", Settings_HideUnitNames);

    local function Settings_CameraMovementDisableInstance(dbValue)
        DISABLE_IN_INSTANCE = dbValue == true;
    end
    CallbackRegistry:Register("SettingChanged.CameraMovementDisableInstance", Settings_CameraMovementDisableInstance);

    local function Settings_FrameOrientation(dbValue)
        if dbValue == 1 then
            CameraUtil.UpdateMounted = CameraUtil.UpdateMounted_Left;
        else
            CameraUtil.UpdateMounted = CameraUtil.UpdateMounted_Right;
        end
        CameraUtil:OnUIOrientationChanged();
    end
    CallbackRegistry:Register("SettingChanged.FrameOrientation", Settings_FrameOrientation);

    local function Settings_HideOutlineSparkles(dbValue, userInput)
        HIDE_SPARKLES = (dbValue == true) and addon.IS_RETAIL;  --Forever has no NPC outline for now
        if userInput and CameraUtil.isActive then
            Settings_HideUI(HIDE_UI, userInput);
            if HIDE_UI then
                if not HIDE_SPARKLES then
                    CameraUtil:SetHideOutlineSparkles(HIDE_SPARKLES);
                end
            end
        end
    end
    CallbackRegistry:Register("SettingChanged.HideOutlineSparkles", Settings_HideOutlineSparkles);

    local ZoomMultiplierValues = {
        [1] = 1.0,
        [2] = 1.5,
        [3] = 2.0,
        [4] = 2.5,
        [5] = 3.0,
    };
    local function Settings_CameraZoomMultiplier(dbValue, userInput)
        ZOOM_MUTIPLIER = ZoomMultiplierValues[dbValue] or 1.0;
        if userInput and CameraUtil.isActive and CameraUtil.bestTargetZoom then
            local oldZoom = CameraUtil.oldZoom;
            local zoom = CameraUtil.bestTargetZoom * ZOOM_MUTIPLIER;
            CameraUtil:ZoomTo(zoom);
            CameraUtil.oldZoom = oldZoom;
        end
    end
    addon.CallbackRegistry:Register("SettingChanged.CameraZoomMultiplier", Settings_CameraZoomMultiplier);
end


do  --DynamicCam
    -- Note: Currently it's impossible to let DynamicCam's NPC Interaction situation (situationID = "300") to take over the camera movement.
    -- Because DynamicCam tracks the visibility of QuestFrame and GossipFrame, and DUI nullifies these two frames.

    local function CheckRequiredMethods()
        if not (C_AddOns.IsAddOnLoaded("DynamicCam") and DynamicCam) then return end;

        local dc = DynamicCam;

        local methods = {
            "BlockShoulderOffsetZoom",      --We handle the camera motion during NPC interaction
            "AllowShoulderOffsetZoom",
            "ApplySettings",
        };

        for _, v in ipairs(methods) do
            if not dc[v] then
                return false
            end
        end


        local function ReApplySettings(oldShoulderOffset)
            local self = dc;

            local curSituation = self.db.profile.situations[self.currentSituationID]

            self.virtualCameraZoom = nil
            self.easeShoulderOffsetInProgress = false;

            for cvar, value in pairs(self.db.profile.standardSettings.cvars) do
                if CVar_TargetFocus[cvar] then
                    if curSituation and curSituation.situationSettings.cvars[cvar] then
                        value = curSituation.situationSettings.cvars[cvar]
                    end

                    if cvar == "test_cameraOverShoulder" then
                        SetCVar(cvar, oldShoulderOffset or value);
                    else
                        self:DC_SetCVar(cvar, value);
                    end
                end
            end
        end

        function CameraUtil:OnInteractionStart()
            dc:BlockShoulderOffsetZoom();
            self.oldShoulderOffset = GetCVar("test_cameraOverShoulder");
        end

        function CameraUtil:OnInteractionStop()
            dc:AllowShoulderOffsetZoom();
            ReApplySettings(self.oldShoulderOffset);
        end

        return true
    end

    CallbackRegistry:Register("PLAYER_ENTERING_WORLD", CheckRequiredMethods);
end


do  --Update Parameters Based On Player Form
    local _, _, playerClassID = UnitClass("player");
    if playerClassID == 11 then
        PLAYER_IS_SHAPESHIFTER = true;
    end

    OFFSET_INFO = {
        DruidForm_1 = 1.0,          --Cat
        DruidForm_2 = 1.0,          --Tree of Life  (untested)
        DruidForm_3 = 1.1,          --Travel (Run)
        DruidForm_4 = 0.9,          --Swim
        DruidForm_5 = 0.9,          --Bear
        DruidForm_27 = 0.55,        --Fly Swift
        DruidForm_29 = 0.55,        --Fly
        DruidForm_31 = 1.0          --Moonkin
    };

    local function Updator_OnUpdate(self, elapsed)
        self.t = self.t + elapsed;
        if self.t > 0 then
            self.t = 0;
            self:SetScript("OnUpdate", nil);
            if CameraUtil.isActive then
                CameraUtil:UpdateShapeshiftForm(true);
            end
        end
    end

    function CameraUtil:UpdateShapeshiftForm(setToFinalValue)
        local newOffset;

        if PLAYER_IS_SHAPESHIFTER then
            local formID = API.GetShapeshiftFormID();
            if formID then
                if formID == 31 then
                    local glyphID = API.GetGlyphIDForSpell(24858);		--Moonkin form with Glyph of Stars use regular configuration
                    if glyphID and glyphID == 114301 then
                        formID = 0;
                    end
                end

                local key = "DruidForm_"..formID;
                newOffset = OFFSET_INFO[key];
                if newOffset then
                    PAN_MULTIPLIER = newOffset / FOCUS_SHOULDER_OFFSET_DEFAULT;
                end
            end
        end

        if not newOffset then
            newOffset = FOCUS_SHOULDER_OFFSET_DEFAULT;
            PAN_MULTIPLIER = 1.0;
        end

        if newOffset ~= FOCUS_SHOULDER_OFFSET then
            FOCUS_SHOULDER_OFFSET = newOffset;
            if setToFinalValue and self:ShouldUseOffset() then
                CameraUtil:MoveCameraToFinalPosition();
            end
        end
    end

    function CameraUtil:StopUpdatingForm()
        if self.updator then
            self.updator.t = 0;
            self.updator:SetScript("OnUpdate", nil);
        end
    end

    function CameraUtil:RequestUpdateShapeshiftForm(delay)
        if not self.updator then
            self.updator = CreateFrame("Frame", nil, self);
        end

        delay = (delay and -delay) or 0;
        self.updator.t = delay;
        self.updator:SetScript("OnUpdate", Updator_OnUpdate);
    end
end


do  -- For 12.1.0: Disable EXPERIMENTAL_CVAR_CONFIRMATION_NEEDED due to changes.
    if GameEvent and GameEvent.UnregisterInternalEvent then
        GameEvent.UnregisterInternalEvent("EXPERIMENTAL_CVAR_CONFIRMATION_NEEDED");
    end
end


do  -- For 12.1.0: Disable "CloseAllWindows()" for "UI.TopLevelParentShown" (See Interface/AddOns/Blizzard_Game/Shared/Game.lua)
    -- Otherwise UIs like MerchantFrame will not appear if they are opened while the UIParent is hidden.
    -- Systems that uses "UI.TopLevelParentShown" seem to be of low importance:
    -- LowHealthFrame and ActionStatus (the container that shows Screen Captured)

    -- UNUSED!!! ---

    --[[
    local function UnregisterCallbackWidthNoOwner(callbackType, event)
        if EventRegistry.callbackTables and EventRegistry.callbackTables[callbackType] then
            local callbacks = EventRegistry.callbackTables[callbackType][event];
            if callbacks then
                for owner in pairs(EventRegistry.callbackTables[callbackType][event]) do
                    if type(owner) == "number" then
                        callbacks[owner] = nil;
                    end
                end
            end
        end
    end
    UnregisterCallbackWidthNoOwner(2, "UI.TopLevelParentShown");
    --]]
end


-- Use a new method in 12.1 to handle UI Visiblity
if UIModeUtil and UIModeUtil.RegisterMode and UIModeUtil.SetModeActive then
    local modeName = "DialogueUI.HideUI";

    UIModeUtil.RegisterMode(modeName, {
        rolesetBlocklist = {
            "actionBars",
            "arenaFrames",
            "bags",
            "buffs",
            "chat",
            "cooldownViewers",
            "encounterUI",
            "extraAbilities",
            "microMenu",
            --"minimap",
            "objectives",
            "pvp",
            "statusBars",
            "unitFrames",
            "widgets",
        },
    });

    SetGameUIShown = function(state)
        UIModeUtil.SetModeActive(modeName, not state);
        if state then
            UIParent:SetAlpha(1);
            Minimap:Show();
        else
            UIParent:SetAlpha(0);
            Minimap:Hide();
        end
    end

    local Dummy = {};
    Dummy.isDialogueUI = true;

    function Dummy:OnUIParentShown()
        SetGameUIShown(true);
    end

    EventRegistry:RegisterCallback("UI.TopLevelParentHidden", Dummy.OnUIParentShown, Dummy);
end


--3.3.5a (Sirus): the retail camera drives the client with the test_camera* CVars
--(test_cameraTargetFocusInteractEnable turns the camera towards the NPC) and reads the zoom with
--GetCameraZoom. This client has none of those. It does expose the saved-view API its own scripted
--cameras use: SaveViewRaw(index, distance, yaw, pitch) + SetView(index), and C_Camera.GetViewAngles()
--to read the live view back. So the camera is driven by writing an absolute view instead of nudging
--CameraZoomIn/CameraZoomOut, which keeps the zoom exact and lets us turn the camera towards the NPC
--the same way the retail code does.
if addon.IS_335 then
    --Saved-view slots are 1-5 (1 is first person and cannot be saved); the client's FrameXML rejects
    --anything higher, so the addon keeps using the same slots SetView accepts.
    local VIEW_SLOT = 4;            --slot we write and apply
    local ORIGINAL_SLOT = 3;        --slot holding the player's view when the raw read is unavailable
    local SMOOTH_BLEND_STYLE = "1";

    local MIN_ZOOM_335 = 3.5;
    local MAX_ZOOM_335 = 28.0;

    local VIEW_RESTORE_MIN_FRAMES = 2;          --skip the frame that shows UIParent again and the one after it
    local VIEW_RESTORE_SMOOTH_FRAME = 1/24;     --then start on the first frame drawn faster than this...
    local VIEW_RESTORE_MAX_DELAY = 0.35;        --...but never wait longer than this
    local VIEW_BLEND_TIME = 1.5;                --SetView needs about a second to bring the camera back

    --Yaw convention of SaveViewRaw on this client. The camera sits opposite to where it looks, so a
    --view computed from a world direction is stored rotated by PI. If the camera turns away from the
    --NPC instead of towards it, flip YAW_SIGN (/duicam prints the live values).
    local YAW_OFFSET = math.pi;
    local YAW_SIGN = 1;

    local PAN_ANGLE = 0.30;         --radians of sideways camera pan for the "Pan Camera" mode
    local FOCUS_ZOOM_335 = 3.0;     --retail switch: yards between camera and player while focusing an NPC

    --The original addon asks for camera distances in yards (3 for a close look at the quest giver) out
    --of a normal ~12 yard camera. GetViewAngles/SaveViewRaw on this client use their own scale, so
    --such a goal is turned into a share of the distance the player had before the dialogue: the focus
    --view then always ends up closer, whatever the client units are.
    local RETAIL_CAMERA_DISTANCE = 12.0;
    local MIN_ZOOM_FACTOR = 0.08;
    local MAX_ZOOM_FACTOR = 1.0;    --never pull the camera farther than the player had it

    --The client keeps C_Camera and SaveViewRaw away from addons (FrameXML/SecureCapsule.lua takes them
    --out of the global namespace on non-dev clients), so every view based step is optional and the
    --native camera controls below do the actual work when the views are not available.
    local PAN_DURATION = 0.35;      --seconds the native camera turn stays engaged for "Horizontal"
    local NATIVE_MIN_ZOOM = 1.5;    --yards, the closest the native zoom goes

    local SaveView = SaveView;
    local SaveViewRaw = SaveViewRaw;
    local SetView = SetView;
    local CameraZoomIn = CameraZoomIn;
    local CameraZoomOut = CameraZoomOut;
    local MoveViewLeftStart = MoveViewLeftStart;
    local MoveViewLeftStop = MoveViewLeftStop;
    local MoveViewRightStart = MoveViewRightStart;
    local MoveViewRightStop = MoveViewRightStop;
    local UnitHasVehicleUI = UnitHasVehicleUI;
    local C_Camera = C_Camera;

    local function IsInVehicle()
        return UnitHasVehicleUI and UnitHasVehicleUI("player")
    end

    local function GetView()
        --distance, yaw, pitch (+ altitude) of the live camera
        if not (C_Camera and C_Camera.GetViewAngles) then return end;

        local distance, yaw, pitch = C_Camera.GetViewAngles();

        if type(distance) ~= "number" or type(yaw) ~= "number" or type(pitch) ~= "number" then return end;

        local altitude;
        if C_Camera.GetAltitude then
            altitude = C_Camera.GetAltitude();
        end

        return { distance = distance, yaw = yaw, pitch = pitch, altitude = altitude }
    end

    local function CanWriteView()
        return type(SaveViewRaw) == "function" and type(SetView) == "function";
    end

    local function WriteView(view)
        if not (view and CanWriteView()) then return false end;

        local blendStyle = GetCVar("cameraViewBlendStyle");
        if blendStyle and blendStyle ~= SMOOTH_BLEND_STYLE then
            SetCVar("cameraViewBlendStyle", SMOOTH_BLEND_STYLE);
        end

        local ok = pcall(SaveViewRaw, VIEW_SLOT, view.distance, view.yaw, view.pitch);
        if not ok then return false end;

        if C_Camera then
            if view.altitude then
                if C_Camera.SetAltitude then C_Camera.SetAltitude(view.altitude) end;
            elseif C_Camera.ResetAltitude then
                C_Camera.ResetAltitude();
            end
        end

        if not pcall(SetView, VIEW_SLOT) then return false end;

        if blendStyle and blendStyle ~= SMOOTH_BLEND_STYLE then
            SetCVar("cameraViewBlendStyle", blendStyle);
        end

        return true
    end

    local function ClampZoom(zoom)
        if not zoom then return end;
        if zoom < MIN_ZOOM_335 then return MIN_ZOOM_335 end;
        if zoom > MAX_ZOOM_335 then return MAX_ZOOM_335 end;
        return zoom
    end

    local function ToViewDistance(self, goal, view)
        local base = (self.view335View and self.view335View.distance) or (view and view.distance);

        if not (base and base > 0) then
            return ClampZoom(goal)
        end

        local factor = (tonumber(goal) or RETAIL_CAMERA_DISTANCE) / RETAIL_CAMERA_DISTANCE;
        if factor < MIN_ZOOM_FACTOR then factor = MIN_ZOOM_FACTOR end;
        if factor > MAX_ZOOM_FACTOR then factor = MAX_ZOOM_FACTOR end;

        return base * factor
    end

    local function GetUnitWorldXY(unit)
        if not UnitPosition then return end;

        local y, x = UnitPosition(unit);

        if type(x) == "number" and type(y) == "number" then
            return x, y
        end
    end

    local function GetYawTowards(unit)
        --Compass angle (0 = north, positive = east) from the player to the unit
        local x, y = GetUnitWorldXY(unit);
        local px, py = GetUnitWorldXY("player");

        if not (x and y and px and py) then return end;

        local dx, dy = x - px, y - py;

        if (dx*dx + dy*dy) < 0.01 then return end;

        return math.atan2(dx, dy) * YAW_SIGN
    end

    local PanDriver = CreateFrame("Frame");
    PanDriver:Hide();

    function PanDriver:Run(turnLeft, duration)
        self:Stop();

        local start = turnLeft and MoveViewLeftStart or MoveViewRightStart;
        local finish = turnLeft and MoveViewLeftStop or MoveViewRightStop;

        if type(start) ~= "function" or type(finish) ~= "function" then return false end;

        self.finish = finish;
        self.t = 0;
        self.duration = duration or PAN_DURATION;

        start();
        self:SetScript("OnUpdate", self.OnUpdate);
        self:Show();

        return true
    end

    function PanDriver:OnUpdate(elapsed)
        self.t = self.t + elapsed;
        if self.t >= self.duration then
            self:Stop();
        end
    end

    function PanDriver:Stop()
        if self.finish then
            self.finish();
            self.finish = nil;
        end

        self:SetScript("OnUpdate", nil);
        self:Hide();
    end

    local ViewRestorer = CreateFrame("Frame");
    ViewRestorer:Hide();

    function ViewRestorer:ForceSmoothBlend()
        local style = GetCVar("cameraViewBlendStyle");
        if style and style ~= SMOOTH_BLEND_STYLE and not self.blendStyleBackup then
            self.blendStyleBackup = style;
            SetCVar("cameraViewBlendStyle", SMOOTH_BLEND_STYLE);
        end
    end

    function ViewRestorer:RestoreBlendStyle()
        if self.blendStyleBackup then
            SetCVar("cameraViewBlendStyle", self.blendStyleBackup);
            self.blendStyleBackup = nil;
        end
    end

    function ViewRestorer:OnUpdate(elapsed)
        self.t = self.t + elapsed;

        if self.pending then
            self.frames = self.frames + 1;
            if (self.frames >= VIEW_RESTORE_MIN_FRAMES and elapsed < VIEW_RESTORE_SMOOTH_FRAME) or (self.t >= VIEW_RESTORE_MAX_DELAY) then
                self.pending = nil;
                self.t = 0;

                if IsInVehicle() then
                    self:Stop();
                else
                    self:ForceSmoothBlend();
                    if self.restoreView then
                        WriteView(self.restoreView);
                    elseif type(SetView) == "function" then
                        pcall(SetView, ORIGINAL_SLOT);
                    end
                end
            end
        elseif self.t >= VIEW_BLEND_TIME then
            self:Stop();
        end
    end

    function ViewRestorer:Start(view)
        self.restoreView = view;
        self.pending = true;
        self.t = 0;
        self.frames = 0;
        self:SetScript("OnUpdate", self.OnUpdate);
        self:Show();
    end

    function ViewRestorer:Stop()
        self.pending = nil;
        self.restoreView = nil;
        self:SetScript("OnUpdate", nil);
        self:Hide();
        self:RestoreBlendStyle();
    end

    function ViewRestorer:IsRestoring()
        return self.pending or self:IsShown()
    end

    local function SaveCameraOnce(self)
        if self.view335Saved then return end;
        self.view335Saved = true;

        if ViewRestorer:IsRestoring() then
            --The previous dialog has just closed (next quest of the same NPC, a gossip option that opens
            --a quest...) and the camera is still on its way back. The saved view is the original one: keep it.
            ViewRestorer:Stop();
            return
        end

        self.view335View = GetView();

        if not self.view335View and type(SaveView) == "function" then
            --No raw read on this client: let the game store the exact view in a slot instead
            pcall(SaveView, ORIGINAL_SLOT);
        end
    end

    function CameraUtil:GetShoulderOffsetForCurrentZoom()
        return 0
    end

    function CameraUtil:MoveCameraToFinalPosition()
        --No over-the-shoulder CVar on 3.3.5a
    end

    function CameraUtil:GetLiveZoom()
        local view = GetView();
        if view then return view.distance end;
        return tonumber(GetCVar("cameraDistanceMax")) or 15
    end

    function CameraUtil:ZoomTo(goal, noZoomOut)
        if not self.isActive then return end;

        SaveCameraOnce(self);

        local goalRetail = tonumber(goal);
        local view = GetView();

        local distance = ToViewDistance(self, goalRetail, view);

        if distance and noZoomOut and view and distance > view.distance then return end;

        if view and CanWriteView() then
            local yaw = view.yaw;

            if self.cameraMode == 1 then
                --Focus the NPC like test_cameraTargetFocusInteractEnable does on retail
                local yawTowards = GetYawTowards("npc");
                if yawTowards then
                    yaw = yawTowards + YAW_OFFSET;
                end
            end

            if distance and WriteView({ distance = distance, yaw = yaw, pitch = view.pitch, altitude = view.altitude }) then
                self.currentZoom335 = distance;
                return
            end
        end

        --No camera view API for addons on this client: zoom with the native controls. Zooming all the
        --way in first makes the next step an absolute distance instead of a relative nudge.
        if type(CameraZoomIn) == "function" then
            local zoom = math.max(goalRetail or FOCUS_ZOOM_335, NATIVE_MIN_ZOOM);

            CameraZoomIn(100);
            if type(CameraZoomOut) == "function" then
                CameraZoomOut(zoom);
            end

            self.currentZoom335 = zoom;
        end
    end

    function CameraUtil:Intro_FocusNPC()
        self.cameraMode = 1;
        self.t = 0;
        self.oldZoom = nil;
        SaveCameraOnce(self);

        --One camera move: turn towards the NPC and zoom to a talking distance. The retail code lets the
        --client auto-frame the target through the test_camera CVars, which this client does not have.
        --The model based distance below only refines this later.
        local view = GetView();
        if view and CanWriteView() then
            local yawTowards = GetYawTowards("npc");
            local distance = ToViewDistance(self, FOCUS_ZOOM_335 * ZOOM_MUTIPLIER, view) or view.distance;

            if WriteView({
                distance = distance,
                yaw = yawTowards and (yawTowards + YAW_OFFSET) or view.yaw,
                pitch = view.pitch,
                altitude = view.altitude,
            }) then
                self.currentZoom335 = distance;
            end
        end

        local success = API.EvaluateNPCSize();
        if not success then
            self:OnModelEvaluationComplete(3);
        end
    end

    function CameraUtil:Intro_PanCamera()
        self.cameraMode = 2;
        self.t = 0;
        self.shoulderOffset = 0;
        self.shoulderBlend = 0.1;

        local view = GetView();

        if view and CanWriteView() then
            --Retail pans sideways with test_cameraOverShoulder. With the view API the same offset is a
            --small rotation, which frames the NPC off-centre the same way.
            local pan = PAN_ANGLE * (self.offsetMultiplier or 1);

            WriteView({
                distance = view.distance,
                yaw = view.yaw + pan * YAW_SIGN,
                pitch = view.pitch,
                altitude = view.altitude,
            });

            return
        end

        --Without the view API the camera is orbited with the native move-view controls. They keep
        --turning while engaged, so the turn is timed and always turns the camera back on restore.
        local pan = PAN_DURATION * (self.offsetMultiplier or 1);

        if PanDriver:Run(pan < 0, math.abs(pan)) then
            self.pannedNative335 = { left = pan < 0, duration = PanDriver.duration };
        end
    end

    function CameraUtil:Intro_ZoomToObject()
        self.t = 0;
        self.oldZoom = nil;
        self:ZoomTo(3);
    end

    function CameraUtil:Restore()
        self.isActive = false;
        self:SetScript("OnUpdate", nil);
        self:StopUpdatingForm();

        local cvarRestored = self:RestoreCVars();

        if self.pannedNative335 then
            local pan = self.pannedNative335;
            self.pannedNative335 = nil;
            PanDriver:Run(not pan.left, pan.duration);  --turn the camera back the way it came
        end

        if self.view335Saved then
            self.view335Saved = nil;
            ViewRestorer:Start(self.view335View);   --restore once the UI has settled
            self.view335View = nil;
        end

        if not cvarRestored then return end;

        self.fovChanged = nil;
        self.oldZoom = nil;
        self.currentZoom335 = nil;
        FadeHelper:FadeInUI(addon.DialogueUI);
        self:OnInteractionStop();
    end
end


do  --Camera capability report (3.3.5a calibration helper)
    local function Flag(value)
        if value then return "yes" end;
        return "no"
    end

    SLASH_DUI_CAMERA1 = "/duicam";

    SlashCmdList["DUI_CAMERA"] = function()
        local C_Camera = C_Camera;

        local function CVar(name)
            local value = GetCVar(name);
            if value == nil then return "nil" end;
            return tostring(value)
        end

        print("|cff00ff98Dialogue UI camera|r");
        print("C_Camera:", Flag(C_Camera), "GetViewAngles:", Flag(C_Camera and C_Camera.GetViewAngles),
            "SetAltitude:", Flag(C_Camera and C_Camera.SetAltitude), "GetAltitude:", Flag(C_Camera and C_Camera.GetAltitude));
        print("SaveViewRaw:", Flag(type(SaveViewRaw) == "function"), "SaveView:", Flag(type(SaveView) == "function"),
            "SetView:", Flag(type(SetView) == "function"), "ResetView:", Flag(type(ResetView) == "function"));
        print("GetCameraZoom:", Flag(type(GetCameraZoom) == "function"), "CameraZoomIn:", Flag(type(CameraZoomIn) == "function"),
            "UnitPosition:", Flag(type(UnitPosition) == "function"), "GetPlayerFacing:", Flag(type(GetPlayerFacing) == "function"));
        print("MoveView:", Flag(type(MoveViewRightStart) == "function"), "MoveViewStop:", Flag(type(MoveViewRightStop) == "function"),
            "ZoomOut:", Flag(type(CameraZoomOut) == "function"));
        print("cameraView:", CVar("cameraView"), "blend:", CVar("cameraViewBlendStyle"),
            "distMax:", CVar("cameraDistanceMax"), "fov:", CVar("cameraFov"), "overShoulder:", CVar("test_cameraOverShoulder"));

        if C_Camera and C_Camera.GetViewAngles then
            local distance, yaw, pitch = C_Camera.GetViewAngles();
            print("view:", tostring(distance), tostring(yaw), tostring(pitch),
                "altitude:", tostring(C_Camera.GetAltitude and C_Camera.GetAltitude()));
        end

        if type(UnitPosition) == "function" then
            local py, px = UnitPosition("player");
            local ny, nx = UnitPosition("npc");
            print("player:", tostring(px), tostring(py), "npc:", tostring(nx), tostring(ny));
        end
    end
end
