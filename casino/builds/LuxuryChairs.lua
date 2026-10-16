-- LUXURY CASINO CHAIRS (replaces the chairs and benches at your tables)
-- Written by James. Changes are marked [REX]:
--
--   1. THIRTY CHAIRS PER TABLE. The chairs here are not models - each one is
--      five loose parts (ChairFoot, ChairPost, ChairSeat, ChairTrim, ChairBack)
--      plus a SitPad Seat, all direct children of the table. The original made
--      one group per name-matching part, so a six-seat blackjack table produced
--      thirty groups and thirty luxury chairs stacked on each other. Chairs are
--      now anchored on the seat pads, with every other piece handed to its
--      nearest one. Measured first: chairs sit 2.65 studs apart and a back is
--      1.20 from its own seat, so nearest-anchor is unambiguous.
--   2. SitPad matched none of the chair words, so the old Seats would have been
--      left behind - invisible pads floating inside the new chairs, which the
--      player would still sit on. "sitpad" and "pad" are chair words now.
--   3. floorY came from the lowest part of the WHOLE table, which here is a
--      collider at y -3.62, nowhere near the floor the chairs stand on at y 0.
--      Seat height is measured per chair off its own foot instead; otherwise
--      every chair came out at the 4-stud clamp instead of its real 3.1.
--   4. The seat was built by cyl(), which turns the part 90 degrees about Z to
--      stand the cylinder up. A Seat places the sitter using its own
--      orientation, so players would have sat lying on their side. The seat is
--      now its own upright invisible block, square to the chair and facing the
--      table.
--   5. The previous LuxuryChairs folder is destroyed before anything is
--      measured, and OldChairsBackup is reused rather than a second folder of
--      the same name being made on every run.
--   6. Parented into the Casino folder, like the other builds.
--
-- Safe for the games: nothing in TableGames, SlotService, CasinoCore or any
-- client script references SitPad, Chair, Seat or Occupant - blackjack is
-- driven by ProximityPrompts, so swapping the furniture cannot break it.

-- Settings:
local DETAIL = "high"          -- "high" or "low" (low = fewer parts, less lag)
local SITTABLE = true          -- players can sit in the new chairs
local LEATHER_COLOR = Color3.fromRGB(140, 15, 25)
local REMOVE_OLD = true        -- moves old chairs to ServerStorage > OldChairsBackup

local ServerStorage = game:GetService("ServerStorage")
local V = Vector3.new
local UP = V(0, 1, 0)

----------------------------------------------------------------
-- Find the tables
----------------------------------------------------------------
-- [REX] The previous run is deliberately NOT destroyed here. REMOVE_OLD moves
-- the original chairs into ServerStorage, so a second run finds nothing left to
-- replace - and having already deleted the old folder, it would leave the
-- tables with no chairs at all. The old folder is removed at the very end, and
-- only once new chairs actually exist. It sits under Casino rather than inside
-- the table models, so leaving it in place cannot affect the measuring.
local previous = workspace:FindFirstChild("LuxuryChairs", true)

local tables = {}
local tablesFolder = workspace:FindFirstChild("Tables", true)
if tablesFolder then
    for _, m in ipairs(tablesFolder:GetChildren()) do
        if m:IsA("Model") then
            table.insert(tables, m)
        end
    end
else
    for _, m in ipairs(workspace:GetDescendants()) do
        if m:IsA("Model") and string.find(string.lower(m.Name), "table") then
            table.insert(tables, m)
        end
    end
end
if #tables == 0 then
    error("[Chairs] Couldn't find any tables. Put your table models in a folder called 'Tables'.")
end

----------------------------------------------------------------
-- Materials
----------------------------------------------------------------
local LEATHER = { Color = LEATHER_COLOR, Material = Enum.Material.Leather }
local LEATHER_DARK = { Color = LEATHER_COLOR:Lerp(Color3.new(0, 0, 0), 0.35), Material = Enum.Material.Leather }
local GOLD = { Color = Color3.fromRGB(212, 175, 55), Material = Enum.Material.Metal, Reflectance = 0.35 }
local MAHOGANY = { Color = Color3.fromRGB(75, 30, 22), Material = Enum.Material.Wood }
local BLACK = { Color = Color3.fromRGB(20, 20, 22), Material = Enum.Material.SmoothPlastic }

----------------------------------------------------------------
-- Helpers
----------------------------------------------------------------
local currentModel
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
    p.Parent = currentModel
    return p
end

