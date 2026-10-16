-- GRAND CASINO EXTERIOR
-- Written by James. Changes marked [REX]:
--   1. HIDE_OLD emptied, replaced by HIDE_PATHS. In this place those three
--      folder names are not the exterior: Decor holds the interior columns,
--      cove lighting and the SLOTS / JACKPOT / LUCKY 7 wall neons; Downlights
--      is the ceiling lighting inside the hall; Forecourt is the paving the
--      parking lot sits on. Hiding them would gut the interior. What actually
--      clashes is Decor.Exterior - the old canopy, approach road and tower
--      sign - so that is targeted by path instead.
--   2. The parking lot lookup is recursive. The lot lives at
--      Casino.CasinoParkingLot, so a shallow search missed it and the front
--      direction fell back to the manual setting.
--   3. The two runtime animations (revolving door, chasing bulbs and jackpot)
--      moved into a child Script. Run in edit mode, a bare Heartbeat loop and
--      a while loop spin inside Studio forever and keep dirtying the place.
--      As a child Script they run in game and travel with the model.
--   4. Sign captions build their line breaks from string.char(10); the MCP
--      bridge rewrites a backslash-n inside double quotes into a real newline,
--      which splits the literal and will not compile.
-- The geometry is untouched.

-- Settings:
local CASINO_NAME = "GOLDEN SPIRE"
local CASINO_SUBTITLE = "CASINO & RESORT"
local AUTO_DETECT = true                              -- measure your building automatically
local HIDE_OLD = {}                                   -- [REX] see note 1; was Decor/Forecourt/Downlights
local HIDE_PATHS = { { "Decor", "Exterior" } }        -- [REX] the actual old exterior
local FORECOURT_DEPTH = 40                            -- how far the entrance area reaches out from the building
local FOUNTAINS = true
local PYLON_SIGN = true                               -- big Vegas sign beside the building
local PYLON_SIDE = 1                                  -- 1 = right side, -1 = left side
local ANIMATE_LIGHTS = true                           -- chasing marquee bulbs and jackpot counter

-- Only used if AUTO_DETECT is false or your building can't be found:
local FRONT_CENTER = Vector3.new(0, 0, 0)             -- bottom middle of your building's front wall
local FRONT_DIRECTION = Vector3.new(0, 0, -1)         -- the way the front of the building faces
local BUILDING_WIDTH = 120
local BUILDING_HEIGHT = 40

local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

-- [REX] see note 4
local NL = string.char(10)

----------------------------------------------------------------
-- Find and measure the old building
----------------------------------------------------------------
local function partsBounds(container)
    local minV = Vector3.new(math.huge, math.huge, math.huge)
    local maxV = -minV
    local found = false
    local list = container:GetDescendants()
    table.insert(list, container)
    for _, p in ipairs(list) do
        if p:IsA("BasePart") then
            found = true
            local half = p.Size / 2
            for _, sx in ipairs({ -1, 1 }) do
                for _, sy in ipairs({ -1, 1 }) do
                    for _, sz in ipairs({ -1, 1 }) do
                        local corner = p.CFrame * Vector3.new(half.X * sx, half.Y * sy, half.Z * sz)
                        minV = minV:Min(corner)
                        maxV = maxV:Max(corner)
                    end
                end
            end
        end
    end
    return found, minV, maxV
end

local FRAME, W, H, casinoRoot
if AUTO_DETECT then
    local facade = workspace:FindFirstChild("Facade", true)
    if facade then
        local found, minV, maxV = partsBounds(facade)
        if found then
            casinoRoot = facade.Parent

            -- [REX] Clear the previous run BEFORE probing the ground. Left
            -- until the end, the datum ray lands on last run's own forecourt
            -- and the whole exterior climbs a storey on every rebuild.
            local previous = casinoRoot:FindFirstChild("GrandExterior")
            if previous then
                previous:Destroy()
            end

            local center = (minV + maxV) / 2
            local dir = FRONT_DIRECTION
            -- [REX] recursive; the lot is at Casino.CasinoParkingLot
            local lot = workspace:FindFirstChild("CasinoParkingLot", true)
            if lot then
                dir = lot:GetPivot().Position - center
            end
            if math.abs(dir.X) > math.abs(dir.Z) then
                dir = Vector3.new(dir.X >= 0 and 1 or -1, 0, 0)
            else
                dir = Vector3.new(0, 0, dir.Z >= 0 and 1 or -1)
            end
            local origin
            if dir.X ~= 0 then
                origin = Vector3.new(dir.X > 0 and maxV.X or minV.X, minV.Y, center.Z)
                W = maxV.Z - minV.Z
            else
                origin = Vector3.new(center.X, minV.Y, dir.Z > 0 and maxV.Z or minV.Z)
                W = maxV.X - minV.X
            end
            H = maxV.Y - minV.Y

            -- [REX] Sit on the ground, not on the facade's lowest corner.
            -- partsBounds measures corners, so a rotated facade part dragged
            -- the datum down to -4.90 while the apron people actually walk on
            -- is at -2.47: the whole forecourt built 2.25 studs underground.
            -- Probe the real surface a little out in front instead.
            local probe = origin + dir * 12
            local skip = {}
            for _, d in ipairs(workspace:GetDescendants()) do
                if d:IsA("SpawnLocation") then
                    table.insert(skip, d)
                end
            end
            local groundParams = RaycastParams.new()
            groundParams.FilterType = Enum.RaycastFilterType.Exclude
            groundParams.FilterDescendantsInstances = skip
            local groundHit = workspace:Raycast(Vector3.new(probe.X, 12, probe.Z), Vector3.new(0, -120, 0), groundParams)
            if groundHit then
                origin = Vector3.new(origin.X, groundHit.Position.Y, origin.Z)
                print(string.format("[Grand Exterior] ground datum %.2f from %s (facade corner was %.2f)",
                    groundHit.Position.Y, groundHit.Instance.Name, minV.Y))
            end

            FRAME = CFrame.lookAt(origin, origin + dir)
            print(string.format("[Grand Exterior] Found your building: %d wide, %d tall, front faces %s", W, H, tostring(dir)))
        end
    end
    if not FRAME then
        warn("[Grand Exterior] Couldn't find a 'Facade' folder. Using the manual settings instead.")
    end
end
if not FRAME then
    local flatDir = Vector3.new(FRONT_DIRECTION.X, 0, FRONT_DIRECTION.Z).Unit
    FRAME = CFrame.lookAt(FRONT_CENTER, FRONT_CENTER + flatDir)
    W, H = BUILDING_WIDTH, BUILDING_HEIGHT
end
W = math.clamp(W, 80, 400)
H = math.clamp(H, 28, 70)

