-- Ubermoc UI - Copyright (c) 2026 Marcos. All rights reserved.
-- This file is protected by copyright. It may not be copied, modified, redistributed or reused, in whole or
-- in part, without the written permission of the author. See LICENSE.txt.
-- Cinematic camera for NPC conversations: when an NPC starts talking, the camera eases in close, frames you and
-- the NPC side by side, can slowly circle around you both, and the rest of the screen steps back (interface
-- fades, black bars, darker edges, names hidden, world sound softer). Everything is put back when the talk ends,
-- when combat starts, or after a reload in the middle of a conversation.
local API = UbermocUIAPI
if not API then return end

local DEFAULTS = {
    on = true, zoom = 4, neverOut = false, face = 100, side = 1.0, fov = 75, angle = 15,
    spin = false, spinDir = "left", spinSpeed = 6, spinDelay = 1.5, swingBack = true, spinZoom = 7, spinAim = 50,
    framing = "shoulder", sideFrom = "right", otsSide = "right", otsZoom = 12, otsOffset = 0.9, sideZoom = 14,
    uiAlpha = 0, bars = 20, vignette = 100, hideNames = true, sound = 40, fade = 2, mounted = true,
}

local function DB()
    UbermocUIDB = UbermocUIDB or {}
    local d = UbermocUIDB.cine
    if type(d) ~= "table" then d = {}; UbermocUIDB.cine = d end
    if not d.v2 then   -- 0.99.141: the NPC in the centre is the new starting framing, the lens and turn now work
        d.v2 = true
        d.framing, d.face, d.fov = "center", 100, 75
    end
    if not d.v3 then   -- 0.99.151: the camera distances for the two-person framings start much further back
        d.v3 = true
        if (d.otsZoom or 0) < 8 then d.otsZoom = 12 end
    end
    if not d.v4 then   -- 0.99.167: new starting values; the slow circle is gone
        d.v4 = true
        d.bars, d.vignette, d.fade = 20, 100, 2
    end
    if not d.v5 then d.v5 = true; d.neverOut = false end   -- 0.99.170: "Never zoom out" starts off
    if not d.v6 then d.v6 = true; d.framing, d.mounted = "shoulder", true end   -- 0.99.188: over the shoulder and "also when mounted" start selected
    d.spin = false
    for k, v in pairs(DEFAULTS) do if d[k] == nil then d[k] = v end end
    return d
end

local getCVar = (C_CVar and C_CVar.GetCVar) or GetCVar
local rawSetCVar = (C_CVar and C_CVar.SetCVar) or SetCVar

local NAME_CVARS = {
    "UnitNameOwn", "UnitNameNonCombatCreatureName", "UnitNameFriendlyPlayerName", "UnitNameFriendlyPetName",
    "UnitNameFriendlyMinionName", "UnitNameFriendlyGuardianName", "UnitNameFriendlySpecialNPCName",
    "UnitNameEnemyPlayerName", "UnitNameEnemyPetName", "UnitNameEnemyGuardianName", "UnitNameNPC",
    "UnitNameInteractiveNPC", "UnitNameHostleNPC",
}
local PLATE_CVARS = { "nameplateShowAll", "nameplateShowEnemies", "nameplateShowFriends", "nameplateShowFriendlyNPCs" }
local SOUND_CVARS = { "Sound_MusicVolume", "Sound_AmbienceVolume", "Sound_SFXVolume" }   -- voices stay as they are
-- Name and nameplate settings can't change during a fight; they are put back once it is over.
local function combatOnly(cvar) return cvar:find("^UnitName") or cvar:find("^nameplate") end

