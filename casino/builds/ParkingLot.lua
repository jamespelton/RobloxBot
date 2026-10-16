-- CASINO PARKING LOT
-- Written by James. Changes from the original are marked [REX]:
--   1. POSITION / ROTATION set for this place. The old parking bands centre
--      on Z = -300 and the Drive (approach road) occupies Z -215..-105, so the
--      lot sits at Z -297, which puts its sidewalk edge just clear of the
--      Drive. Y = -2.7 makes the new asphalt top land at -2.6, flush with the
--      existing LotPave slab.
--   2. parented into the Casino folder and replaced on re-run instead of
--      being dropped loose in Workspace
--   3. REMOVE_LEGACY strips the old painted Stall/Stall2 markings and any old
--      lamp pole standing inside the new footprint. The LotPave, Apron and
--      ApronTrim slabs stay, they are the ground this sits on.
--   4. the two STOP signs are mirrored about the centreline. The original put
--      both on the left of their lane, which placed the left one at X -113.5,
--      outside the lot entirely. Same for the stop bars.
-- The geometry is otherwise untouched.

-- Settings:
local POSITION = Vector3.new(0, -2.7, -297) -- [REX] centre of the lot, on the existing pave
local ROTATION = 0                    -- if the VIP spots/sidewalk face away from the casino, try 180 (or 90 / 270)
local PARENT_NAME = "Casino"          -- [REX] folder under Workspace; falls back to Workspace
local SPACES_PER_ROW = 16             -- parking spaces in each row
local BAYS = 2                        -- each bay = 2 rows of spaces with a driving lane between them
local STALL_WIDTH = 10
local STALL_DEPTH = 20
local AISLE = 24                      -- width of the driving lanes between rows
local END_LANE = 24                   -- width of the driving lanes at each end of the lot
local ISLAND = 8                      -- grass islands at the ends of each row
local MEDIAN = 12                     -- planted strip between bays
local SIDEWALK = 10                   -- sidewalk on the casino side
local SIGN_TEXT = "GOLDEN SPIRE CASINO"
local SIGN_SUBTEXT = "GUEST PARKING"
local SEED = 3                        -- change for different stains/trees

-- [REX] old lot dressing to clear out. The base paving slabs are deliberately
-- not in this list; the new lot lays on top of them.
local REMOVE_LEGACY = {
    { path = { "Casino", "Forecourt" }, names = { Stall = true, Stall2 = true } },
    { path = { "Casino", "LotLights" }, insideFootprint = true },
}

local ASPHALT = Color3.fromRGB(38, 38, 40)
local PATCH = Color3.fromRGB(30, 30, 32)
local STAIN = Color3.fromRGB(15, 15, 17)
local WHITE = Color3.fromRGB(235, 235, 225)
local YELLOW = Color3.fromRGB(230, 190, 40)
local BLUE = Color3.fromRGB(30, 90, 200)
local GOLD = Color3.fromRGB(212, 175, 55)
local RED = Color3.fromRGB(190, 25, 30)
local DARK_TEXT = Color3.fromRGB(35, 35, 35)
local LIGHT_COLOR = Color3.fromRGB(255, 215, 160)

local ASPHALT_STYLE = { Color = ASPHALT, Material = Enum.Material.Asphalt }
local CONCRETE_STYLE = { Color = Color3.fromRGB(185, 185, 180), Material = Enum.Material.Concrete }
local CURB_STYLE = { Color = Color3.fromRGB(170, 170, 165), Material = Enum.Material.Concrete }
local GRASS_STYLE = { Color = Color3.fromRGB(60, 110, 45), Material = Enum.Material.Grass }
local MULCH_STYLE = { Color = Color3.fromRGB(80, 50, 30), Material = Enum.Material.Ground, CanCollide = false }
local POLE_STYLE = { Color = Color3.fromRGB(45, 47, 50), Material = Enum.Material.Metal, Reflectance = 0.1 }
local BARK_STYLE = { Color = Color3.fromRGB(85, 60, 40), Material = Enum.Material.Wood }
local GOLD_STYLE = { Color = GOLD, Material = Enum.Material.Metal, Reflectance = 0.3 }
local STONE_STYLE = { Color = Color3.fromRGB(35, 35, 38), Material = Enum.Material.Slate }

