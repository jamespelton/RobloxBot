-- LUXURY CASINO ROOFTOP (use together with the front and sides/back/roof scripts)
-- Written by James. Changes marked [REX]:
--   1. The roof measurements are cached on the GrandSidesAndRoof model the
--      first time. This script destroys that model's roof deck as part of its
--      clean-up, and the deck is what it measures W, D and RT from, so a
--      second run found nothing, fell through to the Facade fallback and
--      rebuilt the whole rooftop at a different height.
--   2. A previous GrandRooftop is destroyed before anything is measured or
--      swept, so re-running replaces it instead of stacking.
--   3. Parented into the Casino folder, and the OldRoofBackup folder is reused
--      rather than a new one created on every run.
--   4. The blinking-light loop moved into a child Script, so it runs in game
--      instead of spinning inside Studio after an edit-mode build.
--
-- REMOVE_OLD_ROOF sweeps all of Workspace and moves anything standing on the
-- roof into ServerStorage. Dry-run before trusting it: on this place it takes
-- 34 parts - the Facade's corner caps, neon and spires, and the old Roof
-- beacons, HVAC, skylight and edge bands - all of which the new exterior
-- scripts have already replaced. Nothing is deleted; it is all recoverable
-- from ServerStorage.OldRoofBackup.
-- The geometry is untouched.

-- Settings:
local CASINO_NAME = "GOLDEN SPIRE"
local BAR_NAME = "SKY BAR"
local DOME = true
local POOL = true
local HELIPAD = true
local MECHANICAL_YARD = true
local GARDEN = true
local STRING_LIGHTS = true
local REMOVE_OLD_ROOF = true   -- moves old roof pieces to ServerStorage > OldRoofBackup
local ANIMATE_LIGHTS = true
local PARENT_NAME = "Casino"   -- [REX] folder under Workspace

-- Only used if the GrandSidesAndRoof model can't be found:
local MANUAL_DEPTH = 150

-- Things this script will never move
local KEEP = {
    GrandExterior = true, GrandSidesAndRoof = true, GrandRooftop = true, CasinoParkingLot = true,
    ParkedCars = true, Trees = true, PalmTrees = true, ParkingLightPosts = true, IntroCar = true,
    CasinoChandelier = true, PottedPalm = true,
}

local ServerStorage = game:GetService("ServerStorage")

local casinoRoot = workspace:FindFirstChild(PARENT_NAME) or workspace

-- [REX] clear a previous run before measuring or sweeping
local previousRooftop = casinoRoot:FindFirstChild("GrandRooftop")
if previousRooftop then
    previousRooftop:Destroy()
end

