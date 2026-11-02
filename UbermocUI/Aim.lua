-- Aiming: ground spells (Heroic Leap, Blizzard and the like) cast on release, and a crosshair or dot in the middle of the
-- screen while one is being aimed. Settings are on their own page, Aiming (under Controller).
local API = UbermocUIAPI
if not API then return end

local MEDIA = "Interface\\AddOns\\UbermocUI\\Media\\"

local function defaults()
    return { hold = true, center = true, mark = false, when = "aim", style = "cross", size = 4, thick = 1, a = 80, x = 0, y = 0, r = 1, g = 1, b = 1, height = 70 }
end
local filled
local function DB()
    UbermocUIDB = UbermocUIDB or {}
    local d = UbermocUIDB.aim
    if type(d) ~= "table" then d = {}; UbermocUIDB.aim = d end
    if d == filled then return d end
    if not d.v2 then   -- 1.0.98: new look (no "both" shape): a thin white 4 px mark at 80%; its place is kept
        d.v2 = true
        for _, k in ipairs({ "style", "size", "thick", "a", "r", "g", "b" }) do d[k] = nil end
    end
    if d.style ~= "dot" then d.style = "cross" end
    if type(d.extra) ~= "table" then d.extra = {} end
    for k, v in pairs(defaults()) do if d[k] == nil then d[k] = v end end
    filled = d
    return d
end
API.aimDB = DB

----------------------------------------------------------------------
-- Hold to aim, release to cast: the game's own "Press and Hold Casting" (cast on the press of the key, which it needs).
----------------------------------------------------------------------
local HELD = "ActionButtonUseKeyHeldSpell"
local function hasHeld()
    local ok, v = pcall(GetCVar, HELD)
    return ok and v ~= nil
end
local function applyHold()
    local d = DB()
    if not hasHeld() then return end
    if d.hold then
        pcall(SetCVar, "ActionButtonUseKeyDown", "1")
        pcall(SetCVar, HELD, "1")
    else
        pcall(SetCVar, HELD, "0")
    end
end
API.aimApplyHold = applyHold

-- While a ground spell waits for a spot the game normally hands the aim to a stick-moved cursor (its setting
-- GamePadCursorForTargeting: 1 = on, the default; 2 = start at the target). Switched off, the aim stays at the pointer
-- that rests in the middle of the screen, which is where the mark is and where a release-to-cast lands. The old value is
-- kept and put back when the option is turned off.
local TCV = "GamePadCursorForTargeting"
local function applyCenterAim()
    local d = DB()
    local ok, cur = pcall(GetCVar, TCV)
    if not ok or cur == nil then return end
    if d.center then
        if d.targetWas == nil then d.targetWas = cur end
        if cur ~= "0" then pcall(SetCVar, TCV, "0") end
    elseif d.targetWas ~= nil then
        pcall(SetCVar, TCV, d.targetWas)
        d.targetWas = nil
    end
end
API.aimApplyCenter = applyCenterAim

-- Where the pointer rests while the controller steers the camera: the game's own CursorCenteredYPos (a fraction of the
-- screen height from the bottom). Ground spells land there and the mark follows it, so both move together.
local function applyHeight()
    local h = tonumber(DB().height)
    if not h then return end
    h = math.max(0.3, math.min(0.9, h / 100))
    local ok, cur = pcall(GetCVar, "CursorCenteredYPos")
    if not ok or cur == nil then return end
    if math.abs((tonumber(cur) or 0) - h) > 0.001 then pcall(SetCVar, "CursorCenteredYPos", string.format("%.2f", h)) end
end
API.aimApplyHeight = applyHeight

