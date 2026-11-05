-- Ubermoc UI - Copyright (c) 2026 Marcos. All rights reserved.
-- This file is protected by copyright. It may not be copied, modified, redistributed or reused, in whole or
-- in part, without the written permission of the author. See LICENSE.txt.
----------------------------------------------------------------------
-- Ubermoc UI: game-cursor menus
-- Bags, the game's menu panels (character, spellbook, talents, map and so on) and the game's own options move the
-- game's real cursor: the D-pad jumps it from button to button, A and X click for real, the bumpers step through the
-- window's tabs, the triggers scroll, and B goes back. The buttons are taken only while such a window is open, and
-- everything closes by itself when combat starts. Ubermoc UI's own windows keep the drawn pointer (Extras.lua).
-- "/ubcursor engine pointer" switches back to the drawn pointer everywhere, "/ubcursor engine game" to this.
----------------------------------------------------------------------
local API = UbermocUIAPI
if not API then return end

local P = {}
API.padCursor = P

local POLL = 0.1
local TAB_CHECK_MAX_DEPTH = 6
local FIXED_FRAMES = { "GameMenuFrame", "ContainerFrameCombinedBags" }
local PANELS = { "left", "center", "right", "doublewide", "fullscreen" }

local function secure(fn, ...)
    if securecallfunction then return pcall(securecallfunction, fn, ...) end
    return pcall(fn, ...)
end

local function shown(frame)
    return type(frame) == "table" and frame.IsShown and frame:IsShown() and true or false
end

local function settings()
    local e = UbermocUIDB and UbermocUIDB.extras
    return (e and e.cursor) or {}
end

function P.engineOn()
    local c = settings()
    return c.on ~= false and c.engine ~= "pointer"
end

function P.closeOnCombat()
    return settings().closeOnCombat ~= false
end

local function isOwnName(name)
    return type(name) == "string" and name:find("^Ubermoc") ~= nil
end

-- What stays with the drawn pointer (Extras.lua): Ubermoc UI's own windows (not its menu bar, which stays up while
-- the panels it opens belong to the game cursor), the small question windows (they start on
-- their main button, and DELETE is filled in for you), the game's pop-up menus, frames unlocked for moving (picked up
-- with A and carried with the D-pad), and the Y options menu on a bag slot or spell (handed over, see onButton).
local OWN_WINDOWS = {
    "UbermocUIWindow", "UbermocDialogue", "UbermocBagPicker",
    "StaticPopup1", "StaticPopup2", "StaticPopup3", "StaticPopup4",
    "ReadyCheckFrame", "LFGDungeonReadyPopup", "PVPReadyDialog", "LFDRoleCheckPopup", "RolePollPopup",
    "LFGInvitePopup", "LFGListInviteDialog", "LFGListApplicationDialog", "PetBattleQueueReadyFrame",
}
function P.OwnOpen()
    for _, n in ipairs(OWN_WINDOWS) do
        if shown(_G[n]) then return true end
    end
    if API.win and shown(API.win) then return true end
    if API.cursorMenuOpen and API.cursorMenuOpen() then return true end
    for _, m in ipairs(API.moverFrames or {}) do
        if shown(m) then return true end
    end
    return false
end

