-- BLACKJACK TUTORIAL + "YOU" ARROW (LocalScript in StarterPlayer > StarterPlayerScripts)
-- James's tutorial for the v3 seat-based blackjack (BlackjackV3 + BlackjackHUD).
-- Casino changes from the original: SPLIT taken out (the table doesn't do
-- splits), and line breaks built with NL (the Studio bridge mangles backslash-n).
-- Since BlackjackHUD v3 (which has its own How to Play guide on H), this script
-- only draws the YOU arrow and the gold ring; its guide window is switched off.
-- Settings:
local SHOW_TUTORIAL_WINDOW = false -- true brings back this script's own guide + button
local AUTO_OPEN = SHOW_TUTORIAL_WINDOW -- open the tutorial the first time you sit at a blackjack table
local NEAR_DISTANCE = 8         -- how close you need to be to a table for the arrow and button
local ARROW_COLOR = Color3.fromRGB(255, 210, 80)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local V = Vector3.new
local NL = string.char(10)

----------------------------------------------------------------
-- Find the blackjack tables
----------------------------------------------------------------
local tables = {}
local known = {}
local function addTable(m)
    if known[m] or not m:IsA("Model") then
        return
    end
    local name = string.lower(m.Name)
    if string.find(name, "blackjack") and not string.find(name, "_chairs") then
        local ok, cf, size = pcall(function()
            return m:GetBoundingBox()
        end)
        if ok and size.Magnitude > 0 then
            known[m] = true
            table.insert(tables, { model = m, cf = cf, size = size })
        end
    end
end
-- Scan once, then pick up tables that stream in later. (Rescanning the whole
-- place every 10s cost ~25ms - a visible hitch - with ~100k instances.)
for _, m in ipairs(workspace:GetDescendants()) do
    addTable(m)
end
workspace.DescendantAdded:Connect(function(m)
    if m:IsA("Model") then
        task.delay(1, addTable, m) -- give its parts a moment to arrive
    end
end)

-- The casino tables' bounding boxes lie on their side (local X points down),
-- so measure along whichever two box axes are actually horizontal.
local function horizontalGap(t, position)
    local lp = t.cf:PointToObjectSpace(position)
    local axes = {
        { math.abs(t.cf.RightVector.Y), lp.X, t.size.X },
        { math.abs(t.cf.UpVector.Y), lp.Y, t.size.Y },
        { math.abs(t.cf.LookVector.Y), lp.Z, t.size.Z },
    }
    table.sort(axes, function(a, b)
        return a[1] < b[1]
    end)
    local da = math.max(0, math.abs(axes[1][2]) - axes[1][3] / 2)
    local db = math.max(0, math.abs(axes[2][2]) - axes[2][3] / 2)
    return math.sqrt(da * da + db * db)
end

local function nearestTable(position)
    local best, bestDistance = nil, math.huge
    for _, t in ipairs(tables) do
        if t.model.Parent then
            local distance = horizontalGap(t, position)
            if distance < bestDistance then
                best, bestDistance = t, distance
            end
        end
    end
    return best, bestDistance
end

----------------------------------------------------------------
-- The "YOU" arrow and the betting spot ring (only you can see them)
----------------------------------------------------------------
local localFolder = Instance.new("Folder")
localFolder.Name = "MyBlackjackMarkers"
localFolder.Parent = workspace

local function newPart(size, shape)
    local p = Instance.new("Part")
    p.Anchored = true
    p.CanCollide = false
    p.CanQuery = false
    p.CanTouch = false
    p.CastShadow = false
    p.Material = Enum.Material.Neon
    p.Color = ARROW_COLOR
    p.Size = size
    if shape then
        p.Shape = shape
    end
    p.Parent = localFolder
    return p
end

local shaft = newPart(V(0.4, 1.6, 0.4))
local headLeft = newPart(V(0.4, 1.3, 0.4))
local headRight = newPart(V(0.4, 1.3, 0.4))
local arrowParts = { shaft, headLeft, headRight }

