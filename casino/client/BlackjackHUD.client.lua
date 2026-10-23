-- BLACKJACK SCREEN + CAMERA + TUTORIAL v2 (LocalScript in StarterPlayer > StarterPlayerScripts)
-- Casino changes: tutorial line breaks use NL (the Studio bridge mangles backslash-n),
-- and the round chip buttons set their existing UICorner instead of adding a second.
-- (Sit & Play prompts are removed by BlackjackTableAdjust - you click a chair to sit.)
local MIN_BET, MAX_BET = 10, 500
local DEFAULT_BET = 50
local CHIP_VALUES = { 10, 25, 50, 100, 250 }
local SWING_TIME = 1.3
local AUTO_TUTORIAL = true

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera
local remote = ReplicatedStorage:WaitForChild("BlackjackRemote")
local V = Vector3.new
local UP = V(0, 1, 0)
local NL = string.char(10)
local function flat(v)
    return V(v.X, 0, v.Z)
end

local BG = Color3.fromRGB(16, 16, 20)
local GOLD = Color3.fromRGB(201, 168, 92)
local TEXT = Color3.fromRGB(235, 235, 235)
local MUTED = Color3.fromRGB(150, 150, 158)

----------------------------------------------------------------
-- UI helpers
----------------------------------------------------------------
local function new(class, props, parent)
    local o = Instance.new(class)
    for k, v in pairs(props) do
        o[k] = v
    end
    o.Parent = parent
    return o
end
local function rounded(o, px)
    local existing = o:FindFirstChildOfClass("UICorner")
    if existing then
        existing.CornerRadius = UDim.new(0, px or 8)
        return
    end
    new("UICorner", { CornerRadius = UDim.new(0, px or 8) }, o)
end
local function outline(o, color, transparency)
    new("UIStroke", {
        Color = color or GOLD, Transparency = transparency or 0.55, Thickness = 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, o)
end
local function panel(props, parent)
    props.BackgroundColor3 = BG
    props.BackgroundTransparency = props.BackgroundTransparency or 0.15
    props.BorderSizePixel = 0
    local f = new("Frame", props, parent)
    rounded(f, 10)
    outline(f)
    return f
end
local function text(props, parent)
    props.BackgroundTransparency = 1
    props.Font = props.Font or Enum.Font.GothamMedium
    props.TextColor3 = props.TextColor3 or TEXT
    props.TextSize = props.TextSize or 16
    return new("TextLabel", props, parent)
end
local function button(label, color, textColor, size, parent)
    local b = new("TextButton", {
        Size = size, BackgroundColor3 = color, BorderSizePixel = 0, AutoButtonColor = true,
        Text = label, Font = Enum.Font.GothamBold, TextSize = 15, TextColor3 = textColor or TEXT,
    }, parent)
    rounded(b, 8)
    return b
end
local function row(parent, padding)
    return new("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, padding or 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, parent)
end
local function commas(n)
    local s = tostring(n)
    repeat
        local k
        s, k = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
    until k == 0
    return s
end

----------------------------------------------------------------
-- Game screen
----------------------------------------------------------------
local gui = new("ScreenGui", {
    Name = "BlackjackHUD", ResetOnSpawn = false, Enabled = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui)
local uiScale = new("UIScale", {}, gui)
local function rescale()
    local size = camera.ViewportSize
    uiScale.Scale = math.clamp(math.min(size.Y / 900, size.X / 1300), 0.65, 1.1)
end
rescale()
camera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)

-- Status bar (top middle)
local status = panel({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 12), Size = UDim2.fromOffset(460, 40) }, gui)
local statusText = text({ Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -28, 1, 0), Font = Enum.Font.GothamBold, TextSize = 17 }, status)
local timerLine = new("Frame", {
    Position = UDim2.new(0, 10, 1, -3), Size = UDim2.new(0, 0, 0, 2),
    BackgroundColor3 = GOLD, BorderSizePixel = 0,
}, status)

-- Result notice (fades in under the status bar)
local toast = panel({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 60), Size = UDim2.fromOffset(320, 34), Visible = false }, gui)
local toastText = text({ Size = UDim2.fromScale(1, 1), Font = Enum.Font.GothamBold, TextSize = 16 }, toast)

