-- Ubermoc UI - Copyright (c) 2026 Marcos. All rights reserved.
-- This file is protected by copyright. It may not be copied, modified, redistributed or reused, in whole or
-- in part, without the written permission of the author. See LICENSE.txt.
----------------------------------------------------------------------
-- Ubermoc UI: threat circle on enemy nameplates
-- A red circle that fills counterclockwise from the top as your threat on that enemy rises, with no numbers.
-- It sits around the health percentage when the nameplate shows one (name-only mode), and at the right
-- end of the health bar otherwise. The threat value is handed straight to a status bar, which draws it,
-- so it keeps working when numbers are hidden from addons.
----------------------------------------------------------------------
local API = UbermocUIAPI
if not API then return end

local MEDIA = "Interface\\AddOns\\UbermocUI\\Media\\"

local function defaults()
    return { on = true, auto = true, size = 30, thick = 1, x = 0, y = 0 }
end

local filled   -- the settings table whose defaults are already filled in (DB() runs many times a second)
local function DB()
    UbermocUIDB = UbermocUIDB or {}
    local d = UbermocUIDB.npThreat
    if type(d) ~= "table" then d = {}; UbermocUIDB.npThreat = d end
    if d == filled then return d end   -- defaults already filled in for this table
    for k, v in pairs(defaults()) do if d[k] == nil then d[k] = v end end
    -- One time: the circle is now 1 pixel thick by default.
    if not d.v2 then d.v2 = true; if d.thick == 3 then d.thick = 1 end end
    -- One time: the circle now sits 2 pixels further right by default.
    if not d.v3 then d.v3 = true end
    -- One time: the circle is centred on the percent again (left / right back to 0).
    if not d.v4 then d.v4 = true; if d.x == 2 then d.x = 0 end end
    filled = d
    return d
end
API.npThreatDB = DB

local function isSecret(v)
    if type(issecretvalue) ~= "function" then return false end
    local ok, r = pcall(issecretvalue, v)
    return ok and r or false
end

-- One ring: a status bar drawn as a radial fill, cut into a ring by a hole mask.
local function makeRing(parent)
    local f = CreateFrame("Frame", nil, parent)
    f.bar = CreateFrame("StatusBar", nil, f)
    f.bar:SetPoint("CENTER")
    f.bar:EnableMouse(false)
    f.bar:SetStatusBarTexture(MEDIA .. "ringdisc.tga")
    f.tex = f.bar:GetStatusBarTexture()
    f.hole = f.bar:CreateMaskTexture()
    f.hole:SetTexture(MEDIA .. "ringhole.tga", "CLAMP", "CLAMP")
    f.tex:AddMaskTexture(f.hole)
    f.ready = false
    local mode = Enum and Enum.StatusBarRenderMode and Enum.StatusBarRenderMode.Radial
    if mode and f.bar.SetRenderMode then
        f.ready = pcall(function()
            f.bar:SetRenderMode(mode)
            f.tex:ClearAllPoints()
            f.tex:SetAllPoints(f.bar)
            f.tex:SetRadialProgressBarStartOffset(0)
            f.tex:SetRadialProgressBarEndOffset(0)
            f.tex:SetRadialProgressBarFeather(0)
            f.bar:SetMinMaxValues(0, 100)
            f.bar:SetValue(0)
        end)
    end
    return f
end

-- With "fit" on, the circle is sized from the health percent's text size, so "100%" always fits inside.
local function ringSize(d)
    if not d.auto then return d.size end
    local np = UbermocUIDB and UbermocUIDB.nameplates and UbermocUIDB.nameplates.enemy
    local ps = (np and np.look and np.look.pctSize) or 12
    return math.ceil(ps * 2.9 + 2 * (d.thick or 1) + 6)
end
API.threatRingSize = function() return ringSize(DB()) end

local function styleRing(f, d)
    local size = ringSize(d)
    local outer = size / 2
    local inner = math.max(1, outer - d.thick)
    f:SetSize(size, size)
    f.bar:SetSize(size, size)
    f.hole:ClearAllPoints()
    f.hole:SetPoint("CENTER", f.bar, "CENTER")
    f.hole:SetSize(inner * 4, inner * 4)
    pcall(f.tex.SetRotation, f.tex, 0)
    pcall(f.tex.SetRadialProgressBarReverse, f.tex, true) -- counterclockwise
    f.tex:SetVertexColor(1, 0.12, 0.1, 1)
end

local function plateBar(plate)
    local uf = plate and plate.UnitFrame
    return uf and (uf.HealthBarsContainer or uf.healthBar)
end

local rings = setmetatable({}, { __mode = "k" })

local function place(f, d, pct, bar)
    f:ClearAllPoints()
    if pct and pct:IsShown() then
        f:SetPoint("CENTER", pct, "CENTER", d.x, d.y)
    elseif bar then
        f:SetPoint("LEFT", bar, "RIGHT", 4 + d.x, d.y)
    end
end