local billboard = Instance.new("BillboardGui")
billboard.Size = UDim2.fromOffset(160, 56)
billboard.StudsOffset = V(0, 1.6, 0)
billboard.AlwaysOnTop = true
billboard.Adornee = shaft
billboard.Parent = shaft
local youLabel = Instance.new("TextLabel")
youLabel.Size = UDim2.fromScale(1, 0.62)
youLabel.BackgroundTransparency = 1
youLabel.Text = "YOU"
youLabel.TextScaled = true
youLabel.Font = Enum.Font.GothamBlack
youLabel.TextColor3 = ARROW_COLOR
youLabel.Parent = billboard
local youStroke = Instance.new("UIStroke")
youStroke.Thickness = 2
youStroke.Color = Color3.fromRGB(60, 30, 0)
youStroke.Parent = youLabel
local hintLabel = Instance.new("TextLabel")
hintLabel.Position = UDim2.fromScale(0, 0.62)
hintLabel.Size = UDim2.fromScale(1, 0.38)
hintLabel.BackgroundTransparency = 1
hintLabel.Text = "Sit down to play"
hintLabel.TextScaled = true
hintLabel.Font = Enum.Font.GothamBold
hintLabel.TextColor3 = Color3.new(1, 1, 1)
hintLabel.Parent = billboard
local hintStroke = Instance.new("UIStroke")
hintStroke.Thickness = 1.5
hintStroke.Parent = hintLabel

local ring = newPart(V(0.05, 3.2, 3.2), Enum.PartType.Cylinder)
local ringInner = newPart(V(0.06, 2.4, 2.4), Enum.PartType.Cylinder)
ringInner.Color = Color3.fromRGB(20, 60, 30)
ringInner.Material = Enum.Material.SmoothPlastic

local function setVisible(parts, visible)
    for _, p in ipairs(parts) do
        p.Transparency = visible and 0 or 1
    end
end
setVisible(arrowParts, false)
setVisible({ ring, ringInner }, false)
billboard.Enabled = false

----------------------------------------------------------------
-- Tutorial window
----------------------------------------------------------------
local GOLD = Color3.fromRGB(212, 175, 55)
local gui = Instance.new("ScreenGui")
gui.Name = "BlackjackTutorial"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local function corner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(radius or 0.04, 0)
    c.Parent = parent
end
local function stroke(parent, color, thickness)
    local s = Instance.new("UIStroke")
    s.Color = color or GOLD
    s.Thickness = thickness or 2
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = parent
    return s
end
local function textLabel(parent, text, pos, size, color, font)
    local l = Instance.new("TextLabel")
    l.Position = pos
    l.Size = size
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextScaled = true
    l.RichText = true
    l.TextWrapped = true
    l.Font = font or Enum.Font.Gotham
    l.TextColor3 = color or Color3.new(1, 1, 1)
    l.Parent = parent
    return l
end
local function button(parent, text, pos, size, bg)
    local b = Instance.new("TextButton")
    b.Position = pos
    b.Size = size
    b.BackgroundColor3 = bg or Color3.fromRGB(40, 30, 50)
    b.Text = text
    b.TextScaled = true
    b.Font = Enum.Font.GothamBold
    b.TextColor3 = Color3.new(1, 1, 1)
    b.AutoButtonColor = true
    b.Parent = parent
    corner(b, 0.25)
    stroke(b, GOLD, 1.5)
    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0.18, 0)
    pad.PaddingBottom = UDim.new(0.18, 0)
    pad.Parent = b
    return b
end

-- "? HOW TO PLAY" button in the corner
local helpButton = button(gui, "?  HOW TO PLAY", UDim2.new(1, -16, 1, -16), UDim2.fromOffset(190, 48), Color3.fromRGB(120, 20, 30))
helpButton.AnchorPoint = Vector2.new(1, 1)
helpButton.Visible = false

-- Main window
local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromScale(0.62, 0.72)
panel.BackgroundColor3 = Color3.fromRGB(16, 12, 20)
panel.Visible = false
panel.Parent = gui
corner(panel, 0.03)
stroke(panel, GOLD, 3)
local limit = Instance.new("UISizeConstraint")
limit.MaxSize = Vector2.new(780, 560)
limit.MinSize = Vector2.new(320, 300)
limit.Parent = panel
local feltStripe = Instance.new("Frame")
feltStripe.Size = UDim2.fromScale(1, 0.16)
feltStripe.BackgroundColor3 = Color3.fromRGB(20, 95, 45)
feltStripe.BorderSizePixel = 0
feltStripe.Parent = panel
corner(feltStripe, 0.2)