-- [REX] The MCP bridge writes a backslash-n inside double quotes as a real
-- newline, which splits the string across two lines and will not compile. The
-- three sign captions build their line break from string.char(10) instead, so
-- the file survives being pasted into Studio.
local NL = string.char(10)

local rng = Random.new(SEED)
local function rand(a, b)
    return rng:NextNumber(a, b)
end

local model = Instance.new("Model")
model.Name = "CasinoParkingLot"

----------------------------------------------------------------
-- Building helpers
----------------------------------------------------------------
local function makePart(props)
    local p = Instance.new("Part")
    p.Anchored = true
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

local function box(center, size, style)
    return styled({ Size = size, CFrame = CFrame.new(center) }, style)
end

local function ball(pos, size, style)
    return styled({ Shape = Enum.PartType.Ball, Size = Vector3.new(size, size, size), CFrame = CFrame.new(pos) }, style)
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
    local up = math.abs(direction.Y) > 0.99 and Vector3.new(1, 0, 0) or Vector3.new(0, 1, 0)
    return styled({
        Shape = Enum.PartType.Cylinder,
        Size = Vector3.new((b - a).Magnitude, thickness, thickness),
        CFrame = CFrame.lookAt((a + b) / 2, b, up) * CFrame.Angles(0, math.rad(90), 0),
    }, style)
end

local function addText(p, face, text, color)
    local gui = Instance.new("SurfaceGui")
    gui.Face = face
    gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    gui.PixelsPerStud = 50
    gui.Parent = p
    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = color
    label.TextScaled = true
    label.Font = Enum.Font.GothamBold
    label.Parent = gui
    return label
end

----------------------------------------------------------------
-- Lot measurements
----------------------------------------------------------------
local W, D = STALL_WIDTH, STALL_DEPTH
local rowLength = SPACES_PER_ROW * W
local coreX = rowLength + 2 * ISLAND
local totalX = coreX + 2 * END_LANE
local bayDepth = 2 * D + AISLE
local totalZ = BAYS * bayDepth + (BAYS - 1) * MEDIAN
local G = 0.1               -- top of the asphalt
local CURB_TOP = G + 0.6    -- top of curbs, islands, sidewalk
local PAINT_Y = G + 0.02

local function flat(x, z)
    return Vector3.new(x, 0, z)
end

-- Painted stripe on the asphalt from point a to point b
local function paint(a, b, width, color)
    local mid = (a + b) / 2
    return makePart({
        Size = Vector3.new(width, 0.04, (b - a).Magnitude),
        CFrame = CFrame.lookAt(Vector3.new(mid.X, PAINT_Y, mid.Z), Vector3.new(b.X, PAINT_Y, b.Z)),
        Color = color,
        Material = Enum.Material.SmoothPlastic,
        Transparency = rand(0, 0.12),
        CanCollide = false,
        CastShadow = false,
    })
end

local function rotateFlat(d, angle)
    local c, s = math.cos(angle), math.sin(angle)
    return Vector3.new(d.X * c - d.Z * s, 0, d.X * s + d.Z * c)
end

local function arrow(center, direction)
    paint(center - direction * 3, center + direction * 2.5, 0.6, WHITE)
    local tip = center + direction * 3.5
    for _, side in ipairs({ -1, 1 }) do
        paint(tip, tip - rotateFlat(direction, side * math.rad(30)) * 2.8, 0.6, WHITE)
    end
end

local function signPost(ground, faceDirection, panelColor, text, textColor)
    box(ground + Vector3.new(0, 3.5, 0), Vector3.new(0.25, 7, 0.25), POLE_STYLE)
    -- [REX] Mount the panel on the FRONT of the post. Centred on it, the 0.25
    -- deep post stuck 0.05 studs out through the 0.15 deep panel and drew a
    -- dark bar straight down the middle of the caption. 0.2 puts the panel's
    -- back flush against the post's front face.
    local panelPos = ground + Vector3.new(0, 6.2, 0) + faceDirection * 0.2
    local panel = styled({
        Size = Vector3.new(2.6, 2.2, 0.15),
        CFrame = CFrame.lookAt(panelPos, panelPos + faceDirection),
    }, { Color = panelColor, Material = Enum.Material.SmoothPlastic })
    addText(panel, Enum.NormalId.Front, text, textColor)
