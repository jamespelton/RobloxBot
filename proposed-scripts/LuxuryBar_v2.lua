-- THE HIGH ROLLER LOUNGE v2 (rebuilds the "Bar" model in Venue - keeps prompts and scripts working)
-- Written by James. Changes are marked [REX]:
--
--   1. The previous build was looked for at the Workspace root only. v1 of
--      this bar lives in Workspace.Casino, so it was never removed and the
--      two bars stood on top of each other. Both places are checked now, and
--      the new bar goes in the Casino folder like the other builds.
--   2. OldTransparency was re-recorded on every run. The old bar was already
--      hidden by v1, so this would have saved "invisible" as its original
--      look and it could never be brought back. Recorded once now.
--   3. Everything more than 10 studs up was kept, to spare a jackpot screen.
--      This Bar has no jackpot screen, so what that kept was the old sign,
--      the glass rack frame and the top shelf of bottles, floating behind
--      the new bar. Only parts actually carrying jackpot text are kept now.
--   4. The 19 old stools kept live seats once invisible, so you could sit on
--      thin air. Old seats are disabled.
--   5. The floor was taken from the bottom of the lowest old part, 0.13 below
--      the real floor, so the base, foot rail and stools sat sunk into it.
--      The floor is measured by ray now.
--   6. The back bar went where the old bar's own back wall was, about three
--      studs in front of the casino wall and its gold band, leaving a gap
--      behind it you could see over the top. It stands against the nearest
--      real wall surface now (probed at several heights, as in v1).
--   7. The stool Seat was built by cylUp(), which turns the part 90 degrees
--      about Z; a Seat orients the sitter by its own CFrame, so players
--      would have sat on their side. Upright SitPad facing the bar now.
--   8. The backslash-n in BAR_NAME becomes a real line break when pasted
--      through the Studio bridge and stops the script compiling. The break
--      is built from string.char(10).
--   9. The glass rack and globe lights hung from rods that stopped in
--      mid-air under the 45-stud ceiling. They reach the ceiling now.

-- Settings:
local NL = string.char(10) -- [REX] see note 8
local BAR_NAME = "THE HIGH ROLLER" .. NL .. "LOUNGE"
local MENU = {
    "SPARKLING CIDER   $8", "SHIRLEY TEMPLE   $6", "ROOT BEER FLOAT   $7",
    "FRUIT PUNCH   $5", "LEMONADE   $5", "HOT COCOA   $6",
}
local GLASS_RACK = true      -- hanging glass rack over the bar
local SITTABLE = true
local LEATHER_COLOR = Color3.fromRGB(140, 15, 25)

local V = Vector3.new
local UP = V(0, 1, 0)
local rng = Random.new(5)

----------------------------------------------------------------
-- Materials
----------------------------------------------------------------
local GOLD = { Color = Color3.fromRGB(212, 175, 55), Material = Enum.Material.Metal, Reflectance = 0.35 }
local BRASS = { Color = Color3.fromRGB(190, 150, 60), Material = Enum.Material.Metal, Reflectance = 0.4 }
local CHROME = { Color = Color3.fromRGB(210, 210, 215), Material = Enum.Material.Metal, Reflectance = 0.45 }
local STEEL = { Color = Color3.fromRGB(170, 172, 176), Material = Enum.Material.Metal, Reflectance = 0.25 }
local MAHOGANY = { Color = Color3.fromRGB(75, 30, 22), Material = Enum.Material.Wood }
local DARK_WOOD = { Color = Color3.fromRGB(45, 20, 14), Material = Enum.Material.Wood }
local MARBLE = { Color = Color3.fromRGB(240, 236, 228), Material = Enum.Material.Marble }
local GRANITE = { Color = Color3.fromRGB(25, 25, 28), Material = Enum.Material.Granite }
local LEATHER = { Color = LEATHER_COLOR, Material = Enum.Material.Leather }
local MIRROR = { Color = Color3.fromRGB(190, 195, 205), Material = Enum.Material.Glass, Reflectance = 0.6 }
local ONYX = { Color = Color3.fromRGB(255, 185, 105), Material = Enum.Material.Neon, Transparency = 0.45 }
local SHELF_GLASS = { Color = Color3.fromRGB(200, 225, 235), Material = Enum.Material.Glass, Transparency = 0.5 }
local GLASS = { Color = Color3.fromRGB(220, 235, 245), Material = Enum.Material.Glass, Transparency = 0.55 }
local NEON_WARM = { Color = Color3.fromRGB(255, 225, 170), Material = Enum.Material.Neon }
local NEON_AMBER = { Color = Color3.fromRGB(255, 170, 60), Material = Enum.Material.Neon }
local NEON_GOLD = { Color = Color3.fromRGB(255, 200, 90), Material = Enum.Material.Neon }
local NEON_BLUE = { Color = Color3.fromRGB(80, 160, 255), Material = Enum.Material.Neon }
local BLACK = { Color = Color3.fromRGB(18, 18, 20), Material = Enum.Material.SmoothPlastic }
local SHADE = { Color = Color3.fromRGB(240, 225, 195), Material = Enum.Material.Fabric }
local ICE = { Color = Color3.fromRGB(220, 235, 245), Material = Enum.Material.Ice }
local BOTTLE_COLORS = {
    Color3.fromRGB(200, 120, 40), Color3.fromRGB(160, 80, 25), Color3.fromRGB(60, 140, 70), Color3.fromRGB(220, 230, 235),
    Color3.fromRGB(180, 30, 40), Color3.fromRGB(40, 90, 180), Color3.fromRGB(230, 190, 60), Color3.fromRGB(110, 50, 120),
}
local DRINK_COLORS = { Color3.fromRGB(255, 120, 150), Color3.fromRGB(255, 200, 80), Color3.fromRGB(120, 220, 255), Color3.fromRGB(255, 90, 60) }