-- Move the old exterior out of the way (kept as a backup)
if casinoRoot then
    local backup = ServerStorage:FindFirstChild("OldExteriorBackup")
    if not backup then
        backup = Instance.new("Folder")
        backup.Name = "OldExteriorBackup"
        backup.Parent = ServerStorage
    end
    for _, name in ipairs(HIDE_OLD) do
        local old = casinoRoot:FindFirstChild(name, casinoRoot ~= workspace)
        if old then
            old.Parent = backup
        end
    end
    -- [REX] targeted removals, by path from the casino root
    for _, path in ipairs(HIDE_PATHS) do
        local node = casinoRoot
        for _, step in ipairs(path) do
            node = node and node:FindFirstChild(step)
        end
        if node then
            print("[Grand Exterior] moved " .. node:GetFullName() .. " to the backup folder")
            node.Parent = backup
        end
    end
end

----------------------------------------------------------------
-- Materials
----------------------------------------------------------------
local STONE = { Color = Color3.fromRGB(228, 218, 198), Material = Enum.Material.Limestone, CanCollide = true }
local STONE_DARK = { Color = Color3.fromRGB(196, 183, 160), Material = Enum.Material.Limestone, CanCollide = true }
local MARBLE = { Color = Color3.fromRGB(242, 238, 230), Material = Enum.Material.Marble, CanCollide = true }
local GRANITE = { Color = Color3.fromRGB(28, 28, 31), Material = Enum.Material.Granite, CanCollide = true }
local GOLD = { Color = Color3.fromRGB(212, 175, 55), Material = Enum.Material.Metal, Reflectance = 0.35 }
local GLASS_DARK = { Color = Color3.fromRGB(25, 30, 40), Material = Enum.Material.Glass, Transparency = 0.3, Reflectance = 0.35 }
local GLASS_CLEAR = { Color = Color3.fromRGB(180, 200, 210), Material = Enum.Material.Glass, Transparency = 0.65, Reflectance = 0.2 }
local GLOW = { Color = Color3.fromRGB(255, 190, 110), Material = Enum.Material.Neon, Transparency = 0.55 }
local NEON_GOLD = { Color = Color3.fromRGB(255, 200, 90), Material = Enum.Material.Neon }
local NEON_WARM = { Color = Color3.fromRGB(255, 230, 180), Material = Enum.Material.Neon }
local BULB_OFF = { Color = Color3.fromRGB(120, 100, 60), Material = Enum.Material.SmoothPlastic }
local RED_CARPET = { Color = Color3.fromRGB(165, 15, 25), Material = Enum.Material.Fabric }
local VELVET = { Color = Color3.fromRGB(140, 10, 20), Material = Enum.Material.Fabric }
local PAVER_A = { Color = Color3.fromRGB(215, 205, 185), Material = Enum.Material.Pavement, CanCollide = true }
local PAVER_B = { Color = Color3.fromRGB(170, 160, 140), Material = Enum.Material.Pavement, CanCollide = true }
local GROUT = { Color = Color3.fromRGB(90, 85, 78), Material = Enum.Material.Concrete, CanCollide = true }
local ASPHALT = { Color = Color3.fromRGB(38, 38, 40), Material = Enum.Material.Asphalt, CanCollide = true }
local CONCRETE = { Color = Color3.fromRGB(175, 175, 170), Material = Enum.Material.Concrete, CanCollide = true }
local GRASS = { Color = Color3.fromRGB(60, 110, 45), Material = Enum.Material.Grass, CanCollide = true }
local HEDGE = { Color = Color3.fromRGB(40, 85, 38), Material = Enum.Material.LeafyGrass, CanCollide = true }
local WATER = { Color = Color3.fromRGB(60, 150, 210), Material = Enum.Material.Glass, Transparency = 0.35, Reflectance = 0.3 }
local BLACK_METAL = { Color = Color3.fromRGB(25, 25, 28), Material = Enum.Material.Metal, CanCollide = true }
local WOOD = { Color = Color3.fromRGB(70, 40, 25), Material = Enum.Material.Wood, CanCollide = true }
local PAINT = { Color = Color3.fromRGB(235, 235, 225), Material = Enum.Material.SmoothPlastic }

local BULB_ON_COLOR = Color3.fromRGB(255, 225, 150)
local UPLIGHT_COLOR = Color3.fromRGB(255, 205, 130)

local rng = Random.new(21)
local function rand(a, b)
    return rng:NextNumber(a, b)
end

local exterior = Instance.new("Model")
exterior.Name = "GrandExterior"

----------------------------------------------------------------
-- Building helpers (everything is built with the front facing -Z)
----------------------------------------------------------------
local function makePart(props)
    local p = Instance.new("Part")
    p.Anchored = true
    p.CanCollide = false
    p.CanTouch = false
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    for key, value in pairs(props) do
        p[key] = value
    end
    p.Parent = exterior
    return p
end

local function styled(props, style)
    for key, value in pairs(style) do
        props[key] = value
    end
    return makePart(props)
end

local function upFor(d)
    return math.abs(d.Y) > 0.98 and Vector3.new(1, 0, 0) or Vector3.new(0, 1, 0)
end

local function lookAtSafe(pos, target)
    return CFrame.lookAt(pos, target, upFor((target - pos).Unit))
end

local function B(x, y, z, sx, sy, sz, style)
    return styled({ Size = Vector3.new(sx, sy, sz), CFrame = CFrame.new(x, y, z) }, style)
end

local function ball(pos, size, style)
    return styled({ Shape = Enum.PartType.Ball, Size = Vector3.new(size, size, size), CFrame = CFrame.new(pos) }, style)
end

local function ellipsoid(pos, size, style)
    local p = styled({ Size = size, CFrame = CFrame.new(pos) }, style)
    local mesh = Instance.new("SpecialMesh")
    mesh.MeshType = Enum.MeshType.Sphere
    mesh.Parent = p
    return p
end

-- Upright cylinder
local function disc(pos, height, width, style)
    return styled({
        Shape = Enum.PartType.Cylinder,
        Size = Vector3.new(height, width, width),
        CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)),
    }, style)
end

local function rod(a, b, thickness, style)
    return styled({
        Shape = Enum.PartType.Cylinder,
        Size = Vector3.new((b - a).Magnitude + thickness * 0.3, thickness, thickness),
        CFrame = lookAtSafe((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0),
    }, style)
end

local function signText(part, face, text, font, gold)
    local gui = Instance.new("SurfaceGui")
    gui.Face = face
    gui.LightInfluence = 0
    gui.Brightness = 1.6
    gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    gui.PixelsPerStud = 40
    gui.Parent = part
    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextScaled = true
    label.Font = font
    label.TextColor3 = Color3.new(1, 1, 1)
    label.Parent = gui
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(60, 40, 0)
    stroke.Thickness = 2
    stroke.Parent = label
    if gold then
        local gradient = Instance.new("UIGradient")
        gradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(200, 155, 40)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 240, 170)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 155, 40)),
        })
        gradient.Rotation = 90
        gradient.Parent = label
    end
    return label
