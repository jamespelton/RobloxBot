-- =============================================================================
-- GRAND CASINO CHANDELIER (deluxe)
-- Builds a two-tier Maria-Theresa style crystal chandelier:
--   gilt canopy -> real chain links -> baluster column -> hub
--   upper tier (8 small candles) + main tier (12 curved arms, full candles)
--   bobeche dishes w/ prism drops, beaded swags between arms,
--   crystal basket strands, finial + teardrop, warm candle lighting
--
-- Run once in edit mode (or at runtime) and it replaces any previous build
-- of the same name under the same parent. Tune CFG below.
-- =============================================================================

local CFG = {
	Name       = "CasinoChandelier",
	Position   = Vector3.new(0, 45, -78), -- TOP of the chandelier (centered on the lobby statue)
	ParentName = "Casino",                -- folder under Workspace; falls back to Workspace

	-- suspension
	ChainLinks = 12,
	ChainDrop  = 4.6,

	-- main tier
	MainArms    = 12,
	MainRadius  = 8.0,
	MainArmY    = -10.6, -- where arms leave the hub (offset from Position)
	MainEndY    = -9.0,  -- where arms end (higher than the hub = upward sweep)
	ArmSegments = 7,

	-- upper tier
	UpperArms   = 8,
	UpperRadius = 4.7,
	UpperArmY   = -7.8,
	UpperEndY   = -6.6,

	-- crystal basket
	Strands       = 12,
	StrandBeads   = 8,
	BasketBottomY = -14.0, -- shallower basket so the teardrop clears the StatueOrb (top Y=25)

	-- beaded garlands between main arm ends
	SwagBeads = 8,
	SwagSag   = 1.9,

	-- a PointLight on every Nth main candle (keeps the light count sane)
	LitEvery = 2,
}

-- ---------------------------------------------------------------- palette ----
local GOLD         = Color3.fromRGB(206, 163, 72)
local GOLD_WARM    = Color3.fromRGB(233, 196, 110)
local GOLD_DARK    = Color3.fromRGB(141, 105, 40)
local CRYSTAL      = Color3.fromRGB(238, 245, 255)
local CRYSTAL_WARM = Color3.fromRGB(255, 244, 220)
local WAX          = Color3.fromRGB(250, 243, 226)
local WICK         = Color3.fromRGB(48, 40, 34)
local FLAME_OUT    = Color3.fromRGB(255, 158, 48)
local FLAME_IN     = Color3.fromRGB(255, 242, 206)

-- fixed seed, so the "random" imperfections are identical every rebuild
local rng = Random.new(20261015)

local TOP = CFG.Position
local model = Instance.new("Model")
model.Name = CFG.Name

-- ---------------------------------------------------------------- helpers ----
local function makePart(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.Metal
	p.Color = GOLD
	p.Reflectance = 0.3
	for key, value in pairs(props) do
		p[key] = value
	end
	p.Parent = model
	return p
end

-- point at polar (radius, angle) and vertical offset y, relative to TOP
local function polar(radius, angle, y)
	return TOP + Vector3.new(math.cos(angle) * radius, y, math.sin(angle) * radius)
end

-- CFrame.lookAt blows up when the direction is parallel to the up vector
local function lookCF(pos, target)
	local dir = target - pos
	if dir.Magnitude < 1e-4 then
		return CFrame.new(pos)
	end
	local up = Vector3.yAxis
	if math.abs(dir.Unit:Dot(up)) > 0.999 then
		up = Vector3.xAxis
	end
	return CFrame.lookAt(pos, target, up)
end

-- vertical cylinder: height along Y, round in XZ
local function cyl(name, pos, height, diameter, color, material, refl)
	return makePart({
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, diameter, diameter),
		CFrame = CFrame.new(pos) * CFrame.fromEulerAnglesXYZ(0, 0, math.rad(90)),
		Color = color,
		Material = material or Enum.Material.Metal,
		Reflectance = refl or 0.3,
	})
end

-- cylinder spanning two points (arms, hoops, chain, rails)
local function tube(a, b, thickness, color, material, name, refl)
	local dir = b - a
	local len = dir.Magnitude
	if len < 1e-3 then
		return nil
	end
	return makePart({
		Name = name or "Link",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(len, thickness, thickness),
		CFrame = lookCF(a + dir * 0.5, b) * CFrame.fromEulerAnglesXYZ(0, math.rad(90), 0),
		Color = color,
		Material = material or Enum.Material.Metal,
		Reflectance = refl or 0.3,
	})
