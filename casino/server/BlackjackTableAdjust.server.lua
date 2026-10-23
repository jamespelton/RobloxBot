-- BLACKJACK TABLE + CHAIR ADJUST v5 (Script in ServerScriptService)
-- Gives every blackjack table 8 seats and places them in a curve around it.
-- Settings:
local SEATS_PER_TABLE = 8 -- how many players can play at one table
local TABLE_RAISE = 1.2   -- how many studs to move the table UP
local CHAIR_DROP = 0.8    -- how many studs to move the chairs DOWN
local ARC_ANGLE = 170     -- how wide the curve of chairs is (degrees). 180 = half circle
local CHAIR_OUT = 2.0     -- how far each seat sits from the table edge (studs)
local MAX_TURN = 6        -- small random turn so they don't look perfect (degrees)
local MAX_SHIFT = 0.2     -- small random nudge (studs)
local MAX_TILT = 1.5      -- tiny lean (degrees)
local GAP = 0.25          -- smallest space allowed between two chairs (studs)
local PLAYER_SIDE = 1.0   -- every chair stays at least this far on the players' side (the game hides seats on the dealer's side)
local REMOVE_SIT_PROMPT = true -- removes the "Sit & Play" button
local CLICK_DISTANCE = 12 -- how close you need to be to click a chair and sit

local V = Vector3.new
local UP = V(0, 1, 0)
local function flat(v)
    return V(v.X, 0, v.Z)
end

