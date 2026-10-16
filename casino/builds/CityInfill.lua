-- CITY INFILL -- low-rise downtown that presses right up to the casino
--
-- Why this exists: CitySkyline lays its towers on a 189.7-stud grid, so it can
-- only ever build on whole grid cells. That left the casino sitting in a bare
-- concrete ring roughly 255 studs wide east and west and 195 studs deep to the
-- north -- shrinking CASINO_GAP from 40 to 0 only moved 38 blocks to 42,
-- because the cells themselves cannot reach in any closer.
--
-- This fills that ring on a much finer grid with 2-8 storey buildings: shop
-- rows with awnings and lit shopfronts, small offices, and open parking decks.
-- Heights are capped well under the towers so the skyline still steps up as it
-- goes out, and the casino reads as the big building downtown rather than a
-- monument alone in a field.
--
-- A cell is only built where a box query proves the ground is genuinely empty,
-- so this can never collide with the casino, the trees, the lot or the towers.
-- Run it as many times as you like; it clears its own previous output first.

local PITCH = 72             -- centre-to-centre spacing of the small blocks
local STREET = 18            -- width of the little streets between them
local MARGIN = 8             -- clearance kept from anything that already exists
local MIN_HEIGHT = 18        -- shortest low-rise
local MAX_HEIGHT = 68        -- tallest low-rise (towers start around 90)
local PART_BUDGET = 8500     -- stop building if the part count passes this
local STREET_LIGHTS = true
local SEED = 77
-- Only fill the ring around the casino. Without this the empty-ground test
-- also passes way out at the map edges, and the low-rise carpets the whole
-- map instead of just the bare moat the towers could not reach.
local MAX_DIST = 620
local DRY_RUN = false     -- count the cells and build nothing

local BLOCK = PITCH - STREET

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

-- Clear the previous run before anything is measured, so the scan below never
-- sees our own output and refuses to build on top of it.
local old = workspace:FindFirstChild("CityInfill")
if old then
    old:Destroy()
end

local folder = Instance.new("Folder")
folder.Name = "CityInfill"

----------------------------------------------------------------
-- Ground
----------------------------------------------------------------
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
    error("[Infill] Could not find the ground: it needs to be a big flat anchored part.")
end
local GY = ground.Position.Y + ground.Size.Y / 2
local minX = ground.Position.X - ground.Size.X / 2
local maxX = ground.Position.X + ground.Size.X / 2
local minZ = ground.Position.Z - ground.Size.Z / 2
local maxZ = ground.Position.Z + ground.Size.Z / 2

-- Parts with CanQuery off are invisible to both Raycast and GetPartBoundsInBox,
-- so an occupancy scan would walk straight through them. Turn them on for the
-- scan and put them back afterwards.
local requery = {}
for _, d in ipairs(workspace:GetDescendants()) do
    if d:IsA("BasePart") and not d.CanQuery then
        d.CanQuery = true
        table.insert(requery, d)
    end
end
local function restoreCanQuery()
    for _, d in ipairs(requery) do
        d.CanQuery = false
    end
end

local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Exclude
overlap.FilterDescendantsInstances = { ground, folder }
overlap.MaxParts = 1

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.FilterDescendantsInstances = { folder }

-- A cell is usable only if every probe lands on the ground part and the whole
-- volume above it is empty.
local function cellIsFree(cx, cz)
    local half = BLOCK / 2 + MARGIN
    if cx - half < minX or cx + half > maxX or cz - half < minZ or cz + half > maxZ then
        return false
    end
    for _, fx in ipairs({ -1, 0, 1 }) do
        for _, fz in ipairs({ -1, 0, 1 }) do
            local px = cx + fx * (BLOCK / 2 - 2)
            local pz = cz + fz * (BLOCK / 2 - 2)
            local hit = workspace:Raycast(V(px, GY + 700, pz), V(0, -2000, 0), rayParams)
            if not hit or hit.Instance ~= ground then
                return false
            end
        end
    end
    local box = CFrame.new(cx, GY + 150, cz)
    local size = V(BLOCK + MARGIN * 2, 300, BLOCK + MARGIN * 2)
    local found = workspace:GetPartBoundsInBox(box, size, overlap)
    return #found == 0
