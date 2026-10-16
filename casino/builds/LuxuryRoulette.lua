-- LUXURY ROULETTE TABLES (keeps your game prompts and scripts working)
-- Written by James. Changes are marked [REX]:
--
--   1. THE WHEEL WOULD HAVE STOPPED SPINNING ON SCREEN. TableGames.spinWheel
--      rotates the ORIGINAL parts named Wheel, Pocket, Hub and Ball for the
--      length of the spin. This script hides every original part, so the game
--      would have spun an invisible wheel while the new one sat still - you bet
--      and nothing moves, which is the whole point of roulette. A WheelMirror
--      script is attached to each new table; it copies the original wheel's
--      rotation onto the new rotor and ball, so the game keeps full control and
--      the new wheel is what you actually see turning.
--   2. The wheel was pushed off the end of the table. wheelX was clamped to a
--      minimum of L/2 + R + 0.6, which here is 13.40, but the real wheel sits
--      at 11.00 - set into the table end, as roulette wheels are. The clamp
--      left the new wheel floating 2.4 studs clear of the table. The measured
--      distance is used when there is one.
--   3. The stool seat was built by cylUp(), which turns the part 90 degrees
--      about Z to stand the cylinder up. A Seat orients the sitter by its own
--      CFrame, so players would have sat lying on their side. It is its own
--      upright invisible block now, facing the table.
--   4. OldTransparency was re-recorded on every run. The second run reads the
--      already-hidden value and saves 1 as "the original", so the old look
--      could never be restored. It is only written once now.
--   5. A second run added another <name>_Luxury model beside the first instead
--      of replacing it. The previous build for each table is cleared first.
--   6. Parented into the Casino folder, like the other builds.

-- Settings:
local SITTABLE = true
local PENDANT_LIGHT = true
local CHIP_STACKS = true
local RESULTS_SCREEN = true
local FELT_COLOR = Color3.fromRGB(20, 95, 45)
local LEATHER_COLOR = Color3.fromRGB(140, 15, 25)
local MIN_BET, MAX_BET = "$5", "$5,000"

local V = Vector3.new
local UP = V(0, 1, 0)
local rng = Random.new(7)

----------------------------------------------------------------
-- Materials
----------------------------------------------------------------
local GOLD = { Color = Color3.fromRGB(212, 175, 55), Material = Enum.Material.Metal, Reflectance = 0.35 }
local MAHOGANY = { Color = Color3.fromRGB(75, 30, 22), Material = Enum.Material.Wood }
local DARK_WOOD = { Color = Color3.fromRGB(50, 22, 15), Material = Enum.Material.Wood }
local TRACK_WOOD = { Color = Color3.fromRGB(60, 35, 20), Material = Enum.Material.Wood }
local BLACK = { Color = Color3.fromRGB(20, 20, 22), Material = Enum.Material.SmoothPlastic }
local GRANITE = { Color = Color3.fromRGB(25, 25, 28), Material = Enum.Material.Granite }
local LEATHER = { Color = LEATHER_COLOR, Material = Enum.Material.Leather }
local FELT = { Color = FELT_COLOR, Material = Enum.Material.Fabric }
local POCKET_RED = { Color = Color3.fromRGB(170, 20, 25), Material = Enum.Material.SmoothPlastic }
local POCKET_BLACK = { Color = Color3.fromRGB(20, 20, 22), Material = Enum.Material.SmoothPlastic }
local POCKET_GREEN = { Color = Color3.fromRGB(20, 120, 50), Material = Enum.Material.SmoothPlastic }
local WHITE = { Color = Color3.fromRGB(245, 245, 240), Material = Enum.Material.SmoothPlastic }
local NEON_WARM = { Color = Color3.fromRGB(255, 225, 170), Material = Enum.Material.Neon }
local CRYSTAL = { Color = Color3.fromRGB(230, 240, 255), Material = Enum.Material.Glass, Transparency = 0.3, Reflectance = 0.4 }
local CHIP_COLORS = {
    Color3.fromRGB(200, 30, 30), Color3.fromRGB(30, 80, 200), Color3.fromRGB(30, 150, 60),
    Color3.fromRGB(20, 20, 20), Color3.fromRGB(240, 240, 240), Color3.fromRGB(150, 60, 170), Color3.fromRGB(240, 170, 40),
}

