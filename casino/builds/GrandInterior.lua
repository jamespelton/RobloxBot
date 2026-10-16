-- GRAND CASINO INTERIOR (decoration only - doesn't touch your games)
-- Written by James. Changes are marked [REX]:
--
--   1. FLOOR DETECTION WAS 47 STUDS OUT. The original took the first thing a
--      downward ray hit, starting from just under the roof deck. In this place
--      that ray hits Shell.Ceiling and stops, so floorY came back as world
--      47.00 - the TOP of the ceiling slab - instead of the real floor at world
--      0.30. Everything downstream is measured off floorY, so the whole script
--      would have decorated the ~2-stud attic between the ceiling and the roof.
--      Verified by running the original measuring code against the place.
--      Now it collects every surface down the column and takes the floor to be
--      the bottom of the tallest air gap, which is the room by definition.
--   2. The ceiling is still found by casting UP from the floor, which is right:
--      a downward ray gives the ceiling's top face (world 47), an upward ray
--      gives its underside (world 44.3), and the underside is the room.
--   3. Planters and Chandeliers are built with CanQuery off (4,952 and 7,443
--      parts), so rays pass straight through them. The "is this spot clear"
--      tests therefore saw empty floor where a planter stands and would have
--      laid floor medallions and wall panelling straight through them. Query
--      is lifted for those two tests and put back afterwards.
--   4. Wall detection now only accepts big parts. With query lifted the
--      planters at X +/-97 would otherwise be mistaken for the walls at
--      +/-148, shrinking the room by a third. Cast retry limit raised from 8
--      to 24 so a ray can pass several objects before reaching the wall.
--   5. The previous GrandInterior is destroyed BEFORE anything is measured.
--      Left in place, its own ceiling and floor slabs become the surfaces the
--      next run measures, so the room shrinks a little every time.
--   6. Parented into the Casino folder, like the other build scripts.
--   7. CARPET_UPGRADE stashes each part's original material in an attribute so
--      the change can be undone.
--   8. The column uplight's SpotLight had no Shadows = false. Every other light
--      in the script sets it; this one was quietly costing shadow passes.
--   9. The column scan is scoped to the Casino folder instead of all ~58,000
--      workspace parts, and skips anything hugging a wall so the facade
--      pilasters do not get free-standing column bases half-buried in the wall.

-- Settings:
local NEW_CEILING = true      -- cream and gold ceiling with lights
local WALL_DETAILS = true     -- wood paneling, gold trim, wall lights
local COLUMN_DETAILS = true   -- gold rings and lights on columns
local FLOOR_DETAILS = true    -- gold border and star circles on the floor
local CARPET_UPGRADE = true   -- gives your floor a carpet texture
local COLOR_GRADING = true    -- slight warm color tone for the game
local MORE_LIGHTS = true      -- false = fewer lights (less lag)

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")

local V = Vector3.new

----------------------------------------------------------------
-- Find the building
----------------------------------------------------------------
local roof, sides
for _ = 1, 100 do
    roof = workspace:FindFirstChild("GrandRooftop", true)
    sides = workspace:FindFirstChild("GrandSidesAndRoof", true)
    if roof or sides then
        break
    end
    task.wait(0.2)
end
if sides and not roof then
    for _ = 1, 25 do
        roof = workspace:FindFirstChild("GrandRooftop", true)
        if roof then
            break
        end
        task.wait(0.2)
    end
end

-- [REX] clear the previous run before measuring anything, not after
local previous = workspace:FindFirstChild("GrandInterior", true)
if previous then
    previous:Destroy()
end

local FRAME, W, D, RT
local function measureDeck(container, material)
    FRAME = container:GetPivot()
    local minX, maxX, minZ, maxZ, top = math.huge, -math.huge, math.huge, -math.huge, nil
    for _, p in ipairs(container:GetDescendants()) do
        if p:IsA("BasePart") and p.Material == material and math.abs(p.Size.Y - 0.5) < 0.01 and p.Size.X > 20 then
            local lc = FRAME:ToObjectSpace(p.CFrame)
            local half = p.Size / 2
            minX, maxX = math.min(minX, lc.X - half.X), math.max(maxX, lc.X + half.X)
            minZ, maxZ = math.min(minZ, lc.Z - half.Z), math.max(maxZ, lc.Z + half.Z)
            top = math.max(top or -math.huge, lc.Y + half.Y)
        end
    end
    if top then
        -- the deck starts at local Z 0, so maxZ is the depth
        W, D, RT = maxX - minX, maxZ, top
        return true
    end
    return false
end
if not ((roof and measureDeck(roof, Enum.Material.Pebble)) or (sides and measureDeck(sides, Enum.Material.Slate))) then
    error("[Interior] Couldn't find the building. Make sure the exterior, sides and roof scripts are in ServerScriptService.")
end

local model = Instance.new("Model")
model.Name = "GrandInterior"

----------------------------------------------------------------
-- Measuring with rays (everything below uses building coordinates)
----------------------------------------------------------------
local function exclusions()
    local list = { model }
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character then
            table.insert(list, player.Character)
        end
    end
    return list
end

-- [REX] Planters and Chandeliers have CanQuery off, so rays go straight
-- through them. Lift it while we test whether a spot is occupied, then put it
-- back exactly as it was.
local lifted = {}
local function liftQuery()
    if #lifted > 0 then
        return
    end
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("BasePart") and not d.CanQuery and not d:IsDescendantOf(model) then
            d.CanQuery = true
            table.insert(lifted, d)
        end
    end
end
local function restoreQuery()
    for _, d in ipairs(lifted) do
        d.CanQuery = false
    end
    lifted = {}
end

-- Casts a ray in building coordinates; skips hits that `accept` rejects
-- [REX] retry limit 8 -> 24, so a ray can pass several objects before the wall
local function cast(originLocal, dirLocal, accept)
    local skip = exclusions()
    local origin = FRAME * originLocal
    local dir = FRAME:VectorToWorldSpace(dirLocal)
    for _ = 1, 24 do
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = skip
        local hit = workspace:Raycast(origin, dir, params)
        if not hit then
            return nil
        end
        if not accept or accept(hit.Instance) then
            return FRAME:PointToObjectSpace(hit.Position), hit.Instance
        end
        table.insert(skip, hit.Instance)
    end
    return nil
end

local function isChandelier(inst)
    local p = inst
    while p and p ~= workspace do
        if string.find(string.lower(p.Name), "chandelier") then
            return true
        end
        p = p.Parent
    end
    return false
end

----------------------------------------------------------------
-- [REX] Floor height, by the tallest air gap
----------------------------------------------------------------
-- Every surface straight down from above the roof, top first.
local function surfacesBelow(xLocal, zLocal)
    local found = {}
    local skip = exclusions()
    local origin = FRAME * V(xLocal, RT + 8, zLocal)
    local dir = FRAME:VectorToWorldSpace(V(0, -(RT + 60), 0))
    for _ = 1, 40 do
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = skip
        local hit = workspace:Raycast(origin, dir, params)
        if not hit then
            break
        end
        table.insert(found, FRAME:PointToObjectSpace(hit.Position).Y)
        table.insert(skip, hit.Instance)
    end
    table.sort(found, function(a, b)
        return a > b
    end)
    return found
end

-- The room is the tallest gap between two surfaces. The roof-to-ceiling void
-- and the plinth sandwich are both far shorter, so this picks the room out
-- without having to know anything about the building.
local floorY
for _, fx in ipairs({ -0.35, -0.18, 0, 0.18, 0.35 }) do
    for _, fz in ipairs({ 0.2, 0.35, 0.5, 0.65, 0.8 }) do
        local surfaces = surfacesBelow(fx * W, fz * D)
        local bestGap, bestBottom = 0, nil
        for i = 1, #surfaces - 1 do
            local gap = surfaces[i] - surfaces[i + 1]
            if gap > bestGap then
                bestGap, bestBottom = gap, surfaces[i + 1]
            end
        end
        -- only trust a gap tall enough to actually be a room
        if bestBottom and bestGap >= 10 then
            floorY = math.min(floorY or math.huge, bestBottom)
        end
    end
end
if not floorY then
    error("[Interior] Couldn't find the casino floor.")
end

-- Ceiling height (ignores chandeliers and small things).
-- Cast upward on purpose: a downward ray returns the ceiling's top face, an
-- upward ray returns its underside, and the underside is what the room sees.
local ceilY
for _, fx in ipairs({ -0.3, 0, 0.3 }) do
    for _, fz in ipairs({ 0.25, 0.5, 0.75 }) do
        local hitPos = cast(V(fx * W, floorY + 4, fz * D), V(0, 100, 0), function(inst)
            return not isChandelier(inst) and math.max(inst.Size.X, inst.Size.Z) >= 6
        end)
        if hitPos and hitPos.Y > floorY + 10 then
            ceilY = math.min(ceilY or math.huge, hitPos.Y)
        end
    end
end
ceilY = ceilY or (RT - 0.6)
local roomH = ceilY - floorY

-- Inside wall positions (the farthest hit in each direction is the wall)
local midZ = D / 2
local wallY = floorY + math.min(8, roomH * 0.5)
local xMin, xMax, zMin, zMax = -W / 2 + 2, W / 2 - 2, 2, D - 2
-- [REX] only a big slab counts as a wall, so furniture cannot stand in for one
local function isWall(inst)
    return math.max(inst.Size.X, inst.Size.Z) >= 30 and inst.Size.Y >= roomH * 0.4
end
local function farthest(dirLocal, offsets, makeOrigin, axis, pickMax)
    local best
    for _, o in ipairs(offsets) do
        local hitPos = cast(makeOrigin(o), dirLocal, isWall)
        if hitPos then
            local value = hitPos[axis]
            if not best or (pickMax and value > best) or (not pickMax and value < best) then
                best = value
            end
        end
    end
    return best
end
local zOffsets, xOffsets = {}, {}
for k = -3, 3 do
    table.insert(zOffsets, midZ + k * D * 0.1)
    table.insert(xOffsets, k * W * 0.1)
end
xMax = farthest(V(W, 0, 0), zOffsets, function(z) return V(0, wallY, z) end, "X", true) or xMax
xMin = farthest(V(-W, 0, 0), zOffsets, function(z) return V(0, wallY, z) end, "X", false) or xMin
zMax = farthest(V(0, 0, D), xOffsets, function(x) return V(x, wallY, midZ) end, "Z", true) or zMax
zMin = farthest(V(0, 0, -D), xOffsets, function(x) return V(x, wallY, midZ) end, "Z", false) or zMin
xMin, xMax = math.max(xMin, -W / 2 - 2), math.min(xMax, W / 2 + 2)
zMin, zMax = math.max(zMin, -2), math.min(zMax, D + 2)

print(string.format("[Interior] Room: %d x %d, floor at %.1f (world %.1f), ceiling %.1f high",
    xMax - xMin, zMax - zMin, floorY, floorY + FRAME.Position.Y, roomH))

----------------------------------------------------------------
-- Materials
----------------------------------------------------------------
local CREAM = { Color = Color3.fromRGB(235, 222, 200), Material = Enum.Material.Plaster }
local GOLD = { Color = Color3.fromRGB(212, 175, 55), Material = Enum.Material.Metal, Reflectance = 0.35 }
local GOLD_LEAF = { Color = Color3.fromRGB(190, 150, 75), Material = Enum.Material.Foil }
local MAHOGANY = { Color = Color3.fromRGB(75, 30, 22), Material = Enum.Material.Wood }
local GRANITE = { Color = Color3.fromRGB(25, 25, 28), Material = Enum.Material.Granite }
local DEEP_RED = { Color = Color3.fromRGB(110, 12, 20), Material = Enum.Material.Carpet }
local NEON_WARM = { Color = Color3.fromRGB(255, 225, 170), Material = Enum.Material.Neon }
local NEON_GOLD = { Color = Color3.fromRGB(255, 200, 90), Material = Enum.Material.Neon }
local BLACK_METAL = { Color = Color3.fromRGB(25, 25, 28), Material = Enum.Material.Metal }
local WARM_LIGHT = Color3.fromRGB(255, 210, 150)

----------------------------------------------------------------
-- Building helpers (decoration never blocks players or clicks)
----------------------------------------------------------------
local function makePart(props)
    local p = Instance.new("Part")
    p.Anchored = true
    p.CanCollide = false
    p.CanTouch = false
    p.CanQuery = false
    p.CastShadow = false
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

local function cylUp(pos, height, width, style)
    return styled({
        Shape = Enum.PartType.Cylinder,
        Size = V(height, width, width),
        CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)),
    }, style)
