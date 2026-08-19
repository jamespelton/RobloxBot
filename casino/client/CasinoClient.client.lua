-- CasinoClient : chips HUD, bet selector, toasts, blackjack and roulette panels.

local Players = game:GetService("Players")
local RS      = game:GetService("ReplicatedStorage")
local TS      = game:GetService("TweenService")

local plr = Players.LocalPlayer
local EV  = RS:WaitForChild("CasinoEvents")

local BETS = { 10, 25, 50, 100, 250 }
local currentBet = 10

-- muted palette to match the room
local BG      = Color3.fromRGB(26, 24, 28)
local BG2     = Color3.fromRGB(38, 35, 40)
local GOLD    = Color3.fromRGB(168, 148, 104)
local CREAM   = Color3.fromRGB(238, 232, 220)
local GREENC  = Color3.fromRGB(120, 175, 130)
local REDC    = Color3.fromRGB(198, 96, 96)

local gui = Instance.new("ScreenGui")
gui.Name = "CasinoUI"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = plr:WaitForChild("PlayerGui")

local function corner(inst, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 8)
	c.Parent = inst
	return c
end
local function stroke(inst, col, th)
	local s = Instance.new("UIStroke")
	s.Color = col or GOLD
	s.Thickness = th or 1
	s.Transparency = 0.35
	s.Parent = inst
	return s
end
local function sound(id, vol, speed)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = vol or 0.5
	s.PlaybackSpeed = speed or 1
	s.Parent = workspace
	s:Play()
	game:GetService("Debris"):AddItem(s, 4)
end
local CLICK = "rbxasset://sounds/clickfast.wav"
local PING  = "rbxasset://sounds/electronicpingshort.wav"
local THUD  = "rbxasset://sounds/collide.wav"

local function button(parent, text, size, pos, col)
	local b = Instance.new("TextButton")
	b.Size = size
	b.Position = pos
	b.BackgroundColor3 = col or BG2
	b.AutoButtonColor = true
	b.Font = Enum.Font.GothamBold
	b.Text = text
	b.TextColor3 = CREAM
	b.TextScaled = true
	b.BorderSizePixel = 0
	b.Parent = parent
	corner(b, 6)
	stroke(b)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 4); pad.PaddingBottom = UDim.new(0, 4)
	pad.PaddingLeft = UDim.new(0, 6); pad.PaddingRight = UDim.new(0, 6)
	pad.Parent = b
	b.MouseButton1Click:Connect(function() sound(CLICK, 0.35) end)
	return b
end

-- =====================================================================
-- HUD : chips + bet selector
-- =====================================================================

local hud = Instance.new("Frame")
hud.Size = UDim2.new(0, 300, 0, 92)
hud.Position = UDim2.new(1, -316, 0, 16)
hud.BackgroundColor3 = BG
hud.BackgroundTransparency = 0.1
hud.BorderSizePixel = 0
hud.Parent = gui
corner(hud, 10)
stroke(hud)

local chipsLabel = Instance.new("TextLabel")
chipsLabel.Size = UDim2.new(1, -20, 0, 34)
chipsLabel.Position = UDim2.new(0, 10, 0, 6)
chipsLabel.BackgroundTransparency = 1
chipsLabel.Font = Enum.Font.GothamBlack
chipsLabel.TextScaled = true
chipsLabel.TextXAlignment = Enum.TextXAlignment.Left
chipsLabel.TextColor3 = GOLD
chipsLabel.Text = "0 CHIPS"
chipsLabel.Parent = hud

local betRow = Instance.new("Frame")
betRow.Size = UDim2.new(1, -20, 0, 34)
betRow.Position = UDim2.new(0, 10, 0, 46)
betRow.BackgroundTransparency = 1
betRow.Parent = hud
local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.Padding = UDim.new(0, 4)
layout.Parent = betRow

local betButtons = {}
local function refreshBetButtons()
	for v, b in pairs(betButtons) do
		b.BackgroundColor3 = (v == currentBet) and GOLD or BG2
		b.TextColor3 = (v == currentBet) and BG or CREAM
	end
