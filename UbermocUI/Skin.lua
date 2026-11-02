-- Ubermoc UI - Copyright (c) 2026 Marcos. All rights reserved.
-- This file is protected by copyright. It may not be copied, modified, redistributed or reused, in whole or
-- in part, without the written permission of the author. See LICENSE.txt.
----------------------------------------------------------------------
-- Ubermoc UI: textures for the round frames
-- A pattern (grain, brushed metal, carbon fibre...) and a shine laid over the halo frames, the party
-- and raid frames and the radial menus. Each overlay is cut to the exact shape of the ring or disc it
-- sits on, so nothing spills into the gaps between rings.
----------------------------------------------------------------------
local API = UbermocUIAPI
if not API then return end

local MEDIA = "Interface\\AddOns\\UbermocUI\\Media\\"
local PATHS = setmetatable({}, { __index = function(t, id)   -- one string per texture, made once
    local v = MEDIA .. "skin_" .. id .. ".tga"; t[id] = v; return v end })

local STYLES = {
    { id = "none", label = "None (clean)" },
    { id = "grain", label = "Fine grain" },
    { id = "brushed", label = "Brushed metal" },
    { id = "carbon", label = "Carbon fibre" },
    { id = "leather", label = "Leather" },
    { id = "stone", label = "Cracked stone" },
    { id = "canvas", label = "Canvas" },
    { id = "hex", label = "Diamond mesh" },
    { id = "dots", label = "Dots" },
    { id = "scan", label = "Scan lines" },
    { id = "stripes", label = "Diagonal stripes" },
}
local SHINES = {
    { id = "none", label = "No shine" },
    { id = "gloss", label = "Gloss: light top, dark bottom" },
    { id = "glow", label = "Soft light from the top left" },
}
local GROUPS = {
    { id = "halo", label = "Halo Frames", desc = "Player, pet, target, target of target and focus." },
    { id = "party", label = "Party & Raid", desc = "Every member circle of the party and raid frames." },
    { id = "dials", label = "Radial Menus", desc = "The discs of the pet and utility radial menus." },
}
API.SKIN_STYLES, API.SKIN_SHINES = STYLES, SHINES

local function groupDefaults()
    return { style = "grain", strength = 35, scale = 100, shine = "gloss", shineA = 30 }
end

local filled   -- the settings table whose defaults are already filled in (DB() runs many times a second)
local function DB()
    UbermocUIDB = UbermocUIDB or {}
    local d = UbermocUIDB.skin
    if type(d) ~= "table" then d = {}; UbermocUIDB.skin = d end
    if d == filled then return d end   -- defaults already filled in for this table
    for _, g in ipairs(GROUPS) do
        if type(d[g.id]) ~= "table" then d[g.id] = {} end
        for k, v in pairs(groupDefaults()) do if d[g.id][k] == nil then d[g.id][k] = v end end
    end
    filled = d
    return d
end
API.skinDB = DB

local function find(list, id)
    for i, e in ipairs(list) do if e.id == id then return e, i end end
    return list[1], 1
end

----------------------------------------------------------------------
-- Overlays
----------------------------------------------------------------------
local objs = setmetatable({}, { __mode = "k" })

