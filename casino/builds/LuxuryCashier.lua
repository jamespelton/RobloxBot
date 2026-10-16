-- LUXURY CASHIER CAGE (keeps your game prompts and scripts working)
-- Written by James. Changes are marked [REX]:
--
--   1. THE PROMPT WOULD HAVE ENDED UP IN THE QUEUE. CasinoCore hangs the
--      "Collect chips" prompt 2.5 studs in front of the OLD CounterTop. The
--      old cashier is 20 studs deep with its counter at the front, but the
--      depth was clamped to 10 and the back kept against the wall, so the new
--      counter moved 10 studs back and the prompt floated at the far end of
--      the velvet-rope line. The cage now keeps the old footprint, so the new
--      counter stands where the old one did and the prompt is at the windows.
--   2. The build started from the bottom of the old cashier's raised floor
--      slab, 0.15 BELOW the casino carpet, so the red queue runner and its
--      gold edging were buried under the carpet. It stands on the real floor.
--   3. The teller stool Seat was built by cylUp(), which turns the part 90
--      degrees about Z; a Seat orients the sitter by its own CFrame, so they
--      would have sat on their side. Upright SitPad facing the window now.
--   4. A second run built a second cage on top of the first, and re-recorded
--      OldTransparency as 1 so the old look could never come back. The
--      previous build is replaced and the original is recorded once.
--   5. Parented into the Casino folder, like the other builds.
--   6. THE WHOLE CAGE WAS BUILT BACKWARDS. Which way the cashier faces is read
--      from the side of the CASHIER sign its text is on, but the face
--      directions were flipped: a part's Front face points along its
--      LookVector, and this used -LookVector. The counter faced the casino's
--      back wall and the queue ran into it.

-- Settings:
local SIGN_TEXT = "CASHIER"
local SUBTITLE = "CHIPS  •  CASH  •  TICKETS"
local KIOSKS = true        -- ticket kiosk and ATM on the sides
local QUEUE_LINE = true    -- velvet rope waiting line in front
local SITTABLE = true

local V = Vector3.new
local UP = V(0, 1, 0)
local rng = Random.new(3)

----------------------------------------------------------------
-- Materials
----------------------------------------------------------------
local GOLD = { Color = Color3.fromRGB(212, 175, 55), Material = Enum.Material.Metal, Reflectance = 0.35 }
local BRASS = { Color = Color3.fromRGB(190, 150, 60), Material = Enum.Material.Metal, Reflectance = 0.4 }
local STEEL = { Color = Color3.fromRGB(170, 172, 176), Material = Enum.Material.Metal, Reflectance = 0.25 }
local MAHOGANY = { Color = Color3.fromRGB(75, 30, 22), Material = Enum.Material.Wood }
local DARK_WOOD = { Color = Color3.fromRGB(45, 20, 14), Material = Enum.Material.Wood }
local MARBLE = { Color = Color3.fromRGB(240, 236, 228), Material = Enum.Material.Marble }
local GRANITE = { Color = Color3.fromRGB(25, 25, 28), Material = Enum.Material.Granite }
local GLASS = { Color = Color3.fromRGB(200, 220, 235), Material = Enum.Material.Glass, Transparency = 0.7, Reflectance = 0.25 }
local BLACK = { Color = Color3.fromRGB(18, 18, 20), Material = Enum.Material.SmoothPlastic }
local WHITE = { Color = Color3.fromRGB(245, 245, 240), Material = Enum.Material.SmoothPlastic }
local LEATHER = { Color = Color3.fromRGB(140, 15, 25), Material = Enum.Material.Leather }
local VELVET = { Color = Color3.fromRGB(140, 10, 20), Material = Enum.Material.Fabric }
local CARPET = { Color = Color3.fromRGB(120, 12, 20), Material = Enum.Material.Carpet }
local KIOSK_BODY = { Color = Color3.fromRGB(25, 25, 32), Material = Enum.Material.Metal, Reflectance = 0.15 }
local NEON_WARM = { Color = Color3.fromRGB(255, 225, 170), Material = Enum.Material.Neon }
local NEON_GOLD = { Color = Color3.fromRGB(255, 200, 90), Material = Enum.Material.Neon }
local NEON_GREEN = { Color = Color3.fromRGB(60, 255, 120), Material = Enum.Material.Neon }
local NEON_RED = { Color = Color3.fromRGB(255, 50, 50), Material = Enum.Material.Neon }
local NEON_BLUE = { Color = Color3.fromRGB(80, 160, 255), Material = Enum.Material.Neon }
local CHIP_COLORS = {
    Color3.fromRGB(200, 30, 30), Color3.fromRGB(30, 80, 200), Color3.fromRGB(30, 150, 60),
    Color3.fromRGB(20, 20, 20), Color3.fromRGB(240, 240, 240), Color3.fromRGB(150, 60, 170), Color3.fromRGB(240, 170, 40),
}