----------------------------------------------------------------------
-- Why the game's own setting is not enough: Blizzard's "Press and Hold Casting" only does something on release for
-- buttons that have a "typerelease" action, and the game gives that only to empowered spells (Evoker). A ground
-- spell such as Heroic Leap has none, so letting go did nothing. So the action buttons holding a ground spell are
-- given one here: pressing shows the reticle as always, letting go stops it and casts the spell at the pointer.
-- (This is done out of combat; the buttons are checked again whenever the bars change.)
----------------------------------------------------------------------
-- Spells that are placed on the ground with a reticle, matched by spell ID (so any game language works). Spells placed at
-- your feet are left out on purpose: they would be cast twice. A spell that is missing is learned the first time its button
-- starts a reticle, or add it with /ubground add Spell Name (the name as your game shows it).
local GROUND_IDS = {
    [6544] = true,    -- Heroic Leap
    [190356] = true,  -- Blizzard
    [2120] = true,    -- Flamestrike
    [153561] = true,  -- Meteor
    [113724] = true,  -- Ring of Frost
    [5740] = true,    -- Rain of Fire
    [30283] = true,   -- Shadowfury
    [152108] = true,  -- Cataclysm
    [1122] = true,    -- Summon Infernal
    [111771] = true,  -- Demonic Gateway
    [43265] = true,   -- Death and Decay
    [152280] = true,  -- Defile
    [51052] = true,   -- Anti-Magic Zone
    [191427] = true,  -- Metamorphosis (Havoc)
    [61882] = true,   -- Earthquake
    [73920] = true,   -- Healing Rain
    [32375] = true,   -- Mass Dispel
    [62618] = true,   -- Power Word: Barrier
    [34861] = true,   -- Holy Word: Sanctify
    [102793] = true,  -- Ursol's Vortex
    [114158] = true,  -- Light's Hammer
    [116844] = true,  -- Ring of Peace
    [115315] = true,  -- Summon Black Ox Statue
    [115313] = true,  -- Summon Jade Serpent Statue
    [1543] = true,    -- Flare
    [370665] = true,  -- Rescue
    [358385] = true,  -- Landslide
    [403631] = true,  -- Breath of Eons
}
local BARS = { "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton", "MultiBarRightButton", "MultiBarLeftButton",
               "MultiBar5Button", "MultiBar6Button", "MultiBar7Button" }
local groundNames = {}
local held, heldAt            -- the ground button being held, and since when

local function spellName(id)
    local ok, n = pcall(function() return C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id) end)
    return ok and type(n) == "string" and n or nil
end

local function buildSets()
    groundNames = {}
    for _, nm in ipairs(DB().extra) do groundNames[nm:lower()] = true end
end

-- The spell's name when this action slot holds a ground spell.
local function groundSpellOf(slot)
    if not slot then return nil end
    local ok, t, id = pcall(GetActionInfo, slot)
    if not ok or t ~= "spell" or type(id) ~= "number" then return nil end
    local name = spellName(id)
    if not name then return nil end
    if GROUND_IDS[id] or groundNames[name:lower()] then return name end
    -- the spell this one replaces (talents and forms swap spells for another)
    local okb, base = pcall(function() return C_Spell and C_Spell.GetBaseSpell and C_Spell.GetBaseSpell(id) end)
    if okb and type(base) == "number" and base ~= id then
        if GROUND_IDS[base] then return name end
        local bn = spellName(base)
        if bn and groundNames[bn:lower()] then return name end
    end
    return nil
end

local dirty
local applyGround