end

local function textPanel(x, y, z, sx, sy, face, text, font, gold)
    local p = B(x, y, z, sx, sy, 0.04, { Transparency = 1 })
    return signText(p, face, text, font, gold)
end

local function uplight(pos, aim)
    local fixture = styled({ Size = Vector3.new(0.8, 0.6, 1.0), CFrame = lookAtSafe(pos, aim) }, BLACK_METAL)
    makePart({
        Size = Vector3.new(0.6, 0.45, 0.05),
        CFrame = fixture.CFrame * CFrame.new(0, 0, -0.52),
        Color = UPLIGHT_COLOR,
        Material = Enum.Material.Neon,
    })
    local light = Instance.new("SpotLight")
    light.Face = Enum.NormalId.Front
    light.Color = UPLIGHT_COLOR
    light.Brightness = 5
    light.Range = 45
    light.Angle = 35
    light.Parent = fixture
end

local bulbs = {}
local function bulb(pos)
    local b = ball(pos, 0.45, BULB_OFF)
    b.Name = "MarqueeBulb" -- [REX] so the animation script can find them
    table.insert(bulbs, { part = b, on = false })
end

local function bulbLine(a, b, spacing)
    local n = math.max(1, math.floor((b - a).Magnitude / spacing))
    for i = 0, n - 1 do
        bulb(a:Lerp(b, i / n))
    end
end

local function bulbRect(cx, cy, z, w, h, spacing)
    local tl = Vector3.new(cx - w / 2, cy + h / 2, z)
    local tr = Vector3.new(cx + w / 2, cy + h / 2, z)
    local br = Vector3.new(cx + w / 2, cy - h / 2, z)
    local bl = Vector3.new(cx - w / 2, cy - h / 2, z)
    bulbLine(tl, tr, spacing)
    bulbLine(tr, br, spacing)
    bulbLine(br, bl, spacing)
    bulbLine(bl, tl, spacing)
end

local function pointLight(part, color, range, brightness)
    local light = Instance.new("PointLight")
    light.Color = color
    light.Range = range
    light.Brightness = brightness
    light.Parent = part
end

----------------------------------------------------------------
-- Layout measurements
----------------------------------------------------------------
local TOWER_W = 12
local CW = math.clamp(W * 0.3, 38, 50)     -- center tower width
local DW, DH = 22, 14                       -- entrance opening width / height
local OH = DW / 2 + 2                       -- half width of the entrance portal
local CH = H + 16                           -- center tower height
local EP = 1                                -- entry platform height
local CNW = math.min(DW + 32, W - 2 * TOWER_W - 8) -- drop-off canopy width
local CD, CB = 28, 16                       -- canopy depth / clear height
local CANOPY_FRONT = -4.5 - CD
local PLAZA = 14.5
local LANE = 12
local FD = math.max(FORECOURT_DEPTH, 34)
local SIDE_CENTER = (CW / 2 + W / 2) / 2
local SIDE_LEN = W / 2 - CW / 2

local function sideBox(y, z, sy, sz, style)
    for _, sign in ipairs({ -1, 1 }) do
        B(sign * SIDE_CENTER, y, z, SIDE_LEN, sy, sz, style)
    end
end

----------------------------------------------------------------
-- Main facade (both sides of the center tower)
----------------------------------------------------------------
sideBox(H / 2, -0.5, H, 1, STONE)
sideBox(2.25, -1.2, 4.5, 1.4, GRANITE)
sideBox(4.55, -1.92, 0.2, 0.08, GOLD)

-- Top ledge with glowing gold strip, small blocks and a stone railing
sideBox(H - 6, -1.3, 0.6, 1.6, STONE_DARK)
sideBox(H - 4.8, -1.6, 1.8, 2.2, STONE)
sideBox(H - 4.8, -2.72, 0.25, 0.06, NEON_GOLD)
sideBox(H - 3, -2.2, 0.8, 3.0, STONE)
sideBox(H - 2.5, -2.5, 0.2, 3.6, GOLD)
sideBox(H - 2.2, -1.3, 0.4, 1.4, STONE)
sideBox(H - 0.2, -1.3, 0.4, 1.6, STONE)
for _, sign in ipairs({ -1, 1 }) do
    for x = CW / 2 + 0.8, W / 2 - 0.8, 1.6 do
        B(sign * x, H - 3.6, -2.6, 0.7, 0.5, 1.8, STONE_DARK)
    end
    for x = CW / 2 + 1, W / 2 - 1, 1.4 do
        disc(Vector3.new(sign * x, H - 1.2, -1.3), 1.6, 0.55, MARBLE)
    end
end

-- Window bays and columns
for _, sign in ipairs({ -1, 1 }) do
    local x0, x1 = CW / 2, W / 2 - TOWER_W
    local span = x1 - x0
    if span >= 10 then
        local count = math.max(1, math.floor(span / 14))
        local bayW = span / count

        for k = 0, count do
            local px = sign * (x0 + k * bayW)
            B(px, (4.5 + H - 6.3) / 2, -1.6, 2.2, H - 10.8, 2.2, MARBLE)
            B(px, 5.1, -1.7, 2.8, 1.2, 2.6, STONE_DARK)
            B(px, H - 6.8, -1.75, 3.0, 1.0, 2.9, GOLD)
            for _, f in ipairs({ -0.5, 0.5 }) do
                B(px + f, (6 + H - 7.5) / 2, -2.72, 0.15, H - 13.5, 0.05, STONE_DARK)
            end
            -- Railing post with a gold urn
            B(px, H - 1.2, -1.3, 1.2, 2.4, 1.6, STONE)
            ellipsoid(Vector3.new(px, H + 0.5, -1.3), Vector3.new(0.9, 1.2, 0.9), GOLD)
            uplight(Vector3.new(px, 0.5, -3.6), Vector3.new(px, H - 8, -1.6))
        end

        for k = 0, count - 1 do
            local bx = sign * (x0 + (k + 0.5) * bayW)
            local ww = bayW - 4
            local r = ww / 2
            local archBase = math.max(9, H - 13 - r)
            local rectH = archBase - 7

            -- Glowing glass with an arched top
            B(bx, 7 + rectH / 2, -1.05, ww, rectH, 0.04, GLOW)
            B(bx, 7 + rectH / 2, -1.12, ww, rectH, 0.06, GLASS_DARK)
            for s = 0, 4 do
                local y = (s + 0.5) * (r / 5)
                local half = math.sqrt(math.max(r * r - y * y, 0.01))
                B(bx, archBase + y, -1.05, half * 2, r / 5 + 0.02, 0.04, GLOW)
                B(bx, archBase + y, -1.12, half * 2, r / 5 + 0.02, 0.06, GLASS_DARK)
            end

            -- Gold frame, arch, keystone, window bars
            for _, side in ipairs({ -1, 1 }) do
                B(bx + side * ww / 2, 7 + rectH / 2, -1.3, 0.35, rectH, 0.4, GOLD)
            end
            local last
            for s = 0, 10 do
                local a = math.pi * s / 10
                local point = Vector3.new(bx + math.cos(a) * r, archBase + math.sin(a) * r, -1.3)
                if last then
                    rod(last, point, 0.35, GOLD)
                end
                last = point
            end
            B(bx, archBase + r + 0.4, -1.4, 1.0, 1.4, 0.8, GOLD)
            B(bx, (7 + archBase + r) / 2, -1.25, 0.18, archBase + r - 7, 0.2, GOLD)
            for y = 12, archBase, 5 do
                B(bx, y, -1.25, ww, 0.18, 0.2, GOLD)
            end
            B(bx, 6.8, -1.5, ww + 1, 0.5, 1.0, STONE_DARK)

            -- Planter with a hedge under each window
            B(bx, 0.95, -2.9, ww, 1.5, 1.8, GRANITE)
            B(bx, 1.72, -2.9, ww + 0.1, 0.06, 1.9, GOLD)
            B(bx, 2.3, -2.9, ww - 0.4, 1.2, 1.4, HEDGE)
        end
    end
