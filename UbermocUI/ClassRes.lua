-- Class resources on the floating frames: combo points (rogue, druid), holy power, soul shards, chi, arcane charges,
-- essence and runes, as a row of dots or segments under the bars. Combo points go on the target's frame by default (they
-- are on the target), everything else on your own frame. Settings: Unit Frames > Player or Target > Frame tab.
local API = UbermocUIAPI
if not API then return end

local MEDIA = "Interface\\AddOns\\UbermocUI\\Media\\"
local PT = (Enum and Enum.PowerType) or {}
local ENERGY = PT.Energy or 3

-- What each class has. col: the lit colour. spec: only in that specialization (monk: windwalker, mage: arcane).
local RES = {
    ROGUE = { combo = true, pt = PT.ComboPoints or 4, col = { 1, 0.82, 0.1 } },
    DRUID = { combo = true, pt = PT.ComboPoints or 4, col = { 1, 0.82, 0.1 } },
    PALADIN = { pt = PT.HolyPower or 9, col = { 0.95, 0.9, 0.6 } },
    WARLOCK = { pt = PT.SoulShards or 7, col = { 0.58, 0.51, 0.79 } },
    MONK = { pt = PT.Chi or 12, spec = 3, col = { 0.71, 1, 0.92 } },
    MAGE = { pt = PT.ArcaneCharges or 16, spec = 1, col = { 0.35, 0.45, 1 } },
    EVOKER = { pt = PT.Essence or 19, col = { 0.2, 0.76, 0.62 } },
    DEATHKNIGHT = { runes = true, col = { 0.5, 0.8, 1 } },
}
local CHARGED = { 0.3, 0.75, 1 }
local EMPTY = { 0.12, 0.12, 0.15, 0.9 }

local function isSecret(v) return issecretvalue and issecretvalue(v) end
local function DB() return API.floatDB and API.floatDB() or {} end

local function classRes()
    local _, cls = UnitClass("player")
    return cls and RES[cls], cls
end
local function specOk(R)
    if not R.spec then return true end
    local okS, spec = pcall(GetSpecialization)
    return okS and spec == R.spec
end

-- Which frames carry the row, from the class and the settings alone (so a frame's layout does not jump about as points
-- come and go): the target's frame for combo points, your own frame for the rest.
function API.resOnFrame(unit)
    local d = DB()
    if d.resOn == false then return false end
    local R = classRes()
    if not R or not specOk(R) then return false end
    local where = d.resCombo or "target"
    if R.combo then
        if unit == "target" then return where ~= "player" end
        if unit == "player" then return where ~= "target" end
        return false
    end
    return unit == "player"
end

-- The room a frame sets aside under its bars for the row.
function API.resReserve(unit)
    if not API.resOnFrame(unit) then return 0 end
    local d = DB()
    local size = d.resSize or 10
    if d.resShape == "segments" then size = math.max(4, math.floor(size * 0.6)) end
    return size + 5
end

-- Current and maximum points, which are charged, and the lit colour; nil when there is nothing to show.
local function values(unit)
    local d = DB()
    if d.resPreview then return 3, 5, { [2] = true }, { 1, 0.82, 0.1 } end
    local R = classRes()
    if not R then return nil end
    if R.runes then
        -- each rune lights on its own (they recharge out of order)
        local ready, lit = 0, {}
        for i = 1, 6 do
            local okR, _, _, isReady = pcall(GetRuneCooldown, i)
            if okR and isReady then ready = ready + 1; lit[i] = true end
        end
        return ready, 6, {}, R.col, lit
    end
    local okM, mx = pcall(UnitPowerMax, "player", R.pt)
    if not okM or isSecret(mx) or type(mx) ~= "number" or mx <= 0 then return nil end
    if R.combo then
        local _, cls = UnitClass("player")
        if cls == "DRUID" then
            local okT, pt = pcall(UnitPowerType, "player")
            if not okT or isSecret(pt) or pt ~= ENERGY then return nil end
        end
        -- on the target's frame they need an enemy target, as on the nameplate
        if unit == "target" then
            if not UnitExists("target") then return nil end
            local okA, atk = pcall(UnitCanAttack, "player", "target")
            if not okA or isSecret(atk) or not atk then return nil end
        end
    end
    local okC, cur = pcall(UnitPower, "player", R.pt)
    if not okC or isSecret(cur) or type(cur) ~= "number" then return nil end
    local charged = {}
    if R.combo and GetUnitChargedPowerPoints then
        local okP, list = pcall(GetUnitChargedPowerPoints, "player")
        if okP and type(list) == "table" then for _, i in ipairs(list) do charged[i] = true end end
    end
    return cur, mx, charged, R.col
end

