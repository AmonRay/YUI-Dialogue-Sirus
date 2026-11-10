setfenv(1, select(2, ...).Env or _G) -- DUI335_ENV

if true then return end;
local _, addon = ...
local L = {};
L._name = "Arabic";
addon.L_arAR = L;