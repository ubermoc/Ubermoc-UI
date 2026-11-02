-- Ubermoc UI - Copyright (c) 2026 Marcos. All rights reserved.
-- This file is protected by copyright. It may not be copied, modified, redistributed or reused, in whole or
-- in part, without the written permission of the author. See LICENSE.txt.
----------------------------------------------------------------------
-- Ubermoc UI: Controller page
-- Turns the gamepad on when the game loads, shows which controller you are using with its own button
-- names, and lets you see and change what every button does. Starts from WoW's own bindings, beginning
-- with the main action bar.
----------------------------------------------------------------------
local API = UbermocUIAPI
-- Game window functions are called through securecallfunction, so the taint of this addon is not carried into
-- the game's own panel bookkeeping (which later made Edit Mode and the arena frames fail).
local function secureCall(fn, ...)
    if securecallfunction then return pcall(securecallfunction, fn, ...) end
    return pcall(fn, ...)
end
if not API then return end

local WHITE = "Interface\\Buttons\\WHITE8X8"

----------------------------------------------------------------------
-- Saved settings
----------------------------------------------------------------------
local function DB()
    UbermocUIDB = UbermocUIDB or {}
    local d = UbermocUIDB.pad
    if type(d) ~= "table" then d = {}; d.freshInstall = true; UbermocUIDB.pad = d end
    if d.auto == nil then d.auto = true end
    if d.layout == nil then d.layout = "auto" end
    return d
end

----------------------------------------------------------------------
-- Controller layouts: what each button is called on each controller
----------------------------------------------------------------------
local SETS = {
    xbox = { name = "Xbox", labels = {
        PAD1 = "A", PAD2 = "B", PAD3 = "X", PAD4 = "Y", PADLSHOULDER = "LB", PADRSHOULDER = "RB",
        PADLTRIGGER = "LT", PADRTRIGGER = "RT", PADLSTICK = "Left stick", PADRSTICK = "Right stick",
        PADBACK = "View", PADFORWARD = "Menu", PADSYSTEM = "Xbox", PADSOCIAL = "Share",
        PADDUP = "D-pad up", PADDDOWN = "D-pad down", PADDLEFT = "D-pad left", PADDRIGHT = "D-pad right",
        PADPADDLE1 = "Paddle 1", PADPADDLE2 = "Paddle 2", PADPADDLE3 = "Paddle 3", PADPADDLE4 = "Paddle 4" } },
    ps5 = { name = "PlayStation 5", labels = {
        PAD1 = "Cross", PAD2 = "Circle", PAD3 = "Square", PAD4 = "Triangle", PADLSHOULDER = "L1", PADRSHOULDER = "R1",
        PADLTRIGGER = "L2", PADRTRIGGER = "R2", PADLSTICK = "L3", PADRSTICK = "R3",
        PADBACK = "Create", PADFORWARD = "Options", PADSYSTEM = "PS button", PADSOCIAL = "Touchpad",
        PADDUP = "D-pad up", PADDDOWN = "D-pad down", PADDLEFT = "D-pad left", PADDRIGHT = "D-pad right",
        PADPADDLE1 = "Fn left", PADPADDLE2 = "Fn right", PADPADDLE3 = "Back left", PADPADDLE4 = "Back right" } },
    ps3 = { name = "PlayStation 3", labels = {
        PAD1 = "Cross", PAD2 = "Circle", PAD3 = "Square", PAD4 = "Triangle", PADLSHOULDER = "L1", PADRSHOULDER = "R1",
        PADLTRIGGER = "L2", PADRTRIGGER = "R2", PADLSTICK = "L3", PADRSTICK = "R3",
        PADBACK = "Select", PADFORWARD = "Start", PADSYSTEM = "PS button", PADSOCIAL = "-",
        PADDUP = "D-pad up", PADDDOWN = "D-pad down", PADDLEFT = "D-pad left", PADDRIGHT = "D-pad right",
        PADPADDLE1 = "-", PADPADDLE2 = "-", PADPADDLE3 = "-", PADPADDLE4 = "-" } },
    switch = { name = "Nintendo Switch", labels = {
        PAD1 = "B", PAD2 = "A", PAD3 = "Y", PAD4 = "X", PADLSHOULDER = "L", PADRSHOULDER = "R",
        PADLTRIGGER = "ZL", PADRTRIGGER = "ZR", PADLSTICK = "Left stick", PADRSTICK = "Right stick",
        PADBACK = "Minus", PADFORWARD = "Plus", PADSYSTEM = "Home", PADSOCIAL = "Capture",
        PADDUP = "D-pad up", PADDDOWN = "D-pad down", PADDLEFT = "D-pad left", PADDRIGHT = "D-pad right",
        PADPADDLE1 = "SL", PADPADDLE2 = "SR", PADPADDLE3 = "-", PADPADDLE4 = "-" } },
    steam = { name = "Steam Controller", labels = {
        PAD1 = "A", PAD2 = "B", PAD3 = "X", PAD4 = "Y", PADLSHOULDER = "L1", PADRSHOULDER = "R1",
        PADLTRIGGER = "L2", PADRTRIGGER = "R2", PADLSTICK = "L-stick", PADRSTICK = "R-stick",
        PADBACK = "View", PADFORWARD = "Menu", PADSYSTEM = "Steam", PADSOCIAL = "-",
        PADDUP = "D-pad up", PADDDOWN = "D-pad down", PADDLEFT = "D-pad left", PADDRIGHT = "D-pad right",
        PADPADDLE1 = "R4", PADPADDLE2 = "L4", PADPADDLE3 = "R5", PADPADDLE4 = "L5" } },
}
local SET_ORDER = { "xbox", "ps5", "ps3", "switch", "steam" }
local SHORT = { -- shorter names for the small boxes
    PADLSTICK = "L-stick", PADRSTICK = "R-stick", PADDUP = "Up", PADDDOWN = "Down", PADDLEFT = "Left", PADDRIGHT = "Right",
    PADPADDLE1 = "Paddle 1", PADPADDLE2 = "Paddle 2", PADPADDLE3 = "Paddle 3", PADPADDLE4 = "Paddle 4",
}

local SPOTS = {
    xbox = {PADLTRIGGER = { 137, -2 }, PADLSHOULDER = { 137, 40 }, PADRTRIGGER = { 375, -2 }, PADRSHOULDER = { 375, 40 }, PADLSTICK = { 176, 84 }, PADDUP = { 218, 130 }, PADDDOWN = { 218, 162 }, PADDLEFT = { 202, 146 }, PADDRIGHT = { 234, 146 }, PADRSTICK = { 294, 146 }, PAD1 = { 338, 102 }, PAD2 = { 356, 84 }, PAD3 = { 320, 84 }, PAD4 = { 338, 66 }, PADSYSTEM = { 256, 52 }, PADBACK = { 232, 86 }, PADFORWARD = { 280, 86 }, PADSOCIAL = { 256, 106 } },
    ps5 = {PADLTRIGGER = { 133, -4 }, PADLSHOULDER = { 133, 36 }, PADRTRIGGER = { 379, -4 }, PADRSHOULDER = { 379, 36 }, PADSOCIAL = { 256, 56 }, PADBACK = { 198, 44 }, PADFORWARD = { 314, 44 }, PADDUP = { 166, 79 }, PADDDOWN = { 166, 109 }, PADDLEFT = { 151, 94 }, PADDRIGHT = { 181, 94 }, PAD1 = { 346, 112 }, PAD2 = { 364, 94 }, PAD3 = { 328, 94 }, PAD4 = { 346, 76 }, PADLSTICK = { 210, 138 }, PADRSTICK = { 302, 138 }, PADSYSTEM = { 256, 132 } },
    ps3 = {PADLTRIGGER = { 135, 8 }, PADLSHOULDER = { 135, 48 }, PADRTRIGGER = { 377, 8 }, PADRSHOULDER = { 377, 48 }, PADDUP = { 168, 81 }, PADDDOWN = { 168, 111 }, PADDLEFT = { 153, 96 }, PADDRIGHT = { 183, 96 }, PAD1 = { 344, 114 }, PAD2 = { 362, 96 }, PAD3 = { 326, 96 }, PAD4 = { 344, 78 }, PADBACK = { 234, 98 }, PADFORWARD = { 278, 98 }, PADSYSTEM = { 256, 124 }, PADLSTICK = { 212, 142 }, PADRSTICK = { 300, 142 } },
    switch = {PADLTRIGGER = { 138, 0 }, PADLSHOULDER = { 138, 42 }, PADRTRIGGER = { 374, 0 }, PADRSHOULDER = { 374, 42 }, PADLSTICK = { 176, 88 }, PADDUP = { 218, 130 }, PADDDOWN = { 218, 162 }, PADDLEFT = { 202, 146 }, PADDRIGHT = { 234, 146 }, PADRSTICK = { 294, 146 }, PAD1 = { 338, 106 }, PAD2 = { 356, 88 }, PAD3 = { 320, 88 }, PAD4 = { 338, 70 }, PADBACK = { 228, 62 }, PADFORWARD = { 284, 62 }, PADSYSTEM = { 272, 92 }, PADSOCIAL = { 240, 92 } },
    steam = {PADLSTICK = { 204, 89 }, PADRSTICK = { 308, 89 }, PADDUP = { 148, 45 }, PADDDOWN = { 148, 79 }, PADDLEFT = { 130, 62 }, PADDRIGHT = { 165, 62 }, PAD4 = { 365, 43 }, PAD3 = { 344, 64 }, PAD2 = { 385, 64 }, PAD1 = { 365, 84 }, PADBACK = { 193, 38 }, PADFORWARD = { 319, 38 }, PADSYSTEM = { 255, 63 }, PADPADDLE2 = { 144, 145 }, PADPADDLE4 = { 139, 187 }, PADPADDLE1 = { 367, 145 }, PADPADDLE3 = { 371, 187 }, PADLTRIGGER = { 158, -8 }, PADRTRIGGER = { 365, -8 }, PADLSHOULDER = { 127, 24 }, PADRSHOULDER = { 384, 24 } },
}

-- Which controller is plugged in (best guess from the device itself).
local detected, detectedName, detectedReal = "xbox", nil, nil
local hasPaddles = false
local function classify(name, vendor, product)
    local n = (name or ""):lower()
    if n:find("steam") or n:find("valve") then return "steam" end
    if type(vendor) == "number" and vendor == 10462 then return "steam" end               -- Valve
    if n:find("dualsense") or n:find("ps5") or n:find("dualshock 4") or n:find("ps4") or n:find("wireless controller") then return "ps5" end
    if n:find("dualshock 3") or n:find("ps3") or n:find("playstation%(r%)3") or n:find("playstation 3") then return "ps3" end
    if n:find("switch") or n:find("pro controller") or n:find("joy%-con") or n:find("nintendo") then return "switch" end
    if type(vendor) == "number" then
        if vendor == 1356 then return (product == 616) and "ps3" or "ps5" end              -- Sony
        if vendor == 1406 then return "switch" end                                         -- Nintendo
        if vendor == 1118 then return "xbox" end                                           -- Microsoft
    end
    if n:find("xbox") or n:find("x%-box") or n:find("xinput") then return "xbox" end
    return nil
