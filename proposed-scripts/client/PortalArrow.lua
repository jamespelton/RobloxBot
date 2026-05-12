-- PASTE LOCATION: StarterPlayer.StarterPlayerScripts.PortalArrow (LocalScript)
--
-- PortalArrow — floating yellow arrow above the ReadyPortal that bobs up/down.
-- Visible for first N sessions per FtueConfig.PortalArrow.ShowForFirstNPlays.
-- Disappears once player enters the portal or after they've played N times.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local FtueConfig = require(ReplicatedStorage:WaitForChild("FtueConfig"))
local cfg = FtueConfig.PortalArrow

local player = Players.LocalPlayer

-- Find the portal anchor (uses center of ReadyPortal model in Lobby)
local function findPortalAnchor()
	local lobby = Workspace:FindFirstChild("Lobby")
	if not lobby then return nil end
	local portal = lobby:FindFirstChild("ReadyPortal")
	if not portal then return nil end
	if portal:IsA("Model") then
		return portal:GetPivot().Position
	elseif portal:IsA("BasePart") then
		return portal.Position
	end
	return nil
end

-- Build the arrow as a BillboardGui attached to a tiny anchor part
local function createArrow(position)
	local anchor = Instance.new("Part")
	anchor.Name = "RexPortalArrowAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.1, 0.1, 0.1)
	anchor.Position = position + Vector3.new(0, cfg.FloatHeightStuds, 0)
	anchor.Parent = Workspace.CurrentCamera -- camera scope so it only renders for this client

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Arrow"
	billboard.AlwaysOnTop = true
	billboard.Size = UDim2.fromOffset(120, 120)
	billboard.Parent = anchor

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "▼"
	label.TextColor3 = cfg.Color
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextStrokeTransparency = 0
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = billboard

	local sub = Instance.new("TextLabel")
	sub.Size = UDim2.fromScale(2.5, 0.35)
	sub.Position = UDim2.fromScale(-0.75, -0.4)
	sub.BackgroundTransparency = 1
	sub.Text = "Enter the portal to start"
	sub.TextColor3 = Color3.fromRGB(255, 255, 255)
	sub.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	sub.TextStrokeTransparency = 0
	sub.TextScaled = true
	sub.Font = Enum.Font.GothamSemibold
	sub.Parent = billboard

	return anchor, billboard
end

-- Check if we should show the arrow (use plays count via Player attribute, or default true)
local function shouldShow()
	-- Best-effort: read playsCount attribute (set by server FirstTimeGift / DataManager).
	local plays = player:GetAttribute("PlaysCount") or 1
	return plays <= cfg.ShowForFirstNPlays
end

-- Main loop
local function start()
	if not shouldShow() then return end
	local anchorPos = findPortalAnchor()
	if not anchorPos then
		warn("[PortalArrow] ReadyPortal not found in Workspace.Lobby — arrow disabled.")
		return
	end
	local anchor = createArrow(anchorPos)
	local startTime = tick()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		if not anchor.Parent then conn:Disconnect() return end
		local t = tick() - startTime
		local offset = math.sin(t * cfg.BobSpeed) * cfg.BobAmplitude
		anchor.Position = anchorPos + Vector3.new(0, cfg.FloatHeightStuds + offset, 0)
	end)

	-- Auto-hide when player enters arena (use ChosenMap attribute change or ReadyUpManager event)
	local function maybeHide()
		local chosenMap = ReplicatedStorage:FindFirstChild("ChosenMap")
		if chosenMap and chosenMap.Value ~= "" then
			if anchor then anchor:Destroy() end
			if conn then conn:Disconnect() end
		end
	end
	local chosenMap = ReplicatedStorage:FindFirstChild("ChosenMap")
	if chosenMap then
		chosenMap.Changed:Connect(maybeHide)
	end
	-- Also auto-destroy after 5 minutes regardless (safety)
	task.delay(300, function()
		if anchor then anchor:Destroy() end
	end)
end

-- Wait a moment for workspace + Lobby to be ready
task.wait(2)
start()
