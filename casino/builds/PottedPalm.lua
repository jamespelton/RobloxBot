-- =============================================================================
-- DETAILED POTTED PALM
-- Written by James. Geometry is his; the touch-ups are marked [REX] and are:
--
--   1. PLACEMENTS list + buildPalm(). The original built exactly one plant at
--      one hard-coded spot. "Bushes around the casino" means several, so this
--      places a whole set from one run and drops them in a Planters folder
--      that is cleared on re-run.
--   2. Floor snap. The casino floor is not flat (Runner 0.5, PitFloor 0.4,
--      Carpet 0.3), so each planter raycasts down and sits on whatever is
--      actually under it instead of trusting a typed Y.
--   3. QUALITY budget. The original is ~1200 parts per plant, which is a lot
--      when you want eight of them. "high" is his exact original density;
--      "normal" is roughly half and reads the same from player height.
--   4. Per-position seed, so two planters are never identical clones.
--   5. Invisible pot collider. Everything was CanCollide = false, so players
--      walked straight through a three-foot marble urn.
--   6. Leaf material Grass instead of SmoothPlastic, to match the "everything
--      has texture" rule.
-- =============================================================================

local CFG = {
	PARENT_NAME = "Casino",   -- folder under Workspace; falls back to Workspace
	FOLDER_NAME = "Planters", -- all palms live here
	CLEAR_EXISTING = true,

	-- [REX] Add, remove or move entries freely. Y is ignored, each planter
	-- finds its own floor. seed/scale/rotation are optional per entry.
	-- Every spot was probed for a clear 5x10x5 volume above the floor before
	-- being used, so none of these land on a table, stool or rail.
	PLACEMENTS = {
		-- lobby, where the stock plants stood, flanking the entrance axis
		{ position = Vector3.new(34, 0, -64) },
		{ position = Vector3.new(34, 0, -90) },
		{ position = Vector3.new(-34, 0, -64) },
		{ position = Vector3.new(-34, 0, -90) },
		-- bookending the bar, which runs X -55..56 at Z 78..94
		{ position = Vector3.new(65, 0, 86), scale = 1 },
		{ position = Vector3.new(-65, 0, 86), scale = 1 },
		-- on the approaches to the VIP lounge (X 94..138) and cashier (X -137..-99)
		{ position = Vector3.new(90, 0, 60), scale = 1 },
		{ position = Vector3.new(-90, 0, 60), scale = 1 },
	},

	-- [REX] the stock plants being replaced are loose Pot/Trunk/Frond parts
	-- sitting directly in the Lobby model. They are cleared before building,
	-- which also matters because the floor raycast would otherwise land on an
	-- old pot lid instead of the actual floor.
	REMOVE_LEGACY = {
		path = { "Casino", "Venue", "Lobby" },
		names = { Pot = true, Trunk = true, Frond = true },
	},

	-- old pot was 5 wide x 4 tall topping out at 13.4; this palm is 3.9 x 11.1
	-- at scale 1, so 1.25 matches both the footprint and the height
	DEFAULT_SCALE = 1.25,
	DEFAULT_ROTATION = 0,
	STALKS = 5,

	QUALITY = "normal", -- "high" = James's original density, "normal", or "low"

	SOLID_POT = true,
	LEAF_MATERIAL = Enum.Material.Grass,
}

-- [REX] detail budget. "high" reproduces the original numbers exactly.
local QUALITY_LEVELS = {
	high   = { ringSegments = 40, potSlices = 24, leafSubs = { 0, 0.5 }, frondSegments = 10, dirtClumps = 30, pebbles = 18, moss = 6 },
	normal = { ringSegments = 18, potSlices = 16, leafSubs = { 0.25 },   frondSegments = 8,  dirtClumps = 16, pebbles = 10, moss = 4 },
	low    = { ringSegments = 12, potSlices = 10, leafSubs = { 0.25 },   frondSegments = 6,  dirtClumps = 8,  pebbles = 6,  moss = 3 },
}
local Q = QUALITY_LEVELS[CFG.QUALITY] or QUALITY_LEVELS.normal