-- Chips (top left)
local chipsPanel = panel({ Position = UDim2.fromOffset(16, 12), Size = UDim2.fromOffset(170, 40) }, gui)
chipsPanel.Visible = false
text({ Position = UDim2.fromOffset(14, 0), Size = UDim2.new(0, 60, 1, 0), Text = "CHIPS", TextSize = 12, TextColor3 = MUTED, TextXAlignment = Enum.TextXAlignment.Left }, chipsPanel)
local chipsText = text({ Position = UDim2.fromOffset(60, 0), Size = UDim2.new(1, -74, 1, 0), Font = Enum.Font.GothamBold, TextSize = 18, TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Right }, chipsPanel)

-- Control bar (bottom middle)
local controls = panel({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -16), Size = UDim2.fromOffset(580, 68), Visible = false }, gui)
local function infoBlock(parent, caption)
    local f = new("Frame", { Size = UDim2.fromOffset(96, 48), BackgroundTransparency = 1, LayoutOrder = 0 }, parent)
    text({ Size = UDim2.new(1, 0, 0, 16), Text = caption, TextSize = 11, TextColor3 = MUTED }, f)
    return text({ Position = UDim2.fromOffset(0, 16), Size = UDim2.new(1, 0, 0, 30), Font = Enum.Font.GothamBold, TextSize = 22, TextColor3 = GOLD }, f)
end

local betMode = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, controls)
row(betMode, 8)
local betAmount = infoBlock(betMode, "YOUR BET")
local chipColors = {
    Color3.fromRGB(40, 70, 150), Color3.fromRGB(35, 110, 70), Color3.fromRGB(150, 40, 45),
    Color3.fromRGB(30, 30, 34), Color3.fromRGB(100, 55, 130),
}
local chipButtons = {}
for i, value in ipairs(CHIP_VALUES) do
    local b = button(tostring(value), chipColors[i], TEXT, UDim2.fromOffset(42, 42), betMode)
    b.TextSize = 13
    b.LayoutOrder = i
    rounded(b, 21)
    outline(b, Color3.new(1, 1, 1), 0.4)
    chipButtons[i] = { button = b, value = value }
end
local clearButton = button("Clear", Color3.fromRGB(42, 42, 50), MUTED, UDim2.fromOffset(64, 34), betMode)
clearButton.LayoutOrder = 10
local placeButton = button("Place Bet", GOLD, Color3.fromRGB(24, 18, 8), UDim2.fromOffset(124, 42), betMode)
placeButton.LayoutOrder = 11

local actionMode = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false }, controls)
row(actionMode, 10)
local handTotal = infoBlock(actionMode, "YOUR HAND")
local hitButton = button("Hit", Color3.fromRGB(34, 110, 70), TEXT, UDim2.fromOffset(124, 42), actionMode)
hitButton.LayoutOrder = 1
local standButton = button("Stand", Color3.fromRGB(150, 40, 45), TEXT, UDim2.fromOffset(124, 42), actionMode)
standButton.LayoutOrder = 2
local doubleButton = button("Double", Color3.fromRGB(42, 42, 50), GOLD, UDim2.fromOffset(124, 42), actionMode)
doubleButton.LayoutOrder = 3
outline(doubleButton, GOLD, 0.4)

-- Leave button (bottom right, above the HOW TO PLAY button)
local leaveButton = button("Leave Table", BG, MUTED, UDim2.fromOffset(150, 36), gui)
leaveButton.AnchorPoint = Vector2.new(1, 1)
leaveButton.Position = UDim2.new(1, -16, 1, -76)
leaveButton.BackgroundTransparency = 0.15
outline(leaveButton)

