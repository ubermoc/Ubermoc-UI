-- Ubermoc UI - Copyright (c) 2026 Marcos. All rights reserved.
-- This file is protected by copyright. It may not be copied, modified, redistributed or reused, in whole or
-- in part, without the written permission of the author. See LICENSE.txt.
----------------------------------------------------------------------
-- Ubermoc UI extras: pet ring, utility ring and the interact key.
-- Everything here is written for Ubermoc UI; the ideas (a radial ring of actions,
-- a pet frame, interacting with what you face) are common to many UIs.
----------------------------------------------------------------------
local API = UbermocUIAPI
-- Game window functions are called through securecallfunction, so the taint of this addon is not carried into
-- the game's own panel bookkeeping (which later made Edit Mode and the arena frames fail).
local function secureCall(fn, ...)
    if securecallfunction then return pcall(securecallfunction, fn, ...) end
    return pcall(fn, ...)
end
if not API then return end

local DB
local pendingRebuild = false

-- Centre text of a ring: wraps inside the ring and shrinks until it fits.
local function setLabel(r, txt)
    local fs = r.label
    local w = r.innerW or 100
    fs:SetWidth(w)
    fs:SetText(txt or "")
    local font = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
    for sz = 16, 8, -1 do
        pcall(fs.SetFont, fs, font, sz, "")
        local h, sw = fs:GetStringHeight(), fs:GetStringWidth()
        if type(h) == "number" and type(sw) == "number" and h <= w * 0.6 and sw <= w + 1 then break end
    end
end

local function defaults()
    return {
        petRing = { on = true, beam = true, size = 20, radius = 50, hold = true, pos = "BOTTOM", x = 0, y = 170, flipY = false },
        utilRing = { on = true, beam = true, size = 20, radius = 50, hold = true, pos = "BOTTOM", x = 0, y = 170, flipY = false, autoExtra = true, autoQuest = true, slots = {} },
        cmicroRing = { on = true, mouse = true, borders = false, corner = "BOTTOMRIGHT", size = 30, radius = 190, hold = true, flipY = false, beam = false },
        cbagRing = { on = true, mouse = true, borders = false, corner = "BOTTOMLEFT", size = 30, radius = 150, hold = true, flipY = false, beam = false },
        menuRing = { on = true, beam = true, size = 34, radius = 84, hold = true, pos = "BOTTOM", x = 0, y = 170, flipY = false },
        cursor = { on = true, auto = true, tips = true },
        ringRound = true,
        stickMax = 0.1, stickExtra = 0.1,
    }
end

local function merge(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            merge(dst[k], v)
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

local function say(msg)
    if API.uiPrint then API.uiPrint("|cff00ccffUbermoc UI|r " .. msg) else print("|cff00ccffUbermoc UI|r " .. msg) end
end

local function useDown()
    local ok, v = pcall(GetCVarBool, "ActionButtonUseKeyDown")
    return ok and v and true or false
end

----------------------------------------------------------------------
-- Ring: a secure radial menu. Opens from a key, clicking an entry uses it and closes the ring.
----------------------------------------------------------------------
local rings = {}
local MAXSLOTS = 12     -- entries you add yourself
local RINGMAX = 24      -- most entries a ring can show (yours plus the automatic ones)

local function iconFor(slot)
    if not slot then return nil end
    if slot.t == "spell" then
        local ok, tex = pcall(function() return C_Spell and C_Spell.GetSpellTexture(slot.id) or GetSpellTexture(slot.id) end)
        return ok and tex or nil
    elseif slot.t == "item" then
        local ok, tex = pcall(function() return C_Item and C_Item.GetItemIconByID(slot.id) or GetItemIcon(slot.id) end)
        return ok and tex or nil
    elseif slot.t == "macro" then
        local ok, _, tex = pcall(GetMacroInfo, slot.name)
        return ok and tex or nil
    elseif slot.t == "micro" or slot.t == "bags" then
        return slot.icon
    elseif slot.t == "dismount" then
        return "Interface\\Icons\\Ability_Mount_RidingHorse"
    elseif slot.t == "extra" then
        local act = (ExtraActionButton1 and ExtraActionButton1.action) or 169
        local ok, tex = pcall(GetActionTexture, act)
        return ok and tex or "Interface\\Icons\\INV_Misc_QuestionMark"
    end
end

-- The gamepad stick that picks entries (by config name; "Left" is the left stick).
local stickIndex = nil
local function findStick()
    stickIndex = nil
    if not (C_GamePad and C_GamePad.StickIndexToConfigName) then return end
    local i = 0
    while true do
        local ok, name = pcall(C_GamePad.StickIndexToConfigName, i)
        if not ok or not name then break end
        if name == "Left" and not stickIndex then stickIndex = i + 1 end
        i = i + 1
        if i > 16 then break end
    end
end

-- One shared frame that takes the stick away from the game while a ring is open, so the
-- character does not walk and the camera does not turn while you pick an entry.
local blocker
local openRings = 0
local stickCfg = function() return 2.5, 0 end
local function blockSticks(on)
    if not blocker then
        blocker = CreateFrame("Frame", "UbermocRingBlocker", UIParent)
        blocker:SetFrameStrata("TOOLTIP")
        blocker:SetScript("OnGamePadStick", function() end)
    end
    if on then
        openRings = openRings + 1
        blocker:SetScript("OnUpdate", nil)
        blocker:EnableGamePadStick(true)
    else
        openRings = math.max(0, openRings - 1)
        if openRings == 0 then
            -- Keep taking the stick until it is back in the middle, so the character does not walk off
            -- in the direction you were pointing after the ability is used.
            blocker.t = 0
            blocker.centred = nil
            local maxHold, extra = stickCfg()
            if maxHold <= 0 then
                blocker:EnableGamePadStick(false)
                return
            end
            blocker:SetScript("OnUpdate", function(self, dt)
                self.t = self.t + dt
                local len = 0
                local ok, state = pcall(C_GamePad.GetDeviceMappedState)
                local pos = ok and state and state.sticks and stickIndex and state.sticks[stickIndex]
                if pos and pos.len then len = pos.len end
                if openRings > 0 then
                    self:SetScript("OnUpdate", nil)
                else
                    if len < 0.2 then self.centred = (self.centred or 0) + dt else self.centred = nil end
                    if (self.centred and self.centred >= extra) or self.t > maxHold then
                        self:SetScript("OnUpdate", nil)
                        self:EnableGamePadStick(false)
                    end
                end
            end)
        end
    end
end

-- Corner wheels: the arc covers one quarter of the screen around a corner. ARC0 is where the quarter starts
-- (degrees clockwise from straight up); icons are spread over ARC_PAD .. 90 - ARC_PAD inside it.
local ARC0 = { BOTTOMRIGHT = 270, BOTTOMLEFT = 0, TOPRIGHT = 180, TOPLEFT = 90 }
local ARC_PAD = 8
-- Index (1..n) of the entry the stick points at, or nil when the stick is centred.
local function stickSelection(r, n)
    if n < 1 or not stickIndex or not (C_GamePad and C_GamePad.GetDeviceMappedState) then return nil end
    local ok, state = pcall(C_GamePad.GetDeviceMappedState)
    local pos = ok and state and state.sticks and state.sticks[stickIndex]
    if not pos or not pos.len then return nil end
    local x, y = pos.x, pos.y
    if DB[r.cfgKey].flipY then y = -y end
    local a = math.deg(math.atan2(x, y))
    if a < 0 then a = a + 360 end
    if pos.len < 0.5 then return nil, a, pos.len end
    if r.arc then
        local a0 = (ARC0[DB[r.cfgKey].corner] or 270) + ARC_PAD
        local span = 90 - 2 * ARC_PAD
        local d = (a - a0) % 360
        if d > span then if d - span < 360 - d then d = span else d = 0 end end
        return (n > 1) and (math.floor(d / span * (n - 1) + 0.5) + 1) or 1, a, pos.len
    end
    local step = 360 / n
    return math.floor(a / step + 0.5) % n + 1, a, pos.len
end

local function placeRing(r)
    if InCombatLockdown() then return end
    local c = DB[r.cfgKey]
    local f = r.frame
    if r.arc then
        local corner = c.corner or "BOTTOMRIGHT"
        local inset = (c.size or 30) / 2 + 8
        f:ClearAllPoints()
        f:SetPoint("CENTER", UIParent, corner, corner:find("RIGHT") and -inset or inset, corner:find("TOP") and -inset or inset)
        return
    end
    local m = (r.R or 125) + 4
    local w, h = UIParent:GetWidth(), UIParent:GetHeight()
    local x, y
    if c.pos == "CURSOR" then
        local cx, cy = GetCursorPosition()
        local s = UIParent:GetEffectiveScale()
        x, y = cx / s, cy / s
    elseif c.pos == "CENTER" then
        x, y = w / 2 + (c.x or 0), h / 2
    else
        x, y = w / 2 + (c.x or 0), (c.y or 170)
    end
    x = math.max(m, math.min(w - m, x))
    y = math.max(m, math.min(h - m, y))
    f:ClearAllPoints()
    f:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
end

-- Menu entries open through the game's own button (a secure click, so nothing gets tainted). If that click
-- opened nothing (some buttons only react to a real mouse), the window is opened directly instead.
local MICRO_WATCH = { "CharacterFrame", "ProfessionsBookFrame", "PlayerSpellsFrame", "AchievementFrame", "WorldMapFrame",
    "QuestLogFrame", "CommunitiesFrame", "GuildFrame", "PVEFrame", "CollectionsJournal", "EncounterJournal", "GameMenuFrame" }
-- After a menu entry opens a window, the controller cursor goes to it.
local function cursorToPage()
    if InCombatLockdown() then return end
    for _, t in ipairs({ 0.4, 1.0 }) do
        C_Timer.After(t, function() if API.cursorActivate then pcall(API.cursorActivate) end end)
    end
end
local MICRO_OPEN = {
    TOGGLECHARACTER0 = function() ToggleCharacter("PaperDollFrame") end,
    TOGGLEPROFESSIONBOOK = function() ToggleProfessionsBook() end,
    TOGGLESPELLBOOK = function() PlayerSpellsUtil.ToggleSpellBookFrame() end,
    TOGGLEACHIEVEMENT = function() ToggleAchievementFrame() end,
    TOGGLEQUESTLOG = function() ToggleQuestLog() end,
    TOGGLEGUILDTAB = function() ToggleGuildFrame() end,
    TOGGLEGROUPFINDER = function() PVEFrame_ToggleFrame() end,
    TOGGLECOLLECTIONS = function() ToggleCollectionsJournal() end,
    TOGGLEENCOUNTERJOURNAL = function() ToggleEncounterJournal() end,
    -- not the game's ToggleGameMenu: that also stops casting, which addon code may not do
    TOGGLEGAMEMENU = function()
        local gm = _G.GameMenuFrame
        if gm and not gm:IsShown() and not InCombatLockdown() then secureCall(ShowUIPanel, gm) end
    end,
}
local function microSnap()
    local t = {}
    for i, n in ipairs(MICRO_WATCH) do
        local f = _G[n]
        local ok, sh = pcall(function() return f and f:IsShown() end)
        t[i] = (ok and sh) and "1" or "0"
    end
    return table.concat(t)
end
local function microFallback(s, before)
    if not s or s.t ~= "micro" or not s.bind or not MICRO_OPEN[s.bind] then return end
    if microSnap() == before then pcall(MICRO_OPEN[s.bind]) end
end

local function newRing(key, title, cfgKey)
    local r = { key = key, cfgKey = cfgKey, buttons = {}, title = title, n = 0 }
    local f = CreateFrame("Frame", "UbermocRing" .. key, UIParent, "SecureHandlerBaseTemplate")
    f:SetSize(1, 1)
    f:SetPoint("CENTER", UIParent, "BOTTOM", 0, 170)
    f:SetFrameStrata("DIALOG")
    f:Hide()
    r.frame = f

    -- Dark disc the entries sit on, a faint turning rune layer, and a beam that points where the stick points.
    r.disc = f:CreateTexture(nil, "BACKGROUND", nil, -2)
    r.disc:SetTexture("Interface\\AddOns\\UbermocUI\\Media\\ringdisc.tga")
    r.disc:SetPoint("CENTER", f, "CENTER", 0, 0)
    r.disc:SetVertexColor(0.03, 0.035, 0.055, 0.8)
    -- Clean flat look: thin hairline rings and a dark inner disc.
    local function hair(layer, r_, g_, b_, a_)
        local t = f:CreateTexture(nil, "BACKGROUND", nil, layer)
        t:SetTexture("Interface\\AddOns\\UbermocUI\\Media\\ringdisc.tga")
        t:SetPoint("CENTER", f, "CENTER", 0, 0)
        t:SetVertexColor(r_, g_, b_, a_)
        local m = f:CreateMaskTexture()
        m:SetTexture("Interface\\AddOns\\UbermocUI\\Media\\ringhole.tga", "CLAMP", "CLAMP")
        m:SetPoint("CENTER", f, "CENTER", 0, 0)
        t:AddMaskTexture(m)
        return { tex = t, mask = m }
    end
    r.hOuter = hair(-1, 0.17, 0.19, 0.26, 1)
    r.hTrack = hair(-1, 0.105, 0.12, 0.17, 1)
    r.innerDisc = f:CreateTexture(nil, "BACKGROUND", nil, -1)
    r.innerDisc:SetTexture("Interface\\AddOns\\UbermocUI\\Media\\ringdisc.tga")
    r.innerDisc:SetPoint("CENTER", f, "CENTER", 0, 0)
    r.innerDisc:SetVertexColor(0.05, 0.055, 0.08, 0.95)
    r.hInner = hair(0, 0.17, 0.19, 0.26, 1)
    if API.skinNew then r.skin = API.skinNew(f, "BACKGROUND", 1) end
    r.runes = f:CreateTexture(nil, "BACKGROUND", nil, -1)
    r.runes:SetPoint("CENTER", f, "CENTER", 0, 0)
    r.runes:SetBlendMode("ADD")
    r.runes:SetAlpha(0) -- static and invisible: the slowly turning layer was removed
    pcall(r.runes.SetAtlas, r.runes, "heartofazeroth-orb-activated", false)
    r.runeAnim = f:CreateAnimationGroup()
    r.runeAnim:SetLooping("REPEAT")
    local rot = r.runeAnim:CreateAnimation("Rotation")
    rot:SetDegrees(-360)
    rot:SetDuration(40)
    r.beam = f:CreateTexture(nil, "BORDER")
    r.beam:SetTexture("Interface\\AddOns\\UbermocUI\\Media\\beam.tga")
    r.beam:SetPoint("CENTER", f, "CENTER", 0, 0)
    r.beam:SetAlpha(0)
    r.dividers = {}
    r.label = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    do local p0, s0 = r.label:GetFont(); if p0 then r.label:SetFont(p0, s0, "OUTLINE") end end
    r.label:SetShadowOffset(0, 0)
    r.label:SetPoint("CENTER", f, "CENTER", 0, 0)
    r.label:SetWidth(120)
    r.label:SetWordWrap(true)
    r.label:SetJustifyH("CENTER")
    r.label:SetText(title)
    r.rule = f:CreateTexture(nil, "OVERLAY")
    r.rule:SetSize(52, 2)
    r.rule:SetPoint("TOP", r.label, "BOTTOM", 0, -8)
    local ac = API.accent or { 0.2, 0.7, 1 }
    r.rule:SetColorTexture(ac[1], ac[2], ac[3], 1)

    -- Pops up: grows from small and fades in.
    r.anim = f:CreateAnimationGroup()
    local sc = r.anim:CreateAnimation("Scale")
    sc:SetScaleFrom(0.55, 0.55)
    sc:SetScaleTo(1, 1)
    sc:SetDuration(0.16)
    sc:SetSmoothing("OUT")
    local al = r.anim:CreateAnimation("Alpha")
    al:SetFromAlpha(0)
    al:SetToAlpha(1)
    al:SetDuration(0.12)

    -- Trigger: a secure action button, so releasing the key can use the entry the stick points at.
    local tog = CreateFrame("Button", "UbermocRing" .. key .. "Toggle", UIParent, "SecureActionButtonTemplate, SecureHandlerBaseTemplate")
    tog:SetFrameRef("ring", f)
    tog:SetAttribute("useOnKeyDown", false)   -- the entry is used when the key is released (or on the second press)
    tog:SetAttribute("hold", true)
    tog:RegisterForClicks("AnyDown", "AnyUp")
    SecureHandlerWrapScript(tog, "PreClick", tog, [[
        local ring = self:GetFrameRef("ring")
        -- "*" names: the action still runs while modifier buttons are held (plain names only match with none held).
        self:SetAttribute("*type", nil)
        self:SetAttribute("*spell", nil)
        self:SetAttribute("*item", nil)
        self:SetAttribute("*macro", nil)
        self:SetAttribute("*macrotext", nil)
        self:SetAttribute("*action", nil)
        if self:GetAttribute("off") then return end
        local hold = self:GetAttribute("hold")
        local open = ring:IsShown()
        local show, act = false, false
        if hold then
            if down then show = true else act = open end
        else
            if down then return end
            if open then act = true else show = true end
        end
        if show then
            self:SetAttribute("sel", nil)
            ring:Show()
            return
        end
        if not act then return end
        local n = self:GetAttribute("n") or 0
        -- The entry the stick points at, kept up to date from outside the secure code (out of combat).
        local idx = self:GetAttribute("sel")
        if idx and (idx < 1 or idx > n) then idx = nil end
        if idx then
            local b = self:GetFrameRef("b" .. idx)
            local t = b and b:GetAttribute("type")
            if b:GetAttribute("ubself") then
                -- opened from outside the secure code after the release
            elseif t == "click" then
                -- the button to click ("*clickbutton") is kept up to date from outside, with the pick
                self:SetAttribute("*type", "click")
            elseif t then
                self:SetAttribute("*type", t)
                self:SetAttribute("*spell", b:GetAttribute("spell"))
                self:SetAttribute("*item", b:GetAttribute("item"))
                self:SetAttribute("*macro", b:GetAttribute("macro"))
                self:SetAttribute("*macrotext", b:GetAttribute("macrotext"))
                self:SetAttribute("*action", b:GetAttribute("action"))
            end
        end
        ring:Hide()
    ]])
    -- In combat the secure code cannot learn the pick; menu and bag entries are opened from here instead.
    tog:HookScript("PostClick", function(_, _, down)
        if down then return end
        local b = r.lastPick and r.buttons[r.lastPick]
        r.lastPick = nil
        local s = b and b.slot
        local snap = r.microSnap
        r.microSnap = nil
        if not s then return end
        if s.t == "bags" then
            if s.all then pcall(ToggleAllBags)   -- the menu wheel's "all bags" entry
            elseif s.bagId == 0 then pcall(ToggleBackpack)
            elseif s.bagId then pcall(ToggleBag, s.bagId) end
        elseif s.t == "micro" and snap and not InCombatLockdown() then
            microFallback(s, snap)
        end
        if s.t == "micro" or s.t == "bags" then cursorToPage() end
    end)
    tog:HookScript("PreClick", function(_, _, down)
        if not down then r.microSnap = microSnap() end
        local c = DB and DB[cfgKey]
        if c and down then placeRing(r) end
    end)
    r.toggle = tog

    -- Live highlight of the entry the stick points at.
    f:HookScript("OnShow", function()
        local ac2 = API.accent or { 0.2, 0.7, 1 }
        r.rule:SetColorTexture(ac2[1], ac2[2], ac2[3], 1)
        r.anim:Stop()
        r.anim:Play()
        r.shownAt = GetTime()
        r.lastPick = nil
        r.blocked = not r.mouseOpen
        if r.blocked then blockSticks(true) end
    end)
    f:HookScript("OnHide", function()
        if r.blocked then blockSticks(false); r.blocked = nil end
        r.mouseOpen = nil
        if API.gameTipLeave then API.gameTipLeave() end
        if GameTooltip:IsShown() then GameTooltip:Hide() end   -- the entry tooltip must not outlive the ring
        r.beam:SetAlpha(0)
        r.lastPick = r.selIdx
        r.selIdx = nil
        if not InCombatLockdown() then r.toggle:SetAttribute("*clickbutton", nil) end
        for _, b in pairs(r.buttons) do b.sel:Hide(); b.icon:SetAlpha(1) end
        setLabel(r, title)
    end)
    f:HookScript("OnUpdate", function()
        local idx, ang, len = stickSelection(r, r.n)
        -- Hand the pick to the secure release code (only possible out of combat).
        if not InCombatLockdown() then
            if r.toggle:GetAttribute("sel") ~= idx then r.toggle:SetAttribute("sel", idx) end
            local pb = idx and r.buttons[idx]
            local cb = (pb and pb:GetAttribute("type") == "click" and pb:GetAttribute("clickbutton")) or nil
            if r.toggle:GetAttribute("*clickbutton") ~= cb then r.toggle:SetAttribute("*clickbutton", cb) end
        end
        -- The beam of light from the middle toward the entry the stick points at (a setting on each ring).
        local bc = DB and DB[cfgKey]
        if ang and len and len > 0.12 and not (bc and bc.beam == false) then
            r.beam:SetRotation(-math.rad(ang))
            r.beam:SetAlpha(1)
        else
            r.beam:SetAlpha(0)
        end
        if idx ~= r.selIdx then
            r.selIdx = idx
            for i, b in pairs(r.buttons) do
                b.sel:SetShown(i == idx)
                if i == idx then
                    local a = API.accent or { 0.2, 0.7, 1 }
                    b.sel:SetColorTexture(a[1], a[2], a[3], 1)
                end
                b.icon:SetAlpha(1)
            end
            local b = idx and r.buttons[idx]
            if b and r.onEnter then r.onEnter(b)
            else
                if API.gameTipLeave then API.gameTipLeave() end
                GameTooltip:Hide()
            end
            if not r.arc then setLabel(r, (b and b.label) or title) end
        end
    end)
    rings[key] = r
    return r
end

local function ringErr(r, where, err)
    r.errors = r.errors or {}
    if #r.errors < 6 then r.errors[#r.errors + 1] = where .. ": " .. tostring(err) end
end

-- Each risky step is guarded on its own, so one failing call cannot leave the ring without entries.
-- Round entries: the square icon and its rims are cut into circles with masks.
local MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local function roundRingButton(b, on)
    pcall(function()
        if not rawget(b, "ubMasks") then
            local function mk(pad)
                local m = b:CreateMaskTexture()
                m:SetTexture(MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
                m:SetPoint("TOPLEFT", b, "TOPLEFT", -pad, pad)
                m:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", pad, -pad)
                return m
            end
            b.ubMasks = { icon = mk(0), edge = mk(3), sel = mk(6) }
        end
        local pairs_ = { { b.icon, b.ubMasks.icon }, { b.hl, b.ubMasks.icon }, { b.edge, b.ubMasks.edge }, { b.sel, b.ubMasks.sel } }
        for _, p in ipairs(pairs_) do
            if p[1] then
                if on then p[1]:AddMaskTexture(p[2]) else p[1]:RemoveMaskTexture(p[2]) end
            end
        end
    end)
end

-- The rim around each entry (Textures page, Radial Menus tab). The active and auto-cast rims keep their own colours.
local function dialPaint(b, state)
    local on, sz, r, g, bl, a = API.borderOf("dialButtons")
    local own = b.ringCfg and DB and DB[b.ringCfg]
    if own and own.borders == false then on = false end
    b.edge:ClearAllPoints()
    b.edge:SetPoint("TOPLEFT", -sz, sz)
    b.edge:SetPoint("BOTTOMRIGHT", sz, -sz)
    if state == "active" then b.edge:SetColorTexture(1, 0.82, 0, 1); b.edge:Show()
    elseif state == "auto" then b.edge:SetColorTexture(0.2, 0.9, 0.2, 1); b.edge:Show()
    else b.edge:SetColorTexture(r, g, bl, a); b.edge:SetShown(on) end
end
API.registerBorder({ key = "dialButtons", part = "dials", label = "Entry rim", size = 3, maxSize = 8,
    legacy = function() return true, 3, 100, "class" end,
    apply = function()
        for _, r in pairs(rings) do
            for _, b in pairs(r.buttons or {}) do if b.edge then pcall(dialPaint, b, b.ubDialState) end end
        end
    end })

-- Background opacity of every ring's discs (Textures page, Radial Menus tab).
local function ringBgApply(r)
    local d = API.skinDB and API.skinDB().dials
    local a = ((d and d.bgA) or 100) / 100
    if r.disc then r.disc:SetVertexColor(0.03, 0.035, 0.055, 0.8 * a) end
    if r.innerDisc then r.innerDisc:SetVertexColor(0.05, 0.055, 0.08, 0.95 * a) end
    if r.hOuter then r.hOuter.tex:SetVertexColor(0.17, 0.19, 0.26, a) end
    if r.hTrack then r.hTrack.tex:SetVertexColor(0.105, 0.12, 0.17, a) end
    if r.hInner then r.hInner.tex:SetVertexColor(0.17, 0.19, 0.26, a) end
end
function API.dialBgApply() for _, r in pairs(rings) do pcall(ringBgApply, r) end end

local function ringButton(r, i)
    local b = r.buttons[i]
    if b then return b end
    b = CreateFrame("Button", "UbermocRing" .. r.key .. "Btn" .. i, r.frame, "SecureActionButtonTemplate")
    b:SetID(i)
    b.ringCfg = r.cfgKey
    r.buttons[i] = b
    b:HookScript("PreClick", function(self) self.ubSnap = self.slot and self.slot.t == "micro" and microSnap() or nil end)
    b:HookScript("PostClick", function(self)
        if self.ubSnap then microFallback(self.slot, self.ubSnap); self.ubSnap = nil end
        if self.slot and (self.slot.t == "micro" or self.slot.t == "bags") then cursorToPage() end
    end)
    local function try(where, fn)
        local ok, err = pcall(fn)
        if not ok then ringErr(r, where .. " " .. i, err) end
    end
    -- Square icon with a coloured rim (no masks: they can make the whole entry vanish on some clients).
    b.sel = b:CreateTexture(nil, "BACKGROUND", nil, -2)
    b.sel:SetPoint("TOPLEFT", -6, 6)
    b.sel:SetPoint("BOTTOMRIGHT", 6, -6)
    b.sel:SetColorTexture(1, 0.82, 0, 1)
    b.sel:Hide()
    b.edge = b:CreateTexture(nil, "BACKGROUND", nil, -1)
    pcall(dialPaint, b)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.hl = b:CreateTexture(nil, "HIGHLIGHT")
    b.hl:SetAllPoints()
    b.hl:SetColorTexture(1, 1, 1, 0.25)
    b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    b.count:SetPoint("BOTTOMRIGHT", -2, 2)
    -- Cooldown swipe: nice to have, so a failure here is ignored.
    b.cd = { SetCooldown = function() end, Clear = function() end }
    try("cooldown", function()
        local cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
        cd:SetAllPoints()
        pcall(cd.SetDrawEdge, cd, false)
        pcall(cd.SetDrawBling, cd, false)
        pcall(cd.SetHideCountdownNumbers, cd, true)
        pcall(cd.SetSwipeTexture, cd, "Interface\\AddOns\\UbermocUI\\Media\\ringdisc.tga")
        pcall(cd.SetSwipeColor, cd, 0, 0, 0, 0.65)
        b.cd = cd
    end)
    try("round", function() if DB and DB.ringRound ~= false then roundRingButton(b, true) end end)
    try("clicks", function() b:RegisterForClicks("AnyDown", "AnyUp") end)
    -- A left click uses the entry and closes the ring.
    try("wrap", function()
        SecureHandlerWrapScript(b, "OnClick", r.frame, nil, [[
            if button == "LeftButton" then owner:Hide() end
        ]])
    end)
    b:SetScript("OnEnter", function(self)
        if r.onEnter then r.onEnter(self) end
    end)
    b:SetScript("OnLeave", function()
        if API.gameTipLeave then API.gameTipLeave() end
        GameTooltip:Hide()
    end)
    if not InCombatLockdown() then
        try("frameref", function() r.toggle:SetFrameRef("b" .. i, b) end)
    end
    return b
end

-- With the pet ring switched on, the game's pet and possess bars are hidden (and can't be clicked).
local function applyPetBarHide()
    local hh = API.holdHidden
    if not hh or not DB or not DB.petRing then return end
    local hide = DB.petRing.on and true or false
    for _, bar in ipairs({ { "PetActionBar", "PetActionButton", 10 }, { "PossessActionBar", "PossessButton", 2 } }) do
        local f = _G[bar[1]]
        if f then
            pcall(hh, f, hide)
            if not InCombatLockdown() then
                pcall(f.EnableMouse, f, false)
                for i = 1, bar[3] do
                    local b = _G[bar[2] .. i] or (f.actionButtons and f.actionButtons[i])
                    if b then pcall(b.EnableMouse, b, not hide) end
                end
            end
        end
    end
end
API.applyPetBarHide = applyPetBarHide

local function applyRingSwitches()
    pcall(applyPetBarHide)
    if InCombatLockdown() then pendingRebuild = true; return end
    findStick()
    for _, pair in ipairs({ { rings.Pet, DB.petRing }, { rings.Util, DB.utilRing }, { rings.Menu, DB.menuRing }, { rings.CMicro, DB.cmicroRing }, { rings.CBag, DB.cbagRing } }) do
        local r, c = pair[1], pair[2]
        if r then
            r.toggle:SetAttribute("off", not c.on)
            r.toggle:SetAttribute("hold", c.hold and true or false)
            r.toggle:SetAttribute("flipy", c.flipY and true or false)
            r.toggle:SetAttribute("stick", stickIndex)
        end
    end
end

local function applyClickMode()
    if InCombatLockdown() then pendingRebuild = true; return end
    local down = useDown()
    for _, r in pairs(rings) do
        for _, b in pairs(r.buttons) do
            b:RegisterForClicks(down and "AnyDown" or "AnyUp")
        end
    end
end

-- Places n buttons evenly on a circle, first one at the top, going clockwise.
-- The radius an arc of n icons needs for a gap between them: never less than the one set.
function API.arcRadius(radius, size, gap, n, spanDeg)
    if gap == nil then gap = 6 end
    if n < 2 then return radius end
    local step = math.rad(spanDeg) / (n - 1)
    local need = (size + gap) / (2 * math.sin(step / 2))
    return math.max(radius, math.ceil(need))
end
local function layout(r, n)
    if InCombatLockdown() then pendingRebuild = true; return end
    local c = DB[r.cfgKey]
    local size, radius = c.size, c.radius
    r.n = n
    r.toggle:SetAttribute("n", n)
    if r.arc then
        local a0 = ARC0[c.corner] or 270
        local span = 90 - 2 * ARC_PAD
        -- Space between the icons: the arc moves further from the corner when it has to, so that the
        -- centres of two neighbours are at least an icon and the gap apart (Distance from the corner is the least).
        radius = API.arcRadius(radius, size, c.gap, n, span)
        r.R = radius + size
        r.toggle:SetAttribute("arc0", a0 + ARC_PAD)
        r.toggle:SetAttribute("arcspan", span)
        r.disc:Hide(); r.innerDisc:Hide(); r.runes:Hide(); r.label:Hide(); r.rule:Hide()
        r.hOuter.tex:Hide(); r.hTrack.tex:Hide(); r.hInner.tex:Hide()
        for i = 1, RINGMAX do
            local b = r.buttons[i]
            if b then
                if i <= n then
                    local t = (n > 1) and ((i - 1) / (n - 1)) or 0.5
                    local ang = math.rad(a0 + ARC_PAD + span * t)
                    b:SetSize(size, size)
                    b:ClearAllPoints()
                    b:SetPoint("CENTER", r.frame, "CENTER", radius * math.sin(ang), radius * math.cos(ang))
                    b:Show()
                else
                    b:Hide()
                end
            end
        end
        return
    end
    local R = radius + size * 0.85
    r.R = R
    r.disc:SetSize(R * 2, R * 2)
    ringBgApply(r)
    if r.skin then API.skinLayout(r.skin, "dials", r.frame, R, 0, R) end
    r.beam:SetSize(R * 2, R * 2)
    r.runes:SetSize(R * 1.7, R * 1.7)
    -- Hairline rings: the outer edge, a thin track under the icons, and the inner disc.
    r.hOuter.tex:SetSize(R * 2, R * 2); r.hOuter.mask:SetSize((R - 1) * 4, (R - 1) * 4)
    r.hTrack.tex:SetSize((radius + 1) * 2, (radius + 1) * 2); r.hTrack.mask:SetSize((radius - 1) * 4, (radius - 1) * 4)
    local ri = radius - size * 0.85
    if ri > 12 then
        r.innerDisc:SetSize(ri * 2, ri * 2); r.innerDisc:Show()
        r.hInner.tex:SetSize(ri * 2, ri * 2); r.hInner.mask:SetSize((ri - 1) * 4, (ri - 1) * 4); r.hInner.tex:Show()
    else
        r.innerDisc:Hide(); r.hInner.tex:Hide()
    end
    for _, d in ipairs(r.dividers) do d:Hide() end
    r.label:SetShown(n > 0)
    r.innerW = math.max(56, (radius - size * 0.85) * 2 - 12)
    setLabel(r, r.label:GetText() or "")
    for i = 1, RINGMAX do
        local b = r.buttons[i]
        if b then
            if i <= n then
                local a = math.pi / 2 - (i - 1) * (2 * math.pi / n)
                b:SetSize(size, size)
                b:ClearAllPoints()
                b:SetPoint("CENTER", r.frame, "CENTER", radius * math.cos(a), radius * math.sin(a))
                b:Show()
            else
                b:Hide()
            end
        end
    end
end

----------------------------------------------------------------------
-- Pet ring
----------------------------------------------------------------------
local petRing

local function updatePetRing()
    if not petRing then return end
    local hasPet = UnitExists("pet") and true or false
    local shown = 0
    for i = 1, 10 do
        local b = petRing.buttons[i]
        if b then
            local name, texture, isToken, isActive, autoAllowed, autoOn = GetPetActionInfo(i)
            local tex = texture
            if isToken and texture then tex = _G[texture] or texture end
            if not tex then
                -- WoW's own pet bar knows the icon even when the API returns nothing.
                local pb = _G["PetActionButton" .. i]
                local pi = pb and (pb.icon or pb.Icon)
                if pi and pi.GetTexture then
                    local okT, t = pcall(pi.GetTexture, pi)
                    if okT and t then tex = t end
                end
            end
            if name or tex then
                shown = shown + 1
                b.icon:SetTexture(tex or "Interface\\Icons\\INV_Misc_QuestionMark")
                b.icon:SetVertexColor(1, 1, 1)
                b:SetAlpha(1)
                b.tooltipName = name
                b.label = name and (isToken and _G[name] or name) or nil
                local st = (isActive and "active") or (autoOn and "auto") or nil
                if b.ubDialState ~= st or not b.ubDialPainted then b.ubDialState, b.ubDialPainted = st, true; dialPaint(b, st) end
                pcall(function()
                    local usable = GetPetActionSlotUsable and GetPetActionSlotUsable(i)
                    local s, d = GetPetActionCooldown(i)
                    if s and d and d > 0 then b.cd:SetCooldown(s, d) else b.cd:Clear() end
                end)
            else
                b.icon:SetColorTexture(0.22, 0.28, 0.5, 0.9)
                b.edge:SetColorTexture(0.45, 0.6, 1, 1)
                b.ubDialPainted = false
                b.label = nil
                b:SetAlpha(0.7)
            end
        end
    end
    petRing.title = shown > 0 and "Pet" or (hasPet and "Pet (no actions)" or "No active pet")
    if petRing.label and not petRing.selIdx then petRing.label:SetText(petRing.title) end
end

local function buildPetRing()
    if petRing then return end
    petRing = newRing("Pet", "Pet", "petRing")
    petRing.onEnter = function(b)
        GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
        local ok = pcall(GameTooltip.SetPetAction, GameTooltip, b:GetID())
        if not ok then GameTooltip:SetText(b.tooltipName or "Pet action") end
        GameTooltip:Show()
    end
    for i = 1, 10 do
        local ok, b = pcall(ringButton, petRing, i)
        if ok and b then
            local ok2, err = pcall(function()
                b:SetAttribute("type", "pet")
                b:SetAttribute("action", i)
            end)
            if not ok2 then ringErr(petRing, "attributes " .. i, err) end
        else
            ringErr(petRing, "button " .. i, b)
        end
    end
    local okL, errL = pcall(layout, petRing, 10)
    if not okL then ringErr(petRing, "layout", errL) end
    petRing.frame:HookScript("OnShow", updatePetRing)
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "PET_BAR_UPDATE", "PET_BAR_UPDATE_COOLDOWN", "PET_BAR_UPDATE_USABLE", "PET_UI_UPDATE", "PLAYER_ENTERING_WORLD" }) do
        pcall(ev.RegisterEvent, ev, e)
    end
    -- only the player's pet: these fire for every unit nearby otherwise
    pcall(ev.RegisterUnitEvent, ev, "UNIT_PET", "player")
    pcall(ev.RegisterUnitEvent, ev, "UNIT_FLAGS", "pet")
    ev:SetScript("OnEvent", function() updatePetRing() end)
    updatePetRing()
