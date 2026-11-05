-- Ubermoc UI - Copyright (c) 2026 Marcos. All rights reserved.
-- This file is protected by copyright. It may not be copied, modified, redistributed or reused, in whole or
-- in part, without the written permission of the author. See LICENSE.txt.
----------------------------------------------------------------------
-- Ubermoc UI: class ability buttons
-- The game's stance bar (warrior stances, druid forms, rogue Stealth and so on) and Vanish for rogues, as small buttons
-- above the portrait of your floating player frame, in the game's own action button art. The row is centred on the
-- portrait and sits above the combo point number; one button is in the middle, two share the middle between them. The
-- stance bar's own place is left empty while this row is up. They are real spell buttons, so they work in combat; the
-- row only changes shape outside combat.
-- Setting: Unit Frames > Player > "Class ability buttons". "/ubclassbuttons off" also switches them off.
----------------------------------------------------------------------
local API = UbermocUIAPI
if not API then return end

local SIZE, GAP, SPACE = 30, 4, 4   -- the game's small action button is 30 px
-- Spells a class has besides its stance bar (Stealth is listed too: it is on the stance bar for rogues, and a spell
-- that turns up twice is shown once).
local EXTRAS = { ROGUE = { 1784, 1856 } }   -- Stealth, Vanish

local pool = {}
local shownList = {}      -- the spell ids the row is built for
local dirty = true
local lastPlaced = ""

local function isSecret(v) return issecretvalue and issecretvalue(v) end

local function enabled()
    local d = API.floatDB and API.floatDB()
    if d and d.classButtons == false then return false end
    return not (UbermocUIDB and UbermocUIDB.classButtonsOff)
end

-- Whether you have the spell, by every way the game offers (a spell the spellbook lists under another name, or one
-- changed by a talent, shows up in some of them and not others).
local function known(id)
    local checks = {
        function() return C_SpellBook and C_SpellBook.IsSpellKnown and C_SpellBook.IsSpellKnown(id) end,
        function() return C_SpellBook and C_SpellBook.IsSpellInSpellBook and C_SpellBook.IsSpellInSpellBook(id) end,
        function() return IsPlayerSpell and IsPlayerSpell(id) end,
        function() return IsSpellKnown and IsSpellKnown(id) end,
    }
    for _, fn in ipairs(checks) do
        local ok, r = pcall(fn)
        if ok and r then return true end
    end
    return false
end

-- The spells to show now, in order.
local function wantedList()
    local list, seen = {}, {}
    local function add(id)
        if type(id) == "number" and not isSecret(id) and not seen[id] then seen[id] = true; list[#list + 1] = id end
    end
    local okN, n = pcall(GetNumShapeshiftForms)
    if okN and type(n) == "number" then
        for i = 1, n do
            local okF, _, _, _, spellID = pcall(GetShapeshiftFormInfo, i)
            if okF then add(spellID) end
        end
    end
    local _, cls = UnitClass("player")
    for _, id in ipairs(EXTRAS[cls] or {}) do
        -- every rogue has Stealth from the first levels, whatever the spellbook checks say
        if known(id) or (cls == "ROGUE" and id == 1784 and (UnitLevel("player") or 0) >= 5) then add(id) end
    end
    return list
end

-- An atlas of the game's own action button art, when this game has it.
local function atlas(tex, name)
    if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name) then
        tex:SetAtlas(name)
        return true
    end
    return false
end

