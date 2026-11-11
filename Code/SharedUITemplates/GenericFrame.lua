setfenv(1, select(2, ...).Env or _G) -- DUI335_ENV
local _, addon = ...
local API = addon.API;
local ThemeUtil = addon.ThemeUtil;

DUIGenericTitledFrameMixin = {};

-- These are ordinary 3.3.5 textures, not the modern TextureSlice API.
local TEXTURE_LOOKUP = {
    [1] = {file = "GenericFrame-Tiled-Large", offset = 16, margins = {80, 80, 80, 80}, width = 512, height = 512},
    [2] = {file = "GenericFrame-Tiled-Large", offset = 16, margins = {80, 80, 80, 80}, width = 512, height = 512},
    HelpTip1 = {file = "HelpTip", shared = true, offset = 8, margins = {40, 24, 40, 24}, width = 512, height = 512, texCoords = {0, 0.5, 0, 104/512}},
    HelpTip2 = {file = "HelpTip", shared = true, offset = 8, margins = {40, 24, 40, 24}, width = 512, height = 512, texCoords = {0, 0.5, 104/512, 208/512}},
};

function DUIGenericTitledFrameMixin:UpdatePixel()
    if not self.textureInfo or self.updatingSlices then return end;
    self.updatingSlices = true;
    local background = self.Background;
    local info = self.textureInfo;
    local px = API.GetPixelForScale(background:GetEffectiveScale(), 1);
    local offset = info.offset * px;
    background:ClearAllPoints();
    background:SetPoint("TOPLEFT", self, "TOPLEFT", -offset, offset);
    background:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", offset, -offset);

    local m = info.margins;
    local left = math.min(m[1] * px, background:GetWidth() / 2);
    local right = math.min(m[3] * px, background:GetWidth() / 2);
    local top = math.min(m[2] * px, background:GetHeight() / 2);
    local bottom = math.min(m[4] * px, background:GetHeight() / 2);
    local xs = {0, left, math.max(left, background:GetWidth() - right), background:GetWidth()};
    local ys = {0, top, math.max(top, background:GetHeight() - bottom), background:GetHeight()};
    for row = 1, 3 do
        for col = 1, 3 do
            local slice = self.slices[(row - 1) * 3 + col];
            slice:ClearAllPoints();
            slice:SetPoint("TOPLEFT", background, "TOPLEFT", xs[col], -ys[row]);
            slice:SetPoint("BOTTOMRIGHT", background, "TOPLEFT", xs[col + 1], -ys[row + 1]);
        end
    end
    self.updatingSlices = nil;
end

function DUIGenericTitledFrameMixin:SetTheme(themeID)
    local info = TEXTURE_LOOKUP[themeID] or TEXTURE_LOOKUP[ThemeUtil:GetThemeID()] or TEXTURE_LOOKUP[1];
    self.themeID = themeID;
    self.textureInfo = info;
    self.pixelOffset = info.offset;
    local file = info.shared and addon.Template.GetSharedTextureFile(info.file) or ThemeUtil:GetTextureFile(info.file);
    local c = info.texCoords or {0, 1, 0, 1};
    local m = info.margins;
    local xs = {c[1], c[1] + m[1]/info.width, c[2] - m[3]/info.width, c[2]};
    local ys = {c[3], c[3] + m[2]/info.height, c[4] - m[4]/info.height, c[4]};
    for row = 1, 3 do
        for col = 1, 3 do
            local slice = self.slices[(row - 1) * 3 + col];
            slice:SetTexture(file);
            slice:SetTexCoord(xs[col], xs[col + 1], ys[row], ys[row + 1]);
        end
    end
    self:UpdatePixel();
end

function DUIGenericTitledFrameMixin:OnLoad()
    self.RealArea = self.Background;
    self.EffectiveArea = self;
    self.slices = {};
    self.Background:SetFrameLevel(self:GetFrameLevel());
    for i = 1, 9 do
        self.slices[i] = self.Background:CreateTexture(nil, "BACKGROUND");
    end
    self.Background:SetScript("OnSizeChanged", function() self:UpdatePixel(); end);
    addon.CallbackRegistry:Register("ThemeChanged", self.OnThemeChanged, self);
    self:SetTheme(ThemeUtil:GetThemeID());
end

function DUIGenericTitledFrameMixin:OnThemeChanged(themeID)
    -- Help tips retain their shared artwork when the selected theme changes.
    self:SetTheme(type(self.themeID) == "string" and self.themeID or themeID);
end
