-- BLACKJACK SOLO / MULTIPLAYER MENU (LocalScript in StarterPlayer > StarterPlayerScripts)
-- Needs a server script that makes ReplicatedStorage.BlackjackLobbyRemote and the BlackjackLobbyPrompt buttons.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local remote = ReplicatedStorage:WaitForChild("BlackjackLobbyRemote")

local BG = Color3.fromRGB(16, 16, 20)
local CARD = Color3.fromRGB(28, 26, 32)
local GOLD = Color3.fromRGB(201, 168, 92)
local TEXT = Color3.fromRGB(235, 235, 235)
local MUTED = Color3.fromRGB(150, 150, 158)

local function new(class, props, parent)
    local o = Instance.new(class)
    for k, v in pairs(props) do
        o[k] = v
    end
    o.Parent = parent
    return o
end
local function rounded(o, px)
    new("UICorner", { CornerRadius = UDim.new(0, px or 8) }, o)
end
local function stroke(o, color, transparency, thickness)
    return new("UIStroke", {
        Color = color or GOLD, Transparency = transparency or 0.55, Thickness = thickness or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, o)
end
local function label(props, parent)
    props.BackgroundTransparency = 1
    props.Font = props.Font or Enum.Font.GothamMedium
    props.TextColor3 = props.TextColor3 or TEXT
    props.TextSize = props.TextSize or 16
    return new("TextLabel", props, parent)
end
local function button(text, color, textColor, size, parent)
    local b = new("TextButton", {
        Size = size, BackgroundColor3 = color, BorderSizePixel = 0, AutoButtonColor = true,
        Text = text, Font = Enum.Font.GothamBold, TextSize = 15, TextColor3 = textColor or TEXT,
    }, parent)
    rounded(b, 8)
    return b
end

----------------------------------------------------------------
-- Menu window
----------------------------------------------------------------
local gui = new("ScreenGui", { Name = "BlackjackLobby", ResetOnSpawn = false, DisplayOrder = 20, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, player:WaitForChild("PlayerGui"))
local scale = new("UIScale", {}, gui)
local function rescale()
    scale.Scale = math.clamp(math.min(camera.ViewportSize.Y / 900, camera.ViewportSize.X / 1300), 0.7, 1.1)
end
rescale()
camera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)

local backdrop = new("TextButton", {
    Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45,
    BorderSizePixel = 0, Text = "", AutoButtonColor = false, Visible = false,
}, gui)
local modal = new("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(460, 350),
    BackgroundColor3 = BG, BorderSizePixel = 0,
}, backdrop)
rounded(modal, 12)
stroke(modal)

label({ Position = UDim2.fromOffset(28, 22), Size = UDim2.new(1, -56, 0, 16), Text = "BLACKJACK", Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Left }, modal)
label({ Position = UDim2.fromOffset(28, 42), Size = UDim2.new(1, -56, 0, 30), Text = "How do you want to play?", Font = Enum.Font.GothamBold, TextSize = 22, TextXAlignment = Enum.TextXAlignment.Left }, modal)
local closeButton = new("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 12), Size = UDim2.fromOffset(30, 30), BackgroundTransparency = 1, Text = "×", Font = Enum.Font.GothamMedium, TextSize = 24, TextColor3 = MUTED }, modal)

-- Solo / Multiplayer choices
local function option(x, title, desc)
    local b = new("TextButton", {
        Position = UDim2.fromOffset(x, 90), Size = UDim2.fromOffset(194, 112),
        BackgroundColor3 = CARD, BorderSizePixel = 0, Text = "", AutoButtonColor = true,
    }, modal)
    rounded(b, 10)
    local s = stroke(b, GOLD, 0.8, 1)
    label({ Position = UDim2.fromOffset(16, 16), Size = UDim2.new(1, -32, 0, 24), Text = title, Font = Enum.Font.GothamBold, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Left }, b)
    label({ Position = UDim2.fromOffset(16, 46), Size = UDim2.new(1, -32, 0, 54), Text = desc, TextSize = 13, TextColor3 = MUTED, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top }, b)
    return b, s
end
local soloButton, soloStroke = option(28, "Solo", "Just you and the dealer. One chair, nobody else can join.")
local multiButton, multiStroke = option(238, "Multiplayer", "Open seats so other players can join your table.")

-- Player count (multiplayer only)
local countRow = new("Frame", { Position = UDim2.fromOffset(28, 218), Size = UDim2.new(1, -56, 0, 40), BackgroundTransparency = 1, Visible = false }, modal)
label({ Size = UDim2.new(0.5, 0, 1, 0), Text = "Number of players", TextSize = 15, TextColor3 = MUTED, TextXAlignment = Enum.TextXAlignment.Left }, countRow)
local minus = button("–", CARD, TEXT, UDim2.fromOffset(40, 36), countRow)
minus.AnchorPoint = Vector2.new(1, 0.5)
minus.Position = UDim2.new(1, -96, 0.5, 0)
stroke(minus, GOLD, 0.7)
local countLabel = label({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -48, 0.5, 0), Size = UDim2.fromOffset(44, 36), Text = "4", Font = Enum.Font.GothamBold, TextSize = 22, TextColor3 = GOLD }, countRow)
local plus = button("+", CARD, TEXT, UDim2.fromOffset(40, 36), countRow)
plus.AnchorPoint = Vector2.new(1, 0.5)
plus.Position = UDim2.new(1, 0, 0.5, 0)
stroke(plus, GOLD, 0.7)