local POT_COLOR = Color3.fromRGB(20, 60, 45)
local GOLD = Color3.fromRGB(212, 175, 55)
local GEM = Color3.fromRGB(190, 20, 40)
local SOIL = Color3.fromRGB(58, 40, 28)
local STALK = Color3.fromRGB(125, 140, 70)
local STALK_RING = Color3.fromRGB(90, 100, 50)
local LEAF_DARK = Color3.fromRGB(40, 100, 42)
local LEAF_LIGHT = Color3.fromRGB(105, 165, 70)
local LEAF_DRY = Color3.fromRGB(150, 115, 60)

local POT_STYLE = { Color = POT_COLOR, Material = Enum.Material.Marble, Reflectance = 0.1 }
local GOLD_STYLE = { Color = GOLD, Material = Enum.Material.Metal, Reflectance = 0.3 }
local GEM_STYLE = { Color = GEM, Material = Enum.Material.Glass, Transparency = 0.2, Reflectance = 0.4 }
local STALK_STYLE = { Color = STALK, Material = Enum.Material.SmoothPlastic }
local RING_STYLE = { Color = STALK_RING, Material = Enum.Material.SmoothPlastic }

-- [REX] reassigned per plant, so the helpers below stay exactly as written
local rng, model

local function rand(a, b)
	return rng:NextNumber(a, b)
end

----------------------------------------------------------------
-- Building helpers
----------------------------------------------------------------
local function makePart(props)
    local p = Instance.new("Part")
    p.Anchored = true
    p.CanCollide = false
    p.CanTouch = false
    p.CanQuery = false
    p.CastShadow = true
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

local function ball(pos, size, style)
    return styled({
        Shape = Enum.PartType.Ball,
        Size = Vector3.new(size, size, size),
        CFrame = CFrame.new(pos),
    }, style)
end

local function addSphereMesh(p)
    local mesh = Instance.new("SpecialMesh")
    mesh.MeshType = Enum.MeshType.Sphere
    mesh.Parent = p
    return p
end

local function ellipsoid(pos, size, style)
    return addSphereMesh(styled({ Size = size, CFrame = CFrame.new(pos) }, style))
end

local function disc(pos, height, width, style)
    return styled({
        Shape = Enum.PartType.Cylinder,
        Size = Vector3.new(height, width, width),
        CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)),
    }, style)
end

local function upFor(direction)
    return math.abs(direction.Y) > 0.99 and Vector3.new(1, 0, 0) or Vector3.new(0, 1, 0)
end

local function rod(a, b, thickness, style)
    local direction = (b - a).Unit
    local length = (b - a).Magnitude + thickness * 0.3
    return styled({
        Shape = Enum.PartType.Cylinder,
        Size = Vector3.new(length, thickness, thickness),
        CFrame = CFrame.lookAt((a + b) / 2, b, upFor(direction)) * CFrame.Angles(0, math.rad(90), 0),
    }, style)
end

local function ring(center, radius, thickness, segments, style)
    local last
    for i = 0, segments do
        local a = (i / segments) * math.pi * 2
        local point = center + Vector3.new(math.cos(a) * radius, 0, math.sin(a) * radius)
        if last then
            rod(last, point, thickness, style)
        end
        last = point
    end
end

-- Ring mark around a stalk
local function node(pos, direction, width)
    styled({
        Shape = Enum.PartType.Cylinder,
        Size = Vector3.new(0.07, width, width),
        CFrame = CFrame.lookAt(pos, pos + direction, upFor(direction)) * CFrame.Angles(0, math.rad(90), 0),
    }, RING_STYLE)
end

-- Flat oval leaf starting at base and pointing along direction
local function leaf(base, direction, length, width, color)
    return addSphereMesh(makePart({
        Size = Vector3.new(width, 0.04, length),
        CFrame = CFrame.lookAt(base + direction * length / 2, base + direction * length, upFor(direction)),
        Color = color,
        Material = CFG.LEAF_MATERIAL, -- [REX] was SmoothPlastic
        CastShadow = false,
    }))
end

local function leafColor()
    return LEAF_DARK:Lerp(LEAF_LIGHT, rand(0, 1))
end

