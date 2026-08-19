-- TableGames : blackjack on the 6 imported tables, roulette on the 2 wheels.
-- All game logic is server-side; the client only sends intents.

local Players = game:GetService("Players")
local RS      = game:GetService("ReplicatedStorage")

local EV = RS:WaitForChild("CasinoEvents")

repeat task.wait() until _G.CasinoBank
local Bank = _G.CasinoBank

local rng = Random.new()
local BETS = { 10, 25, 50, 100, 250 }
local function validBet(v)
	for _, b in ipairs(BETS) do if b == v then return b end end
	return nil
end

local function centreOf(model)
	local mn = Vector3.new(1e9, 1e9, 1e9)
	local mx = Vector3.new(-1e9, -1e9, -1e9)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			local s = d.Size / 2
			for i = -1, 1, 2 do for j = -1, 1, 2 do for k = -1, 1, 2 do
				local p = (d.CFrame * CFrame.new(s.X * i, s.Y * j, s.Z * k)).Position
				mn = mn:Min(p); mx = mx:Max(p)
			end end end
		end
	end
	return (mn + mx) / 2, mn, mx
end

local function makePrompt(parentPart, worldCF, actionText, objectText, dist)
	local att = Instance.new("Attachment")
	att.Name = "GamePrompt"
	att.Parent = parentPart
	att.WorldCFrame = worldCF

	local p = Instance.new("ProximityPrompt")
	p.ActionText = actionText
	p.ObjectText = objectText
	p.KeyboardKeyCode = Enum.KeyCode.E
	p.HoldDuration = 0
	p.MaxActivationDistance = dist or 12
	p.RequiresLineOfSight = false
	p.Parent = att
	return p
end

-- =====================================================================
-- BLACKJACK
-- =====================================================================

local RANKS = { "A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K" }
local SUITS = { "S", "H", "D", "C" }

local bjSession = {}   -- player -> session

local function newShoe()
	local shoe = {}
	for _ = 1, 6 do
		for _, r in ipairs(RANKS) do
			for _, s in ipairs(SUITS) do
				table.insert(shoe, r .. s)
			end
		end
	end
	for i = #shoe, 2, -1 do
		local j = rng:NextInteger(1, i)
		shoe[i], shoe[j] = shoe[j], shoe[i]
	end
	return shoe
end

