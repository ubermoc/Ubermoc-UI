-- Ubermoc UI - Copyright (c) 2026 Marcos. All rights reserved.
-- This file is protected by copyright. It may not be copied, modified, redistributed or reused, in whole or
-- in part, without the written permission of the author. See LICENSE.txt.
----------------------------------------------------------------------
-- Ubermoc UI: combo points
-- Dots in an arc over the top of the target halo frame, and dots or a number on the target's
-- nameplate. Sizes, gaps, positions and colours are all adjustable.
----------------------------------------------------------------------
local API = UbermocUIAPI
if not API then return end

local MEDIA = "Interface\\AddOns\\UbermocUI\\Media\\"
local CP = (Enum and Enum.PowerType and Enum.PowerType.ComboPoints) or 4
local ENERGY = (Enum and Enum.PowerType and Enum.PowerType.Energy) or 3

local function defaults()
    return {
        halo = { on = true, size = 10, gap = 4, dist = 4, r = 1, g = 0.82, b = 0.1, er = 0.12, eg = 0.12, eb = 0.15, ea = 0.9,
                 cr = 0.3, cg = 0.75, cb = 1 },
        plate = { on = true, mode = "dots", pos = "TOP", size = 8, gap = 3, x = 0, y = 4, nsize = 16,
                  r = 1, g = 0.82, b = 0.1, er = 0.12, eg = 0.12, eb = 0.15, ea = 0.9, cr = 0.3, cg = 0.75, cb = 1 },
    }
end

local filled   -- the settings table whose defaults are already filled in (DB() runs many times a second)
local function DB()
    UbermocUIDB = UbermocUIDB or {}
    local d = UbermocUIDB.combo
    if type(d) ~= "table" then d = {}; UbermocUIDB.combo = d end
    if d == filled then return d end   -- defaults already filled in for this table
    for part, t in pairs(defaults()) do
        if type(d[part]) ~= "table" then d[part] = {} end
        for k, v in pairs(t) do if d[part][k] == nil then d[part][k] = v end end
    end
    filled = d
    return d
end
API.comboDB = DB

local function isSecret(v) return issecretvalue and issecretvalue(v) end
local testing = false

-- Current and maximum combo points, which ones are charged, and whether they should show at all.
local function values()
    if testing then return 3, 5, { [2] = true } end
    local okM, mx = pcall(UnitPowerMax, "player", CP)
    if not okM or isSecret(mx) or type(mx) ~= "number" or mx <= 0 then return nil end
    local _, cls = UnitClass("player")
    if cls == "DRUID" then
        local okT, pt = pcall(UnitPowerType, "player")
        if not okT or isSecret(pt) or pt ~= ENERGY then return nil end
    elseif cls ~= "ROGUE" then
        return nil
    end
    if not UnitExists("target") then return nil end
    local okA, atk = pcall(UnitCanAttack, "player", "target")
    if not okA or isSecret(atk) or not atk then return nil end
    local okC, cur = pcall(UnitPower, "player", CP)
    if not okC or isSecret(cur) or type(cur) ~= "number" then return nil end
    local charged = {}
    if GetUnitChargedPowerPoints then
        local okP, list = pcall(GetUnitChargedPowerPoints, "player")
        if okP and type(list) == "table" then for _, i in ipairs(list) do charged[i] = true end end
    end
    return cur, mx, charged
end

-- A row of dot textures with a dark rim, created as needed.
local function dot(f, i)
    f.dots = f.dots or {}
    local d = f.dots[i]
    if d then return d end
    d = {}
    d.rim = f:CreateTexture(nil, "ARTWORK", nil, 1)
    d.rim:SetTexture(MEDIA .. "ringdisc.tga")
    d.rim:SetVertexColor(0, 0, 0, 0.9)
    d.fill = f:CreateTexture(nil, "ARTWORK", nil, 2)
    d.fill:SetTexture(MEDIA .. "ringdisc.tga")
    f.dots[i] = d
    return d
end

local function paintDot(d, c, lit, charged)
    if lit and charged then d.fill:SetVertexColor(c.cr, c.cg, c.cb, 1)
    elseif lit then d.fill:SetVertexColor(c.r, c.g, c.b, 1)
    else d.fill:SetVertexColor(c.er, c.eg, c.eb, c.ea or 0.9) end
end