-- A spell that is not in the list but starts a reticle when its button is pressed is a ground spell: it is added to the
-- player's own list (shown by /ubground list) and set up for hold-and-release from then on.
local function learnFrom(b)
    if not b.action then return end
    local ok, t, id = pcall(GetActionInfo, b.action)
    if not ok or t ~= "spell" or type(id) ~= "number" then return end
    local name = spellName(id)
    if not name or groundSpellOf(b.action) then return end
    local d = DB()
    d.extra[#d.extra + 1] = name
    buildSets()
    print("|cff66ccffUbermoc UI|r " .. name .. " starts a reticle, so it is now a hold-to-aim, release-to-cast ground spell. Undo with /ubground remove " .. name)
    dirty = true
    if not InCombatLockdown() then applyGround() end
end
local function watchPress(b)
    if b.ubWatch then return end
    b.ubWatch = true
    b:HookScript("PreClick", function(self)
        if self.ubGround or not DB().hold then return end
        if SpellIsTargeting and SpellIsTargeting() then return end   -- a reticle was already open
        C_Timer.After(0.1, function()
            if SpellIsTargeting and SpellIsTargeting() then learnFrom(self) end
        end)
    end)
end

function applyGround()
    if InCombatLockdown() then dirty = true; return end
    dirty = false
    buildSets()
    local on = DB().hold
    for _, prefix in ipairs(BARS) do
        for i = 1, 12 do
            local b = _G[prefix .. i]
            if b and b.SetAttribute and not (b.IsForbidden and b:IsForbidden()) then
                if on then watchPress(b) end
                local name = on and groundSpellOf(b.action) or nil
                if name then
                    b:SetAttribute("typerelease", "macro")
                    b:SetAttribute("macrotext", "/stopspelltarget\n/cast [@cursor] " .. name)
                    if not b.ubGroundHook then
                        b.ubGroundHook = true
                        b:HookScript("PreClick", function(self, _, down)
                            if not self.ubGround then return end
                            if down then held, heldAt = self, GetTime()
                            elseif held == self then held = nil end
                        end)
                    end
                    b.ubGround = true
                elseif b.ubGround then
                    b:SetAttribute("typerelease", nil)
                    b:SetAttribute("macrotext", nil)
                    b.ubGround = false
                end
            end
        end
    end
end
API.aimApplyGround = applyGround

local queued
local function applyGroundSoon()
    if queued or not (C_Timer and C_Timer.After) then return end
    queued = true
    C_Timer.After(0.4, function() queued = false; applyGround() end)
end

----------------------------------------------------------------------
-- The mark
----------------------------------------------------------------------
local mark
local previewUntil = 0
local function build()
    if mark then return mark end
    mark = CreateFrame("Frame", "UbermocAimMark", UIParent)
    mark:SetFrameStrata("TOOLTIP")
    mark:SetSize(2, 2)
    mark:EnableMouse(false)
    mark:Hide()
    mark.dot = mark:CreateTexture(nil, "OVERLAY", nil, 2)
    mark.dot:SetTexture(MEDIA .. "ringdisc.tga")
    mark.h = mark:CreateTexture(nil, "OVERLAY", nil, 1)
    mark.v = mark:CreateTexture(nil, "OVERLAY", nil, 1)
    return mark
end

-- Sizes of the parts for a style: the dot's diameter, the cross's length, or 0 for a part that is not drawn.
function API.aimShape(style, size, thick)
    local dot, cross = 0, 0
    if style == "dot" then dot = size
    elseif style == "cross" then cross = size
    end
    return dot, cross
end

-- Where the game puts the centered pointer (a fraction of the screen height from the bottom; the game's own
-- "CursorCenteredYPos" setting), which is where a ground spell lands while the controller steers the camera.
-- Falls back to the middle of the screen.
local function centerFraction()
    local ok, v = pcall(GetCVar, "CursorCenteredYPos")
    v = ok and tonumber(v) or nil
    if v and v > 0 and v < 1 then return v end
    return 0.5
end

-- Controller camera on (the pointer is hidden at the centre).
local function cameraSteered()
    local okF, free = pcall(function() return IsGamePadFreelookEnabled and IsGamePadFreelookEnabled() end)
    local okC, cur = pcall(function() return IsGamePadCursorControlEnabled and IsGamePadCursorControlEnabled() end)
    local okG, centred = pcall(GetCVarBool, "GamePadCursorCentering")
    return (okF and free and true or false) and not (okC and cur and true or false) and not (okG and centred and true or false)
end

local function layout()
    local d = DB()
    local m = build()
    m:ClearAllPoints()
    m:SetPoint("CENTER", UIParent, "BOTTOM", d.x or 0, (GetScreenHeight() or 1080) * centerFraction() + (d.y or 0))
    local dot, cross = API.aimShape(d.style, d.size or 28, d.thick or 2)
    local a = (d.a or 90) / 100
    if dot > 0 then
        m.dot:SetSize(dot, dot)
        m.dot:ClearAllPoints(); m.dot:SetPoint("CENTER", m, "CENTER")
        m.dot:SetVertexColor(d.r, d.g, d.b, a)
        m.dot:Show()
    else
        m.dot:Hide()
    end
    if cross > 0 then
        local t = d.thick or 2
        m.h:SetSize(cross, t); m.h:ClearAllPoints(); m.h:SetPoint("CENTER", m, "CENTER")
        m.v:SetSize(t, cross); m.v:ClearAllPoints(); m.v:SetPoint("CENTER", m, "CENTER")
        m.h:SetColorTexture(d.r, d.g, d.b, a)
        m.v:SetColorTexture(d.r, d.g, d.b, a)
        m.h:Show(); m.v:Show()
    else
        m.h:Hide(); m.v:Hide()
    end
end
API.aimLayout = layout

function API.aimPreview() previewUntil = GetTime() + 3 end

do
    local acc = 0
    local f = CreateFrame("Frame")
    f:SetScript("OnUpdate", function(_, dt)
        acc = acc + dt
        if acc < 0.05 then return end
        acc = 0
        if not UbermocUIDB then return end
        local d = DB()
        -- aiming = the game is waiting for a spot, or a ground spell's button is being held
        if held and GetTime() - (heldAt or 0) > 30 then held = nil end
        local aiming = (SpellIsTargeting and SpellIsTargeting()) or held ~= nil
        local want = d.mark and (aiming or GetTime() < previewUntil or (d.when == "always" and cameraSteered()))
        if want then
            local sig = table.concat({ d.style, d.size, d.thick, d.a, d.x, d.y, d.r, d.g, d.b, centerFraction(), GetScreenHeight() or 0 }, "|")
            if not mark or mark.ubSig ~= sig then
                layout()
                mark.ubSig = sig
            end
            if not mark:IsShown() then mark:Show() end
        elseif mark and mark:IsShown() then
            mark:Hide()
        end
    end)
end

do
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("PLAYER_LOGIN")
    ev:RegisterEvent("PLAYER_ENTERING_WORLD")
    for _, e in ipairs({ "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_PAGE_CHANGED", "UPDATE_BONUS_ACTIONBAR", "SPELLS_CHANGED",
                         "PLAYER_SPECIALIZATION_CHANGED", "UPDATE_SHAPESHIFT_FORM", "PLAYER_REGEN_ENABLED" }) do
        pcall(ev.RegisterEvent, ev, e)
    end
    ev:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
            applyHold()
            if C_Timer and C_Timer.After then C_Timer.After(3, function() applyHold(); applyCenterAim(); applyHeight(); applyGround() end) end
            return
        end
        if event == "PLAYER_REGEN_ENABLED" then
            if dirty then applyGround() end
            return
        end
        applyGroundSoon()
    end)