local WHEEL_ORDER = { 0, 32, 15, 19, 4, 21, 2, 25, 17, 34, 6, 27, 13, 36, 11, 30, 8, 23, 10, 5, 24, 16, 33, 1, 20, 14, 31, 9, 22, 18, 29, 7, 28, 12, 35, 3, 26 }
local RED_NUMBERS = {}
for _, n in ipairs({ 1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36 }) do
    RED_NUMBERS[n] = true
end
local function numberColor(n)
    if n == 0 then
        return Color3.fromRGB(20, 120, 50)
    end
    return RED_NUMBERS[n] and Color3.fromRGB(170, 20, 25) or Color3.fromRGB(20, 20, 22)
end

----------------------------------------------------------------
-- Helpers
----------------------------------------------------------------
local current
local function makePart(props, style, className)
    local p = Instance.new(className or "Part")
    p.Anchored = true
    p.CanCollide = false
    p.CanTouch = false
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
local function bounds(part)
    local half = part.Size / 2
    local mn, mx = V(math.huge, math.huge, math.huge), V(-math.huge, -math.huge, -math.huge)
    for _, sx in ipairs({ -1, 1 }) do
        for _, sy in ipairs({ -1, 1 }) do
            for _, sz in ipairs({ -1, 1 }) do
                local c = part.CFrame * V(half.X * sx, half.Y * sy, half.Z * sz)
                mn, mx = mn:Min(c), mx:Max(c)
            end
        end
    end
    return mn, mx
end
local function flat(v)
    return V(v.X, 0, v.Z)
end

local function label(parent, text, pos, size, bg, textColor, rotation)
    local l = Instance.new("TextLabel")
    l.Position = pos
    l.Size = size
    l.BackgroundColor3 = bg or Color3.new(0, 0, 0)
    l.BackgroundTransparency = bg and 0 or 1
    l.BorderSizePixel = 0
    l.Text = text
    l.TextScaled = true
    l.Font = Enum.Font.GothamBold
    l.TextColor3 = textColor or Color3.new(1, 1, 1)
    l.Rotation = rotation or 0
    l.Parent = parent
    local stroke = Instance.new("UIStroke")
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Color = Color3.fromRGB(240, 235, 210)
    stroke.Thickness = 2
    stroke.Parent = l
    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0.15, 0)
    padding.PaddingBottom = UDim.new(0.15, 0)
    padding.PaddingLeft = UDim.new(0.1, 0)
    padding.PaddingRight = UDim.new(0.1, 0)
    padding.Parent = l
    return l
end

----------------------------------------------------------------
-- Luxury stool (base = floor point, -Z faces the table)
----------------------------------------------------------------
local function stool(base, h)
    local function c(localPos, height, width, style, className)
        return cylUp(base * localPos, height, width, style, className)
    end
    c(V(0, 0.12, 0), 0.25, 2.4, GOLD).CanCollide = true
    c(V(0, 0.3, 0), 0.12, 1.8, BLACK)
    c(V(0, (0.35 + h - 1) / 2, 0), h - 1.35, 0.4, GOLD).CanCollide = true
    c(V(0, h - 0.95, 0), 0.15, 1.2, GOLD)
    local ringY, last = h * 0.42, nil
    for i = 0, 8 do
        local a = i / 8 * math.pi * 2
        local point = base * V(math.cos(a), ringY, math.sin(a))
        if last then
            rod(last, point, 0.12, GOLD)
        end
        last = point
    end
    local cushion = c(V(0, h - 0.275, 0), 0.55, 2.5, LEATHER)
    cushion.CanCollide = true
    cushion.Name = "Cushion"
    -- [REX] The seat has to be its own upright part. cylUp() turns the part 90
    -- degrees about Z to stand the cylinder on end, and a Seat places whoever
    -- sits in it using its own orientation, so passing "Seat" to cylUp() sat
    -- the player on their side. This block is square to the stool and its
    -- LookVector points at the table, so the sitter faces the game.
    if SITTABLE then
        local seat = Instance.new("Seat")
        seat.Name = "SitPad"
        seat.Anchored = true
        seat.CanCollide = true
        seat.Transparency = 1
        seat.Size = V(2.1, 0.5, 2.1)
        seat.CFrame = base * CFrame.new(0, h - 0.25, 0)
        seat.TopSurface = Enum.SurfaceType.Smooth
        seat.BottomSurface = Enum.SurfaceType.Smooth
        seat.Parent = current
    end
    c(V(0, h - 0.55, 0), 0.08, 2.56, GOLD)
    c(V(0, h - 0.72, 0), 0.3, 2.3, MAHOGANY)
    for _, offset in ipairs({ V(0, 0, 0), V(0.6, 0, 0), V(-0.6, 0, 0), V(0, 0, 0.6), V(0, 0, -0.6) }) do
        ball(base * (V(0, h + 0.01, 0) + offset), 0.16, GOLD)
    end
    local R, backH, backBottom = 1.15, 2.6, h - 0.2
    local center = base * V(0, backBottom + backH / 2, 0)
    for _, deg in ipairs({ -60, -30, 0, 30, 60 }) do
        local a = math.rad(deg)
        local pos = base * V(math.sin(a) * R, backBottom + backH / 2, math.cos(a) * R)
        box(CFrame.lookAt(pos, V(center.X, pos.Y, center.Z)), V(0.66, backH, 0.38), LEATHER).CanCollide = true
        local shell = base * V(math.sin(a) * (R + 0.24), backBottom + backH / 2, math.cos(a) * (R + 0.24))
        box(CFrame.lookAt(shell, V(center.X, shell.Y, center.Z)), V(0.66, backH + 0.1, 0.12), MAHOGANY)
    end
    for _, y in ipairs({ backBottom + backH, backBottom }) do
        local prev
        for i = 0, 6 do
            local a = math.rad(-75 + 150 * i / 6)
            local point = base * V(math.sin(a) * R, y, math.cos(a) * R)
            if prev then
                rod(prev, point, 0.22, GOLD)
            end
            prev = point
        end
    end
    for _, deg in ipairs({ -30, 0, 30 }) do
        local a = math.rad(deg)
        ball(base * V(math.sin(a) * (R - 0.2), backBottom + backH * 0.55, math.cos(a) * (R - 0.2)), 0.16, GOLD)
    end
    for _, x in ipairs({ -0.5, 0.5 }) do
        rod(base * V(x, h - 0.6, 0.5), base * V(x * 1.1, backBottom + 0.3, R), 0.14, GOLD)
    end