end

local function rod(a, b, thickness, style)
    local dir = (b - a).Unit
    local up = math.abs(dir.Y) > 0.98 and V(1, 0, 0) or V(0, 1, 0)
    return styled({
        Shape = Enum.PartType.Cylinder,
        Size = V((b - a).Magnitude + thickness * 0.3, thickness, thickness),
        CFrame = CFrame.lookAt((a + b) / 2, b, up) * CFrame.Angles(0, math.rad(90), 0),
    }, style)
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

local function pointLight(part, range, brightness)
    local light = Instance.new("PointLight")
    light.Color = WARM_LIGHT
    light.Range = range
    light.Brightness = brightness
    light.Shadows = false
    light.Parent = part
end

local function uplight(pos, aim)
    local dir = (aim - pos).Unit
    local up = math.abs(dir.Y) > 0.98 and V(1, 0, 0) or V(0, 1, 0)
    local fixture = box(CFrame.lookAt(pos, aim, up), V(0.6, 0.5, 0.8), BLACK_METAL)
    box(fixture.CFrame * CFrame.new(0, 0, -0.42), V(0.45, 0.35, 0.05), NEON_WARM)
    local spot = Instance.new("SpotLight")
    spot.Face = Enum.NormalId.Front
    spot.Color = WARM_LIGHT
    spot.Brightness = 3
    spot.Range = math.min(roomH + 6, 40)
    spot.Angle = 30
    spot.Shadows = false -- [REX] every other light here sets this
    spot.Parent = fixture