----------------------------------------------------------------
-- Measure the roof (from the sides/back/roof script's model)
----------------------------------------------------------------
local FRAME, W, D, RT
local sides
for _ = 1, 100 do
    sides = workspace:FindFirstChild("GrandSidesAndRoof", true)
    if sides then
        break
    end
    task.wait(0.2)
end

if sides then
    FRAME = sides:GetPivot()
    local deck, bestArea = nil, 0
    for _, p in ipairs(sides:GetDescendants()) do
        if p:IsA("BasePart") and p.Material == Enum.Material.Slate and math.abs(p.Size.Y - 0.5) < 0.01 then
            local area = p.Size.X * p.Size.Z
            if area > bestArea then
                deck, bestArea = p, area
            end
        end
    end
    if deck then
        W, D = deck.Size.X, deck.Size.Z
        RT = FRAME:ToObjectSpace(deck.CFrame).Y + 0.25
        -- [REX] remember it: the sweep below destroys this deck, so a second
        -- run has nothing left to measure
        sides:SetAttribute("RooftopW", W)
        sides:SetAttribute("RooftopD", D)
        sides:SetAttribute("RooftopRT", RT)
    elseif sides:GetAttribute("RooftopRT") then
        -- [REX] the deck is gone because this script already ran; reuse the
        -- numbers it measured the first time rather than silently falling
        -- through to the Facade fallback and rebuilding at a different height
        W = sides:GetAttribute("RooftopW")
        D = sides:GetAttribute("RooftopD")
        RT = sides:GetAttribute("RooftopRT")
        print("[Rooftop] reusing the cached roof measurements from the first run")
    end
end

if not RT then
    -- Fallback: measure the Facade folder
    local facade = workspace:FindFirstChild("Facade", true)
    if not facade then
        error("[Rooftop] Couldn't find GrandSidesAndRoof or a Facade folder. Run the other two scripts first.")
    end
    local minV = Vector3.new(math.huge, math.huge, math.huge)
    local maxV = -minV
    for _, p in ipairs(facade:GetDescendants()) do
        if p:IsA("BasePart") then
            minV = minV:Min(p.Position - p.Size / 2)
            maxV = maxV:Max(p.Position + p.Size / 2)
        end
    end
    local center = (minV + maxV) / 2
    local dir = Vector3.new(0, 0, -1)
    local lot = workspace:FindFirstChild("CasinoParkingLot", true) -- [REX] recursive
    if lot then
        dir = lot:GetPivot().Position - center
    end
    if math.abs(dir.X) > math.abs(dir.Z) then
        dir = Vector3.new(dir.X >= 0 and 1 or -1, 0, 0)
    else
        dir = Vector3.new(0, 0, dir.Z >= 0 and 1 or -1)
    end
    local origin
    if dir.X ~= 0 then
        origin = Vector3.new(dir.X > 0 and maxV.X or minV.X, minV.Y, center.Z)
        W = maxV.Z - minV.Z
    else
        origin = Vector3.new(center.X, minV.Y, dir.Z > 0 and maxV.Z or minV.Z)
        W = maxV.X - minV.X
    end
    FRAME = CFrame.lookAt(origin, origin + dir)
    D = MANUAL_DEPTH
    RT = (maxV.Y - minV.Y) - 2.4
end
print(string.format("[Rooftop] Roof is %d wide and %d deep", W, D))

----------------------------------------------------------------
-- Clear the old roof
----------------------------------------------------------------
local function verticalExtent(part)
    local cf, s = part.CFrame, part.Size / 2
    return math.abs(cf.RightVector.Y) * s.X + math.abs(cf.UpVector.Y) * s.Y + math.abs(cf.LookVector.Y) * s.Z
end

local function insideRoof(lp, inset)
    return math.abs(lp.X) < W / 2 - inset and lp.Z > inset and lp.Z < D - inset
end

-- Small roof pieces from the sides/back/roof script
if sides then
    for _, p in ipairs(sides:GetDescendants()) do
        if p:IsA("BasePart") then
            local lp = FRAME:PointToObjectSpace(p.Position)
            local cornerTower = math.abs(lp.X) > W / 2 - 14 and lp.Z > D - 9
            if insideRoof(lp, 1) and lp.Y >= RT - 0.6 and not cornerTower then
                p:Destroy()
            end
        end
    end
end

-- Old roof pieces sticking up through the roof
if REMOVE_OLD_ROOF then
    -- [REX] reuse the backup folder instead of making a new one each run
    local backup = ServerStorage:FindFirstChild("OldRoofBackup")
    if not backup then
        backup = Instance.new("Folder")
        backup.Name = "OldRoofBackup"
        backup.Parent = ServerStorage
    end
    local function protected(inst)
        local p = inst.Parent
        while p and p ~= workspace do
            if KEEP[p.Name] or (p:IsA("Model") and p:FindFirstChildOfClass("Humanoid")) then
                return true
            end
            p = p.Parent
        end
        return false
    end
    local moved = 0
    for _, p in ipairs(workspace:GetDescendants()) do
        if p:IsA("BasePart") and not p:IsA("Terrain") and p:IsDescendantOf(workspace) and not protected(p) then
            local lp = FRAME:PointToObjectSpace(p.Position)
            if insideRoof(lp, 1) then
                local ext = verticalExtent(p)
                if lp.Y + ext > RT + 0.15 and lp.Y - ext > RT - 8 then
                    p.Parent = backup
                    moved += 1
                end
            end
        end
    end
    print("[Rooftop] Moved " .. moved .. " old roof parts to ServerStorage > OldRoofBackup")
end

----------------------------------------------------------------
-- Materials
----------------------------------------------------------------
local STONE = { Color = Color3.fromRGB(228, 218, 198), Material = Enum.Material.Limestone, CanCollide = true }
local STONE_DARK = { Color = Color3.fromRGB(196, 183, 160), Material = Enum.Material.Limestone, CanCollide = true }
local MARBLE = { Color = Color3.fromRGB(242, 238, 230), Material = Enum.Material.Marble, CanCollide = true }
local GRANITE = { Color = Color3.fromRGB(28, 28, 31), Material = Enum.Material.Granite, CanCollide = true }
local GOLD = { Color = Color3.fromRGB(212, 175, 55), Material = Enum.Material.Metal, Reflectance = 0.35, CanCollide = true }
local GRAVEL = { Color = Color3.fromRGB(120, 118, 115), Material = Enum.Material.Pebble, CanCollide = true }
local PAVER = { Color = Color3.fromRGB(220, 210, 190), Material = Enum.Material.Pavement, CanCollide = true }
local JOINT = { Color = Color3.fromRGB(150, 140, 125), Material = Enum.Material.SmoothPlastic }
local GLASS_CEILING = { Color = Color3.fromRGB(255, 230, 190), Material = Enum.Material.Glass, Transparency = 0.6, CanCollide = true }
local FACET = { Color = Color3.fromRGB(255, 205, 140), Material = Enum.Material.Neon, Transparency = 0.45 }
local GLOW = { Color = Color3.fromRGB(255, 190, 110), Material = Enum.Material.Neon, Transparency = 0.3 }
local NEON_GOLD = { Color = Color3.fromRGB(255, 200, 90), Material = Enum.Material.Neon }
local NEON_WARM = { Color = Color3.fromRGB(255, 230, 180), Material = Enum.Material.Neon }
local TEAK = { Color = Color3.fromRGB(150, 100, 65), Material = Enum.Material.WoodPlanks, CanCollide = true }
local POOL_TILE = { Color = Color3.fromRGB(90, 190, 210), Material = Enum.Material.CeramicTiles, CanCollide = true }
local POOL_STRIPE = { Color = Color3.fromRGB(30, 80, 120), Material = Enum.Material.CeramicTiles }
local WATER = { Color = Color3.fromRGB(40, 170, 220), Material = Enum.Material.Glass, Transparency = 0.4, Reflectance = 0.2 }
local CUSHION = { Color = Color3.fromRGB(245, 242, 235), Material = Enum.Material.Fabric }
local CANVAS = { Color = Color3.fromRGB(240, 232, 215), Material = Enum.Material.Fabric }
local CURTAIN = { Color = Color3.fromRGB(250, 248, 242), Material = Enum.Material.Fabric, Transparency = 0.25 }
local LIGHT_WOOD = { Color = Color3.fromRGB(185, 140, 95), Material = Enum.Material.Wood, CanCollide = true }
local DARK_WOOD = { Color = Color3.fromRGB(70, 40, 25), Material = Enum.Material.Wood, CanCollide = true }
local RAIL_GLASS = { Color = Color3.fromRGB(200, 220, 230), Material = Enum.Material.Glass, Transparency = 0.6, CanCollide = true }
local HEDGE = { Color = Color3.fromRGB(40, 85, 38), Material = Enum.Material.LeafyGrass, CanCollide = true }
local SOIL = { Color = Color3.fromRGB(60, 42, 30), Material = Enum.Material.Ground }
local BLACK_METAL = { Color = Color3.fromRGB(25, 25, 28), Material = Enum.Material.Metal, CanCollide = true }
-- [REX] cable for the string lights
local CABLE = { Color = Color3.fromRGB(28, 26, 24), Material = Enum.Material.Fabric, CanCollide = false }
local UNIT_METAL = { Color = Color3.fromRGB(175, 178, 182), Material = Enum.Material.Metal, CanCollide = true }
local DARK_METAL = { Color = Color3.fromRGB(60, 62, 66), Material = Enum.Material.Metal, CanCollide = true }
local CONCRETE = { Color = Color3.fromRGB(165, 165, 160), Material = Enum.Material.Concrete, CanCollide = true }
local HELI_PAD = { Color = Color3.fromRGB(45, 45, 48), Material = Enum.Material.Asphalt, CanCollide = true }
local WHITE_PAINT = { Color = Color3.fromRGB(240, 240, 235), Material = Enum.Material.SmoothPlastic }
local YELLOW_PAINT = { Color = Color3.fromRGB(240, 200, 40), Material = Enum.Material.SmoothPlastic }
local RED_SEAT = { Color = Color3.fromRGB(160, 20, 30), Material = Enum.Material.Leather }

local UP = Vector3.new(0, 1, 0)
local rng = Random.new(77)
local function rand(a, b)
    return rng:NextNumber(a, b)
end

local model = Instance.new("Model")
model.Name = "GrandRooftop"

----------------------------------------------------------------
-- Building helpers
----------------------------------------------------------------
local function makePart(props)
    local p = Instance.new("Part")
    p.Anchored = true
    p.CanCollide = false
    p.CanTouch = false
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    for key, value in pairs(props) do
        p[key] = value
    end
    p.Parent = model
    return p
end

local function styled(props, style)
    for key, value in pairs(style) do
        props[key] = value
    end
    return makePart(props)
end

local function V(x, y, z)
    return Vector3.new(x, y, z)
end

local function upFor(d)
    return math.abs(d.Y) > 0.98 and V(1, 0, 0) or UP
end

local function lookAtSafe(pos, target)
    return CFrame.lookAt(pos, target, upFor((target - pos).Unit))
end

local function box(cf, size, style)
    return styled({ Size = size, CFrame = cf }, style)
end

local function B(x, y, z, sx, sy, sz, style)
    return box(CFrame.new(x, y, z), V(sx, sy, sz), style)
end

local function rangeBox(x0, x1, y0, y1, z0, z1, style)
    if x1 - x0 <= 0.01 or y1 - y0 <= 0.01 or z1 - z0 <= 0.01 then
        return nil
    end
    return B((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2, x1 - x0, y1 - y0, z1 - z0, style)
end

local function ball(pos, size, style)
    return styled({ Shape = Enum.PartType.Ball, Size = V(size, size, size), CFrame = CFrame.new(pos) }, style)
end

local function ellipsoid(cf, size, style)
    if typeof(cf) == "Vector3" then
        cf = CFrame.new(cf)
    end
    local p = box(cf, size, style)
    local mesh = Instance.new("SpecialMesh")
    mesh.MeshType = Enum.MeshType.Sphere
    mesh.Parent = p
    return p
end

local function cylUp(pos, height, width, style)
    return styled({
        Shape = Enum.PartType.Cylinder,
        Size = V(height, width, width),
        CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)),
    }, style)
end