end

local function lightPole(ground, headDirections)
    disc(ground + Vector3.new(0, 0.6, 0), 1.2, 1.8, CONCRETE_STYLE)
    disc(ground + Vector3.new(0, 10.2, 0), 18, 0.5, POLE_STYLE)
    local top = ground + Vector3.new(0, 19.2, 0)
    ball(top, 0.6, POLE_STYLE)
    for _, direction in ipairs(headDirections) do
        local armEnd = top + direction * 3.5 + Vector3.new(0, 0.3, 0)
        rod(top - Vector3.new(0, 0.3, 0), armEnd, 0.25, POLE_STYLE)
        local headPos = armEnd + direction * 1.2
        local head = styled({
            Size = Vector3.new(1.4, 0.5, 2.8),
            CFrame = CFrame.lookAt(headPos, headPos + direction),
        }, POLE_STYLE)
        makePart({
            Size = Vector3.new(1.1, 0.06, 2.4),
            CFrame = head.CFrame * CFrame.new(0, -0.27, 0),
            Color = LIGHT_COLOR,
            Material = Enum.Material.Neon,
            CanCollide = false,
        })
        local spot = Instance.new("SpotLight")
        spot.Face = Enum.NormalId.Bottom
        spot.Color = LIGHT_COLOR
        spot.Brightness = 2.5
        spot.Range = 50
        spot.Angle = 110
        spot.Shadows = false
        spot.Parent = head
    end
end

local function leafStyle()
    local shade = rand(0.8, 1.2)
    return {
        Color = Color3.fromRGB(55 * shade, 105 * shade, 45 * shade),
        Material = Enum.Material.LeafyGrass,
        CanCollide = false,
    }
end

local function tree(ground)
    disc(ground + Vector3.new(0, 0.03, 0), 0.06, 3.5, MULCH_STYLE)
    local top = ground + Vector3.new(rand(-0.4, 0.4), rand(7, 10), rand(-0.4, 0.4))
    rod(ground, top, 0.6, BARK_STYLE)
    for _ = 1, 6 do
        ball(top + Vector3.new(rand(-1.8, 1.8), rand(-1, 1.5), rand(-1.8, 1.8)), rand(3, 4.5), leafStyle())
    end
end

local function shrub(ground)
    for _ = 1, 3 do
        ball(ground + Vector3.new(rand(-0.8, 0.8), 0.6, rand(-0.8, 0.8)), rand(1.4, 2.2), leafStyle())
    end
end

-- Raised curb box with grass on top
local function planter(center, sizeX, sizeZ)
    box(Vector3.new(center.X, CURB_TOP / 2, center.Z), Vector3.new(sizeX, CURB_TOP, sizeZ), CURB_STYLE)
    box(Vector3.new(center.X, CURB_TOP - 0.04, center.Z), Vector3.new(sizeX - 1, 0.1, sizeZ - 1), GRASS_STYLE)
end

----------------------------------------------------------------
-- Ground, curbs, sidewalk
----------------------------------------------------------------
box(Vector3.new(0, G - 0.5, 0), Vector3.new(totalX, 1, totalZ), ASPHALT_STYLE)

-- Driveway aprons at the two front corners (the entrances/exits)
local laneCenters = { -(coreX / 2 + END_LANE / 2), coreX / 2 + END_LANE / 2 }
for _, laneX in ipairs(laneCenters) do
    box(Vector3.new(laneX, G - 0.5, totalZ / 2 + SIDEWALK / 2), Vector3.new(END_LANE, 1, SIDEWALK), ASPHALT_STYLE)
end

-- Repair patches
for _ = 1, 8 do
    makePart({
        Size = Vector3.new(rand(6, 14), 0.01, rand(6, 14)),
        CFrame = CFrame.new(rand(-totalX / 2 + 8, totalX / 2 - 8), G + 0.005, rand(-totalZ / 2 + 8, totalZ / 2 - 8)),
        Color = PATCH,
        Material = Enum.Material.Asphalt,
        CanCollide = false,
        CastShadow = false,
    })
end