----------------------------------------------------------------
-- Helpers
----------------------------------------------------------------
local current
local function makePart(props, style, className)
    local p = Instance.new(className or "Part")
    p.Anchored = true
    p.CanCollide = false
    p.CanTouch = false
    p.CastShadow = false
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    for k, v in pairs(style) do
        p[k] = v
    end
    for k, v in pairs(props) do
        p[k] = v
    end
    p.Parent = current
    return p
end
local function box(cf, size, style, className)
    return makePart({ CFrame = cf, Size = size }, style, className)
end
local function ball(pos, size, style)
    return makePart({ Shape = Enum.PartType.Ball, CFrame = CFrame.new(pos), Size = V(size, size, size) }, style)
end
local function cylUp(pos, height, width, style, className)
    return makePart({
        Shape = Enum.PartType.Cylinder,
        CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)),
        Size = V(height, width, width),
    }, style, className)
end
local function rod(a, b, thickness, style)
    local dir = (b - a).Unit
    local up = math.abs(dir.Y) > 0.98 and V(1, 0, 0) or UP
    return makePart({
        Shape = Enum.PartType.Cylinder,
        CFrame = CFrame.lookAt((a + b) / 2, b, up) * CFrame.Angles(0, math.rad(90), 0),
        Size = V((b - a).Magnitude + thickness * 0.3, thickness, thickness),
    }, style)
end
local function ellipsoid(pos, size, style)
    local p = makePart({ CFrame = CFrame.new(pos), Size = size }, style)
    local mesh = Instance.new("SpecialMesh")
    mesh.MeshType = Enum.MeshType.Sphere
    mesh.Parent = p
    return p
end
local function pointLight(part, range, brightness)
    local light = Instance.new("PointLight")
    light.Color = Color3.fromRGB(255, 215, 160)
    light.Range = range
    light.Brightness = brightness
    light.Parent = part
end
local function bounds(part)
    local half = part.Size / 2
    local mn, mx = V(math.huge, math.huge, math.huge), V(-math.huge, -math.huge, -math.huge)
    for _, sx in ipairs({ -1, 1 }) do
        for _, sy in ipairs({ -1, 1 }) do
            for _, sz in ipairs({ -1, 1 }) do
                local c = part.CFrame * V(half.X * sx, half.Y * sy, half.Z * sz)
                mn, mx = mn:Min(c), mx:Max(c)
            end
        end
    end
    return mn, mx
end
local function flat(v)
    return V(v.X, 0, v.Z)
end
local function frameBars(cf, w, h, thickness, depth, style)
    for _, dy in ipairs({ -h / 2, h / 2 }) do
        box(cf * CFrame.new(0, dy, 0), V(w + thickness, thickness, depth), style)
    end
    for _, dx in ipairs({ -w / 2, w / 2 }) do
        box(cf * CFrame.new(dx, 0, 0), V(thickness, h, depth), style)
    end
end

----------------------------------------------------------------
-- Find the old bar ("Bar" model inside Venue)
----------------------------------------------------------------
-- [REX] the previous build, wherever it is (note 1)
local casinoRoot = workspace:FindFirstChild("Casino") or workspace
local previous = casinoRoot:FindFirstChild("LuxuryBar") or workspace:FindFirstChild("LuxuryBar")

