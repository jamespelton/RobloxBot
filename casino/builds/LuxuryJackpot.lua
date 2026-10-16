-- MEGA JACKPOT DISPLAY (rebuilds the big jackpot board with live counting jackpots)
-- Written by James. Changes are marked [REX]:
--
--   1. IT WOULD HAVE BEEN BUILT INTO THE WALL. The side of the board the
--      text is on was read with the face directions flipped: a part's Front
--      face points along its LookVector, and this used -LookVector.
--   2. Only the MEGA JACKPOT screen and its frame were hidden. The board is
--      four parts: that screen, the GOOD LUCK / PLAY RESPONSIBLY screen under
--      it, the frame and a big bezel. The bezel and the GOOD LUCK screen
--      stayed, sticking out around and under the new display, with the new
--      case covering the top of the GOOD LUCK text. The new display carries
--      that line in its ticker, so the whole old board is hidden and the new
--      one is centred on it. The hide step only touches the board's own
--      model; scanning all of Workspace was not needed and could catch
--      other things.
--   3. Centred on the old MEGA JACKPOT screen, the crown's star reached
--      y 45.3 under a ceiling at 45. Centring on the whole board brings it
--      down 4 studs, and the star is skipped if there is ever no room.
--   4. This runs once in Studio, like the other builds, instead of at every
--      server start. The counter, ticker, shine and ~200 bulbs were all
--      animated by the server every 0.15 s, which is a stream of updates to
--      every player. The JackpotDisplay LocalScript animates them on each
--      player's machine. The amounts come from the server's game clock, so
--      every player sees the same jackpot, and it still resets when a
--      server starts. The settings below still drive it.
--   5. Safe to re-run: the previous build is replaced, not found as the
--      "MEGA JACKPOT" board, and the original look is recorded once.
--   6. Parented into the Casino folder, like the other builds.

-- Settings:
local START_JACKPOT = 4812900      -- starting amount in dollars
local MAJOR, MINOR, MINI = 48215, 2148, 215
local CASINO_NAME = "GOLDEN SPIRE"
local TICKER = "GOOD LUCK   •   PLAY RESPONSIBLY   •   " .. CASINO_NAME .. " CASINO   •   WIN BIG TONIGHT   •   "
local ACCENT = Color3.fromRGB(230, 40, 40)
local SPARKLES = true

local V = Vector3.new

local GOLD = { Color = Color3.fromRGB(212, 175, 55), Material = Enum.Material.Metal, Reflectance = 0.35 }
local DARK_GOLD = { Color = Color3.fromRGB(150, 115, 35), Material = Enum.Material.Metal, Reflectance = 0.3 }
local LACQUER = { Color = Color3.fromRGB(10, 10, 12), Material = Enum.Material.SmoothPlastic, Reflectance = 0.15 }
local BULB_ON = Color3.fromRGB(255, 230, 160)

----------------------------------------------------------------
-- Helpers
----------------------------------------------------------------
local current
local function makePart(props, style)
    local p = Instance.new("Part")
    p.Anchored = true
    p.CanCollide = false
    p.CanTouch = false
    p.CanQuery = false
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
local function box(cf, size, style)
    return makePart({ CFrame = cf, Size = size }, style)
end
local function ball(pos, size, style)
    return makePart({ Shape = Enum.PartType.Ball, CFrame = CFrame.new(pos), Size = V(size, size, size) }, style)
end
local function neon(color)
    return { Color = color, Material = Enum.Material.Neon }
end
local function frameBars(cf, w, h, thickness, depth, style)
    for _, dy in ipairs({ -h / 2, h / 2 }) do
        box(cf * CFrame.new(0, dy, 0), V(w + thickness, thickness, depth), style)
    end
    for _, dx in ipairs({ -w / 2, w / 2 }) do
        box(cf * CFrame.new(dx, 0, 0), V(thickness, h, depth), style)
    end
