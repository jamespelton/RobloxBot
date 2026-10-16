-- LUXURY POKER TABLES (keeps your game prompts and scripts working)
-- Written by James. Changes are marked [REX]:
--
--   1. The stool seat was built by cylUp(), which turns the part 90 degrees
--      about Z to stand the cylinder up. A Seat places whoever sits in it
--      using its own orientation, so players would have sat lying on their
--      side. The cushion is a plain part now, and the Seat is its own upright
--      invisible block facing the table (same fix as the roulette stools).
--   2. The old chairs were never removed. LuxuryChairs lives in
--      Workspace.Casino, not at the Workspace root, so the lookup found
--      nothing and the three PokerTable_Chairs sets would have stayed,
--      overlapping the new stools.
--   3. PokerTable_Chairs contains "poker", so the chairs model was treated as
--      a poker table: hidden, measured and built over. Tables are only looked
--      for outside the LuxuryChairs folder, and models destroyed during the
--      walk are skipped.
--   4. A second run built another table on top of the first. The previous
--      build for each table is cleared first.
--   5. OldTransparency was re-recorded every run, so the second run saved 1
--      as "the original" and the old look could never be restored. Written
--      once now, with OldCanCollide alongside it.
--   6. The pendant rods stopped 15 studs up, in mid-air under a 48-stud
--      ceiling. They now run up to whatever is above the table.
--   7. Parented into the Casino folder, like the other builds.
--   8. These tables are round, which makes the outline path repeat a point
--      where its two arcs meet. A rod between two identical points has no
--      direction and came out with a NaN CFrame; those joins are skipped.

-- Settings:
local SITTABLE = true
local PENDANT_LIGHT = true
local CARDS_AND_CHIPS = true
local FELT_COLOR = Color3.fromRGB(20, 95, 45)
local LEATHER_COLOR = Color3.fromRGB(140, 15, 25)

local V = Vector3.new
local UP = V(0, 1, 0)
local rng = Random.new(11)

----------------------------------------------------------------
-- Materials
----------------------------------------------------------------
local GOLD = { Color = Color3.fromRGB(212, 175, 55), Material = Enum.Material.Metal, Reflectance = 0.35 }
local MAHOGANY = { Color = Color3.fromRGB(75, 30, 22), Material = Enum.Material.Wood }
local DARK_WOOD = { Color = Color3.fromRGB(50, 22, 15), Material = Enum.Material.Wood }
local BLACK = { Color = Color3.fromRGB(20, 20, 22), Material = Enum.Material.SmoothPlastic }
local GRANITE = { Color = Color3.fromRGB(25, 25, 28), Material = Enum.Material.Granite }
local LEATHER = { Color = LEATHER_COLOR, Material = Enum.Material.Leather }
local FELT = { Color = FELT_COLOR, Material = Enum.Material.Fabric }
local FELT_DARK = { Color = FELT_COLOR:Lerp(Color3.new(0, 0, 0), 0.25), Material = Enum.Material.Fabric }
local WHITE = { Color = Color3.fromRGB(245, 245, 240), Material = Enum.Material.SmoothPlastic }
local CARD_RED = { Color = Color3.fromRGB(170, 20, 25), Material = Enum.Material.SmoothPlastic }
local CARD_BLACK = { Color = Color3.fromRGB(25, 25, 28), Material = Enum.Material.SmoothPlastic }
local NEON_WARM = { Color = Color3.fromRGB(255, 225, 170), Material = Enum.Material.Neon }
local CHIP_COLORS = {
    Color3.fromRGB(200, 30, 30), Color3.fromRGB(30, 80, 200), Color3.fromRGB(30, 150, 60),
    Color3.fromRGB(20, 20, 20), Color3.fromRGB(240, 240, 240), Color3.fromRGB(150, 60, 170), Color3.fromRGB(240, 170, 40),
}

----------------------------------------------------------------
-- Helpers
----------------------------------------------------------------
local current
local function makePart(props, style, className)
    local p = Instance.new(className or "Part")
    p.Anchored = true
    p.CanCollide = false
    p.CanTouch = false
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    for k, v in pairs(style) do
        p[k] = v
    end
    for k, v in pairs(props) do
        p[k] = v
    end
    p.Parent = current
    return p
