-- CasinoCore : chips currency, persistence, notifications, cashier desk
-- Exposes _G.CasinoBank for SlotService / TableGames.

local Players = game:GetService("Players")
local RS      = game:GetService("ReplicatedStorage")
local DSS     = game:GetService("DataStoreService")

local EV = RS:WaitForChild("CasinoEvents")

local STARTING_CHIPS   = 500
local CASHIER_GRANT    = 250
local CASHIER_COOLDOWN = 120   -- seconds; waived if you are flat broke
local AUTOSAVE_SECONDS = 60

-- DataStore is unavailable in an unpublished place; every call is guarded so
-- the game still runs, it just will not persist until the place is published.
local store
local ok = pcall(function() store = DSS:GetDataStore("GoldenSpireCasino_v1") end)
if not ok then store = nil end

local lastCashier = {}

local function chipsValue(plr)
	local ls = plr:FindFirstChild("leaderstats")
	return ls and ls:FindFirstChild("Chips")
end

local Bank = {}

function Bank.get(plr)
	local v = chipsValue(plr)
	return v and v.Value or 0
end

function Bank.set(plr, n)
	local v = chipsValue(plr)
	if not v then return end
	v.Value = math.max(0, math.floor(n))
	if plr.Parent then
		EV.ChipsChanged:FireClient(plr, v.Value)
	end
end

function Bank.add(plr, n)
	Bank.set(plr, Bank.get(plr) + n)
end

-- Single authoritative spend path. Never trust a client-supplied bet.
function Bank.tryDeduct(plr, n)
	n = math.floor(tonumber(n) or 0)
	if n <= 0 then return false end
	local cur = Bank.get(plr)
	if cur < n then return false end
	Bank.set(plr, cur - n)
	return true
end

function Bank.notify(plr, text, kind)
	EV.Notify:FireClient(plr, text, kind or "info")
end

_G.CasinoBank = Bank

-- ---------- persistence ----------

local function loadChips(plr)
	if not store then return STARTING_CHIPS end
	local okLoad, data = pcall(function()
		return store:GetAsync("p_" .. plr.UserId)
	end)
	if okLoad and type(data) == "number" then return data end
	return STARTING_CHIPS
end

local function saveChips(plr)
	if not store then return end
	local v = chipsValue(plr)
	if not v then return end
	pcall(function()
		store:SetAsync("p_" .. plr.UserId, v.Value)
	end)
end

local function setupPlayer(plr)
	if plr:FindFirstChild("leaderstats") then return end
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	ls.Parent = plr

	local chips = Instance.new("IntValue")
	chips.Name = "Chips"
	chips.Value = STARTING_CHIPS
	chips.Parent = ls

	task.spawn(function()
		local amount = loadChips(plr)
		if plr.Parent then
			chips.Value = amount
			EV.ChipsChanged:FireClient(plr, amount)
		end
	end)
end

Players.PlayerAdded:Connect(setupPlayer)
Players.PlayerRemoving:Connect(function(plr)
	saveChips(plr)
	lastCashier[plr] = nil
end)

-- Studio race: PlayerAdded can fire before this script is running.
for _, plr in ipairs(Players:GetPlayers()) do
	setupPlayer(plr)
end

task.spawn(function()
	while true do
		task.wait(AUTOSAVE_SECONDS)
		for _, plr in ipairs(Players:GetPlayers()) do
			saveChips(plr)
		end
	end
end)

game:BindToClose(function()
	for _, plr in ipairs(Players:GetPlayers()) do
		saveChips(plr)
	end
end)

-- ---------- cashier desk ----------

local function grantCashier(plr)
	local now = os.clock()
	local broke = Bank.get(plr) <= 0
	local last = lastCashier[plr]
	if not broke and last and (now - last) < CASHIER_COOLDOWN then
		local left = math.ceil(CASHIER_COOLDOWN - (now - last))
		Bank.notify(plr, "Cashier: come back in " .. left .. "s", "warn")
		return
	end
	lastCashier[plr] = now
	Bank.add(plr, CASHIER_GRANT)
	Bank.notify(plr, "Cashier: +" .. CASHIER_GRANT .. " chips", "win")
end

EV.CashierClaim.OnServerEvent:Connect(grantCashier)

task.spawn(function()
	local casino = workspace:WaitForChild("Casino", 30)
	if not casino then return end
	local cashier = casino:WaitForChild("Venue"):WaitForChild("Cashier")
	local counter = cashier:WaitForChild("CounterTop")

	local att = Instance.new("Attachment")
	att.Name = "CashierPrompt"
	att.Position = Vector3.new(0, 0, -2.5)
	att.Parent = counter

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Collect chips"
	prompt.ObjectText = "Cashier"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0.35
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = att

	prompt.Triggered:Connect(grantCashier)
end)

print("[Casino] CasinoCore ready. Persistence: " .. (store and "on" or "OFF (place not published)"))
