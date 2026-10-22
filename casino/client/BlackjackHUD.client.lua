-- BLACKJACK HUD + CAMERA + TUTORIAL (LocalScript in StarterPlayer > StarterPlayerScripts)
-- James's clean HUD. Casino changes: guide line breaks use NL (the Studio bridge
-- mangles backslash-n), Sit & Play prompts are hidden while you're seated, and
-- the round chip / help buttons set their existing UICorner instead of adding a second.
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
local function row(parent, padding, align)
    return new("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = align or Enum.HorizontalAlignment.Center,
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
-- Screen layout
----------------------------------------------------------------
local gui = new("ScreenGui", {
    Name = "BlackjackHUD", ResetOnSpawn = false, Enabled = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, player:WaitForChild("PlayerGui"))
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

-- Help + leave (bottom right)
local corner = new("Frame", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 1, -16), Size = UDim2.fromOffset(170, 36), BackgroundTransparency = 1 }, gui)
row(corner, 8, Enum.HorizontalAlignment.Right)
local leaveButton = button("Leave", BG, MUTED, UDim2.fromOffset(84, 36), corner)
leaveButton.BackgroundTransparency = 0.15
outline(leaveButton)
local helpButton = button("?", BG, GOLD, UDim2.fromOffset(36, 36), corner)
helpButton.BackgroundTransparency = 0.15
helpButton.TextSize = 18
helpButton.LayoutOrder = 2
rounded(helpButton, 18)
outline(helpButton)

----------------------------------------------------------------
-- Tutorial
----------------------------------------------------------------
local backdrop = new("TextButton", {
    Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45,
    BorderSizePixel = 0, Text = "", AutoButtonColor = false, Visible = false,
}, gui)
local modal = panel({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(540, 340), BackgroundTransparency = 0.03 }, backdrop)
text({ Position = UDim2.fromOffset(26, 20), Size = UDim2.new(1, -80, 0, 16), Text = "HOW TO PLAY BLACKJACK", Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Left }, modal)
local closeButton = new("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 12), Size = UDim2.fromOffset(30, 30), BackgroundTransparency = 1, Text = "×", Font = Enum.Font.GothamMedium, TextSize = 24, TextColor3 = MUTED }, modal)
local pageTitle = text({ Position = UDim2.fromOffset(26, 44), Size = UDim2.new(1, -52, 0, 32), Font = Enum.Font.GothamBold, TextSize = 24, TextXAlignment = Enum.TextXAlignment.Left }, modal)
new("Frame", { Position = UDim2.fromOffset(26, 84), Size = UDim2.new(1, -52, 0, 1), BackgroundColor3 = GOLD, BackgroundTransparency = 0.6, BorderSizePixel = 0 }, modal)
local pageBody = text({
    Position = UDim2.fromOffset(26, 100), Size = UDim2.new(1, -52, 0, 170), TextSize = 16, TextColor3 = Color3.fromRGB(210, 210, 215),
    TextWrapped = true, RichText = true, LineHeight = 1.2,
    TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
}, modal)
local dots = text({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 26, 1, -24), Size = UDim2.fromOffset(160, 36), TextSize = 14, TextColor3 = MUTED, TextXAlignment = Enum.TextXAlignment.Left }, modal)
local navRow = new("Frame", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -26, 1, -24), Size = UDim2.fromOffset(240, 36), BackgroundTransparency = 1 }, modal)
row(navRow, 10, Enum.HorizontalAlignment.Right)
local backButton = button("Back", Color3.fromRGB(42, 42, 50), TEXT, UDim2.fromOffset(96, 36), navRow)
local nextButton = button("Next", GOLD, Color3.fromRGB(24, 18, 8), UDim2.fromOffset(110, 36), navRow)
nextButton.LayoutOrder = 2

