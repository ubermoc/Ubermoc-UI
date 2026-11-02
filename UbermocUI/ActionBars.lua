-- Ubermoc UI - Copyright (c) 2026 Marcos. All rights reserved.
-- This file is protected by copyright. It may not be copied, modified, redistributed or reused, in whole or
-- in part, without the written permission of the author. See LICENSE.txt.
----------------------------------------------------------------------
-- Ubermoc UI: action bars
-- The game's own action buttons, laid out by controller layer: one row (or arc) for the plain press and
-- one for each combination of held modifier buttons. Three designs (plain, blade, arc), and the layers
-- can all show at once or only the one being held. The buttons stay the game's own, so cooldowns,
-- tooltips, dragging spells and clicking all work as before; only where they sit changes.
----------------------------------------------------------------------
local API = UbermocUIAPI
if not API then return end

local MEDIA = "Interface\\AddOns\\UbermocUI\\Media\\"

-- Borders set on the Textures page (Action Bars tab).
API.registerBorder({ key = "abPlates", part = "abar", label = "Blade edge line", size = 1, maxSize = 6, a = 95,
    auto = "Layer colours",
    legacy = function() local d = UbermocUIDB.abar or {}; return d.edge ~= false and d.borders ~= false, 1, 95, "auto" end,
    apply = function() if API.abarLayout then API.abarLayout() end end })
API.registerBorder({ key = "abButtons", part = "abar", label = "Button borders", size = 1, maxSize = 6, a = 95,
    auto = "Layer colours",
    legacy = function() local d = UbermocUIDB.abar or {}; return d.borders == true, 1, 95, "auto" end,
    apply = function() if API.abarLayout then API.abarLayout() end end })

local function defaults()
    return { on = true, hideGame = true, design = "plain", mode = "held", borders = false, pips = true, emptyIcon = false, hideEmpty = false, size = 40, gap = 4, scale = 100,
             x = 0, y = 24, dim = 40, bgA = 90, tex = "brushed", texA = 50, edge = true, labels = true, noBorder = true, showMods = true, showTarget = true, showUI = true, showMove = true,
             convertBinds = true, fillEmpty = true, cdOn = true, cdScale = 100, cdPos = "CENTER", cdX = 0, cdY = 0 }
end
local filled   -- the settings table whose defaults are already filled in (DB() runs many times a second)
local function DB()
    UbermocUIDB = UbermocUIDB or {}
    local d = UbermocUIDB.abar
    if type(d) ~= "table" then d = {}; UbermocUIDB.abar = d end
    if d == filled then return d end   -- defaults already filled in for this table
    for k, v in pairs(defaults()) do if d[k] == nil then d[k] = v end end
    if not d.v85 then d.v85 = true; d.borders = false end
    if not d.v78 then d.v78 = true; d.emptyIcon = false end
    if not d.v71 then
        d.v71 = true
        d.on = true; d.design = "plain"; d.mode = "held"
    end
    filled = d
    return d
end


-- One colour per layer, so a row is recognised at a glance: none, then each modifier combination.
local COLORS = { { 0.62, 0.68, 0.82 }, { 0.35, 0.6, 1 }, { 1, 0.6, 0.24 }, { 0.75, 0.44, 0.95 },
                 { 0.3, 0.8, 0.5 }, { 0.95, 0.45, 0.6 }, { 0.3, 0.8, 0.8 }, { 0.9, 0.85, 0.3 } }

-- Pad buttons that can carry an action, in the order they are laid out in a row.
local PADKEYS = { "PAD3", "PAD1", "PAD2", "PAD4", "PADDUP", "PADDRIGHT", "PADDDOWN", "PADDLEFT",
                  "PADRTRIGGER", "PADLTRIGGER", "PADRSHOULDER", "PADLSHOULDER", "PADRSTICK", "PADLSTICK",
                  "PADPADDLE1", "PADPADDLE2", "PADPADDLE3", "PADPADDLE4" }

local MULTI = { "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight", "MultiBarLeft", "MultiBar5", "MultiBar6", "MultiBar7" }
local function buttonFor(cmd)
    if type(cmd) ~= "string" then return nil end
    local n = cmd:match("^ACTIONBUTTON(%d+)$")
    if n then return _G["ActionButton" .. n], _G.MainActionBar or _G.MainMenuBar end
    local b, k = cmd:match("^MULTIACTIONBAR(%d+)BUTTON(%d+)$")
    b = tonumber(b)
    if b and MULTI[b] then return _G[MULTI[b] .. "Button" .. k], _G[MULTI[b]] end
    return nil
end

-- Binds that open a window or run part of the interface (map, bags, menus, the interface cursor) are not
-- shown on the bar; everything else a pad button does gets a slot.
-- Kinds of bind that can be left off the bar (Action Bars > Buttons shown).
local function isMove(cmd)
    return cmd:find("MOVE") or cmd:find("STRAFE") or cmd:find("TURN") or cmd:find("PITCH") or cmd:find("CAMERA")
        or cmd:find("ZOOM") or cmd:find("AUTORUN") or cmd:find("FOLLOW") or cmd:find("TOGGLERUN") or cmd:find("STEER")
        or cmd:find("^GAMEPAD") or cmd:find("LOOK") or cmd:find("JUMP") or cmd:find("SITORSTAND") or cmd:find("DISMOUNT") or cmd:find("SWIM") or cmd:find("ASCEND") or cmd:find("DESCEND")
end
local function isUI(cmd)
    return cmd:find("^TOGGLE") or cmd:find("^OPEN") or cmd:find("BAG") or cmd:find("^UBERMOCUI_")
        or cmd:find("^SCREENSHOT") or cmd:find("^MINIMAP") or cmd:find("^CLICK UbermocMenu") or cmd:find("^CLICK UbermocCursor")
end
local function isTarget(cmd)
    return cmd:find("TARGET") or cmd:find("^ASSIST") or cmd:find("FOCUS")
end

-- Icon for a bind that is not an action button: the spell, item or macro it uses, a ring, or a picture
-- that fits what it does. The bind's name is written on the slot as well.
local function iconFor(cmd)
    local kind, what = cmd:match("^(%u+) (.+)$")
    if kind == "SPELL" and what then
        local ok, t = pcall(function() return (C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(what)) or (GetSpellTexture and GetSpellTexture(what)) end)
        if ok and t then return t end
    elseif kind == "ITEM" and what then
        local ok, t = pcall(function() return (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(what)) or (GetItemIcon and GetItemIcon(what)) end)
        if ok and t then return t end
    elseif kind == "MACRO" and what then
        local ok, _, t = pcall(GetMacroInfo, what)
        if ok and t then return t end
    elseif kind == "CLICK" and what then
        if what:find("^UbermocRingPet") then return "Interface\\Icons\\Ability_Hunter_BeastCall" end
        if what:find("^UbermocRingUtil") then return "Interface\\Icons\\INV_Misc_Bag_08" end
        if what:find("^UbermocRingMenu") then return "Interface\\Icons\\INV_Misc_Gear_01" end
        local f = _G[(what:match("^([^:]+)"))]
        local ic = f and (f.icon or f.Icon)
        local ok, t = pcall(function() return ic and ic.GetTexture and ic:GetTexture() end)
        if ok and t then return t end
    end
    if cmd:find("TARGET") then return "Interface\\Icons\\Ability_Hunter_SniperShot" end
    if cmd:find("INTERACT") then return "Interface\\Icons\\INV_Misc_Note_01" end
    if cmd:find("JUMP") or cmd:find("AUTORUN") or cmd:find("SIT") then return "Interface\\Icons\\Ability_Rogue_Sprint" end
    if cmd:find("ASSIST") or cmd:find("FOCUS") then return "Interface\\Icons\\Ability_Hunter_MarkedForDeath" end
    if cmd:find("PET") then return "Interface\\Icons\\Ability_Hunter_BeastCall" end
    return "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function bindName(cmd)
    local n = _G["BINDING_NAME_" .. cmd] or (GetBindingName and GetBindingName(cmd)) or cmd
    if type(n) ~= "string" or n == "" then n = cmd end
    local kind, what = cmd:match("^(%u+) (.+)$")
    if (kind == "SPELL" or kind == "ITEM" or kind == "MACRO") and what then n = what end
    if kind == "CLICK" and what and what:find("^UbermocRing") then n = what:find("Pet") and "Pet ring" or (what:find("CMicro") and "Menu wheel (corner)" or (what:find("CBag") and "Bags wheel (corner)" or (what:find("Menu") and "Menu ring" or "Utility ring"))) end
    return n
