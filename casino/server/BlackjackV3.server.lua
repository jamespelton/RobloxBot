-- BLACKJACK GAME v3 (Script in ServerScriptService)
-- James's multiplayer blackjack: sit in a chair, bet on a timer, take turns,
-- then the dealer NPC plays. Clients: BlackjackHUD (camera + buttons) and
-- BlackjackTutorial.
-- Casino changes from James's original:
--   * Chips go through CasinoCore's _G.CasinoBank (saved chips, chip HUD updates)
--     instead of creating leaderstats here - creating them first stopped
--     CasinoCore loading a player's saved balance.
--   * No auto-bet: if you don't press BET you sit that round out.
--   * No free refills: under the minimum bet means a trip to the Cashier.
--   * Line breaks built with NL (the Studio bridge mangles backslash-n).
--   * The stool on the dealer's side isn't a player seat; it's hidden so the
--     dealer NPC can stand there (HIDE_DEALER_STOOL).
--   * Sends a "hands" message (every hand, turn and status) for the on-screen
--     cards in BlackjackHUD v3, and puts a "Sit & Play" BlackjackJoinPrompt on
--     each player seat.

-- Settings:
local MIN_BET, MAX_BET = 10, 500
local BET_TIME = 10
local TURN_TIME = 20
local DEALER_REVEAL_DELAY = 2.2  -- seconds the dealer waits before flipping the hidden card
local DEALER_DRAW_DELAY = 1.8    -- seconds the dealer takes before each extra card
local CARD_INSET = 2.2           -- how far onto the felt cards sit from the table edge
local DEALER_NPC = true
local HIDE_DEALER_STOOL = true   -- the casino has a stool where the dealer NPC stands; hide it while the game runs

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local remote = ReplicatedStorage:FindFirstChild("BlackjackRemote") or Instance.new("RemoteEvent")
remote.Name = "BlackjackRemote"
remote.Parent = ReplicatedStorage

local V = Vector3.new
local UP = V(0, 1, 0)
local NL = string.char(10)
local rng = Random.new()
local function flat(v)
    return V(v.X, 0, v.Z)
end

----------------------------------------------------------------
-- Chips (CasinoCore owns them)
----------------------------------------------------------------
local Bank
for _ = 1, 300 do
    Bank = _G.CasinoBank
    if Bank then
        break
    end
    task.wait(0.1)
end
if not Bank then
    warn("[Blackjack] CasinoCore's _G.CasinoBank never appeared - blackjack is off.")
    return
end

local function chipBalance(player)
    return Bank.get(player) or 0
end

task.wait(6)

----------------------------------------------------------------
-- Cards
----------------------------------------------------------------
local SUITS = { "♠", "♥", "♦", "♣" }
local RANKS = { "A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K" }

local function newShoe()
    local shoe = {}
    for _ = 1, 6 do
        for _, suit in ipairs(SUITS) do
            for _, rank in ipairs(RANKS) do
                table.insert(shoe, { rank = rank, suit = suit })
            end
        end
    end
    for i = #shoe, 2, -1 do
        local j = rng:NextInteger(1, i)
        shoe[i], shoe[j] = shoe[j], shoe[i]
    end
    return shoe
end
local function cardValue(rank)
    if rank == "A" then
        return 11
    elseif rank == "J" or rank == "Q" or rank == "K" then
        return 10
    end
    return tonumber(rank)
end
local function handTotal(cards)
    local total, aces = 0, 0
    for _, c in ipairs(cards) do
        if not c.hidden then
            total += cardValue(c.rank)
            if c.rank == "A" then
                aces += 1
            end
        end
    end
    while total > 21 and aces > 0 do
        total -= 10
        aces -= 1
    end
    return total
end
local function isBlackjack(cards)
    return #cards == 2 and handTotal(cards) == 21
end

----------------------------------------------------------------
-- Visual helpers
----------------------------------------------------------------
local function newPart(parent, size, color, material)
    local p = Instance.new("Part")
    p.Anchored = true
    p.CanCollide = false
    p.CanTouch = false
    p.CanQuery = false
    p.CastShadow = false
    p.Size = size
    p.Color = color
    p.Material = material or Enum.Material.SmoothPlastic
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.Parent = parent
    return p