local function rod(a, b, thickness, style)
    return styled({
        Shape = Enum.PartType.Cylinder,
        Size = V((b - a).Magnitude + thickness * 0.3, thickness, thickness),
        CFrame = lookAtSafe((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0),
    }, style)
end

local function flatLeaf(base, direction, length, width, color)
    local p = makePart({
        Size = V(width, 0.06, length),
        CFrame = CFrame.lookAt(base + direction * length / 2, base + direction * length, upFor(direction)),
        Color = color,
        Material = Enum.Material.SmoothPlastic,
    })
    local mesh = Instance.new("SpecialMesh")
    mesh.MeshType = Enum.MeshType.Sphere
    mesh.Parent = p
    return p
end

local function pointLight(part, color, range, brightness)
    local light = Instance.new("PointLight")
    light.Color = color
    light.Range = math.min(range, 60)
    light.Brightness = brightness
    light.Parent = part
end

local function spotDown(part, range, angle)
    local spot = Instance.new("SpotLight")
    spot.Face = Enum.NormalId.Bottom
    spot.Color = Color3.fromRGB(255, 225, 170)
    spot.Range = range
    spot.Angle = angle
    spot.Brightness = 2
    spot.Parent = part
end

local function uplight(pos, aim)
    local fixture = box(lookAtSafe(pos, aim), V(0.8, 0.6, 1.0), BLACK_METAL)
    makePart({ Size = V(0.6, 0.45, 0.05), CFrame = fixture.CFrame * CFrame.new(0, 0, -0.52), Color = Color3.fromRGB(255, 205, 130), Material = Enum.Material.Neon })
    local light = Instance.new("SpotLight")
    light.Face = Enum.NormalId.Front
    light.Color = Color3.fromRGB(255, 205, 130)
    light.Brightness = 4
    light.Range = 40
    light.Angle = 40
    light.Parent = fixture
end

local function textPanel(cf, sx, sy, text, font)
    local p = box(cf, V(sx, sy, 0.04), { Transparency = 1 })
    local gui = Instance.new("SurfaceGui")
    gui.Face = Enum.NormalId.Front
    gui.LightInfluence = 0
    gui.Brightness = 1.6
    gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    gui.PixelsPerStud = 40
    gui.Parent = p
    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextScaled = true
    label.Font = font or Enum.Font.Bodoni
    label.TextColor3 = Color3.new(1, 1, 1)
    label.Parent = gui
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(60, 40, 0)
    stroke.Thickness = 2
    stroke.Parent = label
    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(200, 155, 40)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 240, 170)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 155, 40)),
    })
    gradient.Rotation = 90
    gradient.Parent = label
end

-- Boxes arranged in a circle (tangent to the circle)
local function ringBoxes(cx, cz, radius, y, count, height, depth, style)
    for i = 0, count - 1 do
        local a = (i + 0.5) / count * math.pi * 2
        local pos = V(cx + math.cos(a) * radius, y, cz + math.sin(a) * radius)
        local width = 2 * radius * math.sin(math.pi / count) + 0.15
        box(CFrame.lookAt(pos, V(cx, y, cz)), V(width, height, depth), style)
    end
end

local function ringRods(cx, y, cz, radius, count, thickness, style)
    local last
    for i = 0, count do
        local a = i / count * math.pi * 2
        local point = V(cx + math.cos(a) * radius, y, cz + math.sin(a) * radius)
        if last then
            rod(last, point, thickness, style)
        end
        last = point
    end
end

local function paving(x0, x1, z0, z1)
    if rangeBox(x0, x1, RT, RT + 0.15, z0, z1, PAVER) then
        for x = x0 + 6, x1 - 1, 6 do
            B(x, RT + 0.155, (z0 + z1) / 2, 0.08, 0.01, z1 - z0, JOINT)
        end
        for z = z0 + 6, z1 - 1, 6 do
            B((x0 + x1) / 2, RT + 0.155, z, x1 - x0, 0.01, 0.08, JOINT)
        end
    end
end

local blinkers = {}

-- Rectangles already used on the roof
local used = {}
local function free(x0, x1, z0, z1)
    if x0 < -W / 2 + 2 or x1 > W / 2 - 2 or z0 < 2 or z1 > D - 2 then
        return false
    end
    for _, r in ipairs(used) do
        if x0 < r[2] and x1 > r[1] and z0 < r[4] and z1 > r[3] then
            return false
        end
    end
    return true
end
local function claim(x0, x1, z0, z1)
    table.insert(used, { x0, x1, z0, z1 })
end

----------------------------------------------------------------
-- Layout
----------------------------------------------------------------
local M = 6
local zc = D * 0.42
local R = math.clamp(math.min(W, D) * 0.15, 10, 28)
local HOLE = R * 0.7 -- half size of the glass ceiling opening under the dome
local PH = R + 10    -- half size of the plaza around the dome

----------------------------------------------------------------
-- Roof surface (gravel, with an opening under the dome)
----------------------------------------------------------------
local holeX, holeZ = DOME and HOLE or 0, DOME and HOLE or 0
rangeBox(-W / 2, W / 2, RT - 0.5, RT, 0, zc - holeZ, GRAVEL)
rangeBox(-W / 2, W / 2, RT - 0.5, RT, zc + holeZ, D, GRAVEL)
rangeBox(-W / 2, -holeX, RT - 0.5, RT, zc - holeZ, zc + holeZ, GRAVEL)
rangeBox(holeX, W / 2, RT - 0.5, RT, zc - holeZ, zc + holeZ, GRAVEL)

-- Walkway around the edge
paving(-W / 2 + 1, W / 2 - 1, D - 7, D - 1)
paving(-W / 2 + 1, -W / 2 + 7, 1, D - 7)
paving(W / 2 - 7, W / 2 - 1, 1, D - 7)