end

----------------------------------------------------------------
-- Materials
----------------------------------------------------------------
local BRICK_COLORS = {
    Color3.fromRGB(135, 75, 60), Color3.fromRGB(115, 68, 55), Color3.fromRGB(150, 95, 72),
    Color3.fromRGB(96, 62, 54), Color3.fromRGB(160, 120, 95),
}
local STUCCO_COLORS = {
    Color3.fromRGB(205, 195, 175), Color3.fromRGB(185, 178, 165), Color3.fromRGB(215, 205, 190),
    Color3.fromRGB(165, 160, 150),
}
local AWNING_COLORS = {
    Color3.fromRGB(150, 40, 45), Color3.fromRGB(35, 70, 125), Color3.fromRGB(40, 100, 70),
    Color3.fromRGB(190, 145, 45), Color3.fromRGB(70, 50, 95),
}
local SIGN_COLORS = {
    Color3.fromRGB(255, 120, 60), Color3.fromRGB(120, 220, 255), Color3.fromRGB(255, 90, 160),
    Color3.fromRGB(150, 255, 150), Color3.fromRGB(255, 220, 120),
}

local CONCRETE = { Color = Color3.fromRGB(150, 148, 145), Material = Enum.Material.Concrete, CanCollide = true }
local DARK_CONCRETE = { Color = Color3.fromRGB(95, 95, 98), Material = Enum.Material.Concrete }
local SHOP_GLASS = { Color = Color3.fromRGB(30, 38, 46), Material = Enum.Material.Glass, Transparency = 0.25, Reflectance = 0.2 }
local SHOP_GLOW = { Color = Color3.fromRGB(255, 225, 170), Material = Enum.Material.Neon, Transparency = 0.45 }
local WINDOW = { Color = Color3.fromRGB(28, 34, 42), Material = Enum.Material.Glass, Reflectance = 0.25 }
local TRIM = { Color = Color3.fromRGB(225, 220, 210), Material = Enum.Material.Concrete }
local METAL = { Color = Color3.fromRGB(150, 152, 155), Material = Enum.Material.Metal }
local DARK_METAL = { Color = Color3.fromRGB(58, 60, 64), Material = Enum.Material.Metal, CanCollide = true }
local SIDEWALK = { Color = Color3.fromRGB(162, 160, 154), Material = Enum.Material.Concrete, CanCollide = true }
local ASPHALT = { Color = Color3.fromRGB(34, 34, 37), Material = Enum.Material.Asphalt, CanCollide = true }
local WHITE_LINE = { Color = Color3.fromRGB(232, 232, 226), Material = Enum.Material.SmoothPlastic }
local YELLOW_LINE = { Color = Color3.fromRGB(230, 190, 40), Material = Enum.Material.SmoothPlastic }
local POLE = { Color = Color3.fromRGB(42, 44, 47), Material = Enum.Material.Metal, CanCollide = true }
local LAMP = { Color = Color3.fromRGB(255, 228, 175), Material = Enum.Material.Neon }
local BARK = { Color = Color3.fromRGB(85, 60, 40), Material = Enum.Material.Wood, CanCollide = true }
local LEAF = { Color = Color3.fromRGB(52, 98, 44), Material = Enum.Material.LeafyGrass }
local TANK_WOOD = { Color = Color3.fromRGB(110, 80, 55), Material = Enum.Material.WoodPlanks }

----------------------------------------------------------------
-- Part helpers
----------------------------------------------------------------
local current = folder
local made = 0
local function makePart(props)
    local p = Instance.new("Part")
    p.Anchored = true
    p.CanCollide = false
    p.CanTouch = false
    p.CastShadow = false -- low-rise detail; the perf pass would clear these anyway
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    for key, value in pairs(props) do
        p[key] = value
    end
    p.Parent = current
    made = made + 1
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
local function box(cf, size, style)
    return styled({ Size = size, CFrame = cf }, style)
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