----------------------------------------------------------------
-- Tutorial with card pictures
----------------------------------------------------------------
local TGOLD = Color3.fromRGB(212, 175, 55)
local tutGui = new("ScreenGui", {
    Name = "BlackjackTutorial", ResetOnSpawn = false, Enabled = false, DisplayOrder = 10,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui)
local function sCorner(o, r)
    new("UICorner", { CornerRadius = UDim.new(r, 0) }, o)
end
local function sStroke(o, color, thickness)
    new("UIStroke", { Color = color, Thickness = thickness, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, o)
end
local function tLabel(parent, txt, pos, size, color, font)
    return new("TextLabel", {
        Position = pos, Size = size, BackgroundTransparency = 1, Text = txt, TextScaled = true,
        RichText = true, TextWrapped = true, Font = font or Enum.Font.Gotham, TextColor3 = color or Color3.new(1, 1, 1),
    }, parent)
end
local function tButton(parent, txt, pos, size, bg)
    local b = new("TextButton", {
        Position = pos, Size = size, BackgroundColor3 = bg or Color3.fromRGB(40, 30, 50), Text = txt,
        TextScaled = true, Font = Enum.Font.GothamBold, TextColor3 = Color3.new(1, 1, 1), AutoButtonColor = true,
    }, parent)
    sCorner(b, 0.25)
    sStroke(b, TGOLD, 1.5)
    new("UIPadding", { PaddingTop = UDim.new(0.18, 0), PaddingBottom = UDim.new(0.18, 0) }, b)
    return b
end

local helpButton = tButton(tutGui, "?  HOW TO PLAY", UDim2.new(1, -16, 1, -16), UDim2.fromOffset(150, 48), Color3.fromRGB(120, 20, 30))
helpButton.AnchorPoint = Vector2.new(1, 1)

local tutPanel = new("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.62, 0.72),
    BackgroundColor3 = Color3.fromRGB(16, 12, 20), Visible = false,
}, tutGui)
sCorner(tutPanel, 0.03)
sStroke(tutPanel, TGOLD, 3)
new("UISizeConstraint", { MaxSize = Vector2.new(780, 560), MinSize = Vector2.new(320, 300) }, tutPanel)
local feltStripe = new("Frame", { Size = UDim2.fromScale(1, 0.16), BackgroundColor3 = Color3.fromRGB(20, 95, 45), BorderSizePixel = 0 }, tutPanel)
sCorner(feltStripe, 0.2)

tLabel(tutPanel, "HOW TO PLAY  <font color='#FFD36B'>BLACKJACK</font>", UDim2.fromScale(0.05, 0.025), UDim2.fromScale(0.8, 0.11), Color3.new(1, 1, 1), Enum.Font.GothamBlack)
local closeButton = tButton(tutPanel, "X", UDim2.fromScale(0.9, 0.03), UDim2.fromScale(0.07, 0.1), Color3.fromRGB(120, 20, 30))
local pageTitle = tLabel(tutPanel, "", UDim2.fromScale(0.05, 0.19), UDim2.fromScale(0.9, 0.08), Color3.fromRGB(255, 215, 110), Enum.Font.GothamBlack)
local cardRow = new("Frame", { Position = UDim2.fromScale(0.05, 0.29), Size = UDim2.fromScale(0.9, 0.22), BackgroundTransparency = 1 }, tutPanel)
new("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
    VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0.015, 0), SortOrder = Enum.SortOrder.LayoutOrder,
}, cardRow)
local body = tLabel(tutPanel, "", UDim2.fromScale(0.06, 0.53), UDim2.fromScale(0.88, 0.3), Color3.fromRGB(235, 235, 235))
body.TextXAlignment = Enum.TextXAlignment.Left
body.TextYAlignment = Enum.TextYAlignment.Top
local backButton = tButton(tutPanel, "BACK", UDim2.fromScale(0.05, 0.86), UDim2.fromScale(0.22, 0.1))
local nextButton = tButton(tutPanel, "NEXT", UDim2.fromScale(0.73, 0.86), UDim2.fromScale(0.22, 0.1), Color3.fromRGB(20, 95, 45))
local dots = new("Frame", { Position = UDim2.fromScale(0.3, 0.88), Size = UDim2.fromScale(0.4, 0.06), BackgroundTransparency = 1 }, tutPanel)
new("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
    VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0.03, 0),
}, dots)

