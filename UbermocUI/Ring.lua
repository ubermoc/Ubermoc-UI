-- Ubermoc UI - Copyright (c) 2026 Marcos. All rights reserved.
-- This file is protected by copyright. It may not be copied, modified, redistributed or reused, in whole or
-- in part, without the written permission of the author. See LICENSE.txt.
----------------------------------------------------------------------
-- Ring unit frame: a round player frame built from native radial status bars.
-- Health in the middle, the resource ring around it, cast progress outside.
----------------------------------------------------------------------
local API = UbermocUIAPI
local MEDIA = "Interface\\AddOns\\UbermocUI\\Media\\"
local DB
local R
local rings = {}
local ptype = 0
local with
local UNIT = "player"   -- the unit of the ring being built or updated (see with() near the end)

-- Sizes: the ring and pet frames start at half the size they first had.
local HALF = { size = 60, thick = 6, gap = 2, tsize = 10, rsize = 8, isize = 16, ssize = 9, nsize = 9, cdist = 4,
               ix = -17, iy = -9, tx = 18, ty = -9, nx = 0, ny = -23,
               psize = 42, pthick = 5, pgap = 2, ptsize = 9, px = -390, py = -200 }

local UNIT_DEFAULTS = {
    player = { x = -280, y = -160, px = -390, py = -200 },
    target = { x = 280, y = -160 },
    targettarget = { x = 280, y = 60, size = 44, thick = 4, tsize = 10, msize = 8, csize = 8, showMax = false, showCur = false },
    focus = { x = -280, y = 60 },
    focustarget = { x = -280, y = 240, size = 44, thick = 4, tsize = 10, msize = 8, csize = 8, showMax = false, showCur = false },
}

local function baseDefaults()
    return { on = true, size = 60, thick = 6, gap = 0, x = 0, y = -140, res = true, cast = true,
             hcolor = "class", hr = 0.3, hg = 0.8, hb = 0.4, text = true, showPct = true, showCur = true, showMax = true, order = { "pct", "max", "cur" }, showRes = true, showName = true, rsize = 8,
             cIcon = true, cCur = true, cMax = true, isize = 16, ssize = 9, cdist = 4,
             pon = true, psize = 42, pthick = 5, pgap = 0, ptsize = 9, ptext = true, pgrad = false, pdown = false, px = -120, py = -140, nsize = 9,
             ix = -17, iy = -9, tx = 18, ty = -9, nx = 0, ny = -23, tsize = 12, msize = 9, csize = 9, pstyle = true, picon = true, pcolor = false, bg = 60, start = 0, cw = true, threat = true }
end

local function defaults(unit)
    local d = baseDefaults()
    for k, v in pairs(UNIT_DEFAULTS[unit or "player"] or {}) do d[k] = v end
    return d
end

local function isSecret(v) return issecretvalue and issecretvalue(v) end

local function ensureOrder(key, def)
    local o = DB[key]
    local ok = type(o) == "table" and #o == #def
    if ok then
        for _, id in ipairs(def) do
            local found = false
            for _, k in ipairs(o) do if k == id then found = true end end
            if not found then ok = false end
        end
    end
    if not ok then
        o = {}
        for i, id in ipairs(def) do o[i] = id end
        DB[key] = o
    end
    return o
end


----------------------------------------------------------------------
-- One ring: a dark track and a radial status bar, both cut into a ring by a mask.
----------------------------------------------------------------------
local function newRing(key)
    local f = CreateFrame("Frame", nil, R)
    f:SetPoint("CENTER")
    f.key = key
    f.track = f:CreateTexture(nil, "BACKGROUND")
    f.track:SetTexture(MEDIA .. "ringdisc.tga")
    f.track:SetPoint("CENTER")
    f.trackHole = f:CreateMaskTexture()
    f.trackHole:SetTexture(MEDIA .. "ringhole.tga", "CLAMP", "CLAMP")
    f.track:AddMaskTexture(f.trackHole)

    local bar = CreateFrame("StatusBar", nil, f)
    bar:SetPoint("CENTER")
    bar:SetStatusBarTexture(MEDIA .. "ringdisc.tga")
    bar:EnableMouse(false)
    f.bar = bar
    f.tex = bar:GetStatusBarTexture()
    f.hole = bar:CreateMaskTexture()
    f.hole:SetTexture(MEDIA .. "ringhole.tga", "CLAMP", "CLAMP")
    f.tex:AddMaskTexture(f.hole)

    if key ~= "threat" and API.skinNew then
        local sh = CreateFrame("Frame", nil, f)
        sh:SetAllPoints(f)
        sh:SetFrameLevel(bar:GetFrameLevel() + 2)
        f.skin = API.skinNew(sh, "OVERLAY", 1)
    end
    local lf = CreateFrame("Frame", nil, f)
    lf:SetAllPoints(f)
    lf:SetFrameLevel(bar:GetFrameLevel() + 4)
    f.labelFrame = lf
    f.label = lf:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    API.shade(f.label, nil, nil, "uf")
    f.label:SetTextColor(1, 1, 1, 1)
    f.label:SetJustifyH("CENTER")
    f.label:SetWordWrap(false)

    f.ready = false
    local mode = Enum and Enum.StatusBarRenderMode and Enum.StatusBarRenderMode.Radial
    if mode and bar.SetRenderMode then
        local ok, err = pcall(function()
            bar:SetRenderMode(mode)
            f.tex:ClearAllPoints()
            f.tex:SetAllPoints(bar)
            f.tex:SetRadialProgressBarStartOffset(0)
            f.tex:SetRadialProgressBarEndOffset(0)
            f.tex:SetRadialProgressBarFeather(0)
            bar:SetMinMaxValues(0, 1)
            bar:SetValue(0)
        end)
        f.ready = ok
        if not ok then f.err = tostring(err) end
    else
        f.err = "radial status bars are not available"
    end
    return f
end

