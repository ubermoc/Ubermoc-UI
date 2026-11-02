-- Ubermoc UI - Copyright (c) 2026 Marcos. All rights reserved.
-- This file is protected by copyright. It may not be copied, modified, redistributed or reused, in whole or
-- in part, without the written permission of the author. See LICENSE.txt.
----------------------------------------------------------------------
-- Ubermoc UI screen shift (OLED burn-in protection): the whole interface slowly orbits by a pixel or two.
----------------------------------------------------------------------
local API = UbermocUIAPI
if not API then return end

local DB

----------------------------------------------------------------------
-- Screen shift (OLED burn-in): the whole interface slowly orbits by a pixel or two.
----------------------------------------------------------------------
local ORBIT = { { 0, 0 }, { 1, 0 }, { 1, 1 }, { 0, 1 }, { -1, 1 }, { -1, 0 }, { -1, -1 }, { 0, -1 } }
local shiftApplied = { 0, 0 }
local shiftTicker
local shiftWaiting = false

local function moveUI(ox, oy)
    if InCombatLockdown() then shiftWaiting = true; return end
    local n = UIParent:GetNumPoints()
    if not n or n < 1 then return end
    local pts = {}
    for i = 1, n do pts[i] = { UIParent:GetPoint(i) } end
    local dx, dy = ox - shiftApplied[1], oy - shiftApplied[2]
    if dx == 0 and dy == 0 then return end
    UIParent:ClearAllPoints()
    for _, p in ipairs(pts) do
        UIParent:SetPoint(p[1], p[2], p[3], (p[4] or 0) + dx, (p[5] or 0) + dy)
    end
    shiftApplied = { ox, oy }
end

local function shiftStep(advance)
    local c = DB and DB.shift
    if not c then return end
    if not c.on or (c.px or 0) <= 0 then pcall(moveUI, 0, 0); return end
    if advance then c.i = ((c.i or 1) % #ORBIT) + 1 end
    local o = ORBIT[c.i or 1] or ORBIT[1]
    pcall(moveUI, o[1] * c.px, o[2] * c.px)
end

local function shiftRestart()
    if shiftTicker then shiftTicker:Cancel(); shiftTicker = nil end
    local c = DB and DB.shift
    if c and c.on and (c.px or 0) > 0 then
        shiftTicker = C_Timer.NewTicker(math.max(1, c.mins or 5) * 60, function() shiftStep(true) end)
    end
    shiftStep(false)
end

----------------------------------------------------------------------
-- Settings page
----------------------------------------------------------------------
local function buildPage()
    local panel = CreateFrame("Frame")
    local p = CreateFrame("Frame", nil, panel)
    p:SetAllPoints(panel)
    API.newLabel(p, "Screen Shift", 8, -8, "GameFontNormalHuge")
    API.newLabel(p, "OLED burn-in protection", 8, -44, "GameFontNormalLarge")
    local sh = DB.shift
    local note = API.newLabel(p, "Slowly moves the whole interface around by a pixel or two so static parts like action bars and unit frames do not stay on the same pixels. It moves in combat-safe steps and waits until combat ends.", 8, -72, "GameFontHighlightSmall")
    note:SetWidth(570); note:SetJustifyH("LEFT"); note:SetWordWrap(true)
    local y = -30
    local shOn = API.newCheck(p, "Shift the interface", 8, y - 74, function(v) sh.on = v; shiftRestart() end)
    API.newLabel(p, "Shift distance", 40, y - 112)
    local shPx = API.makeSlider(p, 140, 0, 4, 1, function(v) return math.floor(v + 0.5) .. " px" end, function(v) sh.px = v; shiftRestart() end)
    shPx:SetPoint("TOPLEFT", 200, y - 110)
    API.newLabel(p, "Recommended: 2 px. 1 px is barely different from nothing; above 3 px you may notice the movement.", 40, y - 142, "GameFontHighlightSmall")
    API.newLabel(p, "Move every", 40, y - 174)
    local shMin = API.makeSlider(p, 140, 1, 15, 1, function(v) return math.floor(v + 0.5) .. " min" end, function(v) sh.mins = v; shiftRestart() end)
    shMin:SetPoint("TOPLEFT", 200, y - 172)
    API.newLabel(p, "Recommended: 5 minutes. Slow enough to go unnoticed, fast enough to spread the wear.", 40, y - 204, "GameFontHighlightSmall")

    panel:SetScript("OnShow", function()
        shOn:SetChecked(sh.on and true or false)
        API.setSlider(shPx, sh.px or 2)
        API.setSlider(shMin, sh.mins or 5)
        API.evaluate()
    end)
    panel.name = "Screen Shift"
    panel:Hide()
    API.addPage("dark", "Screen Shift", panel)
    API.resetters.dark = function()
        DB.shift = { on = false, px = 2, mins = 5, i = 1 }
        sh = DB.shift
        pcall(shiftRestart)
    end
end

local prev = API.onLogin
API.onLogin = function()
    if prev then prev() end
    UbermocUIDB.dark = UbermocUIDB.dark or {}
    DB = UbermocUIDB.dark
    DB.el = nil   -- the old colour modes are gone
    DB.shift = DB.shift or { on = false, px = 2, mins = 5, i = 1 }
    API.later("Darkness", buildPage)
    shiftRestart()
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("PLAYER_ENTERING_WORLD")
    pcall(ev.RegisterEvent, ev, "PLAYER_REGEN_ENABLED")
    pcall(ev.RegisterEvent, ev, "DISPLAY_SIZE_CHANGED")
    pcall(ev.RegisterEvent, ev, "UI_SCALE_CHANGED")
    ev:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_ENABLED" then
            if shiftWaiting then shiftWaiting = false; shiftStep(false) end
        elseif event == "DISPLAY_SIZE_CHANGED" or event == "UI_SCALE_CHANGED" then
            shiftApplied = { 0, 0 }   -- WoW reset its own anchors
            C_Timer.After(0.5, function() shiftStep(false) end)
        end
    end)
end