end

----------------------------------------------------------------
-- Betting layout drawn on the felt
----------------------------------------------------------------
local LAYOUT_LEFT, LAYOUT_RIGHT = 0.03, 0.80 -- the dealer area is on the wheel side of the felt
local COL_2TO1 = 0.06
local ZERO_W = 0.06
local GRID_TOP, GRID_BOTTOM, DOZEN_BOTTOM, OUTSIDE_BOTTOM = 0.05, 0.62, 0.78, 0.95

local function cellCenter(n)
    -- returns the felt position (0-1, 0-1) of a number on the layout
    local numbersRight = LAYOUT_RIGHT - ZERO_W
    local numbersLeft = LAYOUT_LEFT + COL_2TO1
    local colW = (numbersRight - numbersLeft) / 12
    if n == 0 then
        return numbersRight + ZERO_W / 2, (GRID_TOP + GRID_BOTTOM) / 2
    end
    local column = math.ceil(n / 3)
    local row = (n - 1) % 3 -- 0 = closest to the players
    local u = numbersRight - (column - 0.5) * colW
    local rowH = (GRID_BOTTOM - GRID_TOP) / 3
    local v = GRID_BOTTOM - (row + 0.5) * rowH
    return u, v
end

local function drawLayout(felt)
    local gui = Instance.new("SurfaceGui")
    gui.Face = Enum.NormalId.Top
    gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    gui.PixelsPerStud = 60
    gui.LightInfluence = 0.6
    gui.Parent = felt

    local numbersRight = LAYOUT_RIGHT - ZERO_W
    local numbersLeft = LAYOUT_LEFT + COL_2TO1
    local colW = (numbersRight - numbersLeft) / 12
    local rowH = (GRID_BOTTOM - GRID_TOP) / 3
    local felt0 = FELT_COLOR

    label(gui, "0", UDim2.fromScale(numbersRight, GRID_TOP), UDim2.fromScale(ZERO_W, GRID_BOTTOM - GRID_TOP), numberColor(0))
    for n = 1, 36 do
        local u, v = cellCenter(n)
        label(gui, tostring(n), UDim2.fromScale(u - colW / 2, v - rowH / 2), UDim2.fromScale(colW, rowH), numberColor(n))
    end
    for row = 0, 2 do
        label(gui, "2 to 1", UDim2.fromScale(LAYOUT_LEFT, GRID_TOP + row * rowH), UDim2.fromScale(COL_2TO1, rowH), felt0)
    end
    local dozens = { "1st 12", "2nd 12", "3rd 12" }
    for i, text in ipairs(dozens) do
        local right = numbersRight - (i - 1) * 4 * colW
        label(gui, text, UDim2.fromScale(right - 4 * colW, GRID_BOTTOM), UDim2.fromScale(4 * colW, DOZEN_BOTTOM - GRID_BOTTOM), felt0)
    end
    local outside = { "1-18", "EVEN", "RED", "BLACK", "ODD", "19-36" }
    for i, text in ipairs(outside) do
        local right = numbersRight - (i - 1) * 2 * colW
        local bg = felt0
        if text == "RED" then
            bg = numberColor(1)
        elseif text == "BLACK" then
            bg = numberColor(2)
        end
        label(gui, text, UDim2.fromScale(right - 2 * colW, DOZEN_BOTTOM), UDim2.fromScale(2 * colW, OUTSIDE_BOTTOM - DOZEN_BOTTOM), bg)
    end