-- The middle: a disc that is full at full health and drains from the top as health drops.
local function newOrb()
    local f = CreateFrame("Frame", nil, R)
    f:SetPoint("CENTER")
    f.key = "health"
    f.track = f:CreateTexture(nil, "BACKGROUND")
    f.track:SetTexture(MEDIA .. "ringdisc.tga")
    f.track:SetPoint("CENTER")
    local bar = CreateFrame("StatusBar", nil, f)
    bar:SetPoint("CENTER")
    bar:SetOrientation("VERTICAL")
    bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    bar:EnableMouse(false)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(1)
    f.bar = bar
    f.tex = bar:GetStatusBarTexture()
    f.mask = bar:CreateMaskTexture()
    f.mask:SetTexture(MEDIA .. "ringdisc.tga", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    f.mask:SetPoint("CENTER", bar, "CENTER")
    f.tex:AddMaskTexture(f.mask)
    f.ready = true

    if API.skinNew then
        local sh = CreateFrame("Frame", nil, f)
        sh:SetAllPoints(f)
        sh:SetFrameLevel(bar:GetFrameLevel() + 1)
        f.skin = API.skinNew(sh, "OVERLAY", 1)
    end
    -- Text: percent, then maximum, then current health, stacked; each can be switched off.
    local tf = CreateFrame("Frame", nil, f)
    tf:SetAllPoints(f)
    tf:SetFrameLevel(bar:GetFrameLevel() + 3)
    f.pct = tf:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    f.max = tf:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.cur = tf:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    for _, fs in ipairs({ f.pct, f.max, f.cur }) do
        API.shade(fs, nil, nil, "uf")
        fs:SetJustifyH("CENTER")
        fs:SetTextColor(1, 1, 1, 1)
    end
    return f
end

local function layoutOrb(f, diameter)
    f:SetSize(diameter, diameter)
    f.track:SetSize(diameter, diameter)
    f.track:SetVertexColor(0, 0, 0, (DB.bg or 60) / 100)
    f.bar:SetSize(diameter, diameter)
    f.mask:SetSize(diameter, diameter)
    if f.skin and R then API.skinLayout(f.skin, "halo", f, diameter / 2, 0, R:GetWidth() / 2) end
    local fontPath = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
    local s = DB.tsize or 12
    local ms = DB.msize or 9
    local cs = DB.csize or 9
    API.shade(f.pct, fontPath, s, "uf", true)
    API.shade(f.max, fontPath, ms, "uf", true)
    API.shade(f.cur, fontPath, cs, "uf", true)
    -- Stack the lines that are switched on, in the chosen order, centred in the disc.
    local ord = ensureOrder("order", { "pct", "max", "cur" })
    local info = {
        pct = { f.pct, s * 1.2, DB.showPct }, max = { f.max, ms * 1.2, DB.showMax }, cur = { f.cur, cs * 1.2, DB.showCur },
    }
    local lines = {}
    for _, k in ipairs(ord) do
        local e = info[k]
        if e then
            if e[3] then lines[#lines + 1] = e else e[1]:Hide() end
        end
    end
    local total = 0
    for _, l in ipairs(lines) do total = total + l[2] end
    local y = total / 2
    for _, l in ipairs(lines) do
        l[1]:ClearAllPoints()
        l[1]:SetPoint("CENTER", f, "CENTER", 0, y - l[2] / 2)
        l[1]:Show()
        y = y - l[2]
    end
end

local function layoutRing(f, outer, thick)
    local inner = math.max(1, outer - thick)
    f:SetSize(outer * 2, outer * 2)
    f.track:SetSize(outer * 2, outer * 2)
    f.track:SetVertexColor(0, 0, 0, (DB.bg or 60) / 100)
    f.trackHole:ClearAllPoints()
    f.trackHole:SetPoint("CENTER", f, "CENTER")
    f.trackHole:SetSize(inner * 4, inner * 4)
    f.bar:SetSize(outer * 2, outer * 2)
    f.hole:ClearAllPoints()
    f.hole:SetPoint("CENTER", f.bar, "CENTER")
    f.hole:SetSize(inner * 4, inner * 4)
    f.tex:ClearAllPoints()
    f.tex:SetAllPoints(f.bar)
    pcall(f.tex.SetRotation, f.tex, math.rad(DB.start or 0))
    pcall(f.tex.SetRadialProgressBarReverse, f.tex, not DB.cw)
    if f.skin and R then API.skinLayout(f.skin, "halo", f, outer, inner, R:GetWidth() / 2) end
    -- Text sits on the bar itself, centred at the bottom (the resource percentage).
    local off = outer - thick / 2
    f.label:ClearAllPoints()
    f.label:SetPoint("CENTER", f, "CENTER", 0, -off)
    API.shade(f.label, STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", DB.rsize or 11, "uf", true)
    f.label:SetWidth(math.max(40, outer * 1.6))
end

----------------------------------------------------------------------
-- Text blocks next to the rings: resource text under the frame, cast text above it.
----------------------------------------------------------------------
local blocks = {}

local function newCastBlock()
    -- b is only an anchor point under the frame; the icon, timer and name each sit at their own offset from it.
    local b = CreateFrame("Frame", nil, R)
    b:SetSize(1, 1)
    b:SetFrameLevel(R:GetFrameLevel() + 6)
    local ic = CreateFrame("Frame", nil, b)
    ic:SetSize(28, 28)
    b.iconF = ic
    b.icon = ic:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints(ic)
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.border = ic:CreateTexture(nil, "BACKGROUND")
    b.border:SetPoint("TOPLEFT", -1, 1)
    b.border:SetPoint("BOTTOMRIGHT", 1, -1)
    b.border:SetColorTexture(0, 0, 0, 0.9)
    local function fs()
        local f = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        API.shade(f, nil, nil, "uf")
        f:SetTextColor(1, 1, 1, 1)
        f:SetJustifyH("CENTER")
        return f
    end
    b.time = fs()
    b.name = fs()
    return b
end

----------------------------------------------------------------------
-- Pet unit frame: the pet's picture in a circle; the left half of the ring is its resource and the
-- right half its health, filling from the bottom and meeting at the top. Percentages sit underneath.
----------------------------------------------------------------------
local petF
local pptype = 0

local function petRingTex(P, layer, r, g, b, a)
    local t = P:CreateTexture(nil, "BACKGROUND", nil, layer)
    t:SetTexture(MEDIA .. "ringdisc.tga")
    t:SetPoint("CENTER", P, "CENTER", 0, 0)
    t:SetVertexColor(r, g, b, a)
    local m = P:CreateMaskTexture()
    m:SetTexture(MEDIA .. "ringhole.tga", "CLAMP", "CLAMP")
    m:SetPoint("CENTER", P, "CENTER", 0, 0)
    t:AddMaskTexture(m)
    return { tex = t, mask = m }
end

-- One half of the ring: a flat half-rectangle cut to a ring by a disc mask and swept open by a
-- rotating half-plane mask, so it fills along the arc (bottom up, draining from the top).
local PET_SQRT2 = 2 ^ 0.5
local petCurves = {}
local function newPetHalf(P, left)
    local h = { left = left }
    h.tex = P:CreateTexture(nil, "BACKGROUND", nil, -1)
    h.tex:SetTexture("Interface\\Buttons\\WHITE8x8")
    h.mO = P:CreateMaskTexture()
    h.mO:SetTexture(MEDIA .. "ringdisc.tga", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    h.mS = P:CreateMaskTexture()
    h.mS:SetTexture(MEDIA .. "halfmask.tga", "CLAMP", "CLAMP")
    h.tex:AddMaskTexture(h.mO)
    h.tex:AddMaskTexture(h.mS)
    -- A third mask cuts the middle out, so the fill colour can only ever exist in the ring, never under the picture.
    h.mH = P:CreateMaskTexture()
    h.mH:SetTexture(MEDIA .. "ringhole.tga", "CLAMP", "CLAMP")
    pcall(h.tex.AddMaskTexture, h.tex, h.mH)
    h.mS:SetRotation(left and 0 or math.pi)
    return h
end

local function setHalf(h, rot)
    h.mS:SetRotation(rot)
end

-- A radial threat ring for the pet-style frame: a status bar drawn as a ring, filled by the game's own radial renderer.
local function newThreatRing(P)
    local f = CreateFrame("Frame", nil, P)
    f:SetFrameLevel(P:GetFrameLevel() + 8)
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
    f.tex:SetVertexColor(1, 0.12, 0.1, 1)
    pcall(f.tex.SetRotation, f.tex, 0)
    pcall(f.tex.SetRadialProgressBarReverse, f.tex, true) -- counterclockwise
    f:Hide()
    return f
end

local function buildPet(unit, name)
    local P = CreateFrame("Frame", name, UIParent)
    P.unit = unit
    P:SetFrameStrata("LOW")
    P:EnableMouse(false)
    P:SetSize(10, 10)
    P.track = petRingTex(P, -3, 0.06, 0.065, 0.09, 0.85)
    P.hOuter = petRingTex(P, 1, 0.17, 0.19, 0.26, 1)
    P.hInner = petRingTex(P, 1, 0.17, 0.19, 0.26, 1)
    P.res = newPetHalf(P, true)
    P.hp = newPetHalf(P, false)
    P.back = P:CreateTexture(nil, "BACKGROUND", nil, 0)
    P.back:SetTexture(MEDIA .. "ringdisc.tga")
    P.back:SetPoint("CENTER", P, "CENTER", 0, 0)
    P.back:SetVertexColor(0.02, 0.022, 0.035, 1)
    P.pborder = petRingTex(P, 1, 0.17, 0.19, 0.26, 1)
    -- A solid dark disc right under the picture, so nothing behind it can tint it.
    P.pback = P:CreateTexture(nil, "ARTWORK", nil, -1)
    P.pback:SetTexture(MEDIA .. "ringdisc.tga")
    P.pback:SetVertexColor(0.02, 0.022, 0.035, 1)
    P.pback:SetPoint("CENTER", P, "CENTER", 0, 0)
    P.portrait = P:CreateTexture(nil, "ARTWORK", nil, 0)
    P.portrait:SetPoint("CENTER", P, "CENTER", 0, 0)
    P.portrait:SetAlpha(1)
    P.pmask = P:CreateMaskTexture()
    P.pmask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    P.pmask:SetPoint("CENTER", P, "CENTER", 0, 0)
    P.portrait:AddMaskTexture(P.pmask)
    P.pback:AddMaskTexture(P.pmask)
    local tf = CreateFrame("Frame", nil, P)
    tf:SetAllPoints(P)
    tf:SetFrameLevel(P:GetFrameLevel() + 6)
    local function fs(r, g, b)
        local f = tf:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        API.shade(f, nil, nil, "uf")
        f:SetTextColor(r, g, b, 1)
        return f
    end
    P.lt = fs(0.5, 0.65, 1)
    P.rt = fs(0.48, 0.9, 0.57)
    P.lt:SetJustifyH("RIGHT")
    P.rt:SetJustifyH("LEFT")
    P.lc = fs(0.5, 0.65, 1)
    P.rc = fs(0.48, 0.9, 0.57)
    P.lc:SetJustifyH("RIGHT")
    P.rc:SetJustifyH("LEFT")
    if API.skinNew then
        local sh = CreateFrame("Frame", nil, P)
        sh:SetAllPoints(P)
        sh:SetFrameLevel(P:GetFrameLevel() + 1)
        P.skin = API.skinNew(sh, "OVERLAY", 1)
    end
    if unit ~= "pet" then
        P.threat = newThreatRing(P)
        return P
    end
    -- Click target: left-click targets the pet, right-click opens its menu. It is its own secure
    -- button (not a child of the frame above) so the frame can still show and hide in combat.
    local c = CreateFrame("Button", "UbermocPetClick", UIParent, "SecureUnitButtonTemplate")
    c:SetFrameStrata("LOW")
    c:SetFrameLevel(P:GetFrameLevel() + 10)
    c:SetAttribute("unit", "pet")
    c:SetAttribute("*type1", "target")
    c:SetAttribute("*type2", "togglemenu")
    c:RegisterForClicks("AnyUp")
    c:SetScript("OnEnter", function(self)
        P.ubermocHover = true
        if UnitExists("pet") then
            GameTooltip_SetDefaultAnchor(GameTooltip, self)
            GameTooltip:SetUnit("pet")
            GameTooltip:Show()
        end
    end)
    c:SetScript("OnLeave", function() P.ubermocHover = false; GameTooltip:Hide() end)
    c:Hide()
    P.click = c
    return P
end

local function layoutPetFrame(P)
    if not P or not DB then return end
    local isP = P.unit ~= "pet"
    local pr = (isP and DB.size or (DB.psize or 84)) / 2
    local I = pr + (isP and (DB.gap or 0) or (DB.pgap or 3))
    local th = isP and (DB.thick or 6) or (DB.pthick or 10)
    local O = I + th
    local cx, cy = isP and DB.x or DB.px, isP and DB.y or DB.py
    local on = isP and (DB.on and DB.pstyle) or (not isP and DB.pon)
    on = on and true or false
    P:SetSize(O * 2, O * 2)
    P:ClearAllPoints()
    P:SetPoint("CENTER", UIParent, "CENTER", cx or 0, cy or 0)
    P.track.tex:SetSize(O * 2, O * 2); P.track.mask:SetSize(I * 4, I * 4)
    if P.skin then API.skinLayout(P.skin, "halo", P, O, I, O) end
    P.hOuter.tex:SetSize(O * 2, O * 2); P.hOuter.mask:SetSize((O - 1) * 4, (O - 1) * 4)
    P.hInner.tex:SetSize(I * 2, I * 2); P.hInner.mask:SetSize((I - 1) * 4, (I - 1) * 4)
    for _, h in ipairs({ P.res, P.hp }) do
        h.tex:SetSize(O, O * 2)
        h.tex:ClearAllPoints()
        h.tex:SetPoint(h.left and "RIGHT" or "LEFT", P, "CENTER", 0, 0)
        h.mO:ClearAllPoints(); h.mO:SetPoint("CENTER", P, "CENTER", 0, 0); h.mO:SetSize(O * 2, O * 2)
        h.mS:ClearAllPoints(); h.mS:SetPoint("CENTER", P, "CENTER", 0, 0); h.mS:SetSize(O * 2 * PET_SQRT2, O * 2 * PET_SQRT2)
        h.mH:ClearAllPoints(); h.mH:SetPoint("CENTER", P, "CENTER", 0, 0); h.mH:SetSize(I * 4, I * 4)
    end
    do
        local bon, bsz = API.borderOf("haloPicture")
        P.pborder.tex:SetSize(pr * 2 + 2 * bsz, pr * 2 + 2 * bsz); P.pborder.mask:SetSize((pr - 0) * 4, (pr - 0) * 4)
        P.pborder.tex:SetShown(bon)
    end
    P.back:SetSize(I * 2, I * 2)
    if P.threat then
        -- Just outside the health and resource ring.
        local inner = O + 2
        local outer = inner + math.max(2, math.floor(th * 0.6))
        P.threat:ClearAllPoints()
        P.threat:SetPoint("CENTER", P, "CENTER", 0, 0)
        P.threat:SetSize(outer * 2, outer * 2)
        P.threat.bar:SetSize(outer * 2, outer * 2)
        P.threat.hole:ClearAllPoints()
        P.threat.hole:SetPoint("CENTER", P.threat.bar, "CENTER")
        P.threat.hole:SetSize(inner * 4, inner * 4)
    end
    P.portrait:SetSize(pr * 2, pr * 2)
    P.pback:SetSize(pr * 2, pr * 2)
    P.pmask:SetSize(pr * 2, pr * 2)
    local font = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
    local ts = isP and (DB.tsize or 12) or (DB.ptsize or 14)
    API.shade(P.lt, font, ts, "uf", true)
    API.shade(P.rt, font, ts, "uf", true)
    P.lt:ClearAllPoints(); P.lt:SetPoint("TOPRIGHT", P, "BOTTOM", -8, -4)
    P.rt:ClearAllPoints(); P.rt:SetPoint("TOPLEFT", P, "BOTTOM", 8, -4)
    local cs = DB.csize or 9
    API.shade(P.lc, font, cs, "uf", true)
    API.shade(P.rc, font, cs, "uf", true)
    P.lc:ClearAllPoints(); P.lc:SetPoint("TOPRIGHT", P, "BOTTOM", -8, -(ts + 8))
    P.rc:ClearAllPoints(); P.rc:SetPoint("TOPLEFT", P, "BOTTOM", 8, -(ts + 8))
    P.lc:SetShown(isP); P.rc:SetShown(isP)
    local c = P.click
    if c and not InCombatLockdown() then
        c:ClearAllPoints()
        c:SetPoint("CENTER", UIParent, "CENTER", cx or 0, cy or 0)
        c:SetSize(O * 2, O * 2)
        if DB.pon then
            RegisterStateDriver(c, "visibility", "[@pet,exists] show; hide")
        else
            UnregisterStateDriver(c, "visibility")
            c:Hide()
        end
    end
    local showT = isP or (DB.ptext and true or false)
    P.lt:SetShown(showT)
    P.rt:SetShown(showT)
end

local styleF
local refreshLook
local function layoutPet()
    layoutPetFrame(petF)
    layoutPetFrame(styleF)
    if refreshLook then refreshLook() end
end

-- When our frames are on, the game's own player and pet frames are kept invisible (and not clickable).
local hiddenParent
-- The unit drawn by the Floating Unit Frames instead: the game's frame for it stays hidden too.
local function covered() return API.floatingCovers and API.floatingCovers(UNIT) and true or false end
local HOLD = {
    player = { { "PlayerFrame", "on", true }, { "PetFrame", "pon", false } },
    target = { { "TargetFrame", "on", false } },
    targettarget = { { "TargetFrameToT", "on", false } },
    focustarget = { { "FocusFrameToT", "on", false } },
    focus = { { "FocusFrame", "on", false } },
}

local function blizzFrame(name)
    local f = _G[name]
    if f then return f end
    if name == "TargetFrameToT" and TargetFrame then return TargetFrame.totFrame end
    if name == "FocusFrameToT" and FocusFrame then return FocusFrame.totFrame end
    return nil
end

local function holdDefaults()
    local hh = API.holdHidden
    if not hh then return end
    local combat = InCombatLockdown()
    for _, spec in ipairs(HOLD[UNIT] or {}) do
        local f = blizzFrame(spec[1])
        local cov = (spec[2] == "on" and covered()) or (spec[2] == "pon" and API.floatingCovers and API.floatingCovers("pet"))
        local on = (DB[spec[2]] or cov) and true or false
        if f then
            pcall(hh, f, on)
            if not combat then
                pcall(f.EnableMouse, f, not on)
                -- Player and pet: parked under a hidden frame, so the game's frame cannot show itself again.
                if spec[3] or spec[1] == "PetFrame" then
                    if on then
                        if not f.ubermocOrigParent then f.ubermocOrigParent = f:GetParent() end
                        if not hiddenParent then hiddenParent = CreateFrame("Frame"); hiddenParent:Hide() end
                        pcall(f.SetParent, f, hiddenParent)
                    elseif f.ubermocOrigParent then
                        pcall(f.SetParent, f, f.ubermocOrigParent)
                        f.ubermocOrigParent = nil
                    end
                end
            end
        end
    end
end

-- Where the cast information sits: under the round frame, or (pet style) under the numbers written
-- below the frame. Also re-applied each time a cast starts, so its settings always take effect.
local function placeCastBlock()
    if not (R and DB and blocks.cast) then return end
    local outerH = DB.size / 2
    local outerP = outerH + DB.gap + DB.thick
    local ps = DB.pstyle and true or false
    local outerC = ((DB.res or ps) and outerP or outerH) + DB.gap + math.max(3, math.floor(DB.thick * 0.6))
    do
        local b = blocks.cast
        local is = DB.isize or 28
        local font = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
        b:ClearAllPoints()
        -- Pet style: the cast sits below the percentages and amounts written under the frame.
        local below = outerC
        if ps then
            below = DB.size / 2 + (DB.gap or 0) + (DB.thick or 6) + (DB.tsize or 12) + (DB.csize or 9) + 14
        end
        b:SetPoint("TOP", R, "CENTER", 0, -(below + (DB.cdist or 6)))
        b.iconF:SetSize(is, is)
        b.iconF:ClearAllPoints()
        b.iconF:SetPoint("CENTER", b, "TOP", DB.ix or 0, DB.iy or 0)
        b.iconF:SetShown(DB.cIcon and true or false)
        if b.border then
            local on, sz, r, g, bl, a = API.borderOf("haloCast")
            b.border:ClearAllPoints()
            b.border:SetPoint("TOPLEFT", -sz, sz); b.border:SetPoint("BOTTOMRIGHT", sz, -sz)
            b.border:SetColorTexture(r, g, bl, a)
            b.border:SetShown(on)
        end
        API.shade(b.time, font, DB.ssize or 12, "uf")
        b.time:ClearAllPoints()
        b.time:SetPoint("CENTER", b, "TOP", DB.tx or 0, DB.ty or 0)
        API.shade(b.name, font, DB.nsize or 12, "uf")
        b.name:ClearAllPoints()
        b.name:SetPoint("CENTER", b, "TOP", DB.nx or 0, DB.ny or 0)
        -- The area the cast information uses (around the ring's centre, y up), so the buff and debuff arcs
        -- keep out of it, whether a cast is showing or not.
        local top0 = -(below + (DB.cdist or 6))
        local L, Rt, T, B
        local function add(cx, cy, hw, hh)
            if not L or cx - hw < L then L = cx - hw end
            if not Rt or cx + hw > Rt then Rt = cx + hw end
            if not T or cy + hh > T then T = cy + hh end
            if not B or cy - hh < B then B = cy - hh end
        end
        if DB.cast then
            if DB.cIcon then add(DB.ix or 0, top0 + (DB.iy or 0), is / 2, is / 2) end
            if DB.cCur or DB.cMax then local ss = DB.ssize or 12; add(DB.tx or 0, top0 + (DB.ty or 0), ss * 3, ss * 0.8) end
            if DB.showName then local ns = DB.nsize or 12; add(DB.nx or 0, top0 + (DB.ny or 0), ns * 6, ns * 0.8) end
        end
        if L then
            if ps then T = math.max(T, -(DB.size / 2)) end   -- pet style: the numbers under the frame too
            R.ubCast, R.ubCL, R.ubCR, R.ubCT, R.ubCB = true, L - 4, Rt + 4, T + 4, B - 4
        else
            R.ubCast = false
        end
    end
end

local function layout()
    if not R or not DB then return end
    local outerH = DB.size / 2
    local outerP = outerH + DB.gap + DB.thick
    local ps = DB.pstyle and true or false
    local outerC = ((DB.res or ps) and outerP or outerH) + DB.gap + math.max(3, math.floor(DB.thick * 0.6))
    R:ClearAllPoints()
    R:SetPoint("CENTER", UIParent, "CENTER", DB.x, DB.y)
    R:SetSize(outerC * 2, outerC * 2)
    layoutOrb(rings.health, DB.size)
    layoutRing(rings.power, outerP, DB.thick)
    layoutRing(rings.cast, outerC, math.max(3, math.floor(DB.thick * 0.6)))
    -- Threat: a thin red circle just inside the health disc, around its numbers, filling clockwise from the top.
    if rings.threat then
        local t = rings.threat
        layoutRing(t, math.max(6, DB.size / 2 - 2), math.max(2, math.floor(DB.size / 20)))
        t.label:SetText("")
        t.track:SetAlpha(0)
        pcall(t.tex.SetVertexColor, t.tex, 1, 0.12, 0.1, 1)
        pcall(t.tex.SetRotation, t.tex, 0)
        pcall(t.tex.SetRadialProgressBarReverse, t.tex, true) -- counterclockwise
    end
    rings.power:SetShown(DB.res and not ps)
    rings.health:SetShown(not ps)
    pcall(placeCastBlock)
    R:SetShown((DB.on and (UNIT == "player" or UnitExists(UNIT))) and true or false)
    local cb = R.click
    if cb and not InCombatLockdown() then
        cb:ClearAllPoints()
        cb:SetPoint("CENTER", UIParent, "CENTER", DB.x, DB.y)
        cb:SetSize(outerC * 2, outerC * 2)
        if UNIT == "player" then
            cb:SetShown(DB.on and true or false)
        elseif DB.on then
            RegisterStateDriver(cb, "visibility", "[@" .. UNIT .. ",exists] show; hide")
        else
            UnregisterStateDriver(cb, "visibility")
            cb:Hide()
        end
    end
    pcall(layoutPet)
    pcall(holdDefaults)
end

----------------------------------------------------------------------
-- Live values. The numbers may be hidden by WoW; the status bars accept them as they are.
----------------------------------------------------------------------
local healthCurves

local function buildCurves()
    if healthCurves or not (C_CurveUtil and C_CurveUtil.CreateCurve and Enum and Enum.LuaCurveType) then return end
    local stops = { { 0, 0.90, 0.15, 0.10 }, { 0.5, 0.95, 0.80, 0.10 }, { 1, 0.25, 0.85, 0.25 } }
    local ok, res = pcall(function()
        local out = {}
        for ch = 1, 3 do
            local c = C_CurveUtil.CreateCurve()
            c:SetType(Enum.LuaCurveType.Linear)
            for _, s in ipairs(stops) do c:AddPoint(s[1], s[ch + 1]) end
            out[ch] = c
        end
        return out
    end)
    if ok then healthCurves = res end
end

local function setHealth(f)
    f.bar:SetMinMaxValues(0, UnitHealthMax(UNIT))
    f.bar:SetValue(UnitHealth(UNIT))
end

local function colorHealth(f)
    local mode = DB.hcolor
    if mode == "gradient" and healthCurves and UnitHealthPercent then
        f.tex:SetVertexColor(UnitHealthPercent(UNIT, false, healthCurves[1]),
                             UnitHealthPercent(UNIT, false, healthCurves[2]),
                             UnitHealthPercent(UNIT, false, healthCurves[3]))
    elseif mode == "custom" then
        f.tex:SetVertexColor(DB.hr or 0.3, DB.hg or 0.8, DB.hb or 0.4)
    else
        local _, cls = UnitClass(UNIT)
        local c = cls and RAID_CLASS_COLORS and RAID_CLASS_COLORS[cls]
        if c then f.tex:SetVertexColor(c.r, c.g, c.b) else f.tex:SetVertexColor(0.3, 0.8, 0.4) end
    end
end

local function setHealthText(f)
    if DB.showPct and CurveConstants and CurveConstants.ScaleTo100 and UnitHealthPercent then
        f.pct:SetFormattedText("%.0f%%", UnitHealthPercent(UNIT, false, CurveConstants.ScaleTo100))
    end
    if DB.showMax then f.max:SetFormattedText("%d", UnitHealthMax(UNIT)) end
    if DB.showCur then f.cur:SetFormattedText("%d", UnitHealth(UNIT)) end
end

local function setPower(f)
    f.bar:SetMinMaxValues(0, UnitPowerMax(UNIT, ptype))
    f.bar:SetValue(UnitPower(UNIT, ptype))
end

local function colorPower(f)
    local c = PowerBarColor and (PowerBarColor[ptype] or PowerBarColor["MANA"])
    if c then f.tex:SetVertexColor(c.r, c.g, c.b) else f.tex:SetVertexColor(0.3, 0.5, 1) end
end

-- Cast progress 0..1 (channels count down), or nil when nothing is being cast.
-- Also returns the spell name, seconds elapsed and total seconds.
local function castFraction()
    local name, _, tex, s, e = UnitCastingInfo(UNIT)
    local channel = false
    if not name then
        name, _, tex, s, e = UnitChannelInfo(UNIT)
        channel = true
    end
    if not name or not s or not e or isSecret(s) or isSecret(e) or e <= s then return nil end
    local total = (e - s) / 1000
    local el = GetTime() - s / 1000
    if el < 0 then el = 0 elseif el > total then el = total end
    local f = el / total
    return channel and (1 - f) or f, channel, name, el, total, tex
end

local function setCast(f, frac, channel)
    f.bar:SetMinMaxValues(0, 1)
    f.bar:SetValue(frac)
    if channel then f.tex:SetVertexColor(0.3, 0.85, 0.85) else f.tex:SetVertexColor(1, 0.82, 0.2) end
end

local function setCastText(b, el, total, tex, name)
    if DB.cIcon and tex then b.icon:SetTexture(tex) end
    if DB.cCur and DB.cMax then
        b.time:SetFormattedText("%.1f / %.1f", el, total)
    elseif DB.cCur then
        b.time:SetFormattedText("%.1f", el)
    elseif DB.cMax then
        b.time:SetFormattedText("%.1f", total)
    else
        b.time:SetText("")
    end
    if DB.showName then b.name:SetText(name or ""); b.name:Show() else b.name:Hide() end
end

local function setResLabel(f)
    if CurveConstants and CurveConstants.ScaleTo100 and UnitPowerPercent then
        f.label:SetFormattedText("%.0f%%", UnitPowerPercent(UNIT, ptype, false, CurveConstants.ScaleTo100))
    end
end

-- False only when the unit is known to have no resource at all (a warrior's target, a plain mob, ...).
local function hasPower(u, pt)
    local ok, m = pcall(UnitPowerMax, u, pt)
    if not ok or m == nil or isSecret(m) or type(m) ~= "number" then return true end
    return m > 0
end

local acc, textAcc = 0, 0
-- Threat ring of one halo frame (a plain function, so the many updates a second make no new closures).
local function threatRing(P, DB, u)
    if P.threat.ready and DB.threat and u ~= "player" and UnitExists(u) and UnitCanAttack("player", u) then
        local _, _, scaled = UnitDetailedThreatSituation("player", u)
        P.threat.bar:SetMinMaxValues(0, 100)
        P.threat.bar:SetValue(type(scaled) == "number" and scaled or 0)
        return true
    end
    return false
end

local function petValues(P, texts)
    local u = P.unit or "pet"
    local isP = u ~= "pet"
    local pt = isP and ptype or pptype
    -- Health starts full and drains from the top, so the arc that is left sits at the bottom; the option
    -- turns the sweep the other way round.
    -- Every pet-style frame empties from the top: what is left sits at the bottom of each half.
    local sg = DB.pdown and 1 or -1
    if not petCurves[sg] and C_CurveUtil and C_CurveUtil.CreateCurve and Enum and Enum.LuaCurveType then
        local hc = C_CurveUtil.CreateCurve(); hc:SetType(Enum.LuaCurveType.Linear)
        hc:AddPoint(0, math.pi * sg); hc:AddPoint(1, 0)
        local rc = C_CurveUtil.CreateCurve(); rc:SetType(Enum.LuaCurveType.Linear)
        rc:AddPoint(0, 0); rc:AddPoint(1, math.pi * sg)
        petCurves[sg] = { hc, rc }
    end
    local pc = petCurves[sg]
    if pc and UnitHealthPercent and UnitPowerPercent then
        setHalf(P.hp, UnitHealthPercent(u, false, pc[1]))
        setHalf(P.res, UnitPowerPercent(u, pt, false, pc[2]))
    else
        local hm, pm = UnitHealthMax(u), UnitPowerMax(u, pt)
        local hf = hm > 0 and UnitHealth(u) / hm or 0
        local pf = pm > 0 and UnitPower(u, pt) / pm or 0
        setHalf(P.hp, math.pi * sg * (1 - hf))
        setHalf(P.res, math.pi * sg * pf)
    end
    local c = PowerBarColor and (PowerBarColor[pt] or PowerBarColor["MANA"])
    if c then P.res.tex:SetVertexColor(c.r, c.g, c.b) else P.res.tex:SetVertexColor(0.3, 0.5, 1) end
    -- Threat: a red ring around the whole frame, filling counterclockwise from the top as threat rises.
    if P.threat then
        local ok, show = pcall(threatRing, P, DB, u)
        show = ok and show or false
        if P.threat:IsShown() ~= show then P.threat:SetShown(show) end
    end
    -- No resource: the resource half and its numbers are made fully see-through.
    local ra = hasPower(u, pt) and 1 or 0
    P.res.tex:SetAlpha(ra); P.lt:SetAlpha(ra); P.lc:SetAlpha(ra)
    local mode = isP and (DB.hcolor or "class") or (DB.pgrad and "gradient" or "green")
    if mode == "gradient" and healthCurves and UnitHealthPercent then
        P.hp.tex:SetVertexColor(UnitHealthPercent(u, false, healthCurves[1]),
                                UnitHealthPercent(u, false, healthCurves[2]),
                                UnitHealthPercent(u, false, healthCurves[3]))
    elseif mode == "custom" then
        P.hp.tex:SetVertexColor(DB.hr or 0.3, DB.hg or 0.8, DB.hb or 0.4)
    elseif mode == "class" then
        local _, cls = UnitClass(u)
        local cc = cls and RAID_CLASS_COLORS and RAID_CLASS_COLORS[cls]
        if cc then P.hp.tex:SetVertexColor(cc.r, cc.g, cc.b) else P.hp.tex:SetVertexColor(0.31, 0.83, 0.42) end
    else
        P.hp.tex:SetVertexColor(0.31, 0.83, 0.42)
    end
    if texts and (isP or DB.ptext) and CurveConstants and CurveConstants.ScaleTo100 then
        if UnitPowerPercent then P.lt:SetFormattedText("%.0f%%", UnitPowerPercent(u, pt, false, CurveConstants.ScaleTo100)) end
        if UnitHealthPercent then P.rt:SetFormattedText("%.0f%%", UnitHealthPercent(u, false, CurveConstants.ScaleTo100)) end
    end
    if texts and isP then
        P.lc:SetFormattedText("%d", UnitPower(u, pt))
        P.rc:SetFormattedText("%d", UnitHealth(u))
    end
end

-- The picture of the pet-style frame: the unit's portrait, or its class icon; the ring around it can
-- be class coloured. Both only apply to players (other units keep their portrait).
local function lookOfStyle()
    local P = styleF
    if not P then return end
    local cls, isPlayer
    if UNIT == "player" or UnitExists(UNIT) then
        local okc, _, c = pcall(UnitClass, UNIT)
        if okc and type(c) == "string" then cls = c end
        local okp, ip = pcall(UnitIsPlayer, UNIT)
        isPlayer = (UNIT == "player") or (okp and ip == true)
    end
    local done = false
    if DB.picon and isPlayer and cls then
        local co = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[cls]
        if co then
            P.portrait:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
            P.portrait:SetTexCoord(co[1], co[2], co[3], co[4])
            done = true
        else
            done = pcall(function() P.portrait:SetAtlas("classicon-" .. cls:lower()); P.portrait:SetTexCoord(0, 1, 0, 1) end)
        end
    end
    if not done and SetPortraitTexture and (UNIT == "player" or UnitExists(UNIT)) then
        P.portrait:SetTexCoord(0, 1, 0, 1)
        pcall(SetPortraitTexture, P.portrait, UNIT)
    end
    -- Picture border (Textures page): class colour, a colour of your own, or the unit's own class colour.
    local _, _, br, bg, bb, ba, bmode = API.borderOf("haloPicture")
    local cc = bmode == "auto" and isPlayer and cls and RAID_CLASS_COLORS and RAID_CLASS_COLORS[cls]
    if cc then P.pborder.tex:SetVertexColor(cc.r, cc.g, cc.b, ba) else P.pborder.tex:SetVertexColor(br, bg, bb, ba) end
end

local function refreshPetPortrait()
    if petF and UNIT == "player" and UnitExists("pet") and SetPortraitTexture then pcall(SetPortraitTexture, petF.portrait, "pet") end
    pcall(lookOfStyle)
end

refreshLook = function() pcall(lookOfStyle) end

local petAcc, petTextAcc = 0, 0
local function petOne(P, texts)
    local show
    if P.unit ~= "pet" then show = (DB.on and DB.pstyle and (UNIT == "player" or UnitExists(UNIT))) and true or false
    else show = DB.pon and UnitExists("pet") and true or false end
    if P:IsShown() ~= show then
        P:SetShown(show)
        if show then refreshPetPortrait() end
    end
    if show then pcall(petValues, P, texts) end
end

local function threatShow(t)
    if t.ready and DB.threat and UNIT ~= "player" and not DB.pstyle and UnitExists(UNIT) and UnitCanAttack("player", UNIT) then
        local _, _, scaled = UnitDetailedThreatSituation("player", UNIT)
        t.bar:SetMinMaxValues(0, 100)
        t.bar:SetValue(type(scaled) == "number" and scaled or 0)
        return true
    end
    return false
end

local function petTick(_, dt)
    petAcc = petAcc + dt
    if petAcc < 0.05 then return end
    petTextAcc = petTextAcc + petAcc
    petAcc = 0
    if not DB then return end
    local texts = petTextAcc >= 0.15
    if texts then petTextAcc = 0 end
    if petF then petOne(petF, texts) end
    if styleF then petOne(styleF, texts) end
end

local function tick(_, dt)
    acc = acc + dt
    if acc < 0.04 then return end
    if UNIT ~= "player" then
        local want = (DB.on and UnitExists(UNIT)) and true or false
        if R:IsShown() ~= want then R:SetShown(want) end
        if not want then acc = 0; return end
    end
    textAcc = textAcc + acc
    acc = 0
    local h, p, c = rings.health, rings.power, rings.cast
    if h.ready then
        pcall(setHealth, h)
        pcall(colorHealth, h)
        if textAcc >= 0.15 then
            textAcc = 0
            pcall(setHealthText, h)
        end
    end
    do
        local t = rings.threat
        if t then
            local okT, show = pcall(threatShow, t)
            show = okT and show or false
            if t:IsShown() ~= show then t:SetShown(show) end
        end
    end
    if DB.res and p.ready then
        p:SetAlpha(hasPower(UNIT, ptype) and 1 or 0)
        pcall(setPower, p)
        pcall(colorPower, p)
        if DB.showRes then
            if textAcc == 0 then pcall(setResLabel, p) end
        else
            p.label:SetText("")
        end
    end
    if DB.cast and c.ready then
        local ok, frac, channel, name, el, total, tex = pcall(castFraction)
        if ok and frac then
            c:Show()
            pcall(setCast, c, frac, channel)
            if blocks.cast then
                if not blocks.cast:IsShown() then pcall(placeCastBlock) end
                blocks.cast:SetShown((DB.cIcon or DB.cCur or DB.cMax or DB.showName) and true or false)
                pcall(setCastText, blocks.cast, el, total, tex, name)
            end
        else
            c:Hide()
            if blocks.cast then blocks.cast:Hide() end
        end
    else
        c:Hide()
        if blocks.cast then blocks.cast:Hide() end
    end
end

----------------------------------------------------------------------
-- Settings page
----------------------------------------------------------------------
local function px(v) return math.floor(v + 0.5) .. " px" end
local function pc(v) return math.floor(v + 0.5) .. "%" end
local function deg(v) return math.floor(v + 0.5) .. " deg" end

local function buildPage(c)
    local D = c.cfg
    local function L() with(c, layout) end
    local function EO(k, d) return with(c, ensureOrder, k, d) end
    local panel = CreateFrame("Frame")
    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 8, -8)
    scroll:SetPoint("BOTTOMRIGHT", -30, 8)
    local p = CreateFrame("Frame", nil, scroll)
    p:SetSize(600, 1580)
    scroll:SetScrollChild(p)
    API.newLabel(p, c.label, 16, -14, "GameFontNormalHuge")
    local intro = API.newLabel(p, c.unit == "player"
        and "A round player frame. The middle disc is your health: full at full health, draining as you lose it, with the health percentage, current health and maximum health written inside (each can be switched on or off). Your resource sits in a ring around it and cast progress on the outside. Fade it from Fading > Rules > Player Halo Frame (Ubermoc UI). Pet-style frame: your picture in a circle, mana as the left half of the ring, health as the right half, percentages and current amounts underneath (the picture can be your class icon, and its border class coloured)."
        or ("A round frame for your " .. c.what .. ", built like the player frame: health in the middle disc with its text, resource in a ring around it, cast progress outside. It shows while you have a " .. c.what .. ". Fade it from Fading > Rules > " .. c.label .. " (Ubermoc UI). Pet-style frame: its picture in a circle, resource as the left half of the ring, health as the right half, amounts underneath."), 16, -48, "GameFontHighlightSmall")
    intro:SetWidth(570); intro:SetJustifyH("LEFT"); intro:SetWordWrap(true)

    local checks, sliders = {}, {}
    local updateDims
    local function check(text, y, key, x)
        checks[key] = API.newCheck(p, text, x or 16, y, function(v)
            D[key] = v
            if key == "on" and API.haloTurnedOn then pcall(API.haloTurnedOn, c.unit, v) end
            L(); if updateDims then updateDims() end; if API.evaluate then API.evaluate() end end)
    end
    local function slider(text, y, min, max, step, fmt, key)
        local lab = API.newLabel(p, text, 40, y)
        local s = API.makeSlider(p, 150, min, max, step, fmt, function(v) D[key] = v; L() end)
        s:SetPoint("TOPLEFT", 260, y)
        s.ubermocLabel = lab
        sliders[key] = s
    end
    check("Show the " .. c.what .. " halo frame", -110, "on")
    check("Resource ring", -142, "res")
    check("Cast ring", -174, "cast")
    if c.unit ~= "player" then check("Threat ring (red, fills as threat rises)", -142, "threat", 250) end
    check("Rings fill clockwise", -334, "cw")
    check("Pet-style frame", -366, "pstyle")
    check("Class icon as picture", -366, "picon", 190)
    check("Class-coloured picture border", -366, "pcolor", 390)

    -- Text lines inside the circle: each has a checkbox and Up / Down for the order.
    local refreshers = {}
    local function orderGroup(startY, items, orderKey, def)
        local labels = {}
        local function refresh()
            local o = EO(orderKey, def)
            for _, it in ipairs(items) do
                for i, k in ipairs(o) do
                    if k == it[3] then labels[it[3]]:SetText("Line " .. i) end
                end
            end
        end
        local function move(id, d)
            local o = EO(orderKey, def)
            for i, k in ipairs(o) do
                if k == id and o[i + d] then o[i], o[i + d] = o[i + d], o[i]; break end
            end
            refresh(); L()
        end
        for n, it in ipairs(items) do
            local y = startY - (n - 1) * 32
            check(it[2], y, it[1])
            API.newButton(p, "Up", 44, 300, y - 2, function() move(it[3], -1) end)
            API.newButton(p, "Down", 56, 350, y - 2, function() move(it[3], 1) end)
            labels[it[3]] = API.newLabel(p, "", 420, y - 4)
        end
        refreshers[#refreshers + 1] = refresh
    end
    orderGroup(-206, {
        { "showPct", "Show health percentage", "pct" },
        { "showMax", "Show maximum health", "max" },
        { "showCur", "Show current health", "cur" },
    }, "order", { "pct", "max", "cur" })
    check("Show resource percentage on the resource ring", -302, "showRes")

    API.ufShadowSlider(p, -398)

    -- Health colour: class colour, a colour of your own, or red-to-green by health.
    API.newLabel(p, "Health colour", 40, -440)
    local swatch
    local hbtn = API.segRow(p, 208, -436, { { "class", "Class", 56 }, { "custom", "Custom", 62 }, { "gradient", "Red-green", 80 } },
        function() return D.hcolor or "class" end, function(v) D.hcolor = v; L() end)
    local swb = CreateFrame("Button", nil, p)
    swb:SetSize(26, 26)
    swb:SetPoint("TOPLEFT", 430, -436)
    API.flatButton(swb)
    swatch = swb:CreateTexture(nil, "ARTWORK")
    swatch:SetPoint("TOPLEFT", 4, -4); swatch:SetPoint("BOTTOMRIGHT", -4, 4)
    swb:SetScript("OnClick", function()
        D.hcolor = "custom"
        hbtn.refresh()
        local pr, pg, pb = D.hr, D.hg, D.hb
        local function apply()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            D.hr, D.hg, D.hb = r, g, b
            swatch:SetColorTexture(r, g, b, 1)
        end
        if ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow then
            ColorPickerFrame:SetupColorPickerAndShow({
                r = D.hr, g = D.hg, b = D.hb, hasOpacity = false, swatchFunc = apply,
                cancelFunc = function() D.hr, D.hg, D.hb = pr, pg, pb; swatch:SetColorTexture(pr, pg, pb, 1) end,
            })
        end
    end)

    slider("Ring size", -458, 30, 500, 2, px, "size")
    slider("Health percentage size", -498, 6, 40, 1, px, "tsize")
    slider("Maximum health size", -538, 6, 40, 1, px, "msize")
    slider("Current health size", -578, 6, 40, 1, px, "csize")
    slider("Ring thickness", -618, 3, 40, 1, px, "thick")
    slider("Gap between rings", -658, 0, 500, 1, px, "gap")
    slider("Background darkness", -698, 0, 100, 5, pc, "bg")
    slider("Left / right", -738, -900, 900, 1, px, "x")
    slider("Up / down", -778, -600, 600, 1, px, "y")
    slider("Ring start angle", -818, 0, 355, 5, deg, "start")
    API.newLabel(p, "Cast information (below the frame, while casting)", 16, -864, "GameFontNormal")
    check("Show spell icon", -892, "cIcon")
    check("Show cast time", -924, "cCur")
    check("Show max cast time", -956, "cMax")
    check("Show spell name", -988, "showName")
    slider("Spell icon size", -1028, 10, 500, 1, px, "isize")
    slider("Spell icon left / right", -1068, -500, 500, 1, px, "ix")
    slider("Spell icon up / down", -1108, -500, 500, 1, px, "iy")
    slider("Timer text size", -1148, 6, 30, 1, px, "ssize")
    slider("Timer left / right", -1188, -500, 500, 1, px, "tx")
    slider("Timer up / down", -1228, -500, 500, 1, px, "ty")
    slider("Spell name size", -1268, 6, 30, 1, px, "nsize")
    slider("Spell name left / right", -1308, -500, 500, 1, px, "nx")
    slider("Spell name up / down", -1348, -500, 500, 1, px, "ny")
    slider("Distance below frame", -1388, 0, 500, 1, px, "cdist")
    slider("Ring text size", -1428, 6, 24, 1, px, "rsize")
    -- Swap the places of two pieces of spell information.
    local function swap(ka, kb)
        D[ka .. "x"], D[kb .. "x"] = D[kb .. "x"], D[ka .. "x"]
        D[ka .. "y"], D[kb .. "y"] = D[kb .. "y"], D[ka .. "y"]
        for _, k in ipairs({ ka .. "x", ka .. "y", kb .. "x", kb .. "y" }) do
            local sl = sliders[k]
            if sl then API.setSlider(sl, D[k]) end
        end
        L()
    end
    API.newButton(p, "Swap icon and timer", 190, 16, -1476, function() swap("i", "t") end)
    API.newButton(p, "Swap timer and name", 190, 216, -1476, function() swap("t", "n") end)
    API.newButton(p, "Swap icon and name", 190, 416, -1476, function() swap("i", "n") end)
    local note = API.newLabel(p, "If the resource or cast ring fills from the wrong place or the wrong way, change Ring start angle or Rings fill clockwise.", 16, -1526, "GameFontHighlightSmall")
    note:SetWidth(570); note:SetJustifyH("LEFT"); note:SetWordWrap(true)

    -- Settings that do not apply to the chosen look are greyed out, so nothing seems to do nothing.
    local dimNote = API.newLabel(p, "", 16, -425, "GameFontDisableSmall")
    local ROUND_ONLY = { "cw", "msize", "csize", "bg", "start", "rsize", "showPct", "showMax", "showCur", "showRes" }
    local CAST_KEYS = { "cIcon", "cCur", "cMax", "showName", "isize", "ix", "iy", "ssize", "tx", "ty", "nsize", "nx", "ny", "cdist" }
    updateDims = function()
        local pet = D.pstyle and true or false
        for _, k in ipairs(ROUND_ONLY) do API.setActive(checks[k] or sliders[k], not pet) end
        API.setActive(checks.picon, pet); API.setActive(checks.pcolor, pet)
        if checks.showRes then API.setActive(checks.showRes, (not pet) and D.res) end
        for _, k in ipairs(CAST_KEYS) do API.setActive(checks[k] or sliders[k], D.cast) end
        dimNote:SetText(pet and "Greyed-out settings belong to the round frame and don't change the pet-style frame."
            or "Class icon and picture border are for the pet-style frame.")
    end
    API.newLockButton(p, 400, -14)
    local tabDefs = { { "Frame", 0 }, { "Size & Position", -440 }, { "Cast Information", -860 } }
    local haRefresh
    local acUnit = c.unit == "targettarget" or c.unit == "focustarget"
    if c.unit == "player" or c.unit == "target" or c.unit == "focus" or acUnit then
        -- The game's buffs and debuffs around this frame (Auras.lua does the placing).
        local key = c.unit
        local HY = -1580
        tabDefs[#tabDefs + 1] = { "Buffs & Debuffs", HY + 10 }
        local function hd() return API.haloAurasDB and API.haloAurasDB(key) or {} end
        local function apply() if API.haloAurasApply then API.haloAurasApply(key) end; if haRefresh then haRefresh() end end
        API.newLabel(p, "Buffs and debuffs around the frame", 16, HY, "GameFontNormalLarge")
        local haOn = API.newCheck(p, "Put the game's buffs and debuffs around this frame", 16, HY - 34, function(v) hd().on = v; apply() end)
        local SIDES = { { "left", "Left", 60 }, { "top", "Top", 60 }, { "right", "Right", 60 }, { "bottom", "Bottom", 70 } }
        API.newLabel(p, "Buffs", 40, HY - 78)
        local bRow = API.segRow(p, 228, HY - 72, SIDES, function() return hd().buffs or "left" end, function(v) hd().buffs = v; apply() end)
        API.newLabel(p, "Debuffs", 40, HY - 114)
        local dRow = API.segRow(p, 228, HY - 108, SIDES, function() return hd().debuffs or "right" end, function(v) hd().debuffs = v; apply() end)
        API.newLabel(p, "Icon size", 40, HY - 152)
        local hSize = API.makeSlider(p, 140, 16, 48, 1, px, function(v) hd().size = v; apply() end)
        hSize:SetPoint("TOPLEFT", 260, HY - 148)
        API.sliderDefault(hSize, 26)
        API.newLabel(p, "Distance from the frame", 40, HY - 192)
        local hGap = API.makeSlider(p, 140, 0, 60, 1, px, function(v) hd().gap = v; apply() end)
        hGap:SetPoint("TOPLEFT", 260, HY - 188)
        API.sliderDefault(hGap, 8)
        local hMax
        if acUnit then
            API.newLabel(p, "How many (each)", 40, HY - 232)
            hMax = API.makeSlider(p, 140, 1, 16, 1, tostring, function(v) hd().max = v; apply() end)
            hMax:SetPoint("TOPLEFT", 260, HY - 228)
            API.sliderDefault(hMax, 6)
        end
        local ty0 = acUnit and (HY - 272) or (HY - 232)
        API.newLabel(p, "Time text size", 40, ty0 - 4)
        local hTS = API.makeSlider(p, 140, 40, 250, 5, function(v) return math.floor(v + 0.5) .. "%" end, function(v) hd().tsz = v; apply() end)
        hTS:SetPoint("TOPLEFT", 260, ty0)
        API.sliderDefault(hTS, 100)
        API.newLabel(p, "Time left / right", 40, ty0 - 44)
        local hTX = API.makeSlider(p, 140, -30, 30, 1, px, function(v) hd().tx = v; apply() end)
        hTX:SetPoint("TOPLEFT", 260, ty0 - 40)
        API.sliderDefault(hTX, 0)
        API.newLabel(p, "Time up / down", 40, ty0 - 84)
        local hTY = API.makeSlider(p, 140, -30, 30, 1, px, function(v) hd().ty = v; apply() end)
        hTY:SetPoint("TOPLEFT", 260, ty0 - 80)
        API.sliderDefault(hTY, 0)
        local noteY = ty0 - 122
        local hn = API.newLabel(p, acUnit and ("The icons are the game's own aura display for the " .. c.what .. ", so timers and tooltips work as usual. Buffs and debuffs on the same side share it, debuffs beyond the buffs.") or (key == "player" and "The icons are the game's own, so their timers, tooltips and right-click to cancel work as usual." or "The icons are the game's own " .. c.what .. " frame icons, so their timers and tooltips work as usual.") .. " When an arc is full the next icons start a second arc further out; buffs and debuffs on the same side share it, debuffs after buffs. They go back to their usual place when this is off, the halo frame is off, or the layout editor is open.", 16, noteY, "GameFontHighlightSmall")
        hn:SetWidth(570); hn:SetJustifyH("LEFT"); hn:SetWordWrap(true)
        local pickRefresh
        if not acUnit then
            API.newLabel(p, "Hide specific buffs and debuffs", 16, HY - 420, "GameFontNormal")
            pickRefresh = API.auraPicker and API.auraPicker(p, HY - 450, key)
        end
        haRefresh = function()
            if pickRefresh then pickRefresh() end
            local d = hd()
            haOn:SetChecked(d.on ~= false)
            bRow.refresh(); dRow.refresh()
            API.setSlider(hSize, d.size or 26); API.setSlider(hGap, d.gap or 8)
            API.setSlider(hTS, d.tsz or 100); API.setSlider(hTX, d.tx or 0); API.setSlider(hTY, d.ty or 0)
            API.setActive(hTS, d.on ~= false); API.setActive(hTX, d.on ~= false); API.setActive(hTY, d.on ~= false)
            if hMax then API.setSlider(hMax, d.max or 6); API.setActive(hMax, d.on ~= false) end
            local on = d.on ~= false
            API.setActive(bRow, on); API.setActive(dRow, on); API.setActive(hSize, on); API.setActive(hGap, on)
        end
        p:SetHeight(2400)
    end
    API.makeTabs(panel, scroll, p, tabDefs)

    panel:SetScript("OnShow", function()
        for k, cb in pairs(checks) do cb:SetChecked(D[k] and true or false) end
        for _, r in ipairs(refreshers) do r() end
        for k, s in pairs(sliders) do API.setSlider(s, D[k]) end
        hbtn.refresh()
        swatch:SetColorTexture(D.hr or 0.3, D.hg or 0.8, D.hb or 0.4, 1)
        updateDims()
        if haRefresh then haRefresh() end
    end)
    panel.name = c.label
    API.addPage(c.page, c.label, panel)
    API.resetters[c.page] = function()
        with(c, function()
            local keep = { halved = true, textV = true, textV2 = true }
            if UNIT == "player" then for _, k in ipairs({ "pon", "ptext", "pgrad", "psize", "pthick", "pgap", "ptsize", "px", "py", "pdown" }) do keep[k] = true end end
            for k in pairs(DB) do if not keep[k] then DB[k] = nil end end
            for k, v in pairs(defaults(UNIT)) do DB[k] = v end
            layout(); layoutPet()
            if petF then petValues(petF, true) end
        end)
    end
end


-- The pet unit frame has its own page (a tab beside the player's).
local PET_KEYS = { "pon", "ptext", "pgrad", "psize", "pthick", "pgap", "ptsize", "px", "py", "pdown" }
local function buildPetPage(c)
    local D = c.cfg
    local function L() with(c, layout) end
    local panel = CreateFrame("Frame")
    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 8, -8)
    scroll:SetPoint("BOTTOMRIGHT", -30, 8)
    local p = CreateFrame("Frame", nil, scroll)
    p:SetSize(600, 560)
    scroll:SetScrollChild(p)
    local checks, sliders = {}, {}
    local function check(text, y, key)
        checks[key] = API.newCheck(p, text, 16, y, function(v) D[key] = v; L(); if API.evaluate then API.evaluate() end end)
    end
    local function slider(text, y, min, max, step, fmt, key)
        API.newLabel(p, text, 40, y)
        local s = API.makeSlider(p, 150, min, max, step, fmt, function(v) D[key] = v; L() end)
        s:SetPoint("TOPLEFT", 260, y)
        sliders[key] = s
    end
    API.newLabel(p, "Pet Halo Frame", 16, -14, "GameFontNormalHuge")
    local pnote = API.newLabel(p, "The pet's picture in a circle. The left half of the ring is the pet's resource and the right half its health, filling from the bottom and meeting at the top, with both percentages underneath. It shows while you have a pet. Fade it from Fading > Rules > Pet Halo Frame (Ubermoc UI).", 16, -48, "GameFontHighlightSmall")
    pnote:SetWidth(570); pnote:SetJustifyH("LEFT"); pnote:SetWordWrap(true)
    checks.pon = API.newCheck(p, "Show the pet halo frame", 16, -106, function(v)
        D.pon = v
        if API.haloTurnedOn then pcall(API.haloTurnedOn, "pet", v) end
        L(); if API.evaluate then API.evaluate() end
    end)
    check("Show the percentages under it", -138, "ptext")
    check("Colour the pet's health red to green", -170, "pgrad")
    slider("Picture size", -210, 24, 500, 2, px, "psize")
    slider("Ring thickness", -250, 3, 24, 1, px, "pthick")
    slider("Gap around the picture", -290, 0, 500, 1, px, "pgap")
    slider("Percentage size", -330, 6, 30, 1, px, "ptsize")
    slider("Left / right", -370, -900, 900, 1, px, "px")
    slider("Up / down", -410, -600, 600, 1, px, "py")
    check("Fill the rings downwards instead of upwards", -450, "pdown")
    API.newLockButton(p, 400, -14)
    API.makeTabs(panel, scroll, p, { { "Frame", 0 }, { "Size & Position", -196 } })
    panel:SetScript("OnShow", function()
        for k, cb in pairs(checks) do cb:SetChecked(D[k] and true or false) end
        for k, s in pairs(sliders) do API.setSlider(s, D[k]) end
    end)
    panel.name = "Pet Halo Frame"
    API.addPage("ringpet", "Pet Halo Frame", panel)
    API.resetters.ringpet = function()
        with(c, function()
            for k, v in pairs(defaults(UNIT)) do
                for _, pk in ipairs(PET_KEYS) do if pk == k then DB[k] = v end end
            end
            layout(); layoutPet()
            if petF then petValues(petF, true) end
        end)
    end
end

local function reportBody()
    local say = API.uiPrint or print
    local function line(t) say("|cff00ccffUbermoc UI|r " .. t) end
    if not R then line("ring frame: not built") return end
    line(string.format("ring frame: on=%s shown=%s size=%d at %d,%d", tostring(DB.on), tostring(R:IsShown()), DB.size, DB.x, DB.y))
    for _, k in ipairs({ "health", "power", "cast" }) do
        local f = rings[k]
        line(string.format("%s: ready=%s%s", k == "health" and "centre disc" or ("ring " .. k), tostring(f.ready), type(f.err) == "string" and (" error: " .. f.err) or ""))
    end
    local okh, hp = pcall(UnitHealth, UNIT)
    line("health value: " .. ((okh and isSecret(hp)) and "hidden (fine: the ring reads it directly)" or tostring(hp)))
    line("power type: " .. tostring(ptype))
end

----------------------------------------------------------------------
-- Several rings share this file's code (player, target, target of target, focus). Each ring keeps
-- its own state in a table; with() loads that state, runs a function and stores it back.
----------------------------------------------------------------------
local CTX = {}
-- Borders set on the Textures page (Halo Frames tab).
API.registerBorder({ key = "haloPicture", part = "halo", label = "Picture border (pet style)", size = 1, maxSize = 6,
    auto = "The unit's class colour",
    legacy = function()
        local d = UbermocUIDB.ringhud or {}
        if d.pcolor then return true, 1, 100, "auto" end
        return true, 1, 100, "class"
    end,
    apply = function() for _, c in ipairs(CTX) do pcall(with, c, layout); pcall(with, c, layoutPet) end end })
API.registerBorder({ key = "haloCast", part = "halo", label = "Cast icon border", size = 1, maxSize = 6, a = 90,
    legacy = function() return true, 1, 90, "class" end,
    apply = function() for _, c in ipairs(CTX) do pcall(with, c, layout); pcall(with, c, layoutPet) end end })

local function loadCtx(c)
    DB = c.cfg; R = c.R; rings = c.rings; blocks = c.blocks; ptype = c.ptype
    petF = c.petF; styleF = c.styleF; UNIT = c.unit
    acc, textAcc, petAcc, petTextAcc = c.acc, c.textAcc, c.petAcc, c.petTextAcc
end

local function storeCtx(c)
    c.cfg = DB; c.R = R; c.rings = rings; c.blocks = blocks; c.ptype = ptype
    c.petF = petF; c.styleF = styleF
    c.acc, c.textAcc, c.petAcc, c.petTextAcc = acc, textAcc, petAcc, petTextAcc
end

local activeCtx
with = function(c, fn, ...)
    local prev = activeCtx
    if prev and prev ~= c then storeCtx(prev) end
    if prev ~= c then loadCtx(c) end
    activeCtx = c
    local ok, a = pcall(fn, ...)
    storeCtx(c)
    if prev and prev ~= c then loadCtx(prev) end
    activeCtx = prev
    if not ok then error(a, 0) end
    return a
end

function API.ringHudReport()
    if CTX[1] then with(CTX[1], reportBody) end
end

local SPECS = {
    { unit = "player", db = "ringhud", page = "ringhud", label = "Player Halo Frame", what = "player", suffix = "", mover = "Player halo frame" },
    { unit = "target", db = "ringhud_target", page = "ringtarget", label = "Target Halo Frame", what = "target", suffix = "_target", mover = "Target halo frame" },
    { unit = "targettarget", db = "ringhud_tot", page = "ringtot", label = "Target of Target Halo Frame", what = "target of target", suffix = "_tot", mover = "Target of target halo frame" },
    { unit = "focus", db = "ringhud_focus", page = "ringfocus", label = "Focus Halo Frame", what = "focus target", suffix = "_focus", mover = "Focus halo frame" },
    { unit = "focustarget", db = "ringhud_fot", page = "ringfot", label = "Focus Target Halo Frame", what = "focus's target", suffix = "_fot", mover = "Focus target halo frame" },
}

local function setup(c)
    local unit = c.unit
    UbermocUIDB[c.db] = UbermocUIDB[c.db] or {}
    DB = UbermocUIDB[c.db]
    local oldT = DB.tsize
    for k, v in pairs(defaults(unit)) do if DB[k] == nil then DB[k] = v end end
    if unit == "player" then
        if not DB.textV then
            DB.textV = true
            if oldT then DB.msize = math.max(10, math.floor(oldT * 0.8)); DB.csize = math.max(9, math.floor(oldT * 0.8)) end
        end
        if not DB.textV2 then
            DB.textV2 = true
            DB.msize = DB.csize or 9
        end
        if not DB.halved then
            DB.halved = true
            for k, v in pairs(HALF) do DB[k] = v end
        end
    end
    -- One time: halo frames now start in the pet style.
    if not DB.haloV1 then DB.haloV1 = true; DB.pstyle = true end
    -- One time: the picture is the class icon by default.
    if not DB.haloV2 then DB.haloV2 = true; DB.picon = true end
    -- One time: frames still at the old middle-of-the-screen defaults move to the sides
    -- (player, pet and focus on the left, target and target of target on the right).
    if not DB.haloPosV2 then
        DB.haloPosV2 = true
        local OLD = { player = { 0, -140 }, target = { 240, -140 }, targettarget = { 380, -140 }, focus = { -240, -140 } }
        if unit == "targettarget" and DB.x == 420 and DB.y == -60 then DB.x, DB.y = 380, -140 end
        if unit == "focus" and DB.x == -420 and DB.y == -60 then DB.x, DB.y = -240, -140 end
        local o, n = OLD[unit], UNIT_DEFAULTS[unit]
        if o and n and DB.x == o[1] and DB.y == o[2] then DB.x, DB.y = n.x, n.y end
        if unit == "player" and DB.px == -120 and (DB.py == -140 or DB.py == nil) then DB.px, DB.py = n.px, n.py end
    end
    c.cfg = DB
    API.registerMover(c.mover, function()
        local d = c.cfg
        local w = c.R and c.R:GetWidth() or 120
        return d.on, d.x, d.y, w, w
    end, function(x, y) c.cfg.x, c.cfg.y = x, y; with(c, layout) end)
    if unit == "player" then
        API.registerMover("Pet halo frame", function()
            local d = c.cfg
            local w = c.petF and c.petF:GetWidth() or 100
            return d.pon, d.px, d.py, w, w
        end, function(x, y) c.cfg.px, c.cfg.py = x, y; with(c, layoutPet) end)
    end
    R = CreateFrame("Frame", "UbermocRingHUD" .. c.suffix, UIParent)
    R:SetFrameStrata("LOW")
    R:EnableMouse(false)
    -- Click target: left-click targets the unit, right-click opens its menu.
    local cb = CreateFrame("Button", "UbermocRingClick" .. c.suffix, UIParent, "SecureUnitButtonTemplate")
    cb:SetFrameStrata("LOW")
    cb:SetFrameLevel(R:GetFrameLevel() + 10)
    cb:SetAttribute("unit", unit)
    cb:SetAttribute("*type1", "target")
    cb:SetAttribute("*type2", "togglemenu")
    cb:RegisterForClicks("AnyUp")
    local myR = R
    cb:SetScript("OnEnter", function(self)
        myR.ubermocHover = true
        if unit == "player" or UnitExists(unit) then
            GameTooltip_SetDefaultAnchor(GameTooltip, self)
            GameTooltip:SetUnit(unit)
            GameTooltip:Show()
        end
    end)
    cb:SetScript("OnLeave", function() myR.ubermocHover = false; GameTooltip:Hide() end)
    cb:Hide()
    R.click = cb
    rings.health = newOrb()
    rings.power = newRing("power")
    rings.cast = newRing("cast")
    rings.cast:Hide()
    rings.threat = newRing("threat")
    rings.threat:SetFrameLevel(rings.health:GetFrameLevel() + 6)
    rings.threat:Hide()
    blocks.cast = newCastBlock()
    blocks.cast:Hide()
    buildCurves()
    pcall(function() local t = UnitPowerType(unit); if type(t) == "number" and not isSecret(t) then ptype = t end end)
    local function refreshType()
        local ok, t = pcall(UnitPowerType, unit)
        if ok and not isSecret(t) and type(t) == "number" then ptype = t end
        buildCurves()
    end
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("PLAYER_ENTERING_WORLD")
    ev:RegisterUnitEvent("UNIT_DISPLAYPOWER", unit)
    if unit == "target" or unit == "targettarget" then ev:RegisterEvent("PLAYER_TARGET_CHANGED") end
    if unit == "targettarget" then ev:RegisterUnitEvent("UNIT_TARGET", "target") end
    if unit == "focustarget" then ev:RegisterUnitEvent("UNIT_TARGET", "focus") end
    if unit == "focus" or unit == "focustarget" then ev:RegisterEvent("PLAYER_FOCUS_CHANGED") end
    ev:SetScript("OnEvent", function() with(c, function() refreshType(); refreshPetPortrait(); if unit ~= "player" then layout() end end) end)
    -- Throttled here, before the frame's settings are swapped in, so the swap runs 25 times a second
    -- instead of every frame.
    local rAcc = 0
    R:SetScript("OnUpdate", function(_, dt)
        rAcc = rAcc + dt
        if rAcc < 0.04 then return end
        local s = rAcc; rAcc = 0
        with(c, tick, nil, s)
    end)
    local pev = CreateFrame("Frame")
    pev:RegisterEvent("PLAYER_ENTERING_WORLD")
    if unit == "player" then
        petF = buildPet("pet", "UbermocPetHUD")
        pev:RegisterUnitEvent("UNIT_PET", "player")
        pev:RegisterUnitEvent("UNIT_DISPLAYPOWER", "pet")
        pcall(function() local t = UnitPowerType("pet"); if type(t) == "number" then pptype = t end end)
        pev:RegisterUnitEvent("UNIT_PORTRAIT_UPDATE", "pet", "player")
        pev:RegisterUnitEvent("UNIT_MODEL_CHANGED", "pet", "player")
    else
        pev:RegisterUnitEvent("UNIT_PORTRAIT_UPDATE", unit)
        pev:RegisterUnitEvent("UNIT_MODEL_CHANGED", unit)
        if unit == "target" or unit == "targettarget" then pev:RegisterEvent("PLAYER_TARGET_CHANGED") end
        if unit == "focus" or unit == "focustarget" then pev:RegisterEvent("PLAYER_FOCUS_CHANGED") end
    end
    styleF = buildPet(unit, "UbermocPlayerStyleHUD" .. c.suffix)
    pev:SetScript("OnEvent", function()
        with(c, function()
            if unit == "player" then
                local ok, t = pcall(UnitPowerType, "pet")
                if ok and not isSecret(t) and type(t) == "number" then pptype = t end
            end
            refreshPetPortrait()
        end)
    end)
    local pAcc = 0
    pev:SetScript("OnUpdate", function(_, dt)
        pAcc = pAcc + dt
        if pAcc < 0.05 then return end
        local s = pAcc; pAcc = 0
        with(c, petTick, nil, s)
    end)
    layout()
    local rg = CreateFrame("Frame")
    rg:RegisterEvent("PLAYER_REGEN_ENABLED")
    rg:RegisterEvent("PLAYER_ENTERING_WORLD")
    rg:SetScript("OnEvent", function() with(c, layout) end)
end

local prev = API.onLogin
API.onLogin = function()
    if prev then prev() end
    for i, sp in ipairs(SPECS) do
        local c = { unit = sp.unit, db = sp.db, page = sp.page, label = sp.label, what = sp.what, suffix = sp.suffix, mover = sp.mover,
                    rings = {}, blocks = {}, ptype = 0, acc = 0, textAcc = 0, petAcc = 0, petTextAcc = 0 }
        CTX[i] = c
        local ok, err = pcall(function()
            with(c, setup, c)
            API.later(sp.label or sp.unit, function()
                buildPage(c)
                if sp.unit == "player" then buildPetPage(c) end
            end)
        end)
        if not ok and API.uiPrint then API.uiPrint("Ring setup failed (" .. sp.unit .. "): " .. tostring(err)) end
    end
end

-- The round frame shown for a unit (pet style or classic), and its radius. Used by the combo points.
-- Switches a unit's halo frame on or off (the Floating Unit Frames page picks the design).
function API.haloSet(unit, on)
    for _, c in ipairs(CTX) do
        if c.unit == unit and c.cfg then
            c.cfg.on = on and true or false
            pcall(with, c, layout)
            if API.evaluate then pcall(API.evaluate) end
        end
    end
end
-- The pet halo frame (part of the player's settings).
function API.haloPetSet(on)
    for _, c in ipairs(CTX) do
        if c.unit == "player" and c.cfg then
            c.cfg.pon = on and true or false
            pcall(with, c, layout)
            if API.evaluate then pcall(API.evaluate) end
        end
    end
end
-- Lays a unit's halo frame out again (it also hides or gives back the game's own frame).
function API.haloRefresh(unit)
    for _, c in ipairs(CTX) do
        if c.unit == unit and c.cfg then pcall(with, c, layout) end
    end
end

-- Switches a unit's halo frame off (its Floating Unit Frame replaces it).
function API.haloOff(unit)
    local found
    for _, c in ipairs(CTX) do
        if c.unit == unit and c.cfg then
            found = true
            if c.cfg.on then
                c.cfg.on = false
                pcall(with, c, layout)
                if API.evaluate then pcall(API.evaluate) end
            end
        end
    end
    return found
end

function API.haloFrame(unit)
    for _, c in ipairs(CTX) do
        if c.unit == unit and c.cfg and c.cfg.on then
            local f = c.cfg.pstyle and c.styleF or c.R
            if f and f:IsShown() then return f, (f:GetWidth() or 0) / 2 end
        end
    end
end
