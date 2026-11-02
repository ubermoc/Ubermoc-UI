-- Ubermoc UI - Copyright (c) 2026 Marcos. All rights reserved.
-- This file is protected by copyright. It may not be copied, modified, redistributed or reused, in whole or
-- in part, without the written permission of the author. See LICENSE.txt.
-- NPC dialogue: one clean window for gossip, quest offers, quest progress and quest rewards.
-- Works from a controller (confirm / cancel / D-pad / compare) and from the keyboard (Space or Enter accepts,
-- Escape declines, arrow keys pick). The game's own gossip and quest windows are kept out of sight while it is on.
local API = UbermocUIAPI
if not API then return end

local W = 560
local MAXROWS = 8
local ROWH = 34

local function DB()
    UbermocUIDB = UbermocUIDB or {}
    local d = UbermocUIDB.npc
    if type(d) ~= "table" then d = {}; UbermocUIDB.npc = d end
    if d.on == nil then d.on = true end
    if d.theme == nil or d.theme == "slate" then d.theme = "dark" end
    if d.theme == "parchment" then d.theme = "light" end
    if d.scale == nil then d.scale = 100 end
    if d.text == nil then d.text = 14 end
    if d.markBest == nil then d.markBest = true end
    if d.portrait == nil then d.portrait = true end
    -- Where the window sits: against the right edge by default (left / centre too), plus a nudge.
    -- A window you dragged before keeps its spot (it was measured from the centre).
    if d.anchor == nil then d.anchor = d.x and "center" or "right" end
    return d
end

----------------------------------------------------------------------
-- Looks
----------------------------------------------------------------------
local THEME_NAME = { dark = "Dark parchment", light = "Light parchment" }
local PAPERS = { -- paper tints: light parchment uses them as they are, dark parchment takes them much darker
    { "Classic", 0.90, 0.84, 0.67 }, { "Cream", 0.96, 0.93, 0.82 }, { "Rose", 0.92, 0.82, 0.80 },
    { "Sage", 0.80, 0.86, 0.72 }, { "Sky", 0.76, 0.83, 0.90 }, { "Lilac", 0.84, 0.79, 0.90 }, { "Grey", 0.80, 0.80, 0.80 },
}
local ACCENTS = {
    { 0.96, 0.55, 0.73 }, { 0.78, 0.61, 0.43 }, { 1.00, 0.49, 0.04 }, { 1.00, 0.96, 0.41 }, { 0.20, 0.58, 0.50 },
    { 0.00, 0.44, 0.87 }, { 0.53, 0.53, 0.93 }, { 0.77, 0.12, 0.23 }, { 1, 1, 1 }, { 0.67, 0.83, 0.45 },
}
local function classColor()
    local _, cls = UnitClass("player")
    local c = cls and RAID_CLASS_COLORS and RAID_CLASS_COLORS[cls]
    if c then return { c.r, c.g, c.b } end
    return { 1, 0.82, 0.25 }
end
local function mixc(a, b, t) return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t } end
local function lum(c)
    local function ch(v) return v <= 0.03928 and v / 12.92 or ((v + 0.055) / 1.055) ^ 2.4 end
    return 0.2126 * ch(c[1]) + 0.7152 * ch(c[2]) + 0.0722 * ch(c[3])
end
local function contrast(a, b)
    local x, y = lum(a), lum(b)
    if x < y then x, y = y, x end
    return (x + 0.05) / (y + 0.05)
end
local function readable(acc, paper, toward)
    -- nudges the accent until it can be read on the paper (dark paper: lighter; light paper: darker)
    local c = acc
    for _ = 1, 30 do
        if contrast(c, paper) >= 4.5 then break end
        c = mixc(c, toward, 0.07)
    end
    return c
end

local cache
local function theme()
    local d = DB()
    local key = table.concat({ d.theme, tostring(d.accent and d.accent[1]), tostring(d.accent and d.accent[2]), tostring(d.accent and d.accent[3]),
                               tostring(d.paper and d.paper[1]), tostring(d.paper and d.paper[2]), tostring(d.paper and d.paper[3]) }, "|")
    if cache and cache.key == key then return cache end
    local dark = d.theme ~= "light"
    local acc = d.accent or classColor()
    local tint = d.paper or { PAPERS[1][2], PAPERS[1][3], PAPERS[1][4] }
    local tp = { tint[1], tint[2], tint[3] }
    local th = { key = key, dark = dark, font = "Fonts\\MORPHEUS.ttf" }
    if dark then
        local base = { tp[1] * 0.22, tp[2] * 0.2, tp[3] * 0.18 }
        local a = readable(acc, base, { 1, 1, 1 })
        th.paper = base; th.bg = { base[1], base[2], base[3], 0.98 }
        th.hi = { tp[1] * 0.34, tp[2] * 0.31, tp[3] * 0.27 }; th.lo = { 0.02, 0.015, 0.01 }
        th.text = { 0.92, 0.86, 0.75 }; th.sub = { 0.70, 0.62, 0.48 }
        th.edge = { a[1], a[2], a[3], 1 }; th.title = a
        th.btn = mixc(base, a, 0.16); th.btn[4] = 1; th.btnEdge = { a[1], a[2], a[3], 1 }
        th.hover = { 1, 0.9, 0.6, 0.07 }; th.sel = { a[1], a[2], a[3], 0.28 }
        th.vig = 0.7
    else
        local base = { tp[1], tp[2], tp[3] }
        local a = readable(acc, base, { 0.05, 0.02, 0 })
        th.paper = base; th.bg = { base[1], base[2], base[3], 0.98 }
        th.hi = { math.min(1, tp[1] + 0.06), math.min(1, tp[2] + 0.06), math.min(1, tp[3] + 0.05) }; th.lo = { tp[1] * 0.7, tp[2] * 0.65, tp[3] * 0.55 }
        th.text = { 0.18, 0.11, 0.04 }; th.sub = { 0.42, 0.30, 0.14 }
        th.edge = { a[1], a[2], a[3], 1 }; th.title = a
        th.btn = mixc(base, a, 0.18); th.btn[4] = 1; th.btnEdge = { a[1], a[2], a[3], 1 }
        th.hover = { 0.3, 0.18, 0.05, 0.1 }; th.sel = { a[1], a[2], a[3], 0.25 }
        th.vig = 0.4
    end
    th.name = THEME_NAME[d.theme] or THEME_NAME.dark
    cache = th
    return th
end

local function padOn()
    local ok, v = pcall(GetCVarBool, "GamePadEnable")
    return ok and v and true or false
end
local function glyph(key, fallback)
    if padOn() and API.padLabel then
        local ok, t = pcall(API.padLabel, key, true)
        if ok and type(t) == "string" and t ~= "" and t ~= "-" then return t end
    end
    return fallback
end

----------------------------------------------------------------------
-- State and widgets
----------------------------------------------------------------------
local f                    -- the window
local S = { mode = nil, sel = 1, top = 0, choice = nil, compare = false, data = nil, token = 0 }
local rowPool, itemPool = {}, {}
local render

local function color(t, a) return t[1], t[2], t[3], a or t[4] or 1 end

-- Button icons drawn to match the controller in use: coloured letters (Xbox, Steam), the four shapes
-- (PlayStation), plain letters (Switch), or the keyboard key when no gamepad is on.
local GMEDIA = "Interface\\AddOns\\UbermocUI\\Media\\"
local PAD_COL = { PAD1 = { 0.36, 0.74, 0.22 }, PAD2 = { 0.86, 0.24, 0.22 }, PAD3 = { 0.24, 0.48, 0.92 }, PAD4 = { 0.95, 0.76, 0.12 } }
local PS_SHAPE = { PAD1 = "cross", PAD2 = "circle", PAD3 = "square", PAD4 = "triangle" }
local PS_COL = { cross = { 0.56, 0.7, 1 }, circle = { 1, 0.42, 0.42 }, square = { 0.96, 0.56, 0.86 }, triangle = { 0.36, 0.86, 0.66 } }

