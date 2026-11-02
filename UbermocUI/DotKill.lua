-- Ubermoc UI - Copyright (c) 2026 Marcos. All rights reserved.
-- This file is protected by copyright. It may not be copied, modified, redistributed or reused, in whole or
-- in part, without the written permission of the author. See LICENSE.txt.
----------------------------------------------------------------------
-- Ubermoc UI: kill indicator
-- Shows a skull (or another icon) on an enemy nameplate when the damage your damage-over-time spells
-- still have to deal is enough to finish that enemy.
--
-- Target health is a secret value in combat, so this code never compares health with damage itself.
-- The remaining damage is worked out here from the spell descriptions and the sizes of the ticks seen,
-- then both numbers are handed to a status bar, which does the comparing: the icon rides the end of a
-- very long bar inside a clipping window, so it only slides into view when damage reaches health.
----------------------------------------------------------------------
local API = UbermocUIAPI
if not API then return end

local ICONS = {
    { id = "skull", label = "Raid skull", path = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8" },
    { id = "boss", label = "Boss skull", path = "Interface\\TargetingFrame\\UI-TargetingFrame-Skull" },
    { id = "cross", label = "Red X", path = "Interface\\RaidFrame\\ReadyCheck-NotReady" },
}
local BAR_LENGTH = 10000
local WHITE = "Interface\\Buttons\\WHITE8X8"

local function defaults()
    return { on = true, icon = "skull", size = 18, pos = "left", x = 0, y = 0, test = false, ticks = {} }
end

local filled   -- the settings table whose defaults are already filled in (DB() runs many times a second)
local function DB()
    UbermocUIDB = UbermocUIDB or {}
    local d = UbermocUIDB.kill
    if type(d) ~= "table" then d = {}; UbermocUIDB.kill = d end
    if d == filled then return d end   -- defaults already filled in for this table
    for k, v in pairs(defaults()) do if d[k] == nil then d[k] = v end end
    -- One time: the new default place (left of the bar, 80 across) replaces the old untouched default.
    if not d.v2 then
        d.v2 = true
        if d.pos == "above" and d.x == 0 and d.y == 18 then d.pos, d.x, d.y = "left", 80, 0 end
    end
    -- One time: the default place is now just left of the name.
    if not d.v3 then d.v3 = true; if d.pos == "left" and d.x == 80 and d.y == 0 then d.x = 0 end end
    filled = d
    return d
end
API.killDB = DB

local function isSecret(v)
    if type(issecretvalue) ~= "function" then return false end
    local ok, r = pcall(issecretvalue, v)
    return ok and r or false
end

----------------------------------------------------------------------
-- Reading what a spell does
----------------------------------------------------------------------
local SCHOOL = { Physical = 1, Holy = 2, Fire = 4, Nature = 8, Frost = 16, Shadow = 32, Arcane = 64 }
local DEFAULT_INTERVAL = 3
local KNOWN_INTERVAL = {
    ["Insect Swarm"] = 2, ["Curse of Agony"] = 2, ["Bane of Agony"] = 2, ["Fireball"] = 2,
    ["Holy Fire"] = 2, ["Rip"] = 2, ["Rupture"] = 2,
}
-- Spells whose ticks grow over time (the first ticks are small, the last are big). Their remaining damage
-- is deliberately underestimated: every tick left counts as the smallest one, so there is never a false skull.
local UNEVEN = { ["Bane of Agony"] = true, ["Curse of Agony"] = true }
local IGNORED = {
    ["Rain of Fire"] = true, ["Hellfire"] = true, ["Blizzard"] = true, ["Flamestrike"] = true,
    ["Consecration"] = true, ["Hurricane"] = true, ["Volley"] = true, ["Drain Life"] = true,
    ["Drain Soul"] = true, ["Drain Mana"] = true, ["Health Funnel"] = true, ["Mind Flay"] = true,
    ["Arcane Missiles"] = true, ["Immolation Trap"] = true, ["Explosive Trap"] = true, ["Wyvern Sting"] = true,
}

local function schoolOf(words)
    local m = SCHOOL.Physical
    for w in (words or ""):gmatch("%a+") do
        if SCHOOL[w] then m = SCHOOL[w] end
    end
    return m
end

-- Total damage, school, duration and (when stated) seconds between ticks, from a spell description.
local function readDot(desc)
    if type(desc) ~= "string" or isSecret(desc) then return nil end
    if desc:find("Finishing move") or desc:find("[Cc]oats a weapon") or desc:find("^Heals") then return nil end
    local total, school, duration
    for amount, words, secs in desc:gmatch("(%d+)%s*([%a ]-)%s*damage over (%d+%.?%d*) sec") do
        total, school, duration = tonumber(amount), schoolOf(words), tonumber(secs)
    end
    if total and duration > 0 then return total, school, duration end
    local amount, words, every = desc:match("(%d+)%s*([%a ]-)%s*damage every (%d+%.?%d*) sec")
    local lasts = desc:match("[Ll]asts (%d+%.?%d*) sec")
    if amount and every and lasts then
        every, lasts = tonumber(every), tonumber(lasts)
        if every > 0 and lasts > 0 then
            return tonumber(amount) * math.floor(lasts / every + 0.5), schoolOf(words), lasts, every
        end
    end
end

----------------------------------------------------------------------
-- Tracking your damage-over-time effects per enemy
----------------------------------------------------------------------
local dots = {}   -- enemy key -> spell name -> record
local MATCH = 0.45

local function keyOf(unit)
    local ok, guid = pcall(UnitGUID, unit)
    if ok and guid and not isSecret(guid) then return guid end
    if unit == "target" then return "target" end
    return nil
end

local function expected(d)
    if d.uneven then return d.minTick or (d.total / d.count) * 0.5 end
    if d.normal > 0 then return d.sum / d.normal end
    local saved = DB().ticks[d.spellID]
    return saved or (d.total / d.count)
end

local function onCast(spellID)
    local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID)
    if not name or isSecret(name) or IGNORED[name] then return end
    local descFn = (C_Spell and C_Spell.GetSpellDescription) or GetSpellDescription
    local desc = descFn and descFn(spellID)
    local total, school, duration, every = readDot(desc)
    if not total then return end
    local key = keyOf("target")
    if not key then return end
    local now = GetTime()
    local interval = every or KNOWN_INTERVAL[name] or DEFAULT_INTERVAL
    dots[key] = dots[key] or {}
    dots[key][name] = {
        spellID = spellID, school = school, total = total, interval = interval,
        count = math.max(1, math.floor(duration / interval + 0.5)),
        appliedAt = now, expiresAt = now + duration, nextAt = now + interval,
        sum = 0, normal = 0, seen = 0, missed = 0, uneven = UNEVEN[name] and true or false,
    }