end

local function ball(name, pos, diameter, color, material, refl)
	return makePart({
		Name = name,
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(diameter, diameter, diameter),
		CFrame = CFrame.new(pos),
		Color = color,
		Material = material or Enum.Material.Metal,
		Reflectance = refl or 0.32,
	})
end

-- a Part with a Sphere SpecialMesh scales on all three axes, unlike Shape = Ball
local function ellipsoid(name, pos, size, rot, color, material, refl)
	local p = makePart({
		Name = name,
		Size = size,
		CFrame = CFrame.new(pos) * (rot or CFrame.new()),
		Color = color,
		Material = material or Enum.Material.Metal,
		Reflectance = refl or 0.3,
	})
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

-- faceted crystal drop: octahedral body + a girdle disc on the bigger ones
local function gem(pos, size, color, name)
	local yaw = rng:NextNumber(0, math.pi * 2)
	local body = makePart({
		Name = name or "Prism",
		Size = Vector3.new(size, size * 1.25, size),
		CFrame = CFrame.new(pos) * CFrame.fromEulerAnglesXYZ(math.rad(45), yaw, math.rad(45)),
		Color = color or CRYSTAL,
		Material = Enum.Material.Glass,
		Transparency = 0.22,
		Reflectance = 0.55,
	})
	if size >= 0.5 then
		makePart({
			Name = "Girdle",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(size * 0.16, size * 1.2, size * 1.2),
			CFrame = CFrame.new(pos) * CFrame.fromEulerAnglesXYZ(0, yaw, math.rad(90)),
			Color = color or CRYSTAL,
			Material = Enum.Material.Glass,
			Transparency = 0.16,
			Reflectance = 0.62,
		})
	end
	return body
end

-- oval chain link made of four thin bars, so it reads as an actual link
local function chainLink(center, yaw, height, width, thickness)
	local rot = CFrame.fromEulerAnglesXYZ(0, yaw, 0)
	local function bar(offset, size)
		makePart({
			Name = "ChainLink",
			Size = size,
			CFrame = CFrame.new(center) * rot * CFrame.new(offset),
			Color = GOLD,
			Material = Enum.Material.Metal,
			Reflectance = 0.38,
		})
	end
	bar(Vector3.new(-width / 2, 0, 0), Vector3.new(thickness, height, thickness))
	bar(Vector3.new(width / 2, 0, 0), Vector3.new(thickness, height, thickness))
	bar(Vector3.new(0, height / 2, 0), Vector3.new(width, thickness, thickness))
	bar(Vector3.new(0, -height / 2, 0), Vector3.new(width, thickness, thickness))
end

local function bez(p0, p1, p2, t)
	local u = 1 - t
	return p0 * (u * u) + p1 * (2 * u * t) + p2 * (t * t)
end

-- closed hoop of straight segments through a circle of given radius
local function hoop(name, radius, y, thickness, segments, color)
	local prev = polar(radius, 0, y)
	for i = 1, segments do
		local pt = polar(radius, (i / segments) * math.pi * 2, y)
		tube(prev, pt, thickness, color, Enum.Material.Metal, name, 0.34)
		prev = pt
	end
end

-- ---------------------------------------------------------- candle cluster ---
local flameParts = {}

