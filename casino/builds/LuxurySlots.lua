-- LUXURY SLOT MACHINES + STOOLS (keeps your game prompts and scripts working)
-- Written by James. Changes are marked [REX]:
--
--   1. THE REELS WOULD HAVE STOPPED MOVING. SlotService shows every spin by
--      changing text on the ORIGINAL machine's three reel parts. This script
--      hides those and builds a solid cabinet over them with its own reel
--      symbols that never change, so you would press E, lose chips, and watch
--      nothing happen. Each new reel's middle row is now a "PayLine" label on
--      a "ReelFace" part, and the SlotReelMirror script copies the game's
--      result onto it as the reels spin (same idea as the roulette wheel).
--   2. The reel symbols match the game. SlotService pays on $, C, H, *, 7 and
--      D; the decoration rows draw from the same six (shown as $, cherry,
--      heart, star, 7, diamond), so the payline never shows a symbol the game
--      cannot land.
--   3. No stools were ever built. The stool search looked for a seat INSIDE
--      each machine model, but every machine's stool is its own "Stool" model
--      5.8 studs in front of it. The old stools stayed in front of the new
--      machines, still sittable. Each machine's Stool is found now, hidden,
--      its seat disabled, and a luxury stool built where it stood, on the
--      real carpet (the old ones sat 0.3 studs into it).
--   4. Players would have sat on their side. The stool Seat was a cylUp()
--      cylinder turned 90 degrees about Z, and a Seat orients the sitter by
--      its own CFrame. It is an upright SitPad facing the machine now.
--   5. Safeguard: the pull lever reaches about 0.8 studs past the cabinet's
--      right side. If machines ever stand closer side by side than the
--      cabinet plus LEVER_ROOM, the cabinet narrows so the lever clears the
--      next one. (Today they are 8 studs apart, so it changes nothing.)
--   6. A second run stacked a second machine on the first, and re-recorded
--      OldTransparency as 1 so the old look could never come back. The
--      previous build is cleared first and the original is recorded once.
--   7. Parented into the Casino folder, like the other builds.
--   8. The in-machine stool search took ANY small part at seat height, and
--      on these machines that is an LED strip on the cabinet's front corner.
--      Every stool landed inside its machine, and since "front" was taken as
--      the direction to that stool, every machine was turned about 54 degrees
--      away from where it faces. Only an actual Seat counts now.
--   9. The machines stand back to back in pairs, 4.4 studs apart, and the
--      granite base stuck out 0.15 behind each cabinet, so every pair of
--      bases overlapped. The base now only steps out at the front.

-- Settings:
local DETAIL = "high"      -- "high" or "low" (low = about half the parts, less lag)
local SITTABLE = true
local LEATHER_COLOR = Color3.fromRGB(140, 15, 25)
local LEVER_ROOM = 1.0     -- [REX] gap kept between neighbouring cabinets for the lever

local THEMES = {
    { name = "GOLDEN 7s", color = Color3.fromRGB(255, 190, 40), body = Color3.fromRGB(60, 15, 15) },
    { name = "DIAMOND DELUXE", color = Color3.fromRGB(80, 200, 255), body = Color3.fromRGB(15, 25, 55) },
    { name = "LUCKY CHERRY", color = Color3.fromRGB(255, 70, 140), body = Color3.fromRGB(50, 10, 30) },
    { name = "EMERALD FORTUNE", color = Color3.fromRGB(60, 230, 120), body = Color3.fromRGB(10, 40, 25) },
    { name = "ROYAL JACKPOT", color = Color3.fromRGB(190, 110, 255), body = Color3.fromRGB(30, 15, 50) },
    { name = "RUBY RICHES", color = Color3.fromRGB(255, 60, 60), body = Color3.fromRGB(25, 25, 28) },
}
-- [REX] the six symbols SlotService can land, in the same glyphs and colours
-- SlotReelMirror uses for the payline (note 2)
local SYMBOLS = {
    { "7", Color3.fromRGB(205, 70, 70) }, { "$", Color3.fromRGB(120, 190, 130) }, { "🍒", Color3.new(1, 1, 1) },
    { "♥", Color3.fromRGB(200, 90, 95) }, { "⭐", Color3.new(1, 1, 1) }, { "💎", Color3.new(1, 1, 1) },
}