end

local lastHit
local function onCombat(unit, action, flag, amount, school)
    if isSecret(action) or action ~= "WOUND" then return end
    if isSecret(amount) or isSecret(school) or type(amount) ~= "number" or type(school) ~= "number" then return end
    local key = keyOf(unit)
    local set = key and dots[key]
    if not set then return end
    local now = GetTime()
    local sig = key .. ":" .. amount .. ":" .. school .. ":" .. string.format("%.2f", now)
    if sig == lastHit then return end
    lastHit = sig
    local crit = not isSecret(flag) and flag == "CRITICAL"
    local best, bestDist
    for _, d in pairs(set) do
        if d.school == school then
            local n = math.max(1, math.floor((now - d.appliedAt) / d.interval + 0.5))
            local dist = math.abs(now - (d.appliedAt + n * d.interval))
            local ref = expected(d)
            local ratio = amount / math.max(ref, 1)
            local sized = d.uneven or crit and (ratio > 1.2 and ratio < 2.4) or (ratio > 0.5 and ratio < 1.8)
            if dist <= MATCH and sized and (not bestDist or dist < bestDist) then best, bestDist = d, dist end
        end
    end
    if not best then return end
    best.seen = best.seen + 1
    if best.uneven then
        if not crit and (not best.minTick or amount < best.minTick) then best.minTick = amount end
    elseif not crit then
        best.sum = best.sum + amount
        best.normal = best.normal + 1
        DB().ticks[best.spellID] = best.sum / best.normal
    end
end

local function remaining(d)
    if d.nextAt > d.expiresAt + d.interval / 2 then return 0 end
    local left = math.floor((d.expiresAt - d.nextAt) / d.interval + 0.5) + 1
    return left * expected(d)
end

local function housekeep(now)
    for key, set in pairs(dots) do
        for name, d in pairs(set) do
            while d.nextAt < now - MATCH and d.nextAt <= d.expiresAt do
                d.nextAt = d.nextAt + d.interval
                if d.seen == 0 then d.missed = d.missed + 1 end
            end
            if now > d.expiresAt + MATCH or (d.seen == 0 and d.missed >= 2) then set[name] = nil end
        end
        if next(set) == nil then dots[key] = nil end
    end
end

local function damageOn(unit)
    local set = dots[keyOf(unit) or ""]
    if not set then return 0 end
    local total = 0
    for _, d in pairs(set) do total = total + remaining(d) end
    return math.floor(total + 0.5)
end