end

----------------------------------------------------------------
-- [REX] Keeps the new wheel turning with the game's own spin
----------------------------------------------------------------
local MIRROR_SOURCE = [[
-- TableGames.spinWheel turns the ORIGINAL parts named Wheel, Pocket, Hub and
-- Ball. Those are hidden now, so without this the game would spin an invisible
-- wheel and the luxury one would never move. Read the original wheel's
-- rotation and apply the same turn to the new rotor and ball, about the new
-- wheel's own centre. The game keeps complete control of the result; this only
-- shows it. Idle frames cost nothing because the CFrame is unchanged.
local RunService = game:GetService("RunService")

local model = script.Parent
local link = model:FindFirstChild("OriginalTable")
local original = link and link.Value
local rotor = model:FindFirstChild("Rotor")
local newBall = model:FindFirstChild("Ball")
local centre = model:GetAttribute("WheelCentre")
if not (original and rotor and centre) then
	return
end

local wheel
for _, d in ipairs(original:GetDescendants()) do
	if d:IsA("BasePart") and d.Name == "Wheel" then
		wheel = d
		break
	end
end
if not wheel then
	return
end

local restWheel = wheel.CFrame.Rotation
local restRotor = rotor:GetPivot()
local restBall = newBall and newBall.CFrame
local seen = wheel.CFrame

RunService.Heartbeat:Connect(function()
	if wheel.CFrame == seen then
		return
	end
	seen = wheel.CFrame
	local turn = wheel.CFrame.Rotation * restWheel:Inverse()
	local about = CFrame.new(centre) * turn * CFrame.new(-centre)
	rotor:PivotTo(about * restRotor)
	if newBall then
		newBall.CFrame = about * restBall
	end
end)
]]

