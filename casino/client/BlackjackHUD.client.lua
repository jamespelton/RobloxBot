-- BLACKJACK CAMERA + BUTTONS v2 (LocalScript in StarterPlayer > StarterPlayerScripts)
local MIN_BET, MAX_BET, DEFAULT_BET = 10, 500, 50
local SWING_TIME = 1.4   -- seconds for the camera to swing around the table

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
local function flat(v)
    return V(v.X, 0, v.Z)
end

----------------------------------------------------------------
-- Screen
----------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "BlackjackHUD"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local function corner(parent, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(r or 0.25, 0)
    c.Parent = parent
end
local function outline(parent)
    local s = Instance.new("UIStroke")
    s.Color = GOLD
    s.Thickness = 2
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = parent
end
local function makeButton(text, color, parent)
    local b = Instance.new("TextButton")
    b.BackgroundColor3 = color
    b.Text = text
    b.TextScaled = true
    b.Font = Enum.Font.GothamBlack
    b.TextColor3 = Color3.new(1, 1, 1)
    b.Parent = parent
    corner(b)
    outline(b)
    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0.2, 0)
    pad.PaddingBottom = UDim.new(0.2, 0)
    pad.Parent = b
    return b
end
local function row(parent)
    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.VerticalAlignment = Enum.VerticalAlignment.Center
    layout.Padding = UDim.new(0.02, 0)
    layout.Parent = parent
end

local banner = Instance.new("TextLabel")
banner.AnchorPoint = Vector2.new(0.5, 0)
banner.Position = UDim2.new(0.5, 0, 0, 70)
banner.Size = UDim2.fromScale(0.5, 0.07)
banner.BackgroundColor3 = Color3.fromRGB(15, 12, 20)
banner.BackgroundTransparency = 0.15
banner.TextScaled = true
banner.Font = Enum.Font.GothamBlack
banner.TextColor3 = Color3.fromRGB(255, 215, 110)
banner.Text = ""
banner.Parent = gui
corner(banner)
outline(banner)

local bar = Instance.new("Frame")
bar.AnchorPoint = Vector2.new(0.5, 1)
bar.Position = UDim2.new(0.5, 0, 1, -20)
bar.Size = UDim2.fromScale(0.5, 0.12)
bar.BackgroundColor3 = Color3.fromRGB(15, 12, 20)
bar.BackgroundTransparency = 0.15
bar.Parent = gui
corner(bar, 0.2)
outline(bar)
row(bar)

local betGroup = Instance.new("Frame")
betGroup.Size = UDim2.fromScale(0.96, 0.75)
betGroup.BackgroundTransparency = 1
betGroup.Parent = bar
row(betGroup)
local minus = makeButton("−", Color3.fromRGB(60, 50, 70), betGroup)
minus.Size = UDim2.fromScale(0.15, 1)
local betLabel = Instance.new("TextLabel")
betLabel.Size = UDim2.fromScale(0.3, 1)
betLabel.BackgroundTransparency = 1
betLabel.TextScaled = true
betLabel.Font = Enum.Font.GothamBlack
betLabel.TextColor3 = Color3.new(1, 1, 1)
betLabel.Parent = betGroup
local plus = makeButton("+", Color3.fromRGB(60, 50, 70), betGroup)
plus.Size = UDim2.fromScale(0.15, 1)
local betButton = makeButton("BET", Color3.fromRGB(20, 110, 50), betGroup)
betButton.Size = UDim2.fromScale(0.25, 1)

local actionGroup = Instance.new("Frame")
actionGroup.Size = UDim2.fromScale(0.96, 0.75)
actionGroup.BackgroundTransparency = 1
actionGroup.Visible = false
actionGroup.Parent = bar
row(actionGroup)
local hit = makeButton("HIT", Color3.fromRGB(20, 110, 50), actionGroup)
hit.Size = UDim2.fromScale(0.3, 1)
local stand = makeButton("STAND", Color3.fromRGB(150, 25, 35), actionGroup)
stand.Size = UDim2.fromScale(0.3, 1)
local double = makeButton("DOUBLE", Color3.fromRGB(170, 130, 30), actionGroup)
double.Size = UDim2.fromScale(0.3, 1)

local timerBar = Instance.new("Frame")
timerBar.AnchorPoint = Vector2.new(0, 1)
timerBar.Position = UDim2.fromScale(0, 1)
timerBar.Size = UDim2.fromScale(1, 0.06)
timerBar.BackgroundColor3 = GOLD
timerBar.BorderSizePixel = 0
timerBar.Parent = bar

local resultLabel = Instance.new("TextLabel")
resultLabel.AnchorPoint = Vector2.new(0.5, 0.5)
resultLabel.Position = UDim2.fromScale(0.5, 0.42)
resultLabel.Size = UDim2.fromScale(0.5, 0.1)
resultLabel.BackgroundTransparency = 1
resultLabel.TextScaled = true
resultLabel.Font = Enum.Font.GothamBlack
resultLabel.TextColor3 = Color3.fromRGB(255, 215, 110)
resultLabel.Visible = false
resultLabel.Parent = gui
local resultStroke = Instance.new("UIStroke")
resultStroke.Thickness = 3
resultStroke.Parent = resultLabel

local bet = DEFAULT_BET
local function refreshBet()
    betLabel.Text = "BET  " .. bet