local function candleAssembly(endPos, scale, lit, prisms)
	scale = scale or 1

	-- tapered candle cup
	cyl("CupBase", endPos + Vector3.new(0, 0.10 * scale, 0), 0.20 * scale, 1.05 * scale, GOLD, nil, 0.34)
	cyl("CupStem", endPos + Vector3.new(0, 0.28 * scale, 0), 0.18 * scale, 0.74 * scale, GOLD_DARK, nil, 0.3)
	cyl("CupLip", endPos + Vector3.new(0, 0.44 * scale, 0), 0.14 * scale, 0.98 * scale, GOLD_WARM, nil, 0.4)

	-- bobeche: the glass dish that catches the wax, hung with prisms
	local bobY = endPos.Y + 0.60 * scale
	makePart({
		Name = "Bobeche",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.12 * scale, 1.85 * scale, 1.85 * scale),
		CFrame = CFrame.new(Vector3.new(endPos.X, bobY, endPos.Z)) * CFrame.fromEulerAnglesXYZ(0, 0, math.rad(90)),
		Color = CRYSTAL_WARM,
		Material = Enum.Material.Glass,
		Transparency = 0.26,
		Reflectance = 0.5,
	})
	local n = prisms or 5
	for i = 1, n do
		local a = (i / n) * math.pi * 2 + rng:NextNumber(-0.12, 0.12)
		local px = endPos.X + math.cos(a) * 0.78 * scale
		local pz = endPos.Z + math.sin(a) * 0.78 * scale
		gem(Vector3.new(px, bobY - 0.42 * scale, pz), 0.33 * scale, CRYSTAL_WARM)
	end

	-- candle, with slightly uneven height and a few wax runs
	local candleH = (1.5 + rng:NextNumber(-0.15, 0.15)) * scale
	local candleY = bobY + 0.10 * scale + candleH / 2
	cyl("Candle", Vector3.new(endPos.X, candleY, endPos.Z), candleH, 0.42 * scale, WAX, Enum.Material.SmoothPlastic, 0.02)
	for _ = 1, 3 do
		local a = rng:NextNumber(0, math.pi * 2)
		ellipsoid(
			"WaxDrip",
			Vector3.new(
				endPos.X + math.cos(a) * 0.19 * scale,
				candleY + rng:NextNumber(-0.1, 0.3) * scale,
				endPos.Z + math.sin(a) * 0.19 * scale
			),
			Vector3.new(0.15, 0.48, 0.15) * scale,
			nil,
			WAX,
			Enum.Material.SmoothPlastic,
			0.02
		)
	end

	-- wick + two-layer flame (bright core inside a soft outer envelope)
	local topY = candleY + candleH / 2
	cyl("Wick", Vector3.new(endPos.X, topY + 0.09 * scale, endPos.Z), 0.18 * scale, 0.07 * scale, WICK, Enum.Material.Fabric, 0)

	local flameY = topY + 0.36 * scale
	local outer = ellipsoid(
		"Flame",
		Vector3.new(endPos.X, flameY, endPos.Z),
		Vector3.new(0.34, 0.74, 0.34) * scale,
		nil,
		FLAME_OUT,
		Enum.Material.Neon,
		0
	)
	outer.Transparency = 0.3
	ellipsoid(
		"FlameCore",
		Vector3.new(endPos.X, flameY - 0.09 * scale, endPos.Z),
		Vector3.new(0.17, 0.40, 0.17) * scale,
		nil,
		FLAME_IN,
		Enum.Material.Neon,
		0
	)
	table.insert(flameParts, outer)

	if lit then
		local light = Instance.new("PointLight")
		light.Name = "FlameLight"
		light.Color = FLAME_OUT
		light.Brightness = 1.6
		light.Range = 17
		light.Shadows = false
		light.Parent = outer
	end

	return outer
end

-- ============================================================ build order ===

-- 1. canopy at the ceiling
cyl("CanopyPlate", TOP + Vector3.new(0, -0.15, 0), 0.30, 3.5, GOLD_DARK, nil, 0.25)
cyl("CanopyRim", TOP + Vector3.new(0, -0.42, 0), 0.24, 3.0, GOLD, nil, 0.36)
cyl("CanopyDome", TOP + Vector3.new(0, -0.72, 0), 0.40, 2.3, GOLD, nil, 0.36)
cyl("CanopyNeck", TOP + Vector3.new(0, -1.08, 0), 0.34, 1.4, GOLD_WARM, nil, 0.4)
ball("CanopyKnob", TOP + Vector3.new(0, -1.40, 0), 0.72, GOLD_WARM, nil, 0.42)

-- 2. chain
local chainTop = TOP.Y - 1.70
local linkH = CFG.ChainDrop / CFG.ChainLinks
for i = 1, CFG.ChainLinks do
	local y = chainTop - (i - 0.5) * linkH
	local yaw = (i % 2 == 0) and math.rad(90) or 0
	chainLink(Vector3.new(TOP.X, y, TOP.Z), yaw, linkH * 1.25, 0.60, 0.13)
end

-- 3. collar where the chain meets the column, ringed with beads
local collarY = chainTop - CFG.ChainDrop - 0.35
cyl("Collar", Vector3.new(TOP.X, collarY, TOP.Z), 0.55, 2.9, GOLD, nil, 0.38)
for i = 1, 16 do
	local a = (i / 16) * math.pi * 2
	local base = Vector3.new(TOP.X, collarY, TOP.Z)
	ball("CollarBead", base + Vector3.new(math.cos(a) * 1.45, 0, math.sin(a) * 1.45), 0.34, GOLD_WARM, nil, 0.42)