----------------------------------------------------------------
-- Helpers
----------------------------------------------------------------
local current
local function makePart(props, style, className)
    local p = Instance.new(className or "Part")
    p.Anchored = true
    p.CanCollide = false
    p.CanTouch = false
    p.CastShadow = false
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    for k, v in pairs(style) do
        p[k] = v
    end
    for k, v in pairs(props) do
        p[k] = v
    end
    p.Parent = current
    return p
end
local function box(cf, size, style, className)
    return makePart({ CFrame = cf, Size = size }, style, className)
end
local function ball(pos, size, style)
    return makePart({ Shape = Enum.PartType.Ball, CFrame = CFrame.new(pos), Size = V(size, size, size) }, style)
end
local function cylUp(pos, height, width, style, className)
    return makePart({
        Shape = Enum.PartType.Cylinder,
        CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)),
        Size = V(height, width, width),
    }, style, className)
end
local function rod(a, b, thickness, style)
    local dir = (b - a).Unit
    local up = math.abs(dir.Y) > 0.98 and V(1, 0, 0) or UP
    return makePart({
        Shape = Enum.PartType.Cylinder,
        CFrame = CFrame.lookAt((a + b) / 2, b, up) * CFrame.Angles(0, math.rad(90), 0),
        Size = V((b - a).Magnitude + thickness * 0.3, thickness, thickness),
    }, style)
end
local function ellipsoid(pos, size, style)
    local p = makePart({ CFrame = CFrame.new(pos), Size = size }, style)
    local mesh = Instance.new("SpecialMesh")
    mesh.MeshType = Enum.MeshType.Sphere
    mesh.Parent = p
    return p
end
local function flat(v)
    return V(v.X, 0, v.Z)
end
local function label(part, lines)
    local g = Instance.new("SurfaceGui")
    g.Face = Enum.NormalId.Front
    g.LightInfluence = 0
    g.Brightness = 1.5
    g.Parent = part
    for _, line in ipairs(lines) do
        local l = Instance.new("TextLabel")
        l.Position = UDim2.fromScale(line.x or 0.03, line.y)
        l.Size = UDim2.fromScale(line.w or 0.94, line.h)
        l.BackgroundTransparency = 1
        l.Text = line.text
        l.TextScaled = true
        l.Font = line.font or Enum.Font.GothamBold
        l.TextColor3 = line.color or Color3.new(1, 1, 1)
        l.Parent = g
    end
    return g
end
local function frameBars(cf, w, h, thickness, depth, style)
    for _, dy in ipairs({ -h / 2, h / 2 }) do
        box(cf * CFrame.new(0, dy, 0), V(w + thickness, thickness, depth), style)
    end
    for _, dx in ipairs({ -w / 2, w / 2 }) do
        box(cf * CFrame.new(dx, 0, 0), V(thickness, h, depth), style)
    end
end

----------------------------------------------------------------
-- Find the old cashier and which way it faces
----------------------------------------------------------------
local casinoRoot = workspace:FindFirstChild("Casino") or workspace
local previous = casinoRoot:FindFirstChild("LuxuryCashier") or workspace:FindFirstChild("LuxuryCashier")