----------------------------------------------------------------
-- Grand glass dome
----------------------------------------------------------------
if DOME then
    claim(-PH, PH, zc - PH, zc + PH)
    -- Plaza around the dome
    paving(-PH, PH, zc - PH, zc - HOLE)
    paving(-PH, PH, zc + HOLE, zc + PH)
    paving(-PH, -HOLE, zc - HOLE, zc + HOLE)
    paving(HOLE, PH, zc - HOLE, zc + HOLE)

    -- Glass ceiling so players inside can look up into the dome
    local ceiling = rangeBox(-HOLE, HOLE, RT - 0.6, RT - 0.4, zc - HOLE, zc + HOLE, GLASS_CEILING)
    pointLight(ceiling, Color3.fromRGB(255, 210, 140), 50, 1.5)

    -- Base ring, drum with lit windows, ring of columns
    ringBoxes(0, zc, R + 2.75, RT + 0.75, 32, 1.2, 4.5, STONE_DARK)
    ringRods(0, RT + 1.35, zc, R + 5, 32, 0.25, GOLD)
    local drumBottom, drumTop = RT + 1.35, RT + 7.35
    ringBoxes(0, zc, R + 0.5, (drumBottom + drumTop) / 2, 24, drumTop - drumBottom, 1, STONE)
    for i = 0, 23 do
        local a = (i + 0.5) / 24 * math.pi * 2
        local outward = V(math.cos(a), 0, math.sin(a))
        local pos = V(0, (drumBottom + drumTop) / 2, zc) + outward * (R + 1.03)
        box(CFrame.lookAt(pos, pos + outward), V(2 * (R + 1) * math.sin(math.pi / 24) * 0.5, 3, 0.05), GLOW)
    end
    ringBoxes(0, zc, R + 0.6, drumTop + 0.2, 32, 0.4, 1.6, GOLD)

    local colRadius = R + 3.5
    local columns = math.max(12, math.floor(2 * math.pi * colRadius / 4.5))
    for i = 0, columns - 1 do
        local a = i / columns * math.pi * 2
        local x, z = math.cos(a) * colRadius, zc + math.sin(a) * colRadius
        B(x, drumBottom + 0.2, z, 1.4, 0.4, 1.4, STONE_DARK)
        cylUp(V(x, drumBottom + 3, z), 5.6, 1, MARBLE)
        B(x, drumTop - 0.15, z, 1.5, 0.5, 1.5, GOLD)
    end
    ringBoxes(0, zc, colRadius, drumTop + 0.35, 32, 0.9, 1.8, STONE_DARK)
    ringBoxes(0, zc, R + 2, drumTop + 0.1, 32, 0.4, 3.5, STONE)
    ringRods(0, drumTop - 0.6, zc, colRadius + 0.8, 32, 0.15, NEON_GOLD)

    -- Glowing glass shell with gold ribs
    local c = V(0, drumTop, zc)
    local rings, slices = 6, 16
    for i = 0, rings - 1 do
        local phi0, phi1 = i / rings * math.pi / 2, (i + 1) / rings * math.pi / 2
        local pm = (phi0 + phi1) / 2
        for j = 0, slices - 1 do
            local a = (j + 0.5) / slices * math.pi * 2
            local normal = V(math.cos(pm) * math.cos(a), math.sin(pm), math.cos(pm) * math.sin(a))
            local up = V(-math.sin(pm) * math.cos(a), math.cos(pm), -math.sin(pm) * math.sin(a))
            local pos = c + normal * R
            local width = 2 * R * math.cos(phi0) * math.sin(math.pi / slices) + 0.15
            local height = 2 * R * math.sin((phi1 - phi0) / 2) + 0.1
            box(CFrame.lookAt(pos, pos + normal, up), V(width, height, 0.12), FACET)
        end
    end
    for j = 0, slices - 1 do
        local a = j / slices * math.pi * 2
        local last
        for t = 0, rings do
            local phi = t / rings * math.pi / 2
            local point = c + V(math.cos(phi) * math.cos(a), math.sin(phi), math.cos(phi) * math.sin(a)) * (R + 0.12)
            if last then
                rod(last, point, 0.35, GOLD)
            end
            last = point
        end
    end
    for t = 1, rings - 1 do
        local phi = t / rings * math.pi / 2
        ringRods(0, c.Y + (R + 0.12) * math.sin(phi), zc, (R + 0.12) * math.cos(phi), slices, 0.25, GOLD)
    end
    ringRods(0, c.Y, zc, R + 0.15, slices, 0.5, GOLD)

    -- Lantern on top
    local top = c.Y + R
    cylUp(V(0, top + 1.1, zc), 2.5, 3.6, STONE)
    for k = 0, 5 do
        local a = k / 6 * math.pi * 2
        cylUp(V(math.cos(a) * 1.9, top + 1.1, zc + math.sin(a) * 1.9), 2.5, 0.3, GOLD)
    end
    ellipsoid(V(0, top + 2.4, zc), V(4, 2.6, 4), GOLD)
    rod(V(0, top + 3.5, zc), V(0, top + 9, zc), 0.35, GOLD)
    local tip = ball(V(0, top + 9.3, zc), 1, NEON_GOLD)
    pointLight(tip, Color3.fromRGB(255, 200, 90), 30, 2)

    for k = 0, 3 do
        local a = k / 4 * math.pi * 2 + math.pi / 4
        local pos = V(math.cos(a) * (R + 7), RT + 0.5, zc + math.sin(a) * (R + 7))
        uplight(pos, V(0, drumTop + R * 0.4, zc))
    end
end

----------------------------------------------------------------
-- Small trees and palms
----------------------------------------------------------------
local function smallTree(x, z, groundY)
    B(x, groundY + 0.8, z, 6, 1.6, 6, GRANITE)
    B(x, groundY + 1.62, z, 6.1, 0.06, 6.1, GOLD)
    B(x, groundY + 1.62, z, 5.4, 0.08, 5.4, SOIL)
    local top = V(x + rand(-0.3, 0.3), groundY + rand(7, 9), z + rand(-0.3, 0.3))
    rod(V(x, groundY + 1.6, z), top, 0.5, DARK_WOOD)
    for _ = 1, 5 do
        local shade = rand(0.8, 1.2)
        ball(top + V(rand(-1.5, 1.5), rand(-0.8, 1.2), rand(-1.5, 1.5)), rand(2.4, 3.4), {
            Color = Color3.fromRGB(50 * shade, 100 * shade, 45 * shade),
            Material = Enum.Material.LeafyGrass,
        })
    end
    uplight(V(x + 2.2, groundY + 1.9, z + 2.2), top)
end

local function palm(x, z, groundY)
    B(x, groundY + 0.8, z, 5, 1.6, 5, GRANITE)
    B(x, groundY + 1.62, z, 4.4, 0.08, 4.4, SOIL)
    local height = rand(10, 13)
    local bendAngle = rand(0, math.pi * 2)
    local bend = V(math.cos(bendAngle), 0, math.sin(bendAngle)) * rand(1, 2.5)
    local last = V(x, groundY + 1.6, z)
    for k = 1, 6 do
        local t = k / 6
        local point = V(x, groundY + 1.6, z) + bend * t * t + UP * height * t
        rod(last, point, 1.1 - 0.4 * t, { Color = Color3.fromRGB(140, 115, 85), Material = Enum.Material.Wood })
        last = point
    end
    local top = last
    ball(top, 1.4, { Color = Color3.fromRGB(100, 110, 60), Material = Enum.Material.SmoothPlastic })
    for f = 1, 8 do
        local a = f / 8 * math.pi * 2 + rand(-0.2, 0.2)
        local dir = V(math.cos(a), 0, math.sin(a))
        local lift = rand(0.3, 0.7)
        local length = rand(6, 8)
        local points = {}
        for k = 0, 4 do
            local t = k / 4
            points[k] = top + dir * length * t + UP * (length * (lift * t - (lift + 0.4) * t * t))
        end
        for k = 1, 4 do
            rod(points[k - 1], points[k], 0.2, { Color = Color3.fromRGB(105, 115, 55), Material = Enum.Material.SmoothPlastic })
        end
        for k = 1, 3 do
            local tangent = (points[k + 1] - points[k - 1]).Unit
            local side = tangent:Cross(UP)
            if side.Magnitude > 0.05 then
                side = side.Unit
                for _, s in ipairs({ -1, 1 }) do
                    local leafDir = (side * s + tangent * 0.5 - UP * 0.6).Unit
                    flatLeaf(points[k], leafDir, 2.6 - 0.4 * math.abs(k - 2), 0.5,
                        Color3.fromRGB(45, 105, 42):Lerp(Color3.fromRGB(120, 165, 70), rand(0, 1)))
                end
            end
        end
    end
end

----------------------------------------------------------------
-- Pool deck
----------------------------------------------------------------
local PW = math.clamp(W * 0.42, 40, 110)
local pz0 = (DOME and zc + PH or zc) + 6
local pz1 = D - M - 4
local PD = pz1 - pz0
local poolBuilt = false