-- The game asks to confirm its experimental camera options. While a conversation is framed that question
-- is skipped (it would sit on top of the scene); it is allowed again a moment after everything is put back.
local expMuted, expToken = false, 0
local function muteExperimental(on)
    local ui = UIParent
    if not (ui and ui.UnregisterEvent) then return end
    expToken = expToken + 1
    if on then
        if not expMuted then expMuted = pcall(ui.UnregisterEvent, ui, "EXPERIMENTAL_CVAR_CONFIRMATION_NEEDED") end
    elseif expMuted then
        local tok = expToken
        C_Timer.After(2, function()
            if tok == expToken and expMuted then
                expMuted = false
                pcall(ui.RegisterEvent, ui, "EXPERIMENTAL_CVAR_CONFIRMATION_NEEDED")
            end
        end)
    end
end

-- Every camera setting change goes through here, so the game's experimental-camera question never comes up
-- (the settings are simply kept, as if it had been accepted).
local function setCVar(cvar, value)
    muteExperimental(true)
    local ok, r = pcall(rawSetCVar, cvar, value)
    muteExperimental(false)
    if not ok then error(r, 0) end
    return r
end

-- How low the camera may look (the game's pitch limit, 88 is its usual value).
local function pitchLimit(deg)
    if ConsoleExec then muteExperimental(true); pcall(ConsoleExec, "pitchlimit " .. math.floor(deg + 0.5)); muteExperimental(false) end
end

-- Every CVar changed is saved first (in the saved settings, so a reload mid-talk still puts it back).
local function backup() local d = DB(); d.backup = d.backup or {}; return d.backup end
local function put(cvar, value)
    local cur = getCVar(cvar)
    if cur == nil then return end
    local b = backup()
    if b[cvar] == nil then b[cvar] = cur end
    muteExperimental(true)
    pcall(setCVar, cvar, tostring(value))
end
local function restoreAll(onlyCombatSafe, keepPitch)
    local d = DB()
    local b = d.backup
    if not b then return end
    muteExperimental(true)
    for cvar, v in pairs(b) do
        -- while easing back, the lens is brought back by the picture's own fade (then cleared there)
        if not (onlyCombatSafe and combatOnly(cvar)) and not (keepPitch and cvar == "cameraFov") then
            if pcall(setCVar, cvar, v) then b[cvar] = nil end
        end
    end
    if d.pitched and not keepPitch then pitchLimit(88); d.pitched = nil end
    muteExperimental(false)
    if next(b) == nil then d.backup = nil end
end

----------------------------------------------------------------------
-- Screen dressing: black bars and darker edges (own art: plain colour and gradients)
----------------------------------------------------------------------
local dress
local function makeDress()
    if dress then return dress end
    dress = CreateFrame("Frame", "UbermocCinematic", UIParent)
    -- The whole screen, also where the interface is kept narrower than the screen (wide screens).
    dress:SetAllPoints(WorldFrame or UIParent)
    dress:SetFrameStrata("BACKGROUND")
    dress:SetFrameLevel(1)
    dress:EnableMouse(false)
    if dress.SetIgnoreParentAlpha then dress:SetIgnoreParentAlpha(true) end
    local function solid(layer)
        local t = dress:CreateTexture(nil, layer)
        t:SetColorTexture(0, 0, 0, 1)
        return t
    end
    dress.top = solid("ARTWORK"); dress.top:SetPoint("TOPLEFT"); dress.top:SetPoint("TOPRIGHT")
    dress.bot = solid("ARTWORK"); dress.bot:SetPoint("BOTTOMLEFT"); dress.bot:SetPoint("BOTTOMRIGHT")
    local function edge(a1, a2, orient, fromDark)
        local t = dress:CreateTexture(nil, "BACKGROUND")
        t:SetTexture("Interface\\Buttons\\WHITE8x8")
        t:SetPoint(a1); t:SetPoint(a2)
        t.orient, t.fromDark = orient, fromDark
        return t
    end
    dress.edges = {
        edge("TOPLEFT", "BOTTOMLEFT", "HORIZONTAL", true),     -- left: dark at the edge
        edge("TOPRIGHT", "BOTTOMRIGHT", "HORIZONTAL", false),  -- right
        edge("TOPLEFT", "TOPRIGHT", "VERTICAL", false),        -- top
        edge("BOTTOMLEFT", "BOTTOMRIGHT", "VERTICAL", true),   -- bottom
    }
    dress:Hide()
    return dress
end

local function paintDress(k)
    local d = DB()
    local D = makeDress()
    local h = D:GetHeight() or 0
    local w = D:GetWidth() or 0
    if h <= 1 then h = UIParent:GetHeight() or 768 end
    if w <= 1 then w = UIParent:GetWidth() or 1024 end
    local barH = math.floor(h * (d.bars or 0) / 100 * k + 0.5)
    D.top:SetHeight(math.max(0.01, barH)); D.top:SetShown(barH >= 1)
    D.bot:SetHeight(math.max(0.01, barH)); D.bot:SetShown(barH >= 1)
    local a = (d.vignette or 0) / 100 * k
    for i, t in ipairs(D.edges) do
        local size = (i <= 2) and w * 0.22 or h * 0.22
        if i <= 2 then t:SetWidth(size) else t:SetHeight(size) end
        local dark, clear = { 0, 0, 0, a }, { 0, 0, 0, 0 }
        local c1, c2 = dark, clear
        if not t.fromDark then c1, c2 = clear, dark end
        local ok = CreateColor and pcall(t.SetGradient, t, t.orient, CreateColor(unpack(c1)), CreateColor(unpack(c2)))
        if not ok then t:SetVertexColor(0, 0, 0, a * 0.5) end
        t:SetShown(a > 0.001)
    end
    D:SetShown(k > 0.001)
end

-- Frames that stay visible while the rest of the interface fades.
local KEEP = { "UbermocDialogue", "GossipFrame", "QuestFrame", "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1",
               "ShoppingTooltip2", "StaticPopup1", "StaticPopup2", "StaticPopup3", "StaticPopup4", "UbermocCursor" }
local kept = {}   -- frame -> its earlier ignore-parent-alpha setting
local function keepVisible(on)
    if on then
        for _, n in ipairs(KEEP) do
            local f = _G[n]
            if f and f.SetIgnoreParentAlpha and kept[f] == nil and not (f.IsForbidden and f:IsForbidden()) then
                local ok, was = pcall(f.GetIgnoreParentAlpha, f)
                kept[f] = ok and was or false
                pcall(f.SetIgnoreParentAlpha, f, true)
            end
        end
    else
        for f, was in pairs(kept) do pcall(f.SetIgnoreParentAlpha, f, was) end
        wipe(kept)
    end
end

----------------------------------------------------------------------
-- The camera
----------------------------------------------------------------------
local S = { active = false, k = 0, goal = 0 }
local drv = CreateFrame("Frame")

local function spinFn(dir, start)
    if dir == "right" then return start and MoveViewRightStart or MoveViewRightStop end
    return start and MoveViewLeftStart or MoveViewLeftStop
end
local function spinStop()
    if S.spinning then
        local stop = spinFn(S.spinning)
        if stop then pcall(stop) end
        S.spinning = nil
    end
end
local TURN_RATE = 90   -- degrees per second for the quarter turn in side by side
local SWING = 3   -- swinging back runs this many times faster than the circling

local function zoomTo(goal, allowOut)
    if not GetCameraZoom then return end
    local cur = GetCameraZoom() or goal
    if cur > goal + 0.05 then pcall(CameraZoomIn, cur - goal)
    elseif allowOut and cur < goal - 0.05 then pcall(CameraZoomOut, goal - cur) end
end

local function talking()
    if S.preview then return GetTime() < S.preview end
    local function shown(n) local f = _G[n]; return f and f.IsShown and f:IsShown() end
    if shown("UbermocDialogue") and not (API.npcMode and API.npcMode() == "preview") then return true end
    return shown("GossipFrame") or shown("QuestFrame")
end

local function stop(snap)
    if not S.active then return end
    S.active, S.goal, S.preview, S.spinAt = false, 0, nil, nil
    S.turnAt, S.zoomWant, S.zoomSpan, S.zoomPhase = nil, nil, nil, nil
    if S.turnUntil then local f = spinFn(S.turnDir); if f then pcall(f) end; S.turnUntil, S.turned = nil, S.turnDir end
    if S.turned then   -- swing the quarter turn back
        local back = S.turned == "left" and "right" or "left"
        S.turned = nil
        if not snap and not InCombatLockdown() then
            local go = spinFn(back, true)
            if go and pcall(go, TURN_RATE / 180 * 1.5) then S.backDir = back; S.swingUntil = GetTime() + 90 / (TURN_RATE * 1.5) end
        end
    end
    -- circle back the way it came, faster
    if S.spinning and S.spinStart then
        local spun = GetTime() - S.spinStart
        local dir = S.spinning
        spinStop()
        if DB().swingBack and spun > 0.2 and not snap and not InCombatLockdown() then
            local back = dir == "left" and "right" or "left"
            local go = spinFn(back, true)
            if go and pcall(go, (DB().spinSpeed or 6) / 180 * SWING) then
                S.spinning = back
                S.swingUntil = GetTime() + spun / SWING
            end
        end
    else
        spinStop()
    end
    if S.oldZoom then
        local old = S.oldZoom
        S.oldZoom = nil
        local cur = GetCameraZoom and GetCameraZoom()
        if cur then
            if old > cur + 0.05 then
                if not DB().neverOut then pcall(CameraZoomOut, old - cur) end elseif old < cur - 0.05 then pcall(CameraZoomIn, cur - old) end
        end
    end
    restoreAll(InCombatLockdown(), not snap)   -- the camera angle eases back with the picture
    if snap then S.k = 0; paintDress(0); UIParent:SetAlpha(1); keepVisible(false); if API.abarRefresh then API.abarRefresh() end end
    drv:Show()
end

local function start(preview)
    local d = DB()
    if S.active or InCombatLockdown() then return end
    if not preview and not d.on then return end
    local em = _G.EditModeManagerFrame
    if em and em.IsShown and em:IsShown() then return end
    if not preview and not d.mounted and IsMounted and IsMounted() then return end
    S.active, S.goal = true, 1
    S.preview = preview and (GetTime() + 12) or nil
    S.baseFov = tonumber(getCVar("cameraFov") or "") or 90
    if d.backup and d.backup.cameraFov then S.baseFov = tonumber(d.backup.cameraFov) or S.baseFov end
    if (d.fov or 90) ~= S.baseFov then put("cameraFov", S.baseFov) end   -- saved, then eased toward the lens setting

    -- framing: the NPC in the centre (the camera turns and tilts to look straight at it), side by side (turn
    -- toward it as much as you set, shifted sideways), or over your shoulder (close behind you, looking at the
    -- NPC past one shoulder). The camera is also brought down toward eye level (the pitch limit), and the head
    -- bob is steadied.
    local ots = d.framing == "shoulder"
    local center = d.framing == "center"
    local sideBy = d.framing == "side" and not d.spin
    local face = (ots or center or sideBy) and 100 or (d.face or 0)
    local side = (ots and ((d.otsSide == "left" and -1 or 1) * (d.otsOffset or 0.9))) or (center and 0) or (d.side or 0)
    if face > 0 then
        put("test_cameraTargetFocusInteractEnable", 1)
        put("test_cameraTargetFocusInteractStrengthPitch", string.format("%.2f", face / 100))
        put("test_cameraTargetFocusInteractStrengthYaw", string.format("%.2f", d.spin and 0 or face / 100))
    end
    -- side by side: the camera first lines up behind you looking at the NPC, then swings a quarter turn so that
    -- you and the NPC stand next to each other across the picture
    S.turnAt = sideBy and (GetTime() + 0.7) or nil
    S.turned = nil
    d.pitched = true
    S.angle = d.angle or 15
    if side ~= 0 then
        put("CameraKeepCharacterCentered", 0)
        put("CameraReduceUnexpectedMovement", 0)
        put("test_cameraOverShoulder", string.format("%.2f", side))
    end
    put("test_cameraHeadMovementStrength", 0)
    if d.hideNames then
        for _, c in ipairs(NAME_CVARS) do put(c, 0) end
        for _, c in ipairs(PLATE_CVARS) do put(c, 0) end
    end
    if (d.sound or 0) > 0 then
        for _, c in ipairs(SOUND_CVARS) do
            local v = tonumber(getCVar(c) or "")
            if v then put(c, string.format("%.3f", v * (1 - d.sound / 100))) end
        end
    end
    -- zoom in (and out only when allowed)
    S.oldZoom = GetCameraZoom and GetCameraZoom()
    S.zoomWant = (ots and math.max(8, d.otsZoom or 12)) or (d.spin and (d.spinZoom or 7))
        or (d.framing == "side" and math.max(10, d.sideZoom or 14)) or (d.zoom or 4)
    S.zoomOut = d.spin or ots or d.framing == "side" or not d.neverOut
    -- The game moves the camera in by itself when an NPC starts talking. The distance is only set once that
    -- has come to rest (otherwise the camera runs all the way in and has to back out again).
    S.zoomLast, S.zoomAt, S.zoomIdle, S.zoomSpan = nil, nil, 0, nil
    S.zoomPhase, S.zoomWaitEnd, S.zoomWaitOk, S.zoomWaitLast, S.zoomWaitT = "wait", GetTime() + 1.2, 0, nil, 0
    if API.abarRefresh then API.abarRefresh() end
    -- slow circle around you both, after a short pause
    S.spinAt = d.spin and (GetTime() + (d.spinDelay or 0)) or nil
    if (d.uiAlpha or 0) < 100 then keepVisible(true) end
    drv:Show()
end

API.cineStart = start
API.cineStop = stop
API.cineActive = function() return S.active end
-- How visible the interface is right now (1 = as usual), for parts that keep their own opacity.
API.cineUIAlpha = function() return (S.k > 0 and S.ua) or 1 end
-- Try it on whoever you are looking at, from the settings page (press again to end it).
API.cinePreview = function()
    if S.active then stop() else start(true) end
end

local lastSeen = 0
drv:Hide()
drv:SetScript("OnUpdate", function(self, dt)
    local d = DB()
    local now = GetTime()
    -- ease the picture in / out
    local step = dt / math.max(0.05, d.fade or 0.6)
    if S.k < S.goal then
        local cap = S.goal
        if S.zoomPhase == "wait" then cap = 0 end
        if S.zoomSpan and S.zoomWant and GetCameraZoom and now - (S.zoomStartT or now) < 5 then
            local cz = GetCameraZoom()
            if cz then cap = math.max(0, math.min(1, 1 - math.abs(cz - S.zoomWant) / S.zoomSpan)) end
            if cap > 0.97 then cap = S.goal end
        end
        S.k = math.max(S.k, math.min(cap, S.k + step)) elseif S.k > S.goal then S.k = math.max(S.goal, S.k - step) end
    local k = S.k
    paintDress(k)
    local ua = 1 - k * (1 - (d.uiAlpha or 0) / 100)
    if (d.uiAlpha or 0) < 100 or k == 0 then UIParent:SetAlpha(ua) end
    S.ua = ua
    -- buttons that keep their own opacity (the action bars) follow the interface fade too
    if math.abs((S.uaSeen or 1) - ua) > 0.03 or (ua == 1 and S.uaSeen ~= 1) or (ua == 0 and S.uaSeen ~= 0) then
        S.uaSeen = ua
        if API.abarRefresh then API.abarRefresh() end
    end
    -- lens and camera angle ease in and out with the picture
    if S.baseFov and (d.fov or 90) ~= S.baseFov then
        local fv = string.format("%.1f", S.baseFov + (d.fov - S.baseFov) * k)
        if fv ~= S.fovSeen then S.fovSeen = fv; pcall(setCVar, "cameraFov", fv) end
    end
    if d.pitched then
        local lim = math.floor(88 - (88 - (S.angle or d.angle or 15)) * k + 0.5)
        if lim ~= S.pitchSeen then S.pitchSeen = lim; pitchLimit(lim) end
    end
    if S.active then
        if S.zoomPhase == "wait" then
            S.zoomWaitT = (S.zoomWaitT or 0) + dt
            if S.zoomWaitT >= 0.08 then
                S.zoomWaitT = 0
                local cz = GetCameraZoom and GetCameraZoom()
                if cz and S.zoomWaitLast and math.abs(cz - S.zoomWaitLast) < 0.03 then S.zoomWaitOk = S.zoomWaitOk + 1 else S.zoomWaitOk = 0 end
                S.zoomWaitLast = cz
                if S.zoomWaitOk >= 2 or now >= (S.zoomWaitEnd or 0) then
                    S.zoomPhase = nil
                    if cz and S.zoomWant then
                        zoomTo(S.zoomWant, S.zoomOut)
                        S.zoomSpan = (math.abs(cz - S.zoomWant) > 1) and math.abs(cz - S.zoomWant) or nil
                        S.zoomStartT = now
                        S.zoomLast, S.zoomAt, S.zoomIdle = nil, now + 0.6, 0
                    end
                end
            end
        end
        if S.spinAt and now >= S.spinAt then
            S.spinAt = nil
            -- Circling: the camera turns around your character, so it steps back far enough to keep you and the
            -- NPC in the picture all the way round, sits straight behind (no side offset), and aims part of the
            -- way toward the NPC, so it looks at the space between you both.
            put("test_cameraOverShoulder", "0")
            put("test_cameraTargetFocusInteractEnable", 1)
            put("test_cameraTargetFocusInteractStrengthYaw", string.format("%.2f", (d.spinAim or 50) / 100))
            S.zoomWant, S.zoomOut, S.zoomLast = d.spinZoom or 7, true, nil
            zoomTo(S.zoomWant, true)
            local go = spinFn(d.spinDir, true)
            if go and pcall(go, (d.spinSpeed or 6) / 180) then S.spinning, S.spinStart = d.spinDir, now end
        end
        if S.turnAt and now >= S.turnAt then
            S.turnAt = nil
            local dir = d.sideFrom == "left" and "left" or "right"
            put("test_cameraTargetFocusInteractStrengthYaw", "0")
            local go = spinFn(dir, true)
            if go and pcall(go, TURN_RATE / 180) then S.turnDir = dir; S.turnUntil = now + 90 / TURN_RATE end
        end
        if S.turnUntil and now >= S.turnUntil then
            S.turnUntil = nil
            local f = spinFn(S.turnDir); if f then pcall(f) end
            S.turned = S.turnDir
        end
        -- keep nudging the distance until the camera has settled at the wanted one (a zoom asked for while the
        -- camera is still moving otherwise ends up short or long)
        if S.zoomWant and S.zoomAt and now >= S.zoomAt and GetCameraZoom then
            S.zoomAt = now + 0.35
            local cur = GetCameraZoom()
            if cur then
                if S.zoomLast and math.abs(cur - S.zoomLast) < 0.05 and math.abs(cur - S.zoomWant) > 0.3 then
                    S.zoomIdle = (S.zoomIdle or 0) + 1
                    -- only after it has really stopped (two checks in a row), so a zoom under way is never doubled
                    if S.zoomIdle >= 2 then S.zoomIdle = 0; zoomTo(S.zoomWant, S.zoomOut) end
                else
                    S.zoomIdle = 0
                end
                S.zoomLast = cur
            end
        end
        -- the conversation is over once no dialogue window has been up for a moment
        if talking() then lastSeen = now elseif now - lastSeen > 0.5 then stop() end
    else
        if S.swingUntil and now >= S.swingUntil then
            S.swingUntil = nil; spinStop()
            if S.backDir then local f = spinFn(S.backDir); if f then pcall(f) end; S.backDir = nil end
        end
        if S.swingUntil and S.swingUntil - now > 5 then S.swingUntil = now end   -- never hangs on
        if k <= 0 and not S.swingUntil then
            UIParent:SetAlpha(1)
            keepVisible(false)
            if S.baseFov then pcall(setCVar, "cameraFov", tostring(S.baseFov)); S.baseFov = nil end
            S.fovSeen = nil
            if d.backup then d.backup.cameraFov = nil; if next(d.backup) == nil then d.backup = nil end end
            if d.pitched then pitchLimit(88); d.pitched = nil end
            S.pitchSeen = nil
            if API.abarRefresh then API.abarRefresh() end
            self:Hide()
        end
    end
end)

local ev = CreateFrame("Frame")
for _, e in ipairs({ "GOSSIP_SHOW", "QUEST_GREETING", "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE",
                     "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_LOGIN", "CINEMATIC_START", "PLAY_MOVIE" }) do
    pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        restoreAll(false)   -- a reload in the middle of a conversation
        return
    end
    if event == "PLAYER_REGEN_DISABLED" or event == "CINEMATIC_START" or event == "PLAY_MOVIE" then
        stop(true)
        return
    end
    if event == "PLAYER_REGEN_ENABLED" then
        if not S.active and DB().backup then restoreAll(false) end   -- names hidden when combat began
        return
    end
    -- someone to talk to (not a quest that pops up on its own)
    local ok, real = pcall(function() return UnitExists("npc") and not UnitIsUnit("npc", "player") end)
    if ok and real == false then return end
    lastSeen = GetTime()
    start(false)
end)

