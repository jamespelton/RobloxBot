-- PARKED CARS (fills the CasinoParkingLot automatically)
-- Written by James. Changes from the original are marked [REX]:
--   1. the lot lives at Workspace.Casino.CasinoParkingLot, not at the Workspace
--      root, so the original WaitForChild would have stalled 15 seconds and
--      then built nothing. Looks in the Casino folder first.
--   2. PrimaryPart is left unset. A Model with a PrimaryPart ignores its
--      WorldPivot, so PivotTo would have landed the HITBOX CENTRE on the
--      ground and sunk every car about 2.4 studs into the asphalt. With no
--      PrimaryPart the WorldPivot at (0,0,0) is used, which is where the
--      wheels sit. The hitbox part itself is unchanged and still collides.
--   3. parented into the Casino folder and replaced on re-run.
-- The car geometry is untouched.

-- Settings:
local FILL_CHANCE = 0.5            -- chance a normal space has a car (0 to 1)
local VIP_FILL_CHANCE = 0.75       -- chance a VIP space has a car
local ACCESSIBLE_FILL_CHANCE = 0.3 -- chance an accessible space has a car
local BACK_IN_CHANCE = 0.2         -- chance a car is backed into its space
local SEED = 11                    -- change for a different mix of cars
local PARENT_NAME = "Casino"       -- [REX] folder under Workspace; falls back to Workspace
local EXTRA_CARS = {
    -- Cars anywhere else: { position, rotation in degrees, "sedan" / "suv" / "sports" },
    -- { Vector3.new(0, 0, 0), 0, "sedan" },
}

local CAR_TYPES = {
    sedan = { L = 15, W = 6.6, bottom = 0.8, belt = 3.2, cabinH = 2.0, hood = 4.8, trunk = 3.0, wsRun = 2.4, rearRun = 1.8, wheelR = 1.25, doors = 4 },
    suv = { L = 15.5, W = 7, bottom = 1.1, belt = 3.9, cabinH = 2.5, hood = 4.0, trunk = 0.8, wsRun = 2.2, rearRun = 0.5, wheelR = 1.5, doors = 4, rails = true },
    sports = { L = 14.5, W = 6.8, bottom = 0.6, belt = 2.9, cabinH = 1.5, hood = 5.4, trunk = 2.4, wsRun = 2.6, rearRun = 2.2, wheelR = 1.2, doors = 2, spoiler = true },
}

local PAINTS = {
    Color3.fromRGB(245, 245, 245), Color3.fromRGB(20, 20, 22), Color3.fromRGB(170, 172, 175),
    Color3.fromRGB(95, 97, 100), Color3.fromRGB(25, 45, 90), Color3.fromRGB(150, 20, 25),
    Color3.fromRGB(30, 60, 40), Color3.fromRGB(200, 190, 170), Color3.fromRGB(60, 30, 25),
    Color3.fromRGB(40, 90, 150),
}
local VIP_PAINTS = {
    Color3.fromRGB(15, 15, 17), Color3.fromRGB(245, 245, 245), Color3.fromRGB(170, 15, 20),
    Color3.fromRGB(190, 160, 90),
}

