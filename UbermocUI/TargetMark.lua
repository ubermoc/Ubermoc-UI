-- Ubermoc UI - Copyright (c) 2026 Marcos. All rights reserved.
-- This file is protected by copyright. It may not be copied, modified, redistributed or reused, in whole or
-- in part, without the written permission of the author. See LICENSE.txt.
----------------------------------------------------------------------
-- Ubermoc UI: target indicators on enemy nameplates
-- A few ways to see which enemy is your target: arrows beside the health bar, an arrow above it,
-- and a coloured outline around the bar. Also decides whether the game's own soft-target icon (the
-- sword that pops up above an enemy) is shown; it is hidden unless you switch it on.
----------------------------------------------------------------------
local API = UbermocUIAPI
if not API then return end

local STYLES = {
    { id = "pointer", label = "Pointer", atlas = "Navigation-Tracked-Arrow", points = 0, aspect = 0.65 },
    { id = "chevron", label = "Chevron", atlas = "UI-WorldMapArrow", points = 0, aspect = 0.9 },
    { id = "delve", label = "Bold arrow", atlas = "UI-Journeys-Delve-Arrow-Small-Left-pressed", points = 270, aspect = 1.2 },
    { id = "helptip", label = "Tip arrow", atlas = "ItemUpgrade_HelpTipArrow", points = 90, aspect = 1 },
    { id = "green", label = "Green arrow", atlas = "bags-greenarrow", points = 0, aspect = 1.1 },
}
local COLORS = {
    { id = "white", label = "White", c = { 1, 1, 1 } },
    { id = "red", label = "Red", c = { 1, 0.15, 0.15 } },
    { id = "yellow", label = "Yellow", c = { 1, 0.85, 0.1 } },
    { id = "green", label = "Green", c = { 0.3, 1, 0.3 } },
    { id = "cyan", label = "Cyan", c = { 0.2, 0.9, 1 } },
    { id = "orange", label = "Orange", c = { 1, 0.55, 0.1 } },
}
local WHITE = "Interface\\Buttons\\WHITE8X8"

local function defaults()
    return {
        side = true, above = false, outline = false, softIcon = false,
        style = "pointer", color = "yellow", size = 16, gap = 20, y = 0, aboveY = 24,
        outlineSize = 2, outlineColor = "yellow",
    }
end

local filled   -- the settings table whose defaults are already filled in (DB() runs many times a second)
local function DB()
    UbermocUIDB = UbermocUIDB or {}
    local d = UbermocUIDB.targetMark
    if type(d) ~= "table" then d = {}; UbermocUIDB.targetMark = d end
    if d == filled then return d end   -- defaults already filled in for this table
    for k, v in pairs(defaults()) do if d[k] == nil then d[k] = v end end
    -- One time: the arrows now start 20 pixels from the bar.
    if not d.v2 then d.v2 = true; if d.gap == 4 then d.gap = 20 end end
    filled = d
    return d
end
API.targetMarkDB = DB

local function find(list, id)
    for i, e in ipairs(list) do if e.id == id then return e, i end end
    return list[1], 1
end

local function isSecret(v)
    if type(issecretvalue) ~= "function" then return false end
    local ok, r = pcall(issecretvalue, v)
    return ok and r or false
end

local function plateBar(plate)
    local uf = plate and plate.UnitFrame
    if not uf then return nil end
    -- Name-only mode: no health bar to point at, so the indicators hang on the name.
    local np = UbermocUIDB and UbermocUIDB.nameplates and UbermocUIDB.nameplates.enemy
    local ours = uf.ubermocName
    if np and np.look and np.look.nameOnly and ours and ours:IsShown() then return ours end
    return uf.healthBar or (uf.HealthBarsContainer and uf.HealthBarsContainer.healthBar) or uf.HealthBarsContainer
end

local marks = setmetatable({}, { __mode = "k" })

local function makeMark(plate, bar)
    local m = { bar = bar }
    m.frame = CreateFrame("Frame", nil, plate)
    m.frame:SetAllPoints(plate)
    local ok, lvl = pcall(bar.GetFrameLevel, bar)
    if not ok or isSecret(lvl) or type(lvl) ~= "number" then lvl = 200 end
    m.frame:SetFrameLevel(lvl + 30) -- above the kill icon, so the arrows can sit on top of it
    m.left = m.frame:CreateTexture(nil, "OVERLAY")
    m.right = m.frame:CreateTexture(nil, "OVERLAY")
    m.top = m.frame:CreateTexture(nil, "OVERLAY")
    m.edges = {}
    for i = 1, 4 do
        m.edges[i] = m.frame:CreateTexture(nil, "OVERLAY")
        m.edges[i]:SetTexture(WHITE)
    end
    marks[plate] = m
    return m
end

-- Draws one arrow texture pointing in direction `dir` (degrees clockwise from up).
local function arrow(tex, st, dir, size, color)
    tex:SetAtlas(st.atlas)
    tex:SetSize(size, size * st.aspect)
    tex:SetRotation(-math.rad(dir - st.points))
    tex:SetVertexColor(color[1], color[2], color[3], 1)
    tex:Show()