textLabel(panel, "HOW TO PLAY  <font color='#FFD36B'>BLACKJACK</font>", UDim2.fromScale(0.05, 0.025), UDim2.fromScale(0.8, 0.11), Color3.new(1, 1, 1), Enum.Font.GothamBlack)
local closeButton = button(panel, "X", UDim2.fromScale(0.9, 0.03), UDim2.fromScale(0.07, 0.1), Color3.fromRGB(120, 20, 30))

local pageTitle = textLabel(panel, "", UDim2.fromScale(0.05, 0.19), UDim2.fromScale(0.9, 0.08), Color3.fromRGB(255, 215, 110), Enum.Font.GothamBlack)
local cardRow = Instance.new("Frame")
cardRow.Position = UDim2.fromScale(0.05, 0.29)
cardRow.Size = UDim2.fromScale(0.9, 0.22)
cardRow.BackgroundTransparency = 1
cardRow.Parent = panel
local cardLayout = Instance.new("UIListLayout")
cardLayout.FillDirection = Enum.FillDirection.Horizontal
cardLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
cardLayout.VerticalAlignment = Enum.VerticalAlignment.Center
cardLayout.Padding = UDim.new(0.015, 0)
cardLayout.Parent = cardRow
local body = textLabel(panel, "", UDim2.fromScale(0.06, 0.53), UDim2.fromScale(0.88, 0.3), Color3.fromRGB(235, 235, 235))
body.TextXAlignment = Enum.TextXAlignment.Left
body.TextYAlignment = Enum.TextYAlignment.Top

local backButton = button(panel, "BACK", UDim2.fromScale(0.05, 0.86), UDim2.fromScale(0.22, 0.1))
local nextButton = button(panel, "NEXT", UDim2.fromScale(0.73, 0.86), UDim2.fromScale(0.22, 0.1), Color3.fromRGB(20, 95, 45))
local dots = Instance.new("Frame")
dots.Position = UDim2.fromScale(0.3, 0.88)
dots.Size = UDim2.fromScale(0.4, 0.06)
dots.BackgroundTransparency = 1
dots.Parent = panel
local dotLayout = Instance.new("UIListLayout")
dotLayout.FillDirection = Enum.FillDirection.Horizontal
dotLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
dotLayout.VerticalAlignment = Enum.VerticalAlignment.Center
dotLayout.Padding = UDim.new(0.03, 0)
dotLayout.Parent = dots

-- A drawn playing card (rank only, red or black)
local function makeCard(rank, red, faceDown)
    local card = Instance.new("Frame")
    card.Size = UDim2.fromScale(0.13, 1)
    card.BackgroundColor3 = faceDown and Color3.fromRGB(150, 20, 30) or Color3.fromRGB(250, 250, 245)
    card.Parent = cardRow
    corner(card, 0.12)
    stroke(card, faceDown and GOLD or Color3.fromRGB(180, 180, 180), 2)
    local ratio = Instance.new("UIAspectRatioConstraint")
    ratio.AspectRatio = 0.7
    ratio.Parent = card
    if faceDown then
        local inner = Instance.new("Frame")
        inner.AnchorPoint = Vector2.new(0.5, 0.5)
        inner.Position = UDim2.fromScale(0.5, 0.5)
        inner.Size = UDim2.fromScale(0.7, 0.8)
        inner.BackgroundTransparency = 1
        inner.Parent = card
        stroke(inner, GOLD, 2)
        corner(inner, 0.1)
    else
        local color = red and Color3.fromRGB(200, 25, 30) or Color3.fromRGB(20, 20, 20)
        local small = textLabel(card, rank, UDim2.fromScale(0.06, 0.03), UDim2.fromScale(0.4, 0.25), color, Enum.Font.GothamBlack)
        small.TextXAlignment = Enum.TextXAlignment.Left
        textLabel(card, rank, UDim2.fromScale(0.1, 0.28), UDim2.fromScale(0.8, 0.5), color, Enum.Font.GothamBlack)
    end
    return card
