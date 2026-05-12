--!strict
-- PASTE LOCATION: ReplicatedStorage.FtueConfig (ModuleScript)
--
-- FtueConfig — tuning knobs for first-time user experience.
-- Edit values here without touching the server/client scripts.

local FtueConfig = {}

-- First-time gift (given on player's very first spawn ever)
FtueConfig.FirstTimeGift = {
	Coins = 500,                   -- bonus coins on first spawn
	GrantChest = true,             -- give 1 free Common chest (set false to disable)
	ChestRarity = "Common",        -- LootSystem rarity to grant
}

-- Class auto-pick fallback (if player doesn't pick within N seconds)
FtueConfig.ClassPick = {
	AutoPickAfterSeconds = 5,
	DefaultClass = "Fighter",
}

-- Portal arrow (visual nudge for new players)
FtueConfig.PortalArrow = {
	FloatHeightStuds = 8,          -- height above portal in studs
	BobAmplitude = 1.5,            -- vertical bob
	BobSpeed = 2,                  -- bob frequency
	Color = Color3.fromRGB(255, 215, 0), -- bright yellow
	ShowForFirstNPlays = 3,        -- show for first 3 sessions, then stop
}

-- Tutorial popup sequence (3 popups, all skippable)
FtueConfig.Tutorial = {
	Popups = {
		{
			title = "Welcome to Crystal Siege!",
			body = "Defend the crystal from waves of enemies. Use WASD to move.",
			imageId = "",         -- optional Roblox asset ID; leave empty for text-only
			advanceLabel = "Got it",
		},
		{
			title = "Combat",
			body = "Click to attack enemies. Your class has special abilities — press Q to use them.",
			imageId = "",
			advanceLabel = "Cool",
		},
		{
			title = "Build defenses",
			body = "Press B to open the build menu. Place turrets, walls, and traps to protect the crystal.",
			imageId = "",
			advanceLabel = "Let's go!",
		},
	},
	ShowDelaySeconds = 2,   -- wait 2s after spawn before showing
	CanSkipAll = true,      -- show "Skip tutorial" link
}

return FtueConfig