local bar
for _, m in ipairs(workspace:GetDescendants()) do
    if m:IsA("Model") and m.Name == "Bar" and m.Parent and m.Parent.Name == "Venue" then
        bar = m
        break
    end
end
if not bar then
    local found = workspace:FindFirstChild("Bar", true)
    if found and found:IsA("Model") then
        bar = found
    end
end
if not bar then
    error("[Bar] Couldn't find a model named 'Bar'. In your Explorer it should be inside the Venue folder.")
end

local infos, floorY = {}, math.huge
for _, p in ipairs(bar:GetDescendants()) do
    if p:IsA("BasePart") then
        local mn, mx = bounds(p)
        local hasJackpotText = false
        for _, d in ipairs(p:GetDescendants()) do
            if d:IsA("TextLabel") then
                local t = string.upper(d.Text)
                if string.find(t, "JACKPOT") or string.find(t, "RESPONSIB") or string.find(t, "GOOD LUCK") then
                    hasJackpotText = true
                end
            end
        end
        table.insert(infos, { part = p, mn = mn, mx = mx, jackpot = hasJackpotText })
        floorY = math.min(floorY, mn.Y)
    end
end
-- Keep a jackpot screen if the bar has one
-- [REX] only parts that actually carry jackpot text; "anything 10 studs up"
-- kept the old sign, glass rack and top shelf here (note 3)
for _, info in ipairs(infos) do
    info.keep = info.jackpot
end

-- Which way the bar runs, and which side the back bar is on
local amn, amx = V(math.huge, 0, math.huge), V(-math.huge, 0, -math.huge)
for _, info in ipairs(infos) do
    if not info.keep then
        amn, amx = amn:Min(info.mn), amx:Max(info.mx)
    end
end
local longAxis = (amx.X - amn.X) >= (amx.Z - amn.Z) and V(1, 0, 0) or V(0, 0, 1)
local back = UP:Cross(longAxis)
local center = flat((amn + amx) / 2)
local tallSum, tallN, lowSum, lowN = 0, 0, 0, 0
for _, info in ipairs(infos) do
    if not info.keep then
        local c = (flat((info.mn + info.mx) / 2) - center):Dot(back)
        if info.mx.Y - info.mn.Y >= 5 then
            tallSum += c
            tallN += 1
        elseif info.mx.Y - floorY <= 4 then
            lowSum += c
            lowN += 1
        end
    end
end
if tallN > 0 and lowN > 0 and tallSum / tallN < lowSum / lowN then
    back = -back
end

-- [REX] rays look straight through the old bar and the previous build
local ignore = { bar }
if previous then
    table.insert(ignore, previous)
end
local function castIgnoring(origin, direction, extra)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local list = table.clone(ignore)
    for _, e in ipairs(extra or {}) do
        table.insert(list, e)
    end
    params.FilterDescendantsInstances = list
    return workspace:Raycast(origin, direction, params)
end

-- [REX] the real floor, not the bottom of the lowest old part (note 5)
local partFloor = floorY
do
    local hit = castIgnoring(V(center.X, partFloor + 6, center.Z), V(0, -30, 0))
    if hit then
        floorY = hit.Position.Y
    end
end

-- Measure in the bar's own direction (+Z = back wall)
local xAxis = UP:Cross(back)
local F0 = CFrame.fromMatrix(V(center.X, floorY, center.Z), xAxis, UP)
local lmn, lmx = V(math.huge, math.huge, math.huge), V(-math.huge, -math.huge, -math.huge)
for _, info in ipairs(infos) do
    if not info.keep then
        for _, corner in ipairs({ info.mn, info.mx, V(info.mn.X, info.mn.Y, info.mx.Z), V(info.mx.X, info.mx.Y, info.mn.Z) }) do
            local lp = F0:PointToObjectSpace(corner)
            lmn, lmx = lmn:Min(lp), lmx:Max(lp)
        end
    end
end

-- The counter = the longest piece at bar-top height
local counterZ, counterTop, bestLong = nil, nil, 0
for _, info in ipairs(infos) do
    if not info.keep then
        local top = info.mx.Y - floorY
        local long = math.max(info.mx.X - info.mn.X, info.mx.Z - info.mn.Z)
        if top >= 2.5 and top <= 5.5 and long > bestLong then
            bestLong = long
            counterTop = top
            counterZ = F0:PointToObjectSpace((info.mn + info.mx) / 2).Z
        end
    end
