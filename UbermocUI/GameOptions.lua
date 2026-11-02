-- Ubermoc UI - Copyright (c) 2026 Marcos. All rights reserved.
-- This file is protected by copyright. It may not be copied, modified, redistributed or reused, in whole or
-- in part, without the written permission of the author. See LICENSE.txt.
----------------------------------------------------------------------
-- Ubermoc UI: Game Options
-- The game's own options that matter to this mod, set from one page. Every switch reads and writes the
-- game's real setting, so it always matches the game's Options screen. Enemy / friendly nameplates and
-- friendly NPC plates are on the Nameplates page.
----------------------------------------------------------------------
local API = UbermocUIAPI
if not API then return end

local SECTIONS = {
    { "Nameplates", {
        { "nameplateShowAll", "Always show nameplates (not only in combat)" },
        { "nameplateShowCastBars", "Cast bars on nameplates" },
        { "nameplateShowClassColor", "Class colours on enemy player nameplates" },
        { "nameplateShowFriendlyClassColor", "Class colours on friendly player nameplates" },
        { "nameplateShowOnlyNameForFriendlyPlayerUnits", "Friendly players: show only the name" },
        { "nameplateUseClassColorForFriendlyPlayerUnitNames", "Friendly players: class colour on the name" },
        { "nameplateShowFriendlyRealmName", "Friendly players: show the realm name" },
        { "nameplateForceShowUnitName", "Always show the unit name" },
        { "nameplateShowDebuffsOnFriendly", "Show debuffs on friendly nameplates" },
        { "nameplateShowAllPersonalAuras", "Show all of your own auras on nameplates" },
    } },
    { "Targeting and combat", {
        { "softTargetEnemy", "Action targeting (the game picks enemies for you)", soft = true },
        { "showTargetOfTarget", "Show the target of target" },
        { "threatShowNumeric", "Threat percentage on the target frame" },
        { "displaySpellActivationOverlays", "Spell activation overlays (procs around the screen)" },
        { "assistedCombatHighlight", "Highlight the next suggested ability" },
    } },
    { "Bags", {
        { "combinedBags", "Combine all bags into one window" },
        { "ubOpenAll", "Opening one bag opens all of them", own = true },
    } },
    { "Action bars and chat", {
        { "lockActionBars", "Lock the action bars" },
        { "autoSelfCast", "Cast on yourself when there is no friendly target" },
        { "ActionButtonUseKeyDown", "Cast when the button is pressed, not released" },
        { "chatBubbles", "Chat bubbles over characters" },
    } },
}

local pct = function(v) return math.floor(v * 100 + 0.5) .. "%" end

local function cvarGet(name)
    local ok, v = pcall(function()
        if Settings and Settings.GetValue then
            local r = Settings.GetValue(name)
            if r ~= nil then return r end
        end
        return C_CVar and C_CVar.GetCVar(name)
    end)
    if not ok then return nil end
    return v
end

local function isOn(e)
    if e.own then return UbermocUIDB and UbermocUIDB.bagsOpenAll ~= false end
    local v = cvarGet(e[1])
    if v == nil then return false end
    if e.soft then
        local any = Enum and Enum.SoftTargetEnableFlags and Enum.SoftTargetEnableFlags.Any or 3
        return tonumber(v) == any
    end
    if type(v) == "boolean" then return v end
    return v == "1" or v == 1
end

local pending = {}
local function cvarSet(name, value)
    if InCombatLockdown() then pending[name] = value; return end
    local ok = pcall(function()
        if Settings and Settings.SetValue and Settings.GetValue(name) ~= nil then
            Settings.SetValue(name, value)
        else
            C_CVar.SetCVar(name, type(value) == "boolean" and (value and "1" or "0") or tostring(value))
        end
    end)
    if not ok then pcall(C_CVar.SetCVar, name, type(value) == "boolean" and (value and "1" or "0") or tostring(value)) end
end
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:SetScript("OnEvent", function()
    local list = pending
    pending = {}
    for k, v in pairs(list) do cvarSet(k, v) end
end)

