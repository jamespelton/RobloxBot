-- THE HIGH ROLLER LOUNGE (luxury bar rebuild - keeps your game prompts and scripts working)
-- Written by James. Changes are marked [REX]:
--
--   1. The hide pass hid ANY part in a big box around the bar unless its
--      folder was on the KEEP list, and most of the casino is not on it
--      (Shell, Floor, Decor, Planters...). It would have hidden the bases and
--      trim of the columns beside the bar, the potted palms, the jackpot
--      board and floor/wall trim. It also only hid parts below 11 studs, so
--      the old back wall, its glow panel, the top shelf of bottles, the glass
--      rack over the counter and the old sign stayed up behind the new bar.
--      It now hides exactly the old bar model - all of it - and nothing else,
--      so KEEP is gone.
--   2. The 19 old bar stools kept working seats once they were invisible, so
--      players could sit on thin air. Old seats are disabled now.
--   3. The bar stool Seat was built by cylUp(), which turns the part 90
--      degrees about Z to stand the cylinder up. A Seat orients the sitter by
--      its own CFrame, so players would have sat lying on their side. It is
--      an upright SitPad facing the bar now, as on the other tables.
--   4. The backslash-n in BAR_NAME is turned into a real line break when the
--      script is pasted through the Studio bridge, which splits the string
--      and stops it compiling. The break is built from string.char(10).
--   5. A second run built a second bar on top of the first, and the new
--      sign says HIGH ROLLER too, so the search could find it instead of the
--      old one. The previous build is ignored while searching and replaced.
--      OldTransparency is only recorded once, so the old look can come back.
--   6. The globe lights hung from rods that stopped in mid-air 16 studs up,
--      under a 45-stud ceiling. They reach the ceiling now.
--   7. Parented into the Casino folder, like the other builds.
--   8. The back wall was found with one ray 6 studs up, which passes over the
--      gold band running along the wall at 3-5 studs. With the old bar's own
--      back wall gone, the back bar's shelves, bottles and mirror were built
--      through that band. The wall is now probed at several heights and the
--      nearest surface is used.

-- Settings:
local NL = string.char(10) -- [REX] see note 4
local BAR_NAME = "THE HIGH ROLLER" .. NL .. "LOUNGE"
local MENU = {
    "SPARKLING CIDER   $8", "SHIRLEY TEMPLE   $6", "ROOT BEER FLOAT   $7",
    "FRUIT PUNCH   $5", "LEMONADE   $5", "HOT COCOA   $6",
}
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
local SHELF_GLASS = { Color = Color3.fromRGB(200, 225, 235), Material = Enum.Material.Glass, Transparency = 0.5 }
local GLASS = { Color = Color3.fromRGB(220, 235, 245), Material = Enum.Material.Glass, Transparency = 0.55 }
local NEON_WARM = { Color = Color3.fromRGB(255, 225, 170), Material = Enum.Material.Neon }
local NEON_AMBER = { Color = Color3.fromRGB(255, 170, 60), Material = Enum.Material.Neon }
local NEON_GOLD = { Color = Color3.fromRGB(255, 200, 90), Material = Enum.Material.Neon }
local BLACK = { Color = Color3.fromRGB(18, 18, 20), Material = Enum.Material.SmoothPlastic }
local SHADE = { Color = Color3.fromRGB(240, 225, 195), Material = Enum.Material.Fabric }
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
local function flat(v)
    return V(v.X, 0, v.Z)
end

----------------------------------------------------------------
-- Find the old bar
----------------------------------------------------------------
-- [REX] the previous build is ignored while searching, then replaced (note 5)
local casinoRoot = workspace:FindFirstChild("Casino") or workspace
local previous = casinoRoot:FindFirstChild("LuxuryBar") or workspace:FindFirstChild("LuxuryBar")

local signPart
for _, d in ipairs(workspace:GetDescendants()) do
    if (d:IsA("TextLabel") or d:IsA("TextBox")) and string.find(string.upper(d.Text), "HIGH ROLLER")
        and not (previous and d:IsDescendantOf(previous)) then
        signPart = d:FindFirstAncestorWhichIsA("BasePart")
        if not signPart then
            local surface = d:FindFirstAncestorWhichIsA("SurfaceGui")
            if surface and surface.Adornee and surface.Adornee:IsA("BasePart") then
                signPart = surface.Adornee
            end
        end
        if signPart then
            break
        end
    end
end
if not signPart then
    error("[Bar] Couldn't find the 'HIGH ROLLER' sign. Make sure your bar sign still says THE HIGH ROLLER LOUNGE.")
end
local signPos = signPart.Position

