-- Ubermoc UI - Copyright (c) 2026 Marcos. All rights reserved.
-- This file is protected by copyright. It may not be copied, modified, redistributed or reused, in whole or
-- in part, without the written permission of the author. See LICENSE.txt.
----------------------------------------------------------------------
-- Ubermoc UI: class and special abilities on the left trigger
-- Stealth, shapeshift forms and stances (everything on the game's stance bar) go to the left trigger's bar by default:
-- the first empty slot with a controller button on it. They are placed once, so moving one off the bar afterwards
-- is respected. Only for characters that use the controller layout. "/ubclassslots off" switches it off.
----------------------------------------------------------------------
local API = UbermocUIAPI
if not API then return end

-- The left trigger is the Shift layer, which holds the bottom left bar. Its first eight buttons carry the face buttons
-- and the D-pad (the last two of the ten with a pad key are the bumpers, which target).
local BAR = "MultiBarBottomLeft"
local SLOTS = 8

local function isSecret(v) return issecretvalue and issecretvalue(v) end

local function placedSet()
    local g = UnitGUID and UnitGUID("player")
    if not g then return nil end
    UbermocUIDB.classSlots = UbermocUIDB.classSlots or {}
    UbermocUIDB.classSlots[g] = UbermocUIDB.classSlots[g] or {}
    return UbermocUIDB.classSlots[g], g
end

local function onABar(spellID)
    for slot = 1, 180 do
        if HasAction and HasAction(slot) then
            local ok, kind, id = pcall(GetActionInfo, slot)
            if ok and kind == "spell" and not isSecret(id) and id == spellID then return true end
        end
    end
    return false
end

local function freeSlot()
    for i = 1, SLOTS do
        local btn = _G[BAR .. "Button" .. i]
        local act = btn and btn.action
        if type(act) == "number" and HasAction and not HasAction(act) then return act end
    end
end

local function run()
    if not UbermocUIDB or UbermocUIDB.classSlotsOff or InCombatLockdown() then return end
    if not (GetNumShapeshiftForms and GetShapeshiftFormInfo and C_Spell and C_Spell.PickupSpell and PlaceAction) then return end
    local placed, g = placedSet()
    if not placed then return end
    -- only characters that use the controller layout
    if not (UbermocUIDB.layoutV9 and UbermocUIDB.layoutV9[g]) then return end
    local okN, n = pcall(GetNumShapeshiftForms)
    if not okN or type(n) ~= "number" then return end
    for i = 1, n do
        local okF, _, _, _, spellID = pcall(GetShapeshiftFormInfo, i)
        if okF and type(spellID) == "number" and not isSecret(spellID) and not placed[spellID] then
            if onABar(spellID) then
                placed[spellID] = true
            else
                local act = freeSlot()
                if not act then return end
                pcall(C_Spell.PickupSpell, spellID)
                local ok = pcall(PlaceAction, act)
                if ClearCursor then ClearCursor() end
                if ok and HasAction(act) then placed[spellID] = true end
            end
        end
    end
end

local pending
local function later()
    if pending then return end
    pending = true
    C_Timer.After(1.5, function() pending = false; pcall(run) end)
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "SPELLS_CHANGED", "UPDATE_SHAPESHIFT_FORMS", "PLAYER_REGEN_ENABLED" }) do
    pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", later)

SLASH_UBERMOCCLASSSLOTS1 = "/ubclassslots"
SlashCmdList["UBERMOCCLASSSLOTS"] = function(msg)
    msg = (msg or ""):lower():match("^%s*(%S*)")
    if msg == "off" or msg == "on" then
        UbermocUIDB.classSlotsOff = (msg == "off") or nil
        print("Ubermoc UI: class abilities (Stealth, forms, stances) " .. (msg == "off" and "are no longer" or "are now") .. " placed on the left trigger's bar.")
        if msg == "on" then later() end
    else
        print("Ubermoc UI: /ubclassslots on | off (Stealth, forms and stances go on the left trigger's bar by default).")
    end
end
