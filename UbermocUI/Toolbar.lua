-- Ubermoc UI - Copyright (c) 2026 Marcos. All rights reserved.
-- This file is protected by copyright. It may not be copied, modified, redistributed or reused, in whole or
-- in part, without the written permission of the author. See LICENSE.txt.
----------------------------------------------------------------------
-- Ubermoc UI: menu bar
-- The game's micro menu buttons and bag buttons gathered on one panel that slides in when the mouse
-- reaches a spot on the edge of the screen (top middle by default) and hides itself again a moment
-- after the mouse leaves. It can also be opened with a key or controller button.
----------------------------------------------------------------------
local API = UbermocUIAPI
if not API then return end

BINDING_NAME_UBERMOCUI_TOOLBAR = "Open / close the menu bar"

local BAG_BUTTONS = { "MainMenuBarBackpackButton", "CharacterBag0Slot", "CharacterBag1Slot", "CharacterBag2Slot",
                      "CharacterBag3Slot", "CharacterReagentBag0Slot" }

-- Borders set on the Textures page (Menu Bar tab).
API.registerBorder({ key = "mbPlates", part = "menubar", label = "Plate edge line", size = 1, maxSize = 6, a = 90,
    legacy = function() local d = UbermocUIDB.toolbar or {}; return d.edge ~= false, 1, 90, "class" end,
    apply = function() if API.toolbarRestyle then API.toolbarRestyle() end end })
API.registerBorder({ key = "mbButtons", part = "menubar", label = "Button borders", on = false, size = 1, maxSize = 6,
    legacy = function() return false, 1, 100, "class" end,
    apply = function() if API.toolbarRestyle then API.toolbarRestyle() end end })

local function defaults()
    return { on = false, pos = "TOP", micro = true, bags = true, scale = 100, delay = 1, zone = 300, notch = false,
             bgA = 90, tex = "brushed", texA = 50, edge = true, microA = 100, bagA = 100, noBorder = false, bagPos = "panel" }
end
local filled   -- the settings table whose defaults are already filled in (DB() runs many times a second)
local function DB()
    UbermocUIDB = UbermocUIDB or {}
    local d = UbermocUIDB.toolbar
    if type(d) ~= "table" then d = {}; UbermocUIDB.toolbar = d end
    if d == filled then return d end   -- defaults already filled in for this table
    for k, v in pairs(defaults()) do if d[k] == nil then d[k] = v end end
    -- One time: the hot spot marker is off by default.
    if not d.v2 then d.v2 = true; d.notch = false end
    filled = d
    return d
end

local bar, grid, notch, corner
local picker
local owned = {}            -- button -> true while it sits on our panel
local openedBy               -- "hover" or "key"
local leaveT = 0

