-- CITY DATA PUBLISHER (Script in ServerScriptService)
--
-- CityTraffic waits on ReplicatedStorage.CityData and gives up after 180
-- seconds if it never appears. Nothing was creating it, so the traffic script
-- would have sat there and then quietly returned. This builds that data.
--
-- It reads the streets back off the ground rather than re-deriving them from
-- the generator's settings, so it stays correct if the city is rebuilt with a
-- different pitch or a different number of blocks.
--
-- Shape of the published JSON:
--   nodes[i] = { x, y, z, w, n = { neighbour indices }, light = bool, o = phase }
--     w is the street width AT THAT NODE. The two grids use different widths
--     (26 for the tower blocks, 18 for the low-rise infill), so a single
--     global street width cannot describe both.
--   blocks[i] = { x0, z0, s, y }   -- sidewalk square for the pedestrians
--   streetWidth = the most common width, kept for backwards compatibility

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GRIDS = { "City", "CityInfill" }
local SIGNAL_CYCLE = 22 -- must match the client's signal() cycle

local nodes, blocks = {}, {}

local function round(v)
    return math.floor(v + 0.5)
end

-- The sidewalk slab is the big flat square at the bottom of a block model.
local function sidewalkOf(model)
    local best
    for _, p in ipairs(model:GetChildren()) do
        if p:IsA("BasePart") and p.Size.Y < 1.5 and p.Size.X > 10
            and math.abs(p.Size.X - p.Size.Z) < 0.5 then
            if not best or p.Size.X > best.Size.X then
                best = p
            end
        end
    end
    return best
end

