-- BLACKJACK SCREEN + CAMERA + TUTORIAL v3 (LocalScript in StarterPlayer > StarterPlayerScripts)
local MIN_BET, MAX_BET = 10, 500
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
local GOLD = Color3.fromRGB(212, 175, 55)
local DARK = Color3.fromRGB(15, 12, 20)
local function flat(v)
    return V(v.X, 0, v.Z)
end

----------------------------------------------------------------
-- UI helpers
----------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "BlackjackHUD"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local function corner(p, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(r or 0.2, 0)
    c.Parent = p
end
local function outline(p, color, thickness)
    local s = Instance.new("UIStroke")
    s.Color = color or GOLD
    s.Thickness = thickness or 2
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = p
    return s
end
local function panel(parent, pos, size, anchor)
    local f = Instance.new("Frame")
    f.AnchorPoint = anchor or Vector2.new(0, 0)
    f.Position = pos
    f.Size = size
    f.BackgroundColor3 = DARK
    f.BackgroundTransparency = 0.12
    f.Parent = parent
    corner(f, 0.12)
    outline(f)
    return f
end
local function label(parent, text, pos, size, color, font)
    local l = Instance.new("TextLabel")
    l.Position = pos
    l.Size = size
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextScaled = true
    l.RichText = true
    l.Font = font or Enum.Font.GothamBold
    l.TextColor3 = color or Color3.new(1, 1, 1)
    l.Parent = parent
    return l
end
local function button(parent, text, color)
    local b = Instance.new("TextButton")
    b.BackgroundColor3 = color
    b.Text = text
    b.TextScaled = true
    b.Font = Enum.Font.GothamBlack
    b.TextColor3 = Color3.new(1, 1, 1)
    b.AutoButtonColor = true
    b.Parent = parent
    corner(b, 0.25)
    outline(b, GOLD, 1.5)
    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0.18, 0)
    pad.PaddingBottom = UDim.new(0.18, 0)
    pad.PaddingLeft = UDim.new(0.06, 0)
    pad.PaddingRight = UDim.new(0.06, 0)
    pad.Parent = b
    return b
end
local function hRow(parent, padding)
    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.VerticalAlignment = Enum.VerticalAlignment.Center
    layout.Padding = UDim.new(padding or 0.015, 0)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = parent
end

----------------------------------------------------------------
-- Screen layout
----------------------------------------------------------------
-- Top: step banner + timer
local banner = panel(gui, UDim2.new(0.5, 0, 0, 56), UDim2.fromScale(0.56, 0.075), Vector2.new(0.5, 0))
local bannerText = label(banner, "", UDim2.fromScale(0.03, 0.1), UDim2.fromScale(0.94, 0.72), Color3.fromRGB(255, 215, 110), Enum.Font.GothamBlack)
local timerBar = Instance.new("Frame")
timerBar.Position = UDim2.fromScale(0, 0.9)
timerBar.Size = UDim2.fromScale(0, 0.1)
timerBar.BackgroundColor3 = GOLD
timerBar.BorderSizePixel = 0
timerBar.Parent = banner

-- Chips (top left)
local chipsPanel = panel(gui, UDim2.new(0, 16, 0, 56), UDim2.fromScale(0.16, 0.075))
local chipsText = label(chipsPanel, "CHIPS", UDim2.fromScale(0.06, 0.12), UDim2.fromScale(0.88, 0.76), Color3.fromRGB(120, 255, 160), Enum.Font.GothamBlack)

-- Dealer's hand (top middle)
local dealerPanel = panel(gui, UDim2.fromScale(0.5, 0.17), UDim2.fromScale(0.42, 0.2), Vector2.new(0.5, 0))
local dealerTitle = label(dealerPanel, "DEALER", UDim2.fromScale(0.04, 0.03), UDim2.fromScale(0.92, 0.24), Color3.new(1, 1, 1), Enum.Font.GothamBlack)
local dealerCards = Instance.new("Frame")
dealerCards.Position = UDim2.fromScale(0.03, 0.3)
dealerCards.Size = UDim2.fromScale(0.94, 0.64)
dealerCards.BackgroundTransparency = 1
dealerCards.Parent = dealerPanel
hRow(dealerCards)