-- A drawn playing card
local cardOrder = 0
local function makeCard(rank, red, faceDown)
    cardOrder += 1
    local card = new("Frame", {
        Size = UDim2.fromScale(0.13, 1), LayoutOrder = cardOrder,
        BackgroundColor3 = faceDown and Color3.fromRGB(150, 20, 30) or Color3.fromRGB(250, 250, 245),
    }, cardRow)
    sCorner(card, 0.12)
    sStroke(card, faceDown and TGOLD or Color3.fromRGB(180, 180, 180), 2)
    new("UIAspectRatioConstraint", { AspectRatio = 0.7 }, card)
    if faceDown then
        local inner = new("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromScale(0.7, 0.8), BackgroundTransparency = 1,
        }, card)
        sStroke(inner, TGOLD, 2)
        sCorner(inner, 0.1)
    else
        local color = red and Color3.fromRGB(200, 25, 30) or Color3.fromRGB(20, 20, 20)
        local small = tLabel(card, rank, UDim2.fromScale(0.06, 0.03), UDim2.fromScale(0.4, 0.25), color, Enum.Font.GothamBlack)
        small.TextXAlignment = Enum.TextXAlignment.Left
        tLabel(card, rank, UDim2.fromScale(0.1, 0.28), UDim2.fromScale(0.8, 0.5), color, Enum.Font.GothamBlack)
    end
end
local function makeSymbol(txt)
    cardOrder += 1
    local l = tLabel(cardRow, txt, UDim2.new(), UDim2.fromScale(0.08, 0.6), Color3.fromRGB(255, 215, 110), Enum.Font.GothamBlack)
    l.LayoutOrder = cardOrder
end

local Y = "<font color='#FFD36B'><b>"
local E = "</b></font>"
local PAGES = {
    {
        title = "THE GOAL",
        cards = { { "K", false }, { "A", true }, "=", "21!" },
        text = "Get a hand that is " .. Y .. "closer to 21" .. E .. " than the dealer's hand, " .. Y .. "without going over 21" .. E .. "." .. NL .. "Going over 21 is called a " .. Y .. "BUST" .. E .. " and you lose that hand.",
    },
    {
        title = "CARD VALUES",
        cards = { { "7", true }, "= 7", { "K", false }, "= 10", { "A", true }, "= 1 or 11" },
        text = Y .. "2 to 10" .. E .. " are worth their number." .. NL .. Y .. "J, Q and K" .. E .. " are each worth 10." .. NL .. "An " .. Y .. "Ace" .. E .. " is worth 11, or 1 if 11 would make you bust.",
    },
    {
        title = "PLACING A BET",
        cards = { "10", "25", "50", "→", "PLACE BET" },
        text = "When the round opens, tap the " .. Y .. "chip buttons" .. E .. " at the bottom to set your bet, then press " .. Y .. "Place Bet" .. E .. " before the timer runs out.",
    },
    {
        title = "YOUR CHOICES",
        cards = { { "9", false }, { "5", true }, "= 14", "?" },
        text = Y .. "HIT" .. E .. " - take another card." .. NL .. Y .. "STAND" .. E .. " - keep your total and end your turn." .. NL .. Y .. "DOUBLE" .. E .. " - double your bet and get exactly one more card.",
    },
    {
        title = "THE DEALER",
        cards = { { "10", true }, { "", false, true }, "→", { "10", true }, { "7", false }, "= 17" },
        text = "The dealer has one card " .. Y .. "face down" .. E .. ". After every player finishes, the dealer flips it over." .. NL .. "The dealer " .. Y .. "must hit until 17 or more" .. E .. ". If the dealer busts, everyone still in wins!",
    },
    {
        title = "HOW YOU WIN",
        cards = { { "A", false }, { "Q", true }, "= BLACKJACK" },
        text = Y .. "Beat the dealer" .. E .. ": you win the same as your bet (1 to 1)." .. NL .. Y .. "Blackjack" .. E .. " (an Ace + a 10-value card as your first two cards): pays 3 to 2." .. NL .. Y .. "Tie" .. E .. ": you get your bet back.   " .. Y .. "Bust" .. E .. ": you lose your bet.",
    },
    {
        title = "BEGINNER TIPS",
        cards = { { "6", false }, { "5", true }, "= 11", "→", "DOUBLE!" },
        text = "• " .. Y .. "Stand" .. E .. " on 17 or more.   • " .. Y .. "Hit" .. E .. " on 11 or less." .. NL .. "• " .. Y .. "Double" .. E .. " when you have 11." .. NL .. "• Press " .. Y .. "C" .. E .. " to switch cameras and " .. Y .. "H" .. E .. " to open this guide.",
    },
}