local function buildPage()
    local panel = CreateFrame("Frame")
    panel.name = "Game Options"
    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 8, -8)
    scroll:SetPoint("BOTTOMRIGHT", -30, 8)
    local sc = CreateFrame("Frame", nil, scroll)
    sc:SetSize(600, 900)
    scroll:SetScrollChild(sc)

    local y = -4
    local boxes = {}
    API.newLabel(sc, "These are the game's own options. Changing one here changes it in the game's Options screen too.", 8, y, "GameFontHighlightSmall")
    y = y - 30
    local tabDefs = {}
    local ov
    for _, sec in ipairs(SECTIONS) do
        tabDefs[#tabDefs + 1] = { sec[1], #tabDefs == 0 and 0 or (y + 10) }
        API.newLabel(sc, sec[1], 8, y, "GameFontNormalLarge")
        y = y - 34
        for _, e in ipairs(sec[2]) do
            local cb = API.newCheck(sc, e[2], 8, y, function(v)
                if e.own then
                    UbermocUIDB.bagsOpenAll = v and true or false
                elseif e.soft then
                    local E = Enum and Enum.SoftTargetEnableFlags
                    cvarSet(e[1], v and (E and E.Any or 3) or (E and E.Gamepad or 1))
                else
                    cvarSet(e[1], v and true or false)
                end
            end)
            boxes[#boxes + 1] = { cb = cb, e = e }
            y = y - 30
        end
        if sec[1] == "Targeting and combat" then
            -- Spell overlay strength, under the spell activation overlays option
            API.newLabel(sc, "Spell overlay strength", 38, y - 4)
            ov = API.makeSlider(sc, 160, 0, 1, 0.05, pct, function(v) cvarSet("spellActivationOverlayOpacity", math.floor(v * 100 + 0.5) / 100) end)
            ov:SetPoint("TOPLEFT", 260, y)
            y = y - 40
        end
        y = y - 10
    end
    sc:SetHeight(-y + 20)
    if API.makeTabs and #tabDefs > 1 then API.makeTabs(panel, scroll, sc, tabDefs) end

    function panel.refresh()
        for _, b in ipairs(boxes) do b.cb:SetChecked(isOn(b.e)) end
        local o = tonumber(cvarGet("spellActivationOverlayOpacity"))
        API.setSlider(ov, o or 0.65)
    end
    panel:SetScript("OnShow", function() panel.refresh() end)
    API.addPage("gameopts", "Game Options", panel)
end

-- Opening one bag opens all of them: whenever a bag window shows, the other bags open too.
local opening = false
local function openRest()
    if opening or not (UbermocUIDB and UbermocUIDB.bagsOpenAll ~= false) then return end
    if not (OpenBag and IsBagOpen and C_Container and C_Container.GetContainerNumSlots) then return end
    opening = true
    pcall(function()
        for i = 0, NUM_TOTAL_BAG_FRAMES or 5 do
            if not IsBagOpen(i) and (C_Container.GetContainerNumSlots(i) or 0) > 0 then OpenBag(i) end
        end
    end)
    opening = false
end
local function hookBags()
    local list = { _G.ContainerFrameCombinedBags }
    for i = 1, NUM_CONTAINER_FRAMES or 13 do list[#list + 1] = _G["ContainerFrame" .. i] end
    for _, fr in ipairs(list) do
        if fr and fr.HookScript and not fr.ubOpenAll then
            fr.ubOpenAll = true
            fr:HookScript("OnShow", function() C_Timer.After(0, openRest) end)
        end
    end
end

local prev = API.onLogin
API.onLogin = function()
    if prev then prev() end
    -- once: combined bags on (the game's own setting; it can be switched back on this page)
    if UbermocUIDB and not UbermocUIDB.bagsCombinedV1 then
        UbermocUIDB.bagsCombinedV1 = true
        cvarSet("combinedBags", true)
    end
    pcall(hookBags)
    API.later("Game options", buildPage)
end
