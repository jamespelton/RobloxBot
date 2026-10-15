-- =============================================================================
-- CHANDELIER DETAIL PASS
--
-- The builder makes a chandelier where every gold part is the same flat colour
-- and the same Metal material, which is exactly what makes it read as plastic.
-- This pass ages it:
--
--   * patina driven by 3D Perlin noise, so tarnish forms contiguous blotches
--     across neighbouring parts instead of random per-part static
--   * material varies with how tarnished a spot is: bright Foil on the
--     polished high points, dulled Foil through the middle, CorrodedMetal
--     down in the sheltered recesses. Never plain Metal, which is nearly
--     featureless at viewing distance.
--   * crystals get per-drop tint, transparency, frost, tilt and size, so they
--     look hand-hung rather than stamped out
--   * cast ornament added: column fluting, acanthus leaves on the arms,
--     knurled cup lips, hub bosses, burnt candle rims
--
-- Safe to re-run. The first pass stashes each part's original colour / size /
-- CFrame as attributes and every later run rebuilds from those, so repeated
-- runs never compound. Added geometry is named Detail_* and rebuilt each time.
-- =============================================================================

local CFG = {
	ModelName  = "CasinoChandelier",
	ParentName = "Casino",

	-- patina
	BlotchScale    = 11.0, -- studs per large patina blotch
	GrainScale     = 3.2,  -- studs per fine grain
	TarnishDarken  = 0.42, -- how far the deepest patina drops brightness
	CorrodeAbove   = 0.74, -- tarnish level that flips a part to CorrodedMetal
	PolishBelow    = 0.34, -- tarnish level that keeps a part bright Foil
	DustAboveHub   = 0.09, -- extra tarnish up top, where nobody ever dusts

	-- crystal
	IceChance    = 0.30, -- share of drops that go frosted instead of clear
	TiltDegrees  = 7,
	SizeJitter   = 0.06,

	AddOrnament = true,
}

-- which parts are gilt metal, and which of those stay bright from handling
local GOLD = {
	Arm = true, UpperArm = true, ArmBead = true, MainHoop = true, UpperHoop = true,
	ChainLink = true, Collar = true, CollarBead = true, Column = true,
	Hub = true, HubCap = true, HubRing = true,
	CanopyPlate = true, CanopyRim = true, CanopyDome = true, CanopyNeck = true, CanopyKnob = true,
	CupBase = true, CupStem = true, CupLip = true,
	FinialCup = true, FinialBall = true, FinialNeck = true,
}
local POLISHED = { ArmBead = true, CupLip = true, MainHoop = true, CollarBead = true, FinialBall = true }
local CRYSTAL = { Prism = true, Girdle = true, Bobeche = true, Teardrop = true }
local TILTABLE = { Prism = true, Girdle = true } -- the free-hanging drops only
local WAXY = { Candle = true, WaxDrip = true }
local SKIP = { Flame = true, FlameCore = true, Wick = true }

local rng = Random.new(90210)

local parent = workspace:FindFirstChild(CFG.ParentName) or workspace
local model = parent:FindFirstChild(CFG.ModelName)
if not model then
	error("[DetailPass] no model named " .. CFG.ModelName .. " under " .. parent:GetFullName())
end

local anchor = model.PrimaryPart or model:FindFirstChild("Hub")
local hubY = anchor and anchor.Position.Y or 0

-- ---------------------------------------------------------------- helpers ----

-- Perlin noise sampled in world space. Two parts sitting at the same spot get
-- the same value, which is what keeps a Prism and its Girdle in agreement.
-- Roblox's math.noise returns roughly -0.5..0.5, so scale it up into -1..1
local function noiseAt(pos, scale, offset)
	local n = math.noise(pos.X / scale + offset, pos.Y / scale + offset, pos.Z / scale + offset)
	return math.clamp(n * 2, -1, 1)
end

-- Uniform 0..1 hash keyed on position. Perlin is bell-shaped, so a "22% of
-- drops" style pick starves if you threshold it; this does not.
local function posHash(pos, salt)
	local x = math.sin(pos.X * 12.9898 + pos.Y * 78.233 + pos.Z * 37.719 + salt) * 43758.5453
	return x - math.floor(x)
