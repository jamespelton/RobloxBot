-- LUXURY WALL SIGNS (marquee upgrade for the signs inside the casino)
-- Written by James. Changes are marked [REX]:
--
--   1. EVERY SIGN WOULD HAVE BEEN BUILT INTO THE WALL. The side of the old
--      sign the text is on was read with the face directions flipped: a
--      part's Front face points along its LookVector (this used
--      -LookVector), and Back the other way. The SLOTS, LUCKY 7, JACKPOT and
--      VIP marquees went into the wall behind them, and COAT CHECK and
--      REWARDS DESK came out facing backwards.
--   2. Clearing old frame pieces hid anything near a sign, which beside
--      COAT CHECK and REWARDS DESK meant parts of the potted palms. Only
--      pieces of the sign's own model are hidden now.
--   3. This runs once in Studio, like the other builds, instead of at every
--      server start. The chasing bulbs were animated by the server: about
--      575 bulbs changing every 0.3 s is thousands of property updates a
--      second sent to every player. The MarqueeBulbs LocalScript animates
--      them on each player's own machine instead, in the same pattern.
--      ANIMATE_BULBS below still switches it on and off.
--   4. Safe to re-run: it rebuilds from the signs it hid last time, instead
--      of finding nothing (they are invisible by then) and leaving the wall
--      empty. The original look is recorded once, so it can come back.
--   5. Parented into the Casino folder, like the other builds.
--   6. The marquee is about 4.5 studs wider than the old sign once the frame
--      and side diamonds are on, and COAT CHECK and REWARDS DESK each have a
--      column 0.4 studs past their edge, so both ran into a column. The
--      clear space beside each sign is measured and the marquee narrows to
--      fit when it has to.
--   7. The glow Halo behind each old wall sign is 4 studs bigger than the
--      sign and sits 1.75 studs behind it, outside both the size and depth
--      limits for old frame pieces, so it stuck out around the new frame.
--      The limits are raised; with note 2 they only reach pieces of the
--      sign's own model.

-- Settings:
local ANIMATE_BULBS = true
local SUBTITLES = {             -- small second line under certain signs (leave out a word for no subtitle)
    ["SLOTS"] = "OVER 100 GAMES",
    ["LUCKY 7"] = "★ 777 ★",
    ["JACKPOT"] = "WIN BIG TONIGHT",
    ["HIGH LIMIT VIP"] = "MEMBERS ONLY",
    ["VIP"] = "MEMBERS ONLY",
    ["REWARDS DESK"] = "JOIN TODAY",
    ["COAT CHECK"] = "COMPLIMENTARY",
}
-- Signs with these words are left alone
local SKIP_WORDS = { "CASHIER", "HIGH ROLLER", "RESPONSIBLY", "MEGA JACKPOT", "ROULETTE", "CRAPS", "PLEASE WAIT" }
-- Things with these words in their name are left alone
local SKIP_NAMES = { "grand", "luxury", "city", "parkinglot", "parkedcars", "slot", "table", "cashier", "bar", "introcar" }

local V = Vector3.new
local UP = V(0, 1, 0)
local HIDDEN = "LuxurySignHidden" -- [REX] marks what this script hid (note 4)

local GOLD = { Color = Color3.fromRGB(212, 175, 55), Material = Enum.Material.Metal, Reflectance = 0.35 }
local DARK_GOLD = { Color = Color3.fromRGB(150, 115, 35), Material = Enum.Material.Metal, Reflectance = 0.3 }
local LACQUER = { Color = Color3.fromRGB(12, 12, 14), Material = Enum.Material.SmoothPlastic, Reflectance = 0.15 }
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

local function skippedByName(inst)
    local p = inst
    while p and p ~= workspace do
        local name = string.lower(p.Name)
        for _, word in ipairs(SKIP_NAMES) do
            if string.find(name, word, 1, true) then
                return true
            end
        end
        p = p.Parent
    end
    return false
end

local function cleanText(text)
    return string.upper((string.gsub(text, "^%s*(.-)%s*$", "%1")))
end