end
local function makeSymbol(text, color)
    local l = textLabel(cardRow, text, UDim2.new(), UDim2.fromScale(0.08, 0.6), color or Color3.fromRGB(255, 215, 110), Enum.Font.GothamBlack)
    return l
end

local Y = "<font color='#FFD36B'><b>"
local E = "</b></font>"
local PAGES = {
    {
        title = "THE GOAL",
        cards = { { "K", false }, { "A", true }, "=", "21!" },
        text = "Get a hand that is " .. Y .. "closer to 21" .. E .. " than the dealer's hand, " .. Y .. "without going over 21" .. E .. "." .. NL
            .. "Going over 21 is called a " .. Y .. "BUST" .. E .. " and you lose that hand.",
    },
    {
        title = "CARD VALUES",
        cards = { { "7", true }, "= 7", { "K", false }, "= 10", { "A", true }, "= 1 or 11" },
        text = Y .. "2 to 10" .. E .. " are worth their number." .. NL
            .. Y .. "J, Q and K" .. E .. " are each worth 10." .. NL
            .. "An " .. Y .. "Ace" .. E .. " is worth 11, or 1 if 11 would make you bust.",
    },
    {
        title = "YOUR CHOICES",
        cards = { { "9", false }, { "5", true }, "= 14", "?" },
        text = Y .. "HIT" .. E .. " - take another card." .. NL
            .. Y .. "STAND" .. E .. " - keep your total and end your turn." .. NL
            .. Y .. "DOUBLE" .. E .. " - double your bet and get exactly one more card.",
    },
    {
        title = "THE DEALER",
        cards = { { "10", true }, { "", false, true }, "→", { "10", true }, { "7", false }, "= 17" },
        text = "The dealer has one card " .. Y .. "face down" .. E .. ". After every player finishes, the dealer flips it over." .. NL
            .. "The dealer " .. Y .. "must hit until 17 or more" .. E .. ". If the dealer busts, everyone still in wins!",
    },
    {
        title = "HOW YOU WIN",
        cards = { { "A", false }, { "Q", true }, "= BLACKJACK" },
        text = Y .. "Beat the dealer" .. E .. ": you win the same as your bet (1 to 1)." .. NL
            .. Y .. "Blackjack" .. E .. " (an Ace + a 10-value card as your first two cards): pays 3 to 2." .. NL
            .. Y .. "Tie" .. E .. " (a 'push'): you get your bet back.   " .. Y .. "Bust" .. E .. ": you lose your bet.",
    },
    {
        title = "BEGINNER TIPS",
        cards = { { "6", false }, { "5", true }, "= 11", "→", "DOUBLE!" },
        text = "• " .. Y .. "Stand" .. E .. " on 17 or more.   • " .. Y .. "Hit" .. E .. " on 11 or less." .. NL
            .. "• " .. Y .. "Double" .. E .. " when you have 11." .. NL
            .. "• Dealer showing 7 or higher? Keep hitting until you reach 17." .. NL
            .. "• Look for the " .. Y .. "gold ring" .. E .. " on the table - that's your spot!",
    },
}

local page = 1
local dotFrames = {}
for i = 1, #PAGES do
    local d = Instance.new("Frame")
    d.Size = UDim2.fromScale(0.06, 0.6)
    d.BackgroundColor3 = Color3.fromRGB(90, 80, 100)
    d.Parent = dots
    corner(d, 1)
    local ratio = Instance.new("UIAspectRatioConstraint")
    ratio.AspectRatio = 1
    ratio.Parent = d
    dotFrames[i] = d
end

