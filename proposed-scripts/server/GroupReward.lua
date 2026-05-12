-- PASTE LOCATION: ServerScriptService.GroupReward (Script)
--
-- GroupReward — gives 500 coins + optional cape on first detection that a
-- player has joined the Roblox group. Tracks the "already claimed" flag in
-- DataManager so it only fires once per account.
--
-- DEPENDENCIES:
--   - ReplicatedStorage.GamepassConfig.Group.id is set to your real Group ID
--   - DataManager:GetData(player), :Save(player)
--   - leaderstats.Coins on the player
--
-- INTEGRATION HOOKS (other scripts called by us):
--   - Fires "GroupRewardClaimed" RemoteEvent to the client for splash UI
--   - Fires BadgeManager:OnGroupJoinDetected if BadgeManager is loaded

local Players = game:GetService("Players")
local GroupService = game:GetService("GroupService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GamepassConfig = require(ReplicatedStorage:WaitForChild("GamepassConfig"))
local groupCfg = GamepassConfig.Group

local FLAG_KEY = "GroupRewardClaimed"

local function getDataManager()
	local m = ServerScriptService:FindFirstChild("DataManager")
	if m and m:IsA("ModuleScript") then return require(m) end
	return nil
end
local DataManager = getDataManager()

local function getBadgeManager()
	local m = ServerScriptService:FindFirstChild("BadgeManager")
	if m and m:IsA("ModuleScript") then return require(m) end
	return nil
end

local function ensureRemoteEvent()
	local gameEvents = ReplicatedStorage:FindFirstChild("GameEvents")
	if not gameEvents then
		gameEvents = Instance.new("Folder")
		gameEvents.Name = "GameEvents"
		gameEvents.Parent = ReplicatedStorage
	end
	local e = gameEvents:FindFirstChild("GroupRewardClaimed")
	if not e then
		e = Instance.new("RemoteEvent")
		e.Name = "GroupRewardClaimed"
		e.Parent = gameEvents
	end
	return e
end
local rewardEvent = ensureRemoteEvent()

local function tryGrantCape(player)
	if not groupCfg.exclusiveCapeAssetId or groupCfg.exclusiveCapeAssetId == 0 then
		return -- no cape configured
	end
	-- Best-effort: load asset and attach as Accessory
	local ok, asset = pcall(function()
		return game:GetService("InsertService"):LoadAsset(groupCfg.exclusiveCapeAssetId)
	end)
	if not ok or not asset then return end
	-- Find an accessory in the asset
	local accessory = asset:FindFirstChildWhichIsA("Accessory", true)
	if accessory and player.Character and player.Character:FindFirstChildOfClass("Humanoid") then
		accessory.Parent = nil -- detach from temp model
		player.Character.Humanoid:AddAccessory(accessory)
	end
	asset:Destroy()
end

local function checkAndReward(player)
	if not groupCfg.id or groupCfg.id == 0 then return end
	if not DataManager then return end
	local data = DataManager:GetData(player)
	if not data or data[FLAG_KEY] then return end

	-- Check group membership
	local isInGroup = false
	pcall(function()
		isInGroup = player:IsInGroup(groupCfg.id)
	end)
	if not isInGroup then return end

	-- Grant coins
	local leaderstats = player:FindFirstChild("leaderstats")
	local coinsValue = leaderstats and leaderstats:FindFirstChild("Coins")
	if coinsValue then
		coinsValue.Value = coinsValue.Value + groupCfg.rewardCoins
	end

	-- Grant cape (if configured)
	tryGrantCape(player)

	-- Flag + save
	data[FLAG_KEY] = true
	pcall(function() DataManager:Save(player) end)

	-- Notify client + badge
	rewardEvent:FireClient(player, { coins = groupCfg.rewardCoins })
	local BadgeManager = getBadgeManager()
	if BadgeManager and BadgeManager.OnGroupJoinDetected then
		BadgeManager:OnGroupJoinDetected(player)
	end

	print(("[GroupReward] %s claimed +%d coins for being in group %d"):format(
		player.Name, groupCfg.rewardCoins, groupCfg.id))
end

local function onPlayerAdded(player)
	-- Delay so DataManager has loaded
	task.wait(4)
	if not player.Parent then return end
	checkAndReward(player)
	-- Also re-check when character respawns (in case they join the group mid-session)
	player.CharacterAdded:Connect(function()
		task.wait(1)
		checkAndReward(player)
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(onPlayerAdded, p) end

print("[GroupReward] Initialized.")