end

----------------------------------------------------------------
-- Corner towers with gold domes
----------------------------------------------------------------
local TH = H + 8
for _, sign in ipairs({ -1, 1 }) do
    local tx = sign * (W / 2 - TOWER_W / 2 + 1)
    B(tx, TH / 2, -1, 14, TH, 6, STONE)
    B(tx, 2.5, -1, 14.6, 5, 6.6, GRANITE)
    B(tx, 5.05, -4.32, 14.6, 0.2, 0.08, GOLD)
    for y = 7, 14, 2.5 do
        B(tx, y, -4.03, 14, 0.15, 0.06, STONE_DARK)
    end

    local winH = TH - 24
    if winH > 4 then
        local wy = 16 + winH / 2
        B(tx, wy, -4.05, 3.2, winH, 0.04, GLOW)
        B(tx, wy, -4.1, 3.2, winH, 0.06, GLASS_DARK)
        for _, side in ipairs({ -1, 1 }) do
            B(tx + side * 1.75, wy, -4.2, 0.3, winH + 0.6, 0.3, GOLD)
            B(tx, wy + side * (winH / 2 + 0.15), -4.2, 3.8, 0.3, 0.3, GOLD)
        end
    end

    B(tx, TH - 2.5, -1, 15.6, 1.4, 7.6, STONE_DARK)
    B(tx, TH - 1.7, -1, 16.2, 0.3, 8.2, GOLD)
    B(tx, TH - 3.3, -4.83, 15.6, 0.2, 0.05, NEON_GOLD)

    disc(Vector3.new(tx, TH + 1.5, -1), 3, 9, STONE)
    for c = 1, 8 do
        local a = (c / 8) * math.pi * 2
        rod(Vector3.new(tx + math.cos(a) * 4.6, TH, -1 + math.sin(a) * 4.6),
            Vector3.new(tx + math.cos(a) * 4.6, TH + 3, -1 + math.sin(a) * 4.6), 0.4, GOLD)
    end
    disc(Vector3.new(tx, TH + 3.1, -1), 0.3, 9.8, GOLD)
    ellipsoid(Vector3.new(tx, TH + 3, -1), Vector3.new(9.2, 8, 9.2), GOLD)
    rod(Vector3.new(tx, TH + 6.8, -1), Vector3.new(tx, TH + 11, -1), 0.3, GOLD)
    local tip = ball(Vector3.new(tx, TH + 11.2, -1), 0.8, NEON_GOLD)
    pointLight(tip, Color3.fromRGB(255, 200, 90), 20, 1.5)

    for _, side in ipairs({ -1, 1 }) do
        uplight(Vector3.new(tx + side * 4, 0.5, -5.5), Vector3.new(tx, TH - 6, -4))
    end
end

----------------------------------------------------------------
-- Center entrance tower
----------------------------------------------------------------
for _, sign in ipairs({ -1, 1 }) do
    local pierW = CW / 2 - OH
    local px = sign * (OH + pierW / 2)
    B(px, CH / 2, -2.25, pierW, CH, 4.5, STONE)
    B(px, 2.5, -2.4, pierW + 0.2, 5, 4.9, GRANITE)
    B(px, 5.05, -4.88, pierW + 0.2, 0.2, 0.08, GOLD)
    -- Doorway sides
    B(sign * (DW / 2 + 1), (DH + 2) / 2, -2.25, 2, DH + 2, 4.6, GRANITE)
    B(sign * (DW / 2 + 0.05), DH / 2, -4.58, 0.12, DH, 0.08, GOLD)
    B(sign * (OH + 0.06), (DH + 2) / 2, -4.58, 0.12, DH + 2, 0.08, GOLD)
    -- Gold fins
    B(sign * (CW / 2 - 1.2), (5 + CH - 3) / 2, -4.75, 0.7, CH - 8, 0.5, GOLD)
    uplight(Vector3.new(sign * (CW / 2 - 2), EP + 0.3, -10), Vector3.new(sign * (CW / 2 - 2), CH - 4, -4.5))
end
B(0, (DH + 2 + CH) / 2, -2.25, 2 * OH, CH - DH - 2, 4.5, STONE)
B(0, DH + 1, -2.25, DW, 2, 4.6, GRANITE)
B(0, DH + 2.05, -4.58, 2 * OH, 0.12, 0.08, GOLD)

-- Downlights in the doorway ceiling
for _, x in ipairs({ -6, 0, 6 }) do
    local light = B(x, DH - 0.03, -2.4, 1.2, 0.06, 1.2, NEON_WARM)
    local spot = Instance.new("SpotLight")
    spot.Face = Enum.NormalId.Bottom
    spot.Color = Color3.fromRGB(255, 225, 170)
    spot.Range = 20
    spot.Angle = 80
    spot.Brightness = 2
    spot.Parent = light
end

