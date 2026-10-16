-- GRAND CASINO SIDES, BACK & ROOF (use together with the GRAND CASINO EXTERIOR script)
-- Written by James. Changes marked [REX]:
--   1. Depth is measured from the Facade, not from the casino root. The root
--      now holds the parking lot, the trees and the forecourt, so it spans
--      Z -420..400 and D clamped to 400 instead of the building's real 225 -
--      the back wall would have landed 175 studs out in the car park.
--   2. Ground datum by raycast, as in the front script. partsBounds measures
--      corners, so a rotated facade part drags minV.Y to -4.90 while the
--      ground is -2.47; everything would sit 2.25 studs under. The probe
--      ignores the new exterior models so both scripts agree on one datum.
--   3. Roof height by raycast. RT = H - 2.4 puts the deck at 65.1 while the
--      real roof is at 52.3, so the whole roof set would float 13 studs above
--      the building.
--   4. Previous run cleared before any probing, parked in the Casino folder,
--      recursive parking lot lookup, and the light loop moved into a child
--      Script so it does not spin inside Studio after an edit-mode build.
-- The geometry is untouched.

-- Settings:
local CASINO_NAME = "GOLDEN SPIRE"
-- [REX] The front is the only entrance. With SIDE_ENTRANCES false the side
-- pavilions keep their shape - projecting tower, arched window, GOLDEN SPIRE
-- sign - but lose the glass doors and the lit marquee, so the building no
-- longer advertises three ways in when only one of them opens. Set it true to
-- put them back; the two labels below are only used when it is.
local SIDE_ENTRANCES = false
local LEFT_LABEL = "HOTEL ENTRANCE"   -- sign over one side entrance
local RIGHT_LABEL = "EVENT CENTER"    -- sign over the other side entrance
local AUTO_DETECT = true
local BUILDING_DEPTH = 0              -- 0 = measure automatically, or type how deep your building is
local HELIPAD = true
local ROOF_DOME = true
local ANIMATE_LIGHTS = true
local PARENT_NAME = "Casino"          -- [REX] folder under Workspace

-- Only used if AUTO_DETECT is false or your building can't be found (match the front script):
local FRONT_CENTER = Vector3.new(0, 0, 0)
local FRONT_DIRECTION = Vector3.new(0, 0, -1)
local BUILDING_WIDTH = 120
local BUILDING_HEIGHT = 40
local MANUAL_DEPTH = 100

local RunService = game:GetService("RunService")

----------------------------------------------------------------
-- Find and measure the building (same way as the front script)
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

-- [REX] probe helper that ignores spawn pads and the two generated exteriors,
-- so the sides land on the same ground the front script measured
local function surfaceAt(x, z, fromY)
    local skip = {}
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("SpawnLocation")
            or ((d:IsA("Model") or d:IsA("Folder"))
                and (d.Name == "GrandExterior" or d.Name == "GrandSidesAndRoof")) then
            table.insert(skip, d)
        end
    end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = skip
    local hit = workspace:Raycast(Vector3.new(x, fromY, z), Vector3.new(0, -400, 0), params)
    return hit and hit.Position.Y or nil, hit and hit.Instance.Name or "none"
end

local FRAME, W, H, D, casinoRoot, ROOF_Y
if AUTO_DETECT then
    local facade = workspace:FindFirstChild("Facade", true)
    if facade then
        local found, minV, maxV = partsBounds(facade)
        if found then
            casinoRoot = facade.Parent

            -- [REX] clear the previous run before probing, or the rays land on
            -- last run's own walls and roof
            local previous = casinoRoot:FindFirstChild("GrandSidesAndRoof")
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
                D = maxV.X - minV.X -- [REX] see note 1
            else
                origin = Vector3.new(center.X, minV.Y, dir.Z > 0 and maxV.Z or minV.Z)
                W = maxV.X - minV.X
                D = maxV.Z - minV.Z -- [REX] see note 1
            end
            H = maxV.Y - minV.Y

            -- [REX] ground datum, as in the front script
            local probe = origin + dir * 12
            local groundY, groundName = surfaceAt(probe.X, probe.Z, 12)
            if groundY then
                origin = Vector3.new(origin.X, groundY, origin.Z)
                print(string.format("[Sides & Roof] ground datum %.2f from %s (facade corner was %.2f)",
                    groundY, groundName, minV.Y))
            end

            FRAME = CFrame.lookAt(origin, origin + dir)

            -- [REX] real roof height. Sample inboard of the parapet and off the
            -- centre skylight, and take the lowest, so the new deck sits on the
            -- roof rather than on top of a bump.
            local best, bestName
            for _, f in ipairs({ { 0.3, 0.3 }, { -0.3, 0.3 }, { 0.3, -0.3 }, { -0.3, -0.3 } }) do
                local y, name = surfaceAt(center.X + f[1] * W * 0.5, center.Z + f[2] * D * 0.5, 250)
                if y and (not best or y < best) then
                    best, bestName = y, name
                end
            end
            if best then
                ROOF_Y = best
                print(string.format("[Sides & Roof] roof surface %.2f from %s (H - 2.4 would have been %.2f)",
                    best, bestName, origin.Y + math.clamp(H, 28, 70) - 2.4))
            end
        end
    end