local UP = Vector3.new(0, 1, 0)

-- One arching frond with leaves down both sides
local function frond(origin, angle, length, lift)
    local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
    local segments = Q.frondSegments -- [REX] was a fixed 10
    local points = {}
    for k = 0, segments do
        local t = k / segments
        points[k] = origin + direction * length * t
            + UP * (length * lift * t - length * (lift + 0.25) * t * t)
    end

    for k = 1, segments do
        local t = k / segments
        rod(points[k - 1], points[k], 0.11 - 0.06 * t, STALK_STYLE)
    end

    for k = 1, segments - 1 do
        local tangent = (points[k + 1] - points[k - 1]).Unit
        local side = tangent:Cross(UP)
        if side.Magnitude > 0.01 then
            side = side.Unit
            for _, sub in ipairs(Q.leafSubs) do -- [REX] was { 0, 0.5 }
                local t = (k + sub) / segments
                local base = points[k]:Lerp(points[k + 1], sub)
                local leafLength = (0.4 + 1.4 * math.sin(math.pi * t)) * rand(0.85, 1.1)
                for _, s in ipairs({ -1, 1 }) do
                    local leafDirection = (side * s + tangent * 0.55 - UP * (0.25 + 0.5 * t)
                        + Vector3.new(rand(-0.1, 0.1), rand(-0.1, 0.1), rand(-0.1, 0.1))).Unit
                    leaf(base, leafDirection, leafLength, rand(0.2, 0.28), leafColor())
                    -- Some leaves have dry brown tips
                    if rand(0, 1) < 0.08 then
                        leaf(base + leafDirection * leafLength * 0.75, leafDirection, leafLength * 0.27, 0.17, LEAF_DRY)
                    end
                end
            end
        end
    end

    -- Leaf at the very tip
    local tipDirection = (points[segments] - points[segments - 1]).Unit
    leaf(points[segments], tipDirection, 0.6, 0.2, leafColor())
end