local page = 1
local dotFrames = {}
for i = 1, #PAGES do
    local d = new("Frame", { Size = UDim2.fromScale(0.06, 0.6), BackgroundColor3 = Color3.fromRGB(90, 80, 100) }, dots)
    sCorner(d, 1)
    new("UIAspectRatioConstraint", { AspectRatio = 1 }, d)
    dotFrames[i] = d
end
local function showPage(i)
    page = math.clamp(i, 1, #PAGES)
    local data = PAGES[page]
    pageTitle.Text = page .. ".  " .. data.title
    body.Text = data.text
    for _, child in ipairs(cardRow:GetChildren()) do
        if not child:IsA("UIListLayout") then
            child:Destroy()
        end
    end
    cardOrder = 0
    for _, item in ipairs(data.cards) do
        if typeof(item) == "table" then
            makeCard(item[1], item[2], item[3])
        else
            makeSymbol(item)
        end
    end
    for k, d in ipairs(dotFrames) do
        d.BackgroundColor3 = k == page and TGOLD or Color3.fromRGB(90, 80, 100)
    end
    backButton.Visible = page > 1
    nextButton.Text = page == #PAGES and "GOT IT!" or "NEXT"
end
local function openTutorial()
    showPage(1)
    tutPanel.Visible = true
    tutPanel.Size = UDim2.fromScale(0.5, 0.58)
    TweenService:Create(tutPanel, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Size = UDim2.fromScale(0.62, 0.72) }):Play()
end
local function closeTutorial()
    tutPanel.Visible = false
end
local function toggleTutorial()
    if tutPanel.Visible then
        closeTutorial()
    else
        openTutorial()
    end
end
backButton.MouseButton1Click:Connect(function()
    showPage(page - 1)
end)
nextButton.MouseButton1Click:Connect(function()
    if page == #PAGES then
        closeTutorial()
    else
        showPage(page + 1)
    end
end)
closeButton.MouseButton1Click:Connect(closeTutorial)
helpButton.MouseButton1Click:Connect(toggleTutorial)

----------------------------------------------------------------
-- Betting and actions
----------------------------------------------------------------
local bet, lastBet = 0, DEFAULT_BET
local betPlaced, phase = false, ""

local function myChips()
    local stats = player:FindFirstChild("leaderstats")
    local c = stats and stats:FindFirstChild("Chips")
    return c and c.Value or 0
end
local function refreshBet()
    betAmount.Text = commas(bet)
    local ok = bet >= MIN_BET
    placeButton.AutoButtonColor = ok
    placeButton.BackgroundColor3 = ok and GOLD or Color3.fromRGB(70, 66, 58)
end
local function setMode(mode)
    controls.Visible = mode ~= "none"
    betMode.Visible = mode == "bet"
    actionMode.Visible = mode == "action"
end
for _, chip in ipairs(chipButtons) do
    chip.button.MouseButton1Click:Connect(function()
        if betPlaced then
            return
        end
        bet = math.min(bet + chip.value, MAX_BET, myChips())
        refreshBet()
    end)
end
clearButton.MouseButton1Click:Connect(function()
    bet = 0
    refreshBet()
end)
placeButton.MouseButton1Click:Connect(function()
    if bet < MIN_BET or betPlaced then
        return
    end
    remote:FireServer("bet", bet)
    lastBet = bet
    betPlaced = true
    statusText.Text = "Bet placed  ·  " .. commas(bet) .. " chips"
    setMode("none")
end)
hitButton.MouseButton1Click:Connect(function()
    remote:FireServer("action", "hit")
end)
standButton.MouseButton1Click:Connect(function()
    remote:FireServer("action", "stand")
    setMode("none")
end)
doubleButton.MouseButton1Click:Connect(function()
    remote:FireServer("action", "double")
    setMode("none")
end)
leaveButton.MouseButton1Click:Connect(function()
    local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.Sit = false
        humanoid.Jump = true
    end
end)