local V = Vector3.new
local UP = V(0, 1, 0)
local rng = Random.new(31)
local high = DETAIL == "high"

----------------------------------------------------------------
-- Materials
----------------------------------------------------------------
local GOLD = { Color = Color3.fromRGB(212, 175, 55), Material = Enum.Material.Metal, Reflectance = 0.35 }
local CHROME = { Color = Color3.fromRGB(210, 210, 215), Material = Enum.Material.Metal, Reflectance = 0.45 }
local MAHOGANY = { Color = Color3.fromRGB(75, 30, 22), Material = Enum.Material.Wood }
local BLACK = { Color = Color3.fromRGB(18, 18, 20), Material = Enum.Material.SmoothPlastic }
local GRANITE = { Color = Color3.fromRGB(25, 25, 28), Material = Enum.Material.Granite }
local LEATHER = { Color = LEATHER_COLOR, Material = Enum.Material.Leather }
local REEL = { Color = Color3.fromRGB(245, 243, 235), Material = Enum.Material.SmoothPlastic }
local GLASS = { Color = Color3.fromRGB(200, 220, 235), Material = Enum.Material.Glass, Transparency = 0.75, Reflectance = 0.3 }
local GRILLE = { Color = Color3.fromRGB(40, 40, 44), Material = Enum.Material.DiamondPlate }
local INVISIBLE = { Transparency = 1 }

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
local function neon(color)
    return { Color = color, Material = Enum.Material.Neon }
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

local function gui(part, face)
    local g = Instance.new("SurfaceGui")
    g.Face = face or Enum.NormalId.Front
    g.LightInfluence = 0
    g.Brightness = 1.4
    g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    g.PixelsPerStud = 50
    g.Parent = part
    return g
end
local function text(parent, value, x, y, w, h, color, font)
    local l = Instance.new("TextLabel")
    l.Position = UDim2.fromScale(x, y)
    l.Size = UDim2.fromScale(w, h)
    l.BackgroundTransparency = 1
    l.Text = value
    l.TextScaled = true
    l.Font = font or Enum.Font.GothamBlack
    l.TextColor3 = color
    l.Parent = parent
    return l
end
local function frameBars(cf, w, h, thickness, depth, style)
    for _, dy in ipairs({ -h / 2, h / 2 }) do
        box(cf * CFrame.new(0, dy, 0), V(w + thickness, thickness, depth), style)
    end
    for _, dx in ipairs({ -w / 2, w / 2 }) do
        box(cf * CFrame.new(dx, 0, 0), V(thickness, h, depth), style)
    end
end

-- Hide a model's old look but leave it in place, so prompts and scripts keep working
local function hideOld(model)
    for _, dd in ipairs(model:GetDescendants()) do
        if dd:IsA("BasePart") then
            -- [REX] only record the original once (note 6)
            if dd:GetAttribute("OldTransparency") == nil then
                dd:SetAttribute("OldTransparency", dd.Transparency)
                dd:SetAttribute("OldCanCollide", dd.CanCollide)
            end
            dd.Transparency = 1
            dd.CanCollide = false
            -- [REX] an invisible old seat would still sit people down (note 3)
            if dd:IsA("Seat") then
                if dd:GetAttribute("OldDisabled") == nil then
                    dd:SetAttribute("OldDisabled", dd.Disabled)
                end
                dd.Disabled = true
            end
        elseif dd:IsA("Decal") or dd:IsA("Texture") then
            dd.Transparency = 1
        elseif dd:IsA("SurfaceGui") then
            dd.Enabled = false
        end
    end
end