-- The four sides of a footprint, as an outward normal plus a sideways axis.
local function sides(w, d)
    return {
        { n = V(0, 0, -1), along = V(1, 0, 0), half = d / 2, width = w },
        { n = V(0, 0, 1), along = V(1, 0, 0), half = d / 2, width = w },
        { n = V(-1, 0, 0), along = V(0, 0, 1), half = w / 2, width = d },
        { n = V(1, 0, 0), along = V(0, 0, 1), half = w / 2, width = d },
    }
end
local function faceBox(centre, side, offset, out, y, width, height, depth, style)
    local pos = centre + side.n * (side.half + out) + side.along * offset + V(0, y, 0)
    local size = side.along.X ~= 0 and V(width, height, depth) or V(depth, height, width)
    return styled({ Size = size, CFrame = CFrame.new(pos) }, style)
end

----------------------------------------------------------------
-- Shared bits of building
----------------------------------------------------------------
local function rooftopClutter(cx, cz, w, d, y)
    for _ = 1, rng:NextInteger(1, 3) do
        local sx, sz = rand(3, 7), rand(3, 7)
        B(cx + rand(-0.4, 0.4) * math.max(w - sx - 3, 0), y + 1.2,
            cz + rand(-0.4, 0.4) * math.max(d - sz - 3, 0), sx, 2.4, sz, METAL)
    end
    -- a stair bulkhead, so the roof is not just boxes
    B(cx + rand(-0.3, 0.3) * w, y + 1.8, cz + rand(-0.3, 0.3) * d, 5, 3.6, 4, DARK_CONCRETE)
end

local function waterTower(x, z, y)
    for _, lx in ipairs({ -1.6, 1.6 }) do
        for _, lz in ipairs({ -1.6, 1.6 }) do
            B(x + lx, y + 1.8, z + lz, 0.35, 3.6, 0.35, DARK_METAL)
        end
    end
    cylUp(V(x, y + 5.6, z), 4.2, 5, TANK_WOOD)
    local roof = B(x, y + 8.3, z, 5.4, 2, 5.4, TANK_WOOD)
    local mesh = Instance.new("SpecialMesh")
    mesh.MeshType = Enum.MeshType.Sphere
    mesh.Parent = roof
end

-- Ground-floor shopfronts and awnings, all the way round the footprint.
local function shopfronts(cx, cz, w, d, gy)
    local centre = V(cx, 0, cz)
    for _, side in ipairs(sides(w, d)) do
        local bays = math.max(1, math.floor(side.width / 9))
        local bayWidth = side.width / bays
        for k = 0, bays - 1 do
            local offset = -side.width / 2 + (k + 0.5) * bayWidth
            -- recessed glass with a warm glow behind it
            faceBox(centre, side, offset, 0.04, gy + 3.1, bayWidth - 1.6, 5, 0.12, SHOP_GLOW)
            faceBox(centre, side, offset, 0.14, gy + 3.1, bayWidth - 1.2, 5.4, 0.1, SHOP_GLASS)
            -- awning, angled down and out
            if rand(0, 1) < 0.72 then
                local colour = pick(AWNING_COLORS)
                local pos = centre + side.n * (side.half + 1.5) + side.along * offset + V(0, gy + 6.4, 0)
                local tilt = CFrame.lookAt(pos, pos + side.n) * CFrame.Angles(math.rad(28), 0, 0)
                box(tilt, V(bayWidth - 1, 0.18, 3.4), { Color = colour, Material = Enum.Material.Fabric })
            end
            -- a lit sign over about a third of the bays
            if rand(0, 1) < 0.34 then
                faceBox(centre, side, offset, 0.5, gy + 7.6, bayWidth - 3, 1.4, 0.3,
                    { Color = pick(SIGN_COLORS), Material = Enum.Material.Neon })
            end
        end
        -- a continuous sill above the shopfronts
        faceBox(centre, side, 0, 0.3, gy + 6.1, side.width + 0.6, 0.5, 0.7, TRIM)
    end
