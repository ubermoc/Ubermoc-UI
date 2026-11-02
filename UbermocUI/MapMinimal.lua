-- Ubermoc UI - Copyright (c) 2026 Marcos. All rights reserved.
-- This file is protected by copyright. It may not be copied, modified, redistributed or reused, in whole or
-- in part, without the written permission of the author. See LICENSE.txt.
-- Minimal map: a clean map with a rounded-square or round shape and an optional frame. No strip above it and
-- no bar below it; the zone name sits inside the top, and the coordinates, FPS / latency and time each sit in a
-- corner you choose. Gold, bags, durability and experience live on a small info board that shows up when one
-- changes. Turning it off puts every setting it touched back. Also: a key to show / hide the map.
local API = UbermocUIAPI
if not API then return end

local MEDIA = "Interface\\AddOns\\UbermocUI\\Media\\"
local MASKS = { rounded = MEDIA .. "roundmask.tga", round = MEDIA .. "circlemask.tga" }
local RINGS = {
    rounded = { thin = MEDIA .. "ring_thin.tga", thick = MEDIA .. "ring_thick.tga" },
    round = { thin = MEDIA .. "ringc_thin.tga", thick = MEDIA .. "ringc_thick.tga" },
}
local PLATE = { 0.045, 0.05, 0.068 }   -- the menu bar's plate colour

local function DB()
    UbermocUIDB = UbermocUIDB or {}
    if API.miniFilled and UbermocUIDB.mm and UbermocUIDB.mm.mini == API.miniFilled then return API.miniFilled end
    UbermocUIDB.mm = UbermocUIDB.mm or {}
    local m = UbermocUIDB.mm.mini
    if type(m) ~= "table" then m = {}; m.fresh = true; UbermocUIDB.mm.mini = m end
    if m.on == nil then m.on = false end
    if m.r == nil then m.r, m.g, m.b = 0.72, 0.45, 0.2 end   -- copper
    if m.clock == nil then m.clock = 18 end
    if m.shape == nil then m.shape = "rounded" end            -- rounded (square with round corners) / round
    if m.frame == nil then m.frame = "thin" end                -- thin / thick / none
    if m.tex == nil then m.tex = "menu" end                    -- menu = same texture as the menu bar
    if m.texA == nil then m.texA = 50 end
    if m.coordCorner == nil then m.coordCorner = "TOPRIGHT" end
    if m.coordSize == nil then m.coordSize = 10 end
    if m.boardBorder == nil then m.boardBorder = true end   -- the info board's thin border
    if m.boardTex == nil then m.boardTex = "frame" end      -- frame = same texture as the map's frame
    if m.boardA == nil then m.boardA = 94 end               -- the info board's background opacity
    if m.boardFit == nil then m.boardFit = true end         -- auto: as wide as the map, text shrinks to fit
    if m.boardW == nil then m.boardW = 160 end              -- manual: width, text size, icon size
    if m.boardSize == nil then m.boardSize = 11 end
    if m.boardIcon == nil then m.boardIcon = 12 end
    -- One time: "same as the menu bar" became a real texture (textures are set on the Textures page now),
    -- the nailed-on board look is gone, and the compass letters start on.
    if not m.v2 then
        m.v2 = true
        if m.tex == "menu" then
            local t = UbermocUIDB.toolbar or {}
            m.tex = t.tex or "brushed"
            m.texA = t.texA or m.texA
        end
        m.nailed = nil
        local c = UbermocUIDB.mm
        c.compass = c.compass or {}
        c.compass.on = true
    end
    API.miniFilled = m
    return m
end
API.miniDB = DB
-- Borders set on the Textures page (Minimap tab).
local COPPER = { 0.72, 0.45, 0.2 }
local function miniLegacyColour(m)
    if API.borderOldDefault and API.borderOldDefault(m.r, m.g, m.b, COPPER[1], COPPER[2], COPPER[3]) then return "class" end
    return "custom", m.r, m.g, m.b
end
API.registerBorder({ key = "mapFrame", part = "minimap", label = "Minimal map frame", size = 1, maxSize = 2,
    sizeFmt = function(v) return (v or 1) >= 2 and "Thick" or "Thin" end,
    legacy = function()
        local m = (UbermocUIDB.mm and UbermocUIDB.mm.mini) or {}
        return m.frame ~= "none", (m.frame == "thick") and 2 or 1, 100, miniLegacyColour(m)
    end,
    apply = function() if API.mapBorderRefresh then API.mapBorderRefresh() end end })
