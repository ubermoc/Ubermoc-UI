-- Ubermoc UI - Copyright (c) 2026 Marcos. All rights reserved.
-- This file is protected by copyright. It may not be copied, modified, redistributed or reused, in whole or
-- in part, without the written permission of the author. See LICENSE.txt.
----------------------------------------------------------------------
-- Party frames: one round frame per party member, in the same design as the ring unit frame.
-- A health disc (class colour, draining from the top) with the percentage inside, the resource
-- in a ring around it, cast progress on a thin outer ring, a role badge on top and the spec icon
-- above the percentage. Left-click targets, right-click opens the member's menu.
----------------------------------------------------------------------
local API = UbermocUIAPI
local MEDIA = "Interface\\AddOns\\UbermocUI\\Media\\"

-- Borders set on the Textures page (Party & Raid tab).
if API and API.registerBorder then
    local function partyRelayout() for _, fn in ipairs(API.partyLayouts or {}) do fn() end end
    API.registerBorder({ key = "partyRim", part = "party", label = "Member circle rim", size = 3, maxSize = 8,
        legacy = function() return true, 3, 100, "class" end, apply = partyRelayout })
    API.registerBorder({ key = "partyRole", part = "party", label = "Role icon rim", size = 1, maxSize = 6,
        legacy = function() return true, 1, 100, "class" end, apply = partyRelayout })