-- Glass doors (players can walk through them)
local DOOR_Z = -0.8
for _, sign in ipairs({ -1, 1 }) do
    for k = 0, 1 do
        local px = sign * (3.8 + 1.8 + k * 3.6)
        B(px, EP + 5, DOOR_Z, 3.5, 10, 0.12, GLASS_CLEAR)
        B(px, (EP + 10.5 + DH) / 2, DOOR_Z, 3.5, DH - EP - 10.5, 0.12, GLASS_DARK)
        for _, edge in ipairs({ -1.8, 1.8 }) do
            B(px + edge, (EP + DH) / 2, DOOR_Z - 0.05, 0.2, DH - EP, 0.25, GOLD)
        end
        B(px, EP + 10.25, DOOR_Z - 0.05, 3.6, 0.25, 0.25, GOLD)
        B(px, EP + 0.1, DOOR_Z - 0.05, 3.6, 0.2, 0.25, GOLD)
        B(px, EP + 4, DOOR_Z - 0.2, 2.6, 0.15, 0.15, GOLD)
    end
end

-- Revolving door (spins)
local DOOR_CENTER = CFrame.new(0, EP + 4.6, -2.4)
local DOOR_R = 3.4
for _, range in ipairs({ { -60, 60 }, { 120, 240 } }) do
    local last
    for a = range[1], range[2], 20 do
        local rad = math.rad(a)
        local point = Vector3.new(math.cos(rad) * DOOR_R, EP + 4.6, -2.4 + math.sin(rad) * DOOR_R)
        if last then
            local mid = (last + point) / 2
            styled({
                Size = Vector3.new(0.08, 9, (point - last).Magnitude + 0.05),
                CFrame = CFrame.lookAt(mid, point),
            }, GLASS_CLEAR)
        end
        last = point
    end
end
disc(Vector3.new(0, EP + 9.4, -2.4), 0.6, DOOR_R * 2 + 0.4, GOLD)
disc(Vector3.new(0, EP + 0.05, -2.4), 0.1, DOOR_R * 2, GRANITE)
disc(Vector3.new(0, EP + 4.6, -2.4), 9, 0.4, GOLD)

-- [REX] the spinning wings live in their own Model so the animation script can
-- turn them with PivotTo, instead of the builder holding a Heartbeat loop
local revolving = Instance.new("Model")
revolving.Name = "RevolvingDoor"
for k = 0, 3 do
    local turn = CFrame.Angles(0, k * math.pi / 2, 0)
    local wing = B(0, 0, 0, 3.2, 8.8, 0.1, GLASS_CLEAR)
    local edge = B(0, 0, 0, 0.2, 8.8, 0.2, GOLD)
    wing.CFrame = DOOR_CENTER * turn * CFrame.new(1.8, 0, 0)
    edge.CFrame = DOOR_CENTER * turn * CFrame.new(3.35, 0, 0)
    wing.Parent = revolving
    edge.Parent = revolving
end
revolving.WorldPivot = DOOR_CENTER
revolving.Parent = exterior

-- Gold sunburst above the canopy
local sunCenter = Vector3.new(0, CB + 3.5, -4.56)
local SUN_R = 6
for s = 0, 5 do
    local y = (s + 0.5) * (SUN_R / 6)
    local half = math.sqrt(math.max(SUN_R * SUN_R - y * y, 0.01))
    B(0, sunCenter.Y + y, -4.56, half * 2, SUN_R / 6 + 0.02, 0.06, GLASS_DARK)
end
for ray = 0, 10 do
    local a = math.pi * ray / 10
    rod(sunCenter + Vector3.new(math.cos(a) * 1.4, math.sin(a) * 1.4, -0.08),
        sunCenter + Vector3.new(math.cos(a) * SUN_R, math.sin(a) * SUN_R, -0.08), 0.22, GOLD)
end
for _, radius in ipairs({ SUN_R, 1.4 }) do
    local last
    for s = 0, 12 do
        local a = math.pi * s / 12
        local point = sunCenter + Vector3.new(math.cos(a) * radius, math.sin(a) * radius, -0.1)
        if last then
            rod(last, point, 0.3, GOLD)
        end
        last = point
    end
end
ball(sunCenter + Vector3.new(0, 0.4, -0.1), 1.2, NEON_GOLD)

-- Big lit sign
local SY = sunCenter.Y + SUN_R + 6.5
B(0, SY, -4.75, CW - 6, 10, 0.5, GRANITE)
for _, side in ipairs({ -1, 1 }) do
    B(0, SY + side * 5.15, -4.8, CW - 5.4, 0.3, 0.6, GOLD)
    B(side * (CW / 2 - 2.85), SY, -4.8, 0.3, 10.6, 0.6, GOLD)
end
textPanel(0, SY + 0.9, -5.02, CW - 9, 5.8, Enum.NormalId.Front, CASINO_NAME, Enum.Font.Bodoni, true)
textPanel(0, SY - 3.1, -5.02, CW - 14, 2, Enum.NormalId.Front, CASINO_SUBTITLE, Enum.Font.GothamMedium, true)
bulbRect(0, SY, -5.1, CW - 4.2, 11.4, 1.1)

-- Tower top, stepped crown and spire
B(0, CH - 1.2, -2.25, CW + 1.6, 1.6, 6.2, STONE_DARK)
B(0, CH - 0.3, -2.25, CW + 2, 0.3, 6.6, GOLD)
B(0, CH - 2.1, -5.38, CW + 1.6, 0.2, 0.05, NEON_GOLD)
B(0, CH + 3, -2.25, CW * 0.7, 6, 4.2, STONE)
B(0, CH + 6.1, -2.25, CW * 0.7 + 0.6, 0.3, 4.8, GOLD)
for f = -2, 2 do
    B(f * CW * 0.13, CH + 3, -4.4, 0.5, 5.6, 0.3, GOLD)
end
B(0, CH + 8.75, -2.25, CW * 0.42, 5.5, 3.6, STONE)
B(0, CH + 11.6, -2.25, CW * 0.42 + 0.6, 0.3, 4.2, GOLD)
for _, side in ipairs({ -1, 1 }) do
    B(side * CW * 0.21, CH + 8.75, -4.06, 0.2, 5.5, 0.1, NEON_GOLD)
end
rod(Vector3.new(0, CH + 11.7, -2.25), Vector3.new(0, CH + 19, -2.25), 1.2, GOLD)
rod(Vector3.new(0, CH + 19, -2.25), Vector3.new(0, CH + 28, -2.25), 0.5, GOLD)
disc(Vector3.new(0, CH + 15, -2.25), 0.3, 1.8, NEON_GOLD)
disc(Vector3.new(0, CH + 18, -2.25), 0.3, 1.6, NEON_GOLD)
local spireTip = ball(Vector3.new(0, CH + 28.4, -2.25), 1.2, NEON_GOLD)
pointLight(spireTip, Color3.fromRGB(255, 200, 90), 35, 2)