API.registerBorder({ key = "board", part = "minimap", label = "Info board border", size = 1, maxSize = 6,
    legacy = function()
        local m = (UbermocUIDB.mm and UbermocUIDB.mm.mini) or {}
        return m.boardBorder ~= false, 1, 100, miniLegacyColour(m)
    end,
    apply = function() if API.mapBorderRefresh then API.mapBorderRefresh() end end })
local function on() local m = UbermocUIDB and UbermocUIDB.mm and UbermocUIDB.mm.mini; return m and m.on end

local function maskPath() return MASKS[DB().shape] or MASKS.rounded end

-- The texture on the frame and the board: the menu bar's own, or one picked here.
local function texture()
    local m = DB()
    if m.tex == "menu" then
        local t = UbermocUIDB.toolbar or {}
        local id = t.tex or "brushed"
        return id ~= "none" and id or nil, (t.texA or 50) / 100
    end
    if m.tex == "none" then return nil, 0 end
    return m.tex, (m.texA or 50) / 100
end
API.miniTexture = texture

local ring, coords
local busy = false

----------------------------------------------------------------------
-- Where a label sits in a corner of the map (FPS, time and coordinates all use this)
----------------------------------------------------------------------
function API.miniLift() return 0 end
-- Nine places: the four corners, the middle of each edge, and the centre.
function API.mapCorner(corner)
    corner = corner or "BOTTOMLEFT"
    local size = (Minimap and Minimap:GetWidth()) or 140
    local m = UbermocUIDB and UbermocUIDB.mm and UbermocUIDB.mm.mini
    local ix, top, bottom = 6, 6, 4
    local vert = corner:find("TOP") or corner:find("BOTTOM")
    local side = corner:find("LEFT") or corner:find("RIGHT")
    if m and m.on and m.shape == "round" and vert and side then
        -- the corners of a round map are outside it: come in until the label sits on the map
        local d = math.floor(size * 0.15 + 0.5)
        ix, top, bottom = d, d, d
    end
    local x = corner:find("LEFT") and ix or (corner:find("RIGHT") and -ix or 0)
    local y = corner:find("TOP") and -top or (corner:find("BOTTOM") and bottom or 0)
    return corner, x, y
end

----------------------------------------------------------------------
-- Info board: gold, bags, durability and experience in one small bar, shown for five seconds when one changes.
-- Nailed on: half of it sits over the bottom of the map and half hangs below, like a board fixed to the map.
----------------------------------------------------------------------
local bar
local HOLD, FADE = 5, 0.6
local last = {}

local function money()
    local c = (GetMoney and GetMoney()) or 0
    local g, sv = math.floor(c / 10000), math.floor((c % 10000) / 100)
    if g > 0 then return string.format("|cffffd24a%d|rg |cffd0d0d0%d|rs", g, sv) end
    return string.format("|cffd0d0d0%d|rs |cffc87f4a%d|rc", sv, c % 100)
end
local function bagText()
    local free, total = 0, 0
    if C_Container and C_Container.GetContainerNumSlots then
        for b = 0, (tonumber(NUM_BAG_SLOTS) or 4) do
            local n = tonumber(C_Container.GetContainerNumSlots(b)) or 0
            local fr = C_Container.GetContainerNumFreeSlots and C_Container.GetContainerNumFreeSlots(b)
            total = total + n
            free = free + (tonumber(fr) or 0)
        end
    end
    if total == 0 then return "-" end
    return (total - free) .. "/" .. total
end
local function duraText()
    local cur, mx = 0, 0
    for slot = 1, 19 do
        if slot ~= 4 and slot ~= 18 then
            local ok, c, m = pcall(GetInventoryItemDurability, slot)
            if ok and type(c) == "number" and type(m) == "number" and m > 0 then cur, mx = cur + c, mx + m end
        end
    end
    if mx == 0 then return "100%" end
    return math.floor(cur / mx * 100 + 0.5) .. "%"
end
local function xpText()
    local ok, lvl = pcall(UnitLevel, "player")
    local okm, maxl = pcall(function() return GetMaxPlayerLevel and GetMaxPlayerLevel() or 0 end)
    if not ok or type(lvl) ~= "number" or (okm and type(maxl) == "number" and maxl > 0 and lvl >= maxl) then return nil end
    local x, mx = UnitXP("player"), UnitXPMax("player")
    if type(x) ~= "number" or type(mx) ~= "number" or mx <= 0 then return nil end
    return math.floor(x / mx * 100) .. "%"
