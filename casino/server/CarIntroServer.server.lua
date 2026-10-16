-- =============================================================================
-- CAR ARRIVAL INTRO (server half)
--
-- James wrote the client camera script; this is the other half it talks to.
-- On its own the camera script waits for ReplicatedFirst's loading screen to
-- clear, fires "ready", and then nothing happens: there is no CarIntroEvent and
-- nothing to send it the "drive" / "exit" / "done" phases. This drives them.
--
-- Sequence, per player:
--   1. character spawns -> frozen and hidden immediately, so they are never
--      seen standing at the spawn pad before their lift arrives
--   2. client reports "ready" -> a car is cloned from the parked fleet and set
--      down the approach road, with the player seated in it
--   3. "drive"  -> the car runs up to the entrance canopy and stops
--   4. "exit"   -> the player is set down at the driver's door and walks clear
--   5. "done"   -> controls and camera handed back, the car pulls away
--
-- The car is moved by welding every part to its Hitbox and animating that one
-- part. Moving all ~120 parts each frame would replicate 120 CFrames per frame
-- per player; this replicates one.
-- =============================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CFG = {
    -- Offset clear of the spawn pad. CasinoSpawn is a visible 24x24 slab at
    -- (0,-140) whose top stands a stud above the road, so a car centred there
    -- has the bottom of its wheels buried in it.
    ArrivalX = 24,
    ArrivalZ = -142,   -- under the entrance canopy, beside the spawn pad
    ArrivalYaw = 180,  -- car faces the casino, having driven up from the lot
    -- Keep the whole approach on the Drive (Z -215..-105). Starting further
    -- back runs the car through the parking lot, over wheel stops and parked
    -- cars: a probe at Z -242 comes back at Y 3.80 instead of road level.
    Approach = 65,
    DriveTime = 4.0,
    SettleHold = 0.5,
    ExitHold = 3.0,
    WalkAhead = 11,
    DepartTime = 3.0,
    -- It pulls forward, away from the canopy, but the facade is at Z -112. At
    -- 20 the nose finishes 2 studs off the wall; 14 leaves 8.
    DepartDistance = 14,
    ReadyTimeout = 20, -- release the player anyway if the client never reports
    FleetFolder = "ParkedCars",
    -- Cast for the road from BELOW the entrance canopy. The canopy roof sits at
    -- Y 24.5-27.5 directly over the arrival point, so a ray dropped from high up
    -- lands on it and the car arrives thirty studs in the air.
    RayFromHeight = 15,
}

local event = ReplicatedStorage:FindFirstChild("CarIntroEvent")
if not event then
    event = Instance.new("RemoteEvent")
    event.Name = "CarIntroEvent"
    event.Parent = ReplicatedStorage
end

local casino = workspace:FindFirstChild("Casino")
local fleet = casino and casino:FindFirstChild(CFG.FleetFolder)

-- ---------------------------------------------------------------- ground ----
-- Ignore spawn pads: the pad at the arrival point stands a stud proud of the
-- road, and a car perched on it looks wrong.
local function groundAt(x, z)
    local ignore = {}
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("SpawnLocation") then
            table.insert(ignore, d)
        end
    end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = ignore
    local hit = workspace:Raycast(Vector3.new(x, CFG.RayFromHeight, z), Vector3.new(0, -200, 0), params)
    return hit and hit.Position.Y or 0
end

local ARRIVAL = CFrame.new(CFG.ArrivalX, groundAt(CFG.ArrivalX, CFG.ArrivalZ), CFG.ArrivalZ)
    * CFrame.Angles(0, math.rad(CFG.ArrivalYaw), 0)