local cashier = workspace:FindFirstChild("Cashier", true)
if not cashier or not cashier:IsA("Model") then
    cashier = nil
    for _, m in ipairs(workspace:GetDescendants()) do
        if m:IsA("Model") and string.find(string.lower(m.Name), "cashier") and m.Name ~= "LuxuryCashier"
            and not (previous and m:IsDescendantOf(previous)) then
            cashier = m
            break
        end
    end
end
if not cashier then
    error("[Cashier] Couldn't find a model named Cashier.")
end

local front
for _, d in ipairs(cashier:GetDescendants()) do
    if (d:IsA("TextLabel") or d:IsA("TextBox")) and string.find(string.upper(d.Text), "CASHIER") then
        local gui = d:FindFirstAncestorWhichIsA("SurfaceGui")
        local part = gui and (gui.Adornee or gui:FindFirstAncestorWhichIsA("BasePart"))
        if gui and part and part:IsA("BasePart") then
            local cf = part.CFrame
            -- [REX] the Front face points along LookVector, not against it (note 6)
            local normals = {
                [Enum.NormalId.Front] = cf.LookVector, [Enum.NormalId.Back] = -cf.LookVector,
                [Enum.NormalId.Right] = cf.RightVector, [Enum.NormalId.Left] = -cf.RightVector,
            }
            local n = normals[gui.Face]
            if n and flat(n).Magnitude > 0.5 then
                front = flat(n).Unit
                break
            end
        end
    end
end
front = front or flat(-cashier:GetPivot().LookVector).Unit

-- Measure the old cashier in its own direction
local parts, floorY = {}, math.huge
for _, p in ipairs(cashier:GetDescendants()) do
    if p:IsA("BasePart") then
        table.insert(parts, p)
        floorY = math.min(floorY, p.Position.Y - p.Size.Y / 2)
    end
end
local center = flat(cashier:GetPivot().Position)

-- [REX] stand on the casino floor, not the bottom of the old raised slab (note 2)
do
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local ignore = { cashier }
    if previous then
        table.insert(ignore, previous)
    end
    params.FilterDescendantsInstances = ignore
    local hit = workspace:Raycast(V(center.X, floorY + 6, center.Z), V(0, -30, 0), params)
    if hit then
        floorY = hit.Position.Y
    end
end

local T0 = CFrame.lookAt(V(center.X, floorY, center.Z), V(center.X, floorY, center.Z) + front)
local lmn, lmx = V(math.huge, math.huge, math.huge), V(-math.huge, -math.huge, -math.huge)
for _, p in ipairs(parts) do
    local half = p.Size / 2
    for _, sx in ipairs({ -1, 1 }) do
        for _, sy in ipairs({ -1, 1 }) do
            for _, sz in ipairs({ -1, 1 }) do
                local lp = T0:PointToObjectSpace(p.CFrame * V(half.X * sx, half.Y * sy, half.Z * sz))
                lmn, lmx = lmn:Min(lp), lmx:Max(lp)
            end
        end
    end
end
local W = math.clamp(lmx.X - lmn.X, 14, 40)
-- [REX] keep the old depth so the counter stays where the prompt is (note 1)
local D = math.clamp(lmx.Z - lmn.Z, 6, 24)
-- Keep the back where the old back was (against the wall); -Z is the front
local T = T0 * CFrame.new((lmn.X + lmx.X) / 2, 0, lmx.Z)

-- Hide the old look (parts stay in place so prompts and scripts keep working)
for _, d in ipairs(cashier:GetDescendants()) do
    if d:IsA("BasePart") then
        -- [REX] only record the original once (note 4)
        if d:GetAttribute("OldTransparency") == nil then
            d:SetAttribute("OldTransparency", d.Transparency)
            d:SetAttribute("OldCanCollide", d.CanCollide)
        end
        d.Transparency = 1
        d.CanCollide = false
    elseif d:IsA("Decal") or d:IsA("Texture") then
        d.Transparency = 1
    elseif d:IsA("SurfaceGui") then
        d.Enabled = false
    end
end

