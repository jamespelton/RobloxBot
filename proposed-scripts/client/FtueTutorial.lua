-- PASTE LOCATION: StarterPlayer.StarterPlayerScripts.FtueTutorial (LocalScript)
--
-- FtueTutorial — shows a 3-popup walkthrough on first spawn. Skippable.
-- Triggered by the FirstTimeGiftReceived RemoteEvent from server (so it only
-- shows for genuinely-new players).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local FtueConfig = require(ReplicatedStorage:WaitForChild("FtueConfig"))
local cfg = FtueConfig.Tutorial

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local function buildGui()
	local screen = Instance.new("ScreenGui")
	screen.Name = "FtueTutorial"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.DisplayOrder = 50
	screen.Parent = playerGui

	-- Dimmed backdrop
	local backdrop = Instance.new("Frame")
	backdrop.Name = "Backdrop"
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	backdrop.BackgroundTransparency = 0.4
	backdrop.BorderSizePixel = 0
	backdrop.Parent = screen

	-- Centered card
	local card = Instance.new("Frame")
	card.Name = "Card"
	card.Size = UDim2.fromOffset(560, 320)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.BackgroundColor3 = Color3.fromRGB(30, 20, 40)
	card.BorderSizePixel = 0
	card.Parent = backdrop

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = card

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(255, 45, 149) -- hot pink crystal
	stroke.Parent = card

	-- Title
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -40, 0, 50)
	title.Position = UDim2.fromOffset(20, 20)
	title.BackgroundTransparency = 1
	title.TextColor3 = Color3.fromRGB(255, 215, 0)
	title.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	title.TextStrokeTransparency = 0
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = card

	-- Body
	local body = Instance.new("TextLabel")
	body.Name = "Body"
	body.Size = UDim2.new(1, -40, 0, 140)
	body.Position = UDim2.fromOffset(20, 80)
	body.BackgroundTransparency = 1
	body.TextColor3 = Color3.fromRGB(240, 240, 240)
	body.Font = Enum.Font.Gotham
	body.TextScaled = true
	body.TextWrapped = true
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.Parent = card

	-- Step indicator (1/3, 2/3, 3/3)
	local step = Instance.new("TextLabel")
	step.Name = "Step"
	step.Size = UDim2.fromOffset(80, 28)
	step.Position = UDim2.new(0, 20, 1, -60)
	step.BackgroundTransparency = 1
	step.TextColor3 = Color3.fromRGB(180, 180, 180)
	step.Font = Enum.Font.GothamSemibold
	step.TextScaled = true
	step.Parent = card

	-- Skip link
	local skip = Instance.new("TextButton")
	skip.Name = "Skip"
	skip.Size = UDim2.fromOffset(120, 28)
	skip.Position = UDim2.new(0.5, -60, 1, -60)
	skip.BackgroundTransparency = 1
	skip.Text = cfg.CanSkipAll and "Skip tutorial" or ""
	skip.TextColor3 = Color3.fromRGB(180, 180, 180)
	skip.Font = Enum.Font.Gotham
	skip.TextScaled = true
	skip.Parent = card
	skip.Visible = cfg.CanSkipAll

	-- Advance button
	local advance = Instance.new("TextButton")
	advance.Name = "Advance"
	advance.Size = UDim2.fromOffset(160, 50)
	advance.Position = UDim2.new(1, -180, 1, -70)
	advance.BackgroundColor3 = Color3.fromRGB(255, 45, 149)
	advance.BorderSizePixel = 0
	advance.TextColor3 = Color3.fromRGB(255, 255, 255)
	advance.Font = Enum.Font.GothamBold
	advance.TextScaled = true
	advance.AutoButtonColor = true
	advance.Parent = card
	local advCorner = Instance.new("UICorner")
	advCorner.CornerRadius = UDim.new(0, 8)
	advCorner.Parent = advance

	return { screen = screen, card = card, title = title, body = body, step = step, skip = skip, advance = advance }
end

local function runTutorial()
	local gui = buildGui()
	local idx = 1
	local function render()
		local popup = cfg.Popups[idx]
		if not popup then
			gui.screen:Destroy()
			return
		end
		gui.title.Text = popup.title
		gui.body.Text = popup.body
		gui.step.Text = ("%d / %d"):format(idx, #cfg.Popups)
		gui.advance.Text = popup.advanceLabel or (idx == #cfg.Popups and "Start" or "Next")
	end
	render()

	gui.advance.MouseButton1Click:Connect(function()
		idx = idx + 1
		render()
	end)
	gui.skip.MouseButton1Click:Connect(function()
		gui.screen:Destroy()
	end)
end

-- Trigger: only show on FirstTimeGiftReceived (genuinely-new players)
local function waitForGiftEvent()
	local gameEvents = ReplicatedStorage:WaitForChild("GameEvents", 10)
	if not gameEvents then return end
	local event = gameEvents:WaitForChild("FirstTimeGiftReceived", 10)
	if not event then return end
	event.OnClientEvent:Connect(function()
		task.wait(cfg.ShowDelaySeconds)
		runTutorial()
	end)
end

waitForGiftEvent()