local GLASS = { Color = Color3.fromRGB(20, 25, 30), Material = Enum.Material.Glass, Transparency = 0.35, Reflectance = 0.25 }
local BLACK = { Color = Color3.fromRGB(25, 25, 25), Material = Enum.Material.SmoothPlastic }
local CHROME = { Color = Color3.fromRGB(200, 200, 205), Material = Enum.Material.Metal, Reflectance = 0.4 }
local SILVER_RIM = { Color = Color3.fromRGB(180, 182, 186), Material = Enum.Material.Metal, Reflectance = 0.3 }
local GOLD_RIM = { Color = Color3.fromRGB(212, 175, 55), Material = Enum.Material.Metal, Reflectance = 0.35 }
local TIRE = { Color = Color3.fromRGB(28, 28, 28), Material = Enum.Material.Rubber }
local HEADLIGHT = { Color = Color3.fromRGB(235, 235, 225), Material = Enum.Material.Glass, Transparency = 0.1, Reflectance = 0.4 }
local AMBER = { Color = Color3.fromRGB(255, 150, 30), Material = Enum.Material.Glass, Transparency = 0.15 }
local TAIL = { Color = Color3.fromRGB(170, 15, 20), Material = Enum.Material.Glass, Transparency = 0.1, Reflectance = 0.2 }
local INTERIOR = { Color = Color3.fromRGB(40, 38, 36), Material = Enum.Material.Fabric }
local SEAT = { Color = Color3.fromRGB(55, 50, 45), Material = Enum.Material.Leather }
local SEAM = { Color = Color3.fromRGB(15, 15, 15), Material = Enum.Material.SmoothPlastic }
local PLATE = { Color = Color3.fromRGB(240, 240, 240), Material = Enum.Material.SmoothPlastic }
local CALIPER = { Color = Color3.fromRGB(190, 20, 25), Material = Enum.Material.SmoothPlastic }

local rng = Random.new(SEED)
local function rand(a, b)
    return rng:NextNumber(a, b)
end

local folder = Instance.new("Folder")
folder.Name = "ParkedCars"
local current

----------------------------------------------------------------
-- Building helpers
----------------------------------------------------------------
local function makePart(props)
    local p = Instance.new("Part")
    p.Anchored = true
    p.CanCollide = false
    p.CanTouch = false
    p.CanQuery = false
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    for key, value in pairs(props) do
        p[key] = value
    end
    p.Parent = current
    return p
end

local function styled(props, style)
    for key, value in pairs(style) do
        props[key] = value
    end
    return makePart(props)
end

local function box(cframe, size, style)
    return styled({ Size = size, CFrame = cframe }, style)
end

local function upFor(direction)
    return math.abs(direction.Y) > 0.99 and Vector3.new(1, 0, 0) or Vector3.new(0, 1, 0)
end

local function rod(a, b, thickness, style)
    local direction = (b - a).Unit
    return styled({
        Shape = Enum.PartType.Cylinder,
        Size = Vector3.new((b - a).Magnitude, thickness, thickness),
        CFrame = CFrame.lookAt((a + b) / 2, b, upFor(direction)) * CFrame.Angles(0, math.rad(90), 0),
    }, style)
end

-- Flat panel stretched from point a to point b (used for windshields)
local function panel(a, b, width, style)
    return box(CFrame.lookAt((a + b) / 2, b, upFor((b - a).Unit)), Vector3.new(width, 0.1, (b - a).Magnitude), style)
end

local function cylinderX(pos, length, diameter, style)
    return styled({
        Shape = Enum.PartType.Cylinder,
        Size = Vector3.new(length, diameter, diameter),
        CFrame = CFrame.new(pos),
    }, style)
end

local function plateText()
    local letters = ""
    for _ = 1, 3 do
        letters = letters .. string.char(rng:NextInteger(65, 90))
    end
    return letters .. " " .. rng:NextInteger(1000, 9999)
end

local function addPlateText(p, face, text)
    local gui = Instance.new("SurfaceGui")
    gui.Face = face
    gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    gui.PixelsPerStud = 60
    gui.Parent = p
    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(20, 40, 110)
    label.TextScaled = true
    label.Font = Enum.Font.GothamBold
    label.Parent = gui
end