local function makeGlyph(parent)
    local g = CreateFrame("Frame", nil, parent)
    g:SetSize(22, 22)
    g.bg = g:CreateTexture(nil, "ARTWORK")
    g.bg:SetAllPoints()
    g.bg:SetTexture(GMEDIA .. "disc.tga")
    g.ring = g:CreateTexture(nil, "OVERLAY")
    g.ring:SetTexture(GMEDIA .. "ringc_thick.tga")
    g.ring:SetPoint("CENTER"); g.ring:SetSize(13, 13)
    g.lines = {}
    for i = 1, 4 do
        local l = g:CreateLine(nil, "OVERLAY")
        l:SetThickness(2)
        g.lines[i] = l
    end
    g.fs = g:CreateFontString(nil, "OVERLAY")
    g.fs:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE")
    g.fs:SetPoint("CENTER", 0, 0)
    return g
end

local function line(g, i, x1, y1, x2, y2, c)
    local l = g.lines[i]
    l:SetStartPoint("CENTER", g, x1, y1)
    l:SetEndPoint("CENTER", g, x2, y2)
    l:SetColorTexture(c[1], c[2], c[3], 1)
    l:Show()
end

local function setGlyph(g, key, fallback)
    for i = 1, 4 do g.lines[i]:Hide() end
    g.ring:Hide()
    g.fs:SetText("")
    if not padOn() then
        g.bg:SetVertexColor(0.24, 0.25, 0.3, 1)
        g.fs:SetText(fallback)
        g.fs:SetFont(STANDARD_TEXT_FONT, #fallback > 2 and 8 or 11, "OUTLINE")
        return
    end
    local set = (API.padSet and API.padSet()) or "xbox"
    local label = glyph(key, fallback)
    if set == "ps5" or set == "ps3" then
        g.bg:SetVertexColor(0.07, 0.075, 0.09, 1)
        local shape = PS_SHAPE[key]
        local c = shape and PS_COL[shape]
        if shape == "cross" then
            line(g, 1, -5, 5, 5, -5, c); line(g, 2, -5, -5, 5, 5, c)
        elseif shape == "circle" then
            g.ring:SetVertexColor(c[1], c[2], c[3], 1); g.ring:Show()
        elseif shape == "square" then
            line(g, 1, -5, 5, 5, 5, c); line(g, 2, 5, 5, 5, -5, c); line(g, 3, 5, -5, -5, -5, c); line(g, 4, -5, -5, -5, 5, c)
        elseif shape == "triangle" then
            line(g, 1, 0, 6, -6, -4, c); line(g, 2, -6, -4, 6, -4, c); line(g, 3, 6, -4, 0, 6, c)
        else
            g.fs:SetText(label); g.fs:SetFont(STANDARD_TEXT_FONT, #label > 2 and 8 or 11, "OUTLINE")
        end
        return
    end
    if set == "switch" then
        g.bg:SetVertexColor(0.3, 0.31, 0.35, 1)
    else
        local c = PAD_COL[key]
        if c then g.bg:SetVertexColor(c[1], c[2], c[3], 1) else g.bg:SetVertexColor(0.24, 0.25, 0.3, 1) end
    end
    g.fs:SetText(label)
    g.fs:SetFont(STANDARD_TEXT_FONT, #label > 2 and 8 or 12, "OUTLINE")
end

local function makeButton(parent)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(210, 36)
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints()
    b.edge = {}
    for i = 1, 4 do b.edge[i] = b:CreateTexture(nil, "BORDER") end
    b.edge[1]:SetPoint("TOPLEFT"); b.edge[1]:SetPoint("TOPRIGHT"); b.edge[1]:SetHeight(1)
    b.edge[2]:SetPoint("BOTTOMLEFT"); b.edge[2]:SetPoint("BOTTOMRIGHT"); b.edge[2]:SetHeight(1)
    b.edge[3]:SetPoint("TOPLEFT"); b.edge[3]:SetPoint("BOTTOMLEFT"); b.edge[3]:SetWidth(1)
    b.edge[4]:SetPoint("TOPRIGHT"); b.edge[4]:SetPoint("BOTTOMRIGHT"); b.edge[4]:SetWidth(1)
    b.hl = b:CreateTexture(nil, "HIGHLIGHT")
    b.hl:SetAllPoints()
    b.hl:SetColorTexture(1, 1, 1, 0.12)
    b.glyph = makeGlyph(b)
    b.glyph:SetPoint("LEFT", 8, 0)
    b.label = b:CreateFontString(nil, "OVERLAY")
    b.label:SetFont(STANDARD_TEXT_FONT, 14, "")
    b.label:SetPoint("LEFT", b.glyph, "RIGHT", 8, 0)
    b.label:SetPoint("RIGHT", -8, 0)
    b.label:SetJustifyH("LEFT")
    return b
end

local function goldString(copper)
    if GetCoinTextureString then
        local ok, s = pcall(GetCoinTextureString, copper)
        if ok and type(s) == "string" then return s end
    end
    return tostring(math.floor((copper or 0) / 10000)) .. "g"
end

local function closeSide()
    -- Which side of the window has more room for the tooltip.
    local cx = f and f:GetCenter() or 0
    local sw = UIParent:GetWidth() or 1920
    return (cx or 0) > sw / 2 and "ANCHOR_LEFT" or "ANCHOR_RIGHT"
end

local function showTip(btn)
    if not btn or not btn.item then return end
    GameTooltip:SetOwner(btn, closeSide())
    local it = btn.item
    if it.tip then it.tip(GameTooltip, it) else GameTooltip:SetText(it.name or "", 1, 1, 1) end
    GameTooltip:Show()
    if S.compare and it.compare then
        for _, fn in ipairs({ "GameTooltip_ShowCompareItem" }) do
            local g = _G[fn]
            if g then pcall(g, GameTooltip) end
        end
        if _G.TooltipComparisonManager and TooltipComparisonManager.CompareItem then pcall(TooltipComparisonManager.CompareItem, TooltipComparisonManager, GameTooltip) end
    end
end

local function applySelection()
    local th = theme()
    -- list rows
    for i, r in ipairs(rowPool) do
        if r:IsShown() then
            local idx = r.index
            r.sel:SetShown(idx == S.sel)
        end
    end
    -- reward choices
    for _, b in ipairs(itemPool) do
        if b:IsShown() and b.item and b.item.kind == "choice" then
            b.sel:SetShown(S.choice == b.item.idx)
        end
    end
end

local function selectChoice(i)
    S.choice = i
    applySelection()
    for _, b in ipairs(itemPool) do
        if b:IsShown() and b.item and b.item.kind == "choice" and b.item.idx == i then showTip(b) end
    end
end

----------------------------------------------------------------------
-- Building the window
----------------------------------------------------------------------
local applyThemeRef
for _, spec in ipairs({
    { "dlgWindow", "Window border", 2, "The theme's accent colour" },
    { "dlgButtons", "Button borders", 1, "The theme's accent colour" },
    { "dlgReward", "Reward icon borders", 2, "The item's quality colour" },
}) do
    API.registerBorder({ key = spec[1], part = "dialogue", label = spec[2], size = spec[3], maxSize = 6, auto = spec[4],
        legacy = function() return true, spec[3], 100, "auto" end,
        apply = function()
            if applyThemeRef then pcall(applyThemeRef) end
            if S and S.data and render then pcall(render, S.data, true) end
        end })
end

local function applyTheme()
    local th = theme()
    local d = DB()
    f:SetScale(math.max(0.5, (d.scale or 100) / 100))
    f.bg:SetColorTexture(color(th.bg))
    pcall(function()
        local lo, a = th.lo, th.vig or 0.5
        local clear = CreateColor(lo[1], lo[2], lo[3], 0)
        local solid = CreateColor(lo[1], lo[2], lo[3], a)
        f.vig[1]:SetColorTexture(1, 1, 1, 1); f.vig[1]:SetGradient("VERTICAL", clear, solid)
        f.vig[2]:SetColorTexture(1, 1, 1, 1); f.vig[2]:SetGradient("VERTICAL", solid, clear)
        f.vig[3]:SetColorTexture(1, 1, 1, 1); f.vig[3]:SetGradient("HORIZONTAL", solid, clear)
        f.vig[4]:SetColorTexture(1, 1, 1, 1); f.vig[4]:SetGradient("HORIZONTAL", clear, solid)
        local h = th.hi
        f.glow:SetColorTexture(1, 1, 1, 1)
        f.glow:SetGradient("VERTICAL", CreateColor(h[1], h[2], h[3], 0), CreateColor(h[1], h[2], h[3], 0.55))
    end)
    do
        -- Window border (Textures page, NPC Dialogue tab): class colour, your own, or the theme's accent.
        local on, sz, r, g, b, a, mode = API.borderOf("dlgWindow")
        if mode == "auto" then r, g, b = th.edge[1], th.edge[2], th.edge[3] end
        for i, e in ipairs(f.edge) do
            e:SetColorTexture(r, g, b, a); e:SetShown(on)
            if i <= 2 then e:SetHeight(sz) else e:SetWidth(sz) end
        end
    end
    f.npcFS:SetTextColor(color(th.sub))
    f.titleFS:SetFont(th.font, 20, "")
    f.titleFS:SetTextColor(color(th.title))
    f.bodyFS:SetFont(th.font, d.text or 14, "")
    f.bodyFS:SetTextColor(color(th.text))
    f.hint:SetTextColor(color(th.sub))
    f.lblChoose:SetTextColor(color(th.title))
    f.lblGet:SetTextColor(color(th.title))
    f.moneyFS:SetTextColor(color(th.text))
    for _, b in ipairs({ f.primary, f.secondary }) do
        b.bg:SetColorTexture(color(th.btn))
        local on, sz, r, g, bl, a, mode = API.borderOf("dlgButtons")
        if mode == "auto" then r, g, bl = th.btnEdge[1], th.btnEdge[2], th.btnEdge[3] end
        for i, e in ipairs(b.edge) do
            e:SetColorTexture(r, g, bl, a); e:SetShown(on)
            if i <= 2 then e:SetHeight(sz) else e:SetWidth(sz) end
        end
        b.label:SetTextColor(color(th.text))
    end
    for _, r in ipairs(rowPool) do
        r.hover:SetColorTexture(color(th.hover))
        r.sel:SetColorTexture(color(th.sel))
        r.text:SetFont(th.font, (d.text or 14) + 1, "")
        r.text:SetTextColor(color(th.text))
    end
    for _, b in ipairs(itemPool) do b.sel:SetColorTexture(color(th.sel)) end
end

local function getRow(i)
    local r = rowPool[i]
    if r then return r end
    r = CreateFrame("Button", nil, f)
    r:SetSize(W - 32, ROWH - 2)
    r.hover = r:CreateTexture(nil, "BACKGROUND")
    r.hover:SetAllPoints()
    r.hover:Hide()
    r.sel = r:CreateTexture(nil, "BACKGROUND", nil, 1)
    r.sel:SetAllPoints()
    r.sel:Hide()
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(22, 22)
    r.icon:SetPoint("LEFT", 8, 0)
    r.num = r:CreateFontString(nil, "OVERLAY")
    r.num:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE")
    r.num:SetPoint("RIGHT", -8, 0)
    r.text = r:CreateFontString(nil, "OVERLAY")
    r.text:SetPoint("LEFT", r.icon, "RIGHT", 8, 0)
    r.text:SetPoint("RIGHT", r.num, "LEFT", -8, 0)
    r.text:SetJustifyH("LEFT")
    r.text:SetWordWrap(false)
    r:SetScript("OnEnter", function(self) self.hover:Show(); S.sel = self.index; applySelection() end)
    r:SetScript("OnLeave", function(self) self.hover:Hide() end)
    r:SetScript("OnClick", function(self) if S.data and S.data.activate then S.data.activate(self.index) end end)
    r:EnableMouseWheel(true)
    r:SetScript("OnMouseWheel", function(_, delta)
        local n = S.data and S.data.rows and #S.data.rows or 0
        S.top = math.max(0, math.min(math.max(0, n - MAXROWS), (S.top or 0) - delta))
        render(S.data, true)
    end)
    rowPool[i] = r
    return r
end

local function getItem(i)
    local b = itemPool[i]
    if b then return b end
    b = CreateFrame("Button", nil, f)
    b:SetSize(44, 44)
    b.sel = b:CreateTexture(nil, "BACKGROUND")
    b.sel:SetPoint("TOPLEFT", -4, 4); b.sel:SetPoint("BOTTOMRIGHT", 4, -4)
    b.sel:Hide()
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.border = b:CreateTexture(nil, "OVERLAY")
    b.border:SetPoint("TOPLEFT", -2, 2); b.border:SetPoint("BOTTOMRIGHT", 2, -2)
    b.border:SetColorTexture(1, 1, 1, 1)
    b.border:SetDrawLayer("BORDER")
    b.count = b:CreateFontString(nil, "OVERLAY")
    b.count:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
    b.count:SetPoint("BOTTOMRIGHT", -2, 2)
    -- a small gold coin in the corner: this reward sells to a vendor for the most
    b.coin = b:CreateTexture(nil, "OVERLAY", nil, 3)
    b.coin:SetSize(16, 16)
    b.coin:SetPoint("TOPRIGHT", 5, 5)
    b.coin:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
    b.coin:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.coin:Hide()
    b.coinRing = b:CreateTexture(nil, "OVERLAY", nil, 2)
    b.coinRing:SetSize(19, 19)
    b.coinRing:SetPoint("CENTER", b.coin, "CENTER")
    b.coinRing:SetColorTexture(0, 0, 0, 0.9)
    b.coinRing:Hide()
    b:SetScript("OnEnter", function(self) showTip(self) end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:SetScript("OnClick", function(self)
        if self.item and self.item.kind == "choice" then selectChoice(self.item.idx) end
    end)
    itemPool[i] = b
    return b
end

local function build()
    if f then return f end
    f = CreateFrame("Frame", "UbermocDialogue", UIParent)
    f:SetSize(W, 400)
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(40)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:EnableKeyboard(true)
    pcall(f.SetPropagateKeyboardInput, f, true)   -- keys it does not use go on to the bindings
    f:SetMovable(true)
    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints()
    f.edge = {}
    for i = 1, 4 do f.edge[i] = f:CreateTexture(nil, "BORDER") end
    f.edge[1]:SetPoint("TOPLEFT"); f.edge[1]:SetPoint("TOPRIGHT"); f.edge[1]:SetHeight(2)
    f.edge[2]:SetPoint("BOTTOMLEFT"); f.edge[2]:SetPoint("BOTTOMRIGHT"); f.edge[2]:SetHeight(2)
    f.edge[3]:SetPoint("TOPLEFT"); f.edge[3]:SetPoint("BOTTOMLEFT"); f.edge[3]:SetWidth(2)
    f.edge[4]:SetPoint("TOPRIGHT"); f.edge[4]:SetPoint("BOTTOMRIGHT"); f.edge[4]:SetWidth(2)

    -- aged-paper look: darker edges fading inward
    f.vig = {}
    for i = 1, 4 do f.vig[i] = f:CreateTexture(nil, "BACKGROUND", nil, 1) end
    f.vig[1]:SetPoint("TOPLEFT", 2, -2); f.vig[1]:SetPoint("TOPRIGHT", -2, -2); f.vig[1]:SetHeight(34)
    f.vig[2]:SetPoint("BOTTOMLEFT", 2, 2); f.vig[2]:SetPoint("BOTTOMRIGHT", -2, 2); f.vig[2]:SetHeight(34)
    f.vig[3]:SetPoint("TOPLEFT", 2, -2); f.vig[3]:SetPoint("BOTTOMLEFT", 2, 2); f.vig[3]:SetWidth(34)
    f.vig[4]:SetPoint("TOPRIGHT", -2, -2); f.vig[4]:SetPoint("BOTTOMRIGHT", -2, 2); f.vig[4]:SetWidth(34)
    f.glow = f:CreateTexture(nil, "BACKGROUND", nil, 1)
    f.glow:SetPoint("TOPLEFT", 40, -40); f.glow:SetPoint("BOTTOMRIGHT", -40, 40)

    f.portrait = f:CreateTexture(nil, "ARTWORK")
    f.portrait:SetSize(46, 46)
    f.portrait:SetPoint("TOPLEFT", 16, -14)
    pcall(function()
        f.portraitMask = f:CreateMaskTexture()
        f.portraitMask:SetAllPoints(f.portrait)
        f.portraitMask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        f.portrait:AddMaskTexture(f.portraitMask)
    end)
    f.npcFS = f:CreateFontString(nil, "OVERLAY")
    f.npcFS:SetFont(STANDARD_TEXT_FONT, 12, "")
    f.npcFS:SetJustifyH("LEFT")
    f.titleFS = f:CreateFontString(nil, "OVERLAY")
    f.titleFS:SetFont(STANDARD_TEXT_FONT, 20, "")
    f.titleFS:SetJustifyH("LEFT")
    f.titleFS:SetWordWrap(true)

    f.sf = CreateFrame("ScrollFrame", nil, f)
    f.sc = CreateFrame("Frame", nil, f.sf)
    f.sc:SetSize(W - 32, 10)
    f.sf:SetScrollChild(f.sc)
    f.bodyFS = f.sc:CreateFontString(nil, "OVERLAY")
    f.bodyFS:SetFont(STANDARD_TEXT_FONT, 14, "")
    f.bodyFS:SetPoint("TOPLEFT", 0, 0)
    f.bodyFS:SetWidth(W - 40)
    f.bodyFS:SetJustifyH("LEFT")
    f.bodyFS:SetJustifyV("TOP")
    f.bodyFS:SetWordWrap(true)
    f.sf:EnableMouseWheel(true)
    f.sf:SetScript("OnMouseWheel", function(self, delta)
        local max = self:GetVerticalScrollRange() or 0
        self:SetVerticalScroll(math.max(0, math.min(max, (self:GetVerticalScroll() or 0) - delta * 40)))
    end)

    f.lblChoose = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.lblGet = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.moneyFS = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.moneyFS:SetJustifyH("LEFT")
    f.hint = f:CreateFontString(nil, "OVERLAY")
    f.hint:SetFont(STANDARD_TEXT_FONT, 11, "")
    f.hint:SetJustifyH("LEFT")
    f.hint:SetWidth(W - 32)

    f.primary = makeButton(f)
    f.secondary = makeButton(f)
    f.primary:SetScript("OnClick", function() if S.data and S.data.primaryFn then S.data.primaryFn() end end)
    f.secondary:SetScript("OnClick", function() if S.data and S.data.secondaryFn then S.data.secondaryFn() end end)

    -- the window moves with the unlock button on the NPC Dialogue page (or drag it by an empty part)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) if API.unlocked then self:StartMoving() end end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local cx, cy = self:GetCenter()
        local ux, uy = UIParent:GetCenter()
        if cx and ux then
            local s = self:GetEffectiveScale() / UIParent:GetEffectiveScale()
            DB().x, DB().y = math.floor(cx * s - ux + 0.5), math.floor(cy * s - uy + 0.5)
        end
    end)

    f:Hide()
    applyTheme()
    return f
end

local function place()
    local d = DB()
    f:ClearAllPoints()
    if d.anchor == "right" then f:SetPoint("RIGHT", UIParent, "RIGHT", -40 + (d.nx or 0), 20 + (d.ny or 0))
    elseif d.anchor == "left" then f:SetPoint("LEFT", UIParent, "LEFT", 40 + (d.nx or 0), 20 + (d.ny or 0))
    else f:SetPoint("CENTER", UIParent, "CENTER", (d.x or 0) + (d.nx or 0), (d.y or 20) + (d.ny or 0)) end
end

----------------------------------------------------------------------
-- Drawing one screen of dialogue
----------------------------------------------------------------------
render = function(data, keepScroll)
    if not data then return end
    build()
    if API.npcWire then API.npcWire() end
    local d = DB()
    S.data = data
    applyTheme()
    local th = theme()
    local left = 16
    local y = 14

    -- header: NPC portrait, name, then the quest or window title
    local hasPortrait = d.portrait ~= false and data.portrait
    f.portrait:SetShown(hasPortrait and true or false)
    if hasPortrait then
        pcall(SetPortraitTexture, f.portrait, "npc")
        left = 16 + 46 + 12
    end
    f.npcFS:ClearAllPoints()
    f.npcFS:SetPoint("TOPLEFT", left, -y)
    f.npcFS:SetText(data.npc or "")
    f.titleFS:ClearAllPoints()
    f.titleFS:SetPoint("TOPLEFT", left, -(y + 16))
    f.titleFS:SetWidth(W - left - 16)
    f.titleFS:SetText(data.title or "")
    local th2 = math.max(24, f.titleFS:GetStringHeight() or 24)
    y = y + 16 + th2 + 10
    if hasPortrait then y = math.max(y, 14 + 46 + 10) end

    -- body text
    f.bodyFS:SetText(data.text or "")
    local textH = (f.bodyFS:GetStringHeight() or 20) + 6
    local maxBody = data.maxBody or 220
    local bodyH = (data.text and data.text ~= "") and math.min(maxBody, math.max(24, textH)) or 0
    f.sf:ClearAllPoints()
    f.sf:SetPoint("TOPLEFT", 16, -y)
    f.sf:SetSize(W - 32, math.max(1, bodyH))
    f.sc:SetSize(W - 32, math.max(1, textH))
    f.sf:SetShown(bodyH > 0)
    if not keepScroll then f.sf:SetVerticalScroll(0) end
    y = y + bodyH + (bodyH > 0 and 10 or 0)

    -- list of options / quests
    local rows = data.rows or {}
    local n = math.min(#rows, MAXROWS)
    S.sel = math.max(1, math.min(S.sel or 1, math.max(1, #rows)))
    if #rows > 0 then
        if S.sel < (S.top or 0) + 1 then S.top = S.sel - 1 end
        if S.sel > (S.top or 0) + MAXROWS then S.top = S.sel - MAXROWS end
        S.top = math.max(0, math.min(math.max(0, #rows - MAXROWS), S.top or 0))
    else
        S.top = 0
    end
    for i = 1, math.max(#rowPool, n) do
        local r = getRow(i)
        local idx = (S.top or 0) + i
        local row = rows[idx]
        if i <= n and row then
            r.index = idx
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", 16, -(y + (i - 1) * ROWH))
            r.text:SetText(row.text or "")
            if row.icon then r.icon:SetTexture(row.icon); r.icon:SetShown(true) else r.icon:SetShown(false) end
            if row.grey then r.text:SetTextColor(0.55, 0.55, 0.55) else r.text:SetTextColor(color(th.text)) end
            r.num:SetText(idx <= 9 and tostring(idx) or "")
            r.num:SetTextColor(color(th.sub))
            r:Show()
        else
            r:Hide()
        end
    end
    if n > 0 then y = y + n * ROWH + 8 end

    -- rewards
    local choices, gets, req = data.choices or {}, data.rewards or {}, data.required or {}
    for _, b in ipairs(itemPool) do b:Hide() end
    local used = 0
    local function placeItems(list, lbl, title)
        if #list == 0 then lbl:Hide(); return end
        lbl:ClearAllPoints()
        lbl:SetPoint("TOPLEFT", 16, -y)
        lbl:SetText(title)
        lbl:Show()
        y = y + 20
        local perRow = 9
        for i, it in ipairs(list) do
            used = used + 1
            local b = getItem(used)
            local col, rw = (i - 1) % perRow, math.floor((i - 1) / perRow)
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", 20 + col * 56, -(y + rw * 54 + 4))
            b.item = it
            b.icon:SetTexture(it.tex)
            local qr, qg, qb = 0.5, 0.5, 0.5
            if it.quality and GetItemQualityColor then
                local okc, r, g, bl = pcall(GetItemQualityColor, it.quality)
                if okc and r then qr, qg, qb = r, g, bl end
            end
            do
                -- Reward border (Textures page): the item's quality colour, class colour or your own.
                local on, sz, r, g, bl, a, mode = API.borderOf("dlgReward")
                if mode == "auto" then r, g, bl = qr, qg, qb end
                b.border:ClearAllPoints()
                b.border:SetPoint("TOPLEFT", -sz, sz); b.border:SetPoint("BOTTOMRIGHT", sz, -sz)
                b.border:SetColorTexture(r, g, bl, a)
                b.border:SetShown(on)
            end
            b.count:SetText((it.count and it.count > 1) and it.count or "")
            local best = it.best and d.markBest ~= false
            b.coin:SetShown(best and true or false)
            b.coinRing:SetShown(best and true or false)
            b.sel:SetColorTexture(color(th.sel))
            b.sel:SetShown(it.kind == "choice" and S.choice == it.idx)
            b:Show()
        end
        y = y + math.ceil(#list / perRow) * 54 + 8
    end
    f.lblChoose:Hide(); f.lblGet:Hide()
    if #req > 0 then placeItems(req, f.lblGet, "Needed") end
    if #choices > 0 then placeItems(choices, f.lblChoose, #choices > 1 and "Choose one reward" or "Reward") end
    if #gets > 0 then placeItems(gets, f.lblGet, "You will also receive") end
    local extras = {}
    if data.money and data.money > 0 then extras[#extras + 1] = goldString(data.money) end
    if data.xp and data.xp > 0 then
        -- with the share of the current level it fills, e.g. "380 XP (12.5%)"
        local t = data.xp .. " XP"
        local ok, mx = pcall(UnitXPMax, "player")
        if ok and type(mx) == "number" and mx > 0 then
            local p = data.xp / mx * 100
            t = t .. string.format(p < 10 and " (%.1f%%)" or " (%d%%)", p < 10 and p or math.floor(p + 0.5))
        end
        extras[#extras + 1] = t
    end
    for _, c in ipairs(data.currencies or {}) do extras[#extras + 1] = c end
    if #extras > 0 then
        f.moneyFS:ClearAllPoints()
        f.moneyFS:SetPoint("TOPLEFT", 16, -y)
        f.moneyFS:SetText(table.concat(extras, "     "))
        f.moneyFS:Show()
        y = y + 24
    else
        f.moneyFS:Hide()
    end

    -- buttons
    y = y + 4
    local function setBtn(b, label, key, fallback, fn, enabled)
        if not label then b:Hide(); return end
        b:Show()
        b.label:SetText(label)
        setGlyph(b.glyph, key, fallback)
        b:SetAlpha(enabled == false and 0.45 or 1)
    end
    f.primary:ClearAllPoints(); f.primary:SetPoint("TOPLEFT", 16, -y)
    f.secondary:ClearAllPoints(); f.secondary:SetPoint("TOPRIGHT", -16, -y)
    setBtn(f.primary, data.primary, "PAD1", "Space", nil, data.primaryOn)
    setBtn(f.secondary, data.secondary, "PAD2", "Esc")
    y = y + 44

    -- No line of button explanations under the buttons: the icons on them say it.
    f.hint:SetText("")
    f.hint:Hide()

    f:SetHeight(y + 4)
    place()
    f:Show()
    applySelection()
end

----------------------------------------------------------------------
-- What the game is showing right now
----------------------------------------------------------------------
local function N(fn)
    local ok, v = pcall(function() return fn and fn() end)
    return (ok and type(v) == "number") and v or 0
end

local function npcName() return UnitName("npc") or UnitName("target") or "" end

local function itemEntry(kind, i)
    local name, tex, count, quality = GetQuestItemInfo(kind, i)
    if not name then return nil end
    local link = GetQuestItemLink and GetQuestItemLink(kind, i)
    local price
    if link and GetItemInfo then
        local ok, p = pcall(function() return select(11, GetItemInfo(link)) end)
        if ok and type(p) == "number" then price = p * (count or 1) end
    end
    return { kind = kind, idx = i, name = name, tex = tex, count = count, quality = quality, price = price,
             compare = (kind == "choice"),
             tip = function(tt, it) tt:SetQuestItem(kind, i) end }
end

local function markBest(list)
    local best, tie = 0, 0
    for _, it in ipairs(list) do if it.price and it.price > best then best = it.price end end
    if best <= 0 or #list < 2 then return end
    for _, it in ipairs(list) do if it.price == best then it.best = true end end
end

API.npcMode = function() return S.mode end

local function close()
    S.closing = true
    if f then f:Hide() end
    S.closing = false
    S.mode = nil
    GameTooltip:Hide()
end

local function trace(...)
    if DB().trace then print("|cff66ccffNPC|r", string.format("%.2f", GetTime()), ...) end
end

local function closeGame()
    local m = S.mode
    trace("closeGame", tostring(m))
    if m == "gossip" then
        if C_GossipInfo and C_GossipInfo.CloseGossip then pcall(C_GossipInfo.CloseGossip) end
    elseif m == "preview" then
        -- nothing to close
    else
        -- The game's own Decline button only hides its window, and hiding it calls CloseQuest: the same here.
        if CloseQuest then pcall(CloseQuest) end
    end
    if m ~= "preview" then S.dismissedAt = GetTime() end
    close()
end

local function dataGossip()
    local rows, ids = {}, {}
    local d = { mode = "gossip", npc = npcName(), portrait = true }
    local title = npcName()
    d.title = title ~= "" and title or "Gossip"
    d.npc = ""
    d.text = (C_GossipInfo and C_GossipInfo.GetText and C_GossipInfo.GetText()) or ""
    local function add(row) rows[#rows + 1] = row end
    -- quests first, then options
    for _, q in ipairs((C_GossipInfo and C_GossipInfo.GetActiveQuests and C_GossipInfo.GetActiveQuests()) or {}) do
        add({ text = q.title, icon = q.isComplete and "Interface\\GossipFrame\\ActiveQuestIcon" or "Interface\\GossipFrame\\IncompleteQuestIcon",
              grey = not q.isComplete, kind = "active", id = q.questID })
    end
    for _, q in ipairs((C_GossipInfo and C_GossipInfo.GetAvailableQuests and C_GossipInfo.GetAvailableQuests()) or {}) do
        add({ text = q.title, icon = "Interface\\GossipFrame\\AvailableQuestIcon", grey = q.isTrivial, kind = "available", id = q.questID })
    end
    for _, o in ipairs((C_GossipInfo and C_GossipInfo.GetOptions and C_GossipInfo.GetOptions()) or {}) do
        local ic = (type(o.overrideIconID) == "number" and o.overrideIconID) or (type(o.icon) == "number" and o.icon) or "Interface\\GossipFrame\\GossipGossipIcon"
        local unavailable = Enum and Enum.GossipOptionStatus and o.status == Enum.GossipOptionStatus.Unavailable
        add({ text = o.name, icon = ic, grey = unavailable and true or false, kind = "option", id = o.gossipOptionID })
    end
    d.rows = rows
    d.maxBody = 150
    d.activate = function(i)
        local row = rows[i]
        if not row then return end
        if row.kind == "option" then C_GossipInfo.SelectOption(row.id)
        elseif row.kind == "available" then C_GossipInfo.SelectAvailableQuest(row.id)
        else C_GossipInfo.SelectActiveQuest(row.id) end
    end
    d.primary, d.secondary = "Choose", "Goodbye"
    d.primaryOn = #rows > 0
    d.primaryFn = function() if #rows > 0 then d.activate(S.sel) else closeGame() end end
    d.secondaryFn = closeGame
    return d
end

local function dataGreeting()
    local rows = {}
    local d = { mode = "greeting", npc = "", portrait = true }
    d.title = npcName()
    d.text = (GetGreetingText and GetGreetingText()) or ""
    for i = 1, N(GetNumActiveQuests) do
        local title, complete = GetActiveTitle(i)
        local isComplete = complete
        if IsActiveQuestTrivial then end
        rows[#rows + 1] = { text = title, icon = "Interface\\GossipFrame\\ActiveQuestIcon", kind = "active", id = i }
    end
    for i = 1, N(GetNumAvailableQuests) do
        rows[#rows + 1] = { text = GetAvailableTitle(i), icon = "Interface\\GossipFrame\\AvailableQuestIcon", kind = "available", id = i }
    end
    d.rows = rows
    d.maxBody = 150
    d.activate = function(i)
        local row = rows[i]
        if not row then return end
        if row.kind == "available" then SelectAvailableQuest(row.id) else SelectActiveQuest(row.id) end
    end
    d.primary, d.secondary = "Choose", "Goodbye"
    d.primaryOn = #rows > 0
    d.primaryFn = function() if #rows > 0 then d.activate(S.sel) else closeGame() end end
    d.secondaryFn = closeGame
    return d
end

local function rewardLists(d)
    d.choices, d.rewards = {}, {}
    for i = 1, N(GetNumQuestChoices) do
        local it = itemEntry("choice", i)
        if it then d.choices[#d.choices + 1] = it end
    end
    markBest(d.choices)
    for i = 1, N(GetNumQuestRewards) do
        local it = itemEntry("reward", i)
        if it then d.rewards[#d.rewards + 1] = it end
    end
    d.money = GetRewardMoney and GetRewardMoney() or 0
    d.xp = GetRewardXP and GetRewardXP() or 0
    d.currencies = {}
    for i = 1, N(GetNumRewardCurrencies) do
        local ok, name, _, amount = pcall(GetQuestCurrencyInfo, "reward", i)
        if ok and name then d.currencies[#d.currencies + 1] = (amount or 1) .. " " .. name end
    end
end

local function dataDetail()
    local d = { mode = "detail", npc = npcName(), portrait = true }
    d.title = GetTitle and GetTitle() or "Quest"
    local text = (GetQuestText and GetQuestText()) or ""
    local obj = (GetObjectiveText and GetObjectiveText()) or ""
    if obj ~= "" then text = text .. "\n\n" .. obj end
    d.text = text
    rewardLists(d)
    local auto = QuestGetAutoAccept and QuestGetAutoAccept()
    if auto then
        d.primary, d.secondary = "Okay", nil
        d.primaryFn = function() if AcknowledgeAutoAcceptQuest then AcknowledgeAutoAcceptQuest() end; closeGame() end
    else
        d.primary, d.secondary = "Accept", "Decline"
        d.primaryFn = function() AcceptQuest() end
        d.secondaryFn = function() closeGame() end
    end
    d.maxBody = 260
    return d
end

local function dataProgress()
    local d = { mode = "progress", npc = npcName(), portrait = true }
    d.title = GetTitle and GetTitle() or "Quest"
    d.text = (GetProgressText and GetProgressText()) or ""
    d.required = {}
    for i = 1, N(GetNumQuestItems) do
        local it = itemEntry("required", i)
        if it then d.required[#d.required + 1] = it end
    end
    d.money = (GetQuestMoneyToGet and GetQuestMoneyToGet()) or 0
    local ok = IsQuestCompletable and IsQuestCompletable()
    d.primary, d.secondary = "Continue", "Goodbye"
    d.primaryOn = ok and true or false
    d.primaryFn = function() if IsQuestCompletable and IsQuestCompletable() then CompleteQuest() end end
    d.secondaryFn = closeGame
    d.maxBody = 220
    return d
end

local function dataComplete()
    local d = { mode = "complete", npc = npcName(), portrait = true }
    d.title = GetTitle and GetTitle() or "Quest"
    d.text = (GetRewardText and GetRewardText()) or ""
    rewardLists(d)
    d.primary, d.secondary = "Complete", "Not now"
    d.primaryFn = function()
        local n = #d.choices
        if n > 1 and not S.choice then selectChoice(1); return end
        GetQuestReward(n > 1 and S.choice or 1)
    end
    d.secondaryFn = closeGame
    d.maxBody = 200
    return d
end

----------------------------------------------------------------------
-- Preview (Settings > NPC Dialogue): a made-up reward screen, so the look can be set without an NPC
----------------------------------------------------------------------
local function dataPreview()
    local d = { mode = "preview", npc = "Preview", portrait = false }
    d.title = "A Fine Reward"
    d.text = "You have done well. Take your pick of these: the armourer sets aside the best for those who finish the job."
    d.choices = {
        { kind = "choice", idx = 1, name = "Worn Sword", tex = "Interface\\Icons\\INV_Sword_04", quality = 2, price = 1200, compare = true, tip = function(tt) tt:SetText("Worn Sword", 0.1, 1, 0.1); tt:AddLine("Preview only", 1, 1, 1) end },
        { kind = "choice", idx = 2, name = "Silver Ring", tex = "Interface\\Icons\\INV_Jewelry_Ring_03", quality = 3, price = 5200, best = true, compare = true, tip = function(tt) tt:SetText("Silver Ring", 0, 0.5, 1); tt:AddLine("Sells for the most", 1, 0.82, 0) end },
        { kind = "choice", idx = 3, name = "Scout's Boots", tex = "Interface\\Icons\\INV_Boots_Cloth_05", quality = 2, price = 800, compare = true, tip = function(tt) tt:SetText("Scout's Boots", 0.1, 1, 0.1) end },
    }
    d.rewards = {}
    d.money = 5400
    d.xp = 380
    d.primary, d.secondary = "Complete", "Not now"
    d.primaryFn = function()
        if not S.choice then selectChoice(1); return end
        close()
    end
    d.secondaryFn = close
    d.maxBody = 200
    return d
end

----------------------------------------------------------------------
-- Showing
----------------------------------------------------------------------
local function show(mode, builder)
    if not DB().on then return end
    S.token = S.token + 1
    if S.mode ~= mode then S.sel, S.top, S.choice, S.compare = 1, 0, nil, false end
    S.mode = mode
    local ok, data = pcall(builder)
    if not ok or not data then if DB().debug then print("NPC dialogue:", data) end return end
    local ok2, err2 = pcall(render, data)
    if not ok2 then if DB().debug then print("NPC dialogue:", err2) end return end
    -- the sell price of a reward can arrive a moment after the window: draw again once it is known
    if mode == "complete" or mode == "detail" then
        C_Timer.After(0.4, function() if S.mode == mode and f and f:IsShown() then pcall(function() render(({ complete = dataComplete, detail = dataDetail })[mode](), true) end) end end)
    end
end

function API.npcPreview()
    S.mode = nil
    show("preview", dataPreview)
end

----------------------------------------------------------------------
-- Keys and controller buttons
----------------------------------------------------------------------
local function move(dx, dy)
    local data = S.data
    if not data then return end
    if data.rows and #data.rows > 0 and dy ~= 0 then
        S.sel = math.max(1, math.min(#data.rows, (S.sel or 1) + dy))
        render(data, true)
        return
    end
    if data.choices and #data.choices > 1 and dx ~= 0 then
        local c = (S.choice or (dx > 0 and 0 or #data.choices + 1)) + dx
        c = math.max(1, math.min(#data.choices, c))
        selectChoice(c)
        return
    end
    if dy ~= 0 and f and f.sf and f.sf:IsShown() then
        local max = f.sf:GetVerticalScrollRange() or 0
        f.sf:SetVerticalScroll(math.max(0, math.min(max, (f.sf:GetVerticalScroll() or 0) + dy * 40)))
    end
end

local function toggleCompare()
    local data = S.data
    if not (data and data.choices and #data.choices > 0) then return end
    S.compare = not S.compare
    if not S.choice then S.choice = 1; applySelection() end
    for _, b in ipairs(itemPool) do
        if b:IsShown() and b.item and b.item.kind == "choice" and b.item.idx == S.choice then showTip(b) end
    end
end

local KEYS = {
    UP = function() move(0, -1) end, DOWN = function() move(0, 1) end, LEFT = function() move(-1, 0) end, RIGHT = function() move(1, 0) end,
    PADDUP = function() move(0, -1) end, PADDDOWN = function() move(0, 1) end, PADDLEFT = function() move(-1, 0) end, PADDRIGHT = function() move(1, 0) end,
    W = function() move(0, -1) end, S = function() move(0, 1) end, A = function() move(-1, 0) end, D = function() move(1, 0) end,
    ENTER = function() if S.data and S.data.primaryFn and S.data.primaryOn ~= false then S.data.primaryFn() end end,
    SPACE = function() if S.data and S.data.primaryFn and S.data.primaryOn ~= false then S.data.primaryFn() end end,
    PAD1 = function() if S.data and S.data.primaryFn and S.data.primaryOn ~= false then S.data.primaryFn() end end,
    ESCAPE = function() if S.data and S.data.secondaryFn then S.data.secondaryFn() else closeGame() end end,
    PAD2 = function() if S.data and S.data.secondaryFn then S.data.secondaryFn() else closeGame() end end,
    C = toggleCompare, PAD4 = toggleCompare,
    PAGEUP = function() move(0, -3) end, PAGEDOWN = function() move(0, 3) end,
}
for i = 1, 9 do
    KEYS[tostring(i)] = function()
        local data = S.data
        if data and data.rows and data.rows[i] and data.activate then S.sel = i; data.activate(i) end
    end
end

-- A question window of the game (the experimental camera question, bind-on-pickup, ready check...) always
-- comes first: while one is up this window hands every key and button on, so the pointer (and the game's own
-- window) get them, and nothing is accepted or declined here by accident.
local POPUP_NAMES = { "StaticPopup1", "StaticPopup2", "StaticPopup3", "StaticPopup4", "ReadyCheckFrame", "LFGDungeonReadyPopup",
                      "PVPReadyDialog", "LFDRoleCheckPopup", "RolePollPopup", "LFGInvitePopup", "UbermocBagPicker" }
local function popupUp()
    for _, n in ipairs(POPUP_NAMES) do
        local p = _G[n]
        if p and p.IsShown and p:IsShown() then return true end
    end
    return false
end

local function onKey(self, key)
    if popupUp() then
        pcall(self.SetPropagateKeyboardInput, self, true)
        return
    end
    local fn = f and f:IsShown() and KEYS[key]
    -- A, S, D and W only steer while there is something to steer (they are movement keys otherwise)
    if fn and (key == "W" or key == "S" or key == "A" or key == "D") then
        local data = S.data
        if not (data and ((data.rows and #data.rows > 0) or (data.choices and #data.choices > 1))) then fn = nil end
    end
    if fn and (key == "C") then
        local data = S.data
        if not (data and data.choices and #data.choices > 0) then fn = nil end
    end
    if fn then
        pcall(self.SetPropagateKeyboardInput, self, false)
        pcall(fn)
    else
        pcall(self.SetPropagateKeyboardInput, self, true)
    end
end

----------------------------------------------------------------------
-- Keeping the game's own windows out of sight
----------------------------------------------------------------------
local hider
local function takeOver(on)
    hider = hider or CreateFrame("Frame")
    if not hider.ubHidden then hider.ubHidden = true; hider:Hide() end
    for _, n in ipairs({ "QuestFrame", "GossipFrame" }) do
        local fr = _G[n]
        if fr and fr.SetParent then pcall(fr.SetParent, fr, on and hider or UIParent) end
    end
    -- Inside the hidden frame the game's quest panels never run their on-show setup, so when a reward item
    -- finishes loading its own update code fails. Our window does that update itself, so the game's window
    -- stops listening for it while ours is in use.
    local qf = _G.QuestFrame
    if qf and qf.UnregisterEvent then
        hider.qfEvents = hider.qfEvents or {}
        for _, e in ipairs({ "QUEST_ITEM_UPDATE", "LEARNED_SPELL_IN_TAB", "LEARNED_SPELL_IN_SKILL_LINE" }) do
            if on then
                local ok, had = pcall(qf.IsEventRegistered, qf, e)
                if ok and had then hider.qfEvents[e] = true; pcall(qf.UnregisterEvent, qf, e) end
            elseif hider.qfEvents[e] then
                hider.qfEvents[e] = nil
                pcall(qf.RegisterEvent, qf, e)
            end
        end
    end
end
applyThemeRef = function() if f then applyTheme() end end
API.npcTakeOver = function() takeOver(DB().on) end

-- Keys, controller buttons and closing, hooked up once the window exists.
local wired = false
function API.npcWire()
    if not f or wired then return end
    wired = true
    f:SetScript("OnKeyDown", onKey)
    f:EnableGamePadButton(true)
    f:SetScript("OnGamePadButtonDown", onKey)
    f:SetScript("OnHide", function() if not S.closing then S.mode = nil; GameTooltip:Hide() end end)
    -- Sit underneath a game question window so it is never covered by this one.
    local acc, lowered = 0, false
    f:HookScript("OnUpdate", function(self, dt)
        acc = acc + dt
        if acc < 0.15 then return end
        acc = 0
        local up = popupUp()
        if up ~= lowered then
            lowered = up
            pcall(self.SetFrameStrata, self, up and "MEDIUM" or "DIALOG")
        end
    end)
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "GOSSIP_SHOW", "GOSSIP_CLOSED", "QUEST_GREETING", "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE", "QUEST_FINISHED",
                     "QUEST_ITEM_UPDATE", "GET_ITEM_INFO_RECEIVED", "PLAYER_LOGIN" }) do
    pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        DB()
        takeOver(DB().on)   -- the window itself is made the first time an NPC talks to you
        return
    end
    if not DB().on then return end
    trace(event, "mode=" .. tostring(S.mode), "npc=" .. tostring(UnitName("npc")))
    -- Right after Goodbye / Decline / Escape the same NPC cannot open again by itself (a repeated key press, or
    -- the game sending the list again): the game's side is closed once more and nothing is shown.
    if S.dismissedAt and GetTime() - S.dismissedAt < 0.4
        and (event == "GOSSIP_SHOW" or event == "QUEST_GREETING" or event == "QUEST_DETAIL" or event == "QUEST_PROGRESS" or event == "QUEST_COMPLETE") then
        trace("ignored (just closed)")
        if event == "GOSSIP_SHOW" then
            if C_GossipInfo and C_GossipInfo.CloseGossip then pcall(C_GossipInfo.CloseGossip) end
        elseif CloseQuest then
            pcall(CloseQuest)
        end
        return
    end
    if event == "GOSSIP_SHOW" then
        -- Like the game's own window: an NPC whose only choice is an action (a vendor, say) goes straight to it
        -- with no window, so ours does not flash up and vanish when the shop opens.
        local okA, skip = pcall(function()
            local G = C_GossipInfo
            if G.GetNumAvailableQuests() ~= 0 or G.GetNumActiveQuests() ~= 0 then return false end
            local opts = G.GetOptions()
            if #opts ~= 1 or (G.ForceGossip and G.ForceGossip()) or not opts[1].selectOptionWhenOnlyOption then return false end
            G.SelectOptionByIndex(opts[1].orderIndex)
            return true
        end)
        if okA and skip then return end
        show("gossip", dataGossip)
    elseif event == "QUEST_GREETING" then show("greeting", dataGreeting)
    elseif event == "QUEST_DETAIL" then show("detail", dataDetail)
    elseif event == "QUEST_PROGRESS" then show("progress", dataProgress)
    elseif event == "QUEST_COMPLETE" then show("complete", dataComplete)
    elseif event == "QUEST_FINISHED" then
        if S.mode ~= "preview" then close() end
    elseif event == "GOSSIP_CLOSED" then
        -- choosing a quest in a gossip list sends GOSSIP_CLOSED first and the quest right after: wait a moment
        local token = S.token
        if S.mode == "gossip" then
            C_Timer.After(0.25, function() if S.token == token and S.mode == "gossip" then close() end end)
        end
    elseif event == "QUEST_ITEM_UPDATE" or event == "GET_ITEM_INFO_RECEIVED" then
        if f and f:IsShown() and S.mode and S.mode ~= "preview" then
            local m = S.mode
            local fn = ({ complete = dataComplete, detail = dataDetail, progress = dataProgress })[m]
            if fn then pcall(function() render(fn(), true) end) end
        end
    end
end)

----------------------------------------------------------------------
-- Settings page
----------------------------------------------------------------------
local function buildPage()
    local panel = CreateFrame("Frame")
    panel.name = "NPC Dialogue"
    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 0, 0)
    scroll:SetPoint("BOTTOMRIGHT", -26, 8)
    local p = CreateFrame("Frame", nil, scroll)
    p:SetSize(640, 640)
    scroll:SetScrollChild(p)
    API.newLabel(p, "NPC Dialogue", 16, -14, "GameFontNormalHuge")
    local intro = API.newLabel(p, "One clean window for talking to NPCs: gossip, quests, quest hand-ins and rewards. Space or Enter accepts, Escape declines, arrow keys (or the D-pad) choose, and the buttons show your controller's own names. When a quest offers a choice of rewards, pick one with left / right, press the compare button to see what you wear, and the reward that sells to a vendor for the most carries a small gold coin.", 16, -48, "GameFontHighlightSmall")
    intro:SetWidth(580); intro:SetJustifyH("LEFT"); intro:SetWordWrap(true)
    local onCB = API.newCheck(p, "Use this window instead of the game's quest and gossip windows", 16, -150, function(v)
        DB().on = v
        takeOver(v)
        if not v then close() end
    end)
    API.newLabel(p, "Theme", 40, -196)
    local themeBtn = API.segRow(p, 200, -192, { { "dark", "Dark parchment", 130 }, { "light", "Light parchment", 130 } },
        function() return DB().theme == "light" and "light" or "dark" end, function(v)
            DB().theme = v
            if f then applyTheme(); if S.data then render(S.data, true) end end
        end)

    -- colour choices: swatches (D-pad friendly) plus the game's colour picker
    local function refreshLook() if f then applyTheme(); if S.data then render(S.data, true) end end end
    local function swatchRow(y, list, onPick, getC)
        local btns = {}
        for i, c in ipairs(list) do
            local b = CreateFrame("Button", nil, p)
            b:SetSize(24, 24)
            b:SetPoint("TOPLEFT", 232 + (i - 1) * 28, y)
            b.t = b:CreateTexture(nil, "ARTWORK"); b.t:SetAllPoints(); b.t:SetColorTexture(getC(c))
            b.o = b:CreateTexture(nil, "BACKGROUND"); b.o:SetPoint("TOPLEFT", -1, 1); b.o:SetPoint("BOTTOMRIGHT", 1, -1); b.o:SetColorTexture(0, 0, 0, 1)
            b:SetScript("OnClick", function() onPick(c) end)
            btns[i] = b
        end
        return btns
    end
    local function openPicker(cur, apply)
        local r, g, b = cur[1], cur[2], cur[3]
        local function changed()
            local nr, ng, nb = ColorPickerFrame:GetColorRGB()
            apply({ nr, ng, nb })
        end
        local function cancelled() apply({ r, g, b }) end
        local ok = pcall(function()
            ColorPickerFrame:SetupColorPickerAndShow({ r = r, g = g, b = b, hasOpacity = false, swatchFunc = changed, cancelFunc = cancelled })
        end)
        if not ok then
            pcall(function()
                ColorPickerFrame.func = changed; ColorPickerFrame.cancelFunc = cancelled
                ColorPickerFrame:SetColorRGB(r, g, b); ColorPickerFrame.hasOpacity = false
                ColorPickerFrame:Hide(); ColorPickerFrame:Show()
            end)
        end
    end
    API.newLabel(p, "Accent colour", 40, -236)
    local accentBtn = API.newButton(p, "Class colour", 120, 232, -232, function() DB().accent = nil; refreshLook() end)
    swatchRow(-266, ACCENTS, function(c) DB().accent = { c[1], c[2], c[3] }; refreshLook() end, function(c) return c[1], c[2], c[3], 1 end)
    API.newButton(p, "Pick any colour", 130, 232 + 10 * 28 + 8 - 8, -232, function()
        local cur = DB().accent or classColor()
        openPicker(cur, function(c) DB().accent = c; refreshLook() end)
    end)
    API.newLabel(p, "Paper colour", 40, -306)
    API.newButton(p, "Classic", 120, 232, -302, function() DB().paper = nil; refreshLook() end)
    swatchRow(-336, PAPERS, function(c) DB().paper = { c[2], c[3], c[4] }; refreshLook() end, function(c) return c[2], c[3], c[4], 1 end)
    API.newButton(p, "Pick any colour", 130, 232 + 10 * 28 + 8 - 8, -302, function()
        local cur = DB().paper or { PAPERS[1][2], PAPERS[1][3], PAPERS[1][4] }
        openPicker(cur, function(c) DB().paper = c; refreshLook() end)
    end)
    local function slider(label, y, min, max, step, fmt, key)
        API.newLabel(p, label, 40, y - 4)
        local s = API.makeSlider(p, 150, min, max, step, fmt, function(v)
            DB()[key] = v
            if f then applyTheme(); if S.data then render(S.data, true) end end
        end)
        s:SetPoint("TOPLEFT", 232, y)
        return s
    end
    local pct = function(v) return math.floor(v + 0.5) .. "%" end
    local px = function(v) return math.floor(v + 0.5) .. " px" end
    local sScale = slider("Window size", -376, 60, 160, 5, pct, "scale")
    local sText = slider("Text size", -416, 10, 22, 1, px, "text")
    local bestCB = API.newCheck(p, "Mark the reward that sells for the most with a small gold coin", 16, -464, function(v)
        DB().markBest = v
        if f and S.data then render(S.data, true) end
    end)
    local portCB = API.newCheck(p, "Show the NPC's picture", 16, -496, function(v)
        DB().portrait = v
        if f and S.data then render(S.data, true) end
    end)
    API.newButton(p, "Show a preview", 190, 16, -540, function() if API.npcPreview then API.npcPreview() end end)
    API.newLockButton(p, 220, -540)
    local note = API.newLabel(p, "The preview is a made-up reward screen so you can set the theme and size without an NPC. Unlock to drag the window where you want it; it keeps that place.", 16, -584, "GameFontHighlightSmall")
    note:SetWidth(580); note:SetJustifyH("LEFT"); note:SetWordWrap(true)
    -- Window place: right edge (default), centre or left edge, then nudged.
    local function moved() if f then place() end end
    API.newLabel(p, "Window place", 40, -630)
    local placeRow = API.segRow(p, 200, -626, { { "left", "Left", 70 }, { "center", "Centre", 80 }, { "right", "Right", 70 } },
        function() return DB().anchor end, function(v)
            local d = DB(); d.anchor = v; d.nx, d.ny = 0, 0
            if v == "center" then d.x, d.y = 0, 20 end
            moved()
            if API.npcPreview and not (f and f:IsShown()) then API.npcPreview() end
        end)
    API.newLabel(p, "Nudge", 40, -668)
    local nudge = API.nudgePad(p, 200, -664, function() local d = DB(); return d.nx or 0, d.ny or 0 end,
        function(nx, ny) local d = DB(); d.nx, d.ny = nx, ny; moved() end)
    -- Second tab: which button names the dialogue shows (the options live in Controller.lua).
    local promptCBs = {}
    if API.padOption then
        API.newLabel(p, "Button prompts", 8, -728, "GameFontNormalLarge")
        local cb, ny = API.padOption("hints", p, 16, -764)
        promptCBs[#promptCBs + 1] = cb
        cb = API.padOption("dui", p, 16, ny - 4)
        promptCBs[#promptCBs + 1] = cb
    end
    -- Third tab: the cinematic camera (Cinematic.lua).
    local cineRefresh
    if API.cineSettings then
        local bottom
        bottom, cineRefresh = API.cineSettings(p, -900)
        p:SetHeight(-bottom + 20)
        API.makeTabs(panel, scroll, p, { { "Window", 0 }, { "Button prompts", -720 }, { "Cinematic camera", -890 } })
    end
    panel:SetScript("OnShow", function()
        if cineRefresh then cineRefresh() end
        for _, cb in ipairs(promptCBs) do cb:refreshOption() end
        placeRow.refresh(); if nudge.refresh then nudge.refresh() end
        local d = DB()
        onCB:SetChecked(d.on); themeBtn.refresh()
        API.setSlider(sScale, d.scale); API.setSlider(sText, d.text)
        bestCB:SetChecked(d.markBest ~= false); portCB:SetChecked(d.portrait ~= false)
    end)
    API.resetters = API.resetters or {}
    API.resetters.npc = function() UbermocUIDB.npc = nil; DB(); takeOver(true); if f then applyTheme() end end
    API.addPage("npc", "NPC Dialogue", panel)
    if API.registerMover then
        API.registerMover("NPC dialogue window", function()
            local d = DB()
            local x, y = d.x or 0, d.y or 20
            if f and f:GetCenter() then   -- where it really is (right / left placement too)
                local cx, cy = f:GetCenter()
                local s = f:GetEffectiveScale() / UIParent:GetEffectiveScale()
                x, y = cx * s - UIParent:GetWidth() / 2, cy * s - UIParent:GetHeight() / 2
            end
            return d.on, x, y, W * (d.scale or 100) / 100, 220
        end, function(x, y)
            local d = DB()
            d.x, d.y, d.anchor, d.nx, d.ny = x, y, "center", 0, 0   -- dragged: measured from the centre
            if f then place() end
        end)
    end
end

local prev = API.onLogin
API.onLogin = function()
    if prev then prev() end
    DB()
    API.later("NPC dialogue", buildPage)
end
