-- BLACKJACK TABLES + CHAIRS + SOLO/MULTIPLAYER LOBBY v8 (Script in ServerScriptService)
-- Pairs with StarterPlayerScripts.BlackjackLobby (the menu). BlackjackV3 plays with whoever is seated.
-- Settings:
local SEATS_PER_TABLE = 8 -- most players at one table (extra chairs get hidden)
local IDLE_CHAIRS = 5     -- how many chairs show when nobody is playing
local TABLE_RAISE = 1.2   -- how many studs to move the table UP
local CHAIR_DROP = 0.8    -- how many studs to move the chairs DOWN
local ARC_ANGLE = 170     -- how wide the curve of chairs is (degrees)
local CHAIR_OUT = 2.0     -- how far each seat sits from the table edge (studs)
local MAX_TURN = 6        -- small random turn so they don't look perfect (degrees)
local MAX_SHIFT = 0.2     -- small random nudge (studs)
local MAX_TILT = 1.5      -- tiny lean (degrees)
local GAP = 0.25          -- smallest space allowed between two chairs (studs)
local PLAYER_SIDE = 1.0   -- every chair stays at least this far on the players' side (the game hides seats on the dealer's side)
local EMPTY_RESET_TIME = 4 -- seconds a table must be empty before it resets

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
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

local lobbyRemote = ReplicatedStorage:FindFirstChild("BlackjackLobbyRemote") or Instance.new("RemoteEvent")
lobbyRemote.Name = "BlackjackLobbyRemote"
lobbyRemote.Parent = ReplicatedStorage

----------------------------------------------------------------
-- Remove the old "Sit & Play" button (the lobby has its own)
----------------------------------------------------------------
local function removePrompt(d)
    if d:IsA("ProximityPrompt") and (d.Name == "BlackjackJoinPrompt" or d.ActionText == "Sit & Play") then
        task.defer(function()
            d:Destroy()
        end)
    end
end
for _, d in ipairs(workspace:GetDescendants()) do
    removePrompt(d)
end
workspace.DescendantAdded:Connect(removePrompt)

----------------------------------------------------------------
-- Show / hide a chair
----------------------------------------------------------------
local function remember(o, prop)
    local key = "Lobby_" .. prop
    if o:GetAttribute(key) == nil then
        o:SetAttribute(key, o[prop])
    end
    return o:GetAttribute(key)
end
local function showChair(chair, shown)
    for _, p in ipairs(chair.parts) do
        p.Transparency = shown and remember(p, "Transparency") or 1
        p.CanCollide = shown and remember(p, "CanCollide") or false
        p.CanQuery = shown and remember(p, "CanQuery") or false -- hidden chairs don't block clicks or the camera
        for _, d in ipairs(p:GetDescendants()) do
            if d:IsA("Decal") or d:IsA("Texture") then
                d.Transparency = shown and remember(d, "Transparency") or 1
            elseif d:IsA("SurfaceGui") or d:IsA("BillboardGui") or d:IsA("Light") or d:IsA("ParticleEmitter") then
                d.Enabled = shown and remember(d, "Enabled") or false
            end
        end
    end