-- The game's own small action button look: its slot, rounded icon mask, frame, mouse-over and checked glow.
local function button(i)
    local b = pool[i]
    if b then return b end
    b = CreateFrame("CheckButton", "UbermocClassButton" .. i, UIParent, "SecureActionButtonTemplate")
    b:SetSize(SIZE, SIZE)
    b:RegisterForClicks("AnyUp")
    b:SetAttribute("useOnKeyDown", false)
    b:SetAttribute("type", "spell")
    b:SetFrameStrata("MEDIUM")
    b.slotBg = b:CreateTexture(nil, "BACKGROUND")
    b.slotBg:SetAllPoints()
    if not atlas(b.slotBg, "UI-HUD-ActionBar-IconFrame-Background") then b.slotBg:SetColorTexture(0, 0, 0, 0.6) end
    b.icon = b:CreateTexture(nil, "BACKGROUND", nil, 1)
    b.icon:SetAllPoints()
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    if b.CreateMaskTexture then
        b.mask = b:CreateMaskTexture()
        b.mask:SetPoint("CENTER", b.icon, "CENTER")
        b.mask:SetSize(SIZE, SIZE)
        if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("UI-HUD-ActionBar-IconFrame-Mask") then
            b.mask:SetAtlas("UI-HUD-ActionBar-IconFrame-Mask")
            b.icon:AddMaskTexture(b.mask)
        end
    end
    b.slotArt = b:CreateTexture(nil, "BACKGROUND", nil, 2)
    b.slotArt:SetAllPoints()
    if not atlas(b.slotArt, "ui-hud-actionbar-iconframe-slot") then b.slotArt:Hide() end
    b:SetNormalTexture("")
    local nt = b:GetNormalTexture()
    if nt then
        nt:SetAllPoints()
        if not atlas(nt, "UI-HUD-ActionBar-IconFrame") then nt:SetTexture("Interface\\Buttons\\UI-Quickslot2") end
    end
    b:SetPushedTexture("")
    local pt = b:GetPushedTexture()
    if pt then pt:SetAllPoints(); atlas(pt, "UI-HUD-ActionBar-IconFrame-Down") end
    b:SetHighlightTexture("")
    local ht = b:GetHighlightTexture()
    if ht then ht:SetAllPoints(); atlas(ht, "UI-HUD-ActionBar-IconFrame-Mouseover") end
    b:SetCheckedTexture("")
    local ct = b:GetCheckedTexture()
    if ct then ct:SetAllPoints(); atlas(ct, "UI-HUD-ActionBar-IconFrame-Mouseover") end
    b.cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
    b.cd:SetPoint("TOPLEFT", b.icon, "TOPLEFT", 3, -3)
    b.cd:SetPoint("BOTTOMRIGHT", b.icon, "BOTTOMRIGHT", -3, 3)
    b.cd:SetDrawEdge(false)
    b.cd:SetDrawBling(false)
    pcall(b.cd.SetSwipeColor, b.cd, 0, 0, 0, 0.64)
    b:SetScript("OnEnter", function(self)
        if not self.spellID then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        pcall(GameTooltip.SetSpellByID, GameTooltip, self.spellID)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:Hide()
    pool[i] = b
    return b
end

local function active(id)
    local okN, n = pcall(GetNumShapeshiftForms)
    if okN and type(n) == "number" then
        for i = 1, n do
            local okF, _, isActive, _, spellID = pcall(GetShapeshiftFormInfo, i)
            if okF and spellID == id then return isActive and true or false end
        end
    end
    if id == 1784 and IsStealthed then
        local ok, r = pcall(IsStealthed)
        return ok and r == true
    end
    return false
end

-- Icons, checked state and recharge of the buttons already in place (safe in combat).
local function paint()
    for i, id in ipairs(shownList) do
        local b = pool[i]
        if b and b.spellID == id then
            local okT, tex = pcall(C_Spell.GetSpellTexture, id)
            if okT and tex then b.icon:SetTexture(tex) end
            b:SetChecked(active(id))
            local done = false
            if C_Spell.GetSpellCooldownDuration and b.cd.SetCooldownFromDurationObject then
                local okD, dur = pcall(C_Spell.GetSpellCooldownDuration, id)
                if okD and dur and pcall(b.cd.SetCooldownFromDurationObject, b.cd, dur) then done = true end
            end
            if not done then
                local okC, info = pcall(C_Spell.GetSpellCooldown, id)
                if okC and type(info) == "table" and not isSecret(info.duration) and info.duration and info.duration > 1.6 then
                    pcall(b.cd.SetCooldown, b.cd, info.startTime, info.duration)
                else
                    pcall(b.cd.Clear, b.cd)
                end
            end
        end
    end
end

-- The game's own stance bar is left empty while this row shows the same buttons (the addon's usual way of keeping a
-- game bar out of sight: only its look is touched).
-- The game's own stance bar is left empty while this row shows the same buttons. Only its opacity is held at zero (the
-- addon's usual way of keeping a game bar out of sight): nothing else of the bar, its buttons or its place is touched,
-- since the game's action bar layout reads them and refuses what the addon has changed.
local function stanceBar(hide)
    local f = _G.StanceBar
    if f and API.holdHidden then pcall(API.holdHidden, f, hide) end
end

-- How far above the top of the portrait the row sits: clear of the combo point number, which hangs half off the top.
local function liftAbovePortrait()
    local lift = SPACE
    local cd = API.comboDB and API.comboDB()
    local h = cd and cd.halo
    if h and h.on and h.mode ~= "dots" then lift = lift + (h.nsize or 18) / 2 + math.max(0, h.ny or 0) end
    return lift
end

