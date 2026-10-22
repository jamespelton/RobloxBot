-- BLACKJACK TURN CAMERA (LocalScript in StarterPlayer > StarterPlayerScripts)
-- James's "camera turns to whoever's turn it is", wired to the casino's
-- BlackjackTables server. Runs on top of BlackjackClient, which still owns the
-- bet / Hit / Stand / Double panel and swoops the camera in when you sit.
--   * Betting:        overview of the whole table
--   * Your turn:      camera moves in over your cards   ("YOUR TURN!  You have 14")
--   * Dealer's turn:  camera turns toward the dealer's cards ("Dealer's turn")
--   * C switches between this game camera and your normal camera.

-- Settings (distances are in card lengths, so they fit any table size):
local SHOT_TIME = 0.7
local YOUR_TURN_BACK, YOUR_TURN_UP = 3.6, 3.2     -- camera behind / above your cards
local DEALER_BACK, DEALER_UP = 2.0, 3.0           -- camera spot when looking at the dealer
local TOGGLE_KEY = Enum.KeyCode.C

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local remote = ReplicatedStorage:WaitForChild("BlackjackRemote")
local GOLD = Color3.fromRGB(212, 175, 55)

----------------------------------------------------------------
-- Turn banner
----------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "BlackjackTurnBanner"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local banner = Instance.new("TextLabel")
banner.AnchorPoint = Vector2.new(0.5, 0)
banner.Position = UDim2.new(0.5, 0, 0, 70)
banner.Size = UDim2.fromScale(0.4, 0.06)
banner.BackgroundColor3 = Color3.fromRGB(15, 12, 20)
banner.BackgroundTransparency = 0.15
banner.TextScaled = true
banner.Font = Enum.Font.GothamBlack
banner.TextColor3 = Color3.fromRGB(255, 215, 110)
banner.Text = ""
banner.Parent = gui
local bannerCorner = Instance.new("UICorner")
bannerCorner.CornerRadius = UDim.new(0.25, 0)
bannerCorner.Parent = banner
local bannerStroke = Instance.new("UIStroke")
bannerStroke.Color = GOLD
bannerStroke.Thickness = 2
bannerStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
bannerStroke.Parent = banner
local bannerPad = Instance.new("UIPadding")
bannerPad.PaddingTop = UDim.new(0.15, 0)
bannerPad.PaddingBottom = UDim.new(0.15, 0)
bannerPad.Parent = banner
local bannerScale = Instance.new("UIScale")
bannerScale.Parent = banner

local function setBanner(text)
    if banner.Text == text then
        return
    end
    banner.Text = text
    bannerScale.Scale = 1.15
    TweenService:Create(bannerScale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

----------------------------------------------------------------
-- Camera
----------------------------------------------------------------
local layouts = {}      -- [tableId] = layout from the server
local myLayout = nil    -- set while you're playing
local myTableId = nil   -- other tables broadcast too, so filter on this
local gameCamera = true -- C switches this
local lastShot = nil    -- CFrame, so C can switch back
local activeTween = nil
local yourTotal = nil   -- e.g. "14", "BUST", "BLACKJACK"
local turn = nil        -- "betting", "you", "dealer"

local function shoot(cframe)
    lastShot = cframe
    if not gameCamera then
        return
    end
    if activeTween then
        activeTween:Cancel()
    end
    camera.CameraType = Enum.CameraType.Scriptable
    activeTween = TweenService:Create(camera, TweenInfo.new(SHOT_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
        CFrame = cframe,
    })
    activeTween:Play()
end

local function normalCamera()
    if activeTween then
        activeTween:Cancel()
        activeTween = nil
    end
    camera.CameraType = Enum.CameraType.Custom
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        camera.CameraSubject = humanoid
    end
end

-- Row frames: X = your right, Y = up, Z = toward you (LookVector points at the dealer)
local function overviewShot()
    return myLayout.Camera
end
local function yourTurnShot()
    local row = myLayout.PlayerRow
    local cardL = myLayout.CardSize.Z
    local eye = (row * CFrame.new(0, cardL * YOUR_TURN_UP, cardL * YOUR_TURN_BACK)).Position
    local look = (row * CFrame.new(0, 0, -cardL * 0.6)).Position
    return CFrame.lookAt(eye, look)
end
local function dealerShot()
    local row = myLayout.PlayerRow
    local cardL = myLayout.CardSize.Z
    local eye = (row * CFrame.new(0, cardL * DEALER_UP, cardL * DEALER_BACK)).Position
    local look = myLayout.DealerRow.Position + Vector3.new(0, cardL * 0.2, 0)
    return CFrame.lookAt(eye, look)
end

local function setTurn(newTurn)
    if newTurn == "you" then
        setBanner("YOUR TURN!" .. (yourTotal and ("  You have " .. yourTotal) or ""))
    end
    if turn == newTurn then
        return
    end
    turn = newTurn
    if newTurn == "betting" then
        setBanner("Place your bet")
        shoot(overviewShot())
    elseif newTurn == "you" then
        shoot(yourTurnShot())
    elseif newTurn == "dealer" then
        setBanner("Dealer's turn")
        shoot(dealerShot())
    end
end

UserInputService.InputBegan:Connect(function(input, typing)
    if typing or input.KeyCode ~= TOGGLE_KEY or not myLayout then
        return
    end
    gameCamera = not gameCamera
    if gameCamera and lastShot then
        shoot(lastShot)
    elseif not gameCamera then
        normalCamera()
    end
end)

----------------------------------------------------------------
-- Messages from the game
----------------------------------------------------------------
remote.OnClientEvent:Connect(function(event, tableId, data)
    if event == "Open" then
        layouts[tableId] = data
    elseif event == "Joined" then
        myLayout = layouts[tableId]
        myTableId = tableId
        if myLayout then
            gui.Enabled = true
            gameCamera = true
            turn = nil
            yourTotal = nil
        end
    elseif event == "Left" then
        -- BlackjackClient gives the normal camera back; just stop moving it
        if activeTween then
            activeTween:Cancel()
            activeTween = nil
        end
        myLayout = nil
        myTableId = nil
        lastShot = nil
        turn = nil
        gui.Enabled = false
    elseif not myLayout or tableId ~= myTableId then
        return
    elseif event == "Value" and type(data) == "table" then
        yourTotal = data.Player
        if turn == "you" then
            setTurn("you") -- refresh the total in the banner
        end
    elseif event == "Clear" then
        yourTotal = nil
    elseif event == "State" then
        if data.Phase == "Betting" then
            setTurn("betting")
        elseif data.Phase == "Playing" then
            setTurn("you")
        elseif data.Phase == "Busy" and data.Message == "Dealer's turn..." then
            setTurn("dealer")
        end
        -- other Busy steps (dealing, drawing your card) keep the current shot
    end
end)

print("[Casino] BlackjackTurnCamera ready")