----------------------------------------------------------------
-- Build one roulette table (T = table frame on the floor, +X points to the wheel)
----------------------------------------------------------------
local function buildRoulette(T, L, Wd, ht, wheelX, R)
    local function at(x, y, z)
        return T * CFrame.new(x, y, z)
    end
    local function pos(x, y, z)
        return T * V(x, y, z)
    end

    -- Cabinet with gold-framed panels
    box(at(0, (ht - 0.9) / 2, 0), V(L - 0.6, ht - 0.9, Wd - 0.6), MAHOGANY).CanCollide = true
    box(at(0, 0.25, 0), V(L - 0.4, 0.5, Wd - 0.4), GRANITE)
    box(at(0, 0.52, 0), V(L - 0.35, 0.06, Wd - 0.35), GOLD)
    local panelH = ht - 2.2
    for _, side in ipairs({ -1, 1 }) do
        for _, px in ipairs({ -(L - 2) / 4, (L - 2) / 4 }) do
            local pw = (L - 2) / 2 - 0.8
            local z = side * (Wd / 2 - 0.3)
            box(at(px, 0.9 + panelH / 2, z), V(pw, panelH, 0.06), DARK_WOOD)
            for _, dy in ipairs({ -panelH / 2, panelH / 2 }) do
                box(at(px, 0.9 + panelH / 2 + dy, z + side * 0.04), V(pw, 0.1, 0.05), GOLD)
            end
            for _, dx in ipairs({ -pw / 2, pw / 2 }) do
                box(at(px + dx, 0.9 + panelH / 2, z + side * 0.04), V(0.1, panelH, 0.05), GOLD)
            end
        end
        ball(pos(side * (L / 2 - 0.5), 0.15, Wd / 2 - 0.5), 0.35, GOLD)
        ball(pos(side * (L / 2 - 0.5), 0.15, -(Wd / 2 - 0.5)), 0.35, GOLD)
    end

    -- Table top, felt and padded armrest
    box(at(0, ht - 0.6, 0), V(L, 0.6, Wd), MAHOGANY).CanCollide = true
    local FL, FW = L - 1.6, Wd - 1.6
    local felt = box(at(0, ht - 0.25, 0), V(FL, 0.1, FW), FELT)
    felt.CanCollide = true
    drawLayout(felt)
    for _, side in ipairs({ -1, 1 }) do
        box(at(0, ht - 0.05, side * (Wd / 2 - 0.4)), V(L, 0.55, 0.8), LEATHER).CanCollide = true
        box(at(side * (L / 2 - 0.4), ht - 0.05, 0), V(0.8, 0.55, Wd - 1.6), LEATHER).CanCollide = true
        box(at(0, ht - 0.33, side * (Wd / 2 + 0.02)), V(L + 0.05, 0.08, 0.05), GOLD)
        box(at(side * (L / 2 + 0.02), ht - 0.33, 0), V(0.05, 0.08, Wd + 0.05), GOLD)
    end

    local function feltPoint(u, v)
        return pos(-FL / 2 + u * FL, ht - 0.2, -FW / 2 + v * FW)
    end
    local function chipStack(p, count)
        local color = CHIP_COLORS[rng:NextInteger(1, #CHIP_COLORS)]
        for i = 0, count - 1 do
            cylUp(p + V(0, 0.06 + i * 0.12, 0), 0.11, 0.7, { Color = color, Material = Enum.Material.SmoothPlastic })
        end
        cylUp(p + V(0, count * 0.12 + 0.005, 0), 0.01, 0.45, WHITE)
    end

    -- Chips on random numbers and the gold marker
    if CHIP_STACKS then
        for _ = 1, 6 do
            local u, v = cellCenter(rng:NextInteger(0, 36))
            chipStack(feltPoint(u, v), rng:NextInteger(2, 6))
        end
        local u, v = cellCenter(rng:NextInteger(1, 36))
        local markerBase = feltPoint(u, v)
        cylUp(markerBase + V(0, 0.2, 0), 0.4, 0.5, GOLD)
        ball(markerBase + V(0, 0.6, 0), 0.45, CRYSTAL)

        -- Dealer chip rack
        local rackCenter = feltPoint((LAYOUT_RIGHT + 1) / 2 + 0.01, 0.3)
        box(T.Rotation + rackCenter + V(0, 0.15, 0), V(math.min(FL * 0.16, 3), 0.3, math.min(FW * 0.4, 2.4)), BLACK)
        for i = -1, 1 do
            for j = -1, 1 do
                local offset = T:VectorToWorldSpace(V(i * 0.75, 0, j * 0.6))
                chipStack(rackCenter + offset + V(0, 0.3, 0), rng:NextInteger(4, 8))
            end
        end
    end

    -- Wheel cabinet
    local function wpos(x, y, z)
        return pos(wheelX + x, y, z)
    end
    -- [REX] the mirror script needs to know where to turn the rotor about
    current:SetAttribute("WheelCentre", wpos(0, 0, 0))
    cylUp(wpos(0, (ht - 0.6) / 2, 0), ht - 0.6, 2 * R + 1.2, MAHOGANY).CanCollide = true
    cylUp(wpos(0, 0.15, 0), 0.3, 2 * R + 1.4, GRANITE)
    for _, y in ipairs({ 0.5, ht - 0.8 }) do
        cylUp(wpos(0, y, 0), 0.1, 2 * R + 1.26, GOLD)
    end
    cylUp(wpos(0, ht - 0.25, 0), 0.5, 2 * R + 0.8, MAHOGANY).CanCollide = true
    local center = wpos(0, 0, 0)
    local function ringRods(radius, y, count, thickness, style)
        local last
        for i = 0, count do
            local a = i / count * math.pi * 2
            local p = wpos(math.cos(a) * radius, y, math.sin(a) * radius)
            if last then
                rod(last, p, thickness, style)
            end
            last = p
        end
    end
    ringRods(R + 0.4, ht + 0.01, 28, 0.14, GOLD)
    cylUp(wpos(0, ht - 0.1, 0), 0.3, 2 * R + 0.1, TRACK_WOOD)
    for i = 0, 7 do
        local a = i / 8 * math.pi * 2
        local p = wpos(math.cos(a) * R * 0.88, ht + 0.1, math.sin(a) * R * 0.88)
        box(CFrame.lookAt(p, V(center.X, p.Y, center.Z)) * CFrame.Angles(0, math.rad(45), 0), V(0.25, 0.12, 0.25), GOLD)
    end

    -- Spinning part of the wheel (grouped so the game can spin it later)
    local rotor = Instance.new("Model")
    rotor.Name = "Rotor"
    rotor.Parent = current
    local previous = current
    current = rotor
    local pocketR = R * 0.68
    local pocketDepth = R * 0.32
    for i, n in ipairs(WHEEL_ORDER) do
        local a = (i - 1) / 37 * math.pi * 2
        local p = wpos(math.cos(a) * pocketR, ht + 0.02, math.sin(a) * pocketR)
        local style = n == 0 and POCKET_GREEN or (RED_NUMBERS[n] and POCKET_RED or POCKET_BLACK)
        local pocket = box(CFrame.lookAt(p, V(center.X, p.Y, center.Z)), V(2 * pocketR * math.sin(math.pi / 37) + 0.02, 0.1, pocketDepth), style)
        pocket.Name = "Pocket_" .. n
        local fa = a + math.pi / 37
        local fp = wpos(math.cos(fa) * pocketR, ht + 0.08, math.sin(fa) * pocketR)
        box(CFrame.lookAt(fp, V(center.X, fp.Y, center.Z)), V(0.05, 0.16, pocketDepth), GOLD)
    end
    ringRods(pocketR + pocketDepth / 2, ht + 0.1, 37, 0.1, GOLD)
    ringRods(pocketR - pocketDepth / 2, ht + 0.1, 37, 0.1, GOLD)
    cylUp(wpos(0, ht + 0.05, 0), 0.2, R * 1.04, MAHOGANY)
    ellipsoid(wpos(0, ht + 0.15, 0), V(R * 0.9, 0.4, R * 0.9), GOLD)
    cylUp(wpos(0, ht + 0.6, 0), 0.8, 0.2, GOLD)
    for k = 0, 3 do
        local a = k / 4 * math.pi * 2
        local tip = wpos(math.cos(a) * R * 0.45, ht + 0.85, math.sin(a) * R * 0.45)
        rod(wpos(0, ht + 0.85, 0), tip, 0.1, GOLD)
        ball(tip, 0.18, GOLD)
    end
    ball(wpos(0, ht + 1.05, 0), 0.25, GOLD)
    current = previous

    -- Ball on the track
    local ballAngle = rng:NextNumber(0, math.pi * 2)
    ball(wpos(math.cos(ballAngle) * R * 0.8, ht + 0.15, math.sin(ballAngle) * R * 0.8), 0.28, WHITE).Name = "Ball"

    -- Stools on both long sides (fewer on the dealer side)
    local n = math.max(2, math.floor((L - 1) / 3.4))
    local seatH = math.clamp(ht - 1.1, 2, 3.4)
    for i = 0, n - 1 do
        local x = -L / 2 + (i + 0.5) * L / n
        local p = pos(x, 0, Wd / 2 + 1.7)
        stool(CFrame.lookAt(p, p + T:VectorToWorldSpace(V(0, 0, -1))), seatH)
    end
    for i = 0, n - 2 do
        local x = -L / 2 + (i + 0.5) * (L - 3) / (n - 1)
        local p = pos(x, 0, -(Wd / 2 + 1.7))
        stool(CFrame.lookAt(p, p + T:VectorToWorldSpace(V(0, 0, 1))), seatH)
    end

    -- Hanging lamp over the table
    if PENDANT_LIGHT then
        local y = ht + 9
        box(at(0, y, 0), V(L * 0.75, 0.7, Wd * 0.5), MAHOGANY)
        box(at(0, y - 0.38, 0), V(L * 0.75 + 0.1, 0.08, Wd * 0.5 + 0.1), GOLD)
        local glow = box(at(0, y - 0.4, 0), V(L * 0.7, 0.05, Wd * 0.42), NEON_WARM)
        for _, x in ipairs({ -L * 0.2, L * 0.2 }) do
            local holder = box(at(x, y - 0.42, 0), V(0.2, 0.05, 0.2), NEON_WARM)
            local spot = Instance.new("SpotLight")
            spot.Face = Enum.NormalId.Bottom
            spot.Color = Color3.fromRGB(255, 230, 190)
            spot.Brightness = 2.5
            spot.Range = 16
            spot.Angle = 90
            spot.Shadows = false
            spot.Parent = holder
            rod(pos(x, y + 0.35, 0), pos(x, y + 15, 0), 0.1, GOLD)
        end
        glow.Name = "LampGlow"
    end

    -- Results screen on a gold pole
    if RESULTS_SCREEN then
        local base = pos(L / 2 + 0.3, 0, -(Wd / 2 + 1.3))
        cylUp(base + V(0, 3.6, 0), 7.2, 0.3, GOLD)
        cylUp(base + V(0, 0.1, 0), 0.2, 1.4, GOLD)
        local facing = T:VectorToWorldSpace(V(0, 0, 1))
        local screenPos = base + V(0, 8.6, 0)
        local screen = box(CFrame.lookAt(screenPos, screenPos + facing), V(2.4, 3.6, 0.35), BLACK)
        local frameCF = CFrame.lookAt(screenPos, screenPos + facing)
        for _, dy in ipairs({ -1.85, 1.85 }) do
            box(frameCF * CFrame.new(0, dy, 0), V(2.6, 0.12, 0.45), GOLD)
        end
        for _, dx in ipairs({ -1.25, 1.25 }) do
            box(frameCF * CFrame.new(dx, 0, 0), V(0.12, 3.8, 0.45), GOLD)
        end
        local gui = Instance.new("SurfaceGui")
        gui.Face = Enum.NormalId.Front
        gui.LightInfluence = 0
        gui.Brightness = 1.5
        gui.Parent = screen
        local header = Instance.new("TextLabel")
        header.Size = UDim2.fromScale(1, 0.14)
        header.BackgroundTransparency = 1
        header.Text = "ROULETTE"
        header.TextScaled = true
        header.Font = Enum.Font.Bodoni
        header.TextColor3 = Color3.fromRGB(255, 215, 110)
        header.Parent = gui
        local limits = Instance.new("TextLabel")
        limits.Position = UDim2.fromScale(0, 0.9)
        limits.Size = UDim2.fromScale(1, 0.1)
        limits.BackgroundTransparency = 1
        limits.Text = "MIN " .. MIN_BET .. "   MAX " .. MAX_BET
        limits.TextScaled = true
        limits.Font = Enum.Font.GothamBold
        limits.TextColor3 = Color3.fromRGB(230, 230, 230)
        limits.Parent = gui
        for i = 0, 7 do
            local n = rng:NextInteger(0, 36)
            local result = Instance.new("TextLabel")
            result.Name = "Result" .. (i + 1)
            result.Position = UDim2.fromScale(n == 0 and 0.35 or (RED_NUMBERS[n] and 0.1 or 0.6), 0.15 + i * 0.093)
            result.Size = UDim2.fromScale(0.3, 0.09)
            result.BackgroundTransparency = 1
            result.Text = tostring(n)
            result.TextScaled = true
            result.Font = Enum.Font.GothamBlack
            result.TextColor3 = n == 0 and Color3.fromRGB(60, 220, 100) or (RED_NUMBERS[n] and Color3.fromRGB(255, 60, 60) or Color3.fromRGB(240, 240, 240))
            result.Parent = gui
        end
    end

    -- [REX] keep the new wheel turning with the game's spin
    local mirror = Instance.new("Script")
    mirror.Name = "WheelMirror"
    mirror.Source = MIRROR_SOURCE
    mirror.Parent = current
end

----------------------------------------------------------------
-- Find each roulette table, hide the old look, build the new one
----------------------------------------------------------------
local casinoRoot = workspace:FindFirstChild("Casino") or workspace
local newFolder = workspace:FindFirstChild("LuxuryRoulette", true) or Instance.new("Folder")
newFolder.Name = "LuxuryRoulette"
newFolder.Parent = casinoRoot

local function isRoulette(inst)
    if not inst:IsA("Model") or not string.find(string.lower(inst.Name), "roulette") then
        return false
    end
    if inst:IsDescendantOf(newFolder) then
        return false
    end
    -- [REX] GetDescendants() is a snapshot, and the previous build for a table
    -- is destroyed while we are still walking it. A destroyed model is no
    -- longer a descendant of anything, so it slipped past the check above and
    -- warned about a table top it never had.
    if not inst:IsDescendantOf(game) then
        return false
    end
    -- [REX] the chairs script names its models <table>_Chairs, so
    -- RouletteTable_Chairs matched here and warned about a table top it was
    -- never going to have
    local lux = casinoRoot:FindFirstChild("LuxuryChairs")
    if lux and inst:IsDescendantOf(lux) then
        return false
    end
    return true
end

local count = 0
for _, model in ipairs(workspace:GetDescendants()) do
    if isRoulette(model) and not (model.Parent and model.Parent:FindFirstAncestorWhichIsA("Model") and isRoulette(model.Parent)) then
        local infos, floorY = {}, math.huge
        for _, p in ipairs(model:GetDescendants()) do
            if p:IsA("BasePart") then
                local mn, mx = bounds(p)
                table.insert(infos, { part = p, mn = mn, mx = mx })
                floorY = math.min(floorY, mn.Y)
            end
        end

        -- The betting table is the longest flat-topped piece at table height
        local top, bestLong = nil, 0
        for _, info in ipairs(infos) do
            local height = info.mx.Y - floorY
            local s = info.part.Size
            local long, short = math.max(s.X, s.Z), math.min(s.X, s.Z)
            if height >= 2 and height <= 5 and long / math.max(short, 0.1) >= 1.3 and long > bestLong then
                top, bestLong = info, long
            end
        end

        if not top then
            warn("[Roulette] Couldn't find the table top in " .. model:GetFullName())
        else
            local part = top.part
            local L = math.max(part.Size.X, part.Size.Z)
            local Wd = math.clamp(math.min(part.Size.X, part.Size.Z), 4.5, 9)
            L = math.max(L, 8)
            local longAxis = flat(part.Size.X >= part.Size.Z and part.CFrame.RightVector or part.CFrame.LookVector).Unit
            local tableCenter = flat(part.Position)
            local ht = math.clamp(top.mx.Y - floorY, 3, 4.5)

            -- The wheel is whatever sits past the end of the table
            local sum, num, wheelDiameter = V(0, 0, 0), 0, 0
            for _, info in ipairs(infos) do
                local c = flat((info.mn + info.mx) / 2)
                local along = (c - tableCenter):Dot(longAxis)
                if math.abs(along) > L / 2 + 0.5 then
                    sum += c
                    num += 1
                    wheelDiameter = math.max(wheelDiameter, info.mx.X - info.mn.X, info.mx.Z - info.mn.Z)
                end
            end
            local sign, wheelDistance = 1, nil
            if num > 0 then
                local along = (sum / num - tableCenter):Dot(longAxis)
                sign = along >= 0 and 1 or -1
                wheelDistance = math.abs(along)
            end
            local R = math.clamp((wheelDiameter > 0 and wheelDiameter or Wd * 1.1) / 2, 2.6, 4.5)
            -- [REX] Use the distance we measured. The old clamp forced a minimum
            -- of L/2 + R + 0.6 (13.40 here) when the real wheel sits at 11.00,
            -- set into the end of the table the way a roulette wheel is, which
            -- left the new wheel floating clear of the table it belongs to.
            local wheelX = wheelDistance or (L / 2 + R + 0.6)
            wheelX = math.clamp(wheelX, L / 2 - R * 0.2, L / 2 + R + 3)

            local xAxis = longAxis * sign
            local T = CFrame.fromMatrix(V(tableCenter.X, floorY, tableCenter.Z), xAxis, UP)

            -- [REX] drop the previous build for this table, so a second run
            -- replaces it instead of stacking another one on top
            for _, old in ipairs(newFolder:GetChildren()) do
                local link = old:FindFirstChild("OriginalTable")
                if link and link.Value == model then
                    old:Destroy()
                end
            end

            -- Remove luxury chairs another script put at this table
            local lux = casinoRoot:FindFirstChild("LuxuryChairs") or workspace:FindFirstChild("LuxuryChairs", true)
            if lux then
                for _, chairs in ipairs(lux:GetChildren()) do
                    local lp = T:PointToObjectSpace(chairs:GetPivot().Position)
                    if math.abs(lp.X) < L / 2 + 2 * R + 6 and math.abs(lp.Z) < Wd / 2 + 6 then
                        chairs:Destroy()
                    end
                end
            end

            -- Hide the old look (parts stay in place so prompts and scripts keep working)
            for _, d in ipairs(model:GetDescendants()) do
                if d:IsA("BasePart") then
                    -- [REX] only record the original once. Re-running read back
                    -- the already-hidden 1 and saved that as "the original",
                    -- which made the old look impossible to restore.
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

            current = Instance.new("Model")
            current.Name = model.Name .. "_Luxury"
            local link = Instance.new("ObjectValue")
            link.Name = "OriginalTable"
            link.Value = model
            link.Parent = current
            current.Parent = newFolder
            buildRoulette(T, L, Wd, ht, wheelX, R)
            count += 1
        end
    end
end

local parts = 0
for _, d in ipairs(newFolder:GetDescendants()) do
    if d:IsA("BasePart") then
        parts = parts + 1
    end
end
print(string.format("[Roulette] Upgraded %d roulette table(s) | %d parts", count, parts))