end
local function money(n, cents)
    local whole = tostring(math.floor(n)):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    if cents then
        return "$" .. whole .. string.format(".%02d", math.floor((n % 1) * 100))
    end
    return "$" .. whole
end

----------------------------------------------------------------
-- Find the old jackpot board
----------------------------------------------------------------
-- [REX] skip the previous build when searching (note 5)
local casinoRoot = workspace:FindFirstChild("Casino") or workspace
local previous = casinoRoot:FindFirstChild("LuxuryJackpot") or workspace:FindFirstChild("LuxuryJackpot")

local board, boardGui, best = nil, nil, 0
for _, gui in ipairs(workspace:GetDescendants()) do
    if gui:IsA("SurfaceGui") and not (previous and gui:IsDescendantOf(previous)) then
        local part = gui.Adornee or gui.Parent
        if part and part:IsA("BasePart") then
            for _, d in ipairs(gui:GetDescendants()) do
                if d:IsA("TextLabel") and string.find(string.upper(d.Text), "MEGA JACKPOT") then
                    local area = part.Size.X * part.Size.Y * part.Size.Z
                    if area > best then
                        board, boardGui, best = part, gui, area
                    end
                end
            end
        end
    end
end
if not board then
    error("[Jackpot] Couldn't find a sign that says MEGA JACKPOT.")
end

local cf, s = board.CFrame, board.Size
-- [REX] a part's Front face points along LookVector (note 1)
local faces = {
    [Enum.NormalId.Front] = { cf.LookVector, s.X, s.Y, s.Z / 2 },
    [Enum.NormalId.Back] = { -cf.LookVector, s.X, s.Y, s.Z / 2 },
    [Enum.NormalId.Right] = { cf.RightVector, s.Z, s.Y, s.X / 2 },
    [Enum.NormalId.Left] = { -cf.RightVector, s.Z, s.Y, s.X / 2 },
}
local f = faces[boardGui.Face] or faces[Enum.NormalId.Front]
local normal = V(f[1].X, 0, f[1].Z).Unit
local W, H = math.max(f[2], 16), math.max(f[3], 6)

-- [REX] centre on the whole old board, on the plane of its screen (notes 2, 3)
local owner = board:FindFirstAncestorWhichIsA("Model")
local boardCenter = owner and owner:GetBoundingBox().Position or board.Position
local faceCenter = boardCenter + normal * ((board.Position - boardCenter):Dot(normal) + f[4])
local S = CFrame.lookAt(faceCenter, faceCenter + normal) -- -Z points away from the wall

-- Hide the old board
-- [REX] all of it, and only it (note 2); original recorded once (note 5)
for _, p in ipairs((owner or board):GetDescendants()) do
    if p:IsA("BasePart") then
        if p:GetAttribute("OldTransparency") == nil then
            p:SetAttribute("OldTransparency", p.Transparency)
        end
        p.Transparency = 1
        for _, d in ipairs(p:GetDescendants()) do
            if d:IsA("SurfaceGui") then
                d.Enabled = false
            elseif d:IsA("Decal") or d:IsA("Texture") then
                d.Transparency = 1
            end
        end
    end
end
if not owner then
    board:SetAttribute("OldTransparency", board:GetAttribute("OldTransparency") or 0)
    board.Transparency = 1
    boardGui.Enabled = false
end

-- [REX] how much room there is above for the crown (note 3)
local ceilingY = math.huge
do
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local ignore = { owner or board }
    if previous then
        table.insert(ignore, previous)
    end
    params.FilterDescendantsInstances = ignore
    local hit = workspace:Raycast((S * CFrame.new(0, 0, -0.9)).Position, V(0, 60, 0), params)
    if hit then
        ceilingY = hit.Position.Y
    end
end

----------------------------------------------------------------
-- Build the new display
----------------------------------------------------------------
if previous then
    previous:Destroy()