end
counterZ = counterZ or (lmx.Z - 8)
local L = math.clamp(lmx.X - lmn.X, 16, 160)
local ht = math.clamp(counterTop or 3.8, 3.4, 4.3)
local T = F0 * CFrame.new((lmn.X + lmx.X) / 2, 0, counterZ)

-- [REX] the back bar stands against the nearest real wall surface, probed at
-- several heights so the gold band along the wall counts (note 6)
local wallDist
for _, h in ipairs({ 1, 3.5, 4.5, 6, 8.5 }) do
    local skip = {}
    local origin = T * V(0, h, 0)
    local dir = T:VectorToWorldSpace(V(0, 0, 1))
    for _ = 1, 15 do
        local hit = castIgnoring(origin, dir * 40, skip)
        if not hit then
            break
        end
        local s = hit.Instance.Size
        if math.max(s.X, s.Y, s.Z) >= 10 then
            local dist = (hit.Position - origin):Dot(dir)
            wallDist = wallDist and math.min(wallDist, dist) or dist
            break
        end
        table.insert(skip, hit.Instance)
    end
end
local wz = math.clamp(wallDist or (lmx.Z - counterZ), 5, 22)

-- Hide the old bar (parts stay in place so prompts and scripts keep working)
local hidden = 0
for _, info in ipairs(infos) do
    if not info.keep then
        local p = info.part
        -- [REX] only record the original once (note 2)
        if p:GetAttribute("OldTransparency") == nil then
            p:SetAttribute("OldTransparency", p.Transparency)
            p:SetAttribute("OldCanCollide", p.CanCollide)
        end
        p.Transparency = 1
        p.CanCollide = false
        -- [REX] an invisible old seat still sits people down (note 4)
        if p:IsA("Seat") then
            if p:GetAttribute("OldDisabled") == nil then
                p:SetAttribute("OldDisabled", p.Disabled)
            end
            p.Disabled = true
        end
        for _, d in ipairs(p:GetDescendants()) do
            if d:IsA("Decal") or d:IsA("Texture") then
                d.Transparency = 1
            elseif d:IsA("SurfaceGui") then
                d.Enabled = false
            elseif d:IsA("Light") then
                d.Enabled = false
            end
        end
        hidden += 1
    end
end

-- [REX] how far up the rack and light rods have to reach (note 9)
local function ceilingAbove(p, fallback)
    local hit = castIgnoring(p + V(0, 0.5, 0), V(0, 120, 0))
    return hit and math.min(hit.Position.Y, p.Y + 80) or fallback
end

----------------------------------------------------------------
-- Build the new bar (local: X along the bar, -Z = guests, +Z = back wall)
----------------------------------------------------------------
if previous then
    previous:Destroy()
end
local model = Instance.new("Model")
model.Name = "LuxuryBar"
model.Parent = casinoRoot
current = model

local function at(x, y, z)
    return T * CFrame.new(x, y, z)
end
local function pos(x, y, z)
    return T * V(x, y, z)
end
local function facingGuests(p)
    return CFrame.lookAt(p, p - T:VectorToWorldSpace(V(0, 0, 1)))
end

-- Front bar
box(at(0, 0.2, 0), V(L, 0.4, 2.5), GRANITE).CanCollide = true
box(at(0, (ht - 0.3) / 2 + 0.2, 0), V(L, ht - 0.7, 2.4), MAHOGANY).CanCollide = true
local panels = math.max(1, math.floor(L / 6))
local panelH = ht - 1.6
for i = 0, panels - 1 do
    local x = -L / 2 + (i + 0.5) * L / panels
    local cf = at(x, 0.8 + panelH / 2, -1.25)
    box(cf, V(L / panels - 0.7, panelH, 0.1), LEATHER)
    frameBars(cf * CFrame.new(0, 0, -0.05), L / panels - 0.7, panelH, 0.1, 0.05, GOLD)
    for _, dy in ipairs({ -panelH / 4, panelH / 4 }) do
        for _, dx in ipairs({ -(L / panels) / 4, 0, (L / panels) / 4 }) do
            ball((cf * CFrame.new(dx, dy, -0.08)).Position, 0.14, GOLD)
        end
    end
end
for _, side in ipairs({ -1, 1 }) do
    cylUp(pos(side * L / 2, (ht - 0.3) / 2 + 0.2, 0), ht - 0.7, 2.4, MAHOGANY).CanCollide = true
    cylUp(pos(side * L / 2, ht, -0.25), 0.3, 3.4, MARBLE).CanCollide = true
