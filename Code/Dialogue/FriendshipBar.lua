setfenv(1, select(2, ...).Env or _G) -- DUI335_ENV
local _, addon = ...
local API = addon.API;
local TooltipFrame = addon.SharedTooltip;
local Clamp = API.Clamp;
local Lerp = API.ClampLerp;

local GetFriendshipReputation = C_GossipInfo.GetFriendshipReputation;
local GetFriendshipReputationRanks = C_GossipInfo.GetFriendshipReputationRanks;

local FRAME_SIZE = 52;
local FriendshipBar = CreateFrame("Frame");
addon.FriendshipBar = FriendshipBar;
FriendshipBar:SetSize(FRAME_SIZE, FRAME_SIZE);
FriendshipBar.textures = {};


-- The legacy client uses baked texture alpha and rectangular UV clipping.

local function SetTextureNumber(texture, number)
    --Bake number into textures for visual consistency
    number = Clamp(number, 1, 9);
    texture:SetTexCoord((number - 1)*0.0625, number*0.0625, 0, 1);
end

function FriendshipBar:Init()
    local Container = CreateFrame("Frame", nil, self);
    Container:SetSize(FRAME_SIZE, FRAME_SIZE);
    Container:SetPoint("CENTER", self, "CENTER", 0, 0);
    self.Container = Container;

    local tinsert = table.insert;

    local FrontTexture = Container:CreateTexture(nil, "OVERLAY", nil, 3);
    FrontTexture:SetTexCoord(0.0625, 0.4375, 0.0625, 0.4375);
    FrontTexture:SetAllPoints(true);
    self.FrontTexture = FrontTexture;
    tinsert(self.textures, FrontTexture);

    local BackTexture = Container:CreateTexture(nil, "BACKGROUND");
    BackTexture:SetTexCoord(0.5625, 0.9375, 0.0625, 0.4375);
    BackTexture:SetAllPoints(true);
    self.BackTexture = BackTexture;
    tinsert(self.textures, BackTexture);


    local fillLayer = "ARTWORK";

    local FillFull = Container:CreateTexture(nil, fillLayer);
    FillFull:SetTexCoord(0.5625, 0.9375, 0.0625, 0.4375);
    FillFull:SetAllPoints(true);
    self.FillFull = FillFull;
    tinsert(self.textures, FillFull);

    -- FillFull uses the baked alpha of FriendshipBar; no mask objects.
    self.BackTexture:SetVertexColor(0.35, 0.35, 0.35);


    --[[
    local MaxLevelText = Container:CreateFontString(nil, "OVERLAY", "MirageFont_Serif_10_DarkBrown", 2);
    MaxLevelText:SetJustifyH("CENTER");
    MaxLevelText:SetJustifyV("MIDDLE");
    MaxLevelText:SetPoint("CENTER", Container, "CENTER", 8.5, 4.8);
    MaxLevelText:SetText(5);
    self.MaxLevelText = MaxLevelText;

    local CurrentLevelText = Container:CreateFontString(nil, "OVERLAY", "MirageFont_Serif_18_DarkBrown", 3);
    CurrentLevelText:SetJustifyH("CENTER");
    CurrentLevelText:SetJustifyV("MIDDLE");
    CurrentLevelText:SetPoint("CENTER", Container, "CENTER", -8.5, 3);
    CurrentLevelText:SetText(1);
    self.CurrentLevelText = CurrentLevelText;
    --]]

    local CurrentLevelText = Container:CreateTexture(nil, "OVERLAY", nil, 5);
    CurrentLevelText:SetPoint("CENTER", Container, "CENTER", -8, 3);
    CurrentLevelText:SetSize(20, 20);
    self.CurrentLevelText = CurrentLevelText;

    local MaxLevelText = Container:CreateTexture(nil, "OVERLAY", nil, 5);
    MaxLevelText:SetPoint("CENTER", Container, "CENTER", 8.5, 4.8);
    MaxLevelText:SetSize(13, 13);
    self.MaxLevelText = MaxLevelText;

    self:SetScript("OnEnter", self.OnEnter);
    self:SetScript("OnLeave", self.OnLeave);
    self:SetScript("OnEvent", self.OnEvent);
    self:SetScript("OnHide", self.OnHide);

    self:SetHitRectInsets(1, 1, 2, 2);

    self.Init = nil;
    self:LoadTheme();
end

