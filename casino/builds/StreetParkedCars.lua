-- STREET PARKED CARS
-- Parks a mix of cars along the kerbs of the city streets, in the same style
-- as the casino lot (it uses James's car builder from ParkedCars.lua).
--
-- Eight body styles: James's sedan, SUV and sports car, plus a hatchback,
-- coupe, pickup (open bed), passenger van and taxi (roof sign + checker band).
--
-- Where they go:
--   * only streets at least MIN_STREET_WIDTH wide. The 18-stud infill streets
--     are too narrow to park on and still leave two lanes for the traffic.
--   * kerbside, nose pointing with the traffic on that side of the road.
--   * never within CORNER_CLEAR of an intersection, so crossings and turning
--     traffic stay clear.
--   * every car is checked before it is kept: tarmac under all four corners,
--     and nothing (lamp posts, trees, kerbs, other cars) inside its footprint.
--   * streets near the casino fill up more than the far edges of the city.
--
-- Safe to re-run: it replaces Workspace.StreetParkedCars rather than stacking.
-- Change SEED for a different arrangement, TARGET_CARS for more or fewer.

local CFG = {
    TARGET_CARS = 70,          -- ~125 parts per car
    SEED = 23,
    MIN_STREET_WIDTH = 24,
    CURB_GAP = 0.2,            -- space between the tyres and the kerb
    CORNER_CLEAR = 14,         -- keep this far from the end of each street
    STALL = 19.5,              -- length of one kerbside space (longest car is 17)
    NEAR_CASINO = 450,         -- streets within roughly this distance fill fastest
    SHADOW_MIN_SIZE = 1.5,     -- matches CityPerformance: small parts cast no shadow
    FOLDER = "StreetParkedCars",
}

local MIX = { -- relative chance of each style
    { "sedan", 22 }, { "suv", 18 }, { "hatchback", 14 }, { "pickup", 12 },
    { "van", 9 }, { "taxi", 9 }, { "coupe", 9 }, { "sports", 7 },
}

local CAR_TYPES = {
    sedan = { L = 15, W = 6.6, bottom = 0.8, belt = 3.2, cabinH = 2.0, hood = 4.8, trunk = 3.0, wsRun = 2.4, rearRun = 1.8, wheelR = 1.25, doors = 4 },
    suv = { L = 15.5, W = 7, bottom = 1.1, belt = 3.9, cabinH = 2.5, hood = 4.0, trunk = 0.8, wsRun = 2.2, rearRun = 0.5, wheelR = 1.5, doors = 4, rails = true },
    sports = { L = 14.5, W = 6.8, bottom = 0.6, belt = 2.9, cabinH = 1.5, hood = 5.4, trunk = 2.4, wsRun = 2.6, rearRun = 2.2, wheelR = 1.2, doors = 2, spoiler = true },
    hatchback = { L = 13, W = 6.4, bottom = 0.8, belt = 3.1, cabinH = 2.1, hood = 4.0, trunk = 0.6, wsRun = 2.4, rearRun = 0.7, wheelR = 1.2, doors = 4 },
    coupe = { L = 14.8, W = 6.6, bottom = 0.7, belt = 3.0, cabinH = 1.8, hood = 5.0, trunk = 2.8, wsRun = 2.6, rearRun = 2.4, wheelR = 1.25, doors = 2 },
    pickup = { L = 17, W = 7, bottom = 1.2, belt = 3.9, cabinH = 2.4, hood = 4.4, trunk = 6.4, wsRun = 1.8, rearRun = 0.3, wheelR = 1.55, doors = 4, bed = true },
    van = { L = 16.5, W = 6.8, bottom = 1.0, belt = 3.4, cabinH = 3.4, hood = 2.6, trunk = 0.15, wsRun = 2.0, rearRun = 0.25, wheelR = 1.35, doors = 4, van = true },
    taxi = { L = 15, W = 6.6, bottom = 0.8, belt = 3.2, cabinH = 2.0, hood = 4.8, trunk = 3.0, wsRun = 2.4, rearRun = 1.8, wheelR = 1.25, doors = 4, taxi = true },
}

local PAINTS = {
    Color3.fromRGB(245, 245, 245), Color3.fromRGB(20, 20, 22), Color3.fromRGB(170, 172, 175),
    Color3.fromRGB(95, 97, 100), Color3.fromRGB(25, 45, 90), Color3.fromRGB(150, 20, 25),
    Color3.fromRGB(30, 60, 40), Color3.fromRGB(200, 190, 170), Color3.fromRGB(60, 30, 25),
    Color3.fromRGB(40, 90, 150), Color3.fromRGB(210, 110, 30), Color3.fromRGB(90, 130, 110),
}
local SPORTS_PAINTS = {
    Color3.fromRGB(15, 15, 17), Color3.fromRGB(245, 245, 245), Color3.fromRGB(170, 15, 20),
    Color3.fromRGB(230, 190, 40), Color3.fromRGB(20, 90, 200), Color3.fromRGB(240, 110, 20),
}
local TAXI_YELLOW = Color3.fromRGB(245, 195, 25)

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
local BED_LINER = { Color = Color3.fromRGB(35, 35, 37), Material = Enum.Material.Slate }
local TAXI_SIGN = { Color = Color3.fromRGB(255, 240, 200), Material = Enum.Material.Neon }
local CHECKER_DARK = { Color = Color3.fromRGB(20, 20, 20), Material = Enum.Material.SmoothPlastic }

local rng = Random.new(CFG.SEED)
local function rand(a, b)
    return rng:NextNumber(a, b)
end
local function pick(list)
    return list[rng:NextInteger(1, #list)]
end

local folder = Instance.new("Folder")
folder.Name = CFG.FOLDER
local current

----------------------------------------------------------------
-- Building helpers (from ParkedCars.lua)
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

local function addSurfaceText(p, face, text, color, ppS)
    local gui = Instance.new("SurfaceGui")
    gui.Face = face
    gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    gui.PixelsPerStud = ppS or 60
    gui.Parent = p
    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = color
    label.TextScaled = true
    label.Font = Enum.Font.GothamBold
    label.Parent = gui
end

----------------------------------------------------------------
-- Build one car (front points toward -Z, wheels on y = 0)
----------------------------------------------------------------
local function buildCar(kind, paintColor)
    local s = CAR_TYPES[kind]
    current = Instance.new("Model")
    current.Name = kind:sub(1, 1):upper() .. kind:sub(2)

    local fancy = kind == "sports"
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

    for _, z in ipairs({ zF, zR }) do
        box(CFrame.new(0, (0.3 + wellTop) / 2, z), Vector3.new(W - 2, wellTop - 0.3, 2 * r + 0.4), BLACK)
    end

    for _, sign in ipairs({ -1, 1 }) do
        box(CFrame.new(0, s.bottom + 0.45, sign * (L / 2 - 0.3)), Vector3.new(W - 0.2, 0.9, 0.6), PAINT)
        box(CFrame.new(0, s.bottom + 0.1, sign * (L / 2 - 0.35)), Vector3.new(W - 0.6, 0.25, 0.62), BLACK)
    end

    box(CFrame.new(0, belt - 0.9, frontEdge - 0.03), Vector3.new(2.8, 0.8, 0.1), BLACK)
    for k = -1, 1 do
        box(CFrame.new(0, belt - 0.9 + k * 0.25, frontEdge - 0.07), Vector3.new(2.7, 0.06, 0.04), CHROME)
    end

    for _, side in ipairs({ -1, 1 }) do
        box(CFrame.new(side * (W / 2 - 1.25), belt - 0.45, frontEdge - 0.03), Vector3.new(1.3, 0.45, 0.1), HEADLIGHT)
        box(CFrame.new(side * (W / 2 - 0.35), belt - 0.45, frontEdge - 0.03), Vector3.new(0.4, 0.3, 0.1), AMBER)
        box(CFrame.new(side * (W / 2 - 1.0), belt - 0.45, rearEdge + 0.03), Vector3.new(1.6, 0.45, 0.1), TAIL)
        box(CFrame.new(side * (W / 2 + 0.01), belt - 0.45, rearEdge - 0.3), Vector3.new(0.08, 0.4, 0.6), TAIL)
    end

    local plateBlue = Color3.fromRGB(20, 40, 110)
    local front = box(CFrame.new(0, s.bottom + 0.45, -L / 2 - 0.03), Vector3.new(1.6, 0.5, 0.05), PLATE)
    addSurfaceText(front, Enum.NormalId.Front, plateText(), plateBlue)
    local rear = box(CFrame.new(0, belt - 1.25, rearEdge + 0.03), Vector3.new(1.6, 0.5, 0.05), PLATE)
    addSurfaceText(rear, Enum.NormalId.Back, plateText(), plateBlue)

    -- Cabin
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

    -- Doors. The rear seam never runs past the back of the cabin, so a pickup's
    -- rear door stops at the cab instead of continuing down the bed.
    local frontSeam = baseF - 0.2
    local rearSeam = math.min(zR - r - 0.4, baseR - 0.1)
    local zB = (frontSeam + rearSeam) / 2
    local doors = s.doors == 4 and { { frontSeam, zB }, { zB, rearSeam } } or { { frontSeam, frontSeam + 4.2 } }

    for _, side in ipairs({ -1, 1 }) do
        rod(Vector3.new(side * xg, belt, baseF), Vector3.new(side * xg, top, roofF), 0.28, PAINT)
        rod(Vector3.new(side * xg, top, roofR), Vector3.new(side * xg, belt, baseR), 0.28, PAINT)
        rod(Vector3.new(side * xg, top, roofF), Vector3.new(side * xg, top, roofR), 0.28, PAINT)
        if s.doors == 4 then
            box(CFrame.new(side * (xg + 0.03), belt + s.cabinH / 2, zB), Vector3.new(0.12, s.cabinH, 0.4), BLACK)
        end
        if s.van then
            -- extra pillar behind the sliding door
            box(CFrame.new(side * (xg + 0.03), belt + s.cabinH / 2, rearSeam + 3.2), Vector3.new(0.12, s.cabinH, 0.4), BLACK)
            box(CFrame.new(side * (W / 2 + 0.02), belt - 0.15, (zB + rearSeam) / 2), Vector3.new(0.04, 0.06, rearSeam - zB), CHROME)
        end

        box(CFrame.new(side * (W / 2 + 0.01), belt, (baseF + baseR) / 2), Vector3.new(0.04, 0.08, baseR - baseF), CHROME)

        local x = side * (W / 2 + 0.01)
        for _, door in ipairs(doors) do
            for _, z in ipairs(door) do
                box(CFrame.new(x, (s.bottom + 0.2 + belt) / 2, z), Vector3.new(0.02, belt - s.bottom - 0.2, 0.06), SEAM)
            end
            box(CFrame.new(side * (W / 2 + 0.03), belt - 0.35, door[2] - 0.6), Vector3.new(0.06, 0.12, 0.6), CHROME)
        end

        box(CFrame.new(side * (W / 2 + 0.15), belt + 0.3, baseF + 0.35), Vector3.new(0.4, 0.12, 0.12), BLACK)
        box(CFrame.new(side * (W / 2 + 0.45), belt + 0.35, baseF + 0.45), Vector3.new(0.55, 0.4, 0.25), PAINT)
        box(CFrame.new(side * (W / 2 + 0.45), belt + 0.35, baseF + 0.59), Vector3.new(0.45, 0.3, 0.03), CHROME)

        box(CFrame.new(side * (W / 2 - 0.5), belt + 0.01, (frontEdge + baseF) / 2), Vector3.new(0.05, 0.02, baseF - frontEdge), SEAM)
    end
    box(CFrame.new(0, belt + 0.01, baseF - 0.25), Vector3.new(W - 1, 0.02, 0.05), SEAM)

    if s.trunk >= 1.5 and not s.bed then
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

    local backH = math.min(s.cabinH * 0.6, 1.8)
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
    if s.van then
        seat(0, frontSeatZ + 5.2, W - 1.4)
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

    local exhausts = s.spoiler and { -W / 3, W / 3 } or { W / 3 }
    for _, x in ipairs(exhausts) do
        styled({
            Shape = Enum.PartType.Cylinder,
            Size = Vector3.new(0.6, 0.3, 0.3),
            CFrame = CFrame.new(x, s.bottom + 0.15, L / 2 - 0.1) * CFrame.Angles(0, math.rad(90), 0),
        }, CHROME)
    end

    if s.rails then
        for _, side in ipairs({ -1, 1 }) do
            local x = side * (W / 2 - 0.9)
            rod(Vector3.new(x, top + 0.4, roofF + 0.3), Vector3.new(x, top + 0.4, roofR - 0.3), 0.15, BLACK)
            for _, z in ipairs({ roofF + 0.5, roofR - 0.5 }) do
                box(CFrame.new(x, top + 0.27, z), Vector3.new(0.15, 0.25, 0.3), BLACK)
            end
        end
    end

    if s.spoiler then
        box(CFrame.new(0, belt + 0.55, L / 2 - 1.2), Vector3.new(W - 0.8, 0.1, 0.8), PAINT)
        for _, side in ipairs({ -1, 1 }) do
            box(CFrame.new(side * (W / 2 - 1.4), belt + 0.25, L / 2 - 1.2), Vector3.new(0.15, 0.5, 0.3), BLACK)
        end
    end

    -- Pickup bed: side walls, tailgate, dark liner, cab guard
    if s.bed then
        local bedF, bedR = baseR + 0.1, rearEdge
        local wallH = 1.0
        box(CFrame.new(0, belt + 0.03, (bedF + bedR) / 2), Vector3.new(W - 0.6, 0.06, bedR - bedF), BED_LINER)
        for _, side in ipairs({ -1, 1 }) do
            box(CFrame.new(side * (W / 2 - 0.15), belt + wallH / 2, (bedF + bedR) / 2), Vector3.new(0.3, wallH, bedR - bedF), PAINT)
            box(CFrame.new(side * (W / 2 - 0.15), belt + wallH + 0.04, (bedF + bedR) / 2), Vector3.new(0.34, 0.08, bedR - bedF), BLACK)
        end
        box(CFrame.new(0, belt + wallH / 2, bedR - 0.15), Vector3.new(W - 0.6, wallH, 0.3), PAINT)
        box(CFrame.new(0, belt + wallH / 2, bedF + 0.15), Vector3.new(W - 0.6, wallH, 0.3), PAINT)
        box(CFrame.new(0, belt + wallH * 0.6, bedR + 0.01), Vector3.new(1.2, 0.25, 0.05), CHROME)
    end

    -- Taxi: roof sign and a checker band along both sides
    if s.taxi then
        local mid = (roofF + roofR) / 2
        box(CFrame.new(0, top + 0.2, mid), Vector3.new(1.0, 0.12, 0.5), BLACK)
        local sign = box(CFrame.new(0, top + 0.55, mid), Vector3.new(2.4, 0.6, 0.5), TAXI_SIGN)
        addSurfaceText(sign, Enum.NormalId.Front, "TAXI", Color3.fromRGB(30, 30, 30), 40)
        addSurfaceText(sign, Enum.NormalId.Back, "TAXI", Color3.fromRGB(30, 30, 30), 40)
        local squares = 12
        local z0, z1 = frontSeam + 0.3, rearSeam - 0.3
        local step = (z1 - z0) / squares
        for _, side in ipairs({ -1, 1 }) do
            for k = 0, squares - 1, 2 do
                box(CFrame.new(side * (W / 2 + 0.015), belt - 0.75, z0 + step * (k + 0.5)), Vector3.new(0.03, 0.3, step), CHECKER_DARK)
            end
        end
    end

    makePart({
        Name = "Hitbox",
        Size = Vector3.new(W, top - 0.3, L),
        CFrame = CFrame.new(0, (top + 0.3) / 2, 0),
        Transparency = 1,
        CanCollide = true,
        CanQuery = true,
    })

    -- No PrimaryPart, so PivotTo uses this pivot, which sits on the wheel line
    -- (same reason as in ParkedCars.lua).
    current.WorldPivot = CFrame.new(0, 0, 0)
    return current, s, top
end

----------------------------------------------------------------
-- Find the kerbside spaces
----------------------------------------------------------------
local streetRoots = {}
for _, path in ipairs({ { "City", "Streets" }, { "CityInfill", "InfillStreets" } }) do
    local root = workspace:FindFirstChild(path[1])
    local streets = root and root:FindFirstChild(path[2])
    if streets then
        table.insert(streetRoots, streets)
    end
end
if #streetRoots == 0 then
    warn("[StreetParkedCars] no Streets models found under Workspace.City / Workspace.CityInfill")
    return
end

-- Workspace.Casino is a Folder (no bounding box), so measure from its spawn
local casinoSpawn = workspace:FindFirstChild("CasinoSpawn")
local casinoPos = casinoSpawn and casinoSpawn.Position or Vector3.zero

local UP = Vector3.new(0, 1, 0)
local slots = {}
for _, streets in ipairs(streetRoots) do
    for _, p in ipairs(streets:GetDescendants()) do
        if p:IsA("BasePart") and p.Material == Enum.Material.Asphalt then
            local alongX = p.Size.X > p.Size.Z
            local length = alongX and p.Size.X or p.Size.Z
            local width = alongX and p.Size.Z or p.Size.X
            -- a street run between two crossings, not an intersection square
            if width >= CFG.MIN_STREET_WIDTH and length > width * 2 then
                local axis = alongX and p.CFrame.RightVector or p.CFrame.LookVector
                axis = Vector3.new(axis.X, 0, axis.Z).Unit
                local usable = length - CFG.CORNER_CLEAR * 2
                local count = math.floor(usable / CFG.STALL)
                local roadTop = p.Position.Y + p.Size.Y / 2
                for _, sideSign in ipairs({ -1, 1 }) do
                    local sideDir = axis:Cross(UP) * sideSign
                    local facing = UP:Cross(sideDir) -- traffic on this side drives this way
                    for k = 0, count - 1 do
                        local along = -usable / 2 + CFG.STALL * (k + 0.5) + (usable - count * CFG.STALL) / 2
                        local pos = Vector3.new(p.Position.X, roadTop, p.Position.Z) + axis * along
                        local d = (Vector3.new(pos.X, 0, pos.Z) - Vector3.new(casinoPos.X, 0, casinoPos.Z)).Magnitude
                        local weight = math.exp(-d / CFG.NEAR_CASINO)
                        table.insert(slots, {
                            pos = pos,
                            side = sideDir,
                            facing = facing,
                            halfWidth = width / 2,
                            -- weighted shuffle: higher weight sorts earlier
                            key = rng:NextNumber() ^ (1 / weight),
                        })
                    end
                end
            end
        end
    end
end
table.sort(slots, function(a, b)
    return a.key > b.key
end)

----------------------------------------------------------------
-- Place and verify
----------------------------------------------------------------
local groundRay = RaycastParams.new()
groundRay.FilterType = Enum.RaycastFilterType.Include
groundRay.FilterDescendantsInstances = streetRoots

local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Exclude
local excluded = table.clone(streetRoots)
table.insert(excluded, folder)
local old = workspace:FindFirstChild(CFG.FOLDER)
if old then
    table.insert(excluded, old)
end
overlap.FilterDescendantsInstances = excluded

local function pickKind()
    local total = 0
    for _, m in ipairs(MIX) do
        total = total + m[2]
    end
    local roll = rng:NextNumber() * total
    for _, m in ipairs(MIX) do
        roll = roll - m[2]
        if roll <= 0 then
            return m[1]
        end
    end
    return "sedan"
end

local function fits(cf, spec, top)
    -- tarmac under every corner
    for _, cx in ipairs({ -1, 1 }) do
        for _, cz in ipairs({ -1, 1 }) do
            local corner = cf * Vector3.new(cx * spec.W / 2, 0, cz * spec.L / 2)
            local hit = workspace:Raycast(corner + Vector3.new(0, 5, 0), Vector3.new(0, -10, 0), groundRay)
            if not hit or math.abs(hit.Position.Y - cf.Position.Y) > 0.3 then
                return false
            end
        end
    end
    -- nothing standing in the space (starts above the road markings)
    local height = top - 0.4
    local probe = cf * CFrame.new(0, 0.4 + height / 2, 0)
    local hits = workspace:GetPartBoundsInBox(probe, Vector3.new(spec.W + 0.3, height, spec.L + 0.6), overlap)
    return #hits == 0
end

local built, rejected = 0, 0
local counts = {}
for _, slot in ipairs(slots) do
    if built >= CFG.TARGET_CARS then
        break
    end
    local kind = pickKind()
    local spec = CAR_TYPES[kind]
    local paint = kind == "taxi" and TAXI_YELLOW or pick((kind == "sports" or kind == "coupe") and SPORTS_PAINTS or PAINTS)
    local offset = slot.halfWidth - CFG.CURB_GAP - spec.W / 2
    local center = slot.pos + slot.side * offset + slot.facing * rand(-0.8, 0.8)
    local forward = CFrame.Angles(0, math.rad(rand(-0.6, 0.6)), 0) * slot.facing
    local cf = CFrame.lookAt(center, center + forward)

    local car, _, top = buildCar(kind, paint)
    if fits(cf, spec, top) then
        car:PivotTo(cf)
        car.Parent = folder
        built = built + 1
        counts[kind] = (counts[kind] or 0) + 1
    else
        car:Destroy()
        rejected = rejected + 1
    end
end

if old then
    old:Destroy()
end
folder.Parent = workspace

local parts = 0
for _, d in ipairs(folder:GetDescendants()) do
    if d:IsA("BasePart") then
        parts = parts + 1
        local s = d.Size
        if math.min(s.X, s.Y, s.Z) < CFG.SHADOW_MIN_SIZE or d.Material == Enum.Material.Neon or d.Transparency > 0.5 then
            d.CastShadow = false
        end
    end
end

local mix = {}
for _, m in ipairs(MIX) do
    table.insert(mix, m[1] .. "=" .. (counts[m[1]] or 0))
end
print(string.format("[StreetParkedCars] %d cars, %d parts, %d spaces rejected | %s",
    built, parts, rejected, table.concat(mix, " ")))

return folder