end
for _, v in ipairs(BETS) do
	local b = button(betRow, tostring(v), UDim2.new(0, 52, 1, 0), UDim2.new(), BG2)
	betButtons[v] = b
	b.MouseButton1Click:Connect(function()
		currentBet = v
		refreshBetButtons()
		EV.SlotSpin:FireServer(v)
	end)
end
refreshBetButtons()

local hint = Instance.new("TextLabel")
hint.Size = UDim2.new(0, 300, 0, 20)
hint.Position = UDim2.new(1, -316, 0, 112)
hint.BackgroundTransparency = 1
hint.Font = Enum.Font.Gotham
hint.TextSize = 13
hint.TextXAlignment = Enum.TextXAlignment.Right
hint.TextColor3 = Color3.fromRGB(150, 145, 140)
hint.Text = "Walk up to a machine and press E"
hint.Parent = gui

local function setChips(n)
	chipsLabel.Text = string.format("%d CHIPS", n)
end

local ls = plr:WaitForChild("leaderstats", 10)
if ls then
	local c = ls:WaitForChild("Chips", 10)
	if c then
		setChips(c.Value)
		c.Changed:Connect(setChips)
	end
end
EV.ChipsChanged.OnClientEvent:Connect(setChips)

-- =====================================================================
-- Toasts
-- =====================================================================

local toastHolder = Instance.new("Frame")
toastHolder.Size = UDim2.new(0, 380, 0, 200)
toastHolder.Position = UDim2.new(0.5, -190, 1, -260)
toastHolder.BackgroundTransparency = 1
toastHolder.Parent = gui
local tl = Instance.new("UIListLayout")
tl.VerticalAlignment = Enum.VerticalAlignment.Bottom
tl.HorizontalAlignment = Enum.HorizontalAlignment.Center
tl.Padding = UDim.new(0, 6)
tl.Parent = toastHolder

local function toast(text, kind)
	local f = Instance.new("Frame")
	f.Size = UDim2.new(0, 340, 0, 34)
	f.BackgroundColor3 = BG
	f.BackgroundTransparency = 0.08
	f.BorderSizePixel = 0
	f.Parent = toastHolder
	corner(f, 8)
	local col = CREAM
	if kind == "win"  then col = GREENC
	elseif kind == "lose" then col = Color3.fromRGB(170, 130, 130)
	elseif kind == "warn" then col = Color3.fromRGB(212, 176, 110) end
	stroke(f, col, 1)

	local t = Instance.new("TextLabel")
	t.Size = UDim2.new(1, -16, 1, 0)
	t.Position = UDim2.new(0, 8, 0, 0)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.GothamBold
	t.TextSize = 15
	t.TextColor3 = col
	t.Text = text
	t.Parent = f

	if kind == "win" then sound(PING, 0.5, 1.1) end
	task.delay(3, function()
		TS:Create(f, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
		TS:Create(t, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		task.wait(0.45)
		f:Destroy()
	end)
end

EV.Notify.OnClientEvent:Connect(toast)

EV.SlotResult.OnClientEvent:Connect(function(machine, a, b, c, payout, who)
	if who == plr.Name then
		sound(THUD, 0.25, 1.6)
	elseif payout >= 500 then
		toast(who .. " hit " .. a .. b .. c .. " for " .. payout .. "!", "win")
	end
end)

-- =====================================================================
-- Shared panel chrome
-- =====================================================================

local function makePanel(titleText, w, h)
	local p = Instance.new("Frame")
	p.Size = UDim2.new(0, w, 0, h)
	p.Position = UDim2.new(0.5, -w / 2, 0.5, -h / 2)
	p.BackgroundColor3 = BG
	p.BackgroundTransparency = 0.04
	p.BorderSizePixel = 0
	p.Visible = false
	p.Parent = gui
	corner(p, 12)
	stroke(p, GOLD, 1.5)

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 36)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 18
	title.TextColor3 = GOLD
	title.Text = titleText
	title.Parent = p
	return p
end

-- =====================================================================
-- BLACKJACK
-- =====================================================================

local bj = makePanel("BLACKJACK", 560, 400)

local SUIT = { S = "\u{2660}", H = "\u{2665}", D = "\u{2666}", C = "\u{2663}" }

local function cardRow(parent, y, labelText)
	local head = Instance.new("TextLabel")
	head.Size = UDim2.new(1, -24, 0, 18)
	head.Position = UDim2.new(0, 12, 0, y)
	head.BackgroundTransparency = 1
	head.Font = Enum.Font.GothamBold
	head.TextSize = 13
	head.TextXAlignment = Enum.TextXAlignment.Left
	head.TextColor3 = Color3.fromRGB(160, 155, 150)
	head.Text = labelText
	head.Parent = parent

	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -24, 0, 74)
	row.Position = UDim2.new(0, 12, 0, y + 20)
	row.BackgroundTransparency = 1
	row.Parent = parent
	local l = Instance.new("UIListLayout")
	l.FillDirection = Enum.FillDirection.Horizontal
	l.Padding = UDim.new(0, 6)
	l.Parent = row
	return row, head
