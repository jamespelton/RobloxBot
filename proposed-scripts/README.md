# Proposed Scripts — Drop-In Bundle

**Built by Rex on 2026-05-12** while Roblox Studio was offline. Each script is a complete, self-contained drop-in. Paste into Studio at the location specified at the top of each file.

These cover **Week 1 tasks #2-7 of the 12-week roadmap** (FTUE, gamepasses, badges, group reward, Emergency Save).

---

## Paste Order (matters because of dependencies)

### Phase 1 — FTUE (D1 retention)
1. `shared/FtueConfig.lua` → `ReplicatedStorage.FtueConfig` (ModuleScript)
2. `server/FirstTimeGift.lua` → `ServerScriptService.FirstTimeGift` (Script)
3. `client/PortalArrow.lua` → `StarterPlayer.StarterPlayerScripts.PortalArrow` (LocalScript)
4. `client/FtueTutorial.lua` → `StarterPlayer.StarterPlayerScripts.FtueTutorial` (LocalScript)

### Phase 2 — Monetization
5. `shared/GamepassConfig.lua` → `ReplicatedStorage.GamepassConfig` (ModuleScript) — **EDIT THIS FILE** to add real gamepass IDs after creating them on Creator Hub
6. `server/GamepassManager.lua` → `ServerScriptService.GamepassManager` (Script)
7. `server/EmergencySave.lua` → `ServerScriptService.EmergencySave` (Script)
8. `client/EmergencySavePrompt.lua` → `StarterPlayer.StarterPlayerScripts.EmergencySavePrompt` (LocalScript)

### Phase 3 — Algorithm signals
9. `shared/BadgeConfig.lua` → `ReplicatedStorage.BadgeConfig` (ModuleScript) — **EDIT THIS FILE** with real Badge IDs after creating them
10. `server/BadgeManager.lua` → `ServerScriptService.BadgeManager` (Script)
11. `server/GroupReward.lua` → `ServerScriptService.GroupReward` (Script)

---

## What you (James) need to do in Creator Hub before Phase 2/3 work

### Gamepasses (4 total) — create at https://create.roblox.com → Crystal Siege → Monetization → Gamepasses
- **Crystal Champion (VIP)** — 499 Robux. Description: "Exclusive cape, +25% coins, 1.5× XP, 2 extra build slots, chat tag, trail."
- **2× Gems Forever** — 299 Robux. Description: "Double all gem drops, permanently."
- **Auto-Revive** — 199 Robux. Description: "Skip the revive hold — instant respawn during a wave."
- **Necromancer Class** — 399 Robux. Description: "Unlock the dark Necromancer class. Summon skeleton minions to fight for you."

After creating each, copy its **Pass ID** (number in URL after `?gameId=...&passId=`) and paste into `shared/GamepassConfig.lua`.

### Dev product (1 total) — same page, Developer Products tab
- **Emergency Save** — 49 Robux. Description: "Crystal HP <10%? One-time per round: restore crystal to 50% HP and stun all enemies for 5 seconds."

Copy its **Product ID** and paste into `shared/GamepassConfig.lua` (devProductId field).

### Badges (15 total) — same page, Badges tab. Each badge costs **100 Robux** to create.
List in `shared/BadgeConfig.lua`. After creating each, copy its **Badge ID** and paste into that config file.

### Group reward
- Roblox group invite URL + group ID go in `shared/GamepassConfig.lua` under `groupId`.

---

## Integration Hooks Existing Scripts Need

These are points where your EXISTING scripts (GameManager, ClassManager, BuildManager, etc.) need to fire events the new scripts listen to. I documented each integration point at the bottom of the relevant new script. You'll need to add the listed lines.

### Critical existing-script edits (minimal, but you have to do them):

**`GameManager`** — add at the end of `onEnemyKilled` function (wherever you increment kill count):
```lua
local BadgeManager = require(game.ServerScriptService.BadgeManager)
BadgeManager:OnEnemyKilled(killer, totalKills)
```

**`GameManager`** — add at the end of `onWaveCompleted`:
```lua
local BadgeManager = require(game.ServerScriptService.BadgeManager)
BadgeManager:OnWaveCompleted(player, waveNumber)
```

**`GameManager`** — in the crystal HP update loop, after a wave-tick:
```lua
local EmergencySave = require(game.ServerScriptService.EmergencySave)
EmergencySave:CheckTrigger(currentWave, currentCrystalHP, maxCrystalHP)
```

**`ClassManager`** — when a class is purchased:
```lua
local BadgeManager = require(game.ServerScriptService.BadgeManager)
BadgeManager:OnClassUnlocked(player, className)
```

**`ClassSelection`** (client) — add 5-second auto-pick fallback:
```lua
-- At top of ClassSelection.lua, after gui setup
task.delay(5, function()
    if not classSelected then
        autoSelectClass("Fighter") -- forced default
    end
end)
```

---

## What this bundle does NOT cover

- **Wave 1 difficulty audit** — requires reading GameManager to retune enemy counts/HP. Defer until Studio MCP is up.
- **Gem icon swap** — needs PNG asset replacement in Studio (UI manipulation).
- **5 sound effects from Creator Store** — needs your Robux wallet.

---

## Testing checklist (after pasting)

- [ ] New player spawn: gets the welcome popup + 500 coins + 1 chest
- [ ] Portal arrow appears for first-timers
- [ ] 3-popup tutorial sequence works, skippable
- [ ] Logged-out player not getting first-time gift again on second join
- [ ] VIP gamepass holder gets the trail + chat tag (after purchase via Creator Hub)
- [ ] Wave 15+ with crystal <10% triggers Emergency Save prompt
- [ ] Buying Emergency Save restores crystal + stuns enemies
- [ ] Each badge awards on its trigger condition
- [ ] Group reward grants 500 coins + cape on first detect