-- [REX] the old bar is the model the sign belongs to; only that gets hidden (note 1)
local barModel = signPart:FindFirstAncestorWhichIsA("Model") or signPart.Parent

-- The counter = the longest long, low part of the old bar
local counter, bestLong = nil, 0
for _, p in ipairs(barModel:GetDescendants()) do
    if p:IsA("BasePart") and p ~= signPart then
        local s = p.Size
        local long, short = math.max(s.X, s.Z), math.min(s.X, s.Z)
        local dist = (flat(p.Position) - flat(signPos)).Magnitude
        if long >= 20 and short <= 8 and s.Y <= 6 and dist <= 45 and p.Position.Y < signPos.Y and long > bestLong then
            counter, bestLong = p, long
        end
    end
end
if not counter then
    error("[Bar] Found the sign but not the bar counter next to it.")
end

local longAxis = flat(counter.Size.X >= counter.Size.Z and counter.CFrame.RightVector or counter.CFrame.LookVector).Unit
local center = flat(counter.Position)
local backDir = UP:Cross(longAxis)
if (flat(signPos) - center):Dot(backDir) < 0 then
    backDir = -backDir
end
local L = math.clamp(bestLong, 16, 120)
local counterTop = counter.Position.Y + counter.Size.Y / 2

-- [REX] rays look straight through the old bar and the previous build
local ignore = { barModel }
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

-- Floor height: lowest hit in front of the bar
local floorY = math.huge
for i = -2, 2 do
    local origin = V(center.X, counterTop + 1, center.Z) + longAxis * (i * L / 5) - backDir * 4
    local hit = castIgnoring(origin, V(0, -40, 0))
    if hit then
        floorY = math.min(floorY, hit.Position.Y)
    end
end
if floorY == math.huge then
    floorY = counter.Position.Y - counter.Size.Y / 2
end
local ht = math.clamp(counterTop - floorY, 3.4, 4.3)

-- Back wall: the nearest wall surface behind the bar
-- [REX] probed at several heights, and long trim counts as wall too. One ray
-- at 6 studs went over the gold band that runs along the wall at 3-5 studs,
-- and the back bar was built straight through it (note 8)
local wallZ
for _, h in ipairs({ 1, 3.5, 4.5, 6, 8.5 }) do
    local skip = {}
    local origin = V(center.X, floorY + h, center.Z)
    for _ = 1, 15 do
        local hit = castIgnoring(origin, backDir * 40, skip)
        if not hit then
            break
        end
        local s = hit.Instance.Size
        if math.max(s.X, s.Y, s.Z) >= 10 then
            local dist = (hit.Position - origin):Dot(backDir)
            wallZ = wallZ and math.min(wallZ, dist) or dist
            break
        end
        table.insert(skip, hit.Instance)
    end
end
wallZ = math.clamp(wallZ or ((flat(signPos) - center):Dot(backDir) + 0.3), 5, 20)

local xAxis = UP:Cross(backDir)
local T = CFrame.fromMatrix(V(center.X, floorY, center.Z), xAxis, UP) -- +Z points to the back wall

-- Hide the old bar (parts stay in place so prompts and scripts keep working)
-- [REX] exactly the old bar model, all of it (notes 1, 2, 5)
local hidden = 0
for _, p in ipairs(barModel:GetDescendants()) do
    if p:IsA("BasePart") then
        if p:GetAttribute("OldTransparency") == nil then
            p:SetAttribute("OldTransparency", p.Transparency)
            p:SetAttribute("OldCanCollide", p.CanCollide)
        end
        p.Transparency = 1
        p.CanCollide = false
        if p:IsA("Seat") then
            if p:GetAttribute("OldDisabled") == nil then
                p:SetAttribute("OldDisabled", p.Disabled)
            end
            p.Disabled = true
        end
        hidden += 1
    elseif p:IsA("Decal") or p:IsA("Texture") then
        p.Transparency = 1
    elseif p:IsA("SurfaceGui") then
        p.Enabled = false
    elseif p:IsA("Light") then
        p.Enabled = false
    end
end

-- [REX] how far up the globe light rods have to reach (note 6)
local function ceilingAbove(p)
    local hit = castIgnoring(p, V(0, 120, 0))
    return hit and hit.Position.Y or nil
end

----------------------------------------------------------------
-- Build the new bar (local: X along the bar, -Z = guests, +Z = back wall)
----------------------------------------------------------------
local function at(x, y, z)
    return T * CFrame.new(x, y, z)
end
local function pos(x, y, z)
    return T * V(x, y, z)
end

if previous then
    previous:Destroy()