-- Other players (right side)
local othersPanel = panel(gui, UDim2.new(1, -16, 0.17, 0), UDim2.fromScale(0.2, 0.32), Vector2.new(1, 0))
label(othersPanel, "AT THE TABLE", UDim2.fromScale(0.05, 0.02), UDim2.fromScale(0.9, 0.12), GOLD, Enum.Font.GothamBlack)
local othersList = Instance.new("Frame")
othersList.Position = UDim2.fromScale(0.05, 0.16)
othersList.Size = UDim2.fromScale(0.9, 0.82)
othersList.BackgroundTransparency = 1
othersList.Parent = othersPanel
local othersLayout = Instance.new("UIListLayout")
othersLayout.Padding = UDim.new(0.02, 0)
othersLayout.Parent = othersList

-- Your hand + controls (bottom)
local myPanel = panel(gui, UDim2.new(0.5, 0, 1, -16), UDim2.fromScale(0.6, 0.36), Vector2.new(0.5, 1))
local myTitle = label(myPanel, "YOUR HAND", UDim2.fromScale(0.03, 0.02), UDim2.fromScale(0.94, 0.15), Color3.new(1, 1, 1), Enum.Font.GothamBlack)
local myCards = Instance.new("Frame")
myCards.Position = UDim2.fromScale(0.03, 0.19)
myCards.Size = UDim2.fromScale(0.94, 0.4)
myCards.BackgroundTransparency = 1
myCards.Parent = myPanel
hRow(myCards)

local betRow = Instance.new("Frame")
betRow.Position = UDim2.fromScale(0.02, 0.63)
betRow.Size = UDim2.fromScale(0.96, 0.16)
betRow.BackgroundTransparency = 1
betRow.Parent = myPanel
hRow(betRow, 0.012)
local chipColors = { Color3.fromRGB(30, 80, 200), Color3.fromRGB(30, 150, 60), Color3.fromRGB(200, 30, 30), Color3.fromRGB(20, 20, 20), Color3.fromRGB(150, 60, 170) }
local chipButtons = {}
for i, value in ipairs(CHIP_VALUES) do
    local b = button(betRow, "+" .. value, chipColors[i])
    b.Size = UDim2.fromScale(0.13, 1)
    b.LayoutOrder = i
    corner(b, 1)
    chipButtons[i] = { button = b, value = value }
end
local clearButton = button(betRow, "CLEAR", Color3.fromRGB(70, 60, 80))
clearButton.Size = UDim2.fromScale(0.15, 1)
clearButton.LayoutOrder = 10

local actionRow = Instance.new("Frame")
actionRow.Position = UDim2.fromScale(0.02, 0.81)
actionRow.Size = UDim2.fromScale(0.96, 0.17)
actionRow.BackgroundTransparency = 1
actionRow.Parent = myPanel
hRow(actionRow, 0.02)
local dealButton = button(actionRow, "DEAL", Color3.fromRGB(20, 130, 60))
dealButton.Size = UDim2.fromScale(0.4, 1)
local hitButton = button(actionRow, "HIT", Color3.fromRGB(20, 130, 60))
hitButton.Size = UDim2.fromScale(0.28, 1)
local standButton = button(actionRow, "STAND", Color3.fromRGB(160, 25, 35))
standButton.Size = UDim2.fromScale(0.28, 1)
local doubleButton = button(actionRow, "DOUBLE", Color3.fromRGB(180, 135, 30))
doubleButton.Size = UDim2.fromScale(0.28, 1)

