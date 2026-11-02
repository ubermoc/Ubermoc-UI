-- Ubermoc UI - Copyright (c) 2026 Marcos. All rights reserved.
-- This file is protected by copyright. It may not be copied, modified, redistributed or reused, in whole or
-- in part, without the written permission of the author. See LICENSE.txt.
----------------------------------------------------------------------
-- Ubermoc UI: nameplate debuffs
-- Takes over the debuff icons on nameplates: only your own debuffs or all, icon size, spacing,
-- icons per row, position, timer and stack text, and a border coloured by debuff type.
-- Uses the game's own aura container, so it keeps working while auras are hidden from addons.
----------------------------------------------------------------------
local API = UbermocUIAPI
if not API then return end

local GROUPS = { "enemy", "friendly" }
local KEY = "Debuffs"

-- Time text on an aura icon: its centre sits on the middle of the icon's top edge by default (so the top border
-- runs through the middle of the numbers); size is a percentage, x / y move it. Used by every aura display.
function UbermocUIAPI.auraTimeStyle(fs, owner, iconSize, size, x, y, scaleFix)
    if not (fs and owner) then return end
    local path = fs.GetFont and fs:GetFont() or STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
    local sz = math.max(7, math.floor((iconSize or 20) * 0.42 * (size or 100) / 100))
    pcall(fs.SetFont, fs, path, sz, "OUTLINE")
    pcall(fs.SetShadowOffset, fs, 0, 0)
    pcall(fs.SetShadowColor, fs, 0, 0, 0, 0)
    pcall(fs.ClearAllPoints, fs)
    local k = scaleFix or 1
    pcall(fs.SetPoint, fs, "CENTER", owner, "TOP", (x or 0) * k, (y or 0) * k)
end

local function defaults(group)
    return {
        on = (group == "enemy"), mine = true,
        size = 20, gapX = 2, gapY = 2, perRow = 6, max = 8,
        x = 0, y = 16,
        timer = true, timerScale = 100, timerX = 0, timerY = 0,
        stacks = true, stackScale = 100,
        color = true,
    }
end

local filled   -- the settings table whose defaults are already filled in (DB() runs many times a second)
local function DB()
    UbermocUIDB = UbermocUIDB or {}
    local d = UbermocUIDB.npAuras
    if type(d) ~= "table" then d = {}; UbermocUIDB.npAuras = d end
    if d == filled then return d end   -- defaults already filled in for this table
    for _, g in ipairs(GROUPS) do
        if type(d[g]) ~= "table" then d[g] = {} end
        for k, v in pairs(defaults(g)) do if d[g][k] == nil then d[g][k] = v end end
    end
    -- One time: controlling (and showing only my) debuffs on enemy nameplates is now on by default.
    if not d.v2 then d.v2 = true; d.enemy.on = true end
    if type(d.saved) ~= "table" then d.saved = {} end
    filled = d
    return d
end
API.npAuraDB = DB

