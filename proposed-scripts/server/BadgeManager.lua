-- PASTE LOCATION: ServerScriptService.BadgeManager (ModuleScript)
--
-- BadgeManager — wraps BadgeService:AwardBadgeAsync and tracks unlock conditions.
-- Other server scripts (GameManager, ClassManager, LootSystem, ReviveSystem,
-- DataManager) call public methods on this module when their events happen.
--
-- DEPENDENCIES:
--   - ReplicatedStorage.BadgeConfig (edit with real Badge IDs first)
--   - DataManager:GetData(player) for persistent counters
--
-- USAGE (existing scripts call these — see README integration hooks):
--   BadgeManager:OnEnemyKilled(player, totalKillsLifetime)
--   BadgeManager:OnWaveCompleted(player, waveNumber)
--   BadgeManager:OnClassUnlocked(player, className)
--   BadgeManager:OnBossKilled(player, bossName)
--   BadgeManager:OnChestOpened(player)
--   BadgeManager:OnGamepassPurchased(player)
--   BadgeManager:OnGroupJoinDetected(player)
--   BadgeManager:OnLoginStreakUpdated(player, streakDays)
--   BadgeManager:OnRevivePerformed(player)
--   BadgeManager:OnBuildingPlaced(player, buildingType, tier)

local BadgeService = game:GetService("BadgeService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local BadgeConfig = require(ReplicatedStorage:WaitForChild("BadgeConfig"))

local module = {}

local function getDataManager()
	local m = ServerScriptService:FindFirstChild("DataManager")
	if m and m:IsA("ModuleScript") then return require(m) end
	return nil
end
local DataManager = getDataManager()

local awardedCache = {} -- userId → set of badge IDs we already awarded this session

local function alreadyAwarded(player, badgeId)
	if not awardedCache[player.UserId] then awardedCache[player.UserId] = {} end
	return awardedCache[player.UserId][badgeId]
end

local function award(player, badgeKey)
	local def = BadgeConfig.Badges[badgeKey]
	if not def or not def.id or def.id == 0 then return end
	if alreadyAwarded(player, def.id) then return end
	awardedCache[player.UserId][def.id] = true
	-- Don't re-award if BadgeService says the player already has it
	local owns = false
	pcall(function()
		owns = BadgeService:UserHasBadgeAsync(player.UserId, def.id)
	end)
	if owns then return end
	local ok, err = pcall(function()
		BadgeService:AwardBadgeAsync(player.UserId, def.id)
	end)
	if ok then
		print(("[BadgeManager] %s awarded to %s"):format(def.name, player.Name))
	else
		warn(("[BadgeManager] Award failed for %s/%s: %s"):format(player.Name, badgeKey, tostring(err)))
	end
end

-- Public API

function module:OnEnemyKilled(player, totalLifetimeKills)
	if not player then return end
	award(player, "FirstKill")
	if totalLifetimeKills then
		if totalLifetimeKills >= 100 then award(player, "Kills100") end
		if totalLifetimeKills >= 1000 then award(player, "Kills1000") end
	end
end

function module:OnWaveCompleted(player, waveNumber)
	if not player or not waveNumber then return end
	if waveNumber >= 5 then award(player, "Wave5") end
	if waveNumber >= 10 then award(player, "Wave10") end
	if waveNumber >= 25 then award(player, "Wave25") end
	if waveNumber >= 50 then award(player, "Wave50") end
end

function module:OnClassUnlocked(player, className)
	if not player then return end
	-- Track played classes via DataManager
	if DataManager then
		local data = DataManager:GetData(player)
		if data then
			data.PlayedClasses = data.PlayedClasses or {}
			if not data.PlayedClasses[className] then
				data.PlayedClasses[className] = true
				pcall(function() DataManager:Save(player) end)
			end
			local count = 0
			for _ in pairs(data.PlayedClasses) do count += 1 end
			if count >= 6 then award(player, "AllClasses") end
		end
	end
end

function module:OnBossKilled(player, bossName)
	if not player then return end
	award(player, "FirstBoss")
end

function module:OnChestOpened(player)
	if not player then return end
	award(player, "FirstChest")
end

function module:OnGamepassPurchased(player)
	if not player then return end
	award(player, "FirstGamepass")
end

function module:OnGroupJoinDetected(player)
	if not player then return end
	award(player, "JoinedGroup")
end

function module:OnLoginStreakUpdated(player, streakDays)
	if not player or not streakDays then return end
	if streakDays >= 7 then award(player, "LoginStreak7") end
end

function module:OnRevivePerformed(player)
	if not player then return end
	award(player, "FirstRevive")
end

function module:OnBuildingPlaced(player, buildingType, tier)
	if not player or not DataManager then return end
	local data = DataManager:GetData(player)
	if not data then return end
	data.PlacedBuildings = data.PlacedBuildings or {}
	data.PlacedBuildings[buildingType] = math.max(data.PlacedBuildings[buildingType] or 0, tier or 1)
	local typeCount = 0
	local hasMaxTier = false
	for _, t in pairs(data.PlacedBuildings) do
		typeCount += 1
		if t >= 3 then hasMaxTier = true end
	end
	if typeCount >= 9 and hasMaxTier then award(player, "FullBase") end
end

print("[BadgeManager] Initialized.")

return module