end

local function setCardFace(part, card, faceUp)
    for _, child in ipairs(part:GetChildren()) do
        child:Destroy()
    end
    local gui = Instance.new("SurfaceGui")
    gui.Face = Enum.NormalId.Top
    gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    gui.PixelsPerStud = 80
    gui.Parent = part
    if faceUp then
        part.Color = Color3.fromRGB(250, 250, 245)
        local red = card.suit == "♥" or card.suit == "♦"
        local label = Instance.new("TextLabel")
        label.Size = UDim2.fromScale(1, 1)
        label.BackgroundTransparency = 1
        label.Text = card.rank .. NL .. card.suit
        label.TextScaled = true
        label.Font = Enum.Font.GothamBlack
        label.TextColor3 = red and Color3.fromRGB(200, 25, 30) or Color3.fromRGB(20, 20, 20)
        label.Parent = gui
    else
        part.Color = Color3.fromRGB(150, 20, 30)
        local border = Instance.new("Frame")
        border.AnchorPoint = Vector2.new(0.5, 0.5)
        border.Position = UDim2.fromScale(0.5, 0.5)
        border.Size = UDim2.fromScale(0.78, 0.82)
        border.BackgroundTransparency = 1
        border.Parent = gui
        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromRGB(212, 175, 55)
        stroke.Thickness = 4
        stroke.Parent = border
    end
end

local function makeBillboard(parent, position)
    local anchor = newPart(parent, V(0.2, 0.2, 0.2), Color3.new(1, 1, 1))
    anchor.Transparency = 1
    anchor.CFrame = CFrame.new(position)
    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.fromOffset(170, 56)
    bb.AlwaysOnTop = true
    bb.LightInfluence = 0
    bb.MaxDistance = 60
    bb.Parent = anchor
    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundColor3 = Color3.fromRGB(15, 12, 20)
    label.BackgroundTransparency = 0.25
    label.TextScaled = true
    label.Font = Enum.Font.GothamBold
    label.TextColor3 = Color3.new(1, 1, 1)
    label.Text = ""
    label.Parent = bb
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0.25, 0)
    corner.Parent = label
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(212, 175, 55)
    stroke.Thickness = 2
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent = label
    return anchor, label
end

local function buildDealer(parent, standPos, facing)
    local root = CFrame.lookAt(standPos, standPos + facing)
    local skin = Color3.fromRGB(230, 190, 150)
    local function piece(size, offset, color, material)
        local p = newPart(parent, size, color, material)
        p.CFrame = root * offset
        p.CanCollide = true
        return p
    end
    piece(V(0.95, 2.2, 0.95), CFrame.new(-0.5, 1.1, 0), Color3.fromRGB(20, 20, 22))
    piece(V(0.95, 2.2, 0.95), CFrame.new(0.5, 1.1, 0), Color3.fromRGB(20, 20, 22))
    piece(V(2.05, 2.2, 1.1), CFrame.new(0, 3.3, 0), Color3.fromRGB(240, 240, 240))
    piece(V(2.1, 2.0, 1.15), CFrame.new(0, 3.25, 0.02), Color3.fromRGB(25, 25, 28), Enum.Material.Fabric)
    piece(V(0.9, 1.9, 0.05), CFrame.new(0, 3.4, -0.58), Color3.fromRGB(240, 240, 240))
    piece(V(0.6, 0.25, 0.08), CFrame.new(0, 4.2, -0.62), Color3.fromRGB(180, 20, 30))
    for _, side in ipairs({ -1, 1 }) do
        piece(V(0.75, 2.0, 0.75), CFrame.new(side * 1.4, 3.3, -0.2) * CFrame.Angles(math.rad(25), 0, 0), Color3.fromRGB(240, 240, 240))
        piece(V(0.6, 0.6, 0.6), CFrame.new(side * 1.4, 2.4, -0.7), skin)
    end
    local head = piece(V(1.3, 1.3, 1.3), CFrame.new(0, 5.1, 0), skin)
    piece(V(1.38, 0.45, 1.38), CFrame.new(0, 5.8, 0.05), Color3.fromRGB(40, 28, 20))
    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.fromOffset(100, 28)
    bb.StudsOffset = V(0, 1.6, 0)
    bb.Parent = head
    local tag = Instance.new("TextLabel")
    tag.Size = UDim2.fromScale(1, 1)
    tag.BackgroundTransparency = 1
    tag.Text = "DEALER"
    tag.TextScaled = true
    tag.Font = Enum.Font.GothamBlack
    tag.TextColor3 = Color3.fromRGB(255, 215, 110)
    tag.Parent = bb
    return head