function FriendshipBar:LoadTheme()
    if self.Init then return end;

    local barFile = addon.ThemeUtil:GetTextureFile("FriendshipBar");
    local numberFile = addon.ThemeUtil:GetTextureFile("FriendshipDigits");

    for _, tex in ipairs(self.textures) do
        tex:SetTexture(barFile);
    end

    local filer = "TRILINEAR";
    self.CurrentLevelText:SetTexture(numberFile);
    self.MaxLevelText:SetTexture(numberFile);
end


-- 3.3.5 cannot rotate alpha masks. Reveal the baked heart vertically instead.
function FriendshipBar:SetRatio(ratio)
    ratio = Clamp(ratio, 0, 1);
    self.FillFull:ClearAllPoints();
    self.FillFull:SetPoint("BOTTOMLEFT", self.Container, "BOTTOMLEFT", 0, 0);
    self.FillFull:SetSize(FRAME_SIZE, math.max(0.01, FRAME_SIZE * ratio));
    self.FillFull:SetTexCoord(0.5625, 0.9375, 0.4375 - 0.375 * ratio, 0.4375);
    self.FillFull:SetShown(ratio > 0);
end

function FriendshipBar:Update(factionID)
    local repInfo = GetFriendshipReputation and GetFriendshipReputation(factionID or 0);
	if repInfo and repInfo.friendshipFactionID and  repInfo.friendshipFactionID > 0 then
        if self.Init then
            self:Init();
        end

		self.friendshipFactionID = repInfo.friendshipFactionID;
        local fillRatio;

        if repInfo.nextThreshold then
			local current = repInfo.standing - repInfo.reactionThreshold;
			local max = repInfo.nextThreshold - repInfo.reactionThreshold;
            if max == 0 then
                fillRatio = 1;
            else
                fillRatio = current / max;
            end
		else
			fillRatio = 1;
		end

        self:SetRatio(fillRatio);

        local rankInfo = GetFriendshipReputationRanks(repInfo.friendshipFactionID);

        --self.CurrentLevelText:SetText(rankInfo.currentLevel);
        --self.MaxLevelText:SetText(rankInfo.maxLevel);
        SetTextureNumber(self.CurrentLevelText, rankInfo.currentLevel);
        SetTextureNumber(self.MaxLevelText, rankInfo.maxLevel);

        self:RegisterEvent("UPDATE_FACTION");
		self.Container:Show();

	elseif self.Container then
        self.friendshipFactionID = nil;
        self:UnregisterEvent("UPDATE_FACTION");
		self.Container:Hide();
	end
end

function FriendshipBar:OnUpdate(elapsed)
    self:SetScript("OnUpdate", nil);
    self:Update();
end

function FriendshipBar:RequestUpdate()
    self:SetScript("OnUpdate", self.OnUpdate);
    self:Show();
end

function FriendshipBar:OnEnter()
    if not self.friendshipFactionID then return end;

	local repInfo = GetFriendshipReputation(self.friendshipFactionID);
	if repInfo and repInfo.friendshipFactionID and repInfo.friendshipFactionID > 0 then
        TooltipFrame:Hide();
		TooltipFrame:SetOwner(self, "ANCHOR_NONE");
        TooltipFrame:SetPoint("BOTTOMLEFT", self, "TOPRIGHT", 0, 0);
		local rankInfo = GetFriendshipReputationRanks(repInfo.friendshipFactionID);
		if rankInfo.maxLevel > 0 then
			TooltipFrame:SetTitle(repInfo.name.." ("..rankInfo.currentLevel.." / "..rankInfo.maxLevel..")", 1, 1, 1);
		else
			TooltipFrame:SetTitle(repInfo.name, 1, 1, 1);
		end
		TooltipFrame:AddLeftLine(repInfo.text, 1, 0.82, 0, true);
		if repInfo.nextThreshold then
			local current = repInfo.standing - repInfo.reactionThreshold;
			local max = repInfo.nextThreshold - repInfo.reactionThreshold;
			TooltipFrame:AddLeftLine(repInfo.reaction.." ("..current.." / "..max..")" , 1, 1, 1, true);

            local diff = max - current;
            TooltipFrame:AddLeftLine(addon.L["To Next Level Label"]..": |cffffffff"..diff.."|r", 1, 0.82, 0);
		else
			TooltipFrame:AddLeftLine(repInfo.reaction, 1, 1, 1, true);
		end
		TooltipFrame:Show();
	end
end

function FriendshipBar:OnLeave()
    TooltipFrame:Hide();
end

function FriendshipBar:OnEvent(event, ...)
    if event == "UPDATE_FACTION" then
        self:RequestUpdate();
    end
end

function FriendshipBar:OnHide()
    self:UnregisterEvent("UPDATE_FACTION");
end