end

-- Punched windows on the upper floors.
local function upperWindows(cx, cz, w, d, gy, firstFloor, floors)
    local centre = V(cx, 0, cz)
    for _, side in ipairs(sides(w, d)) do
        local bays = math.max(1, math.min(7, math.floor(side.width / 7)))
        local bayWidth = side.width / bays
        for f = 0, floors - 1 do
            local y = gy + firstFloor + f * 7
            for k = 0, bays - 1 do
                local offset = -side.width / 2 + (k + 0.5) * bayWidth
                local lit = rand(0, 1) < 0.3
                faceBox(centre, side, offset, 0.06, y, math.min(3.4, bayWidth - 2), 3.4, 0.1,
                    lit and { Color = Color3.fromRGB(255, 212, 150), Material = Enum.Material.Neon, Transparency = 0.2 }
                        or WINDOW)
            end
        end
    end
end

----------------------------------------------------------------
-- Low-rise styles
----------------------------------------------------------------
local function shopRow(cx, cz, w, d, h, gy)
    local wall = { Color = pick(BRICK_COLORS), Material = Enum.Material.Brick, CanCollide = true }
    B(cx, gy + h / 2, cz, w, h, d, wall)
    B(cx, gy + 0.6, cz, w + 0.8, 1.2, d + 0.8, DARK_CONCRETE)
    shopfronts(cx, cz, w, d, gy)
    local floors = math.max(1, math.floor((h - 10) / 7))
    upperWindows(cx, cz, w, d, gy, 11, floors)
    -- cornice
    B(cx, gy + h + 0.4, cz, w + 1.4, 0.8, d + 1.4, TRIM)
    B(cx, gy + h + 1, cz, w + 0.8, 0.5, d + 0.8, wall)
    if rand(0, 1) < 0.45 then
        waterTower(cx + rand(-0.25, 0.25) * w, cz + rand(-0.25, 0.25) * d, gy + h + 1.2)
    else
        rooftopClutter(cx, cz, w, d, gy + h + 1.2)
    end
end

local function smallOffice(cx, cz, w, d, h, gy)
    local wall = { Color = pick(STUCCO_COLORS), Material = Enum.Material.Concrete, CanCollide = true }
    B(cx, gy + h / 2, cz, w, h, d, wall)
    shopfronts(cx, cz, w, d, gy)
    -- ribbon windows rather than punched ones
    local centre = V(cx, 0, cz)
    local ribbons = math.max(1, math.floor((h - 10) / 6))
    for f = 0, ribbons - 1 do
        local y = gy + 11 + f * 6
        for _, side in ipairs(sides(w, d)) do
            faceBox(centre, side, 0, 0.08, y, side.width - 3, 3, 0.12, WINDOW)
            faceBox(centre, side, 0, 0.2, y - 2.1, side.width - 2, 0.6, 0.3, TRIM)
        end
    end
    B(cx, gy + h + 0.5, cz, w + 1, 1, d + 1, TRIM)
    rooftopClutter(cx, cz, w, d, gy + h + 1)
end

local function parkingDeck(cx, cz, w, d, h, gy)
    local decks = math.max(2, math.floor(h / 10))
    -- corner and mid columns
    for _, sx in ipairs({ -1, 0, 1 }) do
        for _, sz in ipairs({ -1, 0, 1 }) do
            B(cx + sx * (w / 2 - 1.5), gy + h / 2, cz + sz * (d / 2 - 1.5), 1.8, h, 1.8, CONCRETE)
        end
    end
    for k = 0, decks do
        local y = gy + k * (h / decks)
        B(cx, y + 0.4, cz, w, 0.8, d, CONCRETE)
        -- spandrel band round the edge, so you see floors not a solid box
        local centre = V(cx, 0, cz)
        for _, side in ipairs(sides(w, d)) do
            faceBox(centre, side, 0, 0.1, y + 1.9, side.width + 0.4, 2.2, 0.5, DARK_CONCRETE)
        end
        -- parked cars, just blocks of colour at this distance
        if k < decks then
            for _ = 1, rng:NextInteger(2, 5) do
                local carColour = Color3.fromRGB(rng:NextInteger(40, 210), rng:NextInteger(40, 210), rng:NextInteger(40, 210))
                B(cx + rand(-0.38, 0.38) * w, y + 1.6, cz + rand(-0.38, 0.38) * d, 5, 1.6, 2.4,
                    { Color = carColour, Material = Enum.Material.SmoothPlastic })
            end
        end
    end
    -- stair and lift core
    B(cx + w / 2 - 4, gy + h / 2 + 2, cz - d / 2 + 4, 7, h + 4, 7, CONCRETE)
    -- PARKING sign
    local centre = V(cx, 0, cz)
    faceBox(centre, sides(w, d)[1], 0, 0.4, gy + h * 0.5, 3, 10, 0.4,
        { Color = Color3.fromRGB(90, 200, 255), Material = Enum.Material.Neon })