----------------------------------------------------------------
-- Build one car (front of the car points toward -Z, wheels on y = 0)
----------------------------------------------------------------
local function buildCar(kind, paintColor, fancy)
    local s = CAR_TYPES[kind]
    current = Instance.new("Model")
    current.Name = kind:sub(1, 1):upper() .. kind:sub(2)

    local PAINT = { Color = paintColor, Material = Enum.Material.SmoothPlastic, Reflectance = 0.15 }
    local L, W, r, belt = s.L, s.W, s.wheelR, s.belt
    local frontEdge, rearEdge = -L / 2 + 0.6, L / 2 - 0.6
    local zF, zR = -L / 2 + 3, L / 2 - 3
    local wellTop = 2 * r + 0.15

    -- Body (lower sections leave open wheel wells)
    local function lower(z1, z2)
        if z2 > z1 then
            box(CFrame.new(0, (s.bottom + wellTop) / 2, (z1 + z2) / 2), Vector3.new(W, wellTop - s.bottom, z2 - z1), PAINT)
        end
    end
    lower(frontEdge, zF - r - 0.2)
    lower(zF + r + 0.2, zR - r - 0.2)
    lower(zR + r + 0.2, rearEdge)
    box(CFrame.new(0, (wellTop + belt) / 2, 0), Vector3.new(W, belt - wellTop, rearEdge - frontEdge), PAINT)

    -- Dark wheel well liners
    for _, z in ipairs({ zF, zR }) do
        box(CFrame.new(0, (0.3 + wellTop) / 2, z), Vector3.new(W - 2, wellTop - 0.3, 2 * r + 0.4), BLACK)
    end

    -- Bumpers with black lower lips
    for _, sign in ipairs({ -1, 1 }) do
        box(CFrame.new(0, s.bottom + 0.45, sign * (L / 2 - 0.3)), Vector3.new(W - 0.2, 0.9, 0.6), PAINT)
        box(CFrame.new(0, s.bottom + 0.1, sign * (L / 2 - 0.35)), Vector3.new(W - 0.6, 0.25, 0.62), BLACK)
    end

    -- Grille with chrome bars
    box(CFrame.new(0, belt - 0.9, frontEdge - 0.03), Vector3.new(2.8, 0.8, 0.1), BLACK)
    for k = -1, 1 do
        box(CFrame.new(0, belt - 0.9 + k * 0.25, frontEdge - 0.07), Vector3.new(2.7, 0.06, 0.04), CHROME)
    end

    -- Lights
    for _, side in ipairs({ -1, 1 }) do
        box(CFrame.new(side * (W / 2 - 1.25), belt - 0.45, frontEdge - 0.03), Vector3.new(1.3, 0.45, 0.1), HEADLIGHT)
        box(CFrame.new(side * (W / 2 - 0.35), belt - 0.45, frontEdge - 0.03), Vector3.new(0.4, 0.3, 0.1), AMBER)
        box(CFrame.new(side * (W / 2 - 1.0), belt - 0.45, rearEdge + 0.03), Vector3.new(1.6, 0.45, 0.1), TAIL)
        box(CFrame.new(side * (W / 2 + 0.01), belt - 0.45, rearEdge - 0.3), Vector3.new(0.08, 0.4, 0.6), TAIL)
    end

    -- License plates
    local front = box(CFrame.new(0, s.bottom + 0.45, -L / 2 - 0.03), Vector3.new(1.6, 0.5, 0.05), PLATE)
    addPlateText(front, Enum.NormalId.Front, plateText())
    local rear = box(CFrame.new(0, belt - 1.25, rearEdge + 0.03), Vector3.new(1.6, 0.5, 0.05), PLATE)
    addPlateText(rear, Enum.NormalId.Back, plateText())

    -- Cabin: windshields, roof, side windows, pillars
    local baseF, baseR = -L / 2 + s.hood, L / 2 - s.trunk
    local roofF, roofR = baseF + s.wsRun, baseR - s.rearRun
    local top = belt + s.cabinH
    local xg = W / 2 - 0.45

    panel(Vector3.new(0, belt, baseF), Vector3.new(0, top, roofF), W - 0.9, GLASS)
    panel(Vector3.new(0, top, roofR), Vector3.new(0, belt, baseR), W - 0.9, GLASS)
    box(CFrame.new(0, top + 0.05, (roofF + roofR) / 2), Vector3.new(W - 0.7, 0.2, roofR - roofF + 0.4), PAINT)

    local strips = 6
    for k = 0, strips - 1 do
        local t = (k + 0.5) / strips
        local zf = baseF + (roofF - baseF) * t
        local zr = baseR + (roofR - baseR) * t
        for _, side in ipairs({ -1, 1 }) do
            box(CFrame.new(side * xg, belt + s.cabinH * t, (zf + zr) / 2), Vector3.new(0.08, s.cabinH / strips + 0.01, zr - zf), GLASS)
        end
    end

    -- Door positions
    local frontSeam = baseF - 0.2
    local rearSeam = zR - r - 0.4
    local zB = (frontSeam + rearSeam) / 2
    local doors = s.doors == 4 and { { frontSeam, zB }, { zB, rearSeam } } or { { frontSeam, frontSeam + 4.2 } }

    for _, side in ipairs({ -1, 1 }) do
        rod(Vector3.new(side * xg, belt, baseF), Vector3.new(side * xg, top, roofF), 0.28, PAINT)
        rod(Vector3.new(side * xg, top, roofR), Vector3.new(side * xg, belt, baseR), 0.28, PAINT)
        rod(Vector3.new(side * xg, top, roofF), Vector3.new(side * xg, top, roofR), 0.28, PAINT)
        if s.doors == 4 then
            box(CFrame.new(side * (xg + 0.03), belt + s.cabinH / 2, zB), Vector3.new(0.12, s.cabinH, 0.4), BLACK)
        end

        -- Chrome trim along the windows
        box(CFrame.new(side * (W / 2 + 0.01), belt, (baseF + baseR) / 2), Vector3.new(0.04, 0.08, baseR - baseF), CHROME)

        -- Door seams and handles
        local x = side * (W / 2 + 0.01)
        for _, door in ipairs(doors) do
            for _, z in ipairs(door) do
                box(CFrame.new(x, (s.bottom + 0.2 + belt) / 2, z), Vector3.new(0.02, belt - s.bottom - 0.2, 0.06), SEAM)
            end
            box(CFrame.new(side * (W / 2 + 0.03), belt - 0.35, door[2] - 0.6), Vector3.new(0.06, 0.12, 0.6), CHROME)
        end

        -- Side mirror
        box(CFrame.new(side * (W / 2 + 0.15), belt + 0.3, baseF + 0.35), Vector3.new(0.4, 0.12, 0.12), BLACK)
        box(CFrame.new(side * (W / 2 + 0.45), belt + 0.35, baseF + 0.45), Vector3.new(0.55, 0.4, 0.25), PAINT)
        box(CFrame.new(side * (W / 2 + 0.45), belt + 0.35, baseF + 0.59), Vector3.new(0.45, 0.3, 0.03), CHROME)

        -- Hood seams
        box(CFrame.new(side * (W / 2 - 0.5), belt + 0.01, (frontEdge + baseF) / 2), Vector3.new(0.05, 0.02, baseF - frontEdge), SEAM)
    end
    box(CFrame.new(0, belt + 0.01, baseF - 0.25), Vector3.new(W - 1, 0.02, 0.05), SEAM)

    -- Trunk seams
    if s.trunk >= 1.5 then
        box(CFrame.new(0, belt + 0.01, baseR + 0.25), Vector3.new(W - 1.2, 0.02, 0.05), SEAM)
        for _, side in ipairs({ -1, 1 }) do
            box(CFrame.new(side * (W / 2 - 0.6), belt + 0.01, (baseR + 0.25 + rearEdge) / 2), Vector3.new(0.05, 0.02, rearEdge - baseR - 0.25), SEAM)
        end
    end

    -- Interior
    box(CFrame.new(0, belt + 0.03, (baseF + baseR) / 2), Vector3.new(W - 1, 0.05, baseR - baseF), INTERIOR)
    local dashZ = baseF + s.wsRun * 0.45
    box(CFrame.new(0, belt + 0.2, dashZ), Vector3.new(W - 1, 0.4, 0.8), INTERIOR)
    styled({
        Shape = Enum.PartType.Cylinder,
        Size = Vector3.new(0.1, 0.8, 0.8),
        CFrame = CFrame.new(-W / 4, belt + 0.6, dashZ + 0.7) * CFrame.Angles(math.rad(25), 0, 0) * CFrame.Angles(0, math.rad(90), 0),
    }, BLACK)

    local backH = s.cabinH * 0.6
    local function seat(x, z, width)
        box(CFrame.new(x, belt + 0.1, z - 0.7), Vector3.new(width, 0.4, 1.3), SEAT)
        box(CFrame.new(x, belt + backH / 2, z), Vector3.new(width, backH, 0.3), SEAT)
    end
    local frontSeatZ = baseF + s.wsRun + 0.6
    for _, side in ipairs({ -1, 1 }) do
        seat(side * W / 4, frontSeatZ, 1.6)
        box(CFrame.new(side * W / 4, belt + backH + 0.15, frontSeatZ), Vector3.new(0.9, 0.35, 0.25), SEAT)
    end
    if s.doors == 4 then
        seat(0, frontSeatZ + 2.4, W - 1.4)
    end

    -- Wheels
    local rimStyle = fancy and GOLD_RIM or SILVER_RIM
    for _, z in ipairs({ zF, zR }) do
        for _, side in ipairs({ -1, 1 }) do
            cylinderX(Vector3.new(side * (W / 2 - 0.45), r, z), 1.0, 2 * r, TIRE)
            local face = side * (W / 2 + 0.05)
            cylinderX(Vector3.new(face, r, z), 0.06, 2 * r * 0.62, rimStyle)
            cylinderX(Vector3.new(face + side * 0.04, r, z), 0.1, 0.45, rimStyle)
            for k = 0, 4 do
                box(CFrame.new(face + side * 0.03, r, z) * CFrame.Angles(k * math.pi * 2 / 5, 0, 0) * CFrame.new(0, 0, r * 0.3),
                    Vector3.new(0.05, 0.18, r * 0.58), rimStyle)
            end
            if fancy then
                box(CFrame.new(face - side * 0.06, r + 0.35, z - 0.3), Vector3.new(0.1, 0.4, 0.6), CALIPER)
            end
        end
    end

    -- Exhaust
    local exhausts = s.spoiler and { -W / 3, W / 3 } or { W / 3 }
    for _, x in ipairs(exhausts) do
        styled({
            Shape = Enum.PartType.Cylinder,
            Size = Vector3.new(0.6, 0.3, 0.3),
            CFrame = CFrame.new(x, s.bottom + 0.15, L / 2 - 0.1) * CFrame.Angles(0, math.rad(90), 0),
        }, CHROME)
    end

    -- Roof rails (SUV)
    if s.rails then
        for _, side in ipairs({ -1, 1 }) do
            local x = side * (W / 2 - 0.9)
            rod(Vector3.new(x, top + 0.4, roofF + 0.3), Vector3.new(x, top + 0.4, roofR - 0.3), 0.15, BLACK)
            for _, z in ipairs({ roofF + 0.5, roofR - 0.5 }) do
                box(CFrame.new(x, top + 0.27, z), Vector3.new(0.15, 0.25, 0.3), BLACK)
            end
        end
    end

    -- Rear spoiler (sports)
    if s.spoiler then
        box(CFrame.new(0, belt + 0.55, L / 2 - 1.2), Vector3.new(W - 0.8, 0.1, 0.8), PAINT)
        for _, side in ipairs({ -1, 1 }) do
            box(CFrame.new(side * (W / 2 - 1.4), belt + 0.25, L / 2 - 1.2), Vector3.new(0.15, 0.5, 0.3), BLACK)
        end
    end

    -- Invisible collision box so players can't walk through
    makePart({
        Name = "Hitbox",
        Size = Vector3.new(W, top - 0.3, L),
        CFrame = CFrame.new(0, (top + 0.3) / 2, 0),
        Transparency = 1,
        CanCollide = true,
        CanQuery = true,
    })

    -- [REX] No PrimaryPart. A Model with one ignores its WorldPivot, so PivotTo
    -- would place the hitbox CENTRE at the target and bury the car roughly 2.4
    -- studs in the tarmac. Leaving it unset makes the pivot below authoritative,
    -- and that sits exactly on the wheels.
    current.WorldPivot = CFrame.new(0, 0, 0)
    return current, s