end
box(at(0, ht, -0.25), V(L, 0.3, 3.4), MARBLE).CanCollide = true
box(at(0, ht - 0.17, -1.96), V(L, 0.08, 0.05), GOLD)
box(at(0, ht - 0.25, -1.6), V(L, 0.06, 0.1), NEON_WARM)
box(at(0, 0.45, -1.3), V(L, 0.06, 0.08), NEON_AMBER)
rod(pos(-L / 2, ht + 0.12, -1.75), pos(L / 2, ht + 0.12, -1.75), 0.5, LEATHER)
rod(pos(-L / 2 + 1, 0.7, -1.95), pos(L / 2 - 1, 0.7, -1.95), 0.25, BRASS)
for x = -L / 2 + 1, L / 2 - 1, 6 do
    rod(pos(x, 0.7, -1.95), pos(x, 1.0, -1.25), 0.15, BRASS)
end

-- Bartender's work counter with ice wells and sinks
box(at(0, 1.45, 1.9), V(L - 2, 2.9, 1.2), STEEL).CanCollide = true
box(at(0, 2.92, 1.9), V(L - 2, 0.05, 1.25), CHROME)
for x = -L / 2 + 6, L / 2 - 6, 24 do
    box(at(x, 2.93, 1.9), V(2, 0.04, 0.9), ICE)
    box(at(x + 6, 2.93, 1.9), V(1.2, 0.04, 0.8), BLACK)
    rod(pos(x + 6, 2.95, 2.35), pos(x + 6, 3.6, 2.35), 0.1, CHROME)
    rod(pos(x + 6, 3.6, 2.35), pos(x + 6, 3.6, 2.0), 0.1, CHROME)
end