end

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
            table.insert(tables, { id = #tables + 1, model = m, cf = cf, size = size, seats = {}, chairs = {}, spare = {} })
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
    -- Only real chairs: skip seats built into the table itself (those put you in the middle)
    if s:IsA("Seat") and not inTable(s) then
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

-- Lock any seats that are built into the tables so nobody gets stuck in the middle
for _, t in ipairs(tables) do
    for _, d in ipairs(t.model:GetDescendants()) do
        if d:IsA("Seat") then
            d.Disabled = true
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
for _, chair in ipairs(allChairs) do
    if not table.find(chair.parts, chair.seat) then
        table.insert(chair.parts, chair.seat)
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
-- Each chair's size and which way it faces
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
-- Too many chairs? Hide the extras for good.
----------------------------------------------------------------
for _, t in ipairs(tables) do
    local center = flat(t.cf.Position)
    local avg = V(0, 0, 0)
    for _, chair in ipairs(t.chairs) do
        avg += flat(chair.start) - center
    end
    local toPlayers = avg.Magnitude > 0.01 and avg.Unit or V(0, 0, 1)
    t.toPlayers = toPlayers
    local right = toPlayers:Cross(UP)
    table.sort(t.chairs, function(a, b)
        return (flat(a.start) - center):Dot(right) < (flat(b.start) - center):Dot(right)
    end)
    if #t.chairs > SEATS_PER_TABLE then
        local keep = {}
        for i = 1, SEATS_PER_TABLE do
            local index = math.floor(1 + (i - 1) * (#t.chairs - 1) / math.max(1, SEATS_PER_TABLE - 1) + 0.5)
            keep[t.chairs[index]] = true
        end
        local kept = {}
        for _, chair in ipairs(t.chairs) do
            if keep[chair] then
                table.insert(kept, chair)
            else
                showChair(chair, false)
                chair.seat.Disabled = true
                table.insert(t.spare, chair)
            end
        end
        t.chairs = kept
    end
end

----------------------------------------------------------------
-- Not enough chairs? Copy some until each table has enough.
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
        table.insert(t.chairs, copy)
    end
end

----------------------------------------------------------------
-- Place the chairs in a curve around each table
----------------------------------------------------------------
local placed = {}
for _, t in ipairs(tables) do
    local chairs = t.chairs
    if #chairs > 0 then
        local center = flat(t.cf.Position)
        local tableOnly = RaycastParams.new()
        tableOnly.FilterType = Enum.RaycastFilterType.Include
        tableOnly.FilterDescendantsInstances = { t.model }
        local top = workspace:Raycast(t.cf.Position + V(0, t.size.Y / 2 + 5, 0), V(0, -(t.size.Y + 10), 0), tableOnly)
        local feltY = top and top.Position.Y or (t.cf.Position.Y + t.size.Y / 2)
        t.feltY = feltY
        local reach = math.max(t.size.X, t.size.Z) / 2 + 10
        local toPlayers = t.toPlayers
        local right = toPlayers:Cross(UP)

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
            chair.extraTurn = math.rad(rng:NextNumber(-MAX_TURN, MAX_TURN))
            chair.tiltX = math.rad(rng:NextNumber(-MAX_TILT, MAX_TILT))
            chair.tiltZ = math.rad(rng:NextNumber(-MAX_TILT, MAX_TILT))
            table.insert(placed, chair)
        end
    end
end

for _ = 1, 80 do
    local anyOverlap = false
    for a = 1, #placed do
        for b = a + 1, #placed do
            local A, B = placed[a], placed[b]
            if A.table == B.table then
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
    for _, chair in ipairs(placed) do
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
    if not anyOverlap then
        break
    end
end

for _, chair in ipairs(placed) do
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
end

----------------------------------------------------------------
-- LOBBY: pick Solo or Multiplayer before playing
----------------------------------------------------------------
local function occupant(chair)
    local o = chair.seat.Occupant
    return o and Players:GetPlayerFromCharacter(o.Parent)
end

-- Pick chairs spread out evenly (1 chair = the middle one, facing the dealer)
local function pickSeats(t, count)
    local total = #t.chairs
    count = math.clamp(count, 1, total)
    local picked = {}
    if count == 1 then
        table.insert(picked, t.chairs[math.ceil(total / 2)])
    else
        for i = 1, count do
            local index = math.floor(1 + (i - 1) * (total - 1) / (count - 1) + 0.5)
            if not table.find(picked, t.chairs[index]) then
                table.insert(picked, t.chairs[index])
            end
        end
    end
    return picked
end

local function updatePrompt(t)
    local prompt = t.prompt
    if t.mode == "idle" then
        prompt.Enabled = true
        prompt.ActionText = "Play Blackjack"
        prompt.ObjectText = "Solo or Multiplayer"
    elseif t.mode == "solo" then
        prompt.Enabled = false
    else
        local used = 0
        for _, chair in ipairs(t.active) do
            if occupant(chair) then
                used += 1
            end
        end
        prompt.Enabled = used < #t.active
        prompt.ActionText = "Join Game"
        prompt.ObjectText = "Blackjack  " .. used .. "/" .. #t.active .. " players"
    end
end

-- Show only these chairs; the rest are hidden and locked
local function showOnly(t, chosen, seatsOpen)
    for _, chair in ipairs(t.chairs) do
        local shown = table.find(chosen, chair) ~= nil
        showChair(chair, shown)
        chair.seat.Disabled = not (shown and seatsOpen)
    end
end

local function resetTable(t)
    t.mode = "idle"
    t.active = {}
    showOnly(t, pickSeats(t, IDLE_CHAIRS), false) -- use the menu to start
    updatePrompt(t)
end

-- Walk the player to an open chair and sit them in it (tries a few times)
local function seatIn(player, chairs)
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not root or humanoid.Health <= 0 then
        return false
    end
    for _, chair in ipairs(chairs) do
        if humanoid.SeatPart == chair.seat then
            return true -- already in one of these chairs
        end
    end
    local best, bestDistance
    for _, chair in ipairs(chairs) do
        if not chair.seat.Occupant and not chair.seat.Disabled then
            local d = (chair.seat.Position - root.Position).Magnitude
            if not bestDistance or d < bestDistance then
                best, bestDistance = chair, d
            end
        end
    end
    if not best then
        return false
    end
    task.spawn(function()
        for _ = 1, 3 do
            if humanoid.SeatPart == best.seat then
                return
            end
            if best.seat.Occupant and best.seat.Occupant ~= humanoid then
                break
            end
            humanoid.Sit = false
            if root.Anchored then
                root.Anchored = false
            end
            task.wait(0.1)
            root.CFrame = best.seat.CFrame + V(0, 3, 0)
            task.wait(0.1)
            best.seat:Sit(humanoid)
            task.wait(0.5)
        end
        if humanoid.SeatPart ~= best.seat then
            warn("[Blackjack] Could not seat " .. player.Name .. " in " .. best.seat:GetFullName())
            lobbyRemote:FireClient(player, "message", { text = "Couldn't reach your seat - press E to try again" })
        end
    end)
    return true
end

local function startTable(t, player, count)
    count = math.clamp(math.floor(count), 1, #t.chairs)
    t.mode = count == 1 and "solo" or "multi"
    t.active = pickSeats(t, count)
    t.lastUsed = os.clock() + 3
    showOnly(t, t.active, true)
    seatIn(player, t.active)
    updatePrompt(t)
end

local function closeTo(player, t, range)
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    return root and flat(root.Position - t.cf.Position).Magnitude < range
end

for _, t in ipairs(tables) do
    if #t.chairs > 0 then
        local anchor = Instance.new("Part")
        anchor.Name = "BlackjackLobbyAnchor"
        anchor.Anchored = true
        anchor.CanCollide = false
        anchor.CanQuery = false
        anchor.CanTouch = false
        anchor.Transparency = 1
        anchor.Size = V(1, 1, 1)
        anchor.CFrame = CFrame.new(V(t.cf.Position.X, (t.feltY or t.cf.Position.Y) + 1.5, t.cf.Position.Z))
        anchor.Parent = extraFolder
        local prompt = Instance.new("ProximityPrompt")
        prompt.Name = "BlackjackLobbyPrompt"
        prompt.KeyboardKeyCode = Enum.KeyCode.E
        prompt.HoldDuration = 0
        prompt.MaxActivationDistance = 14
        prompt.RequiresLineOfSight = false
        prompt:SetAttribute("TableId", t.id)
        prompt.Parent = anchor
        t.prompt = prompt
        prompt.Triggered:Connect(function(player)
            if t.mode == "idle" then
                lobbyRemote:FireClient(player, "openMenu", { tableId = t.id, maxSeats = #t.chairs })
            elseif t.mode == "multi" then
                if not seatIn(player, t.active) then
                    lobbyRemote:FireClient(player, "message", { text = "This table is full" })
                end
            end
        end)
        resetTable(t)
    end
end

lobbyRemote.OnServerEvent:Connect(function(player, kind, tableId, count)
    -- count ~= count catches NaN sent by an exploiter
    if kind ~= "choose" or typeof(tableId) ~= "number" or typeof(count) ~= "number" or count ~= count then
        return
    end
    local t = tables[tableId]
    if not t or not t.prompt or not closeTo(player, t, 25) then
        return
    end
    if t.mode == "idle" then
        startTable(t, player, count)
    elseif t.mode == "multi" then
        if not seatIn(player, t.active) then
            lobbyRemote:FireClient(player, "message", { text = "This table is full" })
        end
    else
        lobbyRemote:FireClient(player, "message", { text = "Someone is already playing here" })
    end
end)

-- Reset tables that nobody is sitting at anymore
task.spawn(function()
    while true do
        task.wait(0.5)
        for _, t in ipairs(tables) do
            if t.prompt and t.mode ~= "idle" then
                local anyone = false
                for _, chair in ipairs(t.active) do
                    if occupant(chair) then
                        anyone = true
                    end
                end
                if anyone then
                    t.lastUsed = os.clock()
                elseif os.clock() - t.lastUsed > EMPTY_RESET_TIME then
                    resetTable(t)
                end
                updatePrompt(t)
            end
        end
    end
end)

print("[Blackjack] Lobby ready at " .. #tables .. " table(s)")
