-- BLACKJACK TABLE + CHAIR ADJUST v2 (Script in ServerScriptService)
-- Settings:
local TABLE_RAISE = 1.2   -- how many studs to move the table UP
local CHAIR_DROP = 0.8    -- how many studs to move the chairs DOWN
local MAX_TURN = 20       -- most a chair can be turned left or right (degrees)
local MAX_SHIFT = 0.6     -- most a chair can be nudged sideways (studs)
local MAX_PUSH = 0.9      -- most a chair can be pushed back from the table (studs)
local MAX_TILT = 2        -- tiny lean so they don't look perfect (degrees)
local REMOVE_SIT_PROMPT = true -- removes the "Sit & Play" button
local CLICK_DISTANCE = 12 -- how close you need to be to click a chair and sit

local Players = game:GetService("Players")

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
-- Lower each chair and turn / nudge / lean it (same look every time you play)
----------------------------------------------------------------
local moved = 0
for i, info in ipairs(allSeats) do
    local seatPos = info.seat.Position
    local rng = Random.new(math.floor(seatPos.X * 7 + seatPos.Z * 13) + i)
    local outward = flat(seatPos - info.table.cf.Position)
    outward = outward.Magnitude > 0.01 and outward.Unit or V(0, 0, 1)
    local sideways = outward:Cross(V(0, 1, 0))

    -- Every other chair turns the opposite way, so no two neighbors look the same
    local direction = (i % 2 == 0) and 1 or -1
    local turn = math.rad(direction * rng:NextNumber(MAX_TURN * 0.35, MAX_TURN))
    local tiltX = math.rad(rng:NextNumber(-MAX_TILT, MAX_TILT))
    local tiltZ = math.rad(rng:NextNumber(-MAX_TILT, MAX_TILT))
    local shift = sideways * rng:NextNumber(-MAX_SHIFT, MAX_SHIFT) + outward * rng:NextNumber(0.2, MAX_PUSH)

    local move = CFrame.new(seatPos + shift - V(0, CHAIR_DROP, 0))
        * CFrame.Angles(tiltX, turn, tiltZ)
        * CFrame.new(-seatPos)
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

print("[Blackjack] Raised " .. #tables .. " table(s) and adjusted " .. moved .. " chair(s)")
