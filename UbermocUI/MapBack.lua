-- Ubermoc UI - Copyright (c) 2026 Marcos. All rights reserved.
-- This file is protected by copyright. It may not be copied, modified, redistributed or reused, in whole or
-- in part, without the written permission of the author. See LICENSE.txt.
----------------------------------------------------------------------
-- Ubermoc UI: minimap background
-- The map's border (square or round) and the background behind the map and the bars around it.
----------------------------------------------------------------------
local API = UbermocUIAPI
if not API then return end

local PRESETS = {
    { id = "black", label = "Black", c = { 0, 0, 0 } },
    { id = "class", label = "Class colour" },
    { id = "white", label = "White", c = { 1, 1, 1 } },
    { id = "gray", label = "Dark gray", c = { 0.15, 0.15, 0.17 } },
    { id = "navy", label = "Navy blue", c = { 0.03, 0.08, 0.25 } },
    { id = "blue", label = "Blue", c = { 0.1, 0.3, 0.8 } },
    { id = "teal", label = "Teal", c = { 0.05, 0.4, 0.4 } },
    { id = "green", label = "Forest green", c = { 0.05, 0.25, 0.1 } },
    { id = "red", label = "Dark red", c = { 0.35, 0.05, 0.05 } },
    { id = "purple", label = "Purple", c = { 0.25, 0.08, 0.4 } },
    { id = "gold", label = "Gold", c = { 0.8, 0.62, 0.1 } },
    { id = "custom", label = "Custom colour" },
}
local function presetOf(id)
    for i, p in ipairs(PRESETS) do if p.id == id then return p, i end end
    return PRESETS[1], 1
end

local function DB()
    UbermocUIDB = UbermocUIDB or {}
    UbermocUIDB.mm = UbermocUIDB.mm or {}
    local b = UbermocUIDB.mm.back
    if type(b) ~= "table" then b = {}; UbermocUIDB.mm.back = b end
    if b.r == nil then b.r, b.g, b.b = 0, 0, 0 end
    if b.preset == nil then b.preset = ((b.r ~= 0 or b.g ~= 0 or b.b ~= 0) and "custom") or "black" end
    if b.a == nil then b.a = 0 end
    if b.pad == nil then b.pad = 4 end
    -- One time: the background now starts fully transparent.
    if not b.v2 then b.v2 = true; b.a = 0 end
    return b
end

function API.mmBack()
    local b = DB()
    local r, g, bl = b.r, b.g, b.b
    if b.preset == "class" then
        local _, cls = UnitClass("player")
        local cc = cls and RAID_CLASS_COLORS and RAID_CLASS_COLORS[cls]
        if cc then r, g, bl = cc.r, cc.g, cc.b end
    elseif b.preset ~= "custom" then
        local p = presetOf(b.preset)
        if p.c then r, g, bl = p.c[1], p.c[2], p.c[3] end
    end
    return r, g, bl, math.max(0, math.min(1, b.a / 100))
end

-- Border colour and opacity (Minimap > Border & Background).
-- From the Textures page (Minimap tab). The minimal map has its own frame, so this border is off then.
function API.mmBorder()
    local on, size, r, g, b, a = API.borderOf("mapBorder")
    local m = UbermocUIDB and UbermocUIDB.mm and UbermocUIDB.mm.mini
    if m and m.on then on = false end
    return r, g, b, a, on, size
end
local function oldDefault(r, g, b, dr, dg, db)
    return math.abs((r or dr) - dr) < 0.01 and math.abs((g or dg) - dg) < 0.01 and math.abs((b or db) - db) < 0.01
end
API.borderOldDefault = oldDefault
local function mapRefresh()
    if API.applySquare then pcall(API.applySquare) end
    if API.mmApply then pcall(API.mmApply) end
    pcall(API.applyMapBack)
    if API.paintMiniMap then pcall(API.paintMiniMap) end
    if API.updateMiniBar then pcall(API.updateMiniBar, true) end
