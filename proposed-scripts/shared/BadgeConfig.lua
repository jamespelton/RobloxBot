--!strict
-- PASTE LOCATION: ReplicatedStorage.BadgeConfig (ModuleScript)
--
-- *** EDIT THIS FILE *** after creating 15 badges on Creator Hub.
-- Each badge costs 100 Robux to create. Copy the badge ID from the URL.
--
-- Badge ideas (per 12-week roadmap §1.5):
--   1. First kill         (any enemy killed)
--   2. Wave 5 complete
--   3. Wave 10 complete
--   4. Wave 25 complete
--   5. Wave 50 complete   (endless mode)
--   6. All 6 classes played
--   7. Fully upgraded base (all 9 build types placed + max tier on at least one)
--   8. 100 enemies total kills
--   9. 1,000 enemies total kills
--  10. First boss kill
--  11. First chest opened
--  12. First gamepass purchased
--  13. Joined the Roblox group
--  14. 7-day login streak
--  15. First revive performed

local BadgeConfig = {}

BadgeConfig.Badges = {
	FirstKill = {
		id = 0,  -- ← paste real Badge ID
		name = "First Blood",
		description = "Defeat your first enemy",
	},
	Wave5 = {
		id = 0,
		name = "Wave 5 Survivor",
		description = "Defend the crystal through Wave 5",
	},
	Wave10 = {
		id = 0,
		name = "Boss Slayer",
		description = "Defeat the Wave 10 boss",
	},
	Wave25 = {
		id = 0,
		name = "Endless Initiate",
		description = "Reach Wave 25 in endless mode",
	},
	Wave50 = {
		id = 0,
		name = "Crystal Champion",
		description = "Survive to Wave 50",
	},
	AllClasses = {
		id = 0,
		name = "Jack of All Trades",
		description = "Play all 6 classes",
	},
	FullBase = {
		id = 0,
		name = "Master Builder",
		description = "Place every type of building",
	},
	Kills100 = {
		id = 0,
		name = "Centurion",
		description = "Defeat 100 enemies (lifetime)",
	},
	Kills1000 = {
		id = 0,
		name = "Legendary Defender",
		description = "Defeat 1,000 enemies (lifetime)",
	},
	FirstBoss = {
		id = 0,
		name = "Berserker Slayer",
		description = "Defeat your first boss",
	},
	FirstChest = {
		id = 0,
		name = "Treasure Hunter",
		description = "Open your first loot chest",
	},
	FirstGamepass = {
		id = 0,
		name = "Supporter",
		description = "Buy your first gamepass",
	},
	JoinedGroup = {
		id = 0,
		name = "Recruit",
		description = "Join the Crystal Siege Roblox group",
	},
	LoginStreak7 = {
		id = 0,
		name = "Daily Defender",
		description = "Log in 7 days in a row",
	},
	FirstRevive = {
		id = 0,
		name = "Lifesaver",
		description = "Revive a fallen teammate for the first time",
	},
}

return BadgeConfig