end

local function lowRise(cx, cz, w, d, h, gy)
    local r = rand(0, 1)
    if r < 0.55 then
        shopRow(cx, cz, w, d, h, gy)
    elseif r < 0.85 then
        smallOffice(cx, cz, w, d, h, gy)
    else
        parkingDeck(cx, cz, w, d, math.max(24, h * 0.8), gy)
    end
end

----------------------------------------------------------------
-- Street furniture
----------------------------------------------------------------
local function streetTree(x, z, y)
    B(x, y + 0.06, z, 3, 0.12, 3, { Color = Color3.fromRGB(70, 50, 32), Material = Enum.Material.Ground })
    B(x, y + 2.6, z, 0.5, 5.2, 0.5, BARK)
    ball(V(x, y + 6, z), 4.2, LEAF)
    ball(V(x + 0.7, y + 7, z - 0.4), 3, { Color = Color3.fromRGB(66, 116, 50), Material = Enum.Material.LeafyGrass })
end

local function bench(x, z, y, alongX)
    local size = alongX and V(4.2, 0.25, 1.2) or V(1.2, 0.25, 4.2)
    B(x, y + 1.1, z, size.X, size.Y, size.Z, { Color = Color3.fromRGB(110, 78, 50), Material = Enum.Material.Wood })
    B(x, y + 0.5, z, size.X * 0.8, 0.9, size.Z * 0.8, DARK_METAL)
end

local function streetLight(x, z, y, dx, dz)
    cylUp(V(x, y + 7, z), 14, 0.45, POLE)
    B(x + dx * 1.2, y + 13.9, z + dz * 1.2, dx ~= 0 and 3 or 0.3, 0.28, dz ~= 0 and 3 or 0.3, POLE)
    local head = B(x + dx * 2.4, y + 13.7, z + dz * 2.4, 1.9, 0.45, 1.1, POLE)
    B(x + dx * 2.4, y + 13.45, z + dz * 2.4, 1.5, 0.06, 0.8, LAMP)
    local spot = Instance.new("SpotLight")
    spot.Face = Enum.NormalId.Bottom
    spot.Color = Color3.fromRGB(255, 224, 172)
    spot.Brightness = 2
    spot.Range = 34
    spot.Angle = 110
    spot.Shadows = false
    spot.Parent = head
end

----------------------------------------------------------------
-- Lay out the fine grid
----------------------------------------------------------------
-- Height grows with distance from the casino, but gently and capped low, so the
-- towers beyond still dominate.
local casinoCentre = V(0, 0, -130)
local casino = workspace:FindFirstChild("Casino")
if casino then
    local mn, mx = V(1e9, 1e9, 1e9), V(-1e9, -1e9, -1e9)
    for _, p in ipairs(casino:GetDescendants()) do
        if p:IsA("BasePart") and p ~= ground and math.max(p.Size.X, p.Size.Z) < 800 then
            mn = mn:Min(p.Position)
            mx = mx:Max(p.Position)
        end
    end
    casinoCentre = (mn + mx) / 2
