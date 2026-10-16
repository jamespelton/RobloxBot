-- LUXURY CASINO WALLS (+ trims hanging lamp rods to the ceiling)
-- Written by James. Changes are marked [REX]:
--
--   1. IT WOULD NOT HAVE RUN. GrandInterior, LuxurySigns and LuxuryJackpot
--      were looked for at the Workspace root; they all live in
--      Workspace.Casino, so it stopped at "Needs the GrandInterior model".
--   2. The interior's old wall trim was DESTROYED. Every other build hides
--      what it replaces so the old look can come back; this does the same
--      now (recorded once, so a re-run doesn't lose the original).
--   3. The gold band that runs round the walls at 3-5 studs sticks out a
--      full stud. The wood panelling and column bases started at the wall
--      face, so they ran straight through it. The lower wall now stands out
--      by however far the band does at that spot, making a deeper wainscot.
--   4. The "is the wall bare here?" rays hit the very trim being replaced
--      (it's only hidden now, and hidden parts still stop rays), which would
--      have marked every wall busy. They look past the interior's trim and
--      the previous build.
--   5. The rod trimmer fired a ray up each lamp rod to find the ceiling, but
--      chandeliers and the interior ceiling ignore rays: it would have
--      pulled the craps lamp's rods back up through the chandelier they now
--      hang from, and missed the ceiling everywhere else. Rods that reach
--      past the interior ceiling are cut to it now; rods that already stop
--      lower (at a chandelier) are left alone.
--   6. The floor was found by rays that could land on a chandelier, a lamp
--      or a slot machine; it is measured on the casino floor itself now.
--   7. Runs once in Studio instead of at every server start, replaces its
--      previous build, and is parented into the Casino folder.

-- Settings:
local BAY = 14               -- width of each wall section
local MIRRORS = true         -- arched mirrors with crystal sconces
local ARTWORK = true         -- framed paintings with picture lights
local VELVET_COLOR = Color3.fromRGB(95, 12, 22)
local FIX_HANGING_RODS = true

local V = Vector3.new
local UP = V(0, 1, 0)
local rng = Random.new(12)
local HIDDEN = "LuxuryWallsHidden"

----------------------------------------------------------------
-- Materials
----------------------------------------------------------------
local GOLD = { Color = Color3.fromRGB(212, 175, 55), Material = Enum.Material.Metal, Reflectance = 0.35 }
local BRASS = { Color = Color3.fromRGB(190, 150, 60), Material = Enum.Material.Metal, Reflectance = 0.4 }
local MAHOGANY = { Color = Color3.fromRGB(75, 30, 22), Material = Enum.Material.Wood }
local MAHOGANY_LIGHT = { Color = Color3.fromRGB(105, 45, 30), Material = Enum.Material.Wood }
local DARK_WOOD = { Color = Color3.fromRGB(45, 20, 14), Material = Enum.Material.Wood }
local BLACK_MARBLE = { Color = Color3.fromRGB(20, 20, 22), Material = Enum.Material.Marble, Reflectance = 0.1 }
local MARBLE = { Color = Color3.fromRGB(235, 228, 215), Material = Enum.Material.Marble }
local MARBLE_SHADE = { Color = Color3.fromRGB(200, 190, 175), Material = Enum.Material.Marble }
local CREAM = { Color = Color3.fromRGB(235, 222, 200), Material = Enum.Material.Plaster }
local VELVET = { Color = VELVET_COLOR, Material = Enum.Material.Fabric }
local MIRROR = { Color = Color3.fromRGB(195, 200, 210), Material = Enum.Material.Glass, Reflectance = 0.65 }
local CRYSTAL = { Color = Color3.fromRGB(230, 240, 255), Material = Enum.Material.Glass, Transparency = 0.3, Reflectance = 0.4 }
local NEON_WARM = { Color = Color3.fromRGB(255, 225, 170), Material = Enum.Material.Neon }
local BLACK = { Color = Color3.fromRGB(20, 20, 22), Material = Enum.Material.Metal }
local LIGHT_COLOR = Color3.fromRGB(255, 210, 150)
local ART_PALETTES = {
    { Color3.fromRGB(120, 20, 40), Color3.fromRGB(240, 160, 60), Color3.fromRGB(255, 220, 120) },
    { Color3.fromRGB(20, 40, 90), Color3.fromRGB(80, 160, 200), Color3.fromRGB(240, 220, 160) },
    { Color3.fromRGB(30, 60, 40), Color3.fromRGB(200, 180, 90), Color3.fromRGB(250, 240, 210) },
    { Color3.fromRGB(60, 20, 70), Color3.fromRGB(220, 90, 140), Color3.fromRGB(255, 200, 120) },
}

----------------------------------------------------------------
-- Helpers
----------------------------------------------------------------
-- [REX] everything lives in the Casino folder (notes 1, 7)
local casinoRoot = workspace:FindFirstChild("Casino") or workspace
local previous = casinoRoot:FindFirstChild("LuxuryWalls") or workspace:FindFirstChild("LuxuryWalls")
if previous then
    previous:Destroy()
end

local model = Instance.new("Model")
model.Name = "LuxuryWalls"

local function makePart(props, style)
    local p = Instance.new("Part")
    p.Anchored = true
    p.CanCollide = false
    p.CanTouch = false
    p.CanQuery = false
    p.CastShadow = false
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    for k, v in pairs(style) do
        p[k] = v
    end
    for k, v in pairs(props) do
        p[k] = v
    end
    p.Parent = model
    return p
end
local function box(cf, size, style)
    return makePart({ CFrame = cf, Size = size }, style)
end
local function ball(pos, size, style)
    return makePart({ Shape = Enum.PartType.Ball, CFrame = CFrame.new(pos), Size = V(size, size, size) }, style)
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
local function frameBars(cf, w, h, thickness, depth, style)
    for _, dy in ipairs({ -h / 2, h / 2 }) do
        box(cf * CFrame.new(0, dy, 0), V(w + thickness, thickness, depth), style)
    end
    for _, dx in ipairs({ -w / 2, w / 2 }) do
        box(cf * CFrame.new(dx, 0, 0), V(thickness, h, depth), style)
    end
end
local function pointLight(part, range, brightness)
    local light = Instance.new("PointLight")
    light.Color = LIGHT_COLOR
    light.Range = range
    light.Brightness = brightness
    light.Shadows = false
    light.Parent = part
end

----------------------------------------------------------------
-- Measure the room from the interior ceiling
----------------------------------------------------------------
local interior = casinoRoot:FindFirstChild("GrandInterior") or workspace:FindFirstChild("GrandInterior", true)
if not interior then
    error("[Walls] Needs the GrandInterior model (from the interior script, with NEW_CEILING = true).")
end
local ceilPanel, bestArea = nil, 0
for _, p in ipairs(interior:GetDescendants()) do
    if p:IsA("BasePart") and p.Material == Enum.Material.Foil and p.Size.X * p.Size.Z > bestArea then
        ceilPanel, bestArea = p, p.Size.X * p.Size.Z
    end
end
if not ceilPanel then
    error("[Walls] Couldn't find the interior ceiling. Make sure NEW_CEILING = true in the interior script.")
end
local R = ceilPanel.CFrame
local halfW, halfD = ceilPanel.Size.X / 2, ceilPanel.Size.Z / 2
local panelTop = ceilPanel.Position.Y + ceilPanel.Size.Y / 2
local panelBottomY = ceilPanel.Position.Y - ceilPanel.Size.Y / 2
local soffitBottom = panelTop - 2.6

-- [REX] measure on the casino floor itself (note 6)
local floorParams = RaycastParams.new()
floorParams.FilterType = Enum.RaycastFilterType.Include
floorParams.FilterDescendantsInstances = { casinoRoot:FindFirstChild("Floor") or casinoRoot, casinoRoot:FindFirstChild("Shell") or casinoRoot }
local floorY = math.huge
for _, offset in ipairs({ V(0, 0, 0), R.RightVector * halfW * 0.5, -R.RightVector * halfW * 0.5, R.LookVector * halfD * 0.5, -R.LookVector * halfD * 0.5 }) do
    local hit = workspace:Raycast(ceilPanel.Position + offset - V(0, 1, 0), V(0, -80, 0), floorParams)
    if hit then
        floorY = math.min(floorY, hit.Position.Y)
    end
end
if floorY == math.huge then
    error("[Walls] Couldn't find the floor.")
end
local topY = soffitBottom - floorY -- height of the decorated wall
local center = V(ceilPanel.Position.X, floorY, ceilPanel.Position.Z)

-- Hide the simpler wall trim from the interior script
-- [REX] hidden, not destroyed (note 2)
local removed = 0
local wallPlanes = {
    { point = center + R.RightVector * halfW, inward = -R.RightVector },
    { point = center - R.RightVector * halfW, inward = R.RightVector },
    { point = center + R.LookVector * halfD, inward = -R.LookVector },
    { point = center - R.LookVector * halfD, inward = R.LookVector },
}
for _, p in ipairs(interior:GetDescendants()) do
    if p:IsA("BasePart") and p.Position.Y < soffitBottom - 0.1 and p.Position.Y > floorY + 0.3 then
        for _, wall in ipairs(wallPlanes) do
            local depth = (p.Position - wall.point):Dot(wall.inward)
            if depth > -0.5 and depth < 1.6 then
                if p:GetAttribute("OldTransparency") == nil then
                    p:SetAttribute("OldTransparency", p.Transparency)
                    p:SetAttribute("OldCanCollide", p.CanCollide)
                end
                p:SetAttribute(HIDDEN, true)
                p.Transparency = 1
                p.CanCollide = false
                for _, d in ipairs(p:GetDescendants()) do
                    if d:IsA("SurfaceGui") then
                        d.Enabled = false
                    elseif d:IsA("Decal") or d:IsA("Texture") then
                        d.Transparency = 1
                    elseif d:IsA("Light") then
                        d.Enabled = false
                    end
                end
                removed += 1
                break
            end
        end
    end
end

-- Areas covered by the new signs and jackpot board (they can't be hit by rays)
local signBoxes = {}
for _, name in ipairs({ "LuxurySigns", "LuxuryJackpot" }) do
    -- [REX] in the Casino folder (note 1)
    local container = casinoRoot:FindFirstChild(name) or workspace:FindFirstChild(name)
    if container then
        local groups = container:IsA("Model") and { container } or container:GetChildren()
        for _, g in ipairs(groups) do
            if g:IsA("Model") then
                local cf, size = g:GetBoundingBox()
                table.insert(signBoxes, { cf = cf, size = size })
            end
        end
    end
end

----------------------------------------------------------------
-- Checks: is the wall bare here?
----------------------------------------------------------------
-- [REX] look past the trim being replaced (note 4)
local bareParams = RaycastParams.new()
bareParams.FilterType = Enum.RaycastFilterType.Exclude
bareParams.FilterDescendantsInstances = { interior }

local function bareAt(T, x, y)
    local origin = T * V(x, y, -5)
    local hit = workspace:Raycast(origin, T:VectorToWorldSpace(V(0, 0, 6)), bareParams)
    if not hit or math.abs((hit.Position - origin).Magnitude - 5) > 0.6 then
        return false
    end
    local point = T * V(x, y, -0.5)
    for _, b in ipairs(signBoxes) do
        local lp = b.cf:PointToObjectSpace(point)
        if math.abs(lp.X) <= b.size.X / 2 + 1.5 and math.abs(lp.Y) <= b.size.Y / 2 + 1.5 and math.abs(lp.Z) <= b.size.Z / 2 + 2 then
            return false
        end
    end
    return true
end
local function allBare(T, xs, ys)
    for _, x in ipairs(xs) do
        for _, y in ipairs(ys) do
            if not bareAt(T, x, y) then
                return false
            end
        end
    end
    return true
end

-- [REX] how far trim on the lower wall (the gold band) stands out here (note 3)
local function bandOut(T, x)
    local function dist(y)
        local origin = T * V(x, y, -5)
        local hit = workspace:Raycast(origin, T:VectorToWorldSpace(V(0, 0, 6)), bareParams)
        return hit and (hit.Position - origin).Magnitude or nil
    end
    local plain, best = dist(2), nil
    if not plain then
        return 0
    end
    for _, y in ipairs({ 3.2, 4, 4.8 }) do
        local d = dist(y)
        if d and plain - d > 0.05 and plain - d <= 1.6 then
            best = math.max(best or 0, plain - d)
        end
    end
    return best and best + 0.02 or 0
end

----------------------------------------------------------------
-- Pieces
----------------------------------------------------------------
local RAIL_Y = 6.6
local lightCount = 0

local function crystalSconce(T, x, y)
    box(T * CFrame.new(x, y, -0.12), V(0.6, 1.5, 0.15), GOLD)
    rod(T * V(x, y - 0.3, -0.2), T * V(x, y - 0.3, -0.85), 0.12, GOLD)
    rod(T * V(x - 0.45, y - 0.3, -0.85), T * V(x + 0.45, y - 0.3, -0.85), 0.1, GOLD)
    local bulb
    for _, side in ipairs({ -0.45, 0.45 }) do
        local cup = T * V(x + side, y - 0.15, -0.85)
        makePart({ Shape = Enum.PartType.Cylinder, CFrame = CFrame.new(cup) * CFrame.Angles(0, 0, math.rad(90)), Size = V(0.3, 0.35, 0.35) }, GOLD)
        bulb = ball(cup + V(0, 0.35, 0), 0.4, NEON_WARM)
        ball(cup - V(0, 0.35, 0), 0.16, CRYSTAL)
        ball(cup - V(0, 0.6, 0), 0.12, CRYSTAL)
    end
    lightCount += 1
    if lightCount % 2 == 0 then
        pointLight(bulb, 12, 0.7)
    end
end

local function archedMirror(T, x, bottom, top, width)
    local r = width / 2
    local archBase = top - r
    local rectH = archBase - bottom
    if rectH < 2 then
        return
    end
    box(T * CFrame.new(x, bottom + rectH / 2, -0.2), V(width, rectH, 0.06), MIRROR)
    for s = 0, 3 do
        local y = (s + 0.5) * (r / 4)
        local half = math.sqrt(math.max(r * r - y * y, 0.01))
        box(T * CFrame.new(x, archBase + y, -0.2), V(half * 2, r / 4 + 0.02, 0.06), MIRROR)
    end
    for _, side in ipairs({ -1, 1 }) do
        box(T * CFrame.new(x + side * r, bottom + rectH / 2, -0.3), V(0.3, rectH, 0.3), GOLD)
    end
    box(T * CFrame.new(x, bottom, -0.3), V(width + 0.3, 0.3, 0.35), GOLD)
    local last
    for s = 0, 10 do
        local a = math.pi * s / 10
        local p = T * V(x + math.cos(a) * r, archBase + math.sin(a) * r, -0.3)
        if last then
            rod(last, p, 0.3, GOLD)
        end
        last = p
    end
    box(T * CFrame.new(x, top + 0.35, -0.35), V(0.8, 0.9, 0.3), GOLD)
    crystalSconce(T, x - r - 1.0, bottom + rectH * 0.6)
    crystalSconce(T, x + r + 1.0, bottom + rectH * 0.6)
end

local function painting(T, x, cy, width, height)
    local cf = T * CFrame.new(x, cy, -0.22)
    local canvas = box(cf, V(width, height, 0.05), { Color = Color3.new(1, 1, 1), Material = Enum.Material.SmoothPlastic })
    -- Make the canvas face into the room
    canvas.CFrame = CFrame.lookAt(canvas.Position, canvas.Position + T:VectorToWorldSpace(V(0, 0, -1)))
    local palette = ART_PALETTES[rng:NextInteger(1, #ART_PALETTES)]
    local gui = Instance.new("SurfaceGui")
    gui.Face = Enum.NormalId.Front
    gui.LightInfluence = 0.7
    gui.Parent = canvas
    local bg = Instance.new("Frame")
    bg.Size = UDim2.fromScale(1, 1)
    bg.BackgroundColor3 = Color3.new(1, 1, 1)
    bg.BorderSizePixel = 0
    bg.Parent = gui
    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, palette[1]), ColorSequenceKeypoint.new(1, palette[2]) })
    gradient.Rotation = rng:NextInteger(30, 150)
    gradient.Parent = bg
    for _ = 1, 4 do
        local s = rng:NextNumber(0.2, 0.5)
        local circle = Instance.new("Frame")
        circle.Size = UDim2.fromScale(s, s * width / height)
        circle.Position = UDim2.fromScale(rng:NextNumber(0, 1 - s), rng:NextNumber(0, 0.6))
        circle.BackgroundColor3 = palette[rng:NextInteger(2, 3)]
        circle.BackgroundTransparency = rng:NextNumber(0.2, 0.6)
        circle.BorderSizePixel = 0
        circle.Parent = bg
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(1, 0)
        corner.Parent = circle
    end
    local band = Instance.new("Frame")
    band.Size = UDim2.fromScale(1.4, 0.08)
    band.Position = UDim2.fromScale(-0.2, rng:NextNumber(0.4, 0.8))
    band.Rotation = rng:NextInteger(-20, 20)
    band.BackgroundColor3 = palette[3]
    band.BorderSizePixel = 0
    band.Parent = bg

    frameBars(T * CFrame.new(x, cy, -0.3), width + 0.3, height + 0.3, 0.4, 0.3, GOLD)
    frameBars(T * CFrame.new(x, cy, -0.33), width + 0.05, height + 0.05, 0.12, 0.25, BRASS)
    -- Picture light
    local lightY = cy + height / 2 + 0.7
    box(T * CFrame.new(x, lightY - 0.3, -0.12), V(0.3, 0.6, 0.15), BRASS)
    local bar = box(T * CFrame.new(x, lightY, -0.6), V(width * 0.6, 0.18, 0.5), BRASS)
    box(T * CFrame.new(x, lightY - 0.1, -0.6), V(width * 0.55, 0.04, 0.3), NEON_WARM)
    local spot = Instance.new("SpotLight")
    spot.Face = Enum.NormalId.Bottom
    spot.Color = LIGHT_COLOR
    spot.Brightness = 1.5
    spot.Range = 8
    spot.Angle = 70
    spot.Parent = bar
end

local function pilaster(T, x, doUplight)
    -- [REX] the base stands out past the band like the panelling (note 3)
    local out = bandOut(T, x)
    box(T * CFrame.new(x, RAIL_Y / 2, -0.4 - out / 2), V(1.9, RAIL_Y, 0.8 + out), MAHOGANY)
    box(T * CFrame.new(x, RAIL_Y + 0.1, -0.45 - out / 2), V(2.1, 0.2, 0.9 + out), GOLD)
    local shaftBottom, shaftTop = RAIL_Y + 0.6, topY - 1.6
    if shaftTop - shaftBottom < 3 then
        return
    end
    box(T * CFrame.new(x, RAIL_Y + 0.4, -0.4), V(1.7, 0.4, 0.7), GOLD)
    box(T * CFrame.new(x, (shaftBottom + shaftTop) / 2, -0.32), V(1.4, shaftTop - shaftBottom, 0.6), MARBLE)
    for _, dx in ipairs({ -0.35, 0, 0.35 }) do
        box(T * CFrame.new(x + dx, (shaftBottom + shaftTop) / 2, -0.63), V(0.12, shaftTop - shaftBottom - 0.6, 0.04), MARBLE_SHADE)
    end
    local midY = shaftBottom + (shaftTop - shaftBottom) * 0.35
    box(T * CFrame.new(x, midY, -0.35), V(1.5, 0.25, 0.68), GOLD)
    box(T * CFrame.new(x, shaftTop + 0.25, -0.4), V(1.7, 0.5, 0.75), GOLD)
    box(T * CFrame.new(x, shaftTop + 0.7, -0.45), V(2.0, 0.4, 0.9), GOLD)
    if doUplight then
        local fixture = box(T * CFrame.new(x, RAIL_Y + 0.85, -1.1 - out) * CFrame.Angles(math.rad(70), 0, 0), V(0.5, 0.4, 0.6), BLACK)
        local spot = Instance.new("SpotLight")
        spot.Face = Enum.NormalId.Front
        spot.Color = LIGHT_COLOR
        spot.Brightness = 2
        spot.Range = topY - RAIL_Y
        spot.Angle = 25
        spot.Parent = fixture
    end
end

----------------------------------------------------------------
-- Decorate each wall
----------------------------------------------------------------
local walls = {
    { point = center + R.RightVector * halfW, inward = -R.RightVector, length = halfD * 2 },
    { point = center - R.RightVector * halfW, inward = R.RightVector, length = halfD * 2 },
    { point = center + R.LookVector * halfD, inward = -R.LookVector, length = halfW * 2 },
    { point = center - R.LookVector * halfD, inward = R.LookVector, length = halfW * 2 },
}
local upperYs = {}
for y = 9, topY - 2, 3 do
    table.insert(upperYs, y)
end
local lowerCount, upperCount, pilasterCount = 0, 0, 0
local featureIndex = 0

for _, wall in ipairs(walls) do
    local T = CFrame.lookAt(wall.point, wall.point + wall.inward) -- -Z points into the room
    local n = math.floor((wall.length - 2) / BAY)
    local start = -(n * BAY) / 2

    -- Top ledge with a glowing light strip (whole wall)
    box(T * CFrame.new(0, topY - 0.4, -0.5), V(wall.length - 1, 0.8, 1.0), CREAM)
    box(T * CFrame.new(0, topY - 0.85, -1.02), V(wall.length - 1, 0.12, 0.05), GOLD)
    box(T * CFrame.new(0, topY - 1.4, -0.13), V(wall.length - 1, 1.0, 0.25), DARK_WOOD)
    box(T * CFrame.new(0, topY - 1.95, -0.2), V(wall.length - 1, 0.08, 0.12), NEON_WARM)

    for k = 0, n - 1 do
        local cx = start + (k + 0.5) * BAY
        local xs = { cx - BAY / 3, cx, cx + BAY / 3 }

        -- Lower wall: wood paneling
        -- [REX] checked above and below the band, and stood out past it (note 3)
        if allBare(T, { cx - BAY / 3, cx + BAY / 3 }, { 2, 6 }) then
            lowerCount += 1
            local out = math.max(bandOut(T, cx - BAY / 3), bandOut(T, cx), bandOut(T, cx + BAY / 3))
            box(T * CFrame.new(cx, 0.45, -0.18 - out / 2), V(BAY, 0.9, 0.35 + out), BLACK_MARBLE)
            box(T * CFrame.new(cx, 0.92, -0.36 - out), V(BAY, 0.06, 0.03), GOLD)
            box(T * CFrame.new(cx, (0.9 + RAIL_Y) / 2, -0.15 - out / 2), V(BAY, RAIL_Y - 0.9, 0.3 + out), MAHOGANY)
            for _, px in ipairs({ cx - BAY / 4, cx + BAY / 4 }) do
                local pcf = T * CFrame.new(px, 3.7, -0.35 - out)
                box(pcf, V(BAY / 2 - 1.6, 3.6, 0.15), MAHOGANY_LIGHT)
                frameBars(pcf * CFrame.new(0, 0, -0.08), BAY / 2 - 1.6, 3.6, 0.1, 0.05, GOLD)
            end
            box(T * CFrame.new(cx, RAIL_Y, -0.25 - out / 2), V(BAY, 0.4, 0.5 + out), MAHOGANY)
            box(T * CFrame.new(cx, RAIL_Y + 0.22, -0.3 - out / 2), V(BAY, 0.06, 0.55 + out), GOLD)
        end

        -- Upper wall: velvet panel with gold frames and a mirror or painting
        if #upperYs > 0 and allBare(T, xs, upperYs) then
            upperCount += 1
            local panelBottom, panelTop = RAIL_Y + 1.0, topY - 2.4
            local ph = panelTop - panelBottom
            local pw = BAY - 2.2
            local pcf = T * CFrame.new(cx, (panelBottom + panelTop) / 2, -0.08)
            box(pcf, V(pw, ph, 0.12), VELVET)
            frameBars(pcf * CFrame.new(0, 0, -0.1), pw - 0.6, ph - 0.6, 0.25, 0.15, GOLD)
            frameBars(pcf * CFrame.new(0, 0, -0.1), pw - 1.6, ph - 1.6, 0.1, 0.1, GOLD)
            for _, sx in ipairs({ -1, 1 }) do
                for _, sy in ipairs({ -1, 1 }) do
                    ball((pcf * CFrame.new(sx * (pw - 0.6) / 2, sy * (ph - 0.6) / 2, -0.2)).Position, 0.4, GOLD)
                end
            end
            featureIndex += 1
            local useMirror = MIRRORS and (featureIndex % 2 == 1 or not ARTWORK)
            if useMirror and ph > 6 then
                archedMirror(T, cx, panelBottom + 1.4, panelTop - 1.6, math.min(pw - 4.5, 5))
            elseif ARTWORK and ph > 4 then
                local artH = math.min(ph - 3.5, 7)
                painting(T, cx, panelBottom + 1.2 + artH / 2, math.min(pw - 3, 7), artH)
            end
        end
    end

    -- Columns between the sections
    for k = 0, n do
        local x = start + k * BAY
        if allBare(T, { x }, { 2, 9, math.max(9, topY - 3) }) then
            pilasterCount += 1
            pilaster(T, x, pilasterCount % 2 == 0)
        end
    end
end

model.Parent = casinoRoot

----------------------------------------------------------------
-- Trim hanging lamp rods so they end at the ceiling
----------------------------------------------------------------
-- [REX] cut to the interior ceiling's height instead of firing rays that
-- pass through it and through chandeliers (note 5)
local trimmed = 0
if FIX_HANGING_RODS then
    for _, name in ipairs({ "LuxuryRoulette", "LuxuryPoker", "LuxuryCraps", "LuxuryBar" }) do
        local container = casinoRoot:FindFirstChild(name) or workspace:FindFirstChild(name)
        if container then
            for _, p in ipairs(container:GetDescendants()) do
                if p:IsA("Part") and p.Shape == Enum.PartType.Cylinder and p.Size.Y <= 0.15 and p.Size.X >= 3
                    and math.abs(p.CFrame.RightVector.Y) > 0.98 then
                    local bottom = p.Position.Y - p.Size.X / 2
                    local top = p.Position.Y + p.Size.X / 2
                    if bottom < panelBottomY and top > panelBottomY + 0.1 then
                        local length = panelBottomY + 0.05 - bottom
                        p.Size = V(length, p.Size.Y, p.Size.Z)
                        p.CFrame = CFrame.new(p.Position.X, bottom + length / 2, p.Position.Z) * CFrame.Angles(0, 0, math.rad(90))
                        trimmed += 1
                    end
                end
            end
        end
    end
end

local parts = 0
for _, d in ipairs(model:GetDescendants()) do
    if d:IsA("BasePart") then
        parts += 1
    end
end
print(string.format("[Walls] Decorated %d lower sections, %d upper sections, %d columns (%d parts). Hid %d old trim parts. Trimmed %d lamp rods.",
    lowerCount, upperCount, pilasterCount, parts, removed, trimmed))