end
API.padDevices = {}
local function detect()
    detectedName, detectedReal = nil, nil
    if not C_GamePad then return end
    -- Look at every device, not only the active one: at login nothing is "active" until a button is
    -- pressed, and Steam can show its own controller beside the virtual one it hands to games.
    local ids, seen = {}, {}
    local okA, active = pcall(function() return C_GamePad.GetActiveDeviceID and C_GamePad.GetActiveDeviceID() end)
    if okA and active ~= nil then ids[#ids + 1] = active; seen[active] = true end
    local okL, all = pcall(function() return C_GamePad.GetAllDeviceIDs and C_GamePad.GetAllDeviceIDs() end)
    if okL and type(all) == "table" then for _, id in ipairs(all) do if not seen[id] then ids[#ids + 1] = id; seen[id] = true end end end
    wipe(API.padDevices)
    local best, bestId
    for _, id in ipairs(ids) do
        local okR, raw = pcall(C_GamePad.GetDeviceRawState, id)
        if okR and type(raw) == "table" then
            local name = type(raw.name) == "string" and raw.name or nil
            local set = classify(name, raw.vendorID, raw.productID)
            API.padDevices[#API.padDevices + 1] = { id = id, name = name, vendor = raw.vendorID, product = raw.productID, set = set }
            -- A Valve device anywhere wins: with Steam's input the game may also see a plain "Xbox" pad.
            if set == "steam" or not best then
                if set or not best then best, bestId, detectedName = set, id, name end
            end
        end
    end
    if best then detected = best; detectedReal = best end
    -- Does the device hand WoW its back buttons? (Steam's default input does not.)
    hasPaddles = false
    local okM, st = pcall(C_GamePad.GetDeviceMappedState, bestId)
    if okM and type(st) == "table" and type(st.buttons) == "table" and C_GamePad.ButtonIndexToBinding then
        for i = 0, #st.buttons - 1 do
            local okB, b = pcall(C_GamePad.ButtonIndexToBinding, i)
            if okB and type(b) == "string" and b:find("PADPADDLE") then hasPaddles = true; break end
        end
    end
end

local function activeSet()
    local d = DB()
    if d.layout ~= "auto" and SETS[d.layout] then return d.layout end
    return detected
end

-- Steam sends its back buttons as keys, so L4 is F6 and L5 is Space in the game's binds. The page shows what the key does
-- under the back button's name, so L4 reads as Interact and L5 as Jump.
local STEAM_KEYS = { PADPADDLE2 = "F6", PADPADDLE4 = "SPACE" }
local function actionOf(combo)
    local act = GetBindingAction(combo)
    if act and act ~= "" then return act end
    if activeSet() == "steam" then
        local layer, key = combo:match("^(.-)([^-]+)$")
        if layer and STEAM_KEYS[key] then return GetBindingAction(layer .. STEAM_KEYS[key]) or act end
    end
    return act
end

local function padLabel(key, short)
    local L = SETS[activeSet()].labels
    if short and SHORT[key] then return SHORT[key] end
    return L[key] or key
end

----------------------------------------------------------------------
-- Gamepad on at load
----------------------------------------------------------------------
-- WoW's own gamepad settings, found by name at run time (the game names them; we only look for them).
local function padCVars()
    local out = {}
    if C_Console and C_Console.GetAllCommands then
        local ok, list = pcall(C_Console.GetAllCommands)
        if ok and type(list) == "table" then
            for _, c in ipairs(list) do
                local n = type(c) == "table" and c.command
                if type(n) == "string" and n:lower():find("gamepad") then out[#out + 1] = n end
            end
        end
    end
    table.sort(out)
    return out
end
API.padCVars = padCVars

-- Turns on WoW's gamepad interface and its button prompts, so the game shows controller buttons
-- everywhere and uses its own controller bindings.
local function enableGamepadUI()
    for _, n in ipairs(padCVars()) do
        local l = n:lower()
        local isUI = (l:find("gamepadui") or l:find("gamepad.*ui.*enable") or l:find("enable.*gamepad.*ui")) and not l:find("scale")
        local isPrompt = l:find("prompt")
        if isUI or isPrompt then
            local ok, v = pcall(GetCVar, n)
            if ok and v == "0" then pcall(SetCVar, n, "1") end
        end
    end
end

-- Start is the game's own Escape action (closes windows, clears the target, then the game menu).
local menuOpen
local function menuWanted() return "TOGGLEGAMEMENU" end

local function bindMenu()
    if InCombatLockdown() then return end
    SetBinding("PADFORWARD", menuWanted())
    pcall(SetCVar, "GamePadEmulateEsc", "NONE")
end

-- The right stick moves the mouse while a menu is open (WoW's own gamepad cursor, found by name).
local function applyCursor(on)
    for _, n in ipairs(padCVars()) do
        local l = n:lower()
        if l:find("cursor") and l:find("autoenable") then
            local ok, v = pcall(GetCVar, n)
            local want = on and "1" or "0"
            if ok and v ~= want then pcall(SetCVar, n, want) end
        end
    end
end
API.applyPadCursor = applyCursor

-- WoW keeps the gamepad cursor on for a while after a window closes, so a nudge of the right stick
-- right afterwards grabs the mouse instead of turning the camera. Once no window is open, give the stick back.
local MENU_FRAMES = { "WorldMapFrame", "GameMenuFrame", "ColorPickerFrame", "StaticPopup1", "StaticPopup2", "StaticPopup3", "StaticPopup4",
                      "GossipFrame", "QuestFrame", "MerchantFrame", "BankFrame", "MailFrame", "ChatConfigFrame", "SettingsPanel",
                      "EditModeManagerFrame", "AddonList", "ContainerFrameCombinedBags", "UbermocDialogue" }
do
    local function shown(f) return type(f) == "table" and f.IsShown and f:IsShown() end
    local NONE = {}
    function menuOpen()
        for _, n in ipairs(UISpecialFrames or NONE) do if shown(_G[n]) then return true end end
        if GetUIPanel then
            if shown(GetUIPanel("left")) or shown(GetUIPanel("center")) or shown(GetUIPanel("right")) then return true end
        end
        for _, n in ipairs(MENU_FRAMES) do
            if shown(_G[n]) then return true end
        end
        if API.win and shown(API.win) then return true end
        if SpellIsTargeting and SpellIsTargeting() then return true end
        for i = 1, 13 do if shown(_G["ContainerFrame" .. i]) then return true end end
        return false
    end
    local closedFor, acc = 0, 0
    local f = CreateFrame("Frame")
    f:SetScript("OnUpdate", function(_, dt)
        acc = acc + dt
        if acc < 0.1 then return end
        local step = acc; acc = 0
        if not (UbermocUIDB and UbermocUIDB.pad) or UbermocUIDB.pad.cursor == false then closedFor = 0; return end
        if not (IsGamePadCursorControlEnabled and SetGamePadCursorControl) then return end
        local okE, on = pcall(IsGamePadCursorControlEnabled)
        if not okE or not on then closedFor = 0; return end
        if menuOpen() then closedFor = 0; return end
        closedFor = closedFor + step
        if closedFor >= 0.2 then
            closedFor = 0
            pcall(SetGamePadCursorControl, false)
        end
    end)
end

local function enablePad()
    if not UbermocUIDB or not DB().auto then return end
    local ok, v = pcall(GetCVar, "GamePadEnable")
    if ok and v ~= "1" then pcall(SetCVar, "GamePadEnable", "1") end
    pcall(enableGamepadUI)
    pcall(applyCursor, DB().cursor ~= false)
    -- Start is the Escape key unless something else is bound to it.
    if not InCombatLockdown() then
        local cur = GetBindingAction("PADFORWARD") or ""
        if cur == "" or cur == "UBERMOCUI_MENU" or cur:find("UbermocMenu", 1, true) then
            bindMenu()
            if SaveBindings and GetCurrentBindingSet then pcall(SaveBindings, GetCurrentBindingSet()) end
        end
    end
end


-- Sticks on every controller: left stick walks in any direction (a light push walks slowly, pushing
-- past the run threshold runs) and the right stick turns the camera.
local function applyStickDefaults()
    local function set(name, value)
        local ok, cur = pcall(GetCVar, name)
        if ok and cur ~= nil and cur ~= value then pcall(SetCVar, name, value) end
    end
    set("GamePadAnalogMovement", "1")   -- move in any direction, not only 8 compass directions
    set("GamePadStickAxisButtons", "0") -- the stick moves, it is not four buttons
    set("GamePadTurnWithCamera", "1")   -- the right stick turns the character in combat
    set("GamePadCameraYawSpeed", "1")
    set("GamePadCameraPitchSpeed", "1")
    -- Walk below the run threshold and run past it (these names are only set if this game has them).
    set("GamePadRunThreshold", "0.5")
    set("GamePadStickRunThreshold", "0.5")
    set("GamePadBackPedalThreshold", "0.6")
    set("GamePadBackPedalStickThreshold", "0.6")
end

local autoSteam, charBinds, tidyBinds
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("GAME_PAD_CONNECTED")
ev:RegisterEvent("GAME_PAD_ACTIVE_CHANGED")
ev:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" or event == "GAME_PAD_CONNECTED" then
        enablePad()
        local d = DB()
        if d.auto and not d.sticksDone then d.sticksDone = true; applyStickDefaults() end
    end
    pcall(detect)
    if API.refreshController then pcall(API.refreshController) end
    if event == "PLAYER_LOGIN" or event == "GAME_PAD_CONNECTED" then
        if C_Timer and C_Timer.After then
            for _, t in ipairs({ 1, 3, 8, 15 }) do
                C_Timer.After(t, function()
                    pcall(detect); pcall(enablePad); pcall(charBinds); pcall(autoSteam); pcall(tidyBinds)
                    if API.refreshController then pcall(API.refreshController) end
                end)
            end
        end
    end
end)

----------------------------------------------------------------------
-- Binding helpers
----------------------------------------------------------------------
local EMU = { { "GamePadEmulateAlt", "ALT-", "Alt" }, { "GamePadEmulateCtrl", "CTRL-", "Ctrl" }, { "GamePadEmulateShift", "SHIFT-", "Shift" } }

local function emulatorOf(mod) -- the pad button that stands in for a keyboard modifier
    for _, e in ipairs(EMU) do
        if e[2] == mod then
            local ok, v = pcall(GetCVar, e[1])
            if ok and type(v) == "string" and v ~= "" and v:upper() ~= "NONE" and v ~= "0" then return v end
        end
    end
end

local function actionName(cmd)
    if not cmd or cmd == "" then return "Nothing" end
    if cmd == "TOGGLEGAMEMENU" then return "Game menu (Escape)" end
    local kind, what = cmd:match("^(%u+) (.+)$")
    if kind == "SPELL" then return what end
    if kind == "MACRO" then return "Macro: " .. what end
    if kind == "ITEM" then return "Item: " .. what end
    if kind == "CLICK" then
        local frame = what:match("^([^:]+)")
        local n = frame and frame:match("^ActionButton(%d+)$")
        if n then return "Action bar button " .. n end
        n = frame and frame:match("^MultiBar(%w+)Button(%d+)$")
        if n then return "Action bar button " .. frame:match("Button(%d+)$") end
        return "Button: " .. (frame or what)
    end
    return _G["BINDING_NAME_" .. cmd] or (GetBindingName and GetBindingName(cmd)) or cmd
end

-- "ALT-SHIFT-PAD1" -> "LT + RT + A" (or "Shift + ..." when no pad button stands in for the modifier).
local function keyWords(combo)
    local parts, rest = {}, combo
    for _, e in ipairs(EMU) do
        if rest:find(e[2], 1, true) == 1 then
            rest = rest:sub(#e[2] + 1)
            local pad = emulatorOf(e[2])
            parts[#parts + 1] = pad and padLabel(pad, true) or e[3]
        end
    end
    local label = rest:find("^PAD") and padLabel(rest, true) or ((GetBindingText and GetBindingText(rest)) or rest)
    if type(label) ~= "string" then label = rest end
    parts[#parts + 1] = label
    return table.concat(parts, " + ")
end

local function say(msg)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffUbermoc UI:|r " .. msg) end
end

local function saveBinds()
    if SaveBindings and GetCurrentBindingSet then pcall(SaveBindings, GetCurrentBindingSet()) end
end

-- A key listed under an action it no longer triggers. The game keeps one action per key, but the lists
-- kept for each action can hold old entries (from earlier setups or earlier layouts), so the key shows
-- under two actions in Key Bindings, "clear" on one makes it jump to the other, and the Buttons page
-- shows a pad button doing two things. Every key is looked at once: the action the game really uses for
-- it stays, the key is cleared and set again so every other list drops it. Out of combat only.
tidyBinds = function(report)
    if InCombatLockdown() or not (GetNumBindings and GetBinding and GetBindingAction and SetBinding) then return 0 end
    if API.tidyBusy then return 0 end
    API.tidyBusy = true
    local fixed = 0
    pcall(function()
        local stale, seen = {}, {}
        for i = 1, GetNumBindings() do
            local t = { GetBinding(i) }
            local cmd = t[1]
            if type(cmd) == "string" and cmd ~= "" then
                for j = 3, #t do
                    local k = t[j]
                    if type(k) == "string" and k ~= "" then
                        local real = GetBindingAction(k) or ""
                        if real ~= cmd and not seen[k .. "\0" .. cmd] then
                            seen[k .. "\0" .. cmd] = true
                            stale[k] = real
                        end
                    end
                end
            end
        end
        for k, real in pairs(stale) do
            SetBinding(k)
            if real ~= "" then SetBinding(k, real) end
            fixed = fixed + 1
        end
    end)
    API.tidyBusy = nil
    if fixed > 0 then
        saveBinds()
        if report then say("Cleaned up " .. fixed .. " button" .. (fixed == 1 and "" or "s") .. " that were listed under two actions.") end
    elseif report then
        say("No button is listed under two actions.")
    end
    return fixed
end
API.tidyBinds = function() return tidyBinds(true) end
do
    -- Again whenever the key bindings change (a moment after the last change), and after combat.
    local f, wait = CreateFrame("Frame"), false
    f:RegisterEvent("UPDATE_BINDINGS")
    f:RegisterEvent("PLAYER_REGEN_ENABLED")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:SetScript("OnEvent", function()
        if wait then return end
        wait = true
        C_Timer.After(1.5, function() wait = false; pcall(tidyBinds) end)
    end)
end

local function bind(combo, cmd)
    if InCombatLockdown() then say("Bindings cannot be changed in combat."); return false end
    local old = GetBindingAction(combo)
    if cmd then
        SetBinding(combo, cmd)
        if old and old ~= "" and old ~= cmd then say(keyWords(combo) .. " was " .. actionName(old) .. " and is now " .. actionName(cmd) .. ".") end
    else
        SetBinding(combo)
    end
    saveBinds()
    return true
end

local function padKeysOf(cmd) -- every gamepad combo bound to a command
    local out = {}
    for _, k in ipairs({ GetBindingKey(cmd) }) do
        if k:find("PAD") then out[#out + 1] = k end
    end
    return out
end

----------------------------------------------------------------------
-- Default binds
-- Four layers: nothing held, the Shift button held, the Ctrl button held, and both held. Each layer fills one
-- of the first four action bars (slots 1 2 3 4 5 6 7 8 9 0 - =), and the stick clicks that do not fit go on
-- bar 5, layer by layer. R1 targets enemies and L1 friends instead of taking a slot. A Steam Controller holds R4 for Shift and R5 for Ctrl; every other controller holds
-- the left trigger for Shift and the right trigger for Ctrl, so the triggers carry no actions there.
-- Interact and jump are on L4 and L5 (the stick clicks on a controller without back buttons).
-- Start and Select are not action buttons: Start is Escape (Shift + Start the menu wheel, Ctrl + Start the
-- bags wheel), Select is the map and auto-run is the left stick click (Shift + left stick click on other controllers). The rest with a modifier are left free to bind.
----------------------------------------------------------------------
local LAYERS = { "", "SHIFT-", "CTRL-", "CTRL-SHIFT-" }
local MAIN_BARS = { "ACTIONBUTTON", "MULTIACTIONBAR1BUTTON", "MULTIACTIONBAR2BUTTON", "MULTIACTIONBAR3BUTTON" }
-- X, A, B, Y, D-pad left / down / right / up, R1, R2, L1, L2
local STEAM_SLOTS = { "PAD3", "PAD1", "PAD2", "PAD4", "PADDLEFT", "PADDDOWN", "PADDRIGHT", "PADDUP",
                      "PADRSHOULDER", "PADRTRIGGER", "PADLSHOULDER", "PADLTRIGGER" }
local STEAM_SPILL = { "PADRSTICK" }   -- R3
-- The triggers are the modifiers, so R3 takes a slot.
local PAD_SLOTS = { "PAD3", "PAD1", "PAD2", "PAD4", "PADDLEFT", "PADDDOWN", "PADDRIGHT", "PADDUP",
                    "PADRSHOULDER", "PADLSHOULDER" }
local PAD_SPILL = {}
-- Interact and jump. A Steam Controller has L4 and L5 for them; Steam sends those as F6 and Space. A controller
-- without back buttons uses its stick clicks for the same two jobs: left stick click is L4, right stick click L5.
local STEAM_INTERACT, STEAM_JUMP = { "F6" }, { "SPACE", "PADPADDLE4" }
local PAD_INTERACT, PAD_JUMP = { "PADLSTICK" }, { "PADRSTICK" }

-- A controller key, with or without modifiers (NUMPAD keys belong to the keyboard).
local function isPadKey(key)
    local base = key:match("([^-]+)$")
    return base ~= nil and base:find("^PAD") ~= nil
end

local function clearPadBinds()
    local keys = {}
    for i = 1, GetNumBindings() do
        local t = { GetBinding(i) }
        for j = 3, #t do
            if type(t[j]) == "string" and isPadKey(t[j]) then keys[#keys + 1] = t[j] end
        end
    end
    for _, k in ipairs(keys) do SetBinding(k) end
end

-- The same on every controller and every layer: the right bumper targets the nearest enemy, the left bumper the
-- nearest friend. Their slots on the bars stay empty, so every other button keeps its slot.
local TARGET = { PADRSHOULDER = "TARGETNEARESTENEMY", PADLSHOULDER = "TARGETNEARESTFRIEND" }

local function bindLayers(slots, spill)
    local n = 0
    for li, layer in ipairs(LAYERS) do
        for key, cmd in pairs(TARGET) do SetBinding(layer .. key, cmd) end
        for i, key in ipairs(slots) do
            if not TARGET[key] then SetBinding(layer .. key, MAIN_BARS[li] .. i) end
        end
        for _, key in ipairs(spill) do
            n = n + 1
            SetBinding(layer .. key, "MULTIACTIONBAR" .. (3 + math.ceil(n / 12)) .. "BUTTON" .. ((n - 1) % 12 + 1))
        end
    end
end

local function bindRoles(interact, jump)
    for _, layer in ipairs(LAYERS) do
        for _, key in ipairs(interact) do SetBinding(layer .. key, "INTERACTTARGET") end
        for _, key in ipairs(jump) do SetBinding(layer .. key, "JUMP") end
    end
end

local function bindSystem(steam)
    bindMenu()
    SetBinding("SHIFT-PADFORWARD", "CLICK UbermocRingCMicroToggle:LeftButton")
    SetBinding("CTRL-PADFORWARD", "CLICK UbermocRingCBagToggle:LeftButton")
    SetBinding("PADBACK", "TOGGLEWORLDMAP")
    -- Auto-run is the left stick click on a Steam Controller; elsewhere that button interacts, so it is Shift + left stick click.
    SetBinding(steam and "PADLSTICK" or "SHIFT-PADLSTICK", "TOGGLEAUTORUN")
end

local function setModifiers(shift, ctrl)
    pcall(SetCVar, "GamePadEmulateShift", shift)
    pcall(SetCVar, "GamePadEmulateCtrl", ctrl)
    pcall(SetCVar, "GamePadEmulateAlt", "NONE")
end

-- Each character keeps its own key binds: the first time a character is seen on the account-wide binds, it gets
-- its own copy (so what you change here no longer shows up on your other characters), without the spell and
-- macro binds that do not belong to this character (the other class's abilities).
charBinds = function()
    if InCombatLockdown() or not GetCurrentBindingSet or not GetNumBindings then return end
    local g = UnitGUID and UnitGUID("player")
    if not g then return end
    UbermocUIDB.charBinds = UbermocUIDB.charBinds or {}
    if UbermocUIDB.charBinds[g] then return end
    UbermocUIDB.charBinds[g] = true
    if GetCurrentBindingSet() ~= 1 then return end   -- already this character's own set
    for i = 1, GetNumBindings() do
        local cmd, _, k1, k2, k3 = GetBinding(i)
        if cmd and (k1 or k2 or k3) then
            local kind, name = cmd:match("^(%u+) (.+)$")
            local drop = false
            if kind == "SPELL" then
                local ok, info = pcall(function() return C_Spell and C_Spell.GetSpellInfo(name) end)
                drop = not (ok and info)
            elseif kind == "MACRO" then
                local ok, idx = pcall(GetMacroIndexByName, name)
                drop = not (ok and idx and idx > 0)
            end
            if drop then
                for _, k in ipairs({ k1 or false, k2 or false, k3 or false }) do
                    if k then SetBinding(k) end
                end
            end
        end
    end
    if SaveBindings then pcall(SaveBindings, 2) end
end

-- Every controller but the Steam Controller: every controller bind is removed, then the left trigger
-- becomes Shift and the right trigger Ctrl.
local function applyStandardDefaults()
    if InCombatLockdown() then say("Controller binds can't be set in combat."); return false end
    clearPadBinds()
    setModifiers("PADLTRIGGER", "PADRTRIGGER")
    bindLayers(PAD_SLOTS, PAD_SPILL)
    bindRoles(PAD_INTERACT, PAD_JUMP)
    bindSystem(false)
    saveBinds()
    return true
end

-- Steam Controller: every controller bind is removed, then R4 becomes Shift and R5 Ctrl. Steam's input
-- sends the back buttons as keys (R4 = Shift, R5 = Ctrl, L4 = F6, L5 = Space). F6 is the only interact key
-- and L5 jumps (also as a paddle), on every layer.
local function applySteamDefaults()
    if InCombatLockdown() then say("Steam Controller binds can't be set in combat."); return false end
    clearPadBinds()
    setModifiers("PADPADDLE1", "PADPADDLE3")
    -- F6 is the only interact key
    for _, k in ipairs({ GetBindingKey("INTERACTTARGET") }) do SetBinding(k) end
    bindLayers(STEAM_SLOTS, STEAM_SPILL)
    bindRoles(STEAM_INTERACT, STEAM_JUMP)
    bindSystem(true)
    saveBinds()
    return true
end

-- Each character keeps its own binds, so the rebuild runs once for each character.
local function rebuilt()
    local g = UnitGUID and UnitGUID("player")
    UbermocUIDB.layoutV9 = UbermocUIDB.layoutV9 or {}
    return not g or UbermocUIDB.layoutV9[g], g
end

local function rebuild(steam)
    if not (steam and applySteamDefaults() or not steam and applyStandardDefaults()) then return false end
    local _, g = rebuilt()
    if g then UbermocUIDB.layoutV9[g] = true end
    DB().padDefaults = steam and "steam" or "standard"
    return true
end

autoSteam = function()
    if InCombatLockdown() or not detectedReal or rebuilt() then return end
    local steam = detectedReal == "steam" or activeSet() == "steam"
    if rebuild(steam) then
        say((steam and "Steam Controller" or "Controller") .. ": old binds removed and the new layout set. Change anything on Controller > Buttons.")
    end
end

----------------------------------------------------------------------
-- The page
----------------------------------------------------------------------
local panel = CreateFrame("Frame")
panel.name = "Controller"
panel:Hide()

local refreshAll
API.refreshController = function() if panel:IsShown() and refreshAll then refreshAll() end end

local selected = "PAD1"
local popOpen = false

local function build()
    API.newLabel(panel, "Buttons", 16, -16, "GameFontNormalHuge")
    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 8, -52)
    scroll:SetPoint("BOTTOMRIGHT", -30, 44)
    local sc = CreateFrame("Frame", nil, scroll)
    sc:SetSize(560, 1354)
    scroll:SetScrollChild(sc)

    -- Header: what is plugged in and which layout is drawn
    local found = API.newLabel(sc, "", 8, -4, "GameFontHighlight")
    found:SetWidth(540); found:SetJustifyH("LEFT")
    API.newLabel(sc, "Layout shown", 8, -38)
    local layoutList = { { "auto", "Automatic" } }
    for _, id in ipairs(SET_ORDER) do layoutList[#layoutList + 1] = { id, SETS[id].name } end
    local layoutBtn = API.cycler(sc, 150, -34, 124, function()
        layoutList[1][2] = "Auto: " .. ((detected and SETS[detected] and SETS[detected].name) or "?")
        return layoutList
    end, function() return DB().layout or "auto" end, function(v) DB().layout = v; refreshAll() end)
    local rebuildBtn
    rebuildBtn = API.newButton(sc, "Rebuild binds", 140, 200, -102, function()
        local steam = activeSet() == "steam"
        if not rebuildBtn.armed then
            rebuildBtn.armed = true
            rebuildBtn:SetText("Click again")
            C_Timer.After(4, function() rebuildBtn.armed = false; rebuildBtn:SetText("Rebuild binds") end)
            return
        end
        rebuildBtn.armed = false
        rebuildBtn:SetText("Rebuild binds")
        if rebuild(steam) then say("Controller binds rebuilt."); refreshAll() end
    end)
    API.newButton(sc, "Sticks: walk, run, camera", 170, 382, -34, function()
        applyStickDefaults()
        say("Left stick walks and runs in any direction, right stick turns the camera.")
    end)
    -- Button test: shows exactly what the game receives for each press (with any modifier held) and what that
    -- is bound to, so a wrong bind and a controller that sends something else can be told apart.
    API.newButton(sc, "Test my buttons", 140, 200, -68, function()
        if API.openButtonTest then API.openButtonTest() end
    end)
    API.newButton(sc, "Clean up doubled binds", 170, 348, -68, function()
        if InCombatLockdown() then say("Not in combat."); return end
        API.tidyBinds()
        if refreshAll then pcall(refreshAll) end
    end)
    local autoCB = API.newCheck(sc, "Gamepad on at load", 8, -70, function(v)
        DB().auto = v
        if v then enablePad() end
    end)

    -- Controller picture ---------------------------------------------------------------------------
    -- The controller is drawn; a dot sits on every button, and a label with its action is joined to the
    -- dot by a line. Click a dot or a label to pick that button.
    local tip = CreateFrame("Frame", nil, sc)
    tip:SetPoint("TOPLEFT", 8, -138)
    tip:SetSize(540, 72)
    local tipBg = tip:CreateTexture(nil, "BACKGROUND")
    tipBg:SetAllPoints()
    tipBg:SetColorTexture(API.accent[1], API.accent[2], API.accent[3], 0.14)
    local tipEdge = tip:CreateTexture(nil, "BORDER")
    tipEdge:SetPoint("TOPLEFT"); tipEdge:SetPoint("BOTTOMLEFT"); tipEdge:SetWidth(3)
    tipEdge:SetColorTexture(API.accent[1], API.accent[2], API.accent[3], 1)
    local tipText = tip:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    tipText:SetPoint("TOPLEFT", 12, -6); tipText:SetPoint("BOTTOMRIGHT", -8, 6)
    tipText:SetJustifyH("LEFT"); tipText:SetJustifyV("MIDDLE"); tipText:SetWordWrap(true)
    tipText:SetText("|cffffd100Steam back buttons:|r Steam's default input does not pass L4, L5, R4 and R5 to WoW. In Steam's controller settings for WoW set R4 = Left Shift, R5 = Left Ctrl, L4 = F6 and L5 = Space. Start WoW from Steam (as a non-Steam game).")
    tip:Hide()
    local top = -220
    local STAGE_H = 330
    local ART_W, ART_H = 340, 170
    local ARTS = ART_W / 512
    local artX = (540 - ART_W) / 2
    local artY = top - (STAGE_H - ART_H) / 2
    local art = sc:CreateTexture(nil, "ARTWORK")
    art:SetSize(ART_W, ART_H)
    art:SetPoint("TOPLEFT", artX, artY)
    local PILL_W, PILL_H = 118, 34
    local dots, pills = {}, {}
    -- The dots, labels and lines are made later (the first time the page shows). They live in one box, made now, so the
    -- tabs can hide them together with the Layout tab.
    local stageBox = CreateFrame("Frame", nil, sc)
    stageBox:SetPoint("TOPLEFT", sc, "TOPLEFT", 0, 0)
    stageBox:SetSize(560, 40)
    -- The triggers sit behind the shoulder buttons, so the pictures get a bump drawn above each one.
    local trigTex = {}
    for i = 1, 2 do
        local t = sc:CreateTexture(nil, "ARTWORK", nil, -2)
        t:SetTexture("Interface\\AddOns\\UbermocUI\\Media\\pad_trigger.tga")
        t:SetSize(60 * ARTS, 30 * ARTS)
        trigTex[i] = t
    end
    local function getDot(key)
        local d = dots[key]
        if d then return d end
        d = CreateFrame("Button", nil, stageBox)
        d:SetSize(22, 22)
        d:SetFrameLevel(sc:GetFrameLevel() + 6)
        d.halo = d:CreateTexture(nil, "BACKGROUND")
        d.halo:SetTexture("Interface\\AddOns\\UbermocUI\\Media\\disc.tga")
        d.halo:SetAllPoints()
        d.core = d:CreateTexture(nil, "ARTWORK")
        d.core:SetTexture("Interface\\AddOns\\UbermocUI\\Media\\disc.tga")
        d.core:SetSize(11, 11)
        d.core:SetPoint("CENTER")
        d.ring = d:CreateTexture(nil, "BORDER")
        d.ring:SetTexture("Interface\\AddOns\\UbermocUI\\Media\\disc.tga")
        d.ring:SetSize(19, 19)
        d.ring:SetPoint("CENTER")
        d.ring:SetVertexColor(1, 0.82, 0)
        d:SetScript("OnClick", function() selected = key; popOpen = true; refreshAll() end)
        d:SetScript("OnEnter", function(self)
            if GameTooltip then
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:SetText(padLabel(key))
                GameTooltip:Show()
            end
        end)
        d:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        dots[key] = d
        return d
    end
    local function getPill(key)
        local p = pills[key]
        if p then return p end
        p = CreateFrame("Button", nil, stageBox)
        p:SetSize(PILL_W, PILL_H)
        API.flatButton(p)
        p.name = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        p.name:SetPoint("TOP", 0, -4)
        p.name:SetWidth(PILL_W - 8)
        p.act = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        p.act:SetPoint("BOTTOM", 0, 4)
        p.act:SetWidth(PILL_W - 8)
        p.act:SetWordWrap(false)
        p.sel = p:CreateTexture(nil, "OVERLAY")
        p.sel:SetAllPoints()
        p.sel:SetColorTexture(API.accent[1], API.accent[2], API.accent[3], 0.28)
        p.line = stageBox:CreateLine(nil, "ARTWORK")
        p.line:SetThickness(1.5)
        p.line:SetColorTexture(0.42, 0.5, 0.7, 0.75)
        p.line2 = stageBox:CreateLine(nil, "ARTWORK")
        p.line2:SetThickness(1.5)
        p.line2:SetColorTexture(0.42, 0.5, 0.7, 0.75)
        p:SetScript("OnClick", function() selected = key; popOpen = true; refreshAll() end)
        pills[key] = p
        return p
    end
    local function layoutStage(setId)
        art:SetTexture("Interface\\AddOns\\UbermocUI\\Media\\pad_" .. setId .. ".tga")
        local spots = SPOTS[setId] or {}
        for i, key in ipairs({ "PADLTRIGGER", "PADRTRIGGER" }) do
            local pt, t = spots[key], trigTex[i]
            t:ClearAllPoints()
            if pt then
                t:SetPoint("CENTER", sc, "TOPLEFT", artX + pt[1] * ARTS, artY - (pt[2] + 1) * ARTS)
                t:Show()
            else
                t:Hide()
            end
        end
        local left, right = {}, {}
        for key, d in pairs(dots) do d:Hide() end
        for key, p in pairs(pills) do p:Hide(); p.line:Hide(); p.line2:Hide() end
        for key, pt in pairs(spots) do
            local d = getDot(key)
            d:ClearAllPoints()
            d:SetPoint("CENTER", sc, "TOPLEFT", artX + pt[1] * ARTS, artY - pt[2] * ARTS)
            local emuMod
            for _, e in ipairs(EMU) do if emulatorOf(e[2]) == key then emuMod = e[3] end end
            -- The button WoW uses as Escape (its "emulate Escape" setting) is shown as such.
            local okE, escKey = pcall(GetCVar, "GamePadEmulateEsc")
            if not emuMod and okE and escKey == key then emuMod = "Escape" end
            local act = actionOf(key)
            local bound = act and act ~= ""
            local col = emuMod and { 0.45, 0.62, 1 } or (bound and { API.accent[1], API.accent[2], API.accent[3] }) or { 0.5, 0.54, 0.64 }
            d.core:SetVertexColor(col[1], col[2], col[3])
            d.halo:SetVertexColor(col[1], col[2], col[3])
            d.halo:SetAlpha((bound or emuMod) and 0.4 or 0.12)
            d.ring:SetShown(key == selected)
            d:Show()
            -- The triggers always get a label, so they can be seen and picked even with nothing bound.
            if bound or emuMod or key == selected or key == "PADLTRIGGER" or key == "PADRTRIGGER" then
                local list = (pt[1] < 256) and left or right
                list[#list + 1] = { key = key, x = pt[1], y = pt[2], act = act, emu = emuMod, bound = bound }
            end
        end
        local function place(list, isLeft)
            table.sort(list, function(a, b) if a.y ~= b.y then return a.y < b.y end return a.x < b.x end)
            local n = #list
            local spacing = math.min(PILL_H + 6, (STAGE_H - 10) / math.max(n, 1))
            for i, e in ipairs(list) do
                local p = getPill(e.key)
                local cy = top - STAGE_H / 2 - (i - (n + 1) / 2) * spacing
                p:ClearAllPoints()
                p:SetPoint("CENTER", sc, "TOPLEFT", isLeft and (PILL_W / 2) or (540 - PILL_W / 2), cy)
                p.name:SetText(padLabel(e.key, true))
                p.act:SetText(e.emu == "Escape" and "|cff9fb4ffEscape|r" or e.emu and "|cff9fb4ffmodifier|r" or (e.bound and actionName(e.act) or "|cff888888Nothing|r"))
                p.sel:SetShown(e.key == selected)
                p:Show()
                -- flat out of the label, then straight to the dot
                local stub = isLeft and 14 or -14
                p.line:ClearAllPoints()
                p.line:SetStartPoint(isLeft and "RIGHT" or "LEFT", p)
                p.line:SetEndPoint(isLeft and "RIGHT" or "LEFT", p, stub, 0)
                p.line:Show()
                p.line2:ClearAllPoints()
                p.line2:SetStartPoint(isLeft and "RIGHT" or "LEFT", p, stub, 0)
                p.line2:SetEndPoint("CENTER", dots[e.key])
                p.line2:Show()
            end
        end
        place(left, true)
        place(right, false)
    end
    local note = API.newLabel(sc, "Click a dot or a label to change what that button does. Lit dots already do something. Left stick: walk (light push) or run (push further). Right stick: camera.", 8, top - STAGE_H - 4, "GameFontHighlightSmall")
    note:SetWidth(540); note:SetJustifyH("LEFT")

    -- Editor for the selected button: a pop-up beside the button's label on the picture, with a
    -- row for the button on its own and one for each modifier layer.
    local POP_W = 470
    local pop = CreateFrame("Frame", nil, panel)
    pop:SetSize(POP_W, 200)
    pop:SetFrameStrata("DIALOG")
    pop:SetFrameLevel(5)
    pop:SetClampedToScreen(true)
    pop:EnableMouse(true)
    pop:Hide()
    do
        local rim = pop:CreateTexture(nil, "BACKGROUND", nil, -2)
        rim:SetPoint("TOPLEFT", -2, 2); rim:SetPoint("BOTTOMRIGHT", 2, -2)
        rim:SetColorTexture(API.accent[1], API.accent[2], API.accent[3], 0.9)
        local bgp = pop:CreateTexture(nil, "BACKGROUND", nil, -1)
        bgp:SetAllPoints(); bgp:SetColorTexture(0.07, 0.08, 0.11, 0.98)
    end
    local edTitle = API.newLabel(pop, "", 12, -10, "GameFontNormalLarge")
    API.newButton(pop, "X", 30, POP_W - 38, -6, function() popOpen = false; pop:Hide(); refreshAll() end)
    local edNote = API.newLabel(pop, "", 12, -36, "GameFontHighlightSmall")
    edNote:SetWidth(POP_W - 24); edNote:SetJustifyH("LEFT"); edNote:SetWordWrap(true)
    local rows = {}
    local picker
    for i = 1, 8 do
        local r = {}
        local y = -64 - (i - 1) * 36
        r.label = API.newLabel(pop, "", 12, y - 4)
        r.label:SetWidth(140); r.label:SetJustifyH("LEFT"); r.label:SetWordWrap(false)
        r.act = API.newLabel(pop, "", 156, y - 4, "GameFontHighlight")
        r.act:SetWidth(170); r.act:SetJustifyH("LEFT"); r.act:SetWordWrap(false)
        r.change = API.newButton(pop, "Change", 70, 330, y, function() if picker and r.combo then picker.open(r.combo) end end)
        r.clear = API.newButton(pop, "Clear", 56, 404, y, function()
            if r.combo and bind(r.combo, nil) then refreshAll() end
        end)
        rows[i] = r
    end
    pop:SetScript("OnHide", function() popOpen = false end)
    panel:HookScript("OnHide", function() pop:Hide() end)
    local function placePop(n)
        pop:SetHeight(64 + n * 36 + 6)
        local p = pills[selected]
        local anchorF = (p and p:IsShown()) and p or dots[selected]
        if not anchorF then pop:Hide(); return end
        pop:ClearAllPoints()
        local _, _, _, ax = anchorF:GetPoint(1)
        local onLeft = p and p:IsShown() and type(ax) == "number" and ax < 270
        if onLeft then pop:SetPoint("TOPLEFT", anchorF, "TOPRIGHT", 8, 0)
        else pop:SetPoint("TOPRIGHT", anchorF, "TOPLEFT", -8, 0) end
        pop:Show()
    end

    -- By bar ---------------------------------------------------------------------------------
    local by = top - STAGE_H - 44
    API.newLabel(sc, "Binds by action bar", 8, by, "GameFontNormalLarge")
    local BARS = {
        { "Main bar", "ACTIONBUTTON%d" }, { "Bottom left bar", "MULTIACTIONBAR1BUTTON%d" },
        { "Bottom right bar", "MULTIACTIONBAR2BUTTON%d" }, { "Right bar", "MULTIACTIONBAR3BUTTON%d" },
        { "Right bar 2", "MULTIACTIONBAR4BUTTON%d" }, { "Action bar 5", "MULTIACTIONBAR5BUTTON%d" },
        { "Action bar 6", "MULTIACTIONBAR6BUTTON%d" }, { "Action bar 7", "MULTIACTIONBAR7BUTTON%d" },
    }
    local barIdx = 1
    local barList = {}
    for i, b in ipairs(BARS) do barList[i] = { i, b[1] } end
    local barBtn = API.cycler(sc, 150, by - 38, 160, function() return barList end, function() return barIdx end,
        function(v) barIdx = v; refreshAll() end)
    API.newLabel(sc, "Bar", 8, by - 42)
    local barRows = {}
    local capture
    for i = 1, 12 do
        local r = {}
        local y = by - 84 - (i - 1) * 34
        r.label = API.newLabel(sc, "", 20, y - 4)
        r.keys = API.newLabel(sc, "", 200, y - 4, "GameFontHighlight")
        r.keys:SetWidth(190); r.keys:SetJustifyH("LEFT"); r.keys:SetWordWrap(false)
        r.set = API.newButton(sc, "Set", 60, 400, y, function() capture(r.cmd) end)
        r.clear = API.newButton(sc, "Clear", 60, 466, y, function()
            if InCombatLockdown() then say("Bindings cannot be changed in combat."); return end
            for _, k in ipairs(padKeysOf(r.cmd)) do SetBinding(k) end
            saveBinds()
            refreshAll()
        end)
        barRows[i] = r
    end
    local ry = by - 84 - 12 * 34 - 16
    local resetBtn
    local armed
    resetBtn = API.newButton(sc, "Reset all key binds to Blizzard's defaults", 300, 8, ry, function()
        if InCombatLockdown() then say("Bindings cannot be changed in combat."); return end
        if not armed then
            armed = true
            resetBtn:SetText("Click again to reset every key bind")
            C_Timer.After(5, function() armed = false; resetBtn:SetText("Reset all key binds to Blizzard's defaults") end)
            return
        end
        armed = false
        resetBtn:SetText("Reset all key binds to Blizzard's defaults")
        if LoadBindings and DEFAULT_BINDINGS then pcall(LoadBindings, DEFAULT_BINDINGS) end
        saveBinds()
        refreshAll()
    end)
    API.newButton(sc, "Show controller details in chat", 230, 318, ry, function()
        pcall(detect)
        say("Controllers the game reports (" .. #API.padDevices .. "):")
        for _, dv in ipairs(API.padDevices) do
            say(("  %s  vendor %s  product %s  -> %s"):format(tostring(dv.name), tostring(dv.vendor), tostring(dv.product), dv.set and SETS[dv.set].name or "unknown"))
        end
        say("Back buttons reach WoW directly: " .. (hasPaddles and "yes" or "no"))
        local parts = {}
        for _, n in ipairs(API.padCVars()) do
            local ok, v = pcall(GetCVar, n)
            parts[#parts + 1] = n .. "=" .. tostring(ok and v or "?")
        end
        say("Gamepad settings: " .. (#parts > 0 and table.concat(parts, ", ") or "none listed"))
    end)
    local rn = API.newLabel(sc, "This puts every key and button bind (keyboard too) back to the ones the game ships with, starting with the main action bar.", 8, ry - 34, "GameFontHighlightSmall")
    rn:SetWidth(540); rn:SetJustifyH("LEFT"); rn:SetWordWrap(true)
    sc:SetHeight(-(ry - 60) + 8)
    API.makeTabs(panel, scroll, sc, { { "Layout", 0 }, { "Binds by bar", by + 8 }, { "More", ry + 10 } }, -52)

    -- Press-a-button dialog -------------------------------------------------------------------------
    -- A dimmed page with a centred dialog: what you are binding, live chips for the buttons you are
    -- holding, a countdown cancel button, and a replace / keep question when the button is taken.
    local cap = CreateFrame("Frame", nil, panel)
    cap:SetAllPoints(panel)
    cap:SetFrameStrata("DIALOG")
    cap:SetFrameLevel(60)
    cap:EnableMouse(true)
    cap:Hide()
    local capBg = cap:CreateTexture(nil, "BACKGROUND")
    capBg:SetAllPoints()
    capBg:SetColorTexture(0, 0, 0, 0.72)
    local dlg = CreateFrame("Frame", nil, cap)
    dlg:SetSize(440, 250)
    dlg:SetPoint("CENTER", 0, 10)
    local drim = dlg:CreateTexture(nil, "BACKGROUND", nil, -2)
    drim:SetPoint("TOPLEFT", -2, 2); drim:SetPoint("BOTTOMRIGHT", 2, -2)
    drim:SetColorTexture(API.accent[1], API.accent[2], API.accent[3], 0.9)
    local dbg = dlg:CreateTexture(nil, "BACKGROUND", nil, -1)
    dbg:SetAllPoints()
    dbg:SetColorTexture(0.07, 0.08, 0.11, 0.99)
    local dHead = dlg:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    dHead:SetPoint("TOP", 0, -18)
    local dTitle = dlg:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    dTitle:SetPoint("TOP", dHead, "BOTTOM", 0, -6)
    dTitle:SetWidth(400); dTitle:SetWordWrap(false)
    local dChipsHolder = CreateFrame("Frame", nil, dlg)
    dChipsHolder:SetSize(400, 44)
    dChipsHolder:SetPoint("TOP", dTitle, "BOTTOM", 0, -22)
    local waiting = dChipsHolder:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    waiting:SetPoint("CENTER")
    waiting:SetText("Waiting for input...")
    local chips, plusSigns = {}, {}
    for i = 1, 4 do
        local c = CreateFrame("Frame", nil, dChipsHolder)
        c:SetSize(84, 38)
        c.rim = c:CreateTexture(nil, "BACKGROUND", nil, -2); c.rim:SetAllPoints()
        c.bg = c:CreateTexture(nil, "BACKGROUND", nil, -1)
        c.bg:SetPoint("TOPLEFT", 1, -1); c.bg:SetPoint("BOTTOMRIGHT", -1, 1)
        c.text = c:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        c.text:SetPoint("CENTER")
        c:Hide()
        chips[i] = c
        local p = dChipsHolder:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        p:SetText("+"); p:Hide()
        plusSigns[i] = p
    end
    local dWith = dlg:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dWith:SetPoint("BOTTOM", dChipsHolder, "TOP", 0, 4)
    dWith:SetTextColor(0.7, 0.75, 0.9)
    dWith:Hide()
    local dHint = dlg:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dHint:SetPoint("TOP", dChipsHolder, "BOTTOM", 0, -14)
    dHint:SetWidth(400)
    local dCancel = API.newButton(dlg, "", 170, 135, -200, function() end)
    dCancel:SetHeight(36)
    local dReplace = API.newButton(dlg, "Replace", 150, 60, -200, function() end)
    dReplace:SetHeight(36)
    local dKeep = API.newButton(dlg, "Keep it", 150, 230, -200, function() end)
    dKeep:SetHeight(36)

    local capCmd, order, onCommit
    local mode, timeLeft = nil, 0
    local TIME = { listen = 6, ask = 25 }
    local function paintChips()
        local n = #order
        waiting:SetShown(n == 0 and mode == "listen")
        local total = n * 84 + math.max(0, n - 1) * 26
        local x = (400 - total) / 2
        for i = 1, 4 do
            local c, p = chips[i], plusSigns[i]
            c:SetWidth(84); c.text:SetWidth(0)
            if i <= n then
                local isLast = (i == n and n > 0)
                c:ClearAllPoints(); c:SetPoint("LEFT", dChipsHolder, "LEFT", x, 0)
                c.text:SetText(order[i].label)
                local col = order[i].mod and { 0.35, 0.58, 1 } or { 1, 0.82, 0 }
                c.rim:SetColorTexture(col[1], col[2], col[3], 1)
                c.bg:SetColorTexture(0.12, 0.14, 0.2, 1)
                c:Show()
                x = x + 84
                if i < n then
                    p:ClearAllPoints(); p:SetPoint("LEFT", dChipsHolder, "LEFT", x + 6, 0); p:Show()
                    x = x + 26
                else p:Hide() end
            else
                c:Hide(); p:Hide()
            end
        end
    end
    local function closeDialog(commit)
        if cap:GetParent() == UIParent then
            cap:SetParent(panel); cap:ClearAllPoints(); cap:SetAllPoints(panel)
            cap:SetFrameStrata("DIALOG"); cap:SetFrameLevel(60)
            -- the interface cursor was put away for the dialog: bring it back
            if API.cursorActivate then C_Timer.After(0.3, API.cursorActivate) end
        end
        cap:Hide()
        cap:EnableKeyboard(false)
        pcall(cap.EnableGamePadButton, cap, false)
        mode = nil
        capCmd = nil
        refreshAll()
    end
    local function setMode(m)
        mode = m
        timeLeft = TIME[m]
        dReplace:SetShown(m == "ask"); dKeep:SetShown(m == "ask")
        dCancel:SetShown(m == "listen")
        dWith:SetShown(m == "ask")
        dHint:SetText(m == "listen" and "Hold a modifier button first to bind a combination. Escape cancels." or "")
    end
    dCancel:SetScript("OnClick", function() closeDialog() end)
    dKeep:SetScript("OnClick", function() closeDialog() end)
    cap:SetScript("OnUpdate", function(self, dt)
        if not mode then return end
        timeLeft = timeLeft - dt
        if timeLeft <= 0 then closeDialog(); return end
        if mode == "listen" then
            dCancel:SetText("Cancel (" .. math.ceil(timeLeft) .. ")")
            waiting:SetAlpha(0.55 + 0.45 * math.sin(GetTime() * 4))
        else
            dKeep:SetText("Keep it  [" .. padLabel("PAD2", true) .. "]  " .. math.ceil(timeLeft))
        end
    end)

    local function askOrBind(combo, cmd, exclusive)
        capCmd = cmd
        local old = GetBindingAction(combo)
        if old and old ~= "" and old ~= cmd then
            -- the button is taken: ask first
            if not cap:IsShown() then cap:Show() end
            cap:EnableKeyboard(true)
            pcall(cap.EnableGamePadButton, cap, true)
            setMode("ask")
            dHead:SetText(keyWords(combo) .. " is already")
            dTitle:SetText(actionName(old))
            order = { { label = actionName(cmd), mod = true } }
            paintChips()
            dWith:SetText("Replace it with")
            chips[1]:SetWidth(380)
            chips[1]:ClearAllPoints(); chips[1]:SetPoint("CENTER", dChipsHolder, "CENTER", 0, 0)
            chips[1].text:SetWidth(360); chips[1].text:SetWordWrap(false)
            dReplace:SetText("Replace  [" .. padLabel("PAD1", true) .. "]")
            dReplace:SetScript("OnClick", function()
                if InCombatLockdown() then
                    say("Bindings cannot be changed in combat.")
                else
                    if exclusive then for _, k in ipairs(padKeysOf(cmd)) do SetBinding(k) end end
                    SetBinding(combo, cmd)
                    saveBinds()
                end
                closeDialog()
            end)
            return
        end
        if exclusive then for _, k in ipairs(padKeysOf(cmd)) do SetBinding(k) end end
        bind(combo, cmd)
        closeDialog()
    end
    local function commit(combo) askOrBind(combo, capCmd, true) end
    API.askBind = askOrBind
    capture = function(cmd)
        if InCombatLockdown() then say("Bindings cannot be changed in combat."); return end
        capCmd, order = cmd, {}
        for i = 1, 4 do chips[i]:SetWidth(84) end
        setMode("listen")
        dHead:SetText("Set a button for")
        dTitle:SetText(actionName(cmd))
        paintChips()
        cap:Show()
        cap:EnableKeyboard(true)
        cap:EnableGamePadButton(true)
    end
    -- Also used from the spellbook (Bind): the same dialog, shown over the whole screen.
    API.captureBind = function(cmd)
        if cap:GetParent() ~= UIParent then
            cap:SetParent(UIParent); cap:ClearAllPoints(); cap:SetAllPoints(UIParent)
            cap:SetFrameStrata("FULLSCREEN_DIALOG"); cap:SetFrameLevel(400)
        end
        capture(cmd)
    end
    cap:SetScript("OnKeyDown", function(self, key)
        if not InCombatLockdown() then self:SetPropagateKeyboardInput(false) end
        if key == "ESCAPE" then closeDialog(); return end
        if mode == "ask" then
            if key == "ENTER" then dReplace:Click() end
            return
        end
        if mode ~= "listen" then return end
        if key:find("^[LR]?SHIFT$") or key:find("^[LR]?CTRL$") or key:find("^[LR]?ALT$") then return end
        local combo = (IsAltKeyDown() and "ALT-" or "") .. (IsControlKeyDown() and "CTRL-" or "") .. (IsShiftKeyDown() and "SHIFT-" or "") .. key
        commit(combo)
    end)
    cap:SetScript("OnGamePadButtonDown", function(_, key)
        if mode == "ask" then
            -- the question can be answered with the controller: A replaces, B keeps what was there
            if key == "PAD1" then dReplace:Click() elseif key == "PAD2" then closeDialog() end
            return
        end
        if mode ~= "listen" then return end
        for _, o in ipairs(order) do if o.key == key then return end end
        order[#order + 1] = { key = key, label = padLabel(key, true) }
        timeLeft = TIME.listen
        -- everything before the last press is a modifier if the game uses it as one
        for i, o in ipairs(order) do
            o.mod = false
            for _, e in ipairs(EMU) do if emulatorOf(e[2]) == o.key and i < #order then o.mod = true end end
        end
        paintChips()
    end)
    cap:SetScript("OnGamePadButtonUp", function()
        if mode ~= "listen" or #order == 0 then return end
        local last = order[#order].key
        local prefix = ""
        for i = 1, #order - 1 do
            for _, e in ipairs(EMU) do
                if emulatorOf(e[2]) == order[i].key and not prefix:find(e[2], 1, true) then prefix = prefix .. e[2] end
            end
        end
        local canon = (prefix:find("ALT%-") and "ALT-" or "") .. (prefix:find("CTRL%-") and "CTRL-" or "") .. (prefix:find("SHIFT%-") and "SHIFT-" or "")
        commit(canon .. last)
    end)

    -- Action picker -------------------------------------------------------------------------------
    -- Opens beside the button's pop-up. One list with collapsible sections: game panels, spells, mounts,
    -- usable items, macros, then every action the game has a key binding for.
    local PW, PH = 470, 470
    picker = CreateFrame("Frame", nil, panel)
    picker:SetSize(PW, PH)
    picker:SetPoint("CENTER", 0, 0)
    picker:SetFrameStrata("DIALOG")
    picker:SetFrameLevel(40)
    picker:SetClampedToScreen(true)
    picker:EnableMouse(true)
    picker:Hide()
    local pbg = picker:CreateTexture(nil, "BACKGROUND")
    pbg:SetAllPoints()
    pbg:SetColorTexture(0.07, 0.08, 0.11, 0.98)
    local prim = picker:CreateTexture(nil, "BACKGROUND", nil, -1)
    prim:SetPoint("TOPLEFT", -2, 2); prim:SetPoint("BOTTOMRIGHT", 2, -2)
    prim:SetColorTexture(API.accent[1], API.accent[2], API.accent[3], 0.9)
    local ptitle = picker:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    ptitle:SetPoint("TOPLEFT", 14, -12)
    ptitle:SetWidth(PW - 120); ptitle:SetJustifyH("LEFT"); ptitle:SetWordWrap(false)
    API.newButton(picker, "Cancel", 80, PW - 94, -8, function() picker:Hide() end)
    local layoutPicker
    local pscroll = CreateFrame("ScrollFrame", nil, picker, "UIPanelScrollFrameTemplate")
    pscroll:SetPoint("TOPLEFT", 10, -44)
    pscroll:SetPoint("BOTTOMRIGHT", -30, 10)
    local pchild = CreateFrame("Frame", nil, pscroll)
    pchild:SetSize(PW - 50, 100)
    pscroll:SetScrollChild(pchild)

    -- The game's own windows and panels (only the ones this client knows are listed).
    local PANELS = {
        "DISMOUNT", "TOGGLEGAMEMENU", "TOGGLECHARACTER0", "TOGGLESPELLBOOK", "TOGGLETALENTS", "TOGGLEPROFESSIONBOOK",
        "OPENALLBAGS", "TOGGLEBACKPACK", "TOGGLEWORLDMAP", "TOGGLEQUESTLOG", "TOGGLEACHIEVEMENT",
        "TOGGLECOLLECTIONS", "TOGGLECOLLECTIONSMOUNTJOURNAL", "TOGGLECOLLECTIONSPETJOURNAL", "TOGGLECOLLECTIONSTOYBOX",
        "TOGGLECOLLECTIONSHEIRLOOM", "TOGGLECOLLECTIONSWARDROBE", "TOGGLEGROUPFINDER", "TOGGLELFGPARENT",
        "TOGGLEENCOUNTERJOURNAL", "TOGGLEGUILDTAB", "TOGGLESOCIAL", "TOGGLEFRIENDSTAB", "TOGGLECHANNELPULLOUT",
        "TOGGLECALENDAR", "TOGGLEPLAYERSPELLSFRAME", "TOGGLEGARRISONLANDINGPAGE", "TOGGLEDUNGEONSANDRAIDS",
        "TOGGLEPVP", "TOGGLEAUTORUN", "TOGGLEUI", "TOGGLEMINIMAP", "TOGGLEBATTLEFIELDMINIMAP", "TOGGLEWORLDSTATESCORES",
        "TOGGLEPETBOOK", "TOGGLEMACROS", "TOGGLEKEYRING", "TOGGLESTATISTICS", "TOGGLETEXTTOSPEECH",
        "TOGGLEQUICKKEYBINDMODE", "SCREENSHOT", "TOGGLEMOUSE", "TOGGLEACTIONBARLOCK",
    }
    local function known(cmd)
        if _G["BINDING_NAME_" .. cmd] then return true end
        local n = GetNumBindings and GetNumBindings() or 0
        for i = 1, n do if GetBinding(i) == cmd then return true end end
        return false
    end
    local knownPanels
    local function panelEntries()
        if not knownPanels then
            knownPanels = {}
            for _, c in ipairs(PANELS) do if known(c) then knownPanels[#knownPanels + 1] = c end end
        end
        local out = { { header = "Windows and panels" } }
        for _, c in ipairs(knownPanels) do out[#out + 1] = { text = actionName(c), cmd = c } end
        return out
    end

    local BANK = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
    local ITYPE = Enum and Enum.SpellBookItemType or {}
    local function spellEntries()
        local out = {}
        local SB = C_SpellBook
        if not (SB and SB.GetNumSpellBookSkillLines) then return { { header = "The spell book can't be read on this client." } } end
        for line = 1, SB.GetNumSpellBookSkillLines() do
            local info = SB.GetSpellBookSkillLineInfo(line)
            if info and not info.shouldHide and (not info.offSpecID or info.offSpecID == 0) then
                out[#out + 1] = { header = info.name }
                for i = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
                    local okT, itemType, actionID, spellID = pcall(SB.GetSpellBookItemType, i, BANK)
                    local passive = SB.IsSpellBookItemPassive and SB.IsSpellBookItemPassive(i, BANK)
                    if okT and not passive then
                        if itemType == ITYPE.Flyout and GetFlyoutInfo then
                            local _, _, slots, isKnown = GetFlyoutInfo(actionID)
                            for f = 1, (slots or 0) do
                                local sid, _, fk = GetFlyoutSlotInfo(actionID, f)
                                local nm = sid and C_Spell.GetSpellName(sid)
                                if fk and nm and not C_Spell.IsSpellPassive(sid) then
                                    out[#out + 1] = { text = nm, icon = C_Spell.GetSpellTexture(sid), cmd = "SPELL " .. nm, spell = sid }
                                end
                            end
                        elseif itemType == ITYPE.Spell then
                            local nm = SB.GetSpellBookItemName(i, BANK)
                            if nm then
                                out[#out + 1] = { text = nm, icon = SB.GetSpellBookItemTexture(i, BANK), cmd = "SPELL " .. nm, spell = spellID or actionID }
                            end
                        end
                    end
                end
            end
        end
        if SB.HasPetSpells then
            local n = SB.HasPetSpells()
            if n and n > 0 then
                local PBANK = Enum.SpellBookSpellBank.Pet
                out[#out + 1] = { header = "Pet" }
                for i = 1, n do
                    local nm = SB.GetSpellBookItemName(i, PBANK)
                    if nm and not (SB.IsSpellBookItemPassive and SB.IsSpellBookItemPassive(i, PBANK)) then
                        out[#out + 1] = { text = nm, icon = SB.GetSpellBookItemTexture(i, PBANK), cmd = "SPELL " .. nm }
                    end
                end
            end
        end
        return out
    end
    local function mountEntries()
        local out = { { header = "Mounts you have collected" } }
        local MJ = C_MountJournal
        if not (MJ and MJ.GetMountIDs) then return out end
        local list = {}
        for _, id in ipairs(MJ.GetMountIDs()) do
            local name, spellID, icon, _, _, _, _, _, _, hide, collected = MJ.GetMountInfoByID(id)
            if collected and not hide and name then list[#list + 1] = { text = name, icon = icon, cmd = "SPELL " .. name, spell = spellID } end
        end
        table.sort(list, function(x, y) return x.text < y.text end)
        for _, e in ipairs(list) do out[#out + 1] = e end
        return out
    end
    local function itemEntries()
        local out = { { header = "Usable items in your bags" } }
        local seen = {}
        for bag = 0, (NUM_TOTAL_EQUIPPED_BAG_SLOTS or 5) do
            for slot = 1, (C_Container.GetContainerNumSlots(bag) or 0) do
                local info = C_Container.GetContainerItemInfo(bag, slot)
                if info and info.itemID and not seen[info.itemID] then
                    local usable = C_Item.IsUsableItem and C_Item.IsUsableItem(info.itemID)
                    local hasSpell = C_Item.GetItemSpell and C_Item.GetItemSpell(info.itemID)
                    if usable and hasSpell then
                        seen[info.itemID] = true
                        local nm = C_Item.GetItemNameByID and C_Item.GetItemNameByID(info.itemID) or (info.hyperlink and info.hyperlink:match("%[(.-)%]"))
                        if nm then out[#out + 1] = { text = nm, icon = info.iconFileID, cmd = "ITEM " .. nm, link = info.hyperlink } end
                    end
                end
            end
        end
        return out
    end
    local function macroEntries()
        local out = {}
        local nGlobal, nChar = GetNumMacros()
        local acc = MAX_ACCOUNT_MACROS or 120
        if nChar and nChar > 0 then
            out[#out + 1] = { header = "Character macros" }
            for i = acc + 1, acc + nChar do
                local nm, icon = GetMacroInfo(i)
                if nm then out[#out + 1] = { text = nm, icon = icon, cmd = "MACRO " .. nm } end
            end
        end
        if nGlobal and nGlobal > 0 then
            out[#out + 1] = { header = "Account macros" }
            for i = 1, nGlobal do
                local nm, icon = GetMacroInfo(i)
                if nm then out[#out + 1] = { text = nm, icon = icon, cmd = "MACRO " .. nm } end
            end
        end
        if #out == 0 then out[1] = { header = "No macros yet (the game's Macros window makes them)." } end
        return out
    end

    local groups, groupOrder
    local expanded = {}
    local function loadGroups()
        if groups then return end
        groups, groupOrder = {}, {}
        local n = (GetNumBindings and GetNumBindings()) or 0
        for i = 1, n do
            local cmd, cat = GetBinding(i)
            if cmd and not cmd:find("^HEADER_") then
                cat = cat or "OTHER"
                if not groups[cat] then groups[cat] = {}; groupOrder[#groupOrder + 1] = cat end
                table.insert(groups[cat], cmd)
            end
        end
        local function rank(c)
            if c == "ACTIONBAR" then return 0 end
            if c:find("^MULTIACTIONBAR") then return 1 end
            return 2
        end
        local pos = {}
        for i, c in ipairs(groupOrder) do pos[c] = i end
        table.sort(groupOrder, function(x, y)
            local ra, rb = rank(x), rank(y)
            if ra ~= rb then return ra < rb end
            return pos[x] < pos[y]
        end)
    end

    local prows = {}
    local pcombo
    local function row(used)
        local r = prows[used]
        if not r then
            r = CreateFrame("Button", nil, pchild)
            r:SetSize(PW - 54, 26)
            API.flatButton(r)
            r.icon = r:CreateTexture(nil, "ARTWORK")
            r.icon:SetSize(20, 20); r.icon:SetPoint("LEFT", 6, 0)
            r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            r.text = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            r.text:SetJustifyH("LEFT"); r.text:SetWordWrap(false); r.text:SetWidth(PW - 100)
            r:SetScript("OnEnter", function(self)
                if not GameTooltip then return end
                if self.spell then GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); pcall(GameTooltip.SetSpellByID, GameTooltip, self.spell); GameTooltip:Show()
                elseif self.link then GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); pcall(GameTooltip.SetHyperlink, GameTooltip, self.link); GameTooltip:Show() end
            end)
            r:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
            prows[used] = r
        end
        return r
    end
    local function choose(cmd)
        picker:Hide()
        if pcombo then API.askBind(pcombo, cmd, false) end
    end
    layoutPicker = function()
        local y, used = 0, 0
        local function add(e, indent)
            used = used + 1
            local r = row(used)
            r:ClearAllPoints(); r:SetPoint("TOPLEFT", 0, -y)
            r.spell, r.link = e.spell, e.link
            r.text:ClearAllPoints()
            if e.icon then
                r.icon:SetTexture(e.icon); r.icon:Show()
                r.text:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
            else
                r.icon:Hide()
                r.text:SetPoint("LEFT", 8 + (indent or 0), 0)
            end
            r.text:SetText(e.text or e.header or "")
            if e.header then r.text:SetTextColor(1, 0.82, 0) else r.text:SetTextColor(1, 1, 1) end
            r:SetScript("OnClick", e.click or (e.cmd and function() choose(e.cmd) end) or nil)
            r:Show()
            y = y + 28
        end
        local function section(id, title, fn)
            add({ header = (expanded[id] and "- " or "+ ") .. title, click = function() expanded[id] = not expanded[id]; layoutPicker() end })
            if expanded[id] then
                local ok, list = pcall(fn)
                if not ok then list = { { text = "Couldn't read this list." } } end
                for _, e in ipairs(list) do
                    if e.header then add({ text = e.header, cmd = nil }, 18) else add(e, 18) end
                end
            end
        end
        section("_ubermoc", "Ubermoc UI", function()
            local out = {}
            for _, c in ipairs({ "UBERMOCUI_TOOLBAR", "UBERMOCUI_REVEAL_TOGGLE", "UBERMOCUI_CURSOR", "UBERMOCUI_MAPTOGGLE", "UBERMOCUI_TOGGLE" }) do
                out[#out + 1] = { text = actionName(c), cmd = c }
            end
            return out
        end)
        section("_panels", "Windows and panels", panelEntries)
        section("_spells", "Spells", spellEntries)
        section("_mounts", "Mounts", mountEntries)
        section("_items", "Usable items", itemEntries)
        section("_macros", "Macros", macroEntries)
        loadGroups()
        for _, cat in ipairs(groupOrder) do
            local title = _G["BINDING_HEADER_" .. cat] or cat
            add({ header = (expanded[cat] and "- " or "+ ") .. title, click = function() expanded[cat] = not expanded[cat]; layoutPicker() end })
            if expanded[cat] then
                for _, cmd in ipairs(groups[cat]) do add({ text = actionName(cmd), cmd = cmd }, 18) end
            end
        end
        for i = used + 1, #prows do prows[i]:Hide() end
        pchild:SetHeight(math.max(y, 10))
        pscroll:SetVerticalScroll(0)
    end
    picker.open = function(combo)
        if InCombatLockdown() then say("Bindings cannot be changed in combat."); return end
        pcombo = combo
        ptitle:SetText("Bind " .. keyWords(combo) .. " to...")
        -- Right beside the button's pop-up when it is open, else in the middle.
        picker:ClearAllPoints()
        if pop and pop:IsShown() then
            local pr = pop:GetRight()
            local sw = UIParent:GetRight()
            if pr and sw and pr + PW + 12 < sw then picker:SetPoint("TOPLEFT", pop, "TOPRIGHT", 10, 0)
            else picker:SetPoint("TOPRIGHT", pop, "TOPLEFT", -10, 0) end
        else
            picker:SetPoint("CENTER", 0, 0)
        end
        picker:Show()
        layoutPicker()
    end

    -- Refresh -----------------------------------------------------------------------------------
    local function modRows(pad)
        -- every combination of the gamepad modifiers that are set, always starting with the plain press
        local mods = {}
        for _, e in ipairs(EMU) do
            local em = emulatorOf(e[2])
            if em and em ~= pad then mods[#mods + 1] = e[2] end
        end
        local list = { "" }
        local n = #mods
        for mask = 1, (2 ^ n) - 1 do
            local s = ""
            for i = 1, n do
                if math.floor(mask / 2 ^ (i - 1)) % 2 == 1 then s = s .. mods[i] end
            end
            list[#list + 1] = s
        end
        -- plain press first, then Paddle 1, then Paddle 3, then the rest and the combinations
        local RANK = { PADPADDLE1 = 1, PADPADDLE3 = 2, PADPADDLE2 = 3, PADPADDLE4 = 4 }
        local function ranks(str)
            local r = {}
            for _, e in ipairs(EMU) do
                if str:find(e[2], 1, true) then r[#r + 1] = RANK[emulatorOf(e[2])] or 9 end
            end
            table.sort(r)
            return r
        end
        local rk = {}
        for _, str in ipairs(list) do rk[str] = ranks(str) end
        table.sort(list, function(a, b)
            local ra, rb = rk[a], rk[b]
            if #ra ~= #rb then return #ra < #rb end
            for i = 1, #ra do if ra[i] ~= rb[i] then return ra[i] < rb[i] end end
            return a < b
        end)
        return list
    end

    -- The layers other files can show: the plain press and every combination of held modifier buttons,
    -- with a short name for each, and the set of pad buttons the game uses as modifiers.
    API.padLayers = function()
        local out, mods = {}, {}
        for _, e in ipairs(EMU) do
            local em = emulatorOf(e[2])
            if em then mods[em] = e[3] end
        end
        for _, prefix in ipairs(modRows(nil)) do
            local words = {}
            for _, e in ipairs(EMU) do
                if prefix:find(e[2], 1, true) then words[#words + 1] = padLabel(emulatorOf(e[2]), true) end
            end
            out[#out + 1] = { prefix = prefix, label = #words == 0 and "None" or table.concat(words, " + "), n = #words }
        end
        return out, mods
    end

    refreshAll = function()
        local d = DB()
        local setId = activeSet()
        local dev = detectedName and (detectedName .. " (" .. SETS[detected].name .. ")") or "No controller reported yet"
        found:SetText("Controller: " .. dev)
        layoutBtn.refresh()
        autoCB:SetChecked(d.auto and true or false)
        tip:SetShown(setId == "steam" and not hasPaddles)

        layoutStage(setId)

        -- editor
        edTitle:SetText(padLabel(selected))
        local list = modRows(selected)
        if popOpen then placePop(math.min(#list, #rows)) else pop:Hide() end
        edNote:SetText(#list > 1 and "Each row is what this button does while you hold the buttons named in the row."
            or "Set Alt, Ctrl and Shift modifiers in WoW's Gamepad options to get more layers on every button.")
        for i, r in ipairs(rows) do
            local prefix = list[i]
            if prefix then
                r.combo = prefix .. selected
                local words = {}
                for _, e in ipairs(EMU) do
                    if prefix:find(e[2], 1, true) then words[#words + 1] = padLabel(emulatorOf(e[2]), true) end
                end
                r.label:SetText(#words == 0 and "Pressed on its own" or ("Hold " .. table.concat(words, " + ")))
                local act = actionOf(r.combo)
                local okE, escKey = pcall(GetCVar, "GamePadEmulateEsc")
                if prefix == "" and okE and escKey == selected and (act or "") == "" then
                    r.act:SetText("|cff9fb4ffEscape (closes windows, then the game menu)|r")
                else
                    r.act:SetText((act and act ~= "") and actionName(act) or "|cff888888Nothing|r")
                end
                r.label:Show(); r.act:Show(); r.change:Show(); r.clear:Show()
            else
                r.label:Hide(); r.act:Hide(); r.change:Hide(); r.clear:Hide()
            end
        end

        -- by bar
        local bar = BARS[barIdx]
        barBtn.refresh()
        for i, r in ipairs(barRows) do
            r.cmd = bar[2]:format(i)
            r.label:SetText(actionName(r.cmd))
            local keys = padKeysOf(r.cmd)
            local words = {}
            for _, k in ipairs(keys) do words[#words + 1] = keyWords(k) end
            r.keys:SetText(#words > 0 and table.concat(words, ", ") or "|cff888888Not set on the pad|r")
        end
    end

    panel.refreshAll = refreshAll
    panel:SetScript("OnShow", function()
        pcall(detect); refreshAll()
        -- Binds and modifier settings can still be loading when the page first opens: look again shortly.
        if C_Timer and C_Timer.After then
            for _, t in ipairs({ 0.3, 1.2 }) do
                C_Timer.After(t, function() if panel:IsShown() then pcall(detect); pcall(refreshAll) end end)
            end
        end
    end)
    -- Changed binds or modifier settings redraw the page (once, a moment after the last change).
    do
        local f, wait = CreateFrame("Frame"), false
        f:RegisterEvent("UPDATE_BINDINGS")
        pcall(f.RegisterEvent, f, "CVAR_UPDATE")
        f:SetScript("OnEvent", function()
            if wait or not panel:IsShown() then return end
            wait = true
            C_Timer.After(0.2, function() wait = false; if panel:IsShown() then pcall(refreshAll) end end)
        end)
    end
end

build()
API.resetters.controller = function()
    UbermocUIDB.pad = nil
    DB()
    enablePad()
end
API.addPage("controller", "Buttons", panel)

----------------------------------------------------------------------
-- Three controller options that live on other pages (NPC Dialogue, Interact). Each call puts the check box and its note
-- into `parent` at x, y and returns the check box (call :refreshOption() when the page shows) and the y below it.
function API.padOption(kind, parent, x, y, width)
    local text, note, get, set
    if kind == "hints" then
        text = "Show controller button hints in quest and gossip windows"
        note = "For quest window addons that show their hints on a bar at the bottom of the screen: the bar is drawn here, with your controller's button names."
        get = function() return DB().hints ~= false end
        set = function(v) DB().hints = v; if API.refreshPadHints then API.refreshPadHints() end end
    elseif kind == "dui" then
        text = "Switch the dialogue add-on to controller button prompts"
        note = "When a controller is connected and your dialogue add-on is set to keyboard and mouse, its input setting is switched to match this controller. A reload finishes the switch."
        get = function() return DB().dui ~= false end
        set = function(v) DB().dui = v; if v and API.syncDialogueUI then API.syncDialogueUI(true) end end
    else
        text = "Right stick moves the mouse when a menu is open"
        note = "Uses the game's own gamepad cursor, so the pointer shows up when a window opens. The D-pad still moves between parts one at a time."
        get = function() return DB().cursor ~= false end
        set = function(v) DB().cursor = v; applyCursor(v) end
    end
    local cb = API.newCheck(parent, text, x, y, set)
    local nl = API.newLabel(parent, note, x + 32, y - 30, "GameFontHighlightSmall")
    nl:SetWidth(width or 500); nl:SetJustifyH("LEFT"); nl:SetWordWrap(true)
    cb.refreshOption = function(self) self:SetChecked(get()) end
    return cb, y - 84
end

-- Controller hints for quest and gossip window addons. Some of them only draw their button hints
-- through a full controller addon's hint bar; this draws an equivalent bar from the same calls.
----------------------------------------------------------------------
API.padLabel = padLabel
API.padSet = function() return activeSet() end   -- xbox / ps5 / ps3 / switch / steam
do
    local FACE = { PAD1 = { 0.3, 0.85, 0.3 }, PAD2 = { 0.95, 0.3, 0.3 }, PAD3 = { 0.3, 0.55, 1 }, PAD4 = { 1, 0.82, 0.15 } }
    local ORDER = { CROSS = 1, SQUARE = 2, CIRCLE = 3, TRIANGLE = 4, UP = 5, DOWN = 6, LEFT = 7, RIGHT = 8, OPTIONS = 9, SHARE = 10, CENTER = 11 }
    local SETTING = { CROSS = { "padaccept", "PAD1" }, CIRCLE = { "padinspect", "PAD4" }, SQUARE = { "padnext", "PAD3" },
        TRIANGLE = { "padgoodbye", "PAD2" }, UP = { "padup", "PADDUP" }, DOWN = { "paddown", "PADDDOWN" },
        LEFT = { "padleft", "PADDLEFT" }, RIGHT = { "padright", "PADDRIGHT" } }
    local FIXED = { OPTIONS = "PADFORWARD", SHARE = "PADSOCIAL", CENTER = "PADSYSTEM" }
    local function buttonFor(id)
        if FIXED[id] then return FIXED[id] end
        local s = SETTING[id]
        if not s then return id end
        local cfg = _G.ImmersionSetup
        local v = type(cfg) == "table" and cfg[s[1]]
        return (type(v) == "string" and v ~= "") and v or s[2]
    end

    local bar = CreateFrame("Frame", "UbermocPadHintBar", UIParent)
    bar:SetFrameStrata("DIALOG")
    bar:SetSize(10, 40)
    bar:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 120)
    bar:Hide()
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(); bg:SetColorTexture(0.03, 0.035, 0.05, 0.75)
    local hints, pool = {}, {}
    local focused = false

    local function item(i)
        local it = pool[i]
        if it then return it end
        it = CreateFrame("Frame", nil, bar)
        it:SetHeight(32)
        it.disc = it:CreateTexture(nil, "ARTWORK")
        it.disc:SetTexture("Interface\\AddOns\\UbermocUI\\Media\\ringdisc.tga")
        it.disc:SetSize(26, 26)
        it.disc:SetPoint("LEFT", 0, 0)
        it.key = it:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        it.key:SetPoint("CENTER", it.disc, "CENTER", 0, 0)
        it.text = it:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        it.text:SetPoint("LEFT", it.disc, "RIGHT", 6, 0)
        pool[i] = it
        return it
    end

    local function layout()
        local on = focused and DB().hints ~= false
        local list = {}
        for id, h in pairs(hints) do if h.text and h.text ~= "" then list[#list + 1] = h end end
        if not on or #list == 0 then bar:Hide(); return end
        table.sort(list, function(a, b) return (ORDER[a.id] or 99) < (ORDER[b.id] or 99) end)
        local x = 12
        for i, h in ipairs(list) do
            local it = item(i)
            local key = buttonFor(h.id)
            local col = FACE[key] or { 0.55, 0.6, 0.7 }
            it.disc:SetVertexColor(col[1], col[2], col[3], h.disabled and 0.35 or 1)
            local lab = padLabel(key, true) or key
            it.key:SetText(#lab <= 2 and lab or lab:sub(1, 2))
            it.text:SetText(h.text)
            it.text:SetTextColor(1, 1, 1, h.disabled and 0.4 or 1)
            local w = 32 + (it.text:GetStringWidth() or 40)
            it:SetWidth(w)
            it:ClearAllPoints()
            it:SetPoint("LEFT", bar, "LEFT", x, 0)
            it:Show()
            x = x + w + 18
        end
        for i = #list + 1, #pool do pool[i]:Hide() end
        bar:SetWidth(x - 6)
        bar:Show()
    end
    API.refreshPadHints = layout

    local function hook(frame)
        if not frame or frame.ubermocHintHook then return end
        frame.ubermocHintHook = true
        local function hk(name, fn) if type(frame[name]) == "function" then hooksecurefunc(frame, name, fn) end end
        hk("AddHint", function(_, id, text) if id then hints[id] = { id = id, text = text }; layout() end end)
        hk("RemoveHint", function(_, id) if id then hints[id] = nil; layout() end end)
        hk("SetHintEnabled", function(_, id) if id and hints[id] then hints[id].disabled = false; layout() end end)
        hk("SetHintDisabled", function(_, id) if id and hints[id] then hints[id].disabled = true; layout() end end)
        hk("SetImmersionFocus", function() focused = true; layout() end)
        hk("ClearImmersionFocus", function() focused = false; wipe(hints); layout() end)
        frame:HookScript("OnHide", function() focused = false; wipe(hints); layout() end)
    end

    local function tryHook()
        -- Only when no full controller addon is drawing its own hint bar.
        local loaded = C_AddOns and C_AddOns.IsAddOnLoaded
        if loaded and loaded("ConsolePort") then return end
        if _G.ImmersionFrame then pcall(hook, _G.ImmersionFrame) end
    end
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("PLAYER_LOGIN")
    ev:RegisterEvent("ADDON_LOADED")
    ev:SetScript("OnEvent", function() pcall(tryHook) end)
    pcall(tryHook)
end

----------------------------------------------------------------------
-- The dialogue add-on picks its button prompts from its own "Input Device" setting (keyboard and mouse by
-- default). With a controller connected, switch it to the matching controller once.
----------------------------------------------------------------------
do
    local DEVICE = { xbox = 2, steam = 2, ps5 = 3, ps3 = 3, switch = 4 }
    if StaticPopupDialogs then
        StaticPopupDialogs["UBERMOCUI_DUI_RELOAD"] = {
            text = "The dialogue add-on now uses controller button prompts. Reload the interface to finish?",
            button1 = "Reload", button2 = "Later",
            OnAccept = function() ReloadUI() end,
            timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
        }
    end
    function API.syncDialogueUI(force)
        local loaded = C_AddOns and C_AddOns.IsAddOnLoaded
        if not (loaded and loaded("DialogueUI")) then return end
        local db = _G.DialogueUI_DB
        if type(db) ~= "table" or not UbermocUIDB or DB().dui == false then return end
        local okG, g = pcall(GetCVar, "GamePadEnable")
        if not (okG and g == "1") then return end
        pcall(detect)
        if not detectedReal and not force then return end
        local want = DEVICE[activeSet()] or 2
        if db.InputDevice == nil or db.InputDevice == 1 then
            db.InputDevice = want
            if StaticPopup_Show then StaticPopup_Show("UBERMOCUI_DUI_RELOAD") end
        end
    end
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("PLAYER_LOGIN")
    pcall(ev.RegisterEvent, ev, "GAME_PAD_CONNECTED")
    ev:SetScript("OnEvent", function()
        if C_Timer then C_Timer.After(3, function() pcall(API.syncDialogueUI) end) end
    end)
end



----------------------------------------------------------------------
-- Button test window
----------------------------------------------------------------------
do
    local T
    local function actionText(cmd)
        if not cmd or cmd == "" then return "|cff999999nothing|r" end
        local n = cmd:match("^ACTIONBUTTON(%d+)$")
        local b, i = cmd:match("^MULTIACTIONBAR(%d+)BUTTON(%d+)$")
        local btn
        if n then btn = _G["ActionButton" .. n] end
        if b then
            local bars = { "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight", "MultiBarLeft", "MultiBar5", "MultiBar6", "MultiBar7" }
            local bn = bars[tonumber(b)]
            btn = bn and _G[bn .. "Button" .. i]
        end
        if btn then
            local act = btn.action
            local where = n and ("action bar 1, button " .. n) or ("action bar " .. (tonumber(b) + 1) .. ", button " .. i)
            local what = "empty"
            if type(act) == "number" and HasAction and HasAction(act) then
                local okI, kind, id = pcall(GetActionInfo, act)
                what = tostring(kind)
                if okI and kind == "spell" and id then
                    local okS, info = pcall(C_Spell.GetSpellInfo, id)
                    if okS and type(info) == "table" and info.name then what = info.name end
                elseif okI and kind == "item" and id then
                    local okN, nm = pcall(C_Item.GetItemNameByID, id)
                    if okN and nm then what = nm end
                elseif okI and kind == "macro" and id then
                    local okN, nm = pcall(GetMacroInfo, id)
                    if okN and nm then what = "macro " .. nm end
                end
            end
            return where .. ": |cffffffff" .. what .. "|r"
        end
        local nm = _G["BINDING_NAME_" .. cmd]
        return "|cffffffff" .. (nm or cmd) .. "|r"
    end
    local function build()
        T = CreateFrame("Frame", "UbermocButtonTest", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
        T:SetSize(560, 300)
        T:SetPoint("CENTER")
        T:SetFrameStrata("FULLSCREEN_DIALOG")
        T:SetFrameLevel(500)
        if T.SetBackdrop then
            T:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
            T:SetBackdropColor(0.05, 0.06, 0.09, 0.97)
            T:SetBackdropBorderColor(API.accent[1], API.accent[2], API.accent[3], 1)
        end
        local title = T:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", 14, -12)
        title:SetText("Button test")
        local help = T:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        help:SetPoint("TOPLEFT", 14, -38); help:SetWidth(530); help:SetJustifyH("LEFT")
        help:SetText("Press any button, alone or with a modifier, to see what the game received and what it is bound to. It closes after 15 seconds without a press.")
        T.lines = {}
        for i = 1, 8 do
            local fs = T:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            fs:SetPoint("TOPLEFT", 14, -76 - (i - 1) * 24); fs:SetWidth(530); fs:SetJustifyH("LEFT"); fs:SetWordWrap(false)
            T.lines[i] = fs
        end
        T.log = {}
        local function add(src, key)
            if key:find("^[LR]?SHIFT$") or key:find("^[LR]?CTRL$") or key:find("^[LR]?ALT$") then
                table.insert(T.log, 1, "|cff88ccff" .. src .. "|r " .. key .. "  (a keyboard modifier)")
            else
                local combo = (IsAltKeyDown() and "ALT-" or "") .. (IsControlKeyDown() and "CTRL-" or "") .. (IsShiftKeyDown() and "SHIFT-" or "") .. key
                local label = (API.padLabel and key:find("^PAD") and API.padLabel(key, true)) or key
                table.insert(T.log, 1, "|cff88ccff" .. src .. "|r |cffffd100" .. combo .. "|r (" .. tostring(label) .. ")  ->  " .. actionText(GetBindingAction(combo)))
            end
            while #T.log > 8 do table.remove(T.log) end
            for i, fs in ipairs(T.lines) do fs:SetText(T.log[i] or "") end
            T.idle = 0
        end
        T:EnableKeyboard(true)
        T:SetScript("OnKeyDown", function(self, key)
            if not InCombatLockdown() then self:SetPropagateKeyboardInput(false) end
            add("Key", key)
        end)
        T:SetScript("OnGamePadButtonDown", function(_, key) add("Pad", key) end)
        local close = CreateFrame("Button", nil, T, "UIPanelButtonTemplate")
        close:SetSize(100, 24); close:SetPoint("BOTTOMRIGHT", -12, 10); close:SetText("Close")
        close:SetScript("OnClick", function() T:Hide() end)
        T:SetScript("OnUpdate", function(self, dt)
            self.idle = (self.idle or 0) + dt
            if self.idle > 15 then self:Hide() end
        end)
        T:SetScript("OnHide", function(self) pcall(self.EnableGamePadButton, self, false) end)
    end
    API.openButtonTest = function()
        if InCombatLockdown() then return end
        if not T then build() end
        T.log = {}
        for _, fs in ipairs(T.lines) do fs:SetText("") end
        T.idle = 0
        T:Show()
        pcall(T.EnableGamePadButton, T, true)
    end
end