end

----------------------------------------------------------------
-- Find the tables and give every seat to its nearest table
----------------------------------------------------------------
local tableList = {}
for _, model in ipairs(workspace:GetDescendants()) do
    if model:IsA("Model") then
        local lname = string.lower(model.Name)
        if string.find(lname, "blackjack") and not string.find(lname, "_chairs") then
            local cf, size = model:GetBoundingBox()
            table.insert(tableList, { model = model, cf = cf, size = size, seats = {} })
        end
    end
end
for _, s in ipairs(workspace:GetDescendants()) do
    if s:IsA("Seat") then
        local best, bestDistance
        for _, t in ipairs(tableList) do
            local d = flat(s.Position - t.cf.Position).Magnitude
            local reach = math.max(t.size.X, t.size.Z) / 2 + 6
            if d <= reach and math.abs(s.Position.Y - t.cf.Position.Y) < 8 and (not bestDistance or d < bestDistance) then
                best, bestDistance = t, d
            end
        end
        if best then
            table.insert(best.seats, s)
        end
    end
end

local tables = {}
for _, raw in ipairs(tableList) do
    if #raw.seats == 0 then
        warn("[Blackjack] No seats found at " .. raw.model:GetFullName() .. " - make the chairs sittable.")
        continue
    end
    local boxCenter = raw.cf.Position
    local reach = math.max(raw.size.X, raw.size.Z) / 2 + 10

    -- Rays that only hit this table
    local tableOnly = RaycastParams.new()
    tableOnly.FilterType = Enum.RaycastFilterType.Include
    tableOnly.FilterDescendantsInstances = { raw.model }
    local hitTop = workspace:Raycast(boxCenter + V(0, raw.size.Y / 2 + 5, 0), V(0, -(raw.size.Y + 10), 0), tableOnly)
    local feltY = hitTop and hitTop.Position.Y or (boxCenter.Y + raw.size.Y / 2)
    local center = V(boxCenter.X, feltY, boxCenter.Z)

    local function feltAt(p)
        local hit = workspace:Raycast(V(p.X, feltY + 5, p.Z), V(0, -10, 0), tableOnly)
        return V(p.X, hit and hit.Position.Y or feltY, p.Z)
    end
    -- Walk from a point toward the middle of the table until hitting its edge,
    -- then step onto the felt
    local function spotFrom(fromXZ)
        local dir = flat(center - fromXZ)
        if dir.Magnitude < 0.01 then
            return center, V(0, 0, 1)
        end
        dir = dir.Unit
        local origin = V(fromXZ.X, feltY - 0.4, fromXZ.Z)
        local hit = workspace:Raycast(origin, dir * (reach * 2), tableOnly)
        local edge = hit and flat(hit.Position) + V(0, feltY, 0) or (center - dir * (reach - 10))
        return feltAt(edge + dir * CARD_INSET), dir, edge
    end

    -- The dealer stands on the side away from the chairs
    local avg = V(0, 0, 0)
    for _, s in ipairs(raw.seats) do
        avg += flat(s.Position - center).Unit
    end
    local dealerDir = avg.Magnitude > 0.01 and -avg.Unit or V(0, 0, -1)
    local toPlayers = -dealerDir
    local right = toPlayers:Cross(UP)

    -- Seats on the dealer's side aren't player seats (the casino puts a
    -- dealer stool there, right where the dealer NPC stands)
    local playerSeats = {}
    for _, s in ipairs(raw.seats) do
        if flat(s.Position - center):Dot(dealerDir) > 0 then
            if HIDE_DEALER_STOOL then
                s.Disabled = true
                for _, p in ipairs(s.Parent:GetDescendants()) do
                    if p:IsA("BasePart") and flat(p.Position - s.Position).Magnitude < 2.5 and math.abs(p.Position.Y - s.Position.Y) < 6 then
                        p.Transparency = 1
                        p.CanCollide = false
                        p.CanQuery = false
                        p.CastShadow = false
                    end
                end
            end
        else
            table.insert(playerSeats, s)
        end
    end
    raw.seats = playerSeats

    local seats = table.clone(raw.seats)
    table.sort(seats, function(a, b)
        local da, db = flat(a.Position - center), flat(b.Position - center)
        return math.atan2(da:Dot(right), da:Dot(toPlayers)) < math.atan2(db:Dot(right), db:Dot(toPlayers))
    end)

    local folder = Instance.new("Folder")
    folder.Name = "BlackjackGame_" .. (#tables + 1)
    folder.Parent = workspace

    -- Each player's cards: on the felt at the edge closest to their own chair
    local seatInfos = {}
    local playerAreaSum = V(0, 0, 0)
    for _, s in ipairs(seats) do
        local spot, inward = spotFrom(s.Position)
        local out = -inward
        playerAreaSum += spot
        local _, label = makeBillboard(folder, spot + V(0, 2.4, 0))
        table.insert(seatInfos, { seat = s, spot = spot, out = out, tangent = out:Cross(UP), label = label })

        -- "Sit & Play" prompt (BlackjackHUD hides these while you're seated)
        local prompt = Instance.new("ProximityPrompt")
        prompt.Name = "BlackjackJoinPrompt"
        prompt.ActionText = "Sit & Play"
        prompt.ObjectText = "Blackjack"
        prompt.HoldDuration = 0
        prompt.MaxActivationDistance = 8
        prompt.RequiresLineOfSight = false
        prompt.Parent = s
        prompt.Triggered:Connect(function(plr)
            local humanoid = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
            if humanoid and humanoid.Health > 0 and not s.Occupant and not humanoid.SeatPart then
                s:Sit(humanoid)
            end
        end)
        s:GetPropertyChangedSignal("Occupant"):Connect(function()
            prompt.Enabled = s.Occupant == nil
        end)
    end

    -- Dealer: on the opposite side of the table from the players
    local dealerSpot, _, dealerEdge = spotFrom(center + dealerDir * reach)
    local _, dealerLabel = makeBillboard(folder, dealerSpot + V(0, 2.6, 0))
    local shoePos = feltAt(dealerSpot + right * 2.8)
    local shoe = newPart(folder, V(1.2, 0.6, 1.8), Color3.fromRGB(20, 20, 22))
    shoe.CFrame = CFrame.lookAt(shoePos + V(0, 0.3, 0), shoePos + V(0, 0.3, 0) + toPlayers)
    newPart(folder, V(1.0, 0.1, 0.05), Color3.fromRGB(212, 175, 55), Enum.Material.Metal).CFrame = shoe.CFrame * CFrame.new(0, 0.25, -0.92)

    local stand = dealerEdge + dealerDir * 1.6
    local dealerHead
    if DEALER_NPC then
        local floorParams = RaycastParams.new()
        floorParams.FilterType = Enum.RaycastFilterType.Exclude
        floorParams.FilterDescendantsInstances = { raw.model, folder }
        local floorHit = workspace:Raycast(V(stand.X, feltY + 2, stand.Z), V(0, -20, 0), floorParams)
        local floorY = floorHit and floorHit.Position.Y or (feltY - 3.5)
        dealerHead = buildDealer(folder, V(stand.X, floorY, stand.Z), toPlayers)
    end
    local headPos = dealerHead and dealerHead.Position or (V(stand.X, feltY + 2, stand.Z))

    table.insert(tables, {
        id = #tables + 1, model = raw.model, center = center, dealerDir = dealerDir,
        seats = seatInfos, dealerSpot = dealerSpot, dealerLabel = dealerLabel, shoePos = shoePos + V(0, 0.6, 0),
        dealerEye = headPos + dealerDir * 2.5 + UP * 1.8,
        dealerLook = #seatInfos > 0 and (playerAreaSum / #seatInfos) or center,
        folder = folder, shoe = newShoe(), pending = {}, confirmed = {}, cardParts = {},
    })
end
print("[Blackjack] Ready at " .. #tables .. " table(s)")

----------------------------------------------------------------
-- Game logic
----------------------------------------------------------------
local function seatedPlayers(t)
    local list = {}
    for _, info in ipairs(t.seats) do
        local occupant = info.seat.Occupant
        local player = occupant and Players:GetPlayerFromCharacter(occupant.Parent)
        if player then
            table.insert(list, { player = player, info = info })
        end
    end
    return list
end
local function tableOf(player)
    for _, t in ipairs(tables) do
        for _, entry in ipairs(seatedPlayers(t)) do
            if entry.player == player then
                return t, entry.info
            end
        end
    end
end
local function stillSeated(t, player)
    for _, entry in ipairs(seatedPlayers(t)) do
        if entry.player == player then
            return true
        end
    end
    return false
end
local function broadcast(t, kind, data)
    data = data or {}
    data.table = t.id
    data.center = t.center
    for _, entry in ipairs(seatedPlayers(t)) do
        local personal = table.clone(data)
        personal.mySpot = entry.info.spot
        remote:FireClient(entry.player, kind, personal)
    end
end
local function draw(t)
    if #t.shoe < 52 then
        t.shoe = newShoe()
    end
    return table.remove(t.shoe)
end
local function dealCard(t, hand, spot, tangent, facing, faceUp)
    local card = draw(t)
    card.hidden = not faceUp
    table.insert(hand.cards, card)
    local k = #hand.cards
    local target = spot + tangent * ((k - 1) * 0.62 - 0.3) + facing * (k * 0.05) + V(0, 0.03 + k * 0.006, 0)
    local part = newPart(t.folder, V(1.0, 0.04, 1.4), Color3.new(1, 1, 1))
    part.CFrame = CFrame.lookAt(t.shoePos, t.shoePos + facing)
    setCardFace(part, card, faceUp)
    card.part = part
    TweenService:Create(part, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { CFrame = CFrame.lookAt(target, target + facing) }):Play()
    table.insert(t.cardParts, part)
    task.wait(0.4)
    return card
end
local function updateLabel(label, name, cards, extra)
    local shown = handTotal(cards)
    local hidden = false
    for _, c in ipairs(cards) do
        if c.hidden then
            hidden = true
        end
    end
    label.Text = name .. ":  " .. shown .. (hidden and " + ?" or "") .. (extra and (NL .. extra) or "")
    label.TextColor3 = shown > 21 and Color3.fromRGB(255, 90, 90) or Color3.new(1, 1, 1)
end

-- Everything the on-screen hands need. The dealer's hidden card is sent as
-- { h = true } with no rank, so nobody can peek at it.
local function handData(cards)
    local list, hidden = {}, false
    for _, c in ipairs(cards) do
        if c.hidden then
            hidden = true
            table.insert(list, { h = true })
        else
            table.insert(list, { r = c.rank, s = c.suit })
        end
    end
    return list, hidden
end
local function sendHands(t, players, dealer, turnId)
    local dealerCards, dealerHidden = handData(dealer.cards)
    local list = {}
    for _, p in ipairs(players) do
        table.insert(list, {
            userId = p.player.UserId, name = p.player.DisplayName,
            cards = (handData(p.hand.cards)), total = handTotal(p.hand.cards),
            bet = p.hand.bet, status = p.status or "",
        })
    end
    broadcast(t, "hands", {
        dealer = { cards = dealerCards, total = handTotal(dealer.cards), hidden = dealerHidden, status = dealer.status or "" },
        players = list,
        turn = turnId,
    })
end

local function runTable(t)
    while true do
        if #seatedPlayers(t) == 0 then
            task.wait(1)
            continue
        end

        -- Betting
        t.pending, t.confirmed = {}, {}
        local deadline = os.clock() + BET_TIME
        broadcast(t, "phase", { phase = "betting", text = "Place your bets!", time = BET_TIME })
        while os.clock() < deadline do
            local everyone = #seatedPlayers(t) > 0
            for _, entry in ipairs(seatedPlayers(t)) do
                if not t.confirmed[entry.player] then
                    everyone = false
                end
            end
            if everyone then
                break
            end
            task.wait(0.25)
        end

        -- Only players who pressed BET play; everyone else sits this round out
        local players = {}
        for _, entry in ipairs(seatedPlayers(t)) do
            local wanted = t.pending[entry.player]
            if not t.confirmed[entry.player] or not wanted then
                remote:FireClient(entry.player, "result", { text = "Sitting out - press BET to join the next hand", delta = 0 })
            else
                local bet = math.clamp(wanted, MIN_BET, MAX_BET)
                if chipBalance(entry.player) < bet then
                    bet = math.floor(chipBalance(entry.player))
                end
                if bet >= MIN_BET and Bank.tryDeduct(entry.player, bet) then
                    table.insert(players, { player = entry.player, info = entry.info, hand = { cards = {}, bet = bet } })
                else
                    remote:FireClient(entry.player, "result", { text = "Not enough chips - visit the Cashier", delta = 0 })
                end
            end
        end
        if #players == 0 then
            task.wait(2) -- let the sit-out message show before the next betting round
            continue
        end

        -- Deal
        t.cardParts = {}
        local dealer = { cards = {} }
        local dealerTangent = t.dealerDir:Cross(UP)
        broadcast(t, "phase", { phase = "dealing", text = "Dealing...", time = 0 })
        for round = 1, 2 do
            for _, p in ipairs(players) do
                dealCard(t, p.hand, p.info.spot, p.info.tangent, -p.info.out, true)
                updateLabel(p.info.label, p.player.DisplayName, p.hand.cards, "Bet " .. p.hand.bet)
                p.status = isBlackjack(p.hand.cards) and "BLACKJACK!" or ""
                sendHands(t, players, dealer)
            end
            dealCard(t, dealer, t.dealerSpot, dealerTangent, -t.dealerDir, round == 1)
            updateLabel(t.dealerLabel, "Dealer", dealer.cards)
            sendHands(t, players, dealer)
        end
        local dealerHasBlackjack = handTotal({ dealer.cards[1], { rank = dealer.cards[2].rank } }) == 21

        -- Player turns
        if not dealerHasBlackjack then
            for _, p in ipairs(players) do
                if stillSeated(t, p.player) and not isBlackjack(p.hand.cards) then
                    broadcast(t, "turn", {
                        kind = "player", userId = p.player.UserId, name = p.player.DisplayName,
                        focus = p.info.spot, seatPos = p.info.seat.Position, time = TURN_TIME,
                    })
                    sendHands(t, players, dealer, p.player.UserId)
                    while true do
                        t.awaiting, t.action = p.player, nil
                        local turnEnd = os.clock() + TURN_TIME
                        remote:FireClient(p.player, "yourTurn", { total = handTotal(p.hand.cards), canDouble = #p.hand.cards == 2 and chipBalance(p.player) >= p.hand.bet, time = TURN_TIME })
                        while os.clock() < turnEnd and t.action == nil and stillSeated(t, p.player) do
                            task.wait(0.1)
                        end
                        local action = t.action or "stand"
                        t.awaiting = nil
                        if action == "hit" then
                            dealCard(t, p.hand, p.info.spot, p.info.tangent, -p.info.out, true)
                            local total = handTotal(p.hand.cards)
                            updateLabel(p.info.label, p.player.DisplayName, p.hand.cards, total > 21 and "BUST" or ("Bet " .. p.hand.bet))
                            p.status = total > 21 and "BUST" or ""
                            sendHands(t, players, dealer, p.player.UserId)
                            if total >= 21 then
                                break
                            end
                        elseif action == "double" and #p.hand.cards == 2 and Bank.tryDeduct(p.player, p.hand.bet) then
                            p.hand.bet *= 2
                            dealCard(t, p.hand, p.info.spot, p.info.tangent, -p.info.out, true)
                            updateLabel(p.info.label, p.player.DisplayName, p.hand.cards, "Bet " .. p.hand.bet)
                            p.status = handTotal(p.hand.cards) > 21 and "BUST" or "DOUBLED"
                            sendHands(t, players, dealer, p.player.UserId)
                            break
                        else
                            break
                        end
                    end
                    remote:FireClient(p.player, "turnOver", {})
                end
            end
        end

        -- Dealer's turn: takes its time like a real dealer
        broadcast(t, "turn", { kind = "dealer", name = "Dealer", focus = t.dealerSpot, eye = t.dealerEye, look = t.dealerLook, time = 0 })
        task.wait(DEALER_REVEAL_DELAY)
        local hole = dealer.cards[2]
        hole.hidden = false
        setCardFace(hole.part, hole, true)
        updateLabel(t.dealerLabel, "Dealer", dealer.cards)
        sendHands(t, players, dealer)
        local anyoneLeft = false
        for _, p in ipairs(players) do
            if handTotal(p.hand.cards) <= 21 and not isBlackjack(p.hand.cards) then
                anyoneLeft = true
            end
        end
        while anyoneLeft and handTotal(dealer.cards) < 17 do
            updateLabel(t.dealerLabel, "Dealer", dealer.cards, "thinking...")
            dealer.status = "thinking..."
            sendHands(t, players, dealer)
            task.wait(DEALER_DRAW_DELAY)
            dealCard(t, dealer, t.dealerSpot, dealerTangent, -t.dealerDir, true)
            updateLabel(t.dealerLabel, "Dealer", dealer.cards)
            dealer.status = ""
            sendHands(t, players, dealer)
        end
        task.wait(1.2)
        local dealerTotal = handTotal(dealer.cards)
        updateLabel(t.dealerLabel, "Dealer", dealer.cards, dealerTotal > 21 and "BUST" or "STANDS")
        dealer.status = dealerTotal > 21 and "BUST" or "STANDS"

        -- Pay out
        for _, p in ipairs(players) do
            local total = handTotal(p.hand.cards)
            local bet = p.hand.bet
            local payout, text = 0, ""
            if total > 21 then
                text = "BUST  -" .. bet
            elseif isBlackjack(p.hand.cards) and not isBlackjack(dealer.cards) then
                payout = math.floor(bet * 2.5)
                text = "BLACKJACK!  +" .. (payout - bet)
            elseif isBlackjack(dealer.cards) and not isBlackjack(p.hand.cards) then
                text = "DEALER BLACKJACK  -" .. bet
            elseif dealerTotal > 21 or total > dealerTotal then
                payout = bet * 2
                text = "YOU WIN!  +" .. bet
            elseif total == dealerTotal then
                payout = bet
                text = "PUSH - bet returned"
            else
                text = "DEALER WINS  -" .. bet
            end
            if payout > 0 and p.player.Parent then
                Bank.add(p.player, payout)
            end
            updateLabel(p.info.label, p.player.DisplayName, p.hand.cards, text)
            p.status = text
            if p.player.Parent then
                remote:FireClient(p.player, "result", { text = text, delta = payout - bet })
            end
        end
        sendHands(t, players, dealer)

        task.wait(4.5)
        broadcast(t, "roundEnd", {})
        for _, part in ipairs(t.cardParts) do
            part:Destroy()
        end
        for _, info in ipairs(t.seats) do
            info.label.Text = ""
        end
        t.dealerLabel.Text = ""
        task.wait(1)
    end
end

remote.OnServerEvent:Connect(function(player, kind, value)
    local t = tableOf(player)
    if not t then
        return
    end
    if kind == "bet" and typeof(value) == "number" and value == value then
        t.pending[player] = math.clamp(math.floor(value), MIN_BET, MAX_BET)
        t.confirmed[player] = true
    elseif kind == "action" and t.awaiting == player and (value == "hit" or value == "stand" or value == "double") then
        t.action = value
    end
end)

for _, t in ipairs(tables) do
    task.spawn(runTable, t)
end