end

local ICONS = { gold = "Interface\\Icons\\INV_Misc_Coin_01", bags = "Interface\\Icons\\INV_Misc_Bag_08",
                dura = "Interface\\Icons\\Trade_BlackSmithing", xp = "Interface\\Icons\\INV_Misc_Book_09" }
local ORDER = { "gold", "bags", "dura", "xp" }

local function buildBar()
    if bar or not Minimap then return end
    local o = CreateFrame("Frame", "UbermocMiniBar", Minimap)   -- the fade rules fade this one
    o:SetFrameLevel(Minimap:GetFrameLevel() + 9)
    o:SetSize(120, 22)
    local f = CreateFrame("Frame", nil, o)                        -- this one shows and fades by itself
    f:SetAllPoints(o)
    f.bg = f:CreateTexture(nil, "BACKGROUND", nil, -4); f.bg:SetAllPoints()
    f.pat = f:CreateTexture(nil, "BACKGROUND", nil, -3); f.pat:SetAllPoints()
    f.edge = {}
    for i = 1, 4 do f.edge[i] = f:CreateTexture(nil, "BORDER") end
    f.edge[1]:SetPoint("TOPLEFT"); f.edge[1]:SetPoint("TOPRIGHT"); f.edge[1]:SetHeight(1)
    f.edge[2]:SetPoint("BOTTOMLEFT"); f.edge[2]:SetPoint("BOTTOMRIGHT"); f.edge[2]:SetHeight(1)
    f.edge[3]:SetPoint("TOPLEFT"); f.edge[3]:SetPoint("BOTTOMLEFT"); f.edge[3]:SetWidth(1)
    f.edge[4]:SetPoint("TOPRIGHT"); f.edge[4]:SetPoint("BOTTOMRIGHT"); f.edge[4]:SetWidth(1)
    f.shine = f:CreateTexture(nil, "ARTWORK"); f.shine:SetPoint("TOPLEFT", 1, -1); f.shine:SetPoint("TOPRIGHT", -1, -1); f.shine:SetHeight(1)
    f.nails = {}
    for i = 1, 2 do
        local n = f:CreateTexture(nil, "OVERLAY")
        n:SetTexture(MEDIA .. "disc.tga")
        n:SetSize(5, 5)
        n:SetVertexColor(0.78, 0.74, 0.68, 1)
        f.nails[i] = n
    end
    f.nails[1]:SetPoint("LEFT", 4, 0); f.nails[2]:SetPoint("RIGHT", -4, 0)
    f.items = {}
    for _, k in ipairs(ORDER) do
        local it = {}
        it.icon = f:CreateTexture(nil, "ARTWORK"); it.icon:SetSize(12, 12); it.icon:SetTexture(ICONS[k]); it.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        it.fs = f:CreateFontString(nil, "OVERLAY"); it.fs:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
        f.items[k] = it
    end
    f:SetAlpha(0)
    f:SetScript("OnUpdate", function(self, dt)
        if self.always then return end
        if self.hold and self.hold > 0 then
            self.hold = self.hold - dt
            if self.hold <= 0 then self.fading = FADE end
        elseif self.fading then
            self.fading = self.fading - dt
            local a = math.max(0, self.fading / FADE)
            self:SetAlpha(a)
            if a <= 0 then self.fading = nil end
        end
    end)
    o.f = f
    bar = o
end