end

----------------------------------------------------------------------
-- Utility ring: your own spells, items and macros, plus the extra action button and quest items
----------------------------------------------------------------------
local utilRing
local utilList = {}

local function questItemList()
    local out = {}
    local getter = GetQuestLogSpecialItemInfo or (C_QuestLog and C_QuestLog.GetQuestLogSpecialItemInfo)
    if not getter or not (C_QuestLog and C_QuestLog.GetNumQuestLogEntries) then return out end
    local ok = pcall(function()
        for i = 1, C_QuestLog.GetNumQuestLogEntries() do
            local info = C_QuestLog.GetInfo(i)
            if info and not info.isHeader then
                local link = getter(i)
                local id = link and tonumber(tostring(link):match("item:(%d+)"))
                if id then out[#out + 1] = { t = "item", id = id, auto = true } end
            end
        end
    end)
    return out
end

-- Anything in your bags you can use (quest items included), except potions and stones that heal you
-- and gear (which would be equipped, not used).
local function healsYou(id, classID, subID)
    local nm = ""
    local okN, n = pcall(function() return C_Item.GetItemNameByID(id) end)
    if okN and type(n) == "string" then nm = n:lower() end
    if nm:find("healthstone", 1, true) or nm:find("healing", 1, true) or nm:find("health potion", 1, true)
       or nm:find("rejuvenat", 1, true) or nm:find("bandage", 1, true) then return true end
    if classID == 0 and subID == 1 then
        local okS, _, spellID = pcall(function() return C_Item.GetItemSpell(id) end)
        if okS and spellID and C_Spell and C_Spell.GetSpellDescription then
            local okD, desc = pcall(C_Spell.GetSpellDescription, spellID)
            if okD and type(desc) == "string" then
                desc = desc:lower()
                if desc:find("heal", 1, true) or desc:find("restores %d+[%d,%.]* health") or desc:find("health", 1, true) then return true end
            end
        end
    end
    return false
end
local function usableBagItems()
    local out, seen = {}, {}
    if not (C_Container and C_Container.GetContainerNumSlots) then return out end
    local last = (NUM_TOTAL_EQUIPPED_BAG_SLOTS or 5)
    for bag = 0, last do
        local nslots = C_Container.GetContainerNumSlots(bag)
        if type(nslots) ~= "number" then nslots = 0 end
        for slot = 1, nslots do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            local id = info and info.itemID
            if id and not seen[id] then
                seen[id] = true
                local okI, _, _, _, _, _, classID, subID = pcall(function() return C_Item.GetItemInfoInstant(id) end)
                local okS, spellName = pcall(function() return C_Item.GetItemSpell(id) end)
                if okI and okS and spellName and classID ~= 2 and classID ~= 4 and not healsYou(id, classID, subID) then
                    local okU, usable = pcall(function() return C_Item.IsUsableItem(id) end)
                    if not okU or usable ~= false then
                        local nm = ""
                        local okN, n = pcall(function() return C_Item.GetItemNameByID(id) end)
                        if okN and type(n) == "string" then nm = n end
                        out[#out + 1] = { t = "item", id = id, auto = true, quest = (classID == 12), name = nm }
                    end
                end
            end
        end
    end
    -- Quest items first, then the rest by name, so the ring keeps the same order.
    table.sort(out, function(x, y)
        if x.quest ~= y.quest then return x.quest end
        if x.name ~= y.name then return x.name < y.name end
        return x.id < y.id
    end)
    return out
end

-- The game's menu buttons (and the bags) as ring entries: clicked through a secure macro.
local MICRO = {
    { "CharacterMicroButton", "Character", "Interface\\Icons\\INV_Shirt_White_01", "TOGGLECHARACTER0" },
    { "ProfessionMicroButton", "Professions", "Interface\\Icons\\Trade_BlackSmithing", "TOGGLEPROFESSIONBOOK" },
    { "PlayerSpellsMicroButton", "Spellbook and talents", "Interface\\Icons\\INV_Misc_Book_09", "TOGGLESPELLBOOK" },
    { "AchievementMicroButton", "Achievements", "Interface\\Icons\\Achievement_General", "TOGGLEACHIEVEMENT" },
    { "QuestLogMicroButton", "Quest log", "Interface\\Icons\\INV_Misc_Note_01", "TOGGLEQUESTLOG" },
    { "GuildMicroButton", "Guild", "Interface\\Icons\\INV_Shirt_GuildTabard_01", "TOGGLEGUILDTAB" },
    { "LFDMicroButton", "Group finder", "Interface\\Icons\\INV_Misc_GroupLooking", "TOGGLEGROUPFINDER" },
    { "CollectionsMicroButton", "Collections", "Interface\\Icons\\Ability_Mount_RidingHorse", "TOGGLECOLLECTIONS" },
    { "EJMicroButton", "Adventure guide", "Interface\\Icons\\INV_Misc_Map_01", "TOGGLEENCOUNTERJOURNAL" },
    { "UbermocChatTyping", "Type in chat", "Interface\\Icons\\INV_Letter_15", nil },
    { "MainMenuMicroButton", "Game menu", "Interface\\Icons\\INV_Misc_Gear_01", "TOGGLEGAMEMENU" },
}

local function buildUtilList()
    local c = DB.utilRing
    local list = {}
    local seen = {}
    local function add(s)
        local key = s.t .. ":" .. tostring(s.id or s.name)
        if seen[key] or #list >= RINGMAX then return end
        seen[key] = true
        list[#list + 1] = s
    end
    -- While mounted a Dismount entry comes first (also works for flying mounts).
    if c.autoDismount ~= false and IsMounted and IsMounted() then add({ t = "dismount", name = "Dismount", auto = true }) end
    for _, s in ipairs(c.slots) do add(s) end
    if c.autoExtra and HasExtraActionBar and HasExtraActionBar() then add({ t = "extra", auto = true }) end
    if c.autoQuest then
        for _, s in ipairs(questItemList()) do add(s) end
        local okB, bagItems = pcall(usableBagItems)
        if okB then for _, s in ipairs(bagItems) do add(s) end end
    end
    return list
end

local function assignSlot(b, s)
    for _, a in ipairs({ "type", "spell", "item", "macro", "macrotext", "clickbutton", "ubself" }) do b:SetAttribute(a, nil) end
    -- Bags are opened by the wheel's own code on release (no secure action needed, and modifiers can't change it).
    if s.t == "bags" then b:SetAttribute("ubself", true) end
    if s.t == "spell" then
        b:SetAttribute("type", "spell")
        local ok, name = pcall(function() return C_Spell and C_Spell.GetSpellName(s.id) end)
        b:SetAttribute("spell", (ok and name) or s.id)
    elseif s.t == "item" then
        b:SetAttribute("type", "item")
        b:SetAttribute("item", "item:" .. s.id)
    elseif s.t == "macro" then
        b:SetAttribute("type", "macro")
        b:SetAttribute("macro", s.name)
    elseif s.t == "extra" then
        b:SetAttribute("type", "macro")
        b:SetAttribute("macrotext", "/click ExtraActionButton1")
    elseif s.t == "dismount" then
        b:SetAttribute("type", "macro")
        b:SetAttribute("macrotext", "/dismount")
    elseif (s.t == "micro" or s.t == "bags") and _G[s.id] then
        b:SetAttribute("type", "click")
        b:SetAttribute("clickbutton", _G[s.id])
    end
    b.slot = s
    b.label = ((s.t == "macro" or s.t == "micro" or s.t == "bags" or s.t == "dismount") and s.name) or (s.t == "extra" and "Extra action") or nil
    if not b.label then
        local ok, nm
        if s.t == "spell" then ok, nm = pcall(function() return C_Spell.GetSpellName(s.id) end)
        elseif s.t == "item" then ok, nm = pcall(function() return C_Item.GetItemNameByID(s.id) end) end
        b.label = ok and nm or nil
    end
    b.icon:SetTexture(iconFor(s))
end

local function updateUtilCounts()
    if not utilRing then return end
    for i, b in pairs(utilRing.buttons) do
        local s = b.slot
        if s and b:IsShown() then
            if s.t == "item" then
                local ok, n = pcall(function() return C_Item.GetItemCount(s.id) end)
                b.count:SetText(ok and n and n > 1 and n or "")
                pcall(function()
                    local st, d = C_Item.GetItemCooldown(s.id)
                    if st and d and d > 0 then b.cd:SetCooldown(st, d) else b.cd:Clear() end
                end)
            elseif s.t == "spell" then
                b.count:SetText("")
                pcall(function()
                    local info = C_Spell.GetSpellCooldown(s.id)
                    if info and info.duration and info.duration > 0 then b.cd:SetCooldown(info.startTime, info.duration) else b.cd:Clear() end
                end)
            else
                b.count:SetText("")
            end
        end
    end
end

local rebuildUtil
-- Adds a spell or item to the utility ring (the spellbook's and the bags' Y menus use it).
API.utilRingAdd = function(slot)
    local u = DB and DB.utilRing
    if not (u and slot) then return end
    u.slots = u.slots or {}
    for _, s2 in ipairs(u.slots) do
        if s2.t == slot.t and s2.id == slot.id then say("That is already on the utility ring."); return end
    end
    if #u.slots >= MAXSLOTS then say("The utility ring is full. Clear a slot on the Radial Menus page (X on a slot)."); return end
    u.slots[#u.slots + 1] = slot
    if rebuildUtil then rebuildUtil() end
    if API.utilSlotsRefresh then pcall(API.utilSlotsRefresh) end
    say("Added to the utility ring.")
end
rebuildUtil = function()
    if not utilRing then return end
    if InCombatLockdown() then pendingRebuild = true; return end
    utilList = buildUtilList()
    for i, s in ipairs(utilList) do
        local b = ringButton(utilRing, i)
        assignSlot(b, s)
    end
    layout(utilRing, #utilList)
    local down = useDown()
    for _, b in pairs(utilRing.buttons) do b:RegisterForClicks(down and "AnyDown" or "AnyUp") end
    updateUtilCounts()
end

local gameTip   -- defined with the corner wheels below
local function buildUtilRing()
    if utilRing then return end
    utilRing = newRing("Util", "Utility", "utilRing")
    utilRing.onEnter = function(b)
        if gameTip and gameTip(b) then return end
        GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
        local s = b.slot
        local ok = false
        if s then
            if s.t == "spell" then ok = pcall(GameTooltip.SetSpellByID, GameTooltip, s.id)
            elseif s.t == "item" then ok = pcall(GameTooltip.SetItemByID, GameTooltip, s.id)
            elseif s.t == "extra" then GameTooltip:SetText("Extra action button"); ok = true
            elseif s.t == "macro" or s.t == "micro" or s.t == "bags" or s.t == "dismount" then GameTooltip:SetText(s.name); ok = true end
        end
        if not ok then GameTooltip:SetText("Empty") end
        GameTooltip:Show()
    end
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "QUEST_LOG_UPDATE", "UPDATE_EXTRA_ACTIONBAR", "PLAYER_REGEN_ENABLED", "BAG_UPDATE_DELAYED", "SPELL_UPDATE_COOLDOWN", "SPELLS_CHANGED", "PLAYER_MOUNT_DISPLAY_CHANGED" }) do
        pcall(ev.RegisterEvent, ev, e)
    end
    local lastBuild = 0
    ev:SetScript("OnEvent", function(_, event)
        if event == "SPELL_UPDATE_COOLDOWN" or event == "BAG_UPDATE_DELAYED" then
            if utilRing.frame:IsShown() then updateUtilCounts() end
            if event == "SPELL_UPDATE_COOLDOWN" then return end
        end
        local now = GetTime()
        if event ~= "PLAYER_REGEN_ENABLED" and now - lastBuild < 1 then return end
        lastBuild = now
        if event == "PLAYER_REGEN_ENABLED" and pendingRebuild then
            pendingRebuild = false
            applyClickMode()
            applyRingSwitches()
            layout(petRing, 10)
        end
        rebuildUtil()
    end)
    rebuildUtil()
end

----------------------------------------------------------------------
-- Menu ring: the game's menu buttons and the bags, on a wheel of their own
----------------------------------------------------------------------
local menuRing
local function menuList()
    local list = {}
    for _, m in ipairs(MICRO) do
        if _G[m[1]] then list[#list + 1] = { t = "micro", id = m[1], name = m[2], icon = m[3], bind = m[4], auto = true } end
    end
    if _G.MainMenuBarBackpackButton then
        list[#list + 1] = { t = "bags", id = "MainMenuBarBackpackButton", name = "Open / close all bags", icon = "Interface\\Icons\\INV_Misc_Bag_08", all = true, auto = true }
    end
    return list
end

local function rebuildMenu()
    if not menuRing then return end
    if InCombatLockdown() then pendingRebuild = true; return end
    local list = menuList()
    for i, s2 in ipairs(list) do assignSlot(ringButton(menuRing, i), s2) end
    layout(menuRing, #list)
    local down = useDown()
    for _, b in pairs(menuRing.buttons) do b:RegisterForClicks(down and "AnyDown" or "AnyUp") end
end

local function buildMenuRing()
    if menuRing then return end
    menuRing = newRing("Menu", "Menu", "menuRing")
    menuRing.onEnter = function(b)
        if gameTip(b) then return end
        GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
        GameTooltip:SetText((b.slot and b.slot.name) or "Empty")
        GameTooltip:Show()
    end
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("PLAYER_ENTERING_WORLD")
    ev:RegisterEvent("PLAYER_REGEN_ENABLED")
    ev:SetScript("OnEvent", function() rebuildMenu() end)
    rebuildMenu()
end

----------------------------------------------------------------------
-- Corner wheels: a fan of small round icons around a screen corner. Opened with the mouse (move it into
-- the corner) or with a key / pad button (hold, point with the left stick, release). One for the game's
-- menu buttons, one for the bags.
----------------------------------------------------------------------
local cmicroRing, cbagRing
-- The game's own tooltip for a menu button or bag slot: the same text it shows when you point at the real button.
-- The game button whose tooltip we borrowed. Its OnEnter can start things of its own (the game menu
-- button keeps redrawing its tooltip every second while it thinks it is pointed at), so its OnLeave
-- always runs when our tooltip goes away.
local tipFrom, tipBtn
local tipWatch = CreateFrame("Frame")
tipWatch:Hide()
-- Some game buttons (the game menu) draw their tooltip a moment after being pointed at, anchored to
-- themselves. While one is pending, a drawn tooltip is moved next to our entry.
tipWatch:SetScript("OnUpdate", function(self, dt)
    self.t = (self.t or 0) + dt
    if self.t < 0.1 then return end
    self.t = 0
    if not (tipFrom and tipBtn and tipBtn:IsShown()) then self:Hide(); return end
    if GameTooltip:IsShown() and GameTooltip:GetOwner() == tipFrom then
        GameTooltip:ClearAllPoints()
        GameTooltip:SetPoint("LEFT", tipBtn, "RIGHT", 10, 0)
    end
end)
local function gameTipLeave()
    local f = tipFrom
    tipFrom, tipBtn = nil, nil
    tipWatch:Hide()
    if f then
        local h = f.GetScript and f:GetScript("OnLeave")
        if h then pcall(h, f) end
    end
end
API.gameTipLeave = gameTipLeave
gameTip = function(b)
    gameTipLeave()
    local s = b.slot
    local f = s and s.id and (s.t == "micro" or s.t == "bags") and _G[s.id]
    local h = f and f.GetScript and f:GetScript("OnEnter")
    if not h then return false end
    GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
    tipFrom = f
    local ok = pcall(h, f)
    if ok and GameTooltip:IsShown() and (GameTooltip:NumLines() or 0) > 0 then
        GameTooltip:ClearAllPoints()
        GameTooltip:SetPoint("LEFT", b, "RIGHT", 10, 0)
        return true
    end
    if ok then
        -- nothing drawn yet: the game button draws it itself a moment later; keep it pointed at until we leave
        tipBtn = b
        tipWatch:Show()
        return false
    end
    gameTipLeave()
    GameTooltip:Hide()
    return false
end
local function arcTip(b)
    if gameTip(b) then return end
    GameTooltip:SetOwner(b, "ANCHOR_TOP")
    local s = b.slot
    GameTooltip:SetText((s and s.name) or "Empty", 1, 1, 1)
    local key = s and s.bind and GetBindingKey(s.bind)
    if key then
        local ok, txt = pcall(GetBindingText, key)
        GameTooltip:AddLine(ok and txt or key, 1, 0.82, 0)
    end
    GameTooltip:Show()
end

local BAGSLOTS = {
    { "MainMenuBarBackpackButton", 0 }, { "CharacterBag0Slot", 1 }, { "CharacterBag1Slot", 2 },
    { "CharacterBag2Slot", 3 }, { "CharacterBag3Slot", 4 }, { "CharacterReagentBag0Slot", 5 },
}
local function bagList()
    local list = {}
    for _, e in ipairs(BAGSLOTS) do
        local id = e[2]
        if _G[e[1]] then
            local tex, nm
            if id == 0 then
                tex, nm = "Interface\\Icons\\INV_Misc_Bag_08", "Backpack"
            else
                local okI, inv = pcall(function() return C_Container.ContainerIDToInventoryID(id) end)
                if okI and inv then tex = GetInventoryItemTexture("player", inv) end
                local okN, n = pcall(function() return C_Container.GetBagName(id) end)
                nm = okN and n or nil
            end
            if tex then
                list[#list + 1] = { t = "bags", id = e[1], bagId = id, name = nm or ("Bag " .. id), icon = tex, bind = "TOGGLEBAG" .. id, auto = true }
            end
        end
    end
    return list
end
local function microList()
    local list = {}
    for _, m in ipairs(MICRO) do
        if _G[m[1]] then list[#list + 1] = { t = "micro", id = m[1], name = m[2], icon = m[3], bind = m[4], auto = true } end
    end
    return list
end
local function rebuildArc(r, list)
    if not r then return end
    if InCombatLockdown() then pendingRebuild = true; return end
    for i, s2 in ipairs(list) do assignSlot(ringButton(r, i), s2) end
    layout(r, #list)
    local down = useDown()
    for _, b in pairs(r.buttons) do b:RegisterForClicks(down and "AnyDown" or "AnyUp") end
end
local function rebuildCorner()
    rebuildArc(cmicroRing, microList())
    rebuildArc(cbagRing, bagList())
end

local function buildCornerWheels()
    if cmicroRing then return end
    cmicroRing = newRing("CMicro", "Menu", "cmicroRing")
    cbagRing = newRing("CBag", "Bags", "cbagRing")
    for _, r in ipairs({ cmicroRing, cbagRing }) do
        r.arc = true
        r.onEnter = arcTip
    end
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED" }) do
        pcall(ev.RegisterEvent, ev, e)
    end
    ev:SetScript("OnEvent", function(_, e)
        if e == "PLAYER_REGEN_DISABLED" then
            for _, r in ipairs({ cmicroRing, cbagRing }) do pcall(r.toggle.SetAttribute, r.toggle, "*clickbutton", nil) end
            return
        end
        rebuildCorner()
    end)
    -- Mouse in the corner opens the wheel; it closes a moment after the mouse leaves it.
    local acc = 0
    ev:SetScript("OnUpdate", function(_, dt)
        acc = acc + dt
        if acc < 0.05 then return end
        local step = acc
        acc = 0
        if InCombatLockdown() or not DB then return end
        local x, y = GetCursorPosition()
        -- a still mouse with both wheels shut has nothing to open or close (a controller player never pays)
        if x == ev.lx and y == ev.ly and not (cmicroRing.frame:IsShown() or cbagRing.frame:IsShown()) then return end
        ev.lx, ev.ly = x, y
        local sc = UIParent:GetEffectiveScale()
        x, y = x / sc, y / sc
        local W, H = UIParent:GetWidth(), UIParent:GetHeight()
        ev.pair = ev.pair or { cmicroRing, cbagRing }
        for _, r in ipairs(ev.pair) do
            local c = DB[r.cfgKey]
            if c and c.on and c.mouse ~= false then
                local corner = c.corner or "BOTTOMRIGHT"
                local cx = corner:find("RIGHT") and W or 0
                local cy = corner:find("TOP") and H or 0
                if not r.frame:IsShown() then
                    if math.abs(x - cx) < 12 and math.abs(y - cy) < 12 and not (cmicroRing.frame:IsShown() or cbagRing.frame:IsShown()) then
                        r.mouseOpen = true
                        placeRing(r)
                        r.leave = 0
                        r.frame:Show()
                    end
                elseif r.mouseOpen then
                    local dist = math.sqrt((x - cx) ^ 2 + (y - cy) ^ 2)
                    if dist > (r.R or 200) + (c.size or 30) then r.leave = (r.leave or 0) + step else r.leave = 0 end
                    if r.leave > 0.5 then r.frame:Hide() end
                end
            end
        end
    end)
    rebuildCorner()
end

----------------------------------------------------------------------
-- Key capture helper for bindings
----------------------------------------------------------------------
local function keyText(cmd)
    local k = GetBindingKey(cmd)
    if not k then return "Not set" end
    local ok, txt = pcall(GetBindingText, k)
    return (ok and txt and txt ~= "") and txt or k
end

local IGNORE = { LSHIFT = 1, RSHIFT = 1, LCTRL = 1, RCTRL = 1, LALT = 1, RALT = 1 }

local function keyButton(parent, x, y, cmd, label)
    local b = API.newButton(parent, "", 200, x, y, function() end)
    local order = {}
    local function refresh() b:SetText(keyText(cmd)) end
    b.refresh = refresh
    local function stop()
        b.capturing = false
        b:EnableKeyboard(false)
        pcall(b.EnableGamePadButton, b, false)
        refresh()
    end
    b:SetScript("OnClick", function(self, btn)
        if InCombatLockdown() then say("Bindings cannot be changed in combat."); return end
        if btn == "RightButton" then
            for _, k in ipairs({ GetBindingKey(cmd) }) do SetBinding(k) end
            SaveBindings(GetCurrentBindingSet())
            refresh()
            return
        end
        self.capturing = true
        self:SetText("Press a key or button...")
        self:EnableKeyboard(true)
        order = {}
        self:EnableGamePadButton(true)
        -- nothing pressed for a while: give up (a controller has no Escape key to cancel with)
        local token = {}
        self.capToken = token
        C_Timer.After(8, function() if self.capturing and self.capToken == token then stop() end end)
    end)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:SetScript("OnKeyDown", function(self, key)
        if not self.capturing then return end
        if not InCombatLockdown() then self:SetPropagateKeyboardInput(false) end
        if IGNORE[key] then return end
        if key == "ESCAPE" then stop(); return end
        local combo = (IsAltKeyDown() and "ALT-" or "") .. (IsControlKeyDown() and "CTRL-" or "") .. (IsShiftKeyDown() and "SHIFT-" or "") .. key
        local old = GetBindingAction(combo)
        for _, k in ipairs({ GetBindingKey(cmd) }) do SetBinding(k) end
        SetBinding(combo, cmd)
        SaveBindings(GetCurrentBindingSet())
        if old and old ~= "" and old ~= cmd then say(combo .. " was used for " .. old .. " and now opens " .. label .. ".") end
        stop()
    end)
    -- Gamepad buttons arrive as their own event. Hold one button and press another to bind a combination:
    -- the first one becomes a WoW gamepad modifier (the same setting as Options > Gamepad > Modifiers).
    local EMU = { { "GamePadEmulateShift", "SHIFT-" }, { "GamePadEmulateCtrl", "CTRL-" }, { "GamePadEmulateAlt", "ALT-" } }
    local function emuOf(btn)
        for _, e in ipairs(EMU) do
            local ok, v = pcall(GetCVar, e[1])
            if ok and v == btn then return e[2] end
        end
    end
    local function freeEmu()
        for _, e in ipairs(EMU) do
            local ok, v = pcall(GetCVar, e[1])
            if ok and (not v or v == "" or v:upper() == "NONE" or v == "0") then return e end
        end
    end
    b:SetScript("OnGamePadButtonDown", function(self, key)
        if not self.capturing then return end
        if emuOf(key) then return end
        for _, k in ipairs(order) do if k == key then return end end
        if #order == 0 then
            self.padPrefix = (IsAltKeyDown() and "ALT-" or "") .. (IsControlKeyDown() and "CTRL-" or "") .. (IsShiftKeyDown() and "SHIFT-" or "")
        end
        order[#order + 1] = key
        self:SetText(table.concat(order, " + ") .. " ...")
    end)
    b:SetScript("OnGamePadButtonUp", function(self, key)
        if not self.capturing or #order == 0 then return end
        local prefix = self.padPrefix or ""
        local combo
        if #order == 1 then
            combo = prefix .. order[1]
        else
            local first, last = order[1], order[#order]
            local e = freeEmu()
            if e then
                pcall(SetCVar, e[1], first)
                combo = prefix .. e[2] .. last
                say(first .. " is now a gamepad modifier (" .. e[2]:gsub("-", "") .. "), so " .. first .. " + " .. last .. " opens " .. label .. ".")
            else
                combo = prefix .. last
                say("All three gamepad modifiers are already in use, so only " .. last .. " was bound. Free one in Options > Gamepad.")
            end
        end
        order = {}
        local old = GetBindingAction(combo)
        for _, k in ipairs({ GetBindingKey(cmd) }) do SetBinding(k) end
        SetBinding(combo, cmd)
        SaveBindings(GetCurrentBindingSet())
        if old and old ~= "" and old ~= cmd then say(combo .. " was used for " .. old .. " and now opens " .. label .. ".") end
        self:EnableGamePadButton(false)
        stop()
    end)
    b:SetScript("OnShow", refresh)
    -- Giving a frame key and gamepad scripts switches its input on: left on, this button would swallow every
    -- key and controller press while its page is open (the pointer stopped working on those pages).
    -- Input is only switched on while it is waiting for a press.
    b:EnableKeyboard(false)
    pcall(b.EnableGamePadButton, b, false)
    refresh()
    return b
end

----------------------------------------------------------------------
-- Settings pages
----------------------------------------------------------------------
local function addPage(panel, name)
    panel.name = name
    panel:Hide()
    API.addPage(name == "Rings" and "rings" or "interact", name == "Rings" and "Radial Menus" or name, panel)
end

local function px(v) return math.floor(v + 0.5) .. " px" end


-- Options every ring has: key, hold or press twice, where it opens, stick direction.
local function ringOptions(p, y, c, cmd, label)
    local on = API.newCheck(p, "Enable the " .. label, 16, y, function(v) c.on = v; applyRingSwitches() end)
    API.newLabel(p, "Key or button", 40, y - 38)
    keyButton(p, 170, y - 34, cmd, "the " .. label)
    local hold = API.newCheck(p, "Hold the key, point with the left stick, release to use", 16, y - 72, function(v) c.hold = v; applyRingSwitches() end)
    API.newLabel(p, "Opens", 40, y - 114)
    local where = API.segRow(p, 96, y - 108, { { "BOTTOM", "Bottom", 64 }, { "CURSOR", "At cursor", 76 }, { "CENTER", "Middle", 64 } },
        function() return c.pos or "BOTTOM" end, function(v) c.pos = v end)
    local flip = API.newCheck(p, "Flip stick up / down (if the wrong entry lights up)", 16, y - 146, function(v) c.flipY = v; applyRingSwitches() end)
    local beam = API.newCheck(p, "Beam of light", 330, y - 108, function(v) c.beam = v end)
    local function refresh()
        on:SetChecked(c.on); hold:SetChecked(c.hold); flip:SetChecked(c.flipY); beam:SetChecked(c.beam ~= false)
        where.refresh()
    end
    return refresh
end

local function buildRingsPage()
    local panel = CreateFrame("Frame")
    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 8, -8)
    scroll:SetPoint("BOTTOMRIGHT", -30, 44)
    local p = CreateFrame("Frame", nil, scroll)
    p:SetSize(560, 2380)
    scroll:SetScrollChild(p)
    API.newLabel(p, "Radial Menus", 8, -8, "GameFontNormalHuge")
    API.newLabel(p, "Hold the key and a ring pops up. Push the left stick toward an entry and let go to use it. With a mouse, click an entry.", 8, -40, "GameFontHighlightSmall")

    local roundCB
    roundCB = API.newCheck(p, "Round buttons on all rings", 16, -996, function(v)
        DB.ringRound = v
        for _, r in pairs(rings) do
            for _, b in pairs(r.buttons) do roundRingButton(b, v) end
        end
    end)
    -- Pet ring
    API.newLabel(p, "Pet ring", 8, -68, "GameFontNormalLarge")
    local c = DB.petRing
    local petRefresh = ringOptions(p, -98, c, "CLICK UbermocRingPetToggle:LeftButton", "pet ring")
    API.newLabel(p, "Ability icon size", 40, -288)
    local petSize = API.makeSlider(p, 140, 20, 500, 1, px, function(v) c.size = v; layout(petRing, 10) end)
    petSize:SetPoint("TOPLEFT", 240, -284)
    API.newLabel(p, "Ring radius", 40, -326)
    local petRad = API.makeSlider(p, 140, 40, 500, 1, px, function(v) c.radius = v; layout(petRing, 10) end)
    petRad:SetPoint("TOPLEFT", 240, -322)
    API.newLockButton(p, 40, -364)

    -- Utility ring
    API.newLabel(p, "Utility ring", 8, -414, "GameFontNormalLarge")
    local u = DB.utilRing
    local utilRefresh = ringOptions(p, -444, u, "CLICK UbermocRingUtilToggle:LeftButton", "utility ring")
    local autoExtra = API.newCheck(p, "Add the extra action button when one is up", 16, -622, function(v) u.autoExtra = v; rebuildUtil() end)
    local autoQuest = API.newCheck(p, "Add usable items automatically (quest items too, but not healing potions)", 16, -654, function(v) u.autoQuest = v; rebuildUtil() end)
    API.newLabel(p, "Ability icon size", 40, -700)
    local utilSize = API.makeSlider(p, 140, 20, 500, 1, px, function(v) u.size = v; rebuildUtil() end)
    utilSize:SetPoint("TOPLEFT", 240, -696)
    API.newLabel(p, "Ring radius", 40, -738)
    local utilRad = API.makeSlider(p, 140, 40, 500, 1, px, function(v) u.radius = v; rebuildUtil() end)
    utilRad:SetPoint("TOPLEFT", 240, -734)
    API.newLockButton(p, 40, -776)

    API.newLabel(p, "Your entries: Y on a spell in the spellbook or an item in your bags adds it. X on a slot clears it (with a mouse: drag one onto a slot).", 8, -822, "GameFontHighlightSmall")
    local slotBtns = {}
    local function refreshSlots()
        for i = 1, MAXSLOTS do
            local b = slotBtns[i]
            local s = u.slots[i]
            b.icon:SetTexture(s and iconFor(s) or nil)
            b.empty:SetShown(not s)
        end
    end
    API.utilSlotsRefresh = refreshSlots
    for i = 1, MAXSLOTS do
        local b = CreateFrame("Button", nil, p)
        b:SetSize(40, 40)
        b:SetPoint("TOPLEFT", 20 + ((i - 1) % 6) * 48, -850 - math.floor((i - 1) / 6) * 48)
        b.bg = b:CreateTexture(nil, "BACKGROUND")
        b.bg:SetAllPoints()
        b.bg:SetColorTexture(0.1, 0.1, 0.14, 1)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetPoint("TOPLEFT", 2, -2)
        b.icon:SetPoint("BOTTOMRIGHT", -2, 2)
        b.empty = b:CreateFontString(nil, "OVERLAY", "GameFontDisable")
        b.empty:SetPoint("CENTER")
        b.empty:SetText(i)
        b.hl = b:CreateTexture(nil, "HIGHLIGHT")
        b.hl:SetAllPoints()
        b.hl:SetColorTexture(1, 1, 1, 0.2)
        b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        local function receive()
            local t, a1, a2, a3 = GetCursorInfo()
            if not t then return false end
            local slot
            if t == "spell" then
                local id = a3
                if not id and a1 and C_SpellBook and C_SpellBook.GetSpellBookItemInfo then
                    local ok, info = pcall(C_SpellBook.GetSpellBookItemInfo, a1, a2 == "pet" and Enum.SpellBookSpellBank.Pet or Enum.SpellBookSpellBank.Player)
                    if ok and info then id = info.spellID end
                end
                if id then slot = { t = "spell", id = id } end
            elseif t == "item" then
                slot = { t = "item", id = a1 }
            elseif t == "macro" then
                local ok, name = pcall(GetMacroInfo, a1)
                if ok and name then slot = { t = "macro", name = name } end
            elseif t == "mount" then
                local ok, _, spellID = pcall(C_MountJournal.GetMountInfoByID, a1)
                if ok and spellID then slot = { t = "spell", id = spellID } end
            end
            if slot then
                u.slots[i] = slot
                ClearCursor()
                refreshSlots()
                rebuildUtil()
                return true
            end
            say("That cannot be put on the ring. Use a spell, item, macro or mount.")
            return false
        end
        b:SetScript("OnClick", function(_, btn)
            if btn == "RightButton" then
                if u.slots[i] then
                    table.remove(u.slots, i)
                    refreshSlots()
                    rebuildUtil()
                end
            else
                receive()
            end
        end)
        b:SetScript("OnReceiveDrag", receive)
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            local s = u.slots[i]
            local ok = false
            if s then
                if s.t == "spell" then ok = pcall(GameTooltip.SetSpellByID, GameTooltip, s.id)
                elseif s.t == "item" then ok = pcall(GameTooltip.SetItemByID, GameTooltip, s.id)
                else GameTooltip:SetText(s.name or "Macro"); ok = true end
            end
            if not ok then GameTooltip:SetText("Empty slot " .. i) end
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        slotBtns[i] = b
    end
    panel:SetScript("OnShow", function()
        petRefresh(); utilRefresh()
        roundCB:SetChecked(DB.ringRound ~= false)
        API.setSlider(petSize, c.size); API.setSlider(petRad, c.radius)
        autoExtra:SetChecked(u.autoExtra); autoQuest:SetChecked(u.autoQuest)
        API.setSlider(utilSize, u.size); API.setSlider(utilRad, u.radius)
        refreshSlots()
        API.evaluate()
    end)
    API.newLabel(p, "All rings", 8, -966, "GameFontNormalLarge")
    API.newLabel(p, "After using an entry, keep the stick locked at most", 40, -1034)
    local stickMax = API.makeSlider(p, 140, 0, 5, 0.1, function(v) return string.format("%.1f s", v) end, function(v) DB.stickMax = math.floor(v * 10 + 0.5) / 10 end)
    stickMax:SetPoint("TOPLEFT", 400, -1034)
    API.newLabel(p, "Extra time after it is centred", 40, -1068)
    local stickExtra = API.makeSlider(p, 140, 0, 1, 0.05, function(v) return string.format("%.2f s", v) end, function(v) DB.stickExtra = math.floor(v * 20 + 0.5) / 20 end)
    stickExtra:SetPoint("TOPLEFT", 400, -1068)
    local snote = API.newLabel(p, "The stick stays locked so the character does not walk off. Set the first to 0 to unlock it at once.", 8, -1100, "GameFontHighlightSmall")
    snote:SetWidth(570); snote:SetJustifyH("LEFT"); snote:SetWordWrap(true)
    panel:HookScript("OnShow", function()
        API.setSlider(stickMax, DB.stickMax or 0.1); API.setSlider(stickExtra, DB.stickExtra or 0.1)
    end)
    -- Menu ring
    API.newLabel(p, "Menu ring", 8, -1118, "GameFontNormalLarge")
    API.newLabel(p, "The game's menu buttons and the bags on a wheel of their own.", 8, -1146, "GameFontHighlightSmall")
    local mc = DB.menuRing
    local menuRefresh = ringOptions(p, -1172, mc, "CLICK UbermocRingMenuToggle:LeftButton", "menu ring")
    API.newLabel(p, "Icon size", 40, -1362)
    local menuSize = API.makeSlider(p, 140, 20, 500, 1, px, function(v) mc.size = v; rebuildMenu() end)
    menuSize:SetPoint("TOPLEFT", 240, -1358)
    API.newLabel(p, "Ring radius", 40, -1400)
    local menuRad = API.makeSlider(p, 140, 40, 500, 1, px, function(v) mc.radius = v; rebuildMenu() end)
    menuRad:SetPoint("TOPLEFT", 240, -1396)
    API.newLockButton(p, 40, -1438)
    panel:HookScript("OnShow", function()
        menuRefresh()
        API.setSlider(menuSize, mc.size); API.setSlider(menuRad, mc.radius)
    end)
    -- Corner wheels
    local function arcOptions(y, c, cmd, label, rebuild)
        local on = API.newCheck(p, "Enable the " .. label, 16, y, function(v)
            c.on = v; applyRingSwitches()
            -- the menu wheel takes over from the menu bar
            if v and c == DB.cmicroRing and API.toolbarDB then
                API.toolbarDB().on = false
            end
            if API.applyToolbar then pcall(API.applyToolbar) end
        end)
        API.newLabel(p, "Key or button", 40, y - 38)
        keyButton(p, 170, y - 34, cmd, "the " .. label)
        local hold = API.newCheck(p, "Hold the key, point with the left stick, release to use", 16, y - 72, function(v) c.hold = v; applyRingSwitches() end)
        local mouse = API.newCheck(p, "Open it with the mouse: move into the corner", 16, y - 106, function(v) c.mouse = v end)
        API.newLabel(p, "Corner", 40, y - 148)
        local where = API.segRow(p, 96, y - 142, { { "BOTTOMRIGHT", "Bottom right", 96 }, { "BOTTOMLEFT", "Bottom left", 90 },
            { "TOPRIGHT", "Top right", 80 }, { "TOPLEFT", "Top left", 76 } },
            function() return c.corner or "BOTTOMRIGHT" end, function(v) c.corner = v; rebuild() end)
        local flip = API.newCheck(p, "Flip stick up / down (if the wrong entry lights up)", 16, y - 180, function(v) c.flipY = v; applyRingSwitches() end)
        local borders = API.newCheck(p, "Borders around the icons", 16, y - 212, function(v)
            c.borders = v
            for _, rr in pairs(rings) do
                if rr.cfgKey and DB[rr.cfgKey] == c then
                    for _, bb in pairs(rr.buttons) do pcall(dialPaint, bb, bb.ubDialState) end
                end
            end
        end)
        API.newLabel(p, "Icon size", 40, y - 258)
        local sz = API.makeSlider(p, 140, 16, 80, 1, px, function(v) c.size = v; rebuild() end)
        sz:SetPoint("TOPLEFT", 240, y - 254)
        API.newLabel(p, "Distance from the corner", 40, y - 296)
        local rad = API.makeSlider(p, 140, 60, 600, 1, px, function(v) c.radius = v; rebuild() end)
        rad:SetPoint("TOPLEFT", 240, y - 292)
        API.newLabel(p, "Space between icons", 40, y - 334)
        local gapS = API.makeSlider(p, 140, 0, 60, 1, px, function(v) c.gap = v; rebuild() end)
        gapS:SetPoint("TOPLEFT", 240, y - 330)
        return function()
            on:SetChecked(c.on); hold:SetChecked(c.hold); mouse:SetChecked(c.mouse ~= false); flip:SetChecked(c.flipY); borders:SetChecked(c.borders ~= false)
            where.refresh(); API.setSlider(sz, c.size); API.setSlider(rad, c.radius)
            API.setSlider(gapS, c.gap == nil and 6 or c.gap)
        end
    end
    API.newLabel(p, "Menu wheel (corner)", 8, -1512, "GameFontNormalLarge")
    API.newLabel(p, "A fan of round icons around a screen corner: the game's menu buttons.", 8, -1540, "GameFontHighlightSmall")
    local cmicroRefresh = arcOptions(-1566, DB.cmicroRing, "CLICK UbermocRingCMicroToggle:LeftButton", "menu wheel", rebuildCorner)
    API.newLabel(p, "Bags wheel (corner)", 8, -1962, "GameFontNormalLarge")
    API.newLabel(p, "The same, for your bags (backpack, bag slots and the reagent bag).", 8, -1990, "GameFontHighlightSmall")
    local cbagRefresh = arcOptions(-2016, DB.cbagRing, "CLICK UbermocRingCBagToggle:LeftButton", "bags wheel", rebuildCorner)
    panel:HookScript("OnShow", function() cmicroRefresh(); cbagRefresh() end)
    p:SetHeight(math.max(p:GetHeight(), 2380))
    API.resetters.rings = function()
        local d = defaults()
        local slots = DB.utilRing and DB.utilRing.slots or {}
        DB.petRing = d.petRing
        DB.utilRing = d.utilRing
        DB.utilRing.slots = slots
        DB.menuRing = d.menuRing
        DB.cmicroRing = d.cmicroRing
        DB.cbagRing = d.cbagRing
        mc = DB.menuRing
        DB.ringRound = d.ringRound; DB.stickMax = d.stickMax; DB.stickExtra = d.stickExtra
        c, u = DB.petRing, DB.utilRing
        pcall(applyRingSwitches)
        pcall(layout, petRing, 10)
        pcall(rebuildUtil)
        pcall(rebuildMenu)
        pcall(rebuildCorner)
    end
    API.makeTabs(panel, scroll, p, { { "Pet ring", 0 }, { "Utility ring", -406 }, { "All rings", -962 }, { "Menu ring", -1110 }, { "Corner menu wheel", -1504 }, { "Corner bags wheel", -1954 } })
    addPage(panel, "Rings")
end



----------------------------------------------------------------------
-- Interface cursor: a pointer that jumps between the buttons of an open window,
-- moved with the D-pad (or arrow keys). A / PAD1 clicks, X / PAD3 right-clicks, B / PAD2 closes.
----------------------------------------------------------------------
local cursor = { nodes = {}, active = false }
local keyboard          -- the on-screen keyboard (set up further down)
local openKeyboard
local activate          -- opens the pointer (set up further down)
local WINDOWS = {
    "UbermocDialogue", "GossipFrame", "QuestFrame", "MerchantFrame", "MailFrame", "BankFrame", "ClassTrainerFrame", "TaxiFrame",
    "AuctionHouseFrame", "ProfessionsFrame", "CharacterFrame", "SpellBookFrame", "PlayerSpellsFrame", "CollectionsJournal",
    "WorldMapFrame", "GuildBankFrame", "PetStableFrame", "TradeFrame", "ItemUpgradeFrame", "ChannelFrame", "FriendsFrame",
    "ContainerFrameCombinedBags", "AccountBankPanel", "LootFrame", "QuestLogFrame", "PVEFrame",
    "GameMenuFrame", "AchievementFrame", "EncounterJournal", "CommunitiesFrame", "GuildFrame", "ProfessionsBookFrame", "SettingsPanel", "UbermocUIWindow", "UbermocMenuBar", "UbermocBagPicker", "EditModeManagerFrame", "HelpFrame", "StaticPopup1", "StaticPopup2", "StaticPopup3", "StaticPopup4",
    -- loot rolls, choices and bonus rolls
    "GroupLootContainer", "PlayerChoiceFrame", "BonusRollFrame",
    -- transmog (the NPC's window and the wardrobe)
    "TransmogFrame", "WardrobeFrame", "WardrobeTransmogFrame",
}
for i = 1, 13 do WINDOWS[#WINDOWS + 1] = "ContainerFrame" .. i end
-- Small question windows: while one is up the pointer stays on it and starts on its main button.
local POPUPS = {
    { "StaticPopup1" }, { "StaticPopup2" }, { "StaticPopup3" }, { "StaticPopup4" }, { "UbermocBagPicker" },
    { "ReadyCheckFrame", "ReadyCheckFrameYesButton" },
    { "LFGDungeonReadyPopup", "LFGDungeonReadyDialogEnterDungeonButton" },
    { "PVPReadyDialog", "PVPReadyDialogEnterBattleButton" },
    { "LFDRoleCheckPopup", "LFDRoleCheckPopupAcceptButton" },
    { "RolePollPopup", "RolePollPopupAcceptButton" },
    { "LFGInvitePopup", "LFGInvitePopupAcceptButton" },
    { "LFGListInviteDialog", "AcceptButton" },
    { "LFGListApplicationDialog", "SignUpButton" },
    { "PetBattleQueueReadyFrame", "AcceptButton" },
}
for _, p in ipairs(POPUPS) do WINDOWS[#WINDOWS + 1] = p[1] end
local itemMenu   -- the Y-button action menu (set up further down)
local DIRS = { PADDUP = "UP", PADDDOWN = "DOWN", PADDLEFT = "LEFT", PADDRIGHT = "RIGHT", UP = "UP", DOWN = "DOWN", LEFT = "LEFT", RIGHT = "RIGHT" }

-- Positions in screen units: windows with a scale of their own (ours, the map...) compare fairly.
local function scaleOf(f) return (f.GetEffectiveScale and f:GetEffectiveScale()) or 1 end
local function centerOf(f)
    local x, y = f:GetCenter()
    if not x or not y then return nil end
    local s = scaleOf(f)
    return x * s, y * s
end
local function rectOf(f)
    local l, b, w, h = f:GetRect()
    if not l or not w then return nil end
    local s = scaleOf(f)
    return l * s, b * s, (l + w) * s, (b + h) * s
end

local function isOurs(f)
    local n = f.GetName and f:GetName()
    return cursor.frame and (f == cursor.frame or f == cursor.ptr)
        or (type(n) == "string" and n:find("^UbermocRing"))
end

local function usable(f)
    if not (f.IsVisible and f:IsVisible()) then return false end
    if f.IsMouseEnabled and not f:IsMouseEnabled() then return false end
    if f.IsEnabled and f:IsEnabled() == false then return false end
    if InCombatLockdown() and f.IsProtected and f:IsProtected() then return false end
    local w, h = f:GetSize()
    if not w or w < 6 or h < 6 then return false end
    local l, b = f:GetLeft(), f:GetBottom()
    if not l or not b then return false end
    return f:GetCenter() ~= nil
end

local function wantsNode(f)
    if f.ubSkipCursor then return false end
    if f.IsObjectType and (f:IsObjectType("Button") or f:IsObjectType("CheckButton") or f:IsObjectType("Slider")) then return true end
    -- text boxes: A opens the on-screen keyboard for them
    if f.IsObjectType and f:IsObjectType("EditBox") then return true end
    if f.GetScript and (f:GetScript("OnMouseUp") or f:GetScript("OnMouseDown")) then return true end
    return false
end

-- Scroll bars are left out: the D-pad scrolls a list by itself when it reaches the edge, and the triggers
-- scroll a page, so the bar's arrows and thumb would only be extra stops on the way.
local function isScrollBar(f)
    if type(f.ScrollUpButton) == "table" and type(f.ScrollDownButton) == "table" then return true end   -- the older bars
    if type(f.Back) == "table" and type(f.Forward) == "table" and type(f.Track) == "table" then return true end   -- the newer ones
    local p = f.GetParent and f:GetParent()
    if p and p.ScrollBar == f then return true end
    return false
end

-- A list that can scroll: a scroll frame, the game's newer lists, or a clipping frame with a wheel script.
local function isScroller(f)
    if not f or (f.IsForbidden and f:IsForbidden()) then return false end
    if f.IsObjectType and f:IsObjectType("Slider") then return false end   -- a wheel there changes a value
    if f.IsObjectType and f:IsObjectType("ScrollFrame") then return true end
    if f.GetScrollPercentage and f.HasScrollableExtent then return true end
    if f.DoesClipChildren and f:DoesClipChildren() and f.GetScript and f:GetScript("OnMouseWheel") then return true end
    return false
end

-- A button inside a scrolling list only counts while it sits inside the visible part of that list (the rest
-- is scrolled out of sight, or cut off by the window's edge).
local function inClip(f, clip)
    if not clip then return true end
    local x, y = centerOf(f)
    if not x then return false end
    return x >= clip[1] and x <= clip[3] and y >= clip[2] and y <= clip[4]
end
local scan
-- One reusable list of children per depth, filled in place, so most frames looked at make no new table
-- (a frame with many children gets a fresh one: filling in place costs more there).
local KIDS = {}
local function kidsOf(depth, ...)
    local n = select("#", ...)
    if n == 0 then return 0 end
    if n > 16 then return n, { ... } end
    local t = KIDS[depth]
    if not t then t = {}; KIDS[depth] = t end
    for i = 1, n do t[i] = (select(i, ...)) end
    return n, t
end
local function scanOne(f, out, depth, clip)
    if depth > 14 or not f or isOurs(f) then return end
    if f.IsShown and not f:IsShown() then return end
    if f.ubSkipCursor or isScrollBar(f) then return end
    local clips = f.IsObjectType and (f:IsObjectType("ScrollFrame") or (f.DoesClipChildren and f:DoesClipChildren()))
    if clips then
        local l, b, r, t = rectOf(f)
        if l then
            if clip then l, b, r, t = math.max(l, clip[1]), math.max(b, clip[2]), math.min(r, clip[3]), math.min(t, clip[4]) end
            clip = { l, b, r, t }
        end
    end
    if cursor.scrollers and isScroller(f) then cursor.scrollers[#cursor.scrollers + 1] = f end
    if wantsNode(f) and usable(f) and inClip(f, clip) then out[#out + 1] = f end
    if f.GetChildren then
        local n, t = kidsOf(depth, f:GetChildren())
        for i = 1, n do scan(t[i], out, depth + 1, clip) end
    end
end
-- One odd frame never ends the pointer: a frame that raises an error is skipped (and said once).
scan = function(f, out, depth, clip)
    local ok, err = pcall(scanOne, f, out, depth, clip)
    if not ok and not cursor.errSaid then
        cursor.errSaid = true
        if API.uiPrint then API.uiPrint("The pointer skipped a frame that raised an error: " .. tostring(err)) end
    end
end

-- The open drop-down / context menu (map quest pop-up, right-click menus), if any.
local function openMenuRoot()
    local ok, m = pcall(function()
        local mgr = _G.Menu and _G.Menu.GetManager and _G.Menu.GetManager()
        local om = mgr and mgr.GetOpenMenu and mgr:GetOpenMenu()
        if om and om.IsShown and om:IsShown() then return om end
        for i = 3, 1, -1 do
            local f = _G["DropDownList" .. i]
            if f and f.IsShown and f:IsShown() then return f end
        end
    end)
    return ok and m or nil
end

-- The main button of a question window (Okay, Accept, Enter dungeon...), or its empty text box.
local function popupPrefer(p, spec)
    local pn = spec[1]
    if pn:find("^StaticPopup") then
        local eb = (p.GetEditBox and p:GetEditBox()) or p.editBox or _G[pn .. "EditBox"]
        if eb and eb.IsShown and eb:IsShown() and (eb:GetText() or "") == "" then return eb end
        return _G[pn .. "Button1"] or p.button1 or (p.GetButton1 and p:GetButton1()) or (p.GetButton and p:GetButton(1))
    end
    if spec[2] then return _G[spec[2]] or p[spec[2]] end
end

local function collect()
    local out, seen = {}, {}
    local roots = {}
    cursor.scrollers = {}
    if keyboard and keyboard:IsShown() then
        scan(keyboard, out, 0)
        return out, 1
    end
    if itemMenu and itemMenu:IsShown() then
        scan(itemMenu, out, 0)
        return out, 1
    end
    local om = openMenuRoot()
    if om then
        scan(om, out, 0)
        if #out > 0 then return out, 1 end
        out = {}
    end
    -- A question window (bind the item to you?, sell?, ready check, dungeon ready...) or the bag picker:
    -- only its buttons, and the pointer starts on its main button.
    cursor.prefer = nil
    for _, spec in ipairs(POPUPS) do
        local p = _G[spec[1]]
        if p and p.IsShown and p:IsShown() then
            scan(p, out, 0)
            if #out > 0 then
                local b1 = popupPrefer(p, spec)
                if b1 and b1.IsShown and b1:IsShown() then cursor.prefer = b1 end
                return out, 1
            end
        end
    end
    out = {}
    -- While an NPC is talking, the pointer stays in the conversation (the menu bar would otherwise slide open
    -- and take the pointer)
    local talking = false
    for _, n in ipairs({ "UbermocDialogue", "GossipFrame", "QuestFrame" }) do
        local f = _G[n]
        if f and f.IsVisible and f:IsVisible() then talking = true end
    end
    for _, n in ipairs(WINDOWS) do
        local f = _G[n]
        if f and f.IsVisible and f:IsVisible() and not (talking and n == "UbermocMenuBar") and n ~= "UbermocDialogue" then roots[#roots + 1] = f; seen[f] = true end
    end
    -- Every other window the game opens as a panel (inspect, dressing room, macros, the great vault...).
    if type(UIPanelWindows) == "table" then
        for name in pairs(UIPanelWindows) do
            local f = type(name) == "string" and _G[name]
            if type(f) == "table" and not seen[f] and f.IsVisible and f:IsVisible() then roots[#roots + 1] = f; seen[f] = true end
        end
    end
    -- Bags kept in a screen corner can be reached while something else is open.
    if #roots > 0 and _G.UbermocBagCorner and _G.UbermocBagCorner:IsVisible() then roots[#roots + 1] = _G.UbermocBagCorner end
    local special = type(UISpecialFrames) == "table" and UISpecialFrames or {}
    for i = 1, math.min(#special, 150) do
        local f = _G[special[i]]
        if f and not seen[f] and f.IsShown and f:IsShown() then roots[#roots + 1] = f; seen[f] = true end
    end
    local ours = cursor.ours
    if not ours then ours = {}; cursor.ours = ours end
    wipe(ours)
    local W = _G.UbermocUIWindow
    for _, r in ipairs(roots) do
        local from = #out
        scan(r, out, 0)
        if r == W then for i = from + 1, #out do ours[out[i]] = true end end
    end
    -- Frames unlocked for moving: each one is a stop (A picks it up, the D-pad moves it).
    if API.unlocked and API.moverList then
        for _, m in ipairs(API.moverList) do
            local f = m.frame
            if f and f.IsShown and f:IsShown() and f:GetCenter() then out[#out + 1] = f end
        end
    end
    cursor.rootList = roots
    return out, #roots
end

-- The game menu's buttons run protected code from their enter / leave scripts, so those are never
-- called from here (the pointer still highlights them).
local function inGameMenu(n)
    local p = n
    for _ = 1, 6 do
        if not p then return false end
        if p == _G.GameMenuFrame then return true end
        p = p.GetParent and p:GetParent()
    end
    return false
end

local function leaveNode(n)
    if not n then return end
    local f = (not inGameMenu(n)) and n.GetScript and n:GetScript("OnLeave")
    if f then pcall(f, n) end
    if GameTooltip and GameTooltip:IsShown() then pcall(GameTooltip.Hide, GameTooltip) end
end

local function enterNode(n)
    if n.ubMover then return end
    local f = (not inGameMenu(n)) and n.GetScript and n:GetScript("OnEnter")
    if f then pcall(f, n) end
    -- the pointer only shows tooltips when asked to (they pop up at once when a window opens)
    if not (DB and DB.cursor and DB.cursor.tips == true) then
        if GameTooltip and GameTooltip:IsShown() then pcall(GameTooltip.Hide, GameTooltip) end
        return
    end
    -- Bag and bank slots only show their tooltip while the real mouse is over them; if the game's own did not
    -- come up, the item is shown from here.
    C_Timer.After(0.05, function()
        if cursor.cur ~= n or not n.IsShown or not n:IsShown() or (GameTooltip and GameTooltip:IsShown()) then return end
        pcall(function()
            local bag = n.GetBagID and n:GetBagID() or (n.GetParent and n:GetParent() and n:GetParent().GetID and n:GetParent():GetID())
            local slot = n.GetID and n:GetID()
            if type(bag) ~= "number" or type(slot) ~= "number" or slot < 1 then return end
            local link = C_Container and C_Container.GetContainerItemInfo and C_Container.GetContainerItemInfo(bag, slot)
            if not link then return end
            GameTooltip:SetOwner(n, "ANCHOR_RIGHT")
            GameTooltip:SetBagItem(bag, slot)
            GameTooltip:Show()
        end)
    end)
end

local function placePointer(n)
    local c = cursor.frame
    if not c or not n then return end
    local w, h = n:GetSize()
    local x, y = centerOf(n)
    if x then cursor.lx, cursor.ly, cursor.lt = x, y, GetTime() end   -- where it was, for the next list
    c.box:ClearAllPoints()
    c.box:SetPoint("TOPLEFT", n, "TOPLEFT", -2, 2)
    c.box:SetPoint("BOTTOMRIGHT", n, "BOTTOMRIGHT", 2, -2)
    c.ptr:ClearAllPoints()
    c.ptr:SetPoint("TOPLEFT", n, "CENTER", math.min((w or 0) * 0.25, 18), -math.min((h or 0) * 0.1, 6))
    c:Show()
end

-- The click keys are bound to secure buttons whose "clickbutton" is the
-- highlighted frame, so the game performs a real click on it (Game Menu exit, map pop-ups, spells...).
-- Addon code clicking a frame is blocked for protected menu entries, a key press is not.
-- Frames that react to mouse down / up scripts instead of OnClick get those called directly.
-- Nothing of the game's is ever replaced or written to here (not even for an instant): a changed
-- game function or field stays marked as the addon's for the whole session and makes the game's own
-- frames (Edit Mode, arena / party frames) fail later. The game menu is left to the real click alone.
-- True when n sits in one of the game's pop-up menus (right-click menus, drop-downs).
local function inGamePopup(n)
    local ok, open = pcall(function()
        local M = _G.Menu
        local mgr = M and M.GetManager and M.GetManager()
        return mgr and mgr.GetOpenMenu and mgr:GetOpenMenu()
    end)
    if not ok or not open then return false end
    local p = n
    for _ = 1, 10 do
        if not p then return false end
        if p == open then return true end
        p = p.GetParent and p:GetParent()
    end
    return false
end

local function synthClick(n, btn, down, up)
    if not n or inGameMenu(n) or inGamePopup(n) then return end
    if n.IsForbidden and n:IsForbidden() then return end
    pcall(function()
        local gs = n.GetScript
        if down and gs then
            local d = n:GetScript("OnMouseDown")
            if d then d(n, btn, true) end
        end
        if up then
            if n.OnMouseClickAction then n:OnMouseClickAction(btn) end   -- map pins
            local u = gs and n:GetScript("OnMouseUp")
            if u then u(n, btn, true) end
        end
    end)
end

local function realButton(n)
    if not n or not n.IsObjectType then return false end
    local ok, r = pcall(function()
        if n.IsForbidden and n:IsForbidden() then return false end
        return n:IsObjectType("Button") and not n:IsObjectType("Slider")
    end)
    return ok and r and true or false
end

local function bindClickTarget(n)
    local o = cursor.owner
    if not o or not cursor.active or InCombatLockdown() or not cursor.clickKeys then return end
    local tl, tr = "UbermocCursorKeyA", "UbermocCursorKeyX"
    if cursor.grab then
        -- a frame being moved: A puts it down
    elseif n and n.ubSecure and n:GetName() then
        tl, tr = n:GetName(), n:GetName()
    elseif realButton(n) and cursor.clickBtn and not n.holdFn then   -- hold-to-repeat buttons keep A on our own key
        cursor.clickBtn:SetAttribute("clickbutton", n)
        cursor.rightBtn:SetAttribute("clickbutton", n)
        tl, tr = "UbermocCursorClickBtn", "UbermocCursorRightBtn"
    end
    local mb = (n and n.ubClickRight) and "RightButton" or "LeftButton"
    if cursor.clickTarget ~= tl or cursor.clickMB ~= mb then
        cursor.clickTarget, cursor.clickMB = tl, mb
        for _, key in ipairs(cursor.clickKeys) do SetOverrideBindingClick(o, true, key, tl, mb) end
    end
    if cursor.rightTarget ~= tr then
        cursor.rightTarget = tr
        for _, key in ipairs(cursor.rightKeys or {}) do SetOverrideBindingClick(o, true, key, tr, "RightButton") end
    end
end

-- True when n sits inside our settings window (the pointer goes back there to where it was).
local function inOurWindow(n)
    local W = _G.UbermocUIWindow
    if not W then return false end
    if cursor.ours and cursor.ours[n] then return true end
    local p = n
    for _ = 1, 24 do
        if not p then return false end
        if p == W then return true end
        p = p.GetParent and p:GetParent()
    end
    return false
end

-- The tabs next to the pointer: the bumpers step through them. Our own tab strips first, then the
-- game's two kinds of tabs (the selected one of those is greyed out, so it is never a stop itself).
local function tabsFor(n)
    if not n then return end
    -- our strips: the innermost (lowest on screen) strip of the window the pointer is in
    if inOurWindow(n) then
        local groups, gy = {}, {}
        for _, b in ipairs(cursor.nodes) do
            if b.ubTab and inOurWindow(b) then
                local g = b.ubTab
                if not groups[g] then groups[g] = true; local _, y = centerOf(b); gy[#gy + 1] = { g = g, y = y or 0 } end
            end
        end
        table.sort(gy, function(a, b) return a.y < b.y end)
        local g = gy[1] and gy[1].g
        if g then
            local list, sel = {}, nil
            for _, b in ipairs(g) do
                if b:IsVisible() then
                    list[#list + 1] = b
                    if b.ubSel then sel = #list end
                end
            end
            return list, sel
        end
    end
    -- the game's tabs, on the window the pointer is in or a part of it
    local p = n.GetParent and n:GetParent()
    for _ = 1, 24 do
        if not p or p == UIParent then break end
        if type(p.numTabs) == "number" and p.numTabs > 1 and p.selectedTab then
            local list, sel = {}, nil
            local name = p.GetName and p:GetName()
            for i = 1, p.numTabs do
                local t = (p.Tabs and p.Tabs[i]) or (name and _G[name .. "Tab" .. i])
                if t and t.IsVisible and t:IsVisible() and not t.isDisabled then
                    list[#list + 1] = t
                    if i == p.selectedTab then sel = #list end
                end
            end
            if #list > 1 then return list, sel end
        end
        local ts = p.TabSystem or p.tabSystem
        if type(ts) == "table" and type(ts.tabs) == "table" then
            local list, sel = {}, nil
            for _, t in ipairs(ts.tabs) do
                if t.IsVisible and t:IsVisible() and not (t.IsForceDisabled and t:IsForceDisabled()) then
                    list[#list + 1] = t
                    if t.isSelected then sel = #list end
                end
            end
            if #list > 1 then return list, sel end
        end
        p = p.GetParent and p:GetParent()
    end
end

local function updateTabTargets()
    if InCombatLockdown() or not cursor.tabPrev then return end
    local prev, nextT
    local list, sel = tabsFor(cursor.cur)
    if list and #list > 1 then
        sel = sel or 1
        prev = list[(sel - 2) % #list + 1]
        nextT = list[sel % #list + 1]
    end
    if cursor.tabPrevT ~= prev then cursor.tabPrevT = prev; cursor.tabPrev:SetAttribute("clickbutton", prev) end
    if cursor.tabNextT ~= nextT then cursor.tabNextT = nextT; cursor.tabNext:SetAttribute("clickbutton", nextT) end
end

local function focus(n)
    if cursor.cur == n then return end
    leaveNode(cursor.cur)
    cursor.cur = n
    pcall(bindClickTarget, n)
    if n then
        placePointer(n); enterNode(n)
        if inOurWindow(n) then cursor.mem = n end
    end
end

local function refreshNodes()
    local nodes, roots = collect()
    cursor.nodes = nodes
    local isNode = {}
    for _, n in ipairs(nodes) do isNode[n] = true end
    if cursor.cur and not isNode[cursor.cur] and cursor.cur ~= cursor.grab then leaveNode(cursor.cur); cursor.cur = nil end
    if cursor.prefer and cursor.cur ~= cursor.prefer and cursor.preferDone ~= cursor.prefer and isNode[cursor.prefer] then
        cursor.preferDone = cursor.prefer
        leaveNode(cursor.cur); cursor.cur = nil
        focus(cursor.prefer)
    end
    if not cursor.prefer then cursor.preferDone = nil end
    if not cursor.cur and nodes[1] then
        local best, bs
        if cursor.lx and cursor.lt and GetTime() - cursor.lt < 6 then
            -- the list changed under the pointer (a choice was made): go to the button nearest where it was
            for _, n in ipairs(nodes) do
                local x, y = centerOf(n)
                if x then
                    local dd = (x - cursor.lx) ^ 2 + (y - cursor.ly) ^ 2
                    if not bs or dd < bs then best, bs = n, dd end
                end
            end
        elseif cursor.mem and isNode[cursor.mem] then
            -- back in our settings window: where the pointer was last time
            best = cursor.mem
        else
            -- begin with the node nearest the top-left of the window
            for _, n in ipairs(nodes) do
                local x, y = centerOf(n)
                if x then
                    local sc = x - y * 1.2
                    if not bs or sc < bs then best, bs = n, sc end
                end
            end
        end
        focus(best)
    end
    pcall(updateTabTargets)
    return roots
end

-- Scrolls f one step up or down. True when it moved (or is sure to have).
local function scrollStep(f, dir, cur)
    local up = dir == "UP"
    if f:IsObjectType("ScrollFrame") then
        local okv, v = pcall(f.GetVerticalScroll, f)
        local okr, r = pcall(f.GetVerticalScrollRange, f)
        if not (okv and okr and v and r) then return false end
        if (up and v <= 0.5) or (not up and v >= r - 0.5) then return false end
    elseif f.GetScrollPercentage and f.HasScrollableExtent then
        local okh, has = pcall(f.HasScrollableExtent, f)
        if not (okh and has) then return false end
        local okp, pct = pcall(f.GetScrollPercentage, f)
        if not (okp and pct) then return false end
        if (up and pct <= 0.001) or (not up and pct >= 0.999) then return false end
    end
    local _, before = centerOf(cur)
    local h = f.GetScript and f:GetScript("OnMouseWheel")
    if f.GetScrollPercentage and f.SetScrollPercentage and not f:IsObjectType("ScrollFrame") then
        -- the game's newer lists: half of what shows
        local vis = (f.GetVisibleExtentPercentage and f:GetVisibleExtentPercentage()) or 0.1
        local pct = f:GetScrollPercentage()
        f:SetScrollPercentage(math.max(0, math.min(1, pct + (up and -1 or 1) * math.max(0.02, vis * 0.5))))
        return true
    elseif h then
        pcall(h, f, up and 1 or -1)
    elseif f:IsObjectType("ScrollFrame") then
        local v, r = f:GetVerticalScroll(), f:GetVerticalScrollRange()
        f:SetVerticalScroll(math.max(0, math.min(r, v + (up and -40 or 40))))
    else
        return false
    end
    if f:IsObjectType("ScrollFrame") then return true end
    local _, after = centerOf(cur)
    return before and after and math.abs(before - after) > 0.5 or false
end

-- D-pad move. Up goes up, down goes down, left goes left and right goes right:
--  * only buttons that really lie that way count (beside it in the same row never counts for up / down);
--  * up / down keeps to the column the run started in: straight down if something is there within a couple
--    of rows, else the next row, on the button nearest that column (so it never wanders sideways for good);
--  * the part of the window the pointer is in comes first (the list, the box, the strip of tabs), then the
--    part around that, and so on outwards; a list that can scroll further is scrolled before it is left.
local function move(dir, tries)
    refreshNodes()
    local cur = cursor.cur
    if not cur then return end
    local cl, cb, cr, ct = rectOf(cur)
    if not cl then return end
    local cx, cy = (cl + cr) / 2, (cb + ct) / 2
    local vertical = dir == "UP" or dir == "DOWN"
    local axis = vertical and "V" or "H"
    if cursor.stickNode ~= cur or cursor.stickAxis ~= axis then
        cursor.stickAxis, cursor.stickPos = axis, vertical and cx or cy
    end
    local keep = cursor.stickPos
    local curSize = vertical and (ct - cb) or (cr - cl)
    -- the parts of the window around the pointer, nearest first
    local chain, idx = {}, {}
    do
        local p = cur.GetParent and cur:GetParent()
        while p and #chain < 24 do chain[#chain + 1] = p; idx[p] = #chain; p = p.GetParent and p:GetParent() end
    end
    -- the list the pointer is in, if any (our settings pages, the game's scrolling lists)
    local listAt = 0
    for i = 1, #chain do if isScroller(chain[i]) then listAt = i; break end end
    local function spanDist(v, lo, hi)
        if v >= lo and v <= hi then return 0 end
        return math.min(math.abs(v - lo), math.abs(v - hi))
    end
    local curLo, curHi   -- the pointer's span across the move (its row for left / right)
    if vertical then curLo, curHi = cl, cr else curLo, curHi = cb, ct end
    local list = {}
    for _, n in ipairs(cursor.nodes) do
        if n ~= cur then
            local l, b, r, t = rectOf(n)
            if l then
                local x, y = (l + r) / 2, (b + t) / 2
                local along
                if dir == "UP" then along = y - cy elseif dir == "DOWN" then along = cy - y
                elseif dir == "LEFT" then along = cx - x else along = x - cx end
                local size = vertical and (t - b) or (r - l)
                if along > math.max(3, math.min(size, curSize) * 0.5) then
                    local lo, hi = (vertical and l) or b, (vertical and r) or t
                    local share = #chain + 1
                    local p, guard = n.GetParent and n:GetParent(), 0
                    while p and guard < 24 do
                        if idx[p] then share = idx[p]; break end
                        p = p.GetParent and p:GetParent(); guard = guard + 1
                    end
                    local inList = share <= listAt
                    local across = spanDist(keep, lo, hi)                       -- from the remembered column / row
                    local acrossC = spanDist(vertical and cx or cy, lo, hi)     -- from where the pointer is
                    local overlap = math.min(hi, curHi) - math.max(lo, curLo) > 0   -- same row (or column)
                    local ok
                    if inList then
                        -- in a list: up / down step row by row; left / right stay in the row
                        ok = vertical or overlap
                    else
                        -- elsewhere: only what lies in line (within 45 degrees), so it never jumps across
                        ok = acrossC <= along
                    end
                    if ok then
                        list[#list + 1] = { n = n, along = along, rank = inList and across or acrossC, share = share, size = size, overlap = overlap, aligned = inList or overlap }
                    end
                end
            end
        end
    end
    -- Up / down: a button straight that way in the same column (if one is close), else the next row and the
    -- button in it nearest the column. Left / right: a button in the same row first (nearest), else the nearest
    -- one that way.
    local function pick(set)
        if #set == 0 then return nil end
        local best, ba, bb
        if vertical then
            local minA
            for _, c in ipairs(set) do if not minA or c.along < minA then minA = c.along end end
            -- something straight down (or up) in the same column, no more than a couple of rows away, wins
            local reach = minA + 2.2 * math.max(28, curSize)
            for _, c in ipairs(set) do
                if c.rank == 0 and c.along <= reach and (not best or c.along < bb) then best, bb = c.n, c.along end
            end
            if best then return best end
            for _, c in ipairs(set) do
                if c.along <= minA + math.max(6, c.size * 0.5) then
                    if not best or c.rank < ba - 0.5 or (math.abs(c.rank - ba) <= 0.5 and c.along < bb) then
                        best, ba, bb = c.n, c.rank, c.along
                    end
                end
            end
            return best
        end
        -- left / right: the nearest button sharing the row
        for _, c in ipairs(set) do
            if (c.rank == 0 or c.overlap) and (not best or c.along < bb) then best, bb = c.n, c.along end
        end
        if best then return best end
        for _, c in ipairs(set) do
            local sc = c.along + c.rank * 3
            if not best or sc < bb then best, bb = c.n, sc end
        end
        return best
    end
    local function go(n)
        focus(n)
        cursor.stickNode = n
    end
    -- First what lines up (the same row or column, or the next row of the list), part by part outwards;
    -- only when nothing lines up anywhere, the nearest button roughly that way.
    for k = 1, #chain + 1 do
        local set = {}
        for _, c in ipairs(list) do
            if c.share <= k and c.aligned then set[#set + 1] = c end
        end
        local best = pick(set)
        if best then return go(best) end
        -- nothing more that way in this part: a list that can scroll further is scrolled first
        local f = chain[k]
        if vertical and f and (tries or 0) < 12 and isScroller(f) then
            local ok, moved = pcall(scrollStep, f, dir, cur)
            if ok and moved then
                cursor.scrollPending = true
                C_Timer.After(0.03, function()
                    cursor.scrollPending = nil
                    if cursor.active then move(dir, (tries or 0) + 1) end
                end)
                return
            end
        end
    end
    for k = 1, #chain + 1 do
        local set = {}
        for _, c in ipairs(list) do
            if c.share <= k then set[#set + 1] = c end
        end
        local best = pick(set)
        if best then return go(best) end
    end
end

-- Triggers: a page up or down in the list the pointer is in (or the window's main list).
local function scrollPage(up)
    local f
    local p = cursor.cur and cursor.cur.GetParent and cursor.cur:GetParent()
    for _ = 1, 24 do
        if not p then break end
        if isScroller(p) then f = p; break end
        p = p.GetParent and p:GetParent()
    end
    if not f then
        for _, s in ipairs(cursor.scrollers or {}) do
            if s.IsVisible and s:IsVisible() then f = s; break end
        end
    end
    if not f then return end
    pcall(function()
        if f:IsObjectType("ScrollFrame") then
            local v, r, h = f:GetVerticalScroll(), f:GetVerticalScrollRange(), f:GetHeight()
            f:SetVerticalScroll(math.max(0, math.min(r, v + (up and -1 or 1) * h * 0.85)))
        elseif f.GetScrollPercentage and f.SetScrollPercentage and f.GetVisibleExtentPercentage then
            local pct, vis = f:GetScrollPercentage(), f:GetVisibleExtentPercentage()
            f:SetScrollPercentage(math.max(0, math.min(1, pct + (up and -1 or 1) * vis * 0.85)))
        else
            local h = f:GetScript("OnMouseWheel")
            for _ = 1, 3 do h(f, up and 1 or -1) end
        end
    end)
    C_Timer.After(0.05, function() if cursor.active then refreshNodes() end end)
end

-- A frame unlocked for moving, picked up with A: the D-pad moves it (faster while held), A or B puts it down.
local function nudgeGrab(dir)
    local f = cursor.grab
    if not f then return end
    local step = (cursor.heldAll or 0) > 1.2 and 12 or ((cursor.heldAll or 0) > 0.4 and 4 or 1)
    local dx = (dir == "LEFT" and -step) or (dir == "RIGHT" and step) or 0
    local dy = (dir == "DOWN" and -step) or (dir == "UP" and step) or 0
    local point, rel, rp, x, y = f:GetPoint(1)
    if not point then return end
    f:ClearAllPoints()
    f:SetPoint(point, rel, rp, (x or 0) + dx, (y or 0) + dy)
    if f.ubReport then pcall(f.ubReport) end
    placePointer(f)
end
local function dropGrab()
    local f = cursor.grab
    if not f then return end
    cursor.grab = nil
    f.dragging = false
    if f.ubReport then pcall(f.ubReport) end
    if API.refreshMovers then pcall(API.refreshMovers) end
    if cursor.frame then cursor.frame.box:SetBackdropBorderColor(1, 0.82, 0.1, 0.95) end
    pcall(bindClickTarget, cursor.cur)
end

local function clickNode(btn)
    local n = cursor.cur
    if not n then return end
    if cursor.grab then dropGrab(); return end
    if n.ubMover then
        cursor.grab = n
        n.dragging = true   -- the mover leaves its place alone while it is carried
        if cursor.frame then cursor.frame.box:SetBackdropBorderColor(0.3, 1, 0.4, 1) end
        return
    end
    if n.IsObjectType and n:IsObjectType("EditBox") then
        if openKeyboard then openKeyboard(n) end
        return
    end
    if btn == "LeftButton" and API.menuBarClick and API.menuBarClick(n) then return end
    -- the game's own menus are only ever clicked through the secure key binding (calling their buttons from
    -- here would run the whole menu action, such as Edit Mode, as addon code)
    if inGameMenu(n) or inGamePopup(n) then return end
    if n.Click then
        local ok = pcall(n.Click, n, btn)
        if ok then return end
    end
    synthClick(n, btn, true, true)
end

local function closeTop()
    if cursor.grab then dropGrab(); return end
    if keyboard and keyboard:IsShown() then
        keyboard.close()
        return
    end
    if itemMenu and itemMenu:IsShown() then
        itemMenu:Hide()
        if cursor.menuFrom then focus(cursor.menuFrom) end
        return
    end
    if openMenuRoot() then
        pcall(function()
            local mgr = _G.Menu and _G.Menu.GetManager and _G.Menu.GetManager()
            if mgr and mgr.CloseMenus then mgr:CloseMenus() end
            if CloseDropDownMenus then secureCall(CloseDropDownMenus) end
        end)
        return
    end
    local closed = false
    local bagsDone = false
    for _, name in ipairs(WINDOWS) do
        local f = _G[name]
        if f and f.IsShown and f:IsShown() and f.Hide and name:find("^ContainerFrame") then
            if not bagsDone and not InCombatLockdown() then
                bagsDone = true
                if CloseAllBags then pcall(CloseAllBags) end
            end
            if f:IsShown() then pcall(f.Hide, f) end
            closed = true
        elseif f and f.IsShown and f:IsShown() and f.Hide then
            if f ~= LootFrame and not (InCombatLockdown() and f.IsProtected and f:IsProtected()) then
                secureCall(HideUIPanel, f); closed = true
            end
        end
    end
    if not closed and CloseAllWindows then secureCall(CloseAllWindows) end
end


----------------------------------------------------------------------
-- On-screen keyboard: A on a text box (chat, mail, a search, a name, an amount of gold...) opens it, and
-- the pointer types. X deletes a letter, Y adds a space, B closes it. "Type in chat" on the menu wheel
-- opens it for chat.
----------------------------------------------------------------------
local KB_LETTERS = {
    { "1", "2", "3", "4", "5", "6", "7", "8", "9", "0" },
    { "q", "w", "e", "r", "t", "y", "u", "i", "o", "p" },
    { "a", "s", "d", "f", "g", "h", "j", "k", "l", "'" },
    { "z", "x", "c", "v", "b", "n", "m", ",", ".", "?" },
}
local KB_SYMBOLS = {
    { "1", "2", "3", "4", "5", "6", "7", "8", "9", "0" },
    { "!", "@", "#", "$", "%", "&", "*", "(", ")", "-" },
    { "+", "=", "/", ":", ";", "\"", "<", ">", "_", "~" },
    { "[", "]", "{", "}", "|", "\\", "^", "`", ",", "." },
}
local CHAT_TYPES = { { "SAY", "Say" }, { "PARTY", "Party" }, { "INSTANCE_CHAT", "Instance" }, { "RAID", "Raid" }, { "GUILD", "Guild" }, { "YELL", "Yell" } }

local function chatBox()
    local U = _G.ChatFrameUtil
    local ok, eb = pcall(function() return U and U.ChooseBoxForSend and U.ChooseBoxForSend() end)
    if ok and eb then return eb end
    return _G.ChatFrame1EditBox
end

local function buildKeyboard()
    local K = CreateFrame("Frame", "UbermocKeyboard", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    K:SetFrameStrata("FULLSCREEN_DIALOG")
    K:SetFrameLevel(120)
    K:SetClampedToScreen(true)
    K:EnableMouse(true)
    local KW, KH, GAP = 40, 34, 4
    local W = 10 * (KW + GAP) - GAP + 24
    K:SetSize(W, 5 * (KH + GAP) + 84)
    K:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 150)
    if K.SetBackdrop then
        K:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 2 })
        K:SetBackdropColor(0.03, 0.04, 0.08, 0.97)
        K:SetBackdropBorderColor(1, 0.82, 0.1, 1)
    end
    K.title = K:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    K.title:SetPoint("TOPLEFT", 12, -10)
    K.hint = K:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    K.hint:SetPoint("TOPRIGHT", -12, -12)
    K.hint:SetText("X delete   Y space   B close")
    local pv = CreateFrame("Frame", nil, K)
    pv:SetPoint("TOPLEFT", 12, -30)
    pv:SetPoint("TOPRIGHT", -12, -30)
    pv:SetHeight(28)
    local pbg = pv:CreateTexture(nil, "BACKGROUND")
    pbg:SetAllPoints()
    pbg:SetColorTexture(0, 0, 0, 0.6)
    K.text = pv:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    K.text:SetPoint("LEFT", 8, 0)
    K.text:SetPoint("RIGHT", -8, 0)
    K.text:SetJustifyH("LEFT")
    K.text:SetWordWrap(false)
    local function mkKey(w)
        local b = CreateFrame("Button", nil, K)
        if API.flatButton then API.flatButton(b) end
        b:SetSize(w, KH)
        b:RegisterForClicks("AnyUp")
        return b
    end
    -- the channel to type in (chat only)
    K.chan = mkKey(110)
    K.chan:SetPoint("TOPRIGHT", K, "TOPRIGHT", -12, -6)
    K.chan:SetHeight(22)
    K.chatType = 1
    K.chan:SetScript("OnClick", function()
        K.chatType = K.chatType % #CHAT_TYPES + 1
        K.paint()
    end)
    K.keys = {}
    local top = -66
    for r = 1, 4 do
        for c = 1, 10 do
            local b = mkKey(KW)
            b:SetPoint("TOPLEFT", K, "TOPLEFT", 12 + (c - 1) * (KW + GAP), top - (r - 1) * (KH + GAP))
            b.r, b.c = r, c
            b:SetScript("OnClick", function(self, btn)
                if btn == "RightButton" then K.back() else K.type(self.ch) end
            end)
            K.keys[#K.keys + 1] = b
        end
    end
    local inner = 10 * (KW + GAP) - GAP
    local y = top - 4 * (KH + GAP)
    local x = 12
    local function bottom(label, weight, fn)
        local w = math.floor(inner * weight - GAP + 0.5)
        local b = mkKey(w)
        b:SetPoint("TOPLEFT", K, "TOPLEFT", x, y)
        x = x + w + GAP
        b:SetText(label)
        b:SetScript("OnClick", function(_, btn) if btn == "RightButton" then K.back() else fn() end end)
        return b
    end
    K.shiftB = bottom("Shift", 0.15, function() K.shift = not K.shift; K.paint() end)
    K.symB = bottom("#+=", 0.15, function() K.sym = not K.sym; K.shift = false; K.paint() end)
    K.spaceB = bottom("Space", 0.34, function() K.type(" ") end)
    K.backB = bottom("Delete", 0.16, function() K.back() end)
    K.doneB = bottom("Done", 0.20, function() K.done() end)

    local function getText()
        if K.chat then return K.buf or "" end
        local ok, t = pcall(K.target.GetText, K.target)
        return ok and t or ""
    end
    function K.paint()
        local rows = K.sym and KB_SYMBOLS or KB_LETTERS
        for _, b in ipairs(K.keys) do
            local ch = rows[b.r][b.c]
            if K.shift and not K.sym then ch = ch:upper() end
            b.ch = ch
            b:SetText(ch)
            -- an amount or a number: only the digits
            local show = not K.numeric or (b.r == 1)
            b:SetShown(show)
        end
        K.shiftB:SetShown(not K.numeric)
        K.symB:SetShown(not K.numeric)
        K.spaceB:SetShown(not K.numeric)
        K.shiftB:SetText(K.shift and "SHIFT" or "Shift")
        K.symB:SetText(K.sym and "abc" or "#+=")
        K.chan:SetShown(K.chat and true or false)
        K.hint:SetShown(not K.chat)
        if K.chat then K.chan:SetText("To: " .. CHAT_TYPES[K.chatType][2]) end
        local t = getText()
        if #t > 60 then t = "..." .. t:sub(-57) end
        K.text:SetText(t .. "|cffffd200_|r")
    end
    function K.type(ch)
        if not ch then return end
        if K.chat then
            if #(K.buf or "") < 255 then K.buf = (K.buf or "") .. ch end
        else
            if K.numeric and not ch:find("^%d$") then return end
            local eb = K.target
            pcall(function()
                local before = eb:GetText() or ""
                eb:SetCursorPosition(#before)
                eb:Insert(ch)
                -- a box that takes no letters without focus still gets them
                if (eb:GetText() or "") == before then
                    local max = eb.GetMaxLetters and eb:GetMaxLetters() or 0
                    if max == 0 or #before < max then eb:SetText(before .. ch) end
                end
            end)
        end
        if K.shift and not K.sym then K.shift = false end
        K.paint()
    end
    function K.back()
        local t = getText():gsub("[%z\1-\127\194-\244][\128-\191]*$", "")
        if K.chat then K.buf = t else pcall(K.target.SetText, K.target, t) end
        K.paint()
    end
    function K.close()
        K:Hide()
        if K.from and cursor.active then
            local n = K.from
            C_Timer.After(0, function() if cursor.active then refreshNodes(); if n:IsVisible() then focus(n) end end end)
        end
    end
    function K.done()
        if K.chat then
            local text = K.buf or ""
            K.buf = ""
            K.close()
            if text:find("%S") then
                local chatType = CHAT_TYPES[K.chatType][1]
                pcall(function()
                    local eb = chatBox()
                    if not text:find("^/") and eb.SetChatType then eb:SetChatType(chatType) end
                    eb:SetText(text)
                    if eb.SendText then eb:SendText(1) elseif _G.ChatEdit_SendText then _G.ChatEdit_SendText(eb, 1) end
                    eb:SetText("")
                end)
            end
            return
        end
        local eb = K.target
        K.close()
        local fn = eb and eb.GetScript and eb:GetScript("OnEnterPressed")
        if fn then pcall(fn, eb) end
        -- a box that hands its focus on (mail: name, then subject) would take the controller's buttons
        local fo = GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
        if fo and fo.ClearFocus then pcall(fo.ClearFocus, fo) end
    end
    K:SetScript("OnHide", function() K.target = nil end)
    K:Hide()
    keyboard = K
    return K
end

openKeyboard = function(eb, chat)
    if InCombatLockdown() then return end
    local K = keyboard or buildKeyboard()
    K.from = (not chat) and eb or nil
    K.target = eb
    K.chat = chat and true or false
    K.buf = chat and (K.buf or "") or nil
    K.shift, K.sym = false, false
    K.numeric = (not chat) and eb and eb.IsNumeric and eb:IsNumeric() or false
    local label
    if chat then
        label = "Type in chat"
    else
        local okL, l = pcall(function()
            local ins = eb.Instructions
            if type(ins) == "table" and ins.GetText then return ins:GetText() end
            return eb:GetName()
        end)
        label = okL and l or nil
        if type(label) ~= "string" or label == "" or label:find("^Ubermoc") then label = "Text" end
        label = label:gsub("EditBox$", ""):gsub("([a-z])([A-Z])", "%1 %2")
        if eb.ClearFocus then pcall(eb.ClearFocus, eb) end
    end
    K.title:SetText(label)
    K.paint()
    K:Show()
    if not cursor.active then activate(true) end
    if cursor.active then
        leaveNode(cursor.cur); cursor.cur = nil
        cursor.lt = nil
        refreshNodes()
        -- start on "q" (on "1" for numbers)
        local first = K.numeric and K.keys[1] or K.keys[11]
        if first and first:IsShown() then leaveNode(cursor.cur); cursor.cur = nil; focus(first) end
    end
end
API.openKeyboard = function(eb) if eb then openKeyboard(eb) end end

-- The menu wheel's "Type in chat" entry presses this.
do
    local b = CreateFrame("Button", "UbermocChatTyping", UIParent)
    b:SetSize(1, 1)
    b:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -50, 50)
    b:SetAlpha(0)
    b:EnableMouse(false)
    b:SetScript("OnClick", function()
        C_Timer.After(0.15, function() openKeyboard(nil, true) end)
    end)
end


----------------------------------------------------------------------
-- Item menu (Y by default): use / sell / delete / disenchant and more for the bag slot under the cursor
----------------------------------------------------------------------
local function itemSlot(n)
    if not n then return end
    -- Only real bag and bank slots: other buttons (popups and so on) also have IDs that look like slots.
    if not n.GetBagID then
        local p = n.GetParent and n:GetParent()
        local pn = p and p.GetName and p:GetName() or ""
        if type(pn) ~= "string" or not (pn:find("^ContainerFrame") or pn:find("Bag") or pn:find("Bank")) then return end
    end
    local bag, slot
    if n.GetBagID then local ok, b = pcall(n.GetBagID, n); if ok then bag = b end end
    if n.GetID then local ok, i = pcall(n.GetID, n); if ok then slot = i end end
    if type(bag) ~= "number" and n.GetParent then
        local p = n:GetParent()
        if p and p.GetID then local ok, b = pcall(p.GetID, p); if ok then bag = b end end
    end
    if type(bag) ~= "number" or type(slot) ~= "number" or not (C_Container and C_Container.GetContainerItemInfo) then return end
    local ok, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
    if not ok or not info then return end
    return bag, slot, info
end

local function knownSpell(id)
    local ok, v = pcall(function()
        if C_SpellBook and C_SpellBook.IsSpellKnown then return C_SpellBook.IsSpellKnown(id) end
        return IsPlayerSpell and IsPlayerSpell(id)
    end)
    return ok and v and true or false
end

local function spellName(id)
    local ok, n = pcall(function() return C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id) or GetSpellInfo(id) end)
    return ok and n or nil
end

local function closeItemMenu()
    if itemMenu then itemMenu:Hide() end
    if cursor.menuFrom then focus(cursor.menuFrom) end
end

local function buildItemMenu()
    local m = CreateFrame("Frame", "UbermocCursorMenu", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    m:SetFrameStrata("FULLSCREEN_DIALOG")
    m:SetFrameLevel(100)
    m:SetClampedToScreen(true)
    m:EnableMouse(true)
    if m.SetBackdrop then
        m:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 2 })
        m:SetBackdropColor(0.03, 0.04, 0.08, 0.96)
        m:SetBackdropBorderColor(1, 0.82, 0.1, 1)
    end
    m.title = m:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    m.title:SetPoint("TOP", 0, -8)
    m.title:SetWidth(180)
    m.btns = {}
    local function mk(i, secure)
        local b = CreateFrame("Button", "UbermocCursorMenuBtn" .. i, m, secure and "SecureActionButtonTemplate, UIPanelButtonTemplate" or "UIPanelButtonTemplate")
        b:SetSize(190, 26)
        if secure then
            b:RegisterForClicks("AnyDown", "AnyUp")
            b:SetAttribute("useOnKeyDown", true)
            b.ubSecure = true
        else
            b:RegisterForClicks("AnyUp")
        end
        m.btns[i] = b
        return b
    end
    for i = 1, 6 do mk(i, false) end
    for i = 7, 10 do mk(i, true) end
    m:Hide()
    itemMenu = m
end

-- The spell a spellbook button stands for (nil for anything else, passives and unknown spells included).
local function spellOf(n)
    if not n then return end
    local f = n
    for _ = 1, 4 do
        if not f then break end
        local ok, id = pcall(function()
            local info = f.spellBookItemInfo
            if not info and f.GetSpellBookItemInfo then info = f:GetSpellBookItemInfo() end
            if not info and f.slotIndex and f.spellBank and C_SpellBook and C_SpellBook.GetSpellBookItemInfo then
                info = C_SpellBook.GetSpellBookItemInfo(f.slotIndex, f.spellBank)
            end
            local sid = info and (info.spellID or info.actionID)
            if type(sid) ~= "number" and f.GetSpellID then sid = f:GetSpellID() end
            if type(sid) ~= "number" then sid = f.spellID end
            if type(sid) ~= "number" then return nil end
            if info and info.itemType and Enum and Enum.SpellBookItemType
                and info.itemType ~= Enum.SpellBookItemType.Spell and info.itemType ~= Enum.SpellBookItemType.PetAction then return nil end
            if C_Spell and C_Spell.IsSpellPassive and C_Spell.IsSpellPassive(sid) then return nil end
            return sid
        end)
        if ok and id then return id end
        f = f.GetParent and f:GetParent() or nil
        if f == UIParent then break end
    end
end

local function openSpellMenu(n, sid)
    local m = itemMenu
    cursor.menuFrom = n
    m.title:SetText(spellName(sid) or "Spell")
    for _, b in ipairs(m.btns) do b:Hide() end
    local list = {}
    local function add(label, fn)
        local b = m.btns[#list + 1]
        b:SetScript("OnEnter", nil); b:SetScript("OnLeave", nil)
        b:SetText(label)
        b:SetScript("OnClick", function(_, _, down) if down then return end; fn(b) end)
        list[#list + 1] = b
    end
    add("Bind", function()
        closeItemMenu()
        if not (API.placeSpellFree and API.captureBind) then return end
        local cmd, msg = API.placeSpellFree(sid)
        if not cmd then say(msg or "No room on the bar."); return end
        if API.cursorDeactivate then API.cursorDeactivate() end
        API.captureBind(cmd)
    end)
    add("Add to the utility ring", function()
        closeItemMenu()
        if API.utilRingAdd then API.utilRingAdd({ t = "spell", id = sid }) end
    end)
    local y = -28
    for _, b in ipairs(list) do
        b:ClearAllPoints(); b:SetPoint("TOP", m, "TOP", 0, y); b:Show(); y = y - 30
    end
    m:SetSize(210, -y + 8)
    m:ClearAllPoints()
    local r, cy = n:GetRight(), select(2, n:GetCenter())
    local es = n:GetEffectiveScale() / UIParent:GetEffectiveScale()
    if r and cy then m:SetPoint("LEFT", UIParent, "BOTTOMLEFT", r * es + 10, cy * es) else m:SetPoint("CENTER", UIParent, "CENTER") end
    leaveNode(cursor.cur)
    cursor.cur = nil
    m:Show()
    refreshNodes()
end

-- Bags: what kind of bag an item is, how many slots it has, and the slots it can go in.
local function bagItemKind(info)
    local id = info and info.itemID
    if not id or not (C_Item and C_Item.GetItemInfoInstant) then return end
    local ok, _, _, subType, equipLoc, _, classID = pcall(C_Item.GetItemInfoInstant, id)
    local container = (Enum and Enum.ItemClass and Enum.ItemClass.Container) or 1
    if not ok or classID ~= container or equipLoc ~= "INVTYPE_BAG" then return end
    return subType or "Bag"
end

-- The slot count printed on a bag's tooltip ("%d Slot %s" in the game's own text).
local function bagItemSlots(bag, slot)
    if not (C_TooltipInfo and C_TooltipInfo.GetBagItem) then return end
    local ok, data = pcall(C_TooltipInfo.GetBagItem, bag, slot)
    if not ok or not data or not data.lines then return end
    local pat = CONTAINER_SLOTS and ("^" .. CONTAINER_SLOTS:gsub("%%d", "(%%d+)"):gsub("%%s", ".+") .. "$")
    for _, l in ipairs(data.lines) do
        local t = l.leftText
        if type(t) == "string" then
            local n = pat and t:match(pat)
            if n then return tonumber(n) end
        end
    end
end

-- Equipped bag slots: 1-4 for bags, 5 for the reagent bag.
local function bagSlotInfo(bagID)
    local inv = C_Container and C_Container.ContainerIDToInventoryID and C_Container.ContainerIDToInventoryID(bagID)
    local link = inv and GetInventoryItemLink("player", inv)
    local size = C_Container.GetContainerNumSlots(bagID) or 0
    local free = C_Container.GetContainerNumFreeSlots and C_Container.GetContainerNumFreeSlots(bagID) or size
    return inv, link, size, size - (free or 0)
end

local openItemMenu
local function openBagSlotMenu(n, bag, slot, info, kind)
    local m = itemMenu
    cursor.menuFrom = n
    local name = (info.hyperlink and info.hyperlink:match("%[(.-)%]")) or "Bag"
    local mySlots = bagItemSlots(bag, slot)
    m.title:SetText("Equip " .. name)
    for _, b in ipairs(m.btns) do b:Hide(); b:SetScript("OnEnter", nil); b:SetScript("OnLeave", nil) end
    local list = {}
    local reagentID = (Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag) or 5
    local function slotButton(bagID, label)
        local b = m.btns[#list + 1]
        local inv, link, size, used = bagSlotInfo(bagID)
        local cur = link and (link:match("%[(.-)%]")) or "empty"
        b:SetText(label)
        b:SetScript("OnClick", function(_, _, down)
            if down then return end
            if InCombatLockdown() then say("Bags can't be changed in combat."); return end
            if not inv then return end
            pcall(ClearCursor)
            pcall(C_Container.PickupContainerItem, bag, slot)
            if CursorHasItem and CursorHasItem() then pcall(PutItemInBag, inv) end
            pcall(ClearCursor)
            closeItemMenu()
        end)
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(label, 1, 0.82, 0)
            if link then
                GameTooltip:AddLine("Now: " .. cur .. " (" .. size .. " slots, " .. used .. " in use)", 1, 1, 1)
            else
                GameTooltip:AddLine("Now: empty", 1, 1, 1)
            end
            if mySlots then
                GameTooltip:AddLine(name .. ": " .. mySlots .. " slots (" .. kind .. ")", 1, 1, 1)
                local diff = mySlots - (link and size or 0)
                if diff > 0 then GameTooltip:AddLine(diff .. " more slots", 0.2, 1, 0.2)
                elseif diff < 0 then GameTooltip:AddLine(-diff .. " fewer slots", 1, 0.3, 0.3)
                else GameTooltip:AddLine("Same number of slots", 0.8, 0.8, 0.8) end
            else
                GameTooltip:AddLine(name .. " (" .. kind .. ")", 1, 1, 1)
            end
            if link and used > 0 then GameTooltip:AddLine("The bag there still holds items.", 1, 0.6, 0.2, true) end
            if bagID == reagentID then GameTooltip:AddLine("Only reagent bags fit here.", 0.7, 0.7, 0.7, true) end
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        list[#list + 1] = b
    end
    for i = 1, (NUM_BAG_SLOTS or 4) do slotButton(i, "Bag slot " .. i) end
    slotButton(reagentID, "Reagent bag slot")
    local back = m.btns[#list + 1]
    back:SetText("Back")
    back:SetScript("OnClick", function(_, _, down) if down then return end; cursor.cur = n; openItemMenu() end)
    list[#list + 1] = back
    local y = -28
    for _, b in ipairs(list) do b:ClearAllPoints(); b:SetPoint("TOP", m, "TOP", 0, y); b:Show(); y = y - 30 end
    m:SetSize(210, -y + 8)
    m:ClearAllPoints()
    local r, cy = n:GetRight(), select(2, n:GetCenter())
    local es = n:GetEffectiveScale() / UIParent:GetEffectiveScale()
    if r and cy then m:SetPoint("LEFT", UIParent, "BOTTOMLEFT", r * es + 10, cy * es) else m:SetPoint("CENTER", UIParent, "CENTER") end
    leaveNode(cursor.cur)
    cursor.cur = nil
    m:Show()
    refreshNodes()
end

openItemMenu = function()
    if not cursor.active or InCombatLockdown() then return end
    if not itemMenu then buildItemMenu() end
    local n = cursor.cur
    local bag, slot, info = itemSlot(n)
    if not bag then
        local sid = spellOf(n)
        if sid then return openSpellMenu(n, sid) end
        local now = GetTime()
        if not cursor.lastHint or now - cursor.lastHint > 1 then
            cursor.lastHint = now
            say("The options menu works on items in your bags and bank, and on spells in the spellbook.")
        end
        return
    end
    local m = itemMenu
    cursor.menuFrom = n
    local link = info.hyperlink
    local name = (link and link:match("%[(.-)%]")) or "Item"
    m.title:SetText(name)
    local vendor = MerchantFrame and MerchantFrame:IsShown()
    local list = {}
    local function add(label, fn)
        local b = m.btns[#list + 1]
        if not b or #list >= 6 then return end
        b:SetScript("OnEnter", nil); b:SetScript("OnLeave", nil)
        b:SetText(label)
        b:SetScript("OnClick", function(_, _, down) if down then return end; fn(b) end)
        list[#list + 1] = b
    end
    -- Use / equip / sell goes through a secure item button: the game only lets a real button press use an item.
    do
        local b = m.btns[10]
        local bn = n.GetName and n:GetName()
        b.ubClickRight = nil
        if vendor and bn then
            -- Selling: the same right-click on the bag slot the game itself uses at a vendor.
            b:SetAttribute("type", "macro")
            b:SetAttribute("macrotext", "/click " .. bn .. " RightButton")
            b:SetAttribute("item", nil)
        elseif vendor then
            -- Unnamed slot: press it with the right button through the pointer's binding.
            b:SetAttribute("type", "click")
            b:SetAttribute("clickbutton", n)
            b.ubClickRight = true
        else
            b:SetAttribute("type", "item")
            b:SetAttribute("item", bag .. " " .. slot)
            b:SetAttribute("macrotext", nil)
        end
        b:SetText(vendor and "Sell" or "Use / equip")
        if not b.ubHooked then
            b.ubHooked = true
            b:HookScript("PostClick", function() C_Timer.After(0.1, closeItemMenu) end)
        end
        list[#list + 1] = b
    end
    local kind = bagItemKind(info)
    if kind and bag ~= nil then
        add("Equip in a bag slot", function() openBagSlotMenu(n, bag, slot, info, kind) end)
    end
    add("Pick up / move", function() closeItemMenu(); pcall(n.Click, n, "LeftButton") end)
    do
        local id = info.itemID
        local okS, useName = pcall(function() return id and C_Item.GetItemSpell(id) end)
        if id and okS and useName then
            add("Add to the utility ring", function() closeItemMenu(); if API.utilRingAdd then API.utilRingAdd({ t = "item", id = id }) end end)
        end
    end
    local armed = false
    add("Delete", function(b)
        if not armed then armed = true; b:SetText("Really delete?"); return end
        pcall(C_Container.PickupContainerItem, bag, slot)
        if CursorHasItem and CursorHasItem() then pcall(DeleteCursorItem) end
        closeItemMenu()
    end)
    if C_Container.SortBags then add("Sort bags", function() closeItemMenu(); pcall(C_Container.SortBags) end) end
    if info.isLocked then end
    -- Profession actions use a secure macro: cast the spell, then use the item slot.
    local secureList = {}
    for idx, spell in ipairs({ { 13262, "Disenchant" }, { 31252, "Prospect" }, { 51005, "Mill" } }) do
        local b = m.btns[6 + idx]
        local sn = spellName(spell[1])
        if b and sn and knownSpell(spell[1]) then
            b:SetAttribute("type", "macro")
            b:SetAttribute("macrotext", "/cast " .. sn .. "\n/use " .. bag .. " " .. slot)
            b:SetText(spell[2])
            if not b.ubHooked then
                b.ubHooked = true
                b:HookScript("PostClick", function() C_Timer.After(0.1, closeItemMenu) end)
            end
            secureList[#secureList + 1] = b
        end
    end
    for _, b in ipairs(secureList) do list[#list + 1] = b end
    for _, b in ipairs(m.btns) do b:Hide() end
    local y = -28
    for _, b in ipairs(list) do
        b:ClearAllPoints()
        b:SetPoint("TOP", m, "TOP", 0, y)
        b:Show()
        y = y - 30
    end
    m:SetSize(210, -y + 8)
    -- Placed by screen position: the menu holds secure buttons, so it can't be anchored to other frames.
    m:ClearAllPoints()
    local r, cy = n:GetRight(), select(2, n:GetCenter())
    local es = n:GetEffectiveScale() / UIParent:GetEffectiveScale()
    if r and cy then
        m:SetPoint("LEFT", UIParent, "BOTTOMLEFT", r * es + 10, cy * es)
    else
        m:SetPoint("CENTER", UIParent, "CENTER")
    end
    leaveNode(cursor.cur)
    cursor.cur = nil
    m:Show()
    refreshNodes()
end

local PADKEYS = { "PADDUP", "PADDDOWN", "PADDLEFT", "PADDRIGHT" }  -- the item menu key is added below
local PADACT = { PADDUP = "UP", PADDDOWN = "DOWN", PADDLEFT = "LEFT", PADDRIGHT = "RIGHT", PAD1 = "A", PAD2 = "B", PAD3 = "X", PAD4 = "Y",
                 PADLTRIGGER = "PGUP", PADRTRIGGER = "PGDN" }
-- A button the game uses as Shift, Ctrl or Alt is never taken over (it would stop working as one).
local function isPadModifier(key)
    for _, cv in ipairs({ "GamePadEmulateShift", "GamePadEmulateCtrl", "GamePadEmulateAlt" }) do
        local ok, v = pcall(GetCVar, cv)
        if ok and v == key then return true end
    end
    return false
end

-- While the cursor is open the D-pad and face buttons are taken over with priority override bindings,
-- so they stop casting abilities. They are released when the cursor closes (and by a secure driver at combat start).
local function setPadBindings(on)
    local o = cursor.owner
    if not o then return end
    if InCombatLockdown() then return end
    ClearOverrideBindings(o)
    cursor.clickTarget, cursor.rightTarget = nil, nil
    if on then
        for _, key in ipairs(PADKEYS) do
            SetOverrideBindingClick(o, true, key, "UbermocCursorKey" .. PADACT[key], "LeftButton")
        end
        -- Bumpers step through the tabs, triggers scroll a page.
        if DB.cursor.shoulders ~= false then
            for _, spec in ipairs({ { "PADLSHOULDER", "UbermocCursorTabPrev" }, { "PADRSHOULDER", "UbermocCursorTabNext" },
                                    { "PADLTRIGGER", "UbermocCursorKeyPGUP" }, { "PADRTRIGGER", "UbermocCursorKeyPGDN" } }) do
                if not isPadModifier(spec[1]) then SetOverrideBindingClick(o, true, spec[1], spec[2], "LeftButton") end
            end
            cursor.tabPrevT, cursor.tabNextT = false, false   -- set again on the next look
        end
        -- Click, right-click, back and the item menu: A, X, B and Y (the bottom, left, right and top face buttons
        -- of any controller), unless another controller button is bound to it in Key Bindings / the Interact page.
        -- A keyboard key bound to it does not take the face button away.
        cursor.clickKeys, cursor.rightKeys, cursor.clickTarget, cursor.rightTarget = {}, {}, nil, nil
        for _, spec in ipairs({ { "UBERMOCUI_CURSORCLICK", "PAD1", "A" }, { "UBERMOCUI_CURSORRIGHT", "PAD3", "X" },
                                { "UBERMOCUI_CURSORBACK", "PAD2", "B" }, { "UBERMOCUI_CURSORMENU", "PAD4", "Y" } }) do
            local keys = { GetBindingKey(spec[1]) }
            local onPad = false
            for _, key in ipairs(keys) do
                if (key:match("([^-]+)$") or key):find("^PAD") then onPad = true end
            end
            if not onPad then keys[#keys + 1] = spec[2] end
            for _, key in ipairs(keys) do
                SetOverrideBindingClick(o, true, key, "UbermocCursorKey" .. spec[3], "LeftButton")
                if spec[3] == "A" then cursor.clickKeys[#cursor.clickKeys + 1] = key end
                if spec[3] == "X" then cursor.rightKeys[#cursor.rightKeys + 1] = key end
            end
        end
    end
end

-- How to move the pointer, in the labels of the controller in use: the same line is in the settings window's title bar
-- and along the bottom of the screen while the pointer is on any other window.
function API.pointerHintText(sep)
    local C = DB and DB.cursor or {}
    local function lab(key) return (API.padLabel and API.padLabel(key, true)) or key end
    local function bound(cmd, default)
        local keys = GetBindingKey and { GetBindingKey(cmd) } or {}
        for _, k in ipairs(keys) do
            if type(k) == "string" and (k:match("([^-]+)$") or k):find("^PAD") then return k end
        end
        return default
    end
    local function key(k) return "|cffffd100[" .. lab(k) .. "]|r" end
    local parts = { "|cffffd100[D-pad]|r Move" }
    parts[#parts + 1] = key(bound("UBERMOCUI_CURSORCLICK", "PAD1")) .. " Click"
    parts[#parts + 1] = key(bound("UBERMOCUI_CURSORRIGHT", "PAD3")) .. " Right-click"
    parts[#parts + 1] = key(bound("UBERMOCUI_CURSORMENU", "PAD4")) .. " Menu"
    parts[#parts + 1] = key(bound("UBERMOCUI_CURSORBACK", "PAD2")) .. " Back"
    if C.shoulders ~= false then
        if not (isPadModifier("PADLSHOULDER") or isPadModifier("PADRSHOULDER")) then
            parts[#parts + 1] = key("PADLSHOULDER") .. key("PADRSHOULDER") .. " Tabs"
        end
        if not (isPadModifier("PADLTRIGGER") or isPadModifier("PADRTRIGGER")) then
            parts[#parts + 1] = key("PADLTRIGGER") .. key("PADRTRIGGER") .. " Scroll"
        end
    end
    return table.concat(parts, sep or "   ")
end

-- The same line along the bottom of the screen while the pointer is on a window that has no title bar of ours.
do
    local strip
    local acc = 0
    local f = CreateFrame("Frame")
    f:SetScript("OnUpdate", function(_, dt)
        acc = acc + dt
        if acc < 0.25 then return end
        acc = 0
        local want = cursor.active and DB and DB.cursor and DB.cursor.hint ~= false
            and not (_G.UbermocUIWindow and _G.UbermocUIWindow:IsShown())
        if not want then
            if strip and strip:IsShown() then strip:Hide() end
            return
        end
        if not strip then
            strip = CreateFrame("Frame", "UbermocPointerHint", UIParent)
            strip:SetFrameStrata("TOOLTIP")
            strip:SetHeight(24)
            strip.bg = strip:CreateTexture(nil, "BACKGROUND")
            strip.bg:SetAllPoints()
            strip.bg:SetColorTexture(0.03, 0.04, 0.08, 0.88)
            strip.text = strip:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            strip.text:SetPoint("CENTER")
            strip:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 14)
        end
        local text = API.pointerHintText()
        if strip.shown ~= text then
            strip.shown = text
            strip.text:SetText(text)
            strip:SetWidth(strip.text:GetStringWidth() + 28)
        end
        if not strip:IsShown() then strip:Show() end
    end)
end

local function deactivate()
    if not cursor.active then return end
    if cursor.grab then pcall(dropGrab) end
    if keyboard and keyboard:IsShown() then keyboard:Hide() end
    cursor.clickTarget, cursor.rightTarget = nil, nil
    cursor.active = false
    leaveNode(cursor.cur)
    cursor.cur = nil
    setPadBindings(false)
    if cursor.frame then
        cursor.frame:Hide()
        cursor.input:EnableKeyboard(false)
    end
end
API.cursorDeactivate = deactivate

local function gamepadOn()
    local ok, v = pcall(GetCVarBool, "GamePadEnable")
    return ok and v and true or false
end

activate = function(manual)
    if not DB or not DB.cursor.on then return false, "off" end
    if not cursor.frame then return false, "not built" end
    if InCombatLockdown() then return false, "combat" end
    if cursor.active then return true end
    if not manual and not gamepadOn() then return false, "no gamepad" end
    local nodes = collect()
    if #nodes == 0 then return false, "no buttons found" end
    cursor.active = true
    cursor.input:EnableKeyboard(true)
    if not InCombatLockdown() then cursor.input.ubermocProp = true; cursor.input:SetPropagateKeyboardInput(true) end
    setPadBindings(true)
    refreshNodes()
    return true
end
API.cursorActivate = function() activate(false) end
-- Starts the pointer over again (a window was swapped for another: the options window for ours).
API.cursorRestart = function()
    if cursor.active and deactivate then pcall(deactivate) end
    for _, t in ipairs({ 0.3, 0.9, 1.8 }) do C_Timer.After(t, function() if not cursor.active then activate(false) end end) end
end
-- Opens the pointer on the first entry of the game's open pop-up menu (used after the target menu opens).
API.cursorToMenu = function()
    if not (DB and DB.cursor and DB.cursor.on) or InCombatLockdown() then return end
    local root = openMenuRoot()
    if not root then return end
    local out = {}
    scan(root, out, 0)
    if #out == 0 then return end
    activate(true)
    if not cursor.active then return end
    local best, by, bx
    for _, n in ipairs(out) do
        local x, y = n:GetCenter()
        if x and y and (not by or y > by + 2 or (math.abs(y - by) <= 2 and x < bx)) then best, by, bx = n, y, x end
    end
    if best then
        refreshNodes()
        if cursor.cur ~= best then leaveNode(cursor.cur); cursor.cur = nil; focus(best) end
    end
end

local function padAction(act)
    if not cursor.active then return end
    local dir = act == "UP" or act == "DOWN" or act == "LEFT" or act == "RIGHT"
    if cursor.grab then
        if dir then nudgeGrab(act) elseif act == "A" or act == "B" then dropGrab() end
        return
    end
    local typing = keyboard and keyboard:IsShown()
    if dir then move(act)
    elseif act == "A" then clickNode("LeftButton")
    elseif act == "X" then if typing then keyboard.back() else clickNode("RightButton") end
    elseif act == "B" then closeTop()
    elseif act == "Y" then if typing then keyboard.type(" ") else openItemMenu() end
    elseif act == "PGUP" or act == "PGDN" then scrollPage(act == "PGUP") end
end

function UbermocUI_CursorMenu() padAction("Y") end
function UbermocUI_CursorClick() padAction("A") end
function UbermocUI_CursorRight() padAction("X") end
function UbermocUI_CursorBack() padAction("B") end

local function buildCursor()
    local c = CreateFrame("Frame", "UbermocCursor", UIParent)
    c:SetFrameStrata("TOOLTIP")   -- above every window (a window raised to the top would otherwise cover it)
    c:SetFrameLevel(50)
    c:SetSize(1, 1)
    c:SetPoint("CENTER", UIParent, "CENTER")
    c:Hide()
    c.box = CreateFrame("Frame", nil, c, BackdropTemplateMixin and "BackdropTemplate" or nil)
    c.box:SetFrameStrata("TOOLTIP")
    c.box:SetFrameLevel(49)
    if c.box.SetBackdrop then
        c.box:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14 })
        c.box:SetBackdropBorderColor(1, 0.82, 0.1, 0.95)
    end
    c.ptr = c:CreateTexture(nil, "OVERLAY")
    c.ptr:SetTexture("Interface\\CURSOR\\Point")
    c.ptr:SetSize(26, 26)
    cursor.frame, cursor.ptr = c, c.ptr

    -- Owner of the override bindings. A secure driver clears them the moment combat starts.
    local owner = CreateFrame("Frame", "UbermocCursorOwner", UIParent, "SecureHandlerStateTemplate")
    owner:SetAttribute("_onstate-combat", [[ if newstate == "1" then self:ClearBindings() end ]])
    pcall(RegisterStateDriver, owner, "combat", "[combat] 1; 0")
    cursor.owner = owner
    for _, spec in ipairs({ { "UbermocCursorClickBtn", "clickBtn" }, { "UbermocCursorRightBtn", "rightBtn" } }) do
        local sb = CreateFrame("Button", spec[1], UIParent, "SecureActionButtonTemplate")
        sb:SetAttribute("type", "click")
        sb:SetAttribute("useOnKeyDown", false)
        sb:RegisterForClicks("AnyUp")
        -- Frames that react to mouse down / up scripts instead of OnClick get those too.
        sb:HookScript("PreClick", function(self, btn, down)
            local n = self:GetAttribute("clickbutton")
            if not n or not n.GetScript or n:GetScript("OnClick") then return end
            synthClick(n, btn, true, true)
        end)
        cursor[spec[2]] = sb
    end
    -- Bumpers: a real click on the tab before or after the selected one.
    for _, spec in ipairs({ { "UbermocCursorTabPrev", "tabPrev" }, { "UbermocCursorTabNext", "tabNext" } }) do
        local sb = CreateFrame("Button", spec[1], UIParent, "SecureActionButtonTemplate")
        sb:SetAttribute("type", "click")
        sb:SetAttribute("useOnKeyDown", false)
        sb:RegisterForClicks("AnyUp")
        sb:HookScript("PostClick", function(self)
            local t = self:GetAttribute("clickbutton")
            C_Timer.After(0.05, function()
                if not cursor.active then return end
                refreshNodes()
                -- our own tabs stay selectable: the pointer goes onto the tab just opened
                for _, n in ipairs(cursor.nodes) do if n == t then focus(t); break end end
            end)
        end)
        cursor[spec[2]] = sb
    end
    for _, act in pairs(PADACT) do
        local btn = CreateFrame("Button", "UbermocCursorKey" .. act, UIParent)
        btn:RegisterForClicks("AnyDown", "AnyUp")
        btn:SetScript("OnClick", function(_, _, down)
            -- A on a hold-to-repeat button (- and +, < and >, Up and Down): held, it repeats like a held mouse button.
            local hb = cursor.holdBtn
            if act == "A" and not down and hb then
                cursor.holdBtn = nil
                local up = hb:GetScript("OnMouseUp")
                if up then up(hb, "LeftButton") end
                if hb.repeated then hb.repeated = false elseif hb.holdFn then hb.holdFn(1) end
                return
            end
            local cn = cursor.cur
            if act == "A" and down and cursor.active and not cursor.grab and cn and cn.holdFn and cn:IsVisible()
                and (not cn.IsEnabled or cn:IsEnabled()) and cn:GetScript("OnMouseDown") then
                cursor.holdBtn = cn
                cn:GetScript("OnMouseDown")(cn, "LeftButton")
                return
            end
            if down then
                cursor.heldAll = 0
                padAction(act)
                if act == "UP" or act == "DOWN" or act == "LEFT" or act == "RIGHT" then
                    cursor.held, cursor.heldT, cursor.heldAll = act, -0.4, 0   -- hold the D-pad to keep moving
                end
            elseif cursor.held == act then
                cursor.held = nil
            end
        end)
    end

    -- Keyboard: arrows and Enter work too.
    local inp = CreateFrame("Frame", "UbermocCursorInput", UIParent)
    inp:SetFrameStrata("TOOLTIP")
    inp:SetSize(1, 1)
    inp:SetPoint("CENTER")
    inp:EnableKeyboard(false)
    inp:SetScript("OnKeyDown", function(self, key)
        local dir = DIRS[key]
        local handled = false
        if cursor.active then
            -- with a controller on, only the d-pad moves the pointer (the sticks, which can arrive as arrow keys, do not)
            if dir and not key:find("^PAD") and not key:find("STICK") and not gamepadOn() then move(dir); handled = true
            elseif key == "ENTER" then clickNode("LeftButton"); handled = true end
        end
        -- Protected in combat: touching it there raises ADDON_ACTION_BLOCKED, so leave it alone then.
        if not InCombatLockdown() and self.ubermocProp ~= (not handled) then
            self.ubermocProp = not handled
            self:SetPropagateKeyboardInput(not handled)
        end
    end)
    cursor.input = inp

    local acc = 0
    c:SetScript("OnUpdate", nil)
    local watch = CreateFrame("Frame")
    watch:SetScript("OnUpdate", function(_, dt)
        if cursor.held and cursor.active then
            cursor.heldT = (cursor.heldT or 0) + dt
            cursor.heldAll = (cursor.heldAll or 0) + dt
            local cn = cursor.cur
            local every = cursor.grab and 0.05 or 0.12
            if cursor.heldT >= every and not cursor.scrollPending then
                cursor.heldT = 0
                if cursor.grab then nudgeGrab(cursor.held) else move(cursor.held) end
            end
        end
        acc = acc + dt
        if acc < 0.25 then return end
        acc = 0
        if not cursor.active then return end
        -- A text box that takes the focus by itself (a search box, mail) would swallow every controller
        -- button and the pointer would stop. While the controller is what is being used, it lets go; A on
        -- the box opens the on-screen keyboard instead.
        if cursor.padActive ~= false and gamepadOn() and not (keyboard and keyboard:IsShown()) then
            local fo = GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
            if fo and fo.ClearFocus and not (fo.IsForbidden and fo:IsForbidden()) then pcall(fo.ClearFocus, fo) end
        end
        local roots = refreshNodes()
        if roots == 0 or #cursor.nodes == 0 then
            -- a short gap (a window changing or sliding in) does not end it
            cursor.empty = (cursor.empty or 0) + 1
            if cursor.empty >= 4 then cursor.empty = 0; deactivate() end
        else
            cursor.empty = 0
            if cursor.cur then placePointer(cursor.cur) end
        end
    end)

    local ev = CreateFrame("Frame")
    -- PLAYER_INTERACTION_MANAGER_FRAME_SHOW is how the game opens the transmog window (and the other NPC windows
    -- that are loaded when first needed): it loads the window and shows it in one step, before a hook on it exists.
    for _, e in ipairs({ "GOSSIP_SHOW", "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE", "QUEST_GREETING", "MERCHANT_SHOW",
        "MAIL_SHOW", "BANKFRAME_OPENED", "TRAINER_SHOW", "TAXIMAP_OPENED", "TRADE_SHOW", "AUCTION_HOUSE_SHOW",
        "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" }) do
        pcall(ev.RegisterEvent, ev, e)
    end
    ev:RegisterEvent("PLAYER_REGEN_DISABLED")
    pcall(ev.RegisterEvent, ev, "GAME_PAD_ACTIVE_CHANGED")
    ev:SetScript("OnEvent", function(_, e, arg1)
        if e == "GAME_PAD_ACTIVE_CHANGED" then cursor.padActive = arg1 and true or false; return end
        if e == "PLAYER_REGEN_DISABLED" then
            if keyboard and keyboard:IsShown() then keyboard:Hide() end
            if cursor.grab then pcall(dropGrab) end
            -- the secure driver already released the bindings
            cursor.active = false
            leaveNode(cursor.cur); cursor.cur = nil
            c:Hide()
            -- the key listener lets go too (still allowed at this moment), so no key can be held back in combat
            pcall(cursor.input.SetPropagateKeyboardInput, cursor.input, true)
            pcall(cursor.input.EnableKeyboard, cursor.input, false)
            return
        end
        if DB and DB.cursor.auto then
            -- tried again a little later when the window was not ready yet (the camera is moving in then)
            for _, t in ipairs({ 0.35, 1.0, 2.0 }) do C_Timer.After(t, function() if not cursor.active then activate(false) end end) end
        end
    end)

    -- Windows without an event (bags, character, map...): open the cursor when they show.
    local function hookShow(f)
        if type(f) == "table" and f.HookScript and not f.ubermocCursorHook then
            f.ubermocCursorHook = true
            f:HookScript("OnShow", function()
                if DB and DB.cursor.auto then C_Timer.After(0.35, function() activate(false) end) end
            end)
            -- hooked after it was already shown (a window loaded and shown in one step)
            if f.IsShown and f:IsShown() and DB and DB.cursor.auto then
                for _, t in ipairs({ 0.2, 0.6, 1.5 }) do C_Timer.After(t, function() if not cursor.active then activate(false) end end) end
            end
            -- Closing a window ends the cursor right away (the slow check below only runs every quarter second
            -- and waits several rounds), after a double look so a window sliding in or out doesn't end it.
            f:HookScript("OnHide", function()
                if not cursor.active then return end
                C_Timer.After(0.1, function()
                    if not cursor.active then return end
                    local _, r1 = collect()
                    if r1 and r1 > 0 then return end
                    C_Timer.After(0.1, function()
                        if not cursor.active then return end
                        local _, r2 = collect()
                        if not r2 or r2 == 0 then cursor.empty = 0; deactivate() end
                    end)
                end)
            end)
        end
    end
    API.cursorHook = hookShow   -- windows built later (the settings window) hook themselves in
    local function hookAll()
        for _, n in ipairs(WINDOWS) do hookShow(_G[n]) end
        for i = 1, 13 do hookShow(_G["ContainerFrame" .. i]) end
        if type(UIPanelWindows) == "table" then
            for name in pairs(UIPanelWindows) do if type(name) == "string" then hookShow(_G[name]) end end
        end
        for i = 1, 4 do hookShow(_G["GroupLootFrame" .. i]) end
    end
    -- The transmog and wardrobe windows come with their own game addons, loaded when first needed: once one is
    -- loaded, its top-level windows (named Transmog... or Wardrobe...) are added to the list and hooked.
    local discovered = {}
    local function discover()
        for _, addon in ipairs({ "Blizzard_Transmog", "Blizzard_Collections" }) do
            if not discovered[addon] and C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(addon) then
                discovered[addon] = true
                local have = {}
                for _, n in ipairs(WINDOWS) do have[n] = true end
                for name, v in pairs(_G) do
                    if type(name) == "string" and not have[name] and (name:find("^Transmog") or name:find("^Wardrobe"))
                        and type(v) == "table" and v.GetParent and v.IsVisible and v:GetParent() == UIParent then
                        WINDOWS[#WINDOWS + 1] = name
                    end
                end
            end
        end
    end
    local hookAll0 = hookAll
    hookAll = function() pcall(discover); hookAll0() end
    hookAll()
    local ev2 = CreateFrame("Frame")
    ev2:RegisterEvent("ADDON_LOADED")
    ev2:SetScript("OnEvent", function() C_Timer.After(0, hookAll); C_Timer.After(0.2, hookAll) end)
    for _, fn in ipairs({ "ToggleAllBags", "OpenAllBags", "ToggleBackpack", "OpenBackpack", "ToggleBag", "OpenBag" }) do
        if _G[fn] then
            hooksecurefunc(fn, function()
                hookAll()
                if DB and DB.cursor.auto then C_Timer.After(0.4, function() activate(false) end) end
            end)
        end
    end
end

-- A small "[Y] Options" tag under the bags and the spellbook while a controller is in use, so it is clear
-- the options button does something there.
do
    local tags = {}
    local function keyWord()
        local k = GetBindingKey and GetBindingKey("UBERMOCUI_CURSORMENU")
        if k and API.padLabel then return API.padLabel(k, true) end
        return "Y"
    end
    local function paint(f)
        local t = tags[f]
        if not t then return end
        if gamepadOn() and DB and DB.cursor and DB.cursor.on and DB.cursor.hint ~= false then
            t.text:SetText("[" .. keyWord() .. "] Options")
            t:Show()
        else
            t:Hide()
        end
    end
    local function tagFor(name)
        local f = _G[name]
        if type(f) ~= "table" or not f.HookScript or tags[f] then return end
        local t = CreateFrame("Frame", nil, f)
        t:SetSize(110, 18)
        t:SetPoint("TOPRIGHT", f, "BOTTOMRIGHT", -6, -2)
        t.bg = t:CreateTexture(nil, "BACKGROUND")
        t.bg:SetAllPoints()
        t.bg:SetColorTexture(0.03, 0.04, 0.08, 0.85)
        t.text = t:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        t.text:SetPoint("CENTER")
        tags[f] = t
        f:HookScript("OnShow", function() paint(f) end)
        paint(f)
    end
    local function tagAll()
        for _, n in ipairs({ "ContainerFrameCombinedBags", "PlayerSpellsFrame", "SpellBookFrame", "ContainerFrame1" }) do tagFor(n) end
        for f in pairs(tags) do paint(f) end
    end
    API.refreshOptionTags = tagAll
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("PLAYER_ENTERING_WORLD")
    ev:RegisterEvent("ADDON_LOADED")
    ev:RegisterEvent("UPDATE_BINDINGS")
    pcall(ev.RegisterEvent, ev, "GAME_PAD_ACTIVE_CHANGED")
    ev:SetScript("OnEvent", function() C_Timer.After(0.3, tagAll) end)
end

SLASH_UBERMOCRING1 = "/ubring"
SlashCmdList["UBERMOCRING"] = function(msg)
    local r = (msg or ""):lower():find("util") and rings.Util or rings.Pet
    if not r then say("rings are not built yet"); return end
    local key = GetBindingKey("CLICK UbermocRing" .. r.key .. "Toggle:LeftButton")
    say(r.key .. " ring: key=" .. tostring(key) .. " buttons=" .. tostring(r.n) .. " off=" .. tostring(r.toggle:GetAttribute("off")) .. " shown=" .. tostring(r.frame:IsShown()))
    if InCombatLockdown() then return end
    if r.frame:IsShown() then r.frame:Hide() else placeRing(r); r.frame:Show() end
end

function API.ringReport(which)
    local w = (which or ""):lower()
    local r = w:find("util") and rings.Util or (w:find("menu") and rings.Menu) or rings.Pet
    if not r then say("rings are not built yet"); return end
    local key = GetBindingKey("CLICK UbermocRing" .. r.key .. "Toggle:LeftButton")
    say(r.key .. " ring: key=" .. tostring(key) .. " entries=" .. tostring(r.n) .. " open=" .. tostring(r.frame:IsShown())
        .. " hasPet=" .. tostring(UnitExists("pet")) .. " combat=" .. tostring(InCombatLockdown()))
    for _, line in ipairs(r.errors or {}) do say("ring error: " .. line) end
    if API.buildErrors then for _, line in ipairs(API.buildErrors) do say("build error: " .. line) end end
    if r.key == "Pet" then
        for i = 1, 10 do
            local ok, name, tex, tok = pcall(GetPetActionInfo, i)
            local b = r.buttons[i]
            local icon = b and b.icon and b.icon.GetTexture and b.icon:GetTexture()
            say("pet slot " .. i .. ": api=" .. tostring(ok and name or "-") .. " tex=" .. tostring(ok and tex or "-") .. " token=" .. tostring(ok and tok or "-")
                .. " | ring button: " .. (b and ("shown=" .. tostring(b:IsShown()) .. " size=" .. math.floor(b:GetWidth()) .. " icon=" .. tostring(icon)) or "none"))
        end
    else
        for i = 1, r.n do
            local b = r.buttons[i]
            say("entry " .. i .. ": " .. tostring(b and b.label) .. " icon=" .. tostring(b and b.icon and b.icon:GetTexture()))
        end
    end
    -- Show the ring so it can be looked at without holding a key.
    if not InCombatLockdown() then
        if r.frame:IsShown() then r.frame:Hide() else placeRing(r); r.frame:Show() end
    end
end

function UbermocUI_CursorToggle()
    if cursor.active then deactivate(); return end
    local ok, why = activate(true)
    if not ok then say("Interface cursor did not open: " .. tostring(why) .. ". Open a window first (bags, vendor, mail...).") end
end

SLASH_UBERMOCCURSOR1 = "/ubcursor"
function API.cursorReport()
    local nodes, roots = collect()
    say("cursor: on=" .. tostring(DB and DB.cursor.on) .. " auto=" .. tostring(DB and DB.cursor.auto) .. " gamepad=" .. tostring(gamepadOn())
        .. " windows=" .. tostring(roots) .. " buttons=" .. tostring(#nodes) .. " active=" .. tostring(cursor.active)
        .. " padCVar=" .. tostring(GetCVar and GetCVar("GamePadEnable")))
    local n = cursor.cur
    if n then
        local ok, line = pcall(function()
            local gs = n.GetScript
            return string.format("highlighted: %s (%s) OnClick=%s OnMouseDown=%s OnMouseUp=%s secure=%s",
                tostring(n.GetName and n:GetName() or "(unnamed)"), tostring(n.GetObjectType and n:GetObjectType()),
                tostring(gs and n:GetScript("OnClick") ~= nil), tostring(gs and n:GetScript("OnMouseDown") ~= nil),
                tostring(gs and n:GetScript("OnMouseUp") ~= nil), tostring(n.ubSecure == true))
        end)
        say(ok and line or "highlighted: (unreadable)")
    else
        say("highlighted: nothing")
    end
end

SlashCmdList["UBERMOCCURSOR"] = function()
    API.cursorReport()
    UbermocUI_CursorToggle()
end

local function cvarOn(name)
    local ok, v = pcall(GetCVarBool, name)
    return ok and v and true or false
end

----------------------------------------------------------------------
-- Pressing the interact key while a player is your target opens the menu you get from right-clicking
-- their unit frame (whisper, invite, inspect, trade, and so on). The key still does its usual job for
-- everything else, and the listener never swallows the key.
----------------------------------------------------------------------
-- While a player is your target, the interact key is pointed at a hidden button that opens the menu
-- (an override binding, the same way the game lets addons remap a key). Any other target, or none, and the
-- key goes back to interacting as usual. Bindings can't change in combat, so the switch waits for it to end.
local function buildTargetMenuKey()
    local owner = CreateFrame("Frame", "UbermocTargetMenuOwner", UIParent)
    -- A secure button: the game opens the unit menu itself ("togglemenu"), so its entries (Set Focus and the like) are not
    -- blocked. Opening the menu from ordinary addon code is what made the game refuse Set Focus.
    local btn = CreateFrame("Button", "UbermocTargetMenuBtn", UIParent, "SecureActionButtonTemplate")
    btn:SetAttribute("type", "togglemenu")
    btn:SetAttribute("unit", "target")
    btn:RegisterForClicks("AnyUp")
    btn:HookScript("PostClick", function()
        -- the menu is built a moment later: put the pointer on its first entry
        for _, t in ipairs({ 0.1, 0.35 }) do
            C_Timer.After(t, function() if API.cursorToMenu then pcall(API.cursorToMenu) end end)
        end
    end)
    local bound = false
    local function apply()
        if InCombatLockdown() then owner.pending = true; return end
        owner.pending = nil
        local want = false
        if UbermocUIDB and UbermocUIDB.targetMenuKey ~= false and UnitExists("target") then
            local okP, isP = pcall(UnitIsPlayer, "target")
            want = okP and isP == true   -- yourself included
            if not want then
                -- any hostile target (a dead one is left to the key, so it can still be looted)
                local okA, atk = pcall(UnitCanAttack, "player", "target")
                local okD, dead = pcall(UnitIsDead, "target")
                want = okA and atk == true and not (okD and dead == true)
            end
        end
        if bound then ClearOverrideBindings(owner); bound = false end
        if want then
            for _, k in ipairs({ GetBindingKey("INTERACTTARGET") }) do
                if k then SetOverrideBindingClick(owner, false, k, "UbermocTargetMenuBtn", "LeftButton"); bound = true end
            end
        end
    end
    owner:RegisterEvent("PLAYER_TARGET_CHANGED")
    owner:RegisterEvent("PLAYER_REGEN_ENABLED")
    owner:SetScript("OnEvent", function(_, e)
        if e == "PLAYER_REGEN_ENABLED" and not owner.pending then return end
        pcall(apply)
    end)
    API.targetMenuApply = function() pcall(apply) end
    apply()
end

local function buildInteractPage()
    local panel = CreateFrame("Frame")
    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 8, -8)
    scroll:SetPoint("BOTTOMRIGHT", -30, 44)
    local p = CreateFrame("Frame", nil, scroll)
    p:SetSize(580, 920)
    scroll:SetScrollChild(p)
    API.newLabel(p, "Interact", 16, -16, "GameFontNormalHuge")
    API.newLabel(p, "Interact key", 16, -50, "GameFontNormalLarge")
    local anyFlag = (Enum and Enum.SoftTargetEnableFlags and Enum.SoftTargetEnableFlags.Any) or 3
    local padFlag = (Enum and Enum.SoftTargetEnableFlags and Enum.SoftTargetEnableFlags.Gamepad) or 1
    local on = API.newCheck(p, "Enable the interact key (works with keyboard and mouse too)", 16, -80, function(v)
        pcall(SetCVar, "softTargetInteract", v and anyFlag or padFlag)
    end)
    API.newLabel(p, "Key or button", 40, -122)
    keyButton(p, 140, -118, "INTERACTTARGET", "interact")
    API.newLabel(p, "A (or a click) waits for a key or button; X (or a right-click) clears it.", 40, -148, "GameFontHighlightSmall")
    local icons = API.newCheck(p, "Show an icon over what you will interact with", 16, -176, function(v)
        pcall(SetCVar, "SoftTargetIconInteract", v and "1" or "0")
        pcall(SetCVar, "SoftTargetIconGameObject", v and "1" or "0")
    end)
    local tip = API.newCheck(p, "Show its tooltip", 16, -208, function(v) pcall(SetCVar, "SoftTargetTooltipInteract", v and "1" or "0") end)
    local plate = API.newCheck(p, "Show its nameplate", 16, -240, function(v) pcall(SetCVar, "SoftTargetNameplateInteract", v and "1" or "0") end)
    local snd = API.newCheck(p, "Play a sound when you press the interact key", 16, -272, function(v) pcall(SetCVar, "softTargettingInteractKeySound", v and "1" or "0") end)
    local bub = API.newCheck(p, "Show a white chat bubble over NPCs you can talk to", 16, -304, function(v) UbermocUIDB.chatBubble = v end)
    local tmk = API.newCheck(p, "Interact with a targeted player opens their right-click menu", 16, -336, function(v) UbermocUIDB.targetMenuKey = v; if API.targetMenuApply then API.targetMenuApply() end end)
    local n1 = API.newLabel(p, "Interact is part of WoW; this page puts its settings in one place. Enemies you can attack use WoW's own soft targeting (Gameplay > Targeting).", 16, -368, "GameFontHighlightSmall")
    n1:SetWidth(540); n1:SetJustifyH("LEFT"); n1:SetWordWrap(true)

    API.newLabel(p, "Interface cursor", 16, -392, "GameFontNormalLarge")
    local cOn = API.newCheck(p, "D-pad moves a pointer over buttons in open windows", 16, -424, function(v) DB.cursor.on = v; if not v then deactivate() end end)
    local cAuto = API.newCheck(p, "Open the cursor automatically at NPCs, vendors, mail and quests", 16, -456, function(v) DB.cursor.auto = v end)
    local cTips = API.newCheck(p, "Show tooltips for the button the pointer is on", 16, -488, function(v) DB.cursor.tips = v end)
    local cShoulder = API.newCheck(p, "Bumpers switch tabs, triggers scroll a page (while the pointer is up)", 16, -520, function(v)
        DB.cursor.shoulders = v
        if cursor.active and not InCombatLockdown() then setPadBindings(true); pcall(bindClickTarget, cursor.cur) end
    end)
    API.newLabel(p, "Click", 40, -564)
    keyButton(p, 260, -560, "UBERMOCUI_CURSORCLICK", "cursor click")
    API.newLabel(p, "Right-click", 40, -598)
    keyButton(p, 260, -594, "UBERMOCUI_CURSORRIGHT", "cursor right-click")
    API.newLabel(p, "Back (close)", 40, -632)
    keyButton(p, 260, -628, "UBERMOCUI_CURSORBACK", "cursor back")
    API.newLabel(p, "Item menu (use, sell, delete, disenchant)", 40, -666)
    keyButton(p, 260, -662, "UBERMOCUI_CURSORMENU", "the item menu")
    local n2 = API.newLabel(p, "The D-pad moves the pointer. A clicks, X right-clicks, B goes back, Y opens the item menu, bumpers switch tabs, triggers scroll. Press A on a box, then the key or button you want; X resets it.", 16, -704, "GameFontHighlightSmall")
    n2:SetWidth(540); n2:SetJustifyH("LEFT"); n2:SetWordWrap(true)
    local delCB = API.newCheck(p, "Fill in DELETE for me when deleting a good item with a controller", 16, -768, function(v) DB.autoDelete = v end)
    local stickCB = API.padOption and API.padOption("cursor", p, 16, -806, 540)
    panel:SetScript("OnShow", function()
        if stickCB then stickCB:refreshOption() end
        delCB:SetChecked(DB.autoDelete ~= false)
        local ok, v = pcall(GetCVar, "softTargetInteract")
        on:SetChecked(ok and tonumber(v) == anyFlag)
        icons:SetChecked(cvarOn("SoftTargetIconInteract"))
        tip:SetChecked(cvarOn("SoftTargetTooltipInteract"))
        plate:SetChecked(cvarOn("SoftTargetNameplateInteract"))
        snd:SetChecked(cvarOn("softTargettingInteractKeySound"))
        cOn:SetChecked(DB.cursor.on); cAuto:SetChecked(DB.cursor.auto); cTips:SetChecked(DB.cursor.tips == true); cShoulder:SetChecked(DB.cursor.shoulders ~= false)
        bub:SetChecked(UbermocUIDB.chatBubble == true)
        tmk:SetChecked(UbermocUIDB.targetMenuKey ~= false)
        API.evaluate()
    end)
    API.resetters.interact = function()
        DB.cursor = defaults().cursor
        for _, name in ipairs({ "softTargetInteract", "SoftTargetIconInteract", "SoftTargetIconGameObject" }) do
            local okd, dv = pcall(GetCVarDefault, name)
            if okd and dv then pcall(SetCVar, name, dv) end
        end
        pcall(deactivate)
    end
    API.makeTabs(panel, scroll, p, { { "Interact", 0 }, { "Interface cursor", -382 } })
    addPage(panel, "Interact")
end

----------------------------------------------------------------------
-- Start
----------------------------------------------------------------------
local prevLogin = API.onLogin   -- modules loaded before this one (Skin) chain in here too
API.onLogin = function()
    if prevLogin then
        local ok, err = pcall(prevLogin)
        if not ok and API.uiPrint then API.uiPrint("Login step failed: " .. tostring(err)) end
    end
    UbermocUIDB.extras = UbermocUIDB.extras or {}
    merge(UbermocUIDB.extras, defaults())
    DB = UbermocUIDB.extras
    -- One time: "Flip stick up / down" now starts off.
    if not DB.flipV2 then
        -- An old one-time step kept switching it back on for new setups; switch it off once more.
        DB.flipV1, DB.flipV2 = true, true
        if DB.petRing then DB.petRing.flipY = false end
        if DB.utilRing then DB.utilRing.flipY = false end
    end
    if not DB.stickV3 then
        DB.stickV3 = true
        if (DB.stickExtra or 0) == 0 then DB.stickExtra = 0.1 end
    end
    -- One time: the stick lock after using a ring entry now starts at 0.1 s instead of 2.5 s.
    if not DB.stickV4 then
        DB.stickV4 = true
        if DB.stickMax == nil or DB.stickMax == 2.5 then DB.stickMax = 0.1 end
    end
    if (DB.ringV or 1) < 2 then
        -- The first rings were too big: bring existing settings down once.
        for _, k in ipairs({ "petRing", "utilRing" }) do
            if DB[k] then DB[k].size = 34; DB[k].radius = 66 end
        end
        DB.ringV = 2
    end
    if (DB.ringV or 2) < 3 then
        DB.ringV = 3
    end
    -- One time: the corner menu wheel is the way to the menu buttons (no borders), and the menu bar steps aside.
    if not DB.cornerV1 then
        DB.cornerV1 = true
        if DB.cmicroRing then DB.cmicroRing.on = true; DB.cmicroRing.borders = false end
        if DB.cbagRing then DB.cbagRing.borders = false end
        UbermocUIDB.toolbar = type(UbermocUIDB.toolbar) == "table" and UbermocUIDB.toolbar or {}
        UbermocUIDB.toolbar.on = false
    end
    if not DB.tipsV1 then
        DB.tipsV1 = true
        if DB.cursor then DB.cursor.tips = true end
    end
    if not DB.bagV3 then
        DB.bagV3 = true
        if DB.cbagRing then DB.cbagRing.on = true end
    end
    stickCfg = function() return DB.stickMax or 0.1, DB.stickExtra or 0.1 end
    -- The rings and frames always exist so their keys work; the "enable" boxes only gate the key's effect.
    API.buildErrors = {}
    for _, step in ipairs({ { "cursor", buildCursor }, { "pet ring", buildPetRing }, { "utility ring", buildUtilRing }, { "menu ring", buildMenuRing }, { "corner wheels", buildCornerWheels },
                            { "target menu key", buildTargetMenuKey }, { "click mode", applyClickMode }, { "ring switches", applyRingSwitches },
                            { "rings page", buildRingsPage }, { "interact page", buildInteractPage } }) do
        local ok, err = pcall(step[2])
        if not ok then API.buildErrors[#API.buildErrors + 1] = step[1] .. ": " .. tostring(err) end
    end
    for _, rr in ipairs({ { petRing, "Pet ring wheel" }, { utilRing, "Utility ring wheel" }, { menuRing, "Menu ring wheel" } }) do
        local r = rr[1]
        if r then
            API.registerMover(rr[2], function()
                local c = DB[r.cfgKey]
                local d = 2 * (r.R or 125) + 8
                return true, c.x or 0, (c.pos == "CENTER") and 0 or ((c.y or 170) - UIParent:GetHeight() / 2), d, d
            end, function(x, y)
                local c = DB[r.cfgKey]
                c.pos = "BOTTOM"; c.x = x; c.y = y + UIParent:GetHeight() / 2
            end)
        end
    end
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("CVAR_UPDATE")
    ev:SetScript("OnEvent", function(_, _, name)
        if name == "ActionButtonUseKeyDown" then applyClickMode() end
    end)
    -- The interact key is on by default: switched on once, then left to the player.
    do
        local f = CreateFrame("Frame")
        f:RegisterEvent("PLAYER_LOGIN")
        f:SetScript("OnEvent", function()
            C_Timer.After(2, function()
                if not UbermocUIDB or InCombatLockdown() then return end
                if UbermocUIDB.interactOnV1 then return end
                UbermocUIDB.interactOnV1 = true
                local anyFlag = (Enum and Enum.SoftTargetEnableFlags and Enum.SoftTargetEnableFlags.Any) or 3
                pcall(SetCVar, "softTargetInteract", anyFlag)
            end)
        end)
    end
    -- Keep the pet and possess bars hidden when the game rebuilds them (new pet, entering the world).
    local pb = CreateFrame("Frame")
    for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "UNIT_PET", "UPDATE_POSSESS_BAR", "PET_BAR_UPDATE" }) do
        pcall(pb.RegisterEvent, pb, e)
    end
    pb:SetScript("OnEvent", function() pcall(applyPetBarHide) end)
    pcall(applyPetBarHide)
end


----------------------------------------------------------------------
-- Deleting a good item asks you to type DELETE. With a controller connected that word is filled in
-- for you, so the pointer can go straight to Okay.
----------------------------------------------------------------------
do
    local WHICH = { DELETE_GOOD_ITEM = true, DELETE_GOOD_QUEST_ITEM = true, DELETE_QUEST_ITEM = true }
    local function fill(which)
        if not WHICH[which] then return end
        local ok, pad = pcall(GetCVarBool, "GamePadEnable")
        if not (ok and pad) then return end
        if UbermocUIDB and UbermocUIDB.extras and UbermocUIDB.extras.autoDelete == false then return end
        local word = DELETE_ITEM_CONFIRM_STRING or "DELETE"
        for i = 1, 4 do
            local p = _G["StaticPopup" .. i]
            if p and p:IsShown() and p.which == which then
                local eb = (p.GetEditBox and p:GetEditBox()) or p.editBox or _G["StaticPopup" .. i .. "EditBox"]
                if eb and eb.SetText then
                    eb:SetText(word)
                    eb:ClearFocus()
                    local b1 = (p.GetButton1 and p:GetButton1()) or p.button1 or _G["StaticPopup" .. i .. "Button1"]
                    if b1 and b1.Enable then b1:Enable() end
                end
            end
        end
    end
    if StaticPopup_Show then
        hooksecurefunc("StaticPopup_Show", function(which)
            if C_Timer then C_Timer.After(0, function() pcall(fill, which) end) else pcall(fill, which) end
            -- Any question window takes the pointer at once, before anything else is pressed: opened if it was
            -- closed, moved onto the window's main button if it was already open elsewhere (tried again a little
            -- later for a window still sliding in, as when the camera is moving).
            if C_Timer then
                for _, t in ipairs({ 0.05, 0.4, 1.2 }) do
                    C_Timer.After(t, function()
                        if not (DB and DB.cursor and DB.cursor.on and DB.cursor.auto) then return end
                        if cursor.active then pcall(refreshNodes) else pcall(activate, false) end
                    end)
                end
            end
        end)
    end
end

-- The removed ground-spell option left a changed key setting behind: put it back once.
do
    local prev = API.onLogin
    API.onLogin = function(...)
        if prev then prev(...) end
        local db = UbermocUIDB
        if db and (db.groundKeyDownWas ~= nil or db.groundRelease ~= nil or db.groundSpells ~= nil or db.groundV2 ~= nil) then
            C_Timer.After(3, function()
                if InCombatLockdown() then return end
                if db.groundKeyDownWas ~= nil then pcall(SetCVar, "ActionButtonUseKeyDown", db.groundKeyDownWas) end
                db.groundKeyDownWas, db.groundRelease, db.groundSpells, db.groundV2 = nil, nil, nil, nil
            end)
        end
    end
end