-- The debuff filter, built with the game's own helper when it has one (it knows the exact tokens,
-- including the one that lets nameplate-only debuffs through).
local function filterFor(mine)
    local AU = AuraUtil
    local AF = AU and AU.AuraFilters
    if AU and AU.CreateFilterString and AF and AF.Harmful then
        local parts = { AF.Harmful }
        if AF.IncludeNameplateOnly then parts[#parts + 1] = AF.IncludeNameplateOnly end
        if mine and AF.Player then parts[#parts + 1] = AF.Player end
        local ok, f = pcall(AU.CreateFilterString, unpack(parts))
        if ok and type(f) == "string" then return f end
    end
    return mine and "HARMFUL|PLAYER" or "HARMFUL"
end

local function groupOfUnit(unit)
    if unit and UnitCanAttack and UnitCanAttack("player", unit) then return "enemy" end
    return "friendly"
end

----------------------------------------------------------------------
-- Hiding the game's own debuff icons: its display options are bit fields, the debuff bit is
-- switched off while we control that group and put back to what it was afterwards.
----------------------------------------------------------------------
local BLIZZ = {}
do
    local K, E = NamePlateConstants, Enum
    if K and E then
        local function add(group, cvar, enumTable)
            if cvar and enumTable and enumTable.Debuffs ~= nil then
                BLIZZ[#BLIZZ + 1] = { group = group, cvar = cvar, bit = enumTable.Debuffs }
            end
        end
        add("enemy", K.ENEMY_NPC_AURA_DISPLAY_CVAR, E.NamePlateEnemyNpcAuraDisplay)
        add("enemy", K.ENEMY_PLAYER_AURA_DISPLAY_CVAR, E.NamePlateEnemyPlayerAuraDisplay)
        add("friendly", K.FRIENDLY_PLAYER_AURA_DISPLAY_CVAR, E.NamePlateFriendlyPlayerAuraDisplay)
    end
end

local pendingCVars = false
local function applyBlizzard()
    if InCombatLockdown() then pendingCVars = true; return end
    pendingCVars = false
    local d = DB()
    if not (C_CVar and C_CVar.GetCVarBitfield and C_CVar.SetCVarBitfield) then return end
    for _, b in ipairs(BLIZZ) do
        local key = b.cvar .. ":" .. b.bit
        if d[b.group].on then
            if d.saved[key] == nil then
                local ok, cur = pcall(C_CVar.GetCVarBitfield, b.cvar, b.bit)
                if ok then d.saved[key] = cur and true or false end
            end
            pcall(C_CVar.SetCVarBitfield, b.cvar, b.bit, false)
        elseif d.saved[key] ~= nil then
            pcall(C_CVar.SetCVarBitfield, b.cvar, b.bit, d.saved[key])
            d.saved[key] = nil
        end
    end
    local fc = NamePlateConstants and NamePlateConstants.SHOW_DEBUFFS_ON_FRIENDLY_CVAR
    if fc and C_CVar.SetCVar then
        if d.friendly.on then
            if d.saved.friendlyDebuffs == nil then
                local ok, cur = pcall(C_CVar.GetCVar, fc)
                if ok then d.saved.friendlyDebuffs = cur end
            end
            pcall(C_CVar.SetCVar, fc, "0")
        elseif d.saved.friendlyDebuffs ~= nil then
            pcall(C_CVar.SetCVar, fc, d.saved.friendlyDebuffs)
            d.saved.friendlyDebuffs = nil
        end
    end
end

----------------------------------------------------------------------
-- Buttons
----------------------------------------------------------------------
local DISPEL_KEYS = { "None", "Magic", "Curse", "Disease", "Poison", "Bleed" }
local TYPE_COLORS = {
    Magic = { 0.13, 0.44, 1 }, Poison = { 0, 0.52, 0.03 }, Curse = { 0.47, 0, 0.78 },
    Disease = { 1, 0.53, 0.14 }, Bleed = { 0.8, 0.1, 0.1 }, None = { 0, 0, 0 },
}
local colorMap
local function typeColorMap()
    if colorMap then return colorMap end
    if not CreateColor then return nil end
    colorMap = {}
    for _, k in ipairs(DISPEL_KEYS) do
        local c = TYPE_COLORS[k]
        colorMap[k] = CreateColor(c[1], c[2], c[3], 1)
    end
    return colorMap
end

local NPD = { enemy = "npDebuff_enemy", friendly = "npDebuff_friendly" }
for _, gk in ipairs({ "enemy", "friendly" }) do
    API.registerBorder({ key = NPD[gk], part = "nameplates", label = (gk == "enemy" and "Enemy" or "Friendly") .. " debuff icon borders",
        size = 1, maxSize = 4, auto = "Debuff type colours",
        legacy = function()
            local d = UbermocUIDB.npAuras and UbermocUIDB.npAuras[gk] or {}
            return true, 1, 100, d.color and "auto" or "class"
        end,
        apply = function() if API.refreshNpAuras then pcall(API.refreshNpAuras) end end })
end

local function styleButton(button, c, group)
    if not button or not button.ubermocIcon then return end
    local s = c.size
    pcall(button.SetSize, button, s, s)
    -- Border (Textures page, Nameplates tab): class colour, your own, or coloured by debuff type.
    local edges = button.ubermocEdges
    local bOn, th, br, bg, bb, ba, bmode = API.borderOf(NPD[group] or "npDebuff_enemy")
    if button.ubermocTh ~= th then
        button.ubermocTh = th
        for i = 1, 4 do edges[i]:ClearAllPoints() end
        edges[1]:SetPoint("BOTTOMLEFT", button, "TOPLEFT", -th, 0); edges[1]:SetPoint("BOTTOMRIGHT", button, "TOPRIGHT", th, 0); edges[1]:SetHeight(th)
        edges[2]:SetPoint("TOPLEFT", button, "BOTTOMLEFT", -th, 0); edges[2]:SetPoint("TOPRIGHT", button, "BOTTOMRIGHT", th, 0); edges[2]:SetHeight(th)
        edges[3]:SetPoint("TOPRIGHT", button, "TOPLEFT", 0, 0); edges[3]:SetPoint("BOTTOMRIGHT", button, "BOTTOMLEFT", 0, 0); edges[3]:SetWidth(th)
        edges[4]:SetPoint("TOPLEFT", button, "TOPRIGHT", 0, 0); edges[4]:SetPoint("BOTTOMLEFT", button, "BOTTOMRIGHT", 0, 0); edges[4]:SetWidth(th)
    end
    local wantType = (bOn and bmode == "auto") and true or false
    if button.ubermocTyped ~= wantType then
        button.ubermocTyped = wantType
        if button.ClearDispelTypeTextures then pcall(button.ClearDispelTypeTextures, button) end
        if wantType and button.AddDispelTypeTexture and Enum and Enum.CustomAuraButtonDispelTypeTextureStyle then
            local map = typeColorMap()
            if map then
                for i = 1, 4 do
                    pcall(button.AddDispelTypeTexture, button, edges[i], {
                        style = Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset,
                        showWhenHarmful = true, showWhenHelpful = false,
                        showWithoutDispelType = true, customDispelColorMap = map,
                    })
                end
            end
        end
    end
    if not wantType then for i = 1, 4 do edges[i]:SetColorTexture(br, bg, bb, ba); edges[i]:SetShown(bOn) end end
    local cd = button.ubermocCooldown
    if cd then
        pcall(cd.SetHideCountdownNumbers, cd, not c.timer)
        if cd.GetCountdownFontString then
            local fs = cd:GetCountdownFontString()
            if fs then
                local sc = math.max(0.2, (c.timerScale or 100) / 100 * math.max(0.4, s / 24))
                pcall(fs.SetScale, fs, sc)
                pcall(fs.ClearAllPoints, fs)
                pcall(fs.SetPoint, fs, "CENTER", button, "TOP", (c.timerX or 0) / sc, (c.timerY or 0) / sc)
            end
        end
    end
    local n = button.ubermocCount
    if n then
        n:SetScale(math.max(0.2, (c.stackScale or 100) / 100 * math.max(0.6, s / 24)))
        n:SetShown(c.stacks and true or false)
        n:SetAlpha(c.stacks and 1 or 0)
    end
end

local function initButton(button, group)
    pcall(function()
        -- The button has no size of its own until it is given one; without this the icons draw at 0 x 0.
        local s0 = DB()[group].size or 20
        button:SetSize(s0, s0)
        button:SetFlattensRenderLayers(true)
        local icon = button:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints(button)
        icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        button.ubermocIcon = icon
        button:SetIcon(icon)

        local cd = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
        cd:SetMinimumCountdownDuration(0)
        cd:SetAllPoints(button)
        cd:SetReverse(true)
        cd:SetDrawBling(false)
        -- No dark sweep over the icon: the spell icon and the countdown number stay clear.
        cd:SetDrawSwipe(false)
        cd:SetDrawEdge(false)
        button.ubermocCooldown = cd
        button:SetDurationCooldown(cd)

        local overlay = CreateFrame("Frame", nil, button)
        overlay:SetAllPoints(button)
        overlay:SetFrameLevel(cd:GetFrameLevel() + 1)
        local edges = {}
        for i = 1, 4 do
            local t = overlay:CreateTexture(nil, "OVERLAY", nil, 4)
            t:SetColorTexture(0, 0, 0, 1)
            edges[i] = t
        end
        local th = 1
        edges[1]:SetPoint("BOTTOMLEFT", button, "TOPLEFT", -th, 0); edges[1]:SetPoint("BOTTOMRIGHT", button, "TOPRIGHT", th, 0); edges[1]:SetHeight(th)
        edges[2]:SetPoint("TOPLEFT", button, "BOTTOMLEFT", -th, 0); edges[2]:SetPoint("TOPRIGHT", button, "BOTTOMRIGHT", th, 0); edges[2]:SetHeight(th)
        edges[3]:SetPoint("TOPRIGHT", button, "TOPLEFT", 0, 0); edges[3]:SetPoint("BOTTOMRIGHT", button, "BOTTOMLEFT", 0, 0); edges[3]:SetWidth(th)
        edges[4]:SetPoint("TOPLEFT", button, "TOPRIGHT", 0, 0); edges[4]:SetPoint("BOTTOMLEFT", button, "BOTTOMRIGHT", 0, 0); edges[4]:SetWidth(th)
        button.ubermocEdges = edges

        local count = overlay:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 2, -2)
        button.ubermocCount = count
        button:SetApplicationCount(count)

        if button.SetTooltipAnchorPoint then button:SetTooltipAnchorPoint("ANCHOR_BOTTOMLEFT", 0, 0) end
        if button.SetCancelAuraButtons then button:SetCancelAuraButtons(nil) end
        styleButton(button, DB()[group], group)
    end)
end

----------------------------------------------------------------------
-- One aura container per plate
----------------------------------------------------------------------
local containers = setmetatable({}, { __mode = "k" })
local bound = {}   -- unit token -> plate

local function sortArgs()
    local m, d = Enum and Enum.AuraContainerSortMethod, Enum and Enum.AuraContainerSortDirection
    if m and d and m.Default ~= nil and d.Normal ~= nil then return m.Default, d.Normal end
end

local function lineWidth(c)
    return c.perRow * c.size + (c.perRow - 1) * c.gapX
end

local function layout(group)
    return { elementSpacing = DB()[group].gapX, lineSpacing = DB()[group].gapY,
             elementWidth = DB()[group].size, elementHeight = DB()[group].size, layoutIndex = 1 }
end

local function getContainer(plate, group)
    local rec = containers[plate]
    if rec and rec.group == group then return rec.frame end
    if rec then rec.frame:Hide(); pcall(rec.frame.SetEnabled, rec.frame, false); containers[plate] = nil end
    -- The game's aura module has to be loaded before its container frames can be made.
    if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.LoadAddOn and not C_AddOns.IsAddOnLoaded("Blizzard_AuraContainer") then
        pcall(C_AddOns.LoadAddOn, "Blizzard_AuraContainer")
    end
    local ok, f = pcall(CreateFrame, "AuraContainer", nil, UIParent, "CustomAuraContainerTemplate")
    if not ok or not f then API.npAuraError = "create: " .. tostring(f); return nil end
    API.npAuraError = nil
    local function step(name, fn, ...)
        local okS, err = pcall(fn, ...)
        if not okS and not API.npAuraError then API.npAuraError = name .. ": " .. tostring(err) end
    end
    step("setup", function()
        f:SetEnabled(false)
        if f.SetEditModePreviewEnabled then f:SetEditModePreviewEnabled(false) end
        f:Hide()
        f:SetSize(1, 1) -- the container needs a drawable rectangle from the start
        f:SetFlattensRenderLayers(true)
        f:SetFlowLayoutAnchorPoint("BOTTOMLEFT")
        local FD = AnchorUtil and AnchorUtil.FlowDirection
        if FD then f:SetFlowLayoutGrowthDirection(FD.Right, FD.Up) end
    end)
    local m, d = sortArgs()
    step("group", f.AddAuraGroup, f, KEY, filterFor(DB()[group].mine), {
        maxFrameCount = 0, sortMethod = m, sortDirection = d,
        initializeFrame = function(button) initButton(button, group) end,
        layout = layout(group),
    })
    -- Made under the main interface first, then moved onto the nameplate's unit frame.
    step("parent", f.SetParent, f, (plate.UnitFrame or plate))
    containers[plate] = { frame = f, group = group }
    return f
end

local function plateAnchor(plate)
    local uf = plate and plate.UnitFrame
    return (uf and (uf.HealthBarsContainer or uf.healthBar)) or plate
end

-- In name-only mode the debuffs hang on the name text (set by the nameplate code), so they follow it
-- whatever its length; otherwise on the health bar.
local nameAnchor = setmetatable({}, { __mode = "k" })
local function rec2anchor(plate, group)
    return nameAnchor[plate] or plateAnchor(plate)
end

function API.reanchorNpAura(plate, anchor)
    local ua = plate.UnitFrame and plate.UnitFrame.ubermocName
    nameAnchor[plate] = (anchor and anchor == ua) and anchor or nil
    local rec = containers[plate]
    if not rec or not rec.frame:IsShown() then return end
    local group = rec.group
    local c = DB()[group]
    pcall(function()
        rec.frame:ClearAllPoints()
        rec.frame:SetPoint("BOTTOMLEFT", rec2anchor(plate, group), "TOPLEFT", c.x, c.y)
    end)
end

local function applyToPlate(plate, unit)
    if not (plate and unit) then return end
    local group = groupOfUnit(unit)
    local c = DB()[group]
    local rec = containers[plate]
    if not c.on then
        if rec then rec.frame:Hide(); pcall(rec.frame.SetEnabled, rec.frame, false) end
        return
    end
    local f = getContainer(plate, group)
    if not f then return end
    local function step(name, fn, ...)
        local ok, err = pcall(fn, ...)
        if not ok then API.npAuraError = name .. ": " .. tostring(err) end
        return ok
    end
    step("anchor", function()
        f:ClearAllPoints()
        f:SetPoint("BOTTOMLEFT", rec2anchor(plate, group), "TOPLEFT", c.x, c.y)
        local uf = plate.UnitFrame
        if uf and uf.GetFrameLevel then f:SetFrameLevel(uf:GetFrameLevel() + 10) end
    end)
    step("line", f.SetFlowLayoutMaximumLineSize, f, lineWidth(c))
    step("filter", f.SetAuraGroupFilterString, f, KEY, filterFor(c.mine))
    step("layout", f.SetAuraGroupLayout, f, KEY, layout(group))
    step("count", f.SetAuraGroupMaxFrameCount, f, KEY, c.max)
    step("unit", f.SetUnit, f, unit)
    step("enable", f.SetEnabled, f, true)
    f:Show()
    pcall(function()
        for i = 1, f:GetAuraGroupFrameCount(KEY) do
            styleButton(f:GetAuraGroupFrame(KEY, i), c, group)
        end
    end)
end

local restylePending = false
function API.refreshNpAuras()
    if C_Secrets and C_Secrets.ShouldAurasBeSecret and C_Secrets.ShouldAurasBeSecret() then
        restylePending = true
        return
    end
    restylePending = false
    for unit, plate in pairs(bound) do
        pcall(applyToPlate, plate, unit)
    end
    applyBlizzard()
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("NAME_PLATE_UNIT_ADDED")
ev:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:SetScript("OnEvent", function(_, event, unit)
    if not UbermocUIDB then return end
    if event == "NAME_PLATE_UNIT_ADDED" then
        local plate = C_NamePlate and C_NamePlate.GetNamePlateForUnit and C_NamePlate.GetNamePlateForUnit(unit)
        if plate then
            bound[unit] = plate
            pcall(applyToPlate, plate, unit)
        end
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        local plate = bound[unit]
        bound[unit] = nil
        local rec = plate and containers[plate]
        if rec then rec.frame:Hide(); pcall(rec.frame.SetEnabled, rec.frame, false) end
    else
        if pendingCVars or event == "PLAYER_ENTERING_WORLD" then applyBlizzard() end
        if restylePending then API.refreshNpAuras() end
    end
end)

----------------------------------------------------------------------
-- Options panel (the Debuffs view of the Nameplates page)
----------------------------------------------------------------------
function API.buildDebuffPanel(parent, fixedGroup)
    local panel = { group = fixedGroup or "enemy" }
    local ctl = {}
    local function c() return DB()[panel.group] end
    local function changed()
        API.refreshNpAuras(); if API.refreshNpPreview then pcall(API.refreshNpPreview) end
        if panel.dims then panel.dims() end
    end
    local px = function(v) return math.floor(v + 0.5) .. " px" end
    local pct = function(v) return math.floor(v + 0.5) .. "%" end

    API.newLabel(parent, "Debuffs on nameplates", 8, -4, "GameFontNormalLarge")
    if not fixedGroup then API.newLabel(parent, "Editing", 8, -40) end
    panel.groupBtn = API.segRow(parent, 80, -34, { { "enemy", "Enemy nameplates", 140 }, { "friendly", "Friendly nameplates", 150 } },
        function() return panel.group end, function(v) if not fixedGroup then panel.group = v; panel.refresh() end end)

    local y = fixedGroup and -44 or -68
    ctl.on = API.newCheck(parent, "Control debuffs", 8, y, function(v) c().on = v; changed() end)
    y = y - 34
    ctl.mine = API.newCheck(parent, "Only show my debuffs", 8, y, function(v) c().mine = v; changed() end)
    y = y - 40
    local function slider(label, key, min, max, step, fmt)
        local lab = API.newLabel(parent, label, 40, y)
        local s = API.makeSlider(parent, 150, min, max, step, fmt, function(v) c()[key] = v; changed() end)
        s:SetPoint("TOPLEFT", 240, y)
        s.ubermocLabel = lab
        ctl[key] = s
        y = y - 36
    end
    slider("Icon size", "size", 12, 500, 1, px)
    slider("Space between icons", "gapX", 0, 500, 1, px)
    slider("Space between rows", "gapY", 0, 500, 1, px)
    slider("Icons per row", "perRow", 1, 12, 1, function(v) return tostring(math.floor(v + 0.5)) end)
    slider("Most icons shown", "max", 1, 16, 1, function(v) return tostring(math.floor(v + 0.5)) end)
    slider("Left / right", "x", -500, 500, 1, px)
    slider("Up / down", "y", -500, 500, 1, px)
    y = y - 6
    ctl.timer = API.newCheck(parent, "Show the countdown timer", 8, y, function(v) c().timer = v; changed() end)
    y = y - 34
    slider("Timer text size", "timerScale", 40, 250, 5, pct)
    slider("Timer left / right", "timerX", -40, 40, 1, px)
    slider("Timer up / down", "timerY", -40, 40, 1, px)
    ctl.stacks = API.newCheck(parent, "Show the stack count", 8, y, function(v) c().stacks = v; changed() end)
    y = y - 34
    slider("Stack text size", "stackScale", 40, 250, 5, pct)
    ctl.color = API.newButton(parent, "Icon borders (and debuff type colours): Textures page", 360, 8, y, function()
        if API.openTextures then API.openTextures("nameplates") end
    end)
    y = y - 44
    API.newButton(parent, "Reset these debuff settings", 240, 8, y, function()
        local d = DB()
        d[panel.group] = defaults(panel.group)
        panel.refresh()
        API.refreshNpAuras()
    end)
    panel.height = -y + 40

    function panel.refresh()
        local d = c()
        panel.groupBtn.refresh()
        if fixedGroup then panel.groupBtn.frame:Hide() end
        ctl.on:SetChecked(d.on and true or false)
        ctl.mine:SetChecked(d.mine and true or false)
        ctl.timer:SetChecked(d.timer and true or false)
        ctl.stacks:SetChecked(d.stacks and true or false)
        for _, k in ipairs({ "size", "gapX", "gapY", "perRow", "max", "x", "y", "timerScale", "stackScale", "timerX", "timerY" }) do
            API.setSlider(ctl[k], d[k] or 0)
        end
        if API.refreshNpPreview then pcall(API.refreshNpPreview) end
        panel.dims()
    end
    -- Everything below "Control debuffs" only matters while it is on.
    function panel.dims()
        local d = c()
        local on = d.on and true or false
        for _, k in ipairs({ "mine", "size", "gapX", "gapY", "perRow", "max", "x", "y", "timer", "stacks", "color" }) do API.setActive(ctl[k], on) end
        API.setActive(ctl.timerScale, on and d.timer); API.setActive(ctl.timerX, on and d.timer); API.setActive(ctl.timerY, on and d.timer)
        API.setActive(ctl.stackScale, on and d.stacks)
    end
    return panel
end

-- Mock debuff icons for the nameplate preview, laid out like the real container: the first icon sits at
-- the top left of the anchor (the bar, or the name in name-only mode), rows grow upward.
local PV_ICONS = { "Interface\\Icons\\Spell_Shadow_ShadowWordPain", "Interface\\Icons\\Spell_Nature_Slow",
    "Interface\\Icons\\Ability_Rogue_Rupture", "Interface\\Icons\\Spell_Shadow_CurseOfTounges" }
local PV_TYPES = { "Magic", "Curse", "Bleed", "Curse" }
local pvButtons = {}
function API.previewDebuffs(mock, anchor, group)
    local d = DB()[group]
    local show = d.on
    for i = 1, 16 do
        local b = pvButtons[i]
        if not b then
            b = CreateFrame("Frame", nil, mock)
            b:SetFrameLevel(mock:GetFrameLevel() + 8)
            b.t = b:CreateTexture(nil, "ARTWORK")
            b.t:SetAllPoints()
            b.t:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            b.e = {}
            for k = 1, 4 do b.e[k] = b:CreateTexture(nil, "OVERLAY") end
            b.time = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
            b.time:SetPoint("CENTER")
            b.cnt = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
            b.cnt:SetPoint("BOTTOMRIGHT", 2, -2)
            pvButtons[i] = b
        end
        if show and i <= d.max then
            local row, col = math.floor((i - 1) / d.perRow), (i - 1) % d.perRow
            b:SetSize(d.size, d.size)
            b:ClearAllPoints()
            b:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", d.x + col * (d.size + d.gapX), d.y + row * (d.size + d.gapY))
            b.t:SetTexture(PV_ICONS[(i - 1) % #PV_ICONS + 1])
            local c3 = d.color and TYPE_COLORS[PV_TYPES[(i - 1) % #PV_TYPES + 1]] or { 0, 0, 0 }
            for k = 1, 4 do b.e[k]:SetColorTexture(c3[1], c3[2], c3[3], 1); b.e[k]:ClearAllPoints() end
            b.e[1]:SetPoint("BOTTOMLEFT", b, "TOPLEFT", -1, 0); b.e[1]:SetPoint("BOTTOMRIGHT", b, "TOPRIGHT", 1, 0); b.e[1]:SetHeight(1)
            b.e[2]:SetPoint("TOPLEFT", b, "BOTTOMLEFT", -1, 0); b.e[2]:SetPoint("TOPRIGHT", b, "BOTTOMRIGHT", 1, 0); b.e[2]:SetHeight(1)
            b.e[3]:SetPoint("TOPRIGHT", b, "TOPLEFT", 0, 0); b.e[3]:SetPoint("BOTTOMRIGHT", b, "BOTTOMLEFT", 0, 0); b.e[3]:SetWidth(1)
            b.e[4]:SetPoint("TOPLEFT", b, "TOPRIGHT", 0, 0); b.e[4]:SetPoint("BOTTOMLEFT", b, "BOTTOMRIGHT", 0, 0); b.e[4]:SetWidth(1)
            b.time:SetFont(STANDARD_TEXT_FONT, math.max(6, math.floor(10 * (d.timerScale / 100) * math.max(0.4, d.size / 24))), "OUTLINE")
            b.time:SetText("12")
            b.time:SetShown(d.timer)
            b.cnt:SetFont(STANDARD_TEXT_FONT, math.max(6, math.floor(10 * (d.stackScale / 100) * math.max(0.6, d.size / 24))), "OUTLINE")
            b.cnt:SetText(i == 2 and "3" or "")
            b.cnt:SetShown(d.stacks)
            b:Show()
        else
            b:Hide()
        end
    end
end

----------------------------------------------------------------------
-- The game's own buffs and debuffs, laid out in arcs around the halo frames (player, target, focus).
-- The buttons stay the game's (timers, tooltips; right-click to cancel on your own buffs); only where they
-- sit changes. When an arc is full the next icons start a second arc further out.
-- Target and focus: the game's frame is made see-through by the halo frame, so its aura icons are lifted
-- into a holder of our own while this is on, and handed back when it is off.
----------------------------------------------------------------------
local HA_SIDE = { left = 180, right = 0, top = 90, bottom = 270 }
local HA = {
    { key = "player", db = "haloAuras", ring = "UbermocRingHUD", rdb = "ringhud" },
    { key = "target", db = "haloAurasTarget", ring = "UbermocRingHUD_target", rdb = "ringhud_target", blizz = "TargetFrame", unit = "target" },
    { key = "focus", db = "haloAurasFocus", ring = "UbermocRingHUD_focus", rdb = "ringhud_focus", blizz = "FocusFrame", unit = "focus" },
    -- Units the game shows no icons for: the game's own aura display (a container it fills itself), beside the frame.
    { key = "targettarget", db = "haloAurasToT", ring = "UbermocRingHUD_tot", rdb = "ringhud_tot", unit = "targettarget", ac = true },
    { key = "focustarget", db = "haloAurasFoT", ring = "UbermocRingHUD_fot", rdb = "ringhud_fot", unit = "focustarget", ac = true },
}
local HA_BY = {}
-- Kept beside the game's buttons, never written onto them (a field added to the game's frame marks it as the addon's).
local HA_PARENT = setmetatable({}, { __mode = "k" })
local HA_W = setmetatable({}, { __mode = "k" })
for _, sp in ipairs(HA) do sp.buffs, sp.debuffs, sp.nb, sp.nd, sp.moved = {}, {}, 0, 0, false; HA_BY[sp.key] = sp end
local haBusy = false

local function haDB(sp)
    if not (UbermocUIDB and UbermocUIDB.version) then return nil end   -- not before the saved settings are in
    local d = UbermocUIDB[sp.db]
    if type(d) ~= "table" then d = {}; UbermocUIDB[sp.db] = d end
    if d == sp.filled then return d end
    if d.on == nil then d.on = true end
    if d.buffs == nil then d.buffs = "left" end
    if d.debuffs == nil then d.debuffs = "right" end
    if d.size == nil then d.size = 26 end
    if d.gap == nil then d.gap = 8 end
    if d.max == nil then d.max = 6 end
    if d.tsz == nil then d.tsz = 100 end
    if d.tx == nil then d.tx = 0 end
    if d.ty == nil then d.ty = 0 end
    sp.filled = d
    return d
end
API.haloAurasDB = function(key) local sp = HA_BY[key or "player"]; return sp and haDB(sp) end

-- Centre and radius of a halo frame, in screen pixels (nil when it is off or has no unit).
local function haRing(sp)
    local R = _G[sp.ring]
    local r = UbermocUIDB and UbermocUIDB[sp.rdb]
    if not (R and r and r.on) then return nil end
    if API.floatingCovers and API.floatingCovers(sp.unit or "player") then return nil end   -- drawn as a floating frame: no halo arcs
    if sp.unit and not UnitExists(sp.unit) then return nil end
    local x, y = R:GetCenter()
    if not x then return nil end
    local es = R:GetEffectiveScale()
    return x * es, y * es, (R:GetWidth() or 0) / 2 * es
end

-- Oldest aura first, so icons don't jump about when one is added (sorted in place, no new tables).
local function haSort(list, n)
    for i = 2, n do
        local v = list[i]
        local k = v.auraInstanceID or 0
        local j = i - 1
        while j >= 1 and (list[j].auraInstanceID or 0) > k do list[j + 1] = list[j]; j = j - 1 end
        list[j + 1] = v
    end
end

-- Buffs and debuffs you chose to hide (UbermocUIDB.auraHide[spellId] = { name, icon }), for every halo frame.
local function hideDB()
    local h = UbermocUIDB and UbermocUIDB.auraHide
    if type(h) ~= "table" and UbermocUIDB then h = {}; UbermocUIDB.auraHide = h end
    return h or {}
end
local function plain(v)
    if v == nil then return nil end
    if issecretvalue and issecretvalue(v) then return nil end   -- hidden by the game (some auras in combat)
    return v
end
-- The spell behind one of the game's aura buttons (nil when it can't be known right now).
local SPELL_OF = {}   -- aura instance -> spell, remembered while the aura lasts
local function spellOf(b, unit, harmful)
    local info = b.buttonInfo
    local inst = plain(b.auraInstanceID) or (type(info) == "table" and plain(info.auraInstanceID))
    if inst and SPELL_OF[inst] then return SPELL_OF[inst] end
    local data
    local U = C_UnitAuras
    if inst and U and U.GetAuraDataByAuraInstanceID then
        local ok, d = pcall(U.GetAuraDataByAuraInstanceID, unit, inst); if ok then data = d end
    end
    if not data and type(info) == "table" and plain(info.index) and U and U.GetAuraDataByIndex then
        local ok, d = pcall(U.GetAuraDataByIndex, unit, info.index, harmful and "HARMFUL" or "HELPFUL"); if ok then data = d end
    end
    local sid = data and plain(data.spellId)
    if sid and inst then
        SPELL_OF.n = (SPELL_OF.n or 0) + 1
        if SPELL_OF.n > 400 then wipe(SPELL_OF); SPELL_OF.n = 1 end   -- old auras are long gone
        SPELL_OF[inst] = sid
    end
    return sid
end
local function isHidden(b, unit, harmful)
    local h = UbermocUIDB and UbermocUIDB.auraHide
    if not h or next(h) == nil then return false end
    local sid = spellOf(b, unit, harmful)
    return sid and h[sid] and true or false
end

-- Fills sp.buffs / sp.debuffs with the shown buttons (the hidden ones go in sp.parked).
local function haCollect(sp)
    local nb, nd, np = 0, 0, 0
    sp.parked = sp.parked or {}
    local unit = sp.unit or "player"
    if sp.key == "player" then
        local bf, df = _G.BuffFrame, _G.DebuffFrame
        if bf and type(bf.auraFrames) == "table" then
            for _, b in ipairs(bf.auraFrames) do
                if b.IsShown and b:IsShown() then
                    if isHidden(b, unit, false) then np = np + 1; sp.parked[np] = b else nb = nb + 1; sp.buffs[nb] = b end
                end
            end
        end
        if df and type(df.auraFrames) == "table" then
            for _, b in ipairs(df.auraFrames) do
                if b.IsShown and b:IsShown() then
                    if isHidden(b, unit, true) then np = np + 1; sp.parked[np] = b else nd = nd + 1; sp.debuffs[nd] = b end
                end
            end
        end
    else
        local fr = _G[sp.blizz]
        local pools = fr and fr.auraPools
        if pools and pools.EnumerateActive then
            for b in pools:EnumerateActive() do
                if b.IsShown and b:IsShown() then
                    local harmful = b.Border and true or false   -- the game's debuff icons have a coloured border, its buffs don't
                    if isHidden(b, unit, harmful) then np = np + 1; sp.parked[np] = b
                    elseif harmful then nd = nd + 1; sp.debuffs[nd] = b else nb = nb + 1; sp.buffs[nb] = b end
                end
            end
            haSort(sp.buffs, nb); haSort(sp.debuffs, nd)
        end
    end
    for i = nb + 1, #sp.buffs do sp.buffs[i] = nil end
    for i = nd + 1, #sp.debuffs do sp.debuffs[i] = nil end
    for i = np + 1, #sp.parked do sp.parked[i] = nil end
    sp.nb, sp.nd, sp.np = nb, nd, np
end

-- True when an icon centred at (x, y) with half-size h would sit on the ring's cast information.
local function haBlocked(R, cx, cy, x, y, h)
    if not (R and R.ubCast) then return false end
    local es = R:GetEffectiveScale()
    local l, r = cx + R.ubCL * es, cx + R.ubCR * es
    local t, b = cy + R.ubCT * es, cy + R.ubCB * es
    return x + h > l and x - h < r and y + h > b and y - h < t
end

local function haPut(sp, b, size, x, y)
    if InCombatLockdown() and b.IsProtected and b:IsProtected() then return end
    if sp.holder and b:GetParent() ~= sp.holder then
        HA_PARENT[b] = HA_PARENT[b] or b:GetParent()
        b:SetParent(sp.holder)
    end
    local icon = b.Icon or b.icon
    local bw = HA_W[b] or (icon and icon.GetWidth and icon:GetWidth()) or b:GetWidth() or 30
    if not bw or bw < 1 then bw = 30 end
    HA_W[b] = bw
    local parent = b:GetParent()
    local pes = (parent and parent:GetEffectiveScale()) or 1
    b:SetScale(size / (bw * pes))
    -- The time sits inside the icon, in a thin outline (no shadow); the text scales with the icon.
    local dur = b.Duration or b.duration
    if dur and dur.SetFont then
        local FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
        local hd = haDB(sp) or {}
        pcall(dur.SetFont, dur, FONT, 12, "OUTLINE")
        UbermocUIAPI.auraTimeStyle(dur, icon or b, bw, hd.tsz, hd.tx, hd.ty, (bw * pes) / size)
        pcall(dur.SetDrawLayer, dur, "OVERLAY", 7)
    end
    local es = b:GetEffectiveScale()
    b:ClearAllPoints()
    b:SetPoint("TOP", UIParent, "BOTTOMLEFT", x / es, (y + size / 2) / es)
end

-- Places n buttons on arcs on one side, starting at radius r0. Returns the next free radius.
-- Spots that would cover the cast information are skipped: the icons move along, or out to the next arc.
local function haLayout(sp, list, n, side, cx, cy, r0, d)
    if n == 0 then return r0 end
    local R = _G[sp.ring]
    local ues = UIParent:GetEffectiveScale()
    local size = d.size * ues
    local half = size / 2 + 2 * ues
    local c = HA_SIDE[side] or 180
    local dir = (side == "right" or side == "top") and -1 or 1
    local r, placed, rows = r0, 0, 0
    while placed < n and rows < 10 do
        rows = rows + 1
        local mid = r + size / 2
        local st = math.deg((size + 4 * ues) / mid)
        local per = math.max(1, math.floor(150 / st))
        local k = math.min(per, n - placed)
        -- First try the usual centred spots; if any is blocked, use the whole arc from its top end.
        local a0 = c - dir * (k - 1) / 2 * st
        local clear = true
        for j = 0, k - 1 do
            local a = math.rad(a0 + dir * j * st)
            if haBlocked(R, cx, cy, cx + mid * math.cos(a), cy + mid * math.sin(a), half) then clear = false; break end
        end
        if clear then
            for j = 0, k - 1 do
                local a = math.rad(a0 + dir * j * st)
                local b = list[placed + j + 1]
                if b then haPut(sp, b, size, cx + mid * math.cos(a), cy + mid * math.sin(a)) end
            end
            placed = placed + k
        else
            a0 = c - dir * (per - 1) / 2 * st
            for j = 0, per - 1 do
                if placed >= n then break end
                local a = math.rad(a0 + dir * j * st)
                local x, y = cx + mid * math.cos(a), cy + mid * math.sin(a)
                if not haBlocked(R, cx, cy, x, y, half) then
                    placed = placed + 1
                    local b = list[placed]
                    if b then haPut(sp, b, size, x, y) end
                end
            end
        end
        r = r + size + 4 * ues
    end
    return r
end

local function haRestore(sp)
    sp.moved = false
    if sp.key == "player" then
        for _, fr in ipairs({ _G.BuffFrame, _G.DebuffFrame }) do
            if fr and type(fr.auraFrames) == "table" then
                for _, b in ipairs(fr.auraFrames) do if b.SetScale then pcall(b.SetScale, b, 1) end end
                if fr.UpdateAuraButtons then pcall(fr.UpdateAuraButtons, fr) end
            end
        end
    else
        local fr = _G[sp.blizz]
        local pools = fr and fr.auraPools
        if pools and pools.EnumerateActive and not InCombatLockdown() then
            for b in pools:EnumerateActive() do
                if HA_PARENT[b] then pcall(b.SetParent, b, HA_PARENT[b]); HA_PARENT[b] = nil end
                pcall(b.SetScale, b, 1)
            end
        end
        if sp.holder then sp.holder:Hide() end
        if fr and fr.UpdateAuras then pcall(fr.UpdateAuras, fr) end
    end
end

-- Beside a halo frame of a unit the game has no aura icons for: the game's own aura display, filled by the game.
local AC_SIDE = { left = "RIGHT", right = "LEFT", top = "BOTTOM", bottom = "TOP" }
local AC_FROM = { left = "LEFT", right = "RIGHT", top = "TOP", bottom = "BOTTOM" }
local function haApplyAC(sp)
    local d = haDB(sp)
    local R = _G[sp.ring]
    local cx = haRing(sp)
    local edit = _G.EditModeManagerFrame and _G.EditModeManagerFrame:IsShown()
    if not (d and d.on and cx and R and API.makeAuraRow) or edit then
        if sp.acB then sp.acB:Hide() end
        if sp.acD then sp.acD:Hide() end
        return
    end
    local size, max, gap = d.size or 26, d.max or 6, d.gap or 8
    local sig = size .. ":" .. max .. ":" .. tostring(d.buffs) .. ":" .. tostring(d.debuffs)
    if sp.acSig ~= sig and not InCombatLockdown() then
        sp.acSig = sig
        for _, k in ipairs({ "acB", "acD" }) do
            if sp[k] then pcall(sp[k].SetEnabled, sp[k], false); sp[k]:Hide(); sp[k] = nil end
        end
        local function make(harmful, side)
            local line = (side == "left" or side == "right") and math.max(1, math.min(max, 3)) * (size + 2) or nil
            local ok, ac = pcall(API.makeAuraRow, R, harmful, size, max, side == "top", line, function() local q = haDB(sp) or {}; return q.tsz, q.tx, q.ty end)
            if not ok then return nil end
            ac:SetUnit(sp.unit)
            return ac
        end
        sp.acB, sp.acD = make(false, d.buffs or "left"), make(true, d.debuffs or "right")
        sp.acPos = nil
    end
    -- the unit behind "target" / "focus" changed: point the rows at it again
    if sp.acEpoch ~= (API.auraEpoch or 0) then
        sp.acEpoch = API.auraEpoch or 0
        for _, k in ipairs({ "acB", "acD" }) do
            if sp[k] and sp.unit then
                if API.repointAuras then API.repointAuras(sp[k], sp.unit) else pcall(sp[k].SetUnit, sp[k], sp.unit) end
            end
        end
    end
    local pos = tostring(d.buffs) .. ":" .. tostring(d.debuffs) .. ":" .. gap .. ":" .. size
    if sp.acPos ~= pos and sp.acB and sp.acD then
        sp.acPos = pos
        local function put(ac, side, to, toSide)
            ac:ClearAllPoints()
            local off = (side == "left" or side == "bottom") and -gap or gap
            if to ~= R then off = (side == "left" or side == "bottom") and -2 or 2 end
            local ox, oy = 0, 0
            if side == "left" or side == "right" then ox = off else oy = off end
            ac:SetPoint(AC_SIDE[side], to, toSide and AC_FROM[side] or AC_FROM[side], ox, oy)
        end
        local bs, ds = d.buffs or "left", d.debuffs or "right"
        put(sp.acB, bs, R)
        put(sp.acD, ds, (ds == bs) and sp.acB or R)   -- on the same side the debuffs sit beyond the buffs
    end
    local ts = tostring(d.tsz) .. ":" .. tostring(d.tx) .. ":" .. tostring(d.ty)
    if sp.acTS ~= ts then
        sp.acTS = ts
        if API.auraTimeRefresh then API.auraTimeRefresh(sp.acB); API.auraTimeRefresh(sp.acD) end
    end
    if sp.acB then sp.acB:Show() end
    if sp.acD then sp.acD:Show() end
end

local function haApply(sp)
    if sp.ac then return haApplyAC(sp) end
    local d = haDB(sp)
    local cx, cy, rad = haRing(sp)
    local edit = _G.EditModeManagerFrame and _G.EditModeManagerFrame:IsShown()
    if not (d and d.on and cx) or edit then
        if sp.holder then sp.holder:Hide() end   -- no target: the icons stay parked, out of sight
        local ringOn = UbermocUIDB[sp.rdb] and UbermocUIDB[sp.rdb].on
        local cov = API.floatingCovers and API.floatingCovers(sp.unit or "player")
        if sp.moved and (not d or not d.on or edit or not ringOn or cov) then pcall(haRestore, sp) end
        return
    end
    if sp.unit and not sp.holder then
        sp.holder = CreateFrame("Frame", "UbermocHaloAuras_" .. sp.key, UIParent)
        sp.holder:SetAllPoints(UIParent)
        sp.holder:SetFrameStrata("MEDIUM")
    end
    if sp.holder then sp.holder:Show() end
    haCollect(sp)
    local start = rad + d.gap * UIParent:GetEffectiveScale()
    local ok, nextR = pcall(haLayout, sp, sp.buffs, sp.nb, d.buffs, cx, cy, start, d)
    local dstart = (ok and d.debuffs == d.buffs and nextR) or start
    pcall(haLayout, sp, sp.debuffs, sp.nd, d.debuffs, cx, cy, dstart, d)
    -- hidden ones: parked far off the screen (they come back when shown again)
    for i = 1, sp.np or 0 do pcall(haPut, sp, sp.parked[i], d.size, -20000, -20000) end
    sp.moved = true
end
local function haApplyAll()
    if haBusy then return end
    haBusy = true
    for _, sp in ipairs(HA) do pcall(haApply, sp) end
    haBusy = false
end
local function haApplyOne(sp)
    if haBusy then return end
    haBusy = true
    pcall(haApply, sp)
    haBusy = false
end
API.haloAurasApply = function(key)
    local sp = HA_BY[key or "player"]
    if sp then sp.filled = nil; haApplyOne(sp) end
end

-- What is on a unit right now, for the settings list: { { id, name, icon, harmful }, ... }.
local function activeAuras(unit)
    local out, seen = {}, {}
    local U = C_UnitAuras
    if not (U and U.GetAuraDataByIndex) or not UnitExists(unit) then return out end
    for _, f in ipairs({ "HELPFUL", "HARMFUL" }) do
        for i = 1, 40 do
            local ok, d = pcall(U.GetAuraDataByIndex, unit, i, f)
            if not ok or not d then break end
            local id, name, icon = plain(d.spellId), plain(d.name), plain(d.icon)
            if id and not seen[id] then
                seen[id] = true
                out[#out + 1] = { id = id, name = name or ("Spell " .. id), icon = icon, harmful = f == "HARMFUL" }
            end
        end
    end
    return out
end
API.auraHidden = function(id) return hideDB()[id] ~= nil end
API.auraHiddenIDs = function() return hideDB() end
API.auraSetHidden = function(a, hide)
    local h = hideDB()
    if hide then h[a.id] = { a.name, a.icon } else h[a.id] = nil end
    API.auraHideVer = (API.auraHideVer or 0) + 1
    if API.floatAuraFilterChanged then pcall(API.floatAuraFilterChanged) end
    for _, sp in ipairs(HA) do sp.sb = nil; if sp.moved or hide then haApplyOne(sp) end end
    if not hide then
        -- a shown-again icon goes back to its arc (or its usual place when the arcs are off)
        for _, sp in ipairs(HA) do local d = haDB(sp); if d and not d.on and sp.moved then pcall(haRestore, sp) end end
    end
end

-- Settings list: what is on the unit now (Hide) or what you have hidden (Show again), 8 to a page.
function API.auraPicker(p, y, key)
    local unit = (key == "player" or not key) and "player" or key
    local ROWS = 8
    local state = { view = "now", page = 1 }
    local rows = {}
    local view = API.segRow(p, 228, y, { { "now", "On " .. (unit == "player" and "you" or "your " .. unit) .. " now", 150 }, { "hidden", "Hidden", 90 } },
        function() return state.view end, function(v) state.view = v; state.page = 1; state.refresh() end)
    API.newLabel(p, "Show or hide", 40, y - 4)
    local info = API.newLabel(p, "", 40, y - 40, "GameFontHighlightSmall")
    info:SetWidth(540); info:SetJustifyH("LEFT")
    local function list()
        if state.view == "hidden" then
            local out = {}
            for id, v in pairs(hideDB()) do
                out[#out + 1] = { id = id, name = type(v) == "table" and v[1] or ("Spell " .. id), icon = type(v) == "table" and v[2] or nil }
            end
            table.sort(out, function(a, b) return tostring(a.name) < tostring(b.name) end)
            return out
        end
        return activeAuras(unit)
    end
    for i = 1, ROWS do
        local ry = y - 66 - (i - 1) * 32
        local r = {}
        r.icon = p:CreateTexture(nil, "ARTWORK"); r.icon:SetSize(24, 24); r.icon:SetPoint("TOPLEFT", 40, ry + 1)
        r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        r.name = API.newLabel(p, "", 72, ry - 4)
        r.name:SetWidth(290); r.name:SetJustifyH("LEFT"); r.name:SetWordWrap(false)
        r.btn = API.newButton(p, "Hide", 130, 380, ry, function()
            if not r.a then return end
            API.auraSetHidden(r.a, not API.auraHidden(r.a.id))
            state.refresh()
        end)
        rows[i] = r
    end
    local py = y - 66 - ROWS * 32 - 4
    local prevB = API.newButton(p, "< Page", 90, 40, py, function() state.page = math.max(1, state.page - 1); state.refresh() end)
    local pageL = API.newLabel(p, "", 140, py - 4)
    local nextB = API.newButton(p, "Page >", 90, 230, py, function() state.page = state.page + 1; state.refresh() end)
    API.newButton(p, "Refresh list", 130, 380, py, function() state.refresh() end)
    state.refresh = function()
        view.refresh()
        -- on another tab of the page the list stays hidden (showing its rows would draw them over that tab)
        if not info:IsShown() then return end
        local L = list()
        local pages = math.max(1, math.ceil(#L / ROWS))
        if state.page > pages then state.page = pages end
        for i, r in ipairs(rows) do
            local a = L[(state.page - 1) * ROWS + i]
            r.a = a
            if a then
                r.icon:SetTexture(a.icon or 134400); r.icon:Show()
                local hid = API.auraHidden(a.id)
                r.name:SetText((a.harmful and "|cffff6060" or "|cff60c0ff") .. tostring(a.name) .. "|r" .. (hid and "  |cff999999(hidden)|r" or ""))
                r.btn:SetText(hid and "Show again" or "Hide"); r.btn:Show()
            else
                r.icon:Hide(); r.name:SetText(""); r.btn:Hide()
            end
        end
        pageL:SetText(pages > 1 and ("Page " .. state.page .. " of " .. pages) or "")
        prevB:SetShown(pages > 1); nextB:SetShown(pages > 1)
        if #L == 0 then
            info:SetText(state.view == "hidden" and "Nothing hidden." or ("No buffs or debuffs on " .. (unit == "player" and "you" or "your " .. unit) .. " right now (some can't be read during a fight)."))
        else
            info:SetText("Blue: buffs. Red: debuffs. A hidden one stays hidden on every halo frame until you show it again.")
        end
    end
    -- fill the list again as soon as its tab comes back into view
    local watch = CreateFrame("Frame", nil, p)
    local seen = false
    watch:SetScript("OnUpdate", function()
        local v = info:IsShown() and true or false
        if v ~= seen then seen = v; if v then state.refresh() end end
    end)
    return state.refresh, py - 40
end

-- Re-place right after the game lays its buttons out, and when a ring moves, grows or the icons change
-- (checked 4 times a second, without making any tables).
do
    local hooked = false
    local function hook()
        if hooked then return end
        hooked = true
        local P = HA_BY.player
        for _, fr in ipairs({ _G.BuffFrame, _G.DebuffFrame }) do
            if fr then
                if fr.UpdateAuraButtons then hooksecurefunc(fr, "UpdateAuraButtons", function() haApplyOne(P) end) end
                if fr.AuraContainer and fr.AuraContainer.UpdateGridLayout then hooksecurefunc(fr.AuraContainer, "UpdateGridLayout", function() haApplyOne(P) end) end
            end
        end
        for _, sp in ipairs(HA) do
            local fr = sp.blizz and _G[sp.blizz]
            if fr and fr.UpdateAuras then hooksecurefunc(fr, "UpdateAuras", function() haApplyOne(sp) end) end
        end
    end
    local w = CreateFrame("Frame")
    local acc = 0
    w:SetScript("OnUpdate", function(_, dt)
        acc = acc + dt
        if acc < 0.25 then return end
        acc = 0
        if not (UbermocUIDB and UbermocUIDB.version) then return end
        hook()
        for _, sp in ipairs(HA) do
            local d = haDB(sp)
            if sp.ac then
                if d then pcall(haApplyAC, sp) end
            elseif d and (d.on or sp.moved) then
                local cx, cy, rad = haRing(sp)
                local onNow = (d.on and cx) and true or false
                local nb, nd = -1, -1
                if onNow then haCollect(sp); nb, nd = sp.nb, sp.nd + (sp.np or 0) * 1000 end
                local R = _G[sp.ring]
                local cbox = (R and R.ubCast) and (R.ubCL + R.ubCR * 3 + R.ubCT * 7 + R.ubCB * 11) or 0
                if cx ~= sp.sx or cy ~= sp.sy or rad ~= sp.sr or nb ~= sp.sb or nd ~= sp.sd or onNow ~= sp.son
                    or cbox ~= sp.scb or (not d.on and sp.moved) then
                    sp.sx, sp.sy, sp.sr, sp.sb, sp.sd, sp.son, sp.scb = cx, cy, rad, nb, nd, onNow, cbox
                    haApplyOne(sp)
                end
            end
        end
    end)
end

-- Put the saved choice into effect after login.
local prev = API.onLogin
API.onLogin = function(...)
    if prev then prev(...) end
    pcall(DB)
    pcall(applyBlizzard)
end
