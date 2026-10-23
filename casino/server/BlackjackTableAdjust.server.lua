-- BLACKJACK TABLE + CHAIR ADJUST v3 (Script in ServerScriptService)
-- Settings:
local TABLE_RAISE = 1.2   -- how many studs to move the table UP
local CHAIR_DROP = 0.8    -- how many studs to move the chairs DOWN
local MAX_TURN = 12       -- most a chair can be turned left or right (degrees)
local MAX_SHIFT = 0.4     -- most a chair can be nudged sideways (studs)
local MAX_PUSH = 0.8      -- most a chair can be pushed back from the table (studs)
local MAX_TILT = 1.5      -- tiny lean so they don't look perfect (degrees)
local GAP = 0.35          -- smallest space allowed between two chairs (studs)
local REMOVE_SIT_PROMPT = true -- removes the "Sit & Play" button
local CLICK_DISTANCE = 12 -- how close you need to be to click a chair and sit

local V = Vector3.new
local function flat(v)
    return V(v.X, 0, v.Z)
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
        if string.find(name, "blackjack") and not string.find(name, "_chairs") and not string.find(name, "blackjackgame") then
            local cf, size = m:GetBoundingBox()
            table.insert(tables, { model = m, cf = cf, size = size })
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

-- (the table pivots are rotated, so the box's X/Y/Z don't line up with the world - use the biggest side)
local allSeats = {}
for _, s in ipairs(workspace:GetDescendants()) do
    if s:IsA("Seat") then
        local best, bestDistance
        for _, t in ipairs(tables) do
            local d = flat(s.Position - t.cf.Position).Magnitude
            local reach = math.max(t.size.X, t.size.Y, t.size.Z) / 2 + 6
            if d <= reach and math.abs(s.Position.Y - t.cf.Position.Y) < 8 and (not bestDistance or d < bestDistance) then
                best, bestDistance = t, d
            end
        end
        if best then
            table.insert(allSeats, { seat = s, table = best, parts = {} })
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
            for _, info in ipairs(allSeats) do
                local offset = p.Position - info.seat.Position
                local d = flat(offset).Magnitude
                if d < 2.8 and offset.Y > -5 and offset.Y < 6 and (not bestDistance or d < bestDistance) then
                    best, bestDistance = info, d
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
end

----------------------------------------------------------------
-- Pick a messy position for each chair (same look every time you play)
----------------------------------------------------------------
for i, info in ipairs(allSeats) do
    local seatPos = info.seat.Position
    local rng = Random.new(math.floor(seatPos.X * 7 + seatPos.Z * 13) + i)
    local center = flat(info.table.cf.Position)
    local outward = flat(seatPos) - center
    outward = outward.Magnitude > 0.01 and outward.Unit or V(0, 0, 1)
    local sideways = outward:Cross(V(0, 1, 0))

    -- How wide this chair is (a circle around the seat that covers every part)
    local radius = 1
    for _, p in ipairs(info.parts) do
        local reach = flat(p.Position - seatPos).Magnitude + math.max(p.Size.X, p.Size.Z) * 0.4
        radius = math.max(radius, reach)
    end
    info.radius = math.min(radius, 2.6)

    local direction = (i % 2 == 0) and 1 or -1
    info.turn = math.rad(direction * rng:NextNumber(MAX_TURN * 0.3, MAX_TURN))
    info.tiltX = math.rad(rng:NextNumber(-MAX_TILT, MAX_TILT))
    info.tiltZ = math.rad(rng:NextNumber(-MAX_TILT, MAX_TILT))
    info.start = seatPos
    info.center = center
    info.minFromTable = flat(seatPos - center).Magnitude
    info.pos = flat(seatPos) + sideways * rng:NextNumber(-MAX_SHIFT, MAX_SHIFT) + outward * rng:NextNumber(0.15, MAX_PUSH)
end

----------------------------------------------------------------
-- Slide chairs apart until none of them overlap
----------------------------------------------------------------
local settled = false
for _ = 1, 60 do
    local anyOverlap = false
    for a = 1, #allSeats do
        for b = a + 1, #allSeats do
            local A, B = allSeats[a], allSeats[b]
            if A.table == B.table then
                local between = B.pos - A.pos
                local distance = between.Magnitude
                local needed = A.radius + B.radius + GAP
                if distance < needed then
                    anyOverlap = true
                    local push = (distance > 0.01 and between.Unit or (A.pos - A.center):Cross(V(0, 1, 0)).Unit) * ((needed - distance) / 2 + 0.01)
                    A.pos -= push
                    B.pos += push
                end
            end
        end
    end
    -- Never let a chair slide into the table
    for _, info in ipairs(allSeats) do
        local fromTable = info.pos - info.center
        if fromTable.Magnitude < info.minFromTable then
            info.pos = info.center + fromTable.Unit * info.minFromTable
        end
    end
    if not anyOverlap then
        settled = true
        break
    end
end

----------------------------------------------------------------
-- Move every chair to its new spot
----------------------------------------------------------------
local moved = 0
for _, info in ipairs(allSeats) do
    local seatPos = info.start
    local target = V(info.pos.X, seatPos.Y - CHAIR_DROP, info.pos.Z)
    local move = CFrame.new(target) * CFrame.Angles(info.tiltX, info.turn, info.tiltZ) * CFrame.new(-seatPos)
    for _, p in ipairs(info.parts) do
        p.CFrame = move * p.CFrame
    end
    moved += 1
end

----------------------------------------------------------------
-- Click (or tap) a chair to sit in it - replaces the "Sit & Play" button
-- (the seat pad is invisible, so the cushion on top of it is clickable too)
----------------------------------------------------------------
if REMOVE_SIT_PROMPT then
    for _, info in ipairs(allSeats) do
        local seat = info.seat
        local function sitDown(plr)
            local humanoid = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
            if humanoid and humanoid.Health > 0 and not seat.Occupant and not humanoid.SeatPart then
                seat:Sit(humanoid)
            end
        end
        for _, p in ipairs(info.parts) do
            if p == seat or p.Name == "Cushion" then
                local click = Instance.new("ClickDetector")
                click.MaxActivationDistance = CLICK_DISTANCE
                click.Parent = p
                click.MouseClick:Connect(sitDown)
            end
        end
    end
end

print("[Blackjack] Raised " .. #tables .. " table(s) and adjusted " .. moved .. " chair(s)" .. (settled and ", no overlaps" or ", some chairs may still touch"))
