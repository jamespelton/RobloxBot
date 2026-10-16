-- CAR LOADING SCREEN (LocalScript inside ReplicatedFirst)
-- Written by James. Three changes, marked [REX]:
--   1. PreloadAsync is fed only instances that actually carry an asset. The
--      original passed every workspace descendant - 40,942 of them in this
--      place, of which 858 have anything to fetch (732 Decals, 126
--      ParticleEmitters). That is 1,024 round trips, almost all of them spent
--      on parts and welds with nothing to load, on the one screen where
--      stalling is most visible. Filtered, it is ~22 batches.
--   2. MAX_TIME, a hard stall guard. If preloading wedges, the screen would
--      otherwise sit there until the player found the Skip button.
--   3. The vertical CASINO tower sign builds its line breaks from
--      string.char(10) rather than a backslash-n escape, which the MCP bridge
--      rewrites into real newlines and breaks the literal.
-- The art and animation are untouched.

-- Settings:
local GAME_NAME = "GOLDEN SPIRE CASINO"
local CAR_COLOR = Color3.fromRGB(200, 25, 35)
local MIN_TIME = 5      -- shortest time (seconds) the loading screen shows
local SKIP_AFTER = 6    -- seconds before the Skip button appears
local MAX_TIME = 25     -- [REX] give up and let the player in regardless
local TIPS = {
    "Tip: VIP parking is right by the front door.",
    "Tip: Check out the slot machines inside!",
    "Tip: Invite your friends to play together.",
    "Tip: Look for the gold signs to find the VIP area.",
}

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ContentProvider = game:GetService("ContentProvider")

ReplicatedFirst:RemoveDefaultLoadingScreen()

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

----------------------------------------------------------------
-- UI helpers
----------------------------------------------------------------
local function new(className, props, parent)
    local obj = Instance.new(className)
    for key, value in pairs(props) do
        obj[key] = value
    end
    obj.Parent = parent
    return obj
end

local function frame(props, parent)
    props.BorderSizePixel = 0
    return new("Frame", props, parent)
end

local function round(parent, scale)
    new("UICorner", { CornerRadius = UDim.new(scale or 1, 0) }, parent)
end

