-- Ubermoc UI - Copyright (c) 2026 Marcos. All rights reserved.
-- This file is protected by copyright. It may not be copied, modified, redistributed or reused, in whole or
-- in part, without the written permission of the author. See LICENSE.txt.
----------------------------------------------------------------------
-- Ubermoc UI: window trace
-- "/ubwatch on" prints, in chat, who opens and closes the game's windows (the professions book, the spellbook and so on)
-- with a short call list, to find what closes a window right after it opens. "/ubwatch off" stops. Only looks: nothing is
-- changed, the hooks run after the game's own functions.
----------------------------------------------------------------------
local API = UbermocUIAPI
if not API then return end

local on = false
local WATCH = { ProfessionsBookFrame = true, PlayerSpellsFrame = true, CharacterFrame = true, WorldMapFrame = true }

local function name(f)
    local ok, n = pcall(function() return f and f.GetName and f:GetName() end)
    return ok and n or nil
end

local function say(tag, level)
    if not on then return end
    local stack = (debugstack and debugstack(level or 3, 7, 0)) or ""
    print("|cff66ccffUbermoc trace|r " .. string.format("%.2f", GetTime()) .. " " .. tag)
    for line in stack:gmatch("[^\n]+") do
        local short = line:gsub("^.*[/\\]AddOns[/\\]", ""):gsub("^%[string \"", "")
        print("   " .. short:sub(1, 110))
    end
end

local hooked = {}
local function hookFrame(f)
    local n = name(f)
    if not n or hooked[n] or not f.HookScript then return end
    hooked[n] = true
    f:HookScript("OnShow", function() say(n .. " shown", 2) end)
    f:HookScript("OnHide", function() say(n .. " HIDDEN", 2) end)
end

local function findFrames()
    for n in pairs(WATCH) do
        local f = _G[n]
        if f then pcall(hookFrame, f) end
    end
end

for _, fn in ipairs({ "ToggleProfessionsBook", "ToggleCharacter", "ToggleSpellBook", "CloseAllWindows" }) do
    if type(_G[fn]) == "function" then
        hooksecurefunc(fn, function(...) say(fn .. " called", 3); C_Timer.After(0.05, findFrames) end)
    end
end
for _, fn in ipairs({ "HideUIPanel", "ToggleFrame" }) do
    if type(_G[fn]) == "function" then
        hooksecurefunc(fn, function(f)
            local n = name(f)
            if n and WATCH[n] then say(fn .. "(" .. n .. ")", 3) end
        end)
    end
end

SLASH_UBERMOCWATCH1 = "/ubwatch"
SlashCmdList["UBERMOCWATCH"] = function(msg)
    msg = (msg or ""):lower():match("^%s*(%S*)")
    if msg == "on" then on = true; findFrames(); print("Ubermoc UI: window trace on. Open the window, then read the lines above.")
    elseif msg == "off" then on = false; print("Ubermoc UI: window trace off.")
    else print("Ubermoc UI: /ubwatch on | off (who opens and closes the game's windows).") end
end
