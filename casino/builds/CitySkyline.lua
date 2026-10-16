-- CITY SKYLINE (fills the empty parts of your map with tall buildings)
-- Written by James. Changes are marked [REX]:
--   1. Ground detection rewritten. The original asked insideKept() to ignore
--      anything under a KEEP_CLEAR name, but in this place EVERYTHING lives
--      under workspace.Casino, so groundSet came back empty and the script
--      died on "Couldn't find your ground". Dropping the exclusion was worse:
--      seven parts match the flat-ground filter, including Shell.Ceiling at
--      y=46 and Roof.RoofCrown at y=51, and groundAt() accepts the first
--      groundSet part a downward ray hits -- so the city would have been
--      built on the casino roof. Now the ground is the single part with the
--      largest footprint, which is unambiguous.
--   2. The ground plate is extended first. At 900x800 the only land the city
--      could legally use was a 198-stud strip at the north; everything else
--      was inside CASINO_GAP of the forecourt, lot or trees. The original
--      size is stashed as attributes so this is reversible.
--   3. The previous City is destroyed BEFORE the ground is probed, not after.
--      Old sidewalks are flat 150+ stud parts, so a re-run would measure its
--      own output and stack a second city on the first.
--   4. casinoCenter is the largest keep box, not keepBoxes[1]. The first box
--      depends on GetDescendants() order, and CasinoSpawn can win it, which
--      silently moves the centre of the height gradient.
--   5. The blinking-light loop moved into a child Script. Held by the builder
--      it spins forever in edit mode and dirties the place file.
--   6. No task.wait() in the build loop -- execute_luau returns as soon as the
--      script yields, so the build reported done while still half-built.

-- Settings:
local MAX_BLOCKS = 70        -- most city blocks to build (lower = less lag, bigger blocks)
local MIN_HEIGHT = 50        -- shortest buildings (closest to the casino)
local MAX_HEIGHT = 260       -- tallest buildings (farthest from the casino)
local STREET_WIDTH = 26
local CASINO_GAP = 40        -- empty space kept around your casino and parking lot
local LIT_WINDOWS = true
local STREET_LIGHTS = true
local AVIATION_LIGHTS = true -- blinking red lights on tall towers
local SEED = 2024            -- change for a different city

-- [REX] The ground is grown to make room for the city. Set to nil to leave it
-- alone. The original size/position are stashed on the part as attributes.
local GROUND_W, GROUND_D = 1800, 1400
local GROUND_CENTER_X, GROUND_CENTER_Z = 0, -130

-- [REX] report the layout and build nothing
local DRY_RUN = false

-- The city stays away from these
local KEEP_CLEAR = {
    "Casino", "GrandExterior", "GrandSidesAndRoof", "GrandRooftop", "CasinoParkingLot",
    "ParkedCars", "Trees", "PalmTrees", "ParkingLightPosts",
}

local rng = Random.new(SEED)
local function rand(a, b)
    return rng:NextNumber(a, b)