-- ------------------------------------------------------------------- car ----
-- Returns the car, and the offset from its ground line to its Hitbox, so the
-- wheels can be put on the road rather than the hitbox centre (a Model with a
-- PrimaryPart pivots on that part, not on its WorldPivot).
local function makeCar()
    if not fleet then
        return nil
    end
    local pool = {}
    for _, c in ipairs(fleet:GetChildren()) do
        if c:IsA("Model") and c:FindFirstChild("Hitbox") then
            table.insert(pool, c)
        end
    end
    if #pool == 0 then
        return nil
    end

    local car = pool[math.random(1, #pool)]:Clone()
    car.Name = "IntroCar"
    local hitbox = car:FindFirstChild("Hitbox")

    local cf, size = car:GetBoundingBox()
    local lift = hitbox.Position.Y - (cf.Position.Y - size.Y / 2)

    -- one moving part, everything else welded to it
    for _, p in ipairs(car:GetDescendants()) do
        if p:IsA("BasePart") and p ~= hitbox then
            local weld = Instance.new("WeldConstraint")
            weld.Part0 = hitbox
            weld.Part1 = p
            weld.Parent = hitbox
            p.Anchored = false
        end
    end
    hitbox.Anchored = true
    hitbox.CanCollide = false -- never shove the player it is delivering
    car.PrimaryPart = hitbox  -- the camera script follows PrimaryPart.Position

    car.Parent = workspace
    return car, lift
end

-- ----------------------------------------------------------- the sequence ---
local busy = {}

local function freeze(character)
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if hrp then
        hrp.Anchored = true
    end
    for _, d in ipairs(character:GetDescendants()) do
        if d:IsA("BasePart") or d:IsA("Decal") then
            d.Transparency = 1
        end
    end
end

local function show(character)
    for _, d in ipairs(character:GetDescendants()) do
        if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
            d.Transparency = 0
        elseif d:IsA("Decal") then
            d.Transparency = 0
        end
    end
end

local function thaw(character)
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if hrp then
        hrp.Anchored = false
    end
end

-- animate the car (and optionally the passenger) between two ground CFrames
local function glide(car, lift, fromCF, toCF, duration, character)
    local hitbox = car.PrimaryPart
    local elapsed = 0
    while elapsed < duration do
        local dt = RunService.Heartbeat:Wait()
        elapsed = math.min(elapsed + dt, duration)
        local a = elapsed / duration
        a = 1 - (1 - a) * (1 - a) -- ease out, so it rolls to a stop
        local ground = fromCF:Lerp(toCF, a)
        hitbox.CFrame = ground * CFrame.new(0, lift, 0)
        if character then
            local hrp = character:FindFirstChild("HumanoidRootPart")
            if hrp then
                hrp.CFrame = ground * CFrame.new(-1.65, 3.6, 0.6)
            end
        end
        if not car.Parent then
            return
        end
    end
end

local function runIntro(player, character)
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not (humanoid and hrp) then
        return
    end

    local car, lift = makeCar()
    if not car then
        warn("[CarIntro] no car to clone from " .. CFG.FleetFolder .. "; skipping the intro")
        return
    end

    -- set both down before the camera cuts to them; glide() with a zero
    -- duration never enters its loop, so place them directly
    local startCF = ARRIVAL * CFrame.new(0, 0, CFG.Approach)
    car.PrimaryPart.CFrame = startCF * CFrame.new(0, lift, 0)
    hrp.CFrame = startCF * CFrame.new(-1.65, 3.6, 0.6)

    event:FireClient(player, "drive", car, ARRIVAL)
    glide(car, lift, startCF, ARRIVAL, CFG.DriveTime, character)
    task.wait(CFG.SettleHold)

    -- step out at the driver's door
    event:FireClient(player, "exit", car, ARRIVAL)
    local standing = humanoid.HipHeight + hrp.Size.Y / 2
    hrp.CFrame = ARRIVAL * CFrame.new(-5.2, standing, 0.6)
    show(character)
    thaw(character)
    humanoid:MoveTo((ARRIVAL * CFrame.new(-5.6, 0, -CFG.WalkAhead)).Position)
    task.wait(CFG.ExitHold)

    event:FireClient(player, "done")

    -- the car pulls away
    task.spawn(function()
        glide(car, lift, ARRIVAL, ARRIVAL * CFrame.new(0, 0, -CFG.DepartDistance), CFG.DepartTime)
        car:Destroy()
    end)
end

-- --------------------------------------------------------------- wiring -----
local function onCharacter(player, character)
    character:WaitForChild("HumanoidRootPart")
    character:WaitForChild("Humanoid")
    freeze(character)
    busy[player] = character

    -- if the client never reports in, give the player their body back anyway
    task.delay(CFG.ReadyTimeout, function()
        if busy[player] == character then
            busy[player] = nil
            show(character)
            thaw(character)
            event:FireClient(player, "done")
        end
    end)
end

Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function(character)
        onCharacter(player, character)
    end)
    if player.Character then
        onCharacter(player, player.Character)
    end
end)

event.OnServerEvent:Connect(function(player, message)
    if message ~= "ready" then
        return
    end
    local character = busy[player]
    if not character or not character.Parent then
        return
    end
    busy[player] = nil

    local ok, err = pcall(runIntro, player, character)
    if not ok then
        warn("[CarIntro] " .. tostring(err))
    end
    -- whatever happened, the player gets their body and camera back
    if character.Parent then
        show(character)
        thaw(character)
    end
    event:FireClient(player, "done")
end)

print("[CarIntro] ready, arrival at " .. tostring(ARRIVAL.Position))