-- Builds the row and centres it over the portrait. Outside combat only (the buttons are protected).
local function layout()
    if InCombatLockdown() then dirty = true; return end
    local pf = API.floatFrame and API.floatFrame("player")
    local list = (enabled() and pf and pf:IsShown()) and wantedList() or {}
    local ring = pf and pf.ring
    local anchor, point = pf, "TOP"
    if ring and ring.IsShown and ring:IsShown() then anchor = ring end
    local lift = liftAbovePortrait()
    local scale = (pf and pf.GetEffectiveScale and pf:GetEffectiveScale() or 1) / (UIParent:GetEffectiveScale() or 1)
    if scale <= 0 then scale = 1 end
    local sig = tostring(lift) .. ":" .. tostring(anchor) .. ":" .. tostring(scale)
    local same = #list == #shownList and lastPlaced == sig
    if same then for i, id in ipairs(list) do if shownList[i] ~= id then same = false; break end end end
    if same and not dirty then return end
    dirty, lastPlaced = false, sig
    shownList = list
    local n = #list
    local width = n * SIZE + math.max(0, n - 1) * GAP
    for i = 1, math.max(n, #pool) do
        local b = pool[i]
        if i <= n then
            b = button(i)
            local id = list[i]
            b.spellID = id
            local okN, name = pcall(C_Spell.GetSpellName, id)
            b:SetAttribute("spell", okN and name or nil)
            -- Anchored to the unit frame, but not its child: a protected button inside a frame makes that frame protected
            -- too, and the game then blocks the addon from showing or hiding it in combat.
            b:SetScale(scale)
            b:ClearAllPoints()
            -- the middle of the row is the middle of the portrait: one button sits there, two share it between them
            b:SetPoint("CENTER", anchor, point, -width / 2 + (i - 1) * (SIZE + GAP) + SIZE / 2, lift / scale + SIZE / 2)
            b:Show()
        elseif b then
            b:Hide()
            b.spellID = nil
        end
    end
    stanceBar(n > 0)
    paint()
end

-- The row fades and hides with the frame it stands over (opacity can change in combat; showing and hiding cannot).
local function follow()
    local pf = API.floatFrame and API.floatFrame("player")
    local a = 1
    if not (pf and pf.IsShown and pf:IsShown()) then a = 0
    elseif pf.GetEffectiveAlpha then a = pf:GetEffectiveAlpha() end
    for _, b in ipairs(pool) do b:SetAlpha(a) end
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "SPELLS_CHANGED", "UPDATE_SHAPESHIFT_FORMS", "PLAYER_REGEN_ENABLED",
                     "ACTIVE_TALENT_GROUP_CHANGED" }) do
    pcall(ev.RegisterEvent, ev, e)
end
for _, e in ipairs({ "UPDATE_SHAPESHIFT_FORM", "SPELL_UPDATE_COOLDOWN", "UPDATE_STEALTH" }) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript("OnEvent", function(_, e)
    if e == "SPELL_UPDATE_COOLDOWN" or e == "UPDATE_SHAPESHIFT_FORM" or e == "UPDATE_STEALTH" then
        pcall(paint)
    else
        dirty = true
        pcall(layout)
    end
end)
local acc = 0
ev:SetScript("OnUpdate", function(_, dt)
    acc = acc + dt
    if acc < 0.25 then return end
    acc = 0
    pcall(layout)
    pcall(follow)
end)

SLASH_UBERMOCCLASSBUTTONS1 = "/ubclassbuttons"
SlashCmdList["UBERMOCCLASSBUTTONS"] = function(msg)
    msg = (msg or ""):lower():match("^%s*(%S*)")
    if msg == "on" or msg == "off" then
        UbermocUIDB.classButtonsOff = (msg == "off") or nil
        dirty = true
        pcall(layout)
        print("Ubermoc UI: the class ability buttons are " .. msg .. ".")
    else
        print("Ubermoc UI: /ubclassbuttons on | off (stances, forms, Stealth and Vanish above your player portrait).")
    end
end

-- /ubwho [seconds]: names the frames under the pointer after a short wait, with their parents (to tell which of the
-- game's bars an icon belongs to).
SLASH_UBERMOCWHO1 = "/ubwho"
SlashCmdList["UBERMOCWHO"] = function(msg)
    local wait = tonumber((msg or ""):match("%d+")) or 5
    print("Ubermoc UI: point at the icon now, reading in " .. wait .. " seconds.")
    C_Timer.After(wait, function()
        local foci = GetMouseFoci and GetMouseFoci() or {}
        if #foci == 0 then print("Ubermoc UI: nothing under the pointer."); return end
        for _, fr in ipairs(foci) do
            local chain, f = {}, fr
            for _ = 1, 6 do
                if not f then break end
                local ok, name = pcall(function() return f.GetName and f:GetName() end)
                chain[#chain + 1] = (ok and name) or (f.GetObjectType and f:GetObjectType()) or "?"
                f = f.GetParent and f:GetParent() or nil
            end
            print("Ubermoc UI: " .. table.concat(chain, " < "))
        end
    end)
end