----------------------------------------------------------------
-- [REX] one plant, built at the origin then pivoted into place
----------------------------------------------------------------
local function buildPalm(spec)
	rng = Random.new(spec.seed)
	model = Instance.new("Model")
	model.Name = "PottedPalm"

	----------------------------------------------------------------
	-- Pot
	----------------------------------------------------------------
	local POT_HEIGHT = 3.4
	local FEET = 0.35

	local function potRadius(y)
		return 1.35 + 0.6 * math.sin(math.pi * (y / POT_HEIGHT) * 0.85)
	end

	-- Gold ball feet and base plate
	for i = 1, 4 do
		local a = i * math.pi / 2 + math.pi / 4
		ball(Vector3.new(math.cos(a) * 1.0, FEET / 2, math.sin(a) * 1.0), FEET, GOLD_STYLE)
	end
	disc(Vector3.new(0, FEET + 0.08, 0), 0.16, 2.8, GOLD_STYLE)
	local bottom = FEET + 0.16

	-- Curved urn body made of thin slices
	local SLICES = Q.potSlices
	for i = 0, SLICES - 1 do
		local y0 = (i / SLICES) * POT_HEIGHT
		local y1 = ((i + 1) / SLICES) * POT_HEIGHT
		local mid = (y0 + y1) / 2
		disc(Vector3.new(0, bottom + mid, 0), (y1 - y0) + 0.01, potRadius(mid) * 2, POT_STYLE)
	end

	-- Rolled rim with gold trim
	local rimY = bottom + POT_HEIGHT
	local topRadius = potRadius(POT_HEIGHT)
	ring(Vector3.new(0, rimY + 0.05, 0), topRadius + 0.05, 0.32, Q.ringSegments, POT_STYLE)
	ring(Vector3.new(0, rimY + 0.22, 0), topRadius + 0.05, 0.08, Q.ringSegments, GOLD_STYLE)

	-- Gold bands
	ring(Vector3.new(0, bottom + 0.35, 0), potRadius(0.35) + 0.03, 0.1, Q.ringSegments, GOLD_STYLE)
	ring(Vector3.new(0, bottom + 1.45, 0), potRadius(1.45) + 0.03, 0.06, Q.ringSegments, GOLD_STYLE)
	ring(Vector3.new(0, bottom + 2.35, 0), potRadius(2.35) + 0.03, 0.06, Q.ringSegments, GOLD_STYLE)
	ring(Vector3.new(0, bottom + POT_HEIGHT - 0.4, 0), potRadius(POT_HEIGHT - 0.4) + 0.03, 0.1, Q.ringSegments, GOLD_STYLE)

	-- Gold diamonds with red gems around the middle
	for i = 1, 8 do
		local a = (i / 8) * math.pi * 2
		local outward = Vector3.new(math.cos(a), 0, math.sin(a))
		local pos = Vector3.new(0, bottom + 1.9, 0) + outward * potRadius(1.9)
		styled({
			Size = Vector3.new(0.42, 0.42, 0.08),
			CFrame = CFrame.lookAt(pos, pos + outward) * CFrame.Angles(0, 0, math.rad(45)),
		}, GOLD_STYLE)
		ball(pos + outward * 0.06, 0.16, GEM_STYLE)
	end

	-- [REX] invisible collider so players cannot walk through the urn
	if CFG.SOLID_POT then
		local h = bottom + POT_HEIGHT
		makePart({
			Name = "PotCollider",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(h, 3.9, 3.9),
			CFrame = CFrame.new(0, h / 2, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Transparency = 1,
			CanCollide = true,
			CanQuery = true,
			CastShadow = false,
		})
	end

	----------------------------------------------------------------
	-- Soil
	----------------------------------------------------------------
	local soilY = rimY + 0.02
	local soilRadius = topRadius - 0.05
	disc(Vector3.new(0, soilY - 0.1, 0), 0.2, soilRadius * 2, { Color = SOIL, Material = Enum.Material.Ground })

	local function randomSoilSpot(edge)
		local r = soilRadius * edge * math.sqrt(rand(0, 1))
		local a = rand(0, math.pi * 2)
		return Vector3.new(math.cos(a) * r, soilY, math.sin(a) * r)
	end

	-- Dirt clumps
	for _ = 1, Q.dirtClumps do
		local shade = rand(0.7, 1.15)
		ball(randomSoilSpot(0.9), rand(0.15, 0.3), {
			Color = Color3.new(SOIL.R * shade, SOIL.G * shade, SOIL.B * shade),
			Material = Enum.Material.Ground,
		})
	end

	-- Pebbles
	for _ = 1, Q.pebbles do
		local size = rand(0.15, 0.3)
		local grey = rand(0.55, 0.9)
		ellipsoid(randomSoilSpot(0.85) + Vector3.new(0, 0.03, 0), Vector3.new(size, size * 0.6, size * 0.85), {
			Color = Color3.new(grey, grey, grey * 0.95),
			Material = Enum.Material.Slate,
		})
	end

	-- Moss patches
	for _ = 1, Q.moss do
		disc(randomSoilSpot(0.8) + Vector3.new(0, 0.02, 0), 0.06, rand(0.5, 0.9), {
			Color = Color3.fromRGB(70, 110, 40),
			Material = Enum.Material.LeafyGrass,
		})
	end

	----------------------------------------------------------------
	-- Palm
	----------------------------------------------------------------
	for i = 1, CFG.STALKS do
		local angle = (i / CFG.STALKS) * math.pi * 2 + rand(-0.3, 0.3)
		local outward = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local base = Vector3.new(0, soilY, 0) + outward * rand(0.2, 0.8)
		local height = rand(4.5, 7)
		local lean = rand(0.6, 1.6)

		-- Stalk with ring marks
		local segments = 7
		local last = base
		for k = 1, segments do
			local t = k / segments
			local point = base + outward * lean * t * t + UP * height * t
			local thickness = 0.3 - 0.13 * t
			rod(last, point, thickness, STALK_STYLE)
			node(point, (point - last).Unit, thickness * 1.3)
			last = point
		end
		local top = last

		-- Crown where the fronds come out
		ellipsoid(top, Vector3.new(0.4, 0.7, 0.4), STALK_STYLE)

		-- Fronds
		for f = 1, 3 do
			frond(top, angle + (f - 2) * rand(0.8, 1.2) + rand(-0.2, 0.2), rand(4, 5.5), rand(0.6, 1.0))
		end

		-- New rolled-up leaf growing from some stalks
		if rand(0, 1) < 0.4 then
			ellipsoid(top + Vector3.new(0, 0.7, 0), Vector3.new(0.14, 1.3, 0.14), { Color = LEAF_LIGHT, Material = Enum.Material.SmoothPlastic })
		end
	end

	-- Fallen dry leaves (on the soil and on the floor)
	for _ = 1, 2 do
		local a = rand(0, math.pi * 2)
		leaf(randomSoilSpot(0.7) + Vector3.new(0, 0.08, 0), Vector3.new(math.cos(a), -0.05, math.sin(a)).Unit, 1.1, 0.24, LEAF_DRY)
	end
	local floorAngle = rand(0, math.pi * 2)
	local floorSpot = Vector3.new(math.cos(floorAngle) * 2.6, 0.03, math.sin(floorAngle) * 2.6)
	leaf(floorSpot, Vector3.new(math.cos(floorAngle + 1), 0, math.sin(floorAngle + 1)), 1.2, 0.25, LEAF_DRY)

	----------------------------------------------------------------
	-- Place it in the world
	----------------------------------------------------------------
	model.WorldPivot = CFrame.new(0, 0, 0)
	local scale = spec.scale or CFG.DEFAULT_SCALE
	if scale ~= 1 then
		model:ScaleTo(scale)
	end
	model:PivotTo(CFrame.new(spec.position) * CFrame.Angles(0, math.rad(spec.rotation or CFG.DEFAULT_ROTATION), 0))
	return model
end

-- ================================================================== run =====

local parentFolder = workspace:FindFirstChild(CFG.PARENT_NAME) or workspace

local folder = parentFolder:FindFirstChild(CFG.FOLDER_NAME)
if folder and CFG.CLEAR_EXISTING then
	folder:Destroy()
	folder = nil
end
if not folder then
	folder = Instance.new("Folder")
	folder.Name = CFG.FOLDER_NAME
	folder.Parent = parentFolder
end

-- [REX] clear the stock plants first, so the floor raycast below lands on the
-- real floor rather than on top of an old pot
local removed = 0
if CFG.REMOVE_LEGACY then
	local node = workspace
	for _, step in ipairs(CFG.REMOVE_LEGACY.path) do
		node = node and node:FindFirstChild(step)
	end
	if node then
		for _, d in ipairs(node:GetDescendants()) do
			if d:IsA("BasePart") and CFG.REMOVE_LEGACY.names[d.Name] then
				d:Destroy()
				removed = removed + 1
			end
		end
	end
end

-- [REX] the casino floor is not level, so drop a ray and sit on whatever is there
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.FilterDescendantsInstances = { folder }

local function floorAt(x, z, guessY)
	local hit = workspace:Raycast(Vector3.new(x, (guessY or 0) + 40, z), Vector3.new(0, -120, 0), rayParams)
	return hit and hit.Position.Y or (guessY or 0)
end

local total, built = 0, 0
for _, spec in ipairs(CFG.PLACEMENTS) do
	local p = spec.position
	local y = floorAt(p.X, p.Z, p.Y)

	-- [REX] seed from the position, so no two planters come out identical
	local seed = spec.seed or (math.floor(math.abs(p.X) * 7919 + math.abs(p.Z) * 104729) % 1000000)

	local palm = buildPalm({
		position = Vector3.new(p.X, y, p.Z),
		rotation = spec.rotation,
		scale = spec.scale,
		seed = seed,
	})
	palm.Parent = folder

	local n = 0
	for _, d in ipairs(palm:GetDescendants()) do
		if d:IsA("BasePart") then
			n = n + 1
		end
	end
	total = total + n
	built = built + 1
end

print(string.format("[PottedPalm] %s | quality=%s | %d planters, %d parts (%d each avg) | removed %d legacy plant parts",
	folder:GetFullName(), CFG.QUALITY, built, total,
	built > 0 and math.floor(total / built) or 0, removed))

return folder
