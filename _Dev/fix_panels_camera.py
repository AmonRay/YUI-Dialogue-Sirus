import io


def load(path):
    return io.open(path, 'r', encoding='utf-8', newline='').read()


def save(path, text):
    io.open(path, 'w', encoding='utf-8', newline='').write(text)


def rep(text, old, new, label, nl):
    old = old.replace('\n', nl)
    new = new.replace('\n', nl)
    assert text.count(old) == 1, 'NOT UNIQUE: ' + label
    print('ok', label)
    return text.replace(old, new, 1)


# --- client panels -------------------------------------------------------------------------------
p = 'Code/Dialogue/DialogueUI.lua'
t = load(p)
nl = '\r\n' if '\r\n' in t else '\n'

t = rep(t, '''    local function IsClientPanelOpen()
        for _, name in ipairs(PANEL_FRAMES) do
            local frame = _G[name];
            if frame and frame.IsShown and frame:IsShown() then
                return true
            end
        end

        return false
    end
''',
        '''    local function IsPanelFrameShown(name)
        local frame = _G[name];
        return frame and frame.IsShown and frame:IsShown()
    end

    local function IsClientPanelOpen()
        --The client registers every panel window it has in UIPanelWindows, the transmogrifier among
        --them, so this also covers windows the addon never heard of.
        if type(UIPanelWindows) == "table" then
            for name in pairs(UIPanelWindows) do
                if IsPanelFrameShown(name) then
                    return true
                end
            end
        end

        for _, name in ipairs(PANEL_FRAMES) do
            if IsPanelFrameShown(name) then
                return true
            end
        end

        return false
    end
''', 'panel open query', nl)

t = rep(t, '''        --Never let a bug here break the client's own panel: it is being opened right now.
        local ok, err = pcall(owner.HideUI, owner);
        if not ok then
            print("|cffff4040Dialogue UI|r: the dialogue could not be closed:", tostring(err));
        end
    end
''',
        '''        --Never let a bug here break the client's own panel: it is being opened right now.
        local ok, err = pcall(owner.HideUI, owner);
        if not ok then
            print("|cffff4040Dialogue UI|r: the dialogue could not be closed:", tostring(err));
        end

        if owner:IsShown() then
            --HideUI backs off on a pending confirmation or a quest that is still arriving; a client
            --panel owns the screen now, so the dialogue goes regardless.
            pcall(owner.Hide, owner);
        end
    end
''', 'force close', nl)

t = rep(t, '''    pcall(manager.RegisterEvent, manager, "PLAYER_ENTERING_WORLD");
    manager:SetScript("OnEvent", OnManagerEvent);
''',
        '''    pcall(manager.RegisterEvent, manager, "PLAYER_ENTERING_WORLD");
    manager:SetScript("OnEvent", OnManagerEvent);

    --Every client panel is shown through ShowUIPanel: close the dialogue from there as well, so a
    --panel that never runs a hooked OnShow (or is created later than this file) still ends it.
    if type(hooksecurefunc) == "function" then
        hooksecurefunc("ShowUIPanel", function(frame)
            if not frame then return end;

            local name = frame.GetName and frame:GetName();
            if (name and type(UIPanelWindows) == "table" and UIPanelWindows[name]) or watchedPanels[frame] then
                OnClientPanel();
            end
        end);
    end
''', 'showuipanel hook', nl)

save(p, t)

# --- camera return -------------------------------------------------------------------------------
p = 'Code/Camera.lua'
t = load(p)
nl = '\r\n' if '\r\n' in t else '\n'

t = rep(t, '''        if self.view335Saved then
            self.view335Saved = nil;
            ViewRestorer:Start(self.view335View);   --restore once the UI has settled
            self.view335View = nil;
        end
''',
        '''        if self.view335Saved then
            self.view335Saved = nil;

            --Only the view API can put the exact view back. Without it SaveCameraOnce stored the view in
            --a client slot and SetView would apply that whole view while the native zoom is still
            --gliding home: the camera then flew out and back in again.
            if self.view335View then
                ViewRestorer:Start(self.view335View);   --restore once the UI has settled
            end

            self.view335View = nil;
        end
''', 'camera single restore', nl)

t = rep(t, '''        if type(UnitPosition) == "function" then
            local py, px = UnitPosition("player");
            local ny, nx = UnitPosition("npc");
            print("player:", tostring(px), tostring(py), "npc:", tostring(nx), tostring(ny));
        end
''',
        '''        if type(UnitPosition) == "function" then
            local py, px = UnitPosition("player");
            local ny, nx = UnitPosition("npc");
            print("player:", tostring(px), tostring(py), "npc:", tostring(nx), tostring(ny));
        end

        if type(GetPlayerMapPosition) == "function" then
            local px, py = GetPlayerMapPosition("player");
            local nx, ny = GetPlayerMapPosition("npc");
            print("map player:", tostring(px), tostring(py), "map npc:", tostring(nx), tostring(ny));
        end
''', 'map position report', nl)

save(p, t)
