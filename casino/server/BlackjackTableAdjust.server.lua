-- BLACKJACK TABLE + CHAIR ADJUST (Script in ServerScriptService)
-- Settings:
local TABLE_RAISE = 1.2   -- how many studs to move the table UP
local CHAIR_DROP = 0.8    -- how many studs to move the chairs DOWN
local MAX_TURN = 9        -- most a chair can be turned left or right (degrees)
local MAX_SHIFT = 0.3     -- most a chair can be nudged sideways (studs)
local MAX_PUSH = 0.45     -- most a chair can be pushed back from the table (studs)

local V = Vector3.new
local function flat(v)
    return V(v.X, 0, v.Z)
end

-- Wait for the chair and table scripts to finish building (the blackjack game starts at 6 seconds)
task.wait(3)

-- Find the blackjack tables
local tables = {}
for _, m in ipairs(workspace:GetDescendants()) do
    if m:IsA("Model") then
        local name = string.lower(m.Name)
        if string.find(name, "blackjack") and not string.find(name, "_chairs") and not string.find(name, "blackjackgame") then
            local cf, size = m:GetBoundingBox()
            table.insert(tables, { model = m, cf = cf, size = size, seats = {} })
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

-- Give each seat to its nearest table
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
            table.insert(best.seats, s)
            table.insert(allSeats, { seat = s, table = best, parts = {} })
        end
    end
end

-- Find which parts belong to each chair (the parts closest to that seat)
for _, p in ipairs(workspace:GetDescendants()) do
    if p:IsA("BasePart") and p.Anchored and not inTable(p) then
        local size = p.Size
        local isHuge = math.max(size.X, size.Y, size.Z) > 9
        local isCharacter = p:FindFirstAncestorOfClass("Model") and p:FindFirstAncestorOfClass("Model"):FindFirstChildOfClass("Humanoid")
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

-- Raise the tables
for _, t in ipairs(tables) do
    for _, p in ipairs(t.model:GetDescendants()) do
        if p:IsA("BasePart") and p.Anchored then
            p.CFrame = p.CFrame + V(0, TABLE_RAISE, 0)
        end
    end
end

-- Lower each chair and turn/nudge it a little (same look every time you play)
local moved = 0
for _, info in ipairs(allSeats) do
    local seatPos = info.seat.Position
    local rng = Random.new(math.floor(seatPos.X * 7 + seatPos.Z * 13))
    local outward = flat(seatPos - info.table.cf.Position)
    outward = outward.Magnitude > 0.01 and outward.Unit or V(0, 0, 1)
    local sideways = outward:Cross(V(0, 1, 0))

    local turn = math.rad(rng:NextNumber(-MAX_TURN, MAX_TURN))
    local shift = sideways * rng:NextNumber(-MAX_SHIFT, MAX_SHIFT) + outward * rng:NextNumber(0, MAX_PUSH)
    local move = CFrame.new(seatPos + shift - V(0, CHAIR_DROP, 0)) * CFrame.Angles(0, turn, 0) * CFrame.new(-seatPos)

    for _, p in ipairs(info.parts) do
        p.CFrame = move * p.CFrame
    end
    moved += 1
end

print("[Blackjack] Raised " .. #tables .. " table(s) and adjusted " .. moved .. " chair(s)")