end

local cx, cz = (xMin + xMax) / 2, (zMin + zMax) / 2

----------------------------------------------------------------
-- Ceiling
----------------------------------------------------------------
local ceil = ceilY - 0.3
if NEW_CEILING then
    rangeBox(xMin, xMax, ceil - 0.2, ceil, zMin, zMax, GOLD_LEAF)

    -- Border around the edge with a glowing strip
    local S = 6
    rangeBox(xMin, xMax, ceil - 2.6, ceil - 0.2, zMin, zMin + S, CREAM)
    rangeBox(xMin, xMax, ceil - 2.6, ceil - 0.2, zMax - S, zMax, CREAM)
    rangeBox(xMin, xMin + S, ceil - 2.6, ceil - 0.2, zMin + S, zMax - S, CREAM)
    rangeBox(xMax - S, xMax, ceil - 2.6, ceil - 0.2, zMin + S, zMax - S, CREAM)
    rangeBox(xMin + S, xMax - S, ceil - 0.6, ceil - 0.3, zMin + S, zMin + S + 0.15, NEON_WARM)
    rangeBox(xMin + S, xMax - S, ceil - 0.6, ceil - 0.3, zMax - S - 0.15, zMax - S, NEON_WARM)
    rangeBox(xMin + S, xMin + S + 0.15, ceil - 0.6, ceil - 0.3, zMin + S, zMax - S, NEON_WARM)
    rangeBox(xMax - S - 0.15, xMax - S, ceil - 0.6, ceil - 0.3, zMin + S, zMax - S, NEON_WARM)
    rangeBox(xMin + S, xMax - S, ceil - 2.7, ceil - 2.6, zMin + S - 0.3, zMin + S, GOLD)
    rangeBox(xMin + S, xMax - S, ceil - 2.7, ceil - 2.6, zMax - S, zMax - S + 0.3, GOLD)
    rangeBox(xMin + S - 0.3, xMin + S, ceil - 2.7, ceil - 2.6, zMin + S, zMax - S, GOLD)
    rangeBox(xMax - S, xMax - S + 0.3, ceil - 2.7, ceil - 2.6, zMin + S, zMax - S, GOLD)

    -- Cream beams in a grid with gold trim
    local x0, x1, z0, z1 = xMin + S, xMax - S, zMin + S, zMax - S
    local spacing = 16
    local nx = math.max(1, math.floor((x1 - x0) / spacing))
    local nz = math.max(1, math.floor((z1 - z0) / spacing))
    local stepX, stepZ = (x1 - x0) / nx, (z1 - z0) / nz
    for i = 1, nx - 1 do
        local x = x0 + i * stepX
        rangeBox(x - 0.6, x + 0.6, ceil - 1.4, ceil - 0.2, z0, z1, CREAM)
        rangeBox(x - 0.2, x + 0.2, ceil - 1.45, ceil - 1.4, z0, z1, GOLD)
    end
    for j = 1, nz - 1 do
        local z = z0 + j * stepZ
        rangeBox(x0, x1, ceil - 1.4, ceil - 0.2, z - 0.6, z + 0.6, CREAM)
        rangeBox(x0, x1, ceil - 1.45, ceil - 1.4, z - 0.2, z + 0.2, GOLD)
    end

    -- Downlight in every panel
    local lightEvery = MORE_LIGHTS and 3 or 6
    local index = 0
    for i = 0, nx - 1 do
        for j = 0, nz - 1 do
            index += 1
            local px, pz = x0 + (i + 0.5) * stepX, z0 + (j + 0.5) * stepZ
            local light = B(px, ceil - 0.25, pz, 1.4, 0.08, 1.4, NEON_WARM)
            B(px, ceil - 0.23, pz, 2.2, 0.06, 2.2, GOLD)
            if index % lightEvery == 0 then
                pointLight(light, 24, 0.8)
            end
        end
    end

    -- Big gold ring with a glowing halo over the middle of the room
    local ringR = math.min(14, (xMax - xMin) / 6, (zMax - zMin) / 6)
    ringRods(cx, ceil - 1.7, cz, ringR, 36, 0.7, GOLD)
    ringRods(cx, ceil - 1.6, cz, ringR - 0.8, 36, 0.25, NEON_GOLD)
    ringRods(cx, ceil - 1.7, cz, ringR + 1.2, 36, 0.3, GOLD)