----------------------------------------------------------------
-- Entry platform, red carpet, ropes
----------------------------------------------------------------
B(0, EP / 2, -6.3, DW + 16, EP, 11.4, MARBLE)
B(0, 0.25, -12.75, DW + 18, 0.5, 1.5, MARBLE)
B(0, EP + 0.01, -11.95, DW + 16, 0.04, 0.12, GOLD)
B(0, 0.51, -13.45, DW + 18, 0.04, 0.12, GOLD)
disc(Vector3.new(0, EP + 0.02, -8.5), 0.04, 4, GOLD)

B(0, EP + 0.04, -6.3, 6, 0.06, 11.4, RED_CARPET)
B(0, 0.53, -12.75, 6, 0.06, 1.5, RED_CARPET)
B(0, 0.23, -14, 6, 0.06, 1.0, RED_CARPET)
for _, side in ipairs({ -1, 1 }) do
    B(side * 3.05, EP + 0.05, -6.3, 0.12, 0.06, 11.4, GOLD)
    local last
    for z = -5, -11, -2 do
        local x = side * 3.9
        disc(Vector3.new(x, EP + 0.1, z), 0.2, 1, GOLD)
        disc(Vector3.new(x, EP + 1.6, z), 3, 0.25, GOLD)
        ball(Vector3.new(x, EP + 3.2, z), 0.45, GOLD)
        local top = Vector3.new(x, EP + 2.8, z)
        if last then
            local mid = (last + top) / 2 - Vector3.new(0, 0.6, 0)
            rod(last, mid, 0.18, VELVET)
            rod(mid, top, 0.18, VELVET)
        end
        last = top
    end
end

-- Valet stand
B(7.5, 1.8, -13.2, 2.2, 3.2, 1.4, WOOD)
B(7.5, 3.45, -13.2, 2.5, 0.12, 1.7, GOLD)
textPanel(7.5, 2.4, -13.92, 2, 0.8, Enum.NormalId.Front, "VALET", Enum.Font.Bodoni, true)

----------------------------------------------------------------
-- Drop-off canopy
----------------------------------------------------------------
local canopyMidZ = -4.5 - CD / 2
B(0, CB + 1.5, canopyMidZ, CNW, 3, CD, STONE)
B(0, CB + 1.5, CANOPY_FRONT - 0.3, CNW + 0.6, 3.6, 0.6, GRANITE)
for _, side in ipairs({ -1, 1 }) do
    B(side * (CNW / 2 + 0.3), CB + 1.5, canopyMidZ - 0.15, 0.6, 3.6, CD - 0.3, GRANITE)
    B(side * (CNW / 2 + 0.62), CB + 3.15, canopyMidZ, 0.05, 0.15, CD, GOLD)
    B(side * (CNW / 2 + 0.62), CB - 0.15, canopyMidZ, 0.05, 0.15, CD, GOLD)
end
B(0, CB + 3.15, CANOPY_FRONT - 0.62, CNW + 0.6, 0.15, 0.05, GOLD)
B(0, CB - 0.15, CANOPY_FRONT - 0.62, CNW + 0.6, 0.15, 0.05, GOLD)
B(0, CB - 0.38, CANOPY_FRONT - 0.4, CNW, 0.12, 0.3, NEON_GOLD)
textPanel(0, CB + 1.5, CANOPY_FRONT - 0.64, CNW - 10, 2.2, Enum.NormalId.Front,
    "VALET  -  " .. CASINO_NAME .. "  -  ENTRANCE", Enum.Font.Bodoni, true)
bulbLine(Vector3.new(-CNW / 2, CB + 3.6, CANOPY_FRONT - 0.4), Vector3.new(CNW / 2, CB + 3.6, CANOPY_FRONT - 0.4), 1.2)

-- Gold crest on top
B(0, CB + 3.9, CANOPY_FRONT - 0.3, 12, 0.8, 0.8, GOLD)
B(0, CB + 4.7, CANOPY_FRONT - 0.3, 7, 0.8, 0.8, GOLD)
B(0, CB + 5.5, CANOPY_FRONT - 0.3, 3, 0.8, 0.8, GOLD)
ball(Vector3.new(0, CB + 6.4, CANOPY_FRONT - 0.3), 1.0, NEON_GOLD)

-- Underside: marble ceiling, gold grid and downlights
B(0, CB - 0.03, canopyMidZ, CNW - 0.2, 0.06, CD - 0.2, MARBLE)
local gridX, gridZ = {}, {}
for x = -CNW / 2 + 6, CNW / 2 - 1, 6 do
    B(x, CB - 0.15, canopyMidZ, 0.2, 0.2, CD - 0.4, GOLD)
    table.insert(gridX, x)
end
for z = -4.5 - 5.5, CANOPY_FRONT + 1, -5.5 do
    B(0, CB - 0.15, z, CNW - 0.4, 0.2, 0.2, GOLD)
    table.insert(gridZ, z)
end
local lightCount = 0
for i = 0, #gridX do
    local xa = gridX[i] or -CNW / 2
    local xb = gridX[i + 1] or CNW / 2
    for j = 0, #gridZ do
        local za = gridZ[j] or -4.5
        local zb = gridZ[j + 1] or CANOPY_FRONT
        local light = B((xa + xb) / 2, CB - 0.1, (za + zb) / 2, 1.4, 0.08, 1.4, NEON_WARM)
        lightCount += 1
        if lightCount % 2 == 0 then
            local spot = Instance.new("SpotLight")
            spot.Face = Enum.NormalId.Bottom
            spot.Color = Color3.fromRGB(255, 225, 170)
            spot.Range = 25
            spot.Angle = 90
            spot.Brightness = 2
            spot.Parent = light
        end
    end
end

-- Columns
local function column(x, z, ground)
    B(x, ground + 0.6, z, 3.2, 1.2, 3.2, GRANITE)
    B(x, ground + 1.25, z, 3.3, 0.1, 3.3, GOLD)
    local bottom, top = ground + 1.2, CB - 1.4
    disc(Vector3.new(x, (bottom + top) / 2, z), top - bottom, 2.2, MARBLE)
    for y = bottom + 2, top - 1, 3 do
        disc(Vector3.new(x, y, z), 0.25, 2.35, GOLD)
    end
    B(x, CB - 1.0, z, 3.0, 0.8, 3.0, GOLD)
    B(x, CB - 0.3, z, 3.6, 0.6, 3.6, STONE_DARK)
end
local colX = CNW / 2 - 2.5
for _, side in ipairs({ -1, 1 }) do
    column(side * colX, -12.5, 0.2)
    column(side * colX, -30, 0.8)
end

