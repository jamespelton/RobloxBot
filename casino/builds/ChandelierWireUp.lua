-- =============================================================================
-- CHANDELIER WIRE-UP
--
-- The crystal strands, swags and pendant drops are placed along curves, so
-- consecutive drops often do not quite touch and end up hanging in mid-air.
-- Real chandeliers solve this the same way this script does: every crystal is
-- strung on a short brass wire pinned to the one above it.
--
-- Method: treat "bounding boxes overlap" as an edge and union-find the model
-- into connected components. The biggest component is the fixture body;
-- everything else is floating. Each round, every stray component gets a wire
-- to its nearest neighbouring part, then components are recomputed. Repeats
-- until one component remains, which is the definition of nothing floating.
--
-- Because the nearest part to a mid-strand drop is its own strand-mate, the
-- wires naturally run along each strand instead of jumping between them.
--
-- Works on a whole folder of fixtures. Each is wired independently, which
-- matters: the fixtures stand 40+ studs apart, so treating them as one set
-- would let a stray drop try to reach a neighbouring chandelier.
--
-- Safe to re-run: every wire it adds is named Wire_* and cleared on entry.
-- =============================================================================

local CFG = {
	ParentName = "Casino",
	FolderName = "Chandeliers", -- wire every model in here
	ModelName  = "CasinoChandelier", -- fallback when the folder is absent

	Thickness  = 0.06, -- wire gauge
	MaxSpan    = 6.0,  -- refuse to bridge anything further than this
	MaxRounds  = 10,
	Touch      = 0.10, -- bounds padding that counts as "touching"

	WireColor    = Color3.fromRGB(150, 118, 52),
	WireMaterial = Enum.Material.Foil,
}

-- ============================================================ one fixture ===

