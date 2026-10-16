-- JACKPOT DISPLAY (LocalScript in StarterPlayer > StarterPlayerScripts)
--
-- Animates the MEGA JACKPOT board built by LuxuryJackpot: the counting
-- jackpot, the MAJOR / MINOR / MINI amounts, the scrolling ticker, the shine
-- on the header and the chasing bulbs. Same speeds as James's script.
--
-- Amounts come from workspace.DistributedGameTime, the server's game clock,
-- so every player sees the same jackpot and it resets when a server starts.
-- Nothing here is sent over the network.

local RunService = game:GetService("RunService")

local JACKPOT_PER_SECOND = 61.7  -- James's script added 0.5-18 every 0.15 s
local SMALL_PER_SECOND = 1.29    -- and 0.05-1.5 to the small ones every 0.6 s
local BULB_ON = Color3.fromRGB(255, 230, 160)
local BULB_OFF = Color3.fromRGB(110, 95, 60)

local casino = workspace:WaitForChild("Casino", 60)
local model = casino and casino:WaitForChild("LuxuryJackpot", 60)
if not model then
    return
end
local screen = model:WaitForChild("Screen", 60)
local gui = screen and screen:WaitForChild("Display", 30)
if not gui then
    return
end

local function money(n)
    local whole = tostring(math.floor(n)):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    return "$" .. whole .. string.format(".%02d", math.floor((n % 1) * 100))
end

-- Counter tiles: rebuilt only when the number of characters changes
local counter = gui:WaitForChild("Counter")
local function tiles()
    local list = {}
    for _, t in ipairs(counter:GetChildren()) do
        if t:IsA("TextLabel") then
            table.insert(list, t)
        end
    end
    table.sort(list, function(a, b)
        return a.LayoutOrder < b.LayoutOrder
    end)
    return list
end
local current = tiles()
local function setCounter(text)
    if #current ~= #text then
        for _, t in ipairs(current) do
            t:Destroy()
        end
        local digits = 0
        for i = 1, #text do
            if string.match(string.sub(text, i, i), "%d") then
                digits += 1
            end
        end
        local unit = 1 / (digits + (#text - digits) * 0.45 + #text * 0.01)
        for i = 1, #text do
            local isDigit = string.match(string.sub(text, i, i), "%d") ~= nil
            local tile = Instance.new("TextLabel")
            tile.Name = "Tile"
            tile.Size = UDim2.fromScale(unit * (isDigit and 1 or 0.45), 1)
            tile.BackgroundColor3 = Color3.fromRGB(20, 5, 5)
            tile.BackgroundTransparency = isDigit and 0 or 1
            tile.BorderSizePixel = 0
            tile.TextScaled = true
            tile.Font = Enum.Font.GothamBlack
            tile.TextColor3 = Color3.fromRGB(255, 70, 50)
            tile.LayoutOrder = i
            tile.Parent = counter
            if isDigit then
                local stroke = Instance.new("UIStroke")
                stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
                stroke.Color = Color3.fromRGB(212, 175, 55)
                stroke.Thickness = 2
                stroke.Parent = tile
                local shine = Instance.new("UIGradient")
                shine.Color = ColorSequence.new(Color3.fromRGB(255, 200, 120), Color3.fromRGB(255, 40, 30))
                shine.Rotation = 90
                shine.Parent = tile
            end
        end
        current = tiles()
    end
    for i, tile in ipairs(current) do
        local ch = string.sub(text, i, i)
        if tile.Text ~= ch then
            tile.Text = ch
        end
    end
end

local start = model:GetAttribute("StartJackpot") or 4812900
local smalls = {}
for _, name in ipairs({ "Major", "Minor", "Mini" }) do
    local panel = gui:FindFirstChild(string.upper(name))
    local amount = panel and panel:FindFirstChild("Amount")
    if amount then
        table.insert(smalls, { label = amount, base = model:GetAttribute(name) or 0 })
    end
end
local ticker = gui:WaitForChild("TickerFrame"):WaitForChild("Ticker")
local shine = gui:WaitForChild("Header"):WaitForChild("Shine")

-- Bulbs arrive with streaming, so the list is refreshed now and then
local bulbs = {}
local function refreshBulbs()
    local list = {}
    for _, d in ipairs(model:GetDescendants()) do
        if d.Name == "MarqueeBulb" and d:IsA("BasePart") then
            table.insert(list, { part = d, index = d:GetAttribute("Index") or #list + 1, on = d.Material == Enum.Material.Neon })
        end
    end
    bulbs = list
end
refreshBulbs()

local lastTick, lastRefresh = -1, 0
RunService.RenderStepped:Connect(function()
    if not model.Parent then
        return
    end
    local t = workspace.DistributedGameTime
    -- smooth: ticker scroll and header shine
    ticker.Position = UDim2.fromScale(-((t * 0.0267) % 1), 0)
    shine.Offset = Vector2.new(((t * 0.2) % 2) - 1, 0)

    -- stepped: amounts every 0.15 s, bulbs every 0.3 s, as before
    local tick = math.floor(t / 0.15)
    if tick == lastTick then
        return
    end
    lastTick = tick
    setCounter(money(start + t * JACKPOT_PER_SECOND))
    if tick % 4 == 0 then
        for _, s in ipairs(smalls) do
            s.label.Text = money(s.base + t * SMALL_PER_SECOND)
        end
    end
    local phase = math.floor(tick / 2)
    for _, b in ipairs(bulbs) do
        local on = (b.index + phase) % 3 ~= 0
        if on ~= b.on and b.part.Parent then
            b.on = on
            b.part.Material = on and Enum.Material.Neon or Enum.Material.SmoothPlastic
            b.part.Color = on and BULB_ON or BULB_OFF
        end
    end
    if t - lastRefresh > 5 then
        lastRefresh = t
        refreshBulbs()
    end
end)