local function hideDots(f, from)
    if not f.dots then return end
    for i = from, #f.dots do f.dots[i].rim:Hide(); f.dots[i].fill:Hide() end
end

-- Arc over the top of a round frame (centre `anchor`, radius `rad`), first point on the left.
local function drawArc(f, anchor, rad, c, cur, mx, charged)
    local R = rad + c.dist + c.size / 2
    local step = (c.size + c.gap) / math.max(1, R)
    for i = 1, mx do
        local d = dot(f, i)
        local a = math.pi / 2 + ((mx + 1) / 2 - i) * step
        local x, y = R * math.cos(a), R * math.sin(a)
        d.rim:ClearAllPoints(); d.rim:SetPoint("CENTER", anchor, "CENTER", x, y); d.rim:SetSize(c.size + 2, c.size + 2)
        d.fill:ClearAllPoints(); d.fill:SetPoint("CENTER", anchor, "CENTER", x, y); d.fill:SetSize(c.size, c.size)
        paintDot(d, c, i <= cur, charged[i])
        d.rim:Show(); d.fill:Show()
    end
    hideDots(f, mx + 1)
end

-- Straight row (or a number) beside `anchor` on side c.pos.
local SIDE = { TOP = { "BOTTOM", "TOP" }, BOTTOM = { "TOP", "BOTTOM" }, LEFT = { "RIGHT", "LEFT" }, RIGHT = { "LEFT", "RIGHT" } }
local function drawRow(f, anchor, c, cur, mx, charged)
    local sd = SIDE[c.pos] or SIDE.TOP
    if c.mode == "number" then
        hideDots(f, 1)
        if not f.num then
            f.num = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
            f.num:SetShadowOffset(0, 0)
        end
        pcall(f.num.SetFont, f.num, STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", c.nsize or 16, "OUTLINE")
        f.num:ClearAllPoints()
        f.num:SetPoint(sd[1], anchor, sd[2], c.x, c.y)
        local any = false
        for i = 1, cur do if charged[i] then any = true end end
        if any then f.num:SetTextColor(c.cr, c.cg, c.cb) elseif cur > 0 then f.num:SetTextColor(c.r, c.g, c.b) else f.num:SetTextColor(c.er, c.eg, c.eb) end
        f.num:SetText(cur)
        f.num:Show()
        return
    end
    if f.num then f.num:Hide() end
    local w = mx * c.size + (mx - 1) * c.gap
    local vertical = (c.pos == "LEFT" or c.pos == "RIGHT")
    for i = 1, mx do
        local d = dot(f, i)
        local off = (i - 1) * (c.size + c.gap) + c.size / 2 - w / 2
        local x, y
        if vertical then
            x = (c.pos == "LEFT" and -1 or 1) * (c.size / 2)
            y = -off
        else
            x = off
            y = (c.pos == "TOP" and 1 or -1) * (c.size / 2)
        end
        for _, t in ipairs({ d.rim, d.fill }) do
            t:ClearAllPoints()
            t:SetPoint("CENTER", anchor, sd[2], x + c.x, y + c.y)
        end
        d.rim:SetSize(c.size + 2, c.size + 2); d.fill:SetSize(c.size, c.size)
        paintDot(d, c, i <= cur, charged[i])
        d.rim:Show(); d.fill:Show()
    end
    hideDots(f, mx + 1)
end

----------------------------------------------------------------------
-- Live
----------------------------------------------------------------------
local haloF = CreateFrame("Frame", "UbermocComboHalo", UIParent)
haloF:SetFrameStrata("LOW")
haloF:SetFrameLevel(60)
haloF:SetAllPoints(UIParent)
haloF:EnableMouse(false)
local plateF = CreateFrame("Frame", "UbermocComboPlate", UIParent)
plateF:SetAllPoints(UIParent)
plateF:EnableMouse(false)

local function plateAnchor(plate)
    local uf = plate and plate.UnitFrame
    if not uf then return end
    local np = UbermocUIDB and UbermocUIDB.nameplates and UbermocUIDB.nameplates.enemy
    if np and np.look and np.look.nameOnly and uf.ubermocName and uf.ubermocName:IsShown() then return uf.ubermocName end
    return uf.healthBar or (uf.HealthBarsContainer and uf.HealthBarsContainer.healthBar) or uf.HealthBarsContainer
end

local function update()
    if not UbermocUIDB then return end
    local d = DB()
    local cur, mx, charged = values()
    -- Halo frame
    local hf, rad
    if cur and d.halo.on and API.haloFrame then hf, rad = API.haloFrame("target") end
    if hf then
        if haloF:GetParent() ~= hf then haloF:SetParent(hf); haloF:SetAllPoints(hf); haloF:SetFrameLevel(hf:GetFrameLevel() + 12) end
        drawArc(haloF, hf, rad, d.halo, cur, mx, charged)
        haloF:Show()
    else
        haloF:Hide()
    end
    -- Nameplate: only when the halo frame is not already showing the points, so they never show twice
    local plate = cur and d.plate.on and not hf and C_NamePlate and C_NamePlate.GetNamePlateForUnit and C_NamePlate.GetNamePlateForUnit("target")
    local anchor = plate and plateAnchor(plate)
    if anchor then
        if plateF:GetParent() ~= plate then
            plateF:SetParent(plate); plateF:ClearAllPoints(); plateF:SetAllPoints(plate)
            local ok, lv = pcall(anchor.GetFrameLevel, anchor)
            if ok and type(lv) == "number" and not isSecret(lv) then plateF:SetFrameLevel(lv + 20) end
        end
        drawRow(plateF, anchor, d.plate, cur, mx, charged)
        plateF:Show()
    else
        plateF:Hide()
    end
end
API.comboUpdate = function() pcall(update) end

-- Our nameplate combo points replace the game's class resource shown on the target's nameplate.
local function applyPlateResource()
    if not UbermocUIDB or InCombatLockdown() then return end
    local d = DB()
    local _, cls = UnitClass("player")
    local mine = (cls == "ROGUE" or cls == "DRUID") and d.plate.on
    local ok, cur = pcall(GetCVar, "nameplateResourceOnTarget")
    if not ok or cur == nil then return end
    if mine then
        if cur ~= "0" then d.prevRes = cur; pcall(SetCVar, "nameplateResourceOnTarget", "0") end
    elseif d.prevRes then
        pcall(SetCVar, "nameplateResourceOnTarget", d.prevRes)
        d.prevRes = nil
    end
end
API.comboPlateResource = applyPlateResource

local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_TARGET_CHANGED", "PLAYER_ENTERING_WORLD", "UPDATE_SHAPESHIFT_FORM", "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED" }) do
    pcall(ev.RegisterEvent, ev, e)
end
pcall(ev.RegisterUnitEvent, ev, "UNIT_POWER_FREQUENT", "player")
pcall(ev.RegisterUnitEvent, ev, "UNIT_MAXPOWER", "player")
pcall(ev.RegisterUnitEvent, ev, "UNIT_POWER_POINT_CHARGE", "player")
ev:SetScript("OnEvent", function(_, e)
    if e == "PLAYER_ENTERING_WORLD" then pcall(applyPlateResource) end
    pcall(update)
end)
-- A slow safety refresh, for frames that move or change size.
local acc = 0
ev:SetScript("OnUpdate", function(_, dt)
    acc = acc + dt
    if acc < 0.5 then return end
    acc = 0
    pcall(update)
end)

-- Nameplate settings preview: 3 of 5 points on the mock enemy nameplate.
function API.previewCombo(mock, anchor, show)
    local f = mock.ubermocCombo
    if not f then
        f = CreateFrame("Frame", nil, mock)
        f:SetAllPoints(mock)
        f:SetFrameLevel(mock:GetFrameLevel() + 20)
        mock.ubermocCombo = f
    end
    local c = DB().plate
    if show and c.on then
        drawRow(f, anchor or mock, c, 3, 5, { [2] = true })
        f:Show()
    else
        f:Hide()
    end
end

----------------------------------------------------------------------
-- Page
----------------------------------------------------------------------
local function buildPage()
    local panel = CreateFrame("Frame")
    panel.name = "Combo Points"
    API.newLabel(panel, "Combo Points", 16, -16, "GameFontNormalHuge")
    API.newLabel(panel, "Rogues and druids in cat form: your combo points on the target halo frame and the target's nameplate.", 16, -44, "GameFontHighlightSmall")

    -- Preview: a round frame with the arc, and a nameplate bar with the row.
    local pv = CreateFrame("Frame", nil, panel)
    pv:SetSize(250, 300)
    pv:SetPoint("TOPLEFT", 500, -76)
    local bg = pv:CreateTexture(nil, "BACKGROUND", nil, -8)
    bg:SetAllPoints(); bg:SetColorTexture(0.06, 0.08, 0.1, 0.9)
    API.newLabel(pv, "Preview", 8, -6, "GameFontHighlightSmall")
    local ring = pv:CreateTexture(nil, "BACKGROUND", nil, -2)
    ring:SetTexture(MEDIA .. "ringdisc.tga"); ring:SetVertexColor(0.17, 0.19, 0.26, 1)
    ring:SetSize(96, 96); ring:SetPoint("CENTER", pv, "TOP", 0, -130)
    local disc = pv:CreateTexture(nil, "BACKGROUND", nil, -1)
    disc:SetTexture(MEDIA .. "ringdisc.tga"); disc:SetVertexColor(0.75, 0.15, 0.15, 1)
    disc:SetSize(84, 84); disc:SetPoint("CENTER", ring, "CENTER")
    local hb = CreateFrame("Frame", nil, pv)
    hb:SetSize(150, 12); hb:SetPoint("BOTTOM", pv, "BOTTOM", 0, 50)
    local hbt = hb:CreateTexture(nil, "ARTWORK"); hbt:SetAllPoints(); hbt:SetColorTexture(0.8, 0.15, 0.15, 1)
    local hbb = hb:CreateTexture(nil, "BACKGROUND"); hbb:SetPoint("TOPLEFT", -1, 1); hbb:SetPoint("BOTTOMRIGHT", 1, -1); hbb:SetColorTexture(0, 0, 0, 1)
    local pvArc = CreateFrame("Frame", nil, pv); pvArc:SetAllPoints(pv); pvArc:SetFrameLevel(pv:GetFrameLevel() + 5)
    local pvRow = CreateFrame("Frame", nil, pv); pvRow:SetAllPoints(pv); pvRow:SetFrameLevel(pv:GetFrameLevel() + 5)

    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 8, -70)
    scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMLEFT", 480, 44)
    local sc = CreateFrame("Frame", nil, scroll)
    sc:SetSize(460, 1000)
    scroll:SetScrollChild(sc)

    local ctl = {}
    local y = -4
    local function header(t) API.newLabel(sc, t, 8, y, "GameFontNormalLarge"); y = y - 32 end
    local function check(part, key, text)
        ctl[part .. key] = API.newCheck(sc, text, 8, y, function(v) DB()[part][key] = v; panel.refresh() end)
        y = y - 32
    end
    local px = function(v) return math.floor(v + 0.5) .. " px" end
    local function slider(part, key, text, min, max)
        local lab = API.newLabel(sc, text, 30, y)
        local s = API.makeSlider(sc, 140, min, max, 1, px, function(v) DB()[part][key] = v; panel.refresh() end)
        s:SetPoint("TOPLEFT", 240, y)
        s.ubermocLabel = lab
        ctl[part .. key] = s
        y = y - 38
    end
    local function swatch(part, pre, text, alpha)
        local lab = API.newLabel(sc, text, 30, y - 4)
        local b = CreateFrame("Button", nil, sc)
        b:SetSize(28, 28); b:SetPoint("TOPLEFT", 240, y + 2)
        API.flatButton(b)
        b.ubermocLabel = lab
        local t = b:CreateTexture(nil, "ARTWORK"); t:SetPoint("TOPLEFT", 4, -4); t:SetPoint("BOTTOMRIGHT", -4, 4)
        b.paint = function() local c = DB()[part]; t:SetColorTexture(c[pre .. "r"] or c.r, c[pre .. "g"] or c.g, c[pre .. "b"] or c.b, 1) end
        b:SetScript("OnClick", function()
            local c = DB()[part]
            local kr, kg, kb = pre .. "r", pre .. "g", pre .. "b"
            if pre == "" then kr, kg, kb = "r", "g", "b" end
            local a = alpha and (c[pre .. "a"] or 1) or nil
            API.pickColor(c[kr], c[kg], c[kb], a, function(r, g, bb, na)
                c[kr], c[kg], c[kb] = r, g, bb
                if alpha and na then c[pre .. "a"] = na end
                panel.refresh()
            end)
        end)
        ctl[part .. "sw" .. pre] = b
        y = y - 38
    end

    header("On the target halo frame")
    check("halo", "on", "Dots in an arc over the top of the target halo frame")
    slider("halo", "size", "Dot size", 4, 40)
    slider("halo", "gap", "Gap between dots", 0, 30)
    slider("halo", "dist", "Distance from the frame", -20, 60)
    swatch("halo", "", "Filled colour")
    swatch("halo", "e", "Empty colour (with opacity)", true)
    swatch("halo", "c", "Charged colour")
    y = y - 10
    header("On the target's nameplate")
    check("plate", "on", "Combo points on the target's nameplate")
    API.newLabel(sc, "Show as", 30, y - 4)
    local modeBtn = API.segRow(sc, 208, y, { { "dots", "Dots", 80 }, { "number", "A number", 90 } },
        function() return DB().plate.mode == "number" and "number" or "dots" end,
        function(v) DB().plate.mode = v; panel.refresh() end)
    ctl.platemode = modeBtn
    y = y - 40
    API.newLabel(sc, "Position", 30, y - 4)
    local posBtn = API.segRow(sc, 208, y, { { "TOP", "Above", 64 }, { "BOTTOM", "Below", 64 }, { "LEFT", "Left", 64 }, { "RIGHT", "Right", 64 } },
        function() return DB().plate.pos or "TOP" end, function(v) DB().plate.pos = v; panel.refresh() end)
    ctl.platepos = posBtn
    y = y - 40
    slider("plate", "x", "Left / right", -200, 200)
    slider("plate", "y", "Up / down", -200, 200)
    slider("plate", "size", "Dot size", 4, 40)
    slider("plate", "gap", "Gap between dots", 0, 30)
    slider("plate", "nsize", "Number size", 8, 48)
    swatch("plate", "", "Filled colour (and the number)")
    swatch("plate", "e", "Empty colour (with opacity)", true)
    swatch("plate", "c", "Charged colour")
    y = y - 6
    local test = API.newCheck(sc, "Show 3 combo points now, on any target (to set them up)", 8, y, function(v) testing = v; pcall(update) end)
    y = y - 40
    API.newButton(sc, "Reset combo points", 200, 8, y, function()
        UbermocUIDB.combo = nil; DB(); panel.refresh()
    end)
    sc:SetHeight(-y + 50)

    function panel.refresh()
        pcall(applyPlateResource)
        local d = DB()
        for _, part in ipairs({ "halo", "plate" }) do
            for k, w in pairs(ctl) do
                if k:sub(1, #part) == part then
                    local key = k:sub(#part + 1)
                    if w.paint then w.paint()
                    elseif w.SetChecked then w:SetChecked(d[part][key] and true or false)
                    elseif key ~= "mode" and key ~= "pos" and d[part][key] ~= nil and type(d[part][key]) == "number" then API.setSlider(w, d[part][key]) end
                end
            end
        end
        modeBtn.refresh(); posBtn.refresh()
        test:SetChecked(testing)
        local hOn, pOn = d.halo.on, d.plate.on
        for k, w in pairs(ctl) do
            if k ~= "haloon" and k ~= "plateon" then
                local isHalo = k:sub(1, 4) == "halo"
                local on = isHalo and hOn or (not isHalo and pOn)
                if pOn and not isHalo then
                    if d.plate.mode == "number" and (k == "platesize" or k == "plategap") then on = false end
                    if d.plate.mode ~= "number" and k == "platensize" then on = false end
                end
                API.setActive(w, on and true or false)
            end
        end
        -- Preview
        if hOn then drawArc(pvArc, ring, 48, d.halo, 3, 5, { [2] = true }); pvArc:Show() else pvArc:Hide() end
        if pOn then drawRow(pvRow, hb, d.plate, 3, 5, { [2] = true }); pvRow:Show() else pvRow:Hide() end
        pcall(update)
        if API.refreshNpPreview then pcall(API.refreshNpPreview) end
    end
    panel:SetScript("OnShow", function() panel.refresh() end)
    panel:SetScript("OnHide", function() if testing then testing = false; pcall(update) end end)
    API.resetters = API.resetters or {}
    API.resetters.combo = function() UbermocUIDB.combo = nil; DB() end
    API.addPage("combo", "Combo Points", panel)
end

local prev = API.onLogin
API.onLogin = function()
    if prev then prev() end
    DB()
    API.later("Combo points", buildPage)
end