end

-- A slot for a bind that is not an action button (picture and name), an unbound pad button (empty, ready
-- to take a spell) or a modifier paddle. With a mouse, a bind can be dragged to another slot (the two pad
-- buttons swap binds), and a spell, item or macro dropped on an empty slot gets a free action button.
local virt = {}
local ensureRoot
local layersNow = {}           -- the model last laid out
local startDrag, endDrag, receiveDrop
local function virtualFor(id, cmd, key, prefix)
    local f = virt[id]
    if not f then
        f = CreateFrame("Frame", nil, ensureRoot())
        f.ubermocVirtual = true
        f.icon = f:CreateTexture(nil, "ARTWORK")
        f.icon:SetAllPoints()
        f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        f.name = f:CreateFontString(nil, "OVERLAY")
        f.name:SetFont(STANDARD_TEXT_FONT, 8, "OUTLINE")
        f.name:SetPoint("BOTTOMLEFT", 1, 1)
        f.name:SetPoint("BOTTOMRIGHT", -1, 1)
        f.name:SetJustifyH("CENTER")
        f.name:SetWordWrap(true)
        f.name:SetMaxLines(2)
        f.cd = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
        f.cd:SetAllPoints()
        f.cd:SetDrawSwipe(false); f.cd:SetDrawEdge(false); f.cd:SetDrawBling(false)
        f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            local c = self.cmd or ""
            if c == "" then
                GameTooltip:Hide()
                return
            elseif c:find("^MOD:") then
                GameTooltip:SetText(c:sub(5), 1, 1, 1)
                GameTooltip:AddLine("Modifier button: hold it to change the bar.", 0.8, 0.8, 0.8, true)
            else
                -- a spell or item bound straight to the button shows its own game tooltip
                local shown = false
                local kind, what = c:match("^(%u+) (.+)$")
                if kind == "SPELL" and what then
                    local okI, info = pcall(function() return C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(what) end)
                    local sid = okI and type(info) == "table" and info.spellID
                    if sid then shown = pcall(GameTooltip.SetSpellByID, GameTooltip, sid) end
                elseif kind == "ITEM" and what then
                    local okI, id = pcall(function() return C_Item and C_Item.GetItemInfoInstant and (C_Item.GetItemInfoInstant(what)) end)
                    if okI and id then shown = pcall(GameTooltip.SetItemByID, GameTooltip, id) end
                end
                if not shown then GameTooltip:SetText(bindName(c), 1, 1, 1) end
                local k = (self.prefix or "") .. (self.key or "")
                if k ~= "" then GameTooltip:AddLine(k, 0.6, 0.8, 1) end
            end
            GameTooltip:Show()
        end)
        f:SetScript("OnLeave", function() GameTooltip:Hide() end)
        f:SetScript("OnDragStart", function(self) startDrag(self) end)
        f:SetScript("OnDragStop", function(self) endDrag(self) end)
        f:SetScript("OnReceiveDrag", function(self) receiveDrop(self) end)
        f:SetScript("OnMouseUp", function(self) if GetCursorInfo and GetCursorInfo() then receiveDrop(self) end end)
        virt[id] = f
    end
    f.key, f.prefix = key, prefix
    if f.cmd ~= cmd then
        f.cmd = cmd
        f.ubermocEmpty = (cmd == "")
        f.ubermocMod = cmd:find("^MOD:") and true or false
        if f.ubermocEmpty then
            f.icon:SetTexture(nil); f.name:SetText("")
        elseif f.ubermocMod then
            f.icon:SetTexture(nil)
            f.name:ClearAllPoints(); f.name:SetPoint("CENTER")
            f.name:SetText(cmd:sub(5))
        else
            f.name:ClearAllPoints()
            f.name:SetPoint("BOTTOMLEFT", 1, 1); f.name:SetPoint("BOTTOMRIGHT", -1, 1)
            f.icon:SetTexture(iconFor(cmd))
            f.name:SetText(bindName(cmd))
        end
        f.spellID, f.itemID = nil, nil
        if API.virtualCooldown then pcall(API.virtualCooldown, f) end
    end
    return f
end
-- The recharge of a spell or item bound straight to a pad button, shown as a number on its slot.
API.virtualCooldown = function(f)
    local cmd = f.cmd or ""
    local kind, what = cmd:match("^(%u+) (.+)$")
    local cd = f.cd
    if not cd then return end
    if kind == "SPELL" and what then
        if not f.spellID then
            local okI, info = pcall(function() return C_Spell.GetSpellInfo(what) end)
            f.spellID = okI and type(info) == "table" and info.spellID or false
        end
        if f.spellID and C_Spell.GetSpellCooldownDuration and cd.SetCooldownFromDurationObject then
            local ok, dur = pcall(C_Spell.GetSpellCooldownDuration, f.spellID)
            if ok and dur and pcall(cd.SetCooldownFromDurationObject, cd, dur) then
                if API.abarCooldownStyle then pcall(API.abarCooldownStyle, f, cd) end
                return
            end
        end
    elseif kind == "ITEM" and what then
        if not f.itemID then
            local okI, id = pcall(function() return (C_Item.GetItemInfoInstant(what)) end)
            f.itemID = okI and id or false
        end
        if f.itemID then
            local ok, st, du = pcall(C_Item.GetItemCooldown, f.itemID)
            if ok and st and du and du > 0 then
                pcall(cd.SetCooldown, cd, st, du)
                if API.abarCooldownStyle then pcall(API.abarCooldownStyle, f, cd) end
                return
            end
        end
    end
    pcall(cd.Clear, cd)
end
do
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "SPELL_UPDATE_COOLDOWN", "BAG_UPDATE_COOLDOWN", "PLAYER_ENTERING_WORLD" }) do pcall(ev.RegisterEvent, ev, e) end
    ev:SetScript("OnEvent", function()
        for _, f in pairs(virt) do pcall(API.virtualCooldown, f) end
    end)
end

-- A Steam Controller's back buttons reach the game as keys (F6, Space), so they get no action button of their own.
local function steamPaddle(k) return k:find("^PADPADDLE") ~= nil and API.padSet ~= nil and API.padSet() == "steam" end

local function saveBinds()
    if SaveBindings and GetCurrentBindingSet then pcall(SaveBindings, GetCurrentBindingSet()) end
    if API.refreshController then pcall(API.refreshController) end
end

-- The slot (and its layer) under the mouse.
local function slotUnderMouse(skip)
    for _, L in ipairs(layersNow) do
        for _, sl in ipairs(L.slots) do
            local b = sl.btn
            if b ~= skip and b:IsVisible() and b:GetAlpha() > 0 and b:IsMouseOver() then return sl, L end
        end
    end
end

local ghost
startDrag = function(src)
    if InCombatLockdown() or src.ubermocEmpty or src.ubermocMod then return end
    if not ghost then
        ghost = CreateFrame("Frame", nil, UIParent)
        ghost:SetFrameStrata("TOOLTIP")
        ghost:SetSize(32, 32)
        ghost.t = ghost:CreateTexture(nil, "ARTWORK")
        ghost.t:SetAllPoints()
        ghost.t:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        ghost:SetScript("OnUpdate", function(self)
            local x, y = GetCursorPosition()
            local sc = UIParent:GetEffectiveScale()
            self:ClearAllPoints()
            self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / sc, y / sc)
        end)
    end
    ghost.t:SetTexture(src.icon:GetTexture())
    ghost.src = src
    ghost:Show()
    src:SetAlpha(0.4)