end
local function heightAt(cx, cz)
    local dist = (V(cx, 0, cz) - V(casinoCentre.X, 0, casinoCentre.Z)).Magnitude
    local f = math.clamp((dist - 220) / 420, 0, 1)
    return math.clamp(MIN_HEIGHT + (MAX_HEIGHT - MIN_HEIGHT) * f * rand(0.65, 1.2), MIN_HEIGHT, MAX_HEIGHT)
end

local nx = math.floor((maxX - minX) / PITCH)
local nz = math.floor((maxZ - minZ) / PITCH)
local originX = minX + (maxX - minX - nx * PITCH) / 2 + PITCH / 2
local originZ = minZ + (maxZ - minZ - nz * PITCH) / 2 + PITCH / 2

local built = {}
local function cellKey(i, j)
    return i .. "," .. j
end

-- Work out which cells are usable before building anything, so the dry run can
-- report honestly and the budget is spent on the nearest cells first.
local candidates = {}
for i = 0, nx - 1 do
    for j = 0, nz - 1 do
        local cx = originX + i * PITCH
        local cz = originZ + j * PITCH
        local dist = (V(cx, 0, cz) - V(casinoCentre.X, 0, casinoCentre.Z)).Magnitude
        if dist <= MAX_DIST and cellIsFree(cx, cz) then
            table.insert(candidates, { i = i, j = j, cx = cx, cz = cz, dist = dist })
        end
    end
end
-- nearest first, so if the budget runs out it is the far cells that go missing
table.sort(candidates, function(a, b)
    return a.dist < b.dist
end)