local function lounger(cx, cz, deckTop, towardPool)
    local cf = CFrame.lookAt(V(cx, deckTop, cz), V(cx + towardPool, deckTop, cz))
    box(cf * CFrame.new(0, 0.35, 0), V(1.9, 0.3, 5.2), LIGHT_WOOD)
    for _, lx in ipairs({ -0.8, 0.8 }) do
        for _, lz in ipairs({ -2.3, 2.3 }) do
            box(cf * CFrame.new(lx, 0.1, lz), V(0.2, 0.2, 0.2), LIGHT_WOOD)
        end
    end
    box(cf * CFrame.new(0, 0.62, -0.6), V(1.7, 0.25, 3.6), CUSHION)
    box(cf * CFrame.new(0, 1.15, 1.75) * CFrame.Angles(math.rad(-45), 0, 0), V(1.7, 0.25, 1.9), CUSHION)
    box(cf * CFrame.new(0, 0.76, -0.8), V(1.0, 0.04, 2.4), {
        Color = rand(0, 1) < 0.5 and Color3.fromRGB(212, 175, 55) or Color3.fromRGB(30, 110, 160),
        Material = Enum.Material.Fabric,
    })
end

local function umbrella(cx, cz, deckTop)
    cylUp(V(cx, deckTop + 0.15, cz), 0.3, 1.4, GRANITE)
    cylUp(V(cx, deckTop + 3, cz), 6, 0.2, GOLD)
    ellipsoid(V(cx, deckTop + 5.8, cz), V(6.5, 1.4, 6.5), CANVAS)
    cylUp(V(cx, deckTop + 5.5, cz), 0.15, 6.4, GOLD)
    ball(V(cx, deckTop + 6.6, cz), 0.4, GOLD)
end

local function cabana(cx, cz, deckTop)
    for _, x in ipairs({ -3, 3 }) do
        for _, z in ipairs({ -3, 3 }) do
            cylUp(V(cx + x, deckTop + 3.5, cz + z), 7, 0.35, GOLD)
        end
    end
    B(cx, deckTop + 7.2, cz, 6.8, 0.5, 6.8, CANVAS)
    B(cx, deckTop + 6.7, cz, 7, 0.6, 7, { Color = Color3.fromRGB(212, 175, 55), Material = Enum.Material.Fabric })
    B(cx, deckTop + 6.35, cz, 6.4, 0.1, 6.4, NEON_WARM)
    local lamp = B(cx, deckTop + 6.3, cz, 0.6, 0.1, 0.6, NEON_WARM)
    pointLight(lamp, Color3.fromRGB(255, 220, 160), 12, 1)
    B(cx + 3, deckTop + 3.5, cz, 0.1, 6, 6, CURTAIN)
    B(cx - 3, deckTop + 3.5, cz - 2, 0.1, 6, 2, CURTAIN)
    B(cx - 3, deckTop + 3.5, cz + 2, 0.1, 6, 2, CURTAIN)
    B(cx, deckTop + 0.5, cz, 4.6, 1, 4.6, CUSHION)
    for _, z in ipairs({ -1.4, 0, 1.4 }) do
        B(cx + 1.9, deckTop + 1.4, cz + z, 0.6, 0.9, 1.2, { Color = Color3.fromRGB(212, 175, 55), Material = Enum.Material.Fabric })
    end
end

