-- REALISTIC CASINO CHANDELIER
-- Written by James. Three changes from the original, each marked [REX] below:
--   1. POSITION / PARENT_NAME set for the Golden Spire casino (ceiling
--      underside is Y=45, lobby statue is at X=0 Z=-78)
--   2. any previous model of the same name is removed before parenting, so
--      re-running replaces the chandelier instead of stacking a second one
--   3. the trailing flicker loop moved into a child Script. Run in edit mode,
--      a bare task.spawn loop keeps spinning inside Studio forever and dirties
--      the place file; as a child Script it runs in game and travels with the
--      model if you copy it.
-- Everything else is untouched.

-- Settings:
local POSITION = Vector3.new(0, 45, -78) -- [REX] ceiling underside, centered on the lobby statue
local PARENT_NAME = "Casino"             -- [REX] folder under Workspace; falls back to Workspace
local DROP = 8                          -- how far it hangs down from the ceiling (at least 5)
local ARMS = 8                          -- candles on the bottom tier
local UPPER_ARMS = 6                    -- candles on the top tier
local RADIUS = 6                        -- width of the bottom tier
local ADD_GLOW = true                   -- adds a soft bloom glow to your game's lighting

local BRASS = Color3.fromRGB(201, 162, 74)
local BRASS_DARK = Color3.fromRGB(140, 105, 40)
local CRYSTAL = Color3.fromRGB(235, 245, 255)
local WAX = Color3.fromRGB(250, 243, 225)
local FLAME_OUTER = Color3.fromRGB(255, 150, 40)
local FLAME_INNER = Color3.fromRGB(255, 235, 170)
local LIGHT_COLOR = Color3.fromRGB(255, 190, 110)

local BRASS_STYLE = { Color = BRASS, Material = Enum.Material.Metal, Reflectance = 0.25 }
local DARK_STYLE = { Color = BRASS_DARK, Material = Enum.Material.Metal, Reflectance = 0.15 }
local CRYSTAL_STYLE = { Color = CRYSTAL, Material = Enum.Material.Glass, Transparency = 0.25, Reflectance = 0.5 }
local WAX_STYLE = { Color = WAX, Material = Enum.Material.SmoothPlastic }

local model = Instance.new("Model")
model.Name = "CasinoChandelier"

----------------------------------------------------------------
-- Building helpers
----------------------------------------------------------------
local function makePart(props)
    local p = Instance.new("Part")
    p.Anchored = true
    p.CanCollide = false
    p.CanTouch = false
    p.CanQuery = false
    p.CastShadow = false
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

local function ball(pos, size, style)
    return styled({
        Shape = Enum.PartType.Ball,
        Size = Vector3.new(size, size, size),
        CFrame = CFrame.new(pos),
    }, style)
end

-- Stretched sphere (for urns, bowls, flames, teardrops)
local function ellipsoid(pos, size, style)
    local p = styled({ Size = size, CFrame = CFrame.new(pos) }, style)
    local mesh = Instance.new("SpecialMesh")
    mesh.MeshType = Enum.MeshType.Sphere
    mesh.Parent = p
    return p
end

-- Flat upright cylinder
local function disc(pos, height, width, style)
    return styled({
        Shape = Enum.PartType.Cylinder,
        Size = Vector3.new(height, width, width),
        CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)),
    }, style)
end

-- Round bar from point a to point b
local function rod(a, b, thickness, style)
    local direction = (b - a).Unit
    local up = math.abs(direction.Y) > 0.99 and Vector3.new(1, 0, 0) or Vector3.new(0, 1, 0)
    local length = (b - a).Magnitude + thickness * 0.3
    return styled({
        Shape = Enum.PartType.Cylinder,
        Size = Vector3.new(length, thickness, thickness),
        CFrame = CFrame.lookAt((a + b) / 2, b, up) * CFrame.Angles(0, math.rad(90), 0),
    }, style)
end

-- Flat circular ring
local function ring(center, radius, thickness, segments, style)
    local last
    for i = 0, segments do
        local a = (i / segments) * math.pi * 2
        local point = center + Vector3.new(math.cos(a) * radius, 0, math.sin(a) * radius)
        if last then
            rod(last, point, thickness, style)
        end
        last = point
    end