----------------------------------------------------------------
-- Build the new cashier cage
----------------------------------------------------------------
-- [REX] replace the previous build, in the Casino folder (notes 4, 5)
if previous then
    previous:Destroy()
end
local model = Instance.new("Model")
model.Name = "LuxuryCashier"
model.Parent = casinoRoot
current = model

local function at(x, y, z)
    return T * CFrame.new(x, y, z)
end
local function pos(x, y, z)
    return T * V(x, y, z)
end
local function facingFront(p)
    return CFrame.lookAt(p, p + T:VectorToWorldSpace(V(0, 0, -1)))
end
local function facingBack(p)
    return CFrame.lookAt(p, p + T:VectorToWorldSpace(V(0, 0, 1)))
end

local frontZ = -D
local counterTop = 3.6
local cageZ = frontZ + 1.7
local glassBottom, glassTop = 4.3, 8.5
local wallH = 11.5

-- Back and side walls with gold-framed panels
box(at(0, wallH / 2, -0.2), V(W, wallH, 0.4), MAHOGANY).CanCollide = true
for _, side in ipairs({ -1, 1 }) do
    box(at(side * (W / 2 - 0.2), wallH / 2, frontZ / 2), V(0.4, wallH, D), MAHOGANY).CanCollide = true
    local panelCF = CFrame.lookAt(pos(side * (W / 2 + 0.01), 5.5, frontZ / 2), pos(side * (W / 2 + 1), 5.5, frontZ / 2))
    box(panelCF, V(D - 1.5, 6, 0.05), DARK_WOOD)
    frameBars(panelCF * CFrame.new(0, 0, -0.03), D - 1.5, 6, 0.12, 0.05, GOLD)
end

-- Big clock on the back wall
local clockPos = pos(0, 6.5, -0.45)
makePart({ Shape = Enum.PartType.Cylinder, CFrame = facingFront(clockPos) * CFrame.Angles(0, math.rad(90), 0), Size = V(0.15, 3.2, 3.2) }, GOLD)
makePart({ Shape = Enum.PartType.Cylinder, CFrame = facingFront(clockPos - T:VectorToWorldSpace(V(0, 0, 0.05))) * CFrame.Angles(0, math.rad(90), 0), Size = V(0.1, 2.8, 2.8) }, WHITE)
local clockCF = facingFront(clockPos - T:VectorToWorldSpace(V(0, 0, 0.12)))
for k = 0, 11 do
    local a = k / 12 * math.pi * 2
    box(clockCF * CFrame.new(math.sin(a) * 1.2, math.cos(a) * 1.2, 0) * CFrame.Angles(0, 0, -a), V(0.08, k % 3 == 0 and 0.35 or 0.2, 0.03), BLACK)
end
box(clockCF * CFrame.Angles(0, 0, math.rad(-60)) * CFrame.new(0, 0.4, -0.01), V(0.1, 0.8, 0.03), BLACK)
box(clockCF * CFrame.Angles(0, 0, math.rad(120)) * CFrame.new(0, 0.55, -0.02), V(0.06, 1.1, 0.03), BLACK)
ball((clockCF * CFrame.new(0, 0, -0.03)).Position, 0.15, GOLD)

-- Front counter
box(at(0, 0.2, frontZ + 0.7), V(W, 0.4, 1.45), GRANITE).CanCollide = true
box(at(0, 0.42, frontZ - 0.02), V(W, 0.05, 0.05), GOLD)
box(at(0, (0.4 + counterTop - 0.3) / 2, frontZ + 0.7), V(W, counterTop - 0.7, 1.4), MAHOGANY).CanCollide = true
box(at(0, counterTop - 0.15, frontZ + 1.15), V(W + 0.4, 0.3, 2.9), MARBLE).CanCollide = true
box(at(0, counterTop - 0.32, frontZ - 0.31), V(W + 0.4, 0.07, 0.05), GOLD)

-- Teller windows
local n = math.max(2, math.floor(W / 6))
local ws = W / n
for k = 0, n do
    local x = -W / 2 + k * ws
    box(at(x, (counterTop + 8.8) / 2, cageZ), V(0.5, 8.8 - counterTop, 0.5), GOLD).CanCollide = true
