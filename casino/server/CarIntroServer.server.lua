-- =============================================================================
-- CAR ARRIVAL INTRO (server half)
--
-- James wrote the client camera script; this is the other half it talks to.
--
-- Sequence, per player:
--   1. client reports "ready" once its loading screen has cleared
--   2. the player is hidden and held, a car is cloned from the parked fleet and
--      set down the approach road with them in it
--   3. "drive"  -> the car runs up to the entrance canopy and stops
--   4. "exit"   -> the player is set down at the driver's door and walks clear
--   5. "done"   -> controls and camera handed back, the car pulls away
--
-- Nothing is done to the character until "ready" actually arrives. An earlier
-- version froze and hid the character the moment it spawned and released it on
-- a 20 second timer, which was wrong in two ways: the loading screen can take
-- up to ~27s to clear (MAX_TIME 25 plus its exit animation), so the server gave
-- up before the client ever reported in and then rejected the handshake; and
-- any failure in between left the player standing invisible and immobile.
-- Now, if "ready" never arrives, nothing happens at all and the player simply
-- plays. The loading screen covers the spawn anyway, so there is nothing to
-- hide from them in the meantime.
--
-- The car is moved by welding every part to its Hitbox and animating that one
-- part. Moving all ~120 parts each frame would replicate 120 CFrames per frame
-- per player; this replicates one. (Verified in edit mode.)
-- =============================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CFG = {
    -- 16 Oct: moved into the drop-off lane of the grand exterior's driveway.
    -- The exterior, built after this intro, put a curb-and-grass strip and a
    -- canopy post on the old arrival point (24, -142), and a canopy ceiling at
    -- Y 13.5 over it, so the old ray landed on the canopy and the car would
    -- have arrived 16 studs in the air, inside a post. The lane runs along the
    -- front of the casino between the sidewalk curb (Z -127.5) and the grass
    -- strip (Z -139.5); the car now drives west along it, under the canopy,
    -- and stops just east of the spawn pad (X -12..12) and clear of the
    -- canopy posts at X 24.5.
    ArrivalX = 20,
    ArrivalZ = -133.5, -- middle of the drop-off lane
    ArrivalYaw = 90,   -- heading west (-X) along the lane; the driver's door faces the casino
    Approach = 65,     -- starts at X 85, in the same lane
    DriveTime = 4.0,
    SettleHold = 0.5,
    ExitHold = 3.0,
    -- after stepping out, walk up onto the sidewalk toward the revolving door
    WalkTo = Vector3.new(14, 0, -121),
    DepartTime = 3.0,
    -- pulls away west down the lane before it disappears
    DepartDistance = 60,
    FleetFolder = "ParkedCars",
    -- Cast for the road from below the canopy ceiling (Y 13.4) so the ray
    -- lands on the asphalt, not the canopy.
    RayFromHeight = 5,
    Verbose = true,
}

local function log(...)
    if CFG.Verbose then
        print("[CarIntro/server]", ...)
    end
end

local event = ReplicatedStorage:FindFirstChild("CarIntroEvent")
if not event then
    event = Instance.new("RemoteEvent")
    event.Name = "CarIntroEvent"
    event.Parent = ReplicatedStorage
end

local casino = workspace:FindFirstChild("Casino")
local fleet = casino and casino:FindFirstChild(CFG.FleetFolder)

-- ---------------------------------------------------------------- ground ----
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
local played = {}

local function hide(character)
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

local function hold(character)
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if hrp then
        hrp.Anchored = true
    end
end

local function release(character)
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if hrp then
        hrp.Anchored = false
    end
end

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
        return false, "character has no Humanoid or HumanoidRootPart"
    end

    local car, lift = makeCar()
    if not car then
        return false, "no car to clone from " .. CFG.FleetFolder
    end

    -- only now does the player lose their body; if anything above failed they
    -- were never touched
    hide(character)
    hold(character)

    local startCF = ARRIVAL * CFrame.new(0, 0, CFG.Approach)
    car.PrimaryPart.CFrame = startCF * CFrame.new(0, lift, 0)
    hrp.CFrame = startCF * CFrame.new(-1.65, 3.6, 0.6)

    log(player.Name, "car", car.Name, "set down at", tostring(car.PrimaryPart.Position))
    event:FireClient(player, "drive", car, ARRIVAL)
    glide(car, lift, startCF, ARRIVAL, CFG.DriveTime, character)
    task.wait(CFG.SettleHold)

    log(player.Name, "arrived, stepping out")
    event:FireClient(player, "exit", car, ARRIVAL)
    local standing = humanoid.HipHeight + hrp.Size.Y / 2
    hrp.CFrame = ARRIVAL * CFrame.new(-5.2, standing, 0.6)
    show(character)
    release(character)
    humanoid:MoveTo(Vector3.new(CFG.WalkTo.X, ARRIVAL.Position.Y, CFG.WalkTo.Z))
    task.wait(CFG.ExitHold)

    task.spawn(function()
        glide(car, lift, ARRIVAL, ARRIVAL * CFrame.new(0, 0, -CFG.DepartDistance), CFG.DepartTime)
        car:Destroy()
    end)
    return true
end

-- --------------------------------------------------------------- wiring -----
Players.PlayerRemoving:Connect(function(player)
    played[player] = nil
end)

event.OnServerEvent:Connect(function(player, message)
    if message ~= "ready" then
        return
    end
    if played[player] then
        return -- respawns do not replay the intro
    end
    played[player] = true
    log(player.Name, "reported ready")

    local character = player.Character
    if not character then
        character = player.CharacterAdded:Wait()
    end
    character:WaitForChild("HumanoidRootPart", 10)
    character:WaitForChild("Humanoid", 10)

    local ok, result, reason = pcall(runIntro, player, character)
    if not ok then
        warn("[CarIntro] " .. tostring(result))
    elseif result == false then
        warn("[CarIntro] skipped: " .. tostring(reason))
    end

    -- whatever happened, the player ends up visible, mobile and in control
    if character.Parent then
        show(character)
        release(character)
    end
    event:FireClient(player, "done")
    log(player.Name, "done")
end)

log("loaded; arrival at", tostring(ARRIVAL.Position), "| fleet:", fleet and #fleet:GetChildren() or 0, "cars")
