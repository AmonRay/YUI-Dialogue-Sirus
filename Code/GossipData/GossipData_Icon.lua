setfenv(1, select(2, ...).Env or _G) -- DUI335_ENV
local _, addon = ...
local GossipDataProvider = addon.GossipDataProvider;
local L = addon.L;

local ICON_PATH = "Interface/AddOns/DialogueUI/Art/Icons/";

local GossipIcon = {
    --[gossipOptionID/name] = icon
    ["Gossip Red"] = ICON_PATH.."Gossip-Red",       --<Skip Chaptor>
    ["Gossip Quest"] = ICON_PATH.."Gossip-Quest",   --(Quest) flags == 1
    ["Gossip Movie"] = ICON_PATH.."Gossip-Movie",   --(Quest) flags == 4
    [132053] = ICON_PATH.."Gossip",
    [132058] = ICON_PATH.."Trainer",                --Trainer
    [132060] = ICON_PATH.."Buy",                    --Merchant
    [1019848] = ICON_PATH.."Gossip",                --Tavio in Iskaara (likely meant to use Fishing icon)
    [1673939] = "interface/minimap/tracking/transmogrifier",
    [1130518] = "interface/cursor/crosshair/workorders",                            --Work Orders (Class Hall)
    [132050] = "interface/minimap/tracking/banker",


    --Ask guard for directions
    ["Inn"] = ICON_PATH.."Innkeeper",
    [L["Pin Inn"]] = ICON_PATH.."Innkeeper",
    [L["Pin Profession Trainer"]] = ICON_PATH.."Mine",
    [L["Pin Class Trainer"]] = ICON_PATH.."Trainer",
    [L["Pin Stable Master"]] = ICON_PATH.."Stablemaster",
    [L["Pin Trading Post"]] = ICON_PATH.."TradingPost",
    [L["Pin Battle Pet Trainer"]] = ICON_PATH.."BattlePet",
    [L["Pin Transmogrification"]] = "interface/minimap/tracking/transmogrifier",
    [L["Pin Transmogrifier"]] = "interface/minimap/tracking/transmogrifier",
    [L["Pin Void Storage"]] = "interface/cursor/crosshair/voidstorage",
    [L["Pin Auction House"]] = "interface/minimap/tracking/auctioneer",
    [L["Pin Bank"]] = "interface/minimap/tracking/banker",
    [L["Pin Barber"]] = "interface/minimap/tracking/barbershop",
    [L["Pin Flight Master"]] = "interface/minimap/tracking/flightmaster",
    [L["Pin Mailbox"]] = "interface/minimap/tracking/mailbox",
    [L["Pin Vendor"]] = "interface/cursor/crosshair/buy",
    --["Points of Interest"] = "",
    --["Other Continents"] = "Interface/AddOns/DialogueUI/Art/Icons/Continent",


    --Queue Dungeon Finder
    ["LFG"] = ICON_PATH.."LFG",
};
GossipIcon[132052] = GossipIcon["Inn"];

if addon.IS_335 then
    --3.3.5a has none of these retail files (minimap/tracking/*.blp, cursor/crosshair/*.blp):
    --use the 3.3.5a minimap tracking icons or our own icons instead of an empty square.
    local function Swap(old, new)
        for k, v in pairs(GossipIcon) do
            if v == old then
                GossipIcon[k] = new;
            end
        end
    end
    Swap("interface/minimap/tracking/transmogrifier", ICON_PATH.."Gossip");
    Swap("interface/cursor/crosshair/workorders", ICON_PATH.."Gossip");
    Swap("interface/minimap/tracking/barbershop", ICON_PATH.."Gossip");
    Swap("interface/cursor/crosshair/voidstorage", "Interface\\Minimap\\Tracking\\Banker");
    Swap("interface/cursor/crosshair/buy", ICON_PATH.."Buy");
    Swap("interface/minimap/tracking/banker", "Interface\\Minimap\\Tracking\\Banker");
    Swap("interface/minimap/tracking/auctioneer", "Interface\\Minimap\\Tracking\\Auctioneer");
    Swap("interface/minimap/tracking/flightmaster", "Interface\\Minimap\\Tracking\\FlightMaster");
    Swap("interface/minimap/tracking/mailbox", "Interface\\Minimap\\Tracking\\Mailbox");
end


local GossipOptionIDXIcon = {};
do
    local ids = {
        122968,     --Count me in! <Queue for The Codex of Chromie.>
        124977,     --Send me into the Blackrock Depths. (Heroic Raid)
        124978,     --Send me into the Blackrock Depths. (Normal Raid)
    };
    for _, id in ipairs(ids) do
        GossipOptionIDXIcon[id] = GossipIcon["LFG"];
    end
    ids = nil;
end

function GossipDataProvider:GetGossipIcon(oldIconFile, name, gossipOptionID)
    if name and GossipIcon[name] then
        return GossipIcon[name]
    end

    if gossipOptionID and GossipOptionIDXIcon[gossipOptionID] then
        return GossipOptionIDXIcon[gossipOptionID]
    end

    if not oldIconFile then
        oldIconFile = 132053;
    end

    if GossipIcon[oldIconFile] then
        return GossipIcon[oldIconFile]
    end

    return oldIconFile
end