end

local function applyMarkTo(plate, bar, d, frames)
    if not bar then return end
    local m = marks[plate]
    if m and m.bar ~= bar then m.frame:Hide() end
    if not m or m.bar ~= bar then m = makeMark(plate, bar) end
    local st = find(STYLES, d.style)
    local col = find(COLORS, d.color).c
    if d.side then
        arrow(m.left, st, 90, d.size, col)
        m.left:ClearAllPoints()
        -- frames.left / frames.right: the outermost thing beside the name on that side, if any.
        local lf = (frames and frames.left) or bar
        local rf = (frames and frames.right) or bar
        m.left:SetPoint("RIGHT", lf, "LEFT", -d.gap, d.y)
        arrow(m.right, st, 270, d.size, col)
        m.right:ClearAllPoints()
        m.right:SetPoint("LEFT", rf, "RIGHT", d.gap, d.y)
    else
        m.left:Hide(); m.right:Hide()
    end
    if d.above then
        arrow(m.top, st, 180, d.size, col)
        m.top:ClearAllPoints()
        m.top:SetPoint("BOTTOM", bar, "TOP", 0, d.aboveY)
    else
        m.top:Hide()
    end
    local oOn, t, oR, oG, oB, oA = API.borderOf("npTarget")
    if oOn then
        local e = m.edges
        for i = 1, 4 do e[i]:SetVertexColor(oR, oG, oB, oA); e[i]:ClearAllPoints() end
        e[1]:SetPoint("BOTTOMLEFT", bar, "TOPLEFT", -t, 0); e[1]:SetPoint("BOTTOMRIGHT", bar, "TOPRIGHT", t, 0); e[1]:SetHeight(t)
        e[2]:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", -t, 0); e[2]:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", t, 0); e[2]:SetHeight(t)
        e[3]:SetPoint("TOPRIGHT", bar, "TOPLEFT", 0, 0); e[3]:SetPoint("BOTTOMRIGHT", bar, "BOTTOMLEFT", 0, 0); e[3]:SetWidth(t)
        e[4]:SetPoint("TOPLEFT", bar, "TOPRIGHT", 0, 0); e[4]:SetPoint("BOTTOMLEFT", bar, "BOTTOMRIGHT", 0, 0); e[4]:SetWidth(t)
        for i = 1, 4 do e[i]:Show() end
    else
        for i = 1, 4 do m.edges[i]:Hide() end
    end
    m.frame:Show()
end

local scratch = {}   -- reused: this runs for the target plate many times a second
local function applyMark(plate, d)
    local frames = scratch
    frames.left, frames.right = nil, nil
    if API.plateIcons then pcall(API.plateIcons, plate, frames) end
    return applyMarkTo(plate, plateBar(plate), d, frames)
end

local function hideMark(plate)
    local m = marks[plate]
    if m then m.frame:Hide() end
end

-- The mock nameplate in the nameplate preview uses the very same drawing code as the real plates.
function API.previewTargetMark(mock, show, anchor, frames)
    local d = DB()
    if show and (d.side or d.above or (API.borderOf("npTarget"))) then
        applyMarkTo(mock, anchor or mock, d, frames)
    else
        hideMark(mock)
    end
end

local testing = false
local function refresh()
    local d = DB()
    if not (C_NamePlate and C_NamePlate.GetNamePlates) then return end
    local targetPlate = UnitExists("target") and C_NamePlate.GetNamePlateForUnit and C_NamePlate.GetNamePlateForUnit("target")
    for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
        local unit = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
        local enemy = false
        if unit then
            local ok, r = pcall(UnitCanAttack, "player", unit)
            enemy = ok and r and not isSecret(r) or false
        end
        -- The game's soft-target icon (the sword over an enemy): alpha only, enemies only.
        local stf = plate.UnitFrame and plate.UnitFrame.SoftTargetFrame
        if stf and stf.SetAlpha then
            local want = (enemy and not d.softIcon) and 0 or 1
            local okA, cur = pcall(stf.GetAlpha, stf)
            if not okA or isSecret(cur) or cur ~= want then pcall(stf.SetAlpha, stf, want) end   -- only when it differs
        end
        -- Target markers: on the current target only (or on every enemy while placing them).
        if enemy and not (API.plateCovered and API.plateCovered(plate)) and (plate == targetPlate or testing) and (d.side or d.above or (API.borderOf("npTarget"))) then
            pcall(applyMark, plate, d)
        else
            hideMark(plate)
        end
    end
end

-- The game's sword icon over the enemy you would attack is its own setting; follow the checkbox.
local function applySoftIcon()
    local want = DB().softIcon and "1" or "0"
    local ok, cur = pcall(GetCVar, "SoftTargetIconEnemy")
    if ok and cur ~= nil and cur ~= want then pcall(SetCVar, "SoftTargetIconEnemy", want) end
