setfenv(1, select(2, ...).Env or _G) -- DUI335_ENV
local _, addon = ...

-- Ordinary textures on a frame; no modern slicing or masks are required.
function addon.CreateLegacyPanel(parent, layer, subLevel, width, height, margin)
    local frame = CreateFrame("Frame", nil, parent);
    frame:EnableMouse(false);
    frame.slices = {};
    frame.coords = {0, 1, 0, 1};
    for i = 1, 9 do
        frame.slices[i] = frame:CreateTexture(nil, layer or "BACKGROUND", nil, subLevel or 0);
    end
    function frame:UpdateSlices()
        local c = self.coords;
        local u = {c[1], c[1] + margin/width, c[2] - margin/width, c[2]};
        local v = {c[3], c[3] + margin/height, c[4] - margin/height, c[4]};
        local w, h = self:GetWidth(), self:GetHeight();
        local px = addon.API.GetPixelForScale(self:GetEffectiveScale(), 1);
        local mx, my = math.min(margin*px, w/2), math.min(margin*px, h/2);
        local x, y = {0, mx, w-mx, w}, {0, my, h-my, h};
        for row = 1, 3 do
            for col = 1, 3 do
                local t = self.slices[(row-1)*3+col];
                t:ClearAllPoints();
                t:SetPoint("TOPLEFT", self, "TOPLEFT", x[col], -y[row]);
                t:SetPoint("BOTTOMRIGHT", self, "TOPLEFT", x[col+1], -y[row+1]);
                t:SetTexCoord(u[col], u[col+1], v[row], v[row+1]);
            end
        end
    end
    function frame:SetTexture(file)
        for _, t in ipairs(self.slices) do t:SetTexture(file); end
    end
    function frame:SetTexCoord(l, r, t, b)
        self.coords = {l, r, t, b};
        self:UpdateSlices();
    end
    function frame:SetVertexColor(r, g, b, a)
        for _, t in ipairs(self.slices) do t:SetVertexColor(r, g, b, a or 1); end
    end
    frame:SetScript("OnSizeChanged", frame.UpdateSlices);
    return frame;
end