local function showPage(i)
    page = math.clamp(i, 1, #PAGES)
    local data = PAGES[page]
    pageTitle.Text = page .. ".  " .. data.title
    body.Text = data.text
    for _, child in ipairs(cardRow:GetChildren()) do
        if not child:IsA("UIListLayout") then
            child:Destroy()
        end
    end
    for _, item in ipairs(data.cards) do
        if typeof(item) == "table" then
            makeCard(item[1], item[2], item[3])
        else
            makeSymbol(item)
        end
    end
    for k, d in ipairs(dotFrames) do
        d.BackgroundColor3 = k == page and GOLD or Color3.fromRGB(90, 80, 100)
    end
    backButton.Visible = page > 1
    nextButton.Text = page == #PAGES and "GOT IT!" or "NEXT"
end

local function openTutorial()
    showPage(1)
    panel.Visible = true
    panel.Size = UDim2.fromScale(0.5, 0.58)
    TweenService:Create(panel, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Size = UDim2.fromScale(0.62, 0.72) }):Play()
end
local function closeTutorial()
    panel.Visible = false
end

backButton.MouseButton1Click:Connect(function()
    showPage(page - 1)
end)
nextButton.MouseButton1Click:Connect(function()
    if page == #PAGES then
        closeTutorial()
    else
        showPage(page + 1)
    end
end)
closeButton.MouseButton1Click:Connect(closeTutorial)
helpButton.MouseButton1Click:Connect(function()
    if panel.Visible then
        closeTutorial()
    else
        openTutorial()
    end
end)
UserInputService.InputBegan:Connect(function(input, typing)
    if not typing and input.KeyCode == Enum.KeyCode.H and helpButton.Visible then
        if panel.Visible then
            closeTutorial()
        else
            openTutorial()
        end
    end
end)

----------------------------------------------------------------
-- Every frame: show the arrow, ring and button when you're at a table
----------------------------------------------------------------
local shownThisSession = false
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

RunService.RenderStepped:Connect(function()
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local head = character and character:FindFirstChild("Head")
    if not (humanoid and root and head) then
        setVisible(arrowParts, false)
        setVisible({ ring, ringInner }, false)
        billboard.Enabled = false
        helpButton.Visible = false
        return
    end

    local t = os.clock()
    local seat = humanoid.SeatPart
    local nearby, distance = nearestTable(root.Position)
    local seated = seat ~= nil and nearby ~= nil and distance <= 5
    local close = nearby ~= nil and distance <= NEAR_DISTANCE

    helpButton.Visible = SHOW_TUTORIAL_WINDOW and (close or seated)
    if not (close or seated) and panel.Visible then
        closeTutorial()
    end

    -- Arrow over your head
    if close or seated then
        setVisible(arrowParts, true)
        billboard.Enabled = true
        hintLabel.Visible = not seated
        local top = head.Position + V(0, 3.2 + math.sin(t * 3) * 0.35, 0)
        local spin = CFrame.Angles(0, t * 2, 0)
        shaft.CFrame = CFrame.new(top + V(0, 0.8, 0)) * spin
        headLeft.CFrame = CFrame.new(top) * spin * CFrame.new(-0.35, -0.15, 0) * CFrame.Angles(0, 0, math.rad(40))
        headRight.CFrame = CFrame.new(top) * spin * CFrame.new(0.35, -0.15, 0) * CFrame.Angles(0, 0, math.rad(-40))
    else
        setVisible(arrowParts, false)
        billboard.Enabled = false
    end

    -- Gold ring on the felt in front of your seat
    if seated then
        local center = nearby.cf.Position
        local toTable = V(center.X - seat.Position.X, 0, center.Z - seat.Position.Z)
        local spotXZ = seat.Position + toTable * 0.45
        rayParams.FilterDescendantsInstances = { character, localFolder }
        local hit = workspace:Raycast(V(spotXZ.X, seat.Position.Y + 8, spotXZ.Z), V(0, -15, 0), rayParams)
        if hit then
            local pulse = 0.25 + 0.25 * (0.5 + 0.5 * math.sin(t * 4))
            local cf = CFrame.new(hit.Position + V(0, 0.03, 0)) * CFrame.Angles(0, 0, math.rad(90))
            ring.CFrame = cf
            ringInner.CFrame = cf * CFrame.new(0.005, 0, 0)
            ring.Transparency = pulse
            ringInner.Transparency = 0.2
        end

        if AUTO_OPEN and not shownThisSession then
            shownThisSession = true
            openTutorial()
        end
    else
        setVisible({ ring, ringInner }, false)
    end
end)