-- Help and leave buttons (bottom right)
local helpButton = button(gui, "?  HOW TO PLAY", Color3.fromRGB(120, 20, 30))
helpButton.AnchorPoint = Vector2.new(1, 1)
helpButton.Position = UDim2.new(1, -16, 1, -16)
helpButton.Size = UDim2.fromOffset(190, 46)
local leaveButton = button(gui, "LEAVE TABLE", Color3.fromRGB(60, 50, 70))
leaveButton.AnchorPoint = Vector2.new(1, 1)
leaveButton.Position = UDim2.new(1, -16, 1, -70)
leaveButton.Size = UDim2.fromOffset(190, 40)

-- Big result in the middle
local resultText = label(gui, "", UDim2.fromScale(0.2, 0.42), UDim2.fromScale(0.6, 0.12), Color3.fromRGB(255, 215, 110), Enum.Font.GothamBlack)
resultText.Visible = false
local resultStroke = Instance.new("UIStroke")
resultStroke.Thickness = 4
resultStroke.Parent = resultText

----------------------------------------------------------------
-- Playing cards on screen
----------------------------------------------------------------
local function clearRow(row)
    for _, child in ipairs(row:GetChildren()) do
        if not child:IsA("UIListLayout") then
            child:Destroy()
        end
    end
end
local function screenCard(row, card, order)
    local c = Instance.new("Frame")
    c.Size = UDim2.fromScale(0.2, 1)
    c.LayoutOrder = order
    c.BackgroundColor3 = card.h and Color3.fromRGB(150, 20, 30) or Color3.fromRGB(250, 250, 245)
    c.Parent = row
    corner(c, 0.1)
    outline(c, card.h and GOLD or Color3.fromRGB(170, 170, 170), 2)
    local ratio = Instance.new("UIAspectRatioConstraint")
    ratio.AspectRatio = 0.7
    ratio.Parent = c
    if card.h then
        label(c, "?", UDim2.fromScale(0.1, 0.25), UDim2.fromScale(0.8, 0.5), GOLD, Enum.Font.GothamBlack)
    else
        local red = card.s == "♥" or card.s == "♦"
        local color = red and Color3.fromRGB(200, 25, 30) or Color3.fromRGB(20, 20, 20)
        local small = label(c, card.r, UDim2.fromScale(0.06, 0.02), UDim2.fromScale(0.45, 0.24), color, Enum.Font.GothamBlack)
        small.TextXAlignment = Enum.TextXAlignment.Left
        label(c, card.s, UDim2.fromScale(0.15, 0.25), UDim2.fromScale(0.7, 0.45), color, Enum.Font.GothamBlack)
        label(c, card.r, UDim2.fromScale(0.1, 0.68), UDim2.fromScale(0.8, 0.28), color, Enum.Font.GothamBlack)
    end
end