local startButton = button("Start", GOLD, Color3.fromRGB(24, 18, 8), UDim2.fromOffset(180, 44), modal)
startButton.AnchorPoint = Vector2.new(0.5, 1)
startButton.Position = UDim2.new(0.5, 0, 1, -24)
startButton.TextSize = 16

-- Small message (like "This table is full")
local notice = new("Frame", {
    AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 60), Size = UDim2.fromOffset(320, 34),
    BackgroundColor3 = BG, BackgroundTransparency = 0.15, BorderSizePixel = 0, Visible = false,
}, gui)
rounded(notice, 10)
stroke(notice)
local noticeText = label({ Size = UDim2.fromScale(1, 1), Font = Enum.Font.GothamBold, TextSize = 15, TextColor3 = GOLD }, notice)

----------------------------------------------------------------
-- Menu logic
----------------------------------------------------------------
local mode, count, maxSeats, tableId = "solo", 4, 8, nil
local function refresh()
    soloStroke.Transparency = mode == "solo" and 0 or 0.8
    soloStroke.Thickness = mode == "solo" and 2 or 1
    multiStroke.Transparency = mode == "multi" and 0 or 0.8
    multiStroke.Thickness = mode == "multi" and 2 or 1
    countRow.Visible = mode == "multi"
    countLabel.Text = tostring(count)
    startButton.Text = mode == "solo" and "Start Solo" or ("Start  ·  " .. count .. " players")
end
local function closeMenu()
    backdrop.Visible = false
end
soloButton.MouseButton1Click:Connect(function()
    mode = "solo"
    refresh()
end)
multiButton.MouseButton1Click:Connect(function()
    mode = "multi"
    refresh()
end)
minus.MouseButton1Click:Connect(function()
    count = math.max(2, count - 1)
    refresh()
end)
plus.MouseButton1Click:Connect(function()
    count = math.min(maxSeats, count + 1)
    refresh()
end)
closeButton.MouseButton1Click:Connect(closeMenu)
startButton.MouseButton1Click:Connect(function()
    if tableId then
        remote:FireServer("choose", tableId, mode == "solo" and 1 or count)
    end
    closeMenu()
end)

local noticeId = 0
remote.OnClientEvent:Connect(function(kind, data)
    if kind == "openMenu" then
        tableId = data.tableId
        maxSeats = data.maxSeats or 8
        count = math.clamp(count, 2, maxSeats)
        refresh()
        backdrop.Visible = true
        modal.Size = UDim2.fromOffset(420, 320)
        TweenService:Create(modal, TweenInfo.new(0.2, Enum.EasingStyle.Quad), { Size = UDim2.fromOffset(460, 350) }):Play()
    elseif kind == "message" then
        noticeId += 1
        local id = noticeId
        noticeText.Text = data.text
        notice.Visible = true
        task.delay(3, function()
            if id == noticeId then
                notice.Visible = false
            end
        end)
    end
end)

-- Hide the table buttons while you're sitting, and close the menu if you sit down
-- (the prompts are tracked as they appear - looping the whole workspace every frame lags the casino)
local lobbyPrompts = {}
local function trackPrompt(d)
    if d:IsA("ProximityPrompt") and d.Name == "BlackjackLobbyPrompt" then
        lobbyPrompts[d] = true
        d.AncestryChanged:Connect(function()
            if not d:IsDescendantOf(workspace) then
                lobbyPrompts[d] = nil
            end
        end)
    end
end
for _, d in ipairs(workspace:GetDescendants()) do
    trackPrompt(d)
end
workspace.DescendantAdded:Connect(trackPrompt)

-- Only turn back on the prompts this script hid (the server may have switched some off itself)
local hiddenByUs = {}
RunService.Heartbeat:Connect(function()
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local seated = humanoid ~= nil and humanoid.SeatPart ~= nil
    if seated then
        for prompt in pairs(lobbyPrompts) do
            if prompt.Enabled then
                prompt.Enabled = false
                hiddenByUs[prompt] = true
            end
        end
    elseif next(hiddenByUs) then
        for prompt in pairs(hiddenByUs) do
            prompt.Enabled = true
        end
        table.clear(hiddenByUs)
    end
    if seated and backdrop.Visible then
        closeMenu()
    end
end)
refresh()