----------------------------------------------------------------
-- Forecourt: paving, curb, bollards, lane, island
----------------------------------------------------------------
B(0, 0.05, -7.75, W, 0.1, 13.5, GROUT)
local TILE = 4.5
local col = 0
for x = -W / 2 + TILE / 2, W / 2 - TILE / 2 + 0.01, TILE do
    local row = 0
    for z = -1 - TILE / 2, -14.5 + TILE / 2 - 0.01, -TILE do
        B(x, 0.15, z, TILE - 0.15, 0.1, TILE - 0.15, (col + row) % 2 == 0 and PAVER_A or PAVER_B)
        row += 1
    end
    col += 1
end
B(0, 0.1, -14.75, W, 0.4, 0.5, CONCRETE)

for x = -W / 2 + 4, W / 2 - 4, 7 do
    if math.abs(x) > 5 and math.abs(math.abs(x) - colX) > 2.5 then
        disc(Vector3.new(x, 1.3, -14.1), 2.2, 0.7, GRANITE)
        ball(Vector3.new(x, 2.45, -14.1), 0.75, GOLD)
        disc(Vector3.new(x, 1.9, -14.1), 0.15, 0.74, NEON_GOLD)
    end
end

-- Drop-off lane and entrance apron
B(0, -0.2, -(15 + FD) / 2, W, 0.5, FD - 15, ASPHALT)
for x = -5, 5, 2.2 do
    B(x, 0.07, -21, 1.1, 0.03, LANE - 1, PAINT)
end
for _, x in ipairs({ -W / 4, W / 4 }) do
    B(x, 0.07, -21, 6, 0.03, 0.6, PAINT)
    B(x + 3.2, 0.07, -20.6, 1.4, 0.03, 0.4, PAINT)
    B(x + 3.2, 0.07, -21.4, 1.4, 0.03, 0.4, PAINT)
end

-- Planted island across the lane
local IL = W - 32
B(0, 0.4, -30, IL, 0.8, 6, CONCRETE)
B(0, 0.82, -30, IL - 0.8, 0.06, 5.2, GRASS)
for _, side in ipairs({ -1, 1 }) do
    disc(Vector3.new(side * IL / 2, 0.4, -30), 0.8, 6, CONCRETE)
    disc(Vector3.new(side * IL / 2, 0.82, -30), 0.06, 5.2, GRASS)
end
local flowerColors = { Color3.fromRGB(200, 30, 40), Color3.fromRGB(240, 200, 50), Color3.fromRGB(240, 240, 235), Color3.fromRGB(180, 60, 160) }
for x = -IL / 2 + 4, IL / 2 - 4, 9 do
    if math.abs(math.abs(x) - colX) > 4 and math.abs(x) > 4 then
        B(x, 1.5, -30, 6, 1.3, 2.2, HEDGE)
    else
        for _ = 1, 6 do
            ball(Vector3.new(x + rand(-2, 2), 1.0, -30 + rand(-1.8, 1.8)), rand(0.4, 0.6), {
                Color = flowerColors[rng:NextInteger(1, #flowerColors)],
                Material = Enum.Material.SmoothPlastic,
            })
        end
    end
end

-- Double-globe street lamps on the island
local function lamp(x, z, ground)
    disc(Vector3.new(x, ground + 0.4, z), 0.8, 1.4, GRANITE)
    disc(Vector3.new(x, ground + 6.2, z), 11, 0.45, BLACK_METAL)
    B(x, ground + 11, z, 4.4, 0.25, 0.25, BLACK_METAL)
    for _, side in ipairs({ -1, 1 }) do
        local globe = ball(Vector3.new(x + side * 2, ground + 11.9, z), 1.3, NEON_WARM)
        pointLight(globe, Color3.fromRGB(255, 220, 160), 18, 1.2)
        disc(Vector3.new(x + side * 2, ground + 12.6, z), 0.2, 0.8, GOLD)
    end
    ball(Vector3.new(x, ground + 11.9, z), 0.5, GOLD)
end
for _, side in ipairs({ -1, 1 }) do
    for x = colX + 10, IL / 2 - 2, 18 do
        lamp(side * x, -30, 0.8)
    end
end

----------------------------------------------------------------
-- Fountains
----------------------------------------------------------------
local function fountain(x, z)
    disc(Vector3.new(x, 0.7, z), 1.0, 9.6, GRANITE)
    disc(Vector3.new(x, 0.9, z), 0.12, 9.75, GOLD)
    local water = disc(Vector3.new(x, 1.25, z), 0.08, 8.8, WATER)
    pointLight(water, Color3.fromRGB(120, 200, 255), 14, 1.5)
    local last
    for s = 0, 20 do
        local a = (s / 20) * math.pi * 2
        local point = Vector3.new(x + math.cos(a) * 4.6, 1.45, z + math.sin(a) * 4.6)
        if last then
            rod(last, point, 0.6, MARBLE)
        end
        last = point
    end

    disc(Vector3.new(x, 2.4, z), 2.4, 1.0, MARBLE)
    ellipsoid(Vector3.new(x, 3.6, z), Vector3.new(4.2, 1.0, 4.2), MARBLE)
    disc(Vector3.new(x, 3.85, z), 0.06, 3.4, WATER)
    disc(Vector3.new(x, 4.6, z), 1.6, 0.6, MARBLE)
    ellipsoid(Vector3.new(x, 5.4, z), Vector3.new(2.2, 0.6, 2.2), GOLD)
    local top = ball(Vector3.new(x, 6.0, z), 0.6, GOLD)
    pointLight(top, Color3.fromRGB(255, 210, 120), 10, 1)

    local function spray(part, direction, speed, rate)
        local emitter = Instance.new("ParticleEmitter")
        emitter.EmissionDirection = direction
        emitter.Speed = NumberRange.new(speed * 0.9, speed * 1.1)
        emitter.SpreadAngle = Vector2.new(10, 10)
        emitter.Acceleration = Vector3.new(0, -35, 0)
        emitter.Lifetime = NumberRange.new(0.7, 0.9)
        emitter.Rate = rate
        emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0.15) })
        emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
        emitter.Color = ColorSequence.new(Color3.fromRGB(200, 230, 255))
        emitter.LightEmission = 0.3
        emitter.Parent = part
    end
    spray(top, Enum.NormalId.Top, 12, 80)

    for j = 1, 6 do
        local a = (j / 6) * math.pi * 2
        local pos = Vector3.new(x + math.cos(a) * 3.8, 1.4, z + math.sin(a) * 3.8)
        local inward = (Vector3.new(x, 1.4, z) - pos).Unit
        local nozzle = styled({ Size = Vector3.new(0.2, 0.2, 0.2), CFrame = CFrame.lookAt(pos, pos + (inward * 0.6 + Vector3.new(0, 1, 0)).Unit) }, GOLD)
        spray(nozzle, Enum.NormalId.Front, 9, 25)
    end