local function gradient(parent, colors, rotation)
    local points = {}
    for i, color in ipairs(colors) do
        table.insert(points, ColorSequenceKeypoint.new((i - 1) / (#colors - 1), color))
    end
    return new("UIGradient", { Color = ColorSequence.new(points), Rotation = rotation or 0 }, parent)
end

-- [REX] The MCP bridge rewrites a backslash-n inside double quotes as a real
-- newline, which splits the literal across two lines and will not compile, so
-- the vertical tower sign builds its line breaks from string.char(10).
local NL = string.char(10)

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local GOLD = Color3.fromRGB(212, 175, 55)
local GOLD_LIGHT = Color3.fromRGB(255, 235, 150)
local WARM = Color3.fromRGB(255, 215, 140)

----------------------------------------------------------------
-- Screen
----------------------------------------------------------------
local gui = new("ScreenGui", {
    Name = "LoadingScreen",
    IgnoreGuiInset = true,
    ResetOnSpawn = false,
    DisplayOrder = 1000,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui)

local root = new("CanvasGroup", {
    Size = UDim2.fromScale(1, 1),
    BackgroundColor3 = Color3.fromRGB(10, 8, 25),
    BorderSizePixel = 0,
}, gui)

-- Night sky
local sky = frame({ Size = UDim2.fromScale(1, 0.75), BackgroundColor3 = WHITE }, root)
gradient(sky, { Color3.fromRGB(12, 10, 35), Color3.fromRGB(35, 20, 60), Color3.fromRGB(80, 35, 80) }, 90)

-- Stars
local stars = {}
for _ = 1, 60 do
    local size = math.random(2, 3)
    local star = frame({
        Position = UDim2.fromScale(math.random(), math.random() * 0.5),
        Size = UDim2.fromOffset(size, size),
        BackgroundColor3 = WHITE,
    }, root)
    round(star)
    table.insert(stars, { star = star, phase = math.random() * 6, speed = 1 + math.random() * 2 })
end

-- Moon with glow
local moonGlow = frame({
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.85, 0.13),
    Size = UDim2.fromScale(0.2, 0.2),
    SizeConstraint = Enum.SizeConstraint.RelativeYY,
    BackgroundColor3 = Color3.fromRGB(255, 245, 220),
    BackgroundTransparency = 0.88,
}, root)
round(moonGlow)
local moon = frame({
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.85, 0.13),
    Size = UDim2.fromScale(0.09, 0.09),
    SizeConstraint = Enum.SizeConstraint.RelativeYY,
    BackgroundColor3 = Color3.fromRGB(245, 240, 215),
}, root)
round(moon)

----------------------------------------------------------------
-- Scrolling layers (two copies side by side that loop forever)
----------------------------------------------------------------
local layers = {}
local function loopLayer(speed, build)
    local holder = frame({ Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, root)
    local copies = {}
    for i = 1, 2 do
        local copy = frame({ Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, holder)
        build(copy, Random.new(42))
        copies[i] = copy
    end
    local layer = { copies = copies, speed = speed, offset = 0 }
    table.insert(layers, layer)
    return layer
end

-- City skyline with a casino tower
loopLayer(0.03, function(f, r)
    local x = 0
    while x < 1 do
        local w = math.min(r:NextNumber(0.04, 0.09), 1 - x)
        local h = r:NextNumber(0.08, 0.26)
        local building = frame({
            Position = UDim2.fromScale(x, 0.72 - h),
            Size = UDim2.fromScale(w, h),
            BackgroundColor3 = Color3.fromRGB(25, 22, 42),
        }, f)
        for row = 0, math.floor(h / 0.03) - 1 do
            for col = 0, math.floor(w / 0.018) - 1 do
                if r:NextNumber() < 0.45 then
                    frame({
                        Position = UDim2.fromScale((col * 0.018 + 0.006) / w, (row * 0.03 + 0.012) / h),
                        Size = UDim2.fromScale(0.008 / w, 0.014 / h),
                        BackgroundColor3 = r:NextNumber() < 0.8 and WARM or Color3.fromRGB(150, 200, 255),
                        BackgroundTransparency = r:NextNumber(0, 0.4),
                    }, building)
                end
            end
        end
        x = x + w + r:NextNumber(0, 0.01)
    end

    local tower = frame({
        Position = UDim2.fromScale(0.46, 0.36),
        Size = UDim2.fromScale(0.06, 0.36),
        BackgroundColor3 = Color3.fromRGB(35, 28, 50),
    }, f)
    frame({ Position = UDim2.fromScale(-0.1, 0), Size = UDim2.fromScale(1.2, 0.04), BackgroundColor3 = GOLD }, tower)
    frame({ Position = UDim2.fromScale(0.45, -0.12), Size = UDim2.fromScale(0.1, 0.12), BackgroundColor3 = GOLD }, tower)
    local sign = new("TextLabel", {
        Position = UDim2.fromScale(0.15, 0.1),
        Size = UDim2.fromScale(0.7, 0.75),
        BackgroundTransparency = 1,
        Text = table.concat({ "C", "A", "S", "I", "N", "O" }, NL),
        TextScaled = true,
        Font = Enum.Font.GothamBlack,
        TextColor3 = GOLD_LIGHT,
    }, tower)
    new("UIStroke", { Color = Color3.fromRGB(255, 170, 40), Thickness = 1.5, Transparency = 0.3 }, sign)
end)

-- Road
frame({ Position = UDim2.fromScale(0, 0.72), Size = UDim2.fromScale(1, 0.28), BackgroundColor3 = Color3.fromRGB(32, 32, 36) }, root)
frame({ Position = UDim2.fromScale(0, 0.72), Size = UDim2.fromScale(1, 0.04), BackgroundColor3 = Color3.fromRGB(85, 85, 90) }, root)
frame({ Position = UDim2.fromScale(0, 0.76), Size = UDim2.fromScale(1, 0.006), BackgroundColor3 = Color3.fromRGB(140, 140, 145) }, root)
frame({ Position = UDim2.fromScale(0, 0.955), Size = UDim2.fromScale(1, 0.005), BackgroundColor3 = Color3.fromRGB(200, 200, 200) }, root)

-- Street lamps and road lines rushing past
local roadLayer = loopLayer(0.45, function(f)
    for i = 0, 3 do
        local x = i * 0.25 + 0.1
        frame({ Position = UDim2.fromScale(x, 0.56), Size = UDim2.fromScale(0.004, 0.17), BackgroundColor3 = Color3.fromRGB(45, 45, 50) }, f)
        frame({ Position = UDim2.fromScale(x, 0.56), Size = UDim2.fromScale(0.03, 0.006), BackgroundColor3 = Color3.fromRGB(45, 45, 50) }, f)
        frame({ Position = UDim2.fromScale(x + 0.022, 0.562), Size = UDim2.fromScale(0.018, 0.01), BackgroundColor3 = WARM }, f)
        local glow = frame({
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(x + 0.031, 0.575),
            Size = UDim2.fromScale(0.09, 0.09),
            SizeConstraint = Enum.SizeConstraint.RelativeYY,
            BackgroundColor3 = WARM,
            BackgroundTransparency = 0.85,
        }, f)
        round(glow)
    end
    for i = 0, 7 do
        frame({ Position = UDim2.fromScale(i * 0.125, 0.855), Size = UDim2.fromScale(0.06, 0.01), BackgroundColor3 = Color3.fromRGB(230, 190, 40) }, f)
    end
end)

----------------------------------------------------------------
-- The car
----------------------------------------------------------------
local puffLayer = frame({ Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, root)

local car = frame({
    AnchorPoint = Vector2.new(0.5, 1),
    Position = UDim2.fromScale(0.1, 0.92),
    Size = UDim2.fromScale(0.42, 0.17),
    SizeConstraint = Enum.SizeConstraint.RelativeYY,
    BackgroundTransparency = 1,
}, root)

local light = CAR_COLOR:Lerp(WHITE, 0.35)
local dark = CAR_COLOR:Lerp(BLACK, 0.45)

-- Shadow and headlight beam
local shadow = frame({ Position = UDim2.fromScale(0.04, 0.9), Size = UDim2.fromScale(0.92, 0.14), BackgroundColor3 = BLACK, BackgroundTransparency = 0.55 }, car)
round(shadow)
local beam = frame({ Position = UDim2.fromScale(0.96, 0.38), Size = UDim2.fromScale(0.8, 0.32), BackgroundColor3 = Color3.fromRGB(255, 240, 190) }, car)
new("UIGradient", { Transparency = NumberSequence.new(0.4, 1) }, beam)

-- Cabin and windows
local cabin = frame({ Position = UDim2.fromScale(0.2, 0.1), Size = UDim2.fromScale(0.52, 0.44), BackgroundColor3 = WHITE }, car)
round(cabin, 0.45)
gradient(cabin, { light, CAR_COLOR }, 90)
for _, x in ipairs({ 0.09, 0.53 }) do
    local window = frame({ Position = UDim2.fromScale(x, 0.15), Size = UDim2.fromScale(0.38, 0.6), BackgroundColor3 = WHITE }, cabin)
    round(window, 0.35)
    gradient(window, { Color3.fromRGB(200, 230, 250), Color3.fromRGB(90, 140, 180) }, 45)
end

-- Body
local body = frame({ Position = UDim2.fromScale(0, 0.42), Size = UDim2.fromScale(1, 0.38), BackgroundColor3 = WHITE }, car)
round(body, 0.35)
gradient(body, { light, CAR_COLOR, dark }, 90)

-- Details
frame({ Position = UDim2.fromScale(0.03, 0.6), Size = UDim2.fromScale(0.94, 0.03), BackgroundColor3 = GOLD }, car)
frame({ Position = UDim2.fromScale(0.47, 0.45), Size = UDim2.fromScale(0.006, 0.3), BackgroundColor3 = dark }, car)
frame({ Position = UDim2.fromScale(0.52, 0.5), Size = UDim2.fromScale(0.05, 0.03), BackgroundColor3 = Color3.fromRGB(220, 220, 225) }, car)
frame({ Position = UDim2.fromScale(0.3, 0.5), Size = UDim2.fromScale(0.05, 0.03), BackgroundColor3 = Color3.fromRGB(220, 220, 225) }, car)
local headlight = frame({ Position = UDim2.fromScale(0.94, 0.48), Size = UDim2.fromScale(0.05, 0.09), BackgroundColor3 = Color3.fromRGB(255, 250, 220) }, car)
round(headlight, 0.4)
local taillight = frame({ Position = UDim2.fromScale(0.006, 0.47), Size = UDim2.fromScale(0.035, 0.1), BackgroundColor3 = Color3.fromRGB(255, 40, 40) }, car)
round(taillight, 0.4)
local frontBumper = frame({ Position = UDim2.fromScale(0.9, 0.7), Size = UDim2.fromScale(0.1, 0.07), BackgroundColor3 = Color3.fromRGB(30, 30, 32) }, car)
round(frontBumper, 0.5)
local rearBumper = frame({ Position = UDim2.fromScale(0, 0.7), Size = UDim2.fromScale(0.1, 0.07), BackgroundColor3 = Color3.fromRGB(30, 30, 32) }, car)
round(rearBumper, 0.5)

-- Wheels
local spokes = {}
local function wheel(x)
    local arch = frame({
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(x, 0.77),
        Size = UDim2.fromScale(0.47, 0.47),
        SizeConstraint = Enum.SizeConstraint.RelativeYY,
        BackgroundColor3 = Color3.fromRGB(20, 8, 10),
    }, car)
    round(arch)
    local tire = frame({
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(x, 0.8),
        Size = UDim2.fromScale(0.4, 0.4),
        SizeConstraint = Enum.SizeConstraint.RelativeYY,
        BackgroundColor3 = Color3.fromRGB(20, 20, 22),
    }, car)
    round(tire)
    local rim = frame({
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(0.62, 0.62),
        BackgroundColor3 = Color3.fromRGB(180, 180, 185),
    }, tire)
    round(rim)
    for k = 0, 2 do
        local spoke = frame({
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromScale(0.14, 0.95),
            BackgroundColor3 = Color3.fromRGB(80, 80, 85),
        }, rim)
        table.insert(spokes, { spoke = spoke, base = k * 60 })
    end
    local hub = frame({
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(0.3, 0.3),
        BackgroundColor3 = GOLD,
    }, rim)
    round(hub)
end
wheel(0.22)
wheel(0.78)

----------------------------------------------------------------
-- Text, progress bar, skip button
----------------------------------------------------------------
local title = new("TextLabel", {
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.fromScale(0.5, 0.06),
    Size = UDim2.fromScale(0.8, 0.1),
    BackgroundTransparency = 1,
    Text = GAME_NAME,
    TextScaled = true,
    Font = Enum.Font.GothamBlack,
    TextColor3 = WHITE,
}, root)
local shine = gradient(title, { GOLD, GOLD, GOLD_LIGHT, GOLD, GOLD })
new("UIStroke", { Color = Color3.fromRGB(60, 40, 0), Thickness = 2 }, title)

local subtitle = new("TextLabel", {
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.fromScale(0.5, 0.17),
    Size = UDim2.fromScale(0.4, 0.045),
    BackgroundTransparency = 1,
    Text = "Loading",
    TextScaled = true,
    Font = Enum.Font.GothamMedium,
    TextColor3 = Color3.fromRGB(230, 230, 240),
}, root)

local barBack = frame({
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.fromScale(0.5, 0.235),
    Size = UDim2.fromScale(0.4, 0.018),
    BackgroundColor3 = Color3.fromRGB(40, 35, 60),
}, root)
round(barBack)
new("UIStroke", { Color = GOLD, Thickness = 1, Transparency = 0.5 }, barBack)
local barFill = frame({ Size = UDim2.fromScale(0, 1), BackgroundColor3 = WHITE }, barBack)
round(barFill)
gradient(barFill, { GOLD, GOLD_LIGHT })

local percent = new("TextLabel", {
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.fromScale(0.5, 0.26),
    Size = UDim2.fromScale(0.2, 0.032),
    BackgroundTransparency = 1,
    Text = "0%",
    TextScaled = true,
    Font = Enum.Font.GothamBold,
    TextColor3 = GOLD_LIGHT,
}, root)

local tip = new("TextLabel", {
    AnchorPoint = Vector2.new(0.5, 1),
    Position = UDim2.fromScale(0.5, 0.99),
    Size = UDim2.fromScale(0.8, 0.028),
    BackgroundTransparency = 1,
    Text = TIPS[1],
    TextScaled = true,
    Font = Enum.Font.Gotham,
    TextColor3 = Color3.fromRGB(200, 200, 210),
}, root)

local skip = new("TextButton", {
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.fromScale(0.98, 0.04),
    Size = UDim2.fromScale(0.1, 0.05),
    BackgroundColor3 = Color3.fromRGB(40, 35, 60),
    Text = "SKIP  >",
    TextScaled = true,
    Font = Enum.Font.GothamBold,
    TextColor3 = WHITE,
    Visible = false,
    AutoButtonColor = true,
}, root)
round(skip, 0.3)
new("UIStroke", { Color = GOLD, Thickness = 1.5 }, skip)
new("UIPadding", { PaddingTop = UDim.new(0.2, 0), PaddingBottom = UDim.new(0.2, 0) }, skip)

local skipped = false
skip.MouseButton1Click:Connect(function()
    skipped = true
end)

----------------------------------------------------------------
-- Loading the game
----------------------------------------------------------------
local loadProgress = 0
local doneLoading = false

task.spawn(function()
    if not game:IsLoaded() then
        game.Loaded:Wait()
    end
    loadProgress = 0.3

    -- [REX] Only queue things that actually carry an asset. Handing every
    -- workspace descendant to PreloadAsync means 40,942 instances here against
    -- 858 that have anything to fetch, so 1,024 round trips are spent almost
    -- entirely on parts and welds with no content. Filtered it is ~22 batches.
    local queue = {}
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("Decal") or d:IsA("Texture") or d:IsA("Sound")
            or d:IsA("SurfaceAppearance") or d:IsA("ParticleEmitter")
            or d:IsA("ImageLabel") or d:IsA("ImageButton")
            or ((d:IsA("MeshPart") or d:IsA("SpecialMesh")) and d.MeshId ~= "")
        then
            table.insert(queue, d)
        end
    end

    if #queue == 0 then
        loadProgress = 1
        doneLoading = true
        return
    end

    local batch = 40
    for i = 1, #queue, batch do
        local last = math.min(i + batch - 1, #queue)
        local slice = table.move(queue, i, last, 1, {})
        pcall(function()
            ContentProvider:PreloadAsync(slice)
        end)
        loadProgress = 0.3 + 0.7 * last / #queue
    end
    loadProgress = 1
    doneLoading = true
end)

----------------------------------------------------------------
-- Animation
----------------------------------------------------------------
local startTime = os.clock()
local shown = 0
local wheelAngle = 0
local puffTimer = 0
local tipIndex = 1
local tipTimer = 0
local exiting = false
local connection

local function spawnPuff()
    local px = car.AbsolutePosition.X - root.AbsolutePosition.X + car.AbsoluteSize.X * 0.02
    local py = car.AbsolutePosition.Y - root.AbsolutePosition.Y + car.AbsoluteSize.Y * 0.72
    local size = car.AbsoluteSize.Y * 0.08
    local puff = frame({
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromOffset(px, py),
        Size = UDim2.fromOffset(size, size),
        BackgroundColor3 = Color3.fromRGB(190, 190, 200),
        BackgroundTransparency = 0.45,
    }, puffLayer)
    round(puff)
    local tween = TweenService:Create(puff, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Position = UDim2.fromOffset(px - size * 5, py - size * 1.5),
        Size = UDim2.fromOffset(size * 3, size * 3),
        BackgroundTransparency = 1,
    })
    tween.Completed:Connect(function()
        puff:Destroy()
    end)
    tween:Play()
end

local function finish()
    exiting = true
    for _, layer in ipairs(layers) do
        layer.speed = layer.speed * 1.8
    end
    local drive = TweenService:Create(car, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Position = UDim2.fromScale(1.35, 0.92),
    })
    drive:Play()
    drive.Completed:Wait()
    local fade = TweenService:Create(root, TweenInfo.new(0.6), { GroupTransparency = 1 })
    fade:Play()
    fade.Completed:Wait()
    connection:Disconnect()
    gui:Destroy()
end

connection = RunService.RenderStepped:Connect(function(dt)
    local now = os.clock()
    local elapsed = now - startTime

    -- Progress (never faster than MIN_TIME so the animation can be seen)
    local target = math.min(loadProgress, elapsed / MIN_TIME)
    shown = shown + (target - shown) * math.min(1, dt * 4)
    barFill.Size = UDim2.fromScale(shown, 1)
    percent.Text = math.floor(shown * 100 + 0.5) .. "%"
    subtitle.Text = "Loading" .. string.rep(".", math.floor(elapsed * 2) % 4)

    -- Scrolling layers
    for _, layer in ipairs(layers) do
        layer.offset = (layer.offset + layer.speed * dt) % 1
        layer.copies[1].Position = UDim2.fromScale(-layer.offset, 0)
        layer.copies[2].Position = UDim2.fromScale(1 - layer.offset, 0)
    end

    -- Car moves across with progress, bounces slightly, wheels spin
    if not exiting then
        local bounce = math.sin(now * 15) * 1.5
        car.Position = UDim2.new(0.1 + 0.75 * shown, 0, 0.92, bounce)
    end
    wheelAngle = (wheelAngle + dt * 720 * (roadLayer.speed / 0.45)) % 360
    for _, s in ipairs(spokes) do
        s.spoke.Rotation = wheelAngle + s.base
    end

    -- Exhaust puffs
    puffTimer += dt
    if puffTimer > 0.12 then
        puffTimer = 0
        spawnPuff()
    end

    -- Twinkling stars and shiny title
    for _, s in ipairs(stars) do
        s.star.BackgroundTransparency = 0.15 + 0.6 * (0.5 + 0.5 * math.sin(now * s.speed + s.phase))
    end
    shine.Offset = Vector2.new(((now * 0.5) % 2) - 1, 0)

    -- Tips
    tipTimer += dt
    if tipTimer > 4 then
        tipTimer = 0
        tipIndex = tipIndex % #TIPS + 1
        tip.Text = TIPS[tipIndex]
    end

    -- Skip button
    if elapsed > SKIP_AFTER and not exiting then
        skip.Visible = true
    end

    -- Done? [REX] MAX_TIME is the stall guard; without it a wedged preload
    -- leaves the player staring at the screen until they find Skip.
    if not exiting and (skipped
        or (doneLoading and elapsed >= MIN_TIME and shown > 0.99)
        or elapsed >= MAX_TIME)
    then
        skip.Visible = false
        task.spawn(finish)
    end
end)
