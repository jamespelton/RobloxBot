-- LUXURY CRAPS TABLE (keeps your game prompts and scripts working)
-- Written by James. Changes are marked [REX]:
--
--   1. The backslash-n line breaks inside the layout labels (the upright
--      PASS and the HARD 6 / 9 to 1 boxes) are turned into real line breaks
--      when the script is pasted through the Studio bridge, which splits the
--      string and stops the script compiling. Line breaks are built from
--      NL = string.char(10) instead.
--   2. The boxman's seat was built by cylUp(), which turns the part 90 degrees
--      about Z to stand the cylinder up. A Seat places whoever sits in it
--      using its own orientation, so he would have sat lying on his side.
--      The cushion is a plain part and the Seat is its own upright block
--      facing the table, as on the roulette and poker stools.
--   3. LuxuryChairs is in Workspace.Casino, not the Workspace root, so the
--      chair cleanup found nothing. It also matched against each chair set's
--      pivot, and CrapsTable_Chairs has its pivot at the world origin rather
--      than at its chairs; the real centre of the set is used now.
--   4. CrapsTable_Chairs contains "craps", so the chairs model was treated as
--      a craps table. Tables are only looked for outside LuxuryChairs, and
--      models destroyed during the walk are skipped.
--   5. A second run built another table on top of the first, and re-recorded
--      OldTransparency as 1 so the old look could never be restored. The
--      previous build is cleared first and the original is recorded once.
--   6. The place numbers on the right-hand end read 10 NINE 8 SIX 5 4.
--      `mirror and i or i` was meant to flip them back but picks i either
--      way. A real layout reads 4 5 SIX 8 NINE 10 on both ends.
--   7. The chip ledges sat exactly flush with the top of the tub walls, so
--      the two surfaces flickered against each other. Raised 0.02.
--   8. The lamp rods stopped 15 studs up in mid-air under a 44-stud ceiling;
--      they now reach whatever is above the table.
--   9. Parented into the Casino folder, like the other builds.
--  10. Dropped a 0.01-stud cylinder at the end of the dealer's stick; it was
--      too small to see and did nothing.

-- Settings:
local PENDANT_LIGHT = true
local CHIPS_AND_DICE = true
local TABLE_SIGN = true
local BOXMAN_SEAT = true
local FELT_COLOR = Color3.fromRGB(20, 95, 45)
local LEATHER_COLOR = Color3.fromRGB(140, 15, 25)
local MIN_BET, MAX_BET = "$10", "$5,000"

local V = Vector3.new
local UP = V(0, 1, 0)
local NL = string.char(10) -- [REX] see note 1
local rng = Random.new(21)

----------------------------------------------------------------
-- Materials
----------------------------------------------------------------
local GOLD = { Color = Color3.fromRGB(212, 175, 55), Material = Enum.Material.Metal, Reflectance = 0.35 }
local MAHOGANY = { Color = Color3.fromRGB(75, 30, 22), Material = Enum.Material.Wood }
local DARK_WOOD = { Color = Color3.fromRGB(50, 22, 15), Material = Enum.Material.Wood }
local BLACK = { Color = Color3.fromRGB(20, 20, 22), Material = Enum.Material.SmoothPlastic }
local RUBBER = { Color = Color3.fromRGB(28, 28, 30), Material = Enum.Material.Rubber }
local GRANITE = { Color = Color3.fromRGB(25, 25, 28), Material = Enum.Material.Granite }
local LEATHER = { Color = LEATHER_COLOR, Material = Enum.Material.Leather }
local FELT = { Color = FELT_COLOR, Material = Enum.Material.Fabric }
local MIRROR = { Color = Color3.fromRGB(200, 205, 215), Material = Enum.Material.Glass, Reflectance = 0.7 }
local WHITE = { Color = Color3.fromRGB(245, 245, 240), Material = Enum.Material.SmoothPlastic }
local DICE_RED = { Color = Color3.fromRGB(200, 20, 25), Material = Enum.Material.Glass, Transparency = 0.15, Reflectance = 0.2 }
local NEON_WARM = { Color = Color3.fromRGB(255, 225, 170), Material = Enum.Material.Neon }
local STICK_WOOD = { Color = Color3.fromRGB(150, 105, 60), Material = Enum.Material.Wood }
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

