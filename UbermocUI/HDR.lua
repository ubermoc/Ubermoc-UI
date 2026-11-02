-- HDR settings: WoW's own HDR console variables on the Miscellaneous page (HDR tab). Only the settings this
-- game has are shown, and everything is written straight to the game, so it matches Options.
local API = UbermocUIAPI

local function getcv(name)
    local ok, v = pcall(C_CVar and C_CVar.GetCVar or GetCVar, name)
    if ok then return v end
end
local function setcv(name, v) pcall(C_CVar and C_CVar.SetCVar or SetCVar, name, tostring(v)) end
local function defaultcv(name)
    if not (C_CVar and C_CVar.GetCVarDefault) then return nil end
    local ok, v = pcall(C_CVar.GetCVarDefault, name)
    if ok then return v end
end
local function has(name) return getcv(name) ~= nil end
local ALL = { "HDROutput", "RenderFormat", "useHDRBrightness", "HDRBrightness", "useHDRPeakBrightness", "HDRPeakBrightness", "HDRFactor" }
local function say(text)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffUbermoc UI HDR:|r " .. text) end
end
-- One line for chat: which of the game's HDR settings this game has.
local function report()
    local found, missing = {}, {}
    for _, n in ipairs(ALL) do (has(n) and found or missing)[#(has(n) and found or missing) + 1] = n end
    local v = (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata("UbermocUI", "Version")) or "?"
    say("addon " .. tostring(v) .. ", " .. #found .. " of " .. #ALL .. " HDR settings found in this game"
        .. (#missing > 0 and (" (missing: " .. table.concat(missing, ", ") .. ")") or "")
        .. ", options page " .. (API.hdrSettingsDone and "made" or "not made") .. ".")
end

-- A tooltip on mouse-over.
local function tip(frame, text)
    if not (frame and frame.HookScript and GameTooltip) then return end
    frame:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(text, 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    frame:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

-- The client does not report bounds for these, so they are set here.
local NITS = { min = 0, max = 2000, step = 25, fmt = function(v) return string.format("%d nits", v) end }
local FACTOR = { min = 1, max = 10, step = 0.1, fmt = function(v) return string.format("%.1fx", v) end }

-- 0 (8-bit) is refused by the game, so it is only listed when it is already the value.
local FORMATS = {
    { 1, "10-bit (A2BGR10Unorm)" },
    { 2, "16-bit float (RGBA16F)" },
    { 3, "32-bit float (RGBA32F)" },
}

-- Builds the section at y0 on the page's scroll child sc. Returns a function that reads the settings again.
function API.buildHDR(sc, y0)
    local refreshers, names = {}, {}
    local function note(text, x, y)
        local fs = API.newLabel(sc, text, x, y, "GameFontHighlightSmall")
        fs:SetWidth(520); fs:SetJustifyH("LEFT"); fs:SetWordWrap(true)
        return fs
    end
    local function refresh() for _, r in ipairs(refreshers) do r() end end

    API.newLabel(sc, "HDR", 16, y0, "GameFontNormalLarge")
    local y = y0 - 32

    local any = has("HDROutput") or has("RenderFormat") or has("HDRBrightness") or has("HDRPeakBrightness") or has("HDRFactor")
    if not any then
        note("This version of the game has no HDR settings.", 16, y)
        return refresh
    end

    if has("HDROutput") then
        names[#names + 1] = "HDROutput"
        local cb = API.newCheck(sc, "Enable HDR output", 16, y, function(v) setcv("HDROutput", v and "1" or "0") end)
        tip(cb, "Turns on HDR output, if the display and the render settings support it.")
        refreshers[#refreshers + 1] = function() cb:SetChecked(getcv("HDROutput") == "1") end
        y = y - 34
    end

    if has("RenderFormat") then
        names[#names + 1] = "RenderFormat"
        API.newLabel(sc, "Render format", 16, y - 4)
        local cyc = API.cycler(sc, 150, y, 190, function()
            local cur = tonumber(getcv("RenderFormat"))
            if cur == 0 then
                local list = { { 0, "8-bit (BGRA8Unorm)" } }
                for _, f in ipairs(FORMATS) do list[#list + 1] = f end
                return list
            end
            return FORMATS
        end, function() return tonumber(getcv("RenderFormat")) or 2 end, function(v) setcv("RenderFormat", v) end)
        tip(cyc and cyc.box, "Bits for each color channel. 10-bit is the lowest this game accepts. 16-bit float is the game's own choice. 32-bit float is the most precise and uses the most video memory.")
        y = y - 40
    end

    -- A switch that turns an override on, and the number it uses.
    local function override(switch, cvar, text, range, switchTip, valueTip)
        if not (has(switch) and has(cvar)) then return end
        names[#names + 1] = switch; names[#names + 1] = cvar
        local slider
        local cb = API.newCheck(sc, text, 16, y, function(v)
            setcv(switch, v and "1" or "0")
            if slider then API.setSliderActive(slider, v) end
        end)
        tip(cb, switchTip)
        slider = API.makeSlider(sc, 140, range.min, range.max, range.step, range.fmt, function(v) setcv(cvar, v) end)
        slider:SetPoint("TOPLEFT", 240, y - 34)
        tip(slider.box, valueTip)
        API.newLabel(sc, "Value", 48, y - 34)
        refreshers[#refreshers + 1] = function()
            local on = getcv(switch) == "1"
            cb:SetChecked(on)
            API.setSlider(slider, tonumber(getcv(cvar)) or range.min)
            API.setSliderActive(slider, on)
        end
        y = y - 76
    end
    override("useHDRBrightness", "HDRBrightness", "Override brightness", NITS,
        "Uses the brightness below instead of the brightness the game detects for the display.",
        "Brightness for HDR, in nits (cd/m2). Only used while the override is on.")
    override("useHDRPeakBrightness", "HDRPeakBrightness", "Override peak brightness", NITS,
        "Uses the peak brightness below instead of the peak brightness the game detects for the display.",
        "The brightest the display can go in HDR, in nits (cd/m2). Only used while the override is on.")

    if has("HDRFactor") then
        names[#names + 1] = "HDRFactor"
        API.newLabel(sc, "HDR factor", 16, y - 4)
        local s = API.makeSlider(sc, 140, FACTOR.min, FACTOR.max, FACTOR.step, FACTOR.fmt, function(v) setcv("HDRFactor", v) end)
        s:SetPoint("TOPLEFT", 240, y)
        tip(s.box, "How far above normal (SDR) lighting HDR may go. It is limited to the display's peak brightness.")
        refreshers[#refreshers + 1] = function() API.setSlider(s, tonumber(getcv("HDRFactor")) or 1) end
        y = y - 40
    end

    API.newButton(sc, "Reset HDR to game defaults", 220, 16, y, function()
        for _, n in ipairs(names) do
            local d = defaultcv(n)
            if d ~= nil then setcv(n, d) end
        end
        refresh()
    end)
    y = y - 38
    note("These are WoW's own HDR settings, the same ones the game keeps. HDR output also needs HDR switched on for the display in your operating system. Brightness is in nits. The HDR factor sets how far above normal lighting HDR may go, and is limited by the display's peak brightness.", 16, y)
    refresh()
    return refresh
end

-- The same settings in the game's own options (Options > AddOns > Ubermoc UI HDR). Registered when the addon loads, as the
-- game needs. Plain rows only: search tags
-- and parent rows added from an addon taint the game's options search, so they are left out.
function API.registerHDRSettings(parent)
    if API.hdrSettingsDone then return end
    if not (Settings and Settings.RegisterVerticalLayoutCategory and Settings.RegisterAddOnCategory and Settings.RegisterProxySetting
        and Settings.CreateCheckbox and Settings.CreateSlider and Settings.CreateDropdown and Settings.CreateSliderOptions) then return end
    if not (has("HDROutput") or has("RenderFormat") or has("HDRBrightness") or has("HDRPeakBrightness") or has("HDRFactor")) then return end
    local cat, layout = Settings.RegisterVerticalLayoutCategory("Ubermoc UI HDR")
    if not cat then return end
    Settings.RegisterAddOnCategory(cat)
    API.hdrSettingsDone = true
    local VT = Settings.VarType
    local function header(name)
        if layout and layout.AddInitializer and CreateSettingsListSectionHeaderInitializer then
            pcall(function() layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(name)) end)
        end
    end
    local function defNum(cvar, fallback) return tonumber(defaultcv(cvar)) or fallback end
    local function defBool(cvar)
        local d = defaultcv(cvar)
        return d ~= nil and d ~= "0"
    end
    local function checkbox(cvar, label, tooltip)
        local setting = Settings.RegisterProxySetting(cat, "UbermocUI_" .. cvar, VT.Boolean, label, defBool(cvar),
            function() return getcv(cvar) == "1" end, function(v) setcv(cvar, v and "1" or "0") end)
        Settings.CreateCheckbox(cat, setting, tooltip)
    end
    local function slider(cvar, label, range, tooltip)
        local setting = Settings.RegisterProxySetting(cat, "UbermocUI_" .. cvar, VT.Number, label, defNum(cvar, range.min),
            function() return tonumber(getcv(cvar)) or range.min end, function(v) setcv(cvar, v) end)
        local opts = Settings.CreateSliderOptions(range.min, range.max, range.step)
        if opts.SetLabelFormatter and MinimalSliderWithSteppersMixin then
            opts:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, range.fmt)
        end
        Settings.CreateSlider(cat, setting, opts, tooltip)
    end

    header("Output")
    if has("HDROutput") then
        checkbox("HDROutput", "Enable HDR Output", "Turns on HDR output, if the display and the render settings support it.")
    end
    if has("RenderFormat") then
        local setting = Settings.RegisterProxySetting(cat, "UbermocUI_RenderFormat", VT.Number, "Render Format", defNum("RenderFormat", 2),
            function() return tonumber(getcv("RenderFormat")) or 2 end, function(v) setcv("RenderFormat", v) end)
        Settings.CreateDropdown(cat, setting, function()
            local container = Settings.CreateControlTextContainer()
            if tonumber(getcv("RenderFormat")) == 0 then container:Add(0, "8-bit (BGRA8Unorm)") end
            for _, f in ipairs(FORMATS) do container:Add(f[1], f[2]) end
            return container:GetData()
        end, "Bits for each color channel. 10-bit is the lowest this game accepts. 16-bit float is the game's own choice. 32-bit float is the most precise and uses the most video memory.")
    end
    if has("useHDRBrightness") and has("HDRBrightness") then
        header("Brightness")
        checkbox("useHDRBrightness", "Override Brightness", "Uses the brightness below instead of the brightness the game detects for the display.")
        slider("HDRBrightness", "HDR Brightness", NITS, "Brightness for HDR, in nits (cd/m2). Only used while the override is on.")
    end
    if has("useHDRPeakBrightness") and has("HDRPeakBrightness") then
        checkbox("useHDRPeakBrightness", "Override Peak Brightness", "Uses the peak brightness below instead of the peak brightness the game detects for the display.")
        slider("HDRPeakBrightness", "HDR Peak Brightness", NITS, "The brightest the display can go in HDR, in nits (cd/m2). Only used while the override is on.")
    end
    if has("HDRFactor") then
        header("Tone Mapping")
        slider("HDRFactor", "HDR Factor", FACTOR, "How far above normal (SDR) lighting HDR may go. It is limited to the display's peak brightness.")
    end
end

-- /hdt (or /hdr) opens this tab.
SLASH_UBERMOCHDR1 = "/hdt"
SLASH_UBERMOCHDR2 = "/hdr"
SlashCmdList["UBERMOCHDR"] = function()
    report()
    if not (API.openWindow and UbermocUIDB) then return end
    API.openWindow("misc")
    if API.miscSelectTab then API.miscSelectTab(4) end
end

-- Made when the addon loads (and again at login if that was too early).
do
    local told = false
    local function make()
        if API.hdrSettingsDone then return end
        local ok, err = pcall(API.registerHDRSettings)
        if ok and not API.hdrSettingsDone and not told then
            told = true
            say("this game has none of the HDR settings, so there is no HDR page to show.")
        end
        if not ok and not told then
            told = true
            if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffUbermoc UI:|r the HDR options page could not be made: " .. tostring(err)) end
        end
    end
    local f = CreateFrame("Frame")
    f:RegisterEvent("ADDON_LOADED")
    f:RegisterEvent("PLAYER_LOGIN")
    f:SetScript("OnEvent", function(_, event, name)
        if event == "ADDON_LOADED" and name ~= "UbermocUI" then return end
        make()
        if event == "PLAYER_LOGIN" then f:UnregisterAllEvents() end
    end)
end