----------------------------------------------------------------------
-- The icon on each enemy nameplate
----------------------------------------------------------------------
local pvIcon
local widgets = setmetatable({}, { __mode = "k" })

local function plateBar(plate)
    local uf = plate and plate.UnitFrame
    if not uf then return nil end
    -- Name-only mode: no health bar to point at, so the icon hangs on the name.
    local np = UbermocUIDB and UbermocUIDB.nameplates and UbermocUIDB.nameplates.enemy
    local ours = uf.ubermocName
    if np and np.look and np.look.nameOnly and ours and ours:IsShown() then return ours end
    return uf.healthBar or (uf.HealthBarsContainer and uf.HealthBarsContainer.healthBar) or uf.HealthBarsContainer
end

local function makeWidget(plate, bar)
    local w = { bar = bar }
    w.window = CreateFrame("Frame", nil, plate)
    w.window:SetClipsChildren(true)
    w.sb = CreateFrame("StatusBar", nil, w.window)
    w.sb:SetStatusBarTexture(WHITE)
    w.sb:SetStatusBarColor(0, 0, 0, 0)
    w.sb:SetPoint("RIGHT", w.window, "RIGHT")
    w.icon = w.sb:CreateTexture(nil, "OVERLAY")
    w.icon:SetPoint("RIGHT", w.sb:GetStatusBarTexture(), "RIGHT")
    local ok, lvl = pcall(bar.GetFrameLevel, bar)
    if not ok or isSecret(lvl) or type(lvl) ~= "number" then lvl = 200 end
    w.window:SetFrameLevel(lvl + 20)
    w.sb:SetFrameLevel(lvl + 21)
    widgets[plate] = w
    return w
end

local function iconPath(id)
    for _, i in ipairs(ICONS) do if i.id == id then return i.path end end
    return ICONS[1].path
end

local function style(w, c)
    -- compared field by field (no new table or text on every update)
    if w.sIcon == c.icon and w.sSize == c.size and w.sPos == c.pos and w.sX == c.x and w.sY == c.y then return end
    w.sIcon, w.sSize, w.sPos, w.sX, w.sY = c.icon, c.size, c.pos, c.x, c.y
    w.window:SetSize(c.size, c.size)
    w.sb:SetSize(BAR_LENGTH, c.size)
    w.icon:SetSize(c.size, c.size)
    w.icon:SetTexture(iconPath(c.icon))
    w.window:ClearAllPoints()
    local y = c.y
    if c.pos == "left" then w.window:SetPoint("RIGHT", w.bar, "LEFT", -4 + c.x, y)
    elseif c.pos == "right" then w.window:SetPoint("LEFT", w.bar, "RIGHT", 4 + c.x, y)
    else w.window:SetPoint("BOTTOM", w.bar, "TOP", c.x, 4 + y) end
end

function API.killFrame(plate)
    local w = widgets[plate]
    return w and w.window
end
function API.previewKillFrame() return pvIcon end

local function fillBar(w, c, unit, damage)
    if c.test then
        w.sb:SetMinMaxValues(0, 1)
        w.sb:SetValue(1)
    else
        w.sb:SetMinMaxValues(0, UnitHealth(unit))
        w.sb:SetValue(damage)
    end
end
local function drawPlate(unit, plate, c)
    local w = widgets[plate]
    if API.plateCovered and API.plateCovered(plate) then
        if w then w.window:Hide() end
        return
    end
    if not (UnitCanAttack and UnitCanAttack("player", unit)) then
        if w then w.window:Hide() end
        return
    end
    local damage = damageOn(unit)
    if damage <= 0 and not c.test then
        if w then w.window:Hide() end
        return
    end
    local bar = plateBar(plate)
    if not bar then return end
    if w and w.bar ~= bar then w.window:Hide() end
    if not w or w.bar ~= bar then w = makeWidget(plate, bar) end
    style(w, c)
    local ok = pcall(fillBar, w, c, unit, damage)
    w.window:SetShown(ok)
end

local function hideAll()
    for _, w in pairs(widgets) do w.window:Hide() end
end

local ev = CreateFrame("Frame")
local listening = false
local function setListening(on)
    listening = on
    if on then
        ev:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
        ev:RegisterEvent("UNIT_COMBAT")
    else
        ev:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED")
        ev:UnregisterEvent("UNIT_COMBAT")
        hideAll()
    end
