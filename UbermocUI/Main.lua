-- Ubermoc UI - Copyright (c) 2026 Marcos. All rights reserved.
-- This file is protected by copyright. It may not be copied, modified, redistributed or reused, in whole or
-- in part, without the written permission of the author. See LICENSE.txt.
local ADDON = ...

----------------------------------------------------------------------
-- Data
----------------------------------------------------------------------
-- Priority order of states. An element uses the first ACTIVE state in this
-- list that it has a value for; "idle" is used when none of those apply.
local PRIORITY = { "dialogue", "combat", "healthrefill", "resourcerefill", "mounted", "moving", "instance", "group", "target", "resting" }
local STATE_KEYS = { unpack(PRIORITY) }
STATE_KEYS[#STATE_KEYS + 1] = "idle"

local LABELS = {
    dialogue = "Talking to an NPC", combat = "In combat",
    healthrefill = "Health not full", resourcerefill = "Resource not full",
    mounted = "Mounted / traveling", moving = "Moving (walk / run)",
    instance = "In an instance", group = "In a group", target = "Has a target",
    resting = "In a rested area", idle = "Otherwise (idle)",
}

-- UI elements that can be faded. Frame names are resolved at
-- runtime; missing ones are skipped.
-- Small helpers used in the hot paths, kept in one table (the file is near the 200 local limit).
local H = {}

local ELEMENTS = {
    { key = "minimap", label = "Minimap", frames = { "MinimapCluster" } },
    { key = "minizone", label = "Minimap location name", frames = { "MinimapCluster.ZoneTextButton", "MinimapZoneTextButton", "MinimapZoneText" } },
    { key = "minihead", label = "Minimap header bar", frames = { "MinimapCluster.BorderTop", "MinimapCluster.Background", "MinimapCluster.Header", "MinimapBorderTop" } },
    { key = "miniclock", label = "Minimap clock", frames = { "TimeManagerClockButton" } },
    { key = "minical", label = "Calendar button", frames = { "GameTimeFrame" } },
    { key = "minitrack", label = "Minimap tracking button", frames = { "MinimapCluster.Tracking" } },
    { key = "minidiff", label = "Instance difficulty", frames = { "MinimapCluster.InstanceDifficulty", "MiniMapInstanceDifficulty", "GuildInstanceDifficulty", "MiniMapChallengeMode" } },
    { key = "minilanding", label = "Expansion landing button", frames = { "ExpansionLandingPageMinimapButton" } },
    { key = "minimail", label = "Mail / crafting icons", frames = { "MinimapCluster.IndicatorFrame" } },
    { key = "minidiel", label = "Sun / moon (day and night)", frames = { "MinimapCluster.DielFrame" } },
    { key = "miniaddons", label = "Addon list square", frames = { "AddonCompartmentFrame" } },
    { key = "minizoom", label = "Minimap zoom buttons", frames = { "Minimap.ZoomIn", "Minimap.ZoomOut" } },
    { key = "queue", label = "Queue status eye", frames = { "QueueStatusButton" } },
    { key = "tracker", label = "Quest / objective tracker", frames = { "ObjectiveTrackerFrame" } },
    { key = "mainbar", label = "Main action bar", frames = { "MainActionBar", "MainMenuBar" } },
    { key = "sidebars", label = "Extra action bars", frames = { "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight", "MultiBarLeft", "MultiBar5", "MultiBar6", "MultiBar7" } },
    { key = "classbars", label = "Stance / pet / possess", frames = { "StanceBar", "PetActionBar", "PossessActionBar" } },
    { key = "vehiclebtn", label = "Vehicle exit button", frames = { "MainMenuBarVehicleLeaveButton" } },
    { key = "micro", label = "Micro menu", frames = { "MicroMenuContainer" } },
    { key = "bags", label = "Bag bar", frames = { "BagsBar" } },
    { key = "xpbar", label = "XP / reputation bar", frames = { "StatusTrackingBarManager" } },
    { key = "extra", label = "Extra / zone abilities", frames = { "ExtraAbilityContainer" } },
    { key = "chat", page = "chat", label = "Chat windows", frames = { "ChatFrame1", "ChatFrame2", "ChatFrame3", "ChatFrame4" } },
    { key = "chattabs", page = "chat", label = "Chat tabs", frames = { "GeneralDockManager", "ChatFrame1Tab", "ChatFrame2Tab", "ChatFrame3Tab", "ChatFrame4Tab" } },
    { key = "chatedit", page = "chat", label = "Chat edit box", frames = { "ChatFrame1EditBox" } },
    { key = "chatbtns", page = "chat", label = "Chat buttons", frames = { "ChatFrame1ButtonFrame", "ChatFrameMenuButton", "ChatFrameChannelButton", "QuickJoinToastButton" } },
    { key = "npenemy", label = "Enemy nameplates", plates = "enemy", frames = {} },
    { key = "npfriendly", label = "Friendly nameplates", plates = "friendly", frames = {} },
    { key = "player", label = "Player frame", frames = { "PlayerFrame" } },
    { key = "pet", label = "Pet frame", frames = { "PetFrame" } },
    { key = "target", label = "Target frame", frames = { "TargetFrame" } },
    { key = "tot", label = "Target of target", frames = { "TargetFrameToT" } },
    { key = "focus", label = "Focus frame", frames = { "FocusFrame" } },
    { key = "fot", label = "Focus target", frames = { "FocusFrameToT" } },
    { key = "boss", label = "Boss frames", frames = { "BossTargetFrameContainer" } },
    { key = "arena", label = "Arena frames", frames = { "CompactArenaFrame", "ArenaEnemyFramesContainer", "ArenaEnemyMatchFramesContainer", "ArenaEnemyPrepFramesContainer" } },
    { key = "party", label = "Party / raid frames", frames = { "PartyFrame", "CompactPartyFrame", "CompactRaidFrameContainer", "CompactRaidFrameManager" } },
    { key = "classres", label = "Class resource bar", frames = { "PlayerBottomManagedFrameContainer", "PlayerFrame.classPowerBar", "PlayerFrameBottomManagedFramesContainer", "ComboPointPlayerFrame", "RuneFrame", "PaladinPowerBarFrame", "WarlockPowerFrame", "MageArcaneChargesFrame", "MonkHarmonyBarFrame", "MonkStaggerBar", "EssencePlayerFrame", "DruidComboPointBarFrame", "RogueComboPointBarFrame" } },
    { key = "ringhud", label = "Player Halo Frame (Ubermoc UI)", frames = { "UbermocRingHUD", "UbermocPlayerStyleHUD" } },
    { key = "petframe", label = "Pet Halo Frame (Ubermoc UI)", frames = { "UbermocPetHUD" } },
    { key = "ringtarget", label = "Target Halo Frame (Ubermoc UI)", frames = { "UbermocRingHUD_target", "UbermocPlayerStyleHUD_target" } },
    { key = "ringtot", label = "Target of Target Halo Frame (Ubermoc UI)", frames = { "UbermocRingHUD_tot", "UbermocPlayerStyleHUD_tot" } },
    { key = "ringfocus", label = "Focus Halo Frame (Ubermoc UI)", frames = { "UbermocRingHUD_focus", "UbermocPlayerStyleHUD_focus" } },
    { key = "ringfot", label = "Focus Target Halo Frame (Ubermoc UI)", frames = { "UbermocRingHUD_fot", "UbermocPlayerStyleHUD_fot" } },
    { key = "ui_xp", custom = true, label = "Minimap experience bar (Ubermoc UI)", frames = { "UbermocXPBar", "UbermocXPGap" } },
    { key = "ui_strip", custom = true, label = "Minimap top strip (Ubermoc UI)", frames = { "UbermocTopStrip" } },
    { key = "ui_info", custom = true, label = "Minimap character info (Ubermoc UI)", frames = { "UbermocInfoBar" } },
    { key = "ui_box", custom = true, label = "Minimap addon box (Ubermoc UI)", frames = { "UbermocModBox", "UbermocModFlyout" } },
    { key = "ui_compass", custom = true, label = "Minimap compass letters (Ubermoc UI)", frames = { "UbermocCompass" } },
    { key = "ui_perf", custom = true, label = "Minimap frame rate and latency (Ubermoc UI)", frames = { "UbermocPerfText" } },
    { key = "ui_clock", custom = true, label = "Minimap clock text (Ubermoc UI)", frames = { "UbermocClockText" } },
    { key = "ui_minibar", custom = true, label = "Minimap info board (Ubermoc UI)", frames = { "UbermocMiniBar" } },
    { key = "ui_miniframe", custom = true, label = "Minimap rounded frame (Ubermoc UI)", frames = { "UbermocMiniFrame" } },
    { key = "ui_minicoords", custom = true, label = "Minimap coordinates (Ubermoc UI)", frames = { "UbermocMiniCoords" } },
    { key = "partyframes", label = "Party Halo Frames (Ubermoc UI)", frames = { "UbermocPartyHUD" } },
    { key = "raidframes", label = "Raid Halo Frames (Ubermoc UI)", frames = { "UbermocRaidHUD" } },
    { key = "totem", label = "Totem bar", frames = { "TotemFrame" } },
    { key = "prd", label = "Personal resource display", frames = { "PersonalResourceDisplayFrame" } },
    { key = "buffs", label = "Buffs", frames = { "BuffFrame" } },
    { key = "debuffs", label = "Debuffs", frames = { "DebuffFrame" } },
    { key = "castbar", label = "Player cast bar", frames = { "PlayerCastingBarFrame" } },
    { key = "cd_essential", label = "Essential cooldowns", frames = { "EssentialCooldownViewer" } },
    { key = "cd_utility", label = "Utility cooldowns", frames = { "UtilityCooldownViewer" } },
    { key = "cd_buffs", label = "Tracked buffs", frames = { "BuffIconCooldownViewer" } },
    { key = "cd_bars", label = "Tracked buff bars", frames = { "BuffBarCooldownViewer" } },
    { key = "procs", label = "Spell proc glows", frames = { "SpellActivationOverlayFrame" } },
    { key = "loc", label = "Loss of control", frames = { "LossOfControlFrame" } },
    { key = "meter", label = "Damage meter", frames = { "DamageMeter" } },
    { key = "encounter", label = "Encounter bar", frames = { "EncounterBar" } },
    { key = "encwarn", label = "Encounter warnings", frames = { "CriticalEncounterWarnings", "MediumEncounterWarnings", "MinorEncounterWarnings", "EncounterWarningsFrame", "EncounterWarnings" } },
    { key = "raidwarn", label = "Raid warnings / emotes", frames = { "RaidWarningFrame", "RaidBossEmoteFrame" } },
    { key = "talkinghead", label = "Talking head", frames = { "TalkingHeadFrame" } },
    { key = "errors", label = "Error messages", frames = { "UIErrorsFrame" } },
    { key = "zonetext", label = "Zone name banner", frames = { "ZoneTextFrame", "SubZoneTextFrame" } },
    { key = "banners", label = "Boss / level-up banners", frames = { "BossBanner", "LevelUpDisplay" } },
    { key = "alerts", label = "Alerts and toasts", frames = { "AlertFrame" } },
    { key = "lootroll", label = "Loot roll windows", frames = { "GroupLootContainer" } },
    { key = "lootwin", label = "Loot window", frames = { "LootFrame" } },
    { key = "widgettop", label = "Top-center widgets", frames = { "UIWidgetTopCenterContainerFrame" } },
    { key = "widgetmini", label = "Widgets below minimap", frames = { "UIWidgetBelowMinimapContainerFrame" } },
    { key = "widgetpower", label = "Power bar widgets", frames = { "UIWidgetPowerBarContainerFrame" } },
    { key = "altpower", label = "Alternate power bar", frames = { "PlayerPowerBarAlt" } },
    { key = "vehicle", label = "Vehicle seats", frames = { "VehicleSeatIndicator" } },
    { key = "durability", label = "Durability", frames = { "DurabilityFrame" } },
    { key = "mirror", label = "Breath / mirror timers", frames = { "MirrorTimerContainer" } },
    { key = "archaeology", label = "Archaeology progress", frames = { "ArcheologyDigsiteProgressBar" } },
    { key = "fps", label = "Framerate display", frames = { "FramerateFrame" } },
    -- The floating unit frames (TargetFrame.lua) and the addon's own action bars (ActionBars.lua).
    { key = "flplayer", custom = true, label = "Player Floating Frame (Ubermoc UI)", frames = { "UbermocFloat_player" } },
    { key = "flpet", custom = true, label = "Pet Floating Frame (Ubermoc UI)", frames = { "UbermocFloat_pet" } },
    { key = "fltarget", custom = true, label = "Target Floating Frame (Ubermoc UI)", frames = { "UbermocTargetNameplate_target" } },
    { key = "fltot", custom = true, label = "Target of Target Floating Frame (Ubermoc UI)", frames = { "UbermocTargetNameplate_targettarget" } },
    { key = "flfocus", custom = true, label = "Focus Floating Frame (Ubermoc UI)", frames = { "UbermocTargetNameplate_focus" } },
    { key = "flfot", custom = true, label = "Focus Target Floating Frame (Ubermoc UI)", frames = { "UbermocTargetNameplate_focustarget" } },
    { key = "flparty", custom = true, label = "Party Floating Frames (Ubermoc UI)", frames = { "UbermocFloat_party1", "UbermocFloat_party2", "UbermocFloat_party3", "UbermocFloat_party4" } },
    { key = "flraid", custom = true, label = "Raid Floating Frames (Ubermoc UI)", frames = {} },
    { key = "abarcustom", custom = true, label = "Ubermoc UI action bars", frames = { "UbermocActionBars" } },
}
for i = 1, 40 do ELEMENTS[#ELEMENTS - 1].frames[i] = "UbermocFloat_raid" .. i end

-- Chat elements live on the Chat page; everything else is on the main page.
local MAIN_LIST, CHAT_LIST, CHAT_KEYS = {}, {}, {}
for _, e in ipairs(ELEMENTS) do
    if e.page == "chat" then
        CHAT_LIST[#CHAT_LIST + 1] = e
        CHAT_KEYS[e.key] = true
    else
        MAIN_LIST[#MAIN_LIST + 1] = e
    end
end

local function copyTable(t)
    local c = {}
    for k, v in pairs(t) do c[k] = v end
    return c
end

-- Addon button container tucked inside the map. Once for every setup: a container still on the old starting place
-- (top right, 3 and 21) moves to the bottom left, inside the map's corner, with a nudge of -2 across; any other
-- place is kept as it was. The nudge is measured from the corner spot, so it comes out right on every map shape.
function H.boxInsideMigrate(c)
    if c.insideV1 then return end
    c.insideV1, c.dirV2 = true, true
    if (c.corner or "TOPRIGHT") == "TOPRIGHT" and (c.x or 3) == 3 and (c.y or 21) == 21 then
        c.inside, c.corner, c.dir, c.x, c.y = true, "BOTTOMLEFT", "ABOVE", -2, 0
    else
        c.inside = false
    end
end
-- How far in from the map's corner the container sits when it is inside the map: far enough to clear the rounded
-- corner (a round map comes in 15% of its width, a rounded square a few pixels).
function H.boxInsideSpot(size, round, corner)
    local ix, iy = 6, 4
    if round then ix = math.floor((size or 140) * 0.15 + 0.5); iy = ix end
    return (corner:find("LEFT") and ix or -ix), (corner:find("BOTTOM") and iy or -iy)
end

-- Looks up a frame by global name or by a path such as "MinimapCluster.ZoneTextButton".
UbermocUIAPI = UbermocUIAPI or {}
UbermocUIAPI.parts = {}

-- Frame names like "MinimapCluster.IndicatorFrame" are split once and remembered, because this is
-- called many times a second and splitting a string each time creates garbage.
local function getFrame(name)
    local parts = UbermocUIAPI.parts[name]
    if not parts then
        parts = {}
        for part in string.gmatch(name, "[^%.]+") do parts[#parts + 1] = part end
        UbermocUIAPI.parts[name] = parts
    end
    local f = _G
    for i = 1, #parts do
        if type(f) ~= "table" then return nil end
        f = f[parts[i]]
        if f == nil then return nil end
    end
    if f == _G or type(f) ~= "table" then return nil end
    return f
end
UbermocUIAPI.frameByName = getFrame

-- Minimap text shadow: one strength for all the letters on and around the map.
do
    local reg = setmetatable({}, { __mode = "k" })
    local function strength(group)
        if group == "uf" then
            -- 0.99.142: the new starting look (no shadow, thin border) is put on once for everyone
            if UbermocUIDB and UbermocUIDB.version and not UbermocUIDB.ufLook2 then
                UbermocUIDB.ufLook2 = true
                UbermocUIDB.ufShadow, UbermocUIDB.ufBorder = nil, nil
            end
            local v = UbermocUIDB and UbermocUIDB.ufShadow
            if v == nil then v = 0 end   -- unit frame text: no shadow unless you add one (the thin border reads well)
            return v
        end
        local m = UbermocUIDB and UbermocUIDB.mm
        local v = m and m.shadow
        if v == nil then v = 10 end
        return v
    end
    UbermocUIAPI.mmShadowValue = strength
    local function paint(fs, rec)
        if rec.group == "strip" then
            -- The strip text above the experience bar: a heavy outline (not a shadow) so it reads on any background.
            local x = UbermocUIDB and UbermocUIDB.mm and UbermocUIDB.mm.xp
            if rec.path then pcall(fs.SetFont, fs, rec.path, rec.size, "OUTLINE") end
            fs:SetShadowOffset(0, 0)
            return
        end
        local v = strength(rec.group)
        -- No shadows anywhere: text gets a thin outline instead (unit frame text follows its border setting).
        local isUF = rec.group == "uf"
        local bd = isUF and UbermocUIAPI.ufBorderValue() or nil
        local flags
        if isUF then flags = UbermocUIAPI.UF_BORDER_FLAGS[bd or "off"] or ""
        else flags = (v > 0) and "OUTLINE" or "" end
        if rec.path then pcall(fs.SetFont, fs, rec.path, rec.size, flags)
        else
            local path, size = fs:GetFont()
            if path then pcall(fs.SetFont, fs, path, size, flags) end
        end
        fs:SetShadowOffset(0, 0)
        fs:SetShadowColor(0, 0, 0, 0)
    end
    -- shade(fs) sets only the shadow; shade(fs, path, size) also sets the font.
    -- val = true marks a health / resource number (it takes the unit frame text border).
    -- unset means thin (the starting look); "off" is stored when you turn it off
    function UbermocUIAPI.ufBorderValue() return (UbermocUIDB and UbermocUIDB.ufBorder) or "thin" end
    UbermocUIAPI.UF_BORDER_FLAGS = { thin = "OUTLINE", sharp = "OUTLINE, MONOCHROME", medium = "OUTLINE", thick = "THICKOUTLINE" }
    UbermocUIAPI.UF_BORDERS = { { "off", "Border: off" }, { "thin", "Border: thin" }, { "sharp", "Border: sharp" },
                                { "medium", "Border: medium" }, { "thick", "Border: thick" } }
    function UbermocUIAPI.shade(fs, path, size, group, val)
        if not fs then return end
        local rec = reg[fs]
        if not rec then rec = {}; reg[fs] = rec end
        if group then rec.group = group end
        if val then rec.val = true end
        if path then rec.path, rec.size = path, size end
        paint(fs, rec)
    end
    function UbermocUIAPI.shadeAll()
        for fs, rec in pairs(reg) do paint(fs, rec) end
    end
    -- A dark outline of adjustable strength: eight copies of the text one pixel around it. pct 0 turns it off.
    local OUT_OFFS = { { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 }, { -1, -1 }, { 1, 1 }, { -1, 1 }, { 1, -1 } }
    function UbermocUIAPI.outline(fs, pct)
        if not fs then return end
        local a = math.max(0, math.min(1, (pct or 0) / 100))
        local o = fs.ubOut
        if not o then
            if a <= 0 then return end
            o = {}
            local par = fs:GetParent() or UIParent
            for i, off in ipairs(OUT_OFFS) do
                local t = par:CreateFontString(nil, "ARTWORK")
                t:SetDrawLayer("ARTWORK", -1)
                t.ox, t.oy = off[1], off[2]
                o[i] = t
            end
            fs.ubOut = o
        end
        local path, size, flags = fs:GetFont()
        local just = fs:GetJustifyH()
        for _, t in ipairs(o) do
            if a > 0 and fs:IsShown() then
                if path then pcall(t.SetFont, t, path, size, "") end
                t:SetShadowOffset(0, 0)
                t:SetJustifyH(just)
                t:SetWordWrap(false)
                t:ClearAllPoints()
                t:SetPoint("TOPLEFT", fs, "TOPLEFT", t.ox, t.oy)
                t:SetPoint("BOTTOMRIGHT", fs, "BOTTOMRIGHT", t.ox, t.oy)
                t:SetText(fs:GetText() and (fs:GetText():gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) or "")
                t:SetTextColor(0, 0, 0, a)
                t:Show()
            else
                t:Hide()
            end
        end
    end
    -- One text shadow setting for every unit frame (halo, pet, party and raid frames).
    function UbermocUIAPI.ufShadowSlider(parent, y, x)
        UbermocUIAPI.newLabel(parent, "Text outline (all unit frames)", x or 40, y)
        local s = CreateFrame("Frame", nil, parent)   -- (the old shadow slider is gone: there are no shadows now)
        s:SetSize(1, 1)
        s:Hide()
        -- Beside it: a thin border around the health and resource numbers (off, thin, sharp, medium, thick).
        local cyc = UbermocUIAPI.cycler and UbermocUIAPI.cycler(parent, (x or 40) + 230, y + 2, 130,
            function() return UbermocUIAPI.UF_BORDERS end,
            function() return UbermocUIAPI.ufBorderValue() end,
            function(v)
                UbermocUIDB.ufBorder = v
                UbermocUIAPI.shadeAll()
            end)
        parent:HookScript("OnShow", function()
            if cyc then cyc.refresh() end
        end)
        if cyc then cyc.refresh() end
        return s
    end
end
-- Room to leave around the health percent so the threat circle drawn around it never covers the name or
-- the level square (enemy nameplates in name-only mode). Returns sideways and up / down room.
function UbermocUIAPI.threatPad(group, look)
    if group ~= "enemy" or not (look and look.nameOnly and look.showPct) then return 0, 0 end
    local t = UbermocUIDB and UbermocUIDB.npThreat
    if not (t and t.on) or not UbermocUIAPI.threatRingSize then return 0, 0 end
    local size = UbermocUIAPI.threatRingSize()
    local ps = look.pctSize or 12
    return math.max(0, math.ceil((size - ps * 2.6) / 2)), math.max(0, math.ceil((size - ps * 1.1) / 2))
end
-- The nameplate of your current target can be drawn bigger (Nameplates > Look > Target scale).
function UbermocUIAPI.scaleTargetPlate(plate, np)
    local uf = plate and plate.UnitFrame
    if not (uf and np and np.look) then return end
    local unit = plate.namePlateUnitToken or uf.unit
    local isT = false
    if unit and UnitIsUnit then
        local ok, r = pcall(UnitIsUnit, unit, "target")
        isT = ok and r == true
    end
    local want = isT and math.max(0.5, (np.look.targetScale or 100) / 100) or 1
    if uf.ubermocScale ~= want then
        uf.ubermocScale = want
        pcall(uf.SetScale, uf, want)
    end
end
-- How far the bars around the square map sit from its edge: the border's thickness when the border
-- can be seen, nothing when the map background (and so the border) is see-through, so they sit flush.
function UbermocUIAPI.mapEdge()
    local D = UbermocUIDB
    if not (D and D.mm and UbermocUIAPI.mmBorder) then return 0 end
    local _, _, _, _, on, size = UbermocUIAPI.mmBorder()
    return on and (size or 0) or 0
end
UbermocUIAPI.ELEMENTS = ELEMENTS

-- Four textures as an outline of thickness t just outside `anchor`.
function UbermocUIAPI.drawEdges(e, anchor, t, r, g, b, a)
    for i = 1, 4 do e[i]:SetVertexColor(r, g, b, a or 1); e[i]:ClearAllPoints(); e[i]:Show() end
    e[1]:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", -t, 0); e[1]:SetPoint("BOTTOMRIGHT", anchor, "TOPRIGHT", t, 0); e[1]:SetHeight(t)
    e[2]:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", -t, 0); e[2]:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", t, 0); e[2]:SetHeight(t)
    e[3]:SetPoint("TOPRIGHT", anchor, "TOPLEFT", 0, 0); e[3]:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMLEFT", 0, 0); e[3]:SetWidth(t)
    e[4]:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 0, 0); e[4]:SetPoint("BOTTOMLEFT", anchor, "BOTTOMRIGHT", 0, 0); e[4]:SetWidth(t)
end

-- Colour picker in front of our settings window (it otherwise opens behind it and can't be used).
-- a = nil: colour only; a = 0..1: the picker shows an opacity bar too. fn(r, g, b, a) runs on every change.
function UbermocUIAPI.pickColor(r, g, b, a, fn)
    local cp = ColorPickerFrame
    if not (cp and cp.SetupColorPickerAndShow) then return end
    local pr, pg, pb, pa = r, g, b, a
    local function cur()
        local nr, ng, nb = cp:GetColorRGB()
        local na = a
        if a ~= nil and cp.GetColorAlpha then
            local ok, v = pcall(cp.GetColorAlpha, cp)
            if ok and type(v) == "number" then na = v end
        end
        return nr, ng, nb, na
    end
    cp:SetupColorPickerAndShow({
        r = r, g = g, b = b, hasOpacity = a ~= nil, opacity = a,
        swatchFunc = function() fn(cur()) end,
        opacityFunc = function() fn(cur()) end,
        cancelFunc = function() fn(pr, pg, pb, pa) end,
    })
    UbermocUIAPI.raisePicker()
end
function UbermocUIAPI.raisePicker()
    local cp = ColorPickerFrame
    if not cp then return end
    local win = _G.UbermocUIWindow
    if not (win and win:IsShown()) then return end
    pcall(cp.SetFrameStrata, cp, "FULLSCREEN_DIALOG")
    pcall(cp.SetToplevel, cp, true)
    pcall(cp.SetFrameLevel, cp, (win:GetFrameLevel() or 1) + 100)
    pcall(cp.Raise, cp)
end
-- Every colour square in the addon (any page) gets the picker in front of the window.
if ColorPickerFrame then
    if ColorPickerFrame.SetupColorPickerAndShow then
        pcall(hooksecurefunc, ColorPickerFrame, "SetupColorPickerAndShow", function() UbermocUIAPI.raisePicker() end)
    end
    pcall(ColorPickerFrame.HookScript, ColorPickerFrame, "OnShow", function() UbermocUIAPI.raisePicker() end)
end

-- Look of one group of nameplates (Nameplates page, "Look" section).
local function lookDefaults()
    return {
        hideName = false, hideBar = false, nameSize = 0, castHeight = 0, castTimer = true, castTotal = false, castW = 0, castX = 0, castPad = 6,
        targetW = 0, targetH = 0, mouseW = 0, mouseH = 0, targetScale = 100,
        nameOnly = true, classColor = true, nameGradient = true, missColor = "WHITE", showPct = true, pctColor = "REACTION",
        pctPos = "RIGHT", pctX = 0, pctY = 0, pctSize = 12, showLevel = true, levelSide = "RIGHT", levelX = 0, levelY = 0, levelSize = 22,
        lvlR = 0.55, lvlG = 0.55, lvlB = 0.6,
    }
end

local function defaults()
    return {
        version = 3, enabled = true, fadeTime = 0.4,
        mouse = { on = true, alpha = 1.0 }, -- reveal while hovering the UI
        elements = {}, -- elements[elementKey][stateKey] = opacity (0..1)
        chat = {
            hideTabs = true, tabsFollow = true,
            linesOn = true, visibleTime = 5, fadeTime = 3,
            revealOnMessage = true, revealSeconds = 5, revealAlpha = 1,
        },
        mm = {
            xp = { on = true, attach = true, reserve = true, w = 140, h = 18, x = 0, y = 0, text = true, rested = true, icons = true, phase = true, coords = true },
            clock = { move = false, own = true, v = "TOP", h = "CENTER", x = 0, y = -4 },
            coords = { move = false, v = "BOTTOM", h = "CENTER", x = 0, y = 4 },
            loc = { on = false, w = 150, x = 0, y = 4 },
            box = { border = true, round = true, on = true, corner = "TOPRIGHT", dir = "BELOW", size = 18, cols = 4, x = 3, y = 21 },
            border = { size = 1, on = false, r = 0, g = 0, b = 0, a = 1 },
            bg = { r = 0, g = 0, b = 0, a = 0 },
            perf = { on = true },
            zone = { inside = true },
            compass = { on = true },
            info = { on = true, side = "BOTTOM", gold = true, bags = true, dura = true, thick = 22, isize = 16, x = 0, y = 0, gx = 0, gy = 0, bx = 0, by = 0, dx = 0, dy = 0, fs = 12, bg = 95, money = "GS" },
            mail = { x = 0, y = 0 }, addons = { x = 0, y = 0 }, diel = { x = 0, y = 0 },
        },
        vendor = { sellGray = true, sellMsg = true, repair = true, repairGuild = true, repairMsg = true },
        minimap = { angle = 215, hide = false }, -- minimap button
        squareMinimap = true, -- Miscellaneous: square minimap shape
        tooltipAtCursor = true, -- Miscellaneous: tooltips follow the mouse cursor
        nameplates = { showEnemies = true, showFriends = true, showFriendNpcs = true, friendlyClickThrough = true, -- scale is only stored once you change it
            enemy = {
                width = 260, height = 11,
                look = (function() local l = lookDefaults(); l.castTimer = true; return l end)(),
                quest = { on = true, progress = true, size = 20, position = "RIGHT", offsetX = -6, offsetY = 0 },
                elite = { on = true, size = 16, position = "RIGHT", offsetX = 4, offsetY = 0 },
                rare = { on = true, size = 16, position = "RIGHT", offsetX = 4, offsetY = 0 },
            },
            friendly = {
                width = 150, height = 11,
                look = lookDefaults(),
                quest = { on = true, progress = true, size = 20, position = "RIGHT", offsetX = -6, offsetY = 0 },
                elite = { on = false, size = 16, position = "RIGHT", offsetX = 4, offsetY = 0 },
                rare = { on = false, size = 16, position = "RIGHT", offsetX = 4, offsetY = 0 },
            },
        },
    }
end

local function normalize()
    if type(UbermocUIDB) ~= "table" then
        UbermocUIDB = defaults()
        return
    end
    local DB, d = UbermocUIDB, defaults()
    -- A table that exists but was never filled in (something created it before the first start): fill it in.
    if type(DB.elements) ~= "table" then DB.elements = {} end
    -- Fill the settings groups first, so a failure further down never leaves the map or vendor settings half made.
    if type(DB.mm) ~= "table" then DB.mm = {} end
    for grp, vals in pairs(d.mm) do
        if type(DB.mm[grp]) ~= "table" then DB.mm[grp] = {} end
        for k, v in pairs(vals) do if DB.mm[grp][k] == nil then DB.mm[grp][k] = v end end
    end
    for k, v in pairs(d) do if DB[k] == nil then DB[k] = v end end
    -- The old global fade settings no longer exist.
    DB.states, DB.order, DB.idle = nil, nil, nil
    DB.positions = nil -- field from an older version, no longer used
    local el = DB.elements
    -- 0.11 briefly merged some elements; split their settings back out.
    local SPLIT = {
        minizone = { "minihead" },
        minibtns = { "miniclock", "minical", "minitrack", "minidiff", "minilanding", "minimail", "minizoom" },
        bossarena = { "boss", "arena" },
        classres = { "totem" },
        cd_abilities = { "cd_essential", "cd_utility" },
        cd_tracked = { "cd_buffs", "cd_bars" },
        loot = { "lootroll", "lootwin" },
        widgets = { "widgettop", "widgetmini", "widgetpower", "altpower" },
        minor = { "durability", "mirror", "archaeology", "fps" },
    }
    for merged, parts in pairs(SPLIT) do
        if el[merged] then
            for _, part in ipairs(parts) do
                if not el[part] then el[part] = copyTable(el[merged]) end
            end
            if merged ~= "minizone" and merged ~= "classres" then el[merged] = nil end
        end
    end
    if el.buffs and not el.debuffs then el.debuffs = copyTable(el.buffs) end
    el.tooltip = nil

    -- Situations that were combined: low health -> health not full,
    -- flight path -> mounted / traveling, raid group -> group.
    local RENAMED = { lowhealth = "healthrefill", taxi = "mounted", raid = "group" }
    local function renameStates(o)
        if type(o) ~= "table" then return end
        for old, new in pairs(RENAMED) do
            if o[old] ~= nil then
                if o[new] == nil then o[new] = o[old] end
                o[old] = nil
            end
        end
    end
    for _, o in pairs(el) do renameStates(o) end
    if type(DB.clipboard) == "table" then renameStates(DB.clipboard.data) end
    -- Has a buff / Has a debuff were removed in 0.14.
    local function dropAura(o)
        if type(o) == "table" then o.hasbuff = nil; o.hasdebuff = nil end
    end
    for k, o in pairs(el) do
        dropAura(o)
        if type(o) == "table" and next(o) == nil then el[k] = nil end
    end
    if type(DB.clipboard) == "table" then dropAura(DB.clipboard.data) end
    DB.lowHealthPct = nil
    for k, v in pairs(d) do if DB[k] == nil then DB[k] = v end end
    if type(DB.mouse) ~= "table" then DB.mouse = d.mouse end
    if type(DB.minimap) ~= "table" then DB.minimap = d.minimap end
    if type(DB.nameplates) ~= "table" then DB.nameplates = {} end
    local np = DB.nameplates
    if type(np.enemy) ~= "table" then
        -- Older versions kept the quest icon settings directly on the nameplates table.
        if type(np.quest) ~= "table" then
            np.quest = {
                on = np.questIndicator ~= false, progress = np.showProgress ~= false,
                size = np.indicatorSize or 24, position = np.position or "LEFT",
                offsetX = np.offsetX or 0, offsetY = np.offsetY or 0,
            }
        end
        -- 0.15 and older had one set of icons for every nameplate; both groups start from it.
        np.enemy = { quest = np.quest, elite = np.elite, rare = np.rare }
        np.friendly = copyTable(np.enemy)
    end
    np.quest, np.elite, np.rare = nil, nil, nil
    np.scale, np.friendlyScale = nil, nil -- replaced by width and height
    np.questIndicator, np.showProgress, np.indicatorSize = nil, nil, nil
    np.position, np.offsetX, np.offsetY = nil, nil, nil
    for group, kinds in pairs(d.nameplates) do
      if type(kinds) == "table" then
        if type(np[group]) ~= "table" then np[group] = {} end
        for kind, dv in pairs(kinds) do
            if type(dv) ~= "table" then
                if np[group][kind] == nil then np[group][kind] = dv end
            else
                if type(np[group][kind]) ~= "table" then np[group][kind] = copyTable(dv) end
                for k, v in pairs(dv) do if np[group][kind][k] == nil then np[group][kind][k] = v end end
            end
        end
      end
    end
    -- One time: the info bar lays gold left, bags middle and durability right, so old nudges are cleared.
    if not DB.infoV2 and DB.mm and DB.mm.info then
        DB.infoV2 = true
        local i = DB.mm.info
        i.gx, i.gy, i.bx, i.by, i.dx, i.dy = 0, 0, 0, 0, 0, 0
    end
    -- One time: the new icon positions and quest offset replace the old untouched defaults.
    -- One time: the removed "hide the health bar" and "show current / total" choices are switched off.
    if not DB.npV3 then
        DB.npV3 = true
        for _, group in ipairs({ "enemy", "friendly" }) do
            local lk = np[group] and np[group].look
            if lk then lk.hideBar = false; lk.castTotal = false end
        end
    end
    if not DB.npV2 then
        DB.npV2 = true
        for _, group in ipairs({ "enemy", "friendly" }) do
            local g = np[group]
            if g.quest and (g.quest.offsetY or 0) == 0 then g.quest.offsetY = -5 end
            for _, kind in ipairs({ "elite", "rare" }) do
                local c = g[kind]
                if c and (c.offsetX or 0) == 0 and (c.offsetY or 0) == 0 then
                    c.offsetX, c.offsetY = -33, 15
                    if kind == "rare" and c.position == "TOP" then c.position = "RIGHT" end
                end
            end
        end
    end
    -- One time: the quest icon's own base position now carries the old -5 up / down shift, so its offsets
    -- start at zero; the elite and rare icons get their new default offsets.
    if not DB.npV4 then
        DB.npV4 = true
        for _, group in ipairs({ "enemy", "friendly" }) do
            local g = np[group]
            if g.quest and g.quest.offsetY == -5 then g.quest.offsetY = 0 end
            for _, kind in ipairs({ "elite", "rare" }) do
                local c = g[kind]
                if c and c.offsetX == -33 and c.offsetY == 15 then c.offsetX, c.offsetY = -38, 14 end
            end
        end
    end
    -- One time: new default places for the quest (65 across), elite and rare (55 across) icons replace the old untouched defaults.
    if not DB.npV5 then
        DB.npV5 = true
        for _, group in ipairs({ "enemy", "friendly" }) do
            local g = np[group]
            if g.quest and g.quest.offsetX == 0 and g.quest.offsetY == 0 then g.quest.offsetX = 65 end
            for _, kind in ipairs({ "elite", "rare" }) do
                local c = g[kind]
                if c and c.offsetX == -38 and c.offsetY == 14 then c.offsetX, c.offsetY = 55, 0 end
            end
        end
    end
    -- One time: the icons now chain after the level box (elite and rare on top of each other, the quest
    -- marker after them), so the old fixed offsets are replaced by small gaps.
    if not DB.npV6 then
        DB.npV6 = true
        for _, group in ipairs({ "enemy", "friendly" }) do
            local g = np[group]
            for _, kind in ipairs({ "quest", "elite", "rare" }) do
                local c = g[kind]
                if c then c.position, c.offsetX, c.offsetY = "RIGHT", 4, 0 end
            end
        end
        if np.enemy.elite then np.enemy.elite.on = true end
        if np.enemy.quest then np.enemy.quest.offsetX = -6 end
        if np.enemy.rare then np.enemy.rare.on = true end
        for _, group in ipairs({ "enemy", "friendly" }) do
            if np[group].look then np[group].look.nameOnly = true end
        end
    end
    -- One time: nameplates show the name only, without a health bar (the new default).
    if not DB.npNameOnlyV2 then
        DB.npNameOnlyV2 = true
        local np2 = DB.nameplates
        if type(np2) == "table" then
            for _, group in ipairs({ "enemy", "friendly" }) do
                if type(np2[group]) == "table" and type(np2[group].look) == "table" then np2[group].look.nameOnly = true end
            end
        end
    end
    -- One time: the info bar under the map is thinner so it sits tight against the map.
    if not DB.mmTightV1 then
        DB.mmTightV1 = true
        if DB.mm and DB.mm.info and DB.mm.info.thick == 28 then DB.mm.info.thick = 22 end
    end
    -- One time: the minimap border is its own setting now: on, thin (1 px), black.
    if not DB.mmBorderV1 then
        DB.mmBorderV1 = true
        if DB.mm and DB.mm.border then
            local b = DB.mm.border
            if b.size == 3 or b.size == 2 then b.size = 1 end
            if b.on == nil then b.on = true end
            b.r, b.g, b.b = b.r or 0, b.g or 0, b.b or 0
        end
    end
    -- One time: the minimap border is off unless you turn it on.
    if not DB.mmBorderV2 then
        DB.mmBorderV2 = true
        if DB.mm and DB.mm.border then DB.mm.border.on = false end
    end
    -- One time: enemy nameplates show the cast timer.
    if not DB.npV9 then
        DB.npV9 = true
        local e = DB.nameplates and DB.nameplates.enemy
        if e and e.look then e.look.castTimer = true end
    end
    -- One time: the nameplate cast bar starts 160 px wide and 6 px to the right (where it was left as it came).
    if not DB.npCastV1 then
        DB.npCastV1 = true
        for _, g in ipairs({ "enemy", "friendly" }) do
            local e = DB.nameplates and DB.nameplates[g]
            local l = e and e.look
            if l and (l.castW or 0) == 0 and (l.castX or 0) == 0 then l.castW, l.castX = 160, 6 end
        end
    end
    -- One time: the cast bar follows the plate: as wide as the health bar plus a little on each side (the fixed 160 px was far
    -- wider than small nameplates).
    if not DB.npCastV2 then
        DB.npCastV2 = true
        for _, g in ipairs({ "enemy", "friendly" }) do
            local e = DB.nameplates and DB.nameplates[g]
            local l = e and e.look
            if l then
                if (l.castW or 0) == 160 and (l.castX or 0) == 6 then l.castW, l.castX = 0, 0 end
                if l.castPad == nil then l.castPad = 6 end
            end
        end
    end
    -- One time: the addon button container starts round.
    if not DB.boxRoundV1 then
        DB.boxRoundV1 = true
        if DB.mm and DB.mm.box then DB.mm.box.round = true end
    end
    -- One time: friendly nameplates, friendly NPC nameplates and "friendly nameplates ignore clicks" start on.
    if not DB.npV11 then
        DB.npV11 = true
        if DB.nameplates then
            DB.nameplates.showFriends = true
            DB.nameplates.showFriendNpcs = true
            DB.nameplates.friendlyClickThrough = true
        end
    end
    -- One time: the cast timer is on for both groups.
    if not DB.npV10 then
        DB.npV10 = true
        for _, g in ipairs({ "enemy", "friendly" }) do
            local e = DB.nameplates and DB.nameplates[g]
            if e and e.look then e.look.castTimer = true end
        end
    end
    -- One time: the quest progress icon starts at 20 px.
    if not DB.npV8 then
        DB.npV8 = true
        local np = DB.nameplates
        for _, grp in ipairs({ "enemy", "friendly" }) do
            local q = np and np[grp] and np[grp].quest
            if q and q.size == 24 then q.size = 20 end
        end
    end
    -- One time: the quest marker now sits snug against the elite / rare icon.
    if not DB.npV7 then
        DB.npV7 = true
        for _, group in ipairs({ "enemy", "friendly" }) do
            local q = np[group] and np[group].quest
            if q and q.offsetX == 4 and q.offsetY == 0 then q.offsetX = -6 end
        end
    end
    if type(DB.mm) ~= "table" then DB.mm = {} end
    for grp, vals in pairs(d.mm) do
        if type(DB.mm[grp]) ~= "table" then DB.mm[grp] = {} end
        for k, v in pairs(vals) do if DB.mm[grp][k] == nil then DB.mm[grp][k] = v end end
    end
    if type(DB.vendor) ~= "table" then DB.vendor = {} end
    for k, v in pairs(d.vendor) do if DB.vendor[k] == nil then DB.vendor[k] = v end end
    if type(DB.chat) ~= "table" then DB.chat = {} end
    for k, v in pairs(d.chat) do if DB.chat[k] == nil then DB.chat[k] = v end end
    if not DB.chat.v73 then
        DB.chat.v73 = true
        for k, v in pairs(d.chat) do DB.chat[k] = v end
    end
    if DB.fadeInTime == nil then DB.fadeInTime = DB.fadeTime end
    if DB.fadeOutTime == nil then DB.fadeOutTime = DB.fadeTime end
    if DB.fadeDelay == nil then DB.fadeDelay = 0 end
    DB.version = 3
end

----------------------------------------------------------------------
-- Trigger checks
----------------------------------------------------------------------
-- Druid travel/aquatic/flight/mount forms and shaman ghost wolf.
local TRAVEL_FORMS = { [3] = true, [4] = true, [16] = true, [27] = true, [29] = true, [36] = true }

local isMoving = false -- kept up to date by the poll frame below

-- Resources that refill upward when you are idle: mana, focus, energy, essence.
local REFILL_POWER = { [0] = true, [2] = true, [3] = true, [19] = true }

-- WoW 12 can hide health and power from addons (in combat, for example). When a
-- value is hidden, "not full" cannot be known, so the situation simply is not active.
local function isHidden(v)
    return issecretvalue and issecretvalue(v)
end

-- When WoW hides the numbers, a status bar that the game fills itself can still tell us how full
-- it is: the width of its fill is a normal number.
local probeBars = {}

-- The game's own player frame bars are filled by the game even when the numbers are hidden; how wide
-- their fill is can still be measured.
function H.realBarBody(kind, ptype)
        local pf = _G.PlayerFrame
        if not pf then return nil end
        local bar
        if kind == "health" then
            bar = pf.healthbar
        else
            local okp, cur = pcall(UnitPowerType, "player")
            if not okp or isHidden(cur) or cur ~= ptype then return nil end
            bar = pf.manabar
        end
        if not bar or not bar.GetStatusBarTexture then return nil end
        local tex = bar:GetStatusBarTexture()
        local w, bw = tex and tex:GetWidth(), bar:GetWidth()
        if type(w) ~= "number" or type(bw) ~= "number" or isHidden(w) or isHidden(bw) or bw < 4 then return nil end
        return math.max(0, math.min(100, w / bw * 100))
end
function UbermocUIAPI.realBarPercent(kind, ptype)
    local ok, res = pcall(H.realBarBody, kind, ptype)
    if ok then return res end
    return nil
end

local function barPercent(kind, ptype)
    local rp = UbermocUIAPI.realBarPercent(kind, ptype)
    if rp then return rp end
    if not (CurveConstants and CurveConstants.ScaleTo100 and UIParent) then return nil end
    local ok, res = pcall(function()
        local sb = probeBars[kind]
        if not sb then
            sb = CreateFrame("StatusBar", nil, UIParent)
            sb:SetSize(100, 10)
            sb:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -400, 400)
            sb:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
            sb:SetMinMaxValues(0, 100)
            sb:SetAlpha(0.01)
            probeBars[kind] = sb
        end
        local v
        if kind == "health" then v = UnitHealthPercent("player", false, CurveConstants.ScaleTo100)
        else v = UnitPowerPercent("player", ptype, false, CurveConstants.ScaleTo100) end
        -- A reference bar at 100% must measure 100 wide, otherwise the width cannot be trusted yet.
        local ref = probeBars.ref
        if not ref then
            ref = CreateFrame("StatusBar", nil, UIParent)
            ref:SetSize(100, 10)
            ref:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -400, 380)
            ref:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
            ref:SetMinMaxValues(0, 100)
            ref:SetAlpha(0.01)
            probeBars.ref = ref
        end
        ref:SetValue(100)
        local rw = ref:GetStatusBarTexture():GetWidth()
        if type(rw) ~= "number" or isHidden(rw) or math.abs(rw - 100) > 0.5 then return nil end
        sb:SetValue(v)
        local w = sb:GetStatusBarTexture():GetWidth()
        if type(w) == "number" and not isHidden(w) then return w end
        return nil
    end)
    if ok then return res end
    return nil
end

-- Reads a "is it below full" answer for health or power. Returns true / false, or
-- nil when WoW hides the numbers. Tries the plain numbers first, then the percent
-- helper that newer clients offer.
function H.belowFullBody(kind, ptype)
        local cur, max
        if kind == "health" then
            cur, max = UnitHealth("player"), UnitHealthMax("player")
        else
            cur, max = UnitPower("player", ptype), UnitPowerMax("player", ptype)
        end
        if not isHidden(cur) and not isHidden(max) and type(cur) == "number" and type(max) == "number" then
            return max > 0 and cur < max
        end
        local pct
        if kind == "health" and UnitHealthPercent then
            pct = UnitHealthPercent("player", false, CurveConstants and CurveConstants.ScaleTo100)
        elseif kind == "power" and UnitPowerPercent then
            pct = UnitPowerPercent("player", ptype, false, CurveConstants and CurveConstants.ScaleTo100)
        end
        if type(pct) == "number" and not isHidden(pct) then return pct < 99.99 end
        local bp = barPercent(kind, ptype)
        if bp then return bp < 99.5 end
        return nil
end
local function belowFull(kind, ptype)
    local ok, res = pcall(H.belowFullBody, kind, ptype)
    if ok then return res end
    return nil
end

local lastBelow = { health = false, power = false }
-- Set while WoW hides health / power: "not full" cannot be read, so the fade is done by WoW's
-- own percent curve instead (see secretAlpha).
local hiddenNow = {}
local secretSpec = {}

function H.testPower(pt)
    local r = belowFull("power", pt)
    if r == nil then hiddenNow.power = hiddenNow.power or pt; return false end
    return r
end

local CHECKS = {
    healthrefill = function()
        if UnitIsDeadOrGhost("player") then return false end
        local r = belowFull("health")
        if r == nil then hiddenNow.health = true; return false end
        lastBelow.health = r
        return r
    end,
    resourcerefill = function()
        local ok, ptype = pcall(UnitPowerType, "player")
        if not ok or isHidden(ptype) then return false end
        local test = H.testPower
        if REFILL_POWER[ptype] and test(ptype) then lastBelow.power = true; return true end
        -- Classes whose main bar is not mana (shadow priest, elemental shaman, balance / feral druid...)
        -- still have a mana pool: using it counts as well.
        if ptype ~= 0 then
            local okm, mx = pcall(UnitPowerMax, "player", 0)
            if okm and type(mx) == "number" and not isHidden(mx) and mx > 0 and test(0) then
                lastBelow.power = true
                return true
            end
        end
        lastBelow.power = false
        return false
    end,
    -- Gossip or quest window open: talking to a quest giver or other NPC.
    dialogue = function()
        return (GossipFrame and GossipFrame:IsVisible()) or (QuestFrame and QuestFrame:IsVisible())
            or (UbermocDialogue and UbermocDialogue:IsVisible()) or false
    end,
    moving = function() return isMoving end,
    combat = function() return InCombatLockdown() or UnitAffectingCombat("player") end,
    mounted = function()
        if IsMounted() or IsFlying() or UnitInVehicle("player") or UnitOnTaxi("player") then return true end
        local form = GetShapeshiftFormID and GetShapeshiftFormID()
        return form ~= nil and TRAVEL_FORMS[form] == true
    end,
    instance = function() return (IsInInstance()) end,
    group = function() return IsInGroup() end,
    target = function() return UnitExists("target") end,
    resting = function() return IsResting() end,
}

----------------------------------------------------------------------
-- Fade engine: each element's frames get their own opacity.
-- Elements with no settings are never touched.
----------------------------------------------------------------------
local panel, refreshPanel, miscPanel, refreshMisc, nameplatePanel, refreshNameplates, chatPanel, refreshChat
local mmButton, updateMinimapButton, applySquareMinimap
local uiPrint
local updateAllPlates, getPlateSize, applyPlateSizes, resetPlateSizes, applyPlateVisibility
local applyPlateAlpha, restylePlates, updatePlatePcts, mmAlpha
local makeIndicator, layoutIndicator
local applyChatLines, hookChatFrames
local mouseOver = false
local revealHeld, revealToggle = false, false -- Reveal key binding / macro
local msgReveal, chatDirty = nil, false -- chat revealed by a new message until this time

local curEff, goalEff, touched = {}, {}, {}
local appliedGoal, delayStart, delayPending = {}, {}, false

-- Scratch tables reused every tick, so the per-tick work creates no garbage for WoW to collect.
UbermocUIAPI.buf = { m = {}, fe = {}, list = {}, ao = {}, eo = {}, sig = {}, prev = {}, none = {} }

local function computeMatches()
    local m = UbermocUIAPI.buf.m
    wipe(m)
    wipe(hiddenNow)
    for _, k in ipairs(PRIORITY) do
        if CHECKS[k]() then m[k] = true end
    end
    return m
end

-- While one of our halo frames replaces a WoW frame, WoW's frame is hidden (and stops taking clicks).
local HALO_REPLACES = {
    player = function(D) return D.ringhud and D.ringhud.on end,
    pet = function(D) return D.ringhud and D.ringhud.pon end,
    target = function(D) return D.ringhud_target and D.ringhud_target.on end,
    tot = function(D) return D.ringhud_tot and D.ringhud_tot.on end,
    focus = function(D) return D.ringhud_focus and D.ringhud_focus.on end,
    fot = function(D) return D.ringhud_fot and D.ringhud_fot.on end,
    party = function(D)
        if IsInRaid and IsInRaid() then return D.raid and D.raid.on end
        return D.party and D.party.on
    end,
    -- The minimap experience bar replaces WoW's own experience / reputation bar.
    xpbar = function(D)
        if D.mm and D.mm.xp and D.mm.xp.on then return true end
        return UbermocUIAPI.xpOnBoard and UbermocUIAPI.xpOnBoard() or false   -- the info board's experience item
    end,
    -- The player halo frame shows your cast itself.
    castbar = function(D)
        if D.ringhud and D.ringhud.on and D.ringhud.cast ~= false then return true end
        return UbermocUIAPI.floatingCast and UbermocUIAPI.floatingCast("player") or false   -- the floating player frame has its own
    end,
    -- The floating player frame shows your buffs and debuffs itself.
    buffs = function() return UbermocUIAPI.floatingAuras and UbermocUIAPI.floatingAuras(false) or false end,
    debuffs = function() return UbermocUIAPI.floatingAuras and UbermocUIAPI.floatingAuras(true) or false end,
    -- Combo points on the target halo frame replace the game's combo point bar (rogues and druids).
    classres = function(D)
        local _, cls = UnitClass("player")
        if cls ~= "ROGUE" and cls ~= "DRUID" then return false end
        return D.combo and D.combo.halo and D.combo.halo.on and D.ringhud_target and D.ringhud_target.on and true or false
    end,
    -- Character info on the minimap shows durability.
    durability = function(D) return D.mm and D.mm.info and D.mm.info.on and D.mm.info.dura end,
    -- (The menu bar hides the game's menu and bag bars itself: switching their mouse off here would also
    -- switch it off on the buttons the menu bar takes over.)
}
UbermocUIAPI.HALO_REPLACES = HALO_REPLACES

-- The game's player cast bar is hidden the instant it is shown, not on the next pass of the fade timer (which let it
-- through for about half a second at the start of a cast). Only while the halo or floating player frame shows the cast itself.
do
    local want = false
    local function refresh()
        local D = UbermocUIDB
        want = (D and D.enabled and HALO_REPLACES.castbar(D)) and true or false
        local f = _G.PlayerCastingBarFrame
        if want and f and f.GetAlpha and f:GetAlpha() ~= 0 then f:SetAlpha(0) end
    end
    local hooked = false
    local function hook()
        local f = _G.PlayerCastingBarFrame
        if hooked or not f then return end
        hooked = true
        hooksecurefunc(f, "SetAlpha", function(self, a) if want and a ~= 0 then self:SetAlpha(0) end end)
        hooksecurefunc(f, "Show", function(self) if want then self:SetAlpha(0) end end)
    end
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "ADDON_LOADED" }) do ev:RegisterEvent(e) end
    ev:SetScript("OnEvent", function() pcall(hook); pcall(refresh) end)
    local acc = 0
    ev:SetScript("OnUpdate", function(_, dt)
        acc = acc + dt
        if acc < 0.5 then return end
        acc = 0
        pcall(hook); pcall(refresh)
    end)
end
UbermocUIAPI.haloHidden = {}
local function computeGoals()
    local DB = UbermocUIDB
    if not DB.enabled then
        for _, e in ipairs(ELEMENTS) do goalEff[e.key] = 1 end
        return
    end
    delayPending = false
    local matches = computeMatches()
    local revealAll = revealHeld or revealToggle
    local over = UbermocUI_over or UbermocUIAPI.buf.none
    for _, e in ipairs(ELEMENTS) do
        -- Hovering reveals only the element under the mouse; the reveal key still reveals everything.
        local reveal = revealAll or (DB.mouse.on and over[e.key])
        local o = DB.elements[e.key]
        local t = 1
        secretSpec[e.key] = nil
        local replaced = HALO_REPLACES[e.key] and HALO_REPLACES[e.key](DB) and true or false
        if HALO_REPLACES[e.key] and UbermocUIAPI.haloHidden[e.key] ~= replaced then UbermocUIAPI.haloDirty = true end
        UbermocUIAPI.haloHidden[e.key] = replaced
        if replaced or (o and o.hide) then
            t = 0 -- always hidden (or replaced by a halo frame): wins over every situation and over reveal
        else
            if o then
                local found = false
                for idx, k in ipairs(PRIORITY) do
                    if matches[k] and o[k] ~= nil then t = o[k]; found = true; break end
                    if o[k] ~= nil and ((k == "healthrefill" and hiddenNow.health) or (k == "resourcerefill" and hiddenNow.power)) then
                        -- Value of everything below this situation, used when the resource is full.
                        local rest, fnd = 1, false
                        for j = idx + 1, #PRIORITY do
                            local k2 = PRIORITY[j]
                            if matches[k2] and o[k2] ~= nil then rest = o[k2]; fnd = true; break end
                        end
                        if not fnd and o.idle ~= nil then rest = o.idle end
                        -- one table per element, reused (this runs many times a second in a fight)
                        local pool = UbermocUIAPI.buf.spool
                        if not pool then pool = {}; UbermocUIAPI.buf.spool = pool end
                        local spT = pool[e.key]
                        if not spT then spT = {}; pool[e.key] = spT end
                        spT.kind, spT.aNot, spT.aFull = (k == "healthrefill") and "health" or "power", o[k], rest
                        secretSpec[e.key] = spT
                        t = rest; found = true
                        break
                    end
                end
                if not found and o.idle ~= nil then t = o.idle end
            end
            if reveal and t < DB.mouse.alpha then t = DB.mouse.alpha end
            local sp = secretSpec[e.key]
            if sp and reveal then
                sp.aNot = math.max(sp.aNot, DB.mouse.alpha)
                sp.aFull = math.max(sp.aFull, DB.mouse.alpha)
            end
        end
        -- Wait a moment before fading down, if the player asked for a delay.
        local delay = DB.fadeDelay or 0
        if delay > 0 then
            local applied = appliedGoal[e.key] or t
            if t < applied then
                delayStart[e.key] = delayStart[e.key] or GetTime()
                if GetTime() - delayStart[e.key] < delay then
                    t = applied
                    delayPending = true
                else
                    delayStart[e.key] = nil
                end
            else
                delayStart[e.key] = nil
            end
            appliedGoal[e.key] = t
        end
        goalEff[e.key] = t
    end

    -- Chat extras: a new message can reveal the chat for a while, and the tabs
    -- can be hidden or follow the chat window.
    local ch = DB.chat
    if ch.revealOnMessage and msgReveal and GetTime() < msgReveal then
        for key in pairs(CHAT_KEYS) do
            local o = DB.elements[key]
            if not (o and o.hide) and (goalEff[key] or 1) < ch.revealAlpha then goalEff[key] = ch.revealAlpha end
        end
    end
    if ch.hideTabs then
        goalEff.chattabs = 0
    elseif ch.tabsFollow then
        goalEff.chattabs = goalEff.chat or 1
    end
end

local function approach(c, g, step)
    if c < g then return math.min(g, c + step) end
    return math.max(g, c - step)
end

local touchedFrame = {}

-- Opacity read straight from WoW's percent value through a curve, so it works while health or
-- power are hidden from addons: aNot below full, aFull at full. The curve is made to work whether
-- WoW feeds it 0-1 or 0-100.
local curves = {}
local function secretAlpha(sp)
    if not (C_CurveUtil and C_CurveUtil.CreateCurve and Enum and Enum.LuaCurveType) then return nil end
    local key = sp._key
    if not key or sp._kn ~= sp.aNot or sp._kf ~= sp.aFull or sp._kk ~= sp.kind then
        key = sp.kind .. string.format(":%.3f:%.3f", sp.aNot, sp.aFull)
        sp._key, sp._kn, sp._kf, sp._kk = key, sp.aNot, sp.aFull, sp.kind
    end
    local c = curves[key]
    if not c then
        local ok, cv = pcall(function()
            local cv = C_CurveUtil.CreateCurve()
            cv:SetType(Enum.LuaCurveType.Step)
            cv:AddPoint(0, sp.aNot)
            cv:AddPoint(0.9999, sp.aFull)
            cv:AddPoint(1.0001, sp.aNot)
            cv:AddPoint(99.9999, sp.aFull)
            return cv
        end)
        if not ok then return nil end
        c = cv
        curves[key] = c
    end
    local ok, a
    if sp.kind == "health" then
        ok, a = pcall(UnitHealthPercent, "player", false, c)
    else
        ok, a = pcall(UnitPowerPercent, "player", hiddenNow.power, false, c)
    end
    if ok then return a end
    return nil
end

function UbermocUIAPI.resolveAlpha(f)
    local B = UbermocUIAPI.buf
    local frameElem, alphaOf, effOf = B.fe, B.ao, B.eo
    if effOf[f] then return end
    local want = curEff[frameElem[f]] or 1
    local anc
    local g = f:GetParent()
    while g do
        if frameElem[g] then anc = g; break end
        g = g:GetParent()
    end
    local ancEff = 1
    if anc then UbermocUIAPI.resolveAlpha(anc); ancEff = effOf[anc] end
    local a = 0
    if ancEff > 0.001 then a = math.min(1, want / ancEff) end
    alphaOf[f] = a
    effOf[f] = a * ancEff
end

-- The fade a managed frame has right now (1 when none), for frames that set their own opacity as well.
function UbermocUIAPI.fadeAlphaOf(f) return UbermocUIAPI.buf.ao[f] or 1 end

local driver = CreateFrame("Frame")
driver:Hide()
driver:SetScript("OnUpdate", function(self, dt)
    local DB = UbermocUIDB
    local done = true
    local B = UbermocUIAPI.buf
    local frameElem, list = B.fe, B.list
    wipe(frameElem); wipe(list)
    for _, e in ipairs(ELEMENTS) do
        local goal = goalEff[e.key] or 1
        local cur = curEff[e.key] or 1
        local secs = (cur < goal) and (DB.fadeInTime or DB.fadeTime) or (DB.fadeOutTime or DB.fadeTime)
        local c = approach(cur, goal, dt / math.max(secs, 0.01))
        curEff[e.key] = c
        if c ~= goal then done = false end
        touched[e.key] = (e.plates and c ~= 1) or false
        for _, name in ipairs(e.frames) do
            local f = getFrame(name)
            if f and f.SetAlpha and not frameElem[f] then
                frameElem[f] = e.key
                list[#list + 1] = f
            end
        end
    end

    -- A frame inside another managed frame inherits that frame's opacity, so
    -- divide it out to land exactly on the element's own value.
    local alphaOf, effOf = B.ao, B.eo
    wipe(alphaOf); wipe(effOf)
    local resolve = UbermocUIAPI.resolveAlpha

    for _, f in ipairs(list) do
        resolve(f)
        local a = alphaOf[f]
        -- Only touch frames that need it, so default Blizzard behaviour is left alone.
        if a ~= 1 or touchedFrame[f] then
            touchedFrame[f] = (a ~= 1)
            f:SetAlpha(f.ubRange and (a * f.ubRange) or a)   -- ubRange: a frame that also dims itself (offline, out of range)
        end
        if a ~= 1 then touched[frameElem[f]] = true end
    end
    -- Elements whose health / resource is hidden by WoW take their opacity from the curve.
    for _, e in ipairs(ELEMENTS) do
        local sp = secretSpec[e.key]
        if sp and not e.plates then
            local a = secretAlpha(sp)
            if a ~= nil then
                for _, name in ipairs(e.frames) do
                    local f = getFrame(name)
                    if f and f.SetAlpha then
                        pcall(f.SetAlpha, f, a)
                        touchedFrame[f] = true
                    end
                end
                touched[e.key] = true
            end
        end
    end
    if mmAlpha then mmAlpha() end
    applyPlateAlpha()
    if UbermocUIAPI.haloDirty and not InCombatLockdown() and UbermocUIAPI.syncHaloMouse then
        UbermocUIAPI.haloDirty = false
        pcall(UbermocUIAPI.syncHaloMouse)
    end
    if done then self:Hide() end
end)

local function evaluate()
    if not UbermocUIDB then return end
    computeGoals()
    driver:Show()
end
-- For the busy events (the player's health and power change many times a second in a fight): the
-- goals are worked out again, but the pass over every frame only runs when something has to change.
-- State for the quieter updates below, in one table (this file is at its limit of named locals).
local Q = { pending = false, hover = 0, quest = false,
    BUSY = { UNIT_HEALTH = true, UNIT_MAXHEALTH = true, UNIT_POWER_UPDATE = true, UNIT_MAXPOWER = true } }
function Q.now()
    Q.pending = false
    if not UbermocUIDB then return end
    computeGoals()
    if driver:IsShown() or next(secretSpec) or UbermocUIAPI.haloDirty or delayPending then driver:Show(); return end
    for _, e in ipairs(ELEMENTS) do
        if (goalEff[e.key] or 1) ~= (curEff[e.key] or 1) then driver:Show(); return end
    end
end
-- A burst of them is looked at once, on the next tenth of a second.
function Q.quiet() Q.pending = true end

-- Poll: mouseover reveal, plus a periodic re-apply so frames that Blizzard
-- resets or creates later are kept at the right opacity.
-- Is the player moving? true / false, or nil when WoW hides the answer.
-- Movement speed can be a "secret" value that addons may not compare, so fall
-- back to watching the position change, and give up quietly if that is hidden too.
local lastX, lastY
function UbermocUIAPI.speedProbe()
    local sp = GetUnitSpeed("player")
    if isHidden(sp) then return nil end
    return (tonumber(sp) or 0) > 0
end

function UbermocUIAPI.posProbe()
    local y, x = UnitPosition("player")
    if y == nil or x == nil or isHidden(y) or isHidden(x) then
        lastX, lastY = nil, nil
        return nil
    end
    local result = nil
    if lastX then result = (math.abs(x - lastX) + math.abs(y - lastY)) > 0.05 end
    lastX, lastY = x, y
    return result
end

local function readMoving()
    local ok, res = pcall(UbermocUIAPI.speedProbe)
    if ok and res ~= nil then return res end
    local ok2, moved = pcall(UbermocUIAPI.posProbe)
    if ok2 then return moved end
    return nil
end

local poll, acc, rescan = CreateFrame("Frame"), 0, 0
local stillFor, dialogueOpen = 0, false
local lastMousePlate, pctAcc = nil, 0
poll:SetScript("OnUpdate", function(_, dt)
    if not UbermocUIDB then return end
    acc = acc + dt
    if acc < 0.1 then return end
    local step = acc
    rescan = rescan + acc
    acc = 0
    -- A new chat message reveals the chat; it fades back after the timer runs out.
    if chatDirty or (msgReveal and GetTime() >= msgReveal) then
        chatDirty = false
        if msgReveal and GetTime() >= msgReveal then msgReveal = nil end
        evaluate()
    end
    if delayPending or Q.pending then Q.now() end
    -- Nameplate extras: mouseover emphasis and the live health percent text.
    local npdb = UbermocUIDB.nameplates
    if C_NamePlate and npdb then
        local mouse = C_NamePlate.GetNamePlateForUnit and C_NamePlate.GetNamePlateForUnit("mouseover") or nil
        if mouse ~= lastMousePlate then
            lastMousePlate = mouse
            local e, f = npdb.enemy.look, npdb.friendly.look
            if e.mouseW ~= 0 or e.mouseH ~= 0 or f.mouseW ~= 0 or f.mouseH ~= 0 then restylePlates() end
        end
        pctAcc = pctAcc + step
        if pctAcc >= 0.25 then
            pctAcc = 0
            if npdb.friendly.look.nameOnly or npdb.enemy.look.nameOnly then updatePlatePcts() end
        end
    end
    -- Walking / running, with a short grace period so tiny stops do not flicker.
    local movingNow = readMoving()
    if movingNow == true then
        stillFor = 0
        if not isMoving then isMoving = true; evaluate() end
    elseif movingNow == false then
        stillFor = stillFor + step
        if isMoving and stillFor >= 0.3 then isMoving = false; evaluate() end
    end -- nil: WoW is hiding movement from addons right now, so keep the last known state
    -- NPC dialogue windows opening or closing.
    local d = CHECKS.dialogue() and true or false
    if d ~= dialogueOpen then dialogueOpen = d; evaluate() end
    -- Hover: only looked at when the mouse has moved (a controller player never pays for it), and once
    -- a second in case a frame moved under a still mouse.
    local mx, my = GetCursorPosition()
    Q.hover = Q.hover + step
    local mouseMoved = mx ~= Q.mx or my ~= Q.my
    if mouseMoved or Q.hover >= 1 then Q.mx, Q.my, Q.hover = mx, my, 0 end
    if UbermocUIDB.mouse.on and (mouseMoved or Q.hover == 0) then
        local B = UbermocUIAPI.buf
        local sig, n = B.sig, 0
        for _, e in ipairs(ELEMENTS) do
            for _, nm in ipairs(e.frames) do
                local f = getFrame(nm)
                if f and f.IsMouseOver then
                    local okM, inside = pcall(f.IsMouseOver, f)
                    if okM and (inside or f.ubermocHover) and f:IsShown() then n = n + 1; sig[n] = e.key; break end
                end
            end
        end
        local prev = B.prev
        local changed = (prev.n or 0) ~= n
        if not changed then
            for i = 1, n do if prev[i] ~= sig[i] then changed = true; break end end
        end
        if changed then
            local keys = {}
            for i = 1, n do prev[i] = sig[i]; keys[sig[i]] = true end
            for i = n + 1, #prev do prev[i] = nil end
            prev.n = n
            UbermocUI_over = keys
            mouseOver = n > 0
            evaluate()
        end
    end
    if rescan >= 0.5 then
        rescan = 0
        for _, v in pairs(touched) do
            if v then evaluate(); break end
        end
    end
end)

----------------------------------------------------------------------
-- Widgets
----------------------------------------------------------------------
local function pct(v) return math.floor(v * 100 + 0.5) .. "%" end

-- Shared look: one accent colour and flat dark controls.
UbermocUIAPI = UbermocUIAPI or {}
UbermocUIAPI.accent = { 0.20, 0.70, 1.00 }
UbermocUIAPI.WHITE = "Interface\\Buttons\\WHITE8x8"

-- The accent colour is the colour of the character's class.
function UbermocUIAPI.setAccent()
    pcall(function()
        local _, cls = UnitClass("player")
        local c = cls and RAID_CLASS_COLORS and RAID_CLASS_COLORS[cls]
        if not c then return end
        local r, g, b = c.r, c.g, c.b
        -- keep it readable on the dark window: lift very dark class colours
        local top = math.max(r, g, b)
        if top < 0.55 then local k = 0.55 / math.max(top, 0.01); r, g, b = math.min(1, r * k), math.min(1, g * k), math.min(1, b * k) end
        local A = UbermocUIAPI.accent
        A[1], A[2], A[3] = r, g, b
    end)
end
UbermocUIAPI.setAccent()

function UbermocUIAPI.flatButton(b)
    local A = UbermocUIAPI.accent
    b:SetNormalFontObject("GameFontHighlight")
    b:SetHighlightFontObject("GameFontHighlight")
    b:SetDisabledFontObject("GameFontDisable")
    local rim = b:CreateTexture(nil, "BACKGROUND", nil, -2)
    rim:SetAllPoints()
    rim:SetColorTexture(0.27, 0.30, 0.38, 1)
    local bg = b:CreateTexture(nil, "BACKGROUND", nil, -1)
    bg:SetPoint("TOPLEFT", 1, -1)
    bg:SetPoint("BOTTOMRIGHT", -1, 1)
    bg:SetColorTexture(0.12, 0.14, 0.19, 1)
    b:SetHighlightTexture(UbermocUIAPI.WHITE)
    local ht = b:GetHighlightTexture()
    if ht then
        ht:ClearAllPoints()
        ht:SetPoint("TOPLEFT", 1, -1)
        ht:SetPoint("BOTTOMRIGHT", -1, 1)
        ht:SetVertexColor(A[1], A[2], A[3], 0.22)
    end
    b.flatBg, b.flatRim = bg, rim
    return b
end

-- Hold to repeat: a click runs b.holdFn(1) once; held down it repeats after 0.5 s, every 0.1 s (the game's own
-- scroll arrows use the same timing). With b.holdBig the steps grow the longer it is held (x5 after 1.5 s, x25
-- after 3 s). The controller's A and D-pad use the same timing. The OnUpdate only runs while held, and the scripts
-- are shared functions so no closures are made per button.
H.REPEAT_DELAY, H.REPEAT_GAP = 0.5, 0.1
function H.holdUpdate(b, dt)
    b.holdT = b.holdT + dt
    if b.holdT < H.REPEAT_DELAY then return end
    b.holdTick = b.holdTick + dt
    if b.holdTick < b.holdGap then return end
    b.holdTick = 0
    b.repeated = true
    local t = b.holdT
    b.holdFn(b.holdBig and ((t > 3 and 25) or (t > 1.5 and 5)) or 1)
end
function H.holdDown(b, btn)
    if btn and btn ~= "LeftButton" then return end
    if b.IsEnabled and not b:IsEnabled() then return end
    b.holdT, b.holdTick, b.repeated = 0, 0, false
    b:SetScript("OnUpdate", H.holdUpdate)
end
function H.holdUp(b) b:SetScript("OnUpdate", nil) end
function H.holdClick(b)
    if b.repeated then b.repeated = false; return end
    b.holdFn(1)
end
function H.holdRepeat(b, fn, gap, big)
    b.holdFn, b.holdGap, b.holdBig = fn, gap or H.REPEAT_GAP, big
    b:SetScript("OnMouseDown", H.holdDown)
    b:SetScript("OnMouseUp", H.holdUp)
    b:SetScript("OnHide", H.holdUp)
    b:SetScript("OnClick", H.holdClick)
end

-- Shows a stepper's value: the text and, for ranges with real limits, how full the bar is.
function H.sliderShow(s, v)
    s.text:SetText(s.fmt(v))
    if s.fill then
        local f = (v - s.lo) / (s.hi - s.lo)
        if f > 1 then f = 1 end
        if f > 0.005 then s.fill:SetWidth(70 * f); s.fill:Show() else s.fill:Hide() end
    end
end

-- Number stepper: [ - ] [ value ] [ + ]. Hold - or + to keep going (it speeds up), with the mouse or with A.
-- The D-pad only moves the pointer; A changes the value. Ranges with a few steps, or 0-100, show a bar in the number box, and clicking the bar with the mouse jumps there. Wider ranges stop at
-- their own ends; a mouse click on the number opens a typing field (never needed: - and + reach any value).
local function makeSlider(parent, w, min, max, step, fmt, onChange)
    local span = max - min
    local lo, hi = min, max
    local bounded = true
    if span > 20 and not (min == 0 and max == 100) then
        bounded = false
    end
    local s = CreateFrame("Slider", nil, parent)
    s:SetOrientation("HORIZONTAL")
    s:SetSize(72, 26)
    s:EnableMouse(false) -- the number box and the - / + buttons do the work
    s:SetMinMaxValues(lo, hi)
    s:SetValueStep(step)
    s.stepSize = step
    s.lo, s.hi = lo, hi

    s.nudge = function(dir, mult)
        s:SetValue(s:GetValue() + dir * step * (mult or 1))
    end
    local function stepButton(text, dir, point, relPoint, x)
        local b = CreateFrame("Button", nil, s)
        b:SetSize(28, 26)
        UbermocUIAPI.flatButton(b)
        b:SetText(text)
        b:SetPoint(point, s, relPoint, x, 0)
        H.holdRepeat(b, function(mult) s.nudge(dir, mult) end, 0.07, true)
        return b
    end
    s.minus = stepButton("-", -1, "RIGHT", "LEFT", -4)
    s.plus = stepButton("+", 1, "LEFT", "RIGHT", 4)

    local box = CreateFrame("Button", nil, s)
    box:SetAllPoints(s)
    UbermocUIAPI.flatButton(box)
    s.box = box
    box.ubSkipCursor = true   -- the pointer uses the - and + buttons beside the number (A changes it, hold A to repeat)
    if bounded then
        local A = UbermocUIAPI.accent
        -- A thin bar along the bottom of the number: how far along the range the value is.
        local fill = box:CreateTexture(nil, "ARTWORK", nil, 1)
        fill:SetPoint("BOTTOMLEFT", 1, 1)
        fill:SetHeight(3)
        fill:SetWidth(1)
        fill:SetColorTexture(A[1], A[2], A[3], 0.9)
        s.fill = fill
    end
    s.text = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    s.text:SetPoint("CENTER")
    s.fmt = fmt
    local eb
    box:SetScript("OnMouseDown", function(self, btn)
        self.realDown = true
        if not bounded or btn ~= "LeftButton" then return end
        local l, bw = self:GetLeft(), self:GetWidth()
        if not (l and bw and bw > 0 and GetCursorPosition) then return end
        local f = (GetCursorPosition() / self:GetEffectiveScale() - l) / bw
        if f < 0 then f = 0 elseif f > 1 then f = 1 end
        s:SetValue(math.floor((min + f * span) / step + 0.5) * step)
    end)
    box:SetScript("OnClick", function()
        local real = box.realDown
        box.realDown = nil
        if bounded or not real then return end   -- a controller press never opens the typing field
        if not eb then
            eb = CreateFrame("EditBox", nil, s, "InputBoxTemplate")
            eb:SetAutoFocus(false)
            eb:SetSize(66, 22)
            eb:SetPoint("CENTER", box, "CENTER", 0, 0)
            eb:SetFrameLevel(box:GetFrameLevel() + 5)
            eb:SetJustifyH("CENTER")
            eb:SetScript("OnEscapePressed", function(self) self:ClearFocus(); self:Hide() end)
            eb:SetScript("OnEnterPressed", function(self)
                local n = tonumber(self:GetText())
                if n then s:SetValue(n) end
                self:ClearFocus(); self:Hide()
            end)
            eb:SetScript("OnEditFocusLost", function(self) self:Hide() end)
        end
        eb:SetText(tostring(math.floor(s:GetValue() * 100 + 0.5) / 100))
        eb:Show(); eb:SetFocus(); eb:HighlightText()
    end)
    s:SetScript("OnValueChanged", function(self, v)
        v = math.floor(v * 100 + 0.5) / 100
        H.sliderShow(self, v)
        if not self.silent then onChange(v) end
    end)
    return s
end

local function setSlider(s, v)
    s.silent = true
    s:SetValue(v)
    s.silent = false
    H.sliderShow(s, v)
end

local function setSliderActive(s, on)
    s:SetAlpha(on and 1 or 0.4)
    for _, b in ipairs({ s.minus, s.plus, s.box, s.reset }) do
        b:SetEnabled(on)
        b:SetAlpha(on and 1 or 0.4)
    end
end

local function newCheck(parent, text, x, y, onClick, font)
    local A = UbermocUIAPI.accent
    local cb = CreateFrame("CheckButton", nil, parent)
    cb:SetSize(28, 28)
    cb:SetPoint("TOPLEFT", x, y)
    local rim = cb:CreateTexture(nil, "BACKGROUND", nil, -2)
    rim:SetSize(20, 20); rim:SetPoint("CENTER")
    rim:SetColorTexture(0.32, 0.36, 0.45, 1)
    local box = cb:CreateTexture(nil, "BACKGROUND", nil, -1)
    box:SetSize(18, 18); box:SetPoint("CENTER")
    box:SetColorTexture(0.09, 0.10, 0.14, 1)
    cb:SetCheckedTexture(UbermocUIAPI.WHITE)
    local ck = cb:GetCheckedTexture()
    if ck then
        ck:ClearAllPoints()
        ck:SetPoint("CENTER")
        ck:SetSize(12, 12)
        ck:SetVertexColor(A[1], A[2], A[3], 1)
    end
    cb:SetHighlightTexture(UbermocUIAPI.WHITE)
    local ht = cb:GetHighlightTexture()
    if ht then
        ht:ClearAllPoints()
        ht:SetSize(20, 20); ht:SetPoint("CENTER")
        ht:SetVertexColor(A[1], A[2], A[3], 0.25)
    end
    cb.label = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
    cb.label:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    cb.label:SetText(text)
    cb:SetScript("OnClick", function(self) onClick(self:GetChecked() and true or false) end)
    return cb
end

local function newLabel(parent, text, x, y, font)
    local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetText(text)
    if font == "GameFontNormalLarge" then
        -- Section headings get a thin gold rule so long pages read in blocks.
        local rule = parent:CreateTexture(nil, "ARTWORK")
        rule:SetColorTexture(UbermocUIAPI.accent[1], UbermocUIAPI.accent[2], UbermocUIAPI.accent[3], 0.35)
        rule:SetHeight(1)
        rule:SetPoint("TOPLEFT", fs, "BOTTOMLEFT", 0, -3)
        rule:SetWidth(520)
        fs.rule = rule
    end
    return fs
end

local function newButton(parent, text, w, x, y, onClick)
    local b = CreateFrame("Button", nil, parent)
    UbermocUIAPI.flatButton(b)
    b:SetSize(w, 26)
    b:SetPoint("TOPLEFT", x, y)
    b:SetText(text)
    b:SetScript("OnClick", onClick)
    return b
end

-- Gives a stepper a small Reset button (right of +) that puts back the default value.
function H.sliderDefault(s, v)
    s.default = v
    if s.reset then return s end
    local b = CreateFrame("Button", nil, s)
    UbermocUIAPI.flatButton(b)
    b:SetNormalFontObject("GameFontHighlightSmall")
    b:SetSize(46, 22)
    b:SetPoint("LEFT", s.plus, "RIGHT", 8, 0)
    b:SetText("Reset")
    b:SetScript("OnClick", function() s:SetValue(s.default) end)
    s.reset = b
    return s
end

-- Lights the chosen button of a row (accent rim and tint), dims the rest.
function H.segPaint(b, on)
    local A = UbermocUIAPI.accent
    if on then
        b.flatRim:SetColorTexture(A[1], A[2], A[3], 1)
        b.flatBg:SetColorTexture(A[1] * 0.35, A[2] * 0.35, A[3] * 0.35, 1)
    else
        b.flatRim:SetColorTexture(0.27, 0.30, 0.38, 1)
        b.flatBg:SetColorTexture(0.12, 0.14, 0.19, 1)
    end
end

-- A row of buttons where the current choice is lit: one press picks it.
-- opts = { { value, label, width [, dx, dy, height] }, ... }; dx / dy place a button freely (used by the corner grid).
-- Everything sits in row.frame (placed at x, y on parent), so a page can hide, show or grey out the whole row.
-- Returns a table with .frame, .btns and .refresh(); set(value) stores the choice.
function H.segRow(parent, x, y, opts, get, set)
    local f = CreateFrame("Frame", nil, parent)
    f:SetPoint("TOPLEFT", x, y)
    local row = { btns = {}, get = get, frame = f }
    local cx, right, low = 0, 0, 26
    for i, o in ipairs(opts) do
        local w = o[3] or 80
        local bx, by = o[4] or cx, o[5] or 0
        local b = newButton(f, o[2] or "", w, bx, by, nil)
        if o[6] then b:SetHeight(o[6]) end
        b.value = o[1]
        b:SetScript("OnClick", function() set(b.value); row.refresh() end)
        row.btns[i] = b
        cx = cx + w + 4
        if bx + w > right then right = bx + w end
        if -by + (o[6] or 26) > low then low = -by + (o[6] or 26) end
    end
    f:SetSize(math.max(right, 1), low)
    row.refresh = function()
        local cur = row.get()
        for _, b in ipairs(row.btns) do H.segPaint(b, b.value == cur) end
        if row.after then row.after(cur) end
    end
    return row
end

-- Corner picker: a little 3 x 3 grid shaped like the map, the lit cell is where the text goes, with its name beside it.
-- cells (optional) limits it to some corners, e.g. only the four outer ones.
H.CORNER_CELLS = { { "TOPLEFT", 0, 0 }, { "TOP", 1, 0 }, { "TOPRIGHT", 2, 0 },
                   { "LEFT", 0, 1 }, { "CENTER", 1, 1 }, { "RIGHT", 2, 1 },
                   { "BOTTOMLEFT", 0, 2 }, { "BOTTOM", 1, 2 }, { "BOTTOMRIGHT", 2, 2 } }
H.CORNER4_CELLS = { { "TOPLEFT", 0, 0 }, { "TOPRIGHT", 1, 0 }, { "BOTTOMLEFT", 0, 1 }, { "BOTTOMRIGHT", 1, 1 } }
function H.cornerPick(parent, x, y, names, get, set, cells)
    local opts = {}
    cells = cells or H.CORNER_CELLS
    local cols = 0
    for i, c in ipairs(cells) do opts[i] = { c[1], "", 26, c[2] * 28, -c[3] * 16, 14 }; if c[2] + 1 > cols then cols = c[2] + 1 end end
    local row = H.segRow(parent, x, y, opts, get, set)
    local fs = row.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("LEFT", row.frame, "LEFT", cols * 28 + 8, 0)
    row.name = fs
    row.after = function(cur) fs:SetText(names[cur] or "") end
    return row
end

-- Nudge pad: [Left] [Up] [Down] [Right]  x 3, y -2  [Reset]. Hold a button to keep moving (faster the longer).
-- get() returns x, y; set(x, y) stores them.
function H.nudgePad(parent, x, y, get, set)
    local f = CreateFrame("Frame", nil, parent)
    f:SetPoint("TOPLEFT", x, y)
    f:SetSize(380, 26)
    local pad = { frame = f }
    local val = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    local function show() local a, b = get(); val:SetText(string.format("x %d, y %d", a or 0, b or 0)) end
    local function move(dx, dy, mult)
        local a, b = get()
        set((a or 0) + dx * (mult or 1), (b or 0) + dy * (mult or 1))
        show()
    end
    local DEFS = { { "Left", -1, 0, 50 }, { "Up", 0, 1, 40 }, { "Down", 0, -1, 50 }, { "Right", 1, 0, 52 } }
    local cx = 0
    pad.btns = {}
    for i, d in ipairs(DEFS) do
        local b = newButton(f, d[1], d[4], cx, 0, nil)
        H.holdRepeat(b, function(mult) move(d[2], d[3], mult) end, 0.07, true)
        pad.btns[i] = b
        cx = cx + d[4] + 4
    end
    val:SetPoint("LEFT", f, "LEFT", cx + 6, 0)
    local rs = newButton(f, "Reset", 50, cx + 86, 0, function() set(0, 0); show() end)
    pad.btns[5] = rs
    pad.refresh = show
    pad.frame.refresh = show
    return pad
end
UbermocUIAPI.nudgePad = H.nudgePad

----------------------------------------------------------------------
-- Borders: every border Ubermoc UI draws is registered here and set on the Textures page, all with the
-- same options: on / off, thickness, colour (class colour by default, a colour of your own, or for some
-- borders their own meaningful colours such as debuff type), and opacity.
-- registerBorder{ key, part, label, on, size, maxSize, a, auto = "label of the third colour choice",
--                 legacy = function() return on, size, a, mode, r, g, b end, apply = function() end }
----------------------------------------------------------------------
UbermocUIAPI.BORDERS = UbermocUIAPI.BORDERS or {}
UbermocUIAPI.BORDER_BY = UbermocUIAPI.BORDER_BY or {}
function UbermocUIAPI.registerBorder(def)
    if UbermocUIAPI.BORDER_BY[def.key] then return end
    UbermocUIAPI.BORDERS[#UbermocUIAPI.BORDERS + 1] = def
    UbermocUIAPI.BORDER_BY[def.key] = def
end
H.classCol = {}
function H.classColor()
    local c = H.classCol
    if not c[1] then
        local _, cls = UnitClass("player")
        local cc = cls and RAID_CLASS_COLORS and RAID_CLASS_COLORS[cls]
        c[1], c[2], c[3] = (cc and cc.r) or 0.6, (cc and cc.g) or 0.6, (cc and cc.b) or 0.65
    end
    return c[1], c[2], c[3]
end
H.borderFilled = {}
function UbermocUIAPI.borderDB(key)
    local def = UbermocUIAPI.BORDER_BY[key]
    if not (UbermocUIDB and UbermocUIDB.version) then return nil end
    UbermocUIDB.borders = UbermocUIDB.borders or {}
    -- One time: every border starts off (set the ones you want on the Textures page).
    if not UbermocUIDB.bordersOffV1 then
        UbermocUIDB.bordersOffV1 = true
        for _, bd in pairs(UbermocUIDB.borders) do if type(bd) == "table" then bd.on = false end end
        wipe(H.borderFilled)
    end
    local d = UbermocUIDB.borders[key]
    if d and H.borderFilled[key] == d then return d end
    if type(d) ~= "table" then
        -- First time: carry the old setting over (on, thickness, opacity, and a meaningful colour mode).
        d = {}
        if def and def.legacy then
            local ok, on, size, a, mode, r, g, b = pcall(def.legacy)
            if ok then d.on, d.size, d.a, d.mode, d.r, d.g, d.b = on, size, a, mode, r, g, b end
        end
        d.on = false
        UbermocUIDB.borders[key] = d
    end
    if d.on == nil then d.on = false end
    if d.size == nil then d.size = (def and def.size) or 1 end
    if d.a == nil then d.a = (def and def.a) or 100 end
    if d.mode == nil or (d.mode == "auto" and not (def and def.auto)) then d.mode = "class" end
    if d.r == nil then d.r, d.g, d.b = H.classColor() end
    H.borderFilled[key] = d
    return d
end
-- on, size, r, g, b, a (0-1), mode. With mode "auto" the colour returned is the custom one: the caller
-- uses its own colours (layer, debuff type, quality...) instead.
function UbermocUIAPI.borderOf(key)
    local d = UbermocUIAPI.borderDB(key)
    if not d then
        local def = UbermocUIAPI.BORDER_BY[key]
        local r, g, b = H.classColor()
        return false, (def and def.size) or 1, r, g, b, ((def and def.a) or 100) / 100, "class"
    end
    local r, g, b = d.r, d.g, d.b
    if d.mode == "class" then r, g, b = H.classColor() end
    return d.on and true or false, d.size or 1, r, g, b, (d.a or 100) / 100, d.mode
end
function UbermocUIAPI.applyBorder(key)
    local def = UbermocUIAPI.BORDER_BY[key]
    if def and def.apply then pcall(def.apply) end
end
-- Four thin pieces around a frame (outside it), sized and coloured from a border's settings.
function UbermocUIAPI.makeEdges(frame, layer, sub)
    local e = {}
    for i = 1, 4 do e[i] = frame:CreateTexture(nil, layer or "OVERLAY", nil, sub or 4) end
    return e
end
function UbermocUIAPI.paintEdges(e, frame, on, size, r, g, b, a, inside)
    if not e then return end
    if not on or size <= 0 then for i = 1, 4 do e[i]:Hide() end; return end
    local o = inside and 0 or size
    e[1]:ClearAllPoints(); e[1]:SetPoint("TOPLEFT", frame, "TOPLEFT", -o, o); e[1]:SetPoint("TOPRIGHT", frame, "TOPRIGHT", o, o); e[1]:SetHeight(size)
    e[2]:ClearAllPoints(); e[2]:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", -o, -o); e[2]:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", o, -o); e[2]:SetHeight(size)
    e[3]:ClearAllPoints(); e[3]:SetPoint("TOPLEFT", frame, "TOPLEFT", -o, o - size); e[3]:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", -o, -o + size); e[3]:SetWidth(size)
    e[4]:ClearAllPoints(); e[4]:SetPoint("TOPRIGHT", frame, "TOPRIGHT", o, o - size); e[4]:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", o, -o + size); e[4]:SetWidth(size)
    for i = 1, 4 do e[i]:SetColorTexture(r, g, b, a); e[i]:Show() end
end

UbermocUIAPI.registerBorder({ key = "xpBar", part = "minimap", label = "Experience bar border", size = 1, maxSize = 6,
    legacy = function() local x = UbermocUIDB.mm and UbermocUIDB.mm.xp or {}; return x.border ~= false, 1, 100, "class" end,
    apply = function() if UbermocUIAPI.mmApply then UbermocUIAPI.mmApply() end end })
UbermocUIAPI.registerBorder({ key = "addonBox", part = "minimap", label = "Addon button container border", size = 1, maxSize = 6,
    legacy = function() local x = UbermocUIDB.mm and UbermocUIDB.mm.box or {}; return x.border ~= false, 1, 100, "class" end,
    apply = function() if UbermocUIAPI.mmApply then UbermocUIAPI.mmApply() end end })

H.NP_OUT = { enemy = "npOutline_enemy", friendly = "npOutline_friendly" }
H.NP_LVL = { enemy = "npLevel_enemy", friendly = "npLevel_friendly" }
for _, gk in ipairs({ "enemy", "friendly" }) do
    local G = (gk == "enemy") and "Enemy" or "Friendly"
    UbermocUIAPI.registerBorder({ key = H.NP_OUT[gk], part = "nameplates", label = G .. " health bar outline", on = false, size = 1, maxSize = 8,
        legacy = function()
            local l = UbermocUIDB.nameplates and UbermocUIDB.nameplates[gk] and UbermocUIDB.nameplates[gk].look or {}
            local custom = UbermocUIAPI.borderOldDefault and not UbermocUIAPI.borderOldDefault(l.edgeR, l.edgeG, l.edgeB, 0, 0, 0)
            return l.edgeOn and true or false, l.edgeSize or 1, 100, custom and "custom" or "class", l.edgeR, l.edgeG, l.edgeB
        end,
        apply = function() if updateAllPlates then pcall(updateAllPlates) end; if UbermocUIAPI.refreshNpPreview then pcall(UbermocUIAPI.refreshNpPreview) end end })
    UbermocUIAPI.registerBorder({ key = H.NP_LVL[gk], part = "nameplates", label = G .. " level square border", size = 1, maxSize = 6,
        legacy = function()
            local l = UbermocUIDB.nameplates and UbermocUIDB.nameplates[gk] and UbermocUIDB.nameplates[gk].look or {}
            local custom = UbermocUIAPI.borderOldDefault and not UbermocUIAPI.borderOldDefault(l.lvlR, l.lvlG, l.lvlB, 0.55, 0.55, 0.6)
            return true, 1, 100, custom and "custom" or "class", l.lvlR, l.lvlG, l.lvlB
        end,
        apply = function() if updateAllPlates then pcall(updateAllPlates) end end })
end

-- Text in the same corner as the addon button container moves in past it (x offset, 0 if not).
function UbermocUIAPI.cornerShift(corner)
    local c = UbermocUIDB and UbermocUIDB.mm and UbermocUIDB.mm.box
    local b = _G.UbermocModBox
    if not (c and c.on and b and b:IsShown()) then return 0 end
    local bc = c.corner or "TOPRIGHT"
    if bc ~= corner then return 0 end
    local x = UbermocUIDB.mm.xp
    if bc == "TOPRIGHT" and x and x.on and x.attach and x.reserve then return 0 end   -- sits on the experience bar instead
    local w = (b:GetWidth() or 18) + 4
    return corner:find("LEFT") and w or -w
end
-- True when the rectangle (screen units of the map) touches the map's own text or the addon box.
H.mapTextFrames = { "UbermocPerfText", "UbermocMiniCoords", "UbermocModBox" }
-- (a plain function, not one made on every call: the compass asks this many times in a row)
local function mapHit(o, l, b, r, t)
    if not (o and o.IsVisible and o:IsVisible()) then return false end
    local ol, ob, ow, oh = o:GetRect()
    if not ol then return false end
    return r > ol and l < ol + ow and t > ob and b < ob + oh
end
function UbermocUIAPI.mapTextHit(l, b, r, t)
    for _, n in ipairs(H.mapTextFrames) do
        local f = _G[n]
        if f and mapHit(f.text or f, l, b, r, t) then return true end
    end
    local cl = UbermocUIAPI.clockLabel
    if cl and mapHit(cl.text or cl, l, b, r, t) then return true end
    return false
end

-- Asks to reload now (Reload UI / Later), in front of the settings window.
function H.askReload(text)
    if not StaticPopupDialogs then return end
    StaticPopupDialogs.UBERMOCUI_RELOAD = StaticPopupDialogs.UBERMOCUI_RELOAD or {
        text = "%s", button1 = "Reload UI", button2 = "Later", timeout = 0, whileDead = true, hideOnEscape = true,
        OnAccept = function() ReloadUI() end,
    }
    local f = StaticPopup_Show and StaticPopup_Show("UBERMOCUI_RELOAD", text)
    if f and f.SetFrameStrata then f:SetFrameStrata("FULLSCREEN_DIALOG"); if f.Raise then f:Raise() end end
end

-- The skin textures as a { { id, label }, ... } list for a cycler (built once Skin.lua has loaded).
H.skins = {}
function H.skinList()
    local L = H.skins
    if #L == 0 then
        for _, st in ipairs(UbermocUIAPI.SKIN_STYLES or {}) do L[#L + 1] = { st.id, st.id == "none" and "None" or st.label } end
        if #L == 0 then return { { "none", "None" } } end
    end
    return L
end

-- Cycler: [ < ] [ name ] [ > ] 3/9 for long lists. Hold < or > to keep going (with A on a controller);
-- clicking the name goes to the next one.
-- list() returns { { value, label }, ... }. Everything sits in c.frame.
function H.cycler(parent, x, y, w, list, get, set)
    local f = CreateFrame("Frame", nil, parent)
    f:SetPoint("TOPLEFT", x, y)
    f:SetSize(w + 60, 26)
    local c = { list = list, get = get, frame = f }
    c.step = function(dir)
        local L = c.list()
        local n = #L
        if n == 0 then return end
        local cur, at = c.get(), 0
        for i, o in ipairs(L) do if o[1] == cur then at = i; break end end
        if at == 0 then at = (dir > 0) and 0 or 1 end
        set(L[(at - 1 + (dir > 0 and 1 or -1)) % n + 1][1])
        c.refresh()
    end
    c.prev = newButton(f, "<", 26, 0, 0, nil)
    H.holdRepeat(c.prev, function() c.step(-1) end)
    c.box = newButton(f, "", w, 30, 0, function() c.step(1) end)
    c.box.ubNudge = c.step
    c.next = newButton(f, ">", 26, 34 + w, 0, nil)
    H.holdRepeat(c.next, function() c.step(1) end)
    c.count = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    c.count:SetPoint("LEFT", c.next, "RIGHT", 6, 0)
    c.refresh = function()
        local L = c.list()
        local cur, at = c.get(), 0
        for i, o in ipairs(L) do if o[1] == cur then at = i; break end end
        c.box:SetText(at > 0 and L[at][2] or "")
        c.count:SetText(at > 0 and (at .. " / " .. #L) or "")
    end
    return c
end

----------------------------------------------------------------------
-- Settings page: a list of every element, with its states on the right
----------------------------------------------------------------------
-- The element editor: a scrolling list of elements on the left and the selected
-- element's situations on the right. Used by the main page and the Chat page.
-- The Fade list is grouped under headings so it is quick to find a part.
local FADE_CATS = {
    { "Minimap", { "minimap", "minizone", "minihead", "miniclock", "minical", "minitrack", "minidiff", "minilanding", "minimail", "minidiel", "miniaddons", "minizoom", "queue",
                   "ui_xp", "ui_strip", "ui_info", "ui_box", "ui_compass", "ui_perf", "ui_clock" } },
    { "Action bars", { "mainbar", "sidebars", "abarcustom", "classbars", "vehiclebtn", "micro", "bags", "xpbar", "extra" } },
    { "Unit frames", { "player", "pet", "target", "tot", "focus", "fot", "boss", "arena", "party", "classres", "totem", "prd", "castbar" } },
    { "Halo frames (Ubermoc UI)", { "ringhud", "petframe", "ringtarget", "ringtot", "ringfocus", "ringfot", "partyframes", "raidframes" } },
    { "Floating frames (Ubermoc UI)", { "flplayer", "flpet", "fltarget", "fltot", "flfocus", "flfot", "flparty", "flraid" } },
    { "Nameplates", { "npenemy", "npfriendly" } },
    { "Auras and cooldowns", { "buffs", "debuffs", "cd_essential", "cd_utility", "cd_buffs", "cd_bars", "procs", "loc" } },
    { "Combat and encounters", { "meter", "encounter", "encwarn", "raidwarn" } },
    { "Alerts and loot", { "talkinghead", "errors", "zonetext", "banners", "alerts", "lootroll", "lootwin" } },
    { "Widgets and other", { "tracker", "widgettop", "widgetmini", "widgetpower", "altpower", "vehicle", "durability", "mirror", "archaeology", "fps" } },
}

local function buildEditor(parent, list)
    local idx = 1
    local rightPane, pickFS
    local listBtns, rows = {}, {}
    local nameFS, foundFS, hideCB, copyBtn, pasteBtn, clipFS
    local placeRows, upB, dnB

    local function framesFound(e)
        if e.plates or e.custom then return 1 end
        local n = 0
        for _, name in ipairs(e.frames) do if getFrame(name) then n = n + 1 end end
        return n
    end

    local function refresh()
        if placeRows then placeRows() end
        for i, e in ipairs(list) do
            local b = listBtns[i]
            if i == idx then b.sel:Show() else b.sel:Hide() end
            local o = UbermocUIDB.elements[e.key]
            if framesFound(e) == 0 then b.text:SetTextColor(0.5, 0.5, 0.5, 1)
            elseif o and next(o) ~= nil then b.text:SetTextColor(1, 0.82, 0, 1)
            else b.text:SetTextColor(1, 1, 1, 1) end
        end
        if rightPane then rightPane:SetShown(idx ~= nil) end
        if pickFS then pickFS:SetShown(idx == nil) end
        if not idx then return end
        local e = list[idx]
        nameFS:SetText(e.label)
        local n = framesFound(e)
        foundFS:SetText(e.plates and "Fades every nameplate of this kind."
            or e.custom and "Fades this part of Ubermoc UI (it appears once you switch it on)."
            or n == 0 and "Not available right now (class / arena only, or named differently here)."
            or ("Frames found: " .. n .. " of " .. #e.frames))
        local o = UbermocUIDB.elements[e.key] or {}
        hideCB:SetChecked(o.hide == true)
        for _, k in ipairs(STATE_KEYS) do
            local r = rows[k]
            local v = o[k]
            r:SetAlpha(o.hide and 0.5 or 1)
            r.cb:SetChecked(v ~= nil)
            setSlider(r.sl, v or 1)
            r.sl.text:SetText(v and pct(v) or "normal")
            setSliderActive(r.sl, v ~= nil)
        end
        local clip = UbermocUIDB.clipboard
        copyBtn:SetEnabled(next(o) ~= nil)
        pasteBtn:SetEnabled(clip ~= nil)
        clipFS:SetText(clip and ("Clipboard: " .. clip.from) or "Clipboard: empty")
    end

    -- Left: a scrollable list of every element.
    local VISIBLE, ROW = 12, 25
    local scroll = 0
    local totalRows = #list
    local scrollMax = math.max(0, (totalRows - VISIBLE) * ROW)
    -- Group the elements under headings (only for the long list).
    local useCats = #list > 8
    local groups, headers = {}, {}
    if useCats then
        local catOf = {}
        for ci, c in ipairs(FADE_CATS) do for _, k in ipairs(c[2]) do catOf[k] = ci end end
        for ci, c in ipairs(FADE_CATS) do groups[ci] = { name = c[1], items = {}, open = false } end
        groups[#groups + 1] = { name = "Other", items = {}, open = false }
        for i, e in ipairs(list) do
            local ci = catOf[e.key] or #groups
            local g = groups[ci]
            g.items[#g.items + 1] = i
        end
        idx = nil        -- nothing is picked until the player opens a heading and chooses
    end
    local clip = CreateFrame("Frame", nil, parent)
    clip:SetSize(176, VISIBLE * ROW)
    clip:SetPoint("TOPLEFT", 16, -100)
    clip:SetClipsChildren(true)
    local content = CreateFrame("Frame", nil, clip)
    content:SetSize(176, totalRows * ROW)
    content:SetPoint("TOPLEFT", clip, "TOPLEFT", 0, 0)

    local sb
    local function setScroll(v)
        v = math.max(0, math.min(scrollMax, v))
        scroll = v
        content:ClearAllPoints()
        content:SetPoint("TOPLEFT", clip, "TOPLEFT", 0, v)
        if sb then sb.silent = true; sb:SetValue(v); sb.silent = false end
    end
    local function onWheel(_, delta) setScroll(scroll - delta * ROW * 2) end
    clip:EnableMouseWheel(true)
    clip:SetScript("OnMouseWheel", onWheel)
    content:EnableMouseWheel(true)
    content:SetScript("OnMouseWheel", onWheel)

    sb = CreateFrame("Slider", nil, parent)
    sb.ubSkipCursor = true   -- the D-pad and triggers scroll this list
    sb:SetOrientation("VERTICAL")
    sb:SetSize(14, VISIBLE * ROW)
    sb:SetPoint("TOPLEFT", 196, -100)
    sb:EnableMouse(true)
    sb:SetMinMaxValues(0, math.max(scrollMax, 1))
    sb:SetValueStep(1)
    sb:SetObeyStepOnDrag(true)
    local sbg = sb:CreateTexture(nil, "BACKGROUND")
    sbg:SetAllPoints()
    sbg:SetColorTexture(1, 1, 1, 0.1)
    local thumb = sb:CreateTexture(nil, "OVERLAY")
    thumb:SetColorTexture(1, 0.82, 0, 0.7)
    thumb:SetSize(12, 40)
    sb:SetThumbTexture(thumb)
    sb:SetScript("OnValueChanged", function(self, v) if not self.silent then setScroll(v) end end)
    sb:SetValue(0)

    upB = newButton(parent, "Up", 84, 16, -404, nil)
    dnB = newButton(parent, "Down", 84, 108, -404, nil)
    H.holdRepeat(upB, function() setScroll(scroll - ROW * 3) end)
    H.holdRepeat(dnB, function() setScroll(scroll + ROW * 3) end)
    if scrollMax == 0 then sb:Hide(); upB:Hide(); dnB:Hide() end

    -- Elements you changed are marked in gold; with headings, each heading opens and closes its group.
    function placeRows()
        if useCats then
            local pos = 0
            for gi, g in ipairs(groups) do
                local h = headers[gi]
                if #g.items > 0 and h then
                    h:Show()
                    h:ClearAllPoints()
                    h:SetPoint("TOPLEFT", 0, -pos * ROW)
                    local mods = 0
                    for _, i in ipairs(g.items) do
                        local o = UbermocUIDB.elements[list[i].key]
                        if o and next(o) ~= nil then mods = mods + 1 end
                    end
                    h.text:SetText((g.open and "- " or "+ ") .. g.name .. (mods > 0 and (" (" .. mods .. " set)") or ""))
                    pos = pos + 1
                    for _, i in ipairs(g.items) do
                        local b = listBtns[i]
                        if b then
                            if g.open then
                                b:Show(); b:ClearAllPoints(); b:SetPoint("TOPLEFT", 8, -pos * ROW); pos = pos + 1
                            else
                                b:Hide()
                            end
                        end
                    end
                elseif h then
                    h:Hide()
                end
            end
            totalRows = pos
            content:SetSize(176, math.max(1, pos) * ROW)
            scrollMax = math.max(0, (pos - VISIBLE) * ROW)
            if sb then
                sb:SetMinMaxValues(0, math.max(scrollMax, 1))
                if scrollMax == 0 then sb:Hide() else sb:Show() end
            end
            if upB then upB:SetShown(scrollMax > 0) end
            if dnB then dnB:SetShown(scrollMax > 0) end
            if scroll > scrollMax then setScroll(scrollMax) end
            return
        end
        local pos = 0
        for pass = 1, 2 do
            for i, e in ipairs(list) do
                local o = UbermocUIDB.elements[e.key]
                local mod = (o and next(o) ~= nil) and true or false
                if (pass == 1) == mod and listBtns[i] then
                    listBtns[i]:ClearAllPoints()
                    listBtns[i]:SetPoint("TOPLEFT", 0, -pos * ROW)
                    pos = pos + 1
                end
            end
        end
    end

    if useCats then
        for gi, g in ipairs(groups) do
            local h = CreateFrame("Button", nil, content)
            h:SetSize(176, 24)
            h:EnableMouseWheel(true)
            h:SetScript("OnMouseWheel", onWheel)
            h.bg = h:CreateTexture(nil, "BACKGROUND")
            h.bg:SetAllPoints()
            h.bg:SetColorTexture(0.2, 0.23, 0.32, 0.9)
            h.text = h:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            h.text:SetPoint("LEFT", 6, 0)
            h.text:SetWidth(166)
            h.text:SetJustifyH("LEFT")
            h.text:SetWordWrap(false)
            h:SetScript("OnClick", function() g.open = not g.open; placeRows() end)
            headers[gi] = h
        end
    end

    for i, e in ipairs(list) do
        local b = CreateFrame("Button", nil, content)
        b:SetSize(176, 24)
        b:SetPoint("TOPLEFT", 0, -(i - 1) * ROW)
        b:EnableMouseWheel(true)
        b:SetScript("OnMouseWheel", onWheel)
        b.sel = b:CreateTexture(nil, "BACKGROUND")
        b.sel:SetAllPoints()
        b.sel:SetColorTexture(1, 0.8, 0.1, 0.22)
        b.sel:Hide()
        b.hover = b:CreateTexture(nil, "BACKGROUND")
        b.hover:SetAllPoints()
        b.hover:SetColorTexture(1, 1, 1, 0.08)
        b.hover:Hide()
        b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        b.text:SetPoint("LEFT", 8, 0)
        b.text:SetWidth(164)
        b.text:SetJustifyH("LEFT")
        b.text:SetWordWrap(false)
        b.text:SetText(e.label)
        b:SetScript("OnEnter", function() b.hover:Show() end)
        b:SetScript("OnLeave", function() b.hover:Hide() end)
        b:SetScript("OnClick", function()
            idx = i
            refresh()
        end)
        listBtns[i] = b
    end
    placeRows()

    -- Right: the selected element's settings.
    local rp = CreateFrame("Frame", nil, parent)
    rp:SetAllPoints(parent)
    rightPane = rp
    nameFS = rp:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    nameFS:SetPoint("TOPLEFT", 222, -100)
    foundFS = newLabel(rp, "", 222, -122, "GameFontHighlightSmall")

    hideCB = newCheck(rp, "Always hide this element", 222, -138, function(v)
        local e = list[idx]
        local t = UbermocUIDB.elements[e.key]
        if v then
            if not t then t = {}; UbermocUIDB.elements[e.key] = t end
            t.hide = true
        elseif t then
            t.hide = nil
            if next(t) == nil then UbermocUIDB.elements[e.key] = nil end
        end
        refresh()
        evaluate()
    end)

    -- The situation rows scroll too (mouse wheel or the Up / Down buttons).
    local RVIS, RROW = 11, 25
    local rScroll = 0
    local rMax = math.max(0, (#STATE_KEYS - RVIS) * RROW)
    local rClip = CreateFrame("Frame", nil, rp)
    rClip:SetSize(420, RVIS * RROW)
    rClip:SetPoint("TOPLEFT", 222, -172)
    rClip:SetClipsChildren(true)
    local rContent = CreateFrame("Frame", nil, rClip)
    rContent:SetSize(420, #STATE_KEYS * RROW)
    rContent:SetPoint("TOPLEFT", rClip, "TOPLEFT", 0, 0)
    local function setRowScroll(v)
        v = math.max(0, math.min(rMax, v))
        rScroll = v
        rContent:ClearAllPoints()
        rContent:SetPoint("TOPLEFT", rClip, "TOPLEFT", 0, v)
    end
    local function onRowWheel(_, delta) setRowScroll(rScroll - delta * RROW * 2) end
    rClip:EnableMouseWheel(true)
    rClip:SetScript("OnMouseWheel", onRowWheel)
    rContent:EnableMouseWheel(true)
    rContent:SetScript("OnMouseWheel", onRowWheel)

    for i, k in ipairs(STATE_KEYS) do
        local r = CreateFrame("Frame", nil, rContent)
        r:SetSize(420, 28)
        r:SetPoint("TOPLEFT", 0, -(i - 1) * RROW)
        r:EnableMouseWheel(true)
        r:SetScript("OnMouseWheel", onRowWheel)
        r.cb = newCheck(r, LABELS[k], 0, 0, function(v)
            local e = list[idx]
            local t = UbermocUIDB.elements[e.key]
            if v then
                if not t then t = {}; UbermocUIDB.elements[e.key] = t end
                t[k] = 0.4
            elseif t then
                t[k] = nil
                if next(t) == nil then UbermocUIDB.elements[e.key] = nil end
            end
            refresh()
            evaluate()
        end, "GameFontHighlightSmall")
        r.sl = makeSlider(r, 100, 0, 1, 0.05, pct, function(v)
            local t = UbermocUIDB.elements[list[idx].key]
            if t then t[k] = v end
            evaluate()
        end)
        r.sl:SetPoint("TOPLEFT", 194, -3)
        rows[k] = r
    end

    -- Scroll, copy and paste. Copy takes everything set on this element (situations
    -- and Always hide); Paste replaces the selected element's settings with it.
    local rowUp = newButton(rp, "Up", 74, 222, -452, nil)
    local rowDown = newButton(rp, "Down", 74, 300, -452, nil)
    H.holdRepeat(rowUp, function() setRowScroll(rScroll - RROW * 3) end)
    H.holdRepeat(rowDown, function() setRowScroll(rScroll + RROW * 3) end)
    if rMax == 0 then rowUp:Hide(); rowDown:Hide() end
    copyBtn = newButton(rp, "Copy", 70, 384, -452, function()
        local e = list[idx]
        local o = UbermocUIDB.elements[e.key]
        if o and next(o) ~= nil then
            UbermocUIDB.clipboard = { from = e.label, data = copyTable(o) }
            refresh()
        end
    end)
    pasteBtn = newButton(rp, "Paste", 70, 458, -452, function()
        local clip = UbermocUIDB.clipboard
        if clip then
            UbermocUIDB.elements[list[idx].key] = copyTable(clip.data)
            refresh()
            evaluate()
        end
    end)
    newButton(rp, "Clear this element", 170, 222, -482, function()
        UbermocUIDB.elements[list[idx].key] = nil
        refresh()
        evaluate()
    end)
    clipFS = newLabel(rp, "", 400, -487, "GameFontHighlightSmall")

    pickFS = newLabel(parent, "Open a heading on the left (Minimap, Action bars, Unit frames ...) and pick a part to adjust how it fades.", 222, -104, "GameFontHighlight")
    pickFS:SetWidth(400); pickFS:SetJustifyH("LEFT"); pickFS:SetWordWrap(true)
    pickFS:SetShown(idx == nil)
    if rightPane then rightPane:SetShown(idx ~= nil) end
    local hint1 = newLabel(parent, "An element uses the first active situation (top wins) that it has a value for; Idle applies when none do.", 16, -436, "GameFontHighlightSmall")
    hint1:SetWidth(186); hint1:SetJustifyH("LEFT"); hint1:SetWordWrap(true)
    return refresh
end

-- Colour of the part of the name that stands for missing health.
local MISS_COLORS = {
    WHITE = { 1, 1, 1 }, GRAY = { 0.55, 0.55, 0.55 }, RED = { 0.9, 0.15, 0.15 }, BLACK = { 0.1, 0.1, 0.1 },
}

-- Health as 0..1, or nil when WoW hides it right now.
function H.healthFractionBody(unit)
        if UnitHealthPercent and CurveConstants and CurveConstants.ScaleTo100 then
            local pctv = UnitHealthPercent(unit, false, CurveConstants.ScaleTo100)
            if type(pctv) == "number" and not isHidden(pctv) then return pctv / 100 end
        end
        local cur, max = UnitHealth(unit), UnitHealthMax(unit)
        if type(cur) == "number" and type(max) == "number" and not isHidden(cur) and not isHidden(max) and max > 0 then
            return cur / max
        end
        return nil
end
local function healthFraction(unit)
    local ok, v = pcall(H.healthFractionBody, unit)
    if ok then return v end
    return nil
end

local function hex(r, g, b)
    return ("|cff%02x%02x%02x"):format(math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

-- The name with its class colour on the left and the missing-health colour on the right.
local function gradientText(nm, class, frac, missKey)
    local chars = {}
    for ch in nm:gmatch("[%z\1-\127\194-\244][\128-\191]*") do chars[#chars + 1] = ch end
    local n = #chars
    if n == 0 then return nm end
    local k = math.max(0, math.min(n, math.floor(frac * n + 0.5)))
    local m = MISS_COLORS[missKey] or MISS_COLORS.WHITE
    local out = hex(class.r, class.g, class.b) .. table.concat(chars, "", 1, k) .. "|r"
    if k < n then out = out .. hex(m[1], m[2], m[3]) .. table.concat(chars, "", k + 1, n) .. "|r" end
    return out
end

-- Other addons ask the game for the minimap shape to put their buttons on its edge.
local origMinimapShape = GetMinimapShape
function GetMinimapShape()
    if UbermocUIDB and UbermocUIDB.squareMinimap then return "SQUARE" end
    if origMinimapShape then return origMinimapShape() end
    return "ROUND"
end

local category, nameplateSub, chatSub, timingSub, timingPanel

local function buildPanel()
    panel = CreateFrame("Frame")
    panel.name = "Ubermoc UI"
    newLabel(panel, "Ubermoc UI", 16, -16, "GameFontNormalHuge")
    newLabel(panel, "Pick an element, then tick the situations where it should fade. Changes apply live.", 16, -42, "GameFontHighlightSmall")

    local enableCB = newCheck(panel, "Enabled", 16, -62, function(v) UbermocUIDB.enabled = v; evaluate() end)

    local refreshEditor = buildEditor(panel, MAIN_LIST)
    local hint2 = newLabel(panel, "Controller: bind 'Reveal UI' in Key Bindings > AddOns, or use /ubermoc reveal in a macro. /ubermoc help lists commands.", 16, -486, "GameFontHighlightSmall")
    hint2:SetWidth(186); hint2:SetJustifyH("LEFT"); hint2:SetWordWrap(true)

    refreshPanel = function()
        enableCB:SetChecked(UbermocUIDB.enabled)
        refreshEditor()
    end

    panel:Hide()
    if UbermocUI_AttachReload then UbermocUI_AttachReload(panel) end
    panel:SetScript("OnShow", function() refreshPanel(); evaluate() end)
    panel:SetScript("OnHide", evaluate)

    UbermocUIAPI.addPage("fade", "Fade Rules", panel)
    UbermocUIAPI.makeLauncher()
end

-- Reload UI sits beside the Close button. It is a child of the settings window
-- (not of the page) so the page's edge does not clip it, and it is shown only
-- while the given page is open.
local reloadBtn
local reloadShown = {}
local function placeReload(page)
    if not reloadBtn then
        reloadBtn = CreateFrame("Button", "UbermocUIReloadButton", SettingsPanel or UIParent, "UIPanelButtonTemplate")
        reloadBtn:SetSize(110, 26)
        reloadBtn:SetText("Reload UI")
        reloadBtn:SetFrameStrata("DIALOG")
        reloadBtn:SetScript("OnClick", function() ReloadUI() end)
    end
    local close = SettingsPanel and (SettingsPanel.CloseButton or (SettingsPanel.Container and SettingsPanel.Container.CloseButton))
    reloadBtn:ClearAllPoints()
    if close and close.GetObjectType then
        reloadBtn:SetPoint("RIGHT", close, "LEFT", -8, 0)
    elseif SettingsPanel then
        reloadBtn:SetPoint("BOTTOMRIGHT", SettingsPanel, "BOTTOMRIGHT", -150, 14)
    else
        reloadBtn:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -8, 8)
    end
    reloadBtn:Show()
end

-- The window has its own Reload UI button in its footer.
local function attachReload(page) end

UbermocUI_AttachReload = attachReload

-- Small toolkit shared with Extras.lua (rings, pet frame, interact).
for k, v in pairs({
    makeSlider = makeSlider, setSlider = setSlider, setSliderActive = setSliderActive, newCheck = newCheck, newLabel = newLabel,
    newButton = newButton, attachReload = attachReload, subs = {}, evaluate = function() evaluate() end,
    segRow = H.segRow, cycler = H.cycler, askReload = H.askReload, skinList = H.skinList, CORNER4_CELLS = H.CORNER4_CELLS, cornerPick = H.cornerPick, sliderDefault = H.sliderDefault, holdRepeat = H.holdRepeat,
    getCategory = function() return category end,
}) do UbermocUIAPI[k] = v end

----------------------------------------------------------------------
-- The options window: one window of its own with a page list on the left.
----------------------------------------------------------------------
UbermocUIAPI.pages = {}
-- Capitalises the first letter of every word (used on tab and menu names).
function UbermocUIAPI.titleCase(str)
    return (tostring(str or ""):gsub("(%a)([%w']*)", function(a, b) return a:upper() .. b end))
end
UbermocUIAPI.NAV = {
    { "Controller", { "controller", "rings", "interact", "aim" } },
    { "Interface", { "nameplates", "gameopts", "chat", "mm", "unitframes", "combo", "textures", "toolbar", "abar", "npc", "misc", "dark" } },
    { "Minimal UI", { "fading" } },
    { "Tools", { "debug" } },
}

-- Settings pages that are only built the first time the settings window opens (or frames are unlocked):
-- their hundreds of sliders and buttons cost memory for the whole session otherwise.
UbermocUIAPI.deferred = UbermocUIAPI.deferred or {}
function UbermocUIAPI.later(label, fn)
    local list = UbermocUIAPI.deferred
    list[#list + 1] = { label, fn }
end
function UbermocUIAPI.runDeferred()
    local list = UbermocUIAPI.deferred
    if #list == 0 then return end
    UbermocUIAPI.deferred = {}
    for _, d in ipairs(list) do
        local ok, err = pcall(d[2])
        if not ok then print("|cffff4444Ubermoc UI|r " .. tostring(d[1]) .. " page failed: " .. tostring(err)) end
    end
end

function UbermocUIAPI.addPage(key, label, panel)
    if type(label) == "table" then panel = label; label = panel.name end   -- addPage(key, panel)
    panel.name = panel.name or label
    panel:Hide()
    UbermocUIAPI.pages[key] = { key = key, label = label, panel = panel }
    if UbermocUIAPI.win and UbermocUIAPI.layoutNav then UbermocUIAPI.layoutNav() end
end

-- Pages that are shown as tabs of one page (Fading = fade rules + fade timing).
UbermocUIAPI.COMPOSITES = {
    fading = { label = "Fading", subs = { { "fade", "Rules" }, { "timing", "Timing" } } },
    unitframes = { label = "Unit Frames", subs = { { "uf_player", "Player" }, { "uf_pet", "Pet" }, { "uf_target", "Target" },
        { "uf_tot", "Target of Target" }, { "uf_focus", "Focus" }, { "uf_fot", "Focus Target" }, { "uf_party", "Party" },
        { "uf_raid", "Raid" } } },
}
UbermocUIAPI.subOf = { fade = { "fading", 1 }, timing = { "fading", 2 },
    ringhud = { "unitframes", 1 }, ringpet = { "unitframes", 2 }, ringtarget = { "unitframes", 3 }, ringtot = { "unitframes", 4 },
    ringfocus = { "unitframes", 5 }, ringfot = { "unitframes", 6 }, party = { "unitframes", 7 }, raid = { "unitframes", 8 }, targetframe = { "unitframes", 3 } }

-- Reset to defaults: each page registers a function; the window's footer button runs it.
UbermocUIAPI.resetters = UbermocUIAPI.resetters or {}
do
    local function deep(t)
        if type(t) ~= "table" then return t end
        local c = {}
        for k, v in pairs(t) do c[k] = deep(v) end
        return c
    end
    local function resetKeys(keys)
        local d = defaults()
        for _, k in ipairs(keys) do UbermocUIDB[k] = deep(d[k]) end
    end
    local R = UbermocUIAPI.resetters
    R.fade = function() UbermocUIDB.elements = {}; pcall(UbermocUIAPI.evaluate) end
    R.timing = function()
        resetKeys({ "fadeTime", "mouse" })
        UbermocUIDB.fadeInTime, UbermocUIDB.fadeOutTime = nil, nil
        pcall(UbermocUIAPI.evaluate)
    end
    R.chat = function() resetKeys({ "chat" }); pcall(UbermocUIAPI.evaluate) end
    R.nameplates = function() resetKeys({ "nameplates" }); pcall(UbermocUIAPI.evaluate) end
    R.misc = function()
        resetKeys({ "vendor", "tooltipAtCursor" })
        if UbermocUIAPI.applySquare then pcall(UbermocUIAPI.applySquare) end
    end
end

function UbermocUIAPI.ensureComposites()
    local A = UbermocUIAPI.accent
    for key, c in pairs(UbermocUIAPI.COMPOSITES) do
        if not UbermocUIAPI.pages[key] then
            local ready = true
            for _, s in ipairs(c.subs) do if not UbermocUIAPI.pages[s[1]] then ready = false end end
            if ready then
                local H = CreateFrame("Frame")
                H.tabs = {}
                H.cur = 1
                local bar = CreateFrame("Frame", nil, H)
                bar:SetPoint("TOPLEFT"); bar:SetPoint("TOPRIGHT"); bar:SetHeight(38)
                local line = bar:CreateTexture(nil, "ARTWORK")
                line:SetColorTexture(0.2, 0.23, 0.3, 1)
                line:SetPoint("BOTTOMLEFT"); line:SetPoint("BOTTOMRIGHT"); line:SetHeight(1)
                local area = CreateFrame("Frame", nil, H)
                area:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, 0)
                area:SetPoint("BOTTOMRIGHT")
                H.area = area
                local function select(i)
                    H.cur = i
                    UbermocUIDB.ui = UbermocUIDB.ui or {}
                    UbermocUIDB.ui.tab = i
                    for j, s in ipairs(c.subs) do
                        local pg = UbermocUIAPI.pages[s[1]]
                        local t = H.tabs[j]
                        t:SetSelected(j == i)
                        if j == i then
                            pg.panel:SetParent(area)
                            pg.panel:ClearAllPoints()
                            pg.panel:SetAllPoints(area)
                            pg.panel:Show()
                        else
                            pg.panel:Hide()
                        end
                    end
                end
                H.select = select
                local x, row = 14, 0
                local ROWW = 740
                for i, s in ipairs(c.subs) do
                    local t = CreateFrame("Button", nil, bar)
                    t.text = t:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                    t.text:SetPoint("CENTER", 0, 1)
                    t.text:SetText(UbermocUIAPI.titleCase(s[2]))
                    local tw = math.max(80, math.ceil((t.text:GetStringWidth() or 90) + 28))
                    if x + tw > ROWW and x > 14 then x = 14; row = row + 1 end
                    t:SetSize(tw, 38)
                    t:SetPoint("TOPLEFT", x, -row * 38)
                    x = x + tw + 2
                    t.under = t:CreateTexture(nil, "ARTWORK")
                    t.under:SetColorTexture(A[1], A[2], A[3], 1)
                    t.under:SetPoint("BOTTOMLEFT"); t.under:SetPoint("BOTTOMRIGHT"); t.under:SetHeight(3)
                    t:SetHighlightTexture(UbermocUIAPI.WHITE)
                    local ht = t:GetHighlightTexture()
                    if ht then ht:SetVertexColor(1, 1, 1, 0.06) end
                    t.SetSelected = function(self, on)
                        self.under:SetShown(on)
                        if on then self.text:SetTextColor(1, 1, 1) else self.text:SetTextColor(0.7, 0.74, 0.82) end
                    end
                    t:SetScript("OnClick", function() select(i) end)
                    H.tabs[i] = t
                end
                bar:SetHeight(38 * (row + 1))
                H:SetScript("OnShow", function() select(H.cur) end)
                H:Hide()
                UbermocUIAPI.pages[key] = { key = key, label = c.label, panel = H, composite = H }
            end
        end
    end
end

-- Turns a long scrolling page into tabs. Every control that sits directly on the page is sorted into
-- a tab by its vertical position: defs = { { "Tab name", startY }, ... } with startY going down
-- (0, -350, ...). Only the chosen tab's controls are shown and they are moved up to the top.
----------------------------------------------------------------------
-- Lock / unlock: drag the frames and wheels where you want them
----------------------------------------------------------------------
UbermocUIAPI.moverList = {}
UbermocUIAPI.unlocked = false

function UbermocUIAPI.registerMover(label, getInfo, setPos)
    local list = UbermocUIAPI.moverList
    list[#list + 1] = { label = label, info = getInfo, set = setPos }
end

function UbermocUIAPI.makeMoverFrame(m)
    local A = UbermocUIAPI.accent
    local f = CreateFrame("Frame", nil, UIParent)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetFrameLevel(50)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(A[1], A[2], A[3], 0.28)
    for _, e in ipairs({ { "TOPLEFT", "TOPRIGHT", 1, true }, { "BOTTOMLEFT", "BOTTOMRIGHT", 1, true },
                         { "TOPLEFT", "BOTTOMLEFT", 1, false }, { "TOPRIGHT", "BOTTOMRIGHT", 1, false } }) do
        local t = f:CreateTexture(nil, "BORDER")
        t:SetColorTexture(A[1], A[2], A[3], 0.95)
        t:SetPoint(e[1]); t:SetPoint(e[2])
        if e[4] then t:SetHeight(2) else t:SetWidth(2) end
    end
    local fs = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fs:SetPoint("CENTER")
    fs:SetText(m.label)
    fs:SetWidth(200)
    f.fs = fs
    f:SetScript("OnDragStart", function(self)
        if InCombatLockdown() then return end
        self.dragging = true
        self:StartMoving()
    end)
    local acc = 0
    local function report(self)
        local cx, cy = self:GetCenter()
        local ux, uy = UIParent:GetCenter()
        if not (cx and ux) then return end
        local s = self:GetEffectiveScale() / UIParent:GetEffectiveScale()
        local x = math.floor((cx * s - ux) + 0.5)
        local y = math.floor((cy * s - uy) + 0.5)
        pcall(m.set, x, y)
    end
    -- the controller pointer can pick it up and carry it with the D-pad
    f.ubMover = true
    UbermocUIAPI.moverFrames = UbermocUIAPI.moverFrames or {}
    UbermocUIAPI.moverFrames[#UbermocUIAPI.moverFrames + 1] = f
    f.ubReport = function() report(f) end
    f:SetScript("OnUpdate", function(self, dt)
        if not self.dragging then return end
        acc = acc + dt
        if acc < 0.05 then return end
        acc = 0
        report(self)
    end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        self.dragging = false
        report(self)
        UbermocUIAPI.refreshMovers()
    end)
    f:Hide()
    return f
end

function UbermocUIAPI.refreshMovers()
    for _, m in ipairs(UbermocUIAPI.moverList) do
        local ok, en, x, y, w, h = pcall(m.info)
        if ok and en and UbermocUIAPI.unlocked then
            m.frame = m.frame or UbermocUIAPI.makeMoverFrame(m)
            local f = m.frame
            if not f.dragging then
                f:ClearAllPoints()
                f:SetSize(math.max(40, w or 80), math.max(40, h or 80))
                f:SetPoint("CENTER", UIParent, "CENTER", x or 0, y or 0)
            end
            f:Show()
        elseif m.frame then
            m.frame:Hide()
        end
    end
end

function UbermocUIAPI.lockBar()
    if UbermocUIAPI.lockBarF then return UbermocUIAPI.lockBarF end
    local A = UbermocUIAPI.accent
    local f = CreateFrame("Frame", "UbermocLockBar", UIParent)
    f:SetSize(430, 56)
    f:SetPoint("TOP", UIParent, "TOP", 0, -50)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetFrameLevel(100)
    f:EnableMouse(true)
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.04, 0.045, 0.06, 0.95)
    local ln = f:CreateTexture(nil, "BORDER")
    ln:SetPoint("BOTTOMLEFT"); ln:SetPoint("BOTTOMRIGHT"); ln:SetHeight(2)
    ln:SetColorTexture(A[1], A[2], A[3], 1)
    local t = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    t:SetPoint("LEFT", 14, 0)
    t:SetText("Frames unlocked: A picks one up, the D-pad moves it, A puts it down.")
    t:SetWidth(290); t:SetJustifyH("LEFT"); t:SetWordWrap(true)
    local b = CreateFrame("Button", nil, f)
    UbermocUIAPI.flatButton(b)
    b:SetSize(120, 28)
    b:SetPoint("RIGHT", -12, 0)
    b:SetText("Lock")
    b:SetScript("OnClick", function() UbermocUIAPI.setUnlocked(false) end)
    f:SetScript("OnHide", function()
        if UbermocUIAPI.unlocked then UbermocUIAPI.setUnlocked(false) end
    end)
    f:Hide()
    table.insert(UISpecialFrames, "UbermocLockBar")
    UbermocUIAPI.lockBarF = f
    return f
end

function UbermocUIAPI.setUnlocked(v)
    if v then UbermocUIAPI.runDeferred() end
    v = v and true or false
    if v and InCombatLockdown() then
        if UbermocUIAPI.uiPrint then UbermocUIAPI.uiPrint("Can't unlock frames in combat.") end
        return
    end
    if v == UbermocUIAPI.unlocked then return end
    -- A controller press can arrive as a press and a release: the release would land on the Lock button
    -- that has just appeared under the pointer and lock everything again. Ignore locking for a moment.
    if not v and GetTime() - (UbermocUIAPI.unlockedAt or 0) < 0.8 then
        local bar = UbermocUIAPI.lockBarF
        if bar and not bar:IsShown() then bar:Show() end
        return
    end
    if v then UbermocUIAPI.unlockedAt = GetTime() end
    UbermocUIAPI.unlocked = v
    local bar = UbermocUIAPI.lockBar()
    if v then
        if UbermocUIAPI.win and UbermocUIAPI.win:IsShown() then UbermocUIAPI.win:Hide() end
        bar:Show()
        -- the controller pointer moves over to the frames
        if UbermocUIAPI.cursorRestart then C_Timer.After(0.1, function() pcall(UbermocUIAPI.cursorRestart) end) end
    else
        for _, m in ipairs(UbermocUIAPI.moverList) do if m.frame then m.frame:Hide() end end
        bar:Hide()
        local W = UbermocUIAPI.win
        if not (W and W:IsShown()) then UbermocUIAPI.openWindow() end
    end
    UbermocUIAPI.refreshMovers()
end

function UbermocUIAPI.newLockButton(parent, x, y)
    local b = UbermocUIAPI.newButton(parent, "Unlock to move frames", 190, x, y, function()
        UbermocUIAPI.setUnlocked(true)
    end)
    return b
end

function UbermocUIAPI.makeTabs(panel, scroll, p, defs, barY)
    barY = barY or 0
    local A = UbermocUIAPI.accent or { 0.3, 0.6, 1 }
    local info, order = {}, {}
    local function add(o)
        if info[o] then return end
        local okN, n = pcall(o.GetNumPoints, o)
        if not okN or type(n) ~= "number" or n < 1 then return end
        local point, rel, relPoint, x, y = o:GetPoint(1)
        info[o] = { point = point, rel = rel, relPoint = relPoint, x = x or 0, y = y or 0, n = n, shown = o:IsShown() }
        order[#order + 1] = o
    end
    for _, o in ipairs({ p:GetChildren() }) do add(o) end
    for _, o in ipairs({ p:GetRegions() }) do add(o) end
    local function absY(o, depth)
        local i = info[o]
        if not i or depth > 6 then return nil end
        if i.rel == p or i.rel == nil then return i.y end
        local a = absY(i.rel, depth + 1)
        if a then return a + i.y end
        return nil
    end
    local tabOf, lowest = {}, {}
    for _, o in ipairs(order) do
        local y = absY(o, 0)
        if y then
            local t = 1
            for k = 1, #defs do if y <= defs[k][2] then t = k end end
            tabOf[o] = t
            lowest[t] = math.min(lowest[t] or 0, y - 30)
        end
    end
    local bar = CreateFrame("Frame", nil, panel)
    bar:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, barY)
    bar:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, barY)
    bar:SetHeight(38)
    local line = bar:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(0.2, 0.23, 0.3, 1)
    line:SetPoint("BOTTOMLEFT"); line:SetPoint("BOTTOMRIGHT"); line:SetHeight(1)
    local _, _, _, bx, by = scroll:GetPoint(2)
    scroll:ClearAllPoints()
    scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, barY - 42)
    scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", bx or -30, by or 8)
    local tabs = {}
    local function select(i)
        local start = defs[i][2]
        for _, o in ipairs(order) do
            local t = tabOf[o]
            if t then
                if t == i then
                    local inf = info[o]
                    if (inf.rel == p or inf.rel == nil) and inf.n == 1 then
                        o:ClearAllPoints()
                        o:SetPoint(inf.point, p, inf.relPoint, inf.x, inf.y - start - (i > 1 and 6 or 0))
                    end
                    o:SetShown(inf.shown)
                else
                    o:Hide()
                end
            end
        end
        local h = (lowest[i] or -400) - start
        p:SetHeight(math.max(200, -h + 20))
        scroll:SetVerticalScroll(0)
        for j, b in ipairs(tabs) do b:SetSelected(j == i) end
    end
    local x = 14
    for i, d in ipairs(defs) do
        local b = CreateFrame("Button", nil, bar)
        b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        b.text:SetPoint("CENTER", 0, 1)
        b.text:SetText(UbermocUIAPI.titleCase(d[1]))
        local w = math.max(70, (b.text:GetStringWidth() or 60) + 26)
        b:SetSize(w, 38)
        b:SetPoint("BOTTOMLEFT", x, 0)
        x = x + w + 2
        b.under = b:CreateTexture(nil, "ARTWORK")
        b.under:SetColorTexture(A[1], A[2], A[3], 1)
        b.under:SetPoint("BOTTOMLEFT"); b.under:SetPoint("BOTTOMRIGHT"); b.under:SetHeight(3)
        b:SetHighlightTexture(UbermocUIAPI.WHITE)
        local ht = b:GetHighlightTexture()
        if ht then ht:SetVertexColor(1, 1, 1, 0.06) end
        b.ubTab = tabs   -- the bumpers step through these
        b.SetSelected = function(self, on)
            self.ubSel = on
            self.under:SetShown(on)
            if on then self.text:SetTextColor(1, 1, 1) else self.text:SetTextColor(0.7, 0.74, 0.82) end
        end
        b:SetScript("OnClick", function() select(i) end)
        tabs[i] = b
    end
    select(1)
    return select
end

-- A tab strip with the same look as makeTabs, for pages that switch what they show (not scroll to a part).
-- defs = { { key, label }, ... }; onSelect(key) runs on a press; strip.mark(key) only lights a tab.
function UbermocUIAPI.tabStrip(panel, barY, defs, onSelect)
    local A = UbermocUIAPI.accent or { 0.3, 0.6, 1 }
    local strip = { tabs = {} }
    local bar = CreateFrame("Frame", nil, panel)
    bar:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, barY or 0)
    bar:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, barY or 0)
    bar:SetHeight(38)
    local line = bar:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(0.2, 0.23, 0.3, 1)
    line:SetPoint("BOTTOMLEFT"); line:SetPoint("BOTTOMRIGHT"); line:SetHeight(1)
    strip.bar = bar
    function strip.mark(key)
        for _, b in ipairs(strip.tabs) do
            local on = b.key == key
            b.ubSel = on
            b.under:SetShown(on)
            if on then b.text:SetTextColor(1, 1, 1) else b.text:SetTextColor(0.7, 0.74, 0.82) end
        end
    end
    for i, d in ipairs(defs) do
        local b = CreateFrame("Button", nil, bar)
        b.key = d[1]
        b.ubTab = strip.tabs   -- the bumpers step through these
        b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        b.text:SetPoint("CENTER", 0, 1)
        b.text:SetText(UbermocUIAPI.titleCase(d[2]))
        b.under = b:CreateTexture(nil, "ARTWORK")
        b.under:SetColorTexture(A[1], A[2], A[3], 1)
        b.under:SetPoint("BOTTOMLEFT"); b.under:SetPoint("BOTTOMRIGHT"); b.under:SetHeight(3)
        b:SetHighlightTexture(UbermocUIAPI.WHITE)
        local ht = b:GetHighlightTexture()
        if ht then ht:SetVertexColor(1, 1, 1, 0.06) end
        b:SetScript("OnClick", function() strip.mark(b.key); onSelect(b.key) end)
        strip.tabs[i] = b
    end
    -- Fit the tabs to the window: normal size if they fit, tighter if not, and a second row if still too wide.
    -- strip.onHeight(h) lets the page move its content under the tabs.
    function strip.fit()
        local avail = (bar:GetWidth() or 0) - 20
        if avail < 100 then avail = 900 end
        local function widths(pad, minW)
            local sum = 0
            for _, b in ipairs(strip.tabs) do
                b.ubW = math.max(minW, (b.text:GetStringWidth() or 60) + pad)
                sum = sum + b.ubW + 2
            end
            return sum
        end
        local rows = 1
        if widths(26, 70) > avail and widths(14, 0) > avail then rows = 2 end
        local rowH = 32
        local perRow = rows == 2 and math.ceil(#strip.tabs / 2) or #strip.tabs
        local h = rows == 2 and (rowH * 2) or 38
        bar:SetHeight(h)
        local x, r = 14, 0
        for i, b in ipairs(strip.tabs) do
            local newRow = rows == 2 and i == perRow + 1
            if newRow then x, r = 14, 1 end
            b:SetSize(b.ubW, rows == 2 and rowH or 38)
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", bar, "TOPLEFT", x, -r * rowH)
            x = x + b.ubW + 2
        end
        if strip.height ~= h then strip.height = h; if strip.onHeight then pcall(strip.onHeight, h) end end
    end
    bar:SetScript("OnSizeChanged", function() strip.fit() end)
    strip.fit()
    strip.mark(defs[1] and defs[1][1])
    return strip
end

-- What WoW's own Settings window shows for the addon: a single page that opens our window.
function UbermocUIAPI.makeLauncher()
    local L = CreateFrame("Frame")
    L.name = "Ubermoc UI"
    local t = L:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    t:SetPoint("TOPLEFT", 16, -16)
    t:SetText("Ubermoc UI")
    local d = L:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    d:SetPoint("TOPLEFT", 16, -52)
    d:SetText("The options open in their own window. Press the button to open it.")
    local b = CreateFrame("Button", nil, L, "UIPanelButtonTemplate")
    b:SetSize(280, 44)
    b:SetPoint("CENTER", L, "CENTER", 0, 0)
    b:SetText("Open Ubermoc UI")
    b:SetScript("OnClick", function()
        local W = UbermocUIAPI.win
        if not (W and W:IsShown()) then UbermocUIAPI.openWindow() end
        -- the game's options window (and its menu) close behind ours, and the controller pointer moves over
        if not InCombatLockdown() then
            pcall(function()
                if _G.SettingsPanel and _G.SettingsPanel:IsShown() then
                    if HideUIPanel then HideUIPanel(_G.SettingsPanel) else _G.SettingsPanel:Hide() end
                end
                if _G.GameMenuFrame and _G.GameMenuFrame:IsShown() then HideUIPanel(_G.GameMenuFrame) end
            end)
        end
        if UbermocUIAPI.cursorRestart then C_Timer.After(0.1, function() pcall(UbermocUIAPI.cursorRestart) end) end
    end)
    if Settings and Settings.RegisterCanvasLayoutCategory then
        category = Settings.RegisterCanvasLayoutCategory(L, L.name)
        Settings.RegisterAddOnCategory(category)
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(L)
    end
end

function UbermocUIAPI.buildWindow()
    local A = UbermocUIAPI.accent
    local W = CreateFrame("Frame", "UbermocUIWindow", UIParent)
    W:SetSize(960, 660)
    W:SetPoint("CENTER")
    W:SetFrameStrata("FULLSCREEN_DIALOG")
    W:SetToplevel(true)
    W:SetMovable(true)
    W:SetClampedToScreen(true)
    W:EnableMouse(true)
    W:RegisterForDrag("LeftButton")
    W:SetScript("OnDragStart", function(self) self:StartMoving() end)
    W:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    W:Hide()
    local fit = math.min(1, (UIParent:GetHeight() - 30) / 660, (UIParent:GetWidth() - 30) / 960)
    local saved = UbermocUIDB and UbermocUIDB.ui and UbermocUIDB.ui.scale
    W:SetScale(type(saved) == "number" and saved or (fit > 0.4 and fit or 1))
    -- Not a "special window": opening the spell book, bags and so on must not close it. It closes with its X or Escape.
    W:EnableKeyboard(true)
    W:SetPropagateKeyboardInput(true)   -- every press but Escape goes on to the bindings (the controller pointer)
    W:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" and not InCombatLockdown() then
            self:SetPropagateKeyboardInput(false)
            self:Hide()
        elseif not InCombatLockdown() then
            self:SetPropagateKeyboardInput(true)
        end
    end)
    local function solid(parent, layer, sub, r, g, b, a)
        local t = parent:CreateTexture(nil, layer, nil, sub or 0)
        t:SetColorTexture(r, g, b, a or 1)
        return t
    end
    local rim = solid(W, "BACKGROUND", -3, 0.20, 0.23, 0.30, 1)
    rim:SetPoint("TOPLEFT", -1, 1); rim:SetPoint("BOTTOMRIGHT", 1, -1)
    local bg = solid(W, "BACKGROUND", -2, 0.055, 0.062, 0.08, 0.985)
    bg:SetAllPoints()

    -- Header
    local head = CreateFrame("Frame", nil, W)
    head:SetPoint("TOPLEFT"); head:SetPoint("TOPRIGHT"); head:SetHeight(46)
    head:EnableMouse(true)
    head:RegisterForDrag("LeftButton")
    head:SetScript("OnDragStart", function() W:StartMoving() end)
    head:SetScript("OnDragStop", function() W:StopMovingOrSizing() end)
    local hbg = solid(head, "BACKGROUND", -1, 0.075, 0.085, 0.11, 1)
    hbg:SetAllPoints()
    local accent = solid(head, "ARTWORK", 0, A[1], A[2], A[3], 1)
    accent:SetPoint("BOTTOMLEFT"); accent:SetPoint("BOTTOMRIGHT"); accent:SetHeight(2)
    local title = head:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    title:SetPoint("LEFT", 18, 1)
    title:SetText("Ubermoc UI")
    title:SetTextColor(1, 1, 1)
    local ver = head:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    ver:SetPoint("LEFT", title, "RIGHT", 8, -2)
    local okv, v = pcall(function() return (C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata)("UbermocUI", "Version") end)
    ver:SetText(okv and v and ("v" .. v) or "")
    local x = CreateFrame("Button", nil, head)
    x:SetSize(46, 46)
    x:SetPoint("RIGHT")
    -- How to move through the options with a controller, always in the title bar (in the labels of the controller in use).
    local howTo = head:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    howTo:SetPoint("RIGHT", x, "LEFT", -8, 0)
    howTo:SetJustifyH("RIGHT")
    howTo:SetWordWrap(false)
    W.howTo = howTo
    local function paintHowTo()
        howTo:SetText(UbermocUIAPI.pointerHintText and UbermocUIAPI.pointerHintText("  ") or "")
    end
    W:HookScript("OnShow", paintHowTo)
    paintHowTo()
    W.crumb = head:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    W.crumb:SetPoint("LEFT", ver, "RIGHT", 18, 2)
    W.crumb:SetPoint("RIGHT", howTo, "LEFT", -12, 2)   -- a long path is cut short before it reaches the controls
    W.crumb:SetJustifyH("LEFT")
    W.crumb:SetWordWrap(false)
    W.crumb:SetTextColor(A[1], A[2], A[3])
    local xbg = solid(x, "BACKGROUND", 0, 0.8, 0.2, 0.2, 0)
    xbg:SetAllPoints()
    local xt = x:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    xt:SetPoint("CENTER"); xt:SetText("X"); xt:SetTextColor(0.8, 0.82, 0.88)
    x:SetScript("OnEnter", function() xbg:SetColorTexture(0.8, 0.2, 0.2, 0.85); xt:SetTextColor(1, 1, 1) end)
    x:SetScript("OnLeave", function() xbg:SetColorTexture(0.8, 0.2, 0.2, 0); xt:SetTextColor(0.8, 0.82, 0.88) end)
    x:SetScript("OnClick", function() W:Hide() end)

    -- Footer
    local foot = CreateFrame("Frame", nil, W)
    foot:SetPoint("BOTTOMLEFT"); foot:SetPoint("BOTTOMRIGHT"); foot:SetHeight(44)
    local fbg = solid(foot, "BACKGROUND", -1, 0.075, 0.085, 0.11, 1)
    fbg:SetAllPoints()
    local fl = solid(foot, "ARTWORK", 0, 0.2, 0.23, 0.3, 1)
    fl:SetPoint("TOPLEFT"); fl:SetPoint("TOPRIGHT"); fl:SetHeight(1)
    local hint = foot:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("LEFT", 16, 0)
    hint:SetText("B closes this window. The corner sizes it: A larger, X smaller (or drag it).")
    -- Size grip in the bottom right corner: drag it to make the whole window larger or smaller.
    local grip = CreateFrame("Button", nil, W)
    grip:SetSize(22, 22)
    grip:SetPoint("BOTTOMRIGHT", -2, 2)
    grip:SetFrameLevel(foot:GetFrameLevel() + 10)
    for i = 1, 3 do
        local ln = grip:CreateLine(nil, "OVERLAY")
        ln:SetThickness(1.5)
        ln:SetColorTexture(0.6, 0.65, 0.75, 0.9)
        ln:SetStartPoint("BOTTOMRIGHT", -2, 2 + i * 5)
        ln:SetEndPoint("BOTTOMRIGHT", -2 - i * 5, 2)
        grip["l" .. i] = ln
    end
    grip:SetScript("OnEnter", function(self) for i = 1, 3 do self["l" .. i]:SetColorTexture(A[1], A[2], A[3], 1) end end)
    grip:SetScript("OnLeave", function(self) for i = 1, 3 do self["l" .. i]:SetColorTexture(0.6, 0.65, 0.75, 0.9) end end)
    grip:SetScript("OnMouseDown", function(self)
        -- Keep the top left corner where it is while the size changes.
        local s0 = W:GetScale()
        local l, t = W:GetLeft(), W:GetTop()
        if not (l and t) then return end
        local ps = UIParent:GetEffectiveScale()
        local cx = GetCursorPosition() / ps
        self.drag = { s0 = s0, left = l * s0, top = t * s0, w0 = W:GetWidth() * s0, cx = cx }
        W:ClearAllPoints()
        W:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", l, t)
    end)
    grip:SetScript("OnMouseUp", function(self)
        self.drag = nil
        UbermocUIDB.ui = UbermocUIDB.ui or {}
        UbermocUIDB.ui.scale = W:GetScale()
    end)
    -- With the controller pointer on the corner: A makes the window larger, X smaller.
    grip:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    grip:HookScript("OnMouseDown", function(self, _, synthetic) if not synthetic then self.realDown = true end end)
    grip:SetScript("OnClick", function(self, btn)
        if self.realDown then self.realDown = nil; return end   -- the end of a mouse drag
        local s0 = W:GetScale()
        local l, t = W:GetLeft(), W:GetTop()
        if not (l and t) then return end
        local left, top = l * s0, t * s0
        local maxS = math.min((UIParent:GetWidth() - left) / 960, top / 660, 1.6)
        local ns = math.max(0.5, math.min(maxS, s0 + (btn == "RightButton" and -0.05 or 0.05)))
        W:SetScale(ns)
        W:ClearAllPoints()
        W:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left / ns, top / ns)
        UbermocUIDB.ui = UbermocUIDB.ui or {}
        UbermocUIDB.ui.scale = ns
    end)
    grip:SetScript("OnUpdate", function(self)
        local d = self.drag
        if not d then return end
        if not IsMouseButtonDown("LeftButton") then self:GetScript("OnMouseUp")(self); return end
        local ps = UIParent:GetEffectiveScale()
        local cx = GetCursorPosition() / ps
        local maxS = math.min((UIParent:GetWidth() - d.left) / 960, d.top / 660)
        local ns = math.max(0.5, math.min(maxS, 1.6, (d.w0 + (cx - d.cx)) / 960))
        W:SetScale(ns)
        W:ClearAllPoints()
        W:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", d.left / ns, d.top / ns)
    end)
    local reload = CreateFrame("Button", nil, foot)
    reload:SetSize(120, 28)
    reload:SetPoint("RIGHT", -14, 0)
    UbermocUIAPI.flatButton(reload)
    reload:SetText("Reload UI")
    reload:SetScript("OnClick", function() ReloadUI() end)
    local rs = CreateFrame("Button", nil, foot)
    rs:SetSize(190, 28)
    rs:SetPoint("RIGHT", reload, "LEFT", -10, 0)
    UbermocUIAPI.flatButton(rs)
    rs:SetText("Reset this page to defaults")
    rs:SetScript("OnClick", function(self)
        if not self.armed then
            self.armed = true
            self:SetText("Click again to reset")
            C_Timer.After(3, function() if self.armed then self.armed = false; self:SetText("Reset this page to defaults") end end)
            return
        end
        self.armed = false
        self:SetText("Reset this page to defaults")
        UbermocUIAPI.resetCurrentPage()
    end)
    W.resetBtn = rs

    -- Sidebar
    local side = CreateFrame("Frame", nil, W)
    side:SetPoint("TOPLEFT", head, "BOTTOMLEFT"); side:SetPoint("BOTTOMLEFT", foot, "TOPLEFT"); side:SetWidth(200)
    local sbg = solid(side, "BACKGROUND", -1, 0.04, 0.045, 0.06, 1)
    sbg:SetAllPoints()
    local sl = solid(side, "ARTWORK", 0, 0.2, 0.23, 0.3, 1)
    sl:SetPoint("TOPRIGHT"); sl:SetPoint("BOTTOMRIGHT"); sl:SetWidth(1)
    W.side = side
    W.navButtons, W.navHeads, W.current = {}, {}, false

    -- Content: the pages are shown here, one at a time.
    local C = CreateFrame("Frame", nil, W)
    C:SetPoint("TOPLEFT", side, "TOPRIGHT", 0, 0)
    C:SetPoint("BOTTOMRIGHT", foot, "TOPRIGHT", 0, 0)
    local cbg = solid(C, "BACKGROUND", -1, 0.085, 0.095, 0.12, 1)
    cbg:SetAllPoints()
    W.content = C
    UbermocUIAPI.win = W
    if UbermocUIAPI.cursorHook then pcall(UbermocUIAPI.cursorHook, W) end
    return W
end

function UbermocUIAPI.pageResetKeys(pg)
    if not pg then return {} end
    local keys = {}
    if pg.composite then
        local c = UbermocUIAPI.COMPOSITES[pg.key]
        if pg.key == "unitframes" and c and c.subs[pg.composite.cur or 1] then
            keys[1] = c.subs[pg.composite.cur or 1][1]   -- only the tab you are looking at
        else
            for _, s in ipairs(c and c.subs or {}) do keys[#keys + 1] = s[1] end
        end
    else
        keys[1] = pg.key
    end
    return keys
end

function UbermocUIAPI.resetCurrentPage()
    local W = UbermocUIAPI.win
    local pg = W and W.current
    if not pg then return end
    for _, k in ipairs(UbermocUIAPI.pageResetKeys(pg)) do
        local fn = UbermocUIAPI.resetters[k]
        if fn then
            local ok, err = pcall(fn)
            if not ok and UbermocUIAPI.uiPrint then UbermocUIAPI.uiPrint("Reset failed: " .. tostring(err)) end
        end
        local sub = UbermocUIAPI.pages[k]
        local f = sub and sub.panel and sub.panel:GetScript("OnShow")
        if f then pcall(f, sub.panel) end
    end
    if UbermocUIAPI.uiPrint then UbermocUIAPI.uiPrint("Page reset to defaults.") end
end

function UbermocUIAPI.showPage(key)
    local W = UbermocUIAPI.win
    local pg = UbermocUIAPI.pages[key]
    if not W or not pg then return end
    if W.current and W.current ~= pg then W.current.panel:Hide() end
    W.current = pg
    pg.panel:SetParent(W.content)
    pg.panel:ClearAllPoints()
    pg.panel:SetAllPoints(W.content)
    pg.panel:Show()
    W.crumb:SetText(UbermocUIAPI.titleCase(pg.label))
    if W.resetBtn then
        local any = false
        for _, k in ipairs(UbermocUIAPI.pageResetKeys(pg)) do if UbermocUIAPI.resetters[k] then any = true end end
        W.resetBtn:SetShown(any)
    end
    UbermocUIDB.ui = UbermocUIDB.ui or {}
    UbermocUIDB.ui.page = key
    for k, b in pairs(W.navButtons) do b:SetSelected(k == key) end
end

function UbermocUIAPI.layoutNav()
    local W = UbermocUIAPI.win
    if not W then return end
    UbermocUIAPI.ensureComposites()
    local A = UbermocUIAPI.accent
    local y = -14
    local hi = 0
    -- Fit every entry in the sidebar: rows get shorter (down to 22) when there are many pages.
    local heads, items = 0, 0
    for _, grp in ipairs(UbermocUIAPI.NAV) do
        local n = 0
        for _, k in ipairs(grp[2]) do if UbermocUIAPI.pages[k] then n = n + 1 end end
        if n > 0 then heads = heads + 1; items = items + n end
    end
    local avail = (W.side and W.side:GetHeight()) or 600
    local step = 32
    if items > 0 and avail and avail > 100 then
        step = math.floor((avail - 20 - heads * 32) / items)
        if step > 32 then step = 32 elseif step < 22 then step = 22 end
    end
    W.navStep = step
    if W.side and not W.side.ubFit then
        W.side.ubFit = true   -- sizing the window fits the list again
        W.side:HookScript("OnSizeChanged", function() if W:IsShown() then UbermocUIAPI.layoutNav() end end)
    end
    for _, grp in ipairs(UbermocUIAPI.NAV) do
        local any = false
        for _, k in ipairs(grp[2]) do if UbermocUIAPI.pages[k] then any = true end end
        if any then
            hi = hi + 1
            local h = W.navHeads[hi]
            if not h then
                h = W.side:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
                W.navHeads[hi] = h
            end
            h:ClearAllPoints()
            h:SetPoint("TOPLEFT", 18, y)
            h:SetText(grp[1]:upper())
            h:Show()
            y = y - 20
            for _, k in ipairs(grp[2]) do
                local pg = UbermocUIAPI.pages[k]
                if pg then
                    local b = W.navButtons[k]
                    if not b then
                        b = CreateFrame("Button", nil, W.side)
                        b:SetHeight(step)
                        b.sel = b:CreateTexture(nil, "BACKGROUND")
                        b.sel:SetAllPoints()
                        b.sel:SetColorTexture(A[1], A[2], A[3], 0.16)
                        b.sel:Hide()
                        b.bar = b:CreateTexture(nil, "ARTWORK")
                        b.bar:SetPoint("TOPLEFT"); b.bar:SetPoint("BOTTOMLEFT"); b.bar:SetWidth(3)
                        b.bar:SetColorTexture(A[1], A[2], A[3], 1)
                        b.bar:Hide()
                        b:SetHighlightTexture(UbermocUIAPI.WHITE)
                        local ht = b:GetHighlightTexture()
                        if ht then ht:SetVertexColor(1, 1, 1, 0.06) end
                        b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                        b.text:SetPoint("LEFT", 18, 0)
                        b.text:SetTextColor(0.78, 0.81, 0.88)
                        b.SetSelected = function(self, on)
                            self.sel:SetShown(on); self.bar:SetShown(on)
                            if on then self.text:SetTextColor(1, 1, 1) else self.text:SetTextColor(0.78, 0.81, 0.88) end
                        end
                        b:SetScript("OnClick", function() UbermocUIAPI.showPage(k) end)
                        W.navButtons[k] = b
                    end
                    b.text:SetText(UbermocUIAPI.titleCase(pg.label))
                    b:ClearAllPoints()
                    b:SetHeight(step)
                    b:SetPoint("TOPLEFT", W.side, "TOPLEFT", 0, y)
                    b:SetPoint("TOPRIGHT", W.side, "TOPRIGHT", -1, y)
                    b:Show()
                    y = y - step
                end
            end
            y = y - 12
        end
    end
    local nb = W.current and W.navButtons[W.current.key]
    if nb then nb:SetSelected(true) end
end

function UbermocUIAPI.openWindow(key)
    UbermocUIAPI.runDeferred()
    local W = UbermocUIAPI.win or UbermocUIAPI.buildWindow()
    UbermocUIAPI.layoutNav()
    if key == nil and W:IsShown() then W:Hide(); return end
    if key == "ring" then key = "rings" end
    local saved = UbermocUIDB.ui and UbermocUIDB.ui.page
    local sub = key and UbermocUIAPI.subOf[key]
    if not key and saved and UbermocUIAPI.subOf[saved] then sub = UbermocUIAPI.subOf[saved] end
    local tabIndex
    if sub then key, tabIndex = sub[1], sub[2] end
    if key and not UbermocUIAPI.pages[key] then key = nil end
    key = key or saved or "controller"
    if not UbermocUIAPI.pages[key] then key = "controller" end
    if not UbermocUIAPI.pages[key] then key = "fading" end
    local pg = UbermocUIAPI.pages[key]
    if pg and pg.composite then
        pg.composite.cur = tabIndex or pg.composite.cur or (UbermocUIDB.ui and UbermocUIDB.ui.tab) or 1
    end
    W:Show()
    UbermocUIAPI.showPage(key)
end

local function buildMiscPanel()
    miscPanel = CreateFrame("Frame")
    miscPanel.name = "Miscellaneous"
    -- Everything below the title scrolls, so the page fits however tall it gets.
    local scroll = CreateFrame("ScrollFrame", nil, miscPanel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 0, -48)
    scroll:SetPoint("BOTTOMRIGHT", -30, 8)
    local sc = CreateFrame("Frame", nil, scroll)
    sc:SetSize(600, 1250)
    scroll:SetScrollChild(sc)

    local function note(text, y)
        local fs = newLabel(sc, text, 48, y, "GameFontHighlightSmall")
        fs:SetWidth(520); fs:SetJustifyH("LEFT"); fs:SetWordWrap(true)
    end

    local tipCB = newCheck(sc, "Tooltip at the mouse cursor", 16, -16, function(v)
        UbermocUIDB.tooltipAtCursor = v
    end)
    note("Tooltips appear next to your mouse cursor and follow it, instead of sitting in a fixed corner.", -46)

    local tipsCB = newCheck(sc, "Hide tutorial pop-ups", 16, -86, function(v) UbermocUIDB.hideTips = v end)
    note("WoW's little tip boxes only close with a click on their X. This hides them as they show.", -116)

    local vendorRefresh, lootCB, fastCB
    refreshMisc = function()
        tipCB:SetChecked(UbermocUIDB.tooltipAtCursor and true or false)
        local okL, al = pcall(GetCVar, "autoLootDefault")
        if lootCB then lootCB:SetChecked(okL and al == "1") end
        if fastCB then fastCB:SetChecked(UbermocUIDB.fastLoot ~= false) end
        if tipsCB then tipsCB:SetChecked(UbermocUIDB.hideTips ~= false) end
        if vendorRefresh then vendorRefresh() end
    end

    newLabel(sc, "Vendors", 16, -162, "GameFontNormalLarge")
    local sellCB = newCheck(sc, "Sell grey items when a vendor opens", 16, -194, function(v) UbermocUIDB.vendor.sellGray = v end)
    local sellMsgCB = newCheck(sc, "Tell me what was sold", 48, -224, function(v) UbermocUIDB.vendor.sellMsg = v end)
    local repCB = newCheck(sc, "Repair when a vendor opens", 16, -264, function(v) UbermocUIDB.vendor.repair = v end)
    local repGuildCB = newCheck(sc, "Use guild funds first, if allowed", 48, -294, function(v) UbermocUIDB.vendor.repairGuild = v end)
    local repMsgCB = newCheck(sc, "Tell me what the repair cost", 48, -324, function(v) UbermocUIDB.vendor.repairMsg = v end)
    note("Only vendors that buy items or repair gear are used. Selling only touches grey (poor quality) items.", -362)
    vendorRefresh = function()
        local v = UbermocUIDB.vendor
        sellCB:SetChecked(v.sellGray and true or false)
        sellMsgCB:SetChecked(v.sellMsg and true or false)
        repCB:SetChecked(v.repair and true or false)
        repGuildCB:SetChecked(v.repairGuild and true or false)
        repMsgCB:SetChecked(v.repairMsg and true or false)
    end

    lootCB = newCheck(sc, "Loot automatically", 16, -400, function(v)
        pcall(SetCVar, "autoLootDefault", v and "1" or "0")
    end)
    note("Picks up everything when you open a corpse or chest, without clicking each item (WoW's own Auto Loot setting; this box turns it on and off).", -430)
    fastCB = newCheck(sc, "Fast loot: take everything the moment it opens", 16, -466, function(v) UbermocUIDB.fastLoot = v end)
    newLabel(sc, "Everything at once", 16, -494, "GameFontNormalLarge")
    local allBtn
    allBtn = newButton(sc, "Turn on every Ubermoc UI feature", 280, 16, -526, function()
        if not allBtn.armed then
            allBtn.armed = true
            allBtn:SetText("Click again: turn on and reload")
            C_Timer.After(4, function() allBtn.armed = false; allBtn:SetText("Turn on every Ubermoc UI feature") end)
            return
        end
        UbermocUIAPI.enableEverything()
        ReloadUI()
    end)
    note("Turns on every halo frame, the clean minimap, name-only nameplates and their icons, the radial menus, the interface cursor, the vendor helpers and the cursor tooltip, then reloads. Chat fading stays as it is.", -562)
    local resetAll
    resetAll = newButton(sc, "Reset everything to defaults", 280, 16, -630, function()
        if not resetAll.armed then
            resetAll.armed = true
            resetAll:SetText("Click again: reset all and reload")
            C_Timer.After(4, function() resetAll.armed = false; resetAll:SetText("Reset everything to defaults") end)
            return
        end
        -- The settings are wiped as the interface unloads, so nothing runs without them meanwhile.
        if InCombatLockdown() then print("|cff00ccffUbermoc UI|r Can't reset in combat."); return end
        -- Key and controller binds go back to the game's own defaults; the addon fills in its controller
        -- binds again after the reload. WoW's other settings are not touched.
        if LoadBindings and DEFAULT_BINDINGS then pcall(LoadBindings, DEFAULT_BINDINGS) end
        if SaveBindings and GetCurrentBindingSet then pcall(SaveBindings, GetCurrentBindingSet()) end
        UbermocUIDB.wipeOnReload = true
        ReloadUI()
    end)
    note("Wipes every Ubermoc UI setting and reloads, like a fresh install. Key and controller binds go back to their defaults too. WoW's other settings are left alone.", -666)


    UbermocUIAPI.miscSelectTab = UbermocUIAPI.makeTabs(miscPanel, scroll, sc, { { "General", 0 }, { "Vendors", -152 }, { "Everything at once", -484 } })
    attachReload(miscPanel)
    miscPanel:Hide()
    miscPanel:SetScript("OnShow", function() refreshMisc(); evaluate() end)
    miscPanel:SetScript("OnHide", function() evaluate() end)

    UbermocUIAPI.addPage("misc", "Miscellaneous", miscPanel)
end

local function buildNameplatePanel()
    nameplatePanel = CreateFrame("Frame")
    nameplatePanel.name = "Nameplates"
    newLabel(nameplatePanel, "Nameplates", 16, -16, "GameFontNormalHuge")

    local function px(v) return math.floor(v + 0.5) .. " px" end
    local scrollFrameRef
    local killBuilt, markBuilt, threatBuilt
    local function npDB() return UbermocUIDB.nameplates end
    local group = "enemy" -- which nameplates the page is editing
    local function cfg(kind) return npDB()[group][kind] end
    local KIND_LIST = { "quest", "elite", "rare" }

    -- Live preview: a mock nameplate that shows every enabled icon, at the chosen scale.
    local pv = CreateFrame("Frame", nil, nameplatePanel)
    pv:SetSize(560, 190)
    pv:SetClipsChildren(true)
    pv:SetPoint("TOPLEFT", 16, -48)
    local pbg = pv:CreateTexture(nil, "BACKGROUND")
    pbg:SetAllPoints()
    pbg:SetColorTexture(0.06, 0.08, 0.1, 0.9)
    newLabel(pv, "Preview", 8, -6, "GameFontHighlightSmall")
    local mock = CreateFrame("Frame", nil, pv)
    mock:SetSize(140, 14)
    mock:SetPoint("BOTTOM", pv, "BOTTOM", 0, 44)
    local barBg = mock:CreateTexture(nil, "BACKGROUND")
    barBg:SetAllPoints()
    barBg:SetColorTexture(0, 0, 0, 0.85)
    local bar = mock:CreateTexture(nil, "ARTWORK")
    bar:SetPoint("TOPLEFT", 1, -1)
    bar:SetPoint("BOTTOMRIGHT", -1, 1)
    local mockName = mock:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    mockName:SetPoint("BOTTOM", mock, "TOP", 0, 3)
    local mockPct = mock:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    -- The level square: outline (changeable colour), dark fill and the number centred in it, as in game.
    local mockLvl = mock:CreateTexture(nil, "OVERLAY", nil, 1)
    mockLvl:SetSize(22, 22)
    mockLvl:SetColorTexture(0.55, 0.55, 0.6, 1)
    local mockLvlFill = mock:CreateTexture(nil, "OVERLAY", nil, 2)
    mockLvlFill:SetPoint("TOPLEFT", mockLvl, "TOPLEFT", 1, -1)
    mockLvlFill:SetPoint("BOTTOMRIGHT", mockLvl, "BOTTOMRIGHT", -1, 1)
    mockLvlFill:SetColorTexture(0.05, 0.05, 0.07, 0.95)
    local mockLvlText = mock:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    mockLvlText:SetDrawLayer("OVERLAY", 3)
    mockLvlText:SetJustifyH("CENTER")
    mockLvlText:SetJustifyV("MIDDLE")
    mockLvlText:SetText("60")
    local pvIcons = {}
    for _, kind in ipairs(KIND_LIST) do pvIcons[kind] = makeIndicator(mock, kind) end
    -- Mock cast bar, placed with the same settings as the real one.
    local mockCast = CreateFrame("Frame", nil, pv)
    local mcBg = mockCast:CreateTexture(nil, "BACKGROUND")
    mcBg:SetAllPoints(); mcBg:SetColorTexture(0, 0, 0, 0.8)
    local mcFill = mockCast:CreateTexture(nil, "ARTWORK")
    mcFill:SetPoint("TOPLEFT", 1, -1); mcFill:SetPoint("BOTTOMLEFT", 1, 1)
    mcFill:SetColorTexture(1, 0.7, 0, 1)
    local mcText = mockCast:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    mcText:SetPoint("CENTER")
    local mcTime = mockCast:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    mcTime:SetPoint("RIGHT", -3, 0)
    -- Mock health bar outline.
    local mockEdge = {}
    for i = 1, 4 do mockEdge[i] = mock:CreateTexture(nil, "OVERLAY", nil, 4); mockEdge[i]:SetTexture("Interface\\Buttons\\WHITE8X8") end

    local function refreshPreview()
        local np = npDB()
        if group == "enemy" then
            bar:SetColorTexture(0.8, 0.15, 0.15, 1)
            mockName:SetText("Syndicate Rogue")
        else
            bar:SetColorTexture(0.2, 0.7, 0.25, 1)
            mockName:SetText("Friendly Villager")
        end
        local bw, bh = getPlateSize(group)
        local g = np[group]
        local lk = g.look
        mock:SetSize(math.min(g.width or bw, 520), math.max(4, math.min(g.height or bh, 60)))
        local nameOnly = lk.nameOnly
        local barShown = not (lk.hideBar or nameOnly)
        bar:SetShown(barShown); barBg:SetShown(barShown)
        mockName:SetShown(not lk.hideName)
        if nameOnly and lk.classColor then
            local nm = (group == "enemy") and "Syndicate Rogue" or "Friendly Villager"
            local base = (group == "enemy") and { r = 0.9, g = 0.2, b = 0.2 } or { r = 0.96, g = 0.55, b = 0.73 }
            mockName:SetTextColor(base.r, base.g, base.b)
            if lk.nameGradient then
                mockName:SetText(gradientText(nm, base, 0.7, lk.missColor))
            end
        end
        if not (nameOnly and lk.classColor) then mockName:SetTextColor(1, 1, 1) end
        mockPct:SetShown(nameOnly and lk.showPct and true or false)
        mockLvl:SetShown(nameOnly and lk.showLevel and true or false)
        mockLvlText:SetShown(nameOnly and lk.showLevel and true or false)
        mockLvlFill:SetShown(nameOnly and lk.showLevel and true or false)
        do
            local ls = lk.levelSize or 22
            mockLvlFill:SetColorTexture(0.05, 0.05, 0.07, (lk.levelBg or 95) / 100)
            mockLvl:SetSize(ls, ls)
            mockLvl:SetColorTexture(lk.lvlR or 0.55, lk.lvlG or 0.55, lk.lvlB or 0.6, 1)
            mockLvlText:SetFont(STANDARD_TEXT_FONT, math.max(8, math.floor(ls * 0.55)), "OUTLINE")
            local tr, tg, tb2 = UbermocUIAPI.levelTextColor(lk)
            if tr then mockLvlText:SetTextColor(tr, tg, tb2) else mockLvlText:SetTextColor(1, 1, 1) end
        end
        if nameOnly then
            local sw = mockName:GetStringWidth() or 80
            local x, y = lk.pctX or 0, lk.pctY or 0
            mockPct:SetText("85%")
            mockPct:ClearAllPoints()
            local tp, tv = UbermocUIAPI.threatPad(group, lk)
            if lk.pctPos == "LEFT" then mockPct:SetPoint("RIGHT", mockName, "CENTER", -(sw / 2 + 4 + tp) + x, y)
            elseif lk.pctPos == "TOP" then mockPct:SetPoint("BOTTOM", mockName, "TOP", x, 2 + tv + y)
            elseif lk.pctPos == "BOTTOM" then mockPct:SetPoint("TOP", mockName, "BOTTOM", x, -2 - tv + y)
            else mockPct:SetPoint("LEFT", mockName, "CENTER", sw / 2 + 4 + tp + x, y) end
            mockLvl:ClearAllPoints()
            local right = lk.levelSide ~= "LEFT"
            if right then
                if lk.showPct and (lk.pctPos == "RIGHT" or lk.pctPos == nil) then mockLvl:SetPoint("LEFT", mockPct, "RIGHT", 4 + tp + (lk.levelX or 0), lk.levelY or 0)
                else mockLvl:SetPoint("LEFT", mockName, "CENTER", sw / 2 + 4 + (lk.levelX or 0), lk.levelY or 0) end
            else
                if lk.showPct and lk.pctPos == "LEFT" then mockLvl:SetPoint("RIGHT", mockPct, "LEFT", -4 - tp + (lk.levelX or 0), lk.levelY or 0)
                else mockLvl:SetPoint("RIGHT", mockName, "CENTER", -(sw / 2 + 4) + (lk.levelX or 0), lk.levelY or 0) end
            end
            mockLvlText:ClearAllPoints()
            mockLvlText:SetAllPoints(mockLvl)
        end
        -- Outline and cast bar.
        local mOn, mSz, mR, mG, mB, mA = UbermocUIAPI.borderOf(H.NP_OUT[group] or "npOutline_enemy")
        if mOn and barShown then
            UbermocUIAPI.drawEdges(mockEdge, mock, mSz, mR, mG, mB, mA)
            barBg:SetColorTexture(0, 0, 0, 0)
        else
            for i = 1, 4 do mockEdge[i]:Hide() end
            barBg:SetColorTexture(0, 0, 0, 0.85)
        end
        do
            local cw, cx, cy = lk.castW or 0, lk.castX or 0, lk.castY or 0
            local cpad = lk.castPad; if cpad == nil then cpad = 6 end
            local ch = (lk.castHeight or 0) > 0 and lk.castHeight or (nameOnly and math.max(4, math.min(g.height or bh, 60)) or 10)
            mockCast:ClearAllPoints()
            if nameOnly then
                mockCast:SetPoint("TOP", mockName, "BOTTOM", cx, -3 + cy)
                mockCast:SetWidth((cw > 0) and cw or (math.min(g.width or bw, 520) + 2 * cpad))
            else
                mockCast:SetPoint("TOP", mock, "BOTTOM", cx, -2 + cy)
                mockCast:SetWidth((cw > 0) and cw or (mock:GetWidth() + 2 * cpad))
            end
            mockCast:SetHeight(ch)
            mcFill:SetWidth(math.max(1, (mockCast:GetWidth() - 2) * 0.6))
            pcall(mcText.SetFont, mcText, STANDARD_TEXT_FONT, math.max(7, math.min(12, ch - 1)), "OUTLINE")
            pcall(mcTime.SetFont, mcTime, STANDARD_TEXT_FONT, math.max(7, math.min(12, ch - 1)), "OUTLINE")
            mcText:SetText(group == "enemy" and "Shadow Bolt" or "Healing Touch")
            mcTime:SetText(lk.castTimer and (lk.castTotal and "1.2 / 3.0" or "1.8") or "")
            mockCast:Show()
        end
        -- Icons and debuffs hang on the name in name-only mode, otherwise on the health bar.
        local ia = (nameOnly and not lk.hideName) and mockName or mock
        local pbase = ia
        if nameOnly then
            if lk.showLevel then pbase = mockLvl elseif lk.showPct then pbase = mockPct end
        end
        local pchain
        for _, kind in ipairs({ "elite", "rare", "quest" }) do
            local f = pvIcons[kind]
            if f then
                local c = cfg(kind)
                if c.on and group == "enemy" then
                    layoutIndicator(f, (kind == "quest" and pchain) or pbase, c, 0)
                    if f.text then f.text:SetText(c.progress and "1/5" or "") end
                    f:Show()
                    if kind ~= "quest" and not pchain then pchain = f end
                else
                    f:Hide()
                end
            end
        end
        -- Target arrows, outline and the kill icon, drawn with the same placement rules as in game.
        local showEnemyExtras = (group == "enemy")
        local ea = (nameOnly and not lk.hideName) and mockName or mock
        if UbermocUIAPI.previewKill then pcall(UbermocUIAPI.previewKill, mock, showEnemyExtras, ea) end
        local pvFrames = {}
        if nameOnly then
            if lk.showPct then
                if lk.pctPos == "LEFT" then pvFrames.left = mockPct
                elseif lk.pctPos ~= "TOP" and lk.pctPos ~= "BOTTOM" then pvFrames.right = mockPct end
            end
            if lk.showLevel then
                if lk.levelSide == "LEFT" then pvFrames.left = mockLvl else pvFrames.right = mockLvl end
            end
        end
        for _, kind in ipairs({ "elite", "rare", "quest" }) do
            local f = pvIcons[kind]
            if f and f:IsShown() then
                local pos = cfg(kind).position
                if pos == "RIGHT" then pvFrames.right = f elseif pos == "LEFT" then pvFrames.left = f end
            end
        end
        if UbermocUIAPI.previewTargetMark then pcall(UbermocUIAPI.previewTargetMark, mock, showEnemyExtras, ea, pvFrames) end
        if UbermocUIAPI.previewThreat then pcall(UbermocUIAPI.previewThreat, mock, (nameOnly and lk.showPct) and mockPct or nil, group == "enemy") end
        if UbermocUIAPI.previewDebuffs then pcall(UbermocUIAPI.previewDebuffs, mock, ia, group) end
        if UbermocUIAPI.previewCombo then pcall(UbermocUIAPI.previewCombo, mock, ea, group == "enemy") end
    end
    UbermocUIAPI.refreshNpPreview = refreshPreview

    -- Every change is applied to the real nameplates at once, no reload needed.
    local function changed() updateAllPlates(); refreshPreview() end

    local groupBtns = {}
    local view = "enemy"
    local GROUPS = { { "enemy", "Enemy Nameplates" }, { "friendly", "Friendly Nameplates" } }
    local VIEWS = { { "enemy", "Enemy Nameplates" }, { "friendly", "Friendly Nameplates" } }
    local groupStrip
    do
        local defs = {}
        for _, g in ipairs(VIEWS) do defs[#defs + 1] = { g[1], g[2] } end
        groupStrip = UbermocUIAPI.tabStrip(nameplatePanel, -240, defs, function(key)
            view = key
            group = key
            if scrollFrameRef then scrollFrameRef:SetVerticalScroll(0) end
            refreshNameplates()
        end)
        groupStrip.mark(view)
    end

    -- Everything below the preview is one scrolling menu.
    local scroll = CreateFrame("ScrollFrame", nil, nameplatePanel, "UIPanelScrollFrameTemplate")
    scrollFrameRef = scroll
    scroll:SetPoint("TOPLEFT", 8, -322)
    scroll:SetPoint("BOTTOMRIGHT", -30, 8)
    local sc = CreateFrame("Frame", nil, scroll)
    sc:SetSize(560, 2160)

    -- Sub tabs under the Enemy / Friendly choice: each one shows only its own part of the menu.
    local npTab = "general"
    local TAB_ENEMY = { { "general", "General" }, { "look", "Look" }, { "nameonly", "Name-only" }, { "icons", "Indicators" },
                        { "target", "Target & Threat" }, { "kill", "Kill & Debuffs" } }
    local TAB_FRIEND = { { "general", "General" }, { "look", "Look" }, { "nameonly", "Name-only" }, { "kill", "Debuffs" } }
    local tabButtons = {}
    local function tabsFor(g) return g == "enemy" and TAB_ENEMY or TAB_FRIEND end
    local npStrip
    do
        local seen = {}
        for _, list in ipairs({ TAB_ENEMY, TAB_FRIEND }) do
            for _, t in ipairs(list) do seen[t[1]] = seen[t[1]] or t[2] end
        end
        local order = { "general", "look", "nameonly", "icons", "target", "kill" }
        local defs = {}
        for _, id in ipairs(order) do defs[#defs + 1] = { id, (id == "kill") and "Kill & Debuffs" or seen[id] } end
        npStrip = UbermocUIAPI.tabStrip(nameplatePanel, -278, defs, function(id)
            npTab = id
            if scrollFrameRef then scrollFrameRef:SetVerticalScroll(0) end
            refreshNameplates()
        end)
        npStrip.all = {}
        for _, b in ipairs(npStrip.tabs) do npStrip.all[#npStrip.all + 1] = b; tabButtons[b.key] = b end
    end
    scroll:SetScrollChild(sc)
    -- Quest / elite / rare icons only make sense on enemy nameplates; the rest of the page slides up for friendly.
    local indicatorBox = CreateFrame("Frame", nil, sc)
    indicatorBox:SetPoint("TOPLEFT", 0, 0)
    indicatorBox:SetSize(560, 810)
    local restWrap = CreateFrame("Frame", nil, sc)
    restWrap:SetSize(560, 100)
    restWrap:SetClipsChildren(true)
    local restBox = CreateFrame("Frame", nil, restWrap)
    restBox:SetSize(560, 1840)
    -- Sections stacked in the scroll area: the show / hide choices, the kill indicator and the debuffs
    -- sit with the group they belong to.
    local function section(h)
        local f = CreateFrame("Frame", nil, sc)
        f:SetSize(560, h)
        f:Hide()
        return f
    end
    local enemyShowBox, friendShowBox, killBox, markBox = section(44), section(230), section(380), section(600)
    local nameBox = section(44)
    local threatBox = section(310)
    local debBox = { enemy = section(640), friendly = section(640) }
    local debPanel = {}

    local TITLE = { quest = "Quest indicator", elite = "Elite indicator", rare = "Rare indicator" }
    local DESC = {
        quest = "Shows a quest icon next to the nameplate of any unit that is part of one of your active quests.",
        elite = "Shows an elite icon on elite mobs and world bosses. A rare elite shows this and the Rare icon, so give them different positions.",
        rare = "Shows a rare icon on rare mobs and rare elites.",
    }
    local ctl = {}
    for i, kind in ipairs(KIND_LIST) do
        local y0 = -((i - 1) * 270) - 4
        local c = {}
        ctl[kind] = c
        newLabel(indicatorBox, TITLE[kind], 8, y0, "GameFontNormalLarge")
        c.on = newCheck(indicatorBox, "Show the " .. kind .. " indicator", 8, y0 - 28, function(v)
            cfg(kind).on = v
            changed()
        end)
        if kind == "quest" then
            c.prog = newCheck(indicatorBox, "Show progress (1/5)", 8, y0 - 60, function(v)
                cfg("quest").progress = v
                changed()
            end)
        end
        newLabel(indicatorBox, "Icon size", 40, y0 - 100)
        c.size = makeSlider(indicatorBox, 140, 12, 500, 2, px, function(v) cfg(kind).size = v; changed() end)
        c.size:SetPoint("TOPLEFT", 240, y0 - 100)
        newLabel(indicatorBox, "Icon position", 40, y0 - 142)
        c.pos = H.segRow(indicatorBox, 208, y0 - 138, { { "LEFT", "Left", 66 }, { "RIGHT", "Right", 66 }, { "TOP", "Above", 66 }, { "BOTTOM", "Below", 66 } },
            function() return cfg(kind).position or "LEFT" end, function(v) cfg(kind).position = v; changed() end)
        newLabel(indicatorBox, "Left / right", 40, y0 - 184)
        c.x = makeSlider(indicatorBox, 140, -500, 500, 1, px, function(v) cfg(kind).offsetX = v; changed() end)
        c.x:SetPoint("TOPLEFT", 240, y0 - 184)
        newLabel(indicatorBox, "Up / down", 40, y0 - 224)
        c.y = makeSlider(indicatorBox, 140, -500, 500, 1, px, function(v) cfg(kind).offsetY = v; changed() end)
        c.y:SetPoint("TOPLEFT", 240, y0 - 224)
        local d = newLabel(indicatorBox, DESC[kind], 8, y0 - 252, "GameFontHighlightSmall")
        d:SetWidth(530); d:SetJustifyH("LEFT"); d:SetWordWrap(true)
    end

    -- Size of the selected group's nameplates.
    local y1 = -4
    local sizeTitle = newLabel(restBox, "Nameplate size", 8, y1, "GameFontNormalLarge")
    newLabel(restBox, "Width", 40, y1 - 36)
    local widthSl = makeSlider(restBox, 140, 40, 500, 5, px, function(v)
        npDB()[group].width = v
        applyPlateSizes()
        refreshPreview()
    end)
    widthSl:SetPoint("TOPLEFT", 240, y1 - 36)
    newLabel(restBox, "Height", 40, y1 - 76)
    local heightSl = makeSlider(restBox, 140, 4, 500, 1, px, function(v)
        npDB()[group].height = v
        applyPlateSizes()
        refreshPreview()
    end)
    heightSl:SetPoint("TOPLEFT", 240, y1 - 76)
    local sizeNote = newLabel(restBox, "Sets how wide and tall the nameplates are for the group selected above. Names and icons keep their size. Changes made in a fight apply when it ends.", 8, y1 - 112, "GameFontHighlightSmall")
    sizeNote:SetWidth(530); sizeNote:SetJustifyH("LEFT"); sizeNote:SetWordWrap(true)
    newButton(restBox, "Reset size to default", 180, 8, y1 - 164, function()
        npDB()[group].width, npDB()[group].height = (group == "enemy") and 260 or 150, 11
        resetPlateSizes()
        refreshNameplates()
    end)
    local function cvarOn(name)
        local ok, v = pcall(GetCVar, name)
        return ok and v == "1"
    end
    local enemiesCB = newCheck(enemyShowBox, "Show enemy nameplates", 8, -4, function(v)
        npDB().showEnemies = v
        applyPlateVisibility()
    end)
    local friendsCB = newCheck(friendShowBox, "Show friendly nameplates", 8, -4, function(v)
        npDB().showFriends = v
        applyPlateVisibility()
    end)
    local npcsCB = newCheck(friendShowBox, "Show friendly NPC nameplates", 8, -36, function(v)
        npDB().showFriendNpcs = v
        applyPlateVisibility()
    end)
    local visNote = newLabel(friendShowBox, "Turns the game's own nameplate setting on or off. In a fight the change waits until it ends. Inside dungeons and raids WoW shows friendly nameplates only when it allows it.", 8, -70, "GameFontHighlightSmall")
    visNote:SetWidth(530); visNote:SetJustifyH("LEFT"); visNote:SetWordWrap(true)

    local clickCB = newCheck(friendShowBox, "Friendly nameplates ignore clicks", 8, -114, function(v)
        npDB().friendlyClickThrough = v
        applyPlateVisibility()
    end)

    -- Look of the selected group: hide / size / emphasis options.
    local y2 = y1 - 206
    local lookTitle = newLabel(restBox, "Look", 8, y2, "GameFontNormalLarge")
    local function lk() return npDB()[group].look end
    local lookSliders, lookChecks, friendOnly = {}, {}, {}
    local function lookCheck(text, y, key, onlyFriend)
        local cb = newCheck(restBox, text, 8, y, function(v) lk()[key] = v; changed() end)
        lookChecks[key] = cb
        if onlyFriend then friendOnly[#friendOnly + 1] = cb; friendOnly[#friendOnly + 1] = cb.label end
        return cb
    end
    local function lookSlider(text, y, min, max, key, fmt, onlyFriend)
        local fs = newLabel(restBox, text, 40, y)
        local sl = makeSlider(restBox, 140, min, max, 1, fmt or px, function(v) lk()[key] = v; changed() end)
        sl:SetPoint("TOPLEFT", 280, y)
        sl.ubermocLabel = fs
        lookSliders[key] = sl
        if onlyFriend then friendOnly[#friendOnly + 1] = fs; friendOnly[#friendOnly + 1] = sl end
        return sl
    end
    local function sizeFmt(v) return v <= 0 and "default" or (math.floor(v + 0.5) .. " px") end
    local function plusFmt(v) return v <= 0 and "none" or ("+" .. math.floor(v + 0.5) .. " px") end
    lookCheck("Hide the name", y2 - 30, "hideName")
    do
        local ct = newCheck(restBox, "Cast timer", 250, y2 - 30, function(v) lk().castTimer = v; changed() end)
        lookChecks.castTimer = ct
    end
    lookSlider("Name text size", y2 - 100, 0, 24, "nameSize", sizeFmt)
    lookSlider("Cast bar height", y2 - 140, 0, 40, "castHeight", sizeFmt)
    lookSlider("Target: wider by", y2 - 180, 0, 500, "targetW", plusFmt)
    lookSlider("Target: taller by", y2 - 220, 0, 40, "targetH", plusFmt)
    lookSlider("Mouseover: wider by", y2 - 260, 0, 500, "mouseW", plusFmt)
    lookSlider("Mouseover: taller by", y2 - 300, 0, 40, "mouseH", plusFmt)
    lookSlider("Target: whole nameplate scale", y2 - 340, 50, 300, "targetScale", function(v) return math.floor(v + 0.5) .. "%" end)
    newLabel(restBox, "Target and mouseover sizes change the health bar, so they are greyed out in name-only mode. The target scale works in both modes and also grows the name, icons and debuffs.", 40, y2 - 376, "GameFontDisableSmall")

    -- Cast bar placement and the outline around the health bar.
    newLabel(restBox, "Cast bar", 8, y2 - 410, "GameFontNormal")
    lookSlider("Cast bar width", y2 - 440, 0, 500, "castW", function(v) return v <= 0 and "same as bar" or (math.floor(v + 0.5) .. " px") end)
    lookSlider("Cast bar left / right", y2 - 480, -300, 300, "castX")
    lookSlider("Cast bar up / down", y2 - 520, -300, 300, "castY")
    lookSlider("Wider than the bar by", y2 - 560, 0, 100, "castPad", function(v) return math.floor(v + 0.5) .. " px each side" end)
    newLabel(restBox, "Health bar outline", 8, y2 - 598, "GameFontNormal")
    newButton(restBox, "Outline: set on the Textures page", 260, 40, y2 - 628, function()
        if UbermocUIAPI.openTextures then UbermocUIAPI.openTextures("nameplates") end
    end)
    newLabel(restBox, "The cast bar sits under the health bar and these move and size it from there. The outline replaces the game's thin border.", 40, y2 - 668, "GameFontDisableSmall"):SetWidth(500)

    -- Name-only mode (both enemy and friendly nameplates)
    local y3 = y2 - 740
    local nameOnlyTitle = newLabel(restBox, "Name-only options", 8, y3, "GameFontNormalLarge")
    friendOnly[#friendOnly + 1] = nameOnlyTitle
    friendOnly[#friendOnly + 1] = nameOnlyTitle.rule
    -- The switch itself sits at the top of the page, right under the show nameplates choices.
    local nameOnlyCB = newCheck(nameBox, "Show only the name, no health bar", 8, -4, function(v) lk().nameOnly = v; changed() end)
    lookChecks.nameOnly = nameOnlyCB
    local nameOnlyHint = newLabel(restBox, "These apply when name-only mode is on (the switch is at the top of this page).", 8, y3 - 30, "GameFontHighlightSmall")
    friendOnly[#friendOnly + 1] = nameOnlyHint
    local function nameOnlyLabel()
        local on = lk().nameOnly and true or false
        nameOnlyCB.label:SetText("Show only the name, no health bar   |cff" .. (on and "33ff66" or "ff6666") .. (on and "[ON: bars hidden]" or "[OFF: bars shown]") .. "|r")
    end
    nameOnlyCB:HookScript("OnClick", nameOnlyLabel)
    lookCheck("Colour the name by class", y3 - 62, "classColor", true)
    lookCheck("Show the health percent", y3 - 94, "showPct", true)
    lookCheck("Fade the name colour as health drops", y3 - 126, "nameGradient", true)
    local missLabel = newLabel(restBox, "Missing health colour", 40, y3 - 162)
    local missBtn = H.segRow(restBox, 248, y3 - 158, { { "WHITE", "White", 62 }, { "GRAY", "Grey", 62 }, { "RED", "Red", 62 }, { "BLACK", "Dark", 62 } },
        function() return lk().missColor or "WHITE" end, function(v) lk().missColor = v; changed() end)
    friendOnly[#friendOnly + 1] = missLabel; friendOnly[#friendOnly + 1] = missBtn.frame
    local pcolLabel = newLabel(restBox, "Percent colour", 40, y3 - 196)
    local pcolBtn = H.segRow(restBox, 248, y3 - 192, { { "REACTION", "Reaction", 72 }, { "HEALTH", "Health", 62 }, { "CLASS", "Class", 62 }, { "WHITE", "White", 62 } },
        function() return lk().pctColor or "REACTION" end, function(v) lk().pctColor = v; changed() end)
    friendOnly[#friendOnly + 1] = pcolLabel; friendOnly[#friendOnly + 1] = pcolBtn.frame
    local pctLabel = newLabel(restBox, "Percent position", 40, y3 - 230)
    local pctBtn = H.segRow(restBox, 248, y3 - 226, { { "RIGHT", "Right", 62 }, { "LEFT", "Left", 62 }, { "TOP", "Above", 62 }, { "BOTTOM", "Below", 62 } },
        function() return lk().pctPos or "RIGHT" end, function(v) lk().pctPos = v; changed() end)
    friendOnly[#friendOnly + 1] = pctLabel; friendOnly[#friendOnly + 1] = pctBtn.frame
    lookSlider("Percent left / right", y3 - 270, -500, 500, "pctX", px, true)
    lookSlider("Percent up / down", y3 - 310, -500, 500, "pctY", px, true)
    lookSlider("Percent text size", y3 - 350, 8, 24, "pctSize", px, true)
    lookCheck("Show the level square", y3 - 388, "showLevel", true)
    local lvlLabel = newLabel(restBox, "Level square side", 40, y3 - 426)
    local lvlBtn = H.segRow(restBox, 248, y3 - 422, { { "LEFT", "Left of the name", 130 }, { "RIGHT", "Right of the name", 130 } },
        function() return lk().levelSide == "LEFT" and "LEFT" or "RIGHT" end, function(v) lk().levelSide = v; changed() end)
    friendOnly[#friendOnly + 1] = lvlLabel; friendOnly[#friendOnly + 1] = lvlBtn.frame
    lookSlider("Level square left / right", y3 - 462, -500, 500, "levelX", px, true)
    lookSlider("Level square up / down", y3 - 502, -500, 500, "levelY", px, true)
    lookSlider("Level square size", y3 - 542, 12, 40, "levelSize", px, true)
    do
        local lc = newLabel(restBox, "Level square border", 40, y3 - 586)
        local swb = newButton(restBox, "Set on the Textures page", 200, 280, y3 - 580, function()
            if UbermocUIAPI.openTextures then UbermocUIAPI.openTextures("nameplates") end
        end)
        friendOnly[#friendOnly + 1] = lc; friendOnly[#friendOnly + 1] = swb
    end
    lookSlider("Level square opacity", y3 - 626, 0, 100, "levelBg", function(v) return math.floor(v + 0.5) .. "%" end, true)
    UbermocUIAPI.LVLTEXT = {
        { "diff", "Difficulty colour" }, { "white", "White", 1, 1, 1 }, { "green", "Green", 0.3, 1, 0.3 },
        { "yellow", "Yellow", 1, 0.85, 0.1 }, { "orange", "Orange", 1, 0.55, 0.1 }, { "red", "Red", 1, 0.2, 0.2 },
        { "cyan", "Cyan", 0.2, 0.9, 1 }, { "blue", "Blue", 0.3, 0.5, 1 }, { "purple", "Purple", 0.7, 0.4, 1 },
        { "pink", "Pink", 1, 0.5, 0.8 }, { "custom", "Custom colour" },
    }
    -- The colour for the level number, or nil to use the difficulty colour.
    UbermocUIAPI.levelTextColor = function(l)
        local id = l.lvlText or "diff"
        if id == "diff" then return nil end
        if id == "custom" then return l.ltR or 1, l.ltG or 1, l.ltB or 1 end
        for _, p in ipairs(UbermocUIAPI.LVLTEXT) do if p[1] == id then return p[3], p[4], p[5] end end
    end
    do
        local tl = newLabel(restBox, "Level number colour", 40, y3 - 674)
        local tb = H.cycler(restBox, 248, y3 - 670, 150, function() return UbermocUIAPI.LVLTEXT end,
            function() return lk().lvlText or "diff" end,
            function(v) lk().lvlText = v; changed(); UbermocUIAPI.paintLevelText() end)
        local cl = newLabel(restBox, "Custom number colour", 40, y3 - 714)
        local cb = CreateFrame("Button", nil, restBox)
        cb:SetSize(26, 26)
        cb:SetPoint("TOPLEFT", 280, y3 - 708)
        UbermocUIAPI.flatButton(cb)
        local cs = cb:CreateTexture(nil, "ARTWORK")
        cs:SetPoint("TOPLEFT", 4, -4); cs:SetPoint("BOTTOMRIGHT", -4, 4)
        UbermocUIAPI.paintLevelText = function()
            local l = lk()
            local id = l.lvlText or "diff"
            tb.refresh()
            cs:SetColorTexture(l.ltR or 1, l.ltG or 1, l.ltB or 1, 1)
        end
        cb:SetScript("OnClick", function()
            local l = lk()
            local pr, pg, pb, pid = l.ltR or 1, l.ltG or 1, l.ltB or 1, l.lvlText
            local function apply()
                l.ltR, l.ltG, l.ltB = ColorPickerFrame:GetColorRGB()
                l.lvlText = "custom"
                UbermocUIAPI.paintLevelText()
                changed()
            end
            if ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow then
                ColorPickerFrame:SetupColorPickerAndShow({
                    r = pr, g = pg, b = pb, hasOpacity = false, swatchFunc = apply,
                    cancelFunc = function() l.ltR, l.ltG, l.ltB, l.lvlText = pr, pg, pb, pid; UbermocUIAPI.paintLevelText(); changed() end,
                })
            end
        end)
        friendOnly[#friendOnly + 1] = tl; friendOnly[#friendOnly + 1] = tb.frame
        friendOnly[#friendOnly + 1] = cl; friendOnly[#friendOnly + 1] = cb
    end
    local nameNote = newLabel(restBox, "Hides the health bar and shows just the name, coloured by class (players) or WoW's own colour, with the health percent beside it. Width and height here size the cast bar, since there is no health bar.", 8, y3 - 754, "GameFontHighlightSmall")
    nameNote:SetWidth(530); nameNote:SetJustifyH("LEFT"); nameNote:SetWordWrap(true)
    friendOnly[#friendOnly + 1] = nameNote

    refreshNameplates = function()
        local np = npDB()
        groupStrip.mark(view)
        pv:Show()
        local enemy = group == "enemy"
        if UbermocUIAPI.buildTargetMarkOptions and not markBuilt then
            markBuilt = true
            UbermocUIAPI.buildTargetMarkOptions(markBox, -4)
        end
        if UbermocUIAPI.buildThreatPlateOptions and not threatBuilt then
            threatBuilt = true
            UbermocUIAPI.buildThreatPlateOptions(threatBox, -4)
        end
        if UbermocUIAPI.buildKillOptions and not killBuilt then
            killBuilt = true
            UbermocUIAPI.buildKillOptions(killBox, -4)
        end
        if UbermocUIAPI.buildDebuffPanel and not debPanel[group] then
            debPanel[group] = UbermocUIAPI.buildDebuffPanel(debBox[group], group)
        end
        local yy = 0
        -- How tall the content really is: the lowest edge of what is placed inside (within a y range), so the page
        -- ends where the options end instead of at a guessed height. Measured once, then kept.
        local function extent(f, depth)
            local low = 0
            if depth > 3 then return 0 end
            local function consider(o)
                local okN, n = pcall(o.GetNumPoints, o)
                if not okN or type(n) ~= "number" or n < 1 then return end
                local _, rel, _, _, y = o:GetPoint(1)
                if rel ~= f and rel ~= nil then return end
                local h = o:GetHeight() or 0
                if o.GetStringHeight and (h or 0) < 1 then h = o:GetStringHeight() or 0 end
                local sub = 0
                if o.GetChildren then sub = extent(o, depth + 1) end
                low = math.max(low, -(y or 0) + math.max(h, sub))
            end
            for _, o in ipairs({ f:GetChildren() }) do consider(o) end
            for _, o in ipairs({ f:GetRegions() }) do consider(o) end
            return low
        end
        local measuredH = {}
        local function fit(key, f, fallback, lo, hi)
            if measuredH[key] then return measuredH[key] end
            local low = 0
            local function consider(o)
                local okN, n = pcall(o.GetNumPoints, o)
                if not okN or type(n) ~= "number" or n < 1 then return end
                local _, rel, _, _, y = o:GetPoint(1)
                if rel ~= f and rel ~= nil then return end
                y = -(y or 0)
                if lo and (y < lo or y >= hi) then return end
                local h = o:GetHeight() or 0
                if o.GetStringHeight and h < 1 then h = o:GetStringHeight() or 0 end
                local sub = o.GetChildren and extent(o, 1) or 0
                low = math.max(low, y + math.max(h, sub))
            end
            for _, o in ipairs({ f:GetChildren() }) do consider(o) end
            for _, o in ipairs({ f:GetRegions() }) do consider(o) end
            local h = fallback
            if low > 0 then h = math.min(fallback, math.ceil(low - (lo or 0)) + 6) end
            measuredH[key] = h
            return h
        end
        local function place(f, h, show)
            f:SetShown(show)
            if show then
                f:ClearAllPoints()
                f:SetPoint("TOPLEFT", sc, "TOPLEFT", 0, -yy)
                yy = yy + h
            end
        end
        -- Sub tabs: only this group's tabs show, and the box stack is filtered by the chosen one.
        local valid = false
        for _, t in ipairs(tabsFor(group)) do if t[1] == npTab then valid = true end end
        if not valid then npTab = "general" end
        do
            local vis = {}
            for _, b in ipairs(npStrip.all) do
                local ok = false
                for _, t in ipairs(tabsFor(group)) do if t[1] == b.key then ok = true end end
                b:SetShown(ok)
                if ok then vis[#vis + 1] = b end
            end
            npStrip.tabs = vis
            npStrip.fit()
            npStrip.mark(npTab)
        end
        local function placeRest(startY, h, show)
            restWrap:SetShown(show)
            if show then
                restWrap:ClearAllPoints()
                restWrap:SetPoint("TOPLEFT", sc, "TOPLEFT", 0, -yy)
                restWrap:SetSize(560, h)
                restBox:ClearAllPoints()
                restBox:SetPoint("TOPLEFT", restWrap, "TOPLEFT", 0, startY)
                yy = yy + h
            end
        end
        local T = npTab
        place(enemyShowBox, 44, enemy and T == "general")
        place(friendShowBox, 230, (not enemy) and T == "general")
        place(nameBox, 44, T == "general")
        if T == "general" then placeRest(0, fit("rest_general", restBox, 206, 0, 206), true)
        elseif T == "look" then placeRest(206, fit("rest_look", restBox, 740, 206, 946), true)
        elseif T == "nameonly" then placeRest(946, fit("rest_name", restBox, 894, 946, 1840), true)
        else restWrap:Hide() end
        place(indicatorBox, fit("ind", indicatorBox, 810), enemy and T == "icons")
        place(markBox, fit("mark", markBox, 600), enemy and T == "target")
        place(threatBox, fit("threat", threatBox, 350), enemy and T == "target")
        place(killBox, fit("kill", killBox, 380), enemy and T == "kill")
        place(debBox[group], fit("deb_" .. group, debBox[group], 672), debPanel[group] ~= nil and T == "kill")
        if debPanel[group] then debPanel[group].refresh() end
        for g, f in pairs(debBox) do if g ~= group then f:Hide() end end
        sc:SetHeight(yy + 8)
        if killBox.refreshKill then killBox.refreshKill() end
        if threatBox.refreshThreat then threatBox.refreshThreat() end
        if markBox.refreshMarks then markBox.refreshMarks() end
        for _, kind in ipairs(KIND_LIST) do
            local c, v = ctl[kind], cfg(kind)
            c.on:SetChecked(v.on and true or false)
            if c.prog then c.prog:SetChecked(v.progress and true or false) end
            setSlider(c.size, v.size or 20)
            c.pos.refresh()
            setSlider(c.x, v.offsetX or 0)
            setSlider(c.y, v.offsetY or 0)
        end
        local bw, bh = getPlateSize(group)
        local l = np[group].look
        lookTitle:SetText("Look of " .. (group == "enemy" and "enemy" or "friendly") .. " nameplates")
        for key, sl in pairs(lookSliders) do setSlider(sl, l[key] or (key == "castPad" and 6 or key == "levelBg" and 95 or 0)) end
        for key, cb in pairs(lookChecks) do cb:SetChecked(l[key] and true or false) end
        nameOnlyLabel()
        pctBtn.refresh(); pcolBtn.refresh(); missBtn.refresh(); lvlBtn.refresh()
        if UbermocUIAPI.paintLevelSwatch then UbermocUIAPI.paintLevelSwatch() end
        if UbermocUIAPI.paintLevelText then UbermocUIAPI.paintLevelText() end
        if UbermocUIAPI.paintEdgeSwatch then UbermocUIAPI.paintEdgeSwatch() end
        for _, w in ipairs(friendOnly) do w:SetShown(true); if w.SetAlpha then w:SetAlpha(l.nameOnly and 1 or 0.45) end end
        -- Settings that only change the health bar are greyed out while the bar is hidden.
        for _, k in ipairs({ "targetW", "targetH", "mouseW", "mouseH" }) do UbermocUIAPI.setActive(lookSliders[k], not l.nameOnly) end
        clickCB:SetChecked(np.friendlyClickThrough and true or false)
        setSlider(widthSl, np[group].width or bw)
        setSlider(heightSl, np[group].height or bh)
        sizeTitle:SetText((group == "enemy" and "Enemy" or "Friendly") .. " nameplate size")
        if np.showEnemies ~= nil then enemiesCB:SetChecked(np.showEnemies) else enemiesCB:SetChecked(cvarOn("nameplateShowEnemies")) end
        if np.showFriends ~= nil then friendsCB:SetChecked(np.showFriends) else friendsCB:SetChecked(cvarOn("nameplateShowFriendlyPlayers")) end
        if np.showFriendNpcs ~= nil then npcsCB:SetChecked(np.showFriendNpcs) else npcsCB:SetChecked(cvarOn("nameplateShowFriendlyNpcs")) end
        refreshPreview()
    end

    attachReload(nameplatePanel)
    nameplatePanel:Hide()
    nameplatePanel:SetScript("OnShow", function() refreshNameplates() end)

    UbermocUIAPI.addPage("nameplates", "Nameplates", nameplatePanel)
end

local function buildChatPanel()
    chatPanel = CreateFrame("Frame")
    chatPanel.name = "Chat"
    newLabel(chatPanel, "Chat", 16, -16, "GameFontNormalHuge")
    newLabel(chatPanel, "Fade, hide and time everything to do with chat.", 16, -42, "GameFontHighlightSmall")

    local TABS = { { "fade", "Fade" }, { "tabs", "Tabs" }, { "messages", "Messages" } }
    local current = "fade"
    local tabBtns, pages = {}, {}
    for _, t in ipairs(TABS) do
        local pg = CreateFrame("Frame", nil, chatPanel)
        pg:SetAllPoints()
        pages[t[1]] = pg
    end
    local function secs(v) return math.floor(v + 0.5) .. " s" end

    -- Fade: the chat elements, with the same situations as any other element.
    local refreshFade = buildEditor(pages.fade, CHAT_LIST)

    -- Tabs
    local pt = pages.tabs
    local hideCB = newCheck(pt, "Hide the chat tabs", 16, -110, function(v)
        UbermocUIDB.chat.hideTabs = v
        evaluate()
        refreshChat()
    end)
    local followCB = newCheck(pt, "Fade the tabs together with the chat window", 16, -146, function(v)
        UbermocUIDB.chat.tabsFollow = v
        evaluate()
    end)
    local tabNote = newLabel(pt, "When the second box is off, the tabs use their own settings (Chat tabs on the Fade tab). Hidden tabs are invisible but can still be clicked if you know where they are.", 16, -190, "GameFontHighlightSmall")
    tabNote:SetWidth(540); tabNote:SetJustifyH("LEFT"); tabNote:SetWordWrap(true)

    -- Messages
    local pm = pages.messages
    local linesCB = newCheck(pm, "Fade out old messages on their own", 16, -104, function(v)
        UbermocUIDB.chat.linesOn = v
        applyChatLines()
        refreshChat()
    end)
    newLabel(pm, "Stay visible for", 48, -142)
    local visSl = makeSlider(pm, 160, 5, 300, 5, secs, function(v)
        UbermocUIDB.chat.visibleTime = v
        applyChatLines()
    end)
    visSl:SetPoint("TOPLEFT", 240, -142)
    newLabel(pm, "Fade-out time", 48, -178)
    local fadeSl = makeSlider(pm, 160, 0.5, 10, 0.5, function(v) return ("%.1f s"):format(v) end, function(v)
        UbermocUIDB.chat.fadeTime = v
        applyChatLines()
    end)
    fadeSl:SetPoint("TOPLEFT", 240, -178)
    local lineNote = newLabel(pm, "Each line fades out by itself this long after it appears, in every chat window. WoW has no fade-in for single lines, so new lines appear instantly. Turning this off puts your old chat settings back.", 16, -214, "GameFontHighlightSmall")
    lineNote:SetWidth(540); lineNote:SetJustifyH("LEFT"); lineNote:SetWordWrap(true)

    local revCB = newCheck(pm, "Reveal the chat when a message arrives", 16, -288, function(v)
        UbermocUIDB.chat.revealOnMessage = v
        msgReveal = nil
        evaluate()
        refreshChat()
    end)
    newLabel(pm, "Keep it revealed for", 48, -326)
    local revSl = makeSlider(pm, 160, 2, 60, 1, secs, function(v)
        UbermocUIDB.chat.revealSeconds = v
    end)
    revSl:SetPoint("TOPLEFT", 240, -326)
    newLabel(pm, "Revealed opacity", 48, -362)
    local alphaSl = makeSlider(pm, 160, 0, 1, 0.05, pct, function(v)
        UbermocUIDB.chat.revealAlpha = v
        evaluate()
    end)
    alphaSl:SetPoint("TOPLEFT", 240, -362)
    local revNote = newLabel(pm, "When anything is said, the chat window and tabs fade up to the opacity above, then back to your Fade settings after the time. Elements set to Always hide stay hidden.", 16, -398, "GameFontHighlightSmall")
    revNote:SetWidth(540); revNote:SetJustifyH("LEFT"); revNote:SetWordWrap(true)

    refreshChat = function()
        local ch = UbermocUIDB.chat
        for _, t in ipairs(TABS) do
            tabBtns[t[1]]:SetEnabled(t[1] ~= current)
            pages[t[1]]:SetShown(t[1] == current)
        end
        hideCB:SetChecked(ch.hideTabs and true or false)
        followCB:SetChecked(ch.tabsFollow and true or false)
        linesCB:SetChecked(ch.linesOn and true or false)
        setSlider(visSl, ch.visibleTime or 120)
        setSlider(fadeSl, ch.fadeTime or 3)
        revCB:SetChecked(ch.revealOnMessage and true or false)
        setSlider(revSl, ch.revealSeconds or 8)
        setSlider(alphaSl, ch.revealAlpha or 1)
        UbermocUIAPI.setActive(followCB, not ch.hideTabs)
        UbermocUIAPI.setActive(visSl, ch.linesOn); UbermocUIAPI.setActive(fadeSl, ch.linesOn)
        UbermocUIAPI.setActive(revSl, ch.revealOnMessage); UbermocUIAPI.setActive(alphaSl, ch.revealOnMessage)
        refreshFade()
    end

    for i, t in ipairs(TABS) do
        tabBtns[t[1]] = newButton(chatPanel, UbermocUIAPI.titleCase(t[2]), 96, 16 + (i - 1) * 102, -62, function()
            current = t[1]
            refreshChat()
        end)
    end

    chatPanel:Hide()
    attachReload(chatPanel)
    chatPanel:SetScript("OnShow", function() refreshChat(); evaluate() end)

    UbermocUIAPI.addPage("chat", "Chat", chatPanel)
end

local function buildTimingPanel()
    timingPanel = CreateFrame("Frame")
    timingPanel.name = "Fade timing"
    newLabel(timingPanel, "Fade Timing", 16, -16, "GameFontNormalHuge")
    newLabel(timingPanel, "How quickly elements fade, and how long they wait first.", 16, -42, "GameFontHighlightSmall")
    local function secs(v) return ("%.1f s"):format(v) end

    newLabel(timingPanel, "Fade in time", 16, -90)
    local inSl = makeSlider(timingPanel, 200, 0, 5, 0.1, secs, function(v)
        UbermocUIDB.fadeInTime = v
    end)
    inSl:SetPoint("TOPLEFT", 200, -90)
    newLabel(timingPanel, "Fade out time", 16, -134)
    local outSl = makeSlider(timingPanel, 200, 0, 5, 0.1, secs, function(v)
        UbermocUIDB.fadeOutTime = v
    end)
    outSl:SetPoint("TOPLEFT", 200, -134)
    newLabel(timingPanel, "Wait before fading out", 16, -178)
    local delaySl = makeSlider(timingPanel, 200, 0, 10, 0.5, secs, function(v)
        UbermocUIDB.fadeDelay = v
        evaluate()
    end)
    delaySl:SetPoint("TOPLEFT", 200, -178)
    local note = newLabel(timingPanel, "Fade in: how long an element takes to come back. Fade out: how long it takes to fade away. Wait: how long it stays visible after its situation ends.", 16, -226, "GameFontHighlightSmall")
    note:SetWidth(540); note:SetJustifyH("LEFT"); note:SetWordWrap(true)

    timingPanel:Hide()
    attachReload(timingPanel)
    timingPanel:SetScript("OnShow", function()
        local DB = UbermocUIDB
        setSlider(inSl, DB.fadeInTime or DB.fadeTime)
        setSlider(outSl, DB.fadeOutTime or DB.fadeTime)
        setSlider(delaySl, DB.fadeDelay or 0)
    end)
    UbermocUIAPI.addPage("timing", "Fade Timing", timingPanel)
end

-- Debug page: buttons run the diagnostic commands and show the output here,
-- for when typing in chat is not possible.
local debugLog, debugBox, debugScroll = {}, nil, nil
local debugPanel, debugSub, mmPanel, mmSub

uiPrint = function(msg)
    -- While the Debug page is open its text box shows the result, so nothing goes to chat.
    if not (debugBox and debugBox:IsVisible()) then print(msg) end
    local plain = tostring(msg):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    debugLog[#debugLog + 1] = plain
    while #debugLog > 300 do table.remove(debugLog, 1) end
    if debugBox then
        debugBox:SetText(table.concat(debugLog, "\n"))
        if debugScroll then
            C_Timer.After(0.05, function() debugScroll:SetVerticalScroll(debugScroll:GetVerticalScrollRange()) end)
        end
    end
end

UbermocUIAPI.uiPrint = uiPrint

local function buildDebugPanel()
    debugPanel = CreateFrame("Frame")
    debugPanel.name = "Debug"
    newLabel(debugPanel, "Debug", 16, -16, "GameFontNormalHuge")
    newLabel(debugPanel, "Click a button to run a check. The result appears in the box below.", 16, -42, "GameFontHighlightSmall")

    local function run(cmd)
        uiPrint("|cff888888> " .. cmd .. "|r")
        local ok, err = pcall(SlashCmdList["UBERMOCUI"], cmd)
        if not ok then uiPrint("|cffff4444error:|r " .. tostring(err)) end
    end
    local BUTTONS = {
        { "Check health / mana", "health" }, { "Inspect a nameplate", "plate" },
        { "Show state", "debug" }, { "Missing frames", "frames" },
        { "Turn on / off", "toggle" }, { "Clear chat fading", "clearchat" },
        { "Inspect minimap", "inspect MinimapCluster" }, { "Inspect player frame", "inspect PlayerFrame" },
        { "Addon container", "box" }, { "Pet ring", "ringreport pet" }, { "Utility ring", "ringreport util" }, { "Menu ring", "ringreport menu" },
        { "Interface cursor", "cursorreport" }, { "Ring frame", "ringhudreport" },
    }
    for i, b in ipairs(BUTTONS) do
        local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
        newButton(debugPanel, b[1], 170, 16 + col * 178, -70 - row * 32, function() run(b[2]) end)
    end
    local lastRow = math.floor((#BUTTONS - 1) / 3) + 1
    newButton(debugPanel, "Clear output", 170, 16, -70 - lastRow * 32, function()
        debugLog = {}
        if debugBox then debugBox:SetText("") end
    end)
    newLabel(debugPanel, "To inspect a nameplate, target a friendly player first.", 200, -76 - lastRow * 32, "GameFontHighlightSmall")

    debugScroll = CreateFrame("ScrollFrame", nil, debugPanel, "UIPanelScrollFrameTemplate")
    debugScroll:SetPoint("TOPLEFT", 16, -70 - (lastRow + 1) * 32 - 4)
    debugScroll:SetPoint("BOTTOMRIGHT", -36, 16)
    debugBox = CreateFrame("EditBox", nil, debugScroll)
    debugBox:SetMultiLine(true)
    debugBox:SetFontObject(ChatFontNormal or GameFontHighlightSmall)
    debugBox:SetWidth(520)
    debugBox:SetAutoFocus(false)
    debugBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    debugScroll:SetScrollChild(debugBox)
    debugBox:SetText(table.concat(debugLog, "\n"))

    attachReload(debugPanel)
    debugPanel:Hide()
    UbermocUIAPI.addPage("debug", "Debug", debugPanel)
end

local function openPanel(which)
    UbermocUIAPI.openWindow(which)
end

----------------------------------------------------------------------
-- Minimap button: left-click settings, right-click on/off, drag to reposition
----------------------------------------------------------------------
local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end

local function placeMinimapButton()
    if not mmButton then return end
    local a = math.rad(UbermocUIDB.minimap.angle or 215)
    local r = (Minimap:GetWidth() / 2) + 6
    local c, sn = math.cos(a), math.sin(a)
    if UbermocUIDB.squareMinimap then
        -- Follow the square's edge instead of a circle.
        local m = math.max(math.abs(c), math.abs(sn))
        c, sn = c / m, sn / m
    end
    mmButton:ClearAllPoints()
    mmButton:SetPoint("CENTER", Minimap, "CENTER", c * r, sn * r)
end

updateMinimapButton = function()
    if not mmButton then return end
    if UbermocUIDB.minimap.hide then
        mmButton:Hide()
    else
        mmButton:Show()
        placeMinimapButton()
    end
end

local function buildMinimapButton()
    -- Parented to the minimap, so it fades and hides with the Minimap element.
    local b = CreateFrame("Button", "UbermocUIMinimapButton", Minimap)
    b:SetSize(31, 31)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(8)
    b:SetClampedToScreen(true)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(20, 20)
    bg:SetPoint("TOPLEFT", 7, -5)
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetSize(17, 17)
    icon:SetPoint("TOPLEFT", 7, -6)
    icon:SetTexture("Interface\\Icons\\INV_Misc_Gear_01")
    icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
    local border = b:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    b:SetScript("OnClick", function(_, btn)
        if btn == "RightButton" then UbermocUI_ToggleEnabled() else openPanel() end
    end)
    b:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            if not mx then return end
            local cx, cy = GetCursorPosition()
            local sc = Minimap:GetEffectiveScale()
            UbermocUIDB.minimap.angle = math.deg(atan2(cy / sc - my, cx / sc - mx))
            placeMinimapButton()
        end)
    end)
    b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Ubermoc UI")
        GameTooltip:AddLine("Left-click: settings", 1, 1, 1)
        GameTooltip:AddLine("Right-click: turn on/off", 1, 1, 1)
        GameTooltip:AddLine("Drag: reposition", 1, 1, 1)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    mmButton = b
    updateMinimapButton()
end

----------------------------------------------------------------------
-- Square minimap
----------------------------------------------------------------------
local squareBorder

-- Thickness of the dark frame around the square minimap.
local function setBorderSize(n)
    if not squareBorder or not squareBorder.edges then return end
    n = tonumber(n) or 2
    for _, e in ipairs(squareBorder.edges) do
        local t, p1, p2, horizontal = e[1], e[2], e[3], e[4]
        t:ClearAllPoints()
        if n <= 0 then
            t:Hide()
        else
            -- The top and bottom pieces run the full width, corners included; the side pieces stop at the
            -- map's own top and bottom, so no two pieces ever overlap (an overlap shows as a darker square).
            local function oy(p) return horizontal and (p:find("TOP") and n or -n) or 0 end
            t:SetPoint(p1, squareBorder, p1, p1:find("LEFT") and -n or n, oy(p1))
            t:SetPoint(p2, squareBorder, p2, p2:find("LEFT") and -n or n, oy(p2))
            if horizontal then t:SetHeight(n) else t:SetWidth(n) end
            t:Show()
        end
    end
end

UbermocUIAPI.applySquare = function() if applySquareMinimap then applySquareMinimap() end end
-- Minimap page: square shape on / off (turning it off needs a reload to bring the round shape back).
UbermocUIAPI.setSquareMinimap = function(v)
    UbermocUIDB.squareMinimap = v
    if v then
        if applySquareMinimap then applySquareMinimap() end
    end
    if updateMinimapButton then updateMinimapButton() end
end
applySquareMinimap = function()
    if not UbermocUIDB or not UbermocUIDB.squareMinimap or not Minimap then return end
    pcall(Minimap.SetMaskTexture, Minimap, "Interface\\ChatFrame\\ChatFrameBackground")
    -- Hide the round artwork.
    if MinimapBorder then MinimapBorder:Hide() end
    if MinimapCompassTexture then MinimapCompassTexture:Hide() end
    if MinimapBackdrop and MinimapBackdrop.GetRegions then
        for _, r in ipairs({ MinimapBackdrop:GetRegions() }) do
            if r.Hide then r:Hide() end
        end
    end
    -- Let other addons know the minimap is square.
    -- A thin dark frame around it. Child of the minimap, so it fades with it.
    if not squareBorder then
        local f = CreateFrame("Frame", "UbermocUISquareBorder", Minimap)
        f:SetAllPoints(Minimap)
        f:SetFrameLevel(Minimap:GetFrameLevel() + 1)
        f.edges = {}
        local function edge(p1, p2, horizontal)
            local t = f:CreateTexture(nil, "OVERLAY")
            t:SetColorTexture(0, 0, 0, 1)
            f.edges[#f.edges + 1] = { t, p1, p2, horizontal }
        end
        edge("TOPLEFT", "TOPRIGHT", true)
        edge("BOTTOMLEFT", "BOTTOMRIGHT", true)
        edge("TOPLEFT", "BOTTOMLEFT", false)
        edge("TOPRIGHT", "BOTTOMRIGHT", false)
        squareBorder = f
        UbermocUIAPI.squareBorder = f
    end
    squareBorder:Show()
    setBorderSize(UbermocUIAPI.mmBorder and select(6, UbermocUIAPI.mmBorder()) or 2)
    if UbermocUIAPI.applyMapBack then pcall(UbermocUIAPI.applyMapBack) end
    if updateMinimapButton then updateMinimapButton() end
end

----------------------------------------------------------------------
-- Tooltip at the mouse cursor
----------------------------------------------------------------------
local tipFrame

local function setupTooltipCursor()
    if tipFrame or not GameTooltip then return end
    GameTooltip:SetClampedToScreen(true)
    local lx, ly
    -- Only tooltips that use the game's default anchor follow the cursor; ones pinned to a button stay put.
    local function follow(force)
        if not (UbermocUIDB and UbermocUIDB.tooltipAtCursor) then return end
        if not GameTooltip:IsShown() then return end
        local okA, at = pcall(GameTooltip.GetAnchorType, GameTooltip)
        if okA and at and at ~= "ANCHOR_NONE" then return end
        local x, y = GetCursorPosition()
        if not force and x == lx and y == ly then return end
        lx, ly = x, y
        local scale = GameTooltip:GetEffectiveScale()
        GameTooltip:ClearAllPoints()
        GameTooltip:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x / scale + 16, y / scale + 16)
    end
    -- Place it at the cursor the moment it is anchored and shown, so it never flashes at the game's
    -- own corner position first.
    if hooksecurefunc then
        pcall(hooksecurefunc, "GameTooltip_SetDefaultAnchor", function(tip)
            if tip == GameTooltip then
                if not (UbermocUIDB and UbermocUIDB.tooltipAtCursor) then return end
                local x, y = GetCursorPosition()
                local scale = GameTooltip:GetEffectiveScale()
                lx, ly = x, y
                GameTooltip:ClearAllPoints()
                GameTooltip:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x / scale + 16, y / scale + 16)
            end
        end)
    end
    pcall(GameTooltip.HookScript, GameTooltip, "OnShow", function() follow(true) end)
    tipFrame = CreateFrame("Frame")
    tipFrame:SetScript("OnUpdate", function() follow(false) end)
    -- Only run every frame while the tooltip is up and the option is on.
    tipFrame:Hide()
    pcall(GameTooltip.HookScript, GameTooltip, "OnShow", function()
        if UbermocUIDB and UbermocUIDB.tooltipAtCursor then tipFrame:Show() end
    end)
    pcall(GameTooltip.HookScript, GameTooltip, "OnHide", function() tipFrame:Hide() end)
end

----------------------------------------------------------------------
-- Nameplates: quest indicator and scale
----------------------------------------------------------------------
local indicators = setmetatable({}, { __mode = "k" }) -- plate -> { quest =, elite =, rare = } icon frames
local plateScalePending = false

local function isQuestUnit(unit)
    if not unit or not (C_QuestLog and C_QuestLog.UnitIsRelatedToActiveQuest) then return false end
    local ok, res = pcall(C_QuestLog.UnitIsRelatedToActiveQuest, unit)
    if not ok or isHidden(res) then return false end
    return res and true or false
end

local function plateAnchor(plate)
    local uf = plate.UnitFrame
    if uf then return uf.HealthBarsContainer or uf.healthBar or uf end
    return plate
end

-- Where an icon sits relative to the health bar, and where the quest progress
-- text sits relative to its icon.
local ICON_ANCHOR = {
    LEFT   = { "RIGHT", "LEFT", -2, 0 },
    RIGHT  = { "LEFT", "RIGHT", 2, 0 },
    TOP    = { "BOTTOM", "TOP", 0, 2 },
    BOTTOM = { "TOP", "BOTTOM", 0, -2 },
}
local TEXT_ANCHOR = {
    LEFT   = { "RIGHT", "LEFT", -2, 0 },
    RIGHT  = { "LEFT", "RIGHT", 2, 0 },
    TOP    = { "BOTTOM", "TOP", 0, 1 },
    BOTTOM = { "TOP", "BOTTOM", 0, -1 },
}
local ICON_ATLAS = {
    quest = "QuestNormal", elite = "nameplates-icon-elite-gold", rare = "nameplates-icon-elite-silver",
}
local ICON_FALLBACK = {
    quest = "Interface\\GossipFrame\\AvailableQuestIcon",
    elite = "Interface\\Tooltips\\EliteNameplateIcon",
    rare = "Interface\\Tooltips\\RareEliteNameplateIcon",
}

-- Objective progress such as "1/5" (or "45%"), read from the unit's tooltip lines.
local function questProgress(unit)
    if not (C_TooltipInfo and C_TooltipInfo.GetUnit) then return nil end
    local ok, text = pcall(function()
        local data = C_TooltipInfo.GetUnit(unit)
        if not data or not data.lines then return nil end
        if TooltipUtil and TooltipUtil.SurfaceArgs then TooltipUtil.SurfaceArgs(data) end
        for _, line in ipairs(data.lines) do
            if TooltipUtil and TooltipUtil.SurfaceArgs then TooltipUtil.SurfaceArgs(line) end
            local t = line.leftText
            if t and not isHidden(t) then
                local have, need = t:match("(%d+)%s*/%s*(%d+)")
                if have then return have .. "/" .. need end
                local percent = t:match("(%d+)%%")
                if percent then return percent .. "%" end
            end
        end
        return nil
    end)
    if ok then return text end
    return nil
end

-- Builds one icon (quest, elite or rare). Used for real nameplates and for the
-- preview on the settings page.
makeIndicator = function(parent, kind)
    local f = CreateFrame("Frame", nil, parent)
    f:SetFrameLevel(parent:GetFrameLevel() + 10)
    f.tex = f:CreateTexture(nil, "OVERLAY")
    f.tex:SetAllPoints()
    local atlas = ICON_ATLAS[kind]
    if atlas and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas) then
        f.tex:SetAtlas(atlas)
    else
        f.tex:SetTexture(ICON_FALLBACK[kind])
    end
    if kind == "quest" then
        f.text = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        f.text:SetTextColor(1, 0.95, 0.4, 1)
    end
    return f
end

layoutIndicator = function(f, anchor, cfg, baseY)
    local size = cfg.size or 20
    f:SetSize(size, size)
    local a = ICON_ANCHOR[cfg.position] or ICON_ANCHOR.LEFT
    f:ClearAllPoints()
    f:SetPoint(a[1], anchor, a[2], a[3] + (cfg.offsetX or 0), a[4] + (cfg.offsetY or 0) + (baseY or 0))
    if f.text then
        local t = TEXT_ANCHOR[cfg.position] or TEXT_ANCHOR.LEFT
        f.text:ClearAllPoints()
        f.text:SetPoint(t[1], f, t[2], t[3], t[4])
    end
end

local function classificationOf(unit)
    local ok, c = pcall(UnitClassification, unit)
    if not ok or c == nil or isHidden(c) then return nil end
    return c
end

local KINDS = { "quest", "elite", "rare" }

-- Resizes the plate's Blizzard health bar container: the width comes from two
-- anchors centred on the plate, the height from SetHeight, so names, auras and
-- icons keep their size. The original anchors are remembered for Reset.
local barDefault = {} -- natural bar size per group, captured before the first change

getPlateSize = function(group)
    local b = barDefault[group]
    if b then return b[1], b[2] end
    return 150, 11
end

local function plateUnit(plate)
    if not plate then return nil end
    local u = plate.namePlateUnitToken
    if not u and plate.UnitFrame then u = plate.UnitFrame.unit end
    if not u and plate.GetUnit then
        local ok, r = pcall(plate.GetUnit, plate)
        if ok then u = r end
    end
    return u
end

local function isHostileUnit(unit)
    if not unit then return false end
    local ok, atk = pcall(UnitCanAttack, "player", unit)
    return (ok and atk and not isHidden(atk)) and true or false
end

-- Which emphasis applies to a plate right now: target, mouseover or none.
local function emphasisOf(plate)
    local unit = plateUnit(plate)
    if not unit then return "none" end
    local ok, t = pcall(UnitIsUnit, unit, "target")
    if ok and t and not isHidden(t) then return "target" end
    ok, t = pcall(UnitIsUnit, unit, "mouseover")
    if ok and t and not isHidden(t) then return "mouse" end
    return "none"
end

-- Keeps a frame at alpha 0 even when Blizzard sets its alpha again.
-- Kept beside the frames (never written onto the game's frames, which would mark them as the addon's).
local HOLD = { hidden = setmetatable({}, { __mode = "k" }) }
UbermocUIAPI.isHeldHidden = function(f) return HOLD.hidden[f] and true or false end
-- Nothing is hooked onto the game's frames (that would mark them as the addon's and
-- spread taint into the game's own code); a light timer puts hidden frames back at 0.
-- The game's pet and possess bars show and hide themselves in a fight (a protected update): the addon leaves them alone
-- until the fight is over, so none of its calls are on the stack when the game does that (the game blocked one).
local function heldInFight(f)
    return InCombatLockdown() and (f == _G.PetActionBar or f == _G.PossessActionBar)
end
local function holdHidden(frame, hide)
    if type(frame) ~= "table" or not frame.SetAlpha then return end
    if hide then
        HOLD.hidden[frame] = true
        if not heldInFight(frame) then frame:SetAlpha(0) end
    elseif HOLD.hidden[frame] then
        if heldInFight(frame) then return end
        HOLD.hidden[frame] = nil
        frame:SetAlpha(1)
    end
end
do
    local acc = 0
    local f = CreateFrame("Frame")
    f:SetScript("OnUpdate", function(_, dt)
        acc = acc + dt
        if acc < 0.1 then return end
        acc = 0
        for fr in pairs(HOLD.hidden) do
            local ok, a = pcall(fr.GetAlpha, fr)
            if ok and not isHidden(a) and a ~= 0 and not heldInFight(fr) then pcall(fr.SetAlpha, fr, 0) end
        end
    end)
end

UbermocUIAPI.holdHidden = holdHidden

-- WoW's tutorial pop-ups ("You have an unopened item in your collection" and the like) need a mouse click
-- on their X. With "Hide tutorial pop-ups" on they are made invisible as soon as they show. Only their
-- look is touched (no calls into the game's tip code), so nothing gets tainted.
do
    local hiddenTips = setmetatable({}, { __mode = "k" })
    local function hideAll(pool)
        for tip in pool:EnumerateActive() do
            if tip:GetAlpha() ~= 0 then tip:SetAlpha(0) end
            hiddenTips[tip] = true
        end
    end
    -- The quest tutorials of the new-player zones (a box with an arrow and a dotted line, such as "Add an interrupt
    -- ability to your action bar from your Spellbook") are another system from the tip boxes: the game's own
    -- "show tutorials" setting is switched off, and any pointer it still draws is made invisible.
    local tutorialsOff, pointerHooked = false, false
    local function tutorialPools()
        local out = {}
        for _, name in ipairs({ "NPE_TutorialPointerFrame", "TutorialPointerFrame" }) do
            local t = _G[name]
            if type(t) == "table" then
                for _, k in ipairs({ "framePool", "pool", "Pool", "PointerPool" }) do
                    local p = t[k]
                    if type(p) == "table" and p.EnumerateActive then out[#out + 1] = p end
                end
            end
        end
        return out
    end
    local passRef
    local function pass()
        local on = UbermocUIDB and UbermocUIDB.hideTips ~= false
        local pool = HelpTip and HelpTip.framePool
        if on and pool and pool.EnumerateActive then
            pcall(hideAll, pool)
        elseif not on and next(hiddenTips) then
            for tip in pairs(hiddenTips) do pcall(tip.SetAlpha, tip, 1) end
            wipe(hiddenTips)
        end
        if on then
            if not tutorialsOff then tutorialsOff = true; pcall(SetCVar, "showTutorials", "0") end
            for _, p in ipairs(tutorialPools()) do pcall(hideAll, p) end
            local t = _G.NPE_TutorialPointerFrame
            if not pointerHooked and type(t) == "table" and type(t.Show) == "function" then
                pointerHooked = true
                hooksecurefunc(t, "Show", function() C_Timer.After(0, passRef) end)
            end
        elseif tutorialsOff then
            tutorialsOff = false
            pcall(SetCVar, "showTutorials", "1")
        end
    end
    passRef = pass
    -- Hidden the moment the game shows one (and once a second in case one slipped by).
    if HelpTip and HelpTip.Show then
        hooksecurefunc(HelpTip, "Show", function() C_Timer.After(0, pass) end)
    end
    local acc = 0
    local f = CreateFrame("Frame")
    f:SetScript("OnUpdate", function(_, dt)
        acc = acc + dt
        if acc < 1 then return end
        acc = 0
        pass()
    end)
end

local function sizePlateBar(plate, group, g)
    local uf = plate and plate.UnitFrame
    local bar = uf and uf.HealthBarsContainer
    if not bar then return end
    if InCombatLockdown() then plateScalePending = true; return end
    pcall(function()
        local look = g.look
        local em = emphasisOf(plate)
        local ew, eh = 0, 0
        if em == "target" then ew, eh = look.targetW or 0, look.targetH or 0
        elseif em == "mouse" then ew, eh = look.mouseW or 0, look.mouseH or 0 end
        local active = g.width or g.height or ew ~= 0 or eh ~= 0
        if not bar.ubermocOrig then
            local pts = {}
            for i = 1, bar:GetNumPoints() do pts[i] = { bar:GetPoint(i) } end
            bar.ubermocOrig = { pts = pts }
            hooksecurefunc(bar, "SetHeight", function(self)
                -- Blizzard re-sets the height during updates; put ours back.
                if self.ubermocBusy or not self.ubermocSized or not self.ubermocH then return end
                self.ubermocBusy = true
                self:SetHeight(self.ubermocH)
                self.ubermocBusy = false
            end)
        end
        if not barDefault[group] and not bar.ubermocSized then
            local w, h = bar:GetSize()
            if w and h and w > 1 and h > 1 then barDefault[group] = { w, h } end
        end
        bar.ubermocBusy = true
        if active then
            local dw, dh = getPlateSize(group)
            local w, h = (g.width or dw) + ew, (g.height or dh) + eh
            local first = bar.ubermocOrig.pts[1]
            local y = (first and tonumber(first[5])) or 0
            bar:ClearAllPoints()
            bar:SetPoint("BOTTOMLEFT", uf, "BOTTOM", -w / 2, y)
            bar:SetPoint("BOTTOMRIGHT", uf, "BOTTOM", w / 2, y)
            bar:SetHeight(h)
            bar.ubermocH = h
            bar.ubermocSized = true
        elseif bar.ubermocSized then
            bar:ClearAllPoints()
            for _, pt in ipairs(bar.ubermocOrig.pts) do bar:SetPoint(pt[1], pt[2], pt[3], pt[4], pt[5]) end
            bar.ubermocSized = nil
            bar.ubermocH = nil
        end
        bar.ubermocBusy = false
    end)
end

-- Health percent text for name-only friendly plates. SetFormattedText accepts
-- values WoW hides from addons, so the percent still shows in a fight.
-- Colour for how the unit feels about you (hostile red, neutral yellow, friendly green).
local function reactionColor(unit)
    if not unit then return nil end
    local ok, react = pcall(UnitReaction, unit, "player")
    if ok and type(react) == "number" and not isHidden(react) then
        local c = (FACTION_BAR_COLORS and FACTION_BAR_COLORS[react])
        if c then return c.r, c.g, c.b end
        if react <= 2 then return 0.85, 0.15, 0.15 elseif react == 4 then return 1, 0.85, 0.1 elseif react >= 5 then return 0.15, 0.8, 0.15 end
        return 1, 0.5, 0.1
    end
    local ok2, r, g, b = pcall(UnitSelectionColor, unit)
    if ok2 and type(r) == "number" and not isHidden(r) then return r, g, b end
    return nil
end

function H.pctTint(fs, unit)
            local A = UbermocUIAPI
            local healthColorCurve = A and A.healthCurve
            if not healthColorCurve and C_CurveUtil and C_CurveUtil.CreateColorCurve and CreateColor then
                healthColorCurve = C_CurveUtil.CreateColorCurve()
                healthColorCurve:AddPoint(0, CreateColor(0.9, 0.15, 0.15, 1))
                healthColorCurve:AddPoint(0.5, CreateColor(1, 0.85, 0.1, 1))
                healthColorCurve:AddPoint(1, CreateColor(0.2, 0.9, 0.2, 1))
                if A then A.healthCurve = healthColorCurve end
            end
            local col = healthColorCurve and UnitHealthPercent and UnitHealthPercent(unit, false, healthColorCurve)
            if col and col.GetRGBA then
                fs:SetTextColor(col:GetRGBA())
            else
                local fr = healthFraction(unit)
                if fr then
                    if fr > 0.5 then fs:SetTextColor(math.min(1, 0.2 + (1 - fr) * 1.6), 0.9, 0.1)
                    else fs:SetTextColor(0.95, 0.15 + fr * 1.4, 0.1) end
                end
            end
end
function H.pctText(fs, unit)
        local v
        if UnitHealthPercent and CurveConstants and CurveConstants.ScaleTo100 then
            v = UnitHealthPercent(unit, false, CurveConstants.ScaleTo100)
        end
        if type(v) ~= "number" then
            local cur, max = UnitHealth(unit), UnitHealthMax(unit)
            if isHidden(cur) or isHidden(max) or type(cur) ~= "number" or type(max) ~= "number" or max <= 0 then
                fs:SetText("")
                return
            end
            v = cur / max * 100
        end
        fs:SetFormattedText("%.0f%%", v)
end
function H.nameGrad(uf, gr, fr)
    uf.ubermocName:SetText(gradientText(gr.name, gr.class, fr, gr.miss))
end
local function updatePct(plate)
    local uf = plate.UnitFrame
    local fs = uf and uf.ubermocPct
    local unit = plateUnit(plate)
    -- keep the name gradient in step with health
    local gr = uf and uf.ubermocGrad
    if gr and unit and uf.ubermocName then
        local fr = healthFraction(unit)
        if fr then
            pcall(H.nameGrad, uf, gr, fr)
        end
    end
    if not fs or not unit or not fs:IsShown() then return end
    if uf.ubermocPctMode == "HEALTH" then pcall(H.pctTint, fs, unit) end
    pcall(H.pctText, fs, unit)
end


-- Gradient for when WoW hides the health numbers ("secret" values): a status bar the game fills
-- itself marks how much health is left, and a clipped white copy of the name covers the missing part.
local function missLayer(uf, ours, unit, unitName, look, show)
    local clip = uf.ubermocMissClip
    if not show then
        if clip then clip:Hide() end
        return
    end
    if not clip then
        local sb = CreateFrame("StatusBar", nil, uf)
        sb:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
        sb:GetStatusBarTexture():SetVertexColor(1, 1, 1, 0)
        sb:SetFrameLevel(uf:GetFrameLevel() + 2)
        clip = CreateFrame("Frame", nil, uf)
        clip:SetFrameLevel(uf:GetFrameLevel() + 3)
        clip:SetClipsChildren(true)
        clip:SetPoint("TOPLEFT", sb:GetStatusBarTexture(), "TOPRIGHT", 0, 0)
        clip:SetPoint("BOTTOMRIGHT", sb, "BOTTOMRIGHT", 0, 0)
        clip.fs = clip:CreateFontString(nil, "OVERLAY")
        uf.ubermocMissSB, uf.ubermocMissClip = sb, clip
    end
    local sb = uf.ubermocMissSB
    sb:ClearAllPoints()
    sb:SetPoint("TOPLEFT", ours, "TOPLEFT", 0, 0)
    sb:SetPoint("BOTTOMRIGHT", ours, "BOTTOMRIGHT", 0, 0)
    local f, sz, fl = ours:GetFont()
    if f then clip.fs:SetFont(f, sz, fl) end
    clip.fs:ClearAllPoints()
    clip.fs:SetPoint("CENTER", ours, "CENTER", 0, 0)
    clip.fs:SetWordWrap(false)
    clip.fs:SetText(unitName)
    local m = MISS_COLORS[look.missColor] or MISS_COLORS.WHITE
    clip.fs:SetTextColor(m[1], m[2], m[3])
    local okV, err = pcall(function()
        if UnitHealthPercent and CurveConstants and CurveConstants.ScaleTo100 then
            sb:SetMinMaxValues(0, 100)
            sb:SetValue(UnitHealthPercent(unit, false, CurveConstants.ScaleTo100))
        else
            sb:SetMinMaxValues(0, UnitHealthMax(unit))
            sb:SetValue(UnitHealth(unit))
        end
    end)
    if not okV then
        okV, err = pcall(function()
            sb:SetMinMaxValues(0, UnitHealthMax(unit))
            sb:SetValue(UnitHealth(unit))
        end)
    end
    uf.ubermocMissErr = okV and nil or tostring(err)
    clip:SetShown(okV and true or false)
end

-- Colours, hides, sizes and adds text on a plate according to its group's Look settings.
-- Objects (mailboxes, chests...) get only WoW's interaction icon; friendly NPCs you can talk to get a white chat bubble.
local function plateIsObject(unit)
    if not unit or not UnitIsGameObject then return false end
    local ok, v = pcall(UnitIsGameObject, unit)
    return ok and v and not isHidden(v) and true or false
end

local function updateBubble(plate)
    local uf = plate and plate.UnitFrame
    if not uf then return end
    local unit = plateUnit(plate)
    local show = false
    if unit and UbermocUIDB and UbermocUIDB.chatBubble == true and not plateIsObject(unit) then
        local ok, soft = pcall(UnitIsUnit, unit, "softinteract")
        if ok and soft == true then
            local okP, pl = pcall(UnitIsPlayer, unit)
            local okA, atk = pcall(UnitCanAttack, "player", unit)
            show = okP and okA and pl == false and atk == false
        end
    end
    local b = uf.ubermocBubble
    if show then
        if not b then
            b = CreateFrame("Frame", nil, uf)
            b:SetSize(26, 26)
            b:SetFrameLevel(uf:GetFrameLevel() + 6)
            b.tex = b:CreateTexture(nil, "OVERLAY")
            b.tex:SetAllPoints()
            b.tex:SetTexture("Interface\\CHATFRAME\\UI-ChatIcon-Chat-Up")
            b.tex:SetDesaturated(true)
            b.tex:SetVertexColor(1, 1, 1, 1)
            uf.ubermocBubble = b
        end
        b:ClearAllPoints()
        local anchor = uf.ubermocName
        if anchor and anchor:IsShown() then b:SetPoint("BOTTOM", anchor, "TOP", 0, 4)
        else b:SetPoint("BOTTOM", uf, "TOP", 0, 2) end
        b:Show()
    elseif b then
        b:Hide()
    end
end

local function hideObjectPlate(uf)
    holdHidden(uf.HealthBarsContainer, true)
    holdHidden(uf.healthBar, true)
    holdHidden(uf.selectedBorder, true)
    holdHidden(uf.aggroHighlight, true)
    holdHidden(uf.PlayerLevelDiffFrame, true)
    holdHidden(uf.LevelFrame, true)
    holdHidden(uf.CastBarsContainer, true)
    if uf.name then uf.name:SetAlpha(0); uf.name.ubermocHid = true end
    if uf.ubermocName then uf.ubermocName:Hide() end
    if uf.ubermocPct then uf.ubermocPct:Hide() end
    if uf.ubermocLevel then uf.ubermocLevel:Hide() end
    uf.ubermocGrad = nil
    if uf.ubermocMissClip then uf.ubermocMissClip:Hide() end
    uf.ubermocObject = true
end

-- Cast timer: remaining time (or current / total) on nameplate cast bars. Values the game keeps secret are skipped.
UbermocUIAPI.castTimers = setmetatable({}, { __mode = "k" })
function UbermocUIAPI.castTimes(unit)
    local issecret = _G.issecretvalue
    local _, _, _, s, e = UnitCastingInfo(unit)
    if not e then _, _, _, s, e = UnitChannelInfo(unit) end
    if not e or not s then return nil end
    if issecret and (issecret(s) or issecret(e)) then return nil end
    return GetTime() - s / 1000, (e - s) / 1000
end
do
    local drv, acc = CreateFrame("Frame"), 0
    drv:SetScript("OnUpdate", function(_, dt)
        acc = acc + dt
        if acc < 0.1 then return end
        acc = 0
        for uf, plate in pairs(UbermocUIAPI.castTimers) do
            local cb = uf.CastBarsContainer or uf.castBar
            local fs = cb and cb.ubermocTimer
            if fs and fs:IsShown() then
                local unit = plateUnit(plate)
                local el, tot
                if unit then
                    local ok, a, b = pcall(UbermocUIAPI.castTimes, unit)
                    if ok then el, tot = a, b end
                end
                if el and tot and tot > 0 then
                    el = math.max(0, math.min(tot, el))
                    local key = math.floor(el * 10) + (uf.ubermocCastTotal and 100000 or 0)
                    if fs.ubermocKey ~= key then
                        fs.ubermocKey = key
                        if uf.ubermocCastTotal then fs:SetFormattedText("%.1f / %.1f", el, tot)
                        else fs:SetFormattedText("%.1f", math.max(0, tot - el)) end
                    end
                else
                    if fs.ubermocKey ~= -1 then fs.ubermocKey = -1; fs:SetText("") end
                end
            end
        end
    end)
end

local function stylePlate(plate, group, g)
    local uf = plate and plate.UnitFrame
    if not uf then return end
    local look = g.look
    local unit = plateUnit(plate)
    if plateIsObject(unit) then pcall(hideObjectPlate, uf); return end
    if uf.ubermocObject then
        uf.ubermocObject = nil
        holdHidden(uf.CastBarsContainer, false)
        if uf.name then uf.name:SetAlpha(1); uf.name.ubermocHid = nil end
    end
    pcall(function()
        local nameOnly = look.nameOnly
        local bar = uf.HealthBarsContainer
        local hideBar = look.hideBar or nameOnly
        holdHidden(bar, hideBar)
        holdHidden(uf.healthBar, hideBar)
        local oOn, oSz, oR, oG, oB, oA = UbermocUIAPI.borderOf(H.NP_OUT[group] or "npOutline_enemy")
        local edgeOn = oOn and not hideBar
        holdHidden(bar and bar.border, hideBar or edgeOn)
        -- Our own outline around the health bar, any thickness and colour.
        if bar then
            local e = bar.ubermocEdge
            if edgeOn then
                if not e then
                    e = CreateFrame("Frame", nil, bar)
                    e.t = {}
                    for i = 1, 4 do e.t[i] = e:CreateTexture(nil, "OVERLAY"); e.t[i]:SetTexture("Interface\\Buttons\\WHITE8X8") end
                    bar.ubermocEdge = e
                end
                local hb = uf.healthBar or bar
                e:SetAllPoints(hb)
                local okL, lv = pcall(hb.GetFrameLevel, hb)
                if okL and type(lv) == "number" and not (issecretvalue and issecretvalue(lv)) then e:SetFrameLevel(lv + 5) end
                UbermocUIAPI.drawEdges(e.t, hb, oSz, oR, oG, oB, oA)
                e:Show()
            elseif e then
                e:Hide()
            end
        end
        holdHidden(uf.selectedBorder, hideBar)
        holdHidden(uf.aggroHighlight, hideBar)
        local name = uf.name
        if name then
            if not name.ubermocFont then
                local f, sz, fl = name:GetFont()
                name.ubermocFont = { f, sz, fl }
            end
            local of = name.ubermocFont
            local size = (look.nameSize or 0) > 0 and look.nameSize or nil
            if of[1] then
                if size then
                    name:SetFont(of[1], size, of[3])
                    name.ubermocSized = true
                elseif name.ubermocSized then
                    name:SetFont(of[1], of[2], of[3])
                    name.ubermocSized = nil
                end
            end
        end

        -- Name-only mode: draw the name ourselves (class colour, health gradient) and chain the
        -- percent and level square next to it, so nothing depends on WoW's own name text.
        local ours = uf.ubermocName
        local unitName = unit and UnitName(unit)
        local usable = nameOnly and name and type(unitName) == "string" and not isHidden(unitName) and unitName ~= ""
        if usable then
            if not ours then ours = uf:CreateFontString(nil, "OVERLAY"); uf.ubermocName = ours end
            local of = name.ubermocFont
            ours:SetFont((of and of[1]) or STANDARD_TEXT_FONT, (look.nameSize or 0) > 0 and look.nameSize or ((of and of[2]) or 12), (of and of[3]) or "OUTLINE")
            ours:ClearAllPoints()
            ours:SetPoint("CENTER", name, "CENTER", 0, 0)
            -- Colour: class colour for players, WoW's own colour otherwise.
            local r, gg, b = name:GetTextColor()
            do
                -- WoW's own name text can be plain white; the unit's reaction colour is what we want as the base.
                local rr, rg, rb = reactionColor(unit)
                if rr then r, gg, b = rr, rg, rb end
            end
            local class
            if look.classColor then
                local okP, isPlayer = pcall(UnitIsPlayer, unit)
                if okP and (isHidden(isPlayer) or isPlayer) then
                    local _, cls = UnitClass(unit)
                    if cls and not isHidden(cls) and RAID_CLASS_COLORS and RAID_CLASS_COLORS[cls] then
                        class = RAID_CLASS_COLORS[cls]
                        r, gg, b = class.r, class.g, class.b
                    end
                end
            end
            if not class and look.nameGradient and type(r) == "number" and not isHidden(r) then
                class = { r = r, g = gg, b = b } -- non-players: WoW's own name colour is the base
            end
            -- Tagged by someone else (you will not get credit for it): the name goes grey.
            do
                local okT, tapped = pcall(UnitIsTapDenied, unit)
                if okT and tapped == true and not isHidden(tapped) then
                    class = nil
                    r, gg, b = 0.55, 0.55, 0.55
                end
            end
            local frac = class and look.nameGradient and healthFraction(unit) or nil
            ours:SetWordWrap(false)
            ours:SetNonSpaceWrap(false)
            if class and look.nameGradient then
                uf.ubermocGrad = { name = unitName, class = class, miss = look.missColor }
            else
                uf.ubermocGrad = nil
            end
            if frac then
                ours:SetText(gradientText(unitName, class, frac, look.missColor))
                ours:SetTextColor(1, 1, 1)
            else
                ours:SetText(unitName)
                if type(r) == "number" and not isHidden(r) then ours:SetTextColor(r, gg, b) else ours:SetTextColor(1, 1, 1) end
            end
            missLayer(uf, ours, unit, unitName, look, class and look.nameGradient and not frac and not look.hideName)
            if class and look.nameGradient and not frac then ours:SetTextColor(class.r, class.g, class.b) end
            ours:SetShown(not look.hideName)
            name:SetAlpha(0)
            name.ubermocRepl = true
        else
            uf.ubermocGrad = nil
            if uf.ubermocMissClip then uf.ubermocMissClip:Hide() end
            if ours then ours:Hide() end
            if name and name.ubermocRepl then
                name.ubermocRepl = nil
                if not look.hideName then name:SetAlpha(1) end
            end
        end
        if name and not (usable) then
            if look.hideName then name:SetAlpha(0); name.ubermocHid = true
            elseif name.ubermocHid then name:SetAlpha(1); name.ubermocHid = nil end
        end

        -- Health percent next to the name
        local pctFS = uf.ubermocPct
        local pctShown = false
        if usable and look.showPct then
            if not pctFS then pctFS = uf:CreateFontString(nil, "OVERLAY"); uf.ubermocPct = pctFS end
            local of = name.ubermocFont
            pctFS:SetFont((of and of[1]) or STANDARD_TEXT_FONT, look.pctSize or 12, "OUTLINE")
            pctFS:ClearAllPoints()
            local x, y = look.pctX or 0, look.pctY or 0
            local tp, tv = UbermocUIAPI.threatPad(group, look)
            if look.pctPos == "LEFT" then pctFS:SetPoint("RIGHT", ours, "LEFT", -4 - tp + x, y)
            elseif look.pctPos == "TOP" then pctFS:SetPoint("BOTTOM", ours, "TOP", x, 2 + tv + y)
            elseif look.pctPos == "BOTTOM" then pctFS:SetPoint("TOP", ours, "BOTTOM", x, -2 - tv + y)
            else pctFS:SetPoint("LEFT", ours, "RIGHT", 4 + tp + x, y) end
            uf.ubermocPctMode = look.pctColor or "REACTION"
            do
                local rr, rg, rb
                if uf.ubermocPctMode == "CLASS" then
                    local okP, isPlayer = pcall(UnitIsPlayer, unit)
                    if okP and isPlayer == true then
                        local _, cls = UnitClass(unit)
                        local cc = cls and RAID_CLASS_COLORS and RAID_CLASS_COLORS[cls]
                        if cc then rr, rg, rb = cc.r, cc.g, cc.b end
                    end
                    if not rr then rr, rg, rb = reactionColor(unit) end
                elseif uf.ubermocPctMode == "WHITE" or uf.ubermocPctMode == "HEALTH" then
                    rr, rg, rb = 1, 1, 1
                else
                    rr, rg, rb = reactionColor(unit)
                end
                if rr then pctFS:SetTextColor(rr, rg, rb) else pctFS:SetTextColor(1, 1, 1) end
            end
            pctFS:Show()
            pctShown = true
            updatePct(plate)
        elseif pctFS then
            pctFS:Hide()
        end

        -- Level square: drawn by the addon so it can be switched, moved and resized freely.
        -- WoW's own level frames are kept out of the way while it is on.
        holdHidden(uf.PlayerLevelDiffFrame, usable and true or false)
        holdHidden(uf.LevelFrame, usable and true or false)
        local sq = uf.ubermocLevel
        if usable and look.showLevel then
            if not sq then
                sq = CreateFrame("Frame", nil, uf)
                sq:SetFrameLevel(uf:GetFrameLevel() + 5)
                sq.edge = sq:CreateTexture(nil, "BACKGROUND")
                sq.edge:SetAllPoints()
                sq.edge:SetColorTexture(0.55, 0.55, 0.6, 1)
                sq.fill = sq:CreateTexture(nil, "BORDER")
                sq.fill:SetPoint("TOPLEFT", 1, -1)
                sq.fill:SetPoint("BOTTOMRIGHT", -1, 1)
                sq.fill:SetColorTexture(0.05, 0.05, 0.07, 1)
                sq.text = sq:CreateFontString(nil, "OVERLAY")
                sq.text:SetAllPoints(sq)
                sq.text:SetJustifyH("CENTER")
                sq.text:SetJustifyV("MIDDLE")
                sq.text:SetWordWrap(false)
                uf.ubermocLevel = sq
            end
            local size = look.levelSize or 22
            sq:SetSize(size, size)
            sq.fill:SetColorTexture(0.05, 0.05, 0.07, (look.levelBg or 95) / 100)
            do
                local lOn, lSz, lR, lG, lB, lA = UbermocUIAPI.borderOf(H.NP_LVL[group] or "npLevel_enemy")
                sq.edge:SetColorTexture(lR, lG, lB, lA)
                sq.edge:SetShown(lOn)
                local i = lOn and lSz or 0
                sq.fill:ClearAllPoints(); sq.fill:SetPoint("TOPLEFT", i, -i); sq.fill:SetPoint("BOTTOMRIGHT", -i, i)
            end
            local of = name.ubermocFont
            sq.text:SetFont((of and of[1]) or STANDARD_TEXT_FONT, math.max(8, math.floor(size * 0.55)), "OUTLINE")
            local okL, lv = pcall(UnitEffectiveLevel or UnitLevel, unit)
            sq.text:SetTextColor(1, 1, 1)
            if okL and type(lv) == "number" and not isHidden(lv) then
                sq.text:SetText(lv > 0 and tostring(lv) or "??")
                if GetCreatureDifficultyColor and lv > 0 then
                    local okC, c = pcall(GetCreatureDifficultyColor, lv)
                    if okC and type(c) == "table" and c.r then sq.text:SetTextColor(c.r, c.g, c.b) end
                end
                local tr, tg, tb2 = UbermocUIAPI.levelTextColor(look)
                if tr then sq.text:SetTextColor(tr, tg, tb2) end
            elseif okL and lv ~= nil then
                pcall(sq.text.SetFormattedText, sq.text, "%d", lv)
                local tr, tg, tb2 = UbermocUIAPI.levelTextColor(look)
                if tr then sq.text:SetTextColor(tr, tg, tb2) end
            else
                sq.text:SetText("??")
            end
            local right = look.levelSide ~= "LEFT"
            local rel = ours
            if pctShown and ((right and look.pctPos ~= "LEFT" and look.pctPos ~= "TOP" and look.pctPos ~= "BOTTOM")
                             or (not right and look.pctPos == "LEFT")) then
                rel = pctFS
            end
            local lx, ly = look.levelX or 0, look.levelY or 0
            sq:ClearAllPoints()
            local tp = (rel == pctFS) and UbermocUIAPI.threatPad(group, look) or 0
            if right then sq:SetPoint("LEFT", rel, "RIGHT", 4 + tp + lx, ly) else sq:SetPoint("RIGHT", rel, "LEFT", -4 - tp + lx, ly) end
            sq:Show()
        elseif sq then
            sq:Hide()
        end

        -- Cast bar: lined up under the name (name-only) or under the health bar, at the same width.
        -- Both the container and the bar itself are placed (whichever this client has), and the game's
        -- own re-anchoring is put back every time, so the bar stays centred on the health bar.
        local cbs = {}
        local cbc, cbar = uf.CastBarsContainer, uf.castBar
        if type(cbc) == "table" and cbc.SetPoint then cbs[#cbs + 1] = cbc end
        if type(cbar) == "table" and cbar.SetPoint and cbar ~= cbc then cbs[#cbs + 1] = cbar end
        if #cbs > 0 then
            local mode
            local cw, cx, cy = look.castW or 0, look.castX or 0, look.castY or 0
            if usable and nameOnly and uf.ubermocName then mode = "name"
            elseif bar then mode = "bar" end -- always as wide as the health bar (or the width set here)
            local hb = uf.healthBar or bar
            local h = (look.castHeight or 0) > 0 and look.castHeight or ((usable and nameOnly) and g.height or nil)
            for _, cb in ipairs(cbs) do
                if not cb.ubermocPts then
                    local pts = {}
                    for i = 1, cb:GetNumPoints() do pts[i] = { cb:GetPoint(i) } end
                    cb.ubermocPts = pts
                end
                if mode then
                    cb.ubermocWant = function(self)
                        self.ubermocBusyP = true
                        self:ClearAllPoints()
                        if mode == "name" then
                            local nm = uf.ubermocName or hb
                            if cw > 0 then
                                self:SetPoint("TOP", nm, "BOTTOM", cx, -3 + cy)
                                self:SetWidth(cw)
                            else
                                -- The whole name row: from its left end (name, percent or level) to its right end.
                                local L, R = nm, nm
                                local pf, lv = uf.ubermocPct, uf.ubermocLevel
                                if pf and pf:IsShown() then
                                    if look.pctPos == "LEFT" then L = pf elseif look.pctPos ~= "TOP" and look.pctPos ~= "BOTTOM" then R = pf end
                                end
                                if lv and lv:IsShown() then
                                    if look.levelSide == "LEFT" then L = lv else R = lv end
                                end
                                local pad = look.castPad; if pad == nil then pad = 6 end
                                self:SetPoint("TOPLEFT", L, "BOTTOMLEFT", cx - pad, -3 + cy)
                                self:SetPoint("TOPRIGHT", R, "BOTTOMRIGHT", cx + pad, -3 + cy)
                            end
                        elseif cw > 0 then
                            self:SetPoint("TOP", hb, "BOTTOM", cx, -2 + cy)
                            self:SetWidth(cw)
                        else
                            local pad = look.castPad; if pad == nil then pad = 6 end
                            self:SetPoint("TOPLEFT", hb, "BOTTOMLEFT", cx - pad, -2 + cy)
                            self:SetPoint("TOPRIGHT", hb, "BOTTOMRIGHT", cx + pad, -2 + cy)
                        end
                        if h then self:SetHeight(h) end
                        self.ubermocBusyP = false
                    end
                    if not cb.ubermocPlaceHook then
                        cb.ubermocPlaceHook = true
                        for _, fn in ipairs({ "SetPoint", "ClearAllPoints", "SetWidth", "SetHeight", "SetSize" }) do
                            hooksecurefunc(cb, fn, function(self)
                                if self.ubermocWant and not self.ubermocBusyP then self:ubermocWant() end
                            end)
                        end
                    end
                    cb:ubermocWant()
                    cb.ubermocMoved = true
                elseif cb.ubermocMoved then
                    cb.ubermocWant = nil
                    cb.ubermocBusyP = true
                    cb:ClearAllPoints()
                    for _, pt in ipairs(cb.ubermocPts) do cb:SetPoint(pt[1], pt[2], pt[3], pt[4], pt[5]) end
                    cb.ubermocBusyP = false
                    cb.ubermocMoved = nil
                end
            end
            -- Cast timer text on the right end of the cast bar.
            local cb = cbc or cbar
            if look.castTimer then
                if not cb.ubermocTimer then
                    cb.ubermocTimer = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                    cb.ubermocTimer:SetPoint("RIGHT", cb, "RIGHT", -3, 0)
                    do
                        local p0, s0 = cb.ubermocTimer:GetFont()
                        if p0 then cb.ubermocTimer:SetFont(p0, s0, "OUTLINE") end
                        cb.ubermocTimer:SetShadowOffset(0, 0)
                    end
                end
                cb.ubermocTimer:Show()
                uf.ubermocCastTotal = look.castTotal and true or false
                UbermocUIAPI.castTimers[uf] = plate
            elseif cb.ubermocTimer then
                cb.ubermocTimer:Hide()
                UbermocUIAPI.castTimers[uf] = nil
            end
        end
    end)
    pcall(updateBubble, plate)
end

do
    local bf = CreateFrame("Frame")
    pcall(bf.RegisterEvent, bf, "PLAYER_SOFT_INTERACT_CHANGED")
    bf:SetScript("OnEvent", function()
        if not (C_NamePlate and C_NamePlate.GetNamePlates) then return end
        for _, plate in ipairs(C_NamePlate.GetNamePlates()) do pcall(updateBubble, plate) end
    end)
end

local function plateGroup(plate)
    return isHostileUnit(plateUnit(plate)) and "enemy" or "friendly"
end

restylePlates = function()
    local np = UbermocUIDB and UbermocUIDB.nameplates
    if not np or not (C_NamePlate and C_NamePlate.GetNamePlates) then return end
    for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
        local group = plateGroup(plate)
        sizePlateBar(plate, group, np[group])
        stylePlate(plate, group, np[group])
        UbermocUIAPI.scaleTargetPlate(plate, np[group])
    end
end

updatePlatePcts = function()
    if not (C_NamePlate and C_NamePlate.GetNamePlates) then return end
    for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
        local grp = plateGroup(plate)
        local g = UbermocUIDB.nameplates[grp]
        if g.look.nameOnly then stylePlate(plate, grp, g) elseif grp == "friendly" then updatePct(plate) end
    end
end

-- Nameplate fading: the Enemy / Friendly nameplates elements set the opacity of the plate frame.
local function plateAlpha(plate, group)
    local a = curEff[group == "enemy" and "npenemy" or "npfriendly"] or 1
    if a ~= 1 or plate.ubermocFaded then
        pcall(plate.SetAlpha, plate, a)
        plate.ubermocFaded = (a ~= 1)
    end
end

applyPlateAlpha = function()
    if not (C_NamePlate and C_NamePlate.GetNamePlates) then return end
    for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
        plateAlpha(plate, plateGroup(plate))
    end
end

local function updatePlate(plate)
    if not plate then return end
    local unit = plateUnit(plate)
    local anchor = plateAnchor(plate)
    local hostile = isHostileUnit(unit)
    local group = hostile and "enemy" or "friendly"
    local np = UbermocUIDB.nameplates[group]
    sizePlateBar(plate, group, np)
    stylePlate(plate, group, np)
    UbermocUIAPI.scaleTargetPlate(plate, np)
    plateAlpha(plate, group)
    -- In name-only mode there is no health bar, so icons and debuffs hang on the name itself and follow
    -- it whatever its length.
    do
        local ours = plate.UnitFrame and plate.UnitFrame.ubermocName
        if np.look.nameOnly and ours and ours:IsShown() then anchor = ours end
        if UbermocUIAPI.reanchorNpAura then pcall(UbermocUIAPI.reanchorNpAura, plate, anchor) end
    end
    local c = unit and classificationOf(unit)
    local friendly = group == "friendly"
    local want = {
        quest = (not friendly and np.quest.on and unit and isQuestUnit(unit)) or false,
        elite = (not friendly and np.elite.on and (c == "elite" or c == "rareelite" or c == "worldboss")) or false,
        rare = (not friendly and np.rare.on and (c == "rare" or c == "rareelite")) or false,
    }
    -- The floating target frame draws these itself (the quest marker sits right of its bars), so the target's own
    -- plate keeps none of them.
    if unit and UbermocUIAPI.floatingTargetOn and UbermocUIAPI.floatingTargetOn() then
        local okT, isT = pcall(UnitIsUnit, unit, "target")
        if okT and not (issecretvalue and issecretvalue(isT)) and isT then want.quest, want.elite, want.rare = false, false, false end
    end
    local set = indicators[plate]
    if not set then set = {}; indicators[plate] = set end
    -- Icons chain after the level box (or the percent, or the name): elite and rare share one spot, and
    -- the quest marker sits after whichever of them is showing.
    local uf2 = plate.UnitFrame
    local base = anchor
    if np.look.nameOnly and uf2 then
        local lvl, pct = uf2.ubermocLevel, uf2.ubermocPct
        if lvl and lvl:IsShown() then base = lvl
        elseif pct and pct:IsShown() then base = pct end
    end
    local chainFrame
    for _, kind in ipairs({ "elite", "rare", "quest" }) do
        local f = set[kind]
        if want[kind] then
            if not f then f = makeIndicator(plate, kind); set[kind] = f end
            local rel = base
            if kind == "quest" and chainFrame then rel = chainFrame end
            layoutIndicator(f, rel, np[kind], 0)
            if f.text then f.text:SetText((np[kind].progress and questProgress(unit)) or "") end
            f:Show()
            if kind ~= "quest" and not chainFrame then chainFrame = f end
        elseif f then
            f:Hide()
        end
    end
end

-- Lets the target arrows find the icons on a plate so they can sit outside them.
-- What the target arrows sit outside of, on each side of the name / bar: the health percent and level
-- square (name-only mode) and the quest / elite / rare icons. Worked out from the layout itself, because
-- the game won't hand out nameplate positions. The kill icon is left out on purpose (arrows may cover it).
function H.iconShown(f) return f and f.IsShown and f:IsShown() end
H.ICON_KINDS = { "elite", "rare", "quest" }
function UbermocUIAPI.plateIcons(plate, out)
    local uf = plate and plate.UnitFrame
    if not uf then return end
    local unit = plateUnit(plate)
    local np = UbermocUIDB.nameplates[isHostileUnit(unit) and "enemy" or "friendly"]
    local look = np.look
    local shown = H.iconShown
    local left, right
    if look.nameOnly then
        if shown(uf.ubermocPct) then
            if look.pctPos == "LEFT" then left = uf.ubermocPct
            elseif look.pctPos ~= "TOP" and look.pctPos ~= "BOTTOM" then right = uf.ubermocPct end
        end
        if shown(uf.ubermocLevel) then
            if look.levelSide == "LEFT" then left = uf.ubermocLevel else right = uf.ubermocLevel end
        end
    end
    local set = indicators[plate]
    if set then
        for _, kind in ipairs(H.ICON_KINDS) do
            local f = set[kind]
            if shown(f) and np[kind] then
                if np[kind].position == "RIGHT" then right = f elseif np[kind].position == "LEFT" then left = f end
            end
        end
    end
    out.left, out.right = left, right
end

updateAllPlates = function()
    if not UbermocUIDB or not (C_NamePlate and C_NamePlate.GetNamePlates) then return end
    for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
        pcall(updatePlate, plate) -- a protected plate must never break the rest
    end
end

-- The plate frame itself (what you click) must be at least as wide as the bars,
-- so when a bar is wider than WoW's own plate width the frame is widened to fit.
local baseFrameSize
local function frameSize()
    if not baseFrameSize and C_NamePlate and C_NamePlate.GetNamePlateSize then
        local ok, w, h = pcall(C_NamePlate.GetNamePlateSize)
        if ok and tonumber(w) and tonumber(h) and not isHidden(w) and not isHidden(h) and w > 0 and h > 0 then
            baseFrameSize = { w, h }
        end
    end
    return baseFrameSize
end

applyPlateSizes = function()
    local np = UbermocUIDB and UbermocUIDB.nameplates
    if not np then return end
    if InCombatLockdown() then plateScalePending = true; return end
    local base = frameSize()
    if base and C_NamePlate.SetNamePlateSize then
        local need = base[1]
        for _, group in ipairs({ "enemy", "friendly" }) do
            local lk = np[group].look
            if np[group].width or lk.targetW > 0 or lk.mouseW > 0 then
                local w0 = np[group].width or select(1, getPlateSize(group))
                need = math.max(need, w0 + math.max(lk.targetW, lk.mouseW) + 20)
            end
        end
        pcall(C_NamePlate.SetNamePlateSize, need, base[2])
    end
    updateAllPlates()
end

resetPlateSizes = function()
    applyPlateSizes()
end

-- Blizzard re-lays out a plate when its name updates; put our bar size back afterwards.
local sizeHooked = false
local function hookPlateLayout()
    if sizeHooked or not CompactUnitFrame_UpdateName then return end
    sizeHooked = true
    -- A plain function (no new closure each time: this runs for every nameplate name update).
    local function restyle(frame)
            local np = UbermocUIDB and UbermocUIDB.nameplates
            local unit = frame and frame.unit
            if not np or not unit or InCombatLockdown() or frame:IsForbidden() then return end
            local plate = C_NamePlate.GetNamePlateForUnit(unit)
            if not plate or plate.UnitFrame ~= frame then return end
            local group = isHostileUnit(unit) and "enemy" or "friendly"
            local g = np[group]
            sizePlateBar(plate, group, g)
            stylePlate(plate, group, g)
    end
    hooksecurefunc("CompactUnitFrame_UpdateName", function(frame) pcall(restyle, frame) end)
end
hookPlateLayout()

applyPlateVisibility = function()
    local np = UbermocUIDB and UbermocUIDB.nameplates
    if not np then return end
    if InCombatLockdown() then plateScalePending = true; return end
    if not np.scaleReset then
        -- Older versions could leave the game's nameplate scale changed; width and height replace it.
        np.scaleReset = true
        pcall(SetCVar, "nameplateGlobalScale", "1")
    end
    if np.friendlyClickThrough ~= nil and C_NamePlateManager and C_NamePlateManager.SetNamePlateHitTestInsets
       and Enum and Enum.NamePlateType then
        local inset = np.friendlyClickThrough and 10000 or 0
        pcall(C_NamePlateManager.SetNamePlateHitTestInsets, Enum.NamePlateType.Friendly, inset, inset, inset, inset)
    end
    if not np.onV2 then np.onV2 = true; np.showEnemies = true; np.showFriends = true end   -- once: both on by default
    if not np.enemiesV1 then np.enemiesV1 = true; if np.showEnemies == nil then np.showEnemies = true end end
    if np.showEnemies ~= nil then pcall(SetCVar, "nameplateShowEnemies", np.showEnemies and "1" or "0") end
    if np.showFriends ~= nil then pcall(SetCVar, "nameplateShowFriendlyPlayers", np.showFriends and "1" or "0") end
    if np.showFriendNpcs ~= nil then pcall(SetCVar, "nameplateShowFriendlyNpcs", np.showFriendNpcs and "1" or "0") end
end

----------------------------------------------------------------------
-- Minimap page: experience bar instead of the zone name, time and coordinates inside the minimap
----------------------------------------------------------------------
local buildMinimapPanel, mmApply, mmAlign
UbermocUIAPI.mmApply = function() if mmApply then mmApply() end end
do
    local xpBar

    local function atMaxLevel()
        if IsXPUserDisabled and IsXPUserDisabled() then return true end
        if IsPlayerAtEffectiveMaxLevel then
            local ok, r = pcall(IsPlayerAtEffectiveMaxLevel)
            if ok and r ~= nil then return r and true or false end
        end
        local mx = GetMaxPlayerLevel and GetMaxPlayerLevel()
        return mx ~= nil and UnitLevel("player") >= mx
    end

    local function xpValues()
        local ok, cur, mx, rest = pcall(function()
            return UnitXP("player"), UnitXPMax("player"), GetXPExhaustion and GetXPExhaustion() or nil
        end)
        if not ok or isHidden(cur) or isHidden(mx) or type(cur) ~= "number" or type(mx) ~= "number" or mx <= 0 then return nil end
        if type(rest) ~= "number" or isHidden(rest) then rest = nil end
        return cur, mx, rest
    end

    -- Day phase from the game clock.
    function UbermocUIAPI.phaseInfo()
        local h = (GetGameTime and GetGameTime()) or 12
        if type(h) ~= "number" then h = 12 end
        if h >= 5 and h < 7 then return "Dawn", 1, 0.75, 0.45
        elseif h >= 7 and h < 17 then return "Day", 1, 0.9, 0.4
        elseif h >= 17 and h < 19 then return "Evening", 1, 0.6, 0.3
        elseif h >= 19 and h < 20 then return "Dusk", 0.85, 0.5, 0.75
        end
        return "Night", 0.55, 0.65, 1
    end

    -- Docks a Blizzard button inside the experience bar (scaled to the bar), or puts it back.
    function UbermocUIAPI.dockFrame(frame, spec)
        if type(frame) ~= "table" or not frame.SetPoint or not frame.GetNumPoints then return end
        if InCombatLockdown() and frame.IsProtected and frame:IsProtected() then return end
        if not frame.ubermocDockPts then
            if not spec then return end
            local pts = {}
            for i = 1, tonumber(frame:GetNumPoints()) or 0 do pts[i] = { frame:GetPoint(i) } end
            frame.ubermocDockPts = pts
            frame.ubermocDockScale = frame:GetScale()
            frame.ubermocDockLevel = { frame:GetFrameStrata(), frame:GetFrameLevel() }
            local h = frame:GetHeight()
            frame.ubermocDockH = (type(h) == "number" and h > 4) and h or spec.baseH
            hooksecurefunc(frame, "SetPoint", function(self)
                local sp = self.ubermocDock
                if self.ubermocDockBusy or not sp then return end
                self.ubermocDockBusy = true
                self:ClearAllPoints()
                self:SetPoint(sp.point, sp.rel, sp.point, sp.x / sp.scale, 0)
                self.ubermocDockBusy = false
            end)
        end
        frame.ubermocDockBusy = true
        if spec then
            local sc = math.max(0.3, spec.size / frame.ubermocDockH)
            frame:SetScale(sc)
            frame.ubermocDock = { point = spec.point, rel = spec.rel, x = spec.x, scale = sc }
            frame:ClearAllPoints()
            frame:SetPoint(spec.point, spec.rel, spec.point, spec.x / sc, 0)
            pcall(frame.SetFrameStrata, frame, "MEDIUM")
            pcall(frame.SetFrameLevel, frame, spec.rel:GetFrameLevel() + 4)
            frame.ubermocNudge = nil
            frame.ubermocDocked = true
            if spec.border then
                local bd = frame.ubermocDockBorder
                if not bd then
                    bd = CreateFrame("Frame", nil, frame)
                    bd.tex = bd:CreateTexture(nil, "BACKGROUND")
                    bd.tex:SetAllPoints()
                    bd.tex:SetColorTexture(0, 0, 0, 1)
                    frame.ubermocDockBorder = bd
                end
                local pad = 2 / sc
                bd:ClearAllPoints()
                bd:SetPoint("TOPLEFT", frame, "TOPLEFT", -pad, pad)
                bd:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", pad, -pad)
                pcall(bd.SetFrameLevel, bd, math.max(0, frame:GetFrameLevel() - 1))
                bd:Show()
                -- A black frame drawn over the button's own (gold) rim. It belongs to the strip, not to the
                -- button, so nothing inside the button can cover it.
                local ov = frame.ubermocDockOver
                if not ov then
                    ov = CreateFrame("Frame", nil, spec.rel)
                    ov:EnableMouse(false)
                    ov.t = {}
                    for i = 1, 4 do
                        ov.t[i] = ov:CreateTexture(nil, "OVERLAY")
                        ov.t[i]:SetColorTexture(0, 0, 0, 1)
                    end
                    frame.ubermocDockOver = ov
                end
                ov:SetParent(spec.rel)
                ov:SetFrameStrata(frame:GetFrameStrata())
                pcall(ov.SetFrameLevel, ov, math.max(frame:GetFrameLevel(), spec.rel:GetFrameLevel()) + 40)
                ov:ClearAllPoints()
                ov:SetPoint("TOPLEFT", frame, "TOPLEFT", -1, 1)
                ov:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 1, -1)
                local w = 3
                local t = ov.t
                t[1]:ClearAllPoints(); t[1]:SetPoint("TOPLEFT", ov, "TOPLEFT", 0, 0); t[1]:SetPoint("TOPRIGHT", ov, "TOPRIGHT", 0, 0); t[1]:SetHeight(w)
                t[2]:ClearAllPoints(); t[2]:SetPoint("BOTTOMLEFT", ov, "BOTTOMLEFT", 0, 0); t[2]:SetPoint("BOTTOMRIGHT", ov, "BOTTOMRIGHT", 0, 0); t[2]:SetHeight(w)
                t[3]:ClearAllPoints(); t[3]:SetPoint("TOPLEFT", ov, "TOPLEFT", 0, 0); t[3]:SetPoint("BOTTOMLEFT", ov, "BOTTOMLEFT", 0, 0); t[3]:SetWidth(w)
                t[4]:ClearAllPoints(); t[4]:SetPoint("TOPRIGHT", ov, "TOPRIGHT", 0, 0); t[4]:SetPoint("BOTTOMRIGHT", ov, "BOTTOMRIGHT", 0, 0); t[4]:SetWidth(w)
                ov:Show()
            elseif frame.ubermocDockBorder then
                frame.ubermocDockBorder:Hide()
                if frame.ubermocDockOver then frame.ubermocDockOver:Hide() end
            end
        elseif frame.ubermocDocked then
            if frame.ubermocDockBorder then frame.ubermocDockBorder:Hide() end
            if frame.ubermocDockOver then frame.ubermocDockOver:Hide() end
            frame.ubermocDock = nil
            frame:SetScale(frame.ubermocDockScale or 1)
            frame:ClearAllPoints()
            for _, pt in ipairs(frame.ubermocDockPts) do frame:SetPoint(pt[1], pt[2], pt[3], pt[4], pt[5]) end
            pcall(frame.SetFrameStrata, frame, frame.ubermocDockLevel[1])
            pcall(frame.SetFrameLevel, frame, frame.ubermocDockLevel[2])
            frame.ubermocDocked = nil
        end
        frame.ubermocDockBusy = false
    end

    -- Darkens a minimap header button at the source: the game draws the whole button (gold rim and
    -- icon) as one picture called its state texture, so that picture is tinted and a copy of the
    -- icon part (the centre) is drawn on top untinted. owner is "dock" or "dark"; "dark" wins.
    function UbermocUIAPI.darkenButton(btn, on, owner, r, g, b)
        if type(btn) ~= "table" or not btn.CreateTexture then return false end
        local state = btn.StateTexture
        if type(state) ~= "table" and btn.GetNormalTexture then
            local okN, nt = pcall(btn.GetNormalTexture, btn)
            if okN then state = nt end
        end
        if type(state) ~= "table" or not state.GetAtlas or not state.SetVertexColor then return false end
        if on then
            if btn.ubermocDarkOwner == "dark" and owner ~= "dark" then return true end
            local atlas = state:GetAtlas()
            local file = (not atlas) and state.GetTexture and state:GetTexture() or nil
            if not atlas and not file then return false end
            if not btn.ubermocDarkOrig then
                local cr, cg, cb, ca = state:GetVertexColor()
                btn.ubermocDarkOrig = { cr or 1, cg or 1, cb or 1, ca or 1 }
            end
            local ic = btn.ubermocIcon
            if not ic then
                ic = btn:CreateTexture(nil, "ARTWORK", nil, 1)
                ic.mask = btn:CreateMaskTexture()
                ic.mask:SetTexture("Interface\\BUTTONS\\WHITE8X8", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
                ic:AddMaskTexture(ic.mask)
                btn.ubermocIcon = ic
                hooksecurefunc(state, "SetAtlas", function(_, a)
                    if btn.ubermocDarkOwner and a then pcall(ic.SetAtlas, ic, a) end
                end)
            end
            if atlas then ic:SetAtlas(atlas)
            else
                ic:SetTexture(file)
                if state.GetTexCoord then pcall(function() ic:SetTexCoord(state:GetTexCoord()) end) end
            end
            ic:ClearAllPoints()
            ic:SetAllPoints(state)
            local w = state:GetWidth()
            if type(w) ~= "number" or w <= 0 then w = btn:GetWidth() end
            if type(w) ~= "number" or w <= 0 then w = 32 end
            local inset = w * 0.22
            ic.mask:ClearAllPoints()
            ic.mask:SetPoint("TOPLEFT", state, "TOPLEFT", inset, -inset)
            ic.mask:SetPoint("BOTTOMRIGHT", state, "BOTTOMRIGHT", -inset, inset)
            ic:Show()
            local o = btn.ubermocDarkOrig
            -- Docked buttons lose the drawn rim entirely (only the icon centre stays); dark mode just tints it.
            state:SetVertexColor((o[1]) * (r or 0.1), (o[2]) * (g or r or 0.1), (o[3]) * (b or r or 0.1), owner == "dock" and 0 or o[4])
            btn.ubermocDarkOwner = owner
            return true
        end
        if btn.ubermocDarkOwner == owner then
            local o = btn.ubermocDarkOrig
            if o then state:SetVertexColor(o[1], o[2], o[3], o[4]) end
            if btn.ubermocIcon then btn.ubermocIcon:Hide() end
            btn.ubermocDarkOwner = nil
        end
        return true
    end

    function UbermocUIAPI.dockButtons(on, bar, size)
        local dockFrame = UbermocUIAPI.dockFrame
        local track = getFrame("MinimapCluster.Tracking")
        local mail = getFrame("MinimapCluster.IndicatorFrame")
        local cal = _G.GameTimeFrame
        if on and bar then
            dockFrame(track, { point = "LEFT", rel = bar, x = 3, size = size, baseH = 32, border = true })
            dockFrame(mail, { point = "LEFT", rel = bar, x = 3 + size + 3, size = size, baseH = 24 })
            dockFrame(cal, { point = "RIGHT", rel = bar, x = -3, size = size, baseH = 32, border = true })
        else
            dockFrame(track, nil); dockFrame(mail, nil); dockFrame(cal, nil)
        end
        local dk = on and bar and true or false
        if type(track) == "table" and track.Background and track.Background.SetAlpha then
            pcall(track.Background.SetAlpha, track.Background, dk and 0 or 1)
        end
        -- When the rim itself can be darkened, the extra black frames are not needed.
        for _, pair in ipairs({ { type(track) == "table" and track.Button or nil, track }, { cal, cal } }) do
            local okD, did = pcall(UbermocUIAPI.darkenButton, pair[1], dk, "dock", 0.04)
            local fr = pair[2]
            if okD and did and dk and type(fr) == "table" then
                if fr.ubermocDockBorder then fr.ubermocDockBorder:Hide() end
                if fr.ubermocDockOver then fr.ubermocDockOver:Hide() end
            end
        end
    end

    -- Player coordinates as text, or "--" where the game gives none.
    function UbermocUIAPI.coordText()
        if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then return "--" end
        local ok, x, y = pcall(function()
            local m = C_Map.GetBestMapForUnit("player")
            if not m then return nil end
            local p = C_Map.GetPlayerMapPosition(m, "player")
            if not p then return nil end
            return p:GetXY()
        end)
        if not ok or type(x) ~= "number" or type(y) ~= "number" or isHidden(x) or isHidden(y) then return "--" end
        return string.format("%.1f, %.1f", x * 100, y * 100)
    end

    -- A separate strip above the experience bar: search / mail / calendar buttons at the sides,
    -- the time of day and coordinates in the middle.
    function UbermocUIAPI.updateStrip(xp)
        local c = UbermocUIDB and UbermocUIDB.mm and UbermocUIDB.mm.xp
        local want = c and Minimap and (c.icons or c.phase or c.coords)
        local strip = UbermocUIAPI.stripFrame
        if not want then
            if strip then strip:Hide() end
            pcall(UbermocUIAPI.dockButtons, false)
            return
        end
        if not strip then
            local f = CreateFrame("Frame", "UbermocTopStrip", MinimapCluster or UIParent)
            f:SetFrameStrata("MEDIUM")
            f.bg = f:CreateTexture(nil, "BACKGROUND")
            f.bg:SetAllPoints()
            f.bg:SetColorTexture(0, 0, 0, 0.95)
            f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            f.text:SetPoint("CENTER", 0, 0)
            UbermocUIAPI.shade(f.text, STANDARD_TEXT_FONT, 13, "strip")
            f.t = 0
            f:SetScript("OnUpdate", function(self, dt)
                self.t = self.t + dt
                if self.t < 0.5 then return end
                self.t = 0
                UbermocUIAPI.refreshStripText()
            end)
            strip = f
            UbermocUIAPI.stripFrame = f
        end
        local bs = UbermocUIAPI.mapEdge()
        local H = 24
        strip:SetFrameLevel((Minimap:GetFrameLevel() or 1) + 12)
        strip:ClearAllPoints()
        if xp and xp:IsShown() and c.attach then
            strip:SetPoint("BOTTOMLEFT", xp, "TOPLEFT", 0, 0)
            strip:SetWidth(Minimap:GetWidth() + 2 * bs)
        else
            strip:SetPoint("BOTTOMLEFT", Minimap, "TOPLEFT", -bs, bs)
            strip:SetWidth(Minimap:GetWidth() + 2 * bs)
        end
        strip:SetHeight(H)
        strip:Show()
        pcall(UbermocUIAPI.dockButtons, c.icons and true or false, strip, H - 4)
        -- The sun / moon and the game's addon square are not needed once the strip is up.
        local want = c.icons and true or false
        for _, fr in ipairs({ getFrame("MinimapCluster.DielFrame"), _G.AddonCompartmentFrame }) do
            if type(fr) == "table" then
                if want then
                    fr.ubermocStripHid = true
                    pcall(holdHidden, fr, true)
                elseif fr.ubermocStripHid then
                    fr.ubermocStripHid = nil
                    pcall(holdHidden, fr, false)
                end
            end
        end
        -- Text sits between the mail icon and the calendar (whole strip when icons are off).
        local tx = strip.text
        UbermocUIAPI.shade(tx, STANDARD_TEXT_FONT, c.stripSize or 12, "strip")
        -- The outline is eight dark copies of the text a pixel around it, so its strength can be anything.
        if not strip.out then
            strip.out = {}
            for _, o in ipairs({ { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 }, { -1, -1 }, { 1, 1 }, { -1, 1 }, { 1, -1 } }) do
                local t = strip:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
                t.ox, t.oy = o[1], o[2]
                t:SetDrawLayer("ARTWORK", -1)
                t:SetWordWrap(false)
                t:SetJustifyH("CENTER")
                strip.out[#strip.out + 1] = t
            end
        end
        tx:ClearAllPoints()
        tx:SetWordWrap(false)
        tx:SetJustifyH("CENTER")
        if want then
            tx:SetPoint("LEFT", strip, "LEFT", 3 + 2 * (H - 6) + 10, 0)
            tx:SetPoint("RIGHT", strip, "RIGHT", -(3 + (H - 6) + 6), 0)
        else
            tx:SetPoint("LEFT", strip, "LEFT", 4, 0)
            tx:SetPoint("RIGHT", strip, "RIGHT", -4, 0)
        end
        for _, t in ipairs(strip.out) do
            pcall(t.SetFont, t, STANDARD_TEXT_FONT, c.stripSize or 12, "")
            t:SetShadowOffset(0, 0)
            t:ClearAllPoints()
            if want then
                t:SetPoint("LEFT", strip, "LEFT", 3 + 2 * (H - 6) + 10 + t.ox, t.oy)
                t:SetPoint("RIGHT", strip, "RIGHT", -(3 + (H - 6) + 6) + t.ox, t.oy)
            else
                t:SetPoint("LEFT", strip, "LEFT", 4 + t.ox, t.oy)
                t:SetPoint("RIGHT", strip, "RIGHT", -4 + t.ox, t.oy)
            end
        end
        UbermocUIAPI.stripFrame = strip
        strip.ubLast = nil   -- a setting changed: draw it again
        UbermocUIAPI.refreshStripText()
    end

    -- Black filler between the shortened experience bar and the addon box beside it.
    function UbermocUIAPI.fillXPGap(xp)
        local c = UbermocUIDB and UbermocUIDB.mm
        local box = _G.UbermocModBox
        local g = UbermocUIAPI.xpGap
        local want = xp and xp:IsShown() and c and c.xp and c.xp.attach and c.xp.reserve and c.box and c.box.on and (c.box.corner or "TOPRIGHT") == "TOPRIGHT" and box and box:IsShown()
        if g then g:Hide() end
        if want then
            -- Already in place (this is looked at 4 times a second): nothing to do.
            local h = xp:GetHeight()
            if box.ubXP == xp and box.ubXPH == h and box:GetNumPoints() == 1 then
                local _, rel = box:GetPoint(1)
                if rel == xp then return end
            end
            box.ubXP, box.ubXPH = xp, h
            -- The addon box sits flush at the end of the bar: same height, no gap, no overlap.
            box:SetSize(xp:GetHeight(), xp:GetHeight())
            box:ClearAllPoints()
            box:SetPoint("RIGHT", xp, "RIGHT", 0, 0)
            -- Joined to the bar: no border or background of its own, just the icon on the bar's background.
            if box.edge then box.edge:Hide() end
            if box.bg then box.bg:Hide() end
            if box.icon then
                box.icon:ClearAllPoints()
                box.icon:SetPoint("TOPLEFT", 3, -3)
                box.icon:SetPoint("BOTTOMRIGHT", -3, 3)
            end
        end
        do return end
        if not g then
            g = CreateFrame("Frame", "UbermocXPGap", MinimapCluster or UIParent)
            g:SetFrameStrata("MEDIUM")
            g.tex = g:CreateTexture(nil, "BACKGROUND")
            g.tex:SetAllPoints()
            g.tex:SetColorTexture(0, 0, 0, 1)
            UbermocUIAPI.xpGap = g
        end
        g:SetFrameLevel(xp:GetFrameLevel())
        g:ClearAllPoints()
        g:SetPoint("TOPLEFT", xp, "TOPRIGHT", -1, 0)
        g:SetPoint("BOTTOMRIGHT", box, "BOTTOMLEFT", 1, 0)
        g:Show()
    end

    function UbermocUIAPI.refreshStripText()
        local strip = UbermocUIAPI.stripFrame
        local c = UbermocUIDB and UbermocUIDB.mm and UbermocUIDB.mm.xp
        if not (strip and c) then return end
        local parts = {}
        if c.phase then
            local label, r, g, b = UbermocUIAPI.phaseInfo()
            parts[#parts + 1] = string.format("|cff%02x%02x%02x%s|r", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5), label)
        end
        if c.coords then parts[#parts + 1] = "|cffffffff" .. UbermocUIAPI.coordText() .. "|r" end
        local full = table.concat(parts, "  |cffffffff-|r  ")
        local oa = c.stripOutline
        if full == strip.ubLast and oa == strip.ubLastO then return end   -- unchanged since last time
        strip.ubLast, strip.ubLastO = full, oa
        strip.text:SetText(full)
        if strip.out then
            local plain = full:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
            local a = math.max(0, math.min(1, (c.stripOutline == nil and 100 or (c.stripOutline == true and 100 or (c.stripOutline == false and 0 or c.stripOutline))) / 100))
            for _, t in ipairs(strip.out) do
                t:SetText(plain)
                t:SetTextColor(0, 0, 0, a)
                t:SetShown(a > 0)
            end
        end
    end

    local function buildXP()
        local parent = MinimapCluster or UIParent
        local f = CreateFrame("Frame", "UbermocXPBar", parent)
        f:SetFrameStrata("MEDIUM")
        f:SetFrameLevel((Minimap and Minimap:GetFrameLevel() or 1) + 12)
        f:EnableMouse(true)
        f.edge = f:CreateTexture(nil, "BACKGROUND")
        f.edge:SetAllPoints()
        f.edge:SetColorTexture(0.45, 0.45, 0.5, 1)
        f.bg = f:CreateTexture(nil, "BORDER")
        f.bg:SetPoint("TOPLEFT", 1, -1)
        f.bg:SetPoint("BOTTOMRIGHT", -1, 1)
        f.bg:SetColorTexture(0.02, 0.03, 0.06, 0.95)
        f.fill = f:CreateTexture(nil, "ARTWORK")
        f.fill:SetPoint("TOPLEFT", 1, -1)
        f.fill:SetPoint("BOTTOMLEFT", 1, 1)
        f.fill:SetWidth(1)
        f.fill:SetColorTexture(0.08, 0.2, 0.6, 1)
        pcall(function()
            f.fill:SetColorTexture(1, 1, 1, 1)
            f.fill:SetGradient("HORIZONTAL", CreateColor(0.02, 0.07, 0.28, 1), CreateColor(0.12, 0.32, 0.8, 1))
        end)
        f.rest = f:CreateTexture(nil, "OVERLAY")
        f.rest:SetColorTexture(1, 1, 1, 0.95)
        f.rest:SetWidth(2)
        f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        f.text:SetPoint("CENTER", 0, 0)
        UbermocUIAPI.shade(f.text, STANDARD_TEXT_FONT, 10)
        f:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            local zone = GetMinimapZoneText and GetMinimapZoneText() or ""
            if zone ~= "" then GameTooltip:AddLine(zone, 1, 0.82, 0) end
            local cur, mx, rest = xpValues()
            if cur then
                GameTooltip:AddLine(string.format("Experience: %d / %d (%d%%)", cur, mx, math.floor(cur / mx * 100)), 1, 1, 1)
                if rest and rest > 0 then GameTooltip:AddLine(string.format("Rested: %d", rest), 0.6, 0.8, 1) end
            end
            GameTooltip:Show()
        end)
        f:SetScript("OnLeave", function() GameTooltip:Hide() end)
        return f
    end

    local function zoneButton()
        local zb = MinimapCluster and MinimapCluster.ZoneTextButton
        if type(zb) ~= "table" then zb = _G.MinimapZoneTextButton end
        if type(zb) == "table" and zb.SetAlpha then return zb end
        return nil
    end

    -- True when the mini experience bar sits inside the top of the map, in place of the zone name written there
    -- (the zone name is inside the map with the minimal look, or when chosen on the Zone Name tab).
    function UbermocUIAPI.xpInsideMap()
        local m = UbermocUIDB and UbermocUIDB.mm
        local c = m and m.xp
        return (c and c.on and not c.attach and m.zone and m.zone.inside and not atMaxLevel()) and true or false
    end
    -- True when the mini experience bar is on screen at all.
    function UbermocUIAPI.xpBarShown()
        local m = UbermocUIDB and UbermocUIDB.mm
        return (m and m.xp and m.xp.on and not atMaxLevel()) and true or false
    end

    local function updateXP()
        local c = UbermocUIDB.mm.xp
        local zb = zoneButton()
        local show = c.on and not atMaxLevel()
        if not show then
            if xpBar then xpBar:Hide() end
            pcall(UbermocUIAPI.updateStrip, nil)
            if zb then holdHidden(zb, (UbermocUIDB.mm.zone and UbermocUIDB.mm.zone.inside) and true or false) end
            return
        end
        if not xpBar then xpBar = buildXP() end
        xpBar:Show()   -- it may have been hidden earlier (turned off, or by the minimal look)
        xpBar:SetSize(c.w, c.h)
        -- Background colour and opacity are on its tab; the border on the Textures page (Minimap tab).
        local eOn, eSz, eR, eG, eB, eA = UbermocUIAPI.borderOf("xpBar")
        xpBar.edge:SetColorTexture(eR, eG, eB, eA)
        xpBar.edge:SetShown(eOn)
        xpBar.bg:SetColorTexture(c.bgR or 0.02, c.bgG or 0.03, c.bgB or 0.06, (c.bgA or 95) / 100)
        local inset = eOn and eSz or 0
        xpBar.bg:ClearAllPoints(); xpBar.bg:SetPoint("TOPLEFT", inset, -inset); xpBar.bg:SetPoint("BOTTOMRIGHT", -inset, inset)
        xpBar:ClearAllPoints()
        if c.attach and Minimap then
            -- On top of the map, outside it: as wide as the map and its border, or the width set on its tab.
            local bs = UbermocUIAPI.mapEdge()
            local w = (c.fullW ~= false) and ((Minimap:GetWidth() or c.w) + 2 * bs) or c.w
            xpBar:SetSize(w, c.h)
            if c.fullW ~= false then
                xpBar:SetPoint("BOTTOMLEFT", Minimap, "TOPLEFT", -bs + c.x, bs + c.y)
            else
                xpBar:SetPoint("BOTTOM", Minimap, "TOP", c.x, bs + c.y)
            end
        elseif UbermocUIAPI.xpInsideMap() and Minimap then
            -- where the zone name is written inside the map
            local w = math.min(c.w, math.max(40, (Minimap:GetWidth() or c.w) - 16))
            xpBar:SetSize(w, math.min(c.h, 16))
            xpBar:SetPoint("TOP", Minimap, "TOP", c.x, -20 + c.y)
        elseif zb then
            xpBar:SetPoint("CENTER", zb, "CENTER", c.x, c.y)
        elseif Minimap then
            xpBar:SetPoint("BOTTOM", Minimap, "TOP", c.x, c.y + 4)
        else
            xpBar:SetPoint("TOP", UIParent, "TOP", c.x, c.y - 20)
        end
        if zb then holdHidden(zb, (not c.attach) or (UbermocUIDB.mm.zone and UbermocUIDB.mm.zone.inside) and true or false) end
        xpBar.text:ClearAllPoints()
        -- With the addon box joined, its icon sits inside the right end of this bar; the fill and text use the rest.
        local joined = c.attach and c.reserve and UbermocUIDB.mm.box and UbermocUIDB.mm.box.on and (UbermocUIDB.mm.box.corner or "TOPRIGHT") == "TOPRIGHT" and true or false
        local tail = joined and (c.h or 0) or 0
        xpBar.text:SetPoint("CENTER", xpBar, "CENTER", 0, 0)   -- the middle of the whole bar, whether or not the box icon sits at its end
        pcall(UbermocUIAPI.updateStrip, xpBar)
        pcall(UbermocUIAPI.fillXPGap, xpBar)
        local cur, mx, rest = xpValues()
        local inner = math.max(1, (xpBar:GetWidth() or c.w) - 2 - tail)
        if cur then
            local frac = math.max(0, math.min(1, cur / mx))
            xpBar.fill:SetShown(frac > 0)
            xpBar.fill:SetWidth(math.max(1, inner * frac))
            xpBar.text:SetText(c.text and (math.floor(frac * 100) .. "%") or "")
            if c.rested and rest and rest > 0 then
                local rf = math.min(1, (cur + rest) / mx)
                xpBar.rest:ClearAllPoints()
                xpBar.rest:SetPoint("TOPLEFT", xpBar, "TOPLEFT", math.min(inner - 1, inner * rf), -1)
                xpBar.rest:SetPoint("BOTTOMLEFT", xpBar, "BOTTOMLEFT", math.min(inner - 1, inner * rf), 1)
                xpBar.rest:Show()
            else
                xpBar.rest:Hide()
            end
        else
            xpBar.fill:Hide()
            xpBar.rest:Hide()
            xpBar.text:SetText("")
        end
    end

    local function findCoords()
        for _, n in ipairs({ "MinimapCluster.MinimapContainer.PlayerCoords", "MinimapCluster.PlayerCoords", "Minimap.PlayerCoords" }) do
            local f = getFrame(n)
            if f then return f end
        end
        local parent = Minimap and Minimap.GetParent and Minimap:GetParent()
        if parent and parent.GetChildren then
            for _, ch in ipairs({ parent:GetChildren() }) do
                if type(ch) == "table" and ch.CoordText then return ch end
            end
        end
        return nil
    end

    -- Text sitting on top of the map is hard to read, so it gets an outline and a slight shadow (no backing).
    local function readable(frame, on)
        local list = {}
        local function grab(f)
            if type(f) ~= "table" or not f.GetRegions then return end
            for _, r in ipairs({ f:GetRegions() }) do
                if type(r) == "table" and r.GetObjectType and r:GetObjectType() == "FontString" then list[#list + 1] = r end
            end
        end
        grab(frame)
        if frame.GetChildren then for _, ch in ipairs({ frame:GetChildren() }) do grab(ch) end end
        for _, fs in ipairs(list) do
            if on then
                if not fs.ubermocFont then fs.ubermocFont = { fs:GetFont() } end
                local f, sz = fs:GetFont()
                if f then UbermocUIAPI.shade(fs, f, sz) else UbermocUIAPI.shade(fs) end
            elseif fs.ubermocFont then
                local o = fs.ubermocFont
                if o[1] then fs:SetFont(o[1], o[2], o[3]) end
                fs:SetShadowOffset(0, 0)
                fs.ubermocFont = nil
            end
        end
        if frame.ubermocBack then frame.ubermocBack:Hide() end
    end

    -- Moves a Blizzard frame to a spot inside the minimap, or puts it back where Blizzard had it.
    local function place(frame, c)
        if type(frame) ~= "table" or not frame.SetPoint or not Minimap then return end
        if not frame.ubermocMMPts then
            local pts = {}
            for i = 1, frame:GetNumPoints() do pts[i] = { frame:GetPoint(i) } end
            frame.ubermocMMPts = pts
            frame.ubermocMMLevel = { frame:GetFrameStrata(), frame:GetFrameLevel() }
            hooksecurefunc(frame, "SetPoint", function(self)
                local spec = self.ubermocMMSpec
                if self.ubermocMMBusy or not spec then return end
                self.ubermocMMBusy = true
                self:ClearAllPoints()
                self:SetPoint(spec.point, Minimap, spec.point, spec.x, spec.y)
                self.ubermocMMBusy = false
            end)
        end
        if c.move then
            local point = (c.v == "BOTTOM" and "BOTTOM" or "TOP") .. (c.h == "LEFT" and "LEFT" or (c.h == "RIGHT" and "RIGHT" or ""))
            frame.ubermocMMSpec = { point = point, x = c.x, y = c.y }
            frame.ubermocMMBusy = true
            frame:ClearAllPoints()
            frame:SetPoint(point, Minimap, point, c.x, c.y)
            frame.ubermocMMBusy = false
            pcall(frame.SetFrameStrata, frame, "MEDIUM")
            pcall(frame.SetFrameLevel, frame, Minimap:GetFrameLevel() + 12)
            frame.ubermocMMMoved = true
            pcall(readable, frame, true)
        elseif frame.ubermocMMMoved then
            frame.ubermocMMSpec = nil
            frame.ubermocMMBusy = true
            frame:ClearAllPoints()
            for _, pt in ipairs(frame.ubermocMMPts) do frame:SetPoint(pt[1], pt[2], pt[3], pt[4], pt[5]) end
            frame.ubermocMMBusy = false
            pcall(frame.SetFrameStrata, frame, frame.ubermocMMLevel[1])
            pcall(frame.SetFrameLevel, frame, frame.ubermocMMLevel[2])
            frame.ubermocMMMoved = nil
            pcall(readable, frame, false)
        end
    end

    -- Nudges a Blizzard frame by an offset from wherever Blizzard put it (mail icon, addon square, sun/moon).
    function UbermocUIAPI.nudge(frame, c)
        if type(frame) ~= "table" or not frame.SetPoint or not c then return end
        if type(frame.ubermocNudgePts) ~= "table" then
            local pts = {}
            for i = 1, tonumber(frame:GetNumPoints()) or 0 do pts[i] = { frame:GetPoint(i) } end
            frame.ubermocNudgePts = pts
            hooksecurefunc(frame, "SetPoint", function(self)
                if self.ubermocNudgeBusy or not self.ubermocNudge then return end
                self.ubermocNudgeBusy = true
                local off = self.ubermocNudge
                local fresh = {}
                for i = 1, tonumber(self:GetNumPoints()) or 0 do fresh[i] = { self:GetPoint(i) } end
                -- Blizzard moved it: remember its new home and re-apply our offset on top.
                self.ubermocNudgePts = fresh
                self:ClearAllPoints()
                for _, pt in ipairs(fresh) do self:SetPoint(pt[1], pt[2], pt[3], (pt[4] or 0) + off[1], (pt[5] or 0) + off[2]) end
                self.ubermocNudgeBusy = false
            end)
        end
        local x, y = c.x or 0, c.y or 0
        if InCombatLockdown() and frame.IsProtected and frame:IsProtected() then return end
        frame.ubermocNudgeBusy = true
        frame:ClearAllPoints()
        for _, pt in ipairs(frame.ubermocNudgePts) do
            frame:SetPoint(pt[1], pt[2], pt[3], (pt[4] or 0) + x, (pt[5] or 0) + y)
        end
        frame.ubermocNudgeBusy = false
        frame.ubermocNudge = (x ~= 0 or y ~= 0) and { x, y } or nil
    end

    local function zoneColor()
        local ok, pvp = pcall(GetZonePVPInfo or function() end)
        if not ok or isHidden(pvp) then pvp = nil end
        if pvp == "sanctuary" then return 0.41, 0.8, 0.94
        elseif pvp == "arena" or pvp == "hostile" then return 1, 0.1, 0.1
        elseif pvp == "friendly" then return 0.1, 1, 0.1
        elseif pvp == "contested" then return 1, 0.7, 0 end
        return 1, 0.9294, 0.7607
    end

    -- Zone name written inside the top of the map (instead of the game's header bar).
    function UbermocUIAPI.updateZoneLabel()
        local DB = UbermocUIDB
        local inside = DB and DB.mm and DB.mm.zone and DB.mm.zone.inside
        local f = UbermocUIAPI.zoneLabel
        if not inside or not Minimap or UbermocUIAPI.xpInsideMap() then   -- the experience bar takes its place
            if f then f:Hide() end
            return
        end
        if not f then
            f = CreateFrame("Frame", "UbermocZoneLabel", UIParent)
            f:SetFrameStrata("MEDIUM")
            -- The outline is eight copies of the text one pixel around it, so it can take any colour.
            f.out = {}
            for _, o in ipairs({ { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 }, { -1, -1 }, { 1, 1 }, { -1, 1 }, { 1, -1 } }) do
                local t = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
                t:SetPoint("CENTER", o[1], o[2])
                t:SetWordWrap(false)
                t:SetShadowOffset(0, 0)
                f.out[#f.out + 1] = t
            end
            f.text = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            f.text:SetPoint("CENTER")
            f.text:SetWordWrap(false)
            f.text:SetShadowOffset(0, 0)
            f:EnableMouse(false)
            UbermocUIAPI.zoneLabel = f
        end
        local w = math.max(40, (Minimap:GetWidth() or 140) - 10)
        f:SetFrameLevel((Minimap:GetFrameLevel() or 1) + 12)
        f:ClearAllPoints()
        f:SetPoint("TOP", Minimap, "TOP", 0, -20)
        f:SetSize(w, 16)
        local z = DB.mm.zone
        local font = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
        local txt = GetMinimapZoneText and GetMinimapZoneText() or ""
        if isHidden(txt) then txt = "" end
        for _, t in ipairs({ f.text, unpack(f.out) }) do
            t:SetWidth(w)
            pcall(t.SetFont, t, font, 12, "")
            t:SetText(txt)
        end
        if z.tr then f.text:SetTextColor(z.tr, z.tg or 1, z.tb or 1) else f.text:SetTextColor(zoneColor()) end
        local outOn = z.outline ~= false
        for _, t in ipairs(f.out) do
            t:SetTextColor(z.or_ or 0, z.og or 0, z.ob or 0, 1)
            t:SetShown(outOn)
        end
        f:SetAlpha(curEff.minizone or 1)
        f:Show()
    end

    -- The time written inside the bottom right of the map (replaces the game's clock button).
    function UbermocUIAPI.updateClockLabel()
        local c = UbermocUIDB and UbermocUIDB.mm and UbermocUIDB.mm.clock
        local own = c and c.own and Minimap
        local f = UbermocUIAPI.clockLabel
        local blizz = _G.TimeManagerClockButton
        if not own then
            if f then f:Hide() end
            if blizz then pcall(holdHidden, blizz, false) end
            return
        end
        if not f then
            f = CreateFrame("Frame", "UbermocClockText", Minimap)
            f:SetSize(90, 14)
            f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            f.text:SetPoint("RIGHT")
            UbermocUIAPI.shade(f.text, STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12)
            f.t = 1
            f:SetScript("OnUpdate", function(self, dt)
                self.t = self.t + dt
                if self.t < 1 then return end
                self.t = 0
                local s = date("%I:%M %p")
                self.text:SetText((s:gsub("^0", "")))
            end)
            UbermocUIAPI.clockLabel = f
        end
        f:SetFrameLevel(Minimap:GetFrameLevel() + 12)
        f:ClearAllPoints()
        local cc = c.corner or "BOTTOMRIGHT"
        if UbermocUIAPI.mapCorner then
            local pt, px, py = UbermocUIAPI.mapCorner(cc)
            f:SetPoint(pt, Minimap, pt, px + (c.ox or 0) + UbermocUIAPI.cornerShift(pt), py + (c.oy or 0))
        else
            f:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMRIGHT", -6, 4)
        end
        f.text:ClearAllPoints()
        f.text:SetPoint(cc:find("LEFT") and "LEFT" or (cc:find("RIGHT") and "RIGHT" or "CENTER"))
        local csz = tonumber(c.size) or 12
        if f.size ~= csz then
            f.size = csz
            f:SetSize(math.max(90, csz * 7), csz + 2)
            UbermocUIAPI.shade(f.text, STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", csz)
        end
        f.t = 1
        f:Show()
        if blizz then pcall(holdHidden, blizz, true) end
    end

    ------------------------------------------------------------------
    -- Mod container: addon minimap buttons collected into one flyout
    ------------------------------------------------------------------
    local boxBtn, flyout
    local boxed = {} -- button -> { parent, pts, strata, level }
    local boxList = {}

    local BOX_SKIP = { "^MinimapCluster", "^MinimapBackdrop", "^MinimapZoom", "^MinimapCompass", "^MinimapZone", "^Minimap$",
                       "^MiniMapTracking", "^MiniMapMail", "^MiniMapInstance", "^MiniMapLFG", "^MiniMapBattlefield",
                       "^MiniMapWorldMap", "^MiniMapRecord", "^GameTime", "^Queue", "^Expansion", "^AddonCompartment",
                       "^TimeManager", "^Ubermoc", "^LFG", "^Garrison", "^Zone", "^Stopwatch", "^Tooltip" }

    -- Real buttons, plus plain frames that act like one (a named frame with mouse scripts whose name says
    -- it is a minimap button), since some addons build theirs that way.
    function UbermocUIAPI.buttonLike(ch, name)
        local ot = ch:GetObjectType()
        if ot == "Button" or ot == "CheckButton" then return true end
        if ot ~= "Frame" or not name then return false end
        local l = name:lower()
        if not (l:find("minimap") or l:find("dialogueui") or l:find("^dui")) then return false end
        if ch.IsMouseEnabled and not ch:IsMouseEnabled() then return false end
        return (ch:GetScript("OnMouseUp") or ch:GetScript("OnMouseDown") or ch:GetScript("OnEnter")) and true or false
    end

    function UbermocUIAPI.collectableRaw(ch)
        if type(ch) ~= "table" or not ch.GetObjectType or not ch.GetName then return false end
        if ch.IsForbidden and ch:IsForbidden() then return false end
        local name = ch:GetName()
        if not name then return false end
        if name:find("^LibDBIcon10_") or name == "UbermocUIMinimapButton" then return true end
        for _, p in ipairs(BOX_SKIP) do if name:find(p) then return false end end
        if not UbermocUIAPI.buttonLike(ch, name) then return false end
        local w, h = ch:GetSize()
        if type(w) ~= "number" or type(h) ~= "number" or w > 64 or h > 64 or w < 12 then return false end
        return true
    end
    local function collectable(ch)
        local ok, r = pcall(UbermocUIAPI.collectableRaw, ch)
        return ok and r or false
    end

    -- Buttons that some addons parent elsewhere but anchor to the minimap.
    function UbermocUIAPI.anchoredToMap(ch)
        local n = tonumber(ch:GetNumPoints()) or 0
        for i = 1, n do
            local _, rel = ch:GetPoint(i)
            if rel and (rel == Minimap or rel == _G.MinimapBackdrop or rel == MinimapCluster) then return true end
        end
        return false
    end

    -- A small button sitting on or right next to the minimap, even if nothing is anchored to it by name.
    function UbermocUIAPI.nearMap(ch)
        if not Minimap or not Minimap.GetLeft then return false end
        local ml, mr, mb, mt = Minimap:GetLeft(), Minimap:GetRight(), Minimap:GetBottom(), Minimap:GetTop()
        local cx, cy = ch:GetCenter()
        if not (ml and mr and mb and mt and cx and cy) then return false end
        local pad = 34
        return cx > ml - pad and cx < mr + pad and cy > mb - pad and cy < mt + pad
    end

    function UbermocUIAPI.looseButton(ch)
        if type(ch) ~= "table" or not ch.GetObjectType or (ch.IsForbidden and ch:IsForbidden()) then return false end
        if not ch:IsShown() then return false end
        local name = ch:GetName()
        if not UbermocUIAPI.buttonLike(ch, name) then return false end
        if name then
            for _, p in ipairs(BOX_SKIP) do if name:find(p) then return false end end
            if name:find("^Ubermoc") or name:find("^Container") or name:find("^Chat") or name:find("^Compact") then return false end
        end
        local w, h = ch:GetSize()
        if type(w) ~= "number" or type(h) ~= "number" or w > 64 or h > 64 or w < 12 or h < 12 then return false end
        return UbermocUIAPI.nearMap(ch) or UbermocUIAPI.anchoredToMap(ch)
    end

    -- Some minimap buttons pin their own strata / level, which can leave them behind the container's
    -- background. Put every captured button above it.
    function UbermocUIAPI.raiseBoxed()
        if not flyout then return end
        for btn in pairs(boxed) do
            pcall(function()
                if btn.SetFixedFrameStrata then btn:SetFixedFrameStrata(false) end
                if btn.SetFixedFrameLevel then btn:SetFixedFrameLevel(false) end
                btn:SetFrameStrata(flyout:GetFrameStrata())
                btn:SetFrameLevel(flyout:GetFrameLevel() + 10)
                btn:SetAlpha(1)
            end)
        end
    end

    local function layoutFlyout()
        if not flyout then return end
        local c = UbermocUIDB.mm.box
        UbermocUIAPI.raiseBoxed()
        local list = {}
        for btn in pairs(boxed) do if btn:IsShown() then list[#list + 1] = btn end end
        table.sort(list, function(a, b) return (a:GetName() or "") < (b:GetName() or "") end)
        boxList = list
        local cell, pad = 36, 6
        local cols = math.max(1, math.min(c.cols, math.max(1, #list)))
        local rows = math.max(1, math.ceil(#list / cols))
        flyout:SetSize(pad * 2 + cols * cell - (cell - 32), pad * 2 + rows * cell - (cell - 32))
        for i, btn in ipairs(list) do
            local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
            btn.ubermocBoxSpec = { x = pad + col * cell, y = -pad - row * cell }
            btn.ubermocBoxBusy = true
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", flyout, "TOPLEFT", btn.ubermocBoxSpec.x, btn.ubermocBoxSpec.y)
            btn.ubermocBoxBusy = false
        end
    end

    local function capture(btn)
        if boxed[btn] then return end
        local pts = {}
        for i = 1, tonumber(btn:GetNumPoints()) or 0 do pts[i] = { btn:GetPoint(i) } end
        boxed[btn] = { parent = btn:GetParent(), pts = pts, strata = btn:GetFrameStrata(), level = btn:GetFrameLevel() }
        if not btn.ubermocBoxHooked then
            btn.ubermocBoxHooked = true
            hooksecurefunc(btn, "SetPoint", function(self)
                local spec = self.ubermocBoxSpec
                if not spec or self.ubermocBoxBusy or not boxed[self] or not flyout then return end
                self.ubermocBoxBusy = true
                self:ClearAllPoints()
                self:SetPoint("TOPLEFT", flyout, "TOPLEFT", spec.x, spec.y)
                self.ubermocBoxBusy = false
            end)
        end
        btn:SetParent(flyout)
        pcall(btn.SetFrameStrata, btn, "HIGH")
        pcall(btn.SetFrameLevel, btn, flyout:GetFrameLevel() + 5)
        pcall(btn.RegisterForDrag, btn) -- no dragging while inside the container
    end

    local function release(btn)
        local info = boxed[btn]
        if not info then return end
        boxed[btn] = nil
        btn.ubermocBoxSpec = nil
        btn.ubermocBoxBusy = true
        pcall(btn.SetParent, btn, info.parent)
        btn:ClearAllPoints()
        for _, pt in ipairs(info.pts) do btn:SetPoint(pt[1], pt[2], pt[3], pt[4], pt[5]) end
        btn.ubermocBoxBusy = false
        pcall(btn.SetFrameStrata, btn, info.strata)
        pcall(btn.SetFrameLevel, btn, info.level)
        if btn:GetName() and btn:GetName():find("^LibDBIcon10_") then pcall(btn.RegisterForDrag, btn, "LeftButton") end
    end

    local function scanBox()
        local c = UbermocUIDB and UbermocUIDB.mm and UbermocUIDB.mm.box
        if not c or not c.on or not flyout or not Minimap then return end
        local seen = {}
        local parents = { Minimap, _G.MinimapBackdrop, MinimapCluster }
        for _, par in ipairs(parents) do
            if type(par) == "table" and par.GetChildren then
                for _, ch in ipairs({ par:GetChildren() }) do
                    local forbidden = ch.IsForbidden and ch:IsForbidden()
                    if not forbidden and (collectable(ch) or (not (ch.GetName and ch:GetName()) and select(2, pcall(UbermocUIAPI.looseButton, ch)) == true)) then seen[ch] = true end
                end
            end
        end
        local lib = LibStub and LibStub("LibDBIcon-1.0", true)
        if lib and lib.GetButtonList then
            for _, n in ipairs(lib:GetButtonList()) do
                local b = _G["LibDBIcon10_" .. n]
                if type(b) == "table" then seen[b] = true end
            end
        end
        -- The game's addon list button (addons without a minimap button of their own,
        -- only appear in its list): it goes in the container too.
        local ac = _G.AddonCompartmentFrame
        if type(ac) == "table" and ac.IsShown and ac:IsShown() and not (ac.IsForbidden and ac:IsForbidden()) then seen[ac] = true end
        -- Anything on screen that is anchored to the minimap and looks like a minimap button.
        for _, par in ipairs({ UIParent }) do
            for _, ch in ipairs({ par:GetChildren() }) do
                if type(ch) == "table" and not seen[ch] and select(2, pcall(UbermocUIAPI.looseButton, ch)) == true then seen[ch] = true end
            end
        end
        -- Buttons made by addons that parent them somewhere unexpected: look them up by name (throttled).
        local now = GetTime()
        if not UbermocUIAPI.lastDeep or now - UbermocUIAPI.lastDeep > 4 then
            UbermocUIAPI.lastDeep = now
            for k, v in pairs(_G) do
                if type(k) == "string" and type(v) == "table" and not seen[v] and (k:find("^DialogueUI") or k:find("^DUI") or k:find("[Mm]inimap[%w_]*[Bb]utton") or k:find("[Bb]utton[%w_]*[Mm]inimap")) then
                    local ok, hit = pcall(function()
                        if not v.GetObjectType or (v.IsForbidden and v:IsForbidden()) or not v:IsShown() then return false end
                        if v:GetParent() == flyout then return false end
                        if k:find("^DialogueUI") or k:find("^DUI") then
                            if not (UbermocUIAPI.nearMap(v) or UbermocUIAPI.anchoredToMap(v)) then return false end
                        end
                        return collectable(v)
                    end)
                    if ok and hit then seen[v] = true end
                end
            end
        end
        for btn in pairs(seen) do pcall(capture, btn) end
        layoutFlyout()
    end

    -- /ubermoc box: lists every button the container looked at and why it was taken or skipped.
    function UbermocUI_BoxReport()
        local out = {}
        for _, par in ipairs({ Minimap, _G.MinimapBackdrop, MinimapCluster }) do
            if type(par) == "table" and par.GetChildren then
                local pn = par.GetName and par:GetName() or "?"
                for _, ch in ipairs({ par:GetChildren() }) do
                    local okn, n = pcall(function() return ch.GetName and not (ch.IsForbidden and ch:IsForbidden()) and ch:GetName() end)
                    if okn and n then
                        local w, h = ch:GetSize()
                        out[#out + 1] = string.format("%s > %s (%s %dx%d) %s%s", pn, n, ch:GetObjectType(), tonumber(w) or 0, tonumber(h) or 0,
                            collectable(ch) and "TAKEN" or "skipped", boxed[ch] and " [in box]" or "")
                    end
                end
            end
        end
        local near = 0
        for _, ch in ipairs({ UIParent:GetChildren() }) do
            local ok, hit = pcall(function()
                if ch.IsForbidden and ch:IsForbidden() then return false end
                return ch:IsShown() and (UbermocUIAPI.nearMap(ch) or UbermocUIAPI.anchoredToMap(ch))
            end)
            if ok and hit then
                local _, nm, ot, w, h = pcall(function() return 1, ch:GetName() or "(unnamed)", ch:GetObjectType(), ch:GetSize() end)
                local okl, loose = pcall(UbermocUIAPI.looseButton, ch)
                near = near + 1
                out[#out + 1] = string.format("near map: %s (%s %dx%d) %s%s", tostring(nm), tostring(ot), tonumber(w) or 0, tonumber(h) or 0,
                    (okl and loose) and "TAKEN" or "skipped", boxed[ch] and " [in box]" or "")
            end
        end
        out[#out + 1] = "frames near the minimap: " .. near
        for k, v in pairs(_G) do
            if type(k) == "string" and type(v) == "table" and (k:find("^DialogueUI") or k:find("^DUI")) and v.GetObjectType then
                local okd, line = pcall(function()
                    if v.IsForbidden and v:IsForbidden() then return nil end
                    local w, h = v:GetSize()
                    if (tonumber(w) or 99) > 80 or (tonumber(h) or 99) > 80 then return nil end
                    return string.format("dialogue frame: %s (%s %dx%d) shown=%s %s", k, v:GetObjectType(), tonumber(w) or 0, tonumber(h) or 0,
                        tostring(v:IsShown()), collectable(v) and "TAKEN" or "skipped")
                end)
                if okd and line then out[#out + 1] = line end
            end
        end
        local nb = 0
        for btn in pairs(boxed) do
            nb = nb + 1
            local okb, line = pcall(function()
                local w, h = btn:GetSize()
                return string.format("in box: %s (%dx%d) shown=%s visible=%s alpha=%.2f at %d,%d", btn:GetName() or "(unnamed)", tonumber(w) or 0, tonumber(h) or 0,
                    tostring(btn:IsShown()), tostring(btn:IsVisible()), btn:GetAlpha() or 0, math.floor(btn:GetLeft() or -1), math.floor(btn:GetBottom() or -1))
            end)
            out[#out + 1] = okb and line or "in box: (error)"
        end
        out[#out + 1] = "captured buttons: " .. nb .. ", on display: " .. #boxList
        if flyout then
            out[#out + 1] = string.format("container: open=%s size=%dx%d at %d,%d alpha=%.2f", tostring(flyout:IsShown()), math.floor(flyout:GetWidth()), math.floor(flyout:GetHeight()),
                math.floor(flyout:GetLeft() or -1), math.floor(flyout:GetBottom() or -1), flyout:GetAlpha() or 0)
        end
        local lib = LibStub and LibStub("LibDBIcon-1.0", true)
        if lib and lib.GetButtonList then
            local names = lib:GetButtonList()
            out[#out + 1] = "Minimap library buttons: " .. #names .. " (" .. table.concat(names, ", ") .. ")"
        else
            out[#out + 1] = "Minimap library not found"
        end
        return out
    end

    local function flyoutAnchor()
        local c = UbermocUIDB.mm.box
        flyout:ClearAllPoints()
        flyout:SetClampedToScreen(true)
        local d = c.dir
        -- Open the other way when there is no room on that side of the screen.
        local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
        local bl, br, bb, bt = boxBtn:GetLeft(), boxBtn:GetRight(), boxBtn:GetBottom(), boxBtn:GetTop()
        local fw, fh = flyout:GetWidth(), flyout:GetHeight()
        if bl and br and bb and bt then
            if d == "RIGHT" and br + fw + 8 > sw then d = "LEFT"
            elseif d == "LEFT" and bl - fw - 8 < 0 then d = "RIGHT"
            elseif d == "ABOVE" and bt + fh + 8 > sh then d = "BELOW"
            elseif d == "BELOW" and bb - fh - 8 < 0 then d = "ABOVE" end
        end
        if d == "RIGHT" then flyout:SetPoint("TOPLEFT", boxBtn, "TOPRIGHT", 4, 0)
        elseif d == "ABOVE" then flyout:SetPoint("BOTTOM", boxBtn, "TOP", 0, 4)
        elseif d == "BELOW" then flyout:SetPoint("TOP", boxBtn, "BOTTOM", 0, -4)
        else flyout:SetPoint("TOPRIGHT", boxBtn, "TOPLEFT", -4, 0) end
    end

    local function toggleFlyout(force)
        if not flyout then return end
        local open = force
        if open == nil then open = not flyout:IsShown() end
        if open then
            scanBox()
            flyoutAnchor()
            flyout.t = 0
            flyout.idle = 0
            flyout:SetAlpha(0)
            flyout:Show()
            UbermocUIAPI.raiseBoxed()
        else
            flyout:Hide()
        end
    end

    local function updateBox()
        local c = UbermocUIDB.mm.box
        if not c.on or not Minimap then
            if boxBtn then boxBtn:Hide() end
            if flyout then flyout:Hide() end
            for btn in pairs(boxed) do release(btn) end
            pcall(updateXP)   -- the experience bar takes back the space the box used
            return
        end
        if not boxBtn then
            local b = CreateFrame("Button", "UbermocModBox", MinimapCluster or UIParent)
            b:SetFrameStrata("MEDIUM")
            b:SetFrameLevel(Minimap:GetFrameLevel() + 14)
            b.edge = b:CreateTexture(nil, "BACKGROUND")
            b.edge:SetAllPoints()
            b.edge:SetColorTexture(0.45, 0.45, 0.5, 1)
            b.bg = b:CreateTexture(nil, "BORDER")
            b.bg:SetPoint("TOPLEFT", 1, -1)
            b.bg:SetPoint("BOTTOMRIGHT", -1, 1)
            b.bg:SetColorTexture(0.02, 0.03, 0.06, 0.95)
            b.icon = b:CreateTexture(nil, "ARTWORK")
            b.icon:SetPoint("TOPLEFT", 3, -3)
            b.icon:SetPoint("BOTTOMRIGHT", -3, 3)
            b.icon:SetTexture("Interface\\Icons\\INV_Misc_Bag_08")
            b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)   -- cuts off the light rim drawn into the icon art
            b.hl = b:CreateTexture(nil, "HIGHLIGHT")
            b.hl:SetAllPoints()
            b.hl:SetColorTexture(1, 1, 1, 0.15)
            b:SetScript("OnClick", function() toggleFlyout() end)
            b:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_LEFT")
                GameTooltip:AddLine("Addon buttons", 1, 0.82, 0)
                GameTooltip:AddLine(#boxList > 0 and (#boxList .. " collected. Click to open.") or "Click to open.", 1, 1, 1)
                GameTooltip:Show()
            end)
            b:SetScript("OnLeave", function() GameTooltip:Hide() end)
            boxBtn = b

            local f = CreateFrame("Frame", "UbermocModFlyout", MinimapCluster or UIParent)
            f:SetFrameStrata("HIGH")
            f:EnableMouse(true)
            f.edge = f:CreateTexture(nil, "BACKGROUND")
            f.edge:SetAllPoints()
            f.edge:SetColorTexture(0.45, 0.45, 0.5, 1)
            f.bg = f:CreateTexture(nil, "BORDER")
            f.bg:SetPoint("TOPLEFT", 1, -1)
            f.bg:SetPoint("BOTTOMRIGHT", -1, 1)
            f.bg:SetColorTexture(0.02, 0.03, 0.06, 0.95)
            f:Hide()
            f:SetScript("OnUpdate", function(self, dt)
                -- Quick fade in, and close when the mouse has been away for a moment.
                self.t = math.min(1, (self.t or 0) + dt / 0.15)
                self:SetAlpha(self.t)
                if self:IsMouseOver() or (boxBtn and boxBtn:IsMouseOver()) then
                    self.idle = 0
                else
                    self.idle = (self.idle or 0) + dt
                    if self.idle > 1.5 then self:Hide() end
                end
            end)
            flyout = f
        end
        do
            -- Border from the Textures page (Minimap tab).
            local eOn, eSz, eR, eG, eB, eA = UbermocUIAPI.borderOf("addonBox")
            boxBtn.edge:SetColorTexture(eR, eG, eB, eA)
            boxBtn.edge:SetShown(eOn)
            if boxBtn.bg then
                local i = eOn and eSz or 0
                boxBtn.bg:ClearAllPoints(); boxBtn.bg:SetPoint("TOPLEFT", i, -i); boxBtn.bg:SetPoint("BOTTOMRIGHT", -i, i)
                boxBtn.bg:Show()
            end
        end
        if boxBtn.ubermocRound ~= (c.round and true or false) then
            boxBtn.ubermocRound = c.round and true or false
            pcall(function()
                if not boxBtn.mask then
                    boxBtn.mask = boxBtn:CreateMaskTexture()
                    boxBtn.mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
                    boxBtn.mask:SetAllPoints(boxBtn)
                end
                for _, t in ipairs({ boxBtn.edge, boxBtn.bg, boxBtn.icon, boxBtn.hl }) do
                    if boxBtn.ubermocRound then t:AddMaskTexture(boxBtn.mask) else t:RemoveMaskTexture(boxBtn.mask) end
                end
            end)
        end
        boxBtn:SetSize(c.size, c.size)
        boxBtn:ClearAllPoints()
        do
            H.boxInsideMigrate(c)
            local corner = c.corner or "TOPRIGHT"
            if not c.dirV2 then
                -- One time: the nudge used to run backwards in the left and bottom corners; keep the box where it was.
                c.dirV2 = true
                if corner ~= "TOPRIGHT" then
                    if corner:find("LEFT") then c.x = 3 - ((c.x or 3) - 3) end
                    if corner:find("BOTTOM") then c.y = 21 - ((c.y or 21) - 21) end
                end
            end
            if c.inside then
                local mini = UbermocUIDB.mm and UbermocUIDB.mm.mini
                local round
                if mini and mini.on then round = mini.shape == "round" else round = not UbermocUIDB.squareMinimap end
                local sx, sy = H.boxInsideSpot(Minimap and Minimap:GetWidth(), round, corner)
                boxBtn:SetPoint(corner, Minimap, corner, sx + (c.x or 0), sy + (c.y or 0))   -- positive is right and up
            elseif corner == "TOPRIGHT" then
                boxBtn:SetPoint(corner, Minimap, corner, c.x, c.y)
            else
                -- Other corners: tucked just inside that corner of the map; the sliders nudge it from there.
                local L, B = corner:find("LEFT") and true, corner:find("BOTTOM") and true
                local dx, dy = (c.x or 3) - 3, (c.y or 21) - 21
                -- Left / right and up / down move it the same way in every corner (positive is right and up).
                boxBtn:SetPoint(corner, Minimap, corner, (L and 4 or -4) + dx, (B and 4 or -4) + dy)
            end
        end
        boxBtn:Show()
        pcall(UbermocUIAPI.fillXPGap, xpBar)
        pcall(updateXP)
        scanBox()
        C_Timer.After(3, function() pcall(scanBox) end)
    end

    -- Square minimap: put addon buttons exactly on the square's edge, following their own angle.
    local function snapButton(b)
        if not UbermocUIDB.squareMinimap or boxed[b] or b.ubermocSnapBusy or not Minimap then return end
        local db = b.db
        local ang = db and tonumber(db.minimapPos)
        if not ang or (db.lockalign) then return end
        local a = math.rad(ang)
        local c, s = math.cos(a), math.sin(a)
        local m = math.max(math.abs(c), math.abs(s))
        if m == 0 then return end
        c, s = c / m, s / m
        local r = (Minimap:GetWidth() or 140) / 2
        b.ubermocSnapBusy = true
        b:ClearAllPoints()
        b:SetPoint("CENTER", Minimap, "CENTER", c * r, s * r)
        b.ubermocSnapBusy = false
    end

    local function alignAddonButtons()
        local lib = LibStub and LibStub("LibDBIcon-1.0", true)
        if not (lib and lib.GetButtonList) then return end
        for _, n in ipairs(lib:GetButtonList()) do
            local b = _G["LibDBIcon10_" .. n]
            if type(b) == "table" and b.SetPoint then
                if not b.ubermocSnapHooked then
                    b.ubermocSnapHooked = true
                    hooksecurefunc(b, "SetPoint", function(self) snapButton(self) end)
                end
                pcall(snapButton, b)
            end
        end
    end
    mmAlign = alignAddonButtons

    ------------------------------------------------------------------
    -- Info bar: gold, bag space and durability, on any side of the minimap
    ------------------------------------------------------------------
    local infoBar

    function UbermocUIAPI.mmGroupDigits(n)
        local s = tostring(math.floor(n))
        local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
        return (out:gsub("^,", ""))
    end

    -- Money: gold only, gold and silver, or everything. Lower coins show on their own when there is no gold.
    function UbermocUIAPI.mmMoneyText()
        local m = GetMoney and GetMoney() or 0
        local g = math.floor(m / 10000)
        local sv = math.floor((m % 10000) / 100)
        local cp = m % 100
        local mode = (UbermocUIDB and UbermocUIDB.mm and UbermocUIDB.mm.info.money) or "GS"
        local parts = {}
        if g > 0 then parts[#parts + 1] = "|cffffd100" .. UbermocUIAPI.mmGroupDigits(g) .. "g|r" end
        if mode == "G" then
            if g == 0 then parts[#parts + 1] = (sv > 0) and ("|cffc7c7cf" .. sv .. "s|r") or ("|cffeda55f" .. cp .. "c|r") end
        elseif mode == "GS" then
            if g > 0 or sv > 0 then parts[#parts + 1] = "|cffc7c7cf" .. sv .. "s|r"
            else parts[#parts + 1] = "|cffeda55f" .. cp .. "c|r" end
        else
            if g > 0 or sv > 0 then parts[#parts + 1] = "|cffc7c7cf" .. sv .. "s|r" end
            parts[#parts + 1] = "|cffeda55f" .. cp .. "c|r"
        end
        return table.concat(parts, " ")
    end

    function UbermocUIAPI.mmBagValues()
        local free, total = 0, 0
        for bag = 0, (NUM_BAG_SLOTS or 4) do
            local okT, slots = pcall(C_Container.GetContainerNumSlots, bag)
            local okF, fr = pcall(C_Container.GetContainerNumFreeSlots, bag)
            if okT and okF and type(slots) == "number" and type(fr) == "number" then
                total = total + slots
                free = free + fr
            end
        end
        return total - free, total
    end

    function UbermocUIAPI.mmDuraValues()
        local cur, max, low, lowSlot = 0, 0, 100, nil
        for slot = 1, 19 do
            if slot ~= 4 then
                local ok, c, m = pcall(GetInventoryItemDurability, slot)
                if ok and type(c) == "number" and type(m) == "number" and m > 0 then
                    cur, max = cur + c, max + m
                    if c / m * 100 < low then low = c / m * 100; lowSlot = slot end
                end
            end
        end
        if max == 0 then return 100, 100 end
        return cur / max * 100, low
    end

    local function ensureInfoItem(bar, key, icon)
        local it = bar[key]
        if type(it) == "table" then return it end
        it = CreateFrame("Frame", nil, bar)
        it:EnableMouse(true)
        it.icon = it:CreateTexture(nil, "ARTWORK")
        it.icon:SetSize(16, 16)
        it.icon:SetPoint("LEFT", 0, 0)
        it.icon:SetTexture(icon)
        it.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        it.text = it:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        it.text:SetPoint("LEFT", it.icon, "RIGHT", 4, 0)
        UbermocUIAPI.shade(it.text)
        it:SetScript("OnLeave", function() GameTooltip:Hide() end)
        bar[key] = it
        return it
    end

    local function updateInfo()
        local c = UbermocUIDB.mm.info
        if not c.on or not Minimap then
            if infoBar then infoBar:Hide() end
            return
        end
        if not infoBar then
            local f = CreateFrame("Frame", "UbermocInfoBar", MinimapCluster or UIParent)
            f:SetFrameStrata("MEDIUM")
            f:SetFrameLevel(Minimap:GetFrameLevel() + 10)
            f.bg = f:CreateTexture(nil, "BACKGROUND")
            f.bg:SetAllPoints()
            f.bg:SetColorTexture(0, 0, 0, 0.92)
            infoBar = f
        end
        local bar = infoBar
        do
            local br, bg2, bb, ba = 0, 0, 0, 1
            if UbermocUIAPI.mmBack then br, bg2, bb, ba = UbermocUIAPI.mmBack() end
            bar.bg:SetColorTexture(br, bg2, bb, math.min(1, (c.bg or 70) / 100) * ba)
        end
        local bs = UbermocUIAPI.mapEdge()
        local side, thick = c.side, c.thick
        bar:ClearAllPoints()
        local mw, mh = Minimap:GetWidth(), Minimap:GetHeight()
        if side == "TOP" then
            bar:SetPoint("BOTTOMLEFT", Minimap, "TOPLEFT", -bs + c.x, bs + c.y)
            bar:SetSize(mw + 2 * bs, thick)
        elseif side == "LEFT" then
            bar:SetPoint("TOPRIGHT", Minimap, "TOPLEFT", -bs + c.x, c.y)
            bar:SetSize(thick + 56, mh)
        elseif side == "RIGHT" then
            bar:SetPoint("TOPLEFT", Minimap, "TOPRIGHT", bs + c.x, c.y)
            bar:SetSize(thick + 56, mh)
        else
            bar:SetPoint("TOPLEFT", Minimap, "BOTTOMLEFT", -bs + c.x, -bs + c.y)
            bar:SetSize(mw + 2 * bs, thick)
        end

        local items = {}
        if c.gold then
            local it = ensureInfoItem(bar, "gold", "Interface\\Icons\\INV_Misc_Coin_01")
            it.text:SetText(UbermocUIAPI.mmMoneyText())
            it.text:SetTextColor(1, 1, 1)
            it.tip = function(self)
                GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
                GameTooltip:AddLine("Gold", 1, 0.82, 0)
                local m = GetMoney and GetMoney() or 0
                GameTooltip:AddLine(string.format("|cffffd100%sg|r |cffc7c7cf%ds|r |cffeda55f%dc|r", UbermocUIAPI.mmGroupDigits(math.floor(m / 10000)), math.floor((m % 10000) / 100), m % 100), 1, 1, 1)
                GameTooltip:Show()
            end
            items[#items + 1] = it
        elseif type(bar.gold) == "table" then bar.gold:Hide() end
        if c.bags then
            local it = ensureInfoItem(bar, "bags", "Interface\\Icons\\INV_Misc_Bag_08")
            local used, total = UbermocUIAPI.mmBagValues()
            it.text:SetText(used .. "/" .. total)
            if total > 0 and used / total >= 0.9 then it.text:SetTextColor(1, 0.3, 0.3)
            elseif total > 0 and used / total >= 0.75 then it.text:SetTextColor(1, 0.8, 0.2)
            else it.text:SetTextColor(1, 1, 1) end
            it.tip = function(self)
                GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
                GameTooltip:AddLine("Bag space", 1, 0.82, 0)
                GameTooltip:AddLine((total - used) .. " free of " .. total, 1, 1, 1)
                GameTooltip:Show()
            end
            items[#items + 1] = it
        elseif type(bar.bags) == "table" then bar.bags:Hide() end
        if c.dura then
            local it = ensureInfoItem(bar, "dura", "Interface\\Icons\\Trade_BlackSmithing")
            local avg, low = UbermocUIAPI.mmDuraValues()
            it.text:SetText(string.format("%d%%", math.floor(avg + 0.5)))
            if avg < 25 then it.text:SetTextColor(1, 0.3, 0.3)
            elseif avg < 50 then it.text:SetTextColor(1, 0.8, 0.2)
            else it.text:SetTextColor(0.4, 1, 0.4) end
            it.tip = function(self)
                GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
                GameTooltip:AddLine("Durability", 1, 0.82, 0)
                GameTooltip:AddLine(string.format("Average %d%%, lowest %d%%", math.floor(avg + 0.5), math.floor(low + 0.5)), 1, 1, 1)
                GameTooltip:Show()
            end
            items[#items + 1] = it
        elseif type(bar.dura) == "table" then bar.dura:Hide() end

        local n = #items
        local vertical = (side == "LEFT" or side == "RIGHT")
        -- Round map, above or below it: the items follow the curve of the map instead of a straight bar.
        local arc = (not UbermocUIDB.squareMinimap) and not vertical and n > 0
        local OFF = { gold = { c.gx or 0, c.gy or 0 }, bags = { c.bx or 0, c.by or 0 }, dura = { c.dx or 0, c.dy or 0 } }
        local fpath = GameFontHighlightSmall and GameFontHighlightSmall:GetFont()
        local fsz = c.fs or 12
        local isz = math.max(8, c.isize or 16)
        if fpath then for _, it in ipairs(items) do UbermocUIAPI.shade(it.text, fpath, fsz) end end
        local function textW(it) return math.ceil(it.text:GetStringWidth() or 0) end
        if vertical and n > 0 then
            -- Same idea as below the map: the bar runs the map's full height, the first item at the top,
            -- the last at the bottom, the middle one centred; text shrinks when the rows get too short.
            local h = mh + 2 * bs
            while fpath and fsz > 8 and (isz + 2 + fsz) * n + 8 * (n + 1) > h do
                fsz = fsz - 1
                for _, it in ipairs(items) do UbermocUIAPI.shade(it.text, fpath, fsz) end
            end
            local maxW = 0
            for _, it in ipairs(items) do maxW = math.max(maxW, textW(it)) end
            local w = math.max(thick, isz + 8, maxW + 8)
            bar:ClearAllPoints()
            if side == "LEFT" then bar:SetPoint("TOPRIGHT", Minimap, "TOPLEFT", -bs + c.x, bs + c.y)
            else bar:SetPoint("TOPLEFT", Minimap, "TOPRIGHT", bs + c.x, bs + c.y) end
            bar:SetSize(w, h)
        elseif not arc and n > 0 and fpath then
            -- Shrink the text until every item fits its share of the bar.
            local avail = bar:GetWidth() / n - 14 - isz - 4
            while fsz > 8 do
                local fits = true
                for _, it in ipairs(items) do
                    UbermocUIAPI.shade(it.text, fpath, fsz)
                    if textW(it) > avail then fits = false end
                end
                if fits then break end
                fsz = fsz - 1
            end
        end
        bar.bg:SetShown(not arc)
        -- Arc: work out each item's size first, then the angle each one needs so neighbours never touch.
        local R, angles = 0, {}
        if arc then
            R = math.max(mw, mh) / 2 + bs + 4
            local ws, total = {}, 0
            for i, it in ipairs(items) do ws[i] = math.max(isz, textW(it)) + 6 end
            local itemH = isz + 2 + fsz
            local r = R + itemH / 2
            for i = 1, n do
                if i > 1 then total = total + ((ws[i - 1] + ws[i]) / 2 + 6) / r end
                angles[i] = total
            end
            local mid = (side == "TOP") and (math.pi / 2) or (-math.pi / 2)
            local dir = (side == "TOP") and -1 or 1 -- left to right either way
            for i = 1, n do angles[i] = mid + dir * (angles[i] - total / 2) end
            R = r
        end
        for i, it in ipairs(items) do
            it:ClearAllPoints()
            it:SetScript("OnEnter", it.tip)
            it.icon:SetSize(isz, isz)
            it.icon:ClearAllPoints()
            it.text:ClearAllPoints()
            local key = (it == bar.gold and "gold") or (it == bar.bags and "bags") or "dura"
            local ox, oy = OFF[key][1], OFF[key][2]
            if vertical or arc then
                -- Icon on top, text under it.
                it.icon:SetPoint("TOP", it, "TOP", 0, 0)
                it.text:SetPoint("TOP", it.icon, "BOTTOM", 0, -2)
                it.text:SetJustifyH("CENTER")
                it:SetSize(math.max(isz, textW(it)) + 4, isz + 2 + fsz)
            else
                it.icon:SetPoint("LEFT", it, "LEFT", 0, 0)
                it.text:SetPoint("LEFT", it.icon, "RIGHT", 4, 0)
                it.text:SetJustifyH("LEFT")
                it:SetSize(isz + 4 + textW(it), math.max(isz, bar:GetHeight()))
            end
            if arc then
                local a = angles[i]
                it:SetPoint("CENTER", Minimap, "CENTER", R * math.cos(a) + c.x + ox, R * math.sin(a) + c.y + oy)
            elseif vertical then
                if n == 1 or (n == 3 and i == 2) then it:SetPoint("CENTER", bar, "CENTER", ox, oy)
                elseif i == 1 then it:SetPoint("TOP", bar, "TOP", ox, -6 + oy)
                else it:SetPoint("BOTTOM", bar, "BOTTOM", ox, 6 + oy) end
            else
                -- First item flush with the left edge, last flush with the right edge, the one between centred.
                if n == 1 or (n == 3 and i == 2) then it:SetPoint("CENTER", bar, "CENTER", ox, oy)
                elseif i == 1 then it:SetPoint("LEFT", bar, "LEFT", ox, oy)
                else it:SetPoint("RIGHT", bar, "RIGHT", ox, oy) end
            end
            it:Show()
            UbermocUIAPI.outline(it.text, c.outline == nil and 40 or c.outline)
        end
        bar:Show()
    end

    -- FPS and latency inside the map, bottom left.
    local perfFrame
    local function updatePerf()
        local on = UbermocUIDB.mm.perf.on and Minimap
        if not on then
            if perfFrame then perfFrame:Hide() end
            return
        end
        if not perfFrame then
            local f = CreateFrame("Frame", "UbermocPerfText", Minimap)
            f:SetFrameLevel(Minimap:GetFrameLevel() + 12)
            f:SetSize(120, 14)
            f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            f.text:SetPoint("LEFT")
            UbermocUIAPI.shade(f.text)
            f.t = 0
            f:SetScript("OnUpdate", function(self, dt)
                self.t = self.t + dt
                if self.t < 1 then return end
                self.t = 0
                local fps = math.floor((GetFramerate and GetFramerate() or 0) + 0.5)
                local _, _, home = GetNetStats()
                home = home or 0
                if fps ~= self.lastFps or home ~= self.lastMs then
                    self.lastFps, self.lastMs = fps, home
                    self.text:SetFormattedText("%d FPS | %d MS", fps, home)
                end
            end)
            perfFrame = f
        end
        perfFrame:ClearAllPoints()
        local pc = UbermocUIDB.mm.perf.corner or "BOTTOMLEFT"
        if UbermocUIAPI.mapCorner then
            local pt, px, py = UbermocUIAPI.mapCorner(pc)
            local pf = UbermocUIDB.mm.perf
            perfFrame:SetPoint(pt, Minimap, pt, px + (pf.ox or 0) + UbermocUIAPI.cornerShift(pt), py + (pf.oy or 0))
        else
            perfFrame:SetPoint("BOTTOMLEFT", Minimap, "BOTTOMLEFT", 6, 4)
        end
        perfFrame.text:ClearAllPoints()
        perfFrame.text:SetPoint(pc:find("RIGHT") and "RIGHT" or (pc:find("LEFT") and "LEFT" or "CENTER"))
        local psz = tonumber(UbermocUIDB.mm.perf.size) or 11
        if perfFrame.size ~= psz then
            perfFrame.size = psz
            perfFrame:SetSize(math.max(120, psz * 10), psz + 2)
            UbermocUIAPI.shade(perfFrame.text, STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", psz)
        end
        perfFrame:Show()
    end

    -- N / E / S / W written on the edge of the map. They stay put, or turn with the map when it rotates.
    function UbermocUIAPI.updateCompass()
        local compass = UbermocUIAPI.compassFrame
        local c = UbermocUIDB.mm.compass
        if not (c and c.on and Minimap) then
            if compass then compass:Hide() end
            return
        end
        if not compass then
            local f = CreateFrame("Frame", "UbermocCompass", Minimap)
            f:SetAllPoints(Minimap)
            f:SetFrameLevel(Minimap:GetFrameLevel() + 8)
            f.fs = {}
            for i, k in ipairs({ "N", "E", "S", "W" }) do
                local t = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                t:SetText(k)
                UbermocUIAPI.shade(t)
                if k == "N" then t:SetTextColor(1, 0.3, 0.3) else t:SetTextColor(1, 1, 1) end
                f.fs[i] = t
            end
            f.acc = 0
            f:SetScript("OnUpdate", function(self, dt)
                self.acc = self.acc + dt
                if self.acc < 0.05 then return end
                self.acc = 0
                -- the map-turning setting is read once a second, not 20 times
                self.rotT = (self.rotT or 1) + 0.05
                if self.rotT >= 1 then
                    self.rotT = 0
                    local okc, cv = pcall(GetCVar, "rotateMinimap")
                    self.rot = okc and cv == "1" or false
                end
                local rot = self.rot
                -- Not turning with the map: the letters only need placing again when the map changes size.
                local halfNow = (Minimap:GetWidth() or 140) / 2 - 8
                local sqNow = UbermocUIDB.squareMinimap and true or false
                self.re = (self.re or 0) + 0.05
                if self.re >= 1 then self.re = 0; self.placed = false end   -- text widths change (FPS digits): check again
                if not rot and self.placed and self.lastHalf == halfNow and self.lastSq == sqNow then return end
                self.placed, self.lastHalf, self.lastSq = true, halfNow, sqNow
                local fa = 0
                if rot and GetPlayerFacing then
                    local ok, v = pcall(GetPlayerFacing)
                    if ok and type(v) == "number" and not isHidden(v) then fa = v end
                end
                local half = (Minimap:GetWidth() or 140) / 2 - 8
                local sn, cs = math.sin(fa), math.cos(fa)
                for i = 1, 4 do
                    local dx, dy
                    if i == 1 then dx, dy = sn, cs elseif i == 2 then dx, dy = cs, -sn
                    elseif i == 3 then dx, dy = -sn, -cs else dx, dy = -cs, sn end
                    local t
                    if UbermocUIDB.squareMinimap then
                        t = half / math.max(math.abs(dx), math.abs(dy))
                    else
                        t = half
                    end
                    -- Step the letter in toward the middle until it is clear of the text and the addon box.
                    local fsI = self.fs[i]
                    local hw, hh = (fsI:GetStringWidth() or 8) / 2 + 2, (fsI:GetStringHeight() or 10) / 2 + 1
                    local x, y = dx * t, dy * t
                    if not rot then
                        local ml, mb = Minimap:GetLeft(), Minimap:GetBottom()
                        local mw, mh = Minimap:GetWidth() or 140, Minimap:GetHeight() or 140
                        if ml and mb then
                            for _ = 1, 20 do
                                local cx, cy = ml + mw / 2 + x, mb + mh / 2 + y
                                if not UbermocUIAPI.mapTextHit(cx - hw, cy - hh, cx + hw, cy + hh) then break end
                                x, y = x - dx * 2, y - dy * 2
                            end
                        end
                    end
                    fsI:ClearAllPoints()
                    fsI:SetPoint("CENTER", Minimap, "CENTER", x, y)
                end
            end)
            UbermocUIAPI.compassFrame = f
            compass = f
        end
        compass:Show()
    end

    mmApply = function()
        local DB = UbermocUIDB
        if not DB or not DB.mm or not DB.mm.xp then return end
        if UbermocUIAPI.compassFrame then UbermocUIAPI.compassFrame.placed = false end   -- texts may have moved
        pcall(place, _G.TimeManagerClockButton, DB.mm.clock)
        pcall(place, findCoords(), DB.mm.coords)
        -- Zone name inside the top of the map (the header bar behind it is hidden).
        do
            local zc = DB.mm.zone
            local zb = zoneButton()
            local inside = zc and zc.inside
            if zb then
                pcall(place, zb, { move = false })
                if inside then pcall(holdHidden, zb, true) end
            end
            for _, n in ipairs({ "MinimapCluster.BorderTop", "MinimapCluster.Background", "MinimapCluster.Header", "MinimapBorderTop" }) do
                local f = getFrame(n)
                if f then pcall(holdHidden, f, inside and true or false) end
            end
        end
        local dockedIcons = DB.mm.xp.on and DB.mm.xp.icons and DB.mm.xp.attach
        if not dockedIcons then pcall(UbermocUIAPI.nudge, getFrame("MinimapCluster.IndicatorFrame"), DB.mm.mail) end
        if not (_G.AddonCompartmentFrame and _G.AddonCompartmentFrame:GetParent() == _G.UbermocModFlyout) then
            pcall(UbermocUIAPI.nudge, _G.AddonCompartmentFrame, DB.mm.addons)
        end
        pcall(updateXP)
        if UbermocUIAPI.syncGameXP then pcall(UbermocUIAPI.syncGameXP) end
        pcall(UbermocUIAPI.updateZoneLabel)
        pcall(UbermocUIAPI.updateClockLabel)
        pcall(updateBox)
        pcall(updateInfo)
        pcall(updatePerf)
        pcall(UbermocUIAPI.updateCompass)
        if DB.squareMinimap and UbermocUIAPI.mmBorder then pcall(setBorderSize, select(6, UbermocUIAPI.mmBorder())) end
        if DB.squareMinimap then pcall(alignAddonButtons) end
        if UbermocUIAPI.applyMapBack then pcall(UbermocUIAPI.applyMapBack) end
        if UbermocUIAPI.paintMiniMap then pcall(UbermocUIAPI.paintMiniMap) end
    end

    mmAlpha = function()
        -- (the experience bar fades through its own rule now)
    end

    local xpEvents = CreateFrame("Frame")
    for _, e in ipairs({ "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP", "UPDATE_EXHAUSTION", "PLAYER_ENTERING_WORLD",
                         "ENABLE_XP_GAIN", "DISABLE_XP_GAIN", "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS",
                         "PLAYER_MONEY", "BAG_UPDATE_DELAYED", "UPDATE_INVENTORY_DURABILITY", "MERCHANT_CLOSED" }) do
        pcall(xpEvents.RegisterEvent, xpEvents, e)
    end
    xpEvents:SetScript("OnEvent", function(_, event)
        if not (UbermocUIDB and UbermocUIDB.mm and UbermocUIDB.mm.xp) then return end
        if event == "PLAYER_MONEY" or event == "BAG_UPDATE_DELAYED" or event == "UPDATE_INVENTORY_DURABILITY" or event == "MERCHANT_CLOSED" then
            pcall(updateInfo)
            return
        end
        mmApply()
        if event == "PLAYER_ENTERING_WORLD" and C_Timer and C_Timer.After then
            -- Other addons add their minimap buttons a little after login.
            for _, secs in ipairs({ 1, 3, 8 }) do
                C_Timer.After(secs, function()
                    pcall(scanBox)
                    if UbermocUIDB.squareMinimap then pcall(alignAddonButtons) end
                end)
            end
        end
    end)

    buildMinimapPanel = function()
        mmPanel = CreateFrame("Frame")
        mmPanel.name = "Minimap"
        newLabel(mmPanel, "Minimap", 16, -16, "GameFontNormalHuge")
        local scroll = CreateFrame("ScrollFrame", nil, mmPanel, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 8, -218)
        scroll:SetPoint("BOTTOMRIGHT", -30, 44)
        local sc = CreateFrame("Frame", nil, scroll)
        sc:SetSize(560, 900)
        scroll:SetScrollChild(sc)

        local function mm() return UbermocUIDB.mm end
        local function px(v) return math.floor(v + 0.5) .. " px" end
        local SIDE3 = { LEFT = "Left", CENTER = "Centre", RIGHT = "Right" }
        local CORNER_NAME = { TOPLEFT = "top left", TOP = "top middle", TOPRIGHT = "top right", BOTTOMLEFT = "bottom left",
                              BOTTOM = "bottom middle", BOTTOMRIGHT = "bottom right", LEFT = "middle of the left edge",
                              RIGHT = "middle of the right edge", CENTER = "centre" }
        local ctl = {}          -- every control, so the refresh needs only this one table
        local tabDefs = {}
        -- Layout helpers: each one places its control at the running y and moves y down.
        local y = -4
        local function tab(name) tabDefs[#tabDefs + 1] = { name, y + 4 } end
        local function header(text, gap)
            if gap then y = y - gap end
            newLabel(sc, text, 8, y, "GameFontNormalLarge"); y = y - 32
        end
        local function check(key, text, fn, indent)
            ctl[key] = newCheck(sc, text, 8 + (indent or 0), y, function(v)
                fn(v)
                if mmPanel.refresh then mmPanel.refresh() end
            end)
            y = y - 32
        end
        local function slider(key, text, min, max, group, field, step, fmt)
            local lab = newLabel(sc, text, 40, y + 2)
            local s = makeSlider(sc, 140, min, max, step or 1, fmt or px, function(v) mm()[group][field] = v; mmApply() end)
            s:SetPoint("TOPLEFT", 240, y)
            s.ubermocLabel = lab
            ctl[key] = s
            y = y - 38
        end
        local function note(text, lines)
            local fs = newLabel(sc, text, 8, y, "GameFontHighlightSmall")
            fs:SetWidth(530); fs:SetJustifyH("LEFT"); fs:SetWordWrap(true)
            y = y - 14 * (lines or 2) - 12
        end
        -- A colour square that opens the colour picker; get() returns r, g, b and set(r, g, b) stores them.
        local function swatchRow(key, text, get, set)
            local lab = newLabel(sc, text, 40, y - 4)
            local bt = CreateFrame("Button", nil, sc)
            bt:SetSize(30, 30)
            bt:SetPoint("TOPLEFT", 240, y + 2)
            UbermocUIAPI.flatButton(bt)
            local t = bt:CreateTexture(nil, "ARTWORK")
            t:SetPoint("TOPLEFT", 4, -4); t:SetPoint("BOTTOMRIGHT", -4, 4)
            bt.ubermocLabel = lab
            bt.paint = function() local r, g, b = get(); t:SetColorTexture(r, g, b, 1) end
            bt:SetScript("OnClick", function()
                local r, g, b = get()
                UbermocUIAPI.pickColor(r, g, b, nil, function(nr, ng, nb)
                    set(nr, ng, nb); bt.paint(); mmApply()
                    if mmPanel.refresh then mmPanel.refresh() end
                end)
            end)
            ctl[key] = bt
            y = y - 40
        end

        -- Experience bar ------------------------------------------------------------------------
        -- Minimal map -------------------------------------------------------------------------------
        tab("Minimal Map")
        local function miniDB() mm().mini = mm().mini or {}; return mm().mini end
        local function repaint()
            if UbermocUIAPI.paintMiniMap then pcall(UbermocUIAPI.paintMiniMap) end
            if UbermocUIAPI.updateMiniBar then pcall(UbermocUIAPI.updateMiniBar, true) end
            mmApply()
            if mmPanel.refresh then mmPanel.refresh() end
        end
        header("Minimal map")
        note("These apply while the map look (at the top) is one of the two minimal looks. Its frame, colour and texture are on the Textures page, with the other textures and borders.", 2)
        ctl.miniNote = newLabel(sc, "", 8, y + 6, "GameFontHighlightSmall")
        y = y - 14
        -- One labelled row of buttons (the lit one is the current choice).
        local function choice(key, text, opts, get, set)
            local lab = newLabel(sc, text, 40, y - 6)
            ctl[key] = H.segRow(sc, 208, y, opts, get, function(v) set(v); repaint() end)
            ctl[key].label = lab
            y = y - 36
        end
        local function cornerRow(key, text, get, set)
            newLabel(sc, text, 40, y - 16)
            ctl[key] = H.cornerPick(sc, 208, y, CORNER_NAME, get, function(v) set(v); repaint() end)
            y = y - 54
        end
        local function sizeRow(key, text, get, set)
            local lab = newLabel(sc, text, 40, y + 2)
            local s = makeSlider(sc, 140, 8, 30, 1, px, function(v) set(v); repaint() end)
            s:SetPoint("TOPLEFT", 240, y)
            s.ubermocLabel = lab
            s.get = get
            H.sliderDefault(s, 12)
            ctl[key] = s
            y = y - 40
        end
        local function nudgeRow(key, get, set)
            newLabel(sc, "Nudge", 40, y - 6)
            ctl[key] = H.nudgePad(sc, 208, y, get, function(nx, ny) set(nx, ny); repaint() end)
            y = y - 40
        end
        newButton(sc, "Frame, colour and texture: open the Textures page", 360, 40, y, function()
            if UbermocUIAPI.openTextures then UbermocUIAPI.openTextures("minimap") end
        end)
        y = y - 40
        header("Text inside the map", 8)
        cornerRow("fpsCorner", "FPS / latency", function() return mm().perf.corner or "BOTTOMLEFT" end, function(v) mm().perf.corner = v end)
        nudgeRow("perfNudge", function() return mm().perf.ox or 0, mm().perf.oy or 0 end, function(nx, ny) mm().perf.ox, mm().perf.oy = nx, ny end)
        sizeRow("perfSize", "FPS / latency size", function() return mm().perf.size or 10 end, function(v) mm().perf.size = v end)
        H.sliderDefault(ctl.perfSize, 10)
        cornerRow("coordCorner", "Coordinates", function() return miniDB().coordCorner or "TOPRIGHT" end, function(v) miniDB().coordCorner = v end)
        nudgeRow("coordNudge", function() return miniDB().coordX or 0, miniDB().coordY or 0 end, function(nx, ny) miniDB().coordX, miniDB().coordY = nx, ny end)
        sizeRow("coordSize", "Coordinates size", function() return miniDB().coordSize or 10 end, function(v) miniDB().coordSize = v end)
        H.sliderDefault(ctl.coordSize, 10)
        cornerRow("clockCorner", "Time", function() return mm().clock.corner or "BOTTOMRIGHT" end, function(v) mm().clock.corner = v end)
        nudgeRow("clockNudge", function() return mm().clock.ox or 0, mm().clock.oy or 0 end, function(nx, ny) mm().clock.ox, mm().clock.oy = nx, ny end)
        sizeRow("clockSize", "Time size", function() return mm().clock.size or 12 end, function(v) mm().clock.size = v end)
        header("Info board", 8)
        check("miniBar", "Info board (gold, bag space, durability, experience)", function(v)
            miniDB().bar = v
            if v then mm().info.on = false end   -- only one of the two boards at a time
            repaint()
        end)
        choice("miniMode", "Board shows", { { false, "When something changes", 190 }, { true, "Always", 80 } },
            function() return miniDB().always and true or false end, function(v) miniDB().always = v end)
        -- What the board lists. Experience is left off by itself while the mini experience bar is showing.
        local function itemsDB() local m = miniDB(); m.items = m.items or {}; return m.items end
        for _, it in ipairs({ { "bGold", "gold", "Gold" }, { "bBags", "bags", "Bag space" }, { "bDura", "dura", "Durability" } }) do
            choice(it[1], it[3], { { true, "Show", 70 }, { false, "Hide", 70 } },
                function() return itemsDB()[it[2]] ~= false end, function(v) itemsDB()[it[2]] = v end)
        end
        -- Experience shows in one place: showing it on the board turns the mini experience bar off (and the
        -- other way round, on the XP Bar tab).
        choice("bXP", "Experience", { { true, "Show", 70 }, { false, "Hide", 70 } },
            function() return itemsDB().xp ~= false end,
            function(v) itemsDB().xp = v; if v then mm().xp.on = false; mmApply() end end)
        choice("boardSide", "Board place", { { "bottom", "Under the map", 130 }, { "top", "Above the map", 130 } },
            function() return miniDB().boardSide == "top" and "top" or "bottom" end, function(v) miniDB().boardSide = v end)
        choice("boardFit", "Board size", { { true, "Auto: fit the map", 140 }, { false, "Manual", 80 } },
            function() return miniDB().boardFit ~= false end, function(v) miniDB().boardFit = v end)
        do
            local function bslider(key, text, min, max, field, def)
                local lab = newLabel(sc, text, 40, y + 2)
                local s = makeSlider(sc, 140, min, max, 1, px, function(v) miniDB()[field] = v; repaint() end)
                s:SetPoint("TOPLEFT", 240, y)
                s.ubermocLabel = lab
                s.get = function() return miniDB()[field] or def end
                H.sliderDefault(s, def)
                ctl[key] = s
                y = y - 40
            end
            bslider("boardW", "Board width", 60, 400, "boardW", 160)
            bslider("boardSize", "Board text size", 7, 20, "boardSize", 11)
            bslider("boardIcon", "Board icon size", 8, 24, "boardIcon", 12)
        end
        nudgeRow("boardNudge", function() return miniDB().boardX or 0, miniDB().boardY or 0 end,
            function(nx, ny) miniDB().boardX, miniDB().boardY = nx, ny end)
        newButton(sc, "Board border, texture and background: Textures page", 380, 40, y, function()
            if UbermocUIAPI.openTextures then UbermocUIAPI.openTextures("minimap") end
        end)
        y = y - 40
        note("The board shows for five seconds whenever one of its numbers changes, then fades away. It replaces the Character Info bar: turning one on turns the other off.", 2)

        tab("XP Bar")
        header("Experience bar")
        check("xpOn", "Replace the zone name with a mini experience bar", function(v)
            mm().xp.on = v
            if v then   -- experience shows in one place: here, so it comes off the info board
                mm().mini = mm().mini or {}; mm().mini.items = mm().mini.items or {}; mm().mini.items.xp = false
                if UbermocUIAPI.updateMiniBar then pcall(UbermocUIAPI.updateMiniBar) end
            end
            mmApply()
        end)
        check("xpAttach", "Attach it on top of the map, outside it", function(v) mm().xp.attach = v; mmApply() end)
        check("xpText", "Show the percentage in the middle", function(v) mm().xp.text = v; mmApply() end)
        check("xpRest", "Thin white line where your rested experience reaches", function(v) mm().xp.rested = v; mmApply() end)
        check("xpFullW", "When attached: as wide as the map (off: the Width below)", function(v) mm().xp.fullW = v; mmApply() end, 24)
        slider("xpW", "Width", 60, 500, "xp", "w")
        slider("xpH", "Height", 8, 500, "xp", "h")
        newButton(sc, "Border: open the Textures page", 260, 40, y, function()
            if UbermocUIAPI.openTextures then UbermocUIAPI.openTextures("minimap") end
        end)
        y = y - 40
        swatchRow("xpBg", "Background colour", function() local x = mm().xp; return x.bgR or 0.02, x.bgG or 0.03, x.bgB or 0.06 end,
            function(r, g, b) local x = mm().xp; x.bgR, x.bgG, x.bgB = r, g, b; mmApply() end)
        slider("xpBgA", "Background opacity", 0, 100, "xp", "bgA", 5, function(v) return math.floor(v + 0.5) .. "%" end)
        H.sliderDefault(ctl.xpBgA, 95)
        slider("xpX", "Left / right", -500, 500, "xp", "x")
        slider("xpY", "Up / down", -500, 500, "xp", "y")
        note("The bar sits where the zone name is and fills as you gain experience. Hover it for the exact numbers and your zone. At maximum level the normal zone name comes back.")
        header("Top strip", 6)
        check("dock", "Add a strip above the experience bar with the search, mail and calendar buttons", function(v) mm().xp.icons = v; mmApply() end)
        check("phase", "Show the time of day (dawn, day, evening, dusk, night) in the middle of the strip", function(v) mm().xp.phase = v; mmApply() end, 24)
        check("stripCoords", "Show your coordinates in the middle of the strip", function(v) mm().xp.coords = v; mmApply() end, 24)
        slider("stripOut", "Outline on strip text", 0, 100, "xp", "stripOutline", 5, function(v) return math.floor(v + 0.5) .. "%" end)
        slider("stripSize", "Strip text size", 8, 20, "xp", "stripSize")

        -- Zone name -------------------------------------------------------------------------------
        y = y - 16
        tab("Zone Name")
        header("Zone name")
        check("zoneIn", "Show the zone name inside the top of the map", function(v)
            mm().zone = mm().zone or {}
            mm().zone.inside = v
            mmApply()
        end)
        check("zoneAuto", "Text in the zone's own colour (green friendly, red hostile...)", function(v)
            local z = mm().zone
            if v then z.tr, z.tg, z.tb = nil, nil, nil else z.tr, z.tg, z.tb = 1, 0.82, 0 end
            mmApply()
        end, 24)
        swatchRow("zoneText", "Text colour", function() local z = mm().zone; return z.tr or 1, z.tg or 0.82, z.tb or 0 end,
            function(r, g, b) local z = mm().zone; z.tr, z.tg, z.tb = r, g, b end)
        check("zoneOut", "Outline around the text", function(v) mm().zone.outline = v; mmApply() end, 24)
        swatchRow("zoneOutC", "Outline colour", function() local z = mm().zone; return z.or_ or 0, z.og or 0, z.ob or 0 end,
            function(r, g, b) local z = mm().zone; z.or_, z.og, z.ob = r, g, b end)

        -- Addon buttons -----------------------------------------------------------------------------
        y = y - 16
        tab("Addon Buttons")
        header("Ubermoc UI button")
        check("uiBtn", "Show the Ubermoc UI button on the minimap", function(v)
            UbermocUIDB.minimap.hide = not v
            updateMinimapButton()
        end)
        note("Left-click opens these settings, right-click turns Ubermoc UI on or off. Drag it to move it.", 1)
        header("Addon button container", 6)
        check("boxOn", "Gather addon minimap buttons into one button that flies them out", function(v) mm().box.on = v; mmApply() end)
        check("boxInside", "Keep it inside the map, tucked into the corner", function(v)
            local b = mm().box
            b.inside = v
            -- the Left / right and Up / down numbers mean something different inside the map: move them over
            if v and b.x == 3 and b.y == 21 then b.x, b.y = -2, 0 end
            if not v and b.x == -2 and b.y == 0 then b.x, b.y = 3, 21 end
            mmApply()
        end, 24)
        newLabel(sc, "Corner", 40, y - 8)
        ctl.boxCorner = H.cornerPick(sc, 208, y, CORNER_NAME, function() return mm().box.corner or "TOPLEFT" end,
            function(v) mm().box.corner = v; repaint() end, H.CORNER4_CELLS)
        y = y - 40
        choice("boxDir", "Opens", { { "LEFT", "Left", 64 }, { "RIGHT", "Right", 64 }, { "ABOVE", "Up", 64 }, { "BELOW", "Down", 64 } },
            function() return mm().box.dir or "LEFT" end, function(v) mm().box.dir = v end)
        newLabel(sc, "Border", 40, y - 6)
        ctl.boxBorder = newButton(sc, "Set on the Textures page", 220, 208, y, function()
            if UbermocUIAPI.openTextures then UbermocUIAPI.openTextures("minimap") end
        end)
        y = y - 36
        choice("boxRound", "Shape", { { false, "Square", 70 }, { true, "Round", 70 } },
            function() return mm().box.round and true or false end, function(v) mm().box.round = v end)
        slider("boxSize", "Button size", 16, 500, "box", "size")
        slider("boxCols", "Buttons per row", 1, 8, "box", "cols")
        slider("boxX", "Left / right", -500, 500, "box", "x")
        slider("boxY", "Up / down", -500, 500, "box", "y")
        note("Inside the map, Left / right and Up / down nudge it from its corner. Click the container button to fly your addon buttons out; they close when the mouse leaves. Turn this off to put every button back.", 3)

        -- Info bar --------------------------------------------------------------------------------
        y = y - 16
        tab("Character Info")
        header("Character info")
        check("infoOn", "Show gold, bag space and durability next to the minimap", function(v)
            mm().info.on = v
            if v then miniDB().bar = false; if UbermocUIAPI.updateMiniBar then pcall(UbermocUIAPI.updateMiniBar) end end   -- one board at a time
            mmApply()
        end)
        choice("infoSide", "Side", { { "BOTTOM", "Below", 64 }, { "RIGHT", "Right", 64 }, { "TOP", "Above", 64 }, { "LEFT", "Left", 64 } },
            function() return mm().info.side or "BOTTOM" end, function(v) mm().info.side = v end)
        choice("infoMoney", "Money", { { "G", "Gold", 64 }, { "GS", "Gold, silver", 100 }, { "GSC", "Gold, silver, copper", 150 } },
            function() return mm().info.money or "GS" end, function(v) mm().info.money = v end)
        check("infoGold", "Gold", function(v) mm().info.gold = v; mmApply() end, 24)
        check("infoBags", "Bag space (used / total)", function(v) mm().info.bags = v; mmApply() end, 24)
        check("infoDura", "Durability (average)", function(v) mm().info.dura = v; mmApply() end, 24)
        slider("infoThick", "Bar thickness", 16, 500, "info", "thick")
        slider("infoX", "Left / right", -500, 500, "info", "x")
        slider("infoY", "Up / down", -500, 500, "info", "y")
        slider("fsS", "Text size", 8, 20, "info", "fs")
        slider("infoOut", "Outline on character info", 0, 100, "info", "outline", 5, function(v) return math.floor(v + 0.5) .. "%" end)
        slider("isS", "Icon size", 8, 48, "info", "isize")
        header("Item positions", 6)
        slider("giX", "Gold left / right", -500, 500, "info", "gx")
        slider("giY", "Gold up / down", -500, 500, "info", "gy")
        slider("biX", "Bags left / right", -500, 500, "info", "bx")
        slider("biY", "Bags up / down", -500, 500, "info", "by")
        slider("diX", "Durability left / right", -500, 500, "info", "dx")
        slider("diY", "Durability up / down", -500, 500, "info", "dy")
        note("The bar sits on the outside edge of the map; on a round map, above or below, the items follow the curve. Hover an item for details. Its background colour and opacity are on the Background tab.", 3)

        -- Icons on the map ----------------------------------------------------------------------------
        y = y - 16
        tab("Icons")
        header("Icons on the map")
        check("perfOn", "Show FPS and latency inside the map, bottom left", function(v) mm().perf.on = v; mmApply() end)
        slider("mlX", "Mail icon left / right", -500, 500, "mail", "x")
        slider("mlY", "Mail icon up / down", -500, 500, "mail", "y")
        slider("adX", "Addon square left / right", -500, 500, "addons", "x")
        slider("adY", "Addon square up / down", -500, 500, "addons", "y")
        note("Positive Up / down moves toward the top. To fade or hide the mail icon or addon square, use their rows on the Fade Rules page (Always hide works).")

        -- Background ------------------------------------------------------------------------------
        y = y - 16
        tab("Background")
        if UbermocUIAPI.buildMapBackOptions then UbermocUIAPI.buildMapBackOptions(sc, mmPanel, y) end
        y = y - 300
        sc:SetHeight(-y + 40)

        -- Layout (always visible above the tabs) ----------------------------------------------------------
        newLabel(mmPanel, "Layout", 16, -48, "GameFontNormalLarge")
        local function applyClean()
            -- One press: square map with a border, zone name inside the top, FPS and latency bottom left, the
            -- time bottom right, the gold / bags / durability bar underneath, and the experience bar on top of
            -- the map, outside it, shortened so the addon button container fits at its right end.
            local DB = UbermocUIDB
            local c = DB.mm
            DB.squareMinimap = true
            c.border.size = c.border.size or 1
            c.zone = c.zone or {}
            c.zone.inside = true
            if c.loc then c.loc.on = false end
            c.compass = c.compass or {}
            c.compass.on = true
            c.perf.on = true
            c.xp.on = true; c.xp.x = 0; c.xp.y = 0; c.xp.h = 18; c.xp.attach = true; c.xp.reserve = true
            c.xp.icons = true; c.xp.phase = true; c.xp.coords = true
            c.box.on = true; c.box.corner = "TOPRIGHT"; c.box.dir = "BELOW"; c.box.size = 18; c.box.round = false
            c.box.inside, c.box.insideV1 = false, true
            local e = UbermocUIAPI.mapEdge()
            c.box.x = e; c.box.y = c.box.size + e
            c.info.on = true; c.info.side = "BOTTOM"
            c.info.gold = true; c.info.bags = true; c.info.dura = true
            c.info.thick = 22; c.info.bg = 95; c.info.x = 0; c.info.y = 0
            c.clock.move = false; c.clock.own = true; c.coords.move = false
            pcall(SetCVar, "minimapShowPlayerCoords", "0") -- the coordinates live in the strip instead
            if applySquareMinimap then pcall(applySquareMinimap) end
            mmApply()
            if mmPanel.refresh then mmPanel.refresh() end
        end
        newButton(mmPanel, "Apply the clean square layout", 260, 16, -76, applyClean)
        UbermocUIAPI.applyCleanMinimap = applyClean
        -- One choice for the map's look. The two minimal looks have their own tab; going in or out of them,
        -- or back to the game's round map, finishes with a reload so nothing of the old look is left behind.
        newLabel(mmPanel, "Map look", 16, -150)
        ctl.mapLook = H.segRow(mmPanel, 96, -144, { { "round", "Round", 64 }, { "square", "Square", 64 },
                { "mrounded", "Minimal, rounded square", 170 }, { "mround", "Minimal, round", 120 } },
            function()
                local m = mm().mini
                if m and m.on then return m.shape == "round" and "mround" or "mrounded" end
                return UbermocUIDB.squareMinimap and "square" or "round"
            end,
            function(v)
                local m = mm().mini or {}
                local wasMini, wasSquare = m.on and true or false, UbermocUIDB.squareMinimap and true or false
                local wantMini = (v == "mrounded" or v == "mround")
                if wantMini and UbermocUIAPI.miniDB then
                    if wasMini and UbermocUIAPI.miniTextSave then UbermocUIAPI.miniTextSave() end
                    UbermocUIAPI.miniDB().shape = (v == "mround") and "round" or "rounded"
                    if wasMini and UbermocUIAPI.miniTextLoad then UbermocUIAPI.miniTextLoad() end
                end
                if wantMini ~= wasMini and UbermocUIAPI.setMiniMap then UbermocUIAPI.setMiniMap(wantMini) end
                if not wantMini then UbermocUIAPI.setSquareMinimap(v == "square") end
                if wantMini then pcall(UbermocUIAPI.paintMiniMap) end
                mmApply()
                mmPanel.refresh()
                if wantMini ~= wasMini or (v == "round" and wasSquare) then
                    H.askReload("The map look changes fully after a reload.")
                end
            end)
        ctl.compass = newCheck(mmPanel, "North / east / south / west letters on the edge", 16, -110, function(v)
            mm().compass = mm().compass or {}
            mm().compass.on = v
            mmApply()
        end)
        ctl.SIZES = { "perfSize", "coordSize", "clockSize" }
        mmPanel.refresh = function()
            local c = mm()
            local T = ctl
            do
                local m = c.mini or {}
                T.miniBar:SetChecked(m.bar ~= false)
                T.miniMode.refresh(); T.mapLook.refresh()
                T.bGold.refresh(); T.bBags.refresh(); T.bDura.refresh(); T.bXP.refresh()
                T.fpsCorner.refresh(); T.clockCorner.refresh(); T.coordCorner.refresh()
                for _, k in ipairs(T.SIZES) do setSlider(T[k], T[k].get()) end
                T.perfNudge.refresh(); T.coordNudge.refresh(); T.clockNudge.refresh(); T.boardNudge.refresh()
                T.boardFit.refresh(); T.boardSide.refresh()
                for _, k in ipairs({ "boardW", "boardSize", "boardIcon" }) do
                    setSlider(T[k], T[k].get())
                    UbermocUIAPI.setActive(T[k], m.boardFit == false)
                end
            end
            T.compass:SetChecked(c.compass and c.compass.on and true or false)
            c.zone = c.zone or {}
            T.zoneAuto:SetChecked(c.zone.tr == nil)
            T.zoneOut:SetChecked(c.zone.outline ~= false)
            T.zoneText.paint(); T.zoneOutC.paint()
            for _, k in ipairs({ "xpOn:xp.on", "xpAttach:xp.attach", "xpText:xp.text", "xpRest:xp.rested", "dock:xp.icons",
                "phase:xp.phase", "stripCoords:xp.coords",
                "boxOn:box.on", "infoOn:info.on", "infoGold:info.gold", "infoBags:info.bags", "infoDura:info.dura", "perfOn:perf.on" }) do
                local key, g, f = k:match("^(%w+):(%w+)%.(%w+)$")
                T[key]:SetChecked(c[g] and c[g][f] and true or false)
            end
            T.zoneIn:SetChecked(c.zone and c.zone.inside and true or false)
            T.uiBtn:SetChecked(not UbermocUIDB.minimap.hide)
            do
                local so = c.xp.stripOutline
                if so == nil then so = 100 elseif so == true then so = 100 elseif so == false then so = 0 end
                setSlider(T.stripOut, so)
            end
            setSlider(T.stripSize, c.xp.stripSize or 12)
            T.xpFullW:SetChecked(c.xp.fullW ~= false)
            setSlider(T.xpBgA, c.xp.bgA or 95); T.xpBg.paint()
            UbermocUIAPI.setActive(T.xpW, not (c.xp.attach and c.xp.fullW ~= false))
            UbermocUIAPI.setActive(T.xpFullW, c.xp.attach and true or false)
            setSlider(T.infoOut, c.info.outline == nil and 40 or c.info.outline)
            for _, k in ipairs({ "xpW:xp.w", "xpH:xp.h", "xpX:xp.x", "xpY:xp.y", "boxSize:box.size",
                "boxCols:box.cols", "boxX:box.x", "boxY:box.y", "infoThick:info.thick", "infoX:info.x", "infoY:info.y",
                "fsS:info.fs", "isS:info.isize", "giX:info.gx", "giY:info.gy", "biX:info.bx", "biY:info.by", "diX:info.dx", "diY:info.dy",
                "mlX:mail.x", "mlY:mail.y", "adX:addons.x", "adY:addons.y" }) do
                local key, g, f = k:match("^(%w+):(%w+)%.(%w+)$")
                setSlider(T[key], (c[g] and c[g][f]) or 0)
            end
            T.boxInside:SetChecked(c.box.inside and true or false)
            T.boxCorner.refresh(); T.boxDir.refresh(); T.boxRound.refresh()
            T.infoSide.refresh(); T.infoMoney.refresh()
            if mmPanel.refreshBack then mmPanel.refreshBack() end
            -- Grey out what only matters when its switch above is on.
            local function dim(on, keys) for _, k in ipairs(keys) do UbermocUIAPI.setActive(T[k], on) end end
            dim(c.xp.on, { "xpAttach", "xpText", "xpRest", "xpW", "xpH", "xpX", "xpY", "dock" })
            dim(c.xp.on and c.xp.icons, { "phase", "stripCoords", "stripOut", "stripSize" })
            dim(c.zone.inside, { "zoneAuto", "zoneOut" })
            dim(c.zone.inside and c.zone.tr ~= nil, { "zoneText" })
            dim(c.zone.inside and c.zone.outline ~= false, { "zoneOutC" })
            dim(c.box.on, { "boxInside", "boxCorner", "boxDir", "boxBorder", "boxRound", "boxSize", "boxCols", "boxX", "boxY" })
            dim(c.info.on, { "infoSide", "infoMoney", "infoGold", "infoBags", "infoDura", "infoThick", "infoX", "infoY", "fsS", "infoOut", "isS",
                "giX", "giY", "biX", "biY", "diX", "diY" })
            -- The Minimal Map tab only works with a minimal look; with the round or square map it is greyed out.
            -- With a minimal look, the switches it decides for itself are greyed out on the other tabs.
            local mini = c.mini or {}
            local mo = mini.on and true or false
            local boardOn = mo and mini.bar ~= false
            dim(mo, { "fpsCorner", "perfNudge", "perfSize", "coordCorner", "coordNudge", "coordSize",
                "clockCorner", "clockNudge", "clockSize", "miniBar" })
            dim(boardOn, { "miniMode", "bGold", "bBags", "bDura", "bXP", "boardSide", "boardFit", "boardNudge" })
            dim(boardOn and mini.boardFit == false, { "boardW", "boardSize", "boardIcon" })
            dim(not mo, { "zoneIn", "perfOn" })
            if T.miniNote then
                T.miniNote:SetText(mo and "" or "|cffffaa33Turn on one of the two minimal looks (Map look, at the top) to use these.|r")
            end
        end

        UbermocUIAPI.makeTabs(mmPanel, scroll, sc, tabDefs, -182)
        attachReload(mmPanel)
        mmPanel:Hide()
        mmPanel:SetScript("OnShow", function() mmPanel.refresh(); evaluate() end)
        mmPanel:SetScript("OnHide", function() evaluate() end)
        UbermocUIAPI.addPage("mm", "Minimap", mmPanel)
        UbermocUIAPI.resetters.mm = function()
            local d = defaults()
            local copy
            copy = function(t)
                if type(t) ~= "table" then return t end
                local c = {}
                for k, v in pairs(t) do c[k] = copy(v) end
                return c
            end
            UbermocUIDB.mm = copy(d.mm)
            UbermocUIDB.squareMinimap = d.squareMinimap
            if applySquareMinimap then pcall(applySquareMinimap) end
            mmApply()
        end
    end
end

----------------------------------------------------------------------
-- Chat: per-line fade timers and reveal on new message
----------------------------------------------------------------------
local origChatLines = {}

applyChatLines = function()
    local ch = UbermocUIDB and UbermocUIDB.chat
    if not ch then return end
    for i = 1, (NUM_CHAT_WINDOWS or 10) do
        local f = _G["ChatFrame" .. i]
        if f and f.SetTimeVisible then
            pcall(function()
                if ch.linesOn then
                    -- Remember the player's own values the first time, so turning this off restores them.
                    if not origChatLines[i] then
                        origChatLines[i] = { f:GetFading(), f:GetTimeVisible(), f:GetFadeDuration() }
                    end
                    f:SetFading(true)
                    f:SetTimeVisible(ch.visibleTime)
                    f:SetFadeDuration(ch.fadeTime)
                elseif origChatLines[i] then
                    local o = origChatLines[i]
                    f:SetFading(o[1])
                    f:SetTimeVisible(o[2])
                    f:SetFadeDuration(o[3])
                    origChatLines[i] = nil
                end
            end)
        end
    end
end

local function onChatMessage()
    local DB = UbermocUIDB
    if DB and DB.enabled and DB.chat.revealOnMessage then
        msgReveal = GetTime() + (DB.chat.revealSeconds or 8)
        chatDirty = true -- handled on the next poll tick, so a burst of messages costs one update
    end
end

local chatHooked = {}
hookChatFrames = function()
    for i = 1, (NUM_CHAT_WINDOWS or 10) do
        local f = _G["ChatFrame" .. i]
        if f and f.AddMessage and not chatHooked[f] then
            chatHooked[f] = true
            hooksecurefunc(f, "AddMessage", onChatMessage)
        end
    end
end

----------------------------------------------------------------------
-- Vendors: sell grey items and repair when a merchant window opens
----------------------------------------------------------------------
local function coinText(copper)
    if GetCoinTextureString then return GetCoinTextureString(copper) end
    local g, sv, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
    return g .. "g " .. sv .. "s " .. c .. "c"
end

local function say2(msg) uiPrint("|cff00ccffUbermoc UI|r " .. msg) end

local function sellGrayItems()
    local C = C_Container
    if not (C and C.GetContainerNumSlots and C.GetContainerItemInfo and C.UseContainerItem) then return end
    local total, count = 0, 0
    local slots = {}
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        for slot = 1, (C.GetContainerNumSlots(bag) or 0) do
            local info = C.GetContainerItemInfo(bag, slot)
            if info and info.quality == 0 and not info.hasNoValue and not info.isLocked then
                local price = 0
                if info.hyperlink then
                    local _, _, _, _, _, _, _, _, _, _, sellPrice = (C_Item and C_Item.GetItemInfo or GetItemInfo)(info.hyperlink)
                    price = sellPrice or 0
                end
                total = total + price * (info.stackCount or 1)
                count = count + 1
                slots[#slots + 1] = { bag, slot }
            end
        end
    end
    if count == 0 then return end
    -- The game's own "Sell all junk" (the button on the vendor window) does it in one go.
    local MF = C_MerchantFrame
    local soldAll = false
    if MF and MF.SellAllJunkItems then
        soldAll = pcall(MF.SellAllJunkItems)
    end
    if soldAll then
        if UbermocUIDB.vendor.sellMsg then
            say2("Sold " .. count .. " grey item" .. (count == 1 and "" or "s") .. (total > 0 and (" for " .. coinText(total)) or "") .. ".")
        end
        return
    end
    -- Sell a few per tick so a full bag does not freeze the game.
    local i = 0
    local function step()
        if not (MerchantFrame and MerchantFrame:IsShown()) then return end
        for _ = 1, 6 do
            i = i + 1
            local sl = slots[i]
            if not sl then break end
            C.UseContainerItem(sl[1], sl[2])
        end
        if i < #slots then C_Timer.After(0.05, step) end
    end
    step()
    if UbermocUIDB.vendor.sellMsg then
        say2("Sold " .. count .. " grey item" .. (count == 1 and "" or "s") .. (total > 0 and (" for " .. coinText(total)) or "") .. ".")
    end
end

local function repairGear()
    if not (CanMerchantRepair and CanMerchantRepair()) then return end
    local cost, canRepair = GetRepairAllCost()
    if not canRepair or not cost or cost <= 0 then return end
    local v = UbermocUIDB.vendor
    local usedGuild = false
    if v.repairGuild and IsInGuild() and CanGuildBankRepair and CanGuildBankRepair() then
        local allowance = GetGuildBankWithdrawMoney and GetGuildBankWithdrawMoney() or 0
        local bank = GetGuildBankMoney and GetGuildBankMoney() or 0
        if (allowance == -1 or allowance >= cost) and bank >= cost then
            RepairAllItems(true)
            usedGuild = true
        end
    end
    if not usedGuild then
        if GetMoney() < cost then
            if v.repairMsg then say2("Not enough money to repair (" .. coinText(cost) .. ").") end
            return
        end
        RepairAllItems(false)
    end
    if v.repairMsg then say2("Repaired for " .. coinText(cost) .. (usedGuild and " (guild funds)." or ".")) end
end

local function onMerchantShow()
    local v = UbermocUIDB and UbermocUIDB.vendor
    if not v then return end
    if v.repair then pcall(repairGear) end
    if v.sellGray then
        local buys = true
        if C_MerchantFrame and C_MerchantFrame.IsSellAllJunkEnabled then
            local ok, enabled = pcall(C_MerchantFrame.IsSellAllJunkEnabled)
            if ok and enabled == false then buys = false end
        end
        -- Wait a moment: the vendor window is not open yet when the vendor event arrives.
        if buys then C_Timer.After(0.3, function() pcall(sellGrayItems) end) end
    end
end

----------------------------------------------------------------------
-- Events
----------------------------------------------------------------------
local ev = CreateFrame("Frame")
for _, e in ipairs({
    "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA",
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
    "PLAYER_CONTROL_LOST", "PLAYER_CONTROL_GAINED",
    "PLAYER_MOUNT_DISPLAY_CHANGED", "UPDATE_SHAPESHIFT_FORM", "PLAYER_UPDATE_RESTING",
    "PLAYER_TARGET_CHANGED", "GROUP_ROSTER_UPDATE", "PLAYER_DEAD", "PLAYER_ALIVE",
    "NAME_PLATE_UNIT_ADDED", "QUEST_LOG_UPDATE", "UNIT_QUEST_LOG_CHANGED", "QUEST_POI_UPDATE",
}) do ev:RegisterEvent(e) end
pcall(ev.RegisterEvent, ev, "UPDATE_CHAT_WINDOWS")
pcall(ev.RegisterEvent, ev, "MERCHANT_SHOW")
ev:RegisterUnitEvent("UNIT_HEALTH", "player")
ev:RegisterUnitEvent("UNIT_MAXHEALTH", "player")
ev:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
ev:RegisterUnitEvent("UNIT_MAXPOWER", "player")
ev:RegisterUnitEvent("UNIT_DISPLAYPOWER", "player")
ev:RegisterUnitEvent("UNIT_ENTERED_VEHICLE", "player")
ev:RegisterUnitEvent("UNIT_EXITED_VEHICLE", "player")

local LAGGY = {
    PLAYER_CONTROL_LOST = true, PLAYER_CONTROL_GAINED = true,
    PLAYER_MOUNT_DISPLAY_CHANGED = true, UPDATE_SHAPESHIFT_FORM = true,
}

local QUEST_EVENTS = { QUEST_LOG_UPDATE = true, UNIT_QUEST_LOG_CHANGED = true, QUEST_POI_UPDATE = true }

ev:SetScript("OnEvent", function(_, event, arg1)
    if event == "PLAYER_LOGIN" then
        -- Each step runs on its own, so one failure is reported instead of stopping the rest.
        local steps = {
            -- Pages that are only settings are built the first time the window opens (see UbermocUIAPI.later).
            { "settings", normalize }, { "main page", function() UbermocUIAPI.later("Fade rules", buildPanel) end },
            { "Miscellaneous page", function() UbermocUIAPI.later("Miscellaneous", buildMiscPanel) end },
            { "Nameplates page", buildNameplatePanel }, { "Chat page", function() UbermocUIAPI.later("Chat", buildChatPanel) end },
            { "Fade timing page", function() UbermocUIAPI.later("Fade timing", buildTimingPanel) end },
            { "Debug page", function() UbermocUIAPI.later("Debug", buildDebugPanel) end },
            { "Minimap page", function() UbermocUIAPI.later("Minimap", buildMinimapPanel) end }, { "minimap extras", mmApply }, { "rings, interact", function() if UbermocUIAPI.onLogin then UbermocUIAPI.onLogin() end end }, { "chat hooks", hookChatFrames },
            { "chat timers", applyChatLines }, { "minimap button", buildMinimapButton },
            { "square minimap", applySquareMinimap }, { "tooltip", setupTooltipCursor },
            { "nameplate sizes", applyPlateSizes }, { "nameplate visibility", applyPlateVisibility },
            { "nameplate icons", updateAllPlates },
        }
        UbermocUIAPI.setAccent()
        for _, st in ipairs(steps) do
            local ok, err = pcall(st[2])
            if not ok then print("|cffff4444Ubermoc UI|r " .. st[1] .. " failed: " .. tostring(err)) end
        end
        local getMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
        local okv, ver = pcall(getMeta, "UbermocUI", "Version")
        print("|cff00ccffUbermoc UI|r " .. ((okv and ver) or "") .. " loaded. Open the settings from the game menu (Start), under Ubermoc UI.")
    end
    if not UbermocUIDB then return end
    if event == "NAME_PLATE_UNIT_ADDED" then
        local plate = C_NamePlate and C_NamePlate.GetNamePlateForUnit and C_NamePlate.GetNamePlateForUnit(arg1)
        if plate then pcall(updatePlate, plate) end
        return
    elseif event == "MERCHANT_SHOW" then
        onMerchantShow()
        return
    elseif event == "PLAYER_TARGET_CHANGED" then
        restylePlates()
        -- the new target's plate drops its quest / elite / rare icons (the floating frame draws them) and the old
        -- target's plate gets them back
        updateAllPlates()
    elseif QUEST_EVENTS[event] then
        -- these come in bursts: one plate update for the whole burst
        if not Q.quest then
            Q.quest = true
            C_Timer.After(0.3, function() Q.quest = false; updateAllPlates() end)
        end
        return
    elseif event == "PLAYER_REGEN_ENABLED" and plateScalePending then
        plateScalePending = false
        applyPlateSizes()
        applyPlateVisibility()
        updateAllPlates()
    end
    if event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(1, applySquareMinimap)
        -- Blizzard restores each chat window's own settings around login, so apply ours afterwards.
        C_Timer.After(1, function() hookChatFrames(); applyChatLines() end)
        C_Timer.After(4, applyChatLines)
    elseif event == "UPDATE_CHAT_WINDOWS" then
        hookChatFrames()
        C_Timer.After(0.5, applyChatLines)
    end
    if LAGGY[event] then C_Timer.After(0.2, evaluate) end
    -- many times a second in a fight: only a real change of what shows runs the pass over every frame
    if Q.BUSY[event] then Q.quiet() else evaluate() end
end)

----------------------------------------------------------------------
-- Key bindings and slash commands
----------------------------------------------------------------------
-- Entry points for Bindings.xml. Bind these to controller buttons in
-- Key Bindings > AddOns.
BINDING_HEADER_UBERMOCUI = "Ubermoc UI"
BINDING_NAME_UBERMOCUI_REVEAL = "Reveal UI (hold)"
BINDING_NAME_UBERMOCUI_REVEAL_TOGGLE = "Reveal UI (toggle)"
BINDING_NAME_UBERMOCUI_TOGGLE = "Turn Ubermoc UI on/off"
BINDING_NAME_UBERMOCUI_CURSOR = "Interface cursor (D-pad)"
BINDING_NAME_UBERMOCUI_CURSORMENU = "Interface cursor item menu"
BINDING_NAME_UBERMOCUI_CURSORCLICK = "Interface cursor click"
BINDING_NAME_UBERMOCUI_CURSORRIGHT = "Interface cursor right-click"
BINDING_NAME_UBERMOCUI_CURSORBACK = "Interface cursor back"

function UbermocUI_Reveal(keystate)
    revealHeld = (keystate == "down")
    evaluate()
end

function UbermocUI_RevealToggle()
    revealToggle = not revealToggle
    evaluate()
end

function UbermocUI_ToggleEnabled()
    if not UbermocUIDB then return end
    UbermocUIDB.enabled = not UbermocUIDB.enabled
    print("|cff00ccffUbermoc UI|r " .. (UbermocUIDB.enabled and "on" or "off"))
    if panel and panel:IsShown() and refreshPanel then refreshPanel() end
    evaluate()
end

local function say(msg) uiPrint("|cff00ccffUbermoc UI|r " .. msg) end

-- The settings open from the game menu and from the game's addon list, so a controller is all it takes.
function UbermocUI_OnCompartmentClick() if UbermocUIAPI.openWindow then UbermocUIAPI.openWindow() end end
function UbermocUI_OnCompartmentEnter(_, button)
    if not (GameTooltip and button) then return end
    GameTooltip:SetOwner(button, "ANCHOR_LEFT")
    GameTooltip:SetText("Ubermoc UI")
    GameTooltip:AddLine("Play with a controller. Click to open the settings.", 1, 1, 1, true)
    GameTooltip:Show()
end
function UbermocUI_OnCompartmentLeave() if GameTooltip then GameTooltip:Hide() end end
do
    local hooked = false
    local function addMenuEntry()
        local gm = _G.GameMenuFrame
        if hooked or not (gm and gm.AddButton and gm.InitButtons) then return end
        hooked = true
        hooksecurefunc(gm, "InitButtons", function(self)
            local ok, btn = pcall(self.AddButton, self, "Ubermoc UI", function()
                if securecallfunction and HideUIPanel then pcall(securecallfunction, HideUIPanel, gm) end
                if UbermocUIAPI.openWindow then UbermocUIAPI.openWindow() end
                if UbermocUIAPI.cursorRestart then C_Timer.After(0.15, function() pcall(UbermocUIAPI.cursorRestart) end) end
            end)
            -- The game lays its menu out by each button's layoutIndex: ours goes first, above Options, with a gap under it.
            if ok and type(btn) == "table" then
                local pool = self.buttonPool
                if pool and pool.EnumerateActive then
                    for b in pool:EnumerateActive() do
                        if b ~= btn and b.layoutIndex == 1 then pcall(function() b.topPadding = 20 end) end
                    end
                end
                pcall(function() btn.layoutIndex = 0; btn.topPadding = nil end)
                if self.MarkDirty then pcall(self.MarkDirty, self) end
            end
        end)
    end
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_LOGIN")
    f:SetScript("OnEvent", function() pcall(addMenuEntry) end)
    pcall(addMenuEntry)
end

SLASH_UBERMOCUI1 = "/ubermoc"
SLASH_UBERMOCUI2 = "/ubermocui"
SLASH_UBERMOCUI3 = "/uberui"
SLASH_UBERMOCUI4 = "/uifade"
SlashCmdList["UBERMOCUI"] = function(msg)
    local a, b = strsplit(" ", strtrim(msg or ""):lower(), 2)
    local _, rawB = strsplit(" ", strtrim(msg or ""), 2) -- same text, original capitalisation
    a = a or ""
    local DB = UbermocUIDB
    if a == "on" or a == "off" then
        DB.enabled = (a == "on")
        say(a)
        if refreshPanel and panel and panel:IsShown() then refreshPanel() end
        evaluate()
    elseif a == "toggle" then
        UbermocUI_ToggleEnabled()
    elseif a == "reveal" then
        UbermocUI_RevealToggle()
    elseif a == "square" then
        DB.squareMinimap = not DB.squareMinimap
        if DB.squareMinimap then
            applySquareMinimap()
            say("square minimap on")
        else
            say("square minimap off (round shape returns after /reload)")
        end
        updateMinimapButton()
        if refreshMisc and miscPanel and miscPanel:IsShown() then refreshMisc() end
    elseif a == "plate" then
        -- Prints what the addon can see on a nameplate (your target, mouseover, or the first friendly plate).
        local plate
        for _, u in ipairs({ "target", "mouseover" }) do
            plate = plate or (UnitExists(u) and C_NamePlate.GetNamePlateForUnit(u))
        end
        if not plate then
            for _, pl in ipairs(C_NamePlate.GetNamePlates()) do
                if not isHostileUnit(plateUnit(pl)) then plate = pl; break end
            end
        end
        if not plate then say("No nameplate found. Target a friendly player with nameplates on."); return end
        local unit = plateUnit(plate)
        local uf = plate.UnitFrame
        local function show(label, f)
            local ok, v = pcall(f)
            local text = (not ok and "error: " .. tostring(v)) or (isHidden(v) and "hidden by WoW") or tostring(v)
            say(label .. ": " .. text)
        end
        say("unit " .. tostring(unit) .. ", group " .. (isHostileUnit(unit) and "enemy" or "friendly"))
        show("is player", function() return UnitIsPlayer(unit) end)
        show("class", function() return select(2, UnitClass(unit)) end)
        show("name", function() return UnitName(unit) end)
        show("health fraction", function() return healthFraction(unit) end)
        show("gradient mode", function()
            if not uf then return "no unit frame" end
            local c = uf.ubermocMissClip
            if healthFraction(unit) then return "numbers (coloured letters)" end
            if not c then return "hidden health, layer not created (name-only off, or gradient off?)" end
            return "hidden health, layer " .. (c:IsShown() and "on" or "off") .. (uf.ubermocMissErr and (", error: " .. uf.ubermocMissErr) or "")
        end)
        show("nameplate debuff container error", function() return tostring(UbermocUIAPI.npAuraError or "none") end)
        show("name-only on (friendly / enemy)", function() return tostring(UbermocUIDB.nameplates.friendly.look.nameOnly) .. " / " .. tostring(UbermocUIDB.nameplates.enemy.look.nameOnly) end)
        show("health bar alpha / shown / held hidden", function()
            local b = uf and uf.HealthBarsContainer
            if not b then return "no bar" end
            return tostring(b:GetAlpha()) .. " / " .. tostring(b:IsShown()) .. " / " .. tostring(UbermocUIAPI.isHeldHidden(b))
        end)
        show("WoW show-only-name setting", function() return GetCVar("nameplateShowOnlyNameForFriendlyPlayerUnits") end)
        if uf then
            local keys = {}
            for k, v in pairs(uf) do
                if type(k) == "string" and type(v) == "table" and v.GetObjectType then
                    keys[#keys + 1] = k .. ":" .. v:GetObjectType()
                end
            end
            table.sort(keys)
            say("plate parts: " .. table.concat(keys, ", "))
            show("name width", function() return uf.name and uf.name:GetStringWidth() end)
            show("level frame shown", function() return uf.PlayerLevelDiffFrame and uf.PlayerLevelDiffFrame:IsShown() end)
        else
            say("this plate has no UnitFrame")
        end
    elseif a == "health" then
        local function show(label, f)
            local ok, v = pcall(f)
            local text = (not ok and "error") or (isHidden(v) and "hidden by WoW") or tostring(v)
            uiPrint("|cff66ccffUbermoc UI|r " .. label .. ": " .. text)
        end
        local ptype = UnitPowerType("player")
        show("health", function() return UnitHealth("player") end)
        show("max health", function() return UnitHealthMax("player") end)
        show("power type", function() return ptype end)
        show("power", function() return UnitPower("player", ptype) end)
        show("max power", function() return UnitPowerMax("player", ptype) end)
        show("health below full", function() return belowFull("health") end)
        show("hidden-health fade in use", function()
            local n = {}
            for key, sp in pairs(secretSpec) do n[#n + 1] = key .. "(" .. sp.kind .. " " .. math.floor(sp.aNot * 100) .. "% / " .. math.floor(sp.aFull * 100) .. "%)" end
            return #n > 0 and table.concat(n, ", ") or "no"
        end)
        show("power below full", function() return belowFull("power", ptype) end)
        show("mana below full", function() return belowFull("power", 0) end)
        show("mana (current / max)", function() return tostring(UnitPower("player", 0)) .. " / " .. tostring(UnitPowerMax("player", 0)) end)
        show("fill probe health %", function() return barPercent("health") end)
        show("fill probe power %", function() return barPercent("power", ptype) end)
        show("Health not full active", function() return CHECKS.healthrefill() end)
        show("Resource not full active", function() return CHECKS.resourcerefill() end)
        show("in combat", function() return CHECKS.combat() end)
    elseif a == "chat" then
        openPanel("chat")
    elseif a == "timing" then
        openPanel("timing")
    elseif a == "rings" or a == "ring" or a == "interact" or a == "dark" then
        openPanel(a == "ring" and "rings" or a)
    elseif a == "ringreport" then
        if UbermocUIAPI.ringReport then UbermocUIAPI.ringReport(b) else say("rings are not built yet") end
    elseif a == "ringhudreport" then
        if UbermocUIAPI.ringHudReport then UbermocUIAPI.ringHudReport() else say("ring frame is not built yet") end
    elseif a == "cursorreport" then
        if UbermocUIAPI.cursorReport then UbermocUIAPI.cursorReport() else say("cursor is not built yet") end
    elseif a == "box" then
        if UbermocUI_BoxReport then for _, l in ipairs(UbermocUI_BoxReport()) do say(l) end end
    elseif a == "mm" or (a == "minimap" and rawB == "page") then
        openPanel("mm")
    elseif a == "debug" and rawB == "page" then
        openPanel("debug")
    elseif a == "clearchat" then
        -- Puts every chat fade setting back to normal, in case the chat box became hard to use.
        for _, k in ipairs({ "chat", "chattabs", "chatedit", "chatbtns" }) do DB.elements[k] = nil end
        DB.chat.hideTabs = false
        DB.chat.revealOnMessage = false
        for _, k in ipairs({ "chat", "chattabs", "chatedit", "chatbtns" }) do goalEff[k] = 1 end
        evaluate()
        say("chat fade settings cleared")
    elseif a == "nameplates" then
        openPanel("nameplates")
    elseif a == "tooltip" then
        DB.tooltipAtCursor = not DB.tooltipAtCursor
        say("tooltip at cursor " .. (DB.tooltipAtCursor and "on" or "off"))
        if refreshMisc and miscPanel and miscPanel:IsShown() then refreshMisc() end
    elseif a == "minimap" then
        DB.minimap.hide = not DB.minimap.hide
        say("minimap button " .. (DB.minimap.hide and "hidden" or "shown"))
        updateMinimapButton()
        if refreshMisc and miscPanel and miscPanel:IsShown() then refreshMisc() end
    elseif a == "fade" then
        local v = tonumber(b)
        if v and v >= 0 and v <= 5 then DB.fadeTime = v; DB.fadeInTime = v; DB.fadeOutTime = v; say("fade time " .. v .. "s")
        else say("usage: /ubermoc fade <seconds 0-5> (now " .. DB.fadeTime .. ")") end
    elseif a == "mouse" then
        if b == "on" or b == "off" then
            DB.mouse.on = (b == "on"); mouseOver = false
            say("mouseover reveal " .. b)
            evaluate()
        else
            say("usage: /ubermoc mouse on|off (now " .. (DB.mouse.on and "on" or "off") .. ")")
        end
    elseif a == "revealalpha" then
        local v = tonumber(b)
        if v and v >= 0 and v <= 1 then DB.mouse.alpha = v; say("reveal opacity " .. v); evaluate()
        else say("usage: /ubermoc revealalpha <0-1> (now " .. DB.mouse.alpha .. ")") end
    elseif a == "find" then
        local q = (b or ""):lower()
        if q == "" then
            say("usage: /ubermoc find <text>   (lists frame names that contain the text)")
        else
            local hits = {}
            for k, v in pairs(_G) do
                if type(k) == "string" and type(v) == "table" and k:lower():find(q, 1, true) then
                    local ok, t = pcall(function() return v.GetObjectType and v:GetObjectType() end)
                    if ok and t then hits[#hits + 1] = k end
                end
            end
            table.sort(hits)
            if #hits == 0 then
                say("no frames contain \"" .. q .. "\"")
            else
                say(#hits .. " frame(s) contain \"" .. q .. "\":")
                local line = ""
                for i, name in ipairs(hits) do
                    if i > 60 then line = line .. " ..."; break end
                    if #line + #name > 180 then uiPrint(line); line = "" end
                    line = line .. name .. "   "
                end
                if line ~= "" then uiPrint(line) end
            end
        end
    elseif a == "inspect" then
        local f = rawB and getFrame(rawB)
        if not f then
            say("usage: /ubermoc inspect <frame name or path>   (not found: " .. tostring(rawB) .. ")")
        else
            local keys = {}
            for k, v in pairs(f) do
                if type(k) == "string" and type(v) == "table" then
                    local ok, t = pcall(function() return v.GetObjectType and v:GetObjectType() end)
                    if ok and t then keys[#keys + 1] = k .. "(" .. t .. ")" end
                end
            end
            table.sort(keys)
            say(rawB .. " contains: " .. (#keys > 0 and table.concat(keys, ", ") or "nothing found"))
        end
    elseif a == "frames" or a == "missing" then
        local found, total, missing = 0, 0, {}
        for _, e in ipairs(ELEMENTS) do
            for _, name in ipairs(e.frames) do
                total = total + 1
                if getFrame(name) then found = found + 1 else missing[#missing + 1] = name end
            end
        end
        say(found .. " of " .. total .. " frame names found in this client.")
        if #missing > 0 then say("Not found: " .. table.concat(missing, ", ")) end
    elseif a == "debug" then
        local m = computeMatches()
        local act = {}
        for _, k in ipairs(PRIORITY) do if m[k] then act[#act + 1] = k end end
        say("enabled=" .. tostring(DB.enabled) .. "  mouseOver=" .. tostring(mouseOver))
        say("active: " .. (#act > 0 and table.concat(act, ", ") or "none (idle)"))
        local any = false
        for _, e in ipairs(ELEMENTS) do
            if DB.elements[e.key] then
                any = true
                say(e.label .. ": target " .. pct(goalEff[e.key] or 1) .. ", now " .. pct(curEff[e.key] or 1))
            end
        end
        if not any then say("no elements have settings yet") end
    elseif a == "help" then
        say("/ubermoc opens settings; /ubermoc on|off|toggle; /ubermoc reveal; /ubermoc minimap; /ubermoc mm; /ubermoc rings; /ubermoc interact; /ubermoc dark; /ubermoc square; /ubermoc tooltip; /ubermoc nameplates; /ubermoc chat; /ubermoc timing; /ubermoc health; /ubermoc plate; /ubermoc clearchat; /ubermoc debug page; /ubermoc frames; /ubermoc find <text>; /ubermoc inspect <frame>")
        say("/ubermoc fade <sec>; /ubermoc mouse on|off; /ubermoc revealalpha <0-1>; /ubermoc debug")
    else
        openPanel()
    end
end

----------------------------------------------------------------------
-- Map scale: every bar we draw around the minimap follows the map's own scale, so changing the
-- map size in the game's layout editor keeps the top strip, experience bar, addon box, location
-- name and info bar the same width as the map.
----------------------------------------------------------------------
UbermocUIAPI.mapScaleFrames = { "UbermocTopStrip", "UbermocXPBar", "UbermocXPGap", "UbermocModBox", "UbermocInfoBar" }
function UbermocUIAPI.syncMapScale()
    if not Minimap or not Minimap.GetEffectiveScale then return end
    -- Map size set here (a percentage); everything attached to the map follows its scale below.
    do
        local mm = UbermocUIDB and UbermocUIDB.mm
        local want = mm and mm.mapSize
        if want and MinimapCluster and not InCombatLockdown() then
            local sc = want / 100
            if math.abs((MinimapCluster:GetScale() or 1) - sc) > 0.001 then pcall(MinimapCluster.SetScale, MinimapCluster, sc) end
        end
    end
    local me = Minimap:GetEffectiveScale()
    if type(me) ~= "number" or me <= 0 then return end
    -- Each bar gets whatever scale makes it come out the same size on screen as the map, however many
    -- frames above the map carry a scale of their own (the map's size setting can sit on any of them).
    local last
    for _, name in ipairs(UbermocUIAPI.mapScaleFrames) do
        local f = _G[name]
        if f and f.SetScale then
            local parent = f:GetParent()
            local pe = parent and parent.GetEffectiveScale and parent:GetEffectiveScale()
            if type(pe) == "number" and pe > 0 then
                local ms = me / pe
                if math.abs((f.ubermocMapScale or 0) - ms) > 0.0005 then
                    f.ubermocMapScale = ms
                    pcall(f.SetScale, f, ms)
                end
                last = ms
            end
        end
    end
    UbermocUIAPI.mapScaleLast = last
end
-- In the game's layout editor the map's highlight box is drawn around its whole frame, which is
-- wider and taller than the map. While the editor is open, fit that box around the map and our bars.
function UbermocUIAPI.fitEditBox()
    local cl = MinimapCluster
    local sel = cl and cl.Selection
    if not (sel and sel.SetPoint) then return end
    local editing = EditModeManagerFrame and EditModeManagerFrame:IsShown()
    if not editing then
        if sel.ubermocFit then
            sel.ubermocFit = nil
            sel:ClearAllPoints()
            sel:SetAllPoints(cl)
        end
        return
    end
    local ues = UIParent:GetEffectiveScale()
    local L, B, R, T
    -- the minimal map's info board counts when it sits above the map (so pulling it to the top keeps it on screen)
    local mm_ = UbermocUIDB and UbermocUIDB.mm
    local mb = mm_ and mm_.mini and mm_.mini.on and mm_.mini.bar ~= false and mm_.mini.boardSide == "top" and _G.UbermocMiniBar or false
    for _, f in ipairs({ _G.UbermocTopStrip, _G.UbermocXPBar, Minimap, _G.UbermocInfoBar, mb }) do
        if f and f:IsShown() and f.GetRect then
            local l, b, w, h = f:GetRect()
            if l then
                local es = f:GetEffectiveScale() / ues
                l, b, w, h = l * es, b * es, w * es, h * es
                L = L and math.min(L, l) or l
                B = B and math.min(B, b) or b
                R = R and math.max(R, l + w) or (l + w)
                T = T and math.max(T, b + h) or (b + h)
            end
        end
    end
    if not L then return end
    local k = sel:GetEffectiveScale() / ues
    local pad = 4
    local key = string.format("%d:%d:%d:%d:%.3f", L, B, R, T, k)
    if sel.ubermocFit == key then return end
    sel.ubermocFit = key
    sel:ClearAllPoints()
    sel:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", (L - pad) / k, (B - pad) / k)
    sel:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", (R + pad) / k, (T + pad) / k)
end
-- Option: the map (with its strip and bars) goes flush against the screen edge. The game's frame is
-- bigger than what shows, so it stops short; this moves the frame the missing distance.
-- Which side is nearer, and how far it is (only when it is a small gap).
local function flushPull(gapLow, gapHigh)
    local LIM = 24
    if gapLow >= 0.5 and gapLow <= LIM and gapLow <= gapHigh then return -gapLow end
    if gapHigh >= 0.5 and gapHigh <= LIM then return gapHigh end
    return 0
end
function UbermocUIAPI.flushMap()
    local m = UbermocUIDB and UbermocUIDB.mm
    if not m or (m.flush == false and not m.flushTop) or InCombatLockdown() then return end
    local cl = MinimapCluster
    if not cl or (EditModeManagerFrame and EditModeManagerFrame:IsShown()) then return end
    if cl:GetNumPoints() ~= 1 then return end
    local ues = UIParent:GetEffectiveScale()
    local L, B, R, T
    -- the minimal map's info board counts when it sits above the map (so pulling it to the top keeps it on screen)
    local mm_ = UbermocUIDB and UbermocUIDB.mm
    local mb = mm_ and mm_.mini and mm_.mini.on and mm_.mini.bar ~= false and mm_.mini.boardSide == "top" and _G.UbermocMiniBar or false
    for _, f in ipairs({ _G.UbermocTopStrip, _G.UbermocXPBar, Minimap, _G.UbermocInfoBar, mb }) do
        if f and f:IsShown() and f.GetRect then
            local l, b, w, h = f:GetRect()
            if l then
                local es = f:GetEffectiveScale() / ues
                l, b, w, h = l * es, b * es, w * es, h * es
                L = L and math.min(L, l) or l
                B = B and math.min(B, b) or b
                R = R and math.max(R, l + w) or (l + w)
                T = T and math.max(T, b + h) or (b + h)
            end
        end
    end
    if not L then return end
    local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
    local pull = flushPull
    local dx, dy = 0, 0
    if m.flush ~= false then dx = pull(L, sw - R); dy = pull(B, sh - T) end
    -- Pulled right up to the top of the screen, however far below it the game put it.
    if m.flushTop and math.abs(sh - T) >= 0.5 then dy = sh - T end
    if dx == 0 and dy == 0 then return end
    local k = cl:GetEffectiveScale() / ues
    local p, rel, rp, x, y = cl:GetPoint(1)
    pcall(function()
        cl:ClearAllPoints()
        cl:SetPoint(p, rel, rp, (x or 0) + dx / k, (y or 0) + dy / k)
    end)
end
do
    local ticker = CreateFrame("Frame")
    local acc = 0
    ticker:SetScript("OnUpdate", function(_, dt)
        acc = acc + dt
        if acc < 0.25 then return end
        acc = 0
        pcall(UbermocUIAPI.syncMapScale)
        pcall(UbermocUIAPI.fitEditBox)
        pcall(UbermocUIAPI.flushMap)
        -- Keep the addon box locked to the end of the experience bar whatever else moves it.
        pcall(UbermocUIAPI.fillXPGap, _G.UbermocXPBar)
    end)
end

-- Greys out a setting that does not apply right now (and makes it unclickable), or brings it back.
function UbermocUIAPI.setActive(w, on)
    if not w then return end
    on = on and true or false
    if w.frame and w.refresh then
        -- a button row or a < name > list
        local list = w.btns or w.trio
        if not list then w.trio = { w.prev, w.box, w.next }; list = w.trio end
        for _, b in ipairs(list) do b:SetEnabled(on); b:SetAlpha(on and 1 or 0.4) end
        if w.count then w.count:SetAlpha(on and 1 or 0.4) end
        if w.name then w.name:SetAlpha(on and 1 or 0.4) end
        if w.label and w.label.SetAlpha then w.label:SetAlpha(on and 1 or 0.4) end
    elseif w.box and w.minus then UbermocUIAPI.setSliderActive(w, on) else
        if w.SetEnabled then pcall(w.SetEnabled, w, on) end
        if w.SetAlpha then w:SetAlpha(on and 1 or 0.4) end
        if w.label and w.label.SetAlpha then w.label:SetAlpha(on and 1 or 0.4) end
    end
    if w.ubermocLabel and w.ubermocLabel.SetAlpha then w.ubermocLabel:SetAlpha(on and 1 or 0.4) end
end

-- WoW's frames that a halo frame replaces are see-through; this also stops them taking clicks, out of
-- combat only (they are protected in combat), and gives the clicks back when the halo frame is turned off.
do
    local disabled = {}
    local function walk(f, on, depth)
        if not f or depth > 3 then return end
        if f.IsMouseEnabled and f.EnableMouse then
            if not on then
                local ok, en = pcall(f.IsMouseEnabled, f)
                if ok and en then
                    if pcall(f.EnableMouse, f, false) then disabled[f] = true end
                end
            elseif disabled[f] then
                pcall(f.EnableMouse, f, true); disabled[f] = nil
            end
        end
        if f.GetChildren then
            for _, c in ipairs({ f:GetChildren() }) do walk(c, on, depth + 1) end
        end
    end
    local function sync()
        if InCombatLockdown() or not UbermocUIDB then return end
        for _, e in ipairs(UbermocUIAPI.ELEMENTS or {}) do
            if UbermocUIAPI.HALO_REPLACES[e.key] then
                local hidden = UbermocUIAPI.haloHidden[e.key]
                for _, name in ipairs(e.frames) do
                    local f = UbermocUIAPI.frameByName and UbermocUIAPI.frameByName(name)
                    if f then walk(f, not hidden, 0) end
                end
            end
        end
    end
    UbermocUIAPI.syncHaloMouse = sync
    local f = CreateFrame("Frame")
    for _, ev in ipairs({ "PLAYER_REGEN_ENABLED", "GROUP_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD", "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED" }) do
        pcall(f.RegisterEvent, f, ev)
    end
    f:SetScript("OnEvent", function() if C_Timer then C_Timer.After(0.2, function() pcall(sync) end) else pcall(sync) end end)
end

-- Misc page: one press turns on everything the addon adds.
function UbermocUIAPI.enableEverything()
    local D = UbermocUIDB
    for _, k in ipairs({ "ringhud", "ringhud_target", "ringhud_tot", "ringhud_focus", "ringhud_fot" }) do
        D[k] = D[k] or {}
        D[k].on = true
    end
    D.ringhud.pon = true
    for _, k in ipairs({ "party", "raid" }) do D[k] = D[k] or {}; D[k].on = true end
    D.kill = D.kill or {}; D.kill.on = true
    D.targetMark = D.targetMark or {}; D.targetMark.side = true
    D.npThreat = D.npThreat or {}; D.npThreat.on = true
    D.npAuras = D.npAuras or {}; D.npAuras.enemy = D.npAuras.enemy or {}; D.npAuras.enemy.on = true
    local np = D.nameplates
    if np then
        for _, g in ipairs({ "enemy", "friendly" }) do if np[g] and np[g].look then np[g].look.nameOnly = true end end
        if np.enemy then
            for _, k in ipairs({ "quest", "elite", "rare" }) do if np.enemy[k] then np.enemy[k].on = true end end
        end
    end
    D.extras = D.extras or {}
    for _, k in ipairs({ "petRing", "utilRing", "menuRing", "cursor" }) do D.extras[k] = D.extras[k] or {}; D.extras[k].on = true end
    D.vendor = D.vendor or {}; D.vendor.sellGray = true; D.vendor.repair = true
    D.tooltipAtCursor = true
    pcall(SetCVar, "autoLootDefault", "1")
    if UbermocUIAPI.applyCleanMinimap then
        pcall(UbermocUIAPI.applyCleanMinimap)
    elseif D.mm then
        local c = D.mm
        D.squareMinimap = true
        c.border = c.border or {}; c.border.size = c.border.size or 1
        c.zone = c.zone or {}; c.zone.inside = true
        if c.loc then c.loc.on = false end
        c.compass = c.compass or {}; c.compass.on = true
        c.perf = c.perf or {}; c.perf.on = true
        c.xp = c.xp or {}
        c.xp.on = true; c.xp.x = 0; c.xp.y = 0; c.xp.h = 18; c.xp.attach = true; c.xp.reserve = true
        c.xp.icons = true; c.xp.phase = true; c.xp.coords = true
        c.box = c.box or {}
        c.box.on = true; c.box.corner = "TOPRIGHT"; c.box.dir = "BELOW"; c.box.size = 18; c.box.round = false; c.box.x = 3; c.box.y = 21
        c.box.inside, c.box.insideV1 = false, true
        c.info = c.info or {}
        c.info.on = true; c.info.side = "BOTTOM"; c.info.gold = true; c.info.bags = true; c.info.dura = true
        c.info.thick = 22; c.info.bg = 95; c.info.x = 0; c.info.y = 0
        c.clock = c.clock or {}; c.clock.move = false; c.clock.own = true
        c.coords = c.coords or {}; c.coords.move = false
        pcall(SetCVar, "minimapShowPlayerCoords", "0")
    end
end

-- One time: the coordinates are shown in the minimap strip, so WoW's own line under the minimap is
-- switched off.
do
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_LOGIN")
    f:SetScript("OnEvent", function()
        local D = UbermocUIDB
        if not (D and D.mm) or D.mm.coordCvarV2 then return end
        D.mm.coordCvarV1, D.mm.coordCvarV2 = true, true
        pcall(SetCVar, "minimapShowPlayerCoords", "0")
        -- The time and coordinates stay where Ubermoc UI puts them; the location bar is gone.
        if D.mm.clock then D.mm.clock.move = false end
        if D.mm.coords then D.mm.coords.move = false end
        if D.mm.loc then D.mm.loc.on = false end
    end)
end

do
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_LOGOUT")
    f:SetScript("OnEvent", function()
        if UbermocUIDB and UbermocUIDB.wipeOnReload then UbermocUIDB = nil end
    end)
end

-- Fast loot: every slot is taken the moment the loot opens (instead of one item per game tick), and the loot
-- window stays invisible while that happens. Anything that could not be taken (full bags) shows the window.
do
    local f = CreateFrame("Frame")
    f:RegisterEvent("LOOT_READY")
    f:RegisterEvent("LOOT_CLOSED")
    local hidden = false
    local function reveal()
        if hidden and _G.LootFrame then _G.LootFrame:SetAlpha(1) end
        hidden = false
    end
    f:SetScript("OnEvent", function(_, event, autoLoot)
        if event == "LOOT_CLOSED" then reveal(); return end
        if not UbermocUIDB or UbermocUIDB.fastLoot == false then return end
        local okA, al = pcall(GetCVar, "autoLootDefault")
        local on = okA and al == "1"
        if IsModifiedClick and IsModifiedClick("AUTOLOOTTOGGLE") then on = not on end
        if not (on or autoLoot) then return end
        local n = GetNumLootItems and GetNumLootItems() or 0
        if n == 0 then return end
        if _G.LootFrame then _G.LootFrame:SetAlpha(0); hidden = true end
        for i = n, 1, -1 do pcall(LootSlot, i) end
        -- Something left (bags full, a roll in progress, a choice item): show the window again.
        C_Timer.After(0.3, function()
            if hidden and GetNumLootItems and GetNumLootItems() > 0 then reveal() end
        end)
    end)
end

-- Once for each character (the game keeps Auto Loot per character, so a new character starts with it off):
-- WoW's Auto Loot is switched on (Miscellaneous > Loot automatically).
do
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_LOGIN")
    f:SetScript("OnEvent", function()
        local D = UbermocUIDB
        local g = UnitGUID and UnitGUID("player")
        if not D or not g then return end
        D.autoLootChars = D.autoLootChars or {}
        if D.autoLootChars[g] then return end
        D.autoLootChars[g] = true
        pcall(SetCVar, "autoLootDefault", "1")
    end)
end

-- Nameplates are always on, in a fight or not: "Always show nameplates" and the enemy nameplates are switched on at every login.
do
    local function apply()
        pcall(SetCVar, "nameplateShowAll", "1")
        pcall(SetCVar, "nameplateShowEnemies", "1")
    end
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_LOGIN")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:SetScript("OnEvent", function()
        apply()
        if C_Timer and C_Timer.After then C_Timer.After(3, apply) end
    end)
end

-- WoW's own coordinates line under the minimap stays hidden: the game's setting is switched off at every login
-- (the game turns it back on after some updates and when the interface reloads), and whatever frame shows it
-- is hidden again if the game shows it. Not done when the coordinates are set to be moved instead.
do
    local function wanted()
        local D = UbermocUIDB
        if not (D and D.mm) then return false end
        return not (D.mm.coords and D.mm.coords.move)
    end
    local seen = {}
    local function hook(frame)
        if seen[frame] or type(frame) ~= "table" or not frame.Hide or not frame.HookScript then return end
        seen[frame] = true
        frame:Hide()
        hooksecurefunc(frame, "Show", function(self) if wanted() then self:Hide() end end)
    end
    -- the game's frame is found by what it is called: any child of the minimap with "coord" in its name
    local function scan(parent)
        if type(parent) ~= "table" then return end
        for k, v in pairs(parent) do
            if type(k) == "string" and k:lower():find("coord", 1, true) and type(v) == "table" and v.Hide then
                local name = v.GetName and v:GetName()
                if not (name and name:find("^Ubermoc")) then hook(v) end
            end
        end
    end
    local function hideDefault()
        if not wanted() then return end
        pcall(SetCVar, "minimapShowPlayerCoords", "0")
        pcall(function()
            scan(_G.MinimapCluster)
            scan(_G.MinimapCluster and _G.MinimapCluster.MinimapContainer)
            scan(_G.Minimap)
            scan(_G.Minimap and _G.Minimap.GetParent and _G.Minimap:GetParent())
        end)
    end
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_LOGIN")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:SetScript("OnEvent", function()
        hideDefault()
        if C_Timer and C_Timer.After then
            C_Timer.After(2, hideDefault)
            C_Timer.After(8, hideDefault)
        end
    end)
end