end

-- [REX] from here on the "is this spot occupied" tests need to see the
-- planters, so query goes up until the floor work is finished.
liftQuery()

----------------------------------------------------------------
-- Walls: wood paneling, gold trim and wall lights
----------------------------------------------------------------
local wallsDone = 0
if WALL_DETAILS then
    local SEG = 12
    local walls = {
        { origin = V(xMax, floorY, cz), inward = V(-1, 0, 0), length = zMax - zMin },
        { origin = V(xMin, floorY, cz), inward = V(1, 0, 0), length = zMax - zMin },
        { origin = V(cx, floorY, zMax), inward = V(0, 0, -1), length = xMax - xMin },
        { origin = V(cx, floorY, zMin), inward = V(0, 0, 1), length = xMax - xMin },
    }
    local frameTop = math.min(roomH - 3.5, 30)
    local sconceY = math.min(10, roomH * 0.55)
    local sconceCount = 0

    -- True if the wall here is bare (nothing standing in front of it)
    local function bare(T, s)
        for _, y in ipairs({ 2.5, math.min(9, roomH * 0.5) }) do
            local origin = T * V(s, y, -5)
            local dir = T:VectorToWorldSpace(V(0, 0, 6))
            local hitPos = cast(origin, dir)
            if not hitPos or math.abs((hitPos - origin).Magnitude - 5) > 0.6 then
                return false
            end
        end
        return true
    end

    local function sconce(T, x)
        box(T * CFrame.new(x, sconceY, -0.15), V(0.7, 1.8, 0.2), GOLD)
        box(T * CFrame.new(x, sconceY - 0.4, -0.6), V(0.15, 0.15, 0.9), GOLD)
        box(T * CFrame.new(x, sconceY - 0.4, -1.05), V(1.1, 0.12, 0.12), GOLD)
        local bulbs = {}
        for _, side in ipairs({ -0.5, 0.5 }) do
            cylUp(T * V(x + side, sconceY - 0.2, -1.05), 0.35, 0.4, GOLD)
            table.insert(bulbs, ball(T * V(x + side, sconceY + 0.2, -1.05), 0.45, NEON_WARM))
        end
        sconceCount += 1
        if MORE_LIGHTS or sconceCount % 2 == 0 then
            pointLight(bulbs[1], 14, 0.8)
        end
    end

    for _, wall in ipairs(walls) do
        local T = CFrame.lookAt(wall.origin, wall.origin + wall.inward)
        local n = math.floor((wall.length - 4) / SEG)
        local start = -(n * SEG) / 2
        local bareList = {}
        for k = 0, n - 1 do
            bareList[k] = bare(T, start + (k + 0.5) * SEG)
        end
        for k = 0, n - 1 do
            if bareList[k] then
                wallsDone += 1
                local s = start + (k + 0.5) * SEG
                box(T * CFrame.new(s, 0.4, -0.25), V(SEG, 0.8, 0.5), GRANITE)
                box(T * CFrame.new(s, 3.65, -0.2), V(SEG, 5.7, 0.4), MAHOGANY)
                for _, dy in ipairs({ -2, 2 }) do
                    box(T * CFrame.new(s, 3.65 + dy, -0.45), V(SEG - 2, 0.15, 0.1), GOLD)
                end
                for _, dx in ipairs({ -1, 1 }) do
                    box(T * CFrame.new(s + dx * (SEG / 2 - 1), 3.65, -0.45), V(0.15, 4, 0.1), GOLD)
                end
                box(T * CFrame.new(s, 6.6, -0.35), V(SEG, 0.3, 0.7), GOLD)

                -- Gold picture-frame trim on the upper wall
                if frameTop - 8.5 > 4 then
                    local fh = frameTop - 8.5
                    local fy = 8.5 + fh / 2
                    for _, dy in ipairs({ -fh / 2, fh / 2 }) do
                        box(T * CFrame.new(s, fy + dy, -0.1), V(SEG - 3, 0.2, 0.15), GOLD)
                    end
                    for _, dx in ipairs({ -1, 1 }) do
                        box(T * CFrame.new(s + dx * (SEG - 3) / 2, fy, -0.1), V(0.2, fh, 0.15), GOLD)
                    end
                end

                -- Wall light between two bare panels
                if k < n - 1 and bareList[k + 1] then
                    sconce(T, s + SEG / 2)
                end
            end
        end
    end