if DRY_RUN then
    restoreCanQuery()
    local near, far = math.huge, 0
    for _, c in ipairs(candidates) do
        near = math.min(near, c.dist)
        far = math.max(far, c.dist)
    end
    print(string.format("[Infill] DRY RUN grid %dx%d at %d-stud pitch, %d cells usable of %d",
        nx, nz, PITCH, #candidates, nx * nz))
    print(string.format("[Infill] DRY RUN distance from casino %.0f..%.0f, centre %.0f,%.0f",
        near == math.huge and 0 or near, far, casinoCentre.X, casinoCentre.Z))
    return
end

local blocks, overBudget = 0, false
for _, cell in ipairs(candidates) do
    do
        do
            local cx, cz = cell.cx, cell.cz
            if made < PART_BUDGET then
                current = Instance.new("Model")
                current.Name = "InfillBlock"
                current.Parent = folder

                B(cx, GY + 0.3, cz, BLOCK, 0.6, BLOCK, SIDEWALK)
                local top = GY + 0.6
                local inner = BLOCK - 10
                local h = heightAt(cx, cz)
                local r = rand(0, 1)

                if r < 0.4 then
                    -- one building filling the block
                    lowRise(cx, cz, inner * rand(0.72, 0.9), inner * rand(0.72, 0.9), h, top)
                elseif r < 0.75 then
                    -- two, split along the long axis
                    local halfW = (inner - 6) / 2
                    for _, side in ipairs({ -1, 1 }) do
                        lowRise(cx + side * (halfW / 2 + 3), cz,
                            halfW * rand(0.8, 0.96), inner * rand(0.7, 0.92), h * rand(0.8, 1.1), top)
                    end
                else
                    -- four small ones round a service yard
                    local q = (inner - 6) / 2
                    for _, sx in ipairs({ -1, 1 }) do
                        for _, sz in ipairs({ -1, 1 }) do
                            lowRise(cx + sx * (q / 2 + 3), cz + sz * (q / 2 + 3),
                                q * rand(0.74, 0.92), q * rand(0.74, 0.92), h * rand(0.55, 0.85), top)
                        end
                    end
                end

                -- sidewalk furniture on two sides, kept cheap
                streetTree(cx - BLOCK / 2 + 4, cz - BLOCK / 2 + 4, top)
                streetTree(cx + BLOCK / 2 - 4, cz + BLOCK / 2 - 4, top)
                if rand(0, 1) < 0.5 then
                    bench(cx, cz - BLOCK / 2 + 3, top, true)
                end

                current = folder
                built[cellKey(cell.i, cell.j)] = true
                blocks = blocks + 1
            else
                overBudget = true
            end
        end
    end
end

----------------------------------------------------------------
-- Streets between the new blocks, and crossings
----------------------------------------------------------------
current = Instance.new("Model")
current.Name = "InfillStreets"
current.Parent = folder

-- [REX] Work out which corridors exist BEFORE drawing, so an intersection can
-- be laid wherever one terminates. The original only squared off a corner when
-- a block had both an east and a south neighbour, which with scattered blocks
-- almost never happens: corridors ended in mid-air and the road network was a
-- pile of disconnected stubs. That is invisible until something tries to drive
-- on it - CityDataPublisher found 8 usable edges out of 149.
local ns, ew = {}, {}   -- ns[i,j]: street between column i and i+1, at row j
local roads = 0
for i = 0, nx - 1 do
    for j = 0, nz - 1 do
        if built[cellKey(i, j)] then
            if built[cellKey(i + 1, j)] then
                ns[cellKey(i, j)] = true
            end
            if built[cellKey(i, j + 1)] then
                ew[cellKey(i, j)] = true
            end
        end
    end
end

for i = 0, nx - 1 do
    for j = 0, nz - 1 do
        local cx = originX + i * PITCH
        local cz = originZ + j * PITCH
        if ns[cellKey(i, j)] then
            local x = cx + PITCH / 2
            B(x, GY + 0.05, cz, STREET, 0.1, BLOCK, ASPHALT)
            B(x, GY + 0.11, cz, 0.3, 0.02, BLOCK * 0.8, YELLOW_LINE)
            roads = roads + 1
        end
        if ew[cellKey(i, j)] then
            local z = cz + PITCH / 2
            B(cx, GY + 0.05, z, BLOCK, 0.1, STREET, ASPHALT)
            B(cx, GY + 0.11, z, BLOCK * 0.8, 0.02, 0.3, YELLOW_LINE)
            roads = roads + 1
        end
    end
end

-- The square where corridors meet. Laid if ANY of the four that touch it
-- exists, so every corridor ends on tarmac instead of stopping dead.
local crossings = 0
for i = -1, nx - 1 do
    for j = -1, nz - 1 do
        if ns[cellKey(i, j)] or ns[cellKey(i, j + 1)]
            or ew[cellKey(i, j)] or ew[cellKey(i + 1, j)] then
            local x = originX + i * PITCH + PITCH / 2
            local z = originZ + j * PITCH + PITCH / 2
            B(x, GY + 0.05, z, STREET, 0.1, STREET, ASPHALT)
            crossings = crossings + 1
            -- zebra crossings only where two streets actually cross
            if (ns[cellKey(i, j)] or ns[cellKey(i, j + 1)])
                and (ew[cellKey(i, j)] or ew[cellKey(i + 1, j)]) then
                for k = -2, 2 do
                    B(x + k * 3.2, GY + 0.12, z - STREET / 2 - 2, 1.6, 0.02, 7, WHITE_LINE)
                    B(x - STREET / 2 - 2, GY + 0.12, z + k * 3.2, 7, 0.02, 1.6, WHITE_LINE)
                end
                if STREET_LIGHTS then
                    streetLight(x + STREET / 2 + 1.5, z + STREET / 2 + 1.5, GY + 0.6, -1, 0)
                end
            end
        end
    end
end
current = folder

restoreCanQuery()
folder.Parent = workspace

local parts = 0
for _, d in ipairs(folder:GetDescendants()) do
    if d:IsA("BasePart") then
        parts = parts + 1
    end
end
print(string.format("[Infill] %d low-rise blocks, %d streets, %d crossings, %d parts%s",
    blocks, roads, crossings, parts, overBudget and " (stopped at the part budget)" or ""))
print(string.format("[Infill] grid %dx%d at %d-stud pitch, heights %d-%d, centre %.0f,%.0f",
    nx, nz, PITCH, MIN_HEIGHT, MAX_HEIGHT, casinoCentre.X, casinoCentre.Z))

return folder