end
local function box(cf, size, style, className)
    return makePart({ CFrame = cf, Size = size }, style, className)
end
local function ball(pos, size, style)
    return makePart({ Shape = Enum.PartType.Ball, CFrame = CFrame.new(pos), Size = V(size, size, size) }, style)
end
local function cylUp(pos, height, width, style, className)
    return makePart({
        Shape = Enum.PartType.Cylinder,
        CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)),
        Size = V(height, width, width),
    }, style, className)
end
local function rod(a, b, thickness, style)
    local dir = (b - a).Unit
    local up = math.abs(dir.Y) > 0.98 and V(1, 0, 0) or UP
    return makePart({
        Shape = Enum.PartType.Cylinder,
        CFrame = CFrame.lookAt((a + b) / 2, b, up) * CFrame.Angles(0, math.rad(90), 0),
        Size = V((b - a).Magnitude + thickness * 0.3, thickness, thickness),
    }, style)
end
local function bounds(part)
    local half = part.Size / 2
    local mn, mx = V(math.huge, math.huge, math.huge), V(-math.huge, -math.huge, -math.huge)
    for _, sx in ipairs({ -1, 1 }) do
        for _, sy in ipairs({ -1, 1 }) do
            for _, sz in ipairs({ -1, 1 }) do
                local c = part.CFrame * V(half.X * sx, half.Y * sy, half.Z * sz)
                mn, mx = mn:Min(c), mx:Max(c)
            end
        end
    end
    return mn, mx
end
local function flat(v)
    return V(v.X, 0, v.Z)
end

----------------------------------------------------------------
-- Luxury stool (base = floor point, -Z faces the table)
----------------------------------------------------------------
local function stool(base, h)
    local function c(localPos, height, width, style, className)
        return cylUp(base * localPos, height, width, style, className)
    end
    c(V(0, 0.12, 0), 0.25, 2.4, GOLD).CanCollide = true
    c(V(0, 0.3, 0), 0.12, 1.8, BLACK)
    c(V(0, (0.35 + h - 1) / 2, 0), h - 1.35, 0.4, GOLD).CanCollide = true
    c(V(0, h - 0.95, 0), 0.15, 1.2, GOLD)
    local ringY, last = h * 0.42, nil
    for i = 0, 8 do
        local a = i / 8 * math.pi * 2
        local point = base * V(math.cos(a), ringY, math.sin(a))
        if last then
            rod(last, point, 0.12, GOLD)
        end
        last = point
    end
    -- [REX] the cushion is a plain part; the Seat is the upright block below
    local cushion = c(V(0, h - 0.275, 0), 0.55, 2.5, LEATHER)
    cushion.CanCollide = true
    cushion.Name = "Cushion"
    -- [REX] cylUp() turns its part 90 degrees about Z, and a Seat sits the
    -- player using its own orientation, so a cylUp() Seat laid them on their
    -- side. This block is square to the stool and its LookVector points at
    -- the table, so the sitter faces the game.
    if SITTABLE then
        local seat = Instance.new("Seat")
        seat.Name = "SitPad"
        seat.Anchored = true
        seat.CanCollide = true
        seat.Transparency = 1
        seat.Size = V(2.1, 0.5, 2.1)
        seat.CFrame = base * CFrame.new(0, h - 0.25, 0)
        seat.TopSurface = Enum.SurfaceType.Smooth
        seat.BottomSurface = Enum.SurfaceType.Smooth
        seat.Parent = current
    end
    c(V(0, h - 0.55, 0), 0.08, 2.56, GOLD)
    c(V(0, h - 0.72, 0), 0.3, 2.3, MAHOGANY)
    for _, offset in ipairs({ V(0, 0, 0), V(0.6, 0, 0), V(-0.6, 0, 0), V(0, 0, 0.6), V(0, 0, -0.6) }) do
        ball(base * (V(0, h + 0.01, 0) + offset), 0.16, GOLD)
    end
    -- Curved backrest on the side AWAY from the table (+Z)
    local R, backH, backBottom = 1.15, 2.6, h - 0.2
    local center = base * V(0, backBottom + backH / 2, 0)
    for _, deg in ipairs({ -60, -30, 0, 30, 60 }) do
        local a = math.rad(deg)
        local pos = base * V(math.sin(a) * R, backBottom + backH / 2, math.cos(a) * R)
        box(CFrame.lookAt(pos, V(center.X, pos.Y, center.Z)), V(0.66, backH, 0.38), LEATHER).CanCollide = true
        local shell = base * V(math.sin(a) * (R + 0.24), backBottom + backH / 2, math.cos(a) * (R + 0.24))
        box(CFrame.lookAt(shell, V(center.X, shell.Y, center.Z)), V(0.66, backH + 0.1, 0.12), MAHOGANY)
    end
    for _, y in ipairs({ backBottom + backH, backBottom }) do
        local prev
        for i = 0, 6 do
            local a = math.rad(-75 + 150 * i / 6)
            local point = base * V(math.sin(a) * R, y, math.cos(a) * R)
            if prev then
                rod(prev, point, 0.22, GOLD)
            end
            prev = point
        end
    end
    for _, deg in ipairs({ -30, 0, 30 }) do
        local a = math.rad(deg)
        ball(base * V(math.sin(a) * (R - 0.2), backBottom + backH * 0.55, math.cos(a) * (R - 0.2)), 0.16, GOLD)
    end
    for _, x in ipairs({ -0.5, 0.5 }) do
        rod(base * V(x, h - 0.6, 0.5), base * V(x * 1.1, backBottom + 0.3, R), 0.14, GOLD)
    end