end

-- One oval chain link
local function chainLink(pos, turn)
    local rotation = CFrame.Angles(0, turn, 0)
    local last
    for k = 0, 8 do
        local a = (k / 8) * math.pi * 2
        local offset = rotation:VectorToWorldSpace(Vector3.new(math.cos(a) * 0.17, math.sin(a) * 0.28, 0))
        local point = pos + offset
        if last then
            rod(last, point, 0.07, DARK_STYLE)
        end
        last = point
    end
end

-- Hanging crystal: small bead with a teardrop under it
local function crystalDrop(topPos, scale)
    ball(topPos - Vector3.new(0, 0.08 * scale, 0), 0.14 * scale, CRYSTAL_STYLE)
    ellipsoid(topPos - Vector3.new(0, 0.38 * scale, 0), Vector3.new(0.22, 0.5, 0.22) * scale, CRYSTAL_STYLE)
end

-- Candle with drip pan, crystals, wax drips, wick and flame
local function candle(base, s)
    disc(base, 0.1 * s, 1.5 * s, BRASS_STYLE)
    for k = 1, 4 do
        local a = (k / 4) * math.pi * 2 + math.pi / 4
        crystalDrop(base + Vector3.new(math.cos(a) * 0.65 * s, -0.05, math.sin(a) * 0.65 * s), 0.8 * s)
    end

    ellipsoid(base + Vector3.new(0, 0.25 * s, 0), Vector3.new(0.75, 0.5, 0.75) * s, BRASS_STYLE)
    disc(base + Vector3.new(0, 0.5 * s, 0), 0.08 * s, 0.7 * s, DARK_STYLE)

    local candleHeight = 1.6 * s
    local candleBottom = base + Vector3.new(0, 0.5 * s, 0)
    disc(candleBottom + Vector3.new(0, candleHeight / 2, 0), candleHeight, 0.38 * s, WAX_STYLE)
    local top = candleBottom + Vector3.new(0, candleHeight, 0)

    -- Wax drips
    for _ = 1, 2 do
        local a = math.random() * math.pi * 2
        local length = (0.25 + math.random() * 0.35) * s
        styled({
            Size = Vector3.new(0.08, length, 0.08) * Vector3.new(s, 1, s),
            CFrame = CFrame.new(top + Vector3.new(math.cos(a) * 0.19 * s, -length / 2, math.sin(a) * 0.19 * s)),
        }, WAX_STYLE)
    end

    -- Wick
    makePart({
        Size = Vector3.new(0.04, 0.15, 0.04) * s,
        CFrame = CFrame.new(top + Vector3.new(0, 0.07 * s, 0)),
        Color = Color3.fromRGB(30, 25, 20),
        Material = Enum.Material.SmoothPlastic,
    })

    -- Flame (outer glow + bright core)
    local flamePos = top + Vector3.new(0, 0.32 * s, 0)
    local outer = ellipsoid(flamePos, Vector3.new(0.22, 0.5, 0.22) * s,
        { Color = FLAME_OUTER, Material = Enum.Material.Neon, Transparency = 0.35 })
    outer.Name = "Flame" -- [REX] so the child flicker Script can find these
    ellipsoid(flamePos - Vector3.new(0, 0.06 * s, 0), Vector3.new(0.11, 0.28, 0.11) * s,
        { Color = FLAME_INNER, Material = Enum.Material.Neon })

    local light = Instance.new("PointLight")
    light.Color = LIGHT_COLOR
    light.Brightness = 1.2
    light.Range = 16
    light.Shadows = false
    light.Parent = outer

    local glow = Instance.new("ParticleEmitter")
    glow.Texture = "rbxasset://textures/particles/fire_main.dds"
    glow.Color = ColorSequence.new(FLAME_OUTER)
    glow.LightEmission = 1
    glow.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.3 * s),
        NumberSequenceKeypoint.new(1, 0),
    })
    glow.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.5),
        NumberSequenceKeypoint.new(1, 1),
    })
    glow.Lifetime = NumberRange.new(0.2, 0.4)
    glow.Rate = 15
    glow.Speed = NumberRange.new(0.3, 0.6)
    glow.SpreadAngle = Vector2.new(5, 5)
    glow.EmissionDirection = Enum.NormalId.Top
    glow.Parent = outer

    return light