local timerTween
local function startTimer(seconds)
    if timerTween then
        timerTween:Cancel()
    end
    if seconds and seconds > 0 then
        timerLine.Size = UDim2.new(1, -20, 0, 2)
        timerTween = TweenService:Create(timerLine, TweenInfo.new(seconds, Enum.EasingStyle.Linear), { Size = UDim2.new(0, 0, 0, 2) })
        timerTween:Play()
    else
        timerLine.Size = UDim2.new(0, 0, 0, 2)
    end
end

local toastId = 0
local function showToast(message, delta)
    toastId += 1
    local id = toastId
    toastText.Text = message
    toastText.TextColor3 = (delta or 0) > 0 and Color3.fromRGB(120, 220, 150)
        or ((delta or 0) < 0 and Color3.fromRGB(230, 110, 110) or GOLD)
    toast.Visible = true
    toast.BackgroundTransparency = 1
    toastText.TextTransparency = 1
    TweenService:Create(toast, TweenInfo.new(0.25), { BackgroundTransparency = 0.15 }):Play()
    TweenService:Create(toastText, TweenInfo.new(0.25), { TextTransparency = 0 }):Play()
    task.delay(3.5, function()
        if id ~= toastId then
            return
        end
        TweenService:Create(toast, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
        TweenService:Create(toastText, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
        task.wait(0.4)
        if id == toastId then
            toast.Visible = false
        end
    end)
end

----------------------------------------------------------------
-- Camera
--   Player's turn: from behind their chair, looking at the dealer
--   Dealer's turn: from behind the dealer, looking at the seats
----------------------------------------------------------------
local gameCamera = true -- press C to switch
local tableCenter, dealerSpot
local lastShot, shotKey, swing

local function stopSwing()
    if swing then
        swing:Disconnect()
        swing = nil
    end
end
local function shoot(key, eye, target)
    if key and key == shotKey and lastShot then
        return
    end
    shotKey = key
    lastShot = { eye = eye, target = target }
    if not gameCamera then
        return
    end
    stopSwing()
    camera.CameraType = Enum.CameraType.Scriptable
    local startCF = camera.CFrame
    local startTarget = startCF.Position + startCF.LookVector * math.max((target - eye).Magnitude, 6)
    local pivot = tableCenter or (eye + target) / 2
    local function polar(p)
        local d = p - pivot
        return math.atan2(d.Z, d.X), flat(d).Magnitude, d.Y
    end
    local a0, r0, h0 = polar(startCF.Position)
    local a1, r1, h1 = polar(eye)
    local da = (a1 - a0 + math.pi) % (2 * math.pi) - math.pi
    local t0 = os.clock()
    swing = RunService.RenderStepped:Connect(function()
        local alpha = math.clamp((os.clock() - t0) / SWING_TIME, 0, 1)
        local e = alpha < 0.5 and 2 * alpha * alpha or 1 - ((-2 * alpha + 2) ^ 2) / 2
        local angle = a0 + da * e
        local radius = r0 + (r1 - r0) * e
        local position = pivot + V(math.cos(angle) * radius, h0 + (h1 - h0) * e, math.sin(angle) * radius)
        camera.CFrame = CFrame.lookAt(position, startTarget:Lerp(target, e))
        if alpha >= 1 then
            stopSwing()
        end
    end)
end
local function restoreCamera()
    stopSwing()
    lastShot, shotKey = nil, nil
    camera.CameraType = Enum.CameraType.Custom
    local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        camera.CameraSubject = humanoid
    end
end
-- From behind a chair, looking across the table at the dealer
local function seatView(seatPos)
    local outward = flat(seatPos - tableCenter)
    outward = outward.Magnitude > 0.01 and outward.Unit or V(0, 0, 1)
    local eye = seatPos + outward * 3.5 + UP * 6.5
    local target
    if dealerSpot then
        target = dealerSpot + UP * 2
    else
        target = tableCenter - outward * 4 + UP * 1.5 -- best guess until the dealer has had a turn
    end
    return eye, target
end
local function mySeat()
    local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    return humanoid and humanoid.SeatPart
end

-- Hide your character, fade other players, and fade anything right in front of the camera
local faded = false
local nearFaded = {}
RunService.RenderStepped:Connect(function()
    local on = gui.Enabled and camera.CameraType == Enum.CameraType.Scriptable
    local now = {}
    if on then
        for _, p in ipairs(workspace:GetPartBoundsInRadius(camera.CFrame.Position, 4)) do
            if math.max(p.Size.X, p.Size.Y, p.Size.Z) < 12 then
                p.LocalTransparencyModifier = 0.8
                now[p] = true
            end
        end
    end
    for p in pairs(nearFaded) do
        if not now[p] then
            p.LocalTransparencyModifier = 0
        end
    end
    nearFaded = now

    if not on and not faded then
        return
    end
    faded = on
    for _, plr in ipairs(Players:GetPlayers()) do
        local character = plr.Character
        if character then
            local amount = on and ((plr == player) and 1 or 0.6) or 0
            for _, d in ipairs(character:GetDescendants()) do
                if d:IsA("BasePart") or d:IsA("Decal") then
                    d.LocalTransparencyModifier = amount
                end
            end
        end
    end
end)

UserInputService.InputBegan:Connect(function(input, typing)
    if typing or not gui.Enabled then
        return
    end
    if input.KeyCode == Enum.KeyCode.H then
        toggleTutorial()
    elseif input.KeyCode == Enum.KeyCode.C then
        gameCamera = not gameCamera
        if gameCamera and lastShot then
            local saved = lastShot
            shotKey = nil
            shoot(nil, saved.eye, saved.target)
        elseif not gameCamera then
            local saved = lastShot
            restoreCamera()
            lastShot = saved
        end
    end
end)

----------------------------------------------------------------
-- Messages from the game
----------------------------------------------------------------
local seenTutorial = false
remote.OnClientEvent:Connect(function(kind, data)
    data = data or {}
    if data.center then
        tableCenter = data.center
    end
    if not gui.Enabled then
        gui.Enabled = true
        tutGui.Enabled = true
        if AUTO_TUTORIAL and not seenTutorial then
            seenTutorial = true
            openTutorial()
        end
    end
    local seat = mySeat()

    if kind == "phase" then
        local changed = data.phase ~= phase
        if data.phase == "betting" and changed then
            betPlaced = false
            bet = math.min(lastBet, MAX_BET, myChips())
            refreshBet()
        end
        phase = data.phase
        if data.phase == "betting" then
            statusText.Text = betPlaced and ("Bet placed  ·  " .. commas(lastBet) .. " chips") or "Place your bet"
            setMode(betPlaced and "none" or "bet")
        else
            statusText.Text = data.text or ""
            setMode("none")
        end
        if changed then
            startTimer(data.time)
        end
        if seat and tableCenter then
            shoot("mine", seatView(seat.Position))
        end
    elseif kind == "turn" then
        phase = "playing"
        startTimer(data.time)
        if data.kind == "player" then
            if data.userId == player.UserId then
                statusText.Text = "Your turn"
            else
                statusText.Text = data.name .. "'s turn"
                setMode("none")
            end
            if tableCenter and data.seatPos then
                shoot("player" .. tostring(data.userId), seatView(data.seatPos))
            end
        else
            statusText.Text = "Dealer's turn"
            setMode("none")
            if data.focus then
                dealerSpot = data.focus -- remember where the dealer is for the player views
            end
            if tableCenter then
                shoot("dealer", data.eye, data.look)
            end
        end
    elseif kind == "yourTurn" then
        handTotal.Text = tostring(data.total)
        doubleButton.Visible = data.canDouble
        statusText.Text = "Your turn  ·  You have " .. data.total
        setMode("action")
        startTimer(data.time)
    elseif kind == "turnOver" then
        setMode("none")
    elseif kind == "result" then
        showToast(data.text, data.delta)
    elseif kind == "roundEnd" then
        phase = ""
        statusText.Text = "Next round starting..."
        setMode("none")
        startTimer(0)
        restoreCamera()
    end
end)

----------------------------------------------------------------
-- Every frame: chips count, and close everything when you stand up
----------------------------------------------------------------
RunService.Heartbeat:Connect(function()
    chipsText.Text = commas(myChips())
    if gui.Enabled and not mySeat() then
        gui.Enabled = false
        tutGui.Enabled = false
        closeTutorial()
        setMode("none")
        phase = ""
        dealerSpot = nil
        restoreCamera()
    end
end)
