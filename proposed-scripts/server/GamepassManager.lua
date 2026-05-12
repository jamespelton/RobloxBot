-- PASTE LOCATION: ServerScriptService.GamepassManager (Script)
--
-- GamepassManager — checks player gamepass ownership on join and applies perks.
-- Listens for live purchases via MarketplaceService.PromptGamePassPurchaseFinished.
--
-- DEPENDENCIES:
--   - ReplicatedStorage.GamepassConfig (edit with real Pass IDs first)
--   - leaderstats.Coins exists on the player
--   - For coin/gem/XP multipliers: existing scripts that grant these need to
--     check the player's "PerkXxx" attributes (this script SETS them).
--
-- INTEGRATION HOOKS (existing scripts should reference these player attributes):
--   - player:GetAttribute("PerkCoinMultiplier")  -- defaults to 1
--   - player:GetAttribute("PerkXpMultiplier")    -- defaults to 1
--   - player:GetAttribute("PerkGemMultiplier")   -- defaults to 1
--   - player:GetAttribute("PerkExtraBuildSlots") -- defaults to 0
--   - player:GetAttribute("PerkAutoRevive")      -- defaults to false
--   - player:GetAttribute("UnlockedNecromancer") -- defaults to false
--
-- Existing scripts wanting to act on multipliers should multiply their reward by
-- the relevant attribute before applying:
--     coinValue.Value = coinValue.Value + (baseAmount * (player:GetAttribute("PerkCoinMultiplier") or 1))

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GamepassConfig = require(ReplicatedStorage:WaitForChild("GamepassConfig"))

local function initAttributes(player)
	player:SetAttribute("PerkCoinMultiplier", 1)
	player:SetAttribute("PerkXpMultiplier", 1)
	player:SetAttribute("PerkGemMultiplier", 1)
	player:SetAttribute("PerkExtraBuildSlots", 0)
	player:SetAttribute("PerkAutoRevive", false)
	player:SetAttribute("UnlockedNecromancer", false)
	player:SetAttribute("PerkVIP", false)
end

local function applyPerks(player, perks)
	if perks.coinMultiplier then
		player:SetAttribute("PerkCoinMultiplier",
			math.max(player:GetAttribute("PerkCoinMultiplier") or 1, perks.coinMultiplier))
	end
	if perks.xpMultiplier then
		player:SetAttribute("PerkXpMultiplier",
			math.max(player:GetAttribute("PerkXpMultiplier") or 1, perks.xpMultiplier))
	end
	if perks.gemMultiplier then
		player:SetAttribute("PerkGemMultiplier",
			math.max(player:GetAttribute("PerkGemMultiplier") or 1, perks.gemMultiplier))
	end
	if perks.extraBuildSlots then
		player:SetAttribute("PerkExtraBuildSlots",
			(player:GetAttribute("PerkExtraBuildSlots") or 0) + perks.extraBuildSlots)
	end
	if perks.autoRevive then
		player:SetAttribute("PerkAutoRevive", true)
	end
	if perks.classUnlock == "Necromancer" then
		player:SetAttribute("UnlockedNecromancer", true)
	end
	if perks.trail or perks.chatTag or perks.exclusiveCape then
		player:SetAttribute("PerkVIP", true)
		-- Visual hooks (cape/trail/chatTag) handled by existing visual scripts
		-- listening to PerkVIP attribute change.
	end
end

local function checkAndApply(player, gamepassKey, definition)
	if not definition.id or definition.id == 0 then return end
	local owns = false
	local ok, result = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, definition.id)
	end)
	if ok then owns = result end
	if owns then
		applyPerks(player, definition.perks)
		print(("[GamepassManager] %s applied to %s"):format(definition.name, player.Name))
	end
end

local function onPlayerAdded(player)
	initAttributes(player)
	for key, def in pairs(GamepassConfig.Gamepasses) do
		task.spawn(checkAndApply, player, key, def)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(onPlayerAdded, p) end

-- Listen for live purchases (apply perk immediately without re-join)
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	if not purchased then return end
	for _, def in pairs(GamepassConfig.Gamepasses) do
		if def.id == passId then
			applyPerks(player, def.perks)
			print(("[GamepassManager] Live purchase: %s by %s"):format(def.name, player.Name))
		end
	end
end)

print("[GamepassManager] Initialized.")