end
if FOUNTAINS then
    local fx = CNW / 2 + 7
    if fx + 5 < W / 2 - TOWER_W - 1 then
        fountain(fx, -8.5)
        fountain(-fx, -8.5)
    end
end

----------------------------------------------------------------
-- Big Vegas roadside sign
----------------------------------------------------------------
local jackpotLabels = {}
if PYLON_SIGN then
    local px, pz = PYLON_SIDE * (W / 2 + 14), -24
    B(px, 1.5, pz, 10, 3, 6, GRANITE)
    B(px, 3.05, pz, 10.2, 0.15, 6.2, GOLD)
    for _, side in ipairs({ -1, 1 }) do
        B(px + side * 3, 9, pz, 1.6, 12, 1.6, GOLD)
    end

    B(px, 10, pz, 7.5, 4.5, 1.2, BLACK_METAL)
    for _, side in ipairs({ -1, 1 }) do
        B(px, 10 + side * 2.35, pz, 7.9, 0.25, 1.4, GOLD)
    end
    for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
        local label = textPanel(px, 10, pz, 7, 3.6, face, "JACKPOT" .. NL .. "$1,000,000", Enum.Font.GothamBlack, false)
        label.TextColor3 = Color3.fromRGB(255, 60, 60)
        label.Name = "JackpotLabel" -- [REX] so the animation script can find them
        table.insert(jackpotLabels, label)
    end
    -- Move the jackpot text panel outside the board so it can be seen from both sides
    for _, label in ipairs(jackpotLabels) do
        local panel = label.Parent.Parent
        panel.Size = Vector3.new(7, 3.6, 1.3)
    end

    B(px, 26, pz, 9, 22, 2.4, GRANITE)
    for _, side in ipairs({ -1, 1 }) do
        B(px + side * 4.65, 26, pz, 0.4, 22.6, 2.8, GOLD)
        B(px, 26 + side * 11.15, pz, 9.6, 0.4, 2.8, GOLD)
    end
    for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
        local panel = B(px, 26, pz, 6.5, 19, 2.5, { Transparency = 1 })
        signText(panel, face, table.concat({ "C", "A", "S", "I", "N", "O" }, NL), Enum.Font.Bodoni, true)
    end
    bulbRect(px, 26, pz - 1.25, 8.6, 21.6, 1.2)
    bulbRect(px, 26, pz + 1.25, 8.6, 21.6, 1.2)

    B(px, 37.9, pz, 7, 1.2, 2.2, GOLD)
    B(px, 39.1, pz, 4.5, 1.2, 2, GOLD)
    local star = ball(Vector3.new(px, 40.6, pz), 1.6, NEON_GOLD)
    pointLight(star, Color3.fromRGB(255, 200, 90), 40, 2)
    uplight(Vector3.new(px, 3.3, pz - 3.5), Vector3.new(px, 30, pz - 1.2))
end

----------------------------------------------------------------
-- Place it and attach the animations
----------------------------------------------------------------
-- [REX] bulbs start lit; the animation script takes over at runtime
for _, entry in ipairs(bulbs) do
    entry.part.Material = Enum.Material.Neon
    entry.part.Color = BULB_ON_COLOR
end

-- [REX] Animations as a child Script rather than loops held by the builder.
-- A bare Heartbeat connection and a while loop keep running inside Studio after
-- an edit-mode build, constantly moving parts and dirtying the place.
local animator = Instance.new("Script")
animator.Name = "ExteriorAnimator"
animator.Source = [[
-- Revolving door, chasing marquee bulbs and the jackpot counter.
local RunService = game:GetService("RunService")
local exterior = script.Parent

local ANIMATE_LIGHTS = true
local BULB_ON = Color3.fromRGB(255, 225, 150)
local BULB_OFF = Color3.fromRGB(120, 100, 60)

local door = exterior:FindFirstChild("RevolvingDoor")
if door then
	RunService.Heartbeat:Connect(function(dt)
		door:PivotTo(door:GetPivot() * CFrame.Angles(0, dt * 0.6, 0))
	end)
end

local bulbs, labels = {}, {}
for _, d in ipairs(exterior:GetDescendants()) do
	if d:IsA("BasePart") and d.Name == "MarqueeBulb" then
		table.insert(bulbs, d)
	elseif d:IsA("TextLabel") and d.Name == "JackpotLabel" then
		table.insert(labels, d)
	end
end

if ANIMATE_LIGHTS then
	task.spawn(function()
		local rng = Random.new(21)
		local step = 0
		local jackpot = 1000000
		while exterior.Parent do
			step += 1
			for i, part in ipairs(bulbs) do
				local on = (i + step) % 3 ~= 0
				part.Material = on and Enum.Material.Neon or Enum.Material.SmoothPlastic
				part.Color = on and BULB_ON or BULB_OFF
			end
			jackpot += rng:NextInteger(7, 95)
			local text = tostring(jackpot):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
			for _, label in ipairs(labels) do
				label.Text = "JACKPOT" .. string.char(10) .. "$" .. text
			end
			task.wait(0.25)
		end
	end)
end
]]
animator.Parent = exterior

exterior.WorldPivot = CFrame.new(0, 0, 0)
exterior:PivotTo(FRAME)

-- [REX] replace a previous run and live in the Casino folder
local parent = casinoRoot or workspace
local existing = parent:FindFirstChild(exterior.Name)
if existing then
    existing:Destroy()
end
exterior.Parent = parent

-- [REX] Settle the spawn pad onto the new forecourt. CasinoSpawn is a visible
-- 24x24 slab whose top sat at -1.50, while the new paving lands at -2.27, so it
-- stood up through the plaza as a grey square. Dropped flush and made
-- invisible, players now spawn on the paving itself.
local paveTop = -math.huge
for _, d in ipairs(exterior:GetDescendants()) do
    if d:IsA("BasePart") and d.Material == Enum.Material.Pavement then
        paveTop = math.max(paveTop, d.Position.Y + d.Size.Y / 2)
    end
end
if paveTop > -math.huge then
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("SpawnLocation") then
            d.Transparency = 1
            d.Position = Vector3.new(d.Position.X, paveTop - d.Size.Y / 2, d.Position.Z)
            print(string.format("[Grand Exterior] settled %s flush at %.2f and hid it",
                d.Name, paveTop))
        end
    end
end

local parts = 0
for _, d in ipairs(exterior:GetDescendants()) do
    if d:IsA("BasePart") then
        parts = parts + 1
    end
end
print(string.format("[Grand Exterior] built %s | %d parts, %d marquee bulbs | W=%d H=%d",
    exterior:GetFullName(), parts, #bulbs, W, H))

return exterior