local function wireOne(model)
	-- clear wires from any previous run
	local cleared = 0
	for _, d in ipairs(model:GetDescendants()) do
		if d.Name:sub(1, 5) == "Wire_" then
			d:Destroy()
			cleared = cleared + 1
		end
	end

	-- Spatial queries skip parts with CanQuery = false, and a builder may well
	-- set that on every part for performance. Left alone, every part would read
	-- as floating. Flip it on for the duration and restore it at the end.
	local requery = {}
	for _, d in ipairs(model:GetDescendants()) do
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

	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Include
	overlapParams.FilterDescendantsInstances = { model }
	overlapParams.MaxParts = 60

	local function collectParts()
		local list = {}
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") then
				table.insert(list, d)
			end
		end
		return list
	end

	-- union-find over parts whose bounds touch
	local function components(parts)
		local idx = {}
		for i, p in ipairs(parts) do
			idx[p] = i
		end

		local uf = {}
		for i = 1, #parts do
			uf[i] = i
		end
		local function find(a)
			while uf[a] ~= a do
				uf[a] = uf[uf[a]]
				a = uf[a]
			end
			return a
		end
		local function union(a, b)
			local ra, rb = find(a), find(b)
			if ra ~= rb then
				uf[ra] = rb
			end
		end

		local pad = Vector3.new(CFG.Touch, CFG.Touch, CFG.Touch)
		for i, p in ipairs(parts) do
			for _, hit in ipairs(workspace:GetPartBoundsInBox(p.CFrame, p.Size + pad, overlapParams)) do
				local j = idx[hit]
				if j and j ~= i then
					union(i, j)
				end
			end
		end

		local groups, order = {}, {}
		for i = 1, #parts do
			local root = find(i)
			if not groups[root] then
				groups[root] = {}
				table.insert(order, root)
			end
			table.insert(groups[root], parts[i])
		end

		local out = {}
		for _, root in ipairs(order) do
			table.insert(out, groups[root])
		end
		table.sort(out, function(a, b)
			return #a > #b
		end)
		return out
	end

	-- a cylinder spanning two points; CFrame.lookAt needs a nudge when vertical
	local function wire(a, b)
		local dir = b - a
		local len = dir.Magnitude
		if len < 1e-3 then
			return nil
		end
		local up = Vector3.yAxis
		if math.abs(dir.Unit:Dot(up)) > 0.999 then
			up = Vector3.xAxis
		end

		local p = Instance.new("Part")
		p.Name = "Wire_Link"
		p.Anchored = true
		p.CanCollide = false
		p.CastShadow = false
		p.Shape = Enum.PartType.Cylinder
		p.Size = Vector3.new(len, CFG.Thickness, CFG.Thickness)
		p.CFrame = CFrame.lookAt(a + dir * 0.5, b, up) * CFrame.fromEulerAnglesXYZ(0, math.rad(90), 0)
		p.Color = CFG.WireColor
		p.Material = CFG.WireMaterial
		p.Reflectance = 0.25
		p.Parent = model
		return p
	end

	local added, rounds, unreachable = 0, 0, 0
	local startComponents

	for round = 1, CFG.MaxRounds do
		local parts = collectParts()
		local comps = components(parts)
		if round == 1 then
			startComponents = #comps
		end
		rounds = round

		if #comps <= 1 then
			break
		end

		-- comps[1] is the body; everything after it is floating
		local inStray = {}
		for i = 2, #comps do
			for _, p in ipairs(comps[i]) do
				inStray[p] = i
			end
		end

		local joinedThisRound = 0
		for i = 2, #comps do
			local best, bestFrom, bestTo = math.huge, nil, nil
			for _, from in ipairs(comps[i]) do
				for _, to in ipairs(parts) do
					-- any part outside this component is a valid anchor, which lets a
					-- stray drop latch onto its strand-mate rather than reach for the body
					if inStray[to] ~= i then
						local d = (from.Position - to.Position).Magnitude
						if d < best then
							best, bestFrom, bestTo = d, from, to
						end
					end
				end
			end

			if bestFrom and best <= CFG.MaxSpan then
				wire(bestFrom.Position, bestTo.Position)
				added = added + 1
				joinedThisRound = joinedThisRound + 1
			else
				unreachable = unreachable + 1
			end
		end

		if joinedThisRound == 0 then
			break
		end
	end

	-- Orphan sweep. Component analysis can disagree with a per-part neighbour
	-- check, because a prism rotated 45 degrees has a fatter bounding box than its
	-- Size implies, so two drops can read as connected in one test and a hair apart
	-- in the other. Rather than tune tolerances, enforce the requirement directly:
	-- any part with nothing touching it gets a wire to its nearest neighbour.
	local pad = Vector3.new(CFG.Touch, CFG.Touch, CFG.Touch)

	local function lonelyParts(parts)
		local out = {}
		for _, p in ipairs(parts) do
			local n = 0
			for _, hit in ipairs(workspace:GetPartBoundsInBox(p.CFrame, p.Size + pad, overlapParams)) do
				if hit ~= p then
					n = n + 1
				end
			end
			if n == 0 then
				table.insert(out, p)
			end
		end
		return out
	end

	local orphanWires = 0
	for _ = 1, 3 do
		local parts = collectParts()
		local orphans = lonelyParts(parts)
		if #orphans == 0 then
			break
		end
		for _, orphan in ipairs(orphans) do
			local best, bestTo = math.huge, nil
			for _, other in ipairs(parts) do
				if other ~= orphan then
					local d = (other.Position - orphan.Position).Magnitude
					if d < best then
						best, bestTo = d, other
					end
				end
			end
			if bestTo and best <= CFG.MaxSpan then
				wire(orphan.Position, bestTo.Position)
				added = added + 1
				orphanWires = orphanWires + 1
			end
		end
	end

	local parts = collectParts()
	local finalComps = components(parts)
	local floaters = #lonelyParts(parts)

	restoreCanQuery()

	return {
		cleared = cleared,
		wires = added,
		orphanWires = orphanWires,
		rounds = rounds,
		startComponents = startComponents or 0,
		endComponents = #finalComps,
		floaters = floaters,
		unreachable = unreachable,
	}
end

-- ================================================================== run =====

local parentFolder = workspace:FindFirstChild(CFG.ParentName) or workspace

local targets = {}
local folder = parentFolder:FindFirstChild(CFG.FolderName)
if folder then
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("Model") then
			table.insert(targets, child)
		end
	end
else
	local single = parentFolder:FindFirstChild(CFG.ModelName)
	if single then
		table.insert(targets, single)
	end
end

if #targets == 0 then
	error("[WireUp] nothing to wire under " .. parentFolder:GetFullName())
end

local totalWires, totalFloaters, worstComponents = 0, 0, 0
for _, target in ipairs(targets) do
	local r = wireOne(target)
	totalWires = totalWires + r.wires
	totalFloaters = totalFloaters + r.floaters
	worstComponents = math.max(worstComponents, r.endComponents)
end

print(string.format(
	"[WireUp] %d fixtures | %d wires added | worst end-component count: %d | floating parts now: %d",
	#targets, totalWires, worstComponents, totalFloaters
))

return folder or targets[1]