end
local folder = Instance.new("Model")
folder.Name = "LuxuryBar"
folder.Parent = casinoRoot
current = folder

-- Front bar
box(at(0, 0.2, 0), V(L, 0.4, 2.5), GRANITE).CanCollide = true
box(at(0, (ht - 0.3) / 2 + 0.2, 0), V(L, ht - 0.7, 2.4), MAHOGANY).CanCollide = true
local panelW = 6
local panels = math.floor(L / panelW)
local panelH = ht - 1.6
for i = 0, panels - 1 do
    local x = -L / 2 + (i + 0.5) * L / panels
    local cf = at(x, 0.8 + panelH / 2, -1.25)
    box(cf, V(L / panels - 0.7, panelH, 0.1), LEATHER)
    for _, dy in ipairs({ -panelH / 2, panelH / 2 }) do
        box(cf * CFrame.new(0, dy, -0.05), V(L / panels - 0.6, 0.1, 0.05), GOLD)
    end
    for _, dx in ipairs({ -(L / panels - 0.7) / 2, (L / panels - 0.7) / 2 }) do
        box(cf * CFrame.new(dx, 0, -0.05), V(0.1, panelH, 0.05), GOLD)
    end
    for _, dy in ipairs({ -panelH / 4, panelH / 4 }) do
        ball((cf * CFrame.new(0, dy, -0.08)).Position, 0.14, GOLD)
    end
end
for _, side in ipairs({ -1, 1 }) do
    cylUp(pos(side * L / 2, (ht - 0.3) / 2 + 0.2, 0), ht - 0.7, 2.4, MAHOGANY).CanCollide = true
    cylUp(pos(side * L / 2, ht, -0.25), 0.3, 3.4, MARBLE).CanCollide = true
end
box(at(0, ht, -0.25), V(L, 0.3, 3.4), MARBLE).CanCollide = true
box(at(0, ht - 0.17, -1.96), V(L, 0.08, 0.05), GOLD)
box(at(0, ht - 0.25, -1.6), V(L, 0.06, 0.1), NEON_WARM)
rod(pos(-L / 2, ht + 0.12, -1.75), pos(L / 2, ht + 0.12, -1.75), 0.5, LEATHER)
rod(pos(-L / 2 + 1, 0.7, -1.95), pos(L / 2 - 1, 0.7, -1.95), 0.25, BRASS)
for x = -L / 2 + 1, L / 2 - 1, 6 do
    rod(pos(x, 0.7, -1.95), pos(x, 1.0, -1.25), 0.15, BRASS)
end

-- Bartender's work counter
box(at(0, 1.45, 1.9), V(L - 2, 2.9, 1.2), STEEL).CanCollide = true
box(at(0, 2.92, 1.9), V(L - 2, 0.05, 1.25), CHROME)
box(at(-L / 4, 2.93, 1.9), V(2, 0.04, 0.9), { Color = Color3.fromRGB(220, 235, 245), Material = Enum.Material.Ice })
for _, x in ipairs({ L / 6, L / 3 }) do
    box(at(x, 2.93, 1.9), V(1.2, 0.04, 0.8), BLACK)
    rod(pos(x, 2.95, 2.35), pos(x, 3.6, 2.35), 0.1, CHROME)
    rod(pos(x, 3.6, 2.35), pos(x, 3.6, 2.0), 0.1, CHROME)
end