----------------------------------------------------------------
-- Tutorial
----------------------------------------------------------------
local tutorial = panel(gui, UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.6, 0.66), Vector2.new(0.5, 0.5))
tutorial.BackgroundTransparency = 0
tutorial.ZIndex = 10
tutorial.Visible = false
local tutLimit = Instance.new("UISizeConstraint")
tutLimit.MaxSize = Vector2.new(760, 520)
tutLimit.Parent = tutorial
label(tutorial, "HOW TO PLAY  <font color='#FFD36B'>BLACKJACK</font>", UDim2.fromScale(0.05, 0.03), UDim2.fromScale(0.8, 0.11), Color3.new(1, 1, 1), Enum.Font.GothamBlack)
local tutClose = button(tutorial, "X", Color3.fromRGB(120, 20, 30))
tutClose.Position = UDim2.fromScale(0.9, 0.03)
tutClose.Size = UDim2.fromScale(0.07, 0.1)
local tutTitle = label(tutorial, "", UDim2.fromScale(0.05, 0.17), UDim2.fromScale(0.9, 0.09), Color3.fromRGB(255, 215, 110), Enum.Font.GothamBlack)
local tutCards = Instance.new("Frame")
tutCards.Position = UDim2.fromScale(0.05, 0.28)
tutCards.Size = UDim2.fromScale(0.9, 0.22)
tutCards.BackgroundTransparency = 1
tutCards.Parent = tutorial
hRow(tutCards)
local tutBody = label(tutorial, "", UDim2.fromScale(0.06, 0.53), UDim2.fromScale(0.88, 0.3), Color3.fromRGB(235, 235, 235), Enum.Font.Gotham)
tutBody.TextWrapped = true
tutBody.TextXAlignment = Enum.TextXAlignment.Left
tutBody.TextYAlignment = Enum.TextYAlignment.Top
local tutNav = Instance.new("Frame")
tutNav.Position = UDim2.fromScale(0.05, 0.86)
tutNav.Size = UDim2.fromScale(0.9, 0.1)
tutNav.BackgroundTransparency = 1
tutNav.Parent = tutorial
hRow(tutNav, 0.3)
local tutBack = button(tutNav, "BACK", Color3.fromRGB(60, 50, 70))
tutBack.Size = UDim2.fromScale(0.25, 1)
local tutNext = button(tutNav, "NEXT", Color3.fromRGB(20, 130, 60))
tutNext.Size = UDim2.fromScale(0.25, 1)