end

-- /ubaim : says what the aiming mark sees right now (for finding out why it does not show).
SLASH_UBERMOCAIM1 = "/ubaim"
SlashCmdList["UBERMOCAIM"] = function()
    local d = DB()
    local function yn(v) return v and "yes" or "no" end
    local function say(t) print("|cff66ccffUbermoc UI aim|r " .. t) end
    say("mark on: " .. yn(d.mark) .. ", show: " .. tostring(d.when) .. ", shape: " .. tostring(d.style) .. " " .. tostring(d.size) .. " px")
    say("game is waiting for a spot: " .. yn(SpellIsTargeting and SpellIsTargeting()) .. ", ground button held: " .. yn(held))
    say("controller camera on: " .. yn(cameraSteered()) .. ", centered pointer height: " .. string.format("%.3f", centerFraction()))
    local n = 0
    for _, prefix in ipairs(BARS) do for i = 1, 12 do local b = _G[prefix .. i]; if b and b.ubGround then n = n + 1 end end end
    say("action buttons set up for hold-and-release: " .. n)
    local okT, tv = pcall(GetCVar, TCV)
    say("aim height setting: " .. tostring(d.height) .. "%")
    say("game setting " .. TCV .. ": " .. tostring(okT and tv or "not found") .. ", keep aim in the middle: " .. yn(d.center))
    say("mark frame shown: " .. yn(mark and mark:IsShown()))
    API.aimPreview()
    say("showing the mark for 3 seconds now")