-- Beer taps
for x = -L / 2 + 8, L / 2 - 8, 16 do
    cylUp(pos(x, ht + 0.85, 0.5), 1.4, 0.5, CHROME)
    rod(pos(x - 0.9, ht + 1.4, 0.5), pos(x + 0.9, ht + 1.4, 0.5), 0.25, CHROME)
    for i = -1.5, 1.5 do
        box(at(x + i * 0.55, ht + 1.85, 0.5), V(0.15, 0.6, 0.15), { Color = BOTTLE_COLORS[rng:NextInteger(1, #BOTTLE_COLORS)], Material = Enum.Material.SmoothPlastic })
    end
    box(at(x, ht + 0.19, 0.1), V(1.8, 0.08, 0.5), CHROME)
end

-- Lamps on the bar top
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

-- Stools, glasses and coasters
local stoolH = math.clamp(ht - 1.2, 2.2, 3.2)
for x = -L / 2 + 1.8, L / 2 - 1.8, 3.4 do
    local base = CFrame.lookAt(pos(x, 0, -3.4), pos(x, 0, -3.4) + T:VectorToWorldSpace(V(0, 0, 1)))
    local function c(localPos, height, width, style, className)
        return cylUp(base * localPos, height, width, style, className)
    end
    c(V(0, 0.12, 0), 0.25, 2.0, GOLD).CanCollide = true
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
    -- [REX] plain cushion; the Seat is an upright block facing the bar (note 3)
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

    -- A glass on a coaster in front of some stools
    if rng:NextNumber() < 0.55 then
        local g = pos(x + rng:NextNumber(-0.4, 0.4), ht + 0.15, -1.1)
        cylUp(g + V(0, 0.01, 0), 0.02, 0.6, DARK_WOOD)
        cylUp(g + V(0, 0.04, 0), 0.04, 0.4, GLASS)
        cylUp(g + V(0, 0.3, 0), 0.5, 0.06, GLASS)
        ellipsoid(g + V(0, 0.65, 0), V(0.55, 0.35, 0.55), GLASS)
        ellipsoid(g + V(0, 0.62, 0), V(0.42, 0.22, 0.42), { Color = DRINK_COLORS[rng:NextInteger(1, #DRINK_COLORS)], Material = Enum.Material.Glass, Transparency = 0.2 })
    end
end

-- Hanging globe lights over the bar
local pendantIndex = 0
for x = -L / 2 + 3, L / 2 - 3, 6 do
    pendantIndex += 1
    -- [REX] run the rod up to the ceiling (note 6)
    local start = pos(x, ht + 6.6, -0.3)
    local ceiling = ceilingAbove(start + V(0, 0.5, 0))
    local topY = ceiling and math.min(ceiling, start.Y + 80) or start.Y + 9.4
    rod(start, V(start.X, topY, start.Z), 0.08, GOLD)
    cylUp(pos(x, ht + 6.6, -0.3), 0.2, 0.4, GOLD)
    local globe = ball(pos(x, ht + 6.1, -0.3), 0.9, NEON_WARM)
    if pendantIndex % 2 == 0 then
        pointLight(globe, 14, 0.8)
    end
end

----------------------------------------------------------------
-- Back bar
----------------------------------------------------------------
local wz = wallZ
local BB = L - 1
-- Cabinet with doors
box(at(0, 1.6, wz - 1.1), V(BB, 3.2, 2.0), MAHOGANY).CanCollide = true
box(at(0, 0.2, wz - 1.1), V(BB, 0.4, 2.05), GRANITE)
for x = -BB / 2 + 1.3, BB / 2 - 1.3, 2.5 do
    box(at(x, 1.75, wz - 2.12), V(2.2, 2.4, 0.05), DARK_WOOD)
    ball(pos(x + 0.8, 1.9, wz - 2.17), 0.15, GOLD)
end
box(at(0, 3.32, wz - 1.15), V(BB + 0.2, 0.25, 2.2), MARBLE)
for _, x in ipairs({ -L / 4, L / 4 }) do
    local screenPos = pos(x, 3.9, wz - 1.6)
    local screenCF = CFrame.lookAt(screenPos, screenPos - T:VectorToWorldSpace(V(0, 0, 1))) * CFrame.Angles(math.rad(-15), 0, 0)
    box(screenCF, V(1.2, 0.85, 0.1), BLACK)
    box(screenCF * CFrame.new(0, 0, -0.06), V(1.05, 0.7, 0.02), { Color = Color3.fromRGB(80, 160, 255), Material = Enum.Material.Neon })
    box(at(x, 3.5, wz - 1.6), V(0.5, 0.15, 0.5), BLACK)
end

-- Mirror wall with gold frame
local mirrorBottom, mirrorTop = 3.45, 9.2
box(at(0, (mirrorBottom + mirrorTop) / 2, wz - 0.1), V(BB, mirrorTop - mirrorBottom, 0.1), MIRROR)
box(at(0, 9.45, wz - 0.75), V(BB + 0.4, 0.5, 1.5), MAHOGANY)
box(at(0, 9.2, wz - 1.5), V(BB + 0.4, 0.08, 0.05), GOLD)
box(at(0, 9.72, wz - 1.5), V(BB + 0.4, 0.06, 0.05), NEON_GOLD)

-- Center sign bay and menu bays
local centerBay = math.min(12, L * 0.25)
local menuBay = 6
local signCF = at(0, 6.3, wz - 0.3)
local signPanel = box(signCF, V(centerBay - 1, 3.2, 0.2), BLACK)
local signGui = Instance.new("SurfaceGui")
signGui.Face = Enum.NormalId.Front
signGui.LightInfluence = 0
signGui.Brightness = 1.6
signGui.Parent = signPanel
-- The panel's front faces away from the wall
signPanel.CFrame = CFrame.lookAt(signPanel.Position, signPanel.Position - T:VectorToWorldSpace(V(0, 0, 1)))
local title = Instance.new("TextLabel")
title.Size = UDim2.fromScale(1, 0.75)
title.Position = UDim2.fromScale(0, 0.05)
title.BackgroundTransparency = 1
title.Text = BAR_NAME
title.TextScaled = true
title.Font = Enum.Font.Bodoni
title.TextColor3 = Color3.fromRGB(255, 215, 110)
title.Parent = signGui
local crown = Instance.new("TextLabel")
crown.Size = UDim2.fromScale(1, 0.2)
crown.Position = UDim2.fromScale(0, 0.78)
crown.BackgroundTransparency = 1
crown.Text = "★  ★  ★"
crown.TextScaled = true
crown.Font = Enum.Font.GothamBold
crown.TextColor3 = Color3.fromRGB(255, 200, 90)
crown.Parent = signGui
for _, dy in ipairs({ -1.7, 1.7 }) do
    box(signCF * CFrame.new(0, dy, -0.12), V(centerBay - 0.8, 0.12, 0.05), NEON_GOLD)
end
for _, dx in ipairs({ -(centerBay - 0.8) / 2, (centerBay - 0.8) / 2 }) do
    box(signCF * CFrame.new(dx, 0, -0.12), V(0.12, 3.5, 0.05), NEON_GOLD)
end

for _, side in ipairs({ -1, 1 }) do
    local mx = side * (BB / 2 - menuBay / 2)
    local menuCF = CFrame.lookAt(pos(mx, 6.3, wz - 0.25), pos(mx, 6.3, wz - 0.25) - T:VectorToWorldSpace(V(0, 0, 1)))
    local board = box(menuCF, V(menuBay - 1, 4.2, 0.15), { Color = Color3.fromRGB(28, 30, 32), Material = Enum.Material.Slate })
    for _, dy in ipairs({ -2.1, 2.1 }) do
        box(menuCF * CFrame.new(0, dy, 0), V(menuBay - 0.8, 0.15, 0.25), GOLD)
    end
    for _, dx in ipairs({ -(menuBay - 1) / 2, (menuBay - 1) / 2 }) do
        box(menuCF * CFrame.new(dx, 0, 0), V(0.15, 4.3, 0.25), GOLD)
    end
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
local shelfYs = { 4.6, 6.2, 7.8 }
local function freeX(x)
    if math.abs(x) < centerBay / 2 + 0.3 then
        return false
    end
    if math.abs(x) > BB / 2 - menuBay - 0.2 then
        return false
    end
    return true
end
for _, y in ipairs(shelfYs) do
    for _, side in ipairs({ -1, 1 }) do
        local x0, x1 = side * (centerBay / 2 + 0.3), side * (BB / 2 - menuBay - 0.2)
        local mid, width = (x0 + x1) / 2, math.abs(x1 - x0)
        box(at(mid, y, wz - 0.6), V(width, 0.1, 0.9), SHELF_GLASS)
        box(at(mid, y - 0.08, wz - 1.02), V(width, 0.06, 0.06), NEON_AMBER)
    end
    for x = -BB / 2 + menuBay + 0.6, BB / 2 - menuBay - 0.6, 0.9 do
        if freeX(x) then
            local h = rng:NextNumber(0.9, 1.3)
            local color = BOTTLE_COLORS[rng:NextInteger(1, #BOTTLE_COLORS)]
            local p = pos(x, y + 0.05, wz - 0.6)
            cylUp(p + V(0, h * 0.35, 0), h * 0.7, 0.32, { Color = color, Material = Enum.Material.Glass, Transparency = 0.2, Reflectance = 0.2 })
            cylUp(p + V(0, h * 0.85, 0), h * 0.3, 0.12, { Color = color, Material = Enum.Material.Glass, Transparency = 0.2 })
        end
    end
end
for x = -BB / 2 + menuBay, BB / 2 - menuBay, 9 do
    if math.abs(x) > centerBay / 2 + 0.5 then
        box(at(x, 6.35, wz - 1.05), V(0.4, 5.8, 0.4), GOLD)
    end
end
for _, side in ipairs({ -1, 1 }) do
    box(at(side * (centerBay / 2 + 0.1), 6.35, wz - 1.05), V(0.4, 5.8, 0.4), GOLD)
    box(at(side * (BB / 2 - menuBay), 6.35, wz - 1.05), V(0.4, 5.8, 0.4), GOLD)
end

local parts = 0
for _, d in ipairs(folder:GetDescendants()) do
    if d:IsA("BasePart") then
        parts += 1
    end
end
print(string.format("[Bar] Built the new bar (%d studs long, %d parts). Hid %d old parts.", L, parts, hidden))