end

endDrag = function(src)
    if not ghost or ghost.src ~= src then return end
    ghost:Hide(); ghost.src = nil
    src:SetAlpha(1)
    if InCombatLockdown() then return end
    local sl, L = slotUnderMouse(src)
    if not sl or (sl.btn.ubermocMod) then return end
    local a, b = src.prefix .. src.key, L.prefix .. sl.key
    if a == b then return end
    local ca, cb = GetBindingAction(a) or "", GetBindingAction(b) or ""
    if cb ~= "" then SetBinding(a, cb) else SetBinding(a) end
    if ca ~= "" then SetBinding(b, ca) else SetBinding(b) end
    saveBinds()
end

-- A spell, item or macro dropped on an empty slot: put it on a free action button and bind that slot's
-- pad button to it.
local FREE = {}
for i = 1, 12 do FREE[#FREE + 1] = "ACTIONBUTTON" .. i end
for b = 1, 7 do for i = 1, 12 do FREE[#FREE + 1] = "MULTIACTIONBAR" .. b .. "BUTTON" .. i end end
local function dropMsg(t)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffUbermoc UI:|r " .. t) end
end
receiveDrop = function(dst)
    if not (GetCursorInfo and GetCursorInfo()) or dst.ubermocMod then return end
    if InCombatLockdown() then dropMsg("Can't change binds in combat."); return end
    -- First pass takes a free button on a bar that is showing; the second takes one on any bar.
    for pass = 1, 1 do
        for _, cmd in ipairs(FREE) do
            local btn, bar = buttonFor(cmd)
            if btn and bar and bar:IsShown() then
                local act = btn.action
                if not act and btn.GetAttribute then act = btn:GetAttribute("action") end
                local padBound = false
                for _, k in ipairs({ GetBindingKey(cmd) }) do if type(k) == "string" and k:find("PAD") then padBound = true end end
                if type(act) == "number" and not padBound and not HasAction(act) then
                    local ok = pcall(PlaceAction, act)
                    if ok then
                        if ClearCursor then ClearCursor() end
                        SetBinding(dst.prefix .. dst.key, cmd)
                        saveBinds()
                    end
                    return
                end
            end
        end
    end
    dropMsg("No free action button left on a bar that is switched on. Clear one, or switch on another action bar in the game's Edit Mode.")
end

-- A spell, item or macro bound straight to a pad button is moved onto a free action button (the real
-- thing: border on hover, click with the mouse, the game's own cooldown and tooltip) and the pad button is
-- bound to that action button instead. Done once per bind, out of combat; a bind that cannot be moved stays as it was.
local convertFailed = {}
local converting = false
-- Only buttons on bars the game has switched on: a button on a bar switched off in Edit Mode is never drawn
-- (it still casts from its bind, which is why such a slot looked empty but worked).
local function barOn(bar) return bar and bar.IsShown and bar:IsShown() and true or false end
-- Action bars 2 to 8 (the main bar is left alone: its buttons change with forms and stances).
local POOL = {}
for b = 1, 7 do for i = 1, 12 do POOL[#POOL + 1] = "MULTIACTIONBAR" .. b .. "BUTTON" .. i end end
local function freeActionCmd()
    -- first a button with no key at all, then one only a keyboard key uses
    for pass = 1, 2 do
        for _, cmd in ipairs(POOL) do
            local btn, bar = buttonFor(cmd)
            if btn and barOn(bar) then
                local act = btn.action
                if not act and btn.GetAttribute then act = btn:GetAttribute("action") end
                local keys = { GetBindingKey(cmd) }
                local padBound = false
                for _, k in ipairs(keys) do if type(k) == "string" and k:find("PAD") then padBound = true end end
                if type(act) == "number" and not padBound and not HasAction(act) and (pass == 2 or #keys == 0) then return cmd, act end
            end
        end
    end
end
-- A pad key listed under two action buttons (one of them stale) shows one in the game's key bindings
-- and acts as the other. Keep only the one the game actually uses.
local function repairDupes()
    local fixed = false
    local list = {}
    for i = 1, 12 do list[#list + 1] = "ACTIONBUTTON" .. i end
    for _, c in ipairs(POOL) do list[#list + 1] = c end
    for _, cmd in ipairs(list) do
        for _, k in ipairs({ GetBindingKey(cmd) }) do
            if type(k) == "string" and k:find("PAD") then
                local want = GetBindingAction(k) or ""
                if want ~= cmd then
                    SetBinding(k)
                    if want ~= "" then SetBinding(k, want) end
                    fixed = true
                end
            end
        end
    end
    return fixed
end
local function convertAll()
    if converting or InCombatLockdown() or DB().convertBinds == false then return false end
    if not (GetBindingAction and PlaceAction and HasAction) then return false end
    converting = true
    local did = false
    pcall(function() if repairDupes() then did = true end end)
    pcall(function()
        local prefixes, mods = { "" }, {}
        if API.padLayers then
            local layers, m = API.padLayers()
            mods = m or {}
            prefixes = {}
            for _, L in ipairs(layers) do prefixes[#prefixes + 1] = L.prefix end
        end
        for _, k in ipairs(PADKEYS) do
            for _, prefix in ipairs((mods[k] or steamPaddle(k)) and {} or prefixes) do
                local full = prefix .. k
                local cmd = GetBindingAction(full) or ""
                -- an unused pad button gets an action button of its own, ready for a spell
                if cmd == "" and DB().fillEmpty ~= false and not convertFailed[full] then
                    local free = freeActionCmd()
                    if free then SetBinding(full, free); did = true; cmd = free
                    else convertFailed[full] = true end
                end
                local kind, what = cmd:match("^(%u+) (.+)$")
                if (kind == "SPELL" or kind == "ITEM" or kind == "MACRO") and what and not convertFailed[full .. cmd] then
                    local free, act = freeActionCmd()
                    if not free then
                        convertFailed[full .. cmd] = true
                        if not API.abarNoRoomSaid then
                            API.abarNoRoomSaid = true
                            dropMsg("No free action button on a bar that is switched on, so some pad binds stay as they are. Clear a button, or switch on another action bar in the game's Edit Mode.")
                        end
                    else
                        local picked = false
                        if kind == "SPELL" then
                            local okI, info = pcall(C_Spell.GetSpellInfo, what)
                            local sid = okI and type(info) == "table" and info.spellID
                            if sid then picked = pcall(C_Spell.PickupSpell, sid) end
                        elseif kind == "ITEM" then
                            picked = pcall(C_Item.PickupItem, what)
                        else
                            picked = pcall(PickupMacro, what)
                        end
                        local placed = picked and GetCursorInfo and GetCursorInfo() and pcall(PlaceAction, act)
                        if GetCursorInfo and GetCursorInfo() and ClearCursor then ClearCursor() end
                        if placed and HasAction(act) then
                            SetBinding(full, free)
                            did = true
                        else
                            convertFailed[full .. cmd] = true
                        end
                    end
                end
            end
        end
    end)
    converting = false
    if did then saveBinds() end
    return did
end

----------------------------------------------------------------------
-- What goes where: for every layer, the buttons its pad buttons are bound to. Only worked out again
-- when binds or the modifier setup change (events), never on a timer.
----------------------------------------------------------------------
local function model()
    if not API.padLayers then return {} end
    local layers, mods = API.padLayers()
    local d = DB()
    local out, used = {}, {}
    for _, L in ipairs(layers) do
        local slots = {}
        for _, k in ipairs(PADKEYS) do
            if mods[k] then
                if d.showMods ~= false then
                    local word = type(mods[k]) == "string" and mods[k] or "Modifier"
                    slots[#slots + 1] = { key = k, btn = virtualFor(L.prefix .. k, "MOD:" .. word, k, L.prefix), virtual = true }
                end
            else
                local cmd = GetBindingAction(L.prefix .. k) or ""
                local btn, bar = buttonFor(cmd)
                if cmd == "" and steamPaddle(k) then
                    -- nothing to show: Steam sends this button as a key
                elseif btn and not used[btn] then
                    used[btn] = true
                    slots[#slots + 1] = { key = k, btn = btn, bar = bar }
                else
                    local skip = cmd ~= "" and ((d.showMove == false and isMove(cmd)) or (d.showUI == false and isUI(cmd))
                        or (d.showTarget == false and isTarget(cmd)))
                    if not skip then
                        slots[#slots + 1] = { key = k, btn = virtualFor(L.prefix .. k, cmd, k, L.prefix), virtual = true }
                    end
                end
            end
        end
        if #slots > 0 then out[#out + 1] = { prefix = L.prefix, label = L.label, slots = slots } end
    end
    return out
end

----------------------------------------------------------------------
-- Frames
----------------------------------------------------------------------
local root
local rows = {}
local taken = {}               -- button -> saved state while it sits on our layout
local pending = false

ensureRoot = function()
    if root then return root end
    root = CreateFrame("Frame", "UbermocActionBars", UIParent)
    root:SetFrameStrata("MEDIUM")
    root:SetFrameLevel(10)
    root:SetSize(10, 10)
    root:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 24)
    root.pips = {}
    root:Hide()
    return root
end

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

local function getRow(i)
    local r = rows[i]
    if r then return r end
    r = {}
    r.f = CreateFrame("Frame", nil, ensureRoot())
    r.f:SetAllPoints(root)
    r.f:SetFrameLevel(root:GetFrameLevel() + 1 + i)
    r.top = CreateFrame("Frame", nil, root)          -- labels above the buttons
    r.top:SetAllPoints(root)
    r.top:SetFrameLevel(root:GetFrameLevel() + 60 + i)
    r.plate = CreateFrame("Frame", nil, r.f)          -- blade plate
    r.mid, r.l, r.r = piece(r.plate), piece(r.plate, true), piece(r.plate, true)
    r.plines = {}
    for k = 1, 3 do
        local ln = r.plate:CreateLine(nil, "BORDER")
        ln:SetThickness(1.5)
        r.plines[k] = ln
    end
    r.backs, r.keys, r.rl = {}, {}, {}
    r.name = r.top:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    rows[i] = r
    return r
end

local function backs(r, n)
    for i = 1, n do
        local b = r.backs[i]
        if not b then
            b = {}
            b.edge = r.f:CreateTexture(nil, "BACKGROUND", nil, -2)
            b.fill = r.f:CreateTexture(nil, "BACKGROUND", nil, -1)
            b.hint = r.f:CreateTexture(nil, "BACKGROUND", nil, 0)
            b.hint:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            b.hint:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            r.backs[i] = b
        end
    end
end
local function keyFS(r, i)
    local fs = r.keys[i]
    if not fs then
        fs = r.top:CreateFontString(nil, "OVERLAY")
        fs:SetFont(STANDARD_TEXT_FONT, 9, "OUTLINE")
        r.keys[i] = fs
    end
    return fs
end

----------------------------------------------------------------------
-- Holding the game's buttons where we want them
----------------------------------------------------------------------
local function reapply(btn)
    local w = btn.ubermocPos
    if not w or btn.ubermocBusy then return end
    if InCombatLockdown() then pending = true; return end
    btn.ubermocBusy = true
    pcall(function()
        local par = btn:GetParent()
        local pe = par and par.GetEffectiveScale and par:GetEffectiveScale()
        local re = root and root:GetEffectiveScale()
        if pe and re and pe > 0 then btn:SetScale(re / pe) end
        btn:SetSize(w.s, w.s)
        btn:ClearAllPoints()
        btn:SetPoint("BOTTOMLEFT", root, "BOTTOMLEFT", w.x, w.y)
    end)
    btn.ubermocBusy = false
end

local function take(btn, bar)
    if not taken[btn] then
        local pts = {}
        for i = 1, btn:GetNumPoints() do pts[i] = { btn:GetPoint(i) } end
        taken[btn] = { pts = pts, scale = btn:GetScale(), w = btn:GetWidth(), h = btn:GetHeight(),
                       strata = btn:GetFrameStrata(), bar = bar }
        if not btn.ubermocHooked then
            btn.ubermocHooked = true
            hooksecurefunc(btn, "SetPoint", function(self) if self.ubermocPos and not self.ubermocBusy then reapply(self) end end)
            hooksecurefunc(btn, "SetSize", function(self) if self.ubermocPos and not self.ubermocBusy then reapply(self) end end)
        end
    end
    pcall(function()
        btn:SetIgnoreParentAlpha(true)
        btn:SetFrameStrata("MEDIUM")
        btn:SetFrameLevel(root:GetFrameLevel() + 30)
    end)
end

local function dressButton(btn)
    local d = DB()
    local hide = d.noBorder and 0 or 1
    pcall(function()
        local nt = btn.GetNormalTexture and btn:GetNormalTexture()
        if nt then nt:SetAlpha(hide) end
        for _, k in ipairs({ "SlotArt", "SlotBackground", "Border" }) do
            local t = btn[k]
            if t and t.SetAlpha then t:SetAlpha(hide) end
        end
        if btn.HotKey and btn.HotKey.SetAlpha then btn.HotKey:SetAlpha(0) end
    end)
end

local function release(btn)
    local st = taken[btn]
    if not st then return end
    taken[btn] = nil
    btn.ubermocPos = nil
    pcall(function()
        btn:SetAlpha(1)
        btn:SetIgnoreParentAlpha(false)
        btn:SetFrameStrata(st.strata)
        btn:SetScale(st.scale)
        btn:SetSize(st.w, st.h)
        btn:ClearAllPoints()
        for _, p in ipairs(st.pts) do btn:SetPoint(p[1], p[2], p[3], p[4], p[5]) end
        local nt = btn.GetNormalTexture and btn:GetNormalTexture()
        if nt then nt:SetAlpha(1) end
        for _, k in ipairs({ "SlotArt", "SlotBackground", "Border" }) do
            local t = btn[k]
            if t and t.SetAlpha then t:SetAlpha(1) end
        end
        if btn.HotKey and btn.HotKey.SetAlpha then btn.HotKey:SetAlpha(1) end
    end)
    if btn.ubermocVirtual then btn:Hide(); return end
    local bar = st.bar
    if bar then
        for _, fn in ipairs({ "UpdateGridLayout", "Layout" }) do
            if type(bar[fn]) == "function" then pcall(bar[fn], bar) end
        end
    end
end

local GAME_BARS = { "MainActionBar", "MainMenuBar", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight",
                    "MultiBarLeft", "MultiBar5", "MultiBar6", "MultiBar7" }
local function hideGameBars(hide)
    local hh = API.holdHidden
    if not hh then return end
    for _, n in ipairs(GAME_BARS) do
        local f = _G[n]
        if f then pcall(hh, f, hide) end
    end
end

----------------------------------------------------------------------
-- Which layer is held right now
----------------------------------------------------------------------
local function heldPrefix()
    local a = IsAltKeyDown and IsAltKeyDown()
    local c = IsControlKeyDown and IsControlKeyDown()
    local s = IsShiftKeyDown and IsShiftKeyDown()
    return (a and "ALT-" or "") .. (c and "CTRL-" or "") .. (s and "SHIFT-" or "")
end

local function refreshActive()
    if not root or not root:IsShown() then return end
    local d = DB()
    local cur = heldPrefix()
    local found
    for _, L in ipairs(layersNow) do if L.prefix == cur then found = L end end
    if not found then found = layersNow[1] end
    -- the buttons keep their own opacity, so the cinematic camera's interface fade is applied here too
    local ua = API.cineUIAlpha and API.cineUIAlpha() or 1
    for i, L in ipairs(layersNow) do
        local r = rows[i]
        if r then
            local active = (L == found)
            local a = (active and 1 or ((d.mode == "all") and (d.dim / 100) or 0)) * ua
            r.f:SetAlpha(a)
            r.top:SetAlpha(a)
            r.active = active
            local carrying = false
            if d.hideEmpty and GetCursorInfo then
                local okC, ct = pcall(GetCursorInfo)
                carrying = okC and ct ~= nil
            end
            for k, s in ipairs(L.slots) do
                local b = r.backs[k]
                local empty = false
                local act = s.btn.action
                if not act and s.btn.GetAttribute then act = s.btn:GetAttribute("action") end
                if s.btn.ubermocEmpty then empty = true end
                if act and HasAction then
                    local okH, has = pcall(HasAction, act)
                    empty = okH and not has
                end
                local gone = d.hideEmpty and empty and not carrying
                local wantA = gone and 0 or a
                local okA, curA = pcall(s.btn.GetAlpha, s.btn)
                if not okA or curA ~= wantA then pcall(s.btn.SetAlpha, s.btn, wantA) end   -- only when it differs
                -- Layers can sit on top of each other: the one in use takes the mouse, so the tooltip comes up at once
                -- and a hidden layer's button never catches the pointer over its neighbour.
                -- The game's action buttons are protected: their frame level can only change out of combat.
                local lvl = root:GetFrameLevel() + (active and 45 or 30)
                if s.lvl ~= lvl and not InCombatLockdown() then
                    s.lvl = lvl
                    pcall(s.btn.SetFrameLevel, s.btn, lvl)
                end
                if b then
                    if gone then
                        b.fill:Hide(); b.edge:Hide()
                    else
                        b.fill:Show(); b.edge:SetShown(b.wantEdge ~= false)
                    end
                end
                if r.keys[k] then r.keys[k]:SetAlpha(gone and 0 or 1) end
                if b and b.hint then
                    if empty and d.emptyIcon == true and not gone then
                        b.hint:ClearAllPoints()
                        b.hint:SetPoint("TOPLEFT", b.fill, "TOPLEFT", 3, -3)
                        b.hint:SetPoint("BOTTOMRIGHT", b.fill, "BOTTOMRIGHT", -3, 3)
                        b.hint:SetAlpha(0.3)
                        b.hint:Show()
                    else
                        b.hint:Hide()
                    end
                end
            end
        end
    end
    -- Layer dots for the held-layer mode.
    for i, pip in ipairs(root.pips) do
        local L = layersNow[i]
        if L and d.pips ~= false and d.mode == "held" and #layersNow > 1 then
            local col = COLORS[(i - 1) % #COLORS + 1]
            pip:SetColorTexture(col[1], col[2], col[3], (L == found) and 1 or 0.3)
            pip:Show()
        else
            pip:Hide()
        end
    end
end

----------------------------------------------------------------------
-- Layout
----------------------------------------------------------------------
local GROUP = 12   -- extra space after every fourth button

local function slotOffset(i, s, g)
    return (i - 1) * (s + g) + math.floor((i - 1) / 4) * GROUP
end
local function innerWidth(n, s, g)
    return n * s + (n - 1) * g + math.floor((n - 1) / 4) * GROUP
end

local function paintPlate(r, d, x0, y0, w, h, run, col)
    local pl = r.plate
    pl:ClearAllPoints()
    pl:SetPoint("BOTTOMLEFT", root, "BOTTOMLEFT", x0, y0)
    pl:SetSize(w, h)
    local bgA = math.max(0, math.min(1, (d.bgA or 90) / 100))
    local texOn = d.tex and d.tex ~= "none" and (d.texA or 0) > 0 and bgA > 0
    local function paint(p, px, pw, triFile)
        p.base:ClearAllPoints(); p.base:SetPoint("BOTTOMLEFT", pl, "BOTTOMLEFT", px, 0); p.base:SetSize(math.max(1, pw), h)
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
    paint(r.mid, run, w - 2 * run)
    paint(r.l, 0, run, "blade_c.tga")
    paint(r.r, w - run, run, "blade_d.tga")
    local L = r.plines
    do
        -- Edge line (Textures page): class colour, your own, or this row's layer colour.
        local on, sz, er, eg, eb, ea, mode = API.borderOf("abPlates")
        if mode == "auto" then er, eg, eb = col[1], col[2], col[3] end
        for k = 1, 3 do
            L[k]:SetColorTexture(er, eg, eb, ea)
            if L[k].SetThickness then pcall(L[k].SetThickness, L[k], sz) end
            L[k]:SetShown(on)
        end
    end
    L[1]:SetStartPoint("BOTTOMLEFT", pl, 0, 0);      L[1]:SetEndPoint("TOPLEFT", pl, run, 0)
    L[2]:SetStartPoint("TOPLEFT", pl, run, 0);       L[2]:SetEndPoint("TOPRIGHT", pl, -run, 0)
    L[3]:SetStartPoint("TOPRIGHT", pl, -run, 0);     L[3]:SetEndPoint("BOTTOMRIGHT", pl, 0, 0)
    pl:Show()
end

local function slotBack(r, i, x, y, s, col, strong, solid)
    local b = r.backs[i]
    b.edge:ClearAllPoints(); b.fill:ClearAllPoints()
    -- Button border (Textures page): class colour, your own, or this row's layer colour.
    local on, sz, er, eg, eb, ea, mode = API.borderOf("abButtons")
    if mode == "auto" then er, eg, eb = col[1], col[2], col[3] end
    b.edge:SetPoint("BOTTOMLEFT", root, "BOTTOMLEFT", x - sz, y - sz)
    b.edge:SetSize(s + 2 * sz, s + 2 * sz)
    b.fill:SetPoint("BOTTOMLEFT", root, "BOTTOMLEFT", x, y)
    b.fill:SetSize(s, s)
    b.edge:SetColorTexture(er, eg, eb, ea * (strong and 1 or 0.5))
    b.fill:SetColorTexture(0.03, 0.035, 0.05, solid and 0.9 or 0.6)
    b.wantEdge = (strong ~= nil and on)
    b.edge:SetShown(b.wantEdge)
    b.fill:Show()
end

local function place(r, L, i, x, y, s, col, d)
    local slot = L.slots[i]
    slot.btn.ubermocPos = { x = x, y = y, s = s }
    take(slot.btn, slot.bar)
    if slot.virtual then slot.btn:Show() else dressButton(slot.btn) end
    reapply(slot.btn)
    local fs = keyFS(r, i)
    if d.labels then
        fs:ClearAllPoints()
        fs:SetPoint("TOPLEFT", root, "BOTTOMLEFT", x + 2, y + s - 1)
        fs:SetText(API.padLabel and API.padLabel(slot.key, true) or slot.key)
        fs:SetTextColor(col[1] * 0.4 + 0.6, col[2] * 0.4 + 0.6, col[3] * 0.4 + 0.6)
        fs:Show()
    else
        fs:Hide()
    end
end

local function layout()
    if InCombatLockdown() then pending = true; return end
    if not root then
        if not DB().on then return end
        ensureRoot()
    end
    pending = false
    local d = DB()
    if not d.on then
        root:Hide()
        for b in pairs(taken) do release(b) end
        hideGameBars(false)
        return
    end
    pcall(convertAll)
    local M = model()
    layersNow = M
    -- Give back buttons that are no longer on any layer.
    local keep = {}
    for _, L in ipairs(M) do for _, s in ipairs(L.slots) do keep[s.btn] = true end end
    for b in pairs(taken) do if not keep[b] then release(b) end end
    for i = #M + 1, #rows do
        rows[i].f:Hide(); rows[i].top:Hide()
    end
    if #M == 0 then
        root:Hide()
        hideGameBars(false)
        return
    end
    hideGameBars(d.hideGame and true or false)

    local s, g = d.size, d.gap
    local design = d.design
    local P = 4
    local maxN = 0
    for _, L in ipairs(M) do maxN = math.max(maxN, #L.slots) end
    local W, H = 10, 10
    local held = d.mode == "held"
    local nrows = held and 1 or #M

    if design == "arc" then
        local span = math.rad(56)
        local R0 = math.max(220, (maxN * (s + g)) / span)
        local step = s + 16
        local minY, maxY, maxX = 1e9, -1e9, 0
        local pos = {}
        for i, L in ipairs(M) do
            local R = R0 - (held and 0 or (i - 1) * step)
            local n = #L.slots
            local sp = math.min(span, math.max(n - 1, 1) * (s + g) / R)
            pos[i] = { R = R, list = {} }
            for k = 1, n do
                local th = (n == 1) and 0 or (-sp / 2 + sp * (k - 1) / (n - 1))
                local px, py = R * math.sin(th), R * math.cos(th)
                pos[i].list[k] = { px, py }
                minY = math.min(minY, py - s / 2); maxY = math.max(maxY, py + s / 2)
                maxX = math.max(maxX, math.abs(px) + s / 2)
            end
            pos[i].sp = sp
        end
        W = maxX * 2 + 20
        H = (maxY - minY) + 20
        root:SetSize(W, H)
        for i, L in ipairs(M) do
            local r = getRow(i)
            r.f:Show(); r.top:Show()
            r.plate:Hide()
            local col = COLORS[(i - 1) % #COLORS + 1]
            backs(r, #L.slots)
            for k = 1, #L.slots do
                local px, py = pos[i].list[k][1], pos[i].list[k][2]
                local x, y = W / 2 + px - s / 2, py - minY + 10 - s / 2
                slotBack(r, k, x, y, s, col, true, true)
                place(r, L, k, x, y, s, col, d)
            end
            for k = #L.slots + 1, #r.backs do r.backs[k].edge:Hide(); r.backs[k].fill:Hide() end
            for k = #L.slots + 1, #r.keys do r.keys[k]:Hide() end
            -- The ring the buttons sit on.
            local R, sp = pos[i].R, pos[i].sp
            local segs = 28
            for k = 1, segs do
                local ln = r.rl[k]
                if not ln then ln = r.f:CreateLine(nil, "BORDER"); r.rl[k] = ln end
                local t1 = -sp / 2 - 0.04 + (sp + 0.08) * (k - 1) / segs
                local t2 = -sp / 2 - 0.04 + (sp + 0.08) * k / segs
                ln:SetThickness(r.active and 2 or 1.5)
                ln:SetColorTexture(col[1], col[2], col[3], 0.7)
                local rr = R + s / 2 + 5
                ln:SetStartPoint("BOTTOMLEFT", root, W / 2 + rr * math.sin(t1), rr * math.cos(t1) - minY + 10)
                ln:SetEndPoint("BOTTOMLEFT", root, W / 2 + rr * math.sin(t2), rr * math.cos(t2) - minY + 10)
                ln:Show()
            end
            for k = segs + 1, #r.rl do r.rl[k]:Hide() end
            r.name:ClearAllPoints()
            r.name:SetPoint("RIGHT", root, "BOTTOMLEFT", W / 2 + pos[i].list[1][1] - s / 2 - 8, pos[i].list[1][2] - minY + 10)
            r.name:SetText(L.label); r.name:SetTextColor(col[1], col[2], col[3])
            r.name:SetShown(not held and #M > 1)
        end
    else
        local rowW, rowH, run = {}, s + 2 * P, 0
        if design == "blade" then run = math.floor(rowH * 0.45 + 0.5) end
        local widest = 0
        for i, L in ipairs(M) do
            rowW[i] = innerWidth(#L.slots, s, g) + 2 * P + 2 * run
            widest = math.max(widest, rowW[i])
        end
        local rgap = (design == "blade") and 3 or 5
        W = widest
        H = nrows * rowH + (nrows - 1) * rgap
        root:SetSize(W, H)
        for i, L in ipairs(M) do
            local r = getRow(i)
            r.f:Show(); r.top:Show()
            local col = COLORS[(i - 1) % #COLORS + 1]
            local rr = held and 0 or (i - 1)
            local y0 = rr * (rowH + rgap)
            local x0 = (W - rowW[i]) / 2
            backs(r, #L.slots)
            if design == "blade" then
                paintPlate(r, d, x0, y0, rowW[i], rowH, run, col)
            else
                r.plate:Hide()
            end
            for k = 1, #L.slots do
                local x = x0 + run + P + slotOffset(k, s, g)
                local y = y0 + P
                slotBack(r, k, x, y, s, col, design == "plain" and true or nil, design == "plain")
                place(r, L, k, x, y, s, col, d)
            end
            for k = #L.slots + 1, #r.backs do r.backs[k].edge:Hide(); r.backs[k].fill:Hide() end
            for k = #L.slots + 1, #r.keys do r.keys[k]:Hide() end
            for k = 1, #r.rl do r.rl[k]:Hide() end
            r.name:ClearAllPoints()
            r.name:SetPoint("RIGHT", root, "BOTTOMLEFT", x0 - 6, y0 + rowH / 2)
            r.name:SetText(L.label); r.name:SetTextColor(col[1], col[2], col[3])
            r.name:SetShown(not held and #M > 1)
        end
    end

    -- Layer dots (held-layer mode).
    for i = 1, #M do
        local pip = root.pips[i]
        if not pip then
            pip = root:CreateTexture(nil, "OVERLAY")
            pip:SetSize(8, 8)
            root.pips[i] = pip
        end
        pip:ClearAllPoints()
        pip:SetPoint("BOTTOM", root, "TOP", (i - (#M + 1) / 2) * 12, 6)
    end
    root:ClearAllPoints()
    root:SetPoint("BOTTOM", UIParent, "BOTTOM", d.x, d.y)
    root:SetScale(math.max(0.3, d.scale / 100))
    root:Show()
    -- Positions depend on the scale, so place the buttons again now it is set.
    for _, L in ipairs(M) do for _, sl in ipairs(L.slots) do reapply(sl.btn) end end
    refreshActive()
end

local layoutSoon
do
    local t
    layoutSoon = function()
        if t then return end
        t = true
        C_Timer.After(0.2, function() t = nil; pcall(layout) end)
    end
end
function API.applyActionBars() layoutSoon() end
API.abarDB = DB
API.abarRefresh = function() pcall(refreshActive) end
-- The Textures page changes the blade texture, edge line and button borders.
function API.abarLayout() layoutSoon(); pcall(refreshActive) end

-- Spellbook options menu > Bind: the spell goes on a free action button (returned as its binding command),
-- then the Buttons dialog waits for the controller button or combination to bind to it.
function API.placeSpellFree(spellID)
    if InCombatLockdown() then return nil, "Not in combat." end
    local cmd, act
    for _, c in ipairs(FREE) do
        local btn, bar = buttonFor(c)
        if btn and bar then
            local a2 = btn.action
            if not a2 and btn.GetAttribute then a2 = btn:GetAttribute("action") end
            local padBound = false
            for _, k in ipairs({ GetBindingKey(c) }) do if type(k) == "string" and k:find("PAD") then padBound = true end end
            if type(a2) == "number" and not padBound and HasAction and not HasAction(a2) then cmd, act = c, a2; break end
        end
    end
    if not cmd then return nil, "No free action button left." end
    if not (C_Spell and C_Spell.PickupSpell) then return nil, "Cannot pick up that spell here." end
    pcall(C_Spell.PickupSpell, spellID)
    local ok = pcall(PlaceAction, act)
    if ClearCursor then ClearCursor() end
    if not ok then return nil, "Could not place the spell." end
    return cmd
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "UPDATE_BINDINGS", "PLAYER_REGEN_ENABLED", "CVAR_UPDATE", "ACTIVE_TALENT_GROUP_CHANGED",
                     "MODIFIER_STATE_CHANGED", "UPDATE_BONUS_ACTIONBAR", "ACTIONBAR_SLOT_CHANGED", "CURSOR_CHANGED" }) do
    pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function(_, event)
    if not (UbermocUIDB and DB().on) then return end
    -- a layer held, an action put on or taken off a button, something picked up: the look changes at once
    if event == "CURSOR_CHANGED" then
        -- the pointer's look changes often (hovering things); only picking something up or putting it down matters
        local okC, ct = pcall(GetCursorInfo)
        local carry = okC and ct ~= nil or false
        if carry == ev.carry then return end
        ev.carry = carry
    end
    if event == "MODIFIER_STATE_CHANGED" or event == "ACTIONBAR_SLOT_CHANGED" or event == "CURSOR_CHANGED" then pcall(refreshActive); return end
    if event == "PLAYER_REGEN_ENABLED" then
        if pending then layoutSoon() end
        return
    end
    layoutSoon()
    -- Binds and modifier settings can arrive a little after the world loads: lay out again a few times.
    if event == "PLAYER_ENTERING_WORLD" then
        for _, w in ipairs({ 1, 3, 8 }) do C_Timer.After(w, function() if UbermocUIDB and DB().on then layoutSoon() end end) end
    end
end)
do
    local acc = 0
    -- The events above do the work; this slow look only catches anything they miss.
    ev:SetScript("OnUpdate", function(_, dt)
        acc = acc + dt
        if acc < 0.5 then return end
        acc = 0
        if root and root:IsShown() then pcall(refreshActive) end
    end)
end

----------------------------------------------------------------------
-- Cooldown numbers on the action buttons: the game's own countdown, restyled (thin outline, no shadow),
-- placed where you choose, with no dark sweep over the icon.
----------------------------------------------------------------------
local cdBars = { "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton", "MultiBarRightButton",
                 "MultiBarLeftButton", "MultiBar5Button", "MultiBar6Button", "MultiBar7Button",
                 "StanceButton", "PetActionButton", "PossessButton" }
local function cdStyle(btn, cdOverride)
    local d = DB()
    local cd = cdOverride or (btn and (btn.cooldown or (btn.GetName and btn:GetName() and _G[btn:GetName() .. "Cooldown"])))
    if not cd then return end
    if d.cdOn == false then return end
    pcall(cd.SetDrawSwipe, cd, false)
    pcall(cd.SetDrawEdge, cd, false)
    pcall(cd.SetHideCountdownNumbers, cd, false)
    -- numbers from 1.6 seconds up: short cooldowns like stealth (2 s) show, the global cooldown does not
    pcall(cd.SetMinimumCountdownDuration, cd, 1600)
    if cd.GetCountdownFontString then
        local fs = cd:GetCountdownFontString()
        if fs then
            local w = btn:GetWidth() or 40
            local size = math.max(8, math.floor(w * 0.42 * (d.cdScale or 100) / 100 + 0.5))
            pcall(fs.SetFont, fs, STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", size, "OUTLINE")
            pcall(fs.SetShadowOffset, fs, 0, 0)
            pcall(fs.SetShadowColor, fs, 0, 0, 0, 0)
            pcall(fs.ClearAllPoints, fs)
            local pos = d.cdPos or "CENTER"
            pcall(fs.SetPoint, fs, pos, btn, pos, d.cdX or 0, d.cdY or 0)
        end
    end
end
local function cdApplyAll()
    for _, n in ipairs(cdBars) do
        for i = 1, 12 do
            local b = _G[n .. i]
            if b then cdStyle(b) end
        end
    end
end
API.abarCooldownText = function() pcall(cdApplyAll); for _, f in pairs(virt) do if f.cd then pcall(cdStyle, f, f.cd) end end end
API.abarCooldownStyle = function(btn, cd) cdStyle(btn, cd) end
do
    local hooked = false
    local function hook()
        if hooked or not hooksecurefunc then return end
        if _G.ActionButton_UpdateCooldownNumberHidden then
            hooksecurefunc("ActionButton_UpdateCooldownNumberHidden", function(btn) pcall(cdStyle, btn) end)
            hooked = true
        end
    end
    local f = CreateFrame("Frame")
    for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "ACTIONBAR_SLOT_CHANGED", "UPDATE_BONUS_ACTIONBAR", "UPDATE_SHAPESHIFT_FORM", "UPDATE_SHAPESHIFT_FORMS", "UPDATE_SHAPESHIFT_COOLDOWN", "PET_BAR_UPDATE" }) do pcall(f.RegisterEvent, f, e) end
    f:SetScript("OnEvent", function() hook(); pcall(cdApplyAll) end)
    C_Timer.After(2, function() hook(); pcall(cdApplyAll) end)
end

-- (The stance / stealth button is left to the game: nothing here moves, scales or restyles it.)
API.applyStanceButton = function() end

----------------------------------------------------------------------
-- Page
----------------------------------------------------------------------
local function buildPage()
    local panel = CreateFrame("Frame")
    panel.name = "Action Bars"
    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 8, -8)
    scroll:SetPoint("BOTTOMRIGHT", -30, 8)
    local p = CreateFrame("Frame", nil, scroll)
    p:SetSize(600, 1620)
    scroll:SetScrollChild(p)
    local pct = function(v) return math.floor(v + 0.5) .. "%" end
    local px = function(v) return math.floor(v + 0.5) .. " px" end
    local function slider(label, y, min, max, step, fmt, fn)
        API.newLabel(p, label, 40, y - 4)
        local s = API.makeSlider(p, 150, min, max, step, fmt, fn)
        s:SetPoint("TOPLEFT", 232, y)
        return s
    end
    local function setter(key, fn) return function(v) DB()[key] = v; (fn or layout)() end end

    -- Bar -------------------------------------------------------------------------------------------
    API.newLabel(p, "Action Bars", 16, -14, "GameFontNormalHuge")
    local intro = API.newLabel(p, "Every controller button laid out by layer: a row for the plain press and one for each held modifier. Action buttons are the game's own, so they work in combat and show cooldowns.", 16, -48, "GameFontHighlightSmall")
    intro:SetWidth(560); intro:SetJustifyH("LEFT"); intro:SetWordWrap(true)
    local onCB = API.newCheck(p, "Use these action bars", 16, -90, function(v) DB().on = v; layout(); panel.refresh() end)
    local hideCB = API.newCheck(p, "Hide the game's own action bars", 16, -122, setter("hideGame"))
    API.newLabel(p, "Design", 40, -162)
    local designBtn = API.segRow(p, 200, -158, { { "plain", "Plain", 70 }, { "blade", "Blade", 70 }, { "arc", "Arc", 70 } },
        function() return DB().design or "blade" end, function(v) DB().design = v; layout(); panel.refresh() end)
    API.newLabel(p, "Layers", 40, -198)
    local modeBtn = API.segRow(p, 200, -194, { { "all", "All at once", 110 }, { "held", "Only the held one", 140 } },
        function() return DB().mode == "held" and "held" or "all" end, function(v) DB().mode = v; layout(); panel.refresh() end)
    local labelsCB = API.newCheck(p, "Controller button names on the slots", 16, -232, setter("labels"))
    local sSize = slider("Size", -306, 24, 72, 2, px, setter("size"))
    local sGap = slider("Gap", -342, 0, 16, 1, px, setter("gap"))
    local sScale = slider("Scale", -378, 50, 200, 5, pct, setter("scale"))
    local sX = slider("Left / right", -414, -900, 900, 10, px, setter("x"))
    local sY = slider("Up / down", -450, 0, 700, 5, px, setter("y"))
    local note = API.newLabel(p, "Turning this off puts the buttons back; Reload UI finishes it.", 16, -492, "GameFontHighlightSmall")
    note:SetWidth(560); note:SetJustifyH("LEFT")

    -- Look ------------------------------------------------------------------------------------------
    local LY = -560
    API.newLabel(p, "Look", 16, LY, "GameFontNormalLarge")
    local sDim = slider("Layers not held", LY - 36, 0, 100, 5, pct, setter("dim", refreshActive))
    local sBg = slider("Blade background", LY - 72, 0, 100, 5, pct, setter("bgA"))
    API.newButton(p, "Texture and borders: Textures page", 260, 40, LY - 110, function()
        if API.openTextures then API.openTextures("abar") end
    end)
    local pipCB = API.newCheck(p, "Coloured squares above the bar", 16, LY - 150, setter("pips", refreshActive))
    local emptyCB = API.newCheck(p, "Icon on empty buttons", 16, LY - 182, setter("emptyIcon", refreshActive))
    local hideEmptyCB = API.newCheck(p, "Hide empty buttons", 16, LY - 214, setter("hideEmpty", refreshActive))
    local convCB = API.newCheck(p, "Spells, items and macros bound to a pad button go on real action buttons (bars 2 to 8)", 16, LY - 246, setter("convertBinds"))
    local fillCB = API.newCheck(p, "Every unused pad button gets an empty real action button, ready for a spell", 16, LY - 278, setter("fillEmpty"))

    -- Buttons shown ---------------------------------------------------------------------------------
    local BY = -920
    API.newLabel(p, "Buttons shown", 16, BY, "GameFontNormalLarge")
    local bn = API.newLabel(p, "Every controller button except Start and Select gets a slot on each layer, whatever it does. Untick a kind to leave it off; a button that does something else on another layer still shows there.", 16, BY - 30, "GameFontHighlightSmall")
    bn:SetWidth(560); bn:SetJustifyH("LEFT"); bn:SetWordWrap(true)
    local modsCB = API.newCheck(p, "Modifier buttons (the paddles held for Shift, Ctrl, Alt)", 16, BY - 76, setter("showMods"))
    local targetCB = API.newCheck(p, "Targeting binds (target, assist, focus)", 16, BY - 108, setter("showTarget"))
    local uiCB = API.newCheck(p, "Interface binds (map, bags, menus, the interface cursor)", 16, BY - 140, setter("showUI"))
    local moveCB = API.newCheck(p, "Movement and camera binds", 16, BY - 172, setter("showMove"))
    local dn = API.newLabel(p, "With a mouse: drag a bind from one slot to another and the two buttons swap (the Buttons page shows the change). Drop a spell, item or macro on an empty slot and it is put on a free action button bound to that controller button. Not in combat.", 16, BY - 212, "GameFontHighlightSmall")
    dn:SetWidth(560); dn:SetJustifyH("LEFT"); dn:SetWordWrap(true)

    -- Cooldown numbers ----------------------------------------------------------------------------
    local CY = -1250
    API.newLabel(p, "Cooldown numbers", 16, CY, "GameFontNormalLarge")
    local cn = API.newLabel(p, "The time left shows on an action button while it recharges: a thin outline, no shadow, and no dark sweep over the icon.", 16, CY - 30, "GameFontHighlightSmall")
    cn:SetWidth(560); cn:SetJustifyH("LEFT"); cn:SetWordWrap(true)
    local function cdChanged() if API.abarCooldownText then API.abarCooldownText() end end
    local cdOnCB = API.newCheck(p, "Show cooldown numbers on the action buttons", 16, CY - 70, function(v) DB().cdOn = v; cdChanged() end)
    API.newLabel(p, "Size", 40, CY - 114)
    local cdSize = API.makeSlider(p, 150, 40, 250, 5, pct, function(v) DB().cdScale = v; cdChanged() end)
    cdSize:SetPoint("TOPLEFT", 232, CY - 110)
    API.newLabel(p, "Place", 40, CY - 156)
    local CDNAMES = { TOPLEFT = "top left", TOP = "top middle", TOPRIGHT = "top right", LEFT = "left", CENTER = "middle", RIGHT = "right",
                      BOTTOMLEFT = "bottom left", BOTTOM = "bottom middle", BOTTOMRIGHT = "bottom right" }
    local cdPlace = API.cornerPick(p, 232, CY - 150, CDNAMES, function() return DB().cdPos or "CENTER" end,
        function(v) DB().cdPos = v; cdChanged() end)
    API.newLabel(p, "Left / right", 40, CY - 230)
    local cdXs = API.makeSlider(p, 150, -30, 30, 1, px, function(v) DB().cdX = v; cdChanged() end)
    cdXs:SetPoint("TOPLEFT", 232, CY - 226)
    API.newLabel(p, "Up / down", 40, CY - 270)
    local cdYs = API.makeSlider(p, 150, -30, 30, 1, px, function(v) DB().cdY = v; cdChanged() end)
    cdYs:SetPoint("TOPLEFT", 232, CY - 266)
    local cdNote = API.newLabel(p, "Turning it off puts the game's own look back after a reload.", 16, CY - 306, "GameFontHighlightSmall")
    cdNote:SetWidth(560)

    local stRef = function()
        local d = DB()
        cdOnCB:SetChecked(d.cdOn ~= false)
        API.setSlider(cdSize, d.cdScale or 100); API.setSlider(cdXs, d.cdX or 0); API.setSlider(cdYs, d.cdY or 0)
        cdPlace.refresh()
    end
    API.makeTabs(panel, scroll, p, { { "Bar", 0 }, { "Look", LY + 10 }, { "Buttons shown", BY + 10 }, { "Cooldown numbers", CY + 10 } })

    function panel.refresh()
        local d = DB()
        onCB:SetChecked(d.on); hideCB:SetChecked(d.hideGame); labelsCB:SetChecked(d.labels)
        designBtn.refresh(); modeBtn.refresh()
        API.setSlider(sSize, d.size); API.setSlider(sGap, d.gap); API.setSlider(sScale, d.scale)
        API.setSlider(sX, d.x); API.setSlider(sY, d.y); API.setSlider(sDim, d.dim)
        API.setSlider(sBg, d.bgA)
        pipCB:SetChecked(d.pips ~= false)
        emptyCB:SetChecked(d.emptyIcon == true); hideEmptyCB:SetChecked(d.hideEmpty == true); convCB:SetChecked(d.convertBinds ~= false); fillCB:SetChecked(d.fillEmpty ~= false)
        modsCB:SetChecked(d.showMods ~= false); targetCB:SetChecked(d.showTarget ~= false)
        uiCB:SetChecked(d.showUI ~= false); moveCB:SetChecked(d.showMove ~= false)
        local blade = d.design == "blade"
        API.setActive(sBg, blade)
        API.setActive(sDim, d.mode == "all")
        for _, w in ipairs({ hideCB, designBtn, modeBtn, labelsCB, sSize, sGap, sScale, sX, sY }) do API.setActive(w, d.on and true or false) end
    end
    panel:SetScript("OnShow", function() panel.refresh(); stRef() end)
    API.resetters = API.resetters or {}
    API.resetters.abar = function() local was = UbermocUIDB.abar and UbermocUIDB.abar.on; UbermocUIDB.abar = nil; DB(); if was then layout() end end
    API.addPage("abar", "Action Bars", panel)
end

-- Action bars 2 to 8 have to be switched on in the game for their buttons to be drawn. Done once (the game's
-- own setting, the same as Options > Action Bars), then a reload puts them up.
local function barsOn()
    local d = DB()
    if d.barsOnV1 or not d.on or InCombatLockdown() then return end
    if not (GetActionBarToggles and SetActionBarToggles) then return end
    d.barsOnV1 = true
    local t = { GetActionBarToggles() }
    local changed = false
    for i = 1, 7 do if t[i] ~= true then t[i] = true; changed = true end end
    if changed then
        pcall(SetActionBarToggles, unpack(t))
        if API.askReload then API.askReload("Ubermoc UI switched on action bars 2 to 8, so every controller button can be a real action button. Reload now?") end
    end
end
API.abarBarsOn = barsOn

local prev = API.onLogin
API.onLogin = function()
    if prev then prev() end
    DB()
    C_Timer.After(3, function() pcall(barsOn) end)
    API.later("Action bars", buildPage)
    C_Timer.After(2, function() pcall(layout) end)
end