-- host: the frame the textures are drawn on (above whatever they cover).
function API.skinNew(host, layer, sub)
    local o = { host = host }
    sub = sub or 1
    o.pat = host:CreateTexture(nil, layer or "OVERLAY", nil, sub)
    o.shine = host:CreateTexture(nil, layer or "OVERLAY", nil, math.min(7, sub + 1))
    o.mO = host:CreateMaskTexture()
    o.mO:SetTexture(MEDIA .. "ringdisc.tga", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    o.mH = host:CreateMaskTexture()
    o.mH:SetTexture(MEDIA .. "ringhole.tga", "CLAMP", "CLAMP")
    o.pat:AddMaskTexture(o.mO)
    o.shine:AddMaskTexture(o.mO)
    o.pat:Hide(); o.shine:Hide()
    objs[o] = true
    return o
end

local function apply(o)
    if not o.anchor or not o.outer then return end
    local g = DB()[o.group] or groupDefaults()
    local outer, inner = o.outer, o.inner or 0
    local size = outer * 2
    o.mO:ClearAllPoints(); o.mO:SetPoint("CENTER", o.anchor, "CENTER"); o.mO:SetSize(size, size)
    local wantHole = inner > 0.5
    if wantHole then
        o.mH:ClearAllPoints(); o.mH:SetPoint("CENTER", o.anchor, "CENTER"); o.mH:SetSize(inner * 4, inner * 4)
    end
    if wantHole ~= o.hole then
        o.hole = wantHole
        for _, t in ipairs({ o.pat, o.shine }) do
            if wantHole then pcall(t.AddMaskTexture, t, o.mH) else pcall(t.RemoveMaskTexture, t, o.mH) end
        end
    end
    local on = o.enabled ~= false
    if on and g.style ~= "none" and (g.strength or 0) > 0 then
        local t = o.pat
        if t.ubermocStyle ~= g.style then
            t.ubermocStyle = g.style
            t:SetTexture(PATHS[g.style], "REPEAT", "REPEAT")
        end
        t:ClearAllPoints(); t:SetPoint("CENTER", o.anchor, "CENTER"); t:SetSize(size, size)
        local tile = 128 * math.max(0.25, (g.scale or 100) / 100)
        t:SetTexCoord(0, size / tile, 0, size / tile)
        t:SetAlpha(math.min(1, g.strength / 100))
        t:Show()
    else
        o.pat:Hide()
    end
    if on and g.shine ~= "none" and (g.shineA or 0) > 0 then
        local t = o.shine
        -- The shine spans the whole round frame (o.span), so every ring of one frame shares one light.
        local span = (o.span or outer) * 2
        t:SetTexture(PATHS[g.shine])
        t:ClearAllPoints(); t:SetPoint("CENTER", o.anchor, "CENTER"); t:SetSize(span, span)
        t:SetTexCoord(0, 1, 0, 1)
        t:SetAlpha(math.min(1, g.shineA / 100))
        t:Show()
    else
        o.shine:Hide()
    end
end

-- outer / inner: radii of the ring (inner 0 = a full disc). span: radius of the whole frame, for the shine.
function API.skinLayout(o, group, anchor, outer, inner, span)
    if not o then return end
    o.group, o.anchor, o.outer, o.inner, o.span = group, anchor, outer, inner, span
    pcall(apply, o)
end

function API.skinShow(o, on)
    if not o then return end
    o.enabled = on and true or false
    pcall(apply, o)
end

function API.skinRefresh()
    for o in pairs(objs) do pcall(apply, o) end
end

----------------------------------------------------------------------
-- Page
----------------------------------------------------------------------
-- Parts of the addon with flat plates instead of round frames. Their texture and borders live in their own
-- settings (so nothing about how they are drawn changes); this page is just where they are set.
local FLAT = {
    minimap = { label = "Minimap", desc = "The minimal map's frame and info board, or the border of the round and square map looks.",
        db = function() return API.miniDB and API.miniDB() end,
        def = { tex = "brushed", texA = 50 },
        apply = function()
            if API.paintMiniMap then pcall(API.paintMiniMap) end
            if API.updateMiniBar then pcall(API.updateMiniBar, true) end
            if API.mmApply then pcall(API.mmApply) end
            if API.applyMapBack then pcall(API.applyMapBack) end
        end },
    floating = { label = "Floating Frames", desc = "The health, resource and cast bars and the portrait of every floating frame (player, pet, party, raid, target, focus and the rest). One look for all of them.",
        db = function() return API.floatTexDB and API.floatTexDB() end,
        def = { tex = "none", texA = 50 },
        apply = function() if API.targetFrameRefresh then pcall(API.targetFrameRefresh) end end },
    menubar = { label = "Menu Bar", desc = "The menu bar's angled plates and the buttons on them.",
        db = function() return API.toolbarDB and API.toolbarDB() end,
        def = { tex = "brushed", texA = 50, edge = true, noBorder = false },
        apply = function() if API.toolbarRestyle then pcall(API.toolbarRestyle) end end },
    abar = { label = "Action Bars", desc = "The action bars' plates (Blade design) and the buttons on them.",
        db = function() return API.abarDB and API.abarDB() end,
        def = { tex = "brushed", texA = 50, edge = true, borders = false, noBorder = true },
        apply = function() if API.abarLayout then pcall(API.abarLayout) end end },
}
local ALL = { "halo", "party", "floating", "dials", "minimap", "menubar", "abar", "nameplates", "dialogue" }
-- Parts with only borders (no texture of their own).
local BORDER_ONLY = {
    nameplates = { label = "Nameplates", desc = "Outlines and borders drawn on the nameplates." },
    dialogue = { label = "NPC Dialogue", desc = "The NPC dialogue window, its buttons and the reward icons." },
}
local LABEL = {}
for _, g in ipairs(GROUPS) do LABEL[g.id] = g end
for id, f in pairs(FLAT) do LABEL[id] = f end
for id, f in pairs(BORDER_ONLY) do LABEL[id] = f end

local function getStyle(g)
    local f = FLAT[g]
    if f then local d = f.db(); return d and d.tex or "none" end
    if BORDER_ONLY[g] then return "none" end
    return DB()[g].style
end
local function getStrength(g)
    local f = FLAT[g]
    if f then local d = f.db(); return d and d.texA or 50 end
    if BORDER_ONLY[g] then return 0 end
    return DB()[g].strength
end
local function setTex(g, style, strength)
    if BORDER_ONLY[g] then return end
    local f = FLAT[g]
    if f then
        local d = f.db()
        if not d then return end
        if style then d.tex = style end
        if strength then d.texA = strength end
        f.apply()
    else
        local t = DB()[g]
        if style then t.style = style end
        if strength then t.strength = strength end
        API.skinRefresh()
    end
end
local function minimalOn() local m = UbermocUIDB.mm and UbermocUIDB.mm.mini; return m and m.on and true or false end

local function buildPage()
    local panel = CreateFrame("Frame")
    panel.name = "Textures"
    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 8, -42)   -- under the tabs
    scroll:SetPoint("BOTTOMRIGHT", -30, 8)
    local p = CreateFrame("Frame", nil, scroll)
    p:SetSize(740, 940)
    scroll:SetScrollChild(p)
    API.newLabel(p, "Textures and Borders", 8, -8, "GameFontNormalHuge")
    API.newLabel(p, "Every texture and border in Ubermoc UI, in one place. Pick a part from the tabs, then its texture and its borders.", 8, -36, "GameFontHighlightSmall")

    local group = "halo"
    local scratch = {}   -- flat parts have no scale or shine: their (hidden) controls write here
    local function G() return DB()[group] or scratch end
    local pct = function(v) return math.floor(v + 0.5) .. "%" end
    local px = function(v) return math.floor(v + 0.5) .. " px" end

    -- Which part: one tab each, like the other pages' tabs.
    local tdefs = {}
    for i, id in ipairs(ALL) do tdefs[i] = { id, LABEL[id].label } end
    local tabs = API.tabStrip(panel, 0, tdefs, function(k) group = k; scroll:SetVerticalScroll(0); panel.refresh() end)
    tabs.onHeight = function(h)
        scroll:ClearAllPoints()
        scroll:SetPoint("TOPLEFT", 8, -(h + 4))
        scroll:SetPoint("BOTTOMRIGHT", -30, 8)
    end
    tabs.onHeight(tabs.height or 38)
    local desc = API.newLabel(p, "", 8, -64, "GameFontHighlightSmall")

    -- Previews: a ring and disc for the round parts, a plate for the flat ones.
    local pv = CreateFrame("Frame", nil, p)
    pv:SetSize(200, 200)
    pv:SetPoint("TOPLEFT", 520, -130)
    local pbg = pv:CreateTexture(nil, "BACKGROUND", nil, -8)
    pbg:SetAllPoints(); pbg:SetColorTexture(0.06, 0.08, 0.1, 0.9)
    local function circle(r, g, b, a, sub, size, holeR)
        local t = pv:CreateTexture(nil, "BACKGROUND", nil, sub)
        t:SetTexture(MEDIA .. "ringdisc.tga")
        t:SetPoint("CENTER")
        t:SetSize(size, size)
        t:SetVertexColor(r, g, b, a)
        if holeR then
            local m = pv:CreateMaskTexture()
            m:SetTexture(MEDIA .. "ringhole.tga", "CLAMP", "CLAMP")
            m:SetPoint("CENTER"); m:SetSize(holeR * 4, holeR * 4)
            t:AddMaskTexture(m)
        end
        return t
    end
    circle(0.05, 0.05, 0.08, 1, -6, 172, 70)
    circle(0.25, 0.5, 1, 1, -5, 172, 70)
    circle(0.1, 0.1, 0.13, 1, -6, 140)
    circle(0.2, 0.75, 0.3, 1, -5, 136)
    local pvHost = CreateFrame("Frame", nil, pv)
    pvHost:SetAllPoints(pv)
    local skRing = API.skinNew(pvHost, "ARTWORK", 1)
    local skDisc = API.skinNew(pvHost, "ARTWORK", 3)
    local pvText = pvHost:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    pvText:SetPoint("CENTER"); pvText:SetText("85%")
    local flat = CreateFrame("Frame", nil, p)
    flat:SetSize(200, 70)
    flat:SetPoint("TOPLEFT", 520, -160)
    local fbg = flat:CreateTexture(nil, "BACKGROUND", nil, -8)
    fbg:SetAllPoints(); fbg:SetColorTexture(0.045, 0.05, 0.068, 0.95)
    local fpat = flat:CreateTexture(nil, "BACKGROUND", nil, -7)
    fpat:SetAllPoints()
    local pvLabel = API.newLabel(p, "Preview", 520, -112, "GameFontHighlightSmall")

    -- Texture choices: a grid of small swatches showing each pattern (on its own frame, so border-only
    -- parts can hide it).
    local texArea = CreateFrame("Frame", nil, p)
    texArea:SetPoint("TOPLEFT", 0, -122)
    texArea:SetSize(500, 270)
    API.newLabel(texArea, "Texture", 8, 0, "GameFontNormalLarge")
    local sw = {}
    for i, st in ipairs(STYLES) do
        local col, row = (i - 1) % 4, math.floor((i - 1) / 4)
        local b = CreateFrame("Button", nil, texArea)
        b:SetSize(112, 62)
        b:SetPoint("TOPLEFT", 8 + col * 120, -30 - row * 70)
        API.flatButton(b)
        local base = b:CreateTexture(nil, "ARTWORK", nil, 0)
        base:SetPoint("TOPLEFT", 4, -4); base:SetPoint("BOTTOMRIGHT", -4, 18)
        base:SetColorTexture(0.25, 0.45, 0.85, 1)
        local pat = b:CreateTexture(nil, "ARTWORK", nil, 1)
        pat:SetAllPoints(base)
        if st.id ~= "none" then
            pat:SetTexture(PATHS[st.id], "REPEAT", "REPEAT")
            pat:SetTexCoord(0, 104 / 128, 0, 40 / 128)
            pat:SetAlpha(0.7)
        else
            pat:Hide()
        end
        local lab = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        lab:SetPoint("BOTTOM", 0, 4)
        lab:SetText(st.label)
        local sel = b:CreateTexture(nil, "OVERLAY")
        sel:SetPoint("TOPLEFT", -2, 2); sel:SetPoint("BOTTOMRIGHT", 2, -2)
        sel:SetColorTexture(1, 0.82, 0.1, 0.35)
        b.sel = sel
        b:SetScript("OnClick", function() setTex(group, st.id, nil); panel.refresh() end)
        sw[st.id] = b
    end

    local function slider(parent, label, yy, min, max, fmt, fn)
        local lab = API.newLabel(parent, label, 32, yy - 6)   -- level with the middle of the control
        local s = API.makeSlider(parent, 150, min, max, 1, fmt, fn)
        s:SetPoint("TOPLEFT", 260, yy)
        s.ubermocLabel = lab
        return s
    end
    local function check(parent, label, yy, fn) return API.newCheck(parent, label, 8, yy, function(v) fn(v); panel.refresh() end) end
    local function section(h)
        local f = CreateFrame("Frame", nil, p)
        f:SetSize(700, h)
        f.h = h
        return f
    end

    -- Strength (every textured part).
    local strBox = section(40)
    local sStr = slider(strBox, "Texture strength", 0, 0, 100, pct, function(v) setTex(group, nil, v); panel.refresh() end)

    -- Round parts: scale and shine.
    local roundBox = section(130)
    local sScale = slider(roundBox, "Texture scale", 0, 25, 400, pct, function(v) G().scale = v; API.skinRefresh() end)
    API.newLabel(roundBox, "Shine", 32, -44)
    local shineBtn = API.segRow(roundBox, 228, -40, { { "none", "None", 70 }, { "gloss", "Gloss", 70 }, { "glow", "Soft light", 90 } },
        function() return find(SHINES, G().shine).id end, function(v) G().shine = v; API.skinRefresh(); panel.refresh() end)
    local sShine = slider(roundBox, "Shine strength", -84, 0, 100, pct, function(v) G().shineA = v; API.skinRefresh() end)

    -- Radial menus: how see-through the dark discs behind the entries are.
    local dialBox = section(50)
    local dA = slider(dialBox, "Background opacity", 0, 0, 100, pct, function(v) DB().dials.bgA = v; if API.dialBgApply then API.dialBgApply() end end)
    API.sliderDefault(dA, 100)

    -- Minimap: the info board's own texture and background (its border is one of the border blocks below).
    local function mini() return API.miniDB and API.miniDB() or {} end
    local ibBox = section(130)
    API.newLabel(ibBox, "Info board", 8, 0, "GameFontNormalLarge")
    API.newLabel(ibBox, "Board texture", 32, -38)
    local ibList = { { "frame", "Same as the map frame" } }
    local ibTex = API.cycler(ibBox, 228, -32, 170, function()
        if #ibList == 1 then for _, st in ipairs(STYLES) do ibList[#ibList + 1] = { st.id, st.id == "none" and "None" or st.label } end end
        return ibList
    end, function() return mini().boardTex or "frame" end, function(v) mini().boardTex = v; FLAT.minimap.apply() end)
    local ibA = slider(ibBox, "Board background opacity", -74, 0, 100, pct, function(v) mini().boardA = v; FLAT.minimap.apply() end)
    API.sliderDefault(ibA, 94)
    local mmNote = API.newLabel(ibBox, "", 8, -112, "GameFontHighlightSmall")
    mmNote:SetWidth(700); mmNote:SetJustifyH("LEFT")

    -- The game's own art: plain on / off switches (not our drawing, so no colour or thickness).
    local gameBox = section(110)
    API.newLabel(gameBox, "The game's own art", 8, 0, "GameFontNormalLarge")
    local gMenu = check(gameBox, "Menu bar: the game's borders on the buttons", -32, function(v)
        local d = FLAT.menubar.db(); if d then d.noBorder = not v; FLAT.menubar.apply() end
    end)
    local gAbar = check(gameBox, "Action bars: the game's button frames", -32, function(v)
        local d = FLAT.abar.db(); if d then d.noBorder = not v; FLAT.abar.apply() end
    end)
    local abNote = API.newLabel(gameBox, "The action bars' texture and edge line show on the Blade design (Action Bars page).", 8, -96, "GameFontHighlightSmall")

    -- One block per border, all with the same options. Enemy / friendly nameplate borders share one block
    -- with a choice of which nameplates it sets (or both at once).
    local PAIRS = {
        npOutline_enemy = { "npOutline_friendly", "Health bar outline" },
        npLevel_enemy = { "npLevel_friendly", "Level square border" },
        npDebuff_enemy = { "npDebuff_friendly", "Debuff icon borders" },
    }
    local PAIRED = {}
    for _, v in pairs(PAIRS) do PAIRED[v[1]] = true end
    local blocks = {}
    local function borderBlock(def)
        if PAIRED[def.key] then return end
        local pair = PAIRS[def.key]
        local key = def.key
        local which = "both"
        local f = section(pair and 214 or 178)
        local top = pair and -36 or 0   -- room for the enemy / friendly choice
        local function curKey() return (pair and which == "friendly") and pair[1] or def.key end
        local function bd() return API.borderDB(curKey()) or {} end
        -- set(fn): change the border(s) being edited
        local function set(fn)
            local keys = { curKey() }
            if pair and which == "both" then keys = { def.key, pair[1] } end
            for _, k in ipairs(keys) do
                local d = API.borderDB(k)
                if d then fn(d) end
                API.applyBorder(k)
            end
            panel.refresh()
        end
        API.newLabel(f, pair and pair[2] or def.label, 8, 0, "GameFontNormalLarge")
        local whichRow
        if pair then
            API.newLabel(f, "Nameplates", 32, -36)
            whichRow = API.segRow(f, 228, -30, { { "both", "Both", 70 }, { "enemy", "Enemy", 76 }, { "friendly", "Friendly", 86 } },
                function() return which end, function(v) which = v; panel.refresh() end)
        end
        local on = API.newCheck(f, "Show this border", 8, top - 30, function(v) set(function(d) d.on = v end) end)
        local fmt = def.sizeFmt or px
        local size = slider(f, "Thickness", top - 64, 1, def.maxSize or 8, fmt, function(v) set(function(d) d.size = v end) end)
        API.sliderDefault(size, def.size or 1)
        API.newLabel(f, "Colour", 32, top - 107)
        local opts = { { "class", "Class colour", 104 }, { "custom", "My colour", 90 } }
        if def.auto then opts[3] = { "auto", def.auto, math.max(120, #def.auto * 7 + 16) } end
        local mode = API.segRow(f, 228, top - 100, opts, function() return bd().mode or "class" end, function(v) set(function(d) d.mode = v end) end)
        local swb = CreateFrame("Button", nil, f)
        swb:SetSize(30, 26)
        local w = 0
        for _, o in ipairs(opts) do w = w + o[3] + 4 end
        swb:SetPoint("TOPLEFT", 228 + w + 6, top - 100)
        API.flatButton(swb)
        local swt = swb:CreateTexture(nil, "ARTWORK")
        swt:SetPoint("TOPLEFT", 4, -4); swt:SetPoint("BOTTOMRIGHT", -4, 4)
        swb:SetScript("OnClick", function()
            local d = bd()
            API.pickColor(d.r or 1, d.g or 1, d.b or 1, nil, function(r, g, b)
                set(function(x) x.r, x.g, x.b, x.mode = r, g, b, "custom" end)
            end)
        end)
        local op = slider(f, "Opacity", top - 142, 0, 100, pct, function(v) set(function(d) d.a = v end) end)
        API.sliderDefault(op, def.a or 100)
        f.refresh = function()
            if whichRow then whichRow.refresh() end
            local d = bd()
            on:SetChecked(d.on and true or false)
            API.setSlider(size, d.size or 1); API.setSlider(op, d.a or 100)
            mode.refresh()
            local _, _, r, g, b = API.borderOf(curKey())
            swt:SetColorTexture(r, g, b, 1)
            local live = d.on and true or false
            API.setActive(size, live); API.setActive(mode, live); API.setActive(swb, live); API.setActive(op, live)
        end
        f.def = def
        blocks[#blocks + 1] = f
        return f
    end
    for _, def in ipairs(API.BORDERS or {}) do borderBlock(def) end
    local bordersHead = section(36)
    API.newLabel(bordersHead, "Borders", 8, 0, "GameFontNormalHuge")

    local useAll = API.newButton(p, "Use these settings for all", 260, 8, -900, function()
        if BORDER_ONLY[group] then return end
        local srcStyle, srcStr = getStyle(group), getStrength(group)
        local src = not FLAT[group] and G() or nil
        for _, id in ipairs(ALL) do
            if id ~= group and not BORDER_ONLY[id] then
                setTex(id, srcStyle, srcStr)
                if src and not FLAT[id] then
                    local t = DB()[id]
                    t.scale, t.shine, t.shineA = src.scale, src.shine, src.shineA
                end
            end
        end
        API.skinRefresh()
        panel.refresh()
    end)
    local useAllB = API.newButton(p, "Use these borders' colour for every border", 300, 278, -900, function()
        -- Copies the first border of this tab (on / off stays as each has it).
        local first
        for _, f in ipairs(blocks) do if f.def.part == group then first = f.def.key; break end end
        local src = first and API.borderDB(first)
        if not src then return end
        for _, def in ipairs(API.BORDERS) do
            local d = API.borderDB(def.key)
            if d and def.key ~= first then
                d.mode = (src.mode == "auto" and not def.auto) and "class" or src.mode
                d.r, d.g, d.b, d.a = src.r, src.g, src.b, src.a
                API.applyBorder(def.key)
            end
        end
        panel.refresh()
    end)
    local resetBtn = API.newButton(p, "Reset this part", 200, 8, -940, function()
        local f = FLAT[group]
        if f then
            local d = f.db()
            if d then for k, v in pairs(f.def) do d[k] = v end end
            f.apply()
        elseif not BORDER_ONLY[group] then
            local t = DB()[group]
            for k, v in pairs(groupDefaults()) do t[k] = v end
            t.bgA = nil; if API.dialBgApply then API.dialBgApply() end
            API.skinRefresh()
        end
        -- this part's borders back to their defaults (class colour)
        UbermocUIDB.borders = UbermocUIDB.borders or {}
        for _, def in ipairs(API.BORDERS) do
            if def.part == group then
                UbermocUIDB.borders[def.key] = { on = def.on ~= false, size = def.size or 1, a = def.a or 100, mode = "class" }
                API.applyBorder(def.key)
            end
        end
        panel.refresh()
    end)
    local note = API.newLabel(p, "", 8, -980, "GameFontHighlightSmall")
    note:SetWidth(700); note:SetJustifyH("LEFT"); note:SetWordWrap(true)
    note:SetText("Use these settings for all copies this part's texture and strength to every textured part. The border colour button does the same for every border. Class colour follows your character.")

    -- Stack what this tab shows, top to bottom.
    local function place(f, y)
        f:ClearAllPoints(); f:SetPoint("TOPLEFT", 0, y); f:Show()
        return y - f.h
    end
    function panel.refresh()
        local fl = FLAT[group]
        local bonly = BORDER_ONLY[group]
        tabs.mark(group)
        desc:SetText(LABEL[group].desc or "")
        for _, f in ipairs({ strBox, roundBox, ibBox, gameBox, dialBox, bordersHead }) do f:Hide() end
        for _, f in ipairs(blocks) do f:Hide() end
        local y = -100
        texArea:SetShown(not bonly); pvLabel:SetShown(not bonly)
        pv:SetShown(not fl and not bonly); flat:SetShown(fl and true or false)
        local style, str = getStyle(group), getStrength(group)
        if not bonly then
            for id, b in pairs(sw) do b.sel:SetShown(id == style) end
            y = -122 - 270
            y = place(strBox, y)
            API.setSlider(sStr, str or 0)
            API.setActive(sStr, style ~= "none")
        end
        if not fl and not bonly then
            y = place(roundBox, y)
            local g = G()
            API.setSlider(sScale, g.scale); API.setSlider(sShine, g.shineA)
            shineBtn.refresh()
            API.setActive(sScale, g.style ~= "none")
            API.setActive(sShine, g.shine ~= "none")
            API.skinLayout(skRing, group, pv, 86, 70, 86)
            API.skinLayout(skDisc, group, pv, 68, 0, 86)
        elseif fl then
            if style and style ~= "none" and (str or 0) > 0 then
                fpat:SetTexture(PATHS[style], "REPEAT", "REPEAT"); fpat:SetTexCoord(0, 200 / 128, 0, 70 / 128)
                fpat:SetAlpha(math.min(1, str / 100)); fpat:Show()
            else fpat:Hide() end
        end
        for _, b in pairs(sw) do API.setActive(b, group ~= "minimap" or minimalOn()) end
        if group == "minimap" then
            y = place(ibBox, y)
            ibTex.refresh(); API.setSlider(ibA, mini().boardA or 94)
            local mo = minimalOn()
            API.setActive(ibTex, mo); API.setActive(ibA, mo); API.setActive(sStr, mo and style ~= "none")
            mmNote:SetText(mo and "The minimal map is on: the texture is used on its frame and board. The map border is for the round and square looks."
                or "The round or square look is on: the texture, the frame and the board are for the two minimal looks (Minimap page).")
        end
        if group == "dials" then
            y = place(dialBox, y)
            API.setSlider(dA, DB().dials.bgA or 100)
        end
        if group == "menubar" or group == "abar" then
            y = place(gameBox, y)
            local mb, ab = FLAT.menubar.db() or {}, FLAT.abar.db() or {}
            for _, c in ipairs({ gMenu, gAbar }) do
                local show = (c == gMenu) == (group == "menubar") and (c == gMenu or group == "abar")
                c:SetShown(show); if c.label then c.label:SetShown(show) end
            end
            abNote:SetShown(group == "abar")
            gMenu:SetChecked(not mb.noBorder); gAbar:SetChecked(not ab.noBorder)
        end
        y = place(bordersHead, y - 8)
        for _, f in ipairs(blocks) do
            if f.def.part == group then
                y = place(f, y)
                f.refresh()
            end
        end
        y = y - 10
        useAll:ClearAllPoints(); useAll:SetPoint("TOPLEFT", 8, y); useAll:SetShown(not bonly)
        useAllB:ClearAllPoints(); useAllB:SetPoint("TOPLEFT", bonly and 8 or 278, y)
        resetBtn:ClearAllPoints(); resetBtn:SetPoint("TOPLEFT", 8, y - 36)
        note:ClearAllPoints(); note:SetPoint("TOPLEFT", 8, y - 76)
        p:SetHeight(-(y - 140))
    end
    panel:SetScript("OnShow", function() panel.refresh() end)
    API.skinSetGroup = function(g) if LABEL[g] then group = g; panel.refresh() end end
    API.resetters = API.resetters or {}
    API.resetters.textures = function()
        UbermocUIDB.skin = nil; DB(); API.skinRefresh()
        UbermocUIDB.borders = nil
        for _, def in ipairs(API.BORDERS) do API.applyBorder(def.key) end
    end
    API.addPage("textures", "Textures", panel)
end

-- Other pages' "Textures page" buttons: open this page on their part.
function API.openTextures(g)
    if API.openWindow then API.openWindow("textures") end
    if API.skinSetGroup then API.skinSetGroup(g) end
end

local prev = API.onLogin
API.onLogin = function()
    if prev then prev() end
    DB()
    API.later("Textures", buildPage)
    API.skinRefresh()
end
