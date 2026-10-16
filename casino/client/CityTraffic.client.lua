-- CITY TRAFFIC & PEOPLE (LocalScript in StarterPlayer > StarterPlayerScripts)
-- Written by James. Changes are marked [REX]:
--
--   1. NOTHING WAS PUBLISHING ReplicatedStorage.CityData. This script waits 180
--      seconds for it and then returns, so as written it would have sat there
--      doing nothing and never said why. Added CityDataPublisher on the server,
--      which reads the road network back off the actual tarmac.
--   2. workspace.CurrentCamera was cached. This runs from StarterPlayerScripts
--      before the character exists, and Roblox swaps CurrentCamera out when the
--      character loads, so camPos would have been frozen wherever the old
--      camera last was. Everything outside DRAW_DISTANCE of that stale point
--      stops being updated. Read it each frame instead. (Same bug that made the
--      car-arrival intro invisible.)
--   3. Out-of-range cars and people were never moved, so every part sat at the
--      origin where it was created - about 870 parts heaped in the middle of
--      the casino floor, which is exactly where the player spawns. They now
--      start parked far below the map and are sent back there when they go out
--      of range.
--   4. Street width is per node, not global. The tower grid uses 26-stud
--      streets and the low-rise infill uses 18, so a single streetWidth put
--      half the traffic driving through the kerb.
--   5. Bails out with a warning if the road network comes back empty, rather
--      than building 30 cars that have nowhere to drive.

-- Settings:
local CARS = 30
local PEOPLE = 60
local CAR_SPEED = 28
local DRAW_DISTANCE = 450   -- only animate things this close to the camera

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local dataValue = ReplicatedStorage:WaitForChild("CityData", 180)
if not dataValue then
    warn("[CityTraffic] no CityData after 180s - is CityDataPublisher in ServerScriptService?")
    return
end
while dataValue.Value == "" do
    dataValue.Changed:Wait()
end
local data = HttpService:JSONDecode(dataValue.Value)
local nodes, blocks, SW = data.nodes, data.blocks, data.streetWidth
local V = Vector3.new
local UP = V(0, 1, 0)

-- [REX] was `local LANE = SW * 0.14`, one lane offset for the whole city
-- [REX] 26-stud streets have cars parked at the kerb (StreetParkedCars), so
-- their lanes sit a little closer to the centre line: 0.11 keeps the traffic
-- clear of the parked cars and still clear of the oncoming lane. The 18-stud
-- infill streets have no parking and keep 0.14.
local function laneFor(w)
    w = w or SW
    return w * (w >= 24 and 0.11 or 0.14)
end

if not nodes or #nodes == 0 then
    warn("[CityTraffic] CityData has no drivable roads; not spawning traffic")
    return
end

-- [REX] where things wait when they are out of range, instead of the origin
local PARKED = CFrame.new(0, -500, 0)

local folder = Instance.new("Folder")
folder.Name = "CityTrafficLocal"
folder.Parent = workspace

local function newPart(size, color, material, shape)
    local p = Instance.new("Part")
    p.Anchored = true
    p.CanCollide = false
    p.CanQuery = false
    p.CanTouch = false
    p.CastShadow = false
    p.Size = size
    p.Color = color
    p.Material = material or Enum.Material.SmoothPlastic
    if shape then
        p.Shape = shape
    end
    p.CFrame = PARKED -- [REX] never leave it sitting at 0,0,0
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.Parent = folder
    return p
end

local function signal(offset, axis)
    local t = (workspace:GetServerTimeNow() + offset) % 22
    if axis == "X" then
        if t < 8 then return "green" elseif t < 10 then return "yellow" else return "red" end
    else
        if t >= 11 and t < 19 then return "green" elseif t >= 19 and t < 21 then return "yellow" else return "red" end
    end
end

----------------------------------------------------------------
-- Cars
----------------------------------------------------------------
local CAR_COLORS = {
    Color3.fromRGB(240, 240, 240), Color3.fromRGB(20, 20, 22), Color3.fromRGB(160, 162, 165), Color3.fromRGB(150, 20, 25),
    Color3.fromRGB(25, 45, 95), Color3.fromRGB(35, 70, 45), Color3.fromRGB(200, 180, 140), Color3.fromRGB(230, 190, 40),
}

