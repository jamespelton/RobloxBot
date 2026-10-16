-- DETAILED TREES
-- Written by James. Changes from the original are marked [REX]:
--   1. Real positions. The defaults (0,0,0) / (30,0,0) / (60,0,0) are inside
--      the casino, on the gaming floor. These 12 spots were each probed for a
--      clear 14 x 22 x 14 column over actual Ground, not over LotPave - a tree
--      growing out of tarmac reads wrong, and the parking lot already has its
--      own trees in the medians.
--   2. Ground snap. Y is ignored and each tree raycasts down to whatever is
--      under it, so nothing hovers or sinks.
--   3. A clearance gate. Before planting, the spot is tested against the rest
--      of the venue and skipped if something is already there. The test flips
--      CanQuery on for the duration, because most of the venue is built with
--      CanQuery = false and spatial queries skip those parts entirely - without
--      that, every probe comes back falsely clear.
--   4. Parented into the Casino folder and replaced on re-run.
--   5. The scatter block looks for the lot inside Casino rather than at the
--      Workspace root, where it is not.
-- The tree geometry is untouched.

-- Settings:
local PARENT_NAME = "Casino" -- [REX] folder under Workspace; falls back to Workspace
local CHECK_CLEARANCE = true -- [REX] skip any spot that already has something in it
local CLEAR_WIDTH = 24       -- [REX] column a tree needs. Measured canopies run
                             -- 15-29 studs across, so 14 was far too generous.
local CLEAR_HEIGHT = 22

local TREES = {
    -- { position on the ground, "oak" / "palm" / "pine", size (optional, 1 = normal) },
    -- [REX] Y is ignored, each tree finds its own ground.
    -- East and west flanking avenues, alternating oak and pine:
    { Vector3.new(200, 0, -120), "oak" },
    { Vector3.new(200, 0, -60), "pine" },
    { Vector3.new(200, 0, 0), "oak", 1.15 },
    { Vector3.new(200, 0, 60), "pine" },
    { Vector3.new(200, 0, 120), "oak" },
    { Vector3.new(-200, 0, -120), "oak" },
    { Vector3.new(-200, 0, -60), "pine" },
    { Vector3.new(-200, 0, 0), "oak", 1.15 },
    { Vector3.new(-200, 0, 60), "pine" },
    { Vector3.new(-200, 0, 120), "oak" },
    -- Palms behind the building, by the bar end:
    { Vector3.new(60, 0, 150), "palm" },
    { Vector3.new(-60, 0, 150), "palm" },
}

-- Scatter lots of trees randomly over an area (set SCATTER_ENABLED to true)
local SCATTER_ENABLED = false
local SCATTER_CENTER = Vector3.new(0, 0, 0)
local SCATTER_WIDTH = 300
local SCATTER_DEPTH = 300
local SCATTER_COUNT = 25
local SCATTER_TYPES = { "oak", "oak", "pine", "palm" } -- put a type in more than once to get more of it
local MIN_SPACING = 30          -- how far apart scattered trees must be
                                -- [REX] was 20, under the 28 stud oak canopy
local AVOID_PARKING_LOT = true  -- don't scatter trees on your parking lot

local SEED = 5 -- change for different-looking trees

local BARK = Color3.fromRGB(95, 70, 50)
local BARK_DARK = Color3.fromRGB(60, 45, 32)
local PALM_BARK = Color3.fromRGB(140, 115, 85)
local PALM_RING = Color3.fromRGB(100, 80, 58)
local PINE_BARK = Color3.fromRGB(85, 55, 40)
local OAK_DARK = Color3.fromRGB(40, 80, 32)
local OAK_LIGHT = Color3.fromRGB(115, 155, 60)
local PALM_DARK = Color3.fromRGB(45, 105, 42)
local PALM_LIGHT = Color3.fromRGB(120, 165, 70)
local PINE_DARK = Color3.fromRGB(25, 58, 35)
local PINE_LIGHT = Color3.fromRGB(60, 100, 52)
local DRY = Color3.fromRGB(155, 125, 75)
local DRY_DARK = Color3.fromRGB(115, 85, 50)

local UP = Vector3.new(0, 1, 0)
local rng = Random.new(SEED)
local function rand(a, b)
    return rng:NextNumber(a, b)