----------------------------------------------------------------
-- Find the wall signs
----------------------------------------------------------------
local signs = {}
for _, gui in ipairs(workspace:GetDescendants()) do
    -- [REX] a sign this script hid last time still counts (note 4)
    if gui:IsA("SurfaceGui") and (gui.Enabled or gui:GetAttribute(HIDDEN)) then
        local part = gui.Adornee or gui.Parent
        if part and part:IsA("BasePart") and (part.Transparency < 0.99 or part:GetAttribute(HIDDEN)) and not skippedByName(part) then
            local labels = {}
            for _, d in ipairs(gui:GetDescendants()) do
                if d:IsA("TextLabel") and d.Text ~= "" then
                    table.insert(labels, d)
                end
            end
            if #labels == 1 then
                local label = labels[1]
                local text = cleanText(label.Text)
                local skip = #text < 2 or #text > 24
                for _, word in ipairs(SKIP_WORDS) do
                    if string.find(text, word, 1, true) then
                        skip = true
                    end
                end
                local cf, s = part.CFrame, part.Size
                -- [REX] a part's Front face points along LookVector (note 1)
                local faces = {
                    [Enum.NormalId.Front] = { cf.LookVector, s.X, s.Y, s.Z / 2 },
                    [Enum.NormalId.Back] = { -cf.LookVector, s.X, s.Y, s.Z / 2 },
                    [Enum.NormalId.Right] = { cf.RightVector, s.Z, s.Y, s.X / 2 },
                    [Enum.NormalId.Left] = { -cf.RightVector, s.Z, s.Y, s.X / 2 },
                }
                local f = faces[gui.Face]
                if not skip and f and math.abs(f[1].Y) < 0.2 then
                    local w, h = f[2], f[3]
                    if w >= 4 and w <= 60 and h >= 1.5 and h <= 10 then
                        table.insert(signs, { part = part, gui = gui, label = label, text = text, normal = V(f[1].X, 0, f[1].Z).Unit, w = w, h = h, half = f[4] })
                    end
                end
            end
        end
    end
end

----------------------------------------------------------------
-- Build each new sign
----------------------------------------------------------------
-- [REX] replace the previous build, in the Casino folder (notes 4, 5)
local casinoRoot = workspace:FindFirstChild("Casino") or workspace
local previous = casinoRoot:FindFirstChild("LuxurySigns") or workspace:FindFirstChild("LuxurySigns")
if previous then
    previous:Destroy()
end
local folder = Instance.new("Folder")
folder.Name = "LuxurySigns"
folder:SetAttribute("AnimateBulbs", ANIMATE_BULBS) -- read by the MarqueeBulbs LocalScript
folder.Parent = casinoRoot

local function hide(p)
    if p:GetAttribute("OldTransparency") == nil then
        p:SetAttribute("OldTransparency", p.Transparency)
    end
    p:SetAttribute(HIDDEN, true)
    p.Transparency = 1
    for _, d in ipairs(p:GetDescendants()) do
        if d:IsA("SurfaceGui") then
            d:SetAttribute(HIDDEN, true)
            d.Enabled = false
        elseif d:IsA("Decal") or d:IsA("Texture") then
            d.Transparency = 1
        end
    end
end