----------------------------------------------------------------------
-- Settings (shown as the Cinematic Camera tab of the NPC Dialogue page)
----------------------------------------------------------------------
function API.cineSettings(p, y0)
    local refresh = {}
    local function reapply()
        if S.active then
            local pv = S.preview
            stop(true); start(pv ~= nil)
        end
    end
    local y = y0
    API.newLabel(p, "Cinematic camera", 16, y, "GameFontNormalLarge")
    y = y - 30
    local intro = API.newLabel(p, "When an NPC talks to you, the camera eases in, frames you and the NPC side by side, and the rest of the screen steps back. Everything goes back to how it was when the talk ends or a fight starts.", 16, y, "GameFontHighlightSmall")
    intro:SetWidth(580); intro:SetJustifyH("LEFT"); intro:SetWordWrap(true)
    y = y - 50
    local function check(text, key, after)
        local cb = API.newCheck(p, text, 16, y, function(v) DB()[key] = v; if after then after() end; reapply() end)
        refresh[#refresh + 1] = function() cb:SetChecked(DB()[key] and true or false) end
        y = y - 34
        return cb
    end
    local function slider(label, key, min, max, stepv, fmt, def)
        API.newLabel(p, label, 40, y - 4)
        local s
        s = API.makeSlider(p, 150, min, max, stepv, fmt, function(v)
            local c = math.max(min, math.min(max, v))   -- wide ranges are not held in by the slider itself
            DB()[key] = c
            if c ~= v and s then API.setSlider(s, c) end
            reapply()
        end)
        s:SetPoint("TOPLEFT", 260, y)
        if API.sliderDefault then API.sliderDefault(s, def) end
        refresh[#refresh + 1] = function() API.setSlider(s, DB()[key]) end
        y = y - 40
        return s
    end
    local function seg(label, key, opts)
        API.newLabel(p, label, 40, y - 4)
        local r = API.segRow(p, 228, y, opts, function() return DB()[key] end, function(v)
            DB()[key] = v; reapply()
            for _, fn in ipairs(refresh) do fn() end
        end)
        refresh[#refresh + 1] = r.refresh
        y = y - 40
        return r
    end
    local function head(t) y = y - 6; API.newLabel(p, t, 16, y, "GameFontNormal"); y = y - 26 end
    local yd = function(v) return string.format("%.1f yd", v) end
    local pct = function(v) return math.floor(v + 0.5) .. "%" end
    local sec = function(v) return string.format("%.1f s", v) end

    check("Use the cinematic camera when talking to NPCs", "on")
    API.newButton(p, "Try it on your target", 190, 40, y, function() API.cinePreview() end)
    local tip = API.newLabel(p, "Press again to end it. Lasts 12 seconds.", 244, y - 6, "GameFontHighlightSmall")
    y = y - 40

    head("Camera")
    seg("Framing", "framing", { { "center", "NPC in the centre", 140 }, { "side", "Side by side", 110 }, { "shoulder", "Over the shoulder", 140 } })
    slider("Camera height (low to high)", "angle", 5, 60, 1, function(v) return math.floor(v + 0.5) .. "°" end, DEFAULTS.angle)
    local sideW = {
        slider("Distance", "zoom", 1, 15, 0.5, yd, DEFAULTS.zoom),
        slider("Distance (side by side)", "sideZoom", 10, 25, 0.5, yd, DEFAULTS.sideZoom),
        seg("Camera sits", "sideFrom", { { "left", "Left", 80 }, { "right", "Right", 80 } }),
        slider("Side offset (both in view)", "side", -30, 30, 0.5, yd, DEFAULTS.side),
    }
    local otsW = {
        seg("Shoulder", "otsSide", { { "left", "Left", 80 }, { "right", "Right", 80 } }),
        slider("Distance (over the shoulder)", "otsZoom", 8, 25, 0.5, yd, DEFAULTS.otsZoom),
        slider("Shoulder offset", "otsOffset", 0, 30, 0.1, yd, DEFAULTS.otsOffset),
    }
    -- the settings of the framing not in use are greyed out
    refresh[#refresh + 1] = function()
        local fr = DB().framing
        if API.setActive then
            for i, w in ipairs(sideW) do API.setActive(w, (fr == "side" and i > 1) or (fr == "center" and i == 1)) end
            for _, w in ipairs(otsW) do API.setActive(w, fr == "shoulder") end
        end
    end
    check("Never zoom out (centre framing keeps a closer view; the camera stays put when the talk ends)", "neverOut")
    slider("Lens (field of view)", "fov", 50, 90, 1, function(v) return math.floor(v + 0.5) .. "°" end, DEFAULTS.fov)
    slider("Ease in / out time", "fade", 0.1, 5, 0.1, sec, DEFAULTS.fade)
    check("Also when mounted", "mounted")

    head("Immersion")
    slider("Interface while talking", "uiAlpha", 0, 100, 5, pct, DEFAULTS.uiAlpha)
    slider("Black bars", "bars", 0, 20, 1, pct, DEFAULTS.bars)
    slider("Darker edges", "vignette", 0, 100, 5, pct, DEFAULTS.vignette)
    slider("Softer world sound (voices stay)", "sound", 0, 100, 5, pct, DEFAULTS.sound)
    check("Hide names and nameplates", "hideNames")
    local note = API.newLabel(p, "Interface at 0% leaves only the dialogue window, tooltips and the controller pointer.", 16, y, "GameFontHighlightSmall")
    note:SetWidth(580); note:SetJustifyH("LEFT"); note:SetWordWrap(true)
    y = y - 50
    API.newButton(p, "Reset the cinematic camera", 220, 16, y, function()
        local b = UbermocUIDB.cine and UbermocUIDB.cine.backup
        UbermocUIDB.cine = { backup = b }
        DB()
        for _, fn in ipairs(refresh) do fn() end
        reapply()
    end)
    y = y - 40
    return y, function() for _, fn in ipairs(refresh) do fn() end end
end
