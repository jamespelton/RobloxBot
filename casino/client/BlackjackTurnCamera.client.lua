-- BLACKJACK TURN CAMERA (LocalScript in StarterPlayer > StarterPlayerScripts)
-- James's "camera turns to whoever's turn it is", wired to the casino's
-- BlackjackTables server. Runs on top of BlackjackClient, which still owns the
-- bet / Hit / Stand / Double panel and swoops the camera in when you sit.
--   * Betting + your turn: view from behind your spot, looking at your cards
--   * Dealer's turn: the camera swings round the table to behind the dealer,
--     looking back at you ("Dealer's turn")
--   * Moves orbit around the table centre instead of sliding (v2).
--   * C switches between this game camera and your normal camera.

-- Settings (distances are in card lengths, so they fit any table size):
local SWING_TIME = 1.4                             -- seconds for the camera to swing around the table
local YOUR_TURN_BACK, YOUR_TURN_UP = 3.6, 3.2     -- camera behind / above your cards
local DEALER_BACK, DEALER_UP = 3.0, 3.0           -- camera behind / above the dealer's cards
local JOIN_SWOOP = 0.95                           -- BlackjackClient's sit-down camera move; wait it out
local TOGGLE_KEY = Enum.KeyCode.C

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
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
local lastShot = nil    -- { eye, target }, so C can switch back
local swing = nil       -- RenderStepped connection while the camera is moving
local joinedAt = 0
local yourTotal = nil   -- e.g. "14", "BUST", "BLACKJACK"
local turn = nil        -- "betting", "you", "dealer"

local function flat(v)
    return Vector3.new(v.X, 0, v.Z)
end

local function stopSwing()
    if swing then
        swing:Disconnect()
        swing = nil
    end
end

local function shoot(shot)
    lastShot = shot
    if not gameCamera or not myLayout then
        return
    end
    -- let BlackjackClient finish swooping in before we start moving the camera
    local remaining = JOIN_SWOOP - (os.clock() - joinedAt)
    if remaining > 0 then
        task.delay(remaining, function()
            if lastShot == shot then
                shoot(shot)
            end
        end)
        return
    end
    stopSwing()
    camera.CameraType = Enum.CameraType.Scriptable

    local eye, target = shot.eye, shot.target
    local startCF = camera.CFrame
    local startEye = startCF.Position
    local startTarget = startEye + startCF.LookVector * math.max((target - eye).Magnitude, 4)
    local pivot = myLayout.Center.Position

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
        local position = pivot + Vector3.new(math.cos(angle) * radius, height, math.sin(angle) * radius)
        camera.CFrame = CFrame.lookAt(position, startTarget:Lerp(target, e))
        if alpha >= 1 then
            stopSwing()
        end
    end)
end

local function normalCamera()
    stopSwing()
    camera.CameraType = Enum.CameraType.Custom
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        camera.CameraSubject = humanoid
    end
end

-- Row frames: X = your right, Y = up, Z = toward you (LookVector points at the dealer)
-- View from behind your spot, looking down at your cards
local function yourShot()
    local row = myLayout.PlayerRow
    local cardL = myLayout.CardSize.Z
    return {
        eye = (row * CFrame.new(0, cardL * YOUR_TURN_UP, cardL * YOUR_TURN_BACK)).Position,
        target = (row * CFrame.new(0, 0, -cardL * 0.6)).Position,
    }
end
-- View from behind the dealer, looking back across the table at you
local function dealerShot()
    local row = myLayout.DealerRow
    local cardL = myLayout.CardSize.Z
    return {
        eye = (row * CFrame.new(0, cardL * DEALER_UP, -cardL * DEALER_BACK)).Position,
        target = (myLayout.PlayerRow.Position + row.Position) / 2,
    }
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
        shoot(yourShot())
    elseif newTurn == "you" then
        shoot(yourShot())
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
            joinedAt = os.clock()
            turn = nil
            yourTotal = nil
        end
    elseif event == "Left" then
        -- BlackjackClient gives the normal camera back; just stop moving it
        stopSwing()
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