-- The table models are rotated (their box's X is actually the height), so measure
-- each table along the world's X / Y / Z instead
local function worldBox(model)
    local cf, size = model:GetBoundingBox()
    local function along(axis)
        return math.abs(cf.RightVector:Dot(axis)) * size.X
            + math.abs(cf.UpVector:Dot(axis)) * size.Y
            + math.abs(cf.LookVector:Dot(axis)) * size.Z
    end
    return CFrame.new(cf.Position), V(along(V(1, 0, 0)), along(UP), along(V(0, 0, 1)))
end

----------------------------------------------------------------
-- Remove the "Sit & Play" button (you sit by clicking a chair instead)
----------------------------------------------------------------
local function removePrompt(d)
    if REMOVE_SIT_PROMPT and d:IsA("ProximityPrompt") and (d.Name == "BlackjackJoinPrompt" or d.ActionText == "Sit & Play") then
        task.defer(function()
            d:Destroy()
        end)
    end
end
for _, d in ipairs(workspace:GetDescendants()) do
    removePrompt(d)
end
workspace.DescendantAdded:Connect(removePrompt)

-- Wait for the chair and table scripts to finish building (the blackjack game starts at 6 seconds)
task.wait(3)

----------------------------------------------------------------
-- Find the tables and seats
----------------------------------------------------------------
local tables = {}
for _, m in ipairs(workspace:GetDescendants()) do
    if m:IsA("Model") then
        local name = string.lower(m.Name)
        if string.find(name, "blackjack") and not string.find(name, "_chairs") and not string.find(name, "blackjackgame") and not string.find(name, "extra") then
            local cf, size = worldBox(m)
            table.insert(tables, { model = m, cf = cf, size = size, seats = {}, chairs = {} })
        end
    end
end
local function inTable(part)
    for _, t in ipairs(tables) do
        if part:IsDescendantOf(t.model) then
            return true
        end
    end
    return false
end

for _, s in ipairs(workspace:GetDescendants()) do
    if s:IsA("Seat") then
        local best, bestDistance
        for _, t in ipairs(tables) do
            local d = flat(s.Position - t.cf.Position).Magnitude
            if d <= math.max(t.size.X, t.size.Z) / 2 + 8 and math.abs(s.Position.Y - t.cf.Position.Y) < 8 and (not bestDistance or d < bestDistance) then
                best, bestDistance = t, d
            end
        end
        if best then
            table.insert(best.seats, s)
        end
    end
end

-- The stool on the dealer's side stays put - the blackjack game hides it and stands
-- the dealer there (same rule the game uses: seats on the far side from the rest)
local allChairs = {}
for _, t in ipairs(tables) do
    local center = flat(t.cf.Position)
    local avg = V(0, 0, 0)
    for _, s in ipairs(t.seats) do
        local out = flat(s.Position) - center
        if out.Magnitude > 0.01 then
            avg += out.Unit
        end
    end
    local dealerDir = avg.Magnitude > 0.01 and -avg.Unit or V(0, 0, -1)
    for _, s in ipairs(t.seats) do
        if (flat(s.Position) - center):Dot(dealerDir) <= 0 then
            local chair = { seat = s, table = t, parts = {}, start = s.Position }
            table.insert(t.chairs, chair)
            table.insert(allChairs, chair)
        end
    end
end

-- Find which parts belong to each chair (the parts closest to that seat)
for _, p in ipairs(workspace:GetDescendants()) do
    if p:IsA("BasePart") and p.Anchored and not inTable(p) then
        local isHuge = math.max(p.Size.X, p.Size.Y, p.Size.Z) > 9
        local model = p:FindFirstAncestorOfClass("Model")
        local isCharacter = model and model:FindFirstChildOfClass("Humanoid")
        if not isHuge and not isCharacter then
            local best, bestDistance
            for _, chair in ipairs(allChairs) do
                local offset = p.Position - chair.start
                local d = flat(offset).Magnitude
                if d < 2.8 and offset.Y > -5 and offset.Y < 6 and (not bestDistance or d < bestDistance) then
                    best, bestDistance = chair, d
                end
            end
            if best then
                table.insert(best.parts, p)
            end
        end
    end
end

----------------------------------------------------------------
-- Raise the tables
----------------------------------------------------------------
for _, t in ipairs(tables) do
    for _, p in ipairs(t.model:GetDescendants()) do
        if p:IsA("BasePart") and p.Anchored then
            p.CFrame = p.CFrame + V(0, TABLE_RAISE, 0)
        end
    end
    t.cf, t.size = worldBox(t.model)
end

----------------------------------------------------------------
-- Work out each chair's size and which way it faces now
----------------------------------------------------------------
for _, chair in ipairs(allChairs) do
    local seatPos = chair.start
    local radius = 1
    local backSum, backCount = V(0, 0, 0), 0
    for _, p in ipairs(chair.parts) do
        radius = math.max(radius, flat(p.Position - seatPos).Magnitude + math.max(p.Size.X, p.Size.Z) * 0.4)
        if p.Position.Y > seatPos.Y + 1.2 then
            backSum += p.Position
            backCount += 1
        end
    end
    chair.radius = math.min(radius, 2.6)
    -- The chair faces away from its back
    local forward
    if backCount > 0 then
        forward = flat(seatPos - backSum / backCount)
    end
    if not forward or forward.Magnitude < 0.2 then
        forward = flat(chair.seat.CFrame.LookVector)
    end
    chair.forward = forward.Unit
end

----------------------------------------------------------------
-- Add extra chairs (copies of the ones already there) until each table has enough
----------------------------------------------------------------
local extraFolder = workspace:FindFirstChild("ExtraBlackjackChairs") or Instance.new("Folder")
extraFolder.Name = "ExtraBlackjackChairs"
extraFolder.Parent = workspace

local function cleanCopy(c)
    c.Anchored = true
    for _, d in ipairs(c:GetDescendants()) do
        if d:IsA("JointInstance") or d:IsA("WeldConstraint") then
            d:Destroy()
        end
    end
end

local added = 0
for _, t in ipairs(tables) do
    local originals = table.clone(t.chairs)
    local n = 0
    while #originals > 0 and #t.chairs < SEATS_PER_TABLE do
        n += 1
        local original = originals[(n - 1) % #originals + 1]
        local model = Instance.new("Model")
        model.Name = "ExtraChair"
        model.Parent = extraFolder
        local copy = { table = t, parts = {}, start = original.start, radius = original.radius, forward = original.forward }
        for _, p in ipairs(original.parts) do
            local c = p:Clone()
            cleanCopy(c)
            c.Parent = model
            table.insert(copy.parts, c)
            if p == original.seat then
                copy.seat = c
            end
        end
        if not copy.seat then
            local c = original.seat:Clone()
            cleanCopy(c)
            c.CFrame = original.seat.CFrame
            c.Parent = model
            table.insert(copy.parts, c)
            copy.seat = c
        end
        copy.seat.Disabled = false
        table.insert(t.chairs, copy)
        table.insert(allChairs, copy)
        added += 1
    end
end

----------------------------------------------------------------
-- Place the chairs in a curve around each table
----------------------------------------------------------------
for _, t in ipairs(tables) do
    local chairs = t.chairs
    if #chairs > 0 then
        local center = flat(t.cf.Position)
        local tableOnly = RaycastParams.new()
        tableOnly.FilterType = Enum.RaycastFilterType.Include
        tableOnly.FilterDescendantsInstances = { t.model }
        local top = workspace:Raycast(t.cf.Position + V(0, t.size.Y / 2 + 5, 0), V(0, -(t.size.Y + 10), 0), tableOnly)
        local feltY = top and top.Position.Y or (t.cf.Position.Y + t.size.Y / 2)
        local reach = math.max(t.size.X, t.size.Z) / 2 + 10

        -- The players' side is where the chairs are now
        local avg = V(0, 0, 0)
        for _, chair in ipairs(chairs) do
            avg += flat(chair.start) - center
        end
        local toPlayers = avg.Magnitude > 0.01 and avg.Unit or V(0, 0, 1)
        local right = toPlayers:Cross(UP)

        -- Keep the same left-to-right order the chairs had before
        table.sort(chairs, function(a, b)
            return (flat(a.start) - center):Dot(right) < (flat(b.start) - center):Dot(right)
        end)

        -- Where the table edge is in a given direction
        local function edgeAt(dir)
            local from = V(center.X, feltY - 0.4, center.Z) + dir * reach
            local hit = workspace:Raycast(from, -dir * reach * 2, tableOnly)
            if hit then
                return flat(hit.Position)
            end
            return center + dir * (math.max(t.size.X, t.size.Z) / 2)
        end

        local arc = math.rad(ARC_ANGLE)
        for i, chair in ipairs(chairs) do
            local rng = Random.new(math.floor(chair.start.X * 7 + chair.start.Z * 13) + i * 31)
            local f = #chairs == 1 and 0.5 or (i - 1) / (#chairs - 1)
            local angle = -arc / 2 + arc * f
            local dir = (toPlayers * math.cos(angle) + right * math.sin(angle)).Unit
            local edge = edgeAt(dir)
            chair.pos = edge + dir * (CHAIR_OUT + rng:NextNumber(0, 0.25)) + dir:Cross(UP) * rng:NextNumber(-MAX_SHIFT, MAX_SHIFT)
            chair.center = center
            chair.toPlayers = toPlayers
            chair.minFromTable = flat(edge - center).Magnitude + 1
            chair.facing = -dir
            chair.extraTurn = math.rad(rng:NextNumber(-MAX_TURN, MAX_TURN))
            chair.tiltX = math.rad(rng:NextNumber(-MAX_TILT, MAX_TILT))
            chair.tiltZ = math.rad(rng:NextNumber(-MAX_TILT, MAX_TILT))
        end
    end
end

----------------------------------------------------------------
-- Slide chairs apart until none of them overlap
----------------------------------------------------------------
local settled = false
for _ = 1, 80 do
    local anyOverlap = false
    for a = 1, #allChairs do
        for b = a + 1, #allChairs do
            local A, B = allChairs[a], allChairs[b]
            if A.table == B.table and A.pos and B.pos then
                local between = B.pos - A.pos
                local distance = between.Magnitude
                local needed = A.radius + B.radius + GAP
                if distance < needed then
                    anyOverlap = true
                    local pushDir = distance > 0.01 and between.Unit or (A.pos - A.center):Cross(UP).Unit
                    local push = pushDir * ((needed - distance) / 2 + 0.01)
                    A.pos -= push
                    B.pos += push
                end
            end
        end
    end
    for _, chair in ipairs(allChairs) do
        if chair.pos then
            local fromTable = chair.pos - chair.center
            if fromTable.Magnitude < chair.minFromTable then
                chair.pos = chair.center + fromTable.Unit * chair.minFromTable
            end
            -- ...or around to the dealer's side
            local side = (chair.pos - chair.center):Dot(chair.toPlayers)
            if side < PLAYER_SIDE then
                chair.pos += chair.toPlayers * (PLAYER_SIDE - side)
            end
        end
    end
    if not anyOverlap then
        settled = true
        break
    end
end

----------------------------------------------------------------
-- Move every chair to its new spot, turned to face the table
----------------------------------------------------------------
local moved = 0
for _, chair in ipairs(allChairs) do
    if chair.pos then
        local seatPos = chair.start
        local facing = flat(chair.center - chair.pos).Unit
        local turn = math.atan2(chair.forward:Cross(facing).Y, chair.forward:Dot(facing)) + chair.extraTurn
        local target = V(chair.pos.X, seatPos.Y - CHAIR_DROP, chair.pos.Z)
        local move = CFrame.new(target)
            * CFrame.Angles(chair.tiltX, 0, chair.tiltZ)
            * CFrame.Angles(0, turn, 0)
            * CFrame.new(-seatPos)
        for _, p in ipairs(chair.parts) do
            p.CFrame = move * p.CFrame
        end
        moved += 1
    end
end

----------------------------------------------------------------
-- Click (or tap) a chair to sit in it - replaces the "Sit & Play" button
-- (the seat pad is invisible, so the cushion on top of it is clickable too)
----------------------------------------------------------------
if REMOVE_SIT_PROMPT then
    for _, chair in ipairs(allChairs) do
        local seat = chair.seat
        local function sitDown(plr)
            local humanoid = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
            if humanoid and humanoid.Health > 0 and not seat.Occupant and not humanoid.SeatPart then
                seat:Sit(humanoid)
            end
        end
        for _, p in ipairs(chair.parts) do
            if p == seat or p.Name == "Cushion" then
                local click = Instance.new("ClickDetector")
                click.MaxActivationDistance = CLICK_DISTANCE
                click.Parent = p
                click.MouseClick:Connect(sitDown)
            end
        end
    end
end

print("[Blackjack] " .. #tables .. " table(s): added " .. added .. " chair(s), " .. moved .. " seats total" .. (settled and "" or " (some chairs may still touch)"))