----------------------------------------------------------------
-- Slot machine (T = floor point under the machine center, -Z faces the player)
----------------------------------------------------------------
local function buildMachine(T, w, d, H)
    local theme = THEMES[rng:NextInteger(1, #THEMES)]
    local accent = neon(theme.color)
    local BODY = { Color = theme.body, Material = Enum.Material.Metal, Reflectance = 0.15 }
    local front = -d / 2
    local function at(x, y, z)
        return T * CFrame.new(x, y, z)
    end
    local function pos(x, y, z)
        return T * V(x, y, z)
    end

    local bellyTop = 0.36 * H
    local screenBottom, screenTop = 0.40 * H, 0.66 * H
    local topperBottom = 0.69 * H
    local cabinetTop = H - w * 0.45
    local topperTop = math.min(cabinetTop - 0.2, topperBottom + 0.2 * H)

    -- Base and cabinet
    -- [REX] flush at the back, so back-to-back machines don't overlap (note 9)
    box(at(0, 0.3, -0.075), V(w + 0.3, 0.6, d + 0.15), GRANITE).CanCollide = true
    box(at(0, 0.62, front - 0.13), V(w + 0.3, 0.06, 0.06), GOLD)
    box(at(0, 0.05, front - 0.2), V(w, 0.1, 0.1), accent)
    local cabinet = box(at(0, (0.6 + cabinetTop) / 2, 0), V(w, cabinetTop - 0.6, d), BODY)
    cabinet.CanCollide = true
    for _, side in ipairs({ -1, 1 }) do
        box(at(side * (w / 2 - 0.08), (0.8 + cabinetTop) / 2, front - 0.03), V(0.16, cabinetTop - 1, 0.12), accent)
        box(at(side * (w / 2 + 0.01), (0.6 + cabinetTop) / 2, 0), V(0.04, cabinetTop - 0.6, d * 0.7), GOLD)
    end

    -- Front art panel and coin tray
    local bellyH = bellyTop - 1.6
    if bellyH > 0.8 then
        local bellyCF = at(0, 1.6 + bellyH / 2, front - 0.03)
        local art = box(bellyCF, V(w - 0.9, bellyH, 0.04), { Color = theme.body:Lerp(theme.color, 0.25), Material = Enum.Material.SmoothPlastic })
        local g = gui(art)
        local bg = Instance.new("UIGradient")
        bg.Color = ColorSequence.new(theme.body, theme.color:Lerp(Color3.new(0, 0, 0), 0.4))
        bg.Rotation = 90
        local holder = Instance.new("Frame")
        holder.Size = UDim2.fromScale(1, 1)
        holder.BackgroundColor3 = Color3.new(1, 1, 1)
        holder.BorderSizePixel = 0
        holder.Parent = g
        bg.Parent = holder
        text(holder, theme.name, 0.05, 0.15, 0.9, 0.45, theme.color, Enum.Font.Bodoni)
        text(holder, "★  ★  ★", 0.2, 0.62, 0.6, 0.25, Color3.fromRGB(255, 225, 120))
        frameBars(bellyCF * CFrame.new(0, 0, -0.03), w - 0.9, bellyH, 0.14, 0.08, GOLD)
    end
    box(at(0, 1.05, front - 0.3), V(w * 0.5, 0.35, 0.6), GOLD)
    box(at(0, 1.15, front - 0.32), V(w * 0.42, 0.2, 0.45), BLACK)

    -- Sloped button panel
    local deckCF = at(0, bellyTop + 0.1, front - 0.5) * CFrame.Angles(math.rad(-12), 0, 0)
    box(deckCF, V(w - 0.2, 0.3, 1.2), BODY).CanCollide = true
    box(deckCF * CFrame.new(0, 0.16, -0.58), V(w - 0.2, 0.05, 0.06), GOLD)
    local buttonColors = { Color3.fromRGB(255, 220, 60), Color3.fromRGB(60, 160, 255), Color3.fromRGB(255, 80, 80), Color3.fromRGB(240, 240, 240) }
    local buttonCount = high and 4 or 2
    for i = 1, buttonCount do
        local x = -w / 2 + 0.6 + (i - 1) * 0.65
        box(deckCF * CFrame.new(x, 0.2, -0.1), V(0.45, 0.12, 0.35), neon(buttonColors[(i - 1) % #buttonColors + 1]))
        if high then
            box(deckCF * CFrame.new(x, 0.15, -0.1), V(0.55, 0.06, 0.45), CHROME)
        end
    end
    makePart({ Shape = Enum.PartType.Cylinder, CFrame = deckCF * CFrame.new(w / 2 - 0.8, 0.22, -0.1) * CFrame.Angles(0, 0, math.rad(90)), Size = V(0.18, 0.8, 0.8) }, neon(Color3.fromRGB(60, 255, 120)))
    makePart({ Shape = Enum.PartType.Cylinder, CFrame = deckCF * CFrame.new(w / 2 - 0.8, 0.16, -0.1) * CFrame.Angles(0, 0, math.rad(90)), Size = V(0.06, 0.95, 0.95) }, CHROME)

    -- Bill slot and player card reader
    box(at(w / 2 - 0.55, bellyTop + 0.75, front - 0.15), V(0.7, 0.75, 0.3), BLACK)
    box(at(w / 2 - 0.55, bellyTop + 0.85, front - 0.31), V(0.5, 0.06, 0.02), neon(Color3.fromRGB(60, 255, 120)))
    if high then
        box(at(-w / 2 + 0.55, bellyTop + 0.75, front - 0.12), V(0.55, 0.5, 0.25), BLACK)
        box(at(-w / 2 + 0.55, bellyTop + 0.9, front - 0.25), V(0.35, 0.05, 0.02), neon(Color3.fromRGB(80, 160, 255)))
    end

    -- Reel window: three reels with symbols, pay line, glass, gold frame, bulbs
    local winH = screenTop - screenBottom
    local winW = w - 1.0
    local winY = (screenBottom + screenTop) / 2
    local winCF = at(0, winY, front)
    box(winCF * CFrame.new(0, 0, -0.02), V(winW, winH, 0.04), BLACK)
    local reelW = (winW - 0.4) / 3
    local reelDia = winH * 0.92
    for r = -1, 1 do
        local x = r * (reelW + 0.08)
        makePart({ Shape = Enum.PartType.Cylinder, CFrame = at(x, winY, front + reelDia / 2 - 0.15), Size = V(reelW, reelDia, reelDia) }, REEL)
        local face = box(winCF * CFrame.new(x, 0, -0.17), V(reelW * 0.92, reelDia * 0.85, 0.02), INVISIBLE)
        face.Name = "ReelFace" -- [REX] SlotReelMirror finds the reels by this name
        local g = gui(face)
        local rows = high and { { 0, 0.3, 0.45 }, { 0.32, 0.36, 1 }, { 0.7, 0.3, 0.45 } } or { { 0.32, 0.36, 1 } }
        for _, row in ipairs(rows) do
            local symbol = SYMBOLS[rng:NextInteger(1, #SYMBOLS)]
            local l = text(g, symbol[1], 0.05, row[1], 0.9, row[2], symbol[2])
            l.TextTransparency = 1 - row[3]
            if row[3] == 1 then
                l.Name = "PayLine" -- [REX] the row the game's result is copied onto
            end
        end
    end
    box(winCF * CFrame.new(0, 0, -0.2), V(winW, 0.06, 0.03), neon(Color3.fromRGB(255, 40, 40)))
    box(winCF * CFrame.new(0, 0, -0.27), V(winW, winH, 0.05), GLASS)
    frameBars(winCF * CFrame.new(0, 0, -0.22), winW + 0.15, winH + 0.15, 0.2, 0.15, GOLD)
    if high then
        local perimeter = {}
        local hw, hh = winW / 2 + 0.3, winH / 2 + 0.3
        for i = 0, 3 do
            table.insert(perimeter, V(-hw + i * hw * 2 / 3, hh, 0))
            table.insert(perimeter, V(hw, hh - i * hh * 2 / 3, 0))
            table.insert(perimeter, V(hw - i * hw * 2 / 3, -hh, 0))
            table.insert(perimeter, V(-hw, -hh + i * hh * 2 / 3, 0))
        end
        for i, p in ipairs(perimeter) do
            ball((winCF * CFrame.new(p.X, p.Y, -0.18)).Position, 0.2, neon(i % 2 == 0 and theme.color or Color3.fromRGB(255, 250, 230)))
        end
    end

    -- Top panel with the game name and jackpot meter
    local topH = topperTop - topperBottom
    local topCF = at(0, (topperBottom + topperTop) / 2, front - 0.03)
    local topper = box(topCF, V(w - 0.6, topH, 0.04), { Color = Color3.fromRGB(10, 10, 14), Material = Enum.Material.SmoothPlastic })
    local tg = gui(topper)
    text(tg, theme.name, 0.04, 0.04, 0.92, 0.4, theme.color, Enum.Font.Bodoni)
    text(tg, "PROGRESSIVE JACKPOT", 0.1, 0.46, 0.8, 0.16, Color3.fromRGB(255, 220, 120), Enum.Font.GothamBold)
    local meter = text(tg, string.format("$%d,%03d.%02d", rng:NextInteger(5, 98), rng:NextInteger(0, 999), rng:NextInteger(0, 99)),
        0.08, 0.64, 0.84, 0.32, Color3.fromRGB(255, 50, 50), Enum.Font.Arcade)
    meter.Name = "JackpotMeter"
    frameBars(topCF * CFrame.new(0, 0, -0.03), w - 0.6, topH, 0.14, 0.08, GOLD)
    if high then
        for _, side in ipairs({ -1, 1 }) do
            local sp = at(side * (w / 2 - 0.18), (topperBottom + topperTop) / 2, front - 0.05)
            box(sp, V(0.25, topH * 0.7, 0.05), GRILLE)
        end
    end

    -- Rounded top with glowing rim, gem and light
    local radius = w / 2
    makePart({ Shape = Enum.PartType.Cylinder, CFrame = at(0, cabinetTop, 0) * CFrame.Angles(0, math.rad(90), 0), Size = V(d, w, w) }, BODY)
    makePart({ Shape = Enum.PartType.Cylinder, CFrame = at(0, cabinetTop, front + 0.08) * CFrame.Angles(0, math.rad(90), 0), Size = V(0.12, w + 0.25, w + 0.25) }, accent)
    makePart({ Shape = Enum.PartType.Cylinder, CFrame = at(0, cabinetTop, front + 0.04) * CFrame.Angles(0, math.rad(90), 0), Size = V(0.08, w + 0.4, w + 0.4) }, GOLD)
    local gem = makePart({ CFrame = at(0, cabinetTop + radius * 0.45, front - 0.05) * CFrame.Angles(0, 0, math.rad(45)), Size = V(0.7, 0.7, 0.15) }, neon(theme.color))
    box(gem.CFrame * CFrame.new(0, 0, 0.03), V(0.9, 0.9, 0.08), GOLD)
    local candleBase = pos(0, cabinetTop + radius, 0)
    cylUp(candleBase + V(0, 0.15, 0), 0.3, 0.7, BLACK)
    cylUp(candleBase + V(0, 0.55, 0), 0.5, 0.55, neon(Color3.fromRGB(255, 40, 40)))
    cylUp(candleBase + V(0, 1.05, 0), 0.5, 0.55, neon(Color3.fromRGB(255, 250, 240)))
    cylUp(candleBase + V(0, 1.38, 0), 0.15, 0.65, CHROME)

    -- Pull lever on the right side
    local leverBase = pos(w / 2 + 0.2, 0.5 * H, 0)
    makePart({ Shape = Enum.PartType.Cylinder, CFrame = CFrame.new(leverBase) * T.Rotation, Size = V(0.4, 1.0, 1.0) }, CHROME)
    local leverTop = pos(w / 2 + 0.45, 0.5 * H + 2.2, -0.4)
    rod(leverBase + T:VectorToWorldSpace(V(0.2, 0, 0)), leverTop, 0.18, CHROME)
    ball(leverTop, 0.65, { Color = Color3.fromRGB(220, 20, 20), Material = Enum.Material.SmoothPlastic, Reflectance = 0.2 })
end

----------------------------------------------------------------
-- Slot stool (base = floor point, -Z faces the machine)
----------------------------------------------------------------
local function buildStool(base, h)
    local function c(localPos, height, width, style, className)
        return cylUp(base * localPos, height, width, style, className)
    end
    c(V(0, 0.12, 0), 0.25, 2.2, GOLD).CanCollide = true
    c(V(0, 0.3, 0), 0.12, 1.7, BLACK)
    c(V(0, (0.35 + h - 0.9) / 2, 0), h - 1.25, 0.4, GOLD).CanCollide = true
    c(V(0, h - 0.85, 0), 0.15, 1.1, GOLD)
    if high then
        local ringY, last = h * 0.42, nil
        for i = 0, 6 do
            local a = i / 6 * math.pi * 2
            local point = base * V(math.cos(a) * 0.95, ringY, math.sin(a) * 0.95)
            if last then
                rod(last, point, 0.12, GOLD)
            end
            last = point
        end
    end
    -- [REX] plain cushion; the Seat is the upright block below (note 4)
    local cushion = c(V(0, h - 0.25, 0), 0.5, 2.3, LEATHER)
    cushion.CanCollide = true
    cushion.Name = "Cushion"
    if SITTABLE then
        local seat = Instance.new("Seat")
        seat.Name = "SitPad"
        seat.Anchored = true
        seat.CanCollide = true
        seat.Transparency = 1
        seat.Size = V(2, 0.5, 2)
        seat.CFrame = base * CFrame.new(0, h - 0.25, 0)
        seat.TopSurface = Enum.SurfaceType.Smooth
        seat.BottomSurface = Enum.SurfaceType.Smooth
        seat.Parent = current
    end
    c(V(0, h - 0.5, 0), 0.08, 2.36, GOLD)
    c(V(0, h - 0.65, 0), 0.25, 2.1, MAHOGANY)
    for _, offset in ipairs(high and { V(0, 0, 0), V(0.55, 0, 0), V(-0.55, 0, 0) } or { V(0, 0, 0) }) do
        ball(base * (V(0, h + 0.01, 0) + offset), 0.15, GOLD)
    end
    -- Low curved backrest
    local R, backH = 1.05, 1.5
    local center = base * V(0, h + backH / 2, 0)
    for _, deg in ipairs({ -45, 0, 45 }) do
        local a = math.rad(deg)
        local p = base * V(math.sin(a) * R, h - 0.1 + backH / 2, math.cos(a) * R)
        box(CFrame.lookAt(p, V(center.X, p.Y, center.Z)), V(0.85, backH, 0.3), LEATHER).CanCollide = true
    end
    local prev
    for i = 0, 4 do
        local a = math.rad(-65 + 130 * i / 4)
        local point = base * V(math.sin(a) * R, h - 0.1 + backH, math.cos(a) * R)
        if prev then
            rod(prev, point, 0.18, GOLD)
        end
        prev = point
    end
end

----------------------------------------------------------------
-- Find each slot machine, hide the old look, build the new one
----------------------------------------------------------------
-- [REX] parented in the Casino folder like the other builds
local casinoRoot = workspace:FindFirstChild("Casino") or workspace
local newFolder = workspace:FindFirstChild("LuxurySlots", true) or Instance.new("Folder")
newFolder.Name = "LuxurySlots"
newFolder.Parent = casinoRoot

local function isSlot(inst)
    if not inst:IsA("Model") or not string.find(string.lower(inst.Name), "slot") then
        return false
    end
    return not inst:IsDescendantOf(newFolder) and inst:IsDescendantOf(game)
end

-- [REX] every machine and every separate stool, gathered up front (notes 3, 5)
local machineList, stoolList = {}, {}
for _, model in ipairs(workspace:GetDescendants()) do
    if isSlot(model) and not (model.Parent and model.Parent:FindFirstAncestorWhichIsA("Model") and isSlot(model.Parent)) then
        table.insert(machineList, model)
    elseif model:IsA("Model") and model:FindFirstChildWhichIsA("Seat", true) and string.find(string.lower(model.Name), "stool")
        and not model:IsDescendantOf(newFolder) then
        table.insert(stoolList, model)
    end
end
local usedStools = {}

local floorRay = RaycastParams.new()
floorRay.FilterType = Enum.RaycastFilterType.Exclude
local floorIgnore = { newFolder }
for _, m in ipairs(machineList) do
    table.insert(floorIgnore, m)
end
for _, s in ipairs(stoolList) do
    table.insert(floorIgnore, s)
end
floorRay.FilterDescendantsInstances = floorIgnore
local function floorAt(p, fallback)
    local hit = workspace:Raycast(p + V(0, 4, 0), V(0, -12, 0), floorRay)
    return hit and hit.Position.Y or fallback
end

local count, stoolsBuilt = 0, 0
for _, model in ipairs(machineList) do
    local infos, floorY, topY = {}, math.huge, -math.huge
    for _, p in ipairs(model:GetDescendants()) do
        if p:IsA("BasePart") then
            local mn, mx = bounds(p)
            table.insert(infos, { part = p, mn = mn, mx = mx })
            floorY = math.min(floorY, mn.Y)
            topY = math.max(topY, mx.Y)
        end
    end
    if #infos > 0 then
        local height = topY - floorY

        -- Machine center = middle of the tall parts
        local mmn, mmx = V(math.huge, 0, math.huge), V(-math.huge, 0, -math.huge)
        for _, info in ipairs(infos) do
            if info.mx.Y - floorY > height * 0.6 then
                mmn, mmx = mmn:Min(info.mn), mmx:Max(info.mx)
            end
        end
        local machineCenter = flat((mmn + mmx) / 2)

        -- Stool = a small seat at sitting height, away from the machine
        local seat, best = nil, 1.5
        for _, info in ipairs(infos) do
            local top = info.mx.Y - floorY
            local footprint = math.max(info.mx.X - info.mn.X, info.mx.Z - info.mn.Z)
            local dist = (flat((info.mn + info.mx) / 2) - machineCenter).Magnitude
            -- [REX] only a real Seat counts (note 8)
            if info.part:IsA("Seat") and info.mx.Y - info.mn.Y <= 1.2 and top >= 1.8 and top <= 4.5 and footprint <= 4.5 and dist > best then
                seat, best = info, dist
            end
        end

        local stoolParts = {}
        local front
        if seat then
            local seatCenter = flat((seat.mn + seat.mx) / 2)
            front = (seatCenter - machineCenter).Unit
            for _, info in ipairs(infos) do
                local c = flat((info.mn + info.mx) / 2)
                if (c - seatCenter).Magnitude < 2.5 and info.mx.Y <= seat.mx.Y + 2 then
                    stoolParts[info.part] = true
                end
            end
        else
            front = flat(model:GetPivot().LookVector).Unit
        end

        -- [REX] the machine's own Stool model, in front of it (note 3)
        local stoolModel, stoolDist = nil, 8
        if not seat then
            for _, s in ipairs(stoolList) do
                if not usedStools[s] then
                    local offset = flat(s:GetBoundingBox().Position) - machineCenter
                    if offset.Magnitude < stoolDist and offset.Magnitude > 1 and offset.Unit:Dot(front) > 0.8 then
                        stoolModel, stoolDist = s, offset.Magnitude
                    end
                end
            end
            if stoolModel then
                usedStools[stoolModel] = true
            end
        end

        -- Measure the machine in its own direction
        local T0 = CFrame.lookAt(V(machineCenter.X, floorY, machineCenter.Z), V(machineCenter.X, floorY, machineCenter.Z) + front)
        local lmn, lmx = V(math.huge, math.huge, math.huge), V(-math.huge, -math.huge, -math.huge)
        for _, info in ipairs(infos) do
            if not stoolParts[info.part] then
                for _, corner in ipairs({ info.mn, info.mx, V(info.mn.X, info.mn.Y, info.mx.Z), V(info.mx.X, info.mx.Y, info.mn.Z) }) do
                    local lp = T0:PointToObjectSpace(corner)
                    lmn, lmx = lmn:Min(lp), lmx:Max(lp)
                end
            end
        end
        local w = math.clamp(lmx.X - lmn.X, 3, 7)
        -- [REX] leave room for the lever before the next machine in the row (note 5)
        local nearest = math.huge
        for _, other in ipairs(machineList) do
            if other ~= model then
                local lp = T0:PointToObjectSpace(other:GetPivot().Position)
                if math.abs(lp.Z) < 2 and math.abs(lp.X) > 0.5 then
                    nearest = math.min(nearest, math.abs(lp.X))
                end
            end
        end
        w = math.clamp(math.min(w, nearest - LEVER_ROOM), 3, 7)
        local d = math.clamp(lmx.Z - lmn.Z, 2.5, 6)
        local H = math.clamp(lmx.Y, 6, 14)
        local centerLocal = V((lmn.X + lmx.X) / 2, 0, (lmn.Z + lmx.Z) / 2)
        local T = T0 * CFrame.new(centerLocal)

        -- [REX] drop the previous build for this machine (note 6)
        for _, old in ipairs(newFolder:GetChildren()) do
            local link = old:FindFirstChild("OriginalMachine")
            if link and link.Value == model then
                old:Destroy()
            end
        end

        hideOld(model)
        if stoolModel then
            hideOld(stoolModel)
        end

        current = Instance.new("Model")
        current.Name = model.Name .. "_Luxury"
        local link = Instance.new("ObjectValue")
        link.Name = "OriginalMachine"
        link.Value = model
        link.Parent = current
        if stoolModel then
            local stoolLink = Instance.new("ObjectValue")
            stoolLink.Name = "OriginalStool"
            stoolLink.Value = stoolModel
            stoolLink.Parent = current
        end
        current.Parent = newFolder
        buildMachine(T, w, d, H)
        if seat then
            local seatCenter = flat((seat.mn + seat.mx) / 2)
            local stoolBase = V(seatCenter.X, floorY, seatCenter.Z)
            buildStool(CFrame.lookAt(stoolBase, stoolBase - front), math.clamp(seat.mx.Y - floorY, 2.4, 4))
            stoolsBuilt += 1
        elseif stoolModel then
            -- [REX] stand it on the real floor, at the old seat's height
            local where = flat(stoolModel:GetBoundingBox().Position)
            local ground = floorAt(V(where.X, floorY, where.Z), floorY)
            local seatTop = -math.huge
            for _, p in ipairs(stoolModel:GetDescendants()) do
                if p:IsA("BasePart") then
                    local _, mx = bounds(p)
                    seatTop = math.max(seatTop, mx.Y)
                end
            end
            local stoolBase = V(where.X, ground, where.Z)
            buildStool(CFrame.lookAt(stoolBase, stoolBase - front), math.clamp(seatTop - ground, 2.4, 4))
            stoolsBuilt += 1
        end
        count += 1
        if count % 10 == 0 then
            task.wait()
        end
    end
end

local parts = 0
for _, dd in ipairs(newFolder:GetDescendants()) do
    if dd:IsA("BasePart") then
        parts = parts + 1
    end
end
print(string.format("[Slots] Upgraded %d slot machine(s), %d stools | %d parts", count, stoolsBuilt, parts))