end

-- deterministic pseudo-random in -1..1 keyed on position, not call order
local function posRand(pos, salt)
	return noiseAt(pos, 1.3, salt)
end

local function tarnishAt(pos)
	local blotch = noiseAt(pos, CFG.BlotchScale, 0.5)
	local grain = noiseAt(pos, CFG.GrainScale, 37.2)
	local t = (blotch * 0.68 + grain * 0.32) * 1.4
	t = math.clamp(t * 0.5 + 0.5, 0, 1)
	if pos.Y > hubY then
		t = math.clamp(t + CFG.DustAboveHub, 0, 1) -- dust settles up high
	end
	return t
end

-- stash the pristine values once, then always rebuild from them
local function baseline(p)
	if p:GetAttribute("OrigColor") == nil then
		p:SetAttribute("OrigColor", p.Color)
		p:SetAttribute("OrigSize", p.Size)
		p:SetAttribute("OrigCFrame", p.CFrame)
		p:SetAttribute("OrigReflectance", p.Reflectance)
		p:SetAttribute("OrigTransparency", p.Transparency)
	end
	return p:GetAttribute("OrigColor"),
		p:GetAttribute("OrigSize"),
		p:GetAttribute("OrigCFrame"),
		p:GetAttribute("OrigReflectance"),
		p:GetAttribute("OrigTransparency")
end