local bulbIndex = 0
local count = 0
for _, sign in ipairs(signs) do
    local faceCenter = sign.part.Position + sign.normal * sign.half
    local S = CFrame.lookAt(faceCenter, faceCenter + sign.normal) -- -Z points out from the wall
    local w, h = sign.w, sign.h
    local accent = sign.label.TextColor3
    local brightAccent = accent:Lerp(Color3.new(1, 1, 1), 0.15)

    -- Hide the old sign and any old frame pieces right around it
    -- [REX] only pieces of the sign's own model (note 2)
    local owner = sign.part:FindFirstAncestorWhichIsA("Model") or sign.part.Parent
    hide(sign.part)
    for _, p in ipairs(owner:GetDescendants()) do
        if p:IsA("BasePart") and p ~= sign.part and p.Transparency < 0.99 then
            local lp = S:PointToObjectSpace(p.Position)
            local biggest = math.max(p.Size.X, p.Size.Y, p.Size.Z)
            -- [REX] the old glow Halo behind each wall sign is 4 studs wider
            -- than the sign and 1.75 behind it, and was left poking out (note 7)
            if math.abs(lp.X) <= w / 2 + 2.5 and math.abs(lp.Y) <= h / 2 + 2.5 and math.abs(lp.Z) <= 2 and biggest <= math.max(w, h) + 6 then
                hide(p)
            end
        end
    end

    -- [REX] fit between whatever stands beside the sign (note 6)
    do
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = { folder, owner }
        local origin = faceCenter + sign.normal * 0.3
        local clear = math.huge
        for _, dir in ipairs({ S.RightVector, -S.RightVector }) do
            local hit = workspace:Raycast(origin, dir * (w / 2 + 6), params)
            if hit then
                clear = math.min(clear, (hit.Position - origin):Dot(dir))
            end
        end
        local reach = 1.15 + math.min(h * 0.45, 1.6) * 0.7072 -- frame + side diamond past the text
        if w / 2 + reach > clear - 0.1 then
            w = math.max(4, 2 * (clear - 0.1 - reach))
        end
    end

    current = Instance.new("Model")
    current.Name = "Sign_" .. sign.text
    current.Parent = folder

    -- Backing, double gold frame, neon border
    box(S * CFrame.new(0, 0, -0.15), V(w + 1.4, h + 1.4, 0.3), LACQUER)
    frameBars(S * CFrame.new(0, 0, -0.35), w + 1.1, h + 1.1, 0.4, 0.25, GOLD)
    frameBars(S * CFrame.new(0, 0, -0.38), w + 0.5, h + 0.5, 0.12, 0.2, DARK_GOLD)
    frameBars(S * CFrame.new(0, 0, -0.33), w + 0.15, h + 0.15, 0.1, 0.1, neon(accent))

    -- Glowing lettering
    local panel = box(S * CFrame.new(0, 0, -0.32), V(w, h, 0.02), { Transparency = 1 })
    local gui = Instance.new("SurfaceGui")
    gui.Face = Enum.NormalId.Front
    gui.LightInfluence = 0
    gui.Brightness = 2
    gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    gui.PixelsPerStud = 60
    gui.Parent = panel
    local subtitle = SUBTITLES[sign.text]
    local main = Instance.new("TextLabel")
    main.BackgroundTransparency = 1
    main.Size = UDim2.fromScale(0.96, subtitle and 0.66 or 0.86)
    main.Position = UDim2.fromScale(0.02, subtitle and 0.04 or 0.07)
    main.Text = "✦  " .. sign.text .. "  ✦"
    main.TextScaled = true
    main.Font = Enum.Font.GothamBlack
    main.TextColor3 = Color3.new(1, 1, 1)
    main.Parent = gui
    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, brightAccent),
        ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
        ColorSequenceKeypoint.new(1, brightAccent),
    })
    gradient.Rotation = 90
    gradient.Parent = main
    local glow = Instance.new("UIStroke")
    glow.Color = accent
    glow.Thickness = 4
    glow.Transparency = 0.35
    glow.Parent = main
    if subtitle then
        local sub = Instance.new("TextLabel")
        sub.BackgroundTransparency = 1
        sub.Size = UDim2.fromScale(0.7, 0.22)
        sub.Position = UDim2.fromScale(0.15, 0.72)
        sub.Text = subtitle
        sub.TextScaled = true
        sub.Font = Enum.Font.GothamBold
        sub.TextColor3 = Color3.fromRGB(255, 215, 110)
        sub.Parent = gui
    end

    -- Marquee bulbs around the frame
    local bw, bh = w + 1.1, h + 1.1
    local corners = { V(-bw / 2, bh / 2, 0), V(bw / 2, bh / 2, 0), V(bw / 2, -bh / 2, 0), V(-bw / 2, -bh / 2, 0) }
    for i = 1, 4 do
        local a, b = corners[i], corners[i % 4 + 1]
        local steps = math.max(1, math.floor((b - a).Magnitude / 1.0))
        for k = 0, steps - 1 do
            local p = a:Lerp(b, k / steps)
            local bulb = ball((S * CFrame.new(p.X, p.Y, -0.55)).Position, 0.32, { Color = BULB_ON, Material = Enum.Material.Neon })
            -- [REX] the MarqueeBulbs LocalScript chases them by this order (note 3)
            bulbIndex += 1
            bulb.Name = "MarqueeBulb"
            bulb:SetAttribute("Index", bulbIndex)
        end
    end

    -- Gold crest on top with a gem
    local crestY = bh / 2 + 0.2
    box(S * CFrame.new(0, crestY + 0.25, -0.3), V(math.min(w * 0.35, 6), 0.5, 0.3), GOLD)
    box(S * CFrame.new(0, crestY + 0.7, -0.3), V(math.min(w * 0.22, 4), 0.4, 0.3), GOLD)
    box(S * CFrame.new(0, crestY + 1.1, -0.3), V(math.min(w * 0.1, 2), 0.4, 0.3), GOLD)
    box(S * CFrame.new(0, crestY + 1.75, -0.32) * CFrame.Angles(0, 0, math.rad(45)), V(0.7, 0.7, 0.2), GOLD)
    box(S * CFrame.new(0, crestY + 1.75, -0.44) * CFrame.Angles(0, 0, math.rad(45)), V(0.45, 0.45, 0.06), neon(accent))

    -- Gold diamonds with gems on both ends
    for _, side in ipairs({ -1, 1 }) do
        local x = side * (bw / 2 + 0.6)
        box(S * CFrame.new(x, 0, -0.3) * CFrame.Angles(0, 0, math.rad(45)), V(math.min(h * 0.45, 1.6), math.min(h * 0.45, 1.6), 0.25), GOLD)
        box(S * CFrame.new(x, 0, -0.44) * CFrame.Angles(0, 0, math.rad(45)), V(math.min(h * 0.25, 0.9), math.min(h * 0.25, 0.9), 0.05), neon(accent))
        box(S * CFrame.new(side * (bw / 2 + 0.25), 0, -0.3), V(0.5, 0.15, 0.2), GOLD)
    end

    -- Soft colored glow on the wall
    local light = Instance.new("PointLight")
    light.Color = accent
    light.Range = math.clamp(w * 0.8, 10, 24)
    light.Brightness = 0.8
    light.Shadows = false
    light.Parent = panel

    count += 1
end

print(string.format("[Signs] Upgraded %d wall sign(s), %d marquee bulbs", count, bulbIndex))