end

-- Curved S-shaped arm; returns the point at its tip
local function arm(origin, angle, innerRadius, outerRadius, rise, dip, thickness)
    local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
    local segments = 7
    local last
    for k = 0, segments do
        local t = k / segments
        local r = innerRadius + t * (outerRadius - innerRadius)
        local y = -dip * math.sin(math.pi * t) + rise * t * t
        local point = origin + direction * r + Vector3.new(0, y, 0)
        if last then
            rod(last, point, thickness, BRASS_STYLE)
            if k < segments then
                ball(point, thickness, BRASS_STYLE)
            end
        end
        if k == 3 then
            ellipsoid(point - Vector3.new(0, thickness * 0.9, 0), Vector3.new(0.3, 0.45, 0.3), DARK_STYLE)
        end
        last = point
    end
    return last
end

-- Beaded crystal swags draped between candles
local function swags(bases, sag)
    local count = #bases
    for i = 1, count do
        local a = bases[i]
        local b = bases[(i % count) + 1]
        local direction = (b - a).Unit
        a = a + direction * 0.7
        b = b - direction * 0.7
        local beads = 14
        for k = 1, beads - 1 do
            local t = k / beads
            local pos = a:Lerp(b, t) - Vector3.new(0, sag * 4 * t * (1 - t), 0)
            ball(pos, 0.16, CRYSTAL_STYLE)
            if k == beads / 2 then
                crystalDrop(pos - Vector3.new(0, 0.08, 0), 1)
            end
        end
    end
end

----------------------------------------------------------------
-- Build the chandelier
----------------------------------------------------------------
DROP = math.max(DROP, 5)
local top = POSITION
local C = POSITION - Vector3.new(0, DROP, 0)
local flameLights = {}

-- Ceiling mount
disc(top - Vector3.new(0, 0.05, 0), 0.1, 3, DARK_STYLE)
ellipsoid(top - Vector3.new(0, 0.3, 0), Vector3.new(2.6, 0.9, 2.6), BRASS_STYLE)
ball(top - Vector3.new(0, 0.85, 0), 0.35, BRASS_STYLE)

-- Chain
local columnTop = C + Vector3.new(0, 3.4, 0)
local chainStart = top - Vector3.new(0, 1.05, 0)
local links = math.max(0, math.floor((chainStart.Y - columnTop.Y) / 0.45))
for i = 0, links - 1 do
    chainLink(chainStart - Vector3.new(0, 0.28 + i * 0.45, 0), (i % 2) * math.pi / 2)
end

-- Center column, top to bottom
ball(columnTop, 0.45, BRASS_STYLE)
ellipsoid(C + Vector3.new(0, 2.9, 0), Vector3.new(0.9, 0.6, 0.9), BRASS_STYLE)
disc(C + Vector3.new(0, 2.5, 0), 0.12, 1.3, DARK_STYLE)
rod(C + Vector3.new(0, 2.5, 0), C + Vector3.new(0, 1.9, 0), 0.35, BRASS_STYLE)
ellipsoid(C + Vector3.new(0, 1.6, 0), Vector3.new(1.5, 1.1, 1.5), BRASS_STYLE)
disc(C + Vector3.new(0, 1.05, 0), 0.15, 1.1, DARK_STYLE)
rod(C + Vector3.new(0, 1.0, 0), C + Vector3.new(0, 0.6, 0), 0.4, BRASS_STYLE)
ring(C + Vector3.new(0, 0.55, 0), 1.0, 0.1, 20, BRASS_STYLE)