local Y, E = "<font color='#FFD36B'><b>", "</b></font>"
local PAGES = {
    { "1. HOW TO START", { { r = "A", s = "♠" }, { r = "K", s = "♥" } },
        "Tap the " .. Y .. "chip buttons" .. E .. " to build your bet, then press the green " .. Y .. "DEAL" .. E .. " button. Everyone gets 2 cards and the dealer gets one card face up and one face down." },
    { "2. THE GOAL", { { r = "K", s = "♣" }, { r = "A", s = "♦" } },
        "Get " .. Y .. "closer to 21" .. E .. " than the dealer " .. Y .. "without going over" .. E .. ". Going over 21 is a " .. Y .. "BUST" .. E .. " and you lose." },
    { "3. CARD VALUES", { { r = "7", s = "♥" }, { r = "Q", s = "♠" }, { r = "A", s = "♦" } },
        Y .. "2-10" .. E .. " = their number.   " .. Y .. "J, Q, K" .. E .. " = 10.   " .. Y .. "Ace" .. E .. " = 11, or 1 if 11 would bust you. Your total always shows next to " .. Y .. "YOUR HAND" .. E .. "." },
    { "4. YOUR TURN", { { r = "9", s = "♣" }, { r = "5", s = "♥" } },
        Y .. "HIT" .. E .. " = take another card.   " .. Y .. "STAND" .. E .. " = keep your total.   " .. Y .. "DOUBLE" .. E .. " = double your bet for exactly one more card. You have a timer, so don't wait too long!" },
    { "5. THE DEALER & PAYOUTS", { { r = "10", s = "♦" }, { r = "7", s = "♠" } },
        "The dealer flips the hidden card and " .. Y .. "draws until 17 or more" .. E .. ". Beat the dealer = win your bet. " .. Y .. "Blackjack" .. E .. " (Ace + 10-card) pays 3 to 2. A tie gives your bet back." },
    { "6. TIPS", { { r = "8", s = "♥" }, { r = "8", s = "♣" } },
        "Stand on " .. Y .. "17 or more" .. E .. ". Hit on " .. Y .. "11 or less" .. E .. ". Double on " .. Y .. "11" .. E .. ". Press " .. Y .. "C" .. E .. " to switch cameras and " .. Y .. "H" .. E .. " to open this guide again." },
}
local tutPage = 1
local function showTutorial(page)
    tutPage = math.clamp(page, 1, #PAGES)
    local data = PAGES[tutPage]
    tutTitle.Text = data[1]
    tutBody.Text = data[3]
    clearRow(tutCards)
    for i, card in ipairs(data[2]) do
        screenCard(tutCards, card, i)
    end
    tutBack.Visible = tutPage > 1
    tutNext.Text = tutPage == #PAGES and "GOT IT!" or "NEXT"
    tutorial.Visible = true
end
tutBack.MouseButton1Click:Connect(function()
    showTutorial(tutPage - 1)
end)
tutNext.MouseButton1Click:Connect(function()
    if tutPage == #PAGES then
        tutorial.Visible = false
    else
        showTutorial(tutPage + 1)
    end
end)
tutClose.MouseButton1Click:Connect(function()
    tutorial.Visible = false
end)
helpButton.MouseButton1Click:Connect(function()
    if tutorial.Visible then
        tutorial.Visible = false
    else
        showTutorial(1)
    end
end)

----------------------------------------------------------------
-- Betting and actions
----------------------------------------------------------------
local bet, lastBet = 0, 50
local myBetPlaced, phase = false, ""
local function chips()
    local stats = player:FindFirstChild("leaderstats")
    local c = stats and stats:FindFirstChild("Chips")
    return c and c.Value or 0
end
local function refreshControls()
    local betting = phase == "betting" and not myBetPlaced
    betRow.Visible = betting
    dealButton.Visible = betting
    dealButton.Text = bet >= MIN_BET and ("DEAL  (" .. bet .. ")") or ("BET AT LEAST " .. MIN_BET)
    dealButton.AutoButtonColor = bet >= MIN_BET
    dealButton.BackgroundColor3 = bet >= MIN_BET and Color3.fromRGB(20, 130, 60) or Color3.fromRGB(70, 70, 70)
end
for _, chip in ipairs(chipButtons) do
    chip.button.MouseButton1Click:Connect(function()
        bet = math.min(bet + chip.value, MAX_BET, chips())
        refreshControls()
    end)
end
clearButton.MouseButton1Click:Connect(function()
    bet = 0
    refreshControls()
end)
dealButton.MouseButton1Click:Connect(function()
    if bet < MIN_BET then
        return
    end
    remote:FireServer("bet", bet)
    lastBet = bet
    myBetPlaced = true
    bannerText.Text = "Bet placed! Starting soon..."
    refreshControls()
end)
local function showActions(visible, canDouble)
    hitButton.Visible = visible
    standButton.Visible = visible
    doubleButton.Visible = visible and canDouble
end
showActions(false)
hitButton.MouseButton1Click:Connect(function()
    remote:FireServer("action", "hit")
end)
standButton.MouseButton1Click:Connect(function()
    remote:FireServer("action", "stand")
    showActions(false)
end)
doubleButton.MouseButton1Click:Connect(function()
    remote:FireServer("action", "double")
    showActions(false)
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
        timerBar.Size = UDim2.fromScale(1, 0.1)
        timerTween = TweenService:Create(timerBar, TweenInfo.new(seconds, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(0, 0.1) })
        timerTween:Play()
    else
        timerBar.Size = UDim2.fromScale(0, 0.1)
    end
end

----------------------------------------------------------------
-- Camera: high view, swings around the table, hides characters in the way
----------------------------------------------------------------
local gameCamera = true
local tableCenter, mySpot
local lastShot, shotKey, swing

local function stopSwing()
    if swing then
        swing:Disconnect()
        swing = nil
    end
end
local function shoot(key, eye, target)
    if shotKey == key and lastShot then
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
        local position = pivot + V(math.cos(angle) * (r0 + (r1 - r0) * e), h0 + (h1 - h0) * e, math.sin(angle) * (r0 + (r1 - r0) * e))
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
-- High view from behind a spot on the table, looking across it
local function viewOf(spot)
    local outward = flat(spot - tableCenter)
    outward = outward.Magnitude > 0.01 and outward.Unit or V(0, 0, 1)
    return spot + outward * 6 + UP * 10, spot:Lerp(tableCenter, 0.35)
end
-- View from high above and behind a chair, looking down at that seat's cards
local function seatView(seatPos, spot)
    local outward = flat(seatPos - tableCenter).Unit
    return seatPos + outward * 5 + UP * 11, spot:Lerp(tableCenter, 0.3)
end
UserInputService.InputBegan:Connect(function(input, typing)
    if typing or not gui.Enabled then
        return
    end
    if input.KeyCode == Enum.KeyCode.C then
        gameCamera = not gameCamera
        if gameCamera and lastShot then
            local saved = lastShot
            shotKey = nil
            shoot("restore", saved.eye, saved.target)
        elseif not gameCamera then
            local saved = lastShot
            restoreCamera()
            lastShot = saved
        end
    elseif input.KeyCode == Enum.KeyCode.H then
        if tutorial.Visible then
            tutorial.Visible = false
        else
            showTutorial(1)
        end
    end
end)

----------------------------------------------------------------
-- Showing the hands
----------------------------------------------------------------
local function renderHands(data)
    clearRow(dealerCards)
    for i, card in ipairs(data.dealer.cards) do
        screenCard(dealerCards, card, i)
    end
    local dealerTotal = #data.dealer.cards > 0 and (tostring(data.dealer.total) .. (data.dealer.hidden and " + ?" or "")) or ""
    dealerTitle.Text = "DEALER   " .. Y .. dealerTotal .. E .. (data.dealer.status ~= "" and ("   " .. data.dealer.status) or "")

    local mine
    for _, child in ipairs(othersList:GetChildren()) do
        if child:IsA("TextLabel") then
            child:Destroy()
        end
    end
    for _, p in ipairs(data.players) do
        if p.userId == player.UserId then
            mine = p
        else
            local line = label(othersList, "", UDim2.new(), UDim2.fromScale(1, 0.18), Color3.new(1, 1, 1), Enum.Font.GothamBold)
            line.TextXAlignment = Enum.TextXAlignment.Left
            local turnMark = data.turn == p.userId and "▶ " or ""
            line.Text = turnMark .. p.name .. ":  " .. Y .. p.total .. E .. "  " .. p.status
            line.TextColor3 = data.turn == p.userId and Color3.fromRGB(255, 215, 110) or Color3.new(1, 1, 1)
        end
    end
    othersPanel.Visible = #data.players > (mine and 1 or 0)

    clearRow(myCards)
    if mine then
        for i, card in ipairs(mine.cards) do
            screenCard(myCards, card, i)
        end
        local color = mine.total > 21 and "#FF6A6A" or "#7CFFA0"
        myTitle.Text = "YOUR HAND   <font color='" .. color .. "'>" .. mine.total .. "</font>   (bet " .. mine.bet .. ")   " .. mine.status
    else
        myTitle.Text = "YOUR HAND   -   you're sitting out this round"
    end
end

----------------------------------------------------------------
-- Messages from the game
----------------------------------------------------------------
local seenTutorial = false
remote.OnClientEvent:Connect(function(kind, data)
    data = data or {}
    if data.center then
        tableCenter = data.center
    end
    if data.mySpot then
        mySpot = data.mySpot
    end
    if not gui.Enabled then
        gui.Enabled = true
        if AUTO_TUTORIAL and not seenTutorial then
            seenTutorial = true
            showTutorial(1)
        end
    end

    if kind == "phase" then
        if data.phase == "betting" and phase ~= "betting" then
            myBetPlaced = false
            bet = math.min(lastBet, chips())
            clearRow(myCards)
            clearRow(dealerCards)
            myTitle.Text = "YOUR HAND"
            dealerTitle.Text = "DEALER"
            resultText.Visible = false
        end
        phase = data.phase
        bannerText.Text = myBetPlaced and data.phase == "betting" and "Bet placed! Waiting for the deal..." or data.text
        startTimer(data.time)
        showActions(false)
        refreshControls()
        if tableCenter and mySpot then
            local seat = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
            seat = seat and seat.SeatPart
            if seat then
                shoot("mine", seatView(seat.Position, mySpot))
            else
                shoot("mine", viewOf(mySpot))
            end
        end
    elseif kind == "hands" then
        renderHands(data)
    elseif kind == "turn" then
        phase = "playing"
        refreshControls()
        startTimer(data.time)
        if not tableCenter then
            return
        end
        if data.kind == "player" then
            if data.userId == player.UserId then
                bannerText.Text = "YOUR TURN!  Press HIT or STAND"
            else
                bannerText.Text = data.name .. "'s turn - watch their cards"
                showActions(false)
            end
            if data.seatPos then
                shoot("player" .. data.userId, seatView(data.seatPos, data.focus))
            else
                shoot("player" .. data.userId, viewOf(data.focus))
            end
        else
            bannerText.Text = "Dealer's turn..."
            showActions(false)
            shoot("dealer", data.eye, data.look)
        end
    elseif kind == "yourTurn" then
        showActions(true, data.canDouble)
        bannerText.Text = "YOUR TURN!  You have " .. data.total .. "  -  HIT or STAND?"
        startTimer(data.time)
    elseif kind == "turnOver" then
        showActions(false)
    elseif kind == "result" then
        resultText.Text = data.text
        resultText.TextColor3 = (data.delta or 0) > 0 and Color3.fromRGB(90, 255, 140)
            or ((data.delta or 0) < 0 and Color3.fromRGB(255, 90, 90) or Color3.fromRGB(255, 215, 110))
        resultText.Visible = true
        bannerText.Text = "Round over"
    elseif kind == "roundEnd" then
        resultText.Visible = false
        phase = ""
        restoreCamera()
    end
end)

----------------------------------------------------------------
-- Keep things tidy every frame
----------------------------------------------------------------
local joinPrompts = {}
for _, d in ipairs(workspace:GetDescendants()) do
    if d:IsA("ProximityPrompt") and d.Name == "BlackjackJoinPrompt" then
        table.insert(joinPrompts, d)
    end
end
workspace.DescendantAdded:Connect(function(d)
    if d:IsA("ProximityPrompt") and d.Name == "BlackjackJoinPrompt" then
        table.insert(joinPrompts, d)
    end
end)

RunService.Heartbeat:Connect(function()
    local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    local seated = humanoid and humanoid.SeatPart ~= nil
    for _, prompt in ipairs(joinPrompts) do
        -- hidden while you sit, and on chairs someone else is already in
        local seat = prompt.Parent
        prompt.Enabled = not seated and not (seat and seat:IsA("Seat") and seat.Occupant)
    end
    if gui.Enabled and not seated then
        gui.Enabled = false
        tutorial.Visible = false
        phase = ""
        restoreCamera()
    end
    chipsText.Text = "CHIPS  " .. chips()
end)

-- Hide your own character (and fade other players) while the game camera is on,
-- so nobody blocks your view of the cards. Only writes while the game camera is
-- on, plus one reset when it turns off, so Roblox's own first-person fade still
-- works the rest of the time.
local fadedLastFrame = false
RunService.RenderStepped:Connect(function()
    local gameCamOn = gui.Enabled and camera.CameraType == Enum.CameraType.Scriptable
    if not gameCamOn and not fadedLastFrame then
        return
    end
    fadedLastFrame = gameCamOn
    for _, plr in ipairs(Players:GetPlayers()) do
        local character = plr.Character
        if character then
            local amount = 0
            if gameCamOn then
                amount = (plr == player) and 1 or 0.6
            end
            for _, d in ipairs(character:GetDescendants()) do
                if d:IsA("BasePart") or d:IsA("Decal") then
                    d.LocalTransparencyModifier = amount
                end
            end
        end
    end
end)