-- Back and side curbs
box(Vector3.new(0, CURB_TOP / 2, -totalZ / 2 - 0.5), Vector3.new(totalX + 2, CURB_TOP, 1), CURB_STYLE)
for _, side in ipairs({ -1, 1 }) do
    box(Vector3.new(side * (totalX / 2 + 0.5), CURB_TOP / 2, (SIDEWALK - 1) / 2),
        Vector3.new(1, CURB_TOP, totalZ + SIDEWALK + 1), CURB_STYLE)
end

-- Sidewalk along the casino side with joint lines
local sidewalkZ = totalZ / 2 + SIDEWALK / 2
box(Vector3.new(0, CURB_TOP / 2, sidewalkZ), Vector3.new(coreX, CURB_TOP, SIDEWALK), CONCRETE_STYLE)
for x = -coreX / 2 + 6, coreX / 2 - 1, 6 do
    makePart({
        Size = Vector3.new(0.15, 0.01, SIDEWALK),
        CFrame = CFrame.new(x, CURB_TOP + 0.005, sidewalkZ),
        Color = Color3.fromRGB(120, 120, 115),
        Material = Enum.Material.SmoothPlastic,
        CanCollide = false,
        CastShadow = false,
    })
end

----------------------------------------------------------------
-- Rows of parking spaces
----------------------------------------------------------------
local rows = {}
local aisles = {}
local medians = {}
for b = 0, BAYS - 1 do
    local z0 = -totalZ / 2 + b * (bayDepth + MEDIAN)
    -- dir = which way the space opens toward the driving lane (+1 = toward +Z)
    table.insert(rows, { back = z0, aisleEdge = z0 + D, dir = 1 })
    table.insert(rows, { back = z0 + bayDepth, aisleEdge = z0 + D + AISLE, dir = -1 })
    table.insert(aisles, { from = z0 + D, to = z0 + D + AISLE })
    if b < BAYS - 1 then
        table.insert(medians, z0 + bayDepth + MEDIAN / 2)
    end
end

local center = math.floor(SPACES_PER_ROW / 2)
local function stallType(rowIndex, i)
    if rowIndex ~= #rows or i < 0 or i >= SPACES_PER_ROW then
        return "normal"
    end
    if SPACES_PER_ROW >= 4 and i >= center - 2 and i <= center + 1 then
        return "vip"
    end
    if SPACES_PER_ROW >= 12 then
        if i == center - 6 or i == center - 4 then
            return "access"
        end
        if i == center - 5 then
            return "hatch"
        end
    end
    return "normal"
end

local function boundaryColor(rowIndex, j)
    local a, b = stallType(rowIndex, j - 1), stallType(rowIndex, j)
    if a == "access" or a == "hatch" or b == "access" or b == "hatch" then
        return BLUE
    end
    if a == "vip" or b == "vip" then
        return GOLD
    end
    return WHITE
end