----------------------------------------------------------------------
-- Drawing
----------------------------------------------------------------------
local function row(f)
    if f.resRow then return f.resRow end
    local r = CreateFrame("Frame", nil, f)
    r:SetFrameLevel(f:GetFrameLevel() + 6)
    r:SetSize(10, 10)
    r.pips = {}
    r:Hide()
    f.resRow = r
    return r
end
local function pip(r, i)
    local p = r.pips[i]
    if p then return p end
    p = {}
    p.rim = r:CreateTexture(nil, "ARTWORK", nil, 1)
    p.fill = r:CreateTexture(nil, "ARTWORK", nil, 2)
    r.pips[i] = p
    return p
end

local function draw(f, unit, cur, mx, charged, col, litSet)
    local d = DB()
    local r = row(f)
    local shape = d.resShape == "segments" and "segments" or "dots"
    local size = d.resSize or 10
    local gap = d.resGap or 4
    local barW = f.resW or 150
    local pw = f.barX or 0
    local segH = math.max(4, math.floor(size * 0.6))
    local w, h, step
    if shape == "dots" then
        w, h = mx * size + (mx - 1) * gap, size
        step = size + gap
    else
        local sw = math.max(3, (barW - (mx - 1) * gap) / mx)
        w, h = barW, segH
        step = sw + gap
        size = sw
    end
    local align = d.resAlign or "center"
    local left = (align == "left" and 0) or (align == "right" and (barW - w)) or ((barW - w) / 2)
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", f, "TOPLEFT", pw + left + (d.resX or 0), (f.resTop or -36) + (d.resY or 0))
    r:SetSize(w, h)
    local showEmpty = d.resEmpty ~= false
    for i = 1, mx do
        local p = pip(r, i)
        local lit = litSet and litSet[i] or (not litSet and i <= cur)
        local x = (i - 1) * step
        p.rim:ClearAllPoints(); p.fill:ClearAllPoints()
        if shape == "dots" then
            p.rim:SetTexture(MEDIA .. "ringdisc.tga"); p.fill:SetTexture(MEDIA .. "ringdisc.tga")
            p.rim:SetPoint("TOPLEFT", r, "TOPLEFT", x - 1, 1); p.rim:SetSize(size + 2, size + 2)
            p.fill:SetPoint("TOPLEFT", r, "TOPLEFT", x, 0); p.fill:SetSize(size, size)
            p.rim:SetVertexColor(0, 0, 0, 0.9)
            if lit then
                local c = charged[i] and CHARGED or col
                p.fill:SetVertexColor(c[1], c[2], c[3], 1)
            else
                p.fill:SetVertexColor(EMPTY[1], EMPTY[2], EMPTY[3], EMPTY[4])
            end
        else
            p.rim:SetPoint("TOPLEFT", r, "TOPLEFT", x - 1, 1); p.rim:SetSize(size + 2, h + 2)
            p.fill:SetPoint("TOPLEFT", r, "TOPLEFT", x, 0); p.fill:SetSize(size, h)
            p.rim:SetColorTexture(0, 0, 0, 0.9)
            if lit then
                local c = charged[i] and CHARGED or col
                p.fill:SetColorTexture(c[1], c[2], c[3], 1)
            else
                p.fill:SetColorTexture(EMPTY[1], EMPTY[2], EMPTY[3], EMPTY[4])
            end
        end
        local on = lit or showEmpty
        p.rim:SetShown(on); p.fill:SetShown(on)
    end
    for i = mx + 1, #r.pips do r.pips[i].rim:Hide(); r.pips[i].fill:Hide() end
    r:Show()
end

local function update()
    if not UbermocUIDB then return end
    for _, unit in ipairs({ "player", "target" }) do
        local f = API.floatFrame and API.floatFrame(unit)
        local want = f and f:IsShown() and (API.resOnFrame(unit) or DB().resPreview)
        local cur, mx, charged, col, litSet
        if want then cur, mx, charged, col, litSet = values(unit) end
        if want and cur then
            draw(f, unit, cur, mx, charged, col, litSet)
        elseif f and f.resRow then
            f.resRow:Hide()
        end
    end
end
API.resUpdate = update

do
    local acc = 0
    local drv = CreateFrame("Frame")
    drv:SetScript("OnUpdate", function(_, dt)
        acc = acc + dt
        if acc < 0.1 then return end
        acc = 0
        pcall(update)
    end)
    -- A change of specialization changes what the class has (and so the room the frame sets aside).
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    ev:RegisterEvent("PLAYER_ENTERING_WORLD")
    ev:SetScript("OnEvent", function()
        if API.targetFrameRefresh then C_Timer.After(0.5, API.targetFrameRefresh) end
    end)
end