local function layoutBar()
    if not bar then return end
    local m = DB()
    local f = bar.f
    f.bg:SetColorTexture(PLATE[1], PLATE[2], PLATE[3], (m.boardA or 94) / 100)
    local edgeOn, esz, er, eg, eb, ea = API.borderOf("board")
    for i, e in ipairs(f.edge) do
        e:SetColorTexture(er, eg, eb, ea); e:SetShown(edgeOn)
        if i <= 2 then e:SetHeight(esz) else e:SetWidth(esz) end
    end
    f.shine:SetColorTexture(1, 1, 1, 0.12)
    local nailed = false   -- the nailed-on look is gone: a plain board just under the map
    for _, n in ipairs(f.nails) do n:Hide() end
    f.shine:Hide()
    -- Fill in the numbers. The board is exactly as wide as the map: the items spread evenly across it, and
    -- if they don't fit, the text and icons get smaller until they do.
    local auto = m.boardFit ~= false
    local W = auto and math.floor((Minimap and Minimap:GetWidth()) or 140) or (m.boardW or 160)
    local font = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
    local n = 0
    for _, k in ipairs(ORDER) do
        local it = f.items[k]
        -- Each item can be left off the board; experience is left off on its own while the experience bar shows.
        local items = m.items or {}
        local want = items[k] ~= false
        -- (experience shows in one place: the XP Bar tab sets it to Hide here when the mini bar goes on)
        local v = want and ((k == "gold" and money()) or (k == "bags" and bagText()) or (k == "dura" and duraText()) or (k == "xp" and xpText()))
        if v then
            n = n + 1
            it.fs:SetText(v)
            it.icon:Show(); it.fs:Show()
            it.on = true
        else
            it.icon:Hide(); it.fs:Hide()
            it.on = false
        end
    end
    local size, isz, natural = 11, 12, 0
    if not auto then size, isz = m.boardSize or 11, m.boardIcon or 12 end
    for _ = 1, 6 do
        natural = 8
        for _, k in ipairs(ORDER) do
            local it = f.items[k]
            if it.on then
                if it.ubSize ~= size then it.ubSize = size; it.fs:SetFont(font, size, "OUTLINE") end
                it.icon:SetSize(isz, isz)
                natural = natural + isz + 2 + (it.fs:GetStringWidth() or 20)
            end
        end
        natural = natural + 8
        if not auto or natural <= W or size <= 7 then break end
        size = size - 1; isz = math.max(8, isz - 1)
    end
    if auto and natural > W and f.items.gold.on then
        -- still too wide at the smallest size: gold without the silver
        local gw = f.items.gold.fs:GetStringWidth() or 0
        local c = (GetMoney and GetMoney()) or 0
        f.items.gold.fs:SetText(string.format("|cffffd24a%d|rg", math.floor(c / 10000)))
        natural = natural - gw + (f.items.gold.fs:GetStringWidth() or 0)
    end
    -- the room left over goes evenly between the items
    local spare = math.max(0, W - natural)
    local gap = (n > 1) and (spare / (n - 1)) or 0
    local x = (n > 1) and 8 or math.floor((W - natural) / 2) + 8
    for _, k in ipairs(ORDER) do
        local it = f.items[k]
        if it.on then
            it.icon:ClearAllPoints(); it.icon:SetPoint("LEFT", f, "LEFT", x, 0)
            it.fs:ClearAllPoints(); it.fs:SetPoint("LEFT", it.icon, "RIGHT", 2, 0)
            x = x + isz + 2 + (it.fs:GetStringWidth() or 20) + gap
        end
    end
    x = W
    bar:SetSize(W, 22)
    local tid, ta = texture()
    if m.boardTex == "none" then tid = nil
    elseif m.boardTex and m.boardTex ~= "frame" then tid = m.boardTex end
    if tid and ta > 0 then
        f.pat:SetTexture(MEDIA .. "skin_" .. tid .. ".tga", "REPEAT", "REPEAT")
        f.pat:SetTexCoord(0, x / 128, 0, 22 / 128)
        f.pat:SetAlpha(math.min(1, ta))
        f.pat:Show()
    else
        f.pat:Hide()
    end
    bar:ClearAllPoints()
    if m.boardSide == "top" then
        -- above the map, or above the experience bar / top strip when they sit on top of it
        local over = Minimap
        for _, n in ipairs({ "UbermocXPBar", "UbermocTopStrip" }) do
            local fr = _G[n]
            local c = UbermocUIDB.mm and UbermocUIDB.mm.xp
            if fr and fr:IsShown() and c and c.attach then over = fr end
        end
        bar:SetPoint("BOTTOM", over, "TOP", m.boardX or 0, 3 + (m.boardY or 0))
    else
        bar:SetPoint("TOP", Minimap, "BOTTOM", m.boardX or 0, -3 + (m.boardY or 0))
    end
    if API.flushMap then pcall(API.flushMap) end   -- pulled to the top of the screen: make room for it
end

-- The game's own experience bar is kept out of sight while your experience shows on the info board
-- or on the mini experience bar (it comes back when neither does, and at maximum level).
local GAME_XP = { "MainStatusTrackingBarContainer", "StatusTrackingBarManager" }
local gameXPHidden = false
local function syncGameXP(hide)
    hide = hide and true or false
    if hide == gameXPHidden or not API.holdHidden then return end
    gameXPHidden = hide
    for _, n in ipairs(GAME_XP) do
        local fr = _G[n]
        if fr then pcall(API.holdHidden, fr, hide) end
    end