end
if not FRAME then
    local flatDir = Vector3.new(FRONT_DIRECTION.X, 0, FRONT_DIRECTION.Z).Unit
    FRAME = CFrame.lookAt(FRONT_CENTER, FRONT_CENTER + flatDir)
    W, H, D = BUILDING_WIDTH, BUILDING_HEIGHT, MANUAL_DEPTH
end
if BUILDING_DEPTH > 0 then
    D = BUILDING_DEPTH
end
W = math.clamp(W, 80, 400)
H = math.clamp(H, 28, 70)
D = math.clamp(D or MANUAL_DEPTH, 40, 400)
print(string.format("[Sides & Roof] Building: %d wide, %d tall, %d deep", W, H, D))

----------------------------------------------------------------
-- Materials (same as the front)
----------------------------------------------------------------
local STONE = { Color = Color3.fromRGB(228, 218, 198), Material = Enum.Material.Limestone, CanCollide = true }
local STONE_DARK = { Color = Color3.fromRGB(196, 183, 160), Material = Enum.Material.Limestone, CanCollide = true }
local MARBLE = { Color = Color3.fromRGB(242, 238, 230), Material = Enum.Material.Marble, CanCollide = true }
local GRANITE = { Color = Color3.fromRGB(28, 28, 31), Material = Enum.Material.Granite, CanCollide = true }
local GOLD = { Color = Color3.fromRGB(212, 175, 55), Material = Enum.Material.Metal, Reflectance = 0.35 }
local GLASS_DARK = { Color = Color3.fromRGB(25, 30, 40), Material = Enum.Material.Glass, Transparency = 0.3, Reflectance = 0.35, CanCollide = true }
local GLOW = { Color = Color3.fromRGB(255, 190, 110), Material = Enum.Material.Neon, Transparency = 0.55 }
local NEON_GOLD = { Color = Color3.fromRGB(255, 200, 90), Material = Enum.Material.Neon }
local NEON_WARM = { Color = Color3.fromRGB(255, 230, 180), Material = Enum.Material.Neon }
local BULB_OFF = { Color = Color3.fromRGB(120, 100, 60), Material = Enum.Material.SmoothPlastic }
local CONCRETE = { Color = Color3.fromRGB(185, 182, 175), Material = Enum.Material.Concrete, CanCollide = true }
local HEDGE = { Color = Color3.fromRGB(40, 85, 38), Material = Enum.Material.LeafyGrass, CanCollide = true }
local BLACK_METAL = { Color = Color3.fromRGB(25, 25, 28), Material = Enum.Material.Metal, CanCollide = true }
local ROOF = { Color = Color3.fromRGB(70, 70, 74), Material = Enum.Material.Slate, CanCollide = true }
local ROOF_SEAM = { Color = Color3.fromRGB(50, 50, 54), Material = Enum.Material.SmoothPlastic }
local UNIT_METAL = { Color = Color3.fromRGB(175, 178, 182), Material = Enum.Material.Metal, CanCollide = true }
local DARK_METAL = { Color = Color3.fromRGB(60, 62, 66), Material = Enum.Material.Metal, CanCollide = true }
local PAINT_WHITE = { Color = Color3.fromRGB(240, 240, 235), Material = Enum.Material.SmoothPlastic }
local HELI_PAD = { Color = Color3.fromRGB(45, 45, 48), Material = Enum.Material.Asphalt, CanCollide = true }
local DOME_GLASS = { Color = Color3.fromRGB(255, 225, 180), Material = Enum.Material.Glass, Transparency = 0.45, Reflectance = 0.3 }

local BULB_ON_COLOR = Color3.fromRGB(255, 225, 150)
local UPLIGHT_COLOR = Color3.fromRGB(255, 205, 130)

local rng = Random.new(33)
local function rand(a, b)
    return rng:NextNumber(a, b)
end

local model = Instance.new("Model")
model.Name = "GrandSidesAndRoof"

----------------------------------------------------------------
-- Building helpers
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
    p.Parent = model
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

local function CF(x, y, z)
    return CFrame.new(x, y, z)
end

local function box(cf, size, style)
    return styled({ Size = size, CFrame = cf }, style)
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

local function cylUp(pos, height, width, style)
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

local function pointLight(part, color, range, brightness)
    local light = Instance.new("PointLight")
    light.Color = color
    light.Range = range
    light.Brightness = brightness
    light.Parent = part
end