-- Beer taps, shakers, fruit bowls and lamps on the bar top
for x = -L / 2 + 8, L / 2 - 8, 16 do
    cylUp(pos(x, ht + 0.85, 0.5), 1.4, 0.5, CHROME)
    rod(pos(x - 0.9, ht + 1.4, 0.5), pos(x + 0.9, ht + 1.4, 0.5), 0.25, CHROME)
    for i = -1.5, 1.5 do
        box(at(x + i * 0.55, ht + 1.85, 0.5), V(0.15, 0.6, 0.15), { Color = BOTTLE_COLORS[rng:NextInteger(1, #BOTTLE_COLORS)], Material = Enum.Material.SmoothPlastic })
    end
    box(at(x, ht + 0.19, 0.1), V(1.8, 0.08, 0.5), CHROME)

    -- Cocktail shaker
    cylUp(pos(x + 3, ht + 0.55, 0.6), 0.8, 0.45, CHROME)
    cylUp(pos(x + 3, ht + 1.05, 0.6), 0.25, 0.3, CHROME)
    -- Fruit bowl with lemons and limes
    ellipsoid(pos(x - 4, ht + 0.3, 0.4), V(1.2, 0.4, 1.2), GLASS)
    for f = 1, 5 do
        local lemon = rng:NextNumber() < 0.5
        ball(pos(x - 4 + rng:NextNumber(-0.35, 0.35), ht + 0.42, 0.4 + rng:NextNumber(-0.35, 0.35)), 0.32,
            { Color = lemon and Color3.fromRGB(245, 220, 60) or Color3.fromRGB(110, 190, 60), Material = Enum.Material.SmoothPlastic })
    end
end
local lampIndex = 0
for x = -L / 2 + 4, L / 2 - 4, 8 do
    lampIndex += 1
    cylUp(pos(x, ht + 0.17, -0.9), 0.05, 0.6, GOLD)
    cylUp(pos(x, ht + 0.75, -0.9), 1.1, 0.12, GOLD)
    cylUp(pos(x, ht + 1.55, -0.9), 0.6, 0.9, SHADE)
    local glow = cylUp(pos(x, ht + 1.27, -0.9), 0.04, 0.8, NEON_WARM)
    if lampIndex % 2 == 0 then
        pointLight(glow, 10, 0.6)
    end
end

-- Stools, plus drinks on coasters
local stoolH = math.clamp(ht - 1.2, 2.2, 3.2)
for x = -L / 2 + 1.8, L / 2 - 1.8, 3.4 do
    local base = CFrame.lookAt(pos(x, 0, -3.4), pos(x, 0, -3.4) + T:VectorToWorldSpace(V(0, 0, 1)))
    local function c(localPos, height, width, style, className)
        return cylUp(base * localPos, height, width, style, className)
    end
    c(V(0, 0.12, 0), 0.25, 2.0, GOLD).CanCollide = true
    c(V(0, 0.28, 0), 0.08, 1.6, GRANITE)
    c(V(0, (0.35 + stoolH - 0.9) / 2, 0), stoolH - 1.25, 0.35, GOLD).CanCollide = true
    local ringY, last = stoolH * 0.45, nil
    for i = 0, 6 do
        local a = i / 6 * math.pi * 2
        local point = base * V(math.cos(a) * 0.85, ringY, math.sin(a) * 0.85)
        if last then
            rod(last, point, 0.1, GOLD)
        end
        last = point
    end
    -- [REX] plain cushion; the Seat is an upright block facing the bar (note 7)
    local cushion = c(V(0, stoolH - 0.25, 0), 0.5, 2.1, LEATHER)
    cushion.CanCollide = true
    cushion.Name = "Cushion"
    if SITTABLE then
        local seat = Instance.new("Seat")
        seat.Name = "SitPad"
        seat.Anchored = true
        seat.CanCollide = true
        seat.Transparency = 1
        seat.Size = V(1.8, 0.5, 1.8)
        seat.CFrame = base * CFrame.new(0, stoolH - 0.25, 0)
        seat.TopSurface = Enum.SurfaceType.Smooth
        seat.BottomSurface = Enum.SurfaceType.Smooth
        seat.Parent = current
    end
    c(V(0, stoolH - 0.5, 0), 0.08, 2.16, GOLD)
    c(V(0, stoolH - 0.65, 0), 0.25, 1.9, MAHOGANY)
    ball(base * V(0, stoolH + 0.01, 0), 0.15, GOLD)
    local R, backH = 0.95, 1.4
    local mid = base * V(0, stoolH + backH / 2, 0)
    for _, deg in ipairs({ -45, 0, 45 }) do
        local a = math.rad(deg)
        local p = base * V(math.sin(a) * R, stoolH - 0.1 + backH / 2, math.cos(a) * R)
        box(CFrame.lookAt(p, V(mid.X, p.Y, mid.Z)), V(0.78, backH, 0.28), LEATHER).CanCollide = true
    end
    local prev
    for i = 0, 4 do
        local a = math.rad(-65 + 130 * i / 4)
        local point = base * V(math.sin(a) * R, stoolH - 0.1 + backH, math.cos(a) * R)
        if prev then
            rod(prev, point, 0.16, GOLD)
        end
        prev = point
    end
    if rng:NextNumber() < 0.55 then
        local g = pos(x + rng:NextNumber(-0.4, 0.4), ht + 0.15, -1.1)
        cylUp(g + V(0, 0.01, 0), 0.02, 0.6, DARK_WOOD)
        cylUp(g + V(0, 0.04, 0), 0.04, 0.4, GLASS)
        cylUp(g + V(0, 0.3, 0), 0.5, 0.06, GLASS)
        ellipsoid(g + V(0, 0.65, 0), V(0.55, 0.35, 0.55), GLASS)
        ellipsoid(g + V(0, 0.62, 0), V(0.42, 0.22, 0.42), { Color = DRINK_COLORS[rng:NextInteger(1, #DRINK_COLORS)], Material = Enum.Material.Glass, Transparency = 0.2 })
    end
end

-- Hanging glass rack (or globe lights)
if GLASS_RACK then
    local rackY = ht + 6.5
    for _, dz in ipairs({ -0.9, 0.5 }) do
        box(at(0, rackY, dz), V(L - 4, 0.4, 0.5), MAHOGANY)
        box(at(0, rackY - 0.22, dz), V(L - 4, 0.05, 0.52), GOLD)
    end
    box(at(0, rackY + 0.25, -0.2), V(L - 4, 0.1, 1.9), DARK_WOOD)
    for x = -L / 2 + 3, L / 2 - 3, 1.6 do
        for _, dz in ipairs({ -0.55, 0.15 }) do
            local top = pos(x, rackY - 0.25, dz)
            rod(top, top - V(0, 0.5, 0), 0.05, GLASS)
            ellipsoid(top - V(0, 0.75, 0), V(0.45, 0.4, 0.45), GLASS)
        end
    end
    local lightIndex = 0
    for x = -L / 2 + 4, L / 2 - 4, 6 do
        lightIndex += 1
        local light = box(at(x, rackY - 0.27, -0.2), V(0.6, 0.05, 0.6), NEON_WARM)
        if lightIndex % 2 == 0 then
            local spot = Instance.new("SpotLight")
            spot.Face = Enum.NormalId.Bottom
            spot.Color = Color3.fromRGB(255, 225, 170)
            spot.Brightness = 2
            spot.Range = 14
            spot.Angle = 90
            spot.Parent = light
        end
    end
    for x = -L / 2 + 3, L / 2 - 3, 12 do
        -- [REX] hang the rack from the ceiling (note 9)
        local start = pos(x, rackY + 0.3, -0.2)
        rod(start, V(start.X, ceilingAbove(start, start.Y + 11.7), start.Z), 0.1, GOLD)
    end
else
    local pendantIndex = 0
    for x = -L / 2 + 3, L / 2 - 3, 6 do
        pendantIndex += 1
        local start = pos(x, ht + 6.6, -0.3)
        rod(start, V(start.X, ceilingAbove(start, start.Y + 9.4), start.Z), 0.08, GOLD)
        local globe = ball(pos(x, ht + 6.1, -0.3), 0.9, NEON_WARM)
        if pendantIndex % 2 == 0 then
            pointLight(globe, 14, 0.8)
        end
    end
end

----------------------------------------------------------------
-- Back bar
----------------------------------------------------------------
local BB = L - 1
box(at(0, 1.6, wz - 1.1), V(BB, 3.2, 2.0), MAHOGANY).CanCollide = true
box(at(0, 0.2, wz - 1.1), V(BB, 0.4, 2.05), GRANITE)
for x = -BB / 2 + 1.3, BB / 2 - 1.3, 2.5 do
    box(at(x, 1.75, wz - 2.12), V(2.2, 2.4, 0.05), DARK_WOOD)
    ball(pos(x + 0.8, 1.9, wz - 2.17), 0.15, GOLD)
end
box(at(0, 3.32, wz - 1.15), V(BB + 0.2, 0.25, 2.2), MARBLE)
box(at(0, 3.2, wz - 2.26), V(BB + 0.2, 0.05, 0.05), GOLD)
for _, x in ipairs({ -L / 4, L / 4 }) do
    local screenCF = facingGuests(pos(x, 3.9, wz - 1.6)) * CFrame.Angles(math.rad(-15), 0, 0)
    box(screenCF, V(1.2, 0.85, 0.1), BLACK)
    box(screenCF * CFrame.new(0, 0, -0.06), V(1.05, 0.7, 0.02), NEON_BLUE)
    box(at(x, 3.5, wz - 1.6), V(0.5, 0.15, 0.5), BLACK)
end

local mirrorBottom, mirrorTop = 3.45, 9.2
local centerBay = math.min(12, L * 0.25)
local menuBay = 6
local bayWidth = 9

-- Back wall: bays of mirror and glowing amber panels between gold columns
local x = -BB / 2 + menuBay
local bayIndex = 0
while x < BB / 2 - menuBay - 0.5 do
    local x1 = math.min(x + bayWidth, BB / 2 - menuBay)
    if not (x1 > -centerBay / 2 and x < centerBay / 2) then
        bayIndex += 1
        box(at((x + x1) / 2, (mirrorBottom + mirrorTop) / 2, wz - 0.1), V(x1 - x, mirrorTop - mirrorBottom, 0.1), bayIndex % 2 == 0 and MIRROR or ONYX)
    end
    x = x1
end
for _, side in ipairs({ -1, 1 }) do
    box(at(side * (centerBay / 2 + BB / 2 - menuBay) / 2, (mirrorBottom + mirrorTop) / 2, wz - 0.05), V(BB / 2 - menuBay - centerBay / 2, mirrorTop - mirrorBottom, 0.05), DARK_WOOD)
end
box(at(0, 9.45, wz - 0.75), V(BB + 0.4, 0.5, 1.5), MAHOGANY)
box(at(0, 9.2, wz - 1.5), V(BB + 0.4, 0.08, 0.05), GOLD)
box(at(0, 9.72, wz - 1.5), V(BB + 0.4, 0.06, 0.05), NEON_GOLD)

-- Lit sign in the center
local signCF = facingGuests(pos(0, 6.3, wz - 0.3))
local signPanel = box(signCF, V(centerBay - 1, 3.2, 0.2), BLACK)
local signGui = Instance.new("SurfaceGui")
signGui.Face = Enum.NormalId.Front
signGui.LightInfluence = 0
signGui.Brightness = 1.6
signGui.Parent = signPanel
local title = Instance.new("TextLabel")
title.Size = UDim2.fromScale(1, 0.75)
title.Position = UDim2.fromScale(0, 0.05)
title.BackgroundTransparency = 1
title.Text = BAR_NAME
title.TextScaled = true
title.Font = Enum.Font.Bodoni
title.TextColor3 = Color3.fromRGB(255, 215, 110)
title.Parent = signGui
local stars = Instance.new("TextLabel")
stars.Size = UDim2.fromScale(1, 0.2)
stars.Position = UDim2.fromScale(0, 0.78)
stars.BackgroundTransparency = 1
stars.Text = "★  ★  ★"
stars.TextScaled = true
stars.Font = Enum.Font.GothamBold
stars.TextColor3 = Color3.fromRGB(255, 200, 90)
stars.Parent = signGui
frameBars(signCF * CFrame.new(0, 0, -0.12), centerBay - 0.8, 3.5, 0.12, 0.05, NEON_GOLD)

-- Drink menus on both ends
for _, side in ipairs({ -1, 1 }) do
    local mx = side * (BB / 2 - menuBay / 2)
    local menuCF = facingGuests(pos(mx, 6.3, wz - 0.25))
    local board = box(menuCF, V(menuBay - 1, 4.2, 0.15), { Color = Color3.fromRGB(28, 30, 32), Material = Enum.Material.Slate })
    frameBars(menuCF, menuBay - 1, 4.2, 0.15, 0.25, GOLD)
    local g = Instance.new("SurfaceGui")
    g.Face = Enum.NormalId.Front
    g.LightInfluence = 0
    g.Brightness = 1.3
    g.Parent = board
    local header = Instance.new("TextLabel")
    header.Size = UDim2.fromScale(1, 0.2)
    header.BackgroundTransparency = 1
    header.Text = "DRINKS"
    header.TextScaled = true
    header.Font = Enum.Font.Bodoni
    header.TextColor3 = Color3.fromRGB(255, 215, 110)
    header.Parent = g
    for i, item in ipairs(MENU) do
        local line = Instance.new("TextLabel")
        line.Position = UDim2.fromScale(0.06, 0.22 + (i - 1) * 0.125)
        line.Size = UDim2.fromScale(0.88, 0.11)
        line.BackgroundTransparency = 1
        line.Text = item
        line.TextScaled = true
        line.Font = Enum.Font.GothamMedium
        line.TextColor3 = Color3.fromRGB(240, 235, 225)
        line.Parent = g
    end
end

-- Glass shelves with LED strips and bottles
local function freeX(px)
    return math.abs(px) >= centerBay / 2 + 0.3 and math.abs(px) <= BB / 2 - menuBay - 0.2
end
for _, y in ipairs({ 4.6, 6.2, 7.8 }) do
    for _, side in ipairs({ -1, 1 }) do
        local x0, x1 = side * (centerBay / 2 + 0.3), side * (BB / 2 - menuBay - 0.2)
        box(at((x0 + x1) / 2, y, wz - 0.6), V(math.abs(x1 - x0), 0.1, 0.9), SHELF_GLASS)
        box(at((x0 + x1) / 2, y - 0.08, wz - 1.02), V(math.abs(x1 - x0), 0.06, 0.06), NEON_AMBER)
    end
    for bx = -BB / 2 + menuBay + 0.6, BB / 2 - menuBay - 0.6, 1.1 do
        if freeX(bx) then
            local h = rng:NextNumber(0.9, 1.3)
            local color = BOTTLE_COLORS[rng:NextInteger(1, #BOTTLE_COLORS)]
            local p = pos(bx, y + 0.05, wz - 0.6)
            cylUp(p + V(0, h * 0.35, 0), h * 0.7, 0.32, { Color = color, Material = Enum.Material.Glass, Transparency = 0.2, Reflectance = 0.2 })
            cylUp(p + V(0, h * 0.85, 0), h * 0.3, 0.12, { Color = color, Material = Enum.Material.Glass, Transparency = 0.2 })
        end
    end
end
local px = -BB / 2 + menuBay
while px <= BB / 2 - menuBay + 0.01 do
    if math.abs(px) > centerBay / 2 + 0.5 then
        box(at(px, 6.35, wz - 1.05), V(0.4, 5.8, 0.4), GOLD)
    end
    px += bayWidth
end
for _, side in ipairs({ -1, 1 }) do
    box(at(side * (centerBay / 2 + 0.1), 6.35, wz - 1.05), V(0.4, 5.8, 0.4), GOLD)
    box(at(side * (BB / 2 - menuBay), 6.35, wz - 1.05), V(0.4, 5.8, 0.4), GOLD)
end

local parts = 0
for _, d in ipairs(model:GetDescendants()) do
    if d:IsA("BasePart") then
        parts += 1
    end
end
print(string.format("[Bar] Built the new bar (%d studs long, back wall %.1f studs behind the counter, %d parts). Hid %d old parts.", L, wz, parts, hidden))