for r, row in ipairs(rows) do
    local letter = string.char(64 + r)
    local zLineStart = row.back + row.dir * 0.8
    local zLineEnd = row.aisleEdge

    -- Double "hairpin" lines between spaces
    for j = 0, SPACES_PER_ROW do
        local x = -rowLength / 2 + j * W
        local color = boundaryColor(r, j)
        paint(flat(x - 0.55, zLineStart), flat(x - 0.55, zLineEnd), 0.35, color)
        paint(flat(x + 0.55, zLineStart), flat(x + 0.55, zLineEnd), 0.35, color)
        paint(flat(x - 0.75, zLineEnd), flat(x + 0.75, zLineEnd), 0.4, color)
    end

    for i = 0, SPACES_PER_ROW - 1 do
        local x0 = -rowLength / 2 + i * W
        local cx = x0 + W / 2
        local kind = stallType(r, i)

        if kind == "hatch" then
            -- Striped no-parking area between the accessible spaces
            local zStart = row.back + row.dir * 1.5
            for k = 0, math.floor((D - 4) / 2.5) do
                local z = zStart + row.dir * k * 2.5
                paint(flat(x0 + 0.9, z), flat(x0 + W - 0.9, z + row.dir * 2), 0.35, BLUE)
            end
        else
            -- Wheel stop with the space number
            local stopPos = Vector3.new(cx, G + 0.25, row.back + row.dir * 2.2)
            local stopCF = CFrame.lookAt(stopPos, stopPos + Vector3.new(0, 0, row.dir))
            local stopStyle = CONCRETE_STYLE
            if kind == "vip" then
                stopStyle = GOLD_STYLE
            elseif kind == "access" then
                stopStyle = { Color = BLUE, Material = Enum.Material.SmoothPlastic }
            end
            local stop = styled({ Size = Vector3.new(6, 0.5, 0.9), CFrame = stopCF }, stopStyle)
            if kind == "normal" then
                for _, side in ipairs({ -1, 1 }) do
                    styled({ Size = Vector3.new(0.8, 0.52, 0.94), CFrame = stopCF * CFrame.new(side * 2.6, 0, 0) },
                        { Color = YELLOW, Material = Enum.Material.SmoothPlastic })
                end
            end
            addText(stop, Enum.NormalId.Front, kind == "vip" and "VIP" or (letter .. (i + 1)),
                kind == "access" and WHITE or DARK_TEXT)

            -- Oil stains
            if kind == "normal" and rand(0, 1) < 0.45 then
                local stain = makePart({
                    Size = Vector3.new(rand(2, 3.5), 0.01, rand(2.5, 4.5)),
                    CFrame = CFrame.new(cx + rand(-1, 1), G + 0.015, row.back + row.dir * rand(6, 12)),
                    Color = STAIN,
                    Material = Enum.Material.SmoothPlastic,
                    Transparency = rand(0.2, 0.5),
                    CanCollide = false,
                    CastShadow = false,
                })
                local mesh = Instance.new("SpecialMesh")
                mesh.MeshType = Enum.MeshType.Sphere
                mesh.Parent = stain
            end
        end

        -- Signs on the sidewalk for VIP and accessible spaces
        if kind == "vip" then
            signPost(Vector3.new(cx, CURB_TOP, totalZ / 2 + 1.2), Vector3.new(0, 0, -1), GOLD, "VIP" .. NL .. "PARKING", DARK_TEXT)
        elseif kind == "access" then
            signPost(Vector3.new(cx, CURB_TOP, totalZ / 2 + 1.2), Vector3.new(0, 0, -1), BLUE, "ACCESSIBLE" .. NL .. "PARKING", WHITE)
        end
    end

    -- Grass islands at both ends of the row, each with a light
    local islandZ = (row.back + row.aisleEdge) / 2 - row.dir * 0.5
    for _, side in ipairs({ -1, 1 }) do
        local islandX = side * (rowLength / 2 + ISLAND / 2)
        planter(flat(islandX, islandZ), ISLAND, D - 1)
        shrub(Vector3.new(islandX, CURB_TOP, islandZ - row.dir * 5))
        shrub(Vector3.new(islandX, CURB_TOP, islandZ + row.dir * 5))
        lightPole(Vector3.new(islandX, CURB_TOP, islandZ), { Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0) })
    end
end

----------------------------------------------------------------
-- Driving lanes: arrows and crosswalks
----------------------------------------------------------------
for _, aisle in ipairs(aisles) do
    local mid = (aisle.from + aisle.to) / 2
    for _, x in ipairs({ -rowLength / 4, rowLength / 4 }) do
        arrow(flat(x, mid + AISLE / 4), Vector3.new(1, 0, 0))
        arrow(flat(x, mid - AISLE / 4), Vector3.new(-1, 0, 0))
    end
    -- Zebra crosswalk through the middle
    for z = aisle.from + 1.5, aisle.to - 1.5, 3 do
        paint(flat(-4, z), flat(4, z), 1.6, WHITE)
    end
end

-- End lanes: yellow center lines, stop lines and stop signs at the exits
for _, laneX in ipairs(laneCenters) do
    for z = -totalZ / 2 + 3, totalZ / 2 + SIDEWALK - 6, 8 do
        paint(flat(laneX, z), flat(laneX, z + 4), 0.4, YELLOW)
    end
    local stopZ = totalZ / 2 + SIDEWALK - 2
    -- [REX] mirror about the centreline. The original always used
    -- laneX - END_LANE/2, which on the left-hand lane put the sign at
    -- X -113.5, a stud and a half outside the lot's own side curb.
    local inboard = laneX < 0 and 1 or -1
    paint(flat(laneX + inboard * (END_LANE / 2 - 1), stopZ), flat(laneX + inboard * 0.6, stopZ), 1.2, WHITE)
    local signX = laneX + inboard * (END_LANE / 2 + 1.5)
    signPost(Vector3.new(signX, CURB_TOP, stopZ), Vector3.new(0, 0, -1), RED, "STOP", WHITE)