end

local folder = Instance.new("Folder")
folder.Name = "Trees"
local current

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
    p.Parent = current
    return p
end

local function styled(props, style)
    for key, value in pairs(style) do
        props[key] = value
    end
    return makePart(props)
end

local function shade(color, amount)
    return Color3.new(
        math.clamp(color.R * amount, 0, 1),
        math.clamp(color.G * amount, 0, 1),
        math.clamp(color.B * amount, 0, 1)
    )
end

local function wood(color)
    return { Color = shade(color, rand(0.85, 1.15)), Material = Enum.Material.Wood, CanCollide = true }
end

local function upFor(direction)
    return math.abs(direction.Y) > 0.99 and Vector3.new(1, 0, 0) or UP
end

local function ball(pos, size, style)
    return styled({ Shape = Enum.PartType.Ball, Size = Vector3.new(size, size, size), CFrame = CFrame.new(pos) }, style)
end

local function ellipsoid(pos, size, style)
    local p = styled({ Size = size, CFrame = CFrame.new(pos) }, style)
    local mesh = Instance.new("SpecialMesh")
    mesh.MeshType = Enum.MeshType.Sphere
    mesh.Parent = p
    return p
end

local function disc(pos, height, width, style)
    return styled({
        Shape = Enum.PartType.Cylinder,
        Size = Vector3.new(height, width, width),
        CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)),
    }, style)
end

local function rod(a, b, thickness, style)
    local direction = (b - a).Unit
    return styled({
        Shape = Enum.PartType.Cylinder,
        Size = Vector3.new((b - a).Magnitude + thickness * 0.2, thickness, thickness),
        CFrame = CFrame.lookAt((a + b) / 2, b, upFor(direction)) * CFrame.Angles(0, math.rad(90), 0),
    }, style)
end