end

----------------------------------------------------------------
-- Columns
----------------------------------------------------------------
local columnsDone = 0
if COLUMN_DETAILS then
    local found = {}
    -- [REX] scoped to the Casino folder; scanning all of workspace now means
    -- ~58,000 parts and the city cannot contain casino columns anyway.
    local searchRoot = workspace:FindFirstChild("Casino") or workspace
    for _, p in ipairs(searchRoot:GetDescendants()) do
        if p:IsA("BasePart") and not p:IsA("Terrain") and not p:IsDescendantOf(model) then
            local lp = FRAME:PointToObjectSpace(p.Position)
            if lp.X > xMin + 2 and lp.X < xMax - 2 and lp.Z > zMin + 2 and lp.Z < zMax - 2 then
                local cf = FRAME:ToObjectSpace(p.CFrame)
                local s = p.Size / 2
                local ex = math.abs(cf.RightVector.X) * s.X + math.abs(cf.UpVector.X) * s.Y + math.abs(cf.LookVector.X) * s.Z
                local ey = math.abs(cf.RightVector.Y) * s.X + math.abs(cf.UpVector.Y) * s.Y + math.abs(cf.LookVector.Y) * s.Z
                local ez = math.abs(cf.RightVector.Z) * s.X + math.abs(cf.UpVector.Z) * s.Y + math.abs(cf.LookVector.Z) * s.Z
                local tall = ey * 2 >= roomH * 0.7
                local thin = math.max(ex, ez) * 2 <= 8 and math.min(ex, ez) * 2 >= 1.2
                -- [REX] a pilaster flush against a wall is not a free-standing
                -- column; its base ring would be half buried in the wall.
                local freeStanding = (lp.X - xMin) > 8 and (xMax - lp.X) > 8
                    and (lp.Z - zMin) > 8 and (zMax - lp.Z) > 8
                if tall and thin and freeStanding then
                    local duplicate = false
                    for _, c in ipairs(found) do
                        if (V(c.x, 0, c.z) - V(lp.X, 0, lp.Z)).Magnitude < 2.5 then
                            duplicate = true
                            c.r = math.max(c.r, ex, ez)
                            break
                        end
                    end
                    if not duplicate and #found < 60 then
                        table.insert(found, { x = lp.X, z = lp.Z, r = math.max(ex, ez) })
                    end
                end
            end
        end
    end
    for _, c in ipairs(found) do
        columnsDone += 1
        local d = c.r * 2
        B(c.x, floorY + 0.3, c.z, d + 2.4, 0.6, d + 2.4, GRANITE)
        cylUp(V(c.x, floorY + 1.0, c.z), 0.8, d + 1.4, GOLD)
        cylUp(V(c.x, floorY + 1.55, c.z), 0.15, d + 1.1, NEON_GOLD)
        cylUp(V(c.x, floorY + roomH * 0.38, c.z), 0.35, d + 0.35, GOLD)
        cylUp(V(c.x, floorY + roomH * 0.38 + 0.7, c.z), 0.15, d + 0.3, GOLD)
        cylUp(V(c.x, ceil - 3.2, c.z), 1, d + 1.2, GOLD)
        uplight(V(c.x + c.r + 1.4, floorY + 0.4, c.z), V(c.x, ceil - 3, c.z))
    end