end
API.xpOnBoard = function()
    local m = DB()
    return (m.on and m.bar ~= false and bar and bar.f and bar.f.items and bar.f.items.xp and bar.f.items.xp.on) and true or false
end
API.syncGameXP = function()
    local onBoard = API.xpOnBoard()
    syncGameXP(onBoard or (API.xpBarShown and API.xpBarShown()))
end

-- reveal: show it now for five seconds (or keep it up when set to always)
function API.updateMiniBar(reveal)
    local m = DB()
    -- 0.99.147: settings from before the one-place rule had experience on both the board and the mini bar,
    -- with the board's copy hidden. The board keeps it (the mini bar goes off), once.
    if not m.xpOnce then
        m.xpOnce = true
        local c = UbermocUIDB.mm and UbermocUIDB.mm.xp
        local items = m.items or {}
        if m.on and m.bar ~= false and items.xp == nil and c and c.on then c.on = false; if API.mmApply then pcall(API.mmApply) end end
    end
    buildBar()
    if not bar then return end
    local show = m.on and m.bar ~= false
    bar:SetShown(show)
    local lift = API.miniLift()
    if lift ~= (API.miniLiftSeen or 0) then API.miniLiftSeen = lift; pcall(API.mmApply) end
    if not show then pcall(API.syncGameXP); return end
    layoutBar()
    pcall(API.syncGameXP)
    local f = bar.f
    f.always = m.always and true or false
    if f.always then f:SetAlpha(1); f.hold = nil; f.fading = nil
    elseif reveal then f:SetAlpha(1); f.hold = HOLD; f.fading = nil end
end

local function changed(key, val)
    local old = last[key]
    last[key] = val
    return old ~= nil and old ~= val
end
local function check()
    local ch = false
    if changed("gold", GetMoney and GetMoney() or 0) then ch = true end
    if changed("bags", bagText()) then ch = true end
    if changed("dura", duraText()) then ch = true end
    if changed("xp", xpText() or "") then ch = true end
    API.updateMiniBar(ch)
end

local bev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_MONEY", "BAG_UPDATE_DELAYED", "UPDATE_INVENTORY_DURABILITY", "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP" }) do pcall(bev.RegisterEvent, bev, e) end
bev:SetScript("OnEvent", function() if UbermocUIDB and UbermocUIDB.version and DB().on then check() end end)

----------------------------------------------------------------------
-- The frame around the map: one ring the shape of the map, coloured, with the chosen texture laid inside it.
----------------------------------------------------------------------
local function buildRing()
    if ring or not Minimap then return end
    local f = CreateFrame("Frame", "UbermocMiniFrame", Minimap)
    f:SetAllPoints(Minimap)
    f:SetFrameLevel(Minimap:GetFrameLevel() + 4)
    f:EnableMouse(false)
    f.base = f:CreateTexture(nil, "OVERLAY", nil, 1)
    f.base:SetAllPoints()
    f.pat = f:CreateTexture(nil, "OVERLAY", nil, 2)
    f.pat:SetAllPoints()
    f.mask = f:CreateMaskTexture()
    f.mask:SetAllPoints()
    f.pat:AddMaskTexture(f.mask)
    ring = f
end

