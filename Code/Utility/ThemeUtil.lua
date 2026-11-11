setfenv(1, select(2, ...).Env or _G) -- DUI335_ENV
local _, addon = ...
local GetItemQualityColor = addon.API.GetItemQualityColor;

local ThemeUtil = {};
addon.ThemeUtil = ThemeUtil;

local gsub = string.gsub;
local unpack = unpack;

local ART_PATH = "Interface\\AddOns\\DialogueUI\\Art\\";
local TEXTURE_PATH = ART_PATH.."Theme_Brown\\";
local THEME_ID = 1;


local ColorAdjustment = {
    ---Used to replace Red for Brown theme
    Red = {
        pattern = {
            "|cnRED_FONT_COLOR:",
            "|cnWARNING_FONT_COLOR:",
            "|[cC][fF][fF][fF][fF]0000",
            "|[cC][fF][fF][fF][fF]4040",
        },
        replaceBy = "|cff9B2020",
    },

    ---Used to replace Blue for Dark theme
    Blue = {
        pattern = {
            "|cnPURE_BLUE_COLOR:",
            "|[cC][fF][fF]0000[fF][fF]",
        },
        replaceBy = "|cff0078FF",
    }
};


local ActiveColorLookup = ColorAdjustment.Red;

---Used in Brown theme. Adjust red text color to increase legibility.
---@return string adjustedText
---@return boolean redColorFound
local function AdjustTextColor(text)
    local count = 0;

    for _, pattern in ipairs(ActiveColorLookup.pattern) do
        text, count = gsub(text, pattern, ActiveColorLookup.replaceBy);
        if count > 0 then
            break;
        end
    end

    return text, count > 0;
end


local COLORS = {
    --ColorKey = {r, g, b}

    DarkBrown = {0.19, 0.17, 0.13},
    LightBrown = {0.50, 0.36, 0.24},
    Ivory = {0.87, 0.86, 0.75},
    Brick = {0.416, 0.18, 0.165},

    DarkModeGrey90 = {0.9, 0.9, 0.9},
    DarkModeGrey70 = {0.7, 0.7, 0.7},
    DarkModeGrey50 = {0.5, 0.5, 0.5},
    DarkModeGold = {1, 0.98, 0.8},
    DarkModeGoldDim = {0.796, 0.784, 0.584},

    WarningRed = {1.000, 0.125, 0.125},
    BrightGreen = {0.5, 0.86, 0.5};
};

local FONT_OBJECT_COLOR = {
    --FontObjectName = {Theme Brown, Dark}

    DUIFont_Quest_Title_18 = {"DarkBrown", "DarkModeGrey90"},
    DUIFont_Quest_Title_16 = {"DarkBrown", "DarkModeGrey90"},
    DUIFont_Quest_SubHeader = {"DarkBrown", "DarkModeGrey90"},
    DUIFont_Quest_Paragraph = {"DarkBrown", "DarkModeGrey70"},
    DUIFont_Quest_Gossip = {"DarkBrown", "DarkModeGoldDim"},
    DUIFont_Quest_Quest = {"Ivory", "DarkModeGold"},
    DUIFont_Quest_Disabled = {"LightBrown", "DarkModeGrey50"},
    DUIFont_Quest_MultiLanguage = {"Brick", "DarkModeGrey50"},

    DUIFont_Settings_Disabled = {"LightBrown", "DarkModeGrey50"},

    DUIFont_Item = {"DarkBrown", "DarkModeGrey90"},
    DUIFont_ItemSelect = {"Ivory", "DarkModeGold"},

    DUIFont_QuestType_Left = {"DarkBrown", "DarkModeGrey90"},
    DUIFont_QuestType_Right = {"DarkModeGrey70", "DarkModeGrey70"},

    DUIFont_Constant_10 = {"DarkBrown", "DarkModeGrey70"},
    DUIFont_Constant_8 = {"DarkBrown", "DarkModeGrey70"},

    DUIFont_MenuButton_Normal = {"DarkBrown", "DarkModeGrey90"},
    DUIFont_MenuButton_Highlight = {"DarkBrown", "DarkModeGrey90"},
};


local function SetFontColor(fontObject, key)
    local color = COLORS[key];
    -- Theme selection can run before all XML font objects exist.
    if fontObject and color then
        fontObject:SetTextColor(color[1], color[2], color[3]);
    end
end

function ThemeUtil:SetFontColor(fontObject, key)
    SetFontColor(fontObject, key);
end

function ThemeUtil:SetThemeByID(themeID)
    local colorIndex;

    if themeID == 2 then    --Dark
        colorIndex = 2;
        TEXTURE_PATH = ART_PATH.."Theme_Dark\\";
        ActiveColorLookup = ColorAdjustment.Blue;
    else
        themeID = 1;
        colorIndex = 1;
        TEXTURE_PATH = ART_PATH.."Theme_Brown\\";
        ActiveColorLookup = ColorAdjustment.Red;
    end

    THEME_ID = themeID;

    local _G = _G;

    for fontName, colorKey in pairs(FONT_OBJECT_COLOR) do
        SetFontColor(_G[fontName], colorKey[colorIndex]);
    end

    if addon.DialogueUI then
        addon.DialogueUI:LoadTheme();
    end

    if addon.SettingsUI then
        addon.SettingsUI:LoadTheme();
    end

    if addon.QuestItemDisplay then
        addon.QuestItemDisplay:LoadTheme();
    end

    if addon.DropdownMenu then
        addon.DropdownMenu:LoadTheme();
    end

    addon.CallbackRegistry:Trigger("ThemeChanged", themeID);

    ThemeUtil:UpdateMultiLanguageFontColor();