end
local acc = 0
local ticker = CreateFrame("Frame")
ticker:SetScript("OnUpdate", function(_, dt)
    acc = acc + dt
    if acc < 0.1 then return end
    acc = 0
    local c = UbermocUIDB and UbermocUIDB.kill
    local on = type(c) == "table" and c.on and true or false
    -- Every hit on every unit nearby is only listened to while the indicator is on.
    if on ~= listening then setListening(on) end
    if not on then return end
    housekeep(GetTime())
    if not (C_NamePlate and C_NamePlate.GetNamePlates) then return end
    for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
        local unit = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
        if unit then pcall(drawPlate, unit, plate, c) end
    end
end)

ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:SetScript("OnEvent", function(_, event, unit, a, b, c4, d)
    if not UbermocUIDB then return end
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        if unit == "player" and not isSecret(b) and type(b) == "number" then
            local c = DB()
            if c.on then pcall(onCast, b) end
        end
    elseif event == "UNIT_COMBAT" then
        local c = DB()
        if c.on then pcall(onCombat, unit, a, b, c4, d) end
    elseif event == "PLAYER_ENTERING_WORLD" then
        DB().test = false
    end
end)

-- The mock nameplate in the nameplate preview: same icon, size and placement rules as the real ones.
function API.previewKill(mock, show, anchor)
    local c = DB()
    if not (show and c.on) then
        if pvIcon then pvIcon:Hide() end
        return
    end
    if not pvIcon then
        pvIcon = mock:CreateTexture(nil, "OVERLAY", nil, 7)
    end
    pvIcon:SetSize(c.size, c.size)
    pvIcon:SetTexture(iconPath(c.icon))
    pvIcon:ClearAllPoints()
    anchor = anchor or mock
    if c.pos == "left" then pvIcon:SetPoint("RIGHT", anchor, "LEFT", -4 + c.x, c.y)
    elseif c.pos == "right" then pvIcon:SetPoint("LEFT", anchor, "RIGHT", 4 + c.x, c.y)
    else pvIcon:SetPoint("BOTTOM", anchor, "TOP", c.x, 4 + c.y) end
    pvIcon:Show()
end

----------------------------------------------------------------------
-- Options (the Nameplate options tab)
----------------------------------------------------------------------
function API.buildKillOptions(parent, y)
    local function pv() if API.refreshNpPreview then pcall(API.refreshNpPreview) end end
    local px = function(v) return math.floor(v + 0.5) .. " px" end
    local function c() return DB() end
    API.newLabel(parent, "Kill indicator", 8, y, "GameFontNormalLarge")
    y = y - 32
    API.newLabel(parent, "Shows an icon on an enemy nameplate when your damage-over-time spells will finish it.", 8, y, "GameFontHighlightSmall")
    y = y - 28
    local on = API.newCheck(parent, "Show the kill indicator", 8, y, function(v) c().on = v; if not v then hideAll() end; pv(); parent.refreshKill() end)
    y = y - 36
    local test = API.newCheck(parent, "Show it on every enemy nameplate (to place it)", 8, y, function(v) c().test = v end)
    y = y - 40
    API.newLabel(parent, "Icon", 40, y - 4)
    local iconBtn = API.segRow(parent, 208, y, { { "skull", "Raid skull", 96 }, { "boss", "Boss skull", 96 }, { "cross", "Red X", 70 } },
        function() return c().icon or "skull" end, function(v) c().icon = v; pv() end)
    y = y - 40
    API.newLabel(parent, "Position", 40, y - 4)
    local posBtn = API.segRow(parent, 208, y, { { "above", "Above", 70 }, { "left", "Left", 70 }, { "right", "Right", 70 } },
        function() return c().pos or "above" end, function(v) c().pos = v; pv() end)
    y = y - 40
    local sliders = {}
    local function slider(label, key, min, max)
        local lab = API.newLabel(parent, label, 40, y)
        local s = API.makeSlider(parent, 150, min, max, 1, px, function(v) c()[key] = v; pv() end)
        s:SetPoint("TOPLEFT", 240, y)
        s.ubermocLabel = lab
        sliders[key] = s
        y = y - 36
    end
    slider("Icon size", "size", 10, 500)
    slider("Left / right", "x", -500, 500)
    slider("Up / down", "y", -500, 500)
    API.newButton(parent, "Reset the kill indicator", 220, 8, y, function()
        local d = DB()
        local keep = d.ticks
        for k, v in pairs(defaults()) do d[k] = v end
        d.ticks = keep
        parent.refreshKill()
        pv()
    end)
    function parent.refreshKill()
        local d = c()
        on:SetChecked(d.on and true or false)
        test:SetChecked(d.test and true or false)
        iconBtn.refresh(); posBtn.refresh()
        for k, s in pairs(sliders) do API.setSlider(s, d[k]) end
        for _, w in ipairs({ test, iconBtn, posBtn, sliders.size, sliders.x, sliders.y }) do API.setActive(w, d.on) end
    end
    parent.refreshKill()
end