end

local function pick(list)
    return list[rng:NextInteger(1, #list)]
end

----------------------------------------------------------------
-- Fill the parking lot
----------------------------------------------------------------
-- [REX] the lot is parented inside the Casino folder, not at the Workspace root
local parentFolder = workspace:FindFirstChild(PARENT_NAME) or workspace
local lot = parentFolder:FindFirstChild("CasinoParkingLot")
    or workspace:FindFirstChild("CasinoParkingLot")

local STOP_SIZE = Vector3.new(6, 0.5, 0.9)
local built = 0

if lot then
    for _, stop in ipairs(lot:GetChildren()) do
        if stop:IsA("BasePart") and (stop.Size - STOP_SIZE).Magnitude < 0.01 then
            local isVip = stop.Material == Enum.Material.Metal
            local isAccessible = stop.Color.B > 0.6 and stop.Color.R < 0.3
            local chance = isVip and VIP_FILL_CHANCE or (isAccessible and ACCESSIBLE_FILL_CHANCE or FILL_CHANCE)

            if rng:NextNumber() < chance then
                local kind = isVip and "sports" or (rng:NextNumber() < 0.55 and "sedan" or "suv")
                local car, spec = buildCar(kind, pick(isVip and VIP_PAINTS or PAINTS), isVip)

                local look = stop.CFrame.LookVector -- points from the wheel stop toward the driving lane
                local ground = stop.Position - Vector3.new(0, 0.25, 0)
                local center = ground + look * (1.2 + spec.L / 2) + stop.CFrame.RightVector * rand(-0.4, 0.4)
                local backedIn = not isVip and rng:NextNumber() < BACK_IN_CHANCE
                local forward = CFrame.Angles(0, math.rad(rand(-3, 3)), 0) * (backedIn and look or -look)

                car:PivotTo(CFrame.lookAt(center, center + forward))
                car.Parent = folder
                built = built + 1
            end
        end
    end
elseif #EXTRA_CARS == 0 then
    warn("Parked cars: couldn't find CasinoParkingLot. Add positions to EXTRA_CARS instead.")
end

-- Extra cars placed by hand
for _, entry in ipairs(EXTRA_CARS) do
    local kind = CAR_TYPES[entry[3]] and entry[3] or "sedan"
    local car = buildCar(kind, pick(kind == "sports" and VIP_PAINTS or PAINTS), kind == "sports")
    car:PivotTo(CFrame.new(entry[1]) * CFrame.Angles(0, math.rad(entry[2] or 0), 0))
    car.Parent = folder
    built = built + 1
end

-- [REX] replace a previous run rather than stacking a second set of cars
local existing = parentFolder:FindFirstChild(folder.Name)
if existing then
    existing:Destroy()
end
folder.Parent = parentFolder

local parts = 0
for _, d in ipairs(folder:GetDescendants()) do
    if d:IsA("BasePart") then
        parts = parts + 1
    end
end
print(string.format("[ParkedCars] %s | %d cars, %d parts", folder:GetFullName(), built, parts))

return folder
