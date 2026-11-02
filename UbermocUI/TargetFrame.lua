-- Ubermoc UI - Copyright (c) 2026 Marcos. All rights reserved.
-- This file is protected by copyright. It may not be copied, modified, redistributed or reused, in whole or
-- in part, without the written permission of the author. See LICENSE.txt.
----------------------------------------------------------------------
-- Ubermoc UI: Floating Unit Frames
-- A small frame (round portrait or class icon, name, health and resource bars with text, a cast bar, crowd
-- control over the portrait, buffs and debuffs) that hangs over your target, focus, target of target and
-- focus target and moves with them. It rides on the unit's nameplate (which it hides).
-- The same design can also be used for your own player frame and the party frames, which stay in one
-- place on the screen (each can be the halo frame, this style, or the game's own).
----------------------------------------------------------------------
local API = UbermocUIAPI
if not API then return end

local UNITS = { "target", "focus", "targettarget", "focustarget" }   -- over the unit's head
local layVer = 0   -- raised when a setting changes: every frame is laid out again on its next update
local FIXED = { "player", "pet", "party1", "party2", "party3", "party4" }   -- in one place on the screen
local MAXRAID = 40

local function defaults()
    return {
        enemy = true, friendly = true, hidePlate = true,
        uTarget = true, uFocus = true, uToT = true, uFoT = true,
        sTarget = 100, sFocus = 90, sToT = 75, sFoT = 75,
        portrait = true, classIcon = true, power = true, rareBorder = true, rareSize = 100, rareX = 0, rareY = 0,
        width = 150, y = 4, nameSize = 12,
        hpText = "percent", powText = "percent", textSize = 10, powTextSize = 8, powH = 8,
        barRound = "medium", barGap = 4, skinTex = { tex = "none", texA = 50 },
        resOn = true, resShape = "dots", resSize = 10, resGap = 4, resX = 0, resY = 0, resAlign = "center", resCombo = "target", resEmpty = true,
        cast = true, castIcon = true, castName = true, castTime = "both", castTextSize = 10,
        cc = true,
        debuffs = true, debuffMine = true, buffs = true, buffMine = false,
        debuffOnlyMine = false, debuffBoss = false, debuffMaxMin = 0, buffOnlyMine = false, buffStealable = false, buffMaxMin = 0,
        debuffSize = 20, debuffMax = 6, debuffPos = "below", debuffX = 0, debuffY = 3,
        buffSize = 18, buffMax = 6, buffPos = "above", buffX = 0, buffY = 3,
        auraTimeSize = 100, auraTimeX = 0, auraTimeY = 0, raidAuraTimeSize = 100, raidAuraTimeX = 0, raidAuraTimeY = 0,
        -- player and party frames in this style
        playerFloat = true, partyFloat = true, petFloat = true, raidFloat = true,
        classColour = true, partyRole = true, partyPreview = false,
        sPlayer = 110, sParty = 90, sPet = 90, sRaid = 80,
        pX = -280, pY = -160, petX = -280, petY = -225, partyX = -560, partyY = 330, partyGap = 14,
        -- raid frames: a smaller design of their own
        raidX = -670, raidY = 330, raidGap = 6, raidPer = 5, raidPreview = false, raidRole = true,
        raidWidth = 90, raidPortrait = false, raidPower = false, raidCast = false, raidCC = true, raidDebuffs = false,
        raidNameSize = 10, raidTextSize = 9,
        raidBuffs = false, raidDebuffSize = 14, raidDebuffMax = 3, raidDebuffPos = "below", raidDebuffX = 0, raidDebuffY = 2,
        raidBuffSize = 14, raidBuffMax = 3, raidBuffPos = "above", raidBuffX = 0, raidBuffY = 2,
    }
end
local filled
local function DB()
    UbermocUIDB = UbermocUIDB or {}
    local d = UbermocUIDB.targetFrame
    if type(d) ~= "table" then d = {}; UbermocUIDB.targetFrame = d end
    if d == filled then return d end
    if d.scale and not d.sTarget then d.sTarget = d.scale end   -- the old single size is the target's size
    if not d.v4 then
        d.v4 = true
        if d.powText == "none" then d.powText = "percent" end   -- the resource text is on by default now
        if d.debuffSize and d.buffSize == nil then d.buffSize = d.debuffSize end
        if d.debuffMax and d.buffMax == nil then d.buffMax = d.debuffMax end
        if d.debuffPos and d.buffPos == nil then d.buffPos = d.debuffPos end
    end
    if not d.v5 then
        d.v5 = true                                  -- each kind of frame gets its own copy of the look you had
        d.look = d.look or {}
        for _, g in ipairs({ "player", "pet", "target", "targettarget", "focus", "focustarget", "party" }) do
            local L = d.look[g] or {}
            d.look[g] = L
            for _, k in ipairs({ "enemy", "friendly", "hidePlate", "y", "portrait", "classIcon", "power", "width", "nameSize", "classColour",
                    "hpText", "powText", "textSize", "cast", "castIcon", "castName", "castTime", "castTextSize", "cc",
                    "debuffs", "debuffMine", "buffs", "buffMine", "debuffSize", "debuffMax", "debuffPos", "debuffX", "debuffY",
                    "buffSize", "buffMax", "buffPos", "buffX", "buffY", "powTextSize", "powH", "auraTimeSize", "auraTimeX", "auraTimeY" }) do
                if L[k] == nil and d[k] ~= nil then L[k] = d[k] end
            end
        end
    end
    if not d.barMediumV1 then
        d.barMediumV1 = true                         -- medium corners are the starting look now: moved once from "off"
        if d.barRound == nil or d.barRound == "off" then d.barRound = "medium" end
    end
    if not d.barUniformV1 then
        d.barUniformV1 = true                        -- bar corners and spacing are one setting for every frame
        for _, L in pairs(d.look or {}) do L.barRound, L.barGap = nil, nil end
    end
    if not d.v6 then
        d.v6 = true                                  -- debuffs below the frame, buffs above, for every kind of frame
        d.debuffPos, d.buffPos = "below", "above"
        for _, L in pairs(d.look or {}) do L.debuffPos, L.buffPos = "below", "above" end
    end
    if not d.v3 then
        d.v3 = true
        d.uPlayer, d.uParty = nil, nil                            -- the frames over yourself and party members are gone
        if d.sPlayer == 90 then d.sPlayer = nil end
        if d.sParty == 75 then d.sParty = nil end
    end
    d.look = d.look or {}
    for k, v in pairs(defaults()) do if d[k] == nil then d[k] = v end end
    if not d.v2 then d.v2 = true; d.enemy, d.friendly = true, true end
    filled = d
    return d
end
API.targetFrameDB = DB
-- True when this unit is drawn in this style, so its halo frame and the game's own frame stay hidden.
API.floatingCovers = function(unit)
    if not UbermocUIDB then return false end
    local d = DB()
    if unit == "target" then return d.uTarget and true or false end
    if unit == "focus" then return d.uFocus and true or false end
    if unit == "targettarget" then return d.uToT and true or false end
    if unit == "focustarget" then return d.uFoT and true or false end
    if unit == "player" then return d.playerFloat and true or false end
    if unit == "pet" then return d.petFloat and true or false end
    if type(unit) == "string" and unit:sub(1, 5) == "party" then return d.partyFloat and true or false end
    if type(unit) == "string" and unit:sub(1, 4) == "raid" then return d.raidFloat and true or false end
    return false
end

local WHITE = "Interface\\Buttons\\WHITE8X8"
local MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local RING = "Interface\\AddOns\\UbermocUI\\Media\\ringdisc.tga"
local CLASSES = "Interface\\TargetingFrame\\UI-Classes-Circles"
local ROLES = "Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES"
local ROLE_COORDS = {
    TANK = { 0, 19 / 64, 22 / 64, 41 / 64 },
    HEALER = { 20 / 64, 39 / 64, 1 / 64, 20 / 64 },
    DAMAGER = { 20 / 64, 39 / 64, 22 / 64, 41 / 64 },
}
local TAN = { 0.48, 0.42, 0.28 }

local function isSecret(v)
    if type(issecretvalue) ~= "function" then return false end
    local ok, r = pcall(issecretvalue, v)
    return ok and r or false
end
local function plain(v) if v == nil or isSecret(v) then return nil end return v end
-- A unit that is part of one of your active quests.
local function isQuestUnit(unit)
    if not unit or not (C_QuestLog and C_QuestLog.UnitIsRelatedToActiveQuest) then return false end
    local ok, r = pcall(C_QuestLog.UnitIsRelatedToActiveQuest, unit)
    return ok and plain(r) == true
end

----------------------------------------------------------------------
-- Building one frame
----------------------------------------------------------------------
local function bar(parent, h)
    local b = {}
    b.rim = parent:CreateTexture(nil, "BACKGROUND", nil, 1)
    b.rim:SetColorTexture(TAN[1], TAN[2], TAN[3], 1)
    b.back = parent:CreateTexture(nil, "BACKGROUND", nil, 2)
    b.back:SetColorTexture(0.04, 0.03, 0.03, 0.95)
    b.sb = CreateFrame("StatusBar", nil, parent)
    b.sb:SetStatusBarTexture(WHITE)
    b.sb:SetHeight(h)
    b.text = b.sb:CreateFontString(nil, "OVERLAY")
    b.text:SetShadowOffset(0, 0)
    b.text:SetPoint("CENTER")
    b.h = h
    return b
end
local function placeBar(b, anchor, x, y, w, h)
    b.h = h or b.h
    b.sb:ClearAllPoints()
    b.sb:SetPoint("TOPLEFT", anchor, "TOPLEFT", x, y)
    b.sb:SetSize(w, b.h)
    b.rim:ClearAllPoints()
    b.rim:SetPoint("TOPLEFT", b.sb, "TOPLEFT", -2, 2)
    b.rim:SetPoint("BOTTOMRIGHT", b.sb, "BOTTOMRIGHT", 2, -2)
    b.back:ClearAllPoints()
    b.back:SetPoint("TOPLEFT", b.sb, "TOPLEFT", -1, 1)
    b.back:SetPoint("BOTTOMRIGHT", b.sb, "BOTTOMRIGHT", 1, -1)
end
local function showBar(b, on)
    b.sb:SetShown(on); b.rim:SetShown(on); b.back:SetShown(on)
end
-- Rounded ends for a bar: one mask each for its fill, its dark back and its rim, all the shape of the bar. The mask pictures
-- are a long bar with round corners (slight, medium, or a full pill), stretched to the bar's size.
local BAR_MASK_PATH = "Interface\\AddOns\\UbermocUI\\Media\\"
local BAR_MASKS = { slight = BAR_MASK_PATH .. "bar_round1.tga", medium = BAR_MASK_PATH .. "bar_round2.tga", round = BAR_MASK_PATH .. "bar_round3.tga" }
local function roundBar(b, level)
    local path = level and BAR_MASKS[level]
    if not path and not b.maskOn then return end
    if not b.masks then
        b.masks = {
            rim = b.rim:GetParent():CreateMaskTexture(),
            back = b.back:GetParent():CreateMaskTexture(),
            sb = b.sb:CreateMaskTexture(),
        }
        b.masks.rim:SetAllPoints(b.rim)
        b.masks.back:SetAllPoints(b.back)
        b.masks.sb:SetAllPoints(b.sb)
    end
    local target = { rim = b.rim, back = b.back, sb = b.sb:GetStatusBarTexture() }
    for k, m in pairs(b.masks) do
        if path then
            m:SetTexture(path, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            if not b.maskOn then target[k]:AddMaskTexture(m) end
        elseif b.maskOn then
            target[k]:RemoveMaskTexture(m)
        end
    end
    b.maskOn = path ~= nil
    if b.pat then
        if path and not b.patMasked then b.pat:AddMaskTexture(b.masks.sb); b.patMasked = true
        elseif not path and b.patMasked then b.pat:RemoveMaskTexture(b.masks.sb); b.patMasked = false end
    end
end
-- The Textures page's pattern over the filled part of a bar (it follows the fill as it grows and shrinks).
local function patBar(b, style, strength)
    if not (style and style ~= "none" and (strength or 0) > 0) then
        if b.pat then b.pat:Hide() end
        return
    end
    if not b.pat then
        b.pat = b.sb:CreateTexture(nil, "ARTWORK", nil, 1)
        b.pat:SetAllPoints(b.sb:GetStatusBarTexture())
        b.pat:SetHorizTile(true); b.pat:SetVertTile(true)
        if b.maskOn and b.masks then b.pat:AddMaskTexture(b.masks.sb); b.patMasked = true end
    end
    if b.patStyle ~= style then
        b.patStyle = style
        b.pat:SetTexture(BAR_MASK_PATH .. "skin_" .. style .. ".tga", "REPEAT", "REPEAT")
    end
    b.pat:SetAlpha(math.min(1, strength / 100))
    b.pat:Show()
end
-- The rim of a bar (its border): thick pixels beyond the bar, one of them hidden under the dark back.
local function rimBar(b, thick, r, g, bl, a)
    b.rim:ClearAllPoints()
    b.rim:SetPoint("TOPLEFT", b.sb, "TOPLEFT", -thick, thick)
    b.rim:SetPoint("BOTTOMRIGHT", b.sb, "BOTTOMRIGHT", thick, -thick)
    b.rim:SetColorTexture(r, g, bl, a)
end
-- Textures and borders from the Textures page (Floating Frames tab): one set for every floating frame.
function API.floatTexDB()
    local d = DB()
    if type(d.skinTex) ~= "table" then d.skinTex = { tex = "none", texA = 50 } end
    return d.skinTex
end
API.registerBorder({ key = "floatBar", part = "floating", label = "Bar borders (health, resource and cast)", on = false, size = 1, maxSize = 6,
    apply = function() if API.targetFrameRefresh then API.targetFrameRefresh() end end })
API.registerBorder({ key = "floatPortrait", part = "floating", label = "Portrait border", on = false, size = 3, maxSize = 6,
    apply = function() if API.targetFrameRefresh then API.targetFrameRefresh() end end })

local function auraIcon(parent, harmful)
    local a = CreateFrame("Frame", nil, parent)
    a.rim = a:CreateTexture(nil, "BACKGROUND")
    a.rim:SetAllPoints()
    if harmful then a.rim:SetColorTexture(0.55, 0.06, 0.06, 1) else a.rim:SetColorTexture(0, 0, 0, 1) end
    a.icon = a:CreateTexture(nil, "ARTWORK")
    a.icon:SetPoint("TOPLEFT", 1, -1); a.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    a.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    a.cd = CreateFrame("Cooldown", nil, a, "CooldownFrameTemplate")
    a.cd:SetAllPoints(a.icon)
    a.cd:SetDrawEdge(false)
    if a.cd.SetHideCountdownNumbers then a.cd:SetHideCountdownNumbers(false) end
    a.count = a:CreateFontString(nil, "OVERLAY")
    a.count:SetPoint("BOTTOMRIGHT", 1, 0)
    a.count:SetShadowOffset(0, 0)
    -- Pointing at it shows the spell's tooltip.
    a:EnableMouse(true)
    if a.SetMouseClickEnabled then a:SetMouseClickEnabled(false) end
    a:SetScript("OnEnter", function(self)
        if not self.unit then return end
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
        local done = false
        if self.inst ~= nil and GameTooltip.SetUnitAuraByAuraInstanceID then
            done = pcall(GameTooltip.SetUnitAuraByAuraInstanceID, GameTooltip, self.unit, self.inst)
        end
        if not done and self.index and GameTooltip.SetUnitAura then
            done = pcall(GameTooltip.SetUnitAura, GameTooltip, self.unit, self.index, self.filter)
        end
        if not done and self.blizz then
            local fn = self.blizz:GetScript("OnEnter")
            if fn then done = pcall(fn, self.blizz) end
            if done then GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT"); pcall(fn, self.blizz) end
        end
        GameTooltip:Show()
    end)
    a:SetScript("OnLeave", function() GameTooltip:Hide() end)
    a:Hide()
    return a
end

local frames, fixedF = {}, {}
local function newFrame(name, level)
    local f = CreateFrame("Frame", name, UIParent)
    f:SetFrameStrata("MEDIUM")
    f:SetFrameLevel(level or 50)
    f:SetSize(150, 46)
    f:EnableMouse(false)
    f:Hide()
    f.ring = f:CreateTexture(nil, "BACKGROUND", nil, 0)
    f.ring:SetTexture(RING)
    f.ring:SetVertexColor(TAN[1], TAN[2], TAN[3], 1)
    f.disc = f:CreateTexture(nil, "BACKGROUND", nil, 1)
    f.disc:SetTexture(RING)
    f.disc:SetVertexColor(0.04, 0.045, 0.06, 1)
    f.port = f:CreateTexture(nil, "ARTWORK")
    f.mask = f:CreateMaskTexture()
    f.mask:SetTexture(MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    f.port:AddMaskTexture(f.mask)
    -- The Textures page's pattern over the portrait (Floating Frames tab), cut to the same round shape.
    f.portPat = f:CreateTexture(nil, "ARTWORK", nil, 1)
    f.portPat:SetHorizTile(true); f.portPat:SetVertTile(true)
    f.portPat:AddMaskTexture(f.mask)
    f.portPat:Hide()
    -- Elite / rare / boss border around the portrait (the game's own artwork).
    f.rare = f:CreateTexture(nil, "OVERLAY", nil, 2)
    f.rare:Hide()
    -- Quest marker to the right of the bars (the target is part of one of your quests).
    f.questIcon = f:CreateTexture(nil, "OVERLAY", nil, 3)
    f.questIcon:SetSize(20, 20)
    if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("QuestNormal") then
        f.questIcon:SetAtlas("QuestNormal")
    else
        f.questIcon:SetTexture("Interface\\GossipFrame\\AvailableQuestIcon")
    end
    f.questIcon:Hide()
    -- Crowd control over the portrait (round, with its own timer swipe).
    f.cc = CreateFrame("Frame", nil, f)
    f.cc:SetFrameLevel(f:GetFrameLevel() + 3)
    f.cc.icon = f.cc:CreateTexture(nil, "ARTWORK")
    f.cc.icon:SetAllPoints()
    f.cc.mask = f.cc:CreateMaskTexture()
    f.cc.mask:SetTexture(MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    f.cc.mask:SetAllPoints()
    f.cc.icon:AddMaskTexture(f.cc.mask)
    f.cc.cd = CreateFrame("Cooldown", nil, f.cc, "CooldownFrameTemplate")
    f.cc.cd:SetAllPoints()
    f.cc.cd:SetDrawEdge(false)
    if f.cc.cd.SetUseCircularEdge then f.cc.cd:SetUseCircularEdge(true) end
    f.cc:Hide()
    -- Role badge (party members): a small dark disc on the portrait's top left.
    f.roleF = CreateFrame("Frame", nil, f)
    f.roleF:SetFrameLevel(f:GetFrameLevel() + 5)
    f.roleBack = f.roleF:CreateTexture(nil, "BACKGROUND")
    f.roleBack:SetTexture(RING)
    f.roleBack:SetAllPoints()
    f.roleBack:SetVertexColor(0.04, 0.045, 0.07, 1)
    f.role = f.roleF:CreateTexture(nil, "ARTWORK")
    f.role:SetTexture(ROLES)
    f.role:SetPoint("TOPLEFT", 2, -2); f.role:SetPoint("BOTTOMRIGHT", -2, 2)
    f.roleF:Hide()
    f.name = f:CreateFontString(nil, "OVERLAY")
    f.name:SetJustifyH("LEFT")
    f.name:SetShadowOffset(0, 0)
    f.hp = bar(f, 14)
    f.questIcon:SetPoint("LEFT", f.hp.sb, "RIGHT", 8, 0)
    f.pw = bar(f, 7)
    f.cb = bar(f, 14)
    f.cb.icon = f:CreateTexture(nil, "ARTWORK")
    f.cb.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    f.cb.name = f.cb.sb:CreateFontString(nil, "OVERLAY")
    f.cb.name:SetJustifyH("LEFT"); f.cb.name:SetWordWrap(false)
    f.cb.name:SetShadowOffset(0, 0)
    f.cb.time = f.cb.sb:CreateFontString(nil, "OVERLAY")
    f.cb.time:SetJustifyH("RIGHT")
    f.cb.time:SetShadowOffset(0, 0)
    f.cb.text:Hide()
    showBar(f.cb, false)
    f.cb.icon:Hide()
    f.debuffIcons, f.buffIcons = {}, {}
    return f
end
local function build(unit)
    if frames[unit] then return frames[unit] end
    local f = newFrame("UbermocTargetNameplate_" .. unit, unit == "target" and 52 or 50)
    f.unit = unit
    frames[unit] = f
    return f
end
local function buildFixed(unit)
    if fixedF[unit] then return fixedF[unit] end
    local f = newFrame("UbermocFloat_" .. unit, 40)
    f:SetFrameStrata("LOW")
    f.unit = unit
    f.fixed = true
    f.raid = unit:sub(1, 4) == "raid"
    fixedF[unit] = f
    return f
end

local function font() return STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF" end

local function sizeOf(d, f)
    local unit = f.unit
    local s
    if f.fixed then
        s = (unit == "player" and d.sPlayer) or (unit == "pet" and d.sPet) or (f.raid and d.sRaid) or d.sParty
    else
        s = (unit == "focus" and d.sFocus) or (unit == "targettarget" and d.sToT) or (unit == "focustarget" and d.sFoT) or d.sTarget
    end
    return math.max(0.4, (s or 100) / 100)
end

-- Every kind of unit frame has a design of its own (DB().look[group]); a missing value falls back to the shared one.
-- Raid frames also lay their smaller raid design over it.
local LOOKS = {}
local function lookGroup(unit)
    if type(unit) == "string" and unit:sub(1, 5) == "party" then return "party" end
    return unit
end
local function lookFor(group)
    local P = LOOKS[group]
    if not P then
        P = setmetatable({}, { __index = function(_, k)
            local D = (filled == UbermocUIDB.targetFrame and filled) or DB()   -- skip the set-up check once done
            local L = D.look and D.look[group]
            if L and L[k] ~= nil then return L[k] end
            return D[k]
        end })
        LOOKS[group] = P
    end
    return P
end
local RL
-- True when this unit's floating frame shows its own cast bar (so the game's cast bar is hidden).
API.floatingCast = function(unit)
    if not (API.floatingCovers and API.floatingCovers(unit)) then return false end
    local ok, L = pcall(function() return lookFor(unit) end)
    return ok and L and L.cast ~= false or false
end

-- True when the floating player frame shows your buffs (or debuffs) itself, so the game's own rows are hidden.
API.floatingAuras = function(harmful)
    if not (API.floatingCovers and API.floatingCovers("player")) then return false end
    local ok, L = pcall(function() return lookFor("player") end)
    if not (ok and L) then return false end
    if harmful then return L.debuffs and true or false end
    return L.buffs and true or false
end

local function lookOf(f, D)
    if not f.raid then return lookFor(lookGroup(f.unit)) end
    if not RL then RL = setmetatable({}, { __index = function(_, k) return DB()[k] end }) end
    D = DB()
    RL.width, RL.portrait, RL.power, RL.cast = D.raidWidth, D.raidPortrait, D.raidPower, D.raidCast
    RL.cc, RL.debuffs, RL.buffs = D.raidCC, D.raidDebuffs, D.raidBuffs
    RL.debuffSize, RL.debuffMax, RL.debuffPos, RL.debuffX, RL.debuffY = D.raidDebuffSize, D.raidDebuffMax, D.raidDebuffPos, D.raidDebuffX, D.raidDebuffY
    RL.buffSize, RL.buffMax, RL.buffPos, RL.buffX, RL.buffY = D.raidBuffSize, D.raidBuffMax, D.raidBuffPos, D.raidBuffX, D.raidBuffY
    RL.nameSize, RL.textSize = D.raidNameSize, D.raidTextSize
    RL.auraTimeSize, RL.auraTimeX, RL.auraTimeY = D.raidAuraTimeSize, D.raidAuraTimeX, D.raidAuraTimeY
    return RL
end

local function layoutFrame(f)
    local D = DB()
    local d = lookOf(f, D)
    f:SetScale(sizeOf(D, f))
    local pw = 0
    f.ring:SetShown(d.portrait); f.disc:SetShown(d.portrait); f.port:SetShown(d.portrait)
    if not d.portrait then f.rare:Hide() end
    if d.portrait then
        local pOn, pSize, pR, pG, pB, pA = API.borderOf("floatPortrait")
        local ringSize = pOn and (41 + pSize * 2) or 46
        f.ring:ClearAllPoints(); f.ring:SetPoint("CENTER", f, "LEFT", 23, 0); f.ring:SetSize(ringSize, ringSize)
        if pOn then f.ring:SetVertexColor(pR, pG, pB, pA) else f.ring:SetVertexColor(TAN[1], TAN[2], TAN[3], 1) end
        f.disc:ClearAllPoints(); f.disc:SetPoint("CENTER", f.ring, "CENTER"); f.disc:SetSize(41, 41)
        f.port:ClearAllPoints(); f.port:SetPoint("CENTER", f.ring, "CENTER"); f.port:SetSize(40, 40)
        f.mask:ClearAllPoints(); f.mask:SetAllPoints(f.port)
        f.portPat:ClearAllPoints(); f.portPat:SetAllPoints(f.port)
        f.cc:ClearAllPoints(); f.cc:SetPoint("CENTER", f.ring, "CENTER"); f.cc:SetSize(40, 40)
        f.roleF:ClearAllPoints(); f.roleF:SetPoint("TOPLEFT", f.ring, "TOPLEFT", -3, 3); f.roleF:SetSize(17, 17)
        pw = 50
    else
        f.cc:ClearAllPoints(); f.cc:SetPoint("RIGHT", f, "LEFT", -4, 0); f.cc:SetSize(30, 30)
        f.roleF:ClearAllPoints(); f.roleF:SetPoint("BOTTOMRIGHT", f, "TOPLEFT", -2, -14); f.roleF:SetSize(15, 15)
    end
    local w = math.max(60, d.width)
    f:SetSize(pw + w, 46)
    f.name:SetFont(font(), d.nameSize or 12, "OUTLINE")
    f.name:ClearAllPoints()
    f.name:SetPoint("BOTTOMLEFT", f, "LEFT", pw + 2, 9)
    f.name:SetWidth(w)
    f.name:SetWordWrap(false)
    local ts = d.textSize or 10
    f.hp.text:SetFont(font(), ts, "OUTLINE")
    local ph = math.max(3, d.powH or 8)
    f.pw.text:SetFont(font(), d.powTextSize or math.max(6, ts - 2), "OUTLINE")
    -- The resource bar hangs barGap below the health bar (4 puts their rims side by side, the starting look).
    local gap = tonumber(d.barGap)
    if gap == nil then gap = 4 end
    gap = math.max(0, math.min(30, gap))
    placeBar(f.hp, f, pw, -18, w, 14)
    placeBar(f.pw, f, pw, -(32 + gap), w, ph)
    showBar(f.pw, d.power)
    roundBar(f.hp, d.barRound)
    roundBar(f.pw, d.barRound)
    roundBar(f.cb, d.barRound)
    -- Textures and borders from the Textures page: the same on every bar and portrait.
    local tx = API.floatTexDB()
    for _, b in ipairs({ f.hp, f.pw, f.cb }) do patBar(b, tx.tex, tx.texA) end
    local fp = f.portPat
    if d.portrait and tx.tex and tx.tex ~= "none" and (tx.texA or 0) > 0 then
        if f.portPatStyle ~= tx.tex then
            f.portPatStyle = tx.tex
            fp:SetTexture(BAR_MASK_PATH .. "skin_" .. tx.tex .. ".tga", "REPEAT", "REPEAT")
        end
        fp:SetAlpha(math.min(1, tx.texA / 100))
        fp:Show()
    else
        fp:Hide()
    end
    local bOn, bSize, bR, bG, bB, bA = API.borderOf("floatBar")
    local thick, rr, rg, rb, ra = 2, TAN[1], TAN[2], TAN[3], 1
    if bOn then thick, rr, rg, rb, ra = bSize + 1, bR, bG, bB, bA end
    for _, b in ipairs({ f.hp, f.pw, f.cb }) do rimBar(b, thick, rr, rg, rb, ra) end
    -- Cast bar: as long and as tall as the health bar, hanging under the bars, the spell icon on its left.
    -- A row of class resource points (combo points, holy power...) under the bars takes some room of its own.
    local resH = (not f.raid and API.resReserve and API.resReserve(f.unit)) or 0
    local barsBottom = d.power and (32 + gap + ph) or 32
    f.resTop, f.resW = -(barsBottom + 3), w
    local cy = (d.power and -(36 + gap + ph) or -36) - resH
    local ic = d.castIcon and 15 or 0
    placeBar(f.cb, f, pw + ic, cy, w - ic, 14)
    f.cb.icon:ClearAllPoints()
    f.cb.icon:SetPoint("TOPRIGHT", f.cb.sb, "TOPLEFT", -1, 0)
    f.cb.icon:SetSize(14, 14)
    local cs = d.castTextSize or 10
    f.cb.name:SetFont(font(), cs, "OUTLINE")
    f.cb.time:SetFont(font(), cs, "OUTLINE")
    f.cb.time:ClearAllPoints(); f.cb.time:SetPoint("RIGHT", f.cb.sb, "RIGHT", -3, 0)
    f.cb.name:ClearAllPoints(); f.cb.name:SetPoint("LEFT", f.cb.sb, "LEFT", 3, 0)
    f.cb.name:SetPoint("RIGHT", f.cb.time, "LEFT", -4, 0)
    f.barX = pw
    -- How far the frame reaches above its top and below it (cast bar, aura rows), for stacking party frames.
    local low = d.cast and (-cy + 14) or (barsBottom + resH)
    if d.portrait then low = math.max(46, low) end
    f.auraLow = low
    -- Buffs and debuffs: each row above or below, at its own distance; on the same side the buffs sit
    -- beyond the debuffs.
    local top, bot = 0, 0
    local dOn, bOn = d.debuffs and true or false, d.buffs and true or false
    local dS, bS = d.debuffSize or 20, d.buffSize or 18
    local dDist = dOn and ((d.debuffY or 3) + dS) or 0
    f.debuffShift = 0
    if dOn then
        if d.debuffPos == "below" then bot = dDist else top = dDist end
    end
    if bOn then
        f.buffShift = 0   -- buffs and debuffs are placed separately
        local reach = (d.buffY or 3) + bS
        if d.buffPos == "below" then bot = math.max(bot, reach) else top = math.max(top, reach) end
    end
    f.topExt, f.botExt = top, low + bot
end

----------------------------------------------------------------------
-- Filling it in (values the game keeps hidden are passed straight to the widgets, which can show them)
----------------------------------------------------------------------
local function reactionColour(unit)
    local ok, atk = pcall(UnitCanAttack, "player", unit)
    atk = ok and atk and not isSecret(atk)
    if atk then
        local okR, rx = pcall(UnitReaction, "player", unit)
        if okR and type(rx) == "number" and not isSecret(rx) and rx == 4 then return 1, 0.85, 0.15, true end
        return 0.9, 0.18, 0.18, true
    end
    return 0.25, 0.85, 0.35, false
end
local function classOf(unit)
    local okP, isP = pcall(UnitIsPlayer, unit)
    if not (okP and plain(isP)) then return nil end
    local okC, _, c = pcall(UnitClass, unit)
    return okC and plain(c) or nil
end
local function classColour(unit)
    local cls = classOf(unit)
    local c = cls and RAID_CLASS_COLORS and RAID_CLASS_COLORS[cls]
    if c then return c.r, c.g, c.b end
end

local function scale100() return CurveConstants and CurveConstants.ScaleTo100 end

-- The value / percent / maximum readers take the unit (and power type), so no new functions are made on
-- every update.
local function hpVal(u) return AbbreviateNumbers(UnitHealth(u)) end
local function hpPct(u) return UnitHealthPercent(u, true, scale100()) end
local function hpMax(u) return AbbreviateNumbers(UnitHealthMax(u)) end
local function pwVal(u, pt) return AbbreviateNumbers(UnitPower(u, pt)) end
local function pwPct(u, pt) return UnitPowerPercent(u, pt, false, scale100()) end
local function pwMax(u, pt) return AbbreviateNumbers(UnitPowerMax(u, pt)) end
local function writeText(fs, mode, val, pct)
    if mode == "both" and val ~= nil and pct ~= nil then fs:SetFormattedText("%s  %.0f%%", val, pct)
    elseif mode == "value" and val ~= nil then fs:SetText(val)
    elseif pct ~= nil then fs:SetFormattedText("%.0f%%", pct)
    else fs:SetText("") end
end
local function setText(fs, mode, valFn, pctFn, maxFn, u, pt)
    if mode == "none" then fs:SetText(""); return end
    local val, pct
    if mode ~= "percent" then
        local ok, v = pcall(valFn, u, pt); if ok then val = v end
    end
    if mode == "curmax" or mode == "all" then
        local okM, m = pcall(maxFn, u, pt)
        if okM and m ~= nil and val ~= nil then
            if mode == "all" and scale100() then
                local okP, p = pcall(pctFn, u, pt)
                if okP and p ~= nil and pcall(fs.SetFormattedText, fs, "%s / %s  %.0f%%", val, m, p) then return end
            end
            if pcall(fs.SetFormattedText, fs, "%s / %s", val, m) then return end
        end
        mode = "value"
    end
    if mode ~= "value" and scale100() then
        local ok, v = pcall(pctFn, u, pt); if ok then pct = v end
    end
    if not pcall(writeText, fs, mode, val, pct) then fs:SetText("") end
end

-- The game's own artwork for elite / rare / boss targets. It is drawn the way the game places it around its
-- portrait (the game's portrait is 58 px, centred 55 right and 48 down from the frame's top right corner; the
-- border hangs from the corner at the offsets below), scaled down to this portrait, then moved by the settings.
local RARE_ART = {
    boss = { "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Gold-Winged", 8, -8, 84, 84 },
    elite = { "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Gold", -11, -8, 70, 70 },
    rareelite = { "ui-hud-unitframe-target-portraiton-boss-rare-silver", -11, -8, 70, 70 },
    rare = { "ui-hud-unitframe-target-portraiton-boss-rare-silver", -11, -8, 70, 70 },
}
local function setRare(f, unit, d)
    local kind
    if d.rareBorder ~= false and unit and not (UnitIsPlayer and UnitIsPlayer(unit)) then
        local ok, c = pcall(UnitClassification, unit)
        if ok and type(c) == "string" then
            local okB, boss = pcall(UnitIsBossMob, unit)
            if okB and boss == true then kind = "boss"
            elseif c == "worldboss" then kind = "boss"
            elseif RARE_ART[c] then kind = c end
        end
    end
    local a = kind and RARE_ART[kind]
    if not a then f.rare:Hide(); return end
    local w, h = a[4], a[5]
    local okI, info = pcall(function() return C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(a[1]) end)
    if okI and type(info) == "table" and info.width and info.height then w, h = info.width, info.height end
    local k = (40 / 58) * (d.rareSize or 100) / 100
    -- where the border's centre sits relative to the portrait's centre, in the game's own units
    local ox = a[2] - w / 2 + 55
    local oy = a[3] - h / 2 + 48
    f.rare:SetAtlas(a[1])
    f.rare:SetSize(w * k, h * k)
    f.rare:ClearAllPoints()
    f.rare:SetPoint("CENTER", f.port, "CENTER", ox * k + (d.rareX or 0), oy * k + (d.rareY or 0))
    f.rare:Show()
end

local function setPortrait(f, unit, d)
    d = lookOf(f, d)
    if not d.portrait then f.rare:Hide(); return end
    -- The picture and border only change with the unit (or a setting): drawn again when either changes,
    -- and every 2 seconds for a unit whose look changed (a shapeshift).
    local okG, guid = pcall(UnitGUID, unit)
    if not okG or isSecret(guid) then guid = nil end
    local now = GetTime()
    if guid and f.ubPortG == guid and f.ubPortU == unit and f.ubPortV == layVer and now - (f.ubPortT or 0) < 2 then return end
    f.ubPortG, f.ubPortU, f.ubPortV, f.ubPortT = guid, unit, layVer, now
    setRare(f, unit, d)
    local cls = d.classIcon and classOf(unit)
    local tc = cls and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[cls]
    if tc then
        f.port:SetTexture(CLASSES)
        f.port:SetTexCoord(tc[1], tc[2], tc[3], tc[4])
    else
        f.port:SetTexCoord(0, 1, 0, 1)
        pcall(SetPortraitTexture, f.port, unit)
    end
end

-- Timer swipe of an aura (the game's own timer object when it has one, plain numbers otherwise).
local function auraTimer(cd, unit, data)
    local inst = data and data.auraInstanceID
    if inst and C_UnitAuras and C_UnitAuras.GetAuraDuration and cd.SetCooldownFromDurationObject then
        local ok, dur = pcall(C_UnitAuras.GetAuraDuration, unit, inst)
        if ok and dur and pcall(cd.SetCooldownFromDurationObject, cd, dur) then return end
    end
    local dur, exp = plain(data and data.duration), plain(data and data.expirationTime)
    if dur and exp and dur > 0 then cd:SetCooldown(exp - dur, dur) else cd:Clear() end
end
local function auraCount(fs, unit, data)
    local inst = data and data.auraInstanceID
    if inst and C_UnitAuras and C_UnitAuras.GetAuraApplicationDisplayCount then
        local ok, txt = pcall(C_UnitAuras.GetAuraApplicationDisplayCount, unit, inst)
        if ok and txt ~= nil and pcall(fs.SetText, fs, txt) then return end
    end
    local n = plain(data and data.applications)
    fs:SetText((n and n > 1) and n or "")
end

-- The aura's place in the game's list, for its tooltip (kept beside the aura data, never written into it).
local IDX = setmetatable({}, { __mode = "k" })
-- Auras kept from the game's own aura updates (the changes it sends with every UNIT_AURA), for the moments
-- when asking for the list gives nothing: tracked[unit][auraInstanceID] = aura data.
local tracked = {}
local function trackFull(unit, t)
    local U = C_UnitAuras
    if not U then return end
    if InCombatLockdown() then return end   -- the game refuses these in combat, and each refusal counts as an error
    if U.GetUnitAuraInstanceIDs and U.GetAuraDataByAuraInstanceID then
        for _, f in ipairs({ "HELPFUL", "HARMFUL" }) do
            local ok, ids = pcall(U.GetUnitAuraInstanceIDs, unit, f)
            if ok and type(ids) == "table" then
                for _, id in ipairs(ids) do
                    local ok2, a = pcall(U.GetAuraDataByAuraInstanceID, unit, id)
                    if ok2 and a then t[id] = a end
                end
            end
        end
    end
end
local trackStat = { events = 0, added = 0, full = 0, errs = 0, last = "" }
local trackAura0
local function trackAura(unit, info)
    if unit == "target" or unit == "focus" then return end   -- their icons come from the game's own frames
    do return trackAura0(unit, info) end
    trackStat.events = trackStat.events + 1
    if type(info) == "table" then
        if info.isFullUpdate then trackStat.full = trackStat.full + 1 end
        if type(info.addedAuras) == "table" then trackStat.added = trackStat.added + #info.addedAuras end
    end
    local ok, err = pcall(trackAura0, unit, info)
    if not ok then trackStat.errs = trackStat.errs + 1; trackStat.last = tostring(err) end
end
function trackAura0(unit, info)
    local U = C_UnitAuras
    if not U then return end
    local t = tracked[unit]
    if not t then t = {}; tracked[unit] = t end
    if type(info) ~= "table" or info.isFullUpdate then
        wipe(t)
        trackFull(unit, t)
        if type(info) ~= "table" then return end
    end
    if type(info.addedAuras) == "table" then
        for _, a in ipairs(info.addedAuras) do
            local id = a and a.auraInstanceID
            if id then t[id] = a end
        end
    end
    if type(info.updatedAuraInstanceIDs) == "table" and U.GetAuraDataByAuraInstanceID and not InCombatLockdown() then
        for _, id in ipairs(info.updatedAuraInstanceIDs) do
            local ok, a = pcall(U.GetAuraDataByAuraInstanceID, unit, id)
            if ok and a then t[id] = a end
        end
    end
    if type(info.removedAuraInstanceIDs) == "table" then
        for _, id in ipairs(info.removedAuraInstanceIDs) do t[id] = nil end
    end
end
local function trackedList(unit, filter, max, out)
    local t = tracked[unit]
    local U = C_UnitAuras
    if not t or not U or not U.IsAuraFilteredOutByInstanceID then return 0 end
    local ids = {}
    for id in pairs(t) do ids[#ids + 1] = id end
    table.sort(ids)
    local n = 0
    for _, id in ipairs(ids) do
        if n >= max then break end
        local ok, filtered = pcall(U.IsAuraFilteredOutByInstanceID, unit, id, filter)
        if ok and filtered == false then n = n + 1; out[n] = t[id] end
    end
    return n
end

-- The auras on a unit for one filter, into out[1..n]. Tries every way this client offers, in turn.
local function auraList(unit, filter, max, out)
    local n = 0
    local U = C_UnitAuras
    if not U then return 0 end
    if U.GetUnitAuras then
        local ok, list = pcall(U.GetUnitAuras, unit, filter, max)
        if ok and type(list) == "table" then
            for i = 1, max do
                local a = list[i]
                if not a then break end
                n = n + 1; out[n] = a
            end
            if n > 0 then return n end
        end
    end
    local fight = InCombatLockdown()
    if U.GetAuraDataByIndex and not fight then
        for i = 1, 40 do
            if n >= max then break end
            local ok, a = pcall(U.GetAuraDataByIndex, unit, i, filter)
            if not ok or not a then break end
            n = n + 1; out[n] = a
            IDX[a] = i
        end
        if n > 0 then return n end
    end
    n = trackedList(unit, filter, max, out)
    if n > 0 then return n end
    if U.GetAuraSlots and U.GetAuraDataBySlot and not fight then
        local res = { pcall(U.GetAuraSlots, unit, filter, max) }
        if res[1] then
            for i = 3, #res do   -- res[2] is the "more to come" token
                local ok, a = pcall(U.GetAuraDataBySlot, unit, res[i])
                if ok and a then n = n + 1; out[n] = a; if n >= max then break end end
            end
        end
    end
    return n
end

-- The game's own crowd control filter (only used when this client has it).
local function ccFilter()
    local F = AuraUtil and AuraUtil.AuraFilters
    local cc = F and F.CrowdControl
    if type(cc) == "string" then return "HARMFUL|" .. cc end
end
local ccOut = {}
local function setCC(f, unit, d)
    d = lookOf(f, d)
    local filter = d.cc and ccFilter()
    local data
    if filter and auraList(unit, filter, 1, ccOut) > 0 then data = ccOut[1] end
    ccOut[1] = nil
    if not data then f.cc:Hide(); return end
    pcall(f.cc.icon.SetTexture, f.cc.icon, data.icon)
    auraTimer(f.cc.cd, unit, data)
    f.cc:Show()
end

-- Target and focus: when the game won't hand the auras to the addon (in combat, for some units), the
-- icons the game's own target and focus frames show are read instead (read only; they are never moved).
local BLIZZ = { target = "TargetFrame", focus = "FocusFrame" }
local bzOut = {}
local function blizzAuras(unit, harmful, max, out)
    local fr = BLIZZ[unit] and _G[BLIZZ[unit]]
    local pools = fr and fr.auraPools
    if not (pools and pools.EnumerateActive) then return 0 end
    local n = 0
    for b in pools:EnumerateActive() do
        if n >= max then break end
        if b.IsShown and b:IsShown() and ((b.Border and true or false) == harmful) then
            n = n + 1
            local t = bzOut[n] or {}
            bzOut[n] = t
            local icon = b.Icon or b.icon
            t.icon = icon and icon.GetTexture and icon:GetTexture() or nil
            local info = b.buttonInfo
            t.auraInstanceID = b.auraInstanceID or (type(info) == "table" and info.auraInstanceID) or nil
            t.blizz = b
            t.countText = b.Count and b.Count.GetText and b.Count:GetText() or nil
            out[n] = t
        end
    end
    return n
end

-- Buffs and debuffs: each floating frame has the game's own aura display (a custom aura container). The game
-- fills it itself, in combat too, so nothing is looked up. This addon only says where it goes and how it looks.
local AC_OK = C_AuraContainerUtil ~= nil and AnchorUtil ~= nil and AnchorUtil.FlowDirection ~= nil
local ACPOS = setmetatable({}, { __mode = "k" })
local ACUNIT = setmetatable({}, { __mode = "k" })
local function acStyle(b, size, list, getTime)
    local fs = math.max(7, math.floor(size * 0.42))
    pcall(b.SetSize, b, size, size)
    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT", -1, 1); bg:SetPoint("BOTTOMRIGHT", 1, -1)
    bg:SetColorTexture(0, 0, 0, 1)
    local ic = b:CreateTexture(nil, "ARTWORK")
    ic:SetAllPoints(b)
    ic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    pcall(b.SetIcon, b, ic)
    local cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
    cd:SetAllPoints(b)
    pcall(cd.SetReverse, cd, true)
    pcall(cd.SetDrawEdge, cd, false)
    pcall(cd.SetDrawSwipe, cd, false)   -- no dark sweep as the time runs down
    pcall(cd.SetDrawBling, cd, false)
    pcall(cd.SetHideCountdownNumbers, cd, true)
    pcall(b.SetDurationCooldown, b, cd)
    local ov = CreateFrame("Frame", nil, b)   -- the text sits above the timer swipe
    ov:SetAllPoints(b)
    ov:SetFrameLevel(cd:GetFrameLevel() + 2)
    local tx = ov:CreateFontString(nil, "OVERLAY")
    tx:SetFont(font(), fs, "OUTLINE"); tx:SetShadowOffset(0, 0); tx:SetShadowColor(0, 0, 0, 0)
    b.ubTime, b.ubSize = tx, size
    if API.auraTimeStyle then API.auraTimeStyle(tx, b, size, getTime and select(1, getTime()), getTime and select(2, getTime()), getTime and select(3, getTime())) else tx:SetPoint("TOP", b, "TOP", 0, 0) end
    if list then list[#list + 1] = b; b.ubGetTime = getTime end
    pcall(b.SetDurationText, b, tx)
    local ct = ov:CreateFontString(nil, "OVERLAY")
    ct:SetFont(font(), fs, "OUTLINE"); ct:SetShadowOffset(0, 0); ct:SetShadowColor(0, 0, 0, 0)
    ct:SetPoint("TOPRIGHT", b, "TOPRIGHT", 1, 0)
    pcall(b.SetApplicationCount, b, ct)
end
local function acMake(f, harmful, size, max, above, line, getTime, cand)
    local list = {}
    local ac = CreateFrame("AuraContainer", nil, f, "CustomAuraContainerTemplate")
    if line then ac:SetFlowLayoutMaximumLineSize(line) end
    ac:SetFlowLayoutAnchorPoint(above and "BOTTOMLEFT" or "TOPLEFT")
    ac:SetFlowLayoutGrowthDirection(AnchorUtil.FlowDirection.Right, above and AnchorUtil.FlowDirection.Up or AnchorUtil.FlowDirection.Down)
    ac:AddAuraGroup("auras", harmful and "HARMFUL" or "HELPFUL", {
        maxFrameCount = max,
        candidateFilters = cand,
        initializeFrame = function(b) acStyle(b, size, list, getTime) end,
        layout = { elementWidth = size, elementHeight = size, elementSpacing = 2, lineSpacing = 2 },
    })
    ac.ubList = list
    return ac
end
API.makeAuraRow = acMake
-- The floating frame of a unit (the target's, or the player's), and the floating settings, for the class resource row.
function API.floatFrame(unit) return frames[unit] or fixedF[unit] end
function API.floatDB() return DB() end
-- True while the floating target frame is the one showing the target: the plate's own elite, rare and quest
-- icons are then left off (they were drawn beside it as leftovers).
function API.floatingTargetOn()
    local d = DB()
    return d and d.uTarget and true or false
end
-- Pointing a row at the unit it already has does nothing, and "target" is still called "target" after a change
-- of target, so the row kept the old target's auras (in a fight most of all). It is moved to another unit and
-- straight back, which makes it read the auras of whoever is the target now.
function API.repointAuras(ac, unit)
    pcall(ac.SetUnit, ac, unit == "player" and "pet" or "player")
    pcall(ac.SetUnit, ac, unit)
end
-- Re-applies the time text settings to the icons an aura container has already made.
function API.auraTimeRefresh(ac)
    if not (ac and ac.ubList and API.auraTimeStyle) then return end
    for _, b in ipairs(ac.ubList) do
        if b.ubTime and b.ubGetTime then
            local s, x, y = b.ubGetTime()
            API.auraTimeStyle(b.ubTime, b, b.ubSize, s, x, y)
        end
    end
end   -- the halo frames of units the game has no icons for use it too
local acWarned = false
-- Which auras a row shows: only yours, only boss / stealable ones, none that last longer than N minutes, and
-- none of the spells hidden on the Buffs & Debuffs tab. Returns the game's candidate filters and a signature.
local function candOf(d, harmful)
    local c, parts = {}, {}
    local function add(k, v) parts[#parts + 1] = k .. "=" .. tostring(v) end
    if harmful then
        if d.debuffOnlyMine then c.isFromPlayerOrPlayerPet = true; add("m", 1) end
        if d.debuffBoss then c.isBossAura = true; add("b", 1) end
        local m = tonumber(d.debuffMaxMin) or 0
        if m > 0 then c.maxDuration = m * 60; add("d", m) end
    else
        if d.buffOnlyMine then c.isFromPlayerOrPlayerPet = true; add("m", 1) end
        if d.buffStealable then c.isStealable = true; add("s", 1) end
        local m = tonumber(d.buffMaxMin) or 0
        if m > 0 then c.maxDuration = m * 60; add("d", m) end
    end
    local ex
    local ids = API.auraHiddenIDs and API.auraHiddenIDs()
    if type(ids) == "table" then
        for id in pairs(ids) do if type(id) == "number" then ex = ex or {}; ex[id] = true end end
    end
    if ex then c.excludeSpellIDs = ex; add("x", API.auraHideVer or 0) end
    return c, table.concat(parts, ",")
end
API.floatAuraFilterChanged = function() if API.targetFrameUpdate then API.targetFrameUpdate() end end
-- Shows (or hides) one row of auras on a frame. False when this client has no aura containers.
local function acRow(f, unit, d, harmful)
    if not AC_OK then return false end
    local key = harmful and "acD" or "acB"
    local ac = f[key]
    local on = harmful and d.debuffs or (not harmful and d.buffs)
    if not on or not unit then
        if ac then ac:Hide() end
        return true
    end
    local size = harmful and (d.debuffSize or 20) or (d.buffSize or 18)
    local max = harmful and (d.debuffMax or 6) or (d.buffMax or 6)
    local pos = harmful and d.debuffPos or d.buffPos
    local dx = harmful and (d.debuffX or 0) or (d.buffX or 0)
    local dy = (harmful and (d.debuffY or 3) or (d.buffY or 3)) + (harmful and 0 or (f.buffShift or 0))
    local above = pos ~= "below"
    local cand, csig = candOf(d, harmful)
    local sig = size .. ":" .. max .. ":" .. tostring(above) .. ":" .. csig
    if not ac or (f[key .. "sig"] ~= sig and not InCombatLockdown()) then
        if ac then pcall(ac.SetEnabled, ac, false); ac:Hide() end   -- the look changed: a fresh one
        local ok, made = pcall(acMake, f, harmful, size, max, above, nil, function()
            local L = lookOf(f)
            return L.auraTimeSize, L.auraTimeX, L.auraTimeY
        end, cand)
        if not ok or not made then
            AC_OK = false
            if not acWarned and API.uiPrint then acWarned = true; API.uiPrint("Floating frames: the game's aura display could not be made (" .. tostring(made) .. ").") end
            return false
        end
        ac = made
        f[key], f[key .. "sig"] = ac, sig
    end
    -- "target" and "focus" name a different unit after each change of target: the container is pointed at it
    -- again, or it keeps showing the old unit's auras until that unit is picked again.
    local ukey = unit .. ":" .. (API.auraEpoch or 0)
    if ACUNIT[ac] ~= ukey then
        if ACUNIT[ac] then API.repointAuras(ac, unit) else pcall(ac.SetUnit, ac, unit) end
        ACUNIT[ac] = ukey
    end
    do
        local L = lookOf(f)
        local ts = tostring(L.auraTimeSize) .. ":" .. tostring(L.auraTimeX) .. ":" .. tostring(L.auraTimeY)
        if ac.ubTS ~= ts then ac.ubTS = ts; API.auraTimeRefresh(ac) end
    end
    local x = (f.barX or 0) + dx
    local y = above and dy or -((f.auraLow or 61) + dy)
    local ps = x .. ":" .. y .. ":" .. tostring(above)
    if ACPOS[ac] ~= ps then
        ACPOS[ac] = ps
        ac:ClearAllPoints()
        if above then ac:SetPoint("BOTTOMLEFT", f, "TOPLEFT", x, y) else ac:SetPoint("TOPLEFT", f, "TOPLEFT", x, y) end
    end
    if not ac:IsShown() then ac:Show() end
    return true
end

local auraOut = {}
local function auraRow(f, unit, d, pool, harmful)
    local n = 0
    local on = harmful and d.debuffs or (not harmful and d.buffs)
    if acRow(f, unit, d, harmful) then
        for i = 1, #pool do pool[i]:Hide() end
        return
    end
    if on then
        local mine = false
        local filter = (harmful and "HARMFUL" or "HELPFUL") .. (mine and "|PLAYER" or "")
        local size = harmful and (d.debuffSize or 20) or (d.buffSize or 18)
        local max = harmful and (d.debuffMax or 6) or (d.buffMax or 6)
        local pos = harmful and d.debuffPos or d.buffPos
        local dx = harmful and (d.debuffX or 0) or (d.buffX or 0)
        local dy = (harmful and (d.debuffY or 3) or (d.buffY or 3)) + (harmful and 0 or (f.buffShift or 0))
        local got = auraList(unit, filter, max, auraOut)
        for i = 1, got do
            local data = auraOut[i]
            auraOut[i] = nil
            n = n + 1
            local a = pool[n] or auraIcon(f, harmful)
            pool[n] = a
            a:SetSize(size, size)
            a.count:SetFont(font(), math.max(8, math.floor(size * 0.5)), "OUTLINE")
            a:ClearAllPoints()
            local x = (f.barX or 0) + dx + (n - 1) * (size + 2)
            if pos == "below" then
                a:SetPoint("TOPLEFT", f, "TOPLEFT", x, -((f.auraLow or 61) + dy))
            else
                a:SetPoint("BOTTOMLEFT", f, "TOPLEFT", x, dy)
            end
            a.unit, a.inst, a.index, a.filter, a.blizz = unit, data.auraInstanceID, IDX[data], filter, data.blizz
            pcall(a.icon.SetTexture, a.icon, data.icon)
            auraTimer(a.cd, unit, data)
            if data.blizz then
                if not pcall(a.count.SetText, a.count, data.countText or "") then a.count:SetText("") end
            else
                auraCount(a.count, unit, data)
            end
            a:Show()
        end
    end
    for i = n + 1, #pool do pool[i]:Hide() end
end
local function setAuras(f, unit, d)
    d = lookOf(f, d)
    auraRow(f, unit, d, f.debuffIcons, true)
    auraRow(f, unit, d, f.buffIcons, false)
end

-- What the game hands over for the target's auras right now, for the Target tab's check button.
API.floatAuraReport = function()
    local say = API.uiPrint or print
    if not UnitExists("target") then say("Floating frames: no target."); return end
    local U = C_UnitAuras or {}
    for _, filter in ipairs({ "HELPFUL", "HARMFUL", "HARMFUL|PLAYER" }) do
        local a, b, c, e = 0, 0, 0, ""
        if U.GetUnitAuras then
            local ok, l = pcall(U.GetUnitAuras, "target", filter, 40)
            if ok and type(l) == "table" then a = #l elseif not ok then e = e .. " list error: " .. tostring(l) end
        end
        if U.GetAuraDataByIndex then
            for i = 1, 40 do
                local ok, x = pcall(U.GetAuraDataByIndex, "target", i, filter)
                if not ok then e = e .. " index error: " .. tostring(x); break end
                if not x then break end
                b = b + 1
            end
        end
        if U.GetAuraSlots then
            local r = { pcall(U.GetAuraSlots, "target", filter, 40) }
            if r[1] then c = math.max(0, #r - 2) else e = e .. " slot error: " .. tostring(r[2]) end
        end
        local ids = 0
        if U.GetUnitAuraInstanceIDs then
            local ok, l = pcall(U.GetUnitAuraInstanceIDs, "target", filter)
            if ok and type(l) == "table" then ids = #l elseif not ok then e = e .. " ids error: " .. tostring(l) end
        end
        local tr = {}
        local nt = trackedList("target", filter, 40, tr)
        say(string.format("Floating frames, %s: list %d, index %d, slot %d, ids %d, tracked %d%s", filter, a, b, c, ids, nt, e))
    end
    local kept = 0
    if tracked.target then for _ in pairs(tracked.target) do kept = kept + 1 end end
    say(string.format("Floating frames, aura updates seen on target: %d (%d added, %d full), kept %d, errors %d%s",
        trackStat.events, trackStat.added, trackStat.full, kept, trackStat.errs, trackStat.errs > 0 and (": " .. trackStat.last) or ""))
    local t = {}
    say(string.format("Floating frames: the game's target frame shows %d buffs, %d debuffs. In combat: %s",
        blizzAuras("target", false, 40, t), blizzAuras("target", true, 40, t), tostring(InCombatLockdown() and true or false)))
end

-- Cast bar: plain numbers when the game gives them, the game's own timer object when the times are hidden.
local function castInfo(unit)
    local channel = false
    local ok, name, _, tex, s, e = pcall(UnitCastingInfo, unit)
    if not ok or not name then
        ok, name, _, tex, s, e = pcall(UnitChannelInfo, unit)
        channel = true
    end
    if not ok or not name then return nil end
    return name, tex, s, e, channel
end
local function updateCast(f, unit, d)
    d = lookOf(f, d)
    if not d.cast then showBar(f.cb, false); f.cb.icon:Hide(); return end
    local name, tex, s, e, channel = castInfo(unit)
    if not name then showBar(f.cb, false); f.cb.icon:Hide(); f.cb.dur = nil; return end
    local sb = f.cb.sb
    if channel then sb:SetStatusBarColor(0.3, 0.85, 0.85) else sb:SetStatusBarColor(1, 0.82, 0.2) end
    local ps, pe = plain(s), plain(e)
    local el, tot
    if ps and pe and pe > ps then
        tot = (pe - ps) / 1000
        el = math.max(0, math.min(tot, GetTime() - ps / 1000))
        sb:SetMinMaxValues(0, tot)
        sb:SetValue(channel and (tot - el) or el)
        f.cb.dur = nil
    else
        local fn = channel and _G.UnitChannelDuration or _G.UnitCastingDuration
        local dur
        if fn then
            local okD, v = pcall(fn, unit)
            if okD then dur = v end
        end
        if dur and sb.SetTimerDuration then pcall(sb.SetTimerDuration, sb, dur) end
        f.cb.dur = dur
    end
    if d.castIcon then pcall(f.cb.icon.SetTexture, f.cb.icon, tex); f.cb.icon:Show() else f.cb.icon:Hide() end
    if d.castName then pcall(f.cb.name.SetText, f.cb.name, name); f.cb.name:Show() else f.cb.name:Hide() end
    local mode = d.castTime or "both"
    local tfs = f.cb.time
    local okT = pcall(function()
        if mode == "none" then tfs:SetText(""); return end
        if el and tot then
            local left = tot - el
            if mode == "both" then tfs:SetFormattedText("%.1f / %.1f", left, tot)
            elseif mode == "current" then tfs:SetFormattedText("%.1f", left)
            else tfs:SetFormattedText("%.1f", tot) end
        elseif f.cb.dur and f.cb.dur.GetRemainingDuration then
            local left = f.cb.dur:GetRemainingDuration()
            local all = f.cb.dur.GetTotalDuration and f.cb.dur:GetTotalDuration()
            if mode == "both" and all ~= nil then tfs:SetFormattedText("%.1f / %.1f", left, all)
            elseif mode == "max" and all ~= nil then tfs:SetFormattedText("%.1f", all)
            else tfs:SetFormattedText("%.1f", left) end
        else
            tfs:SetText("")
        end
    end)
    if not okT then tfs:SetText("") end
    showBar(f.cb, true)
end

-- Everything inside one frame. label replaces the name (party preview).
local PREVIEW_ROLES = { "TANK", "HEALER", "DAMAGER", "DAMAGER", "DAMAGER" }
local DEFAULT_POWER = { r = 0.2, g = 0.4, b = 0.9 }
local function setHealthBar(sb, unit)
    sb:SetMinMaxValues(0, UnitHealthMax(unit))
    sb:SetValue(UnitHealth(unit))
end
-- Returns the power type used (it can be hidden in combat: the unit's main one is used then).
local function setPowerBar(sb, unit)
    local pt = plain(UnitPowerType(unit))
    local col = (pt and PowerBarColor and PowerBarColor[pt]) or DEFAULT_POWER
    sb:SetMinMaxValues(0, UnitPowerMax(unit, pt))
    sb:SetValue(UnitPower(unit, pt))
    sb:SetStatusBarColor(col.r, col.g, col.b)
    return pt
end
local function fill(f, unit, d, label)
    d = lookOf(f, d)
    f.drawUnit = unit
    local r, g, b = reactionColour(unit)
    if f.fixed and d.classColour then
        local cr, cg, cb = classColour(unit)
        if cr then r, g, b = cr, cg, cb end
    end
    if label then
        f.name:SetText(label)
    else
        local okN, nm = pcall(UnitName, unit)
        pcall(f.name.SetText, f.name, okN and nm or "")
    end
    f.name:SetTextColor(r, g, b)
    pcall(setHealthBar, f.hp.sb, unit)
    f.hp.sb:SetStatusBarColor(r, g, b)
    -- quest marker to the right of the bars: on the frames over a unit's head (target, focus and so on)
    f.questIcon:SetShown(not f.fixed and d.questIcon ~= false and f.hp.sb:IsShown() and isQuestUnit(unit))
    local okC, conn = pcall(UnitIsConnected, unit)
    local offline = okC and plain(conn) == false
    local okD, dead = pcall(UnitIsDeadOrGhost, unit)
    dead = okD and plain(dead) and true or false
    if f.fixed and offline then
        f.hp.text:SetText("OFF")
    elseif f.fixed and dead then
        f.hp.text:SetText("DEAD")
    else
        setText(f.hp.text, d.hpText or "percent", hpVal, hpPct, hpMax, unit)
    end
    if d.power then
        local okP, pt = pcall(setPowerBar, f.pw.sb, unit)
        showBar(f.pw, okP)
        if okP then
            setText(f.pw.text, d.powText or "percent", pwVal, pwPct, pwMax, unit, pt)
        end
    end
    setPortrait(f, unit, d)
    setCC(f, unit, d)
    setAuras(f, unit, d)
    updateCast(f, unit, d)
    -- Party members: role badge, and faded when offline or out of range.
    local role
    if f.fixed and f.unit ~= "player" and f.unit ~= "pet" and (f.raid and d.raidRole or (not f.raid and d.partyRole)) then
        local okR, ro = pcall(UnitGroupRolesAssigned, unit)
        role = okR and plain(ro)
        if label then role = PREVIEW_ROLES[((tonumber(f.unit:match("%d+")) or 1) - 1) % 5 + 1] end
    end
    local rc = role and ROLE_COORDS[role]
    if rc then f.role:SetTexCoord(rc[1], rc[2], rc[3], rc[4]); f.roleF:Show() else f.roleF:Hide() end
    local alpha = 1
    if f.fixed and f.unit ~= "player" and f.unit ~= "pet" and not label then
        if offline then
            alpha = 0.45
        else
            local okI, inRange = pcall(UnitInRange, unit)
            if okI and plain(inRange) == false then alpha = 0.55 end
        end
    end
    f.ubRange = alpha   -- the fade rules (Fading page) multiply this
    f:SetAlpha(alpha * (API.fadeAlphaOf and API.fadeAlphaOf(f) or 1))
end

----------------------------------------------------------------------
-- Over the unit's head: which units get a frame, and hiding their nameplates
----------------------------------------------------------------------
local hiddenPlates = {}
-- True while a floating frame stands in for this nameplate: the things the addon adds to plates stay hidden too.
API.plateCovered = function(plate)
    local uf = plate and plate.UnitFrame
    return uf and hiddenPlates[uf] and true or false
end
local function plateOf(unit)
    if not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then return nil end
    local ok, p = pcall(C_NamePlate.GetNamePlateForUnit, unit)
    if ok and p and not (p.IsForbidden and p:IsForbidden()) then return p end
end
local function sameAs(a, b)
    local ok, r = pcall(UnitIsUnit, a, b)
    return ok and plain(r) and true or false
end
local function unitOn(d, unit)
    if unit == "target" then return d.uTarget end
    if unit == "focus" then return d.uFocus end
    if unit == "focustarget" then return d.uFoT end
    return d.uToT
end

local wantBuf = {}
local function updateUnit(unit, d, want)
    local f = build(unit)
    if not unitOn(d, unit) or not UnitExists(unit) then f:Hide(); return end
    -- one frame per unit: a unit that already has a frame (as your target, say) doesn't get a second one
    for _, e in ipairs(UNITS) do
        if e == unit then break end
        local ef = frames[e]
        if ef and ef:IsShown() and sameAs(unit, e) then f:Hide(); return end
    end
    local plate = plateOf(unit)
    if not plate then f:Hide(); return end
    local _, _, _, hostile = reactionColour(unit)
    local L = lookFor(lookGroup(unit))
    if (hostile and not L.enemy) or (not hostile and not L.friendly) then f:Hide(); return end
    -- Laying a frame out (sizes, fonts, anchors) is the costly part: only after a setting changed, with
    -- a look once a second for anything changed elsewhere.
    local now = GetTime()
    if f.ubLayVer ~= layVer or now - (f.ubLayT or 0) > 1 then
        layoutFrame(f)
        f.ubLayVer, f.ubLayT = layVer, now
        f.ubPlate = nil
    end
    local y = L.y or 4
    if f.ubPlate ~= plate or f.ubPlateY ~= y then
        f.ubPlate, f.ubPlateY = plate, y
        f:ClearAllPoints()
        f:SetPoint("BOTTOM", plate, "TOP", 0, y)
    end
    fill(f, unit, d)
    f:Show()
    if L.hidePlate and plate.UnitFrame then want[plate.UnitFrame] = true end
end

----------------------------------------------------------------------
-- Player and party frames in this style, in one place on the screen
----------------------------------------------------------------------
local clicks = {}
local function clickFor(unit)
    if clicks[unit] then return clicks[unit] end
    if InCombatLockdown() then return nil end
    -- The click target: its own secure button, so it works and follows the unit during combat.
    local b = CreateFrame("Button", "UbermocFloatClick_" .. unit, UIParent, "SecureUnitButtonTemplate")
    b:SetFrameStrata("LOW")
    b:SetFrameLevel(45)
    b:SetAttribute("unit", unit)
    b:SetAttribute("*type1", "target")
    b:SetAttribute("*type2", "togglemenu")
    b:RegisterForClicks("AnyUp")
    b:SetScript("OnEnter", function(self)
        if UnitExists(unit) then
            GameTooltip_SetDefaultAnchor(GameTooltip, self)
            GameTooltip:SetUnit(unit)
            GameTooltip:Show()
        end
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:Hide()
    clicks[unit] = b
    return b
end

local pendingFixed = false
local RAIDPREVIEW = 20
local function partyStep(f, d)
    return (f.topExt + f.botExt) * f:GetScale() + (d.partyGap or 14)
end
local function inRaidNow() return IsInRaid and IsInRaid() and true or false end
local function inGroupNow() return IsInGroup and IsInGroup() and true or false end

-- Puts one frame (and its click button) at x, y from the screen's centre.
local function placeFixed(f, unit, point, x, y, driver, show, combat)
    local s = f:GetScale()
    f:ClearAllPoints()
    f:SetPoint(point, UIParent, "CENTER", x / s, y / s)
    if combat then return end
    local b = clickFor(unit)
    if not b then return end
    b:SetScale(s)
    b:ClearAllPoints()
    b:SetPoint(point, UIParent, "CENTER", x / s, y / s)
    b:SetSize(f:GetWidth(), f:GetHeight())
    if driver then
        if show then RegisterStateDriver(b, "visibility", driver) else UnregisterStateDriver(b, "visibility"); b:Hide() end
    else
        b:SetShown(show and true or false)
    end
end

local function layoutRaid(d, combat)
    if not d.raidFloat then
        for i = 1, MAXRAID do
            local f = fixedF["raid" .. i]
            if f then
                f:Hide()
                local b = clicks["raid" .. i]
                if b and not combat then UnregisterStateDriver(b, "visibility"); b:Hide() end
            end
        end
        return
    end
    local count = inRaidNow() and MAXRAID or (d.raidPreview and not inGroupNow() and RAIDPREVIEW or 0)
    local per = math.max(1, math.floor(d.raidPer or 5))
    for i = 1, MAXRAID do
        local u = "raid" .. i
        local f = fixedF[u]
        if not f and i <= count then f = buildFixed(u) end
        if f then
            layoutFrame(f)
            local s = f:GetScale()
            local cw = f:GetWidth() * s + (d.raidGap or 6)
            local ch = (f.topExt + f.botExt) * s + (d.raidGap or 6)
            local col, row = (i - 1) % per, math.floor((i - 1) / per)
            placeFixed(f, u, "TOPLEFT", d.raidX + col * cw, d.raidY - row * ch - f.topExt * s,
                "[@" .. u .. ",exists] show; hide", i <= count, combat)
            if i > count then f:Hide() end
        end
    end
end

local function layoutFixed()
    if not UbermocUIDB then return end
    local d = DB()
    local combat = InCombatLockdown()
    local f = buildFixed("player")
    layoutFrame(f)
    placeFixed(f, "player", "CENTER", d.pX, d.pY, nil, d.playerFloat, combat)
    local pet = buildFixed("pet")
    layoutFrame(pet)
    placeFixed(pet, "pet", "CENTER", d.petX, d.petY, "[@pet,exists] show; hide", d.petFloat, combat)
    for i = 1, 4 do
        local u = "party" .. i
        local pf = buildFixed(u)
        layoutFrame(pf)
        local ps = pf:GetScale()
        placeFixed(pf, u, "TOPLEFT", d.partyX, d.partyY - pf.topExt * ps - (i - 1) * partyStep(pf, d),
            "[group:raid] hide; [@" .. u .. ",exists] show; hide", d.partyFloat, combat)
    end
    pcall(layoutRaid, d, combat)
    if API.applyStanceButton then pcall(API.applyStanceButton) end
    if combat then pendingFixed = true end
end

local lastRaid = 0
local function updateFixed(d, force)
    local pf = fixedF.player
    if pf then
        if d.playerFloat then fill(pf, "player", d); pf:Show() else pf:Hide() end
    end
    local pt = fixedF.pet
    if pt then
        if d.petFloat and UnitExists("pet") then fill(pt, "pet", d); pt:Show() else pt:Hide() end
    end
    local inRaid, inGroup = inRaidNow(), inGroupNow()
    for i = 1, 4 do
        local u = "party" .. i
        local f = fixedF[u]
        if f then
            if d.partyFloat and not inRaid and UnitExists(u) then
                fill(f, u, d); f:Show()
            elseif d.partyFloat and d.partyPreview and not inGroup then
                fill(f, "player", d, "Party member " .. i); f:Show()
            else
                f:Hide()
            end
        end
    end
    if d.raidFloat then
        local now = GetTime()
        if not force and now - lastRaid < 0.4 then return end
        lastRaid = now
        local preview = d.raidPreview and not inGroup
        for i = 1, MAXRAID do
            local u = "raid" .. i
            local f = fixedF[u]
            if f then
                if inRaid and UnitExists(u) then fill(f, u, d); f:Show()
                elseif preview and i <= RAIDPREVIEW then fill(f, "player", d, "Raid member " .. i); f:Show()
                else f:Hide() end
            end
        end
    end
end

----------------------------------------------------------------------
-- Keeping the halo frames and the game's own frames out of the way
----------------------------------------------------------------------
-- A unit with a floating frame has its halo frame switched off in the halo options (once; it can be put back).
local HALO_OF = { target = true, focus = true, targettarget = true }
local function haloCheck(d)
    if not API.haloOff then return end
    for _, u in ipairs(UNITS) do
        if HALO_OF[u] and unitOn(d, u) and not (d.haloOffDone and d.haloOffDone[u]) then
            local ok, found = pcall(API.haloOff, u)
            if ok and found then
                d.haloOffDone = d.haloOffDone or {}
                d.haloOffDone[u] = true
            end
        end
    end
end

-- The game's frames this page hides itself (the halo code hides the target, focus, target of target and
-- player frames). Only frames hidden here are ever shown again from here.
local myHold = setmetatable({}, { __mode = "k" })
local origParent = setmetatable({}, { __mode = "k" })
local hiddenParent
local function park(f, on, reparent)
    if type(f) ~= "table" then return end
    local hh = API.holdHidden
    local combat = InCombatLockdown()
    if on then
        if not myHold[f] then myHold[f] = true; if hh then pcall(hh, f, true) end end
        if not combat then
            if reparent then
                if not origParent[f] then
                    if not hiddenParent then hiddenParent = CreateFrame("Frame"); hiddenParent:Hide() end
                    local ok, p = pcall(f.GetParent, f)
                    if ok and p then origParent[f] = p; pcall(f.SetParent, f, hiddenParent) end
                end
            else
                pcall(f.EnableMouse, f, false)
            end
        end
    else
        if myHold[f] then
            myHold[f] = nil
            if hh then pcall(hh, f, false) end
            if not combat and not reparent then pcall(f.EnableMouse, f, true) end
        end
        if origParent[f] and not combat then pcall(f.SetParent, f, origParent[f]); origParent[f] = nil end
    end
end
local function holdGame(d)
    park(_G.FocusFrameToT or (_G.FocusFrame and _G.FocusFrame.totFrame), d.uFoT and true or false, false)
    park(_G.PartyFrame, d.partyFloat and true or false, true)
    park(_G.CompactPartyFrame, d.partyFloat and true or false, true)
    park(_G.CompactRaidFrameContainer, d.raidFloat and true or false, false)
end
-- The halo code puts the game's frames back (or hides them) when it lays its frames out.
local function haloRefresh()
    if not API.haloRefresh then return end
    for _, u in ipairs({ "target", "focus", "targettarget", "focustarget", "player" }) do pcall(API.haloRefresh, u) end
end

local function update()
    if not UbermocUIDB then return end
    local d = DB()
    pcall(haloCheck, d)
    local want = wantBuf
    wipe(want)
    for _, u in ipairs(UNITS) do pcall(updateUnit, u, d, want) end
    local hh = API.holdHidden
    if hh then
        for uf in pairs(hiddenPlates) do
            if not want[uf] then pcall(hh, uf, false); hiddenPlates[uf] = nil end
        end
        for uf in pairs(want) do
            if not hiddenPlates[uf] then pcall(hh, uf, true); hiddenPlates[uf] = true end
        end
    end
    pcall(updateFixed, d)
end
API.targetFrameUpdate = function() pcall(update) end

-- Everything again after a setting changed.
local function refreshAll()
    lastRaid = 0
    layVer = layVer + 1
    pcall(layoutFixed)
    if UbermocUIDB then pcall(holdGame, DB()) end
    pcall(haloRefresh)
    pcall(update)
end

API.targetFrameRefresh = refreshAll

-- Every kind of unit frame can be the halo frame, the floating style, or the game's own.
local FLAG = { player = "playerFloat", pet = "petFloat", target = "uTarget", targettarget = "uToT", focus = "uFocus",
               focustarget = "uFoT", party = "partyFloat", raid = "raidFloat" }
local HALO_PAGE = { player = "ringhud", pet = "ringpet", target = "ringtarget", targettarget = "ringtot", focus = "ringfocus", focustarget = "ringfot",
                    party = "party", raid = "raid" }
local HALO_DB = { player = "ringhud", target = "ringhud_target", targettarget = "ringhud_tot", focus = "ringhud_focus", focustarget = "ringhud_fot" }
local function haloIsOn(unit)
    if unit == "party" or unit == "raid" then return API.groupOn and API.groupOn(unit) or false end
    if unit == "pet" then local r = UbermocUIDB and UbermocUIDB.ringhud; return r and r.pon and true or false end
    local r = UbermocUIDB and HALO_DB[unit] and UbermocUIDB[HALO_DB[unit]]
    return r and r.on and true or false
end
local function haloSwitch(unit, on)
    if unit == "party" or unit == "raid" then if API.groupSet then pcall(API.groupSet, unit, on) end
    elseif unit == "pet" then if API.haloPetSet then pcall(API.haloPetSet, on) end
    elseif HALO_DB[unit] then if API.haloSet then pcall(API.haloSet, unit, on) end end
end
local function styleOf(unit)
    if DB()[FLAG[unit]] then return "float" end
    if HALO_PAGE[unit] and haloIsOn(unit) then return "halo" end
    return "game"
end
local unitPages = {}
local function setStyle(unit, v)
    local d = DB()
    d[FLAG[unit]] = v == "float"
    if HALO_PAGE[unit] then haloSwitch(unit, v == "halo") end
    refreshAll()
end
-- A halo frame switched on from its own page takes over from this style for that unit.
API.haloTurnedOn = function(unit, on)
    if not on or not UbermocUIDB or not FLAG[unit] then return end
    local d = DB()
    d[FLAG[unit]] = false
    pcall(layoutFixed)
    pcall(holdGame, d)
    pcall(update)
    for _, fn in pairs(unitPages) do pcall(fn) end
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED", "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED",
                     "PLAYER_ENTERING_WORLD", "GROUP_ROSTER_UPDATE", "PLAYER_ROLES_ASSIGNED", "PLAYER_REGEN_ENABLED" }) do
    pcall(ev.RegisterEvent, ev, e)
end
-- Unit events, two units to a listener (the most one listener takes).
local UNIT_EVENTS = { "UNIT_TARGET", "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER",
                      "UNIT_NAME_UPDATE", "UNIT_PORTRAIT_UPDATE", "UNIT_AURA", "UNIT_CONNECTION", "UNIT_SPELLCAST_START",
                      "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP",
                      "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_FAILED" }
local dirty = true
local function markDirty() dirty = true end
for _, pair in ipairs({ { "target", "focus" }, { "targettarget", "focustarget" }, { "player", "pet" }, { "party1", "party2" }, { "party3", "party4" } }) do
    local l = CreateFrame("Frame")
    for _, e in ipairs(UNIT_EVENTS) do pcall(l.RegisterUnitEvent, l, e, pair[1], pair[2]) end
    l:SetScript("OnEvent", function(_, event, unit, info)
        dirty = true
        if event == "UNIT_AURA" and unit then pcall(trackAura, unit, info) end
    end)
end
ev:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_FOCUS_CHANGED" or event == "NAME_PLATE_UNIT_ADDED" or event == "NAME_PLATE_UNIT_REMOVED" then
        API.auraEpoch = (API.auraEpoch or 0) + 1
    end
    if event == "PLAYER_TARGET_CHANGED" then
        tracked.target = nil; pcall(trackAura, "target", nil)
    elseif event == "PLAYER_FOCUS_CHANGED" then
        tracked.focus = nil; pcall(trackAura, "focus", nil)
    end
    if event == "PLAYER_REGEN_ENABLED" then
        if pendingFixed then pendingFixed = false; pcall(layoutFixed) end
        if UbermocUIDB then pcall(holdGame, DB()) end
    elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
        if UbermocUIDB and DB().raidFloat then pcall(layoutFixed) end
    end
    dirty = true
end)
local acc, castAcc = 0, 0
ev:SetScript("OnUpdate", function(_, dt)
    if not UbermocUIDB then return end
    acc = acc + dt
    castAcc = castAcc + dt
    if (dirty and acc >= 0.05) or acc >= 0.2 then
        dirty = false
        acc, castAcc = 0, 0
        pcall(update)
    elseif castAcc >= 0.05 then
        castAcc = 0
        local d = DB()
        for _, u in ipairs(UNITS) do
            local f = frames[u]
            if f and f:IsShown() then pcall(updateCast, f, u, d) end
        end
        for _, u in ipairs(FIXED) do
            local f = fixedF[u]
            if f and f:IsShown() then pcall(updateCast, f, f.drawUnit or u, d) end
        end
    end
end)

----------------------------------------------------------------------
-- Pages: one tab for each kind of unit frame, with the design to use (halo, floating or the game's own)
-- and that design's settings, including the floating design of that unit alone.
----------------------------------------------------------------------
local px = function(v) return math.floor(v + 0.5) .. " px" end
local pct = function(v) return math.floor(v + 0.5) .. "%" end
local num = function(v) return tostring(math.floor(v + 0.5)) end

-- A scrolling sheet of settings that fill in the floating style's saved values.
local LOOKSET = {}
local function sheet(parent, store)
    local S = { checks = {}, sliders = {}, rows = {}, y = -10 }
    -- design settings live in this unit's own table (store), the rest in the main one
    local function get(key)
        if store and LOOKSET[key] then
            local v = store()[key]
            if v ~= nil then return v end
        end
        return DB()[key]
    end
    local function set(key, v)
        if store and LOOKSET[key] then store()[key] = v else DB()[key] = v end
    end
    local panel = CreateFrame("Frame", nil, parent)
    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 0, 0)
    scroll:SetPoint("BOTTOMRIGHT", -30, 8)
    local sc = CreateFrame("Frame", nil, scroll)
    sc:SetSize(660, 600)
    scroll:SetScrollChild(sc)
    S.panel, S.sc, S.scroll = panel, sc, scroll
    S.tabs, S.extra = {}, {}
    -- Starts a tab (the same strip the halo frames use): everything from here to the next tab belongs to it.
    function S.tab(name) S.tabs[#S.tabs + 1] = { name, #S.tabs == 0 and 0 or (S.y + 10) } end
    local function changed() refreshAll() end
    function S.head(t) API.newLabel(sc, t, 16, S.y, "GameFontNormalLarge"); S.y = S.y - 32 end
    function S.note(text)
        local fs = API.newLabel(sc, text, 16, S.y, "GameFontHighlightSmall")
        fs:SetWidth(620); fs:SetJustifyH("LEFT"); fs:SetWordWrap(true)
        S.y = S.y - 14 * math.ceil(#text / 105) - 10
    end
    function S.check(label, key, x)
        S.checks[key] = API.newCheck(sc, label, x or 16, S.y, function(v) set(key, v); changed() end)
        S.y = S.y - 32
    end
    function S.slider(label, key, min, max, fmt)
        API.newLabel(sc, label, 40, S.y - 4)
        local sl = API.makeSlider(sc, 160, min, max, 1, fmt, function(v) set(key, v); changed() end)
        sl:SetPoint("TOPLEFT", 260, S.y)
        S.sliders[key] = sl
        S.y = S.y - 40
    end
    function S.seg(label, key, opts)
        API.newLabel(sc, label, 40, S.y - 4)
        S.rows[#S.rows + 1] = API.segRow(sc, 220, S.y, opts, function() return get(key) end, function(v) set(key, v); changed() end)
        S.y = S.y - 36
    end
    function S.gap(n) S.y = S.y - (n or 8) end
    function S.done()
        sc:SetHeight(-S.y + 40)
        if #S.tabs > 1 and API.makeTabs then S.select = API.makeTabs(panel, scroll, sc, S.tabs) end
    end
    function S.refresh()
        for k, cb in pairs(S.checks) do cb:SetChecked(get(k) and true or false) end
        for k, sl in pairs(S.sliders) do API.setSlider(sl, get(k)) end
        for _, r in ipairs(S.rows) do r.refresh() end
        for _, fn in ipairs(S.extra) do pcall(fn) end
    end
    panel:SetScript("OnShow", S.refresh)
    return S
end

local TXT = { { "none", "None", 56 }, { "value", "Current", 70 }, { "percent", "Percent", 70 }, { "both", "Both", 54 },
              { "curmax", "Cur / max", 80 }, { "all", "All", 44 } }

-- What each unit's floating settings hold (also what its Reset puts back).
local FLOAT_KEYS = {
    player = { "sPlayer", "pX", "pY" },
    pet = { "sPet", "petX", "petY" },
    target = { "sTarget" }, targettarget = { "sToT" }, focus = { "sFocus" }, focustarget = { "sFoT" },
    party = { "sParty", "partyX", "partyY", "partyGap", "partyRole", "partyPreview" },
    raid = { "sRaid", "raidX", "raidY", "raidGap", "raidPer", "raidPreview", "raidRole", "raidWidth", "raidPortrait",
             "raidPower", "raidCast", "raidCC", "raidDebuffs", "raidNameSize", "raidTextSize", "raidBuffs",
             "raidDebuffSize", "raidDebuffMax", "raidDebuffPos", "raidDebuffX", "raidDebuffY",
             "raidBuffSize", "raidBuffMax", "raidBuffPos", "raidBuffX", "raidBuffY",
             "raidAuraTimeSize", "raidAuraTimeX", "raidAuraTimeY" },
}
local LOOK_KEYS = { "enemy", "friendly", "hidePlate", "y", "portrait", "classIcon", "power", "width", "nameSize", "classColour",
                    "hpText", "powText", "textSize", "cast", "castIcon", "castName", "castTime", "castTextSize", "cc",
                    "debuffs", "debuffMine", "buffs", "buffMine", "debuffSize", "debuffMax", "debuffPos", "debuffX", "debuffY",
                    "buffSize", "buffMax", "buffPos", "buffX", "buffY", "powTextSize", "powH", "auraTimeSize", "auraTimeX", "auraTimeY",
                    "rareBorder", "rareSize", "rareX", "rareY",
                    "debuffOnlyMine", "debuffBoss", "debuffMaxMin", "buffOnlyMine", "buffStealable", "buffMaxMin" }
for _, k in ipairs(LOOK_KEYS) do LOOKSET[k] = true end
local function resetKeys(keys)
    local dflt, d = defaults(), DB()
    for _, k in ipairs(keys) do d[k] = dflt[k] end
    refreshAll()
end
local function resetLook(unit)
    local dflt, d = defaults(), DB()
    d.look = d.look or {}
    local L = {}
    for _, k in ipairs(LOOK_KEYS) do L[k] = dflt[k] end
    d.look[unit] = L
end

local LOOK_GROUPS = { player = true, pet = true, target = true, targettarget = true, focus = true, focustarget = true, party = true }
local function lookStore(unit)
    return function()
        local D = DB()
        D.look = D.look or {}
        local L = D.look[unit]
        if not L then L = {}; D.look[unit] = L end
        return L
    end
end

local WHERE = { { "above", "Above", 80 }, { "below", "Below", 80 } }
-- The design of one kind of floating frame (every kind has its own).
local function lookSections(S, unit)
    local head = unit == "target" or unit == "targettarget" or unit == "focus" or unit == "focustarget"
    S.gap()
    if head then
        S.head("Over the unit's head")
        S.check("On enemies (red)", "enemy")
        S.check("On friendly units (green)", "friendly")
        S.check("Hide the nameplate under the frame", "hidePlate")
        S.slider("Height above the unit", "y", -100, 200, px)
        S.gap()
    end
    S.head("Look")
    S.check("Round portrait", "portrait")
    S.check("Class icon instead of the portrait on players", "classIcon", 48)
    S.check("Elite / rare / boss border around the portrait", "rareBorder", 48)
    S.slider("Elite / rare border size", "rareSize", 30, 250, pct)
    S.slider("Elite / rare border left / right", "rareX", -40, 40, px)
    S.slider("Elite / rare border up / down", "rareY", -40, 40, px)
    S.check("Resource bar under the health bar", "power")
    if not head then S.check("Class-coloured health bar", "classColour") end
    S.slider("Bar width", "width", 60, 400, px)
    S.seg("Bar corners (every frame)", "barRound", { { "off", "Square", 70 }, { "slight", "Slight", 70 }, { "medium", "Medium", 80 }, { "round", "Round", 70 } })
    S.slider("Bar spacing (every frame)", "barGap", 0, 20, px)
    S.note("The health, resource and cast bars share these two settings on every floating frame (player, pet, party, raid, target, focus and the rest), so they all look the same.")
    S.slider("Name size", "nameSize", 8, 24, px)
    if unit == "player" or unit == "target" then
        S.gap()
        S.head("Class resource (every frame)")
        S.note("Combo points (rogue, druid) on your target's frame; holy power, soul shards, chi, arcane charges, essence or runes on your player frame. The cast bar and auras move down to make room.")
        S.check("Show the class resource", "resOn")
        S.seg("Combo points on", "resCombo", { { "target", "Target frame", 100 }, { "player", "Player frame", 100 }, { "both", "Both", 60 } })
        S.seg("Shape", "resShape", { { "dots", "Dots", 70 }, { "segments", "Segments", 90 } })
        S.slider("Size", "resSize", 4, 30, px)
        S.slider("Space between", "resGap", 0, 20, px)
        S.seg("Align", "resAlign", { { "left", "Left", 70 }, { "center", "Centre", 80 }, { "right", "Right", 70 } })
        S.slider("Left / right", "resX", -200, 200, px)
        S.slider("Up / down", "resY", -60, 60, px)
        S.check("Show the empty points", "resEmpty")
        S.check("Show a test row (turn it off again afterwards)", "resPreview")
    end
    S.gap()
    S.tab("Text")
    S.head("Text")
    S.note("Current: the amount. Both: amount and percent. Cur / max: amount and maximum. All: amount, maximum and percent.")
    S.seg("Health text", "hpText", TXT)
    S.slider("Health text size", "textSize", 6, 20, px)
    S.seg("Resource text", "powText", TXT)
    S.slider("Resource text size", "powTextSize", 6, 20, px)
    S.slider("Resource bar height", "powH", 3, 20, px)
    S.gap()
    S.tab("Cast bar")
    S.head("Cast bar")
    S.check("Cast bar under the bars (as long and tall as the health bar)", "cast")
    S.check("Spell icon", "castIcon", 48)
    S.check("Spell name", "castName", 48)
    S.seg("Time", "castTime", { { "none", "None", 70 }, { "current", "Left", 70 }, { "max", "Full time", 90 }, { "both", "Left / full", 100 } })
    S.slider("Cast text size", "castTextSize", 6, 20, px)
    S.gap()
    S.head("Crowd control")
    S.check("Crowd control over the portrait", "cc")
    S.gap()
    S.tab("Buffs & Debuffs")
    S.head("Debuffs")
    S.check("Show debuffs", "debuffs")
    S.seg("Where", "debuffPos", WHERE)
    S.slider("Distance from the frame", "debuffY", -40, 120, px)
    S.slider("Left / right", "debuffX", -200, 200, px)
    S.slider("Icon size", "debuffSize", 10, 48, px)
    S.slider("How many", "debuffMax", 1, 16, num)
    S.check("Only my debuffs", "debuffOnlyMine", 48)
    S.check("Only boss debuffs", "debuffBoss", 48)
    S.slider("Hide debuffs longer than (0 = show all)", "debuffMaxMin", 0, 60, function(v) return v <= 0 and "show all" or (math.floor(v + 0.5) .. " min") end)
    S.gap()
    S.head("Buffs")
    S.check("Show buffs", "buffs")
    S.seg("Where", "buffPos", WHERE)
    S.slider("Distance from the frame", "buffY", -40, 120, px)
    S.slider("Left / right", "buffX", -200, 200, px)
    S.slider("Icon size", "buffSize", 10, 48, px)
    S.slider("How many", "buffMax", 1, 16, num)
    S.check("Only my buffs", "buffOnlyMine", 48)
    S.check("Only stealable buffs", "buffStealable", 48)
    S.slider("Hide buffs longer than (0 = show all)", "buffMaxMin", 0, 60, function(v) return v <= 0 and "show all" or (math.floor(v + 0.5) .. " min") end)
    S.gap()
    S.head("Time text on the icons")
    S.slider("Size", "auraTimeSize", 40, 250, pct)
    S.slider("Left / right", "auraTimeX", -30, 30, px)
    S.slider("Up / down", "auraTimeY", -30, 30, px)
    S.note("Buffs and debuffs are placed separately. The time starts centred on the top edge of each icon. Point at an icon to see its tooltip.")
    S.gap()
    S.head("Hide specific buffs and debuffs")
    if API.auraPicker then
        local ok, ref, bottom = pcall(API.auraPicker, S.sc, S.y - 4, (unit == "party") and "party1" or unit)
        if ok and ref then
            S.extra[#S.extra + 1] = ref
            S.y = (bottom or (S.y - 380)) - 10
        end
    end
    S.note("A hidden spell stays hidden on every floating and halo frame until you show it again. Some auras can't be told apart during a fight.")
end

local function floatSheet(parent, unit)
    local S = sheet(parent, LOOK_GROUPS[unit] and lookStore(unit) or nil)
    S.tab("Frame")

    local head = unit == "target" or unit == "targettarget" or unit == "focus" or unit == "focustarget"
    local names = { player = "your player frame", pet = "your pet frame", target = "your target", targettarget = "your target's target",
                    focus = "your focus", focustarget = "your focus's target", party = "your party members", raid = "your raid" }
    if head then
        S.note("A small frame that hangs over " .. names[unit] .. " and moves with them. It rides on their nameplate, so the unit needs one (friendly units need friendly nameplates on in the game). Design is set below, for this frame only.")
        S.slider("Size", ({ target = "sTarget", targettarget = "sToT", focus = "sFocus", focustarget = "sFoT" })[unit], 40, 250, pct)
    elseif unit == "player" then
        S.note("Your own frame, in one place on the screen. The design (bars, text, cast bar, auras) is set below, for this frame only.")
        S.slider("Size", "sPlayer", 40, 250, pct)
        S.slider("Left / right", "pX", -1200, 1200, px)
        S.slider("Up / down", "pY", -700, 700, px)
    elseif unit == "pet" then
        S.note("Your pet's frame, in one place on the screen. It shows while you have a pet. Its design (bars, text, cast bar, auras) is set below.")
        S.slider("Size", "sPet", 40, 250, pct)
        S.slider("Left / right", "petX", -1200, 1200, px)
        S.slider("Up / down", "petY", -700, 700, px)
    elseif unit == "party" then
        S.note("One frame per party member, stacked in one place. Left-click targets, right-click opens the menu. In a raid they step aside for the raid frames. Design is set below.")
        S.check("Role icon on each member", "partyRole")
        S.check("Preview the frames while you are not in a group", "partyPreview")
        S.slider("Size", "sParty", 40, 250, pct)
        S.slider("Space between members", "partyGap", 0, 80, px)
        S.slider("Left / right", "partyX", -1200, 1200, px)
        S.slider("Up / down", "partyY", -700, 700, px)
    elseif unit == "raid" then
        S.note("A smaller frame for every raid member, laid out in rows. Left-click targets, right-click opens the menu. They have a design of their own (below), so forty of them stay small.")
        S.check("Role icon on each member", "raidRole")
        S.check("Preview the frames while you are not in a group", "raidPreview")
        S.slider("Size", "sRaid", 40, 250, pct)
        S.slider("Members in a row", "raidPer", 1, 40, num)
        S.slider("Space between members", "raidGap", 0, 40, px)
        S.slider("Left / right", "raidX", -1200, 1200, px)
        S.slider("Up / down", "raidY", -700, 700, px)
        S.gap()
        S.head("Raid frame design")
        S.slider("Bar width", "raidWidth", 40, 250, px)
        S.check("Round portrait", "raidPortrait")
        S.check("Resource bar", "raidPower")
        S.check("Cast bar", "raidCast")
        S.check("Crowd control over the frame", "raidCC")
        S.check("Debuffs", "raidDebuffs")
        S.check("Buffs", "raidBuffs")
        S.slider("Name size", "raidNameSize", 6, 20, px)
        S.slider("Text size", "raidTextSize", 6, 20, px)
        S.gap()
        S.tab("Buffs & Debuffs")
        S.head("Raid debuffs")
        S.seg("Where", "raidDebuffPos", WHERE)
        S.slider("Distance from the frame", "raidDebuffY", -40, 120, px)
        S.slider("Left / right", "raidDebuffX", -200, 200, px)
        S.slider("Icon size", "raidDebuffSize", 8, 40, px)
        S.slider("How many", "raidDebuffMax", 1, 12, num)
        S.gap()
        S.head("Raid buffs")
        S.seg("Where", "raidBuffPos", WHERE)
        S.slider("Distance from the frame", "raidBuffY", -40, 120, px)
        S.slider("Left / right", "raidBuffX", -200, 200, px)
        S.slider("Icon size", "raidBuffSize", 8, 40, px)
        S.slider("How many", "raidBuffMax", 1, 12, num)
        S.gap()
        S.head("Time text on the icons")
        S.slider("Size", "raidAuraTimeSize", 40, 250, pct)
        S.slider("Left / right", "raidAuraTimeX", -30, 30, px)
        S.slider("Up / down", "raidAuraTimeY", -30, 30, px)
    end
    if LOOK_GROUPS[unit] then lookSections(S, unit) end
    S.done()
    return S
end

local DESC = {
    halo = "The round halo frame: its health, resource and cast in rings around the picture.",
    game = "The game's own frame is used. Nothing from this addon is drawn for this unit.",
}

local function unitPage(t)
    local U = CreateFrame("Frame")
    U.name = t.label
    local unit = t.unit
    local haloKey = HALO_PAGE[unit]
    API.newLabel(U, "Frame style", 16, -24, "GameFontNormal")
    local opts = { { "float", "Floating", 90 }, { "game", "Game's own", 110 } }
    if haloKey then table.insert(opts, 1, { "halo", "Halo", 80 }) end
    local row
    local area = CreateFrame("Frame", nil, U)
    area:SetPoint("TOPLEFT", 0, -88)
    area:SetPoint("BOTTOMRIGHT")
    local F = floatSheet(area, unit)
    F.panel:SetAllPoints(area)
    local gameNote = area:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    gameNote:SetPoint("TOPLEFT", 16, -8)
    gameNote:SetWidth(600); gameNote:SetJustifyH("LEFT")
    gameNote:SetText(DESC.game)
    local function show()
        local st = styleOf(unit)
        local hp = haloKey and API.pages[haloKey] and API.pages[haloKey].panel
        if hp then
            if st == "halo" then
                hp:SetParent(area); hp:ClearAllPoints(); hp:SetAllPoints(area); hp:Show()
            else
                hp:Hide()
            end
        end
        F.panel:SetShown(st == "float")
        gameNote:SetShown(st == "game")
        local line = st == "halo" and DESC.halo or (st == "float" and "The floating style: a small flat frame with bars, text and auras. Its design is set on this tab. Fade it from Fading > Rules > Floating frames (Ubermoc UI)." or DESC.game)
        U.line:SetText(line)
    end
    U.line = U:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    U.line:SetPoint("TOPLEFT", 16, -62)
    U.line:SetWidth(600); U.line:SetJustifyH("LEFT")
    row = API.segRow(U, 130, -18, opts, function() return styleOf(unit) end, function(v) setStyle(unit, v); show() end)
    local function refresh() row.refresh(); show(); F.refresh() end
    unitPages[t.key] = function() if U:IsVisible() then refresh() end end
    U:SetScript("OnShow", refresh)
    API.addPage(t.key, t.label, U)
    API.resetters[t.key] = function()
        if haloKey and API.resetters[haloKey] then pcall(API.resetters[haloKey]) end
        resetKeys(FLOAT_KEYS[unit] or {})
        if LOOK_GROUPS[unit] then resetLook(unit); refreshAll() end
    end
end

local TABS = {
    { key = "uf_player", label = "Player", unit = "player" },
    { key = "uf_pet", label = "Pet", unit = "pet" },
    { key = "uf_target", label = "Target", unit = "target" },
    { key = "uf_tot", label = "Target of Target", unit = "targettarget" },
    { key = "uf_focus", label = "Focus", unit = "focus" },
    { key = "uf_fot", label = "Focus Target", unit = "focustarget" },
    { key = "uf_party", label = "Party", unit = "party" },
    { key = "uf_raid", label = "Raid", unit = "raid" },
}
local function buildPages()
    API.resetters = API.resetters or {}
    for _, t in ipairs(TABS) do
        local ok, err = pcall(unitPage, t)
        if not ok and API.uiPrint then API.uiPrint("Unit frame page failed (" .. t.label .. "): " .. tostring(err)) end
    end
end

local prev = API.onLogin
API.onLogin = function()
    if prev then prev() end
    DB()
    for _, u in ipairs(UNITS) do pcall(build, u) end
    for _, u in ipairs(FIXED) do pcall(buildFixed, u) end
    if API.registerMover then
        local function fixedMover(label, unit, xk, yk, flag)
            API.registerMover(label, function()
                local d, f = DB(), fixedF[unit]
                local s = f and f:GetScale() or 1
                return d[flag], d[xk], d[yk], (f and f:GetWidth() or 200) * s, (f and f:GetHeight() or 46) * s
            end, function(x, yy)
                local d = DB()
                d[xk], d[yk] = math.floor(x + 0.5), math.floor(yy + 0.5)
                pcall(layoutFixed)
            end)
        end
        fixedMover("Floating player frame", "player", "pX", "pY", "playerFloat")
        fixedMover("Floating pet frame", "pet", "petX", "petY", "petFloat")
        API.registerMover("Floating party frames", function()
            local d, f = DB(), fixedF.party1
            local s = f and f:GetScale() or 1
            local w = (f and f:GetWidth() or 200) * s
            local h = f and (4 * partyStep(f, d) - (d.partyGap or 14)) or 240
            return d.partyFloat, d.partyX + w / 2, d.partyY - h / 2, w, h
        end, function(x, yy)
            local d, f = DB(), fixedF.party1
            local s = f and f:GetScale() or 1
            local w = (f and f:GetWidth() or 200) * s
            local h = f and (4 * partyStep(f, d) - (d.partyGap or 14)) or 240
            d.partyX, d.partyY = math.floor(x - w / 2 + 0.5), math.floor(yy + h / 2 + 0.5)
            pcall(layoutFixed)
        end)
        API.registerMover("Floating raid frames", function()
            local d = DB()
            local f = fixedF.raid1
            local s = f and f:GetScale() or 1
            local per = math.max(1, math.floor(d.raidPer or 5))
            local rows = math.ceil((inRaidNow() and MAXRAID or RAIDPREVIEW) / per)
            local cw = (f and f:GetWidth() or 90) * s + (d.raidGap or 6)
            local ch = f and ((f.topExt + f.botExt) * s + (d.raidGap or 6)) or 40
            local w, h = per * cw - (d.raidGap or 6), rows * ch - (d.raidGap or 6)
            return d.raidFloat, d.raidX + w / 2, d.raidY - h / 2, w, h
        end, function(x, yy)
            local d = DB()
            local f = fixedF.raid1
            local s = f and f:GetScale() or 1
            local per = math.max(1, math.floor(d.raidPer or 5))
            local rows = math.ceil((inRaidNow() and MAXRAID or RAIDPREVIEW) / per)
            local cw = (f and f:GetWidth() or 90) * s + (d.raidGap or 6)
            local ch = f and ((f.topExt + f.botExt) * s + (d.raidGap or 6)) or 40
            local w, h = per * cw - (d.raidGap or 6), rows * ch - (d.raidGap or 6)
            d.raidX, d.raidY = math.floor(x - w / 2 + 0.5), math.floor(yy + h / 2 + 0.5)
            pcall(layoutFixed)
        end)
    end
    -- Defaults to the floating style for every unit.
    do
        local d = DB()
        d.haloAllV1 = true
        -- One time: every unit now starts with the floating frame (the halo frame and the game's own are a click away).
        if not d.floatAllV1 then
            d.floatAllV1 = true
            for _, flag in pairs(FLAG) do d[flag] = true end
            for _, u in ipairs({ "player", "target", "targettarget", "focus", "focustarget", "party", "raid", "pet" }) do pcall(haloSwitch, u, false) end
        end
    end
    API.later("Unit frames", buildPages)
    refreshAll()
end