local B, E = "<font color='#C9A85C'><b>", "</b></font>"
local NL2 = NL .. NL
local PAGES = {
    { "The Goal", "Beat the dealer by getting a hand total " .. B .. "closer to 21" .. E .. " without going over." .. NL2 .. "Going over 21 is a " .. B .. "bust" .. E .. " and you lose your bet right away." },
    { "Card Values", B .. "2 – 10" .. E .. "  count as their number." .. NL .. B .. "J, Q, K" .. E .. "  count as 10." .. NL .. B .. "Ace" .. E .. "  counts as 11, or 1 if 11 would make you bust." .. NL2 .. "Your total is shown above your cards on the table." },
    { "Placing a Bet", "When a round opens, tap the chips to set your bet, then press " .. B .. "Place Bet" .. E .. " before the timer runs out." .. NL2 .. "You and the dealer each get two cards. One of the dealer's cards stays face down." },
    { "Your Turn", B .. "Hit" .. E .. "  –  take another card." .. NL .. B .. "Stand" .. E .. "  –  keep your total and end your turn." .. NL .. B .. "Double" .. E .. "  –  double your bet and take exactly one more card." .. NL2 .. "If the timer runs out, you automatically stand." },
    { "Dealer & Payouts", "The dealer reveals the hidden card and draws until reaching " .. B .. "17 or more" .. E .. "." .. NL2 .. "A win pays " .. B .. "1 to 1" .. E .. ". A " .. B .. "Blackjack" .. E .. " (Ace + a 10-value card) pays " .. B .. "3 to 2" .. E .. ". A tie returns your bet." .. NL2 .. "Press " .. B .. "H" .. E .. " to reopen this guide and " .. B .. "C" .. E .. " to switch cameras." },
}
local page = 1
local function showPage(n)
    page = math.clamp(n, 1, #PAGES)
    pageTitle.Text = PAGES[page][1]
    pageBody.Text = PAGES[page][2]
    local d = {}
    for i = 1, #PAGES do
        d[i] = i == page and "●" or "○"
    end
    dots.Text = table.concat(d, "  ")
    backButton.Visible = page > 1
    nextButton.Text = page == #PAGES and "Got it" or "Next"
    backdrop.Visible = true
end
local function hideTutorial()
    backdrop.Visible = false
end
local function toggleTutorial()
    if backdrop.Visible then
        hideTutorial()
    else
        showPage(1)
    end
end
backButton.MouseButton1Click:Connect(function()
    showPage(page - 1)
end)
nextButton.MouseButton1Click:Connect(function()
    if page == #PAGES then
        hideTutorial()
    else
        showPage(page + 1)
    end
end)
closeButton.MouseButton1Click:Connect(hideTutorial)
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
-- Camera: high view that swings around the table
----------------------------------------------------------------
local gameCamera = true -- press C to switch
local tableCenter
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
-- High above and behind a chair, looking down at that seat's cards
local function seatView(seatPos, spot)
    local outward = flat(seatPos - tableCenter)
    outward = outward.Magnitude > 0.01 and outward.Unit or V(0, 0, 1)
    return seatPos + outward * 5 + UP * 11, spot:Lerp(tableCenter, 0.3)
end
local function mySeat()
    local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    return humanoid and humanoid.SeatPart
end

-- Hide your own character (and fade others) while the table camera is on
local faded = false
RunService.RenderStepped:Connect(function()
    local on = gui.Enabled and camera.CameraType == Enum.CameraType.Scriptable
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
        if AUTO_TUTORIAL and not seenTutorial then
            seenTutorial = true
            showPage(1)
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
        if seat and tableCenter and data.mySpot then
            shoot("mine", seatView(seat.Position, data.mySpot))
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
            if tableCenter then
                shoot("player" .. tostring(data.userId), seatView(data.seatPos, data.focus))
            end
        else
            statusText.Text = "Dealer's turn"
            setMode("none")
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
-- Sit & Play prompts: hidden while you're seated, and on chairs already taken
----------------------------------------------------------------
local joinPrompts = {}
local function trackPrompt(d)
    if d:IsA("ProximityPrompt") and d.Name == "BlackjackJoinPrompt" then
        table.insert(joinPrompts, d)
    end
end
for _, d in ipairs(workspace:GetDescendants()) do
    trackPrompt(d)
end
workspace.DescendantAdded:Connect(trackPrompt)

----------------------------------------------------------------
-- Every frame: chips count, and close everything when you stand up
----------------------------------------------------------------
RunService.Heartbeat:Connect(function()
    chipsText.Text = commas(myChips())
    local seated = mySeat() ~= nil
    for _, prompt in ipairs(joinPrompts) do
        local seat = prompt.Parent
        prompt.Enabled = not seated and not (seat and seat:IsA("Seat") and seat.Occupant)
    end
    if gui.Enabled and not seated then
        gui.Enabled = false
        hideTutorial()
        setMode("none")
        phase = ""
        restoreCamera()
    end
end)