end
for i = 0, n - 1 do
    local x = -W / 2 + (i + 0.5) * ws
    local openW = ws - 0.6

    -- Panel on the front of the counter under each window
    local panelCF = facingFront(pos(x, 1.95, frontZ - 0.01))
    box(panelCF, V(openW - 0.6, 2.2, 0.05), DARK_WOOD)
    frameBars(panelCF * CFrame.new(0, 0, -0.03), openW - 0.6, 2.2, 0.1, 0.05, GOLD)

    -- Glass with brass bars, and the gap for passing cash
    local glassH = glassTop - glassBottom
    box(at(x, glassBottom + glassH / 2, cageZ), V(openW, glassH, 0.08), GLASS).CanCollide = true
    for bx = -openW / 2 + 0.3, openW / 2 - 0.3, 0.4 do
        rod(pos(x + bx, glassBottom, cageZ - 0.1), pos(x + bx, glassTop, cageZ - 0.1), 0.08, BRASS)
    end
    for _, y in ipairs({ glassBottom, glassBottom + glassH * 0.5, glassTop }) do
        rod(pos(x - openW / 2, y, cageZ - 0.12), pos(x + openW / 2, y, cageZ - 0.12), 0.14, BRASS)
    end
    box(at(x, counterTop + 0.04, frontZ + 1.2), V(1.4, 0.08, 1.0), STEEL)
    box(at(x, counterTop + 0.06, frontZ + 1.2), V(1.1, 0.04, 0.75), { Color = Color3.fromRGB(120, 122, 126), Material = Enum.Material.Metal })

    -- Window number and OPEN / CLOSED light
    local open = i % 2 == 0 or n <= 2
    local plaque = box(facingFront(pos(x - 0.6, 9.3, frontZ + 0.85)), V(0.9, 0.7, 0.08), BLACK)
    label(plaque, { { text = tostring(i + 1), y = 0.05, h = 0.9, color = Color3.fromRGB(255, 215, 110), font = Enum.Font.Bodoni } })
    local status = box(facingFront(pos(x + 0.7, 9.3, frontZ + 0.85)), V(1.3, 0.5, 0.08), BLACK)
    label(status, { { text = open and "OPEN" or "CLOSED", y = 0.05, h = 0.9, color = open and Color3.fromRGB(80, 255, 130) or Color3.fromRGB(255, 70, 70) } })
    ball(pos(x + 1.55, 9.3, frontZ + 0.82), 0.25, open and NEON_GREEN or NEON_RED)

    -- Downlight over the window
    local light = box(at(x, 8.75, frontZ + 1.2), V(0.8, 0.06, 0.8), NEON_WARM)
    local spot = Instance.new("SpotLight")
    spot.Face = Enum.NormalId.Bottom
    spot.Color = Color3.fromRGB(255, 225, 170)
    spot.Brightness = 2
    spot.Range = 12
    spot.Angle = 80
    spot.Parent = light

    -- Teller station behind the glass
    local deskZ = cageZ + 0.9
    local screenPos = pos(x - openW * 0.25, counterTop + 0.6, deskZ)
    local screenCF = facingBack(screenPos) * CFrame.Angles(math.rad(-10), 0, 0)
    box(screenCF, V(1.2, 0.85, 0.1), BLACK)
    box(screenCF * CFrame.new(0, 0, -0.06), V(1.05, 0.7, 0.02), NEON_BLUE)
    box(at(x - openW * 0.25, counterTop + 0.08, deskZ + 0.1), V(0.4, 0.16, 0.4), BLACK)
    box(at(x + openW * 0.25, counterTop + 0.3, deskZ), V(0.8, 0.6, 0.7), STEEL)
    box(facingBack(pos(x + openW * 0.25, counterTop + 0.45, deskZ + 0.36)), V(0.5, 0.15, 0.02), NEON_GREEN)
    box(at(x, counterTop + 0.12, deskZ + 0.4), V(1.6, 0.25, 0.9), BLACK)
    for r = -2, 2 do
        makePart({
            Shape = Enum.PartType.Cylinder,
            CFrame = at(x, counterTop + 0.32, deskZ + 0.4 + r * 0.16),
            Size = V(1.4, 0.15, 0.15),
        }, { Color = CHIP_COLORS[(r + 3) % #CHIP_COLORS + 1], Material = Enum.Material.SmoothPlastic })
    end

    -- Teller stool
    local stoolBase = pos(x, 0, deskZ + 1.8)
    local stoolH = counterTop - 1.1
    cylUp(stoolBase + V(0, 0.12, 0), 0.25, 1.8, GOLD)
    cylUp(stoolBase + V(0, stoolH / 2, 0), stoolH - 0.4, 0.3, GOLD)
    -- [REX] plain cushion; the Seat is an upright block facing the window (note 3)
    local cushion = cylUp(stoolBase + V(0, stoolH, 0), 0.45, 1.9, LEATHER)
    cushion.CanCollide = true
    cushion.Name = "Cushion"
    if SITTABLE then
        local seat = Instance.new("Seat")
        seat.Name = "SitPad"
        seat.Anchored = true
        seat.CanCollide = true
        seat.Transparency = 1
        seat.Size = V(1.6, 0.45, 1.6)
        seat.CFrame = facingFront(stoolBase + V(0, stoolH, 0))
        seat.TopSurface = Enum.SurfaceType.Smooth
        seat.BottomSurface = Enum.SurfaceType.Smooth
        seat.Parent = current
    end
    cylUp(stoolBase + V(0, stoolH - 0.25, 0), 0.08, 1.95, GOLD)
end

-- Top sign panel
box(at(0, 10.3, frontZ + 1.4), V(W + 0.6, 3, 1.0), MAHOGANY).CanCollide = true
box(at(0, 8.85, frontZ + 0.88), V(W + 0.6, 0.1, 0.05), GOLD)
box(at(0, 11.75, frontZ + 0.88), V(W + 0.6, 0.1, 0.05), GOLD)
box(at(0, 12.05, frontZ + 1.4), V(W + 1.2, 0.5, 1.5), MAHOGANY)
box(at(0, 12.32, frontZ + 1.4), V(W + 1.3, 0.06, 1.6), GOLD)
local signW = math.min(W * 0.5, 16)
local signCF = facingFront(pos(0, 10.6, frontZ + 0.86))
local sign = box(signCF, V(signW, 1.9, 0.08), BLACK)
label(sign, {
    { text = SIGN_TEXT, y = 0.02, h = 0.66, color = Color3.fromRGB(255, 215, 110), font = Enum.Font.Bodoni },
    { text = SUBTITLE, y = 0.7, h = 0.26, color = Color3.fromRGB(240, 235, 225) },
})
frameBars(signCF * CFrame.new(0, 0, -0.04), signW + 0.1, 2.0, 0.1, 0.05, NEON_GOLD)

-- Dome security cameras
for _, side in ipairs({ -1, 1 }) do
    local p = pos(side * (W / 2 - 0.8), 8.6, frontZ + 1.2)
    cylUp(p + V(0, 0.15, 0), 0.1, 0.9, BLACK)
    ellipsoid(p, V(0.8, 0.5, 0.8), { Color = Color3.fromRGB(30, 30, 35), Material = Enum.Material.Glass, Transparency = 0.2, Reflectance = 0.3 })
end

-- Waiting line in front
if QUEUE_LINE then
    local z0, z1 = frontZ - 1, frontZ - 10
    local runner = box(at(0, 0.02, (z0 + z1) / 2), V(3.4, 0.04, z0 - z1), CARPET)
    runner.CanCollide = false
    for _, side in ipairs({ -1, 1 }) do
        box(at(side * 1.6, 0.045, (z0 + z1) / 2), V(0.15, 0.04, z0 - z1), GOLD)
        local last
        for z = frontZ - 3, frontZ - 9, -2 do
            local base = pos(side * 2.2, 0, z)
            cylUp(base + V(0, 0.08, 0), 0.15, 1, BRASS)
            cylUp(base + V(0, 1.6, 0), 3, 0.22, BRASS)
            ball(base + V(0, 3.2, 0), 0.4, BRASS)
            local top = base + V(0, 2.8, 0)
            if last then
                local mid = (last + top) / 2 - V(0, 0.5, 0)
                rod(last, mid, 0.16, VELVET)
                rod(mid, top, 0.16, VELVET)
            end
            last = top
        end
    end
    local signBase = pos(3.4, 0, frontZ - 9.5)
    cylUp(signBase + V(0, 0.08, 0), 0.15, 1.2, BRASS)
    cylUp(signBase + V(0, 2, 0), 4, 0.15, BRASS)
    local board = box(facingFront(signBase + V(0, 4.4, 0)), V(2, 1.3, 0.1), BLACK)
    label(board, {
        { text = "PLEASE", y = 0.05, h = 0.3, color = Color3.fromRGB(255, 215, 110) },
        { text = "WAIT HERE", y = 0.38, h = 0.35, color = Color3.fromRGB(255, 215, 110) },
        { text = "NEXT WINDOW WILL CALL", y = 0.76, h = 0.18, color = Color3.fromRGB(220, 220, 220) },
    })
    frameBars(facingFront(signBase + V(0, 4.4, 0)) * CFrame.new(0, 0, -0.06), 2, 1.3, 0.08, 0.05, BRASS)
end

-- Ticket kiosk and ATM
if KIOSKS then
    local function kiosk(x, title, accent)
        local base = pos(x, 0, frontZ + 1)
        local cf = facingFront(base)
        box(cf * CFrame.new(0, 3, 0), V(2.6, 6, 2), KIOSK_BODY).CanCollide = true
        box(cf * CFrame.new(0, 0.2, 0), V(2.7, 0.4, 2.1), GRANITE)
        for _, dx in ipairs({ -1.25, 1.25 }) do
            box(cf * CFrame.new(dx, 3.2, -1.02), V(0.1, 5.2, 0.05), accent)
        end
        local screen = box(cf * CFrame.new(0, 4.2, -1.02) * CFrame.Angles(math.rad(-8), 0, 0), V(1.7, 1.3, 0.05), NEON_BLUE)
        box(cf * CFrame.new(0, 3.1, -1.15) * CFrame.Angles(math.rad(-25), 0, 0), V(1.4, 0.1, 0.7), BLACK)
        for r = 0, 2 do
            for c = -1, 1 do
                box(cf * CFrame.new(c * 0.3, 3.15 + r * 0.05, -1.2 - r * 0.15) * CFrame.Angles(math.rad(-25), 0, 0), V(0.22, 0.06, 0.12), STEEL)
            end
        end
        box(cf * CFrame.new(0, 2.3, -1.02), V(1.2, 0.12, 0.05), NEON_GREEN)
        box(cf * CFrame.new(0, 1.6, -1.02), V(1.0, 0.1, 0.05), BLACK)
        local topper = box(cf * CFrame.new(0, 6.5, 0), V(2.8, 1, 2.1), KIOSK_BODY)
        local topperFace = box(cf * CFrame.new(0, 6.5, -1.07), V(2.6, 0.8, 0.04), BLACK)
        label(topperFace, { { text = title, y = 0.1, h = 0.8, color = accent.Color } })
        box(cf * CFrame.new(0, 7.02, 0), V(2.9, 0.05, 2.2), GOLD)
        return screen, topper
    end
    kiosk(-(W / 2 + 2.2), "TICKET REDEMPTION", NEON_GOLD)
    kiosk(W / 2 + 2.2, "ATM", NEON_GREEN)
end

local partCount = 0
for _, d in ipairs(model:GetDescendants()) do
    if d:IsA("BasePart") then
        partCount += 1
    end
end
print(string.format("[Cashier] Built a new cashier cage with %d windows (%d x %d studs, %d parts)", n, W, D, partCount))