end
refreshBet()
minus.MouseButton1Click:Connect(function()
    bet = math.max(MIN_BET, bet - (bet > 100 and 50 or 10))
    refreshBet()
end)
plus.MouseButton1Click:Connect(function()
    bet = math.min(MAX_BET, bet + (bet >= 100 and 50 or 10))
    refreshBet()
end)
betButton.MouseButton1Click:Connect(function()
    remote:FireServer("bet", bet)
    betGroup.Visible = false
    banner.Text = "Bet placed: " .. bet .. "  -  waiting for others..."
end)
hit.MouseButton1Click:Connect(function()
    remote:FireServer("action", "hit")
end)
stand.MouseButton1Click:Connect(function()
    remote:FireServer("action", "stand")
    actionGroup.Visible = false
end)
double.MouseButton1Click:Connect(function()
    remote:FireServer("action", "double")
    actionGroup.Visible = false
end)

local function startTimer(seconds)
    timerBar.Size = UDim2.fromScale(1, 0.06)
    if seconds and seconds > 0 then
        TweenService:Create(timerBar, TweenInfo.new(seconds, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(0, 0.06) }):Play()
    end
end

----------------------------------------------------------------
-- Camera: swings around the table to each person's point of view
----------------------------------------------------------------
local gameCamera = true -- press C to switch
local lastShot
local tableCenter
local swing

local function stopSwing()
    if swing then
        swing:Disconnect()
        swing = nil
    end
end

local function shoot(eye, target)
    lastShot = { eye = eye, target = target }
    if not gameCamera then
        return
    end
    stopSwing()
    camera.CameraType = Enum.CameraType.Scriptable
    local startCF = camera.CFrame
    local startEye = startCF.Position
    local startTarget = startEye + startCF.LookVector * math.max((target - eye).Magnitude, 4)
    local pivot = tableCenter or (eye + target) / 2

    -- Work in circles around the table so the camera orbits instead of sliding
    local function polar(p)
        local d = p - pivot
        return math.atan2(d.Z, d.X), flat(d).Magnitude, d.Y
    end
    local a0, r0, h0 = polar(startEye)
    local a1, r1, h1 = polar(eye)
    local da = (a1 - a0 + math.pi) % (2 * math.pi) - math.pi
    local t0 = os.clock()

    swing = RunService.RenderStepped:Connect(function()
        local alpha = math.clamp((os.clock() - t0) / SWING_TIME, 0, 1)
        local e = alpha < 0.5 and 2 * alpha * alpha or 1 - ((-2 * alpha + 2) ^ 2) / 2
        local angle = a0 + da * e
        local radius = r0 + (r1 - r0) * e
        local height = h0 + (h1 - h0) * e
        local position = pivot + V(math.cos(angle) * radius, height, math.sin(angle) * radius)
        camera.CFrame = CFrame.lookAt(position, startTarget:Lerp(target, e))
        if alpha >= 1 then
            stopSwing()
        end
    end)
end

local function restoreCamera()
    stopSwing()
    lastShot = nil
    camera.CameraType = Enum.CameraType.Custom
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        camera.CameraSubject = humanoid
    end
end

local function mySeat()
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    return humanoid and humanoid.SeatPart
end

-- View from behind a chair, looking down at that seat's cards
local function seatView(seatPos, spot)
    local outward = flat(seatPos - tableCenter).Unit
    return seatPos + outward * 3 + UP * 6, spot
end

UserInputService.InputBegan:Connect(function(input, typing)
    if typing or input.KeyCode ~= Enum.KeyCode.C or not gui.Enabled then
        return
    end
    gameCamera = not gameCamera
    if gameCamera and lastShot then
        shoot(lastShot.eye, lastShot.target)
    elseif not gameCamera then
        local saved = lastShot
        restoreCamera()
        lastShot = saved
    end
end)

----------------------------------------------------------------
-- Messages from the game
----------------------------------------------------------------
remote.OnClientEvent:Connect(function(kind, data)
    gui.Enabled = true
    if data and data.center then
        tableCenter = data.center
    end
    local seat = mySeat()

    if kind == "phase" then
        banner.Text = data.text
        resultLabel.Visible = false
        actionGroup.Visible = false
        betGroup.Visible = data.phase == "betting"
        startTimer(data.time)
        -- Start from your own seat while betting and dealing
        if seat and tableCenter and data.mySpot then
            shoot(seatView(seat.Position, data.mySpot))
        end
    elseif kind == "turn" then
        startTimer(data.time)
        if not tableCenter then
            return
        end
        if data.kind == "player" then
            if data.userId == player.UserId then
                banner.Text = "YOUR TURN!"
            else
                banner.Text = data.name .. "'s turn"
                actionGroup.Visible = false
            end
            -- Swing around to behind that player's chair
            shoot(seatView(data.seatPos, data.focus))
        else
            -- Swing around to behind the dealer, looking back at the players
            banner.Text = "Dealer's turn"
            actionGroup.Visible = false
            shoot(data.eye, data.look)
        end
    elseif kind == "yourTurn" then
        actionGroup.Visible = true
        betGroup.Visible = false
        double.Visible = data.canDouble
        banner.Text = "YOUR TURN!  You have " .. data.total
        startTimer(data.time)
    elseif kind == "turnOver" then
        actionGroup.Visible = false
    elseif kind == "result" then
        resultLabel.Text = data.text
        resultLabel.TextColor3 = (data.delta or 0) > 0 and Color3.fromRGB(90, 255, 140)
            or ((data.delta or 0) < 0 and Color3.fromRGB(255, 90, 90) or Color3.fromRGB(255, 215, 110))
        resultLabel.Visible = true
    elseif kind == "roundEnd" then
        resultLabel.Visible = false
        restoreCamera()
    end
end)

RunService.Heartbeat:Connect(function()
    if gui.Enabled and not mySeat() then
        gui.Enabled = false
        restoreCamera()
    end
end)