end
current = Instance.new("Model")
current.Name = "LuxuryJackpot"
-- [REX] the JackpotDisplay LocalScript reads the settings from here (note 4)
current:SetAttribute("StartJackpot", START_JACKPOT)
current:SetAttribute("Major", MAJOR)
current:SetAttribute("Minor", MINOR)
current:SetAttribute("Mini", MINI)
current.Parent = casinoRoot

-- Case, gold frames, neon border
box(S * CFrame.new(0, 0, -0.6), V(W + 2.2, H + 2.2, 1.2), LACQUER)
frameBars(S * CFrame.new(0, 0, -1.25), W + 1.8, H + 1.8, 0.55, 0.3, GOLD)
frameBars(S * CFrame.new(0, 0, -1.3), W + 1.0, H + 1.0, 0.2, 0.25, DARK_GOLD)
frameBars(S * CFrame.new(0, 0, -1.28), W + 0.4, H + 0.4, 0.14, 0.2, GOLD)
frameBars(S * CFrame.new(0, 0, -1.24), W + 0.12, H + 0.12, 0.1, 0.1, neon(ACCENT))

-- Corner rosettes with gems
for _, sx in ipairs({ -1, 1 }) do
    for _, sy in ipairs({ -1, 1 }) do
        local corner = S * CFrame.new(sx * (W / 2 + 0.9), sy * (H / 2 + 0.9), -1.45)
        makePart({ Shape = Enum.PartType.Cylinder, CFrame = corner * CFrame.Angles(0, math.rad(90), 0), Size = V(0.3, 1.6, 1.6) }, GOLD)
        box(corner * CFrame.new(0, 0, -0.18) * CFrame.Angles(0, 0, math.rad(45)), V(0.7, 0.7, 0.12), neon(ACCENT))
    end
end

-- Marquee bulbs
local bulbCount = 0
local bw, bh = W + 1.8, H + 1.8
local corners = { V(-bw / 2, bh / 2, 0), V(bw / 2, bh / 2, 0), V(bw / 2, -bh / 2, 0), V(-bw / 2, -bh / 2, 0) }
for i = 1, 4 do
    local a, b = corners[i], corners[i % 4 + 1]
    local steps = math.max(1, math.floor((b - a).Magnitude / 1.0))
    for k = 1, steps - 1 do
        local p = a:Lerp(b, k / steps)
        local bulb = ball((S * CFrame.new(p.X, p.Y, -1.6)).Position, 0.4, { Color = BULB_ON, Material = Enum.Material.Neon })
        -- [REX] chased by the JackpotDisplay LocalScript in this order (note 4)
        bulbCount += 1
        bulb.Name = "MarqueeBulb"
        bulb:SetAttribute("Index", bulbCount)
    end
end

-- Crown on top
local topY = bh / 2 + 0.3
box(S * CFrame.new(0, topY + 0.3, -0.8), V(math.min(W * 0.5, 22), 0.6, 1.0), GOLD)
box(S * CFrame.new(0, topY + 0.85, -0.8), V(math.min(W * 0.36, 16), 0.5, 0.9), GOLD)
box(S * CFrame.new(0, topY + 1.3, -0.8), V(math.min(W * 0.22, 10), 0.4, 0.8), GOLD)
for k = -2, 2 do
    local x = k * math.min(W * 0.05, 2.2)
    local h = 1.2 - math.abs(k) * 0.25
    box(S * CFrame.new(x, topY + 1.5 + h / 2, -0.8), V(0.25, h, 0.25), GOLD)
    ball((S * CFrame.new(x, topY + 1.6 + h, -0.8)).Position, 0.35, GOLD)
end
local starPos = (S * CFrame.new(0, topY + 3.4, -0.9)).Position
-- [REX] only if it fits under the ceiling (note 3)
if starPos.Y + 0.7 < ceilingY - 0.2 then
    local star = ball(starPos, 1.4, neon(Color3.fromRGB(255, 210, 90)))
    local starLight = Instance.new("PointLight")
    starLight.Color = Color3.fromRGB(255, 200, 90)
    starLight.Range = 18
    starLight.Brightness = 1.5
    starLight.Parent = star
