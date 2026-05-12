-- PASTE LOCATION: ServerScriptService.FirstTimeGift (Script)
--
-- FirstTimeGift — gives new players 500 coins + 1 free Common chest on their
-- very first spawn ever. Tracks the "received" flag in DataManager so they
-- only get it once per account.
--
-- DEPENDENCIES:
--   - DataManager must expose :GetData(player) -> table, :Save(player)
--   - LootSystem must expose :GrantChest(player, rarity) -- OR fires a
--     "GrantChest" RemoteEvent in ReplicatedStorage.GameEvents
--   - leaderstats.Coins must exist on the player
--
-- INTEGRATION HOOKS:
--   - Player.OnAdded is listened to internally; no other script needs to call this.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local FtueConfig = require(ReplicatedStorage:WaitForChild("FtueConfig"))
-- DataManager: tries multiple common locations
local function getDataManager()
	local candidates = {
		ServerScriptService:FindFirstChild("DataManager"),
		ServerScriptService:FindFirstChild("DataStoreManager"),
	}
	for _, candidate in ipairs(candidates) do
		if candidate and candidate:IsA("ModuleScript") then
			return require(candidate)
		end
	end
	warn("[FirstTimeGift] DataManager module not found in ServerScriptService.")
	return nil
end

local DataManager = getDataManager()
local FLAG_KEY = "FirstTimeGiftClaimed"
local GIFT_EVENT_NAME = "FirstTimeGiftReceived" -- RemoteEvent → client shows splash

-- Ensure RemoteEvent exists so client can show celebratory UI.
local function ensureRemoteEvent()
	local gameEvents = ReplicatedStorage:FindFirstChild("GameEvents")
	if not gameEvents then
		gameEvents = Instance.new("Folder")
		gameEvents.Name = "GameEvents"
		gameEvents.Parent = ReplicatedStorage
	end
	local event = gameEvents:FindFirstChild(GIFT_EVENT_NAME)
	if not event then
		event = Instance.new("RemoteEvent")
		event.Name = GIFT_EVENT_NAME
		event.Parent = gameEvents
	end
	return event
end

local giftEvent = ensureRemoteEvent()

local function grantChest(player)
	if not FtueConfig.FirstTimeGift.GrantChest then return end
	-- Prefer LootSystem module if available; else fire GrantChest RemoteEvent.
	local lootModule = ServerScriptService:FindFirstChild("LootSystem")
	if lootModule and lootModule:IsA("ModuleScript") then
		local LootSystem = require(lootModule)
		if LootSystem.GrantChest then
			pcall(function()
				LootSystem:GrantChest(player, FtueConfig.FirstTimeGift.ChestRarity)
			end)
			return
		end
	end
	-- Fallback: fire RemoteEvent for client-side chest opening or server LootSystem listener
	local gameEvents = ReplicatedStorage:FindFirstChild("GameEvents")
	local grantChestEvent = gameEvents and gameEvents:FindFirstChild("GrantChest")
	if grantChestEvent and grantChestEvent:IsA("RemoteEvent") then
		grantChestEvent:FireClient(player, FtueConfig.FirstTimeGift.ChestRarity)
	else
		warn("[FirstTimeGift] No LootSystem module nor GrantChest RemoteEvent — chest skipped.")
	end
end

local function tryGiveGift(player)
	if not DataManager then return end
	local data = DataManager:GetData(player)
	if not data then
		warn(("[FirstTimeGift] No data for %s — skipping."):format(player.Name))
		return
	end
	if data[FLAG_KEY] then
		return -- already claimed
	end

	-- Grant coins
	local leaderstats = player:FindFirstChild("leaderstats")
	local coinsValue = leaderstats and leaderstats:FindFirstChild("Coins")
	if coinsValue then
		coinsValue.Value = coinsValue.Value + FtueConfig.FirstTimeGift.Coins
	else
		warn(("[FirstTimeGift] leaderstats.Coins not found on %s"):format(player.Name))
	end

	-- Grant chest
	grantChest(player)

	-- Set flag + save
	data[FLAG_KEY] = true
	pcall(function() DataManager:Save(player) end)

	-- Notify client (for confetti/popup)
	giftEvent:FireClient(player, {
		coins = FtueConfig.FirstTimeGift.Coins,
		chest = FtueConfig.FirstTimeGift.GrantChest,
	})

	print(("[FirstTimeGift] Granted to %s — %d coins + %s chest"):format(
		player.Name, FtueConfig.FirstTimeGift.Coins,
		FtueConfig.FirstTimeGift.GrantChest and FtueConfig.FirstTimeGift.ChestRarity or "no"
	))
end

-- Wait until DataManager has loaded the player's data before granting.
-- We rely on DataManager firing a "DataLoaded" event OR just delay 3s as a fallback.
local function onPlayerAdded(player)
	-- Try event-based first
	local gameEvents = ReplicatedStorage:FindFirstChild("GameEvents")
	local dataLoadedEvent = gameEvents and gameEvents:FindFirstChild("DataLoaded")
	if dataLoadedEvent and dataLoadedEvent:IsA("BindableEvent") then
		local conn
		conn = dataLoadedEvent.Event:Connect(function(loadedPlayer)
			if loadedPlayer == player then
				conn:Disconnect()
				tryGiveGift(player)
			end
		end)
		task.delay(10, function() if conn then conn:Disconnect() end end)
	else
		-- Fallback: wait for DataManager to populate then try.
		task.wait(3)
		if player.Parent then
			tryGiveGift(player)
		end
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
-- Catch up for already-present players
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

print("[FirstTimeGift] Initialized.")