end

----------------------------------------------------------------
-- Planted medians between bays
----------------------------------------------------------------
for _, mz in ipairs(medians) do
    planter(flat(0, mz), coreX, MEDIAN)
    -- Walkway across the median
    box(Vector3.new(0, CURB_TOP, mz), Vector3.new(6, 0.1, MEDIAN - 0.5), CONCRETE_STYLE)
    for x = -rowLength / 2 + 10, rowLength / 2 - 10, 20 do
        if math.abs(x) > 8 then
            tree(Vector3.new(x, CURB_TOP, mz))
        end
    end
    for x = -rowLength / 2 + 20, rowLength / 2 - 20, 40 do
        lightPole(Vector3.new(x, CURB_TOP, mz + MEDIAN / 2 - 1.5), { Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) })
    end
end

-- Lights along the sidewalk
for x = -rowLength / 2 + 20, rowLength / 2 - 20, 40 do
    lightPole(Vector3.new(x, CURB_TOP, totalZ / 2 + SIDEWALK - 2), { Vector3.new(0, 0, -1) })
end

----------------------------------------------------------------
-- Entrance sign
----------------------------------------------------------------
local signBase = Vector3.new(-coreX / 2 + 7, CURB_TOP, sidewalkZ)
box(signBase + Vector3.new(0, 0.75, 0), Vector3.new(10, 1.5, 2), STONE_STYLE)
box(signBase + Vector3.new(0, 3.2, 0), Vector3.new(9.4, 3.4, 0.9), GOLD_STYLE)
local panel = box(signBase + Vector3.new(0, 3.2, 0), Vector3.new(9, 3, 1), STONE_STYLE)
addText(panel, Enum.NormalId.Front, SIGN_TEXT .. NL .. SIGN_SUBTEXT, GOLD)
addText(panel, Enum.NormalId.Back, SIGN_TEXT .. NL .. SIGN_SUBTEXT, GOLD)
local signLight = Instance.new("PointLight")
signLight.Color = GOLD
signLight.Brightness = 1.5
signLight.Range = 12
signLight.Parent = panel

----------------------------------------------------------------
-- Place it in the world
----------------------------------------------------------------
model.WorldPivot = CFrame.new(0, 0, 0)
model:PivotTo(CFrame.new(POSITION) * CFrame.Angles(0, math.rad(ROTATION), 0))

-- [REX] clear the old lot dressing, then park this in the Casino folder
local halfX, halfZ = totalX / 2 + 2, totalZ / 2 + SIDEWALK + 2
local function insideFootprint(p)
    local d = p - POSITION
    return math.abs(d.X) <= halfX and math.abs(d.Z) <= halfZ
end

local removed = 0
for _, rule in ipairs(REMOVE_LEGACY) do
    local node = workspace
    for _, step in ipairs(rule.path) do
        node = node and node:FindFirstChild(step)
    end
    if node then
        for _, d in ipairs(node:GetDescendants()) do
            if d:IsA("BasePart") then
                local hit = rule.names and rule.names[d.Name]
                    or (rule.insideFootprint and insideFootprint(d.Position))
                if hit then
                    d:Destroy()
                    removed = removed + 1
                end
            end
        end
    end
end

local parentFolder = workspace:FindFirstChild(PARENT_NAME) or workspace
local existing = parentFolder:FindFirstChild(model.Name)
if existing then
    existing:Destroy()
end
model.Parent = parentFolder

local parts = 0
for _, d in ipairs(model:GetDescendants()) do
    if d:IsA("BasePart") then
        parts = parts + 1
    end
end
print(string.format("[ParkingLot] %s | %d x %d studs, %d spaces, %d parts | removed %d legacy lot parts",
    model:GetFullName(), totalX, totalZ + SIDEWALK, SPACES_PER_ROW * #rows, parts, removed))

return model