end
local function Group(SP)
    local DB
    local C
    local slots = {}
    local MAXP = SP.max

    local function defaults()
        local d = { on = true, preview = false, size = 60, thick = 5, gap = 3, spacing = 16, x = -560, y = 330,
                 horizontal = false, showRes = true, showCast = true, showName = true, showRole = true, showSpec = true,
                 tsize = 13, nsize = 12, hcolor = "class", hr = 0.3, hg = 0.8, hb = 0.4,
                 showPct = true, showMax = false, showCur = false, msize = 10, csize = 9, bg = 60, start = 0, cw = true }
        for k, v in pairs(SP.defaults or {}) do d[k] = v end
        return d
    end

    local function isSecret(v) return issecretvalue and issecretvalue(v) end

    local PREVIEW = {
        { name = "Brightfang", class = "WARRIOR", role = "TANK",    hp = 1.0,  res = 0.8,  rc = { 0.8, 0.2, 0.2 }, icon = "Interface\\Icons\\Ability_Warrior_DefensiveStance" },
        { name = "Solenne",    class = "PRIEST",  role = "HEALER",  hp = 0.62, res = 0.45, rc = { 0.3, 0.5, 1 },   icon = "Interface\\Icons\\Spell_Holy_PowerWordShield", cast = 0.55 },
        { name = "Kaldrith",   class = "MAGE",    role = "DAMAGER", hp = 0.2,  res = 0.9,  rc = { 0.3, 0.5, 1 },   icon = "Interface\\Icons\\Spell_Frost_FrostBolt02" },
        { name = "Torvek",     class = "HUNTER",  role = "DAMAGER", hp = 0,    res = 0,    rc = { 0.3, 0.5, 1 },   icon = "Interface\\Icons\\Ability_Hunter_FocusedAim", dead = true },
    }

    local ROLE_COORDS = {
        TANK = { 0, 19 / 64, 22 / 64, 41 / 64 },
        HEALER = { 20 / 64, 39 / 64, 1 / 64, 20 / 64 },
        DAMAGER = { 20 / 64, 39 / 64, 22 / 64, 41 / 64 },
    }

    ----------------------------------------------------------------------
    -- A radial ring (used for the resource and the cast).
    ----------------------------------------------------------------------
    local function newRingBar(parent)
        local f = CreateFrame("Frame", nil, parent)
        f:SetPoint("CENTER")
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
        f.ready = false
        local mode = Enum and Enum.StatusBarRenderMode and Enum.StatusBarRenderMode.Radial
        if mode and bar.SetRenderMode then
            f.ready = pcall(function()
                bar:SetRenderMode(mode)
                f.tex:ClearAllPoints()
                f.tex:SetAllPoints(bar)
                f.tex:SetRadialProgressBarStartOffset(0)
                f.tex:SetRadialProgressBarEndOffset(0)
                f.tex:SetRadialProgressBarFeather(0)
                bar:SetMinMaxValues(0, 1)
                bar:SetValue(0)
            end)
        end
        return f
    end

    local function layoutRingBar(f, outer, thick)
        local inner = math.max(1, outer - thick)
        f:SetSize(outer * 2, outer * 2)
        f.track:SetSize(outer * 2, outer * 2)
        f.track:SetVertexColor(0, 0, 0, (DB and DB.bg or 60) / 100)
        f.trackHole:ClearAllPoints(); f.trackHole:SetPoint("CENTER", f, "CENTER"); f.trackHole:SetSize(inner * 4, inner * 4)
        f.bar:SetSize(outer * 2, outer * 2)
        f.hole:ClearAllPoints(); f.hole:SetPoint("CENTER", f.bar, "CENTER"); f.hole:SetSize(inner * 4, inner * 4)
        f.tex:ClearAllPoints(); f.tex:SetAllPoints(f.bar)
        pcall(f.tex.SetRotation, f.tex, math.rad(DB and DB.start or 0))
        pcall(f.tex.SetRadialProgressBarReverse, f.tex, not (DB and DB.cw ~= false))
    end

    ----------------------------------------------------------------------
    -- One member slot
    ----------------------------------------------------------------------
    local function newSlot(i)
        local s = CreateFrame("Frame", nil, C)
        s.unit = SP.prefix .. i
        s.index = i
        s.edge = s:CreateTexture(nil, "BACKGROUND", nil, -2)
        s.edge:SetTexture(MEDIA .. "ringdisc.tga")
        s.edge:SetPoint("CENTER")
        s.edge:SetVertexColor(0.17, 0.19, 0.26, 1)
        s.back = s:CreateTexture(nil, "BACKGROUND", nil, -1)
        s.back:SetTexture(MEDIA .. "ringdisc.tga")
        s.back:SetPoint("CENTER")
        s.back:SetVertexColor(0.04, 0.045, 0.06, 0.85)

        s.res = newRingBar(s)
        s.cast = newRingBar(s)
        s.cast:Hide()

        local bar = CreateFrame("StatusBar", nil, s)
        bar:SetPoint("CENTER")
        bar:SetOrientation("VERTICAL")
        bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
        bar:EnableMouse(false)
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(1)
        s.hbar = bar
        s.htex = bar:GetStatusBarTexture()
        s.hmask = bar:CreateMaskTexture()
        s.hmask:SetTexture(MEDIA .. "ringdisc.tga", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        s.hmask:SetPoint("CENTER", bar, "CENTER")
        s.htex:AddMaskTexture(s.hmask)

        if API.skinNew then
            local sh = CreateFrame("Frame", nil, s)
            sh:SetAllPoints(s)
            sh:SetFrameLevel(bar:GetFrameLevel() + 3)
            s.skinR = API.skinNew(sh, "OVERLAY", 1)
            s.skinH = API.skinNew(sh, "OVERLAY", 3)
        end
        local tf = CreateFrame("Frame", nil, s)
        tf:SetAllPoints(s)
        tf:SetFrameLevel(bar:GetFrameLevel() + 6)
        s.tf = tf

        s.pct = tf:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        API.shade(s.pct, nil, nil, "uf")
        s.pct:SetTextColor(1, 1, 1, 1)

        s.max = tf:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        s.cur = tf:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        for _, fs in ipairs({ s.max, s.cur }) do
            API.shade(fs, nil, nil, "uf")
            fs:SetTextColor(1, 1, 1, 1)
        end

        s.specBack = tf:CreateTexture(nil, "ARTWORK", nil, 0)
        s.specBack:SetTexture(MEDIA .. "ringdisc.tga")
        s.specBack:SetVertexColor(0, 0, 0, 0.8)
        s.spec = tf:CreateTexture(nil, "ARTWORK", nil, 1)
        s.specMask = tf:CreateMaskTexture()
        s.specMask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        s.spec:AddMaskTexture(s.specMask)

        local rf = CreateFrame("Frame", nil, s)
        rf:SetFrameLevel(tf:GetFrameLevel() + 2)
        s.roleF = rf
        s.roleBack = rf:CreateTexture(nil, "BACKGROUND")
        s.roleBack:SetTexture(MEDIA .. "ringdisc.tga")
        s.roleBack:SetPoint("CENTER")
        s.roleBack:SetVertexColor(0.04, 0.045, 0.07, 1)
        s.roleEdge = rf:CreateTexture(nil, "BACKGROUND", nil, -1)
        s.roleEdge:SetTexture(MEDIA .. "ringdisc.tga")
        s.roleEdge:SetPoint("CENTER")
        s.roleEdge:SetVertexColor(0.17, 0.19, 0.26, 1)
        s.role = rf:CreateTexture(nil, "ARTWORK")
        s.role:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES")
        s.role:SetPoint("CENTER")

        s.name = tf:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        API.shade(s.name, nil, nil, "uf")
        s.name:SetWordWrap(false)

        -- The click target: its own secure button, so it works and follows the unit during combat.
        local b = CreateFrame("Button", SP.click .. i, UIParent, "SecureUnitButtonTemplate")
        b:SetFrameStrata("LOW")
        b:SetAttribute("unit", s.unit)
        b:SetAttribute("*type1", "target")
        b:SetAttribute("*type2", "togglemenu")
        b:RegisterForClicks("AnyUp")
        b:SetScript("OnEnter", function(self)
            C.ubermocHover = true
            if UnitExists(s.unit) then
                GameTooltip_SetDefaultAnchor(GameTooltip, self)
                GameTooltip:SetUnit(s.unit)
                GameTooltip:Show()
            end
        end)
        b:SetScript("OnLeave", function() C.ubermocHover = false; GameTooltip:Hide() end)
        b:Hide()
        s.click = b
        s:Hide()
        return s
    end

    ----------------------------------------------------------------------
    -- Layout
    ----------------------------------------------------------------------
    local pendingLayout = false
    -- The member frames are made the first time they are needed (a group, or the preview), not at login:
    -- a raid's forty frames cost memory for players who are never in one.
    local built = false
    local function wanted()
        if not DB or not DB.on then return false end
        if DB.preview then return true end
        local ok, inGroup = pcall(SP.key == "raid" and IsInRaid or IsInGroup)
        return ok and inGroup and true or false
    end
    local function ensureSlots()
        if built or not C or InCombatLockdown() or not wanted() then return built end
        built = true
        for i = 1, MAXP do slots[i] = newSlot(i) end
        return true
    end

    local layout
    API.partyLayouts = API.partyLayouts or {}
    API.partyLayouts[#API.partyLayouts + 1] = function() if layout then pcall(layout) end end
    layout = function()
        if not C or not DB then return end
        ensureSlots()
        local D = DB.size
        local r = D / 2
        local I = r + DB.gap
        local O = I + DB.thick
        local Cc = O + 5
        local S = Cc * 2
        local font = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
        local nameW = 100
        -- Members run along a line (a column, or a row); each group of S.per members starts a new line.
        local per = math.min(SP.per or MAXP, MAXP)
        local lines = math.ceil(MAXP / per)
        local cellW = math.max(S, DB.showName and nameW or S)
        local along, across
        if DB.horizontal then
            along = cellW + DB.spacing
            across = S + (DB.showName and 18 or 0) + DB.spacing
        else
            along = S + DB.spacing
            across = S + (DB.showName and (nameW + 8) or 0) + DB.spacing
        end
        local totalW = DB.horizontal and (along * (per - 1) + cellW) or (across * (lines - 1) + S + (DB.showName and (nameW + 8) or 0))
        local totalH = DB.horizontal and (across * (lines - 1) + S + (DB.showName and 18 or 0)) or (along * (per - 1) + S)
        C:ClearAllPoints()
        C:SetPoint("TOPLEFT", UIParent, "CENTER", DB.x, DB.y)
        C:SetSize(totalW, totalH)
        local combat = InCombatLockdown()
        local eOn, eSz, eR, eG, eB, eA = API.borderOf("partyRim")
        local rOn, rSz, rR, rG, rB, rA = API.borderOf("partyRole")
        for i, s in ipairs(slots) do
            local pos, line = (i - 1) % per, math.floor((i - 1) / per)
            local ox, oy
            if DB.horizontal then
                ox = pos * along + (cellW - S) / 2
                oy = -line * across
            else
                ox = line * across
                oy = -pos * along
            end
            s:SetSize(S, S)
            s:ClearAllPoints()
            s:SetPoint("TOPLEFT", C, "TOPLEFT", ox, oy)
            s.edge:SetSize(D + 2 * eSz, D + 2 * eSz)
            s.edge:SetVertexColor(eR, eG, eB, eA)
            s.edge:SetShown(eOn)
            s.back:SetSize(D, D)
            s.back:SetVertexColor(0.04, 0.045, 0.06, (DB.bg or 60) / 100)
            s.hbar:SetSize(D, D)
            s.hmask:SetSize(D, D)
            layoutRingBar(s.res, O, DB.thick)
            layoutRingBar(s.cast, Cc, 3)
            s.res:SetShown(DB.showRes and true or false)
            if s.skinR then
                API.skinLayout(s.skinR, "party", s, O, I, O)
                API.skinShow(s.skinR, DB.showRes and true or false)
                API.skinLayout(s.skinH, "party", s, r, 0, O)
            end
            local hasSpec = DB.showSpec
            local sp = math.max(12, math.floor(D * 0.3))
            s.spec:SetSize(sp, sp); s.specMask:SetSize(sp, sp)
            s.spec:ClearAllPoints(); s.spec:SetPoint("CENTER", s, "CENTER", 0, D * 0.17)
            s.specMask:ClearAllPoints(); s.specMask:SetPoint("CENTER", s.spec, "CENTER")
            s.specBack:SetSize(sp + 3, sp + 3)
            s.specBack:ClearAllPoints(); s.specBack:SetPoint("CENTER", s.spec, "CENTER")
            s.hasSpecRoom = hasSpec
            API.shade(s.pct, font, DB.tsize, "uf", true)
            API.shade(s.max, font, DB.msize or 10, "uf", true)
            API.shade(s.cur, font, DB.csize or 9, "uf", true)
            local B = math.max(14, math.floor(D * 0.3))
            s.roleF:SetSize(B, B)
            s.roleF:ClearAllPoints()
            s.roleF:SetPoint("CENTER", s, "CENTER", 0, (I + O) / 2)
            s.roleBack:SetSize(B, B)
            s.roleEdge:SetSize(B + 2 * rSz, B + 2 * rSz)
            s.roleEdge:SetVertexColor(rR, rG, rB, rA)
            s.roleEdge:SetShown(rOn)
            s.role:SetSize(B - 4, B - 4)
            API.shade(s.name, font, DB.nsize, "uf")
            s.name:ClearAllPoints()
            if DB.horizontal then
                s.name:SetWidth(nameW)
                s.name:SetPoint("TOP", s, "BOTTOM", 0, -2)
                s.name:SetJustifyH("CENTER")
            else
                s.name:SetWidth(nameW)
                s.name:SetPoint("LEFT", s, "RIGHT", 8, 0)
                s.name:SetJustifyH("LEFT")
            end
            s.name:SetShown(DB.showName and true or false)
            if not combat then
                local b = s.click
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", UIParent, "CENTER", DB.x + ox, DB.y + oy)
                b:SetSize(S, S)
                if DB.on then
                    RegisterStateDriver(b, "visibility", (SP.driverPrefix and SP.driverPrefix() or "") .. "[@" .. s.unit .. ",exists] show; hide")
                else
                    UnregisterStateDriver(b, "visibility")
                    b:Hide()
                end
            end
        end
        if combat then pendingLayout = true end
        C:SetShown(DB.on and true or false)
    end

    ----------------------------------------------------------------------
    -- Spec lookup: the game only tells us another player's spec when we inspect them, so members are
    -- inspected one at a time while out of combat and the result is remembered.
    ----------------------------------------------------------------------
    local specCache = {}
    local inspectGuid, inspectUnit, inspectAt

    local function specIconFor(unit)
        local ok, guid = pcall(UnitGUID, unit)
        if not ok or not guid or isSecret(guid) then return nil end
        local id = specCache[guid]
        if not id then return nil end
        local ok2, _, _, _, icon = pcall(GetSpecializationInfoByID, id)
        return ok2 and icon or nil
    end

    local function inspectStep()
        if InCombatLockdown() or not DB.on or not DB.showSpec then return end
        if InspectFrame and InspectFrame:IsShown() then return end
        local now = GetTime()
        if inspectGuid and inspectAt and now - inspectAt < 4 then return end
        inspectGuid = nil
        for i = 1, MAXP do
            local u = SP.prefix .. i
            if UnitExists(u) and UnitIsConnected(u) then
                local ok, guid = pcall(UnitGUID, u)
                if ok and guid and not isSecret(guid) and not specCache[guid] and CanInspect(u) then
                    inspectGuid, inspectUnit, inspectAt = guid, u, now
                    pcall(NotifyInspect, u)
                    return
                end
            end
        end
    end

    ----------------------------------------------------------------------
    -- Live values
    ----------------------------------------------------------------------
    local function classColor(cls)
        local c = cls and RAID_CLASS_COLORS and RAID_CLASS_COLORS[cls]
        if c then return c.r, c.g, c.b end
        return 0.6, 0.6, 0.6
    end

    -- Health colour: class colour, a colour of your own, or red to green by health.
    local healthCurves
    local function buildCurves()
        if healthCurves or not (C_CurveUtil and C_CurveUtil.CreateCurve and Enum and Enum.LuaCurveType) then return end
        local stops = { { 0, 0.90, 0.15, 0.10 }, { 0.5, 0.95, 0.80, 0.10 }, { 1, 0.25, 0.85, 0.25 } }
        local ok, res = pcall(function()
            local out = {}
            for ch = 1, 3 do
                local cv = C_CurveUtil.CreateCurve()
                cv:SetType(Enum.LuaCurveType.Linear)
                for _, st in ipairs(stops) do cv:AddPoint(st[1], st[ch + 1]) end
                out[ch] = cv
            end
            return out
        end)
        if ok then healthCurves = res end
    end

    local function gradientAt(f)
        if f < 0.5 then
            local t = f / 0.5
            return 0.90 + (0.95 - 0.90) * t, 0.15 + (0.80 - 0.15) * t, 0.10
        end
        local t = (f - 0.5) / 0.5
        return 0.95 + (0.25 - 0.95) * t, 0.80 + (0.85 - 0.80) * t, 0.10 + (0.25 - 0.10) * t
    end

    local function colorHealth(s, unit, cr, cg, cb, frac)
        local mode = DB.hcolor or "class"
        if mode == "custom" then
            s.htex:SetVertexColor(DB.hr or 0.3, DB.hg or 0.8, DB.hb or 0.4)
        elseif mode == "gradient" then
            if unit and healthCurves and UnitHealthPercent then
                s.htex:SetVertexColor(UnitHealthPercent(unit, false, healthCurves[1]),
                                      UnitHealthPercent(unit, false, healthCurves[2]),
                                      UnitHealthPercent(unit, false, healthCurves[3]))
            else
                local gr, gg, gb = gradientAt(frac or 1)
                s.htex:SetVertexColor(gr, gg, gb)
            end
        else
            s.htex:SetVertexColor(cr, cg, cb)
        end
    end

    local function setPct(s, text)
        s.pct:SetText(text)
    end

    local function showExtras(s, role, icon)
        if DB.showRole and role and ROLE_COORDS[role] then
            local c = ROLE_COORDS[role]
            s.role:SetTexCoord(c[1], c[2], c[3], c[4])
            s.roleF:Show()
        else
            s.roleF:Hide()
        end
        local hasIcon = DB.showSpec and icon
        if hasIcon then
            s.spec:SetTexture(icon)
            s.spec:Show(); s.specBack:Show()
        else
            s.spec:Hide(); s.specBack:Hide()
        end
        -- Text lines in the disc: percentage, maximum, current; each can be switched off.
        -- Placed again only when something about them changed (this runs many times a second).
        local hp, hm, hc = DB.showPct ~= false, DB.showMax and true or false, DB.showCur and true or false
        local tp, tm, tc = (DB.tsize or 13) * 1.2, (DB.msize or 10) * 1.2, (DB.csize or 9) * 1.2
        local base = hasIcon and -(DB.size * 0.14) or 0
        local L = s.textLayout
        if not L then L = {}; s.textLayout = L end
        if L.hp == hp and L.hm == hm and L.hc == hc and L.tp == tp and L.tm == tm and L.tc == tc and L.base == base then return end
        L.hp, L.hm, L.hc, L.tp, L.tm, L.tc, L.base = hp, hm, hc, tp, tm, tc, base
        local total = (hp and tp or 0) + (hm and tm or 0) + (hc and tc or 0)
        local y = base + total / 2
        local function put(fs, show, h)
            if not show then fs:Hide(); return end
            fs:ClearAllPoints()
            fs:SetPoint("CENTER", s, "CENTER", 0, y - h / 2)
            fs:Show()
            y = y - h
        end
        put(s.pct, hp, tp); put(s.max, hm, tm); put(s.cur, hc, tc)
    end

    local function updatePreview(s, d)
        s:Show()
        s:SetAlpha(1)
        local r, g, b = classColor(d.class)
        s.hbar:SetMinMaxValues(0, 1)
        s.hbar:SetValue(d.hp)
        colorHealth(s, nil, r, g, b, d.hp)
        setPct(s, d.dead and "DEAD" or (math.floor(d.hp * 100 + 0.5) .. "%"))
        s.max:SetText("52000")
        s.cur:SetText(math.floor(d.hp * 52000 + 0.5))
        if s.res.ready then
            s.res.bar:SetMinMaxValues(0, 1)
            s.res.bar:SetValue(d.res)
            s.res.tex:SetVertexColor(d.rc[1], d.rc[2], d.rc[3])
        end
        if DB.showCast and d.cast and s.cast.ready then
            s.cast.bar:SetMinMaxValues(0, 1)
            s.cast.bar:SetValue(d.cast)
            s.cast.tex:SetVertexColor(1, 0.82, 0.2)
            s.cast:Show()
        else
            s.cast:Hide()
        end
        s.name:SetText(d.name)
        s.name:SetTextColor(r, g, b)
        showExtras(s, d.role, d.icon)
    end

    local function castBody(s)
            local u = s.unit
            local name, _, _, st, en = UnitCastingInfo(u)
            local channel = false
            if name == nil then
                name, _, _, st, en = UnitChannelInfo(u)
                channel = true
            end
            if name == nil then s.cast:Hide() return end
            s.cast.bar:SetMinMaxValues(st, en)
            s.cast.bar:SetValue(GetTime() * 1000)
            s.cast.tex:SetVertexColor(1, 0.82, 0.2)
            s.cast:Show()
    end
    local function updateCast(s)
        if not pcall(castBody, s) then s.cast:Hide() end
    end

    local function updateReal(s)
        local u = s.unit
        if not UnitExists(u) then s:Hide(); s.slowT = nil; return end
        s:Show()
        -- What changes slowly (class colour, name, role, spec, the maximum) is read once a second; health,
        -- power, casts and range every update.
        local now = GetTime()
        local slow = not s.slowT or now - s.slowT >= 1
        if slow then
            s.slowT = now
            local _, cls = UnitClass(u)
            s.cr, s.cg, s.cb = classColor(cls)
        end
        local r, g, b = s.cr, s.cg, s.cb
        local connected = UnitIsConnected(u)
        local dead = UnitIsDeadOrGhost(u)
        s.hbar:SetMinMaxValues(0, UnitHealthMax(u))
        s.hbar:SetValue(UnitHealth(u))
        colorHealth(s, u, r, g, b, 1)
        if slow then s.max:SetFormattedText("%d", UnitHealthMax(u)) end
        s.cur:SetFormattedText("%d", UnitHealth(u))
        if not connected then
            setPct(s, "OFF")
        elseif dead then
            setPct(s, "DEAD")
        elseif CurveConstants and CurveConstants.ScaleTo100 and UnitHealthPercent then
            s.pct:SetFormattedText("%.0f%%", UnitHealthPercent(u, false, CurveConstants.ScaleTo100))
        end
        local alpha = 1
        if not connected then
            alpha = 0.4
        else
            local okr, inRange = pcall(UnitInRange, u)
            if okr and not isSecret(inRange) and inRange == false then alpha = 0.5 end
        end
        s:SetAlpha(alpha)
        if DB.showRes and s.res.ready then
            local okp, pt = pcall(UnitPowerType, u)
            if okp and not isSecret(pt) and type(pt) == "number" then
                s.res.bar:SetMinMaxValues(0, UnitPowerMax(u, pt))
                s.res.bar:SetValue(UnitPower(u, pt))
                local c = PowerBarColor and (PowerBarColor[pt] or PowerBarColor["MANA"])
                if c then s.res.tex:SetVertexColor(c.r, c.g, c.b) else s.res.tex:SetVertexColor(0.3, 0.5, 1) end
            end
        end
        if DB.showCast and s.cast.ready then updateCast(s) else s.cast:Hide() end
        if slow then
            pcall(s.name.SetText, s.name, (UnitName(u)))
            s.name:SetTextColor(r, g, b)
            local role
            local okro, ro = pcall(UnitGroupRolesAssigned, u)
            if okro and not isSecret(ro) then role = ro end
            showExtras(s, role, specIconFor(u))
        end
    end

    local acc, inspAcc, fullAcc = 0, 0, 1
    -- Units whose health, power, cast or state changed since the last update (from the game's events).
    -- Only those are drawn again, plus anyone casting; everyone is looked at twice a second for range.
    local dirty = {}
    local function tick(_, dt)
        acc = acc + dt
        if acc < 0.08 then return end
        inspAcc = inspAcc + acc
        fullAcc = fullAcc + acc
        acc = 0
        if not DB or not DB.on then return end
        if pendingLayout and not InCombatLockdown() then pendingLayout = false; layout() end
        if not built then
            if not InCombatLockdown() and wanted() then layout() end
            if not built then return end
        end
        local anyReal = false
        for i = 1, MAXP do if UnitExists(SP.prefix .. i) then anyReal = true; break end end
        if SP.yield and SP.yield() then
            for _, s in ipairs(slots) do s:Hide() end
            return
        end
        local preview = DB.preview and not anyReal
        local full = fullAcc >= 0.5
        if full then fullAcc = 0 end
        for i, s in ipairs(slots) do
            if preview and i <= (SP.previewCount or MAXP) then
                if full then pcall(updatePreview, s, PREVIEW[(i - 1) % #PREVIEW + 1]) end
            elseif preview then
                s:Hide()
            elseif full or dirty[s.unit] or (s.cast and s.cast:IsShown()) or not s:IsShown() then
                pcall(updateReal, s)
            end
        end
        wipe(dirty)
        if inspAcc > 1.5 then inspAcc = 0; pcall(inspectStep) end
    end

    ----------------------------------------------------------------------
    -- Settings page
    ----------------------------------------------------------------------
    local function px(v) return math.floor(v + 0.5) .. " px" end

    local function buildPage()
        local panel = CreateFrame("Frame")
        local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 8, -8)
        scroll:SetPoint("BOTTOMRIGHT", -30, 8)
        local p = CreateFrame("Frame", nil, scroll)
        p:SetSize(600, 1090)
        scroll:SetScrollChild(p)
        API.newLabel(p, SP.label, 16, -14, "GameFontNormalHuge")
        API.newLockButton(p, 400, -14)
        local intro = API.newLabel(p, SP.intro, 16, -48, "GameFontHighlightSmall")
        intro:SetWidth(570); intro:SetJustifyH("LEFT"); intro:SetWordWrap(true)

        local checks, sliders = {}, {}
        local function check(text, y, key)
            checks[key] = API.newCheck(p, text, 16, y, function(v)
                DB[key] = v
                if key == "on" and API.haloTurnedOn then pcall(API.haloTurnedOn, SP.key, v) end
                layout()
                -- the party frames step aside in a raid while the raid frames are on
                if key == "on" then
                    for _, f in pairs(API.groupLayouts or {}) do if f ~= layout then pcall(f) end end
                    if API.evaluate then API.evaluate() end
                end
            end)
        end
        local function slider(text, y, min, max, step, fmt, key)
            API.newLabel(p, text, 40, y)
            local s = API.makeSlider(p, 150, min, max, step, fmt, function(v) DB[key] = v; layout() end)
            s:SetPoint("TOPLEFT", 260, y)
            sliders[key] = s
        end
        check("Show the " .. SP.what .. " halo frames", -120, "on")
        check("Preview with sample members (while you are not in a " .. (SP.key == "raid" and "raid" or "group") .. ")", -152, "preview")
        check("Lay out in a row instead of a column", -184, "horizontal")
        check("Resource ring", -226, "showRes")
        check("Cast ring", -258, "showCast")
        check("Role badge (top centre)", -290, "showRole")
        check("Spec icon (above the percentage)", -322, "showSpec")
        check("Name", -354, "showName")
        slider("Disc size", -406, 20, 120, 1, px, "size")
        slider("Resource ring thickness", -438, 2, 14, 1, px, "thick")
        slider("Gap", -470, 0, 500, 1, px, "gap")
        slider("Spacing", -502, 0, 500, 1, px, "spacing")
        slider("Percentage size", -534, 8, 24, 1, px, "tsize")
        slider("Name size", -566, 8, 20, 1, px, "nsize")
        slider("Left / right", -614, -1200, 1200, 1, px, "x")
        slider("Up / down", -646, -700, 700, 1, px, "y")

        API.newLabel(p, "Health text and colour", 16, -690, "GameFontNormal")
        check("Show health percentage", -716, "showPct")
        check("Show maximum health", -748, "showMax")
        check("Show current health", -780, "showCur")
        check("Rings fill clockwise", -812, "cw")
        slider("Maximum health size", -858, 6, 30, 1, px, "msize")
        slider("Current health size", -890, 6, 30, 1, px, "csize")
        slider("Background darkness", -922, 0, 100, 5, function(v) return math.floor(v + 0.5) .. "%" end, "bg")
        slider("Ring start angle", -954, 0, 355, 5, function(v) return math.floor(v + 0.5) .. " deg" end, "start")
        API.newLabel(p, "Health colour", 40, -998)
        local swatch
        local hbtn = API.segRow(p, 208, -994, { { "class", "Class", 56 }, { "custom", "Custom", 62 }, { "gradient", "Red-green", 80 } },
            function() return DB.hcolor or "class" end, function(v) DB.hcolor = v; layout() end)
        local swb = CreateFrame("Button", nil, p)
        swb:SetSize(26, 26)
        swb:SetPoint("TOPLEFT", 430, -994)
        API.flatButton(swb)
        swatch = swb:CreateTexture(nil, "ARTWORK")
        swatch:SetPoint("TOPLEFT", 4, -4); swatch:SetPoint("BOTTOMRIGHT", -4, 4)
        swb:SetScript("OnClick", function()
            DB.hcolor = "custom"
            hbtn.refresh()
            local pr, pg, pb = DB.hr, DB.hg, DB.hb
            local function apply()
                local r, g, b = ColorPickerFrame:GetColorRGB()
                DB.hr, DB.hg, DB.hb = r, g, b
                swatch:SetColorTexture(r, g, b, 1)
            end
            if ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow then
                ColorPickerFrame:SetupColorPickerAndShow({
                    r = DB.hr, g = DB.hg, b = DB.hb, hasOpacity = false, swatchFunc = apply,
                    cancelFunc = function() DB.hr, DB.hg, DB.hb = pr, pg, pb; swatch:SetColorTexture(pr, pg, pb, 1) end,
                })
            end
        end)

        API.ufShadowSlider(p, -1038)
        API.makeTabs(panel, scroll, p, { { "Frame", 0 }, { "Size & Position", -400 }, { "Health", -684 } })
        panel:SetScript("OnShow", function()
            for k, cb in pairs(checks) do cb:SetChecked(DB[k] and true or false) end
            for k, s in pairs(sliders) do API.setSlider(s, DB[k]) end
            hbtn.refresh()
            swatch:SetColorTexture(DB.hr or 0.3, DB.hg or 0.8, DB.hb or 0.4, 1)
        end)
        panel.name = SP.label
        API.addPage(SP.page, SP.label, panel)
        API.resetters[SP.page] = function()
            for k in pairs(DB) do DB[k] = nil end
            for k, v in pairs(defaults()) do DB[k] = v end
            layout()
        end
    end

    local prev = API.onLogin
    API.onLogin = function()
        if prev then prev() end
        UbermocUIDB[SP.key] = UbermocUIDB[SP.key] or {}
        DB = UbermocUIDB[SP.key]
        for k, v in pairs(defaults()) do if DB[k] == nil then DB[k] = v end end
        -- One time: frames still at the old default place move up and out, clear of the halo frames.
        if not DB.posV1 then
            DB.posV1 = true
            if SP.key == "party" and DB.x == -560 and DB.y == 120 then DB.y = 330 end
            if SP.key == "raid" and DB.x == -560 and DB.y == 260 then DB.x, DB.y = -670, 330; if DB.size == 38 then DB.size = 28 end end
        end
        -- Raid frames are the game's own unless you switch these on (one time, for settings from before).
        buildCurves()
        API.registerMover(SP.mover, function()
            local w, h = C and C:GetSize()
            w, h = w or 100, h or 100
            return DB.on, DB.x + w / 2, DB.y - h / 2, w, h
        end, function(x, y)
            local w, h = C:GetSize()
            DB.x, DB.y = math.floor(x - w / 2 + 0.5), math.floor(y + h / 2 + 0.5)
            layout()
        end)
        C = CreateFrame("Frame", SP.hud, UIParent)
        C:SetFrameStrata("LOW")
        C:EnableMouse(false)
        C:SetSize(10, 10)
        local ev = CreateFrame("Frame")
        ev:RegisterEvent("INSPECT_READY")
        ev:RegisterEvent("PLAYER_REGEN_ENABLED")
        ev:RegisterEvent("GROUP_ROSTER_UPDATE")
        ev:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
        for _, e in ipairs({ "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER",
                             "UNIT_CONNECTION", "UNIT_FLAGS", "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_CHANNEL_START",
                             "UNIT_SPELLCAST_EMPOWER_START", "UNIT_NAME_UPDATE" }) do
            pcall(ev.RegisterEvent, ev, e)
        end
        local PRE = SP.prefix
        ev:SetScript("OnEvent", function(_, event, arg)
            -- unit events: just note the unit (they come many times a second in a fight)
            if type(arg) == "string" and event:find("^UNIT_") then
                if arg:find(PRE, 1, true) == 1 then dirty[arg] = true end
                return
            end
            if event == "INSPECT_READY" then
                if inspectGuid and arg == inspectGuid and inspectUnit then
                    local ok, id = pcall(GetInspectSpecialization, inspectUnit)
                    if ok and type(id) == "number" and id > 0 then specCache[inspectGuid] = id end
                    pcall(ClearInspectPlayer)
                    inspectGuid = nil
                end
            elseif event == "PLAYER_REGEN_ENABLED" then
                if pendingLayout then pendingLayout = false; layout() end
            elseif event == "GROUP_ROSTER_UPDATE" then
                -- someone joined, left or moved: names, colours and roles are read again at once
                for _, s in ipairs(slots) do s.slowT = nil end
            elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
                local ok, guid = pcall(UnitGUID, arg or "")
                if ok and guid and not isSecret(guid) then specCache[guid] = nil end
            end
        end)
        C:SetScript("OnUpdate", tick)
        API.groupLayouts = API.groupLayouts or {}
        API.groupLayouts[SP.key] = layout
        API.groupDBs = API.groupDBs or {}
        API.groupDBs[SP.key] = DB
        layout()
        API.later(SP.label, buildPage)
    end

end

-- Party and raid halo frames switched on or off from elsewhere (the Floating Unit Frames page picks the design).
API.groupOn = function(key) local d = API.groupDBs and API.groupDBs[key]; return d and d.on and true or false end
API.groupSet = function(key, on)
    local d = API.groupDBs and API.groupDBs[key]
    if not d then return end
    d.on = on and true or false
    for _, f in pairs(API.groupLayouts or {}) do pcall(f) end
    if API.evaluate then pcall(API.evaluate) end
end

Group({ key = "party", page = "party", label = "Party Halo Frames", what = "party", prefix = "party", max = 4, per = 4,
    click = "UbermocPartyClick", hud = "UbermocPartyHUD", mover = "Party halo frames", previewCount = 4,
    -- in a raid with the raid frames on, the raid frames take over
    yield = function() return IsInRaid and IsInRaid() and UbermocUIDB.raid and UbermocUIDB.raid.on end,
    driverPrefix = function() return (UbermocUIDB.raid and UbermocUIDB.raid.on) and "[group:raid] hide; " or "" end,
    intro = "A round frame for each party member: a health disc (class colour, your own colour or red to green) with the health numbers inside, the resource in a ring around it, cast progress on a thin outer ring, a role badge on top and the spec icon above the percentage. Left-click targets, right-click opens the menu. In a raid the raid frames take over while they are on. Fade it from Fading > Rules > Party Halo Frames (Ubermoc UI)." })

Group({ key = "raid", page = "raid", label = "Raid Halo Frames", what = "raid", prefix = "raid", max = 40, per = 5,
    click = "UbermocRaidClick", hud = "UbermocRaidHUD", mover = "Raid halo frames", previewCount = 20,
    defaults = { on = true, size = 28, thick = 4, gap = 2, spacing = 6, x = -670, y = 330, showName = false, showSpec = false,
                 tsize = 10, nsize = 10, horizontal = true },
    intro = "The same round frames for the whole raid, five to a row (one row per raid group). Each shows health, resource, casts and the role badge; names and spec icons are off by default to keep them small. Left-click targets, right-click opens the menu. Hide WoW's own raid frames from Fading > Rules > Party / raid frames (Always hide), and fade these from Fading > Rules > Raid Halo Frames (Ubermoc UI)." })