end
API.mapBorderRefresh = mapRefresh
API.registerBorder({ key = "mapBorder", part = "minimap", label = "Map border (round and square looks)", on = false, size = 1, maxSize = 8,
    legacy = function()
        local bd = UbermocUIDB.mm and UbermocUIDB.mm.border or {}
        local sz = bd.size or 1
        if sz <= 0 then sz = (UbermocUIDB.mm.mini and UbermocUIDB.mm.mini.saved and UbermocUIDB.mm.mini.saved.bsize) or 1 end
        if sz <= 0 then sz = 1 end
        local custom = not oldDefault(bd.r, bd.g, bd.b, 0, 0, 0)
        return bd.on == true, sz, math.floor((bd.a or 1) * 100 + 0.5), custom and "custom" or "class", bd.r, bd.g, bd.b
    end, apply = mapRefresh })

-- A filled circle: a plain colour texture cut round with the portrait mask.
local function disc(parent, layer, sub)
    local t = parent:CreateTexture(nil, layer, nil, sub)
    t:SetColorTexture(1, 1, 1, 1)
    local m = parent:CreateMaskTexture()
    m:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    m:SetAllPoints(t)
    t:AddMaskTexture(m)
    return t
end

-- Behind the map: the background (square or round) and, on a round map, the border ring. The map
-- covers the middle, so only the part outside its edge shows.
local backFrame
local function ensureBack()
    if backFrame or not Minimap then return backFrame end
    local f = CreateFrame("Frame", "UbermocMapBackdrop", Minimap:GetParent() or UIParent)
    f:SetFrameStrata("BACKGROUND")
    f:SetAllPoints(Minimap)
    f.sq = f:CreateTexture(nil, "BACKGROUND", nil, 0)
    f.round = disc(f, "BACKGROUND", 0)
    f.ring = disc(f, "BACKGROUND", 2)
    backFrame = f
    return f
end

function API.applyMapBack()
    if not UbermocUIDB or not Minimap then return end
    local r, g, b, a = API.mmBack()
    local d = DB()
    local square = UbermocUIDB.squareMinimap and true or false
    local er, eg, eb, ea, eon, esz = API.mmBorder()
    local sb = API.squareBorder
    -- The square map's border pieces.
    if sb and sb.edges then
        for _, e in ipairs(sb.edges) do
            if eon and square then e[1]:SetColorTexture(er, eg, eb, ea) else e[1]:SetColorTexture(0, 0, 0, 0) end
        end
    end
    local f = ensureBack()
    if f then
        local edge = eon and esz or 0
        local pad = edge + ((d.reach ~= false) and (d.pad or 4) or 0)
        local mw, mh = Minimap:GetWidth() or 140, Minimap:GetHeight() or 140
        f:SetScale(1)
        f.sq:ClearAllPoints()
        f.sq:SetPoint("TOPLEFT", Minimap, "TOPLEFT", -pad, pad)
        f.sq:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMRIGHT", pad, -pad)
        f.sq:SetColorTexture(r, g, b, a)
        f.sq:SetShown(square and a > 0)
        f.round:ClearAllPoints()
        f.round:SetPoint("CENTER", Minimap, "CENTER")
        f.round:SetSize(mw + 2 * pad, mh + 2 * pad)
        f.round:SetVertexColor(r, g, b, a)
        f.round:SetShown((not square) and a > 0)
        f.ring:ClearAllPoints()
        f.ring:SetPoint("CENTER", Minimap, "CENTER")
        f.ring:SetSize(mw + 2 * edge, mh + 2 * edge)
        f.ring:SetVertexColor(er, eg, eb, ea)
        f.ring:SetShown((not square) and eon and edge > 0)
        f:Show()
    end
    local s = API.stripFrame
    if s and s.bg then s.bg:SetColorTexture(r, g, b, 0.95 * a) end
    local x = _G.UbermocXPBar
    if x and x.bg then x.bg:SetColorTexture(r, g, b, 0.95 * a) end
    local i = _G.UbermocInfoBar
    if i and i.bg then
        local c = UbermocUIDB.mm and UbermocUIDB.mm.info
        i.bg:SetColorTexture(r, g, b, math.min(1, ((c and c.bg) or 70) / 100) * a)
    end