end

----------------------------------------------------------------
-- Racetrack shape helpers (c = half the straight length, r = half the width)
----------------------------------------------------------------
local function stadiumPath(c, r, arcSteps)
    local points = {}
    for i = 0, arcSteps do
        local t = -math.pi / 2 + math.pi * i / arcSteps
        table.insert(points, V(c + r * math.cos(t), 0, r * math.sin(t)))
    end
    for i = 0, arcSteps do
        local t = math.pi / 2 + math.pi * i / arcSteps
        table.insert(points, V(-c + r * math.cos(t), 0, r * math.sin(t)))
    end
    table.insert(points, points[1])
    return points
end

local function inwardNormal(p, c)
    local centerX = math.clamp(p.X, -c, c)
    local d = V(centerX, 0, 0) - V(p.X, 0, p.Z)
    return d.Magnitude > 0.01 and d.Unit or V(0, 0, 1)
end

-- Point at a distance along the path (walks the path's segments)
local function alongPath(points, s)
    local total = 0
    local lengths = {}
    for i = 1, #points - 1 do
        lengths[i] = (points[i + 1] - points[i]).Magnitude
        total += lengths[i]
    end
    s = s % total
    for i = 1, #points - 1 do
        -- [REX] a round table has zero-length joins (c = 0); skip them rather
        -- than divide by zero
        if lengths[i] > 0 and s <= lengths[i] then
            return points[i]:Lerp(points[i + 1], s / lengths[i])
        end
        s -= lengths[i]
    end
    return points[#points]
end

local function pathLength(points)
    local total = 0
    for i = 1, #points - 1 do
        total += (points[i + 1] - points[i]).Magnitude
    end
    return total
end

----------------------------------------------------------------
-- Cards and chips
----------------------------------------------------------------
local function chipStack(p, count)
    local color = CHIP_COLORS[rng:NextInteger(1, #CHIP_COLORS)]
    for i = 0, count - 1 do
        cylUp(p + V(0, 0.06 + i * 0.12, 0), 0.11, 0.7, { Color = color, Material = Enum.Material.SmoothPlastic })
    end
    cylUp(p + V(0, count * 0.12 + 0.005, 0), 0.01, 0.45, WHITE)
end

local function faceUpCard(cf)
    local red = rng:NextNumber() < 0.5
    box(cf, V(0.7, 0.03, 1.0), WHITE)
    box(cf * CFrame.new(0, 0.02, 0) * CFrame.Angles(0, math.rad(45), 0), V(0.28, 0.02, 0.28), red and CARD_RED or CARD_BLACK)
    box(cf * CFrame.new(-0.22, 0.02, -0.36), V(0.12, 0.02, 0.16), red and CARD_RED or CARD_BLACK)
    box(cf * CFrame.new(0.22, 0.02, 0.36), V(0.12, 0.02, 0.16), red and CARD_RED or CARD_BLACK)
end

local function faceDownCard(cf)
    box(cf, V(0.7, 0.03, 1.0), WHITE)
    box(cf * CFrame.new(0, 0.02, 0), V(0.58, 0.02, 0.88), CARD_RED)
    box(cf * CFrame.new(0, 0.03, 0), V(0.4, 0.02, 0.7), GOLD)
    box(cf * CFrame.new(0, 0.04, 0), V(0.32, 0.02, 0.62), CARD_RED)
end

-- [REX] how far up the pendant rods have to reach
local ceilingRay = RaycastParams.new()
ceilingRay.FilterType = Enum.RaycastFilterType.Exclude
local function ceilingAbove(p, ignore)
    ceilingRay.FilterDescendantsInstances = ignore
    local hit = workspace:Raycast(p, V(0, 120, 0), ceilingRay)
    return hit and hit.Position.Y or nil
end
local ignoreForCeiling = {}

----------------------------------------------------------------
-- Build one poker table (T = floor frame at the table center, X = long direction)
----------------------------------------------------------------
local function buildPoker(T, a, b, ht)
    local c = math.max(a - b, 0)
    local function at(x, y, z)
        return T * CFrame.new(x, y, z)
    end
    local function pos(x, y, z)
        return T * V(x, y, z)
    end
    local function solid(y0, y1, r, style)
        local h, mid = y1 - y0, (y0 + y1) / 2
        local parts = {}
        if c > 0.05 then
            table.insert(parts, box(at(0, mid, 0), V(2 * c, h, 2 * r), style))
        end
        for _, side in ipairs(c > 0.05 and { -1, 1 } or { 0 }) do
            table.insert(parts, cylUp(pos(side * c, mid, 0), h, 2 * r, style))
        end
        return parts
    end
    local function ringRods(r, y, thickness, style, steps)
        local points = stadiumPath(c, r, steps or 14)
        for i = 1, #points - 1 do
            -- [REX] a round table repeats a point where the two arcs meet, and
            -- a rod between identical points has a NaN direction
            if (points[i + 1] - points[i]).Magnitude > 0.01 then
                rod(pos(points[i].X, y, points[i].Z), pos(points[i + 1].X, y, points[i + 1].Z), thickness, style)
            end
        end
    end
    local function ringBand(rInner, rOuter, y0, y1, style)
        local mid = (rInner + rOuter) / 2
        local points = stadiumPath(c, mid, 16)
        for i = 1, #points - 1 do
            local p1, p2 = points[i], points[i + 1]
            if (p2 - p1).Magnitude > 0.01 then
                local m = (p1 + p2) / 2
                local wp = pos(m.X, (y0 + y1) / 2, m.Z)
                local dir = T:VectorToWorldSpace(p2 - p1)
                box(CFrame.lookAt(wp, wp + dir), V(rOuter - rInner, y1 - y0, (p2 - p1).Magnitude + 0.05), style)
            end
        end
    end

    -- Pedestals
    local pedestals = c > 1 and { -c * 0.6, c * 0.6 } or { 0 }
    for _, x in ipairs(pedestals) do
        cylUp(pos(x, 0.2, 0), 0.4, math.min(2 * b * 0.6, 5), GRANITE).CanCollide = true
        cylUp(pos(x, 0.45, 0), 0.1, math.min(2 * b * 0.6, 5) - 0.4, GOLD)
        cylUp(pos(x, (0.5 + ht - 1.3) / 2, 0), ht - 1.8, 1.6, MAHOGANY).CanCollide = true
        for _, y in ipairs({ 1.0, ht - 1.6 }) do
            cylUp(pos(x, y, 0), 0.2, 1.75, GOLD)
        end
    end

    -- Apron, top, felt, wood track and padded rail
    for _, p in ipairs(solid(ht - 1.3, ht - 0.6, b - 0.4, MAHOGANY)) do
        p.CanCollide = true
    end
    ringRods(b - 0.4, ht - 1.3, 0.1, GOLD)
    for _, p in ipairs(solid(ht - 0.6, ht - 0.1, b + 0.5, MAHOGANY)) do
        p.CanCollide = true
    end
    local felt = solid(ht - 0.1, ht, b - 1.0, FELT)
    for _, p in ipairs(felt) do
        p.CanCollide = true
    end
    ringBand(b - 1.0, b - 0.2, ht - 0.1, ht + 0.04, MAHOGANY)
    ringRods(b - 0.95, ht + 0.045, 0.06, GOLD)
    ringRods(b + 0.15, ht + 0.25, 1.1, LEATHER)
    ringRods(b + 0.15, ht - 0.28, 0.12, GOLD)

    -- Printed felt: betting line, emblem, dealer spot
    ringRods(math.max(b - 2.6, 1), ht + 0.005, 0.05, GOLD, 20)
    box(at(0, ht + 0.005, 0) * CFrame.Angles(0, math.rad(45), 0), V(1.6, 0.01, 1.6), GOLD)
    box(at(0, ht + 0.012, 0) * CFrame.Angles(0, math.rad(45), 0), V(1.3, 0.01, 1.3), FELT_DARK)
    box(at(0, ht + 0.02, 0) * CFrame.Angles(0, math.rad(45), 0), V(0.6, 0.01, 0.6), GOLD)
    box(at(0, ht + 0.005, -(b - 1.9)), V(3.2, 0.01, 1.4), GOLD)
    box(at(0, ht + 0.01, -(b - 1.9)), V(3.0, 0.01, 1.2), FELT_DARK)

    -- Seats around the table, with a gap for the dealer at -Z
    local seatRadius = b + 2.6
    local seatPath = stadiumPath(c, seatRadius, 24)
    local perimeter = pathLength(seatPath)
    local players = c > 1 and 9 or 8
    local dealerS = perimeter - c
    local seatH = math.clamp(ht - 1.1, 2, 3.4)
    for k = 1, players do
        local s = dealerS + k * perimeter / (players + 1)
        local p = alongPath(seatPath, s)
        local inward = inwardNormal(p, c)
        local floorPos = pos(p.X, 0, p.Z)
        local inwardWorld = T:VectorToWorldSpace(inward)
        stool(CFrame.lookAt(floorPos, floorPos + inwardWorld), seatH)

        -- Cup holder in the wood track
        local cupLocal = p + inward * (seatRadius - (b - 0.6))
        cylUp(pos(cupLocal.X, ht + 0.03, cupLocal.Z), 0.06, 0.75, GOLD)
        cylUp(pos(cupLocal.X, ht + 0.05, cupLocal.Z), 0.06, 0.6, BLACK)

        if CARDS_AND_CHIPS then
            local seatFelt = p + inward * (seatRadius - (b - 2.1))
            local sideways = inward:Cross(UP)
            local cardCF = CFrame.lookAt(pos(seatFelt.X, ht + 0.02, seatFelt.Z), pos(seatFelt.X, ht + 0.02, seatFelt.Z) + inwardWorld)
            faceDownCard(cardCF * CFrame.new(-0.25, 0, 0) * CFrame.Angles(0, math.rad(-8), 0))
            faceDownCard(cardCF * CFrame.new(0.25, 0.04, 0) * CFrame.Angles(0, math.rad(8), 0))
            local chips = p + inward * (seatRadius - (b - 1.4))
            chipStack(pos(chips.X + sideways.X * 0.5, ht, chips.Z + sideways.Z * 0.5), rng:NextInteger(3, 8))
            chipStack(pos(chips.X - sideways.X * 0.5, ht, chips.Z - sideways.Z * 0.5), rng:NextInteger(2, 6))
        end
    end

    if CARDS_AND_CHIPS then
        -- Community cards and the pot
        local towardPlayers = T:VectorToWorldSpace(V(0, 0, 1))
        for i = -2, 2 do
            local p = pos(i * 0.85, ht + 0.02, 0.6)
            faceUpCard(CFrame.lookAt(p, p - towardPlayers))
        end
        for i = -1, 1 do
            chipStack(pos(i * 0.8, ht, -0.8), rng:NextInteger(3, 7))
        end

        -- Dealer chip rack, deck and button
        local rackZ = -(b - 1.9)
        box(at(0, ht + 0.2, rackZ), V(2.8, 0.3, 1.0), BLACK)
        for i = -3, 3 do
            local color = CHIP_COLORS[(i + 4) % #CHIP_COLORS + 1]
            makePart({
                Shape = Enum.PartType.Cylinder,
                CFrame = at(i * 0.38, ht + 0.48, rackZ),
                Size = V(0.9, 0.34, 0.34),
            }, { Color = color, Material = Enum.Material.SmoothPlastic })
        end
        box(at(2.1, ht + 0.15, rackZ), V(0.7, 0.3, 1.0), WHITE)
        box(at(2.1, ht + 0.31, rackZ), V(0.58, 0.02, 0.88), CARD_RED)
        local button = cylUp(pos(-2.2, ht + 0.06, rackZ + 0.3), 0.12, 0.8, WHITE)
        local gui = Instance.new("SurfaceGui")
        gui.Face = Enum.NormalId.Right
        gui.Parent = button
        local label = Instance.new("TextLabel")
        label.Size = UDim2.fromScale(1, 1)
        label.BackgroundTransparency = 1
        label.Text = "DEALER"
        label.TextScaled = true
        label.Font = Enum.Font.GothamBlack
        label.TextColor3 = Color3.fromRGB(20, 20, 20)
        label.Parent = gui
    end

    -- Hanging lamp
    if PENDANT_LIGHT then
        local y = ht + 9
        box(at(0, y, 0), V(2 * a * 0.7, 0.7, 2 * b * 0.45), MAHOGANY)
        box(at(0, y - 0.38, 0), V(2 * a * 0.7 + 0.1, 0.08, 2 * b * 0.45 + 0.1), GOLD)
        box(at(0, y - 0.4, 0), V(2 * a * 0.65, 0.05, 2 * b * 0.38), NEON_WARM)
        for _, x in ipairs(c > 1 and { -a * 0.35, a * 0.35 } or { -b * 0.3, b * 0.3 }) do
            local holder = box(at(x, y - 0.42, 0), V(0.2, 0.05, 0.2), NEON_WARM)
            local spot = Instance.new("SpotLight")
            spot.Face = Enum.NormalId.Bottom
            spot.Color = Color3.fromRGB(255, 230, 190)
            spot.Brightness = 2.5
            spot.Range = 16
            spot.Angle = 100
            spot.Parent = holder
            -- [REX] hang from the ceiling rather than stopping 15 studs up
            local start = pos(x, y + 0.35, 0)
            local ceiling = ceilingAbove(start + V(0, 0.5, 0), ignoreForCeiling)
            local topY = ceiling and math.min(ceiling, start.Y + 80) or start.Y + 15
            rod(start, V(start.X, topY, start.Z), 0.1, GOLD)
        end
    end
end

----------------------------------------------------------------
-- Find each poker table, hide the old look, build the new one
----------------------------------------------------------------
-- [REX] parented in the Casino folder like the other builds
local casinoRoot = workspace:FindFirstChild("Casino") or workspace
local newFolder = workspace:FindFirstChild("LuxuryPoker", true) or Instance.new("Folder")
newFolder.Name = "LuxuryPoker"
newFolder.Parent = casinoRoot
local luxChairs = casinoRoot:FindFirstChild("LuxuryChairs") or workspace:FindFirstChild("LuxuryChairs", true)

local function isPoker(inst)
    if not inst:IsA("Model") or not string.find(string.lower(inst.Name), "poker") then
        return false
    end
    if inst:IsDescendantOf(newFolder) then
        return false
    end
    -- [REX] GetDescendants() is a snapshot and chair models are destroyed
    -- while we walk it; a destroyed model is no longer in the game
    if not inst:IsDescendantOf(game) then
        return false
    end
    -- [REX] the chairs script names its models PokerTable_Chairs, which
    -- matched "poker" and got treated as a table
    if luxChairs and inst:IsDescendantOf(luxChairs) then
        return false
    end
    return true
end

-- the lamp rods look for the ceiling straight through the tables and lamps
ignoreForCeiling = { newFolder }
for _, d in ipairs(workspace:GetDescendants()) do
    if isPoker(d) then
        table.insert(ignoreForCeiling, d)
    end
end
if luxChairs then
    table.insert(ignoreForCeiling, luxChairs)
end

local count = 0
for _, model in ipairs(workspace:GetDescendants()) do
    if isPoker(model) and not (model.Parent and model.Parent:FindFirstAncestorWhichIsA("Model") and isPoker(model.Parent)) then
        local infos, floorY = {}, math.huge
        for _, p in ipairs(model:GetDescendants()) do
            if p:IsA("BasePart") then
                local mn, mx = bounds(p)
                table.insert(infos, { part = p, mn = mn, mx = mx })
                floorY = math.min(floorY, mn.Y)
            end
        end

        -- The table top is the biggest piece at table height
        local top, bestArea = nil, 0
        for _, info in ipairs(infos) do
            local height = info.mx.Y - floorY
            local area = (info.mx.X - info.mn.X) * (info.mx.Z - info.mn.Z)
            if height >= 2 and height <= 5 and area > bestArea then
                top, bestArea = info, area
            end
        end

        if not top then
            warn("[Poker] Couldn't find the table top in " .. model:GetFullName())
        else
            local sizeX, sizeZ = top.mx.X - top.mn.X, top.mx.Z - top.mn.Z
            local center = flat((top.mn + top.mx) / 2)
            local longAxis = sizeX >= sizeZ and V(1, 0, 0) or V(0, 0, 1)
            local a = math.max(sizeX, sizeZ) / 2
            local b = math.min(sizeX, sizeZ) / 2
            if a - b < 0.15 * a then
                a = b -- round table
            end
            b = math.max(b, 4)
            a = math.max(a, b)
            local ht = math.clamp(top.mx.Y - floorY, 3, 4.5)
            local T = CFrame.fromMatrix(V(center.X, floorY, center.Z), longAxis, UP)

            -- [REX] drop the previous build for this table, so a second run
            -- replaces it instead of stacking another one on top
            for _, old in ipairs(newFolder:GetChildren()) do
                local link = old:FindFirstChild("OriginalTable")
                if link and link.Value == model then
                    old:Destroy()
                end
            end

            -- Remove the chairs another script put here (they were facing the wrong way)
            -- [REX] LuxuryChairs is in the Casino folder, not the Workspace root
            if luxChairs then
                for _, chairs in ipairs(luxChairs:GetChildren()) do
                    local lp = T:PointToObjectSpace(chairs:GetPivot().Position)
                    if math.abs(lp.X) < a + 5 and math.abs(lp.Z) < b + 5 then
                        chairs:Destroy()
                    end
                end
            end

            -- Hide the old look (parts stay in place so prompts and scripts keep working)
            for _, d in ipairs(model:GetDescendants()) do
                if d:IsA("BasePart") then
                    -- [REX] only record the original once, or a re-run saves the
                    -- hidden 1 as "the original"
                    if d:GetAttribute("OldTransparency") == nil then
                        d:SetAttribute("OldTransparency", d.Transparency)
                        d:SetAttribute("OldCanCollide", d.CanCollide)
                    end
                    d.Transparency = 1
                    d.CanCollide = false
                elseif d:IsA("Decal") or d:IsA("Texture") then
                    d.Transparency = 1
                elseif d:IsA("SurfaceGui") then
                    d.Enabled = false
                end
            end

            current = Instance.new("Model")
            current.Name = model.Name .. "_Luxury"
            local link = Instance.new("ObjectValue")
            link.Name = "OriginalTable"
            link.Value = model
            link.Parent = current
            current.Parent = newFolder
            buildPoker(T, a, b, ht)
            count += 1
        end
    end
end

local parts = 0
for _, d in ipairs(newFolder:GetDescendants()) do
    if d:IsA("BasePart") then
        parts = parts + 1
    end
end
print(string.format("[Poker] Upgraded %d poker table(s) | %d parts", count, parts))