end

local dealerRow, dealerHead = cardRow(bj, 44,  "DEALER")
local playerRow, playerHead = cardRow(bj, 160, "YOU")

local bjMsg = Instance.new("TextLabel")
bjMsg.Size = UDim2.new(1, -24, 0, 26)
bjMsg.Position = UDim2.new(0, 12, 0, 254)
bjMsg.BackgroundTransparency = 1
bjMsg.Font = Enum.Font.GothamBold
bjMsg.TextSize = 16
bjMsg.TextColor3 = CREAM
bjMsg.Text = ""
bjMsg.Parent = bj

local function renderCards(row, cards)
	row:ClearAllChildren()
	local l = Instance.new("UIListLayout")
	l.FillDirection = Enum.FillDirection.Horizontal
	l.Padding = UDim.new(0, 6)
	l.Parent = row
	for _, c in ipairs(cards) do
		local f = Instance.new("Frame")
		f.Size = UDim2.new(0, 52, 0, 72)
		f.BackgroundColor3 = (c == "??") and Color3.fromRGB(70, 60, 66) or Color3.fromRGB(240, 236, 228)
		f.BorderSizePixel = 0
		f.Parent = row
		corner(f, 6)
		local t = Instance.new("TextLabel")
		t.Size = UDim2.new(1, 0, 1, 0)
		t.BackgroundTransparency = 1
		t.Font = Enum.Font.GothamBlack
		t.TextSize = 20
		t.Parent = f
		if c == "??" then
			t.Text = "?"
			t.TextColor3 = Color3.fromRGB(150, 140, 150)
		else
			local rank = c:sub(1, #c - 1)
			local suit = c:sub(#c)
			t.Text = rank .. (SUIT[suit] or suit)
			t.TextColor3 = (suit == "H" or suit == "D") and Color3.fromRGB(180, 60, 60) or Color3.fromRGB(35, 35, 40)
		end
	end
end

local bjBtnRow = Instance.new("Frame")
bjBtnRow.Size = UDim2.new(1, -24, 0, 40)
bjBtnRow.Position = UDim2.new(0, 12, 1, -54)
bjBtnRow.BackgroundTransparency = 1
bjBtnRow.Parent = bj
local bl = Instance.new("UIListLayout")
bl.FillDirection = Enum.FillDirection.Horizontal
bl.Padding = UDim.new(0, 8)
bl.Parent = bjBtnRow

local bDeal   = button(bjBtnRow, "DEAL",   UDim2.new(0, 100, 1, 0), UDim2.new(), GOLD)
bDeal.TextColor3 = BG
local bHit    = button(bjBtnRow, "HIT",    UDim2.new(0, 96, 1, 0), UDim2.new())
local bStand  = button(bjBtnRow, "STAND",  UDim2.new(0, 96, 1, 0), UDim2.new())
local bDouble = button(bjBtnRow, "DOUBLE", UDim2.new(0, 108, 1, 0), UDim2.new())
local bLeave  = button(bjBtnRow, "LEAVE",  UDim2.new(0, 96, 1, 0), UDim2.new())

bDeal.MouseButton1Click:Connect(function()   EV.BJAction:FireServer("deal", currentBet) end)
bHit.MouseButton1Click:Connect(function()    EV.BJAction:FireServer("hit") end)
bStand.MouseButton1Click:Connect(function()  EV.BJAction:FireServer("stand") end)
bDouble.MouseButton1Click:Connect(function() EV.BJAction:FireServer("double") end)
bLeave.MouseButton1Click:Connect(function()  EV.BJAction:FireServer("leave") end)

EV.BJOpen.OnClientEvent:Connect(function() bj.Visible = true end)
EV.BJClose.OnClientEvent:Connect(function() bj.Visible = false end)

EV.BJState.OnClientEvent:Connect(function(s)
	bj.Visible = true
	renderCards(dealerRow, s.dealer)
	renderCards(playerRow, s.player)
	dealerHead.Text = "DEALER  -  " .. (s.phase == "play" and "?" or tostring(s.dealerTotal))
	playerHead.Text = "YOU  -  " .. tostring(s.playerTotal)
	bjMsg.Text = s.message .. (s.bet and ("      bet " .. s.bet) or "")

	local playing = (s.phase == "play")
	-- during the dealer's reveal nothing should be clickable
	bDeal.Visible   = (s.phase == "bet" or s.phase == "done")
	bHit.Visible    = playing
	bStand.Visible  = playing
	bDouble.Visible = (playing and s.canDouble) == true
	bDeal.Text = (s.phase == "done") and "DEAL AGAIN" or "DEAL"
end)

-- =====================================================================
-- ROULETTE
-- =====================================================================

local rl = makePanel("ROULETTE", 460, 300)

local rlMsg = Instance.new("TextLabel")
rlMsg.Size = UDim2.new(1, -24, 0, 60)
rlMsg.Position = UDim2.new(0, 12, 0, 48)
rlMsg.BackgroundTransparency = 1
rlMsg.Font = Enum.Font.GothamBlack
rlMsg.TextSize = 30
rlMsg.TextColor3 = CREAM
rlMsg.Text = "Choose a bet"
rlMsg.Parent = rl

local rlSub = Instance.new("TextLabel")
rlSub.Size = UDim2.new(1, -24, 0, 22)
rlSub.Position = UDim2.new(0, 12, 0, 108)
rlSub.BackgroundTransparency = 1
rlSub.Font = Enum.Font.Gotham
rlSub.TextSize = 14
rlSub.TextColor3 = Color3.fromRGB(155, 150, 145)
rlSub.Text = "Red / Black pay 2x, Odd / Even pay 2x, Green pays 36x"
rlSub.Parent = rl

local rlRow = Instance.new("Frame")
rlRow.Size = UDim2.new(1, -24, 0, 46)
rlRow.Position = UDim2.new(0, 12, 0, 146)
rlRow.BackgroundTransparency = 1
rlRow.Parent = rl
local rlay = Instance.new("UIListLayout")
rlay.FillDirection = Enum.FillDirection.Horizontal
rlay.Padding = UDim.new(0, 6)
rlay.Parent = rlRow

local function rlBtn(text, kind, col)
	local b = button(rlRow, text, UDim2.new(0, 82, 1, 0), UDim2.new(), col)
	b.MouseButton1Click:Connect(function()
		EV.RLBet:FireServer(kind, currentBet)
	end)
	return b
end
rlBtn("RED",   "red",   Color3.fromRGB(140, 62, 62))
rlBtn("BLACK", "black", Color3.fromRGB(48, 46, 52))
rlBtn("GREEN", "green", Color3.fromRGB(58, 110, 74))
rlBtn("ODD",   "odd",   BG2)
rlBtn("EVEN",  "even",  BG2)

local rlLeave = button(rl, "LEAVE", UDim2.new(0, 100, 0, 34), UDim2.new(0.5, -50, 1, -46))
rlLeave.MouseButton1Click:Connect(function()
	rl.Visible = false
	EV.RLClose:FireServer()
end)

EV.RLOpen.OnClientEvent:Connect(function()
	rl.Visible = true
	rlMsg.Text = "Choose a bet"
	rlMsg.TextColor3 = CREAM
end)

EV.RLResult.OnClientEvent:Connect(function(s)
	if s.phase == "spinning" then
		rlMsg.Text = "Spinning..."
		rlMsg.TextColor3 = Color3.fromRGB(200, 190, 175)
	else
		rlMsg.Text = tostring(s.number) .. "  " .. string.upper(s.colour)
		rlMsg.TextColor3 = s.won and GREENC or REDC
		if s.won then sound(PING, 0.6, 1.0) end
	end
end)

print("[Casino] CasinoClient ready")