end

-- 4. baluster column: a vase profile stacked out of discs
local columnTop = (collarY - TOP.Y) - 0.3 -- back to TOP-relative
local profile = {
	{ y = columnTop - 0.0, d = 1.5 },
	{ y = columnTop - 0.5, d = 2.3 },
	{ y = columnTop - 1.0, d = 2.6 },
	{ y = columnTop - 1.5, d = 2.0 },
	{ y = columnTop - 2.0, d = 1.3 },
	{ y = columnTop - 2.5, d = 1.6 },
	{ y = columnTop - 3.0, d = 2.5 },
	{ y = columnTop - 3.5, d = 3.0 },
	{ y = columnTop - 4.0, d = 2.6 },
	{ y = columnTop - 4.5, d = 1.8 },
}
for i, seg in ipairs(profile) do
	local shade = (i % 2 == 0) and GOLD or GOLD_WARM
	cyl("Column", TOP + Vector3.new(0, seg.y, 0), 0.56, seg.d, shade, nil, 0.36)
end

-- 5. hub the arms spring from
local hub = ball("Hub", TOP + Vector3.new(0, CFG.MainArmY, 0), 3.1, GOLD, nil, 0.38)
cyl("HubRing", TOP + Vector3.new(0, CFG.MainArmY - 1.1, 0), 0.4, 3.6, GOLD_WARM, nil, 0.44)
cyl("HubCap", TOP + Vector3.new(0, CFG.MainArmY + 1.2, 0), 0.4, 2.6, GOLD_WARM, nil, 0.44)

-- 6. upper tier: 8 short arms with small candles
for i = 1, CFG.UpperArms do
	local a = (i / CFG.UpperArms) * math.pi * 2
	local p0 = polar(1.0, a, CFG.UpperArmY)
	local p1 = polar(CFG.UpperRadius * 0.6, a, CFG.UpperArmY - 1.4)
	local p2 = polar(CFG.UpperRadius, a, CFG.UpperEndY)
	local prev = p0
	for s = 1, 5 do
		local t = s / 5
		local pt = bez(p0, p1, p2, t)
		tube(prev, pt, 0.34 - 0.12 * t, GOLD, Enum.Material.Metal, "UpperArm", 0.35)
		prev = pt
	end
	candleAssembly(p2, 0.68, (i % 4 == 0), 4)
	gem(p2 - Vector3.new(0, 0.85, 0), 0.40, CRYSTAL)
	gem(p2 - Vector3.new(0, 1.25, 0), 0.28, CRYSTAL)
end
hoop("UpperHoop", CFG.UpperRadius, CFG.UpperEndY, 0.20, 18, GOLD_WARM)

-- 7. main tier: 12 curved arms with the full candle cluster
for i = 1, CFG.MainArms do
	local a = (i / CFG.MainArms) * math.pi * 2
	local p0 = polar(1.4, a, CFG.MainArmY)
	local p1 = polar(CFG.MainRadius * 0.55, a, CFG.MainArmY - 2.8) -- low control point = sweeping droop
	local p2 = polar(CFG.MainRadius, a, CFG.MainEndY)
	local prev = p0
	for s = 1, CFG.ArmSegments do
		local t = s / CFG.ArmSegments
		local pt = bez(p0, p1, p2, t)
		local th = 0.46 - 0.17 * t
		tube(prev, pt, th, GOLD, Enum.Material.Metal, "Arm", 0.35)
		if s == 3 or s == 5 then
			ball("ArmBead", pt, th * 1.9, GOLD_WARM, nil, 0.44)
		end
		prev = pt
	end

	candleAssembly(p2, 1, (i % CFG.LitEvery == 0), 5)

	-- pendant drop under each arm end
	for k = 1, 4 do
		gem(p2 - Vector3.new(0, 0.95 + k * 0.42, 0), 0.52 - k * 0.075, CRYSTAL)
	end
end
hoop("MainHoop", CFG.MainRadius, CFG.MainEndY, 0.26, 24, GOLD)

-- 8. beaded swags draped between the main arm ends
for i = 1, CFG.MainArms do
	local a1 = (i / CFG.MainArms) * math.pi * 2
	local a2 = (((i % CFG.MainArms) + 1) / CFG.MainArms) * math.pi * 2
	local e1 = polar(CFG.MainRadius, a1, CFG.MainEndY + 0.5)
	local e2 = polar(CFG.MainRadius, a2, CFG.MainEndY + 0.5)
	local ctrl = ((e1 + e2) / 2) - Vector3.new(0, CFG.SwagSag * 2, 0)
	for k = 0, CFG.SwagBeads do
		local t = k / CFG.SwagBeads
		gem(bez(e1, ctrl, e2, t), 0.30 + 0.13 * math.sin(t * math.pi), CRYSTAL_WARM)
	end
