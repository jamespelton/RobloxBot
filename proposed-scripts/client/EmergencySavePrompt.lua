-- PASTE LOCATION: StarterPlayer.StarterPlayerScripts.EmergencySavePrompt (LocalScript)
--
-- EmergencySavePrompt — client UI that shows the 49-Robux Save offer when the
-- server fires EmergencySavePrompt. Clicking [SAVE NOW] triggers
-- MarketplaceService:PromptProductPurchase. Player can dismiss.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local gameEvents = ReplicatedStorage:WaitForChild("GameEvents")
local promptEvent = gameEvents:WaitForChild("EmergencySavePrompt")
local activatedEvent = gameEvents:WaitForChild("EmergencySaveActivated")

local activeGui = nil

local function buildGui(payload)
	if activeGui then activeGui:Destroy() end

	local screen = Instance.new("ScreenGui")
	screen.Name = "EmergencySavePrompt"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 100 -- above gameplay UI
	screen.Parent = playerGui

	-- Top-center banner with pulsing red glow
	local banner = Instance.new("Frame")
	banner.Name = "Banner"
	banner.Size = UDim2.fromOffset(540, 130)
	banner.Position = UDim2.new(0.5, 0, 0, 60)
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.BackgroundColor3 = Color3.fromRGB(35, 10, 10)
	banner.BorderSizePixel = 0
	banner.Parent = screen

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = banner

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(255, 50, 50)
	stroke.Parent = banner

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -24, 0, 36)
	title.Position = UDim2.fromOffset(12, 8)
	title.BackgroundTransparency = 1
	title.Text = "⚠ CRYSTAL CRITICAL!"
	title.TextColor3 = Color3.fromRGB(255, 80, 80)
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	title.TextStrokeTransparency = 0
	title.Parent = banner

	local body = Instance.new("TextLabel")
	body.Size = UDim2.new(1, -24, 0, 36)
	body.Position = UDim2.fromOffset(12, 44)
	body.BackgroundTransparency = 1
	body.Text = ("Restore to 50%% + stun enemies %ds"):format(payload.stunDuration)
	body.TextColor3 = Color3.fromRGB(230, 230, 230)
	body.Font = Enum.Font.GothamSemibold
	body.TextScaled = true
	body.Parent = banner

	-- SAVE NOW button
	local save = Instance.new("TextButton")
	save.Size = UDim2.fromOffset(220, 36)
	save.Position = UDim2.new(0, 12, 1, -42)
	save.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
	save.BorderSizePixel = 0
	save.Text = "SAVE NOW — 49 R$"
	save.TextColor3 = Color3.fromRGB(20, 0, 0)
	save.Font = Enum.Font.GothamBold
	save.TextScaled = true
	save.AutoButtonColor = true
	save.Parent = banner
	local saveCorner = Instance.new("UICorner")
	saveCorner.CornerRadius = UDim.new(0, 6)
	saveCorner.Parent = save

	-- Dismiss link
	local dismiss = Instance.new("TextButton")
	dismiss.Size = UDim2.fromOffset(140, 28)
	dismiss.Position = UDim2.new(1, -152, 1, -38)
	dismiss.BackgroundTransparency = 1
	dismiss.Text = "Dismiss"
	dismiss.TextColor3 = Color3.fromRGB(180, 180, 180)
	dismiss.Font = Enum.Font.Gotham
	dismiss.TextScaled = true
	dismiss.Parent = banner

	save.MouseButton1Click:Connect(function()
		MarketplaceService:PromptProductPurchase(player, payload.productId)
		screen:Destroy()
		activeGui = nil
	end)
	dismiss.MouseButton1Click:Connect(function()
		screen:Destroy()
		activeGui = nil
	end)

	-- Auto-dismiss after 10 seconds
	task.delay(10, function()
		if screen.Parent then screen:Destroy() end
		if activeGui == screen then activeGui = nil end
	end)

	-- Pulse the stroke
	task.spawn(function()
		while screen.Parent do
			TweenService:Create(stroke, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Thickness = 5 }):Play()
			task.wait(0.6)
			if not screen.Parent then return end
			TweenService:Create(stroke, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Thickness = 2 }):Play()
			task.wait(0.6)
		end
	end)

	activeGui = screen
end

promptEvent.OnClientEvent:Connect(buildGui)

-- Announcement when someone activates (small top toast for all players)
activatedEvent.OnClientEvent:Connect(function(payload)
	local screen = Instance.new("ScreenGui")
	screen.Name = "EmergencySaveAnnounce"
	screen.DisplayOrder = 110
	screen.Parent = playerGui

	local toast = Instance.new("TextLabel")
	toast.Size = UDim2.fromOffset(540, 60)
	toast.Position = UDim2.new(0.5, 0, 0, 12)
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
	toast.BorderSizePixel = 0
	toast.Text = ("%s saved the crystal! +%d HP, %ds stun"):format(payload.playerName, payload.restoredHP, payload.stunDuration)
	toast.TextColor3 = Color3.fromRGB(40, 10, 0)
	toast.Font = Enum.Font.GothamBlack
	toast.TextScaled = true
	toast.Parent = screen
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 10)
	c.Parent = toast

	task.delay(4, function() screen:Destroy() end)
end)