end
local function pick(list)
    return list[rng:NextInteger(1, #list)]
end
local function V(x, y, z)
    return Vector3.new(x, y, z)
end

-- [REX] Clear the previous run FIRST. Its sidewalks are flat 150+ stud parts
-- and its towers block the groundAt() rays, so probing before clearing means
-- measuring our own output.
local previous = workspace:FindFirstChild("City")
if previous then
    previous:Destroy()
end

local folder = Instance.new("Folder")
folder.Name = "City"

----------------------------------------------------------------
-- Find the ground and the areas to keep clear
----------------------------------------------------------------
local keepNames = {}
for _, name in ipairs(KEEP_CLEAR) do
    keepNames[name] = true
end

local function insideKept(inst)
    local p = inst.Parent
    while p and p ~= workspace do
        if keepNames[p.Name] then
            return true
        end
        p = p.Parent
    end
    return false
end

local function corners(part)
    local half = part.Size / 2
    local list = {}
    for _, sx in ipairs({ -1, 1 }) do
        for _, sy in ipairs({ -1, 1 }) do
            for _, sz in ipairs({ -1, 1 }) do
                table.insert(list, part.CFrame * V(half.X * sx, half.Y * sy, half.Z * sz))
            end
        end
    end
    return list
end

-- [REX] The ground is the biggest flat slab in the place, full stop. Picking it
-- by footprint area means the ceiling, roof deck, roof crown, carpet, plinth
-- and lot paving can never be mistaken for it.
local ground, groundArea = nil, 0
for _, p in ipairs(workspace:GetDescendants()) do
    if p:IsA("BasePart") and not p:IsA("Terrain") and p.Anchored
        and p.Size.Y <= 30 and math.min(p.Size.X, p.Size.Z) >= 150 and p.CFrame.UpVector.Y > 0.99 then
        local area = p.Size.X * p.Size.Z
        if area > groundArea then
            ground, groundArea = p, area
        end
    end
end
if not ground then
    error("[City] Couldn't find your ground. The ground needs to be a big flat part (at least 150 x 150 studs).")
end

-- [REX] Grow the ground so there is somewhere to put a city. Originals are
-- stashed once, so re-running does not overwrite them with the grown values.
if GROUND_W and GROUND_D then
    if ground:GetAttribute("CityOrigSize") == nil then
        ground:SetAttribute("CityOrigSize", ground.Size)
        ground:SetAttribute("CityOrigPos", ground.Position)
    end
    local origSize = ground:GetAttribute("CityOrigSize")
    local origPos = ground:GetAttribute("CityOrigPos")
    ground.Size = V(GROUND_W, origSize.Y, GROUND_D)
    ground.CFrame = CFrame.new(GROUND_CENTER_X, origPos.Y, GROUND_CENTER_Z)
    print(string.format("[City] Ground grown from %.0f x %.0f to %.0f x %.0f (original stashed on the part)",
        origSize.X, origSize.Z, GROUND_W, GROUND_D))
end

local groundSet = { [ground] = true }
local mapMin = V(math.huge, math.huge, math.huge)
local mapMax = -mapMin
for _, c in ipairs(corners(ground)) do
    mapMin = mapMin:Min(c)
    mapMax = mapMax:Max(c)
end

local keepBoxes = {}
local function addKeepBox(container)
    local mn = V(math.huge, math.huge, math.huge)
    local mx = -mn
    local found = false
    local list = container:GetDescendants()
    table.insert(list, container)
    for _, p in ipairs(list) do
        if p:IsA("BasePart") and not groundSet[p] and math.max(p.Size.X, p.Size.Z) < 800 then
            for _, c in ipairs(corners(p)) do
                mn = mn:Min(c)
                mx = mx:Max(c)
            end
            found = true
        end
    end
    if found then
        table.insert(keepBoxes, { mn - V(CASINO_GAP, 0, CASINO_GAP), mx + V(CASINO_GAP, 0, CASINO_GAP) })
    end
end
for _, inst in ipairs(workspace:GetDescendants()) do
    if keepNames[inst.Name] and (inst:IsA("Model") or inst:IsA("Folder")) and not insideKept(inst) then
        addKeepBox(inst)
    elseif inst:IsA("SpawnLocation") then
        addKeepBox(inst)
    end
end

local function blockedByKeep(x0, z0, x1, z1)
    for _, b in ipairs(keepBoxes) do
        if x0 < b[2].X and x1 > b[1].X and z0 < b[2].Z and z1 > b[1].Z then
            return true
        end
    end
    return false
end

-- Center of the casino (buildings get taller farther from here)
-- [REX] the LARGEST keep box, not keepBoxes[1]. GetDescendants() order decides
-- which box lands first, and the spawn point can win it.
local casinoCenter = (mapMin + mapMax) / 2
local bestArea = 0
for _, b in ipairs(keepBoxes) do
    local area = (b[2].X - b[1].X) * (b[2].Z - b[1].Z)
    if area > bestArea then
        bestArea = area
        casinoCenter = (b[1] + b[2]) / 2
    end
end
local maxDistance = 0
for _, x in ipairs({ mapMin.X, mapMax.X }) do
    for _, z in ipairs({ mapMin.Z, mapMax.Z }) do
        maxDistance = math.max(maxDistance, (V(x, 0, z) - V(casinoCenter.X, 0, casinoCenter.Z)).Magnitude)
    end
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.FilterDescendantsInstances = { folder }

local function groundAt(x, z)
    local hit = workspace:Raycast(V(x, mapMax.Y + 600, z), V(0, -2000, 0), rayParams)
    if hit and groundSet[hit.Instance] then
        return hit.Position.Y
    end
    return nil
end

----------------------------------------------------------------
-- Materials
----------------------------------------------------------------
local GLASS_COLORS = {
    Color3.fromRGB(40, 70, 100), Color3.fromRGB(30, 55, 75), Color3.fromRGB(60, 85, 95),
    Color3.fromRGB(70, 80, 90), Color3.fromRGB(45, 60, 80), Color3.fromRGB(80, 95, 110),
}
local STONE_COLORS = {
    Color3.fromRGB(200, 190, 170), Color3.fromRGB(175, 165, 150), Color3.fromRGB(160, 150, 140),
    Color3.fromRGB(140, 130, 120), Color3.fromRGB(210, 205, 195),
}
local CONCRETE_COLORS = {
    Color3.fromRGB(150, 150, 150), Color3.fromRGB(120, 120, 125), Color3.fromRGB(170, 165, 160), Color3.fromRGB(100, 100, 105),
}
local CROWN_COLORS = {
    Color3.fromRGB(120, 220, 255), Color3.fromRGB(240, 240, 255), Color3.fromRGB(255, 200, 90), Color3.fromRGB(200, 120, 255),
}

local METAL = { Color = Color3.fromRGB(170, 175, 180), Material = Enum.Material.Metal }
local METAL_DARK = { Color = Color3.fromRGB(60, 62, 66), Material = Enum.Material.Metal, CanCollide = true }
local DARK_GLASS = { Color = Color3.fromRGB(20, 25, 32), Material = Enum.Material.Glass, Reflectance = 0.3 }
local LOBBY_GLASS = { Color = Color3.fromRGB(20, 25, 30), Material = Enum.Material.Glass, Transparency = 0.35, Reflectance = 0.2 }
local LOBBY_GLOW = { Color = Color3.fromRGB(255, 215, 150), Material = Enum.Material.Neon, Transparency = 0.55 }
local NEON_GOLD = { Color = Color3.fromRGB(255, 200, 90), Material = Enum.Material.Neon }
local WHITE_CONCRETE = { Color = Color3.fromRGB(225, 225, 220), Material = Enum.Material.Concrete }
local SIDEWALK = { Color = Color3.fromRGB(160, 158, 152), Material = Enum.Material.Concrete, CanCollide = true }
local ASPHALT = { Color = Color3.fromRGB(35, 35, 38), Material = Enum.Material.Asphalt, CanCollide = true }
local YELLOW_LINE = { Color = Color3.fromRGB(230, 190, 40), Material = Enum.Material.SmoothPlastic }
local WHITE_LINE = { Color = Color3.fromRGB(230, 230, 225), Material = Enum.Material.SmoothPlastic }
local POLE = { Color = Color3.fromRGB(40, 42, 45), Material = Enum.Material.Metal, CanCollide = true }
local LAMP = { Color = Color3.fromRGB(255, 225, 170), Material = Enum.Material.Neon }
local BARK = { Color = Color3.fromRGB(85, 60, 40), Material = Enum.Material.Wood, CanCollide = true }
local TANK_WOOD = { Color = Color3.fromRGB(110, 80, 55), Material = Enum.Material.WoodPlanks, CanCollide = true }
local HELI = { Color = Color3.fromRGB(50, 50, 52), Material = Enum.Material.Asphalt, CanCollide = true }
local RED_LIGHT = Color3.fromRGB(255, 30, 30)

----------------------------------------------------------------
-- Building helpers
----------------------------------------------------------------
local current = folder
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
    p.Parent = current
    return p
end

local function styled(props, style)
    for key, value in pairs(style) do
        props[key] = value
    end
    return makePart(props)
end

local function B(x, y, z, sx, sy, sz, style)
    return styled({ Size = V(sx, sy, sz), CFrame = CFrame.new(x, y, z) }, style)
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

local blinkers = {}
local function aviationLight(pos)
    if not AVIATION_LIGHTS then
        return
    end
    local b = ball(pos, 1.2, { Color = RED_LIGHT, Material = Enum.Material.Neon })
    b.Name = "BlinkerRed" -- [REX] so the child animator can find it at runtime
    table.insert(blinkers, b)
end

-- The four faces of a building: outward direction, sideways direction, distance from center, face width
local function faces(w, d)
    return {
        { n = V(1, 0, 0), along = V(0, 0, 1), half = w / 2, width = d },
        { n = V(-1, 0, 0), along = V(0, 0, 1), half = w / 2, width = d },
        { n = V(0, 0, 1), along = V(1, 0, 0), half = d / 2, width = w },
        { n = V(0, 0, -1), along = V(1, 0, 0), half = d / 2, width = w },
    }
end

local function faceStrip(center, face, offset, out, y, stripWidth, stripHeight, depth, style)
    local pos = center + face.n * (face.half + out) + face.along * offset + V(0, y, 0)
    local size = face.along.X ~= 0 and V(stripWidth, stripHeight, depth) or V(depth, stripHeight, stripWidth)
    return styled({ Size = size, CFrame = CFrame.new(pos) }, style)
end

local function litWindows(cx, cz, w, d, gy, bottom, top, count)
    if not LIT_WINDOWS or top - bottom < 6 then
        return
    end
    local center = V(cx, 0, cz)
    local list = faces(w, d)
    for _ = 1, count do
        local face = pick(list)
        local color = rand(0, 1) < 0.7 and Color3.fromRGB(255, 210, 140) or Color3.fromRGB(210, 230, 255)
        faceStrip(center, face, rand(-0.5, 0.5) * math.max(face.width - 10, 0), 0.06, gy + rand(bottom, top),
            rand(3, 9), 2.4, 0.1, { Color = color, Material = Enum.Material.Neon, Transparency = 0.15 })
    end
end

local function verticalStrips(cx, cz, w, d, gy, bottom, top, spacing, stripWidth, out, style)
    local center = V(cx, 0, cz)
    for _, face in ipairs(faces(w, d)) do
        local count = math.min(10, math.floor(face.width / spacing))
        for k = 1, count - 1 do
            local offset = -face.width / 2 + k * face.width / count
            faceStrip(center, face, offset, out, gy + (bottom + top) / 2, stripWidth, top - bottom, 0.6, style)
        end
    end
end

local function edgeOutline(cx, cz, w, d, y, style)
    for _, side in ipairs({ -1, 1 }) do
        B(cx, y, cz + side * d / 2, w + 0.4, 0.4, 0.4, style)
        B(cx + side * w / 2, y, cz, 0.4, 0.4, d + 0.4, style)
    end
end

local function lobby(cx, cz, w, d, gy)
    B(cx, gy + 4, cz, w + 0.2, 7.6, d + 0.2, LOBBY_GLOW)
    B(cx, gy + 4, cz, w + 0.4, 8, d + 0.4, LOBBY_GLASS)
    B(cx, gy + 8.3, cz, w + 1.2, 0.6, d + 1.2, METAL)
end

local function antenna(cx, cz, y, height)
    B(cx, y + height / 2, cz, 0.6, height, 0.6, METAL_DARK)
    B(cx, y + height * 0.4, cz, 2.5, 0.3, 0.3, METAL_DARK)
    aviationLight(V(cx, y + height + 0.6, cz))
end

local function waterTower(x, z, y)
    for _, lx in ipairs({ -2, 2 }) do
        for _, lz in ipairs({ -2, 2 }) do
            B(x + lx, y + 2, z + lz, 0.4, 4, 0.4, METAL_DARK)
        end
    end
    cylUp(V(x, y + 6.5, z), 5, 6, TANK_WOOD)
    local roof = B(x, y + 9.8, z, 6.6, 2.4, 6.6, TANK_WOOD)
    local mesh = Instance.new("SpecialMesh")
    mesh.MeshType = Enum.MeshType.Sphere
    mesh.Parent = roof
end

local function rooftopUnits(cx, cz, w, d, y)
    for _ = 1, rng:NextInteger(1, 3) do
        local sx, sz = rand(4, 9), rand(4, 9)
        local x = cx + rand(-0.5, 0.5) * math.max(w - sx - 4, 0)
        local z = cz + rand(-0.5, 0.5) * math.max(d - sz - 4, 0)
        B(x, y + 1.5, z, sx, 3, sz, { Color = Color3.fromRGB(150, 152, 155), Material = Enum.Material.Metal })
    end
end

local function helipad(cx, cz, y, size)
    B(cx, y + 0.2, cz, size, 0.4, size, HELI)
    B(cx - 2, y + 0.42, cz, 1, 0.04, 6, WHITE_LINE)
    B(cx + 2, y + 0.42, cz, 1, 0.04, 6, WHITE_LINE)
    B(cx, y + 0.42, cz, 4, 0.04, 1, WHITE_LINE)
end

----------------------------------------------------------------
-- Building styles
----------------------------------------------------------------
local function glassTower(cx, cz, w, d, h, gy)
    B(cx, gy + h / 2, cz, w, h, d, { Color = pick(GLASS_COLORS), Material = Enum.Material.Glass, Reflectance = 0.25, CanCollide = true })
    lobby(cx, cz, w, d, gy)
    verticalStrips(cx, cz, w, d, gy, 9, h, 6, 0.5, 0.3, METAL)
    local bands = math.min(8, math.floor(h / 25))
    for k = 1, bands do
        B(cx, gy + 8 + k * (h - 8) / (bands + 1), cz, w + 0.7, 0.5, d + 0.7, METAL)
    end
    local cw, cd = w * 0.8, d * 0.8
    B(cx, gy + h + 4, cz, cw, 8, cd, METAL_DARK)
    edgeOutline(cx, cz, cw, cd, gy + h + 8, { Color = pick(CROWN_COLORS), Material = Enum.Material.Neon })
    edgeOutline(cx, cz, w, d, gy + h, { Color = pick(CROWN_COLORS), Material = Enum.Material.Neon })
    if h > 180 and rand(0, 1) < 0.35 then
        helipad(cx, cz, gy + h + 8, math.min(cw, cd) - 2)
    elseif h > 140 then
        antenna(cx, cz, gy + h + 8, h * 0.15)
    else
        rooftopUnits(cx, cz, cw, cd, gy + h + 8)
    end
    litWindows(cx, cz, w, d, gy, 12, h - 4, 10 + math.floor(h / 20))
end

local function stoneTower(cx, cz, w, d, h, gy)
    local stone = { Color = pick(STONE_COLORS), Material = Enum.Material.Limestone, CanCollide = true }
    local shaft, s1, s2 = h * 0.75, h * 0.15, h * 0.1
    B(cx, gy + 7, cz, w + 6, 14, d + 6, stone)
    B(cx, gy + 14.3, cz, w + 7, 0.6, d + 7, { Color = Color3.fromRGB(120, 112, 100), Material = Enum.Material.Limestone })
    B(cx, gy + 3, cz, w + 6.3, 5, d + 6.3, LOBBY_GLASS)
    B(cx, gy + shaft / 2, cz, w, shaft, d, stone)
    verticalStrips(cx, cz, w, d, gy, 16, shaft - 4, 7, 2.4, 0.05, DARK_GLASS)
    B(cx, gy + shaft + 0.25, cz, w + 0.4, 0.5, d + 0.4, NEON_GOLD)
    B(cx, gy + shaft + s1 / 2, cz, w * 0.72, s1, d * 0.72, stone)
    B(cx, gy + shaft + s1 + 0.25, cz, w * 0.72 + 0.4, 0.5, d * 0.72 + 0.4, NEON_GOLD)
    B(cx, gy + shaft + s1 + s2 / 2, cz, w * 0.45, s2, d * 0.45, stone)
    local top = gy + h
    cylUp(V(cx, top + h * 0.04, cz), h * 0.08, 1.2, { Color = Color3.fromRGB(212, 175, 55), Material = Enum.Material.Metal, Reflectance = 0.3 })
    aviationLight(V(cx, top + h * 0.08 + 0.6, cz))
    litWindows(cx, cz, w, d, gy, 18, shaft - 4, 8 + math.floor(h / 25))
end

local function apartmentTower(cx, cz, w, d, h, gy)
    B(cx, gy + h / 2, cz, w, h, d, { Color = Color3.fromRGB(25, 35, 45), Material = Enum.Material.Glass, Reflectance = 0.2, CanCollide = true })
    lobby(cx, cz, w, d, gy)
    local floors = math.min(28, math.floor((h - 10) / 10))
    for k = 1, floors do
        B(cx, gy + 10 + k * 10 - 5, cz, w + 1.6, 0.7, d + 1.6, WHITE_CONCRETE)
    end
    for _, sx in ipairs({ -1, 1 }) do
        for _, sz in ipairs({ -1, 1 }) do
            B(cx + sx * w / 2, gy + h / 2, cz + sz * d / 2, 1.8, h, 1.8, WHITE_CONCRETE)
        end
    end
    B(cx, gy + h + 1, cz, w + 1.6, 2, d + 1.6, WHITE_CONCRETE)
    if rand(0, 1) < 0.5 then
        waterTower(cx + w * 0.2, cz - d * 0.2, gy + h)
    else
        rooftopUnits(cx, cz, w, d, gy + h)
    end
    if h > 140 then
        aviationLight(V(cx - w / 2 + 1, gy + h + 2.6, cz - d / 2 + 1))
    end
    litWindows(cx, cz, w, d, gy, 12, h - 4, 14 + math.floor(h / 15))
end

local function officeBuilding(cx, cz, w, d, h, gy)
    B(cx, gy + h / 2, cz, w, h, d, { Color = pick(CONCRETE_COLORS), Material = Enum.Material.Concrete, CanCollide = true })
    lobby(cx, cz, w, d, gy)
    local ribbons = math.min(30, math.floor((h - 12) / 7))
    for k = 0, ribbons - 1 do
        B(cx, gy + 12 + k * 7, cz, w + 0.3, 3.2, d + 0.3, DARK_GLASS)
    end
    B(cx, gy + h + 1, cz, w + 0.6, 2, d + 0.6, { Color = Color3.fromRGB(90, 90, 95), Material = Enum.Material.Concrete })
    rooftopUnits(cx, cz, w, d, gy + h)
    if h > 140 then
        antenna(cx + w * 0.25, cz + d * 0.25, gy + h + 2, 18)
    end
    litWindows(cx, cz, w, d, gy, 12, h - 4, 10 + math.floor(h / 20))
end

local function building(cx, cz, w, d, h, gy)
    local r = rand(0, 1)
    if h > 170 then
        if r < 0.6 then glassTower(cx, cz, w, d, h, gy) else stoneTower(cx, cz, w, d, h, gy) end
    elseif r < 0.3 then
        glassTower(cx, cz, w, d, h, gy)
    elseif r < 0.5 then
        stoneTower(cx, cz, w, d, h, gy)
    elseif r < 0.75 then
        apartmentTower(cx, cz, w, d, h, gy)
    else
        officeBuilding(cx, cz, w, d, h, gy)
    end
end

----------------------------------------------------------------
-- City blocks
----------------------------------------------------------------
local function streetTree(x, z, y)
    B(x, y + 0.05, z, 3.5, 0.1, 3.5, { Color = Color3.fromRGB(70, 50, 32), Material = Enum.Material.Ground })
    B(x, y + 3, z, 0.6, 6, 0.6, BARK)
    ball(V(x, y + 7, z), 5, { Color = Color3.fromRGB(50, 95, 42), Material = Enum.Material.LeafyGrass })
    ball(V(x + 0.8, y + 8.2, z - 0.5), 3.6, { Color = Color3.fromRGB(65, 115, 50), Material = Enum.Material.LeafyGrass })
end

local function heightFor(cx, cz)
    local f = math.clamp((V(cx, 0, cz) - V(casinoCenter.X, 0, casinoCenter.Z)).Magnitude / maxDistance, 0, 1)
    return math.clamp(MIN_HEIGHT + (MAX_HEIGHT - MIN_HEIGHT) * f ^ 0.9 * rand(0.55, 1.15), MIN_HEIGHT * 0.8, MAX_HEIGHT * 1.1)
end

local SW = 6
local function buildBlock(x0, z0, size, gy)
    current = Instance.new("Model")
    current.Name = "CityBlock"
    current.Parent = folder

    B(x0 + size / 2, gy + 0.3, z0 + size / 2, size, 0.6, size, SIDEWALK)
    local top = gy + 0.6
    local inner = size - 2 * SW
    local ix, iz = x0 + SW, z0 + SW
    local cx, cz = x0 + size / 2, z0 + size / 2
    local h = heightFor(cx, cz)
    local r = rand(0, 1)

    if r < 0.35 then
        local w, d = inner * rand(0.5, 0.75), inner * rand(0.5, 0.75)
        building(cx, cz, w, d, h * 1.1, top)
        for _, sx in ipairs({ -1, 1 }) do
            for _, sz in ipairs({ -1, 1 }) do
                streetTree(cx + sx * (inner / 2 - 4), cz + sz * (inner / 2 - 4), top)
            end
        end
    elseif r < 0.7 then
        local half = (inner - 8) / 2
        for _, side in ipairs({ -1, 1 }) do
            local w, d = half * rand(0.75, 0.95), inner * rand(0.55, 0.85)
            building(ix + inner / 2 + side * (half / 2 + 4), cz + rand(-0.1, 0.1) * inner, w, d, h * rand(0.75, 1.05), top)
        end
    else
        local q = (inner - 8) / 2
        for _, sx in ipairs({ -1, 1 }) do
            for _, sz in ipairs({ -1, 1 }) do
                local w, d = q * rand(0.7, 0.95), q * rand(0.7, 0.95)
                building(ix + inner / 2 + sx * (q / 2 + 4), iz + inner / 2 + sz * (q / 2 + 4), w, d, h * rand(0.4, 0.65), top)
            end
        end
    end

    -- Trees along the sidewalk
    streetTree(cx, z0 + SW / 2, top)
    streetTree(cx, z0 + size - SW / 2, top)
    streetTree(x0 + SW / 2, cz, top)
    streetTree(x0 + size - SW / 2, cz, top)
    current = folder
end

----------------------------------------------------------------
-- Lay out the grid
----------------------------------------------------------------
local sizeX, sizeZ = mapMax.X - mapMin.X, mapMax.Z - mapMin.Z
local pitch = math.max(110, math.sqrt(sizeX * sizeZ / MAX_BLOCKS))
local blockSize = pitch - STREET_WIDTH
local nx = math.max(0, math.floor((sizeX - STREET_WIDTH) / pitch))
local nz = math.max(0, math.floor((sizeZ - STREET_WIDTH) / pitch))
local startX = mapMin.X + (sizeX - (nx * pitch + STREET_WIDTH)) / 2 + STREET_WIDTH
local startZ = mapMin.Z + (sizeZ - (nz * pitch + STREET_WIDTH)) / 2 + STREET_WIDTH

local built = {}
local function key(i, j)
    return i .. "," .. j
end

local function blockGround(x0, z0)
    local ok, gy = true, nil
    for _, fx in ipairs({ 0.05, 0.5, 0.95 }) do
        for _, fz in ipairs({ 0.05, 0.5, 0.95 }) do
            local y = groundAt(x0 + blockSize * fx, z0 + blockSize * fz)
            if not y or (gy and math.abs(y - gy) > 0.5) then
                ok = false
            end
            gy = gy or y
        end
    end
    if ok then
        return gy
    end
    return nil
end

-- [REX] dry run: report the layout and build nothing
if DRY_RUN then
    local would, blockedKeep, blockedGround = 0, 0, 0
    for i = 0, nx - 1 do
        for j = 0, nz - 1 do
            local x0, z0 = startX + i * pitch, startZ + j * pitch
            if blockedByKeep(x0 - STREET_WIDTH, z0 - STREET_WIDTH, x0 + blockSize + STREET_WIDTH, z0 + blockSize + STREET_WIDTH) then
                blockedKeep = blockedKeep + 1
            elseif blockGround(x0, z0) then
                would = would + 1
            else
                blockedGround = blockedGround + 1
            end
        end
    end
    print(string.format("[City] DRY RUN map %.0f x %.0f, pitch %.1f, block %.1f, grid %dx%d = %d candidates",
        sizeX, sizeZ, pitch, blockSize, nx, nz, nx * nz))
    print(string.format("[City] DRY RUN %d would build, %d blocked by keep-out, %d no clear ground",
        would, blockedKeep, blockedGround))
    print(string.format("[City] DRY RUN %d keep boxes, centre %.0f, %.0f, maxDistance %.0f",
        #keepBoxes, casinoCenter.X, casinoCenter.Z, maxDistance))
    return
end

folder.Parent = workspace

local count = 0
for i = 0, nx - 1 do
    for j = 0, nz - 1 do
        local x0, z0 = startX + i * pitch, startZ + j * pitch
        if not blockedByKeep(x0 - STREET_WIDTH, z0 - STREET_WIDTH, x0 + blockSize + STREET_WIDTH, z0 + blockSize + STREET_WIDTH) then
            -- Check the ground is flat and empty across the whole block
            local gy = blockGround(x0, z0)
            if gy then
                built[key(i, j)] = gy
                buildBlock(x0, z0, blockSize, gy)
                count = count + 1
                -- [REX] no task.wait() here: execute_luau returns the moment the
                -- script yields, so the build reported done while half-built.
            end
        end
    end
end

----------------------------------------------------------------
-- Streets, intersections and street lights
----------------------------------------------------------------
current = Instance.new("Model")
current.Name = "Streets"
current.Parent = folder

local function roadY(...)
    for _, k in ipairs({ ... }) do
        if built[k] then
            return built[k]
        end
    end
    return nil
end

for i = 0, nx do
    for j = 0, nz - 1 do
        local gy = roadY(key(i - 1, j), key(i, j))
        if gy then
            local x = startX + i * pitch - STREET_WIDTH / 2
            local z = startZ + j * pitch + blockSize / 2
            B(x, gy + 0.05, z, STREET_WIDTH, 0.1, blockSize, ASPHALT)
            B(x - 0.35, gy + 0.11, z, 0.3, 0.02, blockSize, YELLOW_LINE)
            B(x + 0.35, gy + 0.11, z, 0.3, 0.02, blockSize, YELLOW_LINE)
        end
    end
end
for j = 0, nz do
    for i = 0, nx - 1 do
        local gy = roadY(key(i, j - 1), key(i, j))
        if gy then
            local x = startX + i * pitch + blockSize / 2
            local z = startZ + j * pitch - STREET_WIDTH / 2
            B(x, gy + 0.05, z, blockSize, 0.1, STREET_WIDTH, ASPHALT)
            B(x, gy + 0.11, z - 0.35, blockSize, 0.02, 0.3, YELLOW_LINE)
            B(x, gy + 0.11, z + 0.35, blockSize, 0.02, 0.3, YELLOW_LINE)
        end
    end
end

for i = 0, nx do
    for j = 0, nz do
        local gy = roadY(key(i - 1, j - 1), key(i, j - 1), key(i - 1, j), key(i, j))
        if gy then
            local x = startX + i * pitch - STREET_WIDTH / 2
            local z = startZ + j * pitch - STREET_WIDTH / 2
            B(x, gy + 0.05, z, STREET_WIDTH, 0.1, STREET_WIDTH, ASPHALT)
            -- Stop lines on the sides that have a block next to them
            if built[key(i, j)] or built[key(i - 1, j)] then
                B(x, gy + 0.11, z + STREET_WIDTH / 2 - 1, STREET_WIDTH - 2, 0.02, 0.8, WHITE_LINE)
            end
            if built[key(i, j - 1)] or built[key(i - 1, j - 1)] then
                B(x, gy + 0.11, z - STREET_WIDTH / 2 + 1, STREET_WIDTH - 2, 0.02, 0.8, WHITE_LINE)
            end
            -- Street light on the corner of the block
            if STREET_LIGHTS and built[key(i, j)] then
                local lx, lz = x + STREET_WIDTH / 2 + 2, z + STREET_WIDTH / 2 + 2
                local base = built[key(i, j)] + 0.6
                cylUp(V(lx, base + 8, lz), 16, 0.5, POLE)
                B(lx - 2.5, base + 15.8, lz - 2.5, 5.5, 0.3, 0.3, POLE)
                local head = B(lx - 5, base + 15.6, lz - 5, 2.2, 0.5, 1.2, POLE)
                B(lx - 5, base + 15.32, lz - 5, 1.8, 0.06, 0.9, LAMP)
                local spot = Instance.new("SpotLight")
                spot.Face = Enum.NormalId.Bottom
                spot.Color = Color3.fromRGB(255, 220, 170)
                spot.Brightness = 2.5
                spot.Range = 40
                spot.Angle = 110
                spot.Parent = head
            end
        end
    end
end
current = folder

----------------------------------------------------------------
-- Blinking red lights on the tall towers
----------------------------------------------------------------
-- [REX] a child Script, so the loop does not spin inside Studio. Held by the
-- builder it never stops and keeps the place file dirty.
if #blinkers > 0 then
    local animator = Instance.new("Script")
    animator.Name = "CityAnimator"
    animator.Source = [[
-- Blinking aviation lights on the tall towers.
local folder = script.Parent
local RED = Color3.fromRGB(255, 30, 30)
local DIM = Color3.fromRGB(50, 15, 15)

local blinkers = {}
for _, d in ipairs(folder:GetDescendants()) do
	if d:IsA("BasePart") and d.Name == "BlinkerRed" then
		table.insert(blinkers, d)
	end
end

task.spawn(function()
	local on = true
	while folder.Parent do
		on = not on
		for _, b in ipairs(blinkers) do
			b.Material = on and Enum.Material.Neon or Enum.Material.SmoothPlastic
			b.Color = on and RED or DIM
		end
		task.wait(1)
	end
end)
]]
    animator.Parent = folder
end

local parts = 0
for _, d in ipairs(folder:GetDescendants()) do
    if d:IsA("BasePart") then
        parts = parts + 1
    end
end
print(string.format("[City] Built %d city blocks (map is %d x %d studs)", count, sizeX, sizeZ))
print(string.format("[City] %d parts, %d towers with aviation lights, pitch %.1f, block %.1f",
    parts, #blinkers, pitch, blockSize))

return folder
