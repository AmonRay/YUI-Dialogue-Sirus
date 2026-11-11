setfenv(1, select(2, ...).Env or _G) -- DUI335_ENV
local _, addon = ...

local Template = {};
addon.Template = Template;

-- Resolve shared artwork from ThemeUtil's canonical addon path as well.
function Template.GetSharedTextureFile(fileName)
    local path = addon.ThemeUtil:GetTexturePath();
    return (path:gsub("/", "\\"):gsub("Theme_[^\\]+\\$", "Theme_Shared\\"))..fileName;
end

-- XML scripts share the addon's environment on 3.3.5.
function DUI_SetSharedTexture(texture, fileName)
    texture:SetTexture(Template.GetSharedTextureFile(fileName));
end