end

-- 9. crystal basket sweeping from the main hoop down to the finial
local bottom = TOP + Vector3.new(0, CFG.BasketBottomY, 0)
for i = 1, CFG.Strands do
	local a = ((i - 0.5) / CFG.Strands) * math.pi * 2
	local p0 = polar(CFG.MainRadius - 0.35, a, CFG.MainEndY - 0.25)
	local p1 = polar(CFG.MainRadius + 1.7, a, CFG.BasketBottomY * 0.62)
	for k = 0, CFG.StrandBeads - 1 do
		local t = k / (CFG.StrandBeads - 1)
		gem(bez(p0, p1, bottom, t), 0.62 - 0.30 * t, CRYSTAL)
	end
end

-- 10. finial and the big teardrop
cyl("FinialCup", bottom + Vector3.new(0, 0.30, 0), 0.40, 2.0, GOLD_WARM, nil, 0.44)
ball("FinialBall", bottom - Vector3.new(0, 0.50, 0), 1.5, GOLD, nil, 0.40)
cyl("FinialNeck", bottom - Vector3.new(0, 1.30, 0), 0.40, 0.70, GOLD_DARK, nil, 0.30)
local drop = ellipsoid("Teardrop", bottom - Vector3.new(0, 2.30, 0), Vector3.new(1.3, 2.6, 1.3), nil, CRYSTAL, Enum.Material.Glass, 0.6)
drop.Transparency = 0.2
gem(bottom - Vector3.new(0, 3.90, 0), 0.60, CRYSTAL)

-- 11. lighting: warm wash from the hub plus a pool of light on the floor
local hubLight = Instance.new("PointLight")
hubLight.Name = "HubGlow"
hubLight.Color = Color3.fromRGB(255, 196, 128)
hubLight.Brightness = 2.2
hubLight.Range = 48
hubLight.Shadows = false
hubLight.Parent = hub

local floorPool = Instance.new("SpotLight")
floorPool.Name = "FloorPool"
floorPool.Color = Color3.fromRGB(255, 206, 150)
floorPool.Brightness = 2.4
floorPool.Range = 70
floorPool.Angle = 100
floorPool.Face = Enum.NormalId.Bottom
floorPool.Shadows = false
floorPool.Parent = drop

-- 12. flicker, as a self-contained script that travels with the model
local flicker = Instance.new("Script")
flicker.Name = "Flicker"
flicker.Source = [[
-- Candle flicker for the chandelier. Each flame gets its own phase so they
-- never pulse in unison, which is what makes a chandelier read as "alive".
local model = script.Parent

local flames = {}
for _, d in ipairs(model:GetDescendants()) do
	if d:IsA("BasePart") and d.Name == "Flame" then
		table.insert(flames, {
			part = d,
			light = d:FindFirstChildOfClass("PointLight"),
			phase = math.random() * math.pi * 2,
			speed = 1.6 + math.random() * 1.4,
			baseSize = d.Size,
		})
	end
end

while model.Parent do
	local now = os.clock()
	for _, f in ipairs(flames) do
		local wave = math.sin(now * f.speed + f.phase) * 0.5 + 0.5
		local jitter = math.random()
		local level = 0.55 + wave * 0.30 + jitter * 0.15

		f.part.Transparency = 0.40 - level * 0.16
		f.part.Size = f.baseSize * (0.92 + level * 0.16)
		if f.light then
			f.light.Brightness = 0.9 + level * 1.3
		end
	end
	task.wait(0.07)
end
]]
flicker.Parent = model

-- --------------------------------------------------------------- install ----
model.PrimaryPart = hub

local parent = workspace:FindFirstChild(CFG.ParentName) or workspace
local old = parent:FindFirstChild(CFG.Name)
if old then
	old:Destroy()
end
model.Parent = parent

local partCount = 0
for _, d in ipairs(model:GetDescendants()) do
	if d:IsA("BasePart") then
		partCount = partCount + 1
	end
end
print(string.format("[Chandelier] built %s - %d parts, %d flames", model:GetFullName(), partCount, #flameParts))

return model