end

local function swatch(sc, text, y, get, set)
    API.newLabel(sc, text, 40, y - 4)
    local swb = CreateFrame("Button", nil, sc)
    swb:SetSize(30, 30)
    swb:SetPoint("TOPLEFT", 240, y + 2)
    API.flatButton(swb)
    local t = swb:CreateTexture(nil, "ARTWORK")
    t:SetPoint("TOPLEFT", 4, -4); t:SetPoint("BOTTOMRIGHT", -4, 4)
    swb.paint = function() local r, g, b = get(); t:SetColorTexture(r, g, b, 1) end
    swb:SetScript("OnClick", function()
        local r, g, b = get()
        API.pickColor(r, g, b, nil, function(nr, ng, nb) set(nr, ng, nb); swb.paint(); API.applyMapBack() end)
    end)
    return swb
end

function API.buildMapBackOptions(sc, panel, y)
    local pct = function(v) return math.floor(v + 0.5) .. "%" end
    local px = function(v) return math.floor(v + 0.5) .. " px" end
    local function bd() local m = UbermocUIDB.mm; m.border = m.border or { size = 1, on = false }; return m.border end
    local function relayout() if API.mmApply then pcall(API.mmApply) end; API.applyMapBack() end
    -- Size and position -------------------------------------------------------------------------
    API.newLabel(sc, "Map size and position", 8, y, "GameFontNormalLarge")
    y = y - 34
    API.newLabel(sc, "Map size", 40, y + 2)
    local sizeS = API.makeSlider(sc, 140, 50, 200, 5, pct, function(v)
        UbermocUIDB.mm.mapSize = v
        if API.syncMapScale then API.syncMapScale() end
        if API.mmApply then pcall(API.mmApply) end
        API.applyMapBack()
    end)
    sizeS:SetPoint("TOPLEFT", 240, y)
    y = y - 38
    API.newButton(sc, "Use the game's size again (reloads)", 260, 40, y, function()
        UbermocUIDB.mm.mapSize = nil
        ReloadUI()
    end)
    y = y - 40
    local szN = API.newLabel(sc, "Makes the whole map bigger or smaller; the experience bar, top strip, bottom bar and addon box follow it. Until you move this slider the game's own size (layout editor) is used.", 8, y, "GameFontHighlightSmall")
    szN:SetWidth(530); szN:SetJustifyH("LEFT"); szN:SetWordWrap(true)
    y = y - 44
    local flushCB = API.newCheck(sc, "Move the map flush against the screen edge", 8, y, function(v)
        UbermocUIDB.mm.flush = v
    end)
    y = y - 34
    local flN = API.newLabel(sc, "The game keeps a hidden margin around the map. With this on, a map placed near a screen edge (within about 24 px) is pulled right up against it. Done outside the layout editor and not in combat.", 8, y, "GameFontHighlightSmall")
    flN:SetWidth(530); flN:SetJustifyH("LEFT"); flN:SetWordWrap(true)
    y = y - 50
    local topCB = API.newCheck(sc, "Pull the map right up to the top of the screen", 8, y, function(v)
        UbermocUIDB.mm.flushTop = v
        if API.flushMap then pcall(API.flushMap) end
    end)
    y = y - 34
    local tpN = API.newLabel(sc, "However far below the top the game puts it: the top of whatever sits highest (experience bar, strip or the map itself) touches the top of the screen.", 8, y, "GameFontHighlightSmall")
    tpN:SetWidth(530); tpN:SetJustifyH("LEFT"); tpN:SetWordWrap(true)
    y = y - 44
    -- Text shadow -------------------------------------------------------------------------------
    API.newLabel(sc, "Text outline", 8, y, "GameFontNormalLarge")
    y = y - 34
    API.newLabel(sc, "Letters on the map (0 = no outline)", 40, y + 2)
    local shS = API.makeSlider(sc, 140, 0, 100, 5, pct, function(v)
        UbermocUIDB.mm.shadow = v
        if API.shadeAll then API.shadeAll() end
        relayout()
    end)
    shS:SetPoint("TOPLEFT", 240, y)
    y = y - 34
    local shN = API.newLabel(sc, "One setting for every piece of text on and around the map. 0% is no shadow; the heavy outline only appears at 80% and up.", 8, y, "GameFontHighlightSmall")
    shN:SetWidth(530); shN:SetJustifyH("LEFT"); shN:SetWordWrap(true)
    y = y - 44
    -- The map border is on the Textures page (Minimap group), with every other border.
    -- Background --------------------------------------------------------------------------------
    API.newLabel(sc, "Map background", 8, y, "GameFontNormalLarge")
    y = y - 34
    API.newLabel(sc, "Colour", 40, y - 4)
    local presetList = {}
    for i, p in ipairs(PRESETS) do presetList[i] = { p.id, p.label } end
    local presetBtn = API.cycler(sc, 208, y, 140, function() return presetList end,
        function() return presetOf(DB().preset).id end, function(v) DB().preset = v; API.applyMapBack() end)
    y = y - 40
    local cCol = swatch(sc, "Custom colour", y, function() local d = DB(); return d.r, d.g, d.b end,
        function(r, g, b) local d = DB(); d.r, d.g, d.b, d.preset = r, g, b, "custom"; presetBtn.refresh() end)
    y = y - 44
    API.newLabel(sc, "Background opacity", 40, y + 2)
    local op = API.makeSlider(sc, 140, 0, 100, 1, pct, function(v) DB().a = v; API.applyMapBack() end)
    op:SetPoint("TOPLEFT", 240, y)
    y = y - 40
    local reachCB = API.newCheck(sc, "Background reaches past the map", 40, y + 4, function(v)
        DB().reach = v; API.applyMapBack(); panel.refreshBack()
    end)
    y = y - 34
    API.newLabel(sc, "Reaches past the map by", 40, y + 2)
    local padS = API.makeSlider(sc, 140, 0, 30, 1, px, function(v) DB().pad = v; API.applyMapBack() end)
    padS:SetPoint("TOPLEFT", 240, y)
    y = y - 44
    local note = API.newLabel(sc, "The background sits behind the map (a square or a circle to match it) and behind the top strip, experience bar and character info. At 0% (the default) it is see-through.", 8, y, "GameFontHighlightSmall")
    note:SetWidth(530); note:SetJustifyH("LEFT"); note:SetWordWrap(true)
    y = y - 50
    API.newButton(sc, "Reset the background", 240, 8, y, function()
        local d = DB()
        d.r, d.g, d.b, d.a, d.preset, d.pad, d.reach = 0, 0, 0, 0, "black", 4, true
        panel.refreshBack()
        relayout()
    end)
    function panel.refreshBack()
        local d = DB()
        cCol.paint()
        presetBtn.refresh()
        API.setSlider(op, d.a)
        API.setSlider(padS, d.pad or 4); reachCB:SetChecked(d.reach ~= false); API.setActive(padS, d.reach ~= false)
        flushCB:SetChecked(UbermocUIDB.mm.flush ~= false)
        topCB:SetChecked(UbermocUIDB.mm.flushTop and true or false)
        API.setSlider(sizeS, UbermocUIDB.mm.mapSize or math.floor(((MinimapCluster and MinimapCluster:GetScale()) or 1) * 100 + 0.5))
        API.setSlider(shS, (UbermocUIDB.mm.shadow == nil) and 10 or UbermocUIDB.mm.shadow)
    end
    panel.refreshBack()
end
