--!strict
-- PASTE LOCATION: ReplicatedStorage.GamepassConfig (ModuleScript)
--
-- *** EDIT THIS FILE *** after creating gamepasses + dev product on Creator Hub.
-- Replace the 0s with the real numeric IDs from the URLs.

local GamepassConfig = {}

-- Gamepass IDs (set to 0 if not yet created — manager ignores those)
GamepassConfig.Gamepasses = {
	-- "Crystal Champion" / VIP — 499 Robux
	-- Perks: trail, chat tag, +25% coins, 1.5× XP, exclusive cape, 2 extra build slots
	VIP = {
		id = 0,  -- ← paste real Pass ID here
		name = "Crystal Champion",
		perks = {
			coinMultiplier = 1.25,
			xpMultiplier = 1.5,
			extraBuildSlots = 2,
			trail = true,
			chatTag = "VIP",
			tagColor = Color3.fromRGB(255, 215, 0),
			exclusiveCape = true,
		},
	},
	-- "2× Gems Forever" — 299 Robux
	GemDoubler = {
		id = 0,  -- ← paste real Pass ID here
		name = "2× Gems Forever",
		perks = {
			gemMultiplier = 2,
		},
	},
	-- "Auto-Revive" — 199 Robux
	AutoRevive = {
		id = 0,  -- ← paste real Pass ID here
		name = "Auto-Revive",
		perks = {
			autoRevive = true,
		},
	},
	-- "Necromancer Class" — 399 Robux
	Necromancer = {
		id = 0,  -- ← paste real Pass ID here
		name = "Necromancer Class",
		perks = {
			classUnlock = "Necromancer",
		},
	},
}

-- Developer product IDs
GamepassConfig.DevProducts = {
	-- "Emergency Save" — 49 Robux
	-- Prompts when crystal HP <10% on wave 15+, cap 1 per round
	EmergencySave = {
		id = 0,  -- ← paste real Product ID here
		name = "Emergency Save",
		minWave = 15,
		hpThreshold = 0.10,       -- 10% of max HP triggers the prompt
		crystalRestoreTo = 0.50,  -- restore to 50% on purchase
		stunDuration = 5,         -- seconds to stun all enemies on purchase
		usagePerRound = 1,        -- max purchases per round
	},
}

-- Roblox group (for group join reward)
GamepassConfig.Group = {
	id = 0,  -- ← paste real Group ID here
	rewardCoins = 500,
	exclusiveCapeAssetId = 0, -- optional cape asset ID; 0 = skip cosmetic
}

return GamepassConfig