end

----------------------------------------------------------------
-- Floor
----------------------------------------------------------------
local carpeted = 0
if CARPET_UPGRADE then
    local done = {}
    for x = xMin + 4, xMax - 4, 20 do
        for z = zMin + 4, zMax - 4, 20 do
            local hitPos, part = cast(V(x, floorY + 6, z), V(0, -8, 0))
            if part and math.abs(hitPos.Y - floorY) < 0.3 and math.max(part.Size.X, part.Size.Z) >= 10 and not done[part] then
                done[part] = true
                -- [REX] remember what it was, so this is reversible
                if part:GetAttribute("InteriorOrigMaterial") == nil then
                    part:SetAttribute("InteriorOrigMaterial", part.Material.Name)
                end
                part.Material = Enum.Material.Carpet
                carpeted += 1
            end
        end
    end
end

local medallions = 0
if FLOOR_DETAILS then
    -- Black and gold border around the room
    local a, b = 2, 4.5
    local y = floorY + 0.015
    rangeBox(xMin + a, xMax - a, y, y + 0.03, zMin + a, zMin + b, GRANITE)
    rangeBox(xMin + a, xMax - a, y, y + 0.03, zMax - b, zMax - a, GRANITE)
    rangeBox(xMin + a, xMin + b, y, y + 0.03, zMin + b, zMax - b, GRANITE)
    rangeBox(xMax - b, xMax - a, y, y + 0.03, zMin + b, zMax - b, GRANITE)
    for _, inset in ipairs({ a, b }) do
        rangeBox(xMin + inset, xMax - inset, y + 0.03, y + 0.05, zMin + inset - 0.15, zMin + inset + 0.15, GOLD)
        rangeBox(xMin + inset, xMax - inset, y + 0.03, y + 0.05, zMax - inset - 0.15, zMax - inset + 0.15, GOLD)
        rangeBox(xMin + inset - 0.15, xMin + inset + 0.15, y + 0.03, y + 0.05, zMin + inset, zMax - inset, GOLD)
        rangeBox(xMax - inset - 0.15, xMax - inset + 0.15, y + 0.03, y + 0.05, zMin + inset, zMax - inset, GOLD)
    end

    -- Gold star circles in open floor spots
    -- [REX] A box query over the whole disc. The original fired five rays at
    -- the centre and four points 4.5 studs out, and anything narrower than the
    -- gaps between them slipped through: 4 of the 14 medallions came out
    -- underneath a slot-machine stool. The disc is 8 studs across, so test all
    -- of it, from just above the floor to head height.
    local discParams = OverlapParams.new()
    discParams.FilterType = Enum.RaycastFilterType.Exclude
    discParams.FilterDescendantsInstances = exclusions()
    discParams.MaxParts = 1
    local function clear(x, z)
        local probe = FRAME * CFrame.new(x, floorY + 2.8, z)
        return #workspace:GetPartBoundsInBox(probe, V(9, 4.4, 9), discParams) == 0
    end
    for x = xMin + 12, xMax - 12, 26 do
        for z = zMin + 12, zMax - 12, 26 do
            if medallions < 14 and clear(x, z) then
                medallions += 1
                cylUp(V(x, floorY + 0.02, z), 0.04, 8, GOLD)
                cylUp(V(x, floorY + 0.03, z), 0.04, 7.4, GRANITE)
                cylUp(V(x, floorY + 0.04, z), 0.04, 6, DEEP_RED)
                for k = 0, 7 do
                    box(CFrame.new(x, floorY + 0.06, z) * CFrame.Angles(0, k * math.pi / 4, 0) * CFrame.new(0, 0, -1.4),
                        V(0.35, 0.02, 2.8), GOLD)
                end
                cylUp(V(x, floorY + 0.07, z), 0.04, 1.2, GOLD)
            end
        end
    end
end

-- [REX] put CanQuery back exactly as it was
restoreQuery()

----------------------------------------------------------------
-- Warm color tone
----------------------------------------------------------------
if COLOR_GRADING and not Lighting:FindFirstChild("CasinoColor") then
    local cc = Instance.new("ColorCorrectionEffect")
    cc.Name = "CasinoColor"
    cc.TintColor = Color3.fromRGB(255, 246, 235)
    cc.Saturation = 0.08
    cc.Contrast = 0.05
    cc.Parent = Lighting
end

----------------------------------------------------------------
-- Place it
----------------------------------------------------------------
model.WorldPivot = CFrame.new(0, 0, 0)
model:PivotTo(FRAME)
-- [REX] into the Casino folder, like the other builds
model.Parent = workspace:FindFirstChild("Casino") or workspace

local parts = 0
for _, d in ipairs(model:GetDescendants()) do
    if d:IsA("BasePart") then
        parts = parts + 1
    end
end
print(string.format("[Interior] Decorated %d wall panels, %d columns, %d floor parts, %d floor circles | %d parts",
    wallsDone, columnsDone, carpeted, medallions, parts))

return model