local function publishGrid(rootName)
    local root = workspace:FindFirstChild(rootName)
    if not root then
        return 0, 0
    end

    local list = {}
    for _, m in ipairs(root:GetChildren()) do
        if m:IsA("Model") and string.find(m.Name, "Block") then
            local pad = sidewalkOf(m)
            if pad then
                table.insert(list, {
                    cx = pad.Position.X,
                    cz = pad.Position.Z,
                    s = pad.Size.X,
                    gy = pad.Position.Y - pad.Size.Y / 2,
                    top = pad.Position.Y + pad.Size.Y / 2,
                })
            end
        end
    end
    if #list < 2 then
        return 0, 0
    end

    -- Pitch is the smallest real gap between block centres on either axis.
    local pitch
    for _, axis in ipairs({ "cx", "cz" }) do
        local vals = {}
        for _, b in ipairs(list) do
            table.insert(vals, b[axis])
        end
        table.sort(vals)
        for i = 2, #vals do
            local d = vals[i] - vals[i - 1]
            if d > 1 and (not pitch or d < pitch) then
                pitch = d
            end
        end
    end
    if not pitch then
        return 0, 0
    end

    local originX, originZ = math.huge, math.huge
    for _, b in ipairs(list) do
        originX = math.min(originX, b.cx)
        originZ = math.min(originZ, b.cz)
    end

    local blockSize = list[1].s
    local streetW = pitch - blockSize

    -- Only look at the road surface itself. The two grids do not agree on when
    -- a street exists: CitySkyline lays one if EITHER flanking block is built,
    -- CityInfill only where BOTH neighbours are. Rather than encode each
    -- generator's rule and get it wrong, ask the ground. An include-filter ray
    -- that can only see the Streets model answers "is this drivable" exactly,
    -- and keeps working if the city is rebuilt differently.
    local streets = root:FindFirstChild("Streets") or root:FindFirstChild("InfillStreets")
    if not streets then
        warn("[CityData] " .. rootName .. " has no Streets model; skipping it")
        return 0, 0
    end
    local okInclude, includeType = pcall(function()
        return Enum.RaycastFilterType.Include
    end)
    local rp = RaycastParams.new()
    rp.FilterType = okInclude and includeType or Enum.RaycastFilterType.Whitelist
    rp.FilterDescendantsInstances = { streets }
    local function roadY(x, z, near)
        local hit = workspace:Raycast(Vector3.new(x, near + 25, z), Vector3.new(0, -60, 0), rp)
        return hit and hit.Position.Y or nil
    end

    -- Index the blocks on the lattice.
    local present = {}
    local maxI, maxJ = 0, 0
    for _, b in ipairs(list) do
        local i = round((b.cx - originX) / pitch)
        local j = round((b.cz - originZ) / pitch)
        present[i .. "," .. j] = b
        maxI, maxJ = math.max(maxI, i), math.max(maxJ, j)
        -- the pedestrian ring, inset by the client
        table.insert(blocks, {
            x0 = b.cx - b.s / 2,
            z0 = b.cz - b.s / 2,
            s = b.s,
            y = b.top,
        })
    end
    local groundY = list[1].gy

    -- A node is real only if there is actually tarmac under it.
    local nodeAt = {}
    for i = 0, maxI + 1 do
        for j = 0, maxJ + 1 do
            local x = originX + (i - 0.5) * pitch
            local z = originZ + (j - 0.5) * pitch
            local y = roadY(x, z, groundY)
            if y then
                table.insert(nodes, {
                    x = x,
                    y = y, -- the asphalt surface, where the wheels go
                    z = z,
                    w = streetW,
                    n = {},
                    o = (i * 7 + j * 13) % SIGNAL_CYCLE,
                })
                nodeAt[i .. "," .. j] = #nodes
            end
        end
    end

    -- An edge is real only if the whole run between the two nodes is paved.
    -- Sampling matters: the infill lays short connectors rather than full
    -- lattice lines, so two neighbouring intersections are not always joined.
    local function paved(a, b)
        for k = 1, 6 do
            local t = 0.1 + (k - 1) * 0.16
            local x = a.x + (b.x - a.x) * t
            local z = a.z + (b.z - a.z) * t
            if not roadY(x, z, groundY) then
                return false
            end
        end
        return true
    end

    local edges = 0
    local function link(ka, kb)
        local a, b = nodeAt[ka], nodeAt[kb]
        if a and b and paved(nodes[a], nodes[b]) then
            table.insert(nodes[a].n, b)
            table.insert(nodes[b].n, a)
            edges += 1
        end
    end
    for i = 0, maxI + 1 do
        for j = 0, maxJ + 1 do
            link(i .. "," .. j, (i + 1) .. "," .. j)
            link(i .. "," .. j, i .. "," .. (j + 1))
        end
    end

    -- Only a full crossroads gets a signal; a corner or a T just yields.
    local lit = 0
    for _, node in ipairs(nodes) do
        if node.light == nil then
            node.light = #node.n >= 4
            if node.light then
                lit += 1
            end
        end
    end

    print(string.format("[CityData] %s: %d blocks, pitch %.1f, street %.1f -> %d edges, %d signals",
        rootName, #list, pitch, streetW, edges, lit))
    return #list, edges
end

local totalBlocks, totalEdges = 0, 0
for _, name in ipairs(GRIDS) do
    local b, e = publishGrid(name)
    totalBlocks += b
    totalEdges += e
end

-- Drop dead nodes and tiny islands, then renumber. A car spawned on a node
-- with no onward edge stalls forever, and one dropped on a two-node stub just
-- drives back and forth, which reads worse than no car at all.
local MIN_ISLAND = 4

local comp, compSize, nextId = {}, {}, 0
for s = 1, #nodes do
    if not comp[s] then
        nextId += 1
        local stack, size = { s }, 0
        comp[s] = nextId
        while #stack > 0 do
            local cur = table.remove(stack)
            size += 1
            for _, j in ipairs(nodes[cur].n) do
                if not comp[j] then
                    comp[j] = nextId
                    table.insert(stack, j)
                end
            end
        end
        compSize[nextId] = size
    end
end

local keep, remap = {}, {}
for i, node in ipairs(nodes) do
    if #node.n > 0 and compSize[comp[i]] >= MIN_ISLAND then
        table.insert(keep, node)
        remap[i] = #keep
    end
end
print(string.format("[CityData] %d road islands, kept those of %d+ nodes", nextId, MIN_ISLAND))
for _, node in ipairs(keep) do
    local fixed = {}
    for _, old in ipairs(node.n) do
        if remap[old] then
            table.insert(fixed, remap[old])
        end
    end
    node.n = fixed
end
nodes = keep

local widths = {}
for _, node in ipairs(nodes) do
    widths[node.w] = (widths[node.w] or 0) + 1
end
local commonW, commonCount = 26, 0
for w, c in pairs(widths) do
    if c > commonCount then
        commonW, commonCount = w, c
    end
end

local payload = HttpService:JSONEncode({
    nodes = nodes,
    blocks = blocks,
    streetWidth = commonW,
})

local value = ReplicatedStorage:FindFirstChild("CityData")
if not value then
    value = Instance.new("StringValue")
    value.Name = "CityData"
    value.Parent = ReplicatedStorage
end
value.Value = payload

print(string.format("[CityData] published %d nodes, %d blocks, %d edges, %.1f KB",
    #nodes, #blocks, totalEdges, #payload / 1024))