local bowl = ellipsoid(C, Vector3.new(3.2, 1.5, 3.2), BRASS_STYLE)
ring(C, 1.6, 0.14, 28, DARK_STYLE)
disc(C - Vector3.new(0, 0.75, 0), 0.15, 1.6, DARK_STYLE)
ellipsoid(C - Vector3.new(0, 1.2, 0), Vector3.new(1.1, 0.9, 1.1), BRASS_STYLE)
ellipsoid(C - Vector3.new(0, 1.85, 0), Vector3.new(0.5, 0.8, 0.5), BRASS_STYLE)
ball(C - Vector3.new(0, 2.3, 0), 0.2, BRASS_STYLE)
crystalDrop(C - Vector3.new(0, 2.4, 0), 1.8)

-- Crystal strands hanging from the bowl
for i = 1, ARMS do
    local angle = ((i + 0.5) / ARMS) * math.pi * 2
    local start = C + Vector3.new(math.cos(angle) * 1.4, -0.3, math.sin(angle) * 1.4)
    for k = 0, 3 do
        ball(start - Vector3.new(0, k * 0.25, 0), 0.15, CRYSTAL_STYLE)
    end
    crystalDrop(start - Vector3.new(0, 1.0, 0), 1)
end

-- Bottom tier
local lowerBases = {}
for i = 1, ARMS do
    local angle = (i / ARMS) * math.pi * 2
    local tip = arm(C, angle, 1.4, RADIUS, 1.0, 1.0, 0.3)
    local base = tip + Vector3.new(0, 0.35, 0)
    rod(tip, base, 0.22, BRASS_STYLE)
    table.insert(flameLights, candle(base, 1))
    table.insert(lowerBases, base)
end
swags(lowerBases, 1.4)

-- Top tier
local upperOrigin = C + Vector3.new(0, 1.6, 0)
local upperBases = {}
for i = 1, UPPER_ARMS do
    local angle = ((i + 0.5) / UPPER_ARMS) * math.pi * 2
    local tip = arm(upperOrigin, angle, 0.6, RADIUS * 0.55, 0.9, 0.6, 0.22)
    local base = tip + Vector3.new(0, 0.3, 0)
    rod(tip, base, 0.18, BRASS_STYLE)
    table.insert(flameLights, candle(base, 0.85))
    table.insert(upperBases, base)
end
swags(upperBases, 0.9)

-- Main warm light
local mainLight = Instance.new("PointLight")
mainLight.Color = LIGHT_COLOR
mainLight.Brightness = 1.2
mainLight.Range = 50
mainLight.Shadows = false
mainLight.Parent = bowl

model.PrimaryPart = bowl

-- [REX] Candle flicker, as a child Script instead of a bare task.spawn loop.
-- Same behaviour, but it runs in game rather than spinning inside Studio.
local flicker = Instance.new("Script")
flicker.Name = "Flicker"
flicker.Source = [[
local model = script.Parent

local flameLights = {}
for _, d in ipairs(model:GetDescendants()) do
	if d:IsA("PointLight") and d.Parent.Name == "Flame" then
		table.insert(flameLights, d)
	end
end

local mainLight = model.PrimaryPart and model.PrimaryPart:FindFirstChildOfClass("PointLight")

while model.Parent do
	for _, light in ipairs(flameLights) do
		light.Brightness = 1.2 * (0.8 + math.random() * 0.4)
	end
	if mainLight then
		mainLight.Brightness = 1.2 * (0.95 + math.random() * 0.1)
	end
	task.wait(0.08)
end
]]
flicker.Parent = model

-- [REX] replace any previous chandelier of the same name instead of stacking
local parentFolder = workspace:FindFirstChild(PARENT_NAME) or workspace
local existing = parentFolder:FindFirstChild(model.Name)
if existing then
    existing:Destroy()
end
model.Parent = parentFolder

-- Soft glow on bright things (flames, crystals)
if ADD_GLOW then
    local Lighting = game:GetService("Lighting")
    if not Lighting:FindFirstChildOfClass("BloomEffect") then
        local bloom = Instance.new("BloomEffect")
        bloom.Intensity = 0.6
        bloom.Size = 20
        bloom.Threshold = 0.95
        bloom.Parent = Lighting
    end
end

return model