local function microButtons()
    local list = {}
    local mm = _G.MicroMenu
    if mm and mm.GetChildren then
        for _, b in ipairs({ mm:GetChildren() }) do
            if b.layoutIndex then list[#list + 1] = b end
        end
    end
    if #list == 0 and type(MICRO_BUTTONS) == "table" then
        for i, n in ipairs(MICRO_BUTTONS) do
            local b = _G[n]
            if b then b.layoutIndex = b.layoutIndex or i; list[#list + 1] = b end
        end
    end
    -- Already on our panel from an earlier open.
    for b in pairs(owned) do
        if b.ubermocMicro then
            local found = false
            for _, x in ipairs(list) do if x == b then found = true end end
            if not found then list[#list + 1] = b end
        end
    end
    table.sort(list, function(a, b) return (a.layoutIndex or 0) < (b.layoutIndex or 0) end)
    return list
end

-- Look of the buttons themselves: how see-through they are, and whether the frame art around each
-- one is hidden (only the picture inside stays).
local KEEP = { icon = true, icontexture = true, portrait = true, count = true, counttext = true }
local BORDERISH = { "border", "background", "buttonbg", "frame", "quickslot", "ring", "slotart", "shadow" }
local function borderLike(key, r)
    local k = type(key) == "string" and key:lower() or ""
    if KEEP[k] then return false end
    local s = k
    local okA, atlas = pcall(r.GetAtlas, r)
    if okA and type(atlas) == "string" then s = s .. " " .. atlas:lower() end
    local okT, file = pcall(r.GetTexture, r)
    if okT and type(file) == "string" then
        s = s .. " " .. file:lower()
        if file:lower():find("interface\\icons", 1, true) then return false end
    end
    for _, w in ipairs(BORDERISH) do if s:find(w, 1, true) then return true end end
    return false
end
local function stripBorders(b, on)
    b.ubermocHid = b.ubermocHid or {}
    if on then
        local keys = {}
        for k, v in pairs(b) do if type(k) == "string" and type(v) == "table" then keys[v] = k end end
        local list = { b:GetRegions() }
        local nt = (not b.ubermocMicro) and b.GetNormalTexture and b:GetNormalTexture()
        if nt then list[#list + 1] = nt end
        for _, r in ipairs(list) do
            if r.IsObjectType and r:IsObjectType("Texture") and (r == nt or borderLike(keys[r], r)) then
                if b.ubermocHid[r] == nil then b.ubermocHid[r] = r:GetAlpha() end
                r:SetAlpha(0)
            end
        end
    else
        for r, a in pairs(b.ubermocHid) do pcall(r.SetAlpha, r, a) end
        wipe(b.ubermocHid)
    end
end
local function styleButton(b)
    local d = DB()
    local a = (b.ubermocMicro and d.microA or d.bagA or 100) / 100
    pcall(b.SetAlpha, b, math.max(0.05, math.min(1, a)))
    pcall(stripBorders, b, d.noBorder and true or false)
    -- Our own border around each button (Textures page), drawn over the game's art or instead of it.
    local on, sz, r, g, bl, ba = API.borderOf("mbButtons")
    if on and not b.ubEdges then b.ubEdges = API.makeEdges(b, "OVERLAY", 6) end
    if b.ubEdges then API.paintEdges(b.ubEdges, b, on, sz, r, g, bl, ba, true) end
end
local function restyle() for b in pairs(owned) do styleButton(b) end end

-- Take a button onto the panel, unless the game has lent it to another bar (vehicle, pet battle).
local function take(b, isMicro, dest, strata)
    if not b then return false end
    dest = dest or grid
    local p = b:GetParent()
    if p ~= dest then
        if isMicro and p ~= _G.MicroMenu and p ~= _G.MicroMenuContainer and not owned[b] then return false end
        b:SetParent(dest)
    end
    owned[b] = true
    b.ubermocMicro = isMicro or nil
    -- Make sure it can be clicked here (an earlier version switched the mouse off on the game's bars).
    -- On top of the panel and of anything else on screen there, whatever strata the game gave it.
    pcall(function()
        if b.SetFixedFrameStrata then b:SetFixedFrameStrata(false) end
        if b.SetFixedFrameLevel then b:SetFixedFrameLevel(false) end
        b:SetFrameStrata(strata or "DIALOG")
        b:SetFrameLevel(dest:GetFrameLevel() + 5)
        if not InCombatLockdown() then
            b:EnableMouse(true)
            if b.SetMouseClickEnabled then b:SetMouseClickEnabled(true) end
            if b.SetMouseMotionEnabled then b:SetMouseMotionEnabled(true) end
        end
        b:SetIgnoreParentAlpha(false)
    end)
    styleButton(b)
    return true
end

-- The game re-lays out its menu bar every time a button leaves or joins it, and measures the first
-- and last button while doing so; a hidden button (Help, for example) has no position and makes that
-- error. So the first and last button stay on the game's bar until every middle button has moved
-- (and come back first when buttons are returned).
local function safeOrder(list, returning)
    local sorted = {}
    for _, b in ipairs(list) do sorted[#sorted + 1] = b end
    table.sort(sorted, function(a, b) return (a.layoutIndex or 0) < (b.layoutIndex or 0) end)
    local n = #sorted
    if n <= 2 then return sorted end
    local out = {}
    if returning then
        out[1], out[2] = sorted[1], sorted[n]
        for i = 2, n - 1 do out[#out + 1] = sorted[i] end
    else
        for i = 2, n - 1 do out[#out + 1] = sorted[i] end
        out[#out + 1] = sorted[n]
        out[#out + 1] = sorted[1]
    end
    return out
end

----------------------------------------------------------------------
-- Blade plates: an angled plate behind each row, wide side against the screen edge, slanted ends,
-- a pattern over it and a thin edge line. Built from a middle piece and two triangle end pieces.
----------------------------------------------------------------------
local MEDIA = "Interface\\AddOns\\UbermocUI\\Media\\"
local plates = {}
local function piece(f, tri)
    local p = {}
    p.base = f:CreateTexture(nil, "BACKGROUND", nil, -4)
    p.pat = f:CreateTexture(nil, "BACKGROUND", nil, -3)
    if tri then
        p.mask = f:CreateMaskTexture()
        p.base:AddMaskTexture(p.mask)
        p.pat:AddMaskTexture(p.mask)
    end
    return p
end
local function plate(i)
    local pl = plates[i]
    if pl then return pl end
    local f = CreateFrame("Frame", nil, grid)
    f:SetFrameLevel(math.max(0, grid:GetFrameLevel()))
    pl = { f = f, mid = piece(f), l = piece(f, true), r = piece(f, true), lines = {} }
    for k = 1, 3 do
        local ln = f:CreateLine(nil, "BORDER")
        ln:SetThickness(1.5)
        pl.lines[k] = ln
    end
    plates[i] = pl
    return pl
end
-- x, y: top-left of the plate's bounding box in the grid; w: width of the wide side; h: height;
-- run: how far each end slants in; wideTop: the wide side is at the top (bar hanging from the top).
local function drawPlate(i, x, y, w, h, run, wideTop)
    local d = DB()
    local pl = plate(i)
    local f = pl.f
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", grid, "TOPLEFT", x, y)
    f:SetSize(w, h)
    local A = API.accent or { 0.2, 0.7, 1 }
    local bgA = math.max(0, math.min(1, (d.bgA or 90) / 100))
    local texOn = d.tex and d.tex ~= "none" and (d.texA or 0) > 0 and bgA > 0
    local function paint(p, px, pw, triFile)
        p.base:ClearAllPoints(); p.base:SetPoint("TOPLEFT", f, "TOPLEFT", px, 0); p.base:SetSize(math.max(1, pw), h)
        p.pat:ClearAllPoints(); p.pat:SetAllPoints(p.base)
        if triFile then
            p.base:SetTexture(MEDIA .. triFile)
            p.mask:SetTexture(MEDIA .. triFile, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            p.mask:ClearAllPoints(); p.mask:SetAllPoints(p.base)
        else
            p.base:SetColorTexture(1, 1, 1, 1)
        end
        p.base:SetVertexColor(0.045, 0.05, 0.068, bgA)
        p.base:SetShown(bgA > 0 and pw > 0)
        if texOn and pw > 0 then
            p.pat:SetTexture(MEDIA .. "skin_" .. d.tex .. ".tga", "REPEAT", "REPEAT")
            p.pat:SetTexCoord(px / 128, (px + pw) / 128, 0, h / 128)
            p.pat:SetAlpha(math.min(1, d.texA / 100) * bgA)
            p.pat:Show()
        else
            p.pat:Hide()
        end
    end
    paint(pl.mid, run, w - 2 * run)
    paint(pl.l, 0, run, wideTop and "blade_a.tga" or "blade_c.tga")
    paint(pl.r, w - run, run, wideTop and "blade_b.tga" or "blade_d.tga")
    -- Edge line: both slanted ends and the narrow side (the wide side meets the screen edge or the plate above).
    local L = pl.lines
    do
        local on, sz, r, g, bl, a = API.borderOf("mbPlates")
        for k = 1, 3 do
            L[k]:SetColorTexture(r, g, bl, a)
            if L[k].SetThickness then pcall(L[k].SetThickness, L[k], sz) end
            L[k]:SetShown(on)
        end
    end
    if wideTop then
        L[1]:SetStartPoint("TOPLEFT", f, 0, 0);         L[1]:SetEndPoint("BOTTOMLEFT", f, run, 0)
        L[2]:SetStartPoint("BOTTOMLEFT", f, run, 0);    L[2]:SetEndPoint("BOTTOMRIGHT", f, -run, 0)
        L[3]:SetStartPoint("BOTTOMRIGHT", f, -run, 0);  L[3]:SetEndPoint("TOPRIGHT", f, 0, 0)
    else
        L[1]:SetStartPoint("BOTTOMLEFT", f, 0, 0);      L[1]:SetEndPoint("TOPLEFT", f, run, 0)
        L[2]:SetStartPoint("TOPLEFT", f, run, 0);       L[2]:SetEndPoint("TOPRIGHT", f, -run, 0)
        L[3]:SetStartPoint("TOPRIGHT", f, -run, 0);     L[3]:SetEndPoint("BOTTOMRIGHT", f, 0, 0)
    end
    f:Show()
end

local layoutNow
-- Buttons are only moved while the panel is shown: a menu button that turns hidden in the middle of the
-- move makes the game re-lay out its own menu bar around a button with no position, which errors.
local function layout()
    if not grid then return end
    if bar:IsShown() then return layoutNow() end
    local a = bar:GetAlpha()
    bar:SetAlpha(0)
    bar:Show()
    local ok, err = pcall(layoutNow)
    bar:Hide()
    bar:SetAlpha(a)
    if not ok then error(err) end
end
layoutNow = function()
    local d = DB()
    -- Collect each row first, then centre the rows on the widest one, with no empty space around them.
    local rows = {}
    if d.micro then
        local row = { h = 0, w = 0, items = {}, step = 2 }
        local all = microButtons()
        for _, b in ipairs(safeOrder(all, false)) do pcall(take, b, true) end
        for _, b in ipairs(all) do
            if b:GetParent() == grid and b:IsShown() then
                local w, h = b:GetSize()
                w, h = w or 32, h or 40
                row.items[#row.items + 1] = { b, w }
                row.w = row.w + w + 2
                row.h = math.max(row.h, h)
            end
        end
        if #row.items > 0 then row.w = row.w - 2; rows[#rows + 1] = row end
    end
    local cornerPos = d.bagPos and d.bagPos ~= "panel" and d.bagPos or nil
    if d.bags and cornerPos then
        -- Bags kept in a screen corner, always showing (handy for swapping bags).
        local x, n = 0, 0
        corner:SetScale(math.max(0.5, d.scale / 100))
        for _, nme in ipairs(BAG_BUTTONS) do
            local b = _G[nme]
            if b and take(b, false, corner, "MEDIUM") then
                b:SetSize(36, 36)
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", corner, "TOPLEFT", x, 0)
                b:Show()
                x = x + 40; n = n + 1
            end
        end
        corner:SetSize(math.max(1, x - 4), 36)
        corner:ClearAllPoints()
        local right = cornerPos:find("RIGHT") and true or false
        local top = cornerPos:find("TOP") and true or false
        corner:SetPoint(cornerPos, UIParent, cornerPos, right and -8 or 8, top and -8 or 8)
        corner:SetShown(n > 0)
        local tog = _G.BagBarExpandToggle
        if tog then pcall(tog.SetParent, tog, corner); tog:Hide() end
    elseif d.bags then
        if corner then corner:Hide() end
        local row = { h = 36, w = 0, items = {}, step = 4 }
        for _, n in ipairs(BAG_BUTTONS) do
            local b = _G[n]
            if b and take(b, false) then
                b:SetSize(36, 36)
                b:Show()
                row.items[#row.items + 1] = { b, 36 }
                row.w = row.w + 36 + 4
            end
        end
        if #row.items > 0 then row.w = row.w - 4; rows[#rows + 1] = row end
        local tog = _G.BagBarExpandToggle
        if tog then pcall(tog.SetParent, tog, grid); tog:Hide() end
    elseif corner then
        corner:Hide()
    end
    -- Blade plates: at the bottom of the screen the plates are upside down (wide side down) and the
    -- bags come first; on the left or right edge they are plain rectangles.
    local pos = d.pos or "TOP"
    if pos == "BOTTOM" then
        local rev = {}
        for i = #rows, 1, -1 do rev[#rev + 1] = rows[i] end
        rows = rev
    end
    local P = 5
    local angled = (pos == "TOP" or pos == "BOTTOM")
    local W = 0
    for _, r in ipairs(rows) do
        r.ph = r.h + 2 * P
        r.run = angled and math.floor(r.ph * 0.45 + 0.5) or 0
        r.pw = r.w + 2 * P + 2 * r.run
        W = math.max(W, r.pw)
    end
    local y = 0
    for i, r in ipairs(rows) do
        local px = (W - r.pw) / 2
        drawPlate(i, px, y, r.pw, r.ph, r.run, pos ~= "BOTTOM")
        local x = px + r.run + P
        for _, it in ipairs(r.items) do
            it[1]:ClearAllPoints()
            it[1]:SetPoint("TOPLEFT", grid, "TOPLEFT", x, y - P)
            x = x + it[2] + r.step
        end
        y = y - r.ph
    end
    for i = #rows + 1, #plates do plates[i].f:Hide() end
    grid:SetSize(math.max(40, W), math.max(20, -y))
    bar:SetSize(grid:GetWidth() * grid:GetScale(), grid:GetHeight() * grid:GetScale())
end

-- Give buttons back to the game's own bars: "micro", "bags", or everything.
local function giveBack(which)
    local micro = {}
    local bagsBack = false
    for b in pairs(owned) do
        if b.ubermocMicro then
            if which ~= "bags" then
                pcall(stripBorders, b, false); pcall(b.SetAlpha, b, 1)
                micro[#micro + 1] = b; owned[b] = nil
            end
        elseif which ~= "micro" then
            pcall(stripBorders, b, false); pcall(b.SetAlpha, b, 1)
            if _G.BagsBar then pcall(b.SetParent, b, _G.BagsBar) end
            owned[b] = nil; bagsBack = true
        end
    end
    if #micro > 0 and _G.MicroMenu then
        for _, b in ipairs(safeOrder(micro, true)) do pcall(b.SetParent, b, _G.MicroMenu) end
    end
    if corner then corner:Hide() end
    if _G.MicroMenu and _G.MicroMenu.Layout then pcall(_G.MicroMenu.Layout, _G.MicroMenu) end
    if _G.BagsBar and _G.BagsBar.Layout then pcall(_G.BagsBar.Layout, _G.BagsBar) end
end

-- The game's own micro menu and bag bar are only hidden for the parts the panel takes over.
local function hideGameBars()
    local hh = API.holdHidden
    if not hh then return end
    local d = DB()
    local f = _G.MicroMenuContainer
    local g = (UbermocUIDB and UbermocUIDB.extras) or {}
    local cm = type(g.cmicroRing) == "table" and g.cmicroRing.on
    local cb = type(g.cbagRing) == "table" and g.cbagRing.on
    if f then pcall(hh, f, ((d.on and d.micro) or cm) and true or false) end
    f = _G.BagsBar
    if f then pcall(hh, f, ((d.on and d.bags) or cb) and true or false) end
end

-- Does the hanging panel have anything to show? (Bags kept in a corner do not need it.)
local function panelHasContent()
    local d = DB()
    return d.micro or (d.bags and (not d.bagPos or d.bagPos == "panel"))
end

local function zoneRect()
    local d = DB()
    local W, H = UIParent:GetWidth(), UIParent:GetHeight()
    local z, depth = d.zone, 40
    -- the hot spot is at least as wide (or tall) as the panel itself, so anywhere it shows up opens it
    if bar and bar.ubSpan then z = math.max(z, bar.ubSpan) end
    -- open-ended on the screen-edge side: a cursor at (or reported past) the very edge always counts
    local FAR = 100000
    if d.pos == "TOP" then return W / 2 - z / 2, H - depth, W / 2 + z / 2, FAR
    elseif d.pos == "BOTTOM" then return W / 2 - z / 2, -FAR, W / 2 + z / 2, depth
    elseif d.pos == "LEFT" then return -FAR, H / 2 - z / 2, depth, H / 2 + z / 2
    else return W - depth, H / 2 - z / 2, FAR, H / 2 + z / 2 end
end

local function cursorIn(l, b, r, t)
    local x, y = GetCursorPosition()
    local s = UIParent:GetEffectiveScale()
    x, y = x / s, y / s
    return x >= l and x <= r and y >= b and y <= t
end

-- A quick flick toward the edge: where the cursor is heading (two checks ahead) is in the hot spot.
-- Catches the mouse that shoots to the edge (or off the window) between two checks.
local lastX, lastY
local function flickIn(l, b, r, t)
    local x, y = GetCursorPosition()
    local s = UIParent:GetEffectiveScale()
    x, y = x / s, y / s
    local px, py = lastX, lastY
    lastX, lastY = x, y
    if not px then return false end
    local fx, fy = x + (x - px) * 2, y + (y - py) * 2
    local fast = math.abs(x - px) + math.abs(y - py) > 25
    return fast and fx >= l and fx <= r and fy >= b and fy <= t
end

local function placeBar()
    if not bar then return end
    local d = DB()
    bar:ClearAllPoints()
    notch:ClearAllPoints()
    if d.pos == "TOP" then bar:SetPoint("TOP", UIParent, "TOP", 0, 0); notch:SetPoint("TOP", UIParent, "TOP", 0, 0); notch:SetSize(60, 6)
    elseif d.pos == "BOTTOM" then bar:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 0); notch:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 0); notch:SetSize(60, 6)
    elseif d.pos == "LEFT" then bar:SetPoint("LEFT", UIParent, "LEFT", 4, 0); notch:SetPoint("LEFT", UIParent, "LEFT", 0, 0); notch:SetSize(6, 60)
    else bar:SetPoint("RIGHT", UIParent, "RIGHT", -4, 0); notch:SetPoint("RIGHT", UIParent, "RIGHT", 0, 0); notch:SetSize(6, 60) end
    notch:SetShown(d.on and d.notch and not bar:IsShown())
end

local function open(by)
    if bar:IsShown() then
        -- mouse came back while it was fading out: fade straight back in instead of waiting for it to finish
        if bar.fade == -1 then bar.fade = 1; openedBy = openedBy or by; leaveT = 0 end
        return
    end
    openedBy = by
    leaveT = 0
    grid:SetScale(math.max(0.5, DB().scale / 100))
    placeBar()
    bar:SetAlpha(0)
    bar.fade = 1
    bar:Show()
    layout()
    do
        local pos = DB().pos or "TOP"
        local sc = bar:GetEffectiveScale() / UIParent:GetEffectiveScale()
        local span = (pos == "TOP" or pos == "BOTTOM") and bar:GetWidth() or bar:GetHeight()
        if span and span > 0 then bar.ubSpan = span * sc end
    end
    notch:Hide()
end

local function close()
    if not bar:IsShown() then return end
    bar.fade = -1
end

function UbermocUI_ToolbarToggle()
    if not bar or not DB().on or not panelHasContent() then return end
    if bar:IsShown() and bar.fade ~= -1 then close() else open("key") end
end

local function build()
    bar = CreateFrame("Frame", "UbermocMenuBar", UIParent)
    bar:SetFrameStrata("DIALOG")
    bar:SetToplevel(true)
    bar:SetClampedToScreen(true)
    bar:Hide()
    local A = API.accent or { 0.2, 0.7, 1 }
    grid = CreateFrame("Frame", "UbermocMenuBarGrid", bar)
    grid:SetPoint("TOPLEFT")
    grid:SetSize(100, 60)

    corner = CreateFrame("Frame", "UbermocBagCorner", UIParent)
    corner:SetSize(40, 36)
    corner:SetFrameStrata("MEDIUM")
    corner:Hide()

    notch = CreateFrame("Frame", nil, UIParent)
    notch:SetFrameStrata("HIGH")
    local nt = notch:CreateTexture(nil, "ARTWORK")
    nt:SetAllPoints(); nt:SetColorTexture(A[1], A[2], A[3], 0.5)
    notch:Hide()

    bar:SetScript("OnUpdate", function(self, dt)
        if self.fade == 1 then
            local a = math.min(1, self:GetAlpha() + dt / 0.15)
            self:SetAlpha(a)
            if a >= 1 then self.fade = nil end
        elseif self.fade == -1 then
            local a = math.max(0, self:GetAlpha() - dt / 0.2)
            self:SetAlpha(a)
            if a <= 0 then
                self.fade = nil
                -- remember how much screen edge the panel covers (for the hot spot)
                local pos = DB().pos or "TOP"
                local sc = self:GetEffectiveScale() / UIParent:GetEffectiveScale()
                local span = (pos == "TOP" or pos == "BOTTOM") and self:GetWidth() or self:GetHeight()
                if span and span > 0 then self.ubSpan = span * sc end
                self:Hide(); placeBar()
            end
            return
        end
        -- Opened by the mouse: close a moment after it leaves the panel (and the hot spot).
        if openedBy == "hover" then
            local over = self:IsMouseOver(8, -8, -8, 8) or cursorIn(zoneRect()) or (picker and picker:IsShown())
            if over then leaveT = 0 else
                leaveT = leaveT + dt
                if leaveT > DB().delay then close() end
            end
        end
    end)

    -- Watch the hot spot without covering it, so clicks still reach the game world there.
    local watch = CreateFrame("Frame")
    local acc = 0
    watch:SetScript("OnUpdate", function(_, dt)
        acc = acc + dt
        if acc < 0.03 then return end
        acc = 0
        -- the hot spot is only for the mouse: nothing to look at while it stands still and the panel is shut
        local mx, my = GetCursorPosition()
        if mx == watch.lx and my == watch.ly and not bar:IsShown() then return end
        watch.lx, watch.ly = mx, my
        local d = DB()
        if not d.on or not panelHasContent() then return end
        local l, b, r, t = zoneRect()
        local flick = flickIn(l, b, r, t)   -- sampled every check, so its speed is always measured fresh
        if bar:IsShown() and bar.fade ~= -1 then return end
        if flick or cursorIn(l, b, r, t) or (bar:IsShown() and bar:IsMouseOver(8, -8, -8, 8)) then open("hover") end
    end)

    -- A button picked from the panel closes it when it was opened with a key.
    for _, b in ipairs(microButtons()) do
        pcall(b.HookScript, b, "OnClick", function() if openedBy == "key" then close() end end)
    end
    -- The game puts the micro buttons back on its own bar after vehicles and pet battles; they are
    -- taken again the next time the panel opens.
    if UpdateMicroButtonsParent then
        hooksecurefunc("UpdateMicroButtonsParent", function(parent)
            if parent ~= grid then for b in pairs(owned) do if b.ubermocMicro and b:GetParent() ~= grid then owned[b] = nil end end end
        end)
    end
end

local function apply()
    if not bar then return end
    local d = DB()
    if d.on then
        if not d.micro then giveBack("micro") end
        if not d.bags then giveBack("bags") end
        hideGameBars()
        layout()
        if not bar:IsShown() then
            -- Collected while hidden, so nothing flashes on screen.
        end
    else
        bar:Hide()
        giveBack()
        hideGameBars()
    end
    placeBar()
end
API.applyToolbar = apply
API.toolbarDB = DB
-- The Textures page changes the texture, edge line and button borders.
function API.toolbarRestyle()
    if bar and bar:IsShown() then pcall(layout) end
    restyle()
end

----------------------------------------------------------------------
-- Bag picker: with the interface pointer on a bag slot of the menu bar, the click button lists the bags
-- you carry that fit that slot; pick one to put it there (the old bag goes back into your bags).
----------------------------------------------------------------------
local SWAP = { CharacterBag0Slot = false, CharacterBag1Slot = false, CharacterBag2Slot = false,
               CharacterBag3Slot = false, CharacterReagentBag0Slot = true } -- true: reagent bags only
local CONTAINER = (Enum and Enum.ItemClass and Enum.ItemClass.Container) or 1
local REAGENT_SUB = 11

local function bagsThatFit(reagent)
    local out = {}
    local C = C_Container
    if not C then return out end
    for bag = 0, (NUM_TOTAL_EQUIPPED_BAG_SLOTS or ((NUM_BAG_SLOTS or 4) + 1)) do
        for slot = 1, (C.GetContainerNumSlots(bag) or 0) do
            local info = C.GetContainerItemInfo(bag, slot)
            if info and info.itemID then
                local _, _, _, equipLoc, icon, classID, subID = C_Item.GetItemInfoInstant(info.itemID)
                if classID == CONTAINER and equipLoc == "INVTYPE_BAG" and ((subID == REAGENT_SUB) == (reagent and true or false)) then
                    local name = info.hyperlink and info.hyperlink:match("%[(.-)%]") or "Bag"
                    out[#out + 1] = { bag = bag, slot = slot, icon = info.iconFileID or icon, name = name, link = info.hyperlink }
                end
            end
        end
    end
    return out
end

local function closePicker()
    if picker then picker:Hide() end
end

local function buildPicker()
    local f = CreateFrame("Frame", "UbermocBagPicker", UIParent)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    local A = API.accent or { 0.2, 0.7, 1 }
    local rim = f:CreateTexture(nil, "BACKGROUND", nil, -2)
    rim:SetPoint("TOPLEFT", -1, 1); rim:SetPoint("BOTTOMRIGHT", 1, -1); rim:SetColorTexture(A[1], A[2], A[3], 0.9)
    local bg = f:CreateTexture(nil, "BACKGROUND", nil, -1)
    bg:SetAllPoints(); bg:SetColorTexture(0.04, 0.045, 0.06, 0.97)
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("TOPLEFT", 10, -8)
    f.rows = {}
    f:Hide()
    picker = f
end

local function pickerRow(i)
    local r = picker.rows[i]
    if r then return r end
    r = CreateFrame("Button", nil, picker)
    r:SetSize(240, 30)
    API.flatButton(r)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(24, 24); r.icon:SetPoint("LEFT", 4, 0)
    r.text = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.text:SetPoint("LEFT", r.icon, "RIGHT", 6, 0); r.text:SetWidth(200); r.text:SetJustifyH("LEFT"); r.text:SetWordWrap(false)
    r:SetScript("OnEnter", function(self)
        if self.link and GameTooltip then GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetHyperlink(self.link); GameTooltip:Show() end
    end)
    r:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    picker.rows[i] = r
    return r
end

function API.openBagPicker(slotBtn)
    if not picker then buildPicker() end
    local name = slotBtn:GetName()
    local reagent = SWAP[name]
    local okB, bagID = pcall(slotBtn.GetBagID, slotBtn)
    if not okB or type(bagID) ~= "number" then bagID = nil end
    local invID = bagID and C_Container.ContainerIDToInventoryID and C_Container.ContainerIDToInventoryID(bagID) or slotBtn:GetID()
    picker.title:SetText(reagent and "Reagent bag slot" or ("Bag slot " .. ((bagID or 0))))
    local list = bagsThatFit(reagent)
    local y, i = -28, 0
    local function row(text, icon, link, fn)
        i = i + 1
        local r = pickerRow(i)
        r.text:SetText(text)
        r.icon:SetTexture(icon or 134400)
        r.link = link
        r:SetScript("OnClick", fn)
        r:ClearAllPoints(); r:SetPoint("TOPLEFT", 8, y); r:Show()
        y = y - 32
    end
    for _, b in ipairs(list) do
        row(b.name, b.icon, b.link, function()
            if InCombatLockdown() then UIErrorsFrame:AddMessage("Bags can't be swapped in combat.", 1, 0.3, 0.3); return end
            ClearCursor()
            C_Container.PickupContainerItem(b.bag, b.slot)
            if PutItemInBag and invID then PutItemInBag(invID) end
            ClearCursor()
            closePicker()
            C_Timer.After(0.2, layout)
        end)
    end
    if #list == 0 then row(reagent and "No reagent bag in your bags" or "No other bag in your bags", 134400, nil, closePicker) end
    row("Open this bag", 133633, nil, function() closePicker(); pcall(slotBtn.Click, slotBtn, "LeftButton") end)
    row("Cancel", 136813, nil, closePicker)
    for k = i + 1, #picker.rows do picker.rows[k]:Hide() end
    picker:SetSize(256, -y + 6)
    picker:ClearAllPoints()
    local cx, cy = slotBtn:GetCenter()
    local es = slotBtn:GetEffectiveScale() / UIParent:GetEffectiveScale()
    if cx then picker:SetPoint("TOP", UIParent, "BOTTOMLEFT", cx * es, (cy - 26) * es) else picker:SetPoint("CENTER") end
    picker:Show()
    return true
end

-- Called by the interface pointer before it clicks something: a bag slot on the menu bar opens the picker.
function API.menuBarClick(n)
    if not n or not owned[n] or not n.GetName then return false end
    local name = n:GetName()
    if name and SWAP[name] ~= nil then return API.openBagPicker(n) end
    return false
end

----------------------------------------------------------------------
-- Page
----------------------------------------------------------------------
local function buildPage()
    local panel = CreateFrame("Frame")
    panel.name = "Menu Bar"
    API.newLabel(panel, "Menu Bar", 16, -16, "GameFontNormalHuge")
    API.newLabel(panel, "The game's menu buttons and bags on one panel that appears when the mouse reaches the edge of the screen, and hides again by itself.", 16, -44, "GameFontHighlightSmall"):SetWidth(720)
    local onCB = API.newCheck(panel, "Use the menu bar (hides the game's own menu buttons and bag bar)", 16, -80, function(v)
        DB().on = v; apply(); panel.refresh()
    end)
    API.newLabel(panel, "Appears at", 40, -124)
    local posBtn = API.segRow(panel, 140, -120, { { "TOP", "Top", 54 }, { "BOTTOM", "Bottom", 64 }, { "LEFT", "Left", 54 }, { "RIGHT", "Right", 56 } },
        function() return DB().pos or "TOP" end, function(v)
            DB().pos = v
            if bar then bar:Hide() end
            placeBar(); panel.refresh()
        end)
    local pct = function(v) return math.floor(v + 0.5) .. "%" end
    local secs = function(v) return string.format("%.1f s", v) end
    local px = function(v) return math.floor(v + 0.5) .. " px" end
    local function relayout() if bar and bar:IsShown() then layout() end end
    local microCB = API.newCheck(panel, "Menu buttons", 16, -160, function(v) DB().micro = v; giveBack("micro"); apply() end)
    API.newLabel(panel, "opacity", 150, -166)
    local sMicroA = API.makeSlider(panel, 130, 10, 100, 5, pct, function(v) DB().microA = v; restyle() end)
    sMicroA:SetPoint("TOPLEFT", 236, -160)
    local bagsCB = API.newCheck(panel, "Bag buttons", 16, -196, function(v) DB().bags = v; giveBack("bags"); apply() end)
    API.newLabel(panel, "opacity", 150, -202)
    local sBagA = API.makeSlider(panel, 130, 10, 100, 5, pct, function(v) DB().bagA = v; restyle() end)
    sBagA:SetPoint("TOPLEFT", 236, -196)
    API.newLabel(panel, "Bags at", 40, -238)
    local bagPosBtn = API.segRow(panel, 100, -234, { { "panel", "Menu bar", 74 }, { "TOPLEFT", "Top L", 50 }, { "TOPRIGHT", "Top R", 50 },
        { "BOTTOMLEFT", "Bot L", 50 }, { "BOTTOMRIGHT", "Bot R", 50 } },
        function() return DB().bagPos or "panel" end, function(v)
            DB().bagPos = v
            giveBack("bags"); apply(); panel.refresh()
        end)
    local notchCB = API.newCheck(panel, "Marker at the hot spot", 16, -272, function(v) DB().notch = v; placeBar() end)
    local y = -314
    local function slider(label, key, min, max, step, fmt)
        API.newLabel(panel, label, 40, y - 4)
        local s = API.makeSlider(panel, 150, min, max, step, fmt, function(v) DB()[key] = v; if bar and bar:IsShown() then grid:SetScale(DB().scale / 100); layout() end end)
        s:SetPoint("TOPLEFT", 170, y)
        y = y - 38
        return s
    end
    local sScale = slider("Size", "scale", 50, 200, 5, pct)
    local sDelay = slider("Hide delay", "delay", 0, 5, 0.5, secs)
    local sZone = slider("Hot spot width", "zone", 60, 1200, 10, px)
    -- Look (right-hand column): each label sits above its control so nothing overlaps.
    local RX = 390
    local lookHead = API.newLabel(panel, "Look", RX, -124, "GameFontNormalLarge")
    if lookHead.rule then lookHead.rule:SetWidth(280) end
    API.newLabel(panel, "Background opacity", RX, -160)
    local sBg = API.makeSlider(panel, 150, 0, 100, 5, pct, function(v) DB().bgA = v; relayout(); panel.refresh() end)
    sBg:SetPoint("TOPLEFT", RX + 32, -178)
    local texOpen = API.newButton(panel, "Texture and borders: Textures page", 260, RX, -222, function()
        if API.openTextures then API.openTextures("menubar") end
    end)
    local lookNote = API.newLabel(panel, "Angled plates, wide side against the screen edge. Set the background opacity to 0% to show only the buttons. The plates' texture, edge line and button borders are set on the Textures page.", RX, -262, "GameFontHighlightSmall")
    lookNote:SetWidth(290); lookNote:SetJustifyH("LEFT"); lookNote:SetWordWrap(true)
    API.newButton(panel, "Show it now", 160, 16, y - 4, function() if DB().on then open("key") end end)
    local note = API.newLabel(panel, "With a controller, bind \"Open / close the menu bar\" (game key bindings, or the Buttons page), then pick a button with the interface pointer. In a vehicle or pet battle the game borrows the menu buttons.", 16, -486, "GameFontHighlightSmall")
    note:SetWidth(660); note:SetJustifyH("LEFT"); note:SetWordWrap(true)

    function panel.refresh()
        local d = DB()
        onCB:SetChecked(d.on); microCB:SetChecked(d.micro); bagsCB:SetChecked(d.bags); notchCB:SetChecked(d.notch)
        API.setSlider(sMicroA, d.microA or 100); API.setSlider(sBagA, d.bagA or 100)
        posBtn.refresh(); bagPosBtn.refresh()
        API.setSlider(sScale, d.scale); API.setSlider(sDelay, d.delay); API.setSlider(sZone, d.zone)
        API.setSlider(sBg, d.bgA or 90)
        for _, w in ipairs({ posBtn, bagPosBtn, microCB, bagsCB, notchCB, sScale, sDelay, sZone, sMicroA, sBagA, sBg }) do API.setActive(w, d.on and true or false) end
    end
    panel:SetScript("OnShow", function() panel.refresh() end)
    API.resetters = API.resetters or {}
    API.resetters.toolbar = function() UbermocUIDB.toolbar = nil; DB(); apply() end
    API.addPage("toolbar", "Menu Bar", panel)
end

local prev = API.onLogin
API.onLogin = function()
    if prev then prev() end
    DB()
    local ok, err = pcall(build)
    if not ok and API.uiPrint then API.uiPrint("Menu bar failed: " .. tostring(err)) end
    API.later("Menu bar", buildPage)
    if C_Timer then C_Timer.After(1, function() pcall(apply) end) else pcall(apply) end
end