-- Ring around a trunk (follows the trunk's direction)
local function ring(pos, direction, width, thickness, style)
    return styled({
        Shape = Enum.PartType.Cylinder,
        Size = Vector3.new(thickness, width, width),
        CFrame = CFrame.lookAt(pos, pos + direction, upFor(direction)) * CFrame.Angles(0, math.rad(90), 0),
    }, style)
end

local function flatLeaf(base, direction, length, width, color)
    local p = makePart({
        Size = Vector3.new(width, 0.06, length),
        CFrame = CFrame.lookAt(base + direction * length / 2, base + direction * length, upFor(direction)),
        Color = color,
        Material = Enum.Material.SmoothPlastic,
    })
    local mesh = Instance.new("SpecialMesh")
    mesh.MeshType = Enum.MeshType.Sphere
    mesh.Parent = p
    return p
end

local function foliage(pos, size, color)
    return ball(pos, size, { Color = color, Material = Enum.Material.LeafyGrass })
end

-- Mulch ring and small rocks around the base
local function groundDetails(radius, mulchColor)
    disc(Vector3.new(0, 0.03, 0), 0.06, radius * 2, { Color = mulchColor, Material = Enum.Material.Ground })
    for _ = 1, 3 do
        local a = rand(0, math.pi * 2)
        local d = rand(radius * 0.6, radius * 1.1)
        local size = rand(0.4, 0.8)
        local grey = rand(0.45, 0.65)
        ellipsoid(Vector3.new(math.cos(a) * d, size * 0.2, math.sin(a) * d), Vector3.new(size, size * 0.6, size * 0.8), {
            Color = Color3.new(grey, grey, grey * 0.95),
            Material = Enum.Material.Slate,
        })
    end
end

local function randomFlat(minDist, maxDist)
    local a = rand(0, math.pi * 2)
    local d = rand(minDist, maxDist)
    return Vector3.new(math.cos(a) * d, 0, math.sin(a) * d)
end

----------------------------------------------------------------
-- OAK
----------------------------------------------------------------
local function leafCluster(pos, size)
    for _ = 1, 3 do
        local offset = Vector3.new(rand(-1, 1), rand(-0.5, 0.8), rand(-1, 1)) * size * 0.45
        local light = math.clamp(0.4 + offset.Y / size + rand(-0.2, 0.2), 0, 1)
        foliage(pos + offset, size * rand(0.75, 1.1), OAK_DARK:Lerp(OAK_LIGHT, light))
    end
end

local function branch(start, direction, length, thickness, depth)
    local finish = start + direction * length
    rod(start, finish, thickness, wood(BARK))
    if depth == 0 then
        leafCluster(finish, 4.5)
        return
    end
    ball(finish, thickness, wood(BARK))
    if depth == 1 then
        leafCluster(start:Lerp(finish, 0.6), 3.5)
    end
    for _ = 1, rng:NextInteger(2, 3) do
        local newDirection = (direction + Vector3.new(rand(-0.8, 0.8), rand(0.1, 0.6), rand(-0.8, 0.8))).Unit
        branch(finish, newDirection, length * rand(0.6, 0.75), thickness * 0.62, depth - 1)
    end
end

local function buildOak()
    local height = rand(9, 13)

    -- Roots spreading into the ground
    for i = 1, 6 do
        local a = (i / 6) * math.pi * 2 + rand(-0.3, 0.3)
        local d = Vector3.new(math.cos(a), 0, math.sin(a))
        local rootEnd = d * rand(2, 3) + Vector3.new(0, -0.2, 0)
        rod(d * 0.4 + Vector3.new(0, 1.2, 0), rootEnd, 0.8, wood(BARK))
        ball(rootEnd, 0.6, wood(BARK))
    end

    -- Slightly crooked trunk
    local points = { Vector3.new(0, 0, 0) }
    local offset = Vector3.new(0, 0, 0)
    local lean = Vector3.new(rand(-0.15, 0.15), 0, rand(-0.15, 0.15))
    for k = 1, 6 do
        local t = k / 6
        offset = offset + lean + Vector3.new(rand(-0.25, 0.25), 0, rand(-0.25, 0.25))
        local point = Vector3.new(offset.X, height * t, offset.Z)
        local thickness = 2.2 - 1.1 * t
        rod(points[k], point, thickness, wood(BARK))
        ball(point, thickness * 0.95, wood(BARK))
        points[k + 1] = point
    end

    -- Bark knots
    for _ = 1, 3 do
        local k = rng:NextInteger(2, 5)
        local p = points[k]:Lerp(points[k + 1], rand(0.2, 0.8))
        local thickness = 2.2 - 1.1 * (k / 6)
        ellipsoid(p + randomFlat(thickness / 2, thickness / 2), Vector3.new(0.5, 0.7, 0.5), { Color = BARK_DARK, Material = Enum.Material.Wood })
    end

    -- Crown
    local top = points[7]
    local mainCount = rng:NextInteger(4, 6)
    for i = 1, mainCount do
        local a = (i / mainCount) * math.pi * 2 + rand(-0.3, 0.3)
        local direction = Vector3.new(math.cos(a) * 0.85, rand(0.5, 0.8), math.sin(a) * 0.85).Unit
        branch(top - Vector3.new(0, rand(0, 1.5), 0), direction, rand(4.5, 6), 1.0, 2)
    end
    branch(top, (UP + Vector3.new(rand(-0.2, 0.2), 0, rand(-0.2, 0.2))).Unit, 4, 0.9, 1)

    -- A lower side branch
    local a = rand(0, math.pi * 2)
    branch(points[5], Vector3.new(math.cos(a), 0.6, math.sin(a)).Unit, 4, 0.7, 1)

    groundDetails(3.5, Color3.fromRGB(75, 50, 32))

    -- Fallen leaves
    local fallenColors = { OAK_DARK, OAK_LIGHT, Color3.fromRGB(190, 120, 40), DRY }
    for _ = 1, 8 do
        local a2 = rand(0, math.pi * 2)
        flatLeaf(randomFlat(1.5, 6) + Vector3.new(0, 0.07, 0), Vector3.new(math.cos(a2), 0, math.sin(a2)), 0.7, 0.45,
            fallenColors[rng:NextInteger(1, #fallenColors)])
    end
end

----------------------------------------------------------------
-- PALM
----------------------------------------------------------------
local function frond(origin, angle, length, lift, droop, spread, dry)
    local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
    local segments = 8
    local points = {}
    for k = 0, segments do
        local t = k / segments
        points[k] = origin + direction * length * spread * t + UP * (length * (lift * t - droop * t * t))
    end

    local stemStyle = dry and { Color = DRY_DARK, Material = Enum.Material.SmoothPlastic }
        or { Color = Color3.fromRGB(105, 115, 55), Material = Enum.Material.SmoothPlastic }
    for k = 1, segments do
        rod(points[k - 1], points[k], 0.25 - 0.12 * (k / segments), stemStyle)
    end

    for k = 1, segments - 1 do
        local tangent = (points[k + 1] - points[k - 1]).Unit
        local side = tangent:Cross(UP)
        if side.Magnitude > 0.05 then
            side = side.Unit
            local t = k / segments
            local leafLength = (0.8 + 2.8 * math.sin(math.pi * t)) * rand(0.85, 1.1)
            for _, s in ipairs({ -1, 1 }) do
                local leafDirection = (side * s + tangent * 0.6 - UP * (0.3 + 0.6 * t)
                    + Vector3.new(rand(-0.1, 0.1), rand(-0.1, 0.1), rand(-0.1, 0.1))).Unit
                local color = dry and DRY:Lerp(DRY_DARK, rand(0, 1)) or PALM_DARK:Lerp(PALM_LIGHT, rand(0, 1))
                flatLeaf(points[k], leafDirection, leafLength, 0.55, color)
                if not dry and rand(0, 1) < 0.06 then
                    flatLeaf(points[k] + leafDirection * leafLength * 0.75, leafDirection, leafLength * 0.27, 0.4, DRY)
                end
            end
        end
    end
    local tipDirection = (points[segments] - points[segments - 1]).Unit
    flatLeaf(points[segments], tipDirection, 1.2, 0.4, dry and DRY or PALM_LIGHT)
end

local function buildPalm()
    local height = rand(14, 19)
    local bendAngle = rand(0, math.pi * 2)
    local bendDirection = Vector3.new(math.cos(bendAngle), 0, math.sin(bendAngle))
    local bend = rand(1.5, 4)

    -- Swollen base
    ellipsoid(Vector3.new(0, 0.6, 0), Vector3.new(2.6, 1.6, 2.6), { Color = PALM_BARK, Material = Enum.Material.Wood, CanCollide = true })

    -- Curved ringed trunk
    local segments = 14
    local last = Vector3.new(0, 0, 0)
    for k = 1, segments do
        local t = k / segments
        local point = bendDirection * bend * t * t + UP * height * t
        local thickness = 1.5 - 0.5 * t
        rod(last, point, thickness, wood(PALM_BARK))
        ring(point, (point - last).Unit, thickness * 1.15, 0.14, { Color = PALM_RING, Material = Enum.Material.Wood })
        last = point
    end
    local top = last

    -- Crown center
    ellipsoid(top + Vector3.new(0, 0.4, 0), Vector3.new(1.6, 1.4, 1.6), { Color = Color3.fromRGB(100, 110, 60), Material = Enum.Material.SmoothPlastic })

    -- Coconuts
    for _ = 1, rng:NextInteger(4, 6) do
        local a = rand(0, math.pi * 2)
        local color = rand(0, 1) < 0.5 and Color3.fromRGB(95, 70, 40) or Color3.fromRGB(110, 120, 50)
        ball(top + Vector3.new(math.cos(a) * 0.8, rand(-0.9, -0.4), math.sin(a) * 0.8), 0.8, { Color = color, Material = Enum.Material.SmoothPlastic })
    end

    -- Dead fronds hanging down
    for i = 1, 4 do
        frond(top - Vector3.new(0, 0.3, 0), (i / 4) * math.pi * 2 + rand(-0.4, 0.4), rand(5, 6.5), -0.3, 0.5, 0.4, true)
    end

    -- Live fronds
    local count = 11
    for i = 1, count do
        local lift = rand(0.35, 0.9)
        frond(top + Vector3.new(0, 0.5, 0), (i / count) * math.pi * 2 + rand(-0.2, 0.2), rand(8, 10.5), lift, lift + rand(0.25, 0.5), 1, false)
    end

    groundDetails(3, Color3.fromRGB(160, 135, 95))
end

----------------------------------------------------------------
-- PINE
----------------------------------------------------------------
local function buildPine()
    local height = rand(16, 22)
    local lean = Vector3.new(rand(-0.6, 0.6), 0, rand(-0.6, 0.6))
    local function trunkAt(y)
        return lean * (y / height) + UP * y
    end

    -- Roots
    for i = 1, 4 do
        local a = (i / 4) * math.pi * 2 + rand(-0.3, 0.3)
        local d = Vector3.new(math.cos(a), 0, math.sin(a))
        rod(d * 0.3 + Vector3.new(0, 0.8, 0), d * rand(1.5, 2.2) + Vector3.new(0, -0.2, 0), 0.6, wood(PINE_BARK))
    end

    -- Trunk
    local segments = 6
    for k = 1, segments do
        local y0 = height * 0.92 * (k - 1) / segments
        local y1 = height * 0.92 * k / segments
        rod(trunkAt(y0), trunkAt(y1), 1.5 - 1.1 * (k / segments), wood(PINE_BARK))
    end

    -- Layers of drooping branches with needle clumps
    local tiers = 10
    local maxRadius = rand(5.5, 6.5)
    for i = 0, tiers - 1 do
        local t = i / (tiers - 1)
        local y = 3 + (height - 4.5) * t
        local radius = (1 - t) * maxRadius + 1
        local origin = trunkAt(y)
        local branches = math.max(4, math.floor(8 - t * 3))
        local offset = rand(0, math.pi * 2)
        for b = 1, branches do
            local a = offset + (b / branches) * math.pi * 2 + rand(-0.2, 0.2)
            local tip = origin + Vector3.new(math.cos(a), 0, math.sin(a)) * radius * rand(0.85, 1.1) - UP * radius * 0.3
            rod(origin, tip, 0.12 + 0.25 * (1 - t), wood(PINE_BARK))
            for _, m in ipairs({ 0.55, 0.95 }) do
                local light = math.clamp(t * 0.7 + rand(-0.15, 0.25), 0, 1)
                foliage(origin:Lerp(tip, m) + UP * 0.3, rand(1.6, 2.3) * (0.6 + (1 - t) * 0.6), PINE_DARK:Lerp(PINE_LIGHT, light))
            end
        end
    end

    -- Pointed top
    local top = trunkAt(height)
    ellipsoid(top, Vector3.new(0.9, 3, 0.9), { Color = PINE_LIGHT, Material = Enum.Material.LeafyGrass })
    foliage(top - UP * 1.2, 1.6, PINE_LIGHT)

    -- Needle bed and pine cones
    groundDetails(4, Color3.fromRGB(130, 85, 45))
    for _ = 1, 6 do
        local spot = randomFlat(1.5, 5)
        styled({
            Size = Vector3.new(0.35, 0.35, 0.55),
            CFrame = CFrame.new(spot + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, rand(0, math.pi * 2), 0),
        }, { Color = Color3.fromRGB(95, 60, 35), Material = Enum.Material.Wood })
    end
end

----------------------------------------------------------------
-- Planting
----------------------------------------------------------------
local BUILDERS = { oak = buildOak, palm = buildPalm, pine = buildPine }

local function plantTree(kind, groundPos, scale)
    local builder = BUILDERS[kind] or buildOak
    current = Instance.new("Model")
    current.Name = (kind:sub(1, 1):upper() .. kind:sub(2)) .. "Tree"
    builder()
    current.WorldPivot = CFrame.new(0, 0, 0)
    if scale and scale ~= 1 then
        current:ScaleTo(scale)
    end
    current:PivotTo(CFrame.new(groundPos) * CFrame.Angles(0, rand(0, math.pi * 2), 0))
    current.Parent = folder
end

local parentFolder = workspace:FindFirstChild(PARENT_NAME) or workspace

-- [REX] Clear a previous run BEFORE probing. Destroying it at the end instead
-- means last run's trees are still standing when the clearance gate looks, so
-- every spot reads as blocked by its own predecessor and nothing replants.
local previous = parentFolder:FindFirstChild(folder.Name)
if previous then
    previous:Destroy()
end

-- [REX] Most of the venue is built with CanQuery = false, and both raycasts and
-- GetPartBoundsInBox skip those parts outright. Without flipping it on, every
-- clearance probe below comes back falsely clear and trees plant inside things.
local requery = {}
for _, d in ipairs(parentFolder:GetDescendants()) do
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

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.FilterDescendantsInstances = { folder }

local boxParams = OverlapParams.new()
boxParams.FilterType = Enum.RaycastFilterType.Exclude
boxParams.FilterDescendantsInstances = { folder }
boxParams.MaxParts = 20

-- [REX] drop to whatever is actually underfoot
local function groundAt(x, z)
    local hit = workspace:Raycast(Vector3.new(x, 80, z), Vector3.new(0, -160, 0), rayParams)
    return hit and hit.Position.Y, hit and hit.Instance
end

-- [REX] is there room for a tree here?
local function blockersAt(x, y, z, floorPart)
    local found, seen = {}, {}
    for _, h in ipairs(workspace:GetPartBoundsInBox(
        CFrame.new(x, y + CLEAR_HEIGHT / 2, z),
        Vector3.new(CLEAR_WIDTH, CLEAR_HEIGHT, CLEAR_WIDTH), boxParams)) do
        if h ~= floorPart then
            local key = h.Parent.Name .. "/" .. h.Name
            if not seen[key] then
                seen[key] = true
                table.insert(found, key)
            end
        end
    end
    return found
end

local planted, skipped = 0, {}
for _, entry in ipairs(TREES) do
    local p = entry[1]
    local y, floorPart = groundAt(p.X, p.Z)
    if not y then
        table.insert(skipped, string.format("(%.0f,%.0f) no ground", p.X, p.Z))
    else
        local blockers = CHECK_CLEARANCE and blockersAt(p.X, y, p.Z, floorPart) or {}
        if #blockers > 0 then
            table.insert(skipped, string.format("(%.0f,%.0f) blocked by %s", p.X, p.Z, blockers[1]))
        else
            plantTree(entry[2], Vector3.new(p.X, y, p.Z), entry[3] or 1)
            planted = planted + 1
        end
    end
end

if SCATTER_ENABLED then
    -- [REX] the lot lives inside the Casino folder, not at the Workspace root
    local lot = AVOID_PARKING_LOT
        and (parentFolder:FindFirstChild("CasinoParkingLot") or workspace:FindFirstChild("CasinoParkingLot"))
    local lotCF, lotSize
    if lot then
        lotCF, lotSize = lot:GetBoundingBox()
    end
    local function onLot(p)
        if not lot then
            return false
        end
        local localPos = lotCF:PointToObjectSpace(p)
        return math.abs(localPos.X) < lotSize.X / 2 + 4 and math.abs(localPos.Z) < lotSize.Z / 2 + 4
    end

    local placed = {}
    local attempts = 0
    while #placed < SCATTER_COUNT and attempts < SCATTER_COUNT * 20 do
        attempts += 1
        local x = SCATTER_CENTER.X + rand(-SCATTER_WIDTH / 2, SCATTER_WIDTH / 2)
        local z = SCATTER_CENTER.Z + rand(-SCATTER_DEPTH / 2, SCATTER_DEPTH / 2)
        local spot = Vector3.new(x, SCATTER_CENTER.Y, z)

        local tooClose = false
        for _, other in ipairs(placed) do
            if (Vector3.new(other.X, 0, other.Z) - Vector3.new(x, 0, z)).Magnitude < MIN_SPACING then
                tooClose = true
                break
            end
        end

        if not tooClose and not onLot(spot) then
            local y, floorPart = groundAt(x, z)
            -- Only plant on the ground, not on roofs or other tall things
            if y and y <= SCATTER_CENTER.Y + 3 then
                local blockers = CHECK_CLEARANCE and blockersAt(x, y, z, floorPart) or {}
                if #blockers == 0 then
                    table.insert(placed, Vector3.new(x, y, z))
                    plantTree(SCATTER_TYPES[rng:NextInteger(1, #SCATTER_TYPES)], Vector3.new(x, y, z), rand(0.85, 1.15))
                    planted = planted + 1
                end
            end
        end
    end
end

restoreCanQuery()

folder.Parent = parentFolder

local parts = 0
for _, d in ipairs(folder:GetDescendants()) do
    if d:IsA("BasePart") then
        parts = parts + 1
    end
end
print(string.format("[Trees] %s | %d planted, %d parts | %d skipped%s",
    folder:GetFullName(), planted, parts, #skipped,
    #skipped > 0 and (": " .. table.concat(skipped, "; ")) or ""))

return folder