local function buildCar()
    local color = CAR_COLORS[math.random(1, #CAR_COLORS)]
    local list, flat = {}, {}
    local function add(size, offset, c, material, shape)
        local p = newPart(size, c, material, shape)
        table.insert(list, { part = p, offset = offset })
        table.insert(flat, p)
    end
    add(V(5.2, 1.8, 11), CFrame.new(0, 1.7, 0), color)
    add(V(4.6, 1.5, 5.5), CFrame.new(0, 3.3, 0.6), Color3.fromRGB(25, 30, 35), Enum.Material.Glass)
    add(V(4.6, 0.15, 5.3), CFrame.new(0, 4.1, 0.6), color)
    for _, x in ipairs({ -2.35, 2.35 }) do
        for _, z in ipairs({ -3.6, 3.6 }) do
            add(V(0.9, 2, 2), CFrame.new(x, 1, z), Color3.fromRGB(25, 25, 25), nil, Enum.PartType.Cylinder)
        end
        add(V(1, 0.4, 0.05), CFrame.new(x * 0.7, 1.9, -5.52), Color3.fromRGB(255, 250, 220), Enum.Material.Neon)
        add(V(1, 0.4, 0.05), CFrame.new(x * 0.7, 1.9, 5.52), Color3.fromRGB(220, 20, 20), Enum.Material.Neon)
    end
    return list, flat
end

local geomCache = {}
local function geom(a, b)
    local k = a .. ">" .. b
    if geomCache[k] then
        return geomCache[k]
    end
    local A, Bn = nodes[a], nodes[b]
    local pa, pb = V(A.x, A.y, A.z), V(Bn.x, Bn.y, Bn.z)
    local d = (pb - pa).Unit
    local right = d:Cross(UP)
    -- [REX] inset by each end's own street width, and take the lane offset from
    -- the average, so a 26-stud street meeting an 18-stud one still lines up
    local lane = (laneFor(A.w) + laneFor(Bn.w)) / 2
    local g = {
        d = d,
        right = right,
        startP = pa + d * ((A.w or SW) / 2) + right * lane,
        endP = pb - d * ((Bn.w or SW) / 2) + right * lane,
    }
    g.length = (g.endP - g.startP).Magnitude
    geomCache[k] = g
    return g
end

local function bezier(p0, p1, p2, u)
    return p0 * (1 - u) ^ 2 + p1 * 2 * (1 - u) * u + p2 * u ^ 2
end
local function bezierTangent(p0, p1, p2, u)
    return (p1 - p0) * 2 * (1 - u) + (p2 - p1) * 2 * u
end

local cars = {}
local function startTurn(car)
    local B = nodes[car.b]
    local options = {}
    for _, j in ipairs(B.n) do
        if j ~= car.a then
            table.insert(options, j)
        end
    end
    if #options == 0 then
        options = { car.a }
    end
    local c = options[math.random(1, #options)]
    local g1, g2 = geom(car.a, car.b), geom(car.b, c)
    local p0, p2 = g1.endP, g2.startP
    local control
    local dot = g1.d:Dot(g2.d)
    if dot > 0.9 then
        control = (p0 + p2) / 2
    elseif dot < -0.9 then
        control = V(B.x, p0.Y, B.z) + g1.d * ((B.w or SW) * 0.6)
    elseif math.abs(g1.d.X) > 0.5 then
        control = V(p2.X, p0.Y, p0.Z)
    else
        control = V(p0.X, p0.Y, p2.Z)
    end
    local length, last = 0, p0
    for i = 1, 8 do
        local point = bezier(p0, control, p2, i / 8)
        length += (point - last).Magnitude
        last = point
    end
    car.mode = "turn"
    car.c = c
    car.turn = { p0, control, p2 }
    car.turnLength = math.max(length, 1)
    car.u = 0
end

local starts = {}
for i, node in ipairs(nodes) do
    if #node.n > 0 then
        table.insert(starts, i)
    end
end

if #starts > 0 then
    for _ = 1, CARS do
        for _ = 1, 20 do
            local a = starts[math.random(1, #starts)]
            local b = nodes[a].n[math.random(1, #nodes[a].n)]
            local g = geom(a, b)
            local s = math.random() * math.max(g.length - 12, 0)
            local ok = true
            for _, other in ipairs(cars) do
                if other.a == a and other.b == b and math.abs(other.s - s) < 14 then
                    ok = false
                    break
                end
            end
            if ok then
                local parts, flat = buildCar()
                table.insert(cars, {
                    a = a, b = b, s = s, v = CAR_SPEED * 0.5, mode = "straight",
                    parts = parts, flat = flat, shown = false,
                })
                break
            end
        end
    end
end

----------------------------------------------------------------
-- People
----------------------------------------------------------------
local SKIN = { Color3.fromRGB(255, 220, 185), Color3.fromRGB(230, 185, 140), Color3.fromRGB(190, 135, 95), Color3.fromRGB(130, 85, 55), Color3.fromRGB(90, 60, 40) }
local SHIRTS = { Color3.fromRGB(200, 40, 40), Color3.fromRGB(40, 90, 200), Color3.fromRGB(240, 240, 240), Color3.fromRGB(30, 30, 30), Color3.fromRGB(60, 150, 80), Color3.fromRGB(240, 190, 40), Color3.fromRGB(150, 60, 160), Color3.fromRGB(240, 130, 50) }
local PANTS = { Color3.fromRGB(30, 40, 70), Color3.fromRGB(25, 25, 28), Color3.fromRGB(110, 90, 60), Color3.fromRGB(80, 80, 85), Color3.fromRGB(60, 40, 30) }
local HAIR = { Color3.fromRGB(30, 20, 15), Color3.fromRGB(90, 60, 30), Color3.fromRGB(200, 170, 90), Color3.fromRGB(20, 20, 20), Color3.fromRGB(140, 60, 30) }

local function pick(list)
    return list[math.random(1, #list)]
end

local function buildPerson()
    local skin, shirt, pants = pick(SKIN), pick(SHIRTS), pick(PANTS)
    local person = {
        legL = newPart(V(0.9, 2.2, 0.9), pants),
        legR = newPart(V(0.9, 2.2, 0.9), pants),
        torso = newPart(V(2, 2.2, 1.1), shirt),
        armL = newPart(V(0.7, 2, 0.7), shirt),
        armR = newPart(V(0.7, 2, 0.7), shirt),
        head = newPart(V(1.3, 1.3, 1.3), skin),
    }
    if math.random() < 0.65 then
        person.hair = newPart(V(1.4, 0.45, 1.4), pick(HAIR))
    end
    local flat = {}
    for _, p in pairs(person) do
        table.insert(flat, p)
    end
    return person, flat
end

local people = {}
local inset = 2.9
if blocks and #blocks > 0 then
    for _ = 1, PEOPLE do
        local b = blocks[math.random(1, #blocks)]
        local sideLen = b.s - inset * 2
        local body, flat = buildPerson()
        table.insert(people, {
            block = b,
            sideLen = sideLen,
            p = math.random() * sideLen * 4,
            dir = math.random() < 0.5 and 1 or -1,
            speed = 3.5 + math.random() * 2,
            pause = 0,
            phase = math.random() * 6,
            lateral = (math.random() - 0.5) * 1.4,
            body = body,
            flat = flat,
            shown = false,
        })
    end
end

local function sidewalkPoint(person)
    local b, L = person.block, person.sideLen
    local i = inset + person.lateral
    local p = person.p % (L * 4)
    local side = math.floor(p / L)
    local t = p - side * L
    local x0, z0, s = b.x0, b.z0, b.s
    local pos, along
    if side == 0 then
        pos, along = V(x0 + i + t, b.y, z0 + i), V(1, 0, 0)
    elseif side == 1 then
        pos, along = V(x0 + s - i, b.y, z0 + i + t), V(0, 0, 1)
    elseif side == 2 then
        pos, along = V(x0 + s - i - t, b.y, z0 + s - i), V(-1, 0, 0)
    else
        pos, along = V(x0 + i, b.y, z0 + s - i - t), V(0, 0, -1)
    end
    return pos, along * person.dir
end

----------------------------------------------------------------
-- Update every frame
----------------------------------------------------------------
RunService.Heartbeat:Connect(function(dt)
    dt = math.min(dt, 0.1)
    local now = os.clock()
    -- [REX] never cache the camera; it is swapped when the character loads
    local camera = workspace.CurrentCamera
    if not camera then
        return
    end
    local camPos = camera.CFrame.Position
    local movedParts, movedCFrames = {}, {}

    -- [REX] send anything that just went out of range back under the map
    local function park(entity)
        if entity.shown then
            entity.shown = false
            for _, p in ipairs(entity.flat) do
                table.insert(movedParts, p)
                table.insert(movedCFrames, PARKED)
            end
        end
    end

    local roots = {}
    for _, player in ipairs(Players:GetPlayers()) do
        local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if root then
            table.insert(roots, root.Position)
        end
    end

    -- Cars
    for _, car in ipairs(cars) do
        local pos, tangent
        if car.mode == "straight" then
            local g = geom(car.a, car.b)
            local limit = g.length
            local node = nodes[car.b]
            if node.light then
                local axis = math.abs(g.d.X) > 0.5 and "X" or "Z"
                local state = signal(node.o, axis)
                if state == "red" or (state == "yellow" and g.length - car.s > 8) then
                    limit = g.length - 1
                end
            end
            for _, other in ipairs(cars) do
                if other ~= car and other.mode == "straight" and other.a == car.a and other.b == car.b and other.s > car.s then
                    limit = math.min(limit, other.s - 12)
                end
            end
            local here = g.startP + g.d * car.s
            for _, rootPos in ipairs(roots) do
                local rel = rootPos - here
                local ahead = rel:Dot(g.d)
                if ahead > 0 and ahead < 14 and math.abs(rel:Dot(g.right)) < 3.5 and math.abs(rel.Y) < 8 then
                    limit = math.min(limit, car.s + ahead - 8)
                end
            end
            local gap = limit - car.s
            local target = CAR_SPEED
            if gap < 0.5 then
                target = 0
            elseif gap < 25 then
                target = math.min(target, gap * 1.4)
            end
            car.v += (target - car.v) * math.min(1, dt * 3)
            car.s = math.min(car.s + car.v * dt, math.max(limit, car.s))
            if car.s >= g.length - 0.01 then
                startTurn(car)
            end
            pos, tangent = g.startP + g.d * car.s, g.d
        end
        if car.mode == "turn" then
            car.v += (math.min(CAR_SPEED, 15) - car.v) * math.min(1, dt * 3)
            car.u = math.min(car.u + car.v * dt / car.turnLength, 1)
            local p0, p1, p2 = car.turn[1], car.turn[2], car.turn[3]
            pos = bezier(p0, p1, p2, car.u)
            tangent = bezierTangent(p0, p1, p2, car.u)
            if tangent.Magnitude < 0.01 then
                tangent = geom(car.b, car.c).d
            end
            if car.u >= 1 then
                car.mode = "straight"
                car.a, car.b, car.s = car.b, car.c, 0
            end
        end
        if (pos - camPos).Magnitude < DRAW_DISTANCE then
            car.shown = true
            local cf = CFrame.lookAt(pos, pos + V(tangent.X, 0, tangent.Z))
            for _, item in ipairs(car.parts) do
                table.insert(movedParts, item.part)
                table.insert(movedCFrames, cf * item.offset)
            end
        else
            park(car)
        end
    end

    -- People
    for _, person in ipairs(people) do
        if person.pause > 0 then
            person.pause -= dt
        else
            person.p += person.dir * person.speed * dt
            if math.random() < dt * 0.04 then
                person.pause = 2 + math.random() * 4
            end
        end
        local pos, forward = sidewalkPoint(person)
        if (pos - camPos).Magnitude < DRAW_DISTANCE then
            person.shown = true
            local root = CFrame.lookAt(pos, pos + forward)
            local swing = person.pause > 0 and 0 or math.sin(now * person.speed * 2.2 + person.phase) * 0.7
            local body = person.body
            local list = {
                { body.legL, root * CFrame.new(-0.5, 2.2, 0) * CFrame.Angles(swing, 0, 0) * CFrame.new(0, -1.1, 0) },
                { body.legR, root * CFrame.new(0.5, 2.2, 0) * CFrame.Angles(-swing, 0, 0) * CFrame.new(0, -1.1, 0) },
                { body.torso, root * CFrame.new(0, 3.3, 0) },
                { body.armL, root * CFrame.new(-1.35, 4.3, 0) * CFrame.Angles(-swing, 0, 0) * CFrame.new(0, -0.95, 0) },
                { body.armR, root * CFrame.new(1.35, 4.3, 0) * CFrame.Angles(swing, 0, 0) * CFrame.new(0, -0.95, 0) },
                { body.head, root * CFrame.new(0, 5.1, 0) },
            }
            if body.hair then
                table.insert(list, { body.hair, root * CFrame.new(0, 5.85, 0.05) })
            end
            for _, item in ipairs(list) do
                table.insert(movedParts, item[1])
                table.insert(movedCFrames, item[2])
            end
        else
            park(person)
        end
    end

    if #movedParts > 0 then
        workspace:BulkMoveTo(movedParts, movedCFrames, Enum.BulkMoveMode.FireCFrameChanged)
    end
end)

print(string.format("[CityTraffic] %d cars on %d nodes, %d people on %d blocks",
    #cars, #nodes, #people, blocks and #blocks or 0))