local function skyBar(cx, cz, deckTop)
    local cf = CFrame.lookAt(V(cx, deckTop, cz), V(cx, deckTop, cz + 1)) -- front of the bar faces the pool
    box(cf * CFrame.new(0, 1.75, -1.5), V(12, 3.5, 1.6), GRANITE)
    box(cf * CFrame.new(0, 1.75, -2.32), V(12, 0.4, 0.05), GOLD)
    box(cf * CFrame.new(0, 0.6, -2.32), V(12, 0.15, 0.05), NEON_GOLD)
    box(cf * CFrame.new(0, 3.62, -1.6), V(12.6, 0.25, 2.2), MARBLE)
    for s = -2, 2 do
        local seatPos = cf * V(s * 2.3, 0, -3.4)
        cylUp(seatPos + V(0, 0.08, 0), 0.15, 1.2, GOLD)
        cylUp(seatPos + V(0, 1.3, 0), 2.4, 0.2, GOLD)
        cylUp(seatPos + V(0, 2.6, 0), 0.35, 1.4, RED_SEAT)
    end
    box(cf * CFrame.new(0, 3, 2.6), V(12, 6, 1), DARK_WOOD)
    local bottleColors = { Color3.fromRGB(255, 170, 40), Color3.fromRGB(80, 200, 120), Color3.fromRGB(80, 150, 255), Color3.fromRGB(255, 90, 120) }
    for row = 0, 2 do
        box(cf * CFrame.new(0, 2 + row * 1.6, 2.0), V(11.6, 0.12, 0.6), GOLD)
        for b = 0, 9 do
            local p = cf * V(-5 + b * 1.1, 2.55 + row * 1.6, 2.0)
            cylUp(p, 0.9, 0.3, { Color = bottleColors[rng:NextInteger(1, #bottleColors)], Material = Enum.Material.Neon, Transparency = 0.2 })
        end
    end
    for _, x in ipairs({ -6.5, 6.5 }) do
        for _, z in ipairs({ -3.8, 3.2 }) do
            box(cf * CFrame.new(x, 4.1, z), V(0.5, 8.2, 0.5), GOLD)
        end
    end
    box(cf * CFrame.new(0, 8.5, -0.3), V(14.5, 0.6, 8.6), STONE)
    box(cf * CFrame.new(0, 8.5, -4.62), V(14.5, 1.4, 0.1), GOLD)
    box(cf * CFrame.new(0, 7.7, -4.5), V(14.5, 0.12, 0.25), NEON_GOLD)
    textPanel(cf * CFrame.new(0, 8.5, -4.7), 9, 1.1, BAR_NAME)
    for _, x in ipairs({ -4, 0, 4 }) do
        local light = box(cf * CFrame.new(x, 8.17, -1.5), V(1, 0.06, 1), NEON_WARM)
        spotDown(light, 16, 80)
    end
end

local function stringLights(a, b, sag)
    local count = math.max(2, math.floor((b - a).Magnitude / 2.5))
    local mid
    -- [REX] run a cable between the bulbs. Without it each span is just a line
    -- of glowing orbs hanging in midair with nothing holding them up.
    local prev
    for i = 0, count do
        local t = i / count
        local pos = a:Lerp(b, t) - UP * sag * 4 * t * (1 - t)
        if prev then
            rod(prev, pos, 0.08, CABLE)
        end
        prev = pos
        local bulb = ball(pos, 0.35, NEON_WARM)
        -- [REX] a short drop, so each bulb hangs off the cable rather than
        -- sitting centred on it
        rod(pos + UP * 0.34, pos, 0.06, CABLE)
        if i == math.floor(count / 2) then
            mid = bulb
        end
    end
    if mid then
        pointLight(mid, Color3.fromRGB(255, 220, 160), 20, 1)
    end
end

if POOL and W >= 100 and PD >= 30 and free(-PW / 2, PW / 2, pz0, pz1) then
    poolBuilt = true
    claim(-PW / 2, PW / 2, pz0, pz1)
    local DT = RT + 1.2
    local PLW = PW * 0.5
    local PLD = PD * 0.55
    local pzc = (pz0 + pz1) / 2 + PD * 0.05
    local p0, p1 = pzc - PLD / 2, pzc + PLD / 2

    -- Wooden deck around the pool
    rangeBox(-PW / 2, PW / 2, RT, DT, pz0, p0, TEAK)
    rangeBox(-PW / 2, PW / 2, RT, DT, p1, pz1, TEAK)
    rangeBox(-PW / 2, -PLW / 2, RT, DT, p0, p1, TEAK)
    rangeBox(PLW / 2, PW / 2, RT, DT, p0, p1, TEAK)

    -- Marble edge around the pool
    rangeBox(-PLW / 2 - 1.2, PLW / 2 + 1.2, DT, DT + 0.25, p0 - 1.2, p0, MARBLE)
    rangeBox(-PLW / 2 - 1.2, PLW / 2 + 1.2, DT, DT + 0.25, p1, p1 + 1.2, MARBLE)
    rangeBox(-PLW / 2 - 1.2, -PLW / 2, DT, DT + 0.25, p0, p1, MARBLE)
    rangeBox(PLW / 2, PLW / 2 + 1.2, DT, DT + 0.25, p0, p1, MARBLE)

    -- Pool tiles, lane stripes, water and lights
    rangeBox(-PLW / 2, PLW / 2, RT + 0.05, RT + 0.25, p0, p1, POOL_TILE)
    rangeBox(-PLW / 2, -PLW / 2 + 0.25, RT + 0.25, DT, p0, p1, POOL_TILE)
    rangeBox(PLW / 2 - 0.25, PLW / 2, RT + 0.25, DT, p0, p1, POOL_TILE)
    rangeBox(-PLW / 2, PLW / 2, RT + 0.25, DT, p0, p0 + 0.25, POOL_TILE)
    rangeBox(-PLW / 2, PLW / 2, RT + 0.25, DT, p1 - 0.25, p1, POOL_TILE)
    for _, x in ipairs({ -PLW / 4, 0, PLW / 4 }) do
        B(x, RT + 0.26, pzc, 0.5, 0.02, PLD - 4, POOL_STRIPE)
    end
    cylUp(V(0, RT + 0.27, pzc), 0.02, math.min(PLW, PLD) * 0.35, GOLD)
    rangeBox(-PLW / 2 + 0.25, PLW / 2 - 0.25, RT + 0.25, DT - 0.15, p0 + 0.25, p1 - 0.25, WATER)
    for z = p0 + 5, p1 - 3, 10 do
        for _, side in ipairs({ -1, 1 }) do
            local light = B(side * (PLW / 2 - 0.27), RT + 0.6, z, 0.05, 0.5, 1, { Color = Color3.fromRGB(140, 230, 255), Material = Enum.Material.Neon })
            pointLight(light, Color3.fromRGB(100, 210, 255), 14, 1.2)
        end
    end
    -- Steps into the pool and a gold ladder
    for s = 1, 3 do
        rangeBox(-4, 4, RT + 0.25, DT - s * 0.3, p0 + 0.25, p0 + 0.25 + s * 1.1, MARBLE)
    end
    for _, x in ipairs({ -0.8, 0.8 }) do
        local base = V(x, RT + 0.3, p1 - 0.6)
        rod(base, V(x, DT + 1.5, p1 - 0.6), 0.15, GOLD)
        rod(V(x, DT + 1.5, p1 - 0.6), V(x, DT + 1.5, p1 + 0.6), 0.15, GOLD)
        rod(V(x, DT + 1.5, p1 + 0.6), V(x, DT, p1 + 0.6), 0.15, GOLD)
    end

    -- Steps up to the deck in the middle of the front edge
    rangeBox(-5, 5, RT, RT + 0.6, pz0 - 1.5, pz0, TEAK)
    paving(-4, 4, DOME and zc + PH or zc, pz0 - 1.5)

    -- Hot tub
    local tubX, tubZ = -PW / 2 + 7, pz0 + 7
    if p0 - pz0 >= 14 then
        cylUp(V(tubX, DT + 0.7, tubZ), 1.4, 8.4, MARBLE)
        cylUp(V(tubX, DT + 1.45, tubZ), 0.1, 8.8, GOLD)
        local tub = cylUp(V(tubX, DT + 1.35, tubZ), 0.1, 7.4, WATER)
        pointLight(tub, Color3.fromRGB(100, 210, 255), 12, 1)
        local bubbles = Instance.new("ParticleEmitter")
        bubbles.Rate = 30
        bubbles.Lifetime = NumberRange.new(0.6, 1)
        bubbles.Speed = NumberRange.new(1, 2)
        bubbles.SpreadAngle = Vector2.new(30, 30)
        bubbles.Size = NumberSequence.new(0.3, 0.1)
        bubbles.Transparency = NumberSequence.new(0.3, 1)
        bubbles.Color = ColorSequence.new(Color3.fromRGB(230, 250, 255))
        bubbles.EmissionDirection = Enum.NormalId.Right -- the cylinder's side points up
        bubbles.Parent = tub
    end

    -- Sky bar
    if p0 - pz0 >= 14 then
        skyBar(PW / 2 - 12, pz0 + 6, DT)
    end

    -- Loungers and umbrellas along both sides of the pool
    local stripWidth = PW / 2 - PLW / 2 - 1.2
    for _, side in ipairs({ -1, 1 }) do
        local lx = side * (PLW / 2 + 1.2 + 3.2)
        local count = 0
        for z = p0 + 3, p1 - 3, 4.5 do
            count += 1
            lounger(lx, z, DT, -side)
            if count % 2 == 0 then
                umbrella(lx + side * 2.6, z - 2.25, DT)
            end
        end
        -- Cabanas further out
        if stripWidth >= 16 then
            for z = p0 + 6, p1 - 5, 14 do
                cabana(side * (PW / 2 - 5), z, DT)
            end
        end
    end

    -- Glass railing with gold posts (gap at the front steps)
    local function railing(a, b)
        local length = (b - a).Magnitude
        local panels = math.max(1, math.floor(length / 4))
        for i = 0, panels - 1 do
            local p = a:Lerp(b, (i + 0.5) / panels)
            box(CFrame.lookAt(p, b), V(0.1, 3, length / panels - 0.3), RAIL_GLASS)
        end
        for i = 0, panels do
            local p = a:Lerp(b, i / panels)
            cylUp(p, 3.4, 0.25, GOLD)
        end
        rod(a + V(0, 1.7, 0), b + V(0, 1.7, 0), 0.2, GOLD)
    end
    local ry = DT + 1.5
    railing(V(-PW / 2 + 0.3, ry, pz0 + 0.3), V(-PW / 2 + 0.3, ry, pz1 - 0.3))
    railing(V(PW / 2 - 0.3, ry, pz0 + 0.3), V(PW / 2 - 0.3, ry, pz1 - 0.3))
    railing(V(-PW / 2 + 0.3, ry, pz1 - 0.3), V(PW / 2 - 0.3, ry, pz1 - 0.3))
    railing(V(-PW / 2 + 0.3, ry, pz0 + 0.3), V(-5.5, ry, pz0 + 0.3))
    railing(V(5.5, ry, pz0 + 0.3), V(PW / 2 - 0.3, ry, pz0 + 0.3))

    -- Palms on the deck corners
    for _, x in ipairs({ -PW / 2 + 4, PW / 2 - 4 }) do
        palm(x, pz1 - 4, DT)
    end
    palm(-PW / 2 + 4, p0 - 4, DT)

    -- String lights across the pool
    if STRING_LIGHTS then
        for z = p0, p1, 16 do
            for _, side in ipairs({ -1, 1 }) do
                cylUp(V(side * (PLW / 2 + 1.6), DT + 4.5, z), 9, 0.3, BLACK_METAL)
            end
            stringLights(V(-(PLW / 2 + 1.6), DT + 9, z), V(PLW / 2 + 1.6, DT + 9, z), 2)
        end
    end
end

----------------------------------------------------------------
-- Helipad
----------------------------------------------------------------
if HELIPAD then
    local spots = { { -W / 2 + M + 15, D - M - 15 }, { -W / 2 + M + 15, M + 15 }, { W / 2 - M - 15, M + 15 } }
    for _, spot in ipairs(spots) do
        local hx, hz = spot[1], spot[2]
        if free(hx - 15, hx + 15, hz - 15, hz + 15) then
            claim(hx - 15, hx + 15, hz - 15, hz + 15)
            local padTop = RT + 2.4
            for _, x in ipairs({ -10, 0, 10 }) do
                for _, z in ipairs({ -10, 0, 10 }) do
                    B(hx + x, RT + 1, hz + z, 0.8, 2, 0.8, DARK_METAL)
                end
            end
            B(hx, padTop - 0.2, hz, 26, 0.4, 26, HELI_PAD)
            for _, side in ipairs({ -1, 1 }) do
                B(hx + side * 12.6, padTop + 0.01, hz, 0.8, 0.02, 26, YELLOW_PAINT)
                B(hx, padTop + 0.01, hz + side * 12.6, 26, 0.02, 0.8, YELLOW_PAINT)
            end
            ringRods(hx, padTop + 0.03, hz, 9, 32, 0.7, WHITE_PAINT)
            B(hx - 2.2, padTop + 0.02, hz, 1, 0.04, 7, WHITE_PAINT)
            B(hx + 2.2, padTop + 0.02, hz, 1, 0.04, 7, WHITE_PAINT)
            B(hx, padTop + 0.02, hz, 4.4, 0.04, 1, WHITE_PAINT)
            for i = 0, 23 do
                local t = i / 24
                local perimeter = t * 4
                local edge = math.floor(perimeter)
                local f = perimeter - edge
                local x, z
                if edge == 0 then x, z = -12.5 + 25 * f, -12.5
                elseif edge == 1 then x, z = 12.5, -12.5 + 25 * f
                elseif edge == 2 then x, z = 12.5 - 25 * f, 12.5
                else x, z = -12.5, 12.5 - 25 * f end
                local light = ball(V(hx + x, padTop + 0.2, hz + z), 0.4, { Color = Color3.fromRGB(60, 255, 120), Material = Enum.Material.Neon })
                light.Name = "BlinkerGreen" -- [REX] for the animation script
                table.insert(blinkers, { part = light, color = Color3.fromRGB(60, 255, 120), offset = i % 2 })
            end
            -- Stairs up to the pad
            local stairSide = hz > D / 2 and -1 or 1
            for s = 1, 4 do
                B(hx, RT + s * 0.55 - 0.27, hz + stairSide * (13 + (5 - s) * 0.9), 4, 0.55 * s, 0.9, DARK_METAL)
            end
            -- Windsock
            local wx, wz = hx + 14, hz + 14
            cylUp(V(wx, RT + 3, wz), 6, 0.2, WHITE_PAINT)
            local sockCF = CFrame.lookAt(V(wx + 1.6, RT + 5.6, wz), V(wx + 4, RT + 5.2, wz))
            ellipsoid(sockCF, V(1, 1, 3.4), { Color = Color3.fromRGB(255, 120, 20), Material = Enum.Material.Fabric })
            break
        end
    end
end

----------------------------------------------------------------
-- Mechanical yard behind screen walls
----------------------------------------------------------------
local function acUnit(x, z)
    for _, side in ipairs({ -1, 1 }) do
        B(x, RT + 0.45, z + side * 2.4, 10.4, 0.4, 0.5, DARK_METAL)
    end
    B(x, RT + 2.65, z, 10, 4, 6, UNIT_METAL)
    for k = -4, 4 do
        B(x + k, RT + 2.6, z - 3.02, 0.15, 3, 0.05, DARK_METAL)
    end
    for _, fx in ipairs({ -2.5, 2.5 }) do
        cylUp(V(x + fx, RT + 4.75, z), 0.2, 3.6, DARK_METAL)
        for b = 0, 2 do
            box(CFrame.new(x + fx, RT + 4.9, z) * CFrame.Angles(0, b * math.pi / 3 + rand(0, 1), 0), V(3.2, 0.08, 0.6), UNIT_METAL)
        end
        for g = -1, 1 do
            B(x + fx + g * 1.1, RT + 5, z, 0.08, 0.08, 3.6, DARK_METAL)
        end
    end
end

if MECHANICAL_YARD then
    local spots = { { W / 2 - M - 16, D - M - 16 }, { W / 2 - M - 16, M + 16 }, { -W / 2 + M + 16, M + 16 } }
    for _, spot in ipairs(spots) do
        local mx, mz = spot[1], spot[2]
        if free(mx - 16, mx + 16, mz - 22, mz + 16) then
            claim(mx - 16, mx + 16, mz - 22, mz + 16)
            B(mx, RT + 0.15, mz, 30, 0.3, 30, CONCRETE)

            -- Slatted screen walls (opening on one side)
            local half = 15
            for i = -2, 2 do
                for _, corner in ipairs({ { i * 7.5, -half }, { i * 7.5, half }, { -half, i * 7.5 }, { half, i * 7.5 } }) do
                    B(mx + corner[1], RT + 3.5, mz + corner[2], 0.6, 7, 0.6, DARK_METAL)
                end
            end
            for h = 1, 6 do
                local y = RT + h
                for _, side in ipairs({ -1, 1 }) do
                    box(CFrame.new(mx, y, mz + side * half) * CFrame.Angles(math.rad(35), 0, 0), V(30, 0.15, 0.8), UNIT_METAL)
                    box(CFrame.new(mx + side * half, y, mz) * CFrame.Angles(0, 0, math.rad(35)), V(0.8, 0.15, 30), UNIT_METAL)
                end
            end

            -- Equipment inside
            acUnit(mx - 7, mz - 6)
            acUnit(mx + 6, mz - 6)
            acUnit(mx - 7, mz + 4)
            cylUp(V(mx + 8, RT + 3.8, mz + 7), 7, 7, UNIT_METAL)
            cylUp(V(mx + 8, RT + 7.4, mz + 7), 0.3, 7.6, DARK_METAL)
            cylUp(V(mx + 8, RT + 7.6, mz + 7), 0.3, 5, DARK_METAL)
            for _, x in ipairs({ -1.5, 1.5 }) do
                for _, z in ipairs({ -1.5, 1.5 }) do
                    B(mx + 1 + x, RT + 2, mz + 9 + z, 0.4, 4, 0.4, DARK_METAL)
                end
            end
            cylUp(V(mx + 1, RT + 5.5, mz + 9), 3.5, 4, CONCRETE)
            for k = 0, 2 do
                local y = RT + 1 + k * 0.9
                rod(V(mx - 12, y, mz - 1), V(mx + 11, y, mz - 1), 0.6, UNIT_METAL)
            end

            -- Radio mast with a blinking red light
            rod(V(mx - 12, RT, mz + 12), V(mx - 12, RT + 18, mz + 12), 0.35, DARK_METAL)
            for y = RT + 3, RT + 15, 3 do
                B(mx - 12, y, mz + 12, 1.4, 0.12, 0.12, DARK_METAL)
            end
            local beacon = ball(V(mx - 12, RT + 18.3, mz + 12), 0.7, { Color = Color3.fromRGB(255, 30, 30), Material = Enum.Material.Neon })
            beacon.Name = "BlinkerRed" -- [REX] for the animation script
            pointLight(beacon, Color3.fromRGB(255, 40, 40), 14, 1)
            table.insert(blinkers, { part = beacon, color = Color3.fromRGB(255, 30, 30), offset = 0 })

            -- Roof access building next to the yard
            local ax, az = mx, mz + (mz > D / 2 and -22 or 22)
            B(ax, RT + 5, az, 12, 10, 10, STONE)
            B(ax, RT + 10.25, az, 12.8, 0.5, 10.8, STONE_DARK)
            B(ax, RT + 10.55, az, 13, 0.1, 11, GOLD)
            local doorSide = mz > D / 2 and -1 or 1
            B(ax, RT + 3.5, az + doorSide * 5.02, 3.4, 7, 0.1, DARK_METAL)
            B(ax + 1.2, RT + 3.5, az + doorSide * 5.1, 0.5, 0.15, 0.1, GOLD)
            local lamp = B(ax, RT + 8, az + doorSide * 5.1, 1, 0.4, 0.2, NEON_WARM)
            pointLight(lamp, Color3.fromRGB(255, 220, 160), 14, 1)
            break
        end
    end
end

----------------------------------------------------------------
-- Front garden terrace
----------------------------------------------------------------
local function firePit(cx, cz)
    cylUp(V(cx, RT + 0.85, cz), 1.4, 5, GRANITE)
    cylUp(V(cx, RT + 1.58, cz), 0.06, 5.2, GOLD)
    local embers = cylUp(V(cx, RT + 1.6, cz), 0.05, 3.8, { Color = Color3.fromRGB(255, 120, 30), Material = Enum.Material.Neon })
    local fire = Instance.new("Fire")
    fire.Size = 5
    fire.Heat = 6
    fire.Color = Color3.fromRGB(255, 120, 30)
    fire.SecondaryColor = Color3.fromRGB(255, 220, 80)
    fire.Parent = embers
    pointLight(embers, Color3.fromRGB(255, 140, 50), 18, 2)
    for k = 0, 3 do
        local a = k / 4 * math.pi * 2 + math.pi / 4
        local pos = V(cx + math.cos(a) * 5.5, RT, cz + math.sin(a) * 5.5)
        local cf = CFrame.lookAt(pos, V(cx, RT, cz))
        box(cf * CFrame.new(0, 0.9, 0), V(2.6, 1, 2.4), CUSHION)
        box(cf * CFrame.new(0, 1.9, 1.05), V(2.6, 2, 0.4), CUSHION)
        box(cf * CFrame.new(-1.15, 1.6, 0.1), V(0.35, 1.4, 2.3), CUSHION)
        box(cf * CFrame.new(1.15, 1.6, 0.1), V(0.35, 1.4, 2.3), CUSHION)
        box(cf * CFrame.new(0, 0.2, 0), V(2.7, 0.4, 2.5), DARK_WOOD)
    end
end

local function bench(x, z, facing)
    local cf = CFrame.lookAt(V(x, RT, z), V(x, RT, z) + facing)
    box(cf * CFrame.new(0, 1.2, 0), V(4.5, 0.25, 1.4), LIGHT_WOOD)
    box(cf * CFrame.new(0, 2, 0.65), V(4.5, 1.3, 0.2), LIGHT_WOOD)
    for _, lx in ipairs({ -1.9, 1.9 }) do
        box(cf * CFrame.new(lx, 0.6, 0), V(0.2, 1.2, 1.2), GOLD)
    end
end

local function pathLight(x, z)
    cylUp(V(x, RT + 0.9, z), 1.6, 0.4, BLACK_METAL)
    local cap = ball(V(x, RT + 1.85, z), 0.45, NEON_WARM)
    return cap
end

if GARDEN then
    local tz0, tz1 = M + 1, (DOME and zc - PH or zc) - 2
    if tz1 - tz0 >= 14 then
        paving(-W / 2 + 7, W / 2 - 7, tz0, tz1)
        claim(-W / 2 + 7, W / 2 - 7, tz0, tz1)

        -- Walkway lined with hedges and lights
        local lightCount = 0
        for z = tz0 + 3, tz1 - 3, 10 do
            for _, side in ipairs({ -1, 1 }) do
                B(side * 6, RT + 0.75, z + 2.5, 1.6, 1.5, 7, GRANITE)
                B(side * 6, RT + 1.95, z + 2.5, 1.3, 1, 6.6, HEDGE)
                lightCount += 1
                local cap = pathLight(side * 6, z - 2)
                if lightCount % 2 == 0 then
                    pointLight(cap, Color3.fromRGB(255, 220, 160), 12, 0.8)
                end
            end
        end

        -- Garden "rooms" on both sides: fire pit lounges and tree planters
        local depth = tz1 - tz0
        local cell = 28
        local index = 0
        for _, side in ipairs({ -1, 1 }) do
            for x = 10 + cell / 2, W / 2 - 8 - cell / 2, cell do
                index += 1
                local cx = side * x
                local cz = (tz0 + tz1) / 2
                if index % 2 == 1 and depth >= 18 then
                    firePit(cx, cz)
                    smallTree(cx - side * 10, tz0 + 4, RT)
                else
                    smallTree(cx - 6, cz - math.min(5, depth / 4), RT)
                    smallTree(cx + 6, cz + math.min(5, depth / 4), RT)
                    bench(cx, cz, V(0, 0, -1))
                end
            end
        end
    end
end

----------------------------------------------------------------
-- Place it and attach the blinking lights
----------------------------------------------------------------
-- [REX] the blink loop as a child Script, so it does not spin inside Studio
if ANIMATE_LIGHTS and #blinkers > 0 then
    local animator = Instance.new("Script")
    animator.Name = "RooftopAnimator"
    animator.Source = [[
-- Helipad perimeter lights and the mast beacon.
local model = script.Parent
local GREEN = Color3.fromRGB(60, 255, 120)
local RED = Color3.fromRGB(255, 30, 30)
local DIM = Color3.fromRGB(40, 40, 40)

local blinkers = {}
for _, d in ipairs(model:GetDescendants()) do
	if d:IsA("BasePart") then
		if d.Name == "BlinkerGreen" then
			table.insert(blinkers, { part = d, color = GREEN, offset = #blinkers % 2 })
		elseif d.Name == "BlinkerRed" then
			table.insert(blinkers, { part = d, color = RED, offset = 0 })
		end
	end
end

task.spawn(function()
	local phase = 0
	while model.Parent do
		phase = 1 - phase
		for _, b in ipairs(blinkers) do
			local on = (phase + b.offset) % 2 == 0
			b.part.Material = on and Enum.Material.Neon or Enum.Material.SmoothPlastic
			b.part.Color = on and b.color or DIM
		end
		task.wait(1)
	end
end)
]]
    animator.Parent = model
end

model.WorldPivot = CFrame.new(0, 0, 0)
model:PivotTo(FRAME)
model.Parent = casinoRoot -- [REX] was workspace

local parts = 0
for _, d in ipairs(model:GetDescendants()) do
    if d:IsA("BasePart") then
        parts = parts + 1
    end
end
print(string.format("[Rooftop] built %s | %d parts, pool %s, %d blinkers | deck at %.2f",
    model:GetFullName(), parts, poolBuilt and "yes" or "no", #blinkers, FRAME.Position.Y + RT))

return model