end
local plaque = box(S * CFrame.new(0, topY + 0.3, -1.32), V(math.min(W * 0.3, 12), 0.5, 0.05), { Transparency = 1 })
local plaqueGui = Instance.new("SurfaceGui")
plaqueGui.Face = Enum.NormalId.Front
plaqueGui.LightInfluence = 0
plaqueGui.Parent = plaque
local plaqueText = Instance.new("TextLabel")
plaqueText.Size = UDim2.fromScale(1, 1)
plaqueText.BackgroundTransparency = 1
plaqueText.Text = CASINO_NAME
plaqueText.TextScaled = true
plaqueText.Font = Enum.Font.Bodoni
plaqueText.TextColor3 = Color3.fromRGB(40, 25, 0)
plaqueText.Parent = plaqueGui

-- Screen
local screen = box(S * CFrame.new(0, 0, -1.22), V(W, H, 0.05), { Color = Color3.fromRGB(8, 6, 10), Material = Enum.Material.SmoothPlastic })
screen.Name = "Screen"
local gui = Instance.new("SurfaceGui")
gui.Name = "Display"
gui.Face = Enum.NormalId.Front
gui.LightInfluence = 0
gui.Brightness = 1.8
gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
gui.PixelsPerStud = 40
gui.Parent = screen

local function label(parent, text, x, y, w, h, color, font)
    local l = Instance.new("TextLabel")
    l.Position = UDim2.fromScale(x, y)
    l.Size = UDim2.fromScale(w, h)
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextScaled = true
    l.Font = font or Enum.Font.GothamBlack
    l.TextColor3 = color or Color3.new(1, 1, 1)
    l.Parent = parent
    return l
end
local function goldGradient(l)
    local g = Instance.new("UIGradient")
    g.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(200, 150, 40)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 245, 190)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 150, 40)),
    })
    g.Rotation = 90
    g.Parent = l
    return g
end

local header = label(gui, "★  MEGA JACKPOT  ★", 0.05, 0.02, 0.9, 0.2, Color3.new(1, 1, 1), Enum.Font.Bodoni)
header.Name = "Header"
goldGradient(header).Name = "Shine"
local headerGlow = Instance.new("UIStroke")
headerGlow.Color = ACCENT
headerGlow.Thickness = 3
headerGlow.Transparency = 0.3
headerGlow.Parent = header