local function paintRing()
    if not ring then return end
    local m = DB()
    -- From the Textures page (Minimap tab): on / off, thin (1) or thick (2), colour and opacity.
    local fon, fsz, fr, fg, fb, fa = API.borderOf("mapFrame")
    if not fon then ring:Hide(); return end
    local file = (RINGS[m.shape] or RINGS.rounded)[(fsz or 1) >= 2 and "thick" or "thin"] or RINGS.rounded.thin
    ring.base:SetTexture(file)
    ring.base:SetVertexColor(fr, fg, fb, fa)
    ring.mask:SetTexture(file, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    local tid, ta = texture()
    if tid and ta > 0 then
        local sz = (Minimap and Minimap:GetWidth()) or 140
        ring.pat:SetTexture(MEDIA .. "skin_" .. tid .. ".tga", "REPEAT", "REPEAT")
        ring.pat:SetTexCoord(0, sz / 128, 0, sz / 128)
        ring.pat:SetVertexColor(0, 0, 0, 1)
        ring.pat:SetAlpha(math.min(1, ta) * 0.8)
        ring.pat:Show()
    else
        ring.pat:Hide()
    end
    ring:Show()
end

local function buildCoords()
    if coords or not Minimap then return end
    local f = CreateFrame("Frame", "UbermocMiniCoords", Minimap)
    f:SetSize(90, 14)
    f:SetFrameLevel(Minimap:GetFrameLevel() + 12)
    f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    API.shade(f.text, STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12)
    f.t = 1
    f:SetScript("OnUpdate", function(self, dt)
        self.t = self.t + dt
        if self.t < 0.5 then return end
        self.t = 0
        local x, y
        if C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition then
            local id = C_Map.GetBestMapForUnit("player")
            local pos = id and C_Map.GetPlayerMapPosition(id, "player")
            if pos and pos.GetXY then x, y = pos:GetXY() end
        end
        if x and y and (x > 0 or y > 0) then self.text:SetFormattedText("%.1f, %.1f", x * 100, y * 100)
        else self.text:SetText("") end
    end)
    coords = f
end

local function placeCoords()
    if not coords then return end
    local m = DB()
    local pt, x, y = API.mapCorner(m.coordCorner)
    coords:ClearAllPoints()
    coords:SetPoint(pt, Minimap, pt, x + (m.coordX or 0) + (API.cornerShift and API.cornerShift(pt) or 0), y + (m.coordY or 0))
    coords.text:ClearAllPoints()
    local side = pt:find("LEFT") and "LEFT" or (pt:find("RIGHT") and "RIGHT" or "CENTER")
    coords.text:SetPoint(side)
    local sz = tonumber(m.coordSize) or 10
    if coords.size ~= sz then
        coords.size = sz
        coords:SetSize(math.max(90, sz * 7), sz + 2)
        API.shade(coords.text, STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", sz)
    end
end

-- With the minimal look, the game's tracking button, world map button, calendar and the empty header strip
-- above the map are kept out of sight (and out of the mouse's way); they come back when it is turned off.
local CLUTTER = { "MinimapCluster.Tracking", "MinimapCluster.TrackingFrame", "MiniMapTracking", "MiniMapWorldMapButton",
                  "GameTimeFrame", "MinimapCluster.BorderTop", "MinimapBorderTop" }
local clutterHidden = false
local function clutterFrame(path)
    local a, b = path:match("^([^.]+)%.?(.*)$")
    local f = _G[a]
    if f and b ~= "" then f = f[b] end
    return type(f) == "table" and f.SetAlpha and f or nil
end
local function hideClutter(hide)
    if hide == clutterHidden then return end
    clutterHidden = hide
    for _, path in ipairs(CLUTTER) do
        local f = clutterFrame(path)
        if f then
            if API.holdHidden then pcall(API.holdHidden, f, hide) end
            if f.EnableMouse and not InCombatLockdown() and not (f.IsProtected and f:IsProtected()) then pcall(f.EnableMouse, f, not hide) end
        end
    end
end

-- The text inside the map (FPS / latency, coordinates, time) keeps its own place and size for each of the two
-- shapes. The settings the rest of the addon reads are the "live" ones; they are swapped when the shape changes.
local TXT = { { "perf", "corner" }, { "perf", "ox" }, { "perf", "oy" }, { "perf", "size" },
              { "clock", "corner" }, { "clock", "ox" }, { "clock", "oy" }, { "clock", "size" },
              { "mini", "coordCorner" }, { "mini", "coordX" }, { "mini", "coordY" }, { "mini", "coordSize" } }
local function txtGroup(g)
    local c = UbermocUIDB and UbermocUIDB.mm
    if not c then return nil end
    if g == "mini" then return DB() end
    c[g] = c[g] or {}
    return c[g]
end
local function txtCapture()
    local t = {}
    for _, f in ipairs(TXT) do local g = txtGroup(f[1]); if g then t[f[1] .. "." .. f[2]] = g[f[2]] end end
    return t
end
local function txtApply(t)
    for _, f in ipairs(TXT) do
        local g = txtGroup(f[1])
        if g then g[f[2]] = t[f[1] .. "." .. f[2]] end
    end
end
local function txtCopy(t) local n = {}; for k, v in pairs(t) do n[k] = v end; return n end
function API.miniTextSave()
    local m = DB()
    if m.txt and m.txtShape then m.txt[m.txtShape] = txtCapture() end
end
function API.miniTextLoad()
    local m = DB()
    if not (UbermocUIDB and UbermocUIDB.mm) then return end
    if not m.txt then   -- first time: both shapes start from what is set now, with the new starting values
        local cur = txtCapture()
        local ps, cs = cur["perf.size"], cur["mini.coordSize"]
        if ps == nil or ps == 11 then cur["perf.size"] = 10 end
        if cs == nil or cs == 12 then cur["mini.coordSize"] = 10 end
        m.txt = { rounded = txtCopy(cur), round = txtCopy(cur) }
        local r = m.txt.round
        if (r["perf.oy"] or 0) == 0 then r["perf.oy"] = -5 end
        if (r["mini.coordY"] or 0) == 0 then r["mini.coordY"] = -5 end
        m.txtV2 = true
        r["perf.ox"], r["mini.coordX"] = -4, 25
        m.txtShape = nil
    end
    if not m.txtV2 then   -- 0.99.169: the round look's starting places
        m.txtV2 = true
        m.txt.round = m.txt.round or txtCopy(txtCapture())
        m.txt.round["perf.ox"], m.txt.round["perf.oy"] = -4, -5
        m.txt.round["mini.coordX"], m.txt.round["mini.coordY"] = 25, -5
        if m.txtShape == "round" then m.txtShape = nil end
    end
    if not m.txtV3 then   -- 0.99.174: the rounded square's starting places
        m.txtV3 = true
        m.txt.rounded = m.txt.rounded or txtCopy(txtCapture())
        local r = m.txt.rounded
        r["perf.ox"], r["mini.coordX"] = 7, 7
        r["clock.ox"], r["clock.oy"], r["clock.size"] = -6, 3, 16
        if m.txtShape == "rounded" then m.txtShape = nil end
    end
    if not m.txtV4 then   -- 0.99.175: the round look's time
        m.txtV4 = true
        m.txt.round = m.txt.round or txtCopy(txtCapture())
        m.txt.round["clock.ox"], m.txt.round["clock.size"] = -4, 16
        if m.txtShape == "round" then m.txtShape = nil end
    end
    local shape = m.shape == "round" and "round" or "rounded"
    if m.txtShape ~= shape then
        if not m.txt[shape] then m.txt[shape] = txtCopy(m.txt[shape == "round" and "rounded" or "round"] or txtCapture()) end
        txtApply(m.txt[shape])
        m.txtShape = shape
        if API.mmApply then pcall(API.mmApply) end
    end
end

-- Light repaint (colour, texture, shape, corners): no settings are changed.
function API.paintMiniMap()
    pcall(hideClutter, (Minimap and on()) and true or false)
    if not Minimap or not on() then
        if ring then ring:Hide() end
        if coords then coords:Hide() end
        if bar then bar:Hide() end
        return
    end
    API.miniTextLoad()
    buildRing(); buildCoords()
    busy = true
    pcall(Minimap.SetMaskTexture, Minimap, maskPath())
    busy = false
    paintRing()
    coords:Show()
    placeCoords()
    if API.compassFrame then API.compassFrame.placed = false end   -- the letters keep clear of the moved text
    if bar and bar:IsShown() then layoutBar() end
end

----------------------------------------------------------------------
-- Switching the look on and off
----------------------------------------------------------------------
-- What this look changes, and what it was before.
local function snapshot(c, DBm)
    return {
        sq = DBm.squareMinimap, bsize = c.border and c.border.size, xp = c.xp and c.xp.on, info = c.info and c.info.on,
        icons = c.xp and c.xp.icons, phase = c.xp and c.xp.phase, coords = c.xp and c.xp.coords,
        perf = c.perf and c.perf.on, perfCorner = c.perf and c.perf.corner, zin = c.zone and c.zone.inside,
        clockSize = c.clock and c.clock.size, clockOwn = c.clock and c.clock.own,
        coordsCVar = GetCVar and GetCVar("minimapShowPlayerCoords"),
    }
end
local function applyLook(c, DBm, m, first)
    DBm.squareMinimap = true              -- hides the game's round artwork; the shape comes from our mask
    c.border = c.border or {}; c.border.size = 0
    -- Only when the look is switched on: after that the experience bar and the other map parts are yours to
    -- turn on again (they are not switched back off at the next login).
    if first then
        c.xp.on = false; c.xp.icons = false; c.xp.phase = false; c.xp.coords = false   -- no strip on top
        c.info.on = false                 -- the info board replaces the bar underneath
    end
    c.perf = c.perf or {}; c.perf.on = true
    c.zone = c.zone or {}; c.zone.inside = true
    c.clock = c.clock or {}; c.clock.own = true; c.clock.move = false
    if first or c.perf.corner == nil then c.perf.corner = "TOPLEFT" end
    if first then c.compass = c.compass or {}; c.compass.on = true; m.bar = true end
    if first or c.clock.size == nil then c.clock.size = m.clock end
    pcall(SetCVar, "minimapShowPlayerCoords", "0")   -- the coordinates are drawn inside the map instead
end

-- Done again at every start: if the other map settings were rebuilt (a repaired or reset settings file),
-- the strip and bar would come back and the map would look like the old one.
local function enforceMini()
    local DBm = UbermocUIDB
    local m = DB()
    local c = DBm and DBm.mm
    if not (m.on and c and c.xp and c.info) then return end
    applyLook(c, DBm, m, false)
    pcall(API.applySquare)
    pcall(API.mmApply)
    if API.updateClockLabel then pcall(API.updateClockLabel) end
end

-- Puts the map, its frame and its labels in the state the saved setting says.
function API.updateMiniMap()
    if not Minimap then return end
    local m = DB()
    if m.on and not API.miniEnforced then API.miniEnforced = true; enforceMini() end
    API.paintMiniMap()
    API.updateMiniBar(false)
end

-- One press: switches the settings this look needs, remembering what they were.
function API.setMiniMap(want)
    local DBm = UbermocUIDB
    local m = DB()
    local c = DBm.mm
    if not (c and c.xp and c.info) then return end
    if want and not m.on then
        m.saved = snapshot(c, DBm)
        m.on = true
        applyLook(c, DBm, m, true)
    elseif not want and m.on then
        local s = m.saved or {}
        m.on = false
        DBm.squareMinimap = s.sq == nil and true or s.sq
        c.border.size = s.bsize or 1
        c.xp.on = s.xp ~= false; c.info.on = s.info ~= false
        c.xp.icons = s.icons ~= false; c.xp.phase = s.phase ~= false; c.xp.coords = s.coords ~= false
        c.perf.on = s.perf ~= false; c.perf.corner = s.perfCorner
        c.zone.inside = s.zin ~= false
        c.clock.size = s.clockSize; c.clock.own = s.clockOwn ~= false
        if s.coordsCVar then pcall(SetCVar, "minimapShowPlayerCoords", s.coordsCVar) end
        m.saved = nil
        if DBm.squareMinimap then pcall(Minimap.SetMaskTexture, Minimap, "Interface\\ChatFrame\\ChatFrameBackground")
        else print("|cff00ccffUbermoc UI|r The round map returns after a reload.") end
    end
    pcall(API.applySquare)
    API.updateMiniMap()
    pcall(API.mmApply)
    if API.updateClockLabel then pcall(API.updateClockLabel) end
end

function API.setMiniColor(r, g, b)
    local m = DB()
    m.r, m.g, m.b = r, g, b
    API.paintMiniMap()
end

-- Key: show / hide the whole minimap (it cannot be changed in combat when the game protects it)
function UbermocUI_MapToggle()
    local mc = MinimapCluster
    if not mc then return end
    if InCombatLockdown and InCombatLockdown() and mc.IsProtected and mc:IsProtected() then return end
    pcall(mc.SetShown, mc, not mc:IsShown())
end
function API.toggleMap() UbermocUI_MapToggle() end
BINDING_NAME_UBERMOCUI_MAPTOGGLE = "Show / hide the minimap"

-- Other code (the square map, Blizzard) may set the mask again: keep ours while the look is on.
if Minimap and Minimap.SetMaskTexture then
    hooksecurefunc(Minimap, "SetMaskTexture", function(_, tex)
        if busy or not on() or tex == maskPath() then return end
        busy = true
        pcall(Minimap.SetMaskTexture, Minimap, maskPath())
        busy = false
    end)
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:SetScript("OnEvent", function()
    C_Timer.After(1, function() if UbermocUIDB and UbermocUIDB.version then pcall(API.updateMiniMap) end end)
end)

local prev = API.onLogin
API.onLogin = function()
    if prev then prev() end
    local m = DB()
    -- first use of the addon: the map starts as the minimal rounded square
    if m.fresh then
        m.fresh = nil
        m.shape = "rounded"
        pcall(API.setMiniMap, true)
    end
    pcall(API.updateMiniMap)
end