local function label(parent, text, u0, u1, v0, v1, bg, textColor)
    local l = Instance.new("TextLabel")
    l.Position = UDim2.fromScale(u0, v0)
    l.Size = UDim2.fromScale(u1 - u0, v1 - v0)
    l.BackgroundColor3 = bg or Color3.new(0, 0, 0)
    l.BackgroundTransparency = bg and 0 or 1
    l.BorderSizePixel = 0
    l.Text = text
    l.TextScaled = true
    l.Font = Enum.Font.GothamBold
    l.TextColor3 = textColor or Color3.new(1, 1, 1)
    l.Parent = parent
    local stroke = Instance.new("UIStroke")
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Color = Color3.fromRGB(240, 235, 210)
    stroke.Thickness = 2
    stroke.Parent = l
    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0.15, 0)
    padding.PaddingBottom = UDim.new(0.15, 0)
    padding.PaddingLeft = UDim.new(0.06, 0)
    padding.PaddingRight = UDim.new(0.06, 0)
    padding.Parent = l
    return l
end

local function chipStack(p, count)
    local color = CHIP_COLORS[rng:NextInteger(1, #CHIP_COLORS)]
    for i = 0, count - 1 do
        cylUp(p + V(0, 0.06 + i * 0.12, 0), 0.11, 0.7, { Color = color, Material = Enum.Material.SmoothPlastic })
    end
    cylUp(p + V(0, count * 0.12 + 0.005, 0), 0.01, 0.45, WHITE)
end

----------------------------------------------------------------
-- Luxury stool for the boxman (base = floor point, -Z faces the table)
----------------------------------------------------------------
local function stool(base, h)
    local function c(localPos, height, width, style, className)
        return cylUp(base * localPos, height, width, style, className)
    end
    c(V(0, 0.12, 0), 0.25, 2.4, GOLD).CanCollide = true
    c(V(0, (0.35 + h - 1) / 2, 0), h - 1.35, 0.4, GOLD).CanCollide = true
    -- [REX] plain cushion; the Seat is the upright block below (note 2)
    local cushion = c(V(0, h - 0.275, 0), 0.55, 2.5, LEATHER)
    cushion.CanCollide = true
    cushion.Name = "Cushion"
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
    c(V(0, h - 0.55, 0), 0.08, 2.56, GOLD)
    c(V(0, h - 0.72, 0), 0.3, 2.3, MAHOGANY)
    local ringY, last = h * 0.42, nil
    for i = 0, 8 do
        local a = i / 8 * math.pi * 2
        local point = base * V(math.cos(a), ringY, math.sin(a))
        if last then
            rod(last, point, 0.12, GOLD)
        end
        last = point
    end
    local R, backH, backBottom = 1.15, 2.6, h - 0.2
    local center = base * V(0, backBottom + backH / 2, 0)
    for _, deg in ipairs({ -60, -30, 0, 30, 60 }) do
        local a = math.rad(deg)
        local pos = base * V(math.sin(a) * R, backBottom + backH / 2, math.cos(a) * R)
        box(CFrame.lookAt(pos, V(center.X, pos.Y, center.Z)), V(0.66, backH, 0.38), LEATHER).CanCollide = true
    end
    local prev
    for i = 0, 6 do
        local a = math.rad(-75 + 150 * i / 6)
        local point = base * V(math.sin(a) * R, backBottom + backH, math.cos(a) * R)
        if prev then
            rod(prev, point, 0.22, GOLD)
        end
        prev = point
    end
end

----------------------------------------------------------------
-- Craps layout drawn on the felt (left half is mirrored on the right)
----------------------------------------------------------------
local function drawLayout(felt)
    local gui = Instance.new("SurfaceGui")
    gui.Face = Enum.NormalId.Top
    gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    gui.PixelsPerStud = 60
    gui.LightInfluence = 0.6
    gui.Parent = felt

    local yellow = Color3.fromRGB(255, 215, 80)
    local red = Color3.fromRGB(190, 25, 30)
    for _, mirror in ipairs({ false, true }) do
        local function area(text, u0, u1, v0, v1, bg, textColor)
            if mirror then
                u0, u1 = 1 - u1, 1 - u0
            end
            label(gui, text, u0, u1, v0, v1, bg, textColor)
        end
        area("DON'T COME", 0.03, 0.085, 0.05, 0.25)
        local places = { "4", "5", "SIX", "8", "NINE", "10" }
        local w = (0.36 - 0.085) / 6
        for i, text in ipairs(places) do
            -- [REX] flip the order on the mirrored end so both read 4 to 10
            local index = mirror and (#places + 1 - i) or i
            area(text, 0.085 + (index - 1) * w, 0.085 + index * w, 0.05, 0.25)
        end
        area("COME", 0.1, 0.36, 0.25, 0.45)
        area("FIELD   2 · 3 · 4 · 9 · 10 · 11 · 12", 0.1, 0.36, 0.45, 0.62, nil, yellow)
        area("DON'T PASS BAR", 0.1, 0.36, 0.62, 0.72)
        area("PASS LINE", 0.03, 0.36, 0.72, 0.88)
        area("P" .. NL .. "A" .. NL .. "S" .. NL .. "S", 0.03, 0.1, 0.25, 0.72)
        area("BIG 6  8", 0.03, 0.12, 0.88, 0.96, red)
    end

    -- Center: one-roll and hard way bets
    label(gui, "SEVEN   4 TO 1", 0.38, 0.62, 0.08, 0.18, nil, Color3.fromRGB(255, 80, 80))
    label(gui, "HARD 6" .. NL .. "9 to 1", 0.38, 0.5, 0.18, 0.34)
    label(gui, "HARD 10" .. NL .. "7 to 1", 0.5, 0.62, 0.18, 0.34)
    label(gui, "HARD 8" .. NL .. "9 to 1", 0.38, 0.5, 0.34, 0.5)
    label(gui, "HARD 4" .. NL .. "7 to 1", 0.5, 0.62, 0.34, 0.5)
    label(gui, "ANY CRAPS   7 TO 1", 0.38, 0.62, 0.5, 0.6, nil, Color3.fromRGB(255, 80, 80))
    label(gui, "2" .. NL .. "30:1", 0.38, 0.44, 0.6, 0.74)
    label(gui, "3" .. NL .. "15:1", 0.44, 0.5, 0.6, 0.74)
    label(gui, "11" .. NL .. "15:1", 0.5, 0.56, 0.6, 0.74)
    label(gui, "12" .. NL .. "30:1", 0.56, 0.62, 0.6, 0.74)
end

----------------------------------------------------------------
-- Dice
----------------------------------------------------------------
local PIPS = {
    { { 0, 0 } },
    { { -1, -1 }, { 1, 1 } },
    { { -1, -1 }, { 0, 0 }, { 1, 1 } },
    { { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 } },
    { { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 }, { 0, 0 } },
    { { -1, -1 }, { -1, 0 }, { -1, 1 }, { 1, -1 }, { 1, 0 }, { 1, 1 } },
}
local function die(cf, topValue, frontValue)
    box(cf, V(0.6, 0.6, 0.6), DICE_RED)
    for _, p in ipairs(PIPS[topValue]) do
        ball((cf * CFrame.new(p[1] * 0.17, 0.3, p[2] * 0.17)).Position, 0.11, WHITE)
    end
    for _, p in ipairs(PIPS[frontValue]) do
        ball((cf * CFrame.new(p[1] * 0.17, p[2] * 0.17, -0.3)).Position, 0.11, WHITE)
    end
end

-- [REX] how far up the pendant rods have to reach
local ceilingRay = RaycastParams.new()
ceilingRay.FilterType = Enum.RaycastFilterType.Exclude
local ignoreForCeiling = {}
local function ceilingAbove(p)
    ceilingRay.FilterDescendantsInstances = ignoreForCeiling
    local hit = workspace:Raycast(p, V(0, 120, 0), ceilingRay)
    return hit and hit.Position.Y or nil
end

----------------------------------------------------------------
-- Build one craps table (T = floor frame at the table center, X = long direction)
----------------------------------------------------------------
local function buildCraps(T, L, W, ht)
    local function at(x, y, z)
        return T * CFrame.new(x, y, z)
    end
    local function pos(x, y, z)
        return T * V(x, y, z)
    end
    local wall = 1.4
    local floorTop = ht - 1.0

    -- Cabinet with gold-framed panels
    box(at(0, (ht - 1.2) / 2, 0), V(L - 0.6, ht - 1.2, W - 0.6), MAHOGANY).CanCollide = true
    box(at(0, 0.25, 0), V(L - 0.4, 0.5, W - 0.4), GRANITE)
    box(at(0, 0.52, 0), V(L - 0.35, 0.06, W - 0.35), GOLD)
    local panelH = ht - 2.4
    for _, side in ipairs({ -1, 1 }) do
        for k = -1, 1 do
            local pw = (L - 2) / 3 - 0.8
            local px = k * (L - 2) / 3
            local z = side * (W / 2 - 0.3)
            box(at(px, 0.9 + panelH / 2, z), V(pw, panelH, 0.06), DARK_WOOD)
            for _, dy in ipairs({ -panelH / 2, panelH / 2 }) do
                box(at(px, 0.9 + panelH / 2 + dy, z + side * 0.04), V(pw, 0.1, 0.05), GOLD)
            end
            for _, dx in ipairs({ -pw / 2, pw / 2 }) do
                box(at(px + dx, 0.9 + panelH / 2, z + side * 0.04), V(0.1, panelH, 0.05), GOLD)
            end
        end
    end

    -- Tub walls and sunken felt
    box(at(0, floorTop - 0.1, 0), V(L - 0.2, 0.2, W - 0.2), MAHOGANY).CanCollide = true
    local felt = box(at(0, floorTop + 0.05, 0), V(L - 2 * wall, 0.1, W - 2 * wall), FELT)
    felt.CanCollide = true
    drawLayout(felt)
    for _, side in ipairs({ -1, 1 }) do
        box(at(0, (floorTop + ht) / 2 - 0.1, side * (W / 2 - wall / 2)), V(L, ht - floorTop + 0.2, wall), MAHOGANY).CanCollide = true
        box(at(side * (L / 2 - wall / 2), (floorTop + ht) / 2 - 0.1, 0), V(wall, ht - floorTop + 0.2, W - 2 * wall), MAHOGANY).CanCollide = true
        -- Mirror strip along the inside of the long walls
        box(at(0, ht - 0.35, side * (W / 2 - wall - 0.03)), V(L - 2 * wall - 0.2, 0.4, 0.05), MIRROR)
        -- Diamond rubber bumpers on the end walls
        local x = side * (L / 2 - wall - 0.12)
        for y = floorTop + 0.3, ht - 0.25, 0.32 do
            for z = -(W / 2 - wall - 0.3), W / 2 - wall - 0.3, 0.45 do
                box(at(x, y, z) * CFrame.Angles(math.rad(45), 0, 0), V(0.25, 0.3, 0.3), RUBBER)
            end
        end
    end

    -- Padded rail with rounded corners
    local hx, hz, rc = L / 2 - 0.45, W / 2 - 0.45, 0.8
    local railPoints = {}
    local corners = { { hx - rc, hz - rc, 0 }, { -(hx - rc), hz - rc, 90 }, { -(hx - rc), -(hz - rc), 180 }, { hx - rc, -(hz - rc), 270 } }
    for _, corner in ipairs(corners) do
        for i = 0, 4 do
            local a = math.rad(corner[3] + i * 90 / 4)
            table.insert(railPoints, V(corner[1] + math.cos(a) * rc, 0, corner[2] + math.sin(a) * rc))
        end
    end
    table.insert(railPoints, railPoints[1])
    for i = 1, #railPoints - 1 do
        local p1, p2 = railPoints[i], railPoints[i + 1]
        rod(pos(p1.X, ht + 0.15, p1.Z), pos(p2.X, ht + 0.15, p2.Z), 0.9, LEATHER)
        rod(pos(p1.X, ht - 0.3, p1.Z), pos(p2.X, ht - 0.3, p2.Z), 0.1, GOLD)
    end

    -- Chip ledge just inside the rail, with grooves
    -- [REX] raised 0.02 so it no longer sits flush with the wall top (note 7)
    for _, side in ipairs({ -1, 1 }) do
        box(at(0, ht - 0.03, side * (W / 2 - 1.15)), V(L - 1.8, 0.1, 0.5), DARK_WOOD)
        for g = -1, 1, 2 do
            box(at(0, ht + 0.025, side * (W / 2 - 1.15) + g * 0.12), V(L - 1.8, 0.01, 0.05), BLACK)
        end
        box(at(side * (L / 2 - 1.15), ht - 0.03, 0), V(0.5, 0.1, W - 1.8), DARK_WOOD)
    end

    -- Drink rail around the outside
    for _, side in ipairs({ -1, 1 }) do
        box(at(0, ht - 0.55, side * (W / 2 + 0.3)), V(L + 0.8, 0.15, 0.6), MAHOGANY)
        box(at(side * (L / 2 + 0.3), ht - 0.55, 0), V(0.6, 0.15, W + 0.8), MAHOGANY)
        box(at(0, ht - 0.47, side * (W / 2 + 0.6)), V(L + 0.8, 0.05, 0.05), GOLD)
        box(at(side * (L / 2 + 0.6), ht - 0.47, 0), V(0.05, 0.05, W + 0.8), GOLD)
    end

    -- Felt helpers: turn a layout spot (0-1, 0-1) into a position on the felt
    local FL, FW = L - 2 * wall, W - 2 * wall
    local function feltPoint(u, v)
        return pos(-FL / 2 + u * FL, floorTop + 0.1, -FW / 2 + v * FW)
    end

    if CHIPS_AND_DICE then
        -- Chips on bets (both ends)
        local spots = { { 0.2, 0.8 }, { 0.15, 0.15 }, { 0.27, 0.15 }, { 0.22, 0.35 }, { 0.25, 0.54 } }
        for _, s in ipairs(spots) do
            if rng:NextNumber() < 0.75 then
                chipStack(feltPoint(s[1], s[2]), rng:NextInteger(2, 6))
            end
            if rng:NextNumber() < 0.75 then
                chipStack(feltPoint(1 - s[1], s[2]), rng:NextInteger(2, 6))
            end
        end
        chipStack(feltPoint(0.44, 0.26), 3)
        chipStack(feltPoint(0.56, 0.42), 2)

        -- Dealer chip bank in the middle of the -Z side
        box(at(0, floorTop + 0.2, -(FW / 2 - 0.7)), V(FL * 0.18, 0.3, 1.1), BLACK)
        for i = -3, 3 do
            makePart({
                Shape = Enum.PartType.Cylinder,
                CFrame = at(i * 0.38, floorTop + 0.48, -(FW / 2 - 0.7)),
                Size = V(1.0, 0.34, 0.34),
            }, { Color = CHIP_COLORS[(i + 4) % #CHIP_COLORS + 1], Material = Enum.Material.SmoothPlastic })
        end

        -- Dice resting on the felt
        local d1 = feltPoint(0.63, 0.66)
        local d2 = feltPoint(0.67, 0.6)
        die(CFrame.new(d1 + V(0, 0.3, 0)) * T.Rotation * CFrame.Angles(0, math.rad(rng:NextNumber(0, 90)), 0), rng:NextInteger(1, 6), rng:NextInteger(1, 6))
        die(CFrame.new(d2 + V(0, 0.3, 0)) * T.Rotation * CFrame.Angles(0, math.rad(rng:NextNumber(0, 90)), 0), rng:NextInteger(1, 6), rng:NextInteger(1, 6))

        -- ON/OFF marker
        local puckPos = feltPoint(0.055, 0.15)
        cylUp(puckPos + V(0, 0.08, 0), 0.15, 0.9, BLACK)
        local puckTop = cylUp(puckPos + V(0, 0.17, 0), 0.03, 0.8, WHITE)
        local gui = Instance.new("SurfaceGui")
        gui.Face = Enum.NormalId.Right
        gui.Parent = puckTop
        local text = Instance.new("TextLabel")
        text.Size = UDim2.fromScale(1, 1)
        text.BackgroundTransparency = 1
        text.Text = "OFF"
        text.TextScaled = true
        text.Font = Enum.Font.GothamBlack
        text.TextColor3 = Color3.fromRGB(20, 20, 20)
        text.Parent = gui

        -- Dealer's stick resting on the rail
        local s1, s2 = pos(-L * 0.25, ht + 0.7, W / 2 - 0.45), pos(L * 0.15, ht + 0.7, W / 2 - 0.45)
        rod(s1, s2, 0.12, STICK_WOOD)
        local hookDir = T:VectorToWorldSpace(V(0.4, 0, -0.6)).Unit
        rod(s2, s2 + hookDir * 0.7, 0.12, STICK_WOOD)
    end

    -- Boxman's seat in the middle of the -Z side
    if BOXMAN_SEAT then
        local p = pos(0, 0, -(W / 2 + 2))
        stool(CFrame.lookAt(p, p + T:VectorToWorldSpace(V(0, 0, 1))), math.clamp(ht - 0.8, 2.2, 3.4))
    end

    -- Hanging lamp
    if PENDANT_LIGHT then
        local y = ht + 9
        box(at(0, y, 0), V(L * 0.7, 0.7, W * 0.45), MAHOGANY)
        box(at(0, y - 0.38, 0), V(L * 0.7 + 0.1, 0.08, W * 0.45 + 0.1), GOLD)
        box(at(0, y - 0.4, 0), V(L * 0.65, 0.05, W * 0.38), NEON_WARM)
        for _, x in ipairs({ -L * 0.22, 0, L * 0.22 }) do
            local holder = box(at(x, y - 0.42, 0), V(0.2, 0.05, 0.2), NEON_WARM)
            local spot = Instance.new("SpotLight")
            spot.Face = Enum.NormalId.Bottom
            spot.Color = Color3.fromRGB(255, 230, 190)
            spot.Brightness = 2.5
            spot.Range = 18
            spot.Angle = 90
            spot.Parent = holder
        end
        for _, x in ipairs({ -L * 0.3, L * 0.3 }) do
            -- [REX] hang from the ceiling rather than stopping 15 studs up
            local start = pos(x, y + 0.35, 0)
            local ceiling = ceilingAbove(start + V(0, 0.5, 0))
            local topY = ceiling and math.min(ceiling, start.Y + 80) or start.Y + 15
            rod(start, V(start.X, topY, start.Z), 0.1, GOLD)
        end
    end

    -- Sign with limits and last rolls
    if TABLE_SIGN then
        local base = pos(L / 2 + 1, 0, -(W / 2 + 1))
        cylUp(base + V(0, 3.6, 0), 7.2, 0.3, GOLD)
        cylUp(base + V(0, 0.1, 0), 0.2, 1.4, GOLD)
        local facing = T:VectorToWorldSpace(V(0, 0, 1))
        local screenPos = base + V(0, 8.6, 0)
        local frameCF = CFrame.lookAt(screenPos, screenPos + facing)
        local screen = box(frameCF, V(2.6, 3.6, 0.35), BLACK)
        for _, dy in ipairs({ -1.85, 1.85 }) do
            box(frameCF * CFrame.new(0, dy, 0), V(2.8, 0.12, 0.45), GOLD)
        end
        for _, dx in ipairs({ -1.35, 1.35 }) do
            box(frameCF * CFrame.new(dx, 0, 0), V(0.12, 3.8, 0.45), GOLD)
        end
        local gui = Instance.new("SurfaceGui")
        gui.Face = Enum.NormalId.Front
        gui.LightInfluence = 0
        gui.Brightness = 1.5
        gui.Parent = screen
        local function line(text, y, h, color, font)
            local l = Instance.new("TextLabel")
            l.Position = UDim2.fromScale(0, y)
            l.Size = UDim2.fromScale(1, h)
            l.BackgroundTransparency = 1
            l.Text = text
            l.TextScaled = true
            l.Font = font or Enum.Font.GothamBold
            l.TextColor3 = color
            l.Parent = gui
            return l
        end
        line("CRAPS", 0.02, 0.16, Color3.fromRGB(255, 215, 110), Enum.Font.Bodoni)
        line("MIN " .. MIN_BET .. "   MAX " .. MAX_BET, 0.19, 0.09, Color3.fromRGB(230, 230, 230))
        line("LAST ROLLS", 0.32, 0.08, Color3.fromRGB(200, 200, 200))
        for i = 0, 5 do
            local roll = rng:NextInteger(1, 6) + rng:NextInteger(1, 6)
            local color = roll == 7 and Color3.fromRGB(255, 70, 70) or Color3.fromRGB(240, 240, 240)
            line(tostring(roll), 0.41 + i * 0.095, 0.09, color, Enum.Font.GothamBlack).Name = "Roll" .. (i + 1)
        end
    end
end

----------------------------------------------------------------
-- Find each craps table, hide the old look, build the new one
----------------------------------------------------------------
-- [REX] parented in the Casino folder like the other builds
local casinoRoot = workspace:FindFirstChild("Casino") or workspace
local newFolder = workspace:FindFirstChild("LuxuryCraps", true) or Instance.new("Folder")
newFolder.Name = "LuxuryCraps"
newFolder.Parent = casinoRoot
local luxChairs = casinoRoot:FindFirstChild("LuxuryChairs") or workspace:FindFirstChild("LuxuryChairs", true)

local function isCraps(inst)
    if not inst:IsA("Model") or not string.find(string.lower(inst.Name), "craps") then
        return false
    end
    if inst:IsDescendantOf(newFolder) then
        return false
    end
    -- [REX] skip models destroyed while we walk the snapshot (note 4)
    if not inst:IsDescendantOf(game) then
        return false
    end
    -- [REX] CrapsTable_Chairs is a set of chairs, not a table (note 4)
    if luxChairs and inst:IsDescendantOf(luxChairs) then
        return false
    end
    return true
end

-- the lamp rods look for the ceiling straight through the tables and lamps
ignoreForCeiling = { newFolder }
for _, d in ipairs(workspace:GetDescendants()) do
    if isCraps(d) then
        table.insert(ignoreForCeiling, d)
    end
end
if luxChairs then
    table.insert(ignoreForCeiling, luxChairs)
end

local count = 0
for _, model in ipairs(workspace:GetDescendants()) do
    if isCraps(model) and not (model.Parent and model.Parent:FindFirstAncestorWhichIsA("Model") and isCraps(model.Parent)) then
        local infos, floorY = {}, math.huge
        for _, p in ipairs(model:GetDescendants()) do
            if p:IsA("BasePart") then
                local mn, mx = bounds(p)
                table.insert(infos, { part = p, mn = mn, mx = mx })
                floorY = math.min(floorY, mn.Y)
            end
        end

        -- The table is the biggest piece
        local top, bestArea = nil, 0
        for _, info in ipairs(infos) do
            local area = (info.mx.X - info.mn.X) * (info.mx.Z - info.mn.Z)
            if info.mx.Y - floorY >= 1 and info.mx.Y - floorY <= 6 and area > bestArea then
                top, bestArea = info, area
            end
        end

        if not top then
            warn("[Craps] Couldn't find the table in " .. model:GetFullName())
        else
            local part = top.part
            local longAxis = flat(part.Size.X >= part.Size.Z and part.CFrame.RightVector or part.CFrame.LookVector)
            if longAxis.Magnitude < 0.5 then
                longAxis = (top.mx.X - top.mn.X) >= (top.mx.Z - top.mn.Z) and V(1, 0, 0) or V(0, 0, 1)
            end
            longAxis = longAxis.Unit
            local sizeX, sizeZ = top.mx.X - top.mn.X, top.mx.Z - top.mn.Z
            local L = math.clamp(math.max(sizeX, sizeZ), 14, 24)
            local W = math.clamp(math.min(sizeX, sizeZ), 7, 11)
            local ht = math.clamp(top.mx.Y - floorY, 3.2, 4.2)
            local center = flat((top.mn + top.mx) / 2)
            local T = CFrame.fromMatrix(V(center.X, floorY, center.Z), longAxis, UP)

            -- [REX] drop the previous build for this table (note 5)
            for _, old in ipairs(newFolder:GetChildren()) do
                local link = old:FindFirstChild("OriginalTable")
                if link and link.Value == model then
                    old:Destroy()
                end
            end

            -- Remove chairs another script put here (craps players stand)
            -- [REX] LuxuryChairs is in the Casino folder, and a chair set's
            -- pivot can sit at the world origin, so use its real centre (note 3)
            if luxChairs then
                for _, chairs in ipairs(luxChairs:GetChildren()) do
                    local where = chairs:IsA("Model") and chairs:GetBoundingBox().Position or chairs:GetPivot().Position
                    local lp = T:PointToObjectSpace(where)
                    if math.abs(lp.X) < L / 2 + 5 and math.abs(lp.Z) < W / 2 + 5 then
                        chairs:Destroy()
                    end
                end
            end

            -- Hide the old look (parts stay in place so prompts and scripts keep working)
            for _, d in ipairs(model:GetDescendants()) do
                if d:IsA("BasePart") then
                    -- [REX] only record the original once (note 5)
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
            buildCraps(T, L, W, ht)
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
print(string.format("[Craps] Upgraded %d craps table(s) | %d parts", count, parts))