local function box(cf, size, style, extra)
    local props = { CFrame = cf, Size = size }
    if extra then
        for k, v in pairs(extra) do
            props[k] = v
        end
    end
    return makePart(props, style)
end

local function ball(pos, size, style)
    return makePart({ Shape = Enum.PartType.Ball, CFrame = CFrame.new(pos), Size = V(size, size, size) }, style)
end

-- Upright cylinder at a position in the chair's frame
local function cyl(base, localPos, height, width, style, className)
    return makePart({
        Shape = Enum.PartType.Cylinder,
        CFrame = base * CFrame.new(localPos) * CFrame.Angles(0, 0, math.rad(90)),
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
-- New chair (base = floor point under the seat, -Z faces the table)
----------------------------------------------------------------
local function buildChair(base, h)
    local high = DETAIL == "high"
    -- Base, swivel post
    cyl(base, V(0, 0.12, 0), 0.25, 2.4, GOLD).CanCollide = true
    cyl(base, V(0, 0.3, 0), 0.12, 1.8, BLACK)
    cyl(base, V(0, (0.35 + h - 1) / 2, 0), h - 1.35, 0.4, GOLD).CanCollide = true
    cyl(base, V(0, h - 0.95, 0), 0.15, 1.2, GOLD)

    -- Footrest ring
    if high then
        local ringY = h * 0.42
        local last
        for i = 0, 8 do
            local a = i / 8 * math.pi * 2
            local point = base * V(math.cos(a) * 1.0, ringY, math.sin(a) * 1.0)
            if last then
                rod(last, point, 0.12, GOLD)
            end
            last = point
        end
        rod(base * V(0, ringY, 0), base * V(1.0, ringY, 0), 0.1, GOLD)
        rod(base * V(0, ringY, 0), base * V(-1.0, ringY, 0), 0.1, GOLD)
    end

    -- Seat cushion with gold piping and wood rim
    local cushion = cyl(base, V(0, h - 0.275, 0), 0.55, 2.5, LEATHER)
    cushion.CanCollide = true
    cushion.Name = "Cushion"
    -- [REX] The seat has to be its own upright part. cyl() turns the part 90
    -- degrees about Z to stand the cylinder on end, and a Seat uses its own
    -- orientation to place whoever sits in it, so passing "Seat" to cyl() sat
    -- the player on their side. This block is invisible, square to the chair,
    -- and its LookVector points at the table, so the sitter faces the game.
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
        seat.Parent = currentModel
    end
    cyl(base, V(0, h - 0.55, 0), 0.08, 2.56, GOLD)
    cyl(base, V(0, h - 0.72, 0), 0.3, 2.3, MAHOGANY)
    if high then
        for _, offset in ipairs({ V(0, 0, 0), V(0.6, 0, 0), V(-0.6, 0, 0), V(0, 0, 0.6), V(0, 0, -0.6) }) do
            ball(base * (V(0, h + 0.01, 0) + offset), 0.16, GOLD)
        end
    end

    -- Curved backrest
    local R = 1.15
    local backH = 2.8
    local backBottom = h - 0.2
    local angles = high and { -60, -30, 0, 30, 60 } or { -40, 0, 40 }
    local sliceW = 2 * math.pi * R * ((high and 30 or 40) / 360) + 0.06
    local center = base * V(0, backBottom + backH / 2, 0)
    for _, deg in ipairs(angles) do
        local a = math.rad(deg)
        local pos = base * V(math.sin(a) * R, backBottom + backH / 2, math.cos(a) * R)
        local slice = box(CFrame.lookAt(pos, V(center.X, pos.Y, center.Z)), V(sliceW, backH, 0.38), LEATHER)
        slice.CanCollide = true
        if high then
            local shellPos = base * V(math.sin(a) * (R + 0.24), backBottom + backH / 2, math.cos(a) * (R + 0.24))
            box(CFrame.lookAt(shellPos, V(center.X, shellPos.Y, center.Z)), V(sliceW, backH + 0.1, 0.12), MAHOGANY)
        end
    end

    -- Gold piping along the top and bottom of the backrest
    local first, last = math.rad(angles[1] - 15), math.rad(angles[#angles] + 15)
    local steps = high and 6 or 3
    for _, y in ipairs(high and { backBottom + backH, backBottom } or { backBottom + backH }) do
        local prev
        for i = 0, steps do
            local a = first + (last - first) * i / steps
            local point = base * V(math.sin(a) * R, y, math.cos(a) * R)
            if prev then
                rod(prev, point, 0.22, GOLD)
            end
            prev = point
        end
    end

    if high then
        -- Tufting buttons on the backrest
        for _, deg in ipairs({ -30, 0, 30 }) do
            local a = math.rad(deg)
            for _, y in ipairs({ backBottom + backH * 0.4, backBottom + backH * 0.72 }) do
                ball(base * V(math.sin(a) * (R - 0.2), y, math.cos(a) * (R - 0.2)), 0.16, GOLD)
            end
        end
        -- Gold supports from the seat to the backrest
        for _, x in ipairs({ -0.5, 0.5 }) do
            rod(base * V(x, h - 0.6, 0.5), base * V(x * 1.1, backBottom + 0.3, R), 0.14, GOLD)
        end
    end
end

----------------------------------------------------------------
-- New bench (base = floor point under the seat center, length along X, -Z faces the table)
----------------------------------------------------------------
local function buildBench(base, h, length, depth)
    local high = DETAIL == "high"
    depth = math.max(depth, 2.4)
    -- Wood base and gold kick strip
    box(base * CFrame.new(0, (h - 0.55) / 2, 0.15), V(length, h - 0.55, depth - 0.3), MAHOGANY).CanCollide = true
    box(base * CFrame.new(0, 0.4, -(depth - 0.3) / 2 + 0.13), V(length, 0.15, 0.05), GOLD)

    -- Seat cushions
    local n = math.max(1, math.floor(length / 2.6 + 0.5))
    for i = 0, n - 1 do
        local x = -length / 2 + (i + 0.5) * length / n
        local cushion = box(base * CFrame.new(x, h - 0.275, 0), V(length / n - 0.08, 0.55, depth), LEATHER, nil)
        cushion.CanCollide = true
        if SITTABLE then
            local seat = Instance.new("Seat")
            seat.Anchored = true
            seat.Size = cushion.Size
            seat.CFrame = cushion.CFrame
            seat.Color = cushion.Color
            seat.Material = cushion.Material
            seat.TopSurface = Enum.SurfaceType.Smooth
            seat.BottomSurface = Enum.SurfaceType.Smooth
            seat.Parent = currentModel
            cushion:Destroy()
        end
    end
    box(base * CFrame.new(0, h - 0.55, -depth / 2), V(length, 0.08, 0.08), GOLD)

    -- Tall channel-tufted back
    local backH = 3.2
    box(base * CFrame.new(0, h - 0.1 + (backH + 0.2) / 2, depth / 2 + 0.25), V(length, backH + 0.2, 0.25), MAHOGANY).CanCollide = true
    local channels = math.max(2, math.floor(length / (high and 1 or 1.8)))
    local cw = length / channels
    for i = 0, channels - 1 do
        local x = -length / 2 + (i + 0.5) * cw
        box(base * CFrame.new(x, h - 0.1 + backH / 2, depth / 2 - 0.12), V(cw - 0.08, backH, 0.5), i % 2 == 0 and LEATHER or LEATHER_DARK).CanCollide = true
        if high and i > 0 then
            ball(base * V(x - cw / 2, h + backH * 0.55, depth / 2 - 0.4), 0.16, GOLD)
        end
    end
    box(base * CFrame.new(0, h - 0.1 + backH + 0.15, depth / 2 + 0.1), V(length + 0.3, 0.3, 0.9), MAHOGANY)
    box(base * CFrame.new(0, h - 0.1 + backH + 0.31, depth / 2 - 0.2), V(length + 0.3, 0.04, 0.12), GOLD)

    -- Arm panels at each end
    for _, side in ipairs({ -1, 1 }) do
        local x = side * (length / 2 + 0.18)
        box(base * CFrame.new(x, (h + 1.2) / 2, 0.1), V(0.35, h + 1.2, depth + 0.5), MAHOGANY).CanCollide = true
        box(base * CFrame.new(x + side * 0.19, (h + 1.2) / 2, 0.1), V(0.04, (h + 1.2) * 0.7, depth - 0.3), GOLD)
        box(base * CFrame.new(x, h + 1.25, 0.1), V(0.45, 0.1, depth + 0.6), GOLD)
    end
end

----------------------------------------------------------------
-- Find the chairs in a table and replace them
----------------------------------------------------------------
-- [REX] "sitpad" and "pad" added. Without them the old Seat objects stayed
-- behind, floating invisibly inside the new chairs for players to sit on.
local NAME_WORDS = { "chair", "seat", "stool", "bench", "sofa", "couch", "booth", "sitpad", "pad" }
local function chairName(inst)
    local name = string.lower(inst.Name)
    for _, word in ipairs(NAME_WORDS) do
        if string.find(name, word) then
            return true
        end
    end
    return false
end

-- [REX] reuse the backup folder instead of adding another on every run
local backup = ServerStorage:FindFirstChild("OldChairsBackup")
if not backup then
    backup = Instance.new("Folder")
    backup.Name = "OldChairsBackup"
    backup.Parent = ServerStorage
end

local newFolder = Instance.new("Folder")
newFolder.Name = "LuxuryChairs"
newFolder.Parent = workspace:FindFirstChild("Casino") or workspace

local chairsMade, benchesMade = 0, 0

-- [REX] indexed, because several tables share a name. The backup used the
-- name alone, so all six BlackjackTables emptied into one folder and there
-- was no way to tell which chair came from which table if you ever wanted
-- them back.
for tableIndex, tableModel in ipairs(tables) do
    local infos = {}
    local tableLow = math.huge
    for _, p in ipairs(tableModel:GetDescendants()) do
        if p:IsA("BasePart") then
            local mn, mx = bounds(p)
            table.insert(infos, { part = p, mn = mn, mx = mx })
            tableLow = math.min(tableLow, mn.Y)
        end
    end

    local groups = {}
    local used = {}

    -- 1) Chairs that really are models
    for _, inst in ipairs(tableModel:GetDescendants()) do
        if inst:IsA("Model") and chairName(inst) then
            local parentIsChair = false
            local p = inst.Parent
            while p and p ~= tableModel do
                if chairName(p) then
                    parentIsChair = true
                    break
                end
                p = p.Parent
            end
            if not parentIsChair then
                local parts = {}
                for _, d in ipairs(inst:GetDescendants()) do
                    if d:IsA("BasePart") then
                        table.insert(parts, d)
                    end
                end
                if #parts > 0 then
                    table.insert(groups, { root = inst, parts = parts })
                    for _, part in ipairs(parts) do
                        used[part] = true
                    end
                end
            end
        end
    end

    -- 2) [REX] Loose chair parts, gathered around each seat pad. This is the
    -- case here: five parts and a Seat per chair, all children of the table.
    -- One group per name match would give a chair per PART, not per chair.
    local pieces, anchors = {}, {}
    for _, d in ipairs(tableModel:GetDescendants()) do
        if d:IsA("BasePart") and not used[d] and (chairName(d) or d:IsA("Seat")) then
            table.insert(pieces, d)
            if d:IsA("Seat") then
                table.insert(anchors, d)
            end
        end
    end
    if #anchors == 0 then
        for _, p in ipairs(pieces) do
            if string.find(string.lower(p.Name), "seat") then
                table.insert(anchors, p)
            end
        end
    end
    if #anchors > 0 then
        local byAnchor = {}
        for i = 1, #anchors do
            byAnchor[i] = {}
        end
        for _, piece in ipairs(pieces) do
            local best, bestD = nil, math.huge
            for i, a in ipairs(anchors) do
                local d = (flat(piece.Position) - flat(a.Position)).Magnitude
                if d < bestD then
                    best, bestD = i, d
                end
            end
            if best then
                table.insert(byAnchor[best], piece)
                used[piece] = true
            end
        end
        for i, parts in ipairs(byAnchor) do
            if #parts > 0 then
                table.insert(groups, { parts = parts, anchor = anchors[i] })
            end
        end
    end

    -- Center of the table (everything that isn't a chair)
    local tmn, tmx = V(math.huge, 0, math.huge), V(-math.huge, 0, -math.huge)
    for _, info in ipairs(infos) do
        if not used[info.part] then
            tmn, tmx = tmn:Min(info.mn), tmx:Max(info.mx)
        end
    end
    local tableCenter = tmn.X < math.huge and flat((tmn + tmx) / 2) or flat(tableModel:GetPivot().Position)

    currentModel = Instance.new("Model")
    currentModel.Name = tableModel.Name .. "_Chairs"
    currentModel.Parent = newFolder

    for _, group in ipairs(groups) do
        -- [REX] Floor under THIS chair, from its own lowest part. The whole
        -- table's lowest part is a collider at y -3.62 here, which made every
        -- seat height hit the 4-stud clamp instead of its real 3.1.
        local floorY = math.huge
        for _, part in ipairs(group.parts) do
            local mn = select(1, bounds(part))
            floorY = math.min(floorY, mn.Y)
        end
        if floorY == math.huge then
            floorY = tableLow
        end

        -- Work out the seat part, its height, and which way the chair faces
        local seat, back = group.seat, group.back
        if not seat then
            local bestArea = 0
            for _, part in ipairs(group.parts) do
                local mn, mx = bounds(part)
                local top = mx.Y - floorY
                local area = (mx.X - mn.X) * (mx.Z - mn.Z)
                if mx.Y - mn.Y <= 1.2 and top >= 1.3 and top <= 3.6 and area > bestArea then
                    seat, bestArea = part, area
                end
            end
            local tallest = 0
            for _, part in ipairs(group.parts) do
                local mn, mx = bounds(part)
                if part ~= seat and mx.Y - mn.Y > tallest then
                    back, tallest = part, mx.Y - mn.Y
                end
            end
        end

        local seatTop, center, long, depth, longAxis
        if seat then
            local mn, mx = bounds(seat)
            seatTop = mx.Y
            center = flat(seat.Position)
            if seat.Size.X >= seat.Size.Z then
                long, depth, longAxis = seat.Size.X, seat.Size.Z, flat(seat.CFrame.RightVector).Unit
            else
                long, depth, longAxis = seat.Size.Z, seat.Size.X, flat(seat.CFrame.LookVector).Unit
            end
        else
            local mn, mx = V(math.huge, math.huge, math.huge), V(-math.huge, -math.huge, -math.huge)
            for _, part in ipairs(group.parts) do
                local a, b = bounds(part)
                mn, mx = mn:Min(a), mx:Max(b)
            end
            seatTop = floorY + 2.4
            center = flat((mn + mx) / 2)
            long, depth = math.max(mx.X - mn.X, mx.Z - mn.Z), math.min(mx.X - mn.X, mx.Z - mn.Z)
            longAxis = (mx.X - mn.X) >= (mx.Z - mn.Z) and V(1, 0, 0) or V(0, 0, 1)
        end

        -- [REX] Which way the chair faces. The backrest is only a hint, and in
        -- this place it is an unreliable one: measured from each table centre,
        -- blackjack backs sit OUTSIDE their seat (7.40 vs 6.20) but poker and
        -- roulette backs sit INSIDE it (7.30 vs 8.50, and 9.35 vs 9.97). The
        -- old poker and roulette chairs were modelled facing away from their
        -- own table, and taking the back at face value copied that: 36 of 72
        -- new chairs came out backwards. The table is the reliable answer, so
        -- the back is used only while it agrees with it.
        local toTable = tableCenter - center
        local forward
        if back then
            forward = center - flat(back.Position)
        end
        if forward and forward.Magnitude > 0.3 and toTable.Magnitude > 0.5
            and forward.Unit:Dot(toTable.Unit) < 0 then
            forward = nil
        end
        if not forward or forward.Magnitude < 0.3 then
            forward = toTable
        end
        if forward.Magnitude < 0.01 then
            forward = V(0, 0, -1)
        end
        forward = forward.Unit

        local h = math.clamp(seatTop - floorY, 1.5, 4)
        local groundPos = V(center.X, floorY, center.Z)
        if long >= 4.5 then
            -- Bench: face straight out from its long side
            local perpendicular = longAxis:Cross(UP)
            if perpendicular:Dot(forward) < 0 then
                perpendicular = -perpendicular
            end
            buildBench(CFrame.lookAt(groundPos, groundPos + perpendicular), h, long, depth)
            benchesMade += 1
        else
            buildChair(CFrame.lookAt(groundPos, groundPos + forward), h)
            chairsMade += 1
        end

        -- Move the old chair out of the way
        if REMOVE_OLD then
            local destName = tableModel.Name .. "_" .. tableIndex
            local destination = backup:FindFirstChild(destName) or Instance.new("Folder")
            destination.Name = destName
            destination.Parent = backup
            if group.root and group.root:IsA("Model") then
                group.root.Parent = destination
            else
                for _, part in ipairs(group.parts) do
                    part.Parent = destination
                end
            end
        end
    end
end

-- [REX] only swap the old set out once the new one exists
if chairsMade + benchesMade == 0 then
    newFolder:Destroy()
    warn("[Chairs] Found no chairs to replace. The originals are already in "
        .. "ServerStorage.OldChairsBackup, so this run changed nothing. Put them "
        .. "back if you want to build again.")
    return
end
if previous then
    previous:Destroy()
end

local parts = 0
for _, d in ipairs(newFolder:GetDescendants()) do
    if d:IsA("BasePart") then
        parts = parts + 1
    end
end
print(string.format("[Chairs] Made %d chairs and %d benches at %d tables | %d parts",
    chairsMade, benchesMade, #tables, parts))