local added = 0
local function detailPart(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in pairs(props) do
		p[key] = value
	end
	p.Parent = model
	added = added + 1
	return p
end

local function detailWedge(props)
	local p = Instance.new("WedgePart")
	p.Anchored = true
	p.CanCollide = false
	p.CastShadow = false
	for key, value in pairs(props) do
		p[key] = value
	end
	p.Parent = model
	added = added + 1
	return p
end

-- ------------------------------------------------------------- treatments ----

local stats = { gold = 0, crystal = 0, wax = 0, corroded = 0, foil = 0, cast = 0, ice = 0 }

local function treatGold(p)
	local base, baseSize, baseCF, baseRefl = baseline(p)
	local t = tarnishAt(p.Position)
	if POLISHED[p.Name] then
		t = math.max(0, t - 0.30) -- hands and dusters keep these bright
	end

	-- gilt bronze goes brown as it dulls: hue down, saturation down, value down
	local h, s, v = Color3.toHSV(base)
	h = (h - 0.014 * t) % 1
	s = math.clamp(s * (1 - 0.34 * t), 0, 1)
	v = math.clamp(v * (1 - CFG.TarnishDarken * t), 0, 1)
	p.Color = Color3.fromHSV(h, s, v)
	p.Reflectance = math.clamp(baseRefl * (1 - 0.78 * t), 0, 1)

	-- Never plain Metal. Roblox's Metal is almost featureless at viewing
	-- distance, which is what made the chain and canopy look like smooth
	-- plastic tubes. Foil carries a crinkled grain at any reflectance and
	-- CorrodedMetal is pitted, so the gradient rides on reflectance instead
	-- of on a material that has nothing to show.
	if t > CFG.CorrodeAbove then
		p.Material = Enum.Material.CorrodedMetal
		stats.corroded = stats.corroded + 1
	elseif t > CFG.PolishBelow then
		p.Material = Enum.Material.Foil
		p.Reflectance = p.Reflectance * 0.55 -- same grain, duller finish
		stats.cast = stats.cast + 1
	else
		p.Material = Enum.Material.Foil
		stats.foil = stats.foil + 1
	end

	-- a real chain is a run of individually cast links, never a uniform tube
	if p.Name == "ChainLink" and posHash(p.Position, 5.9) < 0.3 then
		p.Material = Enum.Material.CorrodedMetal
		p.Reflectance = p.Reflectance * 0.7
	end

	-- cast beads were never identical; nudge the loose ones
	if p.Name == "ArmBead" or p.Name == "CollarBead" or p.Name == "CanopyKnob" then
		local j = posRand(p.Position, 5.1)
		p.Size = baseSize * (1 + j * 0.07)
		p.CFrame = baseCF * CFrame.fromEulerAnglesXYZ(j * 0.2, j * 0.3, j * 0.15)
	end

	stats.gold = stats.gold + 1
end

local function treatCrystal(p)
	local base, baseSize, baseCF, _, baseTransparency = baseline(p)
	local n = noiseAt(p.Position, 6, 11.7)

	-- lead crystal picks up the colour of whatever is behind it; the drops near
	-- the candles read warm, the ones hanging in shadow read cold
	local warm = math.clamp(n * 0.5 + 0.5, 0, 1)
	p.Color = base:Lerp(Color3.fromRGB(255, 232, 192), warm * 0.45)
	p.Transparency = math.clamp(baseTransparency + n * 0.08, 0.08, 0.42)
	p.Reflectance = math.clamp(0.58 + n * 0.18, 0.28, 0.88)

	-- a fifth of the drops are older, cloudier glass
	if posHash(p.Position, 71.3) < CFG.IceChance then
		p.Material = Enum.Material.Ice
		p.Reflectance = p.Reflectance * 0.6
		stats.ice = stats.ice + 1
	else
		p.Material = Enum.Material.Glass
	end

	-- hang them unevenly. Driven by position, so a Prism and the Girdle around
	-- it get the same tilt and stay married.
	if TILTABLE[p.Name] then
		local d = math.rad(CFG.TiltDegrees)
		local rx = posRand(p.Position, 2.7) * d
		local ry = posRand(p.Position, 13.9) * d
		local rz = posRand(p.Position, 44.1) * d
		p.CFrame = baseCF * CFrame.fromEulerAnglesXYZ(rx, ry, rz)
		p.Size = baseSize * (1 + posRand(p.Position, 8.8) * CFG.SizeJitter)
	end

	stats.crystal = stats.crystal + 1
end

local function treatWax(p)
	local base, baseSize, baseCF = baseline(p)
	local n = noiseAt(p.Position, 4, 23.4)
	local h, s, v = Color3.toHSV(base)
	s = math.clamp(s + 0.05 * n + 0.03, 0, 1) -- old wax yellows
	v = math.clamp(v * (1 - 0.07 * math.abs(n)), 0, 1)
	p.Color = Color3.fromHSV(h, s, v)
	p.Material = Enum.Material.Plastic -- Plastic has a grain, SmoothPlastic has none
	p.Reflectance = 0

	if p.Name == "Candle" then
		local lean = math.rad(2.5)
		p.CFrame = baseCF * CFrame.fromEulerAnglesXYZ(posRand(p.Position, 3.3) * lean, 0, posRand(p.Position, 9.4) * lean)
		p.Size = baseSize * (1 + posRand(p.Position, 15.5) * 0.04)
	end

	stats.wax = stats.wax + 1
end

-- ================================================================== run =====

-- clear anything a previous pass added
for _, d in ipairs(model:GetDescendants()) do
	if d.Name:sub(1, 7) == "Detail_" then
		d:Destroy()
	end
end

local candleTops, cupLips, columns, armBeads = {}, {}, {}, {}

for _, p in ipairs(model:GetDescendants()) do
	if p:IsA("BasePart") and not SKIP[p.Name] then
		if GOLD[p.Name] then
			treatGold(p)
		elseif CRYSTAL[p.Name] then
			treatCrystal(p)
		elseif WAXY[p.Name] then
			treatWax(p)
		end

		if p.Name == "Candle" then
			table.insert(candleTops, p)
		elseif p.Name == "CupLip" then
			table.insert(cupLips, p)
		elseif p.Name == "Column" then
			table.insert(columns, p)
		elseif p.Name == "ArmBead" then
			table.insert(armBeads, p)
		end
	end
end

if CFG.AddOrnament then
	local center = anchor and anchor.Position or model:GetPivot().Position

	-- 1. fluting on the broad column discs, so the stem is not a smooth tube
	for _, col in ipairs(columns) do
		local height, diameter = col.Size.X, col.Size.Y -- cylinder: X is the length
		if diameter >= 2.3 then
			for i = 1, 10 do
				local a = (i / 10) * math.pi * 2
				detailPart({
					Name = "Detail_Flute",
					Size = Vector3.new(0.10, height * 0.94, 0.10),
					CFrame = CFrame.new(col.Position + Vector3.new(math.cos(a) * diameter * 0.47, 0, math.sin(a) * diameter * 0.47)),
					Color = col.Color,
					Material = Enum.Material.Foil,
					Reflectance = math.clamp(col.Reflectance + 0.1, 0, 1),
				})
			end
		end
	end

	-- 2. bosses studded around the hub
	for i = 1, 14 do
		local a = (i / 14) * math.pi * 2
		detailPart({
			Name = "Detail_Boss",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.42, 0.42, 0.42),
			CFrame = CFrame.new(center + Vector3.new(math.cos(a) * 1.5, 0.1, math.sin(a) * 1.5)),
			Color = anchor.Color,
			Material = Enum.Material.Foil,
			Reflectance = 0.45,
		})
	end

	-- 3. knurling around every candle cup lip
	for _, lip in ipairs(cupLips) do
		local r = lip.Size.Y * 0.47
		for i = 1, 6 do
			local a = (i / 6) * math.pi * 2
			detailPart({
				Name = "Detail_Knurl",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(r * 0.30, r * 0.30, r * 0.30),
				CFrame = CFrame.new(lip.Position + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)),
				Color = lip.Color,
				Material = Enum.Material.Foil,
				Reflectance = math.clamp(lip.Reflectance + 0.08, 0, 1),
			})
		end
	end

	-- 4. acanthus leaves fanning off the arm beads
	for _, bead in ipairs(armBeads) do
		local flat = Vector3.new(bead.Position.X - center.X, 0, bead.Position.Z - center.Z)
		local outward = (flat.Magnitude > 0.1) and flat.Unit or Vector3.xAxis
		local facing = CFrame.lookAt(bead.Position, bead.Position + outward)
		for i = -1, 1 do
			detailWedge({
				Name = "Detail_Leaf",
				Size = Vector3.new(0.10, 0.34, 0.72),
				CFrame = facing
					* CFrame.fromEulerAnglesXYZ(math.rad(-18), math.rad(i * 42), 0)
					* CFrame.new(0, -0.1, 0.34),
				Color = bead.Color,
				Material = Enum.Material.Foil,
				Reflectance = bead.Reflectance,
			})
		end
	end

	-- 5. burnt rim at the top of each candle + a soot smudge
	for _, candle in ipairs(candleTops) do
		local topY = candle.Position.Y + candle.Size.X / 2 -- cylinder: X is the height
		detailPart({
			Name = "Detail_Burn",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.06, candle.Size.Y * 1.02, candle.Size.Y * 1.02),
			CFrame = CFrame.new(candle.Position.X, topY - 0.02, candle.Position.Z) * CFrame.fromEulerAnglesXYZ(0, 0, math.rad(90)),
			Color = Color3.fromRGB(176, 152, 118),
			Material = Enum.Material.Plastic,
			Reflectance = 0,
		})
		detailPart({
			Name = "Detail_Soot",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.05, candle.Size.Y * 0.55, candle.Size.Y * 0.55),
			CFrame = CFrame.new(candle.Position.X, topY + 0.03, candle.Position.Z) * CFrame.fromEulerAnglesXYZ(0, 0, math.rad(90)),
			Color = Color3.fromRGB(74, 62, 54),
			Material = Enum.Material.Slate,
			Reflectance = 0,
		})
	end
end

print(string.format(
	"[DetailPass] %s | gold=%d (foil=%d cast=%d corroded=%d) crystal=%d (ice=%d) wax=%d | ornament added=%d",
	model:GetFullName(), stats.gold, stats.foil, stats.cast, stats.corroded, stats.crystal, stats.ice, stats.wax, added
))

return model
