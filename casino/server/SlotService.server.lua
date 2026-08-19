-- SlotService : makes every slot machine playable.
-- Adds a ProximityPrompt + reel display to each machine, runs the spin
-- server-side (authoritative) and pays out through _G.CasinoBank.

local Players = game:GetService("Players")
local RS      = game:GetService("ReplicatedStorage")

local EV = RS:WaitForChild("CasinoEvents")

repeat task.wait() until _G.CasinoBank
local Bank = _G.CasinoBank

-- ---------- paytable ----------
-- Weights sum to 100. Three-of-a-kind plus a few "exactly two" consolations
-- give roughly 91% return, so a bankroll drains slowly rather than instantly.
local SYMBOLS = {
	{ id = "$",  weight = 30, three = 8,   pair = 1, color = Color3.fromRGB(120, 190, 130) },
	{ id = "C",  weight = 25, three = 12,  pair = 0, color = Color3.fromRGB(210, 120, 130) },
	{ id = "H",  weight = 18, three = 20,  pair = 0, color = Color3.fromRGB(200, 90,  95)  },
	{ id = "*",  weight = 13, three = 38,  pair = 0, color = Color3.fromRGB(210, 180, 110) },
	{ id = "7",  weight = 9,  three = 90,  pair = 1, color = Color3.fromRGB(205, 70,  70)  },
	{ id = "D",  weight = 5,  three = 225, pair = 1, color = Color3.fromRGB(120, 190, 210) },
}
local BY_ID = {}
local TOTAL_WEIGHT = 0
for _, s in ipairs(SYMBOLS) do
	BY_ID[s.id] = s
	TOTAL_WEIGHT = TOTAL_WEIGHT + s.weight
end

local BETS = { 10, 25, 50, 100, 250 }
local DEFAULT_BET = 10
local SPIN_STOPS = { 0.90, 1.30, 1.75 }
local TICK = 0.08

local rng = Random.new()
local playerBet = {}
local busy = {}          -- machine -> true while spinning
local cooling = {}       -- player -> true briefly after a spin

local function rollSymbol()
	local r = rng:NextNumber() * TOTAL_WEIGHT
	local acc = 0
	for _, s in ipairs(SYMBOLS) do
		acc = acc + s.weight
		if r <= acc then return s end
	end
	return SYMBOLS[1]
end

-- Returns multiplier applied to the bet.
local function evaluate(a, b, c)
	if a.id == b.id and b.id == c.id then
		return a.three, "THREE " .. a.id
	end
	local pairSym
	if a.id == b.id then pairSym = a
	elseif b.id == c.id then pairSym = b
	elseif a.id == c.id then pairSym = a end
	if pairSym and pairSym.pair > 0 then
		return pairSym.pair, "PAIR " .. pairSym.id
	end
	return 0, nil
end

-- ---------- per-machine rig ----------

local machines = {}

local function buildReelDisplay(machine, pivot)
	local wheels = machine:FindFirstChild("Ruedas Jackpot")
	if not wheels then return nil end

	-- collect the parts that carry the reel decal, ordered left to right
	local found = {}
	for _, d in ipairs(wheels:GetDescendants()) do
		if d:IsA("BasePart") then
			local decal = d:FindFirstChildOfClass("Decal")
			if decal then
				table.insert(found, { part = d, decal = decal })
			end
		end
	end
	if #found < 3 then return nil end

	local right = pivot.RightVector
	table.sort(found, function(x, y)
		return x.part.Position:Dot(right) < y.part.Position:Dot(right)
	end)

	local labels = {}
	for i = 1, 3 do
		local entry = found[i]
		entry.decal.Transparency = 1   -- hide the static art, we drive our own

		local old = entry.part:FindFirstChild("ReelGui")
		if old then old:Destroy() end

		local gui = Instance.new("SurfaceGui")
		gui.Name = "ReelGui"
		gui.Face = entry.decal.Face      -- the decal already faces the player
		gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		gui.CanvasSize = Vector2.new(100, 170)
		gui.LightInfluence = 0
		gui.Parent = entry.part

		local bg = Instance.new("Frame")
		bg.Size = UDim2.new(1, 0, 1, 0)
		bg.BackgroundColor3 = Color3.fromRGB(242, 238, 228)
		bg.BorderSizePixel = 0
		bg.Parent = gui

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(1, 0, 1, 0)
		lbl.BackgroundTransparency = 1
		lbl.Font = Enum.Font.GothamBlack
		lbl.TextScaled = true
		lbl.Text = "7"
		lbl.TextColor3 = Color3.fromRGB(205, 70, 70)
		lbl.Parent = bg

		labels[i] = lbl
	end
	return labels
end

local function buildBillboard(machine, pivot)
	local att = Instance.new("Attachment")
	att.Name = "WinAnchor"
	att.Parent = machine:FindFirstChild("_Collider") or machine:FindFirstChildWhichIsA("BasePart", true)
	att.WorldCFrame = pivot * CFrame.new(0, 4.4, 0)

	local bb = Instance.new("BillboardGui")
	bb.Name = "WinBoard"
	bb.Size = UDim2.new(0, 190, 0, 60)
	bb.AlwaysOnTop = false
	bb.MaxDistance = 70
	bb.Enabled = false
	bb.Parent = att

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.Font = Enum.Font.GothamBlack
	lbl.TextScaled = true
	lbl.TextStrokeTransparency = 0.4
	lbl.TextColor3 = Color3.fromRGB(255, 225, 150)
	lbl.Text = ""
	lbl.Parent = bb

	return bb, lbl
end