-- Rolling counter: each character in its own gold-framed tile
local counter = Instance.new("Frame")
counter.Name = "Counter"
counter.Position = UDim2.fromScale(0.06, 0.24)
counter.Size = UDim2.fromScale(0.88, 0.32)
counter.BackgroundTransparency = 1
counter.Parent = gui
local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.Padding = UDim.new(0.006, 0)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = counter
-- (the same tile builder lives in JackpotDisplay, which keeps it counting)
local function setCounter(text)
    local digits = 0
    for i = 1, #text do
        if string.match(string.sub(text, i, i), "%d") then
            digits += 1
        end
    end
    local narrow = #text - digits
    local unit = 1 / (digits + narrow * 0.45 + #text * 0.01)
    for i = 1, #text do
        local ch = string.sub(text, i, i)
        local isDigit = string.match(ch, "%d") ~= nil
        local tile = Instance.new("TextLabel")
        tile.Name = "Tile"
        tile.Size = UDim2.fromScale(unit * (isDigit and 1 or 0.45), 1)
        tile.BackgroundColor3 = Color3.fromRGB(20, 5, 5)
        tile.BackgroundTransparency = isDigit and 0 or 1
        tile.BorderSizePixel = 0
        tile.TextScaled = true
        tile.Font = Enum.Font.GothamBlack
        tile.TextColor3 = Color3.fromRGB(255, 70, 50)
        tile.LayoutOrder = i
        tile.Text = ch
        tile.Parent = counter
        if isDigit then
            local stroke = Instance.new("UIStroke")
            stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
            stroke.Color = Color3.fromRGB(212, 175, 55)
            stroke.Thickness = 2
            stroke.Parent = tile
            local shine = Instance.new("UIGradient")
            shine.Color = ColorSequence.new(Color3.fromRGB(255, 200, 120), Color3.fromRGB(255, 40, 30))
            shine.Rotation = 90
            shine.Parent = tile
        end
    end
end
setCounter(money(START_JACKPOT, true))

-- Smaller jackpots
local smallInfo = {
    { "MAJOR", MAJOR, Color3.fromRGB(120, 40, 170) },
    { "MINOR", MINOR, Color3.fromRGB(30, 80, 190) },
    { "MINI", MINI, Color3.fromRGB(30, 140, 60) },
}
for i, info in ipairs(smallInfo) do
    local panel = Instance.new("Frame")
    panel.Name = info[1]
    panel.Position = UDim2.fromScale(0.06 + (i - 1) * 0.3, 0.6)
    panel.Size = UDim2.fromScale(0.28, 0.21)
    panel.BackgroundColor3 = info[3]
    panel.BorderSizePixel = 0
    panel.Parent = gui
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0.2, 0)
    corner.Parent = panel
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(212, 175, 55)
    stroke.Thickness = 3
    stroke.Parent = panel
    label(panel, info[1], 0.05, 0.05, 0.9, 0.38, Color3.fromRGB(255, 230, 150), Enum.Font.GothamBlack)
    local amount = label(panel, money(info[2], true), 0.05, 0.45, 0.9, 0.5, Color3.new(1, 1, 1), Enum.Font.GothamBold)
    amount.Name = "Amount"
end

-- Scrolling banner
local tickerFrame = Instance.new("Frame")
tickerFrame.Name = "TickerFrame"
tickerFrame.Position = UDim2.fromScale(0.03, 0.85)
tickerFrame.Size = UDim2.fromScale(0.94, 0.12)
tickerFrame.BackgroundColor3 = Color3.fromRGB(30, 8, 8)
tickerFrame.BorderSizePixel = 0
tickerFrame.ClipsDescendants = true
tickerFrame.Parent = gui
local tickerStroke = Instance.new("UIStroke")
tickerStroke.Color = Color3.fromRGB(212, 175, 55)
tickerStroke.Thickness = 2
tickerStroke.Parent = tickerFrame
label(tickerFrame, TICKER .. TICKER, 0, 0, 2, 1, Color3.fromRGB(150, 220, 230), Enum.Font.GothamBold).Name = "Ticker"

-- Sparkles and glow
if SPARKLES then
    local emitter = Instance.new("ParticleEmitter")
    emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    emitter.Color = ColorSequence.new(Color3.fromRGB(255, 220, 120))
    emitter.LightEmission = 1
    emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(0.5, 0.6), NumberSequenceKeypoint.new(1, 0) })
    emitter.Transparency = NumberSequence.new(0.2, 1)
    emitter.Lifetime = NumberRange.new(1, 2)
    emitter.Rate = 12
    emitter.Speed = NumberRange.new(0.5, 1.5)
    emitter.SpreadAngle = Vector2.new(60, 60)
    emitter.EmissionDirection = Enum.NormalId.Front
    emitter.Parent = screen
end
local glow = Instance.new("PointLight")
glow.Color = Color3.fromRGB(255, 120, 80)
glow.Range = math.clamp(W * 0.7, 16, 40)
glow.Brightness = 1
glow.Parent = screen

print(string.format("[Jackpot] Built the new MEGA JACKPOT display (%d x %d, %d bulbs)", W, H, bulbCount))