end

local function changed()
    pcall(applySoftIcon)
    pcall(refresh)
    if API.refreshNpPreview then pcall(API.refreshNpPreview) end
end

local acc = 0
local ticker = CreateFrame("Frame")
ticker:RegisterEvent("PLAYER_TARGET_CHANGED")
ticker:RegisterEvent("NAME_PLATE_UNIT_ADDED")
ticker:RegisterEvent("PLAYER_ENTERING_WORLD")
ticker:SetScript("OnEvent", function(_, event)
    if not UbermocUIDB then return end
    if event == "PLAYER_ENTERING_WORLD" then testing = false; pcall(applySoftIcon) end
    pcall(refresh)
end)
ticker:SetScript("OnUpdate", function(_, dt)
    acc = acc + dt
    if acc < 0.25 then return end
    acc = 0
    if UbermocUIDB then pcall(refresh) end
end)

----------------------------------------------------------------------
-- Options (the Enemy Nameplates tab)
----------------------------------------------------------------------
-- The outline around the target's health bar (Textures page, Nameplates tab).
API.registerBorder({ key = "npTarget", part = "nameplates", label = "Target outline", on = false, size = 2, maxSize = 8,
    legacy = function()
        local d = UbermocUIDB.targetMark or {}
        local oc = find(COLORS, d.outlineColor or "yellow").c
        local custom = (d.outlineColor or "yellow") ~= "yellow"
        return d.outline and true or false, d.outlineSize or 2, 100, custom and "custom" or "class", oc[1], oc[2], oc[3]
    end,
    apply = function() pcall(changed) end })

function API.buildTargetMarkOptions(parent, y)
    local px = function(v) return math.floor(v + 0.5) .. " px" end
    local function d() return DB() end
    API.newLabel(parent, "Target indicators", 8, y, "GameFontNormalLarge")
    y = y - 32
    local intro = API.newLabel(parent, "Ways to see which enemy is your target.", 8, y, "GameFontHighlightSmall")
    y = y - 28
    local checks = {}
    local function check(text, key)
        checks[key] = API.newCheck(parent, text, 8, y, function(v) d()[key] = v; changed(); if parent.refreshMarks then parent.refreshMarks() end end)
        y = y - 34
    end
    check("Arrows on the left and right of the nameplate", "side")
    check("Arrow above the nameplate", "above")
    check("Show the game's sword icon over enemies", "softIcon")
    local test
    test = API.newCheck(parent, "Show the indicators on every enemy nameplate (to place them)", 8, y, function(v) testing = v; changed() end)
    y = y - 44
    local btns = {}
    local function cycler(label, list, key)
        local lab = API.newLabel(parent, label, 40, y - 4)
        local L = {}
        for i, o in ipairs(list) do L[i] = { o.id, o.label } end
        local b = API.cycler(parent, 208, y, 130, function() return L end,
            function() return find(list, d()[key]).id end, function(v) d()[key] = v; changed() end)
        b.label = lab
        btns[key] = { b = b, list = list }
        y = y - 40
    end
    cycler("Arrow style", STYLES, "style")
    cycler("Arrow colour", COLORS, "color")
    local sliders = {}
    local function slider(label, key, min, max)
        local lab = API.newLabel(parent, label, 40, y)
        local s = API.makeSlider(parent, 150, min, max, 1, px, function(v) d()[key] = v; changed() end)
        s:SetPoint("TOPLEFT", 240, y)
        s.ubermocLabel = lab
        sliders[key] = s
        y = y - 36
    end
    slider("Arrow size", "size", 8, 500)
    slider("Arrow distance from the bar", "gap", -500, 500)
    slider("Arrows up / down", "y", -500, 500)
    slider("Top arrow height", "aboveY", -500, 500)
    API.newButton(parent, "Outline around the health bar: Textures page", 330, 8, y, function()
        if API.openTextures then API.openTextures("nameplates") end
    end)
    y = y - 40
    API.newButton(parent, "Reset the target indicators", 240, 8, y, function()
        local cfg = DB()
        for k, v in pairs(defaults()) do cfg[k] = v end
        testing = false
        parent.refreshMarks()
        changed()
    end)
    function parent.refreshMarks()
        local cfg = d()
        for k, cb in pairs(checks) do cb:SetChecked(cfg[k] and true or false) end
        test:SetChecked(testing)
        for _, o in pairs(btns) do o.b.refresh() end
        for k, s in pairs(sliders) do API.setSlider(s, cfg[k]) end
        local arrows = cfg.side or cfg.above
        API.setActive(btns.style.b, arrows); API.setActive(btns.color.b, arrows); API.setActive(sliders.size, arrows)
        API.setActive(sliders.gap, cfg.side); API.setActive(sliders.y, cfg.side)
        API.setActive(sliders.aboveY, cfg.above)
        API.setActive(test, arrows or (API.borderOf("npTarget")))
    end
    parent.refreshMarks()
end