local function textPanel(cf, sx, sy, text, font)
    local p = box(cf, Vector3.new(sx, sy, 0.04), { Transparency = 1 })
    local gui = Instance.new("SurfaceGui")
    gui.Face = Enum.NormalId.Front
    gui.LightInfluence = 0
    gui.Brightness = 1.6
    gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    gui.PixelsPerStud = 40
    gui.Parent = p
    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextScaled = true
    label.Font = font or Enum.Font.Bodoni
    label.TextColor3 = Color3.new(1, 1, 1)
    label.Parent = gui
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(60, 40, 0)
    stroke.Thickness = 2
    stroke.Parent = label
    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(200, 155, 40)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 240, 170)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 155, 40)),
    })
    gradient.Rotation = 90
    gradient.Parent = label
    return label
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
local function bulbRect(T, cy, z, w, h, spacing)
    local corners = {
        T * Vector3.new(-w / 2, cy + h / 2, z), T * Vector3.new(w / 2, cy + h / 2, z),
        T * Vector3.new(w / 2, cy - h / 2, z), T * Vector3.new(-w / 2, cy - h / 2, z),
    }
    for i = 1, 4 do
        bulbLine(corners[i], corners[i % 4 + 1], spacing)
    end
end

local blinkers = {}

----------------------------------------------------------------
-- Wall pieces (T = a frame on the wall's outside face, -Z points outward)
----------------------------------------------------------------
local function archedWindow(T, cx, ww, bottom, top, z)
    local r = ww / 2
    local archBase = math.max(bottom + 2, top - r)
    local rectH = archBase - bottom
    box(T * CF(cx, bottom + rectH / 2, z), Vector3.new(ww, rectH, 0.04), GLOW)
    box(T * CF(cx, bottom + rectH / 2, z - 0.07), Vector3.new(ww, rectH, 0.06), GLASS_DARK)
    for s = 0, 4 do
        local y = (s + 0.5) * (r / 5)
        local half = math.sqrt(math.max(r * r - y * y, 0.01))
        box(T * CF(cx, archBase + y, z), Vector3.new(half * 2, r / 5 + 0.02, 0.04), GLOW)
        box(T * CF(cx, archBase + y, z - 0.07), Vector3.new(half * 2, r / 5 + 0.02, 0.06), GLASS_DARK)
    end
    local fz = z - 0.25
    for _, side in ipairs({ -1, 1 }) do
        box(T * CF(cx + side * ww / 2, bottom + rectH / 2, fz), Vector3.new(0.35, rectH, 0.4), GOLD)
    end
    local last
    for s = 0, 10 do
        local a = math.pi * s / 10
        local point = T * Vector3.new(cx + math.cos(a) * r, archBase + math.sin(a) * r, fz)
        if last then
            rod(last, point, 0.35, GOLD)
        end
        last = point
    end
    box(T * CF(cx, archBase + r + 0.4, fz - 0.1), Vector3.new(1.0, 1.4, 0.8), GOLD)
    box(T * CF(cx, (bottom + archBase + r) / 2, fz + 0.05), Vector3.new(0.18, archBase + r - bottom, 0.2), GOLD)
    if ww > 10 then
        for _, x in ipairs({ -ww / 4, ww / 4 }) do
            box(T * CF(cx + x, (bottom + archBase) / 2, fz + 0.05), Vector3.new(0.18, archBase - bottom, 0.2), GOLD)
        end
    end
    for y = bottom + 5, archBase, 5 do
        box(T * CF(cx, y, fz + 0.05), Vector3.new(ww, 0.18, 0.2), GOLD)
    end
end

local function baysSegment(T, x0, x1)
    local span = x1 - x0
    if span < 10 then
        return
    end
    local count = math.max(1, math.floor(span / 14))
    local bayW = span / count
    for k = 0, count do
        local px = x0 + k * bayW
        box(T * CF(px, (4.5 + H - 6.3) / 2, -1.6), Vector3.new(2.2, H - 10.8, 2.2), MARBLE)
        box(T * CF(px, 5.1, -1.7), Vector3.new(2.8, 1.2, 2.6), STONE_DARK)
        box(T * CF(px, H - 6.8, -1.75), Vector3.new(3.0, 1.0, 2.9), GOLD)
        for _, f in ipairs({ -0.5, 0.5 }) do
            box(T * CF(px + f, (6 + H - 7.5) / 2, -2.72), Vector3.new(0.15, H - 13.5, 0.05), STONE_DARK)
        end
        box(T * CF(px, H - 1.2, -1.3), Vector3.new(1.2, 2.4, 1.6), STONE)
        ellipsoid(T * Vector3.new(px, H + 0.5, -1.3), Vector3.new(0.9, 1.2, 0.9), GOLD)
        uplight(T * Vector3.new(px, 0.5, -3.6), T * Vector3.new(px, H - 8, -1.6))
    end
    for k = 0, count - 1 do
        local bx = x0 + (k + 0.5) * bayW
        local ww = bayW - 4
        archedWindow(T, bx, ww, 7, H - 13, -1.05)
        box(T * CF(bx, 6.8, -1.5), Vector3.new(ww + 1, 0.5, 1.0), STONE_DARK)
        box(T * CF(bx, 0.95, -2.9), Vector3.new(ww, 1.5, 1.8), GRANITE)
        box(T * CF(bx, 1.72, -2.9), Vector3.new(ww + 0.1, 0.06, 1.9), GOLD)
        box(T * CF(bx, 2.3, -2.9), Vector3.new(ww - 0.4, 1.2, 1.4), HEDGE)
    end
end

local function pavilion(T, pav)
    local pw, ph = pav.width, H + pav.extra
    box(T * CF(0, ph / 2, -1.75), Vector3.new(pw, ph, 3.5), STONE)
    box(T * CF(0, 2.5, -1.95), Vector3.new(pw + 0.2, 5, 3.9), GRANITE)
    box(T * CF(0, 5.05, -3.92), Vector3.new(pw + 0.2, 0.2, 0.08), GOLD)
    for _, side in ipairs({ -1, 1 }) do
        box(T * CF(side * (pw / 2 - 1.2), (5 + ph - 3) / 2, -3.75), Vector3.new(0.7, ph - 8, 0.5), GOLD)
        uplight(T * Vector3.new(side * (pw / 2 - 1), 0.5, -6), T * Vector3.new(side * (pw / 2 - 1), ph - 4, -3.5))
    end

    local windowBottom = pav.doors and 11.5 or 6
    archedWindow(T, 0, pw - 8, windowBottom, ph - 10, -3.55)

    -- Lit sign with chasing bulbs
    box(T * CF(0, ph - 6.3, -3.75), Vector3.new(pw - 6, 3.6, 0.5), GRANITE)
    textPanel(T * CF(0, ph - 6.3, -4.02), pw - 8, 2.8, pav.sign)
    bulbRect(T, ph - 6.3, -4.1, pw - 5.4, 4.4, 1.1)

    -- Stepped crown with a spire
    box(T * CF(0, ph - 1.2, -1.75), Vector3.new(pw + 1.6, 1.6, 5.2), STONE_DARK)
    box(T * CF(0, ph - 0.3, -1.75), Vector3.new(pw + 2, 0.3, 5.6), GOLD)
    box(T * CF(0, ph - 2.1, -4.38), Vector3.new(pw + 1.6, 0.2, 0.05), NEON_GOLD)
    box(T * CF(0, ph + 1.2, -1.75), Vector3.new(pw * 0.5, 2.4, 3.6), STONE)
    box(T * CF(0, ph + 2.5, -1.75), Vector3.new(pw * 0.5 + 0.6, 0.3, 4.2), GOLD)
    box(T * CF(0, ph + 3.4, -1.75), Vector3.new(pw * 0.25, 1.6, 3), STONE)
    rod(T * Vector3.new(0, ph + 4.2, -1.75), T * Vector3.new(0, ph + 9.5, -1.75), 0.45, GOLD)
    local tip = ball(T * Vector3.new(0, ph + 9.8, -1.75), 0.9, NEON_GOLD)
    pointLight(tip, Color3.fromRGB(255, 200, 90), 20, 1.5)

    if pav.doors then
        local dw = pw - 8
        local panels = 3
        local panelW = dw / panels
        for p = 0, panels - 1 do
            local px = -dw / 2 + (p + 0.5) * panelW
            box(T * CF(px, 4.7, -3.6), Vector3.new(panelW - 0.3, 9, 0.12), GLASS_DARK)
            box(T * CF(px, 4.7, -3.63), Vector3.new(panelW - 0.3, 9, 0.04), GLOW)
            for _, edge in ipairs({ -0.5, 0.5 }) do
                box(T * CF(px + edge * panelW, 5, -3.75), Vector3.new(0.25, 10, 0.3), GOLD)
            end
            box(T * CF(px, 4, -3.8), Vector3.new(panelW * 0.6, 0.15, 0.15), GOLD)
        end
        box(T * CF(0, 9.4, -3.75), Vector3.new(dw + 0.5, 0.3, 0.3), GOLD)

        -- Small marquee canopy over the doors
        box(T * CF(0, 10.4, -6), Vector3.new(pw - 4, 1.2, 5), GRANITE)
        box(T * CF(0, 10.4, -8.55), Vector3.new(pw - 4, 1.4, 0.1), GOLD)
        box(T * CF(0, 9.75, -8.4), Vector3.new(pw - 4, 0.12, 0.25), NEON_GOLD)
        textPanel(T * CF(0, 10.4, -8.62), pw - 8, 0.9, pav.label, Enum.Font.GothamBold)
        bulbLine(T * Vector3.new(-(pw - 4) / 2, 11.3, -8.4), T * Vector3.new((pw - 4) / 2, 11.3, -8.4), 1.1)
        for _, x in ipairs({ -pw / 5, pw / 5 }) do
            local light = box(T * CF(x, 9.77, -6), Vector3.new(1.2, 0.06, 1.2), NEON_WARM)
            local spot = Instance.new("SpotLight")
            spot.Face = Enum.NormalId.Bottom
            spot.Color = Color3.fromRGB(255, 225, 170)
            spot.Range = 18
            spot.Angle = 90
            spot.Brightness = 2
            spot.Parent = light
        end
    end
end

local function facadeWall(T, length, bayHalf, pav)
    box(T * CF(0, H / 2, -0.5), Vector3.new(length, H, 1), STONE)
    box(T * CF(0, 2.25, -1.2), Vector3.new(length, 4.5, 1.4), GRANITE)
    box(T * CF(0, 4.55, -1.92), Vector3.new(length, 0.2, 0.08), GOLD)
    box(T * CF(0, H - 6, -1.3), Vector3.new(length, 0.6, 1.6), STONE_DARK)
    box(T * CF(0, H - 4.8, -1.6), Vector3.new(length, 1.8, 2.2), STONE)
    box(T * CF(0, H - 4.8, -2.72), Vector3.new(length, 0.25, 0.06), NEON_GOLD)
    box(T * CF(0, H - 3, -2.2), Vector3.new(length, 0.8, 3.0), STONE)
    box(T * CF(0, H - 2.5, -2.5), Vector3.new(length, 0.2, 3.6), GOLD)
    box(T * CF(0, H - 2.2, -1.3), Vector3.new(length, 0.4, 1.4), STONE)
    box(T * CF(0, H - 0.2, -1.3), Vector3.new(length, 0.4, 1.6), STONE)
    for x = -length / 2 + 0.8, length / 2 - 0.8, 1.6 do
        box(T * CF(x, H - 3.6, -2.6), Vector3.new(0.7, 0.5, 1.8), STONE_DARK)
    end
    for x = -length / 2 + 1, length / 2 - 1, 1.4 do
        cylUp(T * Vector3.new(x, H - 1.2, -1.3), 1.6, 0.55, MARBLE)
    end
    if pav then
        baysSegment(T, -bayHalf, -pav.width / 2)
        baysSegment(T, pav.width / 2, bayHalf)
        pavilion(T, pav)
    else
        baysSegment(T, -bayHalf, bayHalf)
    end
end

----------------------------------------------------------------
-- Corner towers (back corners, plus the sides of the front towers)
----------------------------------------------------------------
local TH = H + 8
local function towerFace(faceCF, faceWidth)
    box(faceCF * CF(0, 5.05, -0.32), Vector3.new(faceWidth + 0.6, 0.2, 0.08), GOLD)
    for y = 7, 14, 2.5 do
        box(faceCF * CF(0, y, -0.03), Vector3.new(faceWidth, 0.15, 0.06), STONE_DARK)
    end
    local winH = TH - 24
    if winH > 4 then
        local wy = 16 + winH / 2
        box(faceCF * CF(0, wy, -0.05), Vector3.new(3.2, winH, 0.04), GLOW)
        box(faceCF * CF(0, wy, -0.1), Vector3.new(3.2, winH, 0.06), GLASS_DARK)
        for _, side in ipairs({ -1, 1 }) do
            box(faceCF * CF(side * 1.75, wy, -0.2), Vector3.new(0.3, winH + 0.6, 0.3), GOLD)
            box(faceCF * CF(0, wy + side * (winH / 2 + 0.15), -0.2), Vector3.new(3.8, 0.3, 0.3), GOLD)
        end
    end
    box(faceCF * CF(0, TH - 3.3, -0.83), Vector3.new(faceWidth + 1.6, 0.2, 0.05), NEON_GOLD)
    uplight(faceCF * Vector3.new(0, 0.5, -2), faceCF * Vector3.new(0, TH - 6, 0))
end

local function cornerTower(cx, cz)
    box(CF(cx, TH / 2, cz), Vector3.new(14, TH, 6), STONE)
    box(CF(cx, 2.5, cz), Vector3.new(14.6, 5, 6.6), GRANITE)
    box(CF(cx, TH - 2.5, cz), Vector3.new(15.6, 1.4, 7.6), STONE_DARK)
    box(CF(cx, TH - 1.7, cz), Vector3.new(16.2, 0.3, 8.2), GOLD)
    cylUp(Vector3.new(cx, TH + 1.5, cz), 3, 9, STONE)
    for c = 1, 8 do
        local a = (c / 8) * math.pi * 2
        local x, z = cx + math.cos(a) * 4.6, cz + math.sin(a) * 4.6
        rod(Vector3.new(x, TH, z), Vector3.new(x, TH + 3, z), 0.4, GOLD)
    end
    cylUp(Vector3.new(cx, TH + 3.1, cz), 0.3, 9.8, GOLD)
    ellipsoid(Vector3.new(cx, TH + 3, cz), Vector3.new(9.2, 8, 9.2), GOLD)
    rod(Vector3.new(cx, TH + 6.8, cz), Vector3.new(cx, TH + 11, cz), 0.3, GOLD)
    local tip = ball(Vector3.new(cx, TH + 11.2, cz), 0.8, NEON_GOLD)
    pointLight(tip, Color3.fromRGB(255, 200, 90), 20, 1.5)
end

local function faceFrame(point, normal)
    return CFrame.lookAt(point, point + normal)
end

for _, sign in ipairs({ -1, 1 }) do
    local cx = sign * (W / 2 - 5)
    local out = Vector3.new(sign, 0, 0)
    -- Back corner tower
    cornerTower(cx, D + 1)
    towerFace(faceFrame(Vector3.new(cx, 0, D + 4), Vector3.new(0, 0, 1)), 14)
    towerFace(faceFrame(Vector3.new(cx + sign * 7, 0, D + 1), out), 6)
    -- Side of the front corner tower (built by the front script)
    towerFace(faceFrame(Vector3.new(cx + sign * 7, 0, -1), out), 6)
end

----------------------------------------------------------------
-- Sides and back walls
----------------------------------------------------------------
local sideLength = D - 4
local sidePavilionWidth = math.clamp(sideLength * 0.25, 22, 34)
for _, sign in ipairs({ -1, 1 }) do
    local T = faceFrame(Vector3.new(sign * W / 2, 0, D / 2), Vector3.new(sign, 0, 0))
    local pav = nil
    if sideLength >= sidePavilionWidth + 24 then
        pav = { width = sidePavilionWidth, extra = 6, sign = CASINO_NAME,
            doors = SIDE_ENTRANCES, label = sign < 0 and LEFT_LABEL or RIGHT_LABEL }
    end
    facadeWall(T, sideLength, sideLength / 2, pav)
end

local backT = faceFrame(Vector3.new(0, 0, D), Vector3.new(0, 0, 1))
local backBayHalf = W / 2 - 12
local backPav = { width = math.clamp(W * 0.25, 26, 40), extra = 10, sign = CASINO_NAME, doors = false }
facadeWall(backT, W - 20, backBayHalf, backBayHalf * 2 >= backPav.width + 20 and backPav or nil)

----------------------------------------------------------------
-- Sidewalk around the sides and back, with path lights
----------------------------------------------------------------
for _, sign in ipairs({ -1, 1 }) do
    box(CF(sign * (W / 2 + 4.5), 0.1, D / 2 + 1), Vector3.new(7, 0.2, D + 14), CONCRETE)
end
box(CF(0, 0.1, D + 4.5), Vector3.new(W + 16, 0.2, 7), CONCRETE)

local function pathLight(pos)
    cylUp(pos + Vector3.new(0, 0.9, 0), 1.6, 0.4, BLACK_METAL)
    local cap = ball(pos + Vector3.new(0, 1.85, 0), 0.45, NEON_WARM)
    return cap
end
local lightIndex = 0
for _, sign in ipairs({ -1, 1 }) do
    for z = 0, D + 6, 12 do
        lightIndex += 1
        local cap = pathLight(Vector3.new(sign * (W / 2 + 7.5), 0.2, z))
        if lightIndex % 2 == 0 then
            pointLight(cap, Color3.fromRGB(255, 220, 160), 10, 0.8)
        end
    end
end
for x = -W / 2, W / 2, 12 do
    lightIndex += 1
    local cap = pathLight(Vector3.new(x, 0.2, D + 7.5))
    if lightIndex % 2 == 0 then
        pointLight(cap, Color3.fromRGB(255, 220, 160), 10, 0.8)
    end
end

----------------------------------------------------------------
-- Roof
----------------------------------------------------------------
-- [REX] measured, not H - 2.4. The real roof is 13 studs lower than that
-- formula gives on this building, which would float the whole roof set.
local RT = ROOF_Y and (ROOF_Y + 0.3 - FRAME.Position.Y) or (H - 2.4)
box(CF(0, RT - 0.25, D / 2), Vector3.new(W, 0.5, D), ROOF)
for z = 8, D - 1, 8 do
    box(CF(0, RT + 0.01, z), Vector3.new(W - 1, 0.02, 0.15), ROOF_SEAM)
end
for x = -W / 2 + 8, W / 2 - 1, 8 do
    box(CF(x, RT + 0.01, D / 2), Vector3.new(0.15, 0.02, D - 1), ROOF_SEAM)
end

local blocked = {} -- areas already used on the roof
local function isFree(x, z, radius)
    for _, area in ipairs(blocked) do
        if (Vector2.new(x, z) - area.pos).Magnitude < radius + area.radius then
            return false
        end
    end
    return math.abs(x) + radius < W / 2 - 2 and z - radius > 2 and z + radius < D - 2
end
local function block(x, z, radius)
    table.insert(blocked, { pos = Vector2.new(x, z), radius = radius })
end

-- Glass dome
if ROOF_DOME then
    local zc = D * 0.45
    local R = math.clamp(math.min(W, D) * 0.16, 8, 18)
    block(0, zc, R + 2)
    local drumTop = RT + 4
    cylUp(Vector3.new(0, RT + 2, zc), 4, R * 2 + 1, STONE)
    cylUp(Vector3.new(0, RT + 0.4, zc), 0.8, R * 2 + 2, STONE_DARK)
    cylUp(Vector3.new(0, drumTop + 0.1, zc), 0.4, R * 2 + 1.8, GOLD)
    for k = 1, 12 do
        local a = (k / 12) * math.pi * 2
        local outward = Vector3.new(math.cos(a), 0, math.sin(a))
        local pos = Vector3.new(0, RT + 2.2, zc) + outward * (R + 0.52)
        styled({ Size = Vector3.new(2, 2.4, 0.05), CFrame = CFrame.lookAt(pos, pos + outward) }, NEON_WARM)
    end
    local glow = ellipsoid(Vector3.new(0, drumTop, zc), Vector3.new(R * 2 - 0.6, R * 1.7 - 0.6, R * 2 - 0.6), GLOW)
    pointLight(glow, Color3.fromRGB(255, 200, 120), R * 2, 1.5)
    ellipsoid(Vector3.new(0, drumTop, zc), Vector3.new(R * 2, R * 1.7, R * 2), DOME_GLASS)
    for k = 1, 12 do
        local a = (k / 12) * math.pi * 2
        local last
        for t = 0, 8 do
            local phi = (t / 8) * math.pi / 2
            local point = Vector3.new(math.cos(a) * (R + 0.15) * math.cos(phi), drumTop + 0.85 * (R + 0.15) * math.sin(phi), zc + math.sin(a) * (R + 0.15) * math.cos(phi))
            if last then
                rod(last, point, 0.35, GOLD)
            end
            last = point
        end
    end
    local domeTop = drumTop + 0.85 * R
    cylUp(Vector3.new(0, domeTop + 0.8, zc), 1.6, 2.6, STONE)
    ellipsoid(Vector3.new(0, domeTop + 1.6, zc), Vector3.new(2.8, 2.2, 2.8), GOLD)
    rod(Vector3.new(0, domeTop + 2.5, zc), Vector3.new(0, domeTop + 7, zc), 0.3, GOLD)
    local tip = ball(Vector3.new(0, domeTop + 7.3, zc), 0.9, NEON_GOLD)
    pointLight(tip, Color3.fromRGB(255, 200, 90), 25, 1.5)
end

-- Helipad
if HELIPAD then
    local zc = D - 15
    if isFree(0, zc, 12) then
        block(0, zc, 12)
        box(CF(0, RT + 0.15, zc), Vector3.new(24, 0.3, 24), HELI_PAD)
        local last
        for s = 0, 32 do
            local a = (s / 32) * math.pi * 2
            local point = Vector3.new(math.cos(a) * 8.5, RT + 0.32, zc + math.sin(a) * 8.5)
            if last then
                rod(last, point, 0.6, PAINT_WHITE)
            end
            last = point
        end
        box(CF(-2.2, RT + 0.32, zc), Vector3.new(1, 0.04, 7), PAINT_WHITE)
        box(CF(2.2, RT + 0.32, zc), Vector3.new(1, 0.04, 7), PAINT_WHITE)
        box(CF(0, RT + 0.32, zc), Vector3.new(4.4, 0.04, 1), PAINT_WHITE)
        for s = 0, 15 do
            local a = (s / 16) * math.pi * 2
            local edge = ball(Vector3.new(math.cos(a) * 11.3, RT + 0.45, zc + math.sin(a) * 11.3), 0.35,
                { Color = Color3.fromRGB(60, 255, 120), Material = Enum.Material.Neon })
            edge.Name = "BlinkerGreen" -- [REX] for the animation script
            table.insert(blinkers, { part = edge, color = Color3.fromRGB(60, 255, 120), offset = s % 2 })
        end
    end
end

-- Stair hut with a door
local hutX, hutZ = -W * 0.3, D * 0.5
if isFree(hutX, hutZ, 6) then
    block(hutX, hutZ, 6)
    box(CF(hutX, RT + 4, hutZ), Vector3.new(8, 8, 6), STONE)
    box(CF(hutX, RT + 8.2, hutZ), Vector3.new(8.8, 0.4, 6.8), STONE_DARK)
    box(CF(hutX, RT + 8.45, hutZ), Vector3.new(9, 0.1, 7), GOLD)
    box(CF(hutX + 4.02, RT + 3.4, hutZ), Vector3.new(0.1, 6.5, 3), DARK_METAL)
    box(CF(hutX + 4.1, RT + 3.4, hutZ - 1.1), Vector3.new(0.1, 0.15, 0.5), GOLD)
    local hutLight = box(CF(hutX + 4.1, RT + 7.2, hutZ), Vector3.new(0.2, 0.4, 0.8), NEON_WARM)
    pointLight(hutLight, Color3.fromRGB(255, 220, 160), 12, 1)
end

-- Air conditioning units
local function acUnit(x, z)
    local base = RT
    for _, side in ipairs({ -1, 1 }) do
        box(CF(x, base + 0.2, z + side * 2), Vector3.new(8.4, 0.4, 0.5), DARK_METAL)
    end
    box(CF(x, base + 2.15, z), Vector3.new(8, 3.5, 5), UNIT_METAL)
    for k = -3, 3 do
        box(CF(x + k, base + 2.1, z - 2.52), Vector3.new(0.15, 2.6, 0.05), DARK_METAL)
    end
    for _, fx in ipairs({ -2, 2 }) do
        cylUp(Vector3.new(x + fx, base + 3.95, z), 0.2, 3, DARK_METAL)
        for b = 0, 2 do
            styled({
                Size = Vector3.new(2.6, 0.08, 0.5),
                CFrame = CFrame.new(x + fx, base + 4.1, z) * CFrame.Angles(0, b * math.pi / 3 + rand(0, 1), 0),
            }, UNIT_METAL)
        end
        for g = -1, 1 do
            box(CF(x + fx + g * 0.9, base + 4.2, z), Vector3.new(0.08, 0.08, 3), DARK_METAL)
        end
    end
    rod(Vector3.new(x + 4, base + 2, z), Vector3.new(x + 6, base + 2, z), 1.2, UNIT_METAL)
    rod(Vector3.new(x + 6, base + 2, z), Vector3.new(x + 6, base + 0.2, z), 1.2, UNIT_METAL)
end
for _, spot in ipairs({ { W * 0.3, D * 0.22 }, { -W * 0.3, D * 0.22 }, { W * 0.3, D * 0.7 }, { -W * 0.3, D * 0.75 } }) do
    if isFree(spot[1], spot[2], 6) then
        block(spot[1], spot[2], 6)
        acUnit(spot[1], spot[2])
    end
end

-- Vent pipes
for _ = 1, 10 do
    local x, z = rand(-W / 2 + 4, W / 2 - 4), rand(4, D - 4)
    if isFree(x, z, 1.5) then
        block(x, z, 1.5)
        local height = rand(1.5, 3)
        cylUp(Vector3.new(x, RT + height / 2, z), height, 0.6, UNIT_METAL)
        cylUp(Vector3.new(x, RT + height + 0.15, z), 0.3, 1.0, DARK_METAL)
    end
end

-- Radio mast with a blinking red light
local mastX, mastZ = W / 2 - 14, D - 8
if isFree(mastX, mastZ, 2) then
    box(CF(mastX, RT + 0.3, mastZ), Vector3.new(2, 0.6, 2), DARK_METAL)
    rod(Vector3.new(mastX, RT, mastZ), Vector3.new(mastX, RT + 16, mastZ), 0.35, DARK_METAL)
    for y = RT + 3, RT + 13, 3 do
        box(CF(mastX, y, mastZ), Vector3.new(1.4, 0.12, 0.12), DARK_METAL)
    end
    local beacon = ball(Vector3.new(mastX, RT + 16.3, mastZ), 0.6, { Color = Color3.fromRGB(255, 30, 30), Material = Enum.Material.Neon })
    beacon.Name = "BlinkerRed" -- [REX] for the animation script
    pointLight(beacon, Color3.fromRGB(255, 40, 40), 12, 1)
    table.insert(blinkers, { part = beacon, color = Color3.fromRGB(255, 30, 30), offset = 0 })
end

----------------------------------------------------------------
-- Place it and attach the lights
----------------------------------------------------------------
-- [REX] bulbs start lit; the animation script takes over at runtime
for _, entry in ipairs(bulbs) do
    entry.part.Material = Enum.Material.Neon
    entry.part.Color = BULB_ON_COLOR
end

-- [REX] the light loop as a child Script, so it does not spin inside Studio
local animator = Instance.new("Script")
animator.Name = "SidesAndRoofAnimator"
animator.Source = [[
-- Chasing marquee bulbs, plus the helipad and mast beacons.
local model = script.Parent
local BULB_ON = Color3.fromRGB(255, 225, 150)
local BULB_OFF = Color3.fromRGB(120, 100, 60)
local GREEN = Color3.fromRGB(60, 255, 120)
local RED = Color3.fromRGB(255, 30, 30)
local DIM = Color3.fromRGB(40, 40, 40)

local bulbs, blinkers = {}, {}
for _, d in ipairs(model:GetDescendants()) do
	if d:IsA("BasePart") then
		if d.Name == "MarqueeBulb" then
			table.insert(bulbs, d)
		elseif d.Name == "BlinkerGreen" then
			table.insert(blinkers, { part = d, color = GREEN, offset = #blinkers % 2 })
		elseif d.Name == "BlinkerRed" then
			table.insert(blinkers, { part = d, color = RED, offset = 0 })
		end
	end
end

task.spawn(function()
	local step = 0
	while model.Parent do
		step += 1
		for i, part in ipairs(bulbs) do
			local on = (i + step) % 3 ~= 0
			part.Material = on and Enum.Material.Neon or Enum.Material.SmoothPlastic
			part.Color = on and BULB_ON or BULB_OFF
		end
		if step % 4 == 0 then
			local phase = (step / 4) % 2
			for _, b in ipairs(blinkers) do
				local on = (phase + b.offset) % 2 == 0
				b.part.Material = on and Enum.Material.Neon or Enum.Material.SmoothPlastic
				b.part.Color = on and b.color or DIM
			end
		end
		task.wait(0.25)
	end
end)
]]
animator.Parent = model

model.WorldPivot = CFrame.new(0, 0, 0)
model:PivotTo(FRAME)
model.Parent = casinoRoot or workspace

local parts = 0
for _, d in ipairs(model:GetDescendants()) do
    if d:IsA("BasePart") then
        parts = parts + 1
    end
end
print(string.format("[Sides & Roof] built %s | %d parts, %d bulbs | roof deck at %.2f",
    model:GetFullName(), parts, #bulbs, FRAME.Position.Y + RT))

return model