local function flashLeds(machine, on)
	local leds = machine:FindFirstChild("LEDS")
	if not leds then return end
	for _, p in ipairs(leds:GetChildren()) do
		if p:IsA("BasePart") then
			if on then
				p.Material = Enum.Material.Neon
				p.Color = Color3.fromRGB(255, 210, 130)
			else
				p.Material = Enum.Material.SmoothPlastic
				p.Color = Color3.fromRGB(120, 110, 100)
			end
		end
	end
end

local function pullLever(machine, pivot)
	local lever = machine:FindFirstChild("Lever")
	if not lever then return end
	local base
	for _, p in ipairs(lever:GetChildren()) do
		if p:IsA("BasePart") then base = p break end
	end
	if not base then return end

	local origin = lever:GetPivot()
	local point = base.Position
	local axis = pivot.RightVector

	task.spawn(function()
		local steps = 6
		for i = 1, steps do
			local a = math.rad(55) * (i / steps)
			local rot = CFrame.fromAxisAngle(axis, a)
			lever:PivotTo(CFrame.new(point) * rot * CFrame.new(-point) * origin)
			task.wait(0.03)
		end
		task.wait(0.12)
		for i = steps, 0, -1 do
			local a = math.rad(55) * (i / steps)
			local rot = CFrame.fromAxisAngle(axis, a)
			lever:PivotTo(CFrame.new(point) * rot * CFrame.new(-point) * origin)
			task.wait(0.035)
		end
		lever:PivotTo(origin)
	end)
end

-- ---------- the spin ----------

local function spin(machine, plr)
	local rec = machines[machine]
	if not rec then return end
	if busy[machine] then
		Bank.notify(plr, "That machine is already spinning", "warn")
		return
	end
	if cooling[plr] then return end

	local bet = playerBet[plr] or DEFAULT_BET
	if not Bank.tryDeduct(plr, bet) then
		Bank.notify(plr, "Not enough chips - visit the Cashier", "warn")
		return
	end

	busy[machine] = true
	cooling[plr] = true
	task.delay(0.4, function() cooling[plr] = nil end)

	pullLever(machine, rec.pivot)
	flashLeds(machine, true)

	local result = { rollSymbol(), rollSymbol(), rollSymbol() }

	task.spawn(function()
		local t = 0
		local stopped = { false, false, false }
		while t < SPIN_STOPS[3] do
			for i = 1, 3 do
				if not stopped[i] then
					if t >= SPIN_STOPS[i] then
						stopped[i] = true
						local s = result[i]
						rec.labels[i].Text = s.id
						rec.labels[i].TextColor3 = s.color
					else
						local s = SYMBOLS[rng:NextInteger(1, #SYMBOLS)]
						rec.labels[i].Text = s.id
						rec.labels[i].TextColor3 = s.color
					end
				end
			end
			task.wait(TICK)
			t = t + TICK
		end
		for i = 1, 3 do
			rec.labels[i].Text = result[i].id
			rec.labels[i].TextColor3 = result[i].color
		end

		local mult, label = evaluate(result[1], result[2], result[3])
		local payout = math.floor(bet * mult)

		if payout > 0 then
			Bank.add(plr, payout)
			rec.winLabel.Text = "+" .. payout
			rec.winBoard.Enabled = true
			Bank.notify(plr, label .. "  +" .. payout .. " chips", "win")
			task.delay(3.5, function()
				if rec.winBoard then rec.winBoard.Enabled = false end
			end)
		else
			flashLeds(machine, false)
			Bank.notify(plr, "-" .. bet .. " chips", "lose")
		end

		EV.SlotResult:FireAllClients(machine, result[1].id, result[2].id, result[3].id, payout, plr.Name)

		if payout > 0 then
			task.delay(3.5, function() flashLeds(machine, false) end)
		end
		busy[machine] = nil
	end)
end

-- ---------- wiring ----------

local casino = workspace:WaitForChild("Casino", 30)
local slots  = casino:WaitForChild("Slots")

local built = 0
for _, machine in ipairs(slots:GetChildren()) do
	if machine.Name == "SlotMachine" then
		local pivot = machine:GetPivot()
		local labels = buildReelDisplay(machine, pivot)
		if labels then
			local board, winLabel = buildBillboard(machine, pivot)
			machines[machine] = { pivot = pivot, labels = labels, winBoard = board, winLabel = winLabel }

			local anchor = machine:FindFirstChild("_Collider")
			local att = Instance.new("Attachment")
			att.Name = "PlayPrompt"
			att.Parent = anchor
			att.WorldCFrame = pivot * CFrame.new(0, 0.4, -2.3)

			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = "Spin"
			prompt.ObjectText = "Slot Machine"
			prompt.KeyboardKeyCode = Enum.KeyCode.E
			prompt.HoldDuration = 0
			prompt.MaxActivationDistance = 9
			prompt.RequiresLineOfSight = false
			prompt.Parent = att

			prompt.Triggered:Connect(function(plr) spin(machine, plr) end)

			flashLeds(machine, false)
			built = built + 1
		end
	end
end

-- client asks to change its stake; server validates against the allowed list
EV.SlotSpin.OnServerEvent:Connect(function(plr, value)
	for _, b in ipairs(BETS) do
		if b == value then
			playerBet[plr] = b
			Bank.notify(plr, "Bet set to " .. b .. " chips", "info")
			return
		end
	end
end)

Players.PlayerAdded:Connect(function(plr) playerBet[plr] = DEFAULT_BET end)
Players.PlayerRemoving:Connect(function(plr)
	playerBet[plr] = nil
	cooling[plr] = nil
end)
for _, plr in ipairs(Players:GetPlayers()) do playerBet[plr] = DEFAULT_BET end

print("[Casino] SlotService ready - " .. built .. " playable machines")