end

-- /ubground add Name | remove Name | list : more ground spells (by name) besides the built-in ones; spells that open a reticle are added by themselves.
SLASH_UBERMOCGROUND1 = "/ubground"
SlashCmdList["UBERMOCGROUND"] = function(msg)
    local cmd, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
    local d = DB()
    local function say(t) print("|cff66ccffUbermoc UI|r " .. t) end
    if cmd == "add" and rest ~= "" then
        for _, n in ipairs(d.extra) do if n:lower() == rest:lower() then say(rest .. " is already in the list."); return end end
        d.extra[#d.extra + 1] = rest
        applyGround(); say("Added " .. rest .. ". Hold its button to aim, release to cast.")
    elseif cmd == "remove" and rest ~= "" then
        for i, n in ipairs(d.extra) do if n:lower() == rest:lower() then table.remove(d.extra, i); applyGround(); say("Removed " .. n .. "."); return end end
        say(rest .. " is not in your list.")
    else
        say("Extra ground spells: " .. (#d.extra > 0 and table.concat(d.extra, ", ") or "none") .. ". Use /ubground add Spell Name or /ubground remove Spell Name.")
    end
end

----------------------------------------------------------------------
-- The page section (Miscellaneous > Aiming). Returns a function that reads the settings again.
----------------------------------------------------------------------
function API.buildAim(sc, y0)
    local refreshers = {}
    local function note(text, x, y)
        local fs = API.newLabel(sc, text, x, y, "GameFontHighlightSmall")
        fs:SetWidth(520); fs:SetJustifyH("LEFT"); fs:SetWordWrap(true)
        return fs
    end
    local function refresh() for _, r in ipairs(refreshers) do r() end end
    local function changed() pcall(layout); if mark then mark.ubSig = nil end end

    API.newLabel(sc, "Aiming", 16, y0, "GameFontNormalLarge")
    local y = y0 - 32

    local holdCB = API.newCheck(sc, "Hold the button to aim a ground spell, release it to cast", 16, y, function(v)
        DB().hold = v
        applyHold()
        applyGround()
    end)
    refreshers[#refreshers + 1] = function() holdCB:SetChecked(DB().hold and true or false) end
    y = y - 32
    note(hasHeld()
        and "For Heroic Leap, Blizzard and other spells you place on the ground: hold the button to aim, let go to cast where the pointer is. Works for spells on the action bars; more than thirty are built in, and a missing one is learned the first time its button opens a reticle (or add it with /ubground add Spell Name). It needs the game's cast-on-press setting, which is switched on together with it."
        or "This game does not have the Press and Hold Casting setting, so there is nothing to switch on here.", 48, y)
    y = y - 70

    local centerCB = API.newCheck(sc, "Keep the aim in the middle of the screen while aiming a ground spell", 16, y, function(v)
        DB().center = v
        applyCenterAim()
    end)
    refreshers[#refreshers + 1] = function() centerCB:SetChecked(DB().center and true or false) end
    y = y - 32
    note("The game normally hands the aim to the sticks while a ground spell waits for a spot (its setting GamePadCursorForTargeting). With this on that is switched off, so the spell lands where the pointer rests in the middle of the screen, which is where the mark is. Your old setting is put back when you turn this off.", 48, y)
    y = y - 70

    API.newLabel(sc, "Aim height", 48, y - 4)
    local hs = API.makeSlider(sc, 140, 30, 90, 1, function(v) return math.floor(v + 0.5) .. "%" end,
        function(v) DB().height = math.floor(v + 0.5); applyHeight(); changed() end)
    hs:SetPoint("TOPLEFT", 240, y)
    refreshers[#refreshers + 1] = function() API.setSlider(hs, DB().height) end
    y = y - 34
    note("How high on the screen the aim rests, from the bottom. 70% by default. This is the game's own setting for the centered pointer, so the mark and the spell move together.", 48, y)
    y = y - 40

    API.newLabel(sc, "Crosshair or dot", 16, y, "GameFontNormalLarge")
    y = y - 32
    local markCB = API.newCheck(sc, "Show a mark in the middle of the screen while aiming a ground spell", 16, y, function(v)
        DB().mark = v
    end)
    refreshers[#refreshers + 1] = function() markCB:SetChecked(DB().mark and true or false) end
    y = y - 36

    API.newLabel(sc, "Show it", 48, y - 4)
    local whenSeg = API.segRow(sc, 200, y, { { "aim", "While aiming", 110 }, { "always", "Always (controller camera)", 190 } },
        function() return DB().when end, function(v) DB().when = v; changed() end)
    refreshers[#refreshers + 1] = function() whenSeg.refresh() end
    y = y - 40

    API.newLabel(sc, "Shape", 48, y - 4)
    local seg = API.segRow(sc, 200, y, { { "dot", "Dot", 70 }, { "cross", "Cross", 70 } },
        function() return DB().style end, function(v) DB().style = v; changed() end)
    refreshers[#refreshers + 1] = function() seg.refresh() end
    y = y - 40

    local function slider(label, key, min, max, fmt)
        API.newLabel(sc, label, 48, y - 4)
        local s = API.makeSlider(sc, 140, min, max, 1, fmt, function(v) DB()[key] = v; changed() end)
        s:SetPoint("TOPLEFT", 240, y)
        refreshers[#refreshers + 1] = function() API.setSlider(s, DB()[key]) end
        y = y - 38
    end
    local px = function(v) return math.floor(v + 0.5) .. " px" end
    slider("Size", "size", 4, 120, px)
    slider("Thickness", "thick", 1, 10, px)
    slider("Opacity", "a", 10, 100, function(v) return math.floor(v + 0.5) .. "%" end)
    slider("Left / right", "x", -400, 400, px)
    slider("Up / down", "y", -400, 400, px)

    API.newLabel(sc, "Colour", 48, y - 4)
    local swb = CreateFrame("Button", nil, sc)
    swb:SetSize(34, 26)
    swb:SetPoint("TOPLEFT", 240, y)
    API.flatButton(swb)
    local swt = swb:CreateTexture(nil, "ARTWORK")
    swt:SetPoint("TOPLEFT", 4, -4); swt:SetPoint("BOTTOMRIGHT", -4, 4)
    swb:SetScript("OnClick", function()
        local d = DB()
        API.pickColor(d.r, d.g, d.b, nil, function(r, g, b) d.r, d.g, d.b = r, g, b; changed(); refresh() end)
    end)
    refreshers[#refreshers + 1] = function() local d = DB(); swt:SetColorTexture(d.r, d.g, d.b, 1) end
    y = y - 40

    API.newButton(sc, "Show it for 3 seconds", 180, 48, y, function() API.aimPreview() end)
    API.newButton(sc, "Reset the mark", 140, 240, y, function()
        local dflt, d = defaults(), DB()
        for _, k in ipairs({ "when", "style", "size", "thick", "a", "x", "y", "r", "g", "b" }) do d[k] = dflt[k] end
        changed(); refresh()
    end)
    y = y - 40
    note("The mark shows only while a ground spell is being aimed. The spell lands where the mouse pointer is. The mark sits where the game keeps the centered pointer while you steer the camera with the controller; Left / right and Up / down move it from there. Choose Always to see it whenever the controller steers the camera. Type /ubaim to see what the mark sees.", 16, y)
    refresh()
    return refresh
end

-- The Aiming page (built the first time the settings window opens, like the other pages).
if API.later then
    API.later("Aiming", function()
        local panel = CreateFrame("Frame")
        panel.name = "Aiming"
        local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 0, -48)
        scroll:SetPoint("BOTTOMRIGHT", -30, 8)
        local sc = CreateFrame("Frame", nil, scroll)
        sc:SetSize(600, 900)
        scroll:SetScrollChild(sc)
        local refresh = API.buildAim(sc, -16)
        panel:SetScript("OnShow", function() refresh(); if API.evaluate then API.evaluate() end end)
        API.addPage("aim", "Aiming", panel)
    end)
end