local curSig   -- the ring look, worked out once per refresh
local function updatePlate(plate, d)
    local unit = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
    local r = rings[plate]
    local show = false
    if API.plateCovered and API.plateCovered(plate) then
        if r then r:Hide() end
        return
    end
    if d.on and unit then
        local okE, enemy = pcall(UnitCanAttack, "player", unit)
        if okE and enemy and not isSecret(enemy) then
            local bar = plateBar(plate)
            local uf = plate.UnitFrame
            if bar then
                if not r then
                    r = makeRing(plate)
                    rings[plate] = r
                    r:SetFrameLevel(uf:GetFrameLevel() + 25)
                end
                if r.ready then
                    local sig = curSig or ""   -- worked out once per refresh, not for every plate
                    if r.sig ~= sig then r.sig = sig; styleRing(r, d) end
                    place(r, d, uf.ubermocPct, bar)
                    local okT, _, _, scaled = pcall(UnitDetailedThreatSituation, "player", unit)
                    if okT and (type(scaled) == "number" or isSecret(scaled)) then
                        r.bar:SetMinMaxValues(0, 100)
                        if pcall(r.bar.SetValue, r.bar, scaled) then show = true end
                    end
                end
            end
        end
    end
    if r then r:SetShown(show) end
end

local anyRing = false
local function refresh()
    if not (C_NamePlate and C_NamePlate.GetNamePlates) then return end
    local d = DB()
    -- switched off with nothing left on screen: nothing to do
    if not d.on and not anyRing then return end
    curSig = ringSize(d) .. "|" .. tostring(d.thick) .. "|" .. tostring(d.x) .. "|" .. tostring(d.y)
    for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
        pcall(updatePlate, plate, d)
    end
    anyRing = d.on and true or false
end

local acc = 0
local ev = CreateFrame("Frame")
ev:RegisterEvent("NAME_PLATE_UNIT_ADDED")
-- Threat changes are picked up by the 0.2 s update below; reacting to every threat event as well
-- would redraw all plates many times a second in big fights.
ev:SetScript("OnEvent", function() if UbermocUIDB then pcall(refresh) end end)
ev:SetScript("OnUpdate", function(_, dt)
    acc = acc + dt
    if acc < 0.2 then return end
    acc = 0
    if UbermocUIDB then pcall(refresh) end
end)

-- The mock enemy nameplate in the nameplate preview: a ring two thirds full.
local pvRing
function API.previewThreat(mock, pct, show)
    local d = DB()
    if not (show and d.on) then
        if pvRing then pvRing:Hide() end
        return
    end
    if not pvRing then
        pvRing = makeRing(mock)
        pvRing:SetFrameLevel(mock:GetFrameLevel() + 12)
    end
    if not pvRing.ready then return end
    styleRing(pvRing, d)
    place(pvRing, d, pct, mock)
    pvRing.bar:SetMinMaxValues(0, 100)
    pvRing.bar:SetValue(66)
    pvRing:Show()
end

----------------------------------------------------------------------
-- Options (the Enemy Nameplates tab)
----------------------------------------------------------------------
function API.buildThreatPlateOptions(parent, y)
    local px = function(v) return math.floor(v + 0.5) .. " px" end
    local function changed()
        pcall(refresh)
        if API.refreshNpPreview then pcall(API.refreshNpPreview) end
    end
    API.newLabel(parent, "Threat circle", 8, y, "GameFontNormalLarge")
    y = y - 32
    local on = API.newCheck(parent, "Show a threat circle on enemy nameplates", 8, y, function(v) DB().on = v; changed(); parent.refreshThreat() end)
    y = y - 36
    local note = API.newLabel(parent, "A red circle that fills counterclockwise from the top as your threat on that enemy rises. It sits around the health percentage in name-only mode, otherwise at the right end of the health bar.", 8, y, "GameFontHighlightSmall")
    note:SetWidth(530); note:SetJustifyH("LEFT"); note:SetWordWrap(true)
    y = y - 44
    local fit = API.newCheck(parent, "Size the circle to fit around the health percent", 8, y, function(v) DB().auto = v; changed(); parent.refreshThreat() end)
    y = y - 38
    local sliders = {}
    local function slider(label, key, min, max)
        local lab = API.newLabel(parent, label, 40, y)
        local s = API.makeSlider(parent, 150, min, max, 1, px, function(v) DB()[key] = v; changed() end)
        s:SetPoint("TOPLEFT", 240, y)
        s.ubermocLabel = lab
        sliders[key] = s
        y = y - 36
    end
    slider("Circle size", "size", 10, 500)
    slider("Circle thickness", "thick", 1, 40)
    slider("Left / right", "x", -500, 500)
    slider("Up / down", "y", -500, 500)
    API.newButton(parent, "Reset the threat circle", 220, 8, y, function()
        local d = DB()
        for k, v in pairs(defaults()) do d[k] = v end
        parent.refreshThreat()
        changed()
    end)
    function parent.refreshThreat()
        local d = DB()
        on:SetChecked(d.on and true or false)
        fit:SetChecked(d.auto and true or false)
        API.setActive(fit, d.on)
        for k, s in pairs(sliders) do API.setSlider(s, d[k]); API.setActive(s, d.on) end
        API.setActive(sliders.size, d.on and not d.auto)
    end
    parent.refreshThreat()
end