-- The game's windows that are open, as a list of their top frames.
function P.OpenWindows()
    local list, seen = {}, {}
    local function add(frame)
        if shown(frame) and not seen[frame] then
            seen[frame] = true
            list[#list + 1] = frame
        end
    end
    for _, name in ipairs(UISpecialFrames or {}) do
        if not isOwnName(name) then add(_G[name]) end
    end
    for _, side in ipairs(PANELS) do
        if GetUIPanel then add(GetUIPanel(side)) end
    end
    for _, name in ipairs(FIXED_FRAMES) do add(_G[name]) end
    for i = 1, 13 do add(_G["ContainerFrame" .. i]) end
    return list
end

function P.WindowOpen()
    return #P.OpenWindows() > 0
end

-- True when this cursor (and not the drawn pointer) should handle the windows that are open right now.
function P.Wants()
    if not P.engineOn() or InCombatLockdown() or API.padYield then return false end
    if API.cursorPointerActive and API.cursorPointerActive() then return false end
    if P.OwnOpen() then return false end
    return P.WindowOpen()
end

local function cursorControlOn()
    return IsGamePadCursorControlEnabled and IsGamePadCursorControlEnabled() and true or false
end

local function gamepadOn()
    local ok, v = pcall(GetCVarBool, "GamePadEnable")
    return ok and v and true or false
end

----------------------------------------------------------------------
-- Tabs: the shoulder buttons step through the tabs of the open window
----------------------------------------------------------------------
local Tabs = {}
P.Tabs = Tabs

local function usable(button, isSelected)
    return type(button) == "table" and button.IsShown and button:IsShown() and button.Click
        and (isSelected or (button.IsEnabled and button:IsEnabled()))
end

local function tabsFromFrame(frame)
    if type(frame.tabs) == "table" and frame.selectedTabID ~= nil then
        local list, selected = {}, nil
        for _, button in ipairs(frame.tabs) do
            local isSelected = button.GetTabID and button:GetTabID() == frame.selectedTabID
            if usable(button, isSelected) then
                list[#list + 1] = button
                if isSelected then selected = #list end
            end
        end
        if #list > 1 then return list, selected end
    end
    if type(frame.numTabs) == "number" and frame.selectedTab ~= nil and frame.GetName then
        local name = frame:GetName()
        local list, selected = {}, nil
        for i = 1, frame.numTabs do
            local button = (type(frame.Tabs) == "table" and frame.Tabs[i]) or (name and _G[name .. "Tab" .. i])
            local isSelected = i == frame.selectedTab
            if usable(button, isSelected) then
                list[#list + 1] = button
                if isSelected then selected = #list end
            end
        end
        if #list > 1 then return list, selected end
    end
end

local function tabSearch(frame, depth)
    if frame.IsForbidden and frame:IsForbidden() then return end
    local list, selected = tabsFromFrame(frame)
    if list then return list, selected end
    if depth < TAB_CHECK_MAX_DEPTH and frame.GetChildren then
        for _, child in ipairs({ frame:GetChildren() }) do
            local found, at = tabSearch(child, depth + 1)
            if found then return found, at end
        end
    end
end

function Tabs.Find()
    for _, root in ipairs(P.OpenWindows()) do
        local ok, list, selected = pcall(tabSearch, root, 0)
        if ok and list then return list, selected end
    end
end

-- direction is -1 or 1; goes round at the ends. Returns the tab button to go to, or nil.
-- The tab is not clicked from here: a click made by addon code runs the tab's handler as addon code, and handlers
-- that use protected functions are blocked. The cursor goes to the tab and a real click is sent on release.
function Tabs.Target(direction)
    local list, selected = Tabs.Find()
    if not list then return nil end
    local target = ((selected or (direction > 0 and 0 or 1)) - 1 + direction) % #list + 1
    return list[target]
end

----------------------------------------------------------------------
-- Moving the cursor
----------------------------------------------------------------------
local NODE_TYPES = { Button = true, CheckButton = true }
local MAX_DEPTH, MAX_NODES = 14, 900
local MIN_MOVE = 6
local DIRECTIONS = { PADDUP = "UP", PADDDOWN = "DOWN", PADDLEFT = "LEFT", PADDRIGHT = "RIGHT" }

local function visit(child, out, depth)
    if child:IsForbidden() or not child:IsShown() then return end
    if NODE_TYPES[child:GetObjectType()] and child:IsMouseEnabled() and child:IsVisible() then
        local cx, cy = child:GetCenter()
        local left, bottom, width, height = child:GetRect()
        if cx and cy and left then
            local scale = child:GetEffectiveScale()
            out[#out + 1] = { frame = child, x = cx * scale, y = cy * scale,
                l = left * scale, b = bottom * scale, r = (left + width) * scale, t = (bottom + height) * scale }
        end
    end
    if depth < MAX_DEPTH then
        for _, grandchild in ipairs({ child:GetChildren() }) do
            if #out < MAX_NODES then pcall(visit, grandchild, out, depth + 1) end
        end
    end
end

function P.Nodes()
    local out = {}
    for _, root in ipairs(P.OpenWindows()) do
        for _, child in ipairs({ root:GetChildren() }) do
            if #out < MAX_NODES then pcall(visit, child, out, 1) end
        end
    end
    return out
end

-- The nearest candidate in a direction. Straight ahead wins over off to the side.
function P.Pick(candidates, ox, oy, direction)
    local best, bestScore
    for _, c in ipairs(candidates) do
        local dx, dy = c.x - ox, c.y - oy
        local along, across
        if direction == "UP" then along, across = dy, dx
        elseif direction == "DOWN" then along, across = -dy, dx
        elseif direction == "RIGHT" then along, across = dx, dy
        else along, across = -dx, dy end
        if along > MIN_MOVE then
            local score = along + 2 * math.abs(across)
            if not bestScore or score < bestScore then best, bestScore = c, score end
        end
    end
    return best
end

-- The node the cursor is on (the smallest one when they overlap), or nil.
function P.Containing(candidates, ox, oy)
    local best, bestArea
    for _, c in ipairs(candidates) do
        if c.l and ox >= c.l and ox <= c.r and oy >= c.b and oy <= c.t then
            local area = (c.r - c.l) * (c.t - c.b)
            if not bestArea or area < bestArea then best, bestArea = c, area end
        end
    end
    return best
end

-- The closest node in any direction, for when the cursor is not on anything yet.
function P.Nearest(candidates, ox, oy)
    local best, bestDistance
    for _, c in ipairs(candidates) do
        local distance = (c.x - ox) ^ 2 + (c.y - oy) ^ 2
        if not bestDistance or distance < bestDistance then best, bestDistance = c, distance end
    end
    return best
end

-- SetCursorPosition's units are not written down: a first guess is checked on the next frame against where the
-- cursor really landed, and corrected from then on.
local calibration = { factor = nil }
local pendingCheck

function P.MoveTo(px, py)
    local factor = calibration.factor or (1 / UIParent:GetEffectiveScale())
    local ax, ay = px * factor, py * factor
    local bx, by = GetCursorPosition()
    SetCursorPosition(ax, ay)
    if not calibration.factor then
        pendingCheck = { ax = ax, ay = ay, bx = bx, by = by, tries = 0 }
    end
end

local function checkLanding()
    local check = pendingCheck
    if not check then return end
    local rx, ry = GetCursorPosition()
    if math.abs(rx - check.bx) < 2 and math.abs(ry - check.by) < 2 then
        check.tries = check.tries + 1
        if check.tries > 10 then pendingCheck = nil end
        return
    end
    pendingCheck = nil
    local factor = check.ax / rx
    if rx > 50 and factor > 0.2 and factor < 5 then calibration.factor = factor end
end

function P.Snap(direction)
    local ox, oy = GetCursorPosition()
    local nodes = P.Nodes()
    local target
    if P.Containing(nodes, ox, oy) then
        target = P.Pick(nodes, ox, oy, direction)
    else
        -- Not on a button yet (a window just opened): the first press goes to the nearest one.
        target = P.Nearest(nodes, ox, oy)
    end
    if not target then return false end
    P.MoveTo(target.x, target.y)
    return true
end

local function click(mouseButton)
    local ok = pcall(SimulateMouseClick, mouseButton)
    if ok then return end
    for _, frame in ipairs(GetMouseFoci()) do
        local f = frame
        for _ = 1, 5 do
            if not f or f == WorldFrame then break end
            if type(f.Click) == "function" and f.IsEnabled and f:IsEnabled() then
                pcall(f.Click, f, mouseButton)
                return
            end
            f = f.GetParent and f:GetParent() or nil
        end
    end
end

local function scroll(delta)
    pcall(SimulateMouseWheel, delta)
end

-- Back closes the top thing: a question first, then the options panel, menus, windows and bags. The game's whole Esc
-- action also stops casting and clears the target, and can use up the press before anything closes, so only the
-- closing steps are used.
function P.Back()
    local closed
    if type(StaticPopup_EscapePressed) == "function" then
        local ok, result = secure(StaticPopup_EscapePressed)
        closed = ok and result
    end
    if not closed then
        local sp = _G.SettingsPanel
        if shown(sp) then
            -- true: do not go back to the game menu afterwards, which runs the game's whole Esc action from this
            -- addon's call and is blocked (stop casting is protected)
            closed = secure(sp.Close, sp, true)
        end
    end
    if not closed then
        if type(CloseMenus) == "function" then secure(CloseMenus) end
        local ok, result = secure(CloseAllWindows)
        closed = ok and result
    end
    if not closed and cursorControlOn() then pcall(SetGamePadCursorControl, false) end
end

----------------------------------------------------------------------
-- Buttons: taken only while one of the game's windows is open
----------------------------------------------------------------------
local input = CreateFrame("Frame", "UbermocPadCursorInput", UIParent)
input:SetSize(1, 1)
input:SetPoint("TOPLEFT", UIParent, "TOPLEFT")
local inputActive = false
local pendingTab

function P.TabStep(direction, key)
    local button = Tabs.Target(direction)
    if not button then return false end
    local cx, cy = button:GetCenter()
    if not cx then return false end
    local scale = button:GetEffectiveScale()
    P.MoveTo(cx * scale, cy * scale)
    pendingTab = { key = key, time = GetTime() }
    return true
end

-- The click on a tab is sent when the button is released, because the game only lets addon code place the cursor or
-- click once per controller event, and the click needs the cursor to have landed first.
local function onButtonUp(_, key)
    key = key:match("([^-]+)$") or key
    local pending = pendingTab
    if not pending or pending.key ~= key then return end
    pendingTab = nil
    if GetTime() - pending.time > 1.5 then return end
    pcall(SimulateMouseClick, "LeftButton")
end

local function onButton(_, key)
    key = key:match("([^-]+)$") or key
    if DIRECTIONS[key] then
        P.Snap(DIRECTIONS[key])
    elseif key == "PAD1" then
        click("LeftButton")
    elseif key == "PAD3" then
        click("RightButton")
    elseif key == "PADLSHOULDER" then
        P.TabStep(-1, key)
    elseif key == "PADRSHOULDER" then
        P.TabStep(1, key)
    elseif key == "PADLTRIGGER" then
        scroll(1)
    elseif key == "PADRTRIGGER" then
        scroll(-1)
    elseif key == "PAD2" then
        P.Back()
    elseif key == "PAD4" then
        -- Y: the options menu on a bag slot or a spell is the drawn pointer's; hand the window over to it
        if API.cursorItemMenuFrom then
            for _, frame in ipairs(GetMouseFoci()) do
                if API.cursorItemMenuFrom(frame) then return end
            end
        end
    end
end

-- The game's own cursor click buttons are R2 (left click) and R1 (right click) by default, which would click while
-- those buttons scroll and switch tabs here. While this takes the buttons they are set to NONE and put back after.
local CLICK_CVARS = { left = { "GamePadCursorLeftClick", "PADRTRIGGER" }, right = { "GamePadCursorRightClick", "PADRSHOULDER" } }

local function manageClicks(taking)
    if InCombatLockdown() then return end
    local e = UbermocUIDB and UbermocUIDB.extras
    if not e then return end
    e.cursor = e.cursor or {}
    local backup = e.cursor.clickBackup
    for which, def in pairs(CLICK_CVARS) do
        local name, default = def[1], def[2]
        local okC, current = pcall(GetCVar, name)
        if okC and current ~= nil then
            if taking then
                if current == default then
                    backup = backup or {}
                    backup[which] = current
                    e.cursor.clickBackup = backup
                    pcall(SetCVar, name, "NONE")
                end
            elseif backup and backup[which] and current == "NONE" then
                pcall(SetCVar, name, backup[which])
                backup[which] = nil
            end
        end
    end
end

local function syncInput(want)
    if want == inputActive then return end
    inputActive = want
    input:EnableGamePadButton(want)
    if want then
        input:SetScript("OnGamePadButtonDown", onButton)
        input:SetScript("OnGamePadButtonUp", onButtonUp)
        input:Show()
    else
        input:SetScript("OnGamePadButtonDown", nil)
        input:SetScript("OnGamePadButtonUp", nil)
        pendingTab = nil
        input:Hide()
    end
end

local function update()
    if not UbermocUIDB then return end
    -- The drawn pointer may still be up from the menu bar (or a window that has gone) when a game window opens from it:
    -- the window belongs to the game cursor, so the pointer is put away and the game cursor takes over.
    if P.engineOn() and not API.padYield and not InCombatLockdown() and API.cursorPointerActive and API.cursorPointerActive()
        and P.WindowOpen() and not P.OwnOpen() and API.cursorDeactivate then
        pcall(API.cursorDeactivate)
    end
    -- and a drawn pointer left on screen with nothing driving it (its slot border after the bag closed) goes away
    local cf = _G.UbermocCursor
    if cf and cf.IsShown and cf:IsShown() and not (API.cursorPointerActive and API.cursorPointerActive()) then pcall(cf.Hide, cf) end
    local want = P.Wants() and gamepadOn()
    -- The game switches its cursor off and on again by itself, so the buttons stay taken for as long as a window is
    -- open; letting go for even a moment would fire abilities.
    syncInput(want)
    manageClicks(want)
    if want and not cursorControlOn() then pcall(SetGamePadCursorControl, true) end
end

-- Combat starts: the buttons are the abilities again and, unless it is switched off, every window closes.
local function onCombatStart()
    syncInput(false)
    if not P.closeOnCombat() then return end
    if API.win and shown(API.win) then pcall(API.win.Hide, API.win) end
    if CloseMenus then secure(CloseMenus) end
    secure(CloseAllWindows)
    if cursorControlOn() then pcall(SetGamePadCursorControl, false) end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_REGEN_DISABLED")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_DISABLED" then
        onCombatStart()
    else
        pcall(update)
    end
end)
local acc = 0
ev:SetScript("OnUpdate", function(_, dt)
    checkLanding()
    acc = acc + dt
    if acc < POLL then return end
    acc = 0
    pcall(update)
end)

----------------------------------------------------------------------
-- /ubcursor engine game | pointer, /ubcursor combat on | off
----------------------------------------------------------------------
function P.Command(args)
    local word, rest = (args or ""):match("^(%S*)%s*(.-)%s*$")
    word, rest = word:lower(), rest:lower()
    local e = UbermocUIDB and UbermocUIDB.extras
    if not e then return false end
    e.cursor = e.cursor or {}
    if word == "engine" and (rest == "game" or rest == "pointer") then
        e.cursor.engine = rest
        if rest == "pointer" then syncInput(false) end
        print("Ubermoc UI: windows now use " .. (rest == "game" and "the game's cursor." or "the drawn pointer."))
        return true
    elseif word == "combat" and (rest == "on" or rest == "off") then
        e.cursor.closeOnCombat = rest == "on"
        print("Ubermoc UI: windows " .. (rest == "on" and "close" or "stay open") .. " when combat starts.")
        return true
    end
    return false
end