local function rankOf(card)
	return card:sub(1, #card - 1)
end

local function handTotal(hand)
	local total, aces = 0, 0
	for _, c in ipairs(hand) do
		local r = rankOf(c)
		if r == "A" then
			aces = aces + 1
			total = total + 11
		elseif r == "K" or r == "Q" or r == "J" or r == "10" then
			total = total + 10
		else
			total = total + tonumber(r)
		end
	end
	while total > 21 and aces > 0 do
		total = total - 10
		aces = aces - 1
	end
	return total
end

local function draw(sess)
	if #sess.shoe < 60 then sess.shoe = newShoe() end
	return table.remove(sess.shoe)
end

local function bjPush(plr, phase, message)
	local sess = bjSession[plr]
	if not sess then return end
	local dealerShown = {}
	if phase == "play" then
		dealerShown = { sess.dealer[1], "??" }
	else
		for _, c in ipairs(sess.dealer) do table.insert(dealerShown, c) end
	end
	EV.BJState:FireClient(plr, {
		phase       = phase,
		message     = message or "",
		bet         = sess.bet,
		player      = sess.player,
		playerTotal = handTotal(sess.player),
		dealer      = dealerShown,
		dealerTotal = (phase == "play") and handTotal({ sess.dealer[1] }) or handTotal(sess.dealer),
		canDouble   = (phase == "play") and #sess.player == 2 and not sess.doubled,
	})
end

local function bjSettle(plr)
	local sess = bjSession[plr]
	if not sess then return end

	local pt = handTotal(sess.player)
	local dt = handTotal(sess.dealer)
	local msg, payout

	local playerBJ = (#sess.player == 2 and pt == 21)
	local dealerBJ = (#sess.dealer == 2 and dt == 21)

	if pt > 21 then
		msg, payout = "Bust - you lose " .. sess.bet, 0
	elseif playerBJ and not dealerBJ then
		payout = math.floor(sess.bet * 2.5)
		msg = "Blackjack! +" .. (payout - sess.bet)
	elseif dealerBJ and not playerBJ then
		msg, payout = "Dealer blackjack - you lose " .. sess.bet, 0
	elseif dt > 21 then
		payout = sess.bet * 2
		msg = "Dealer busts! +" .. sess.bet
	elseif pt > dt then
		payout = sess.bet * 2
		msg = "You win! +" .. sess.bet
	elseif pt < dt then
		msg, payout = "Dealer wins - you lose " .. sess.bet, 0
	else
		payout = sess.bet
		msg = "Push - bet returned"
	end

	if payout > 0 then Bank.add(plr, payout) end
	sess.phase = "done"
	bjPush(plr, "done", msg)
end

local function bjDealerPlay(plr)
	local sess = bjSession[plr]
	if not sess then return end
	bjPush(plr, "reveal", "Dealer plays...")
	task.wait(0.7)
	while handTotal(sess.dealer) < 17 do
		table.insert(sess.dealer, draw(sess))
		bjPush(plr, "reveal", "Dealer draws...")
		task.wait(0.7)
	end
	bjSettle(plr)
end

local function bjDeal(plr, bet)
	local sess = bjSession[plr]
	if not sess then return end
	if sess.phase == "play" or sess.phase == "reveal" then return end

	bet = validBet(bet) or 10
	if not Bank.tryDeduct(plr, bet) then
		bjPush(plr, "bet", "Not enough chips - visit the Cashier")
		return
	end

	sess.bet = bet
	sess.doubled = false
	sess.player = { draw(sess), draw(sess) }
	sess.dealer = { draw(sess), draw(sess) }
	sess.phase = "play"

	if handTotal(sess.player) == 21 then
		bjDealerPlay(plr)
	else
		bjPush(plr, "play", "Hit or stand?")
	end
end

local function bjHit(plr)
	local sess = bjSession[plr]
	if not sess or sess.phase ~= "play" then return end
	table.insert(sess.player, draw(sess))
	if handTotal(sess.player) >= 21 then
		bjDealerPlay(plr)
	else
		bjPush(plr, "play", "Hit or stand?")
	end
end

local function bjDouble(plr)
	local sess = bjSession[plr]
	if not sess or sess.phase ~= "play" or #sess.player ~= 2 or sess.doubled then return end
	if not Bank.tryDeduct(plr, sess.bet) then
		bjPush(plr, "play", "Not enough chips to double")
		return
	end
	sess.bet = sess.bet * 2
	sess.doubled = true
	table.insert(sess.player, draw(sess))
	bjDealerPlay(plr)
end

local function bjOpen(plr, tableModel)
	if bjSession[plr] then return end
	bjSession[plr] = {
		shoe = newShoe(), player = {}, dealer = {},
		bet = 10, phase = "bet", table = tableModel, doubled = false,
	}
	EV.BJOpen:FireClient(plr)
	bjPush(plr, "bet", "Place your bet")
end

local function bjClose(plr)
	local sess = bjSession[plr]
	if not sess then return end
	-- an abandoned live hand simply forfeits the stake, already deducted
	bjSession[plr] = nil
	EV.BJClose:FireClient(plr)
end

EV.BJAction.OnServerEvent:Connect(function(plr, action, arg)
	if action == "deal"   then bjDeal(plr, arg)
	elseif action == "hit"    then bjHit(plr)
	elseif action == "stand"  then
		local sess = bjSession[plr]
		if sess and sess.phase == "play" then bjDealerPlay(plr) end
	elseif action == "double" then bjDouble(plr)
	elseif action == "leave"  then bjClose(plr)
	end
end)

-- =====================================================================
-- ROULETTE
-- =====================================================================

local RED = {}
for _, n in ipairs({1,3,5,7,9,12,14,16,18,19,21,23,25,27,30,32,34,36}) do RED[n] = true end

local rlSession = {}      -- player -> table model
local rlSpinning = {}     -- table model -> true

local function spinWheel(tableModel, duration)
	local parts = {}
	local centre
	for _, d in ipairs(tableModel:GetDescendants()) do
		if d:IsA("BasePart") then
			if d.Name == "Wheel" then centre = d.Position end
			if d.Name == "Wheel" or d.Name == "Pocket" or d.Name == "Hub" or d.Name == "Ball" then
				table.insert(parts, { part = d, cf = d.CFrame })
			end
		end
	end
	if not centre then return end

	local t = 0
	local totalTurn = 0
	while t < duration do
		local dt = task.wait()
		t = t + dt
		local speed = 14 * (1 - (t / duration)) ^ 2      -- ease out
		totalTurn = totalTurn + speed * dt
		local rot = CFrame.fromAxisAngle(Vector3.new(0, 1, 0), totalTurn)
		for _, rec in ipairs(parts) do
			rec.part.CFrame = CFrame.new(centre) * rot * CFrame.new(-centre) * rec.cf
		end
	end
end

local function rlBet(plr, betType, stake)
	local tableModel = rlSession[plr]
	if not tableModel then return end
	if rlSpinning[tableModel] then
		Bank.notify(plr, "Wheel is already spinning", "warn")
		return
	end
	stake = validBet(stake)
	if not stake then return end

	local valid = { red = true, black = true, green = true, odd = true, even = true }
	if not valid[betType] then return end

	if not Bank.tryDeduct(plr, stake) then
		Bank.notify(plr, "Not enough chips - visit the Cashier", "warn")
		return
	end

	rlSpinning[tableModel] = true
	EV.RLResult:FireClient(plr, { phase = "spinning" })

	task.spawn(function()
		spinWheel(tableModel, 3.2)

		local n = rng:NextInteger(0, 36)
		local colour = (n == 0) and "green" or (RED[n] and "red" or "black")
		local won = false
		if betType == colour then won = true
		elseif betType == "odd"  and n > 0 and n % 2 == 1 then won = true
		elseif betType == "even" and n > 0 and n % 2 == 0 then won = true
		end

		local payout = 0
		if won then
			payout = (betType == "green") and stake * 36 or stake * 2
			Bank.add(plr, payout)
		end

		EV.RLResult:FireClient(plr, {
			phase = "result", number = n, colour = colour,
			won = won, payout = payout, stake = stake,
		})
		Bank.notify(plr,
			(won and ("Roulette " .. n .. " " .. colour .. " - won " .. (payout - stake))
			      or ("Roulette " .. n .. " " .. colour .. " - lost " .. stake)),
			won and "win" or "lose")

		rlSpinning[tableModel] = nil
	end)
end

EV.RLBet.OnServerEvent:Connect(function(plr, betType, stake)
	rlBet(plr, betType, stake)
end)
EV.RLClose.OnServerEvent:Connect(function(plr)
	rlSession[plr] = nil
end)

-- =====================================================================
-- WIRING
-- =====================================================================

local casino = workspace:WaitForChild("Casino", 30)
local tables = casino:WaitForChild("Tables")

local bjCount, rlCount = 0, 0

for _, model in ipairs(tables:GetChildren()) do
	if model.Name == "BlackjackTable" then
		local tbl = model:FindFirstChild("Table")
		if tbl then
			local c = centreOf(tbl)
			local anchor = tbl:FindFirstChild("_Collider") or tbl:FindFirstChildWhichIsA("BasePart", true)
			if anchor then
				local p = makePrompt(anchor, CFrame.new(c.X, c.Y + 2.2, c.Z - 4.6), "Play Blackjack", "Blackjack", 11)
				p.Triggered:Connect(function(plr) bjOpen(plr, model) end)
				bjCount = bjCount + 1
			end
		end
	elseif model.Name == "RouletteTable" then
		local top = model:FindFirstChild("Top")
		local anchor = top or model:FindFirstChildWhichIsA("BasePart", true)
		if anchor then
			local c = centreOf(model)
			local p = makePrompt(anchor, CFrame.new(c.X, c.Y + 3.0, c.Z + 5.0), "Place Bet", "Roulette", 12)
			p.Triggered:Connect(function(plr)
				rlSession[plr] = model
				EV.RLOpen:FireClient(plr)
			end)
			rlCount = rlCount + 1
		end
	end
end

Players.PlayerRemoving:Connect(function(plr)
	bjSession[plr] = nil
	rlSession[plr] = nil
end)

print("[Casino] TableGames ready - " .. bjCount .. " blackjack, " .. rlCount .. " roulette")