end

function ThemeUtil:GetTexturePath()
    return TEXTURE_PATH
end

-- Bare names may be assembled at runtime (prefix..name, decor/key tables).
-- Search by the final string; explicit categories never select a different theme.
local ASSET_DIRECTORIES = {"Theme_Shared", "Icons", "Keys", "GameAssets", "Book",
    "BasicShapes", "ParchmentDecor", "PreviewPicture", "Shared"};
local MissingTextures = {};
local function MissingTexture(name)
    if not MissingTextures[name] then
        MissingTextures[name] = true;
        print("DUI-TEX: missing "..name);
    end
    return ART_PATH.."Theme_Shared\\ClipboardBackground";
end

local function NormalizeTextureName(name)
    if type(name) ~= "string" or name == "" then return end;
    name = gsub(name, "/", "\\");
    name = gsub(name, "\\+", "\\");
    name = gsub(name, "%.[bB][lL][pP]$", "");
    name = gsub(name, "%.[tT][gG][aA]$", "");
    name = gsub(name, "%.[pP][nN][gG]$", "");
    name = gsub(name, "%.[jJ][pP][eE]?[gG]$", "");
    name = gsub(name, "%.[dD][dD][sS]$", "");
    local key = string.lower(gsub(name, "\\", "/"));
    local root = string.lower(gsub(ART_PATH, "\\", "/"));
    if string.sub(key, 1, #root) == root then
        name, key = string.sub(name, #root + 1), string.sub(key, #root + 1);
    elseif string.find(key, "^interface/") then
        return name, key, true;
    elseif string.find(key, "^art/") then
        name, key = string.sub(name, 5), string.sub(key, 5);
    end
    if key == "" then return end;
    return name, key, false;
end

-- Quiet lookup for compat callers: nil means no known addon asset, not the
-- visible missing-texture substitute. Additional returns are original pixels.
function ThemeUtil:FindTextureFile(fileName)
    local name, key, external = NormalizeTextureName(fileName);
    if not name then return end;
    if external then return name end;
    local sizes = addon.TextureFileSizes;
    local function Found(directory, asset)
        local relative = directory and directory.."\\"..asset or asset;
        local size = sizes and sizes[string.lower(gsub(relative, "\\", "/"))];
        if size then return ART_PATH..relative, size[1], size[2] end;
    end
    if string.find(key, "/", 1, true) then
        local file, w, h = Found(nil, name);
        if file then return file, w, h end;
        if string.find(key, "^shared/") then
            return Found("Theme_Shared", string.sub(name, 8));
        end
        if not sizes then return ART_PATH..name end;
        return;
    end
    local active = THEME_ID == 2 and "Theme_Dark" or "Theme_Brown";
    local file, w, h = Found(active, name);
    if file then return file, w, h end;
    for _, directory in ipairs(ASSET_DIRECTORIES) do
        file, w, h = Found(directory, name);
        if file then return file, w, h end;
    end
    -- Only use the other theme after the shared/non-themed categories.
    file, w, h = Found(THEME_ID == 2 and "Theme_Brown" or "Theme_Dark", name);
    if file then return file, w, h end;
    if not sizes then return TEXTURE_PATH..name end;
end

function ThemeUtil:GetTextureFile(fileName)
    local name = NormalizeTextureName(fileName);
    if not name then return end;
    local file = self:FindTextureFile(fileName);
    return file or MissingTexture(name);
end

function ThemeUtil:GetTextureSize(fileName)
    local _, width, height = self:FindTextureFile(fileName);
    return width, height;
end

function ThemeUtil:GetThemeID()
    return THEME_ID
end

function ThemeUtil:IsDarkMode()
    return THEME_ID == 2
end

function ThemeUtil:GetQualityColor(quality)
    if self:IsDarkMode() then
        return GetItemQualityColor(quality):GetRGB()
    else
        return 0.19, 0.17, 0.13, 1
    end
end

function ThemeUtil:GetItemSelectColor()
    if self:IsDarkMode() then
        return unpack(COLORS.DarkModeGold)
    else
        return unpack(COLORS.Ivory)
    end
end

function ThemeUtil:GetMenuButtonColor()
    if self:IsDarkMode() then
        return unpack(COLORS.DarkModeGrey90)
    else
        return unpack(COLORS.DarkBrown)
    end
end

function ThemeUtil:AdjustTextColor(text)
    return AdjustTextColor(text);
end

function ThemeUtil:UpdateMultiLanguageFontColor(showOriginal)
    local colorIndex = THEME_ID == 2 and 2 or 1;
    local colors;

    if showOriginal == nil then
        showOriginal = true;
    end

    if showOriginal then
        colors = FONT_OBJECT_COLOR.DUIFont_Quest_MultiLanguage;
    else
        colors = FONT_OBJECT_COLOR.DUIFont_Quest_Paragraph;
    end

    local fontName = "DUIFont_Quest_MultiLanguage";
    SetFontColor(_G[fontName], colors[colorIndex]);
end


do
    ThemeUtil:SetThemeByID(1);

    local function Settings_Theme(dbValue)
        local themeID;
        if dbValue == 2 then
            themeID = 2;
        else
            themeID = 1;
        end
        ThemeUtil:SetThemeByID(themeID);
    end
    addon.CallbackRegistry:Register("SettingChanged.Theme", Settings_Theme);

    addon.CallbackRegistry:Register("SettingChanged.TranslatorShowOriginalText", ThemeUtil.UpdateMultiLanguageFontColor, ThemeUtil);
end
