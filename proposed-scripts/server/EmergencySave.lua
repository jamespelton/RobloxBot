-- PASTE LOCATION: ServerScriptService.EmergencySave (Script)
--
-- EmergencySave — server-side handler for the 49-Robux "Save my run" dev product.
-- Watches crystal HP; when wave ≥15 AND crystal HP <10%, prompts a configured
-- player to buy. On purchase: restores crystal to 50% HP + stuns all enemies 5s.
-- Cap: 1 purchase per round (resets at wave start).
--
-- DEPENDENCIES:
--   - ReplicatedStorage.GamepassConfig.DevProducts.EmergencySave.id is the real product ID
--   - ReplicatedStorage.GameEvents.CrystalHealth IntValue (current crystal HP)
--   - ReplicatedStorage.CrystalMaxHealth (or fallback 400)
--   - A way to stun enemies — either:
--       a) ReplicatedStorage.GameEvents.StunAllEnemies BindableEvent that GameManager listens to,
--       b) Direct call to GameManager.StunAllEnemies (we try this fallback)
--
-- INTEGRATION HOOK:
--   GameManager should call EmergencySave:CheckTrigger(currentWave, hpCurrent, hpMax)
--   every time crystal HP changes, OR every 1s during a wave. See README integration.

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local GamepassConfig = require(ReplicatedStorage:WaitForChild("GamepassConfig"))
local cfg = GamepassConfig.DevProducts.EmergencySave

local module = {}

-- State
local roundPurchaseCount = 0
local pendingPrompts = {} -- userId → true (prevents duplicate prompts in same wave)

local function ensureRemoteEvent()
	local gameEvents = ReplicatedStorage:FindFirstChild("GameEvents")
	if not gameEvents then
		gameEvents = Instance.new("Folder")
		gameEvents.Name = "GameEvents"
		gameEvents.Parent = ReplicatedStorage
	end
	for _, name in ipairs({ "EmergencySavePrompt", "EmergencySaveActivated" }) do
		if not gameEvents:FindFirstChild(name) then
			local e = Instance.new("RemoteEvent")
			e.Name = name
			e.Parent = gameEvents
		end
	end
	return gameEvents
end

local gameEvents = ensureRemoteEvent()

-- Public: GameManager calls this whenever crystal HP changes or per-frame during a wave.
function module:CheckTrigger(currentWave, hpCurrent, hpMax)
	if currentWave < cfg.minWave then return end
	if hpMax <= 0 then return end
	if hpCurrent / hpMax > cfg.hpThreshold then return end
	if roundPurchaseCount >= cfg.usagePerRound then return end

	-- Prompt all players in the server who haven't been prompted this wave
	for _, player in ipairs(Players:GetPlayers()) do
		if not pendingPrompts[player.UserId] then
			pendingPrompts[player.UserId] = true
			-- Fire client UI prompt
			gameEvents.EmergencySavePrompt:FireClient(player, {
				productId = cfg.id,
				crystalRestorePct = cfg.crystalRestoreTo,
				stunDuration = cfg.stunDuration,
			})
		end
	end
end

-- Public: GameManager calls on new wave start to reset state
function module:OnWaveStart()
	roundPurchaseCount = 0
	table.clear(pendingPrompts)
end

local function applyEmergencySave(player)
	-- Restore crystal HP
	local crystalHP = ReplicatedStorage:FindFirstChild("GameEvents") and ReplicatedStorage.GameEvents:FindFirstChild("CrystalHealth")
	local crystalMax = ReplicatedStorage:FindFirstChild("CrystalMaxHealth")
	local maxHP = (crystalMax and crystalMax.Value) or 400
	if crystalHP and crystalHP:IsA("IntValue") then
		crystalHP.Value = math.floor(maxHP * cfg.crystalRestoreTo)
	end

	-- Stun all enemies (try BindableEvent first, then direct GameManager call)
	local stunEvent = ReplicatedStorage.GameEvents:FindFirstChild("StunAllEnemies")
	if stunEvent and stunEvent:IsA("BindableEvent") then
		stunEvent:Fire(cfg.stunDuration)
	else
		local gmModule = ServerScriptService:FindFirstChild("GameManager")
		if gmModule and gmModule:IsA("ModuleScript") then
			pcall(function()
				local GM = require(gmModule)
				if GM.StunAllEnemies then GM:StunAllEnemies(cfg.stunDuration) end
			end)
		end
	end

	-- Notify all clients (announce who saved the run)
	gameEvents.EmergencySaveActivated:FireAllClients({
		playerName = player.Name,
		restoredHP = math.floor(maxHP * cfg.crystalRestoreTo),
		stunDuration = cfg.stunDuration,
	})

	roundPurchaseCount = roundPurchaseCount + 1
	print(("[EmergencySave] Activated by %s — crystal restored to %d, %ds stun"):format(
		player.Name, math.floor(maxHP * cfg.crystalRestoreTo), cfg.stunDuration))
end

-- ProcessReceipt callback (chain with existing receipts if any)
local existingProcessReceipt = MarketplaceService.ProcessReceipt
MarketplaceService.ProcessReceipt = function(receiptInfo)
	if receiptInfo.ProductId ~= cfg.id or cfg.id == 0 then
		if existingProcessReceipt then return existingProcessReceipt(receiptInfo) end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if roundPurchaseCount >= cfg.usagePerRound then
		-- Already used this round. Honor the purchase anyway (don't take Robux for nothing).
		-- Granting at full effect because moral-of-store: pay → effect, always.
	end
	applyEmergencySave(player)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- Return module so GameManager can call CheckTrigger / OnWaveStart
_G.RexEmergencySave = module
print("[EmergencySave] Initialized. Use _G.RexEmergencySave:CheckTrigger(wave, hp, maxHp) or require this module from GameManager.")

return module
