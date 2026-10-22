--[[
    BlackjackTutorial  (LocalScript)
    Place in: StarterPlayer > StarterPlayerScripts

    Works alongside BlackjackClient, listening to the same BlackjackRemote.
    When you sit at a blackjack table:
      * A gold arrow bobs over YOUR side of the felt with a "YOU" tag, and a
        "DEALER" tag sits over the dealer's side, so you always know which
        cards are yours. Only the seated player sees these.
      * A step-by-step "How to Play" tutorial opens the first time you sit
        (once per visit). The "? HOW TO PLAY" button above the blackjack panel
        opens it again at any time.
    Everything goes away when you leave the table.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remote = ReplicatedStorage:WaitForChild("BlackjackRemote")

local NL = string.char(10)

--------------------------------------------------------------------------------
-- Settings
--------------------------------------------------------------------------------
local CFG = {
    ShowTutorialOnFirstSeat = true, -- auto-open the tutorial the first time you sit

    -- Arrow placement, in card widths, measured from the centre of your card row.
    -- Negative = your left, so it never covers your cards (chips sit on your right).
    ArrowSide = -2.9,
    ArrowHeight = 2.4, -- tip of the arrow above the felt, in card lengths
    ArrowSize = 1.5, -- overall arrow scale, in card widths
    BobAmount = 0.35, -- how far it bobs, in card lengths
    BobSpeed = 2.6,

    ArrowColor = Color3.fromRGB(255, 200, 80),
    DealerColor = Color3.fromRGB(245, 95, 95),
}

local THEME = {
    PanelTop = Color3.fromRGB(30, 26, 40),
    PanelBottom = Color3.fromRGB(12, 11, 18),
    PanelLight = Color3.fromRGB(52, 46, 70),
    GoldLight = Color3.fromRGB(255, 232, 160),
    Gold = Color3.fromRGB(255, 200, 80),
    GoldDark = Color3.fromRGB(180, 125, 35),
    Text = Color3.fromRGB(245, 240, 230),
    SubText = Color3.fromRGB(175, 165, 150),
    Win = Color3.fromRGB(95, 235, 135),
    Lose = Color3.fromRGB(245, 95, 95),
    Hit = Color3.fromRGB(40, 150, 80),
    Stand = Color3.fromRGB(190, 50, 55),
    Double = Color3.fromRGB(70, 95, 200),
}

-- Tutorial pages. Lines are joined with NL so no backslash escapes are needed.
local PAGES = {
    {
        Title = "WELCOME TO BLACKJACK",
        Body = {
            "Beat the dealer by getting closer to 21 than they do -",
            "without going over.",
            "",
            "Your cards land on YOUR side of the table, where the",
            "gold arrow is pointing. The dealer's cards go across from you.",
        },
    },
    {
        Title = "CARD VALUES",
        Body = {
            "2 to 10  =  the number on the card",
            "J, Q, K  =  10",
            "Ace  =  1 or 11, whichever helps you more",
            "",
            "Your total floats next to your cards on the table.",
        },
    },
    {
        Title = "1.  PLACE YOUR BET",
        Body = {
            "Pick a chip in the chip bar, then press  +  to add it.",
            "CLEAR takes your bet back off the table.",
            "",
            "Press DEAL (or Space) when you're ready.",
            "You get two cards face up. The dealer gets one up, one hidden.",
        },
    },
    {
        Title = "2.  YOUR TURN",
        Body = {
            "HIT  (H)  -  take another card",
            "STAND  (S)  -  keep what you have",
            "DOUBLE  (D)  -  double your bet, take exactly one more card",
            "                      (only on your first two cards)",
            "",
            "Go over 21 and you BUST - the bet is lost.",
        },
    },
    {
        Title = "3.  THE DEALER PLAYS",
        Body = {
            "When you stand, the dealer flips their hidden card.",
            "The dealer must keep hitting until they reach 17 or more.",
            "",
            "If the dealer busts, you win.",
            "Otherwise, the higher total wins.",
        },
    },
    {
        Title = "PAYOUTS",
        Body = {
            "Win  -  paid 1 to 1  (bet 10, get 20 back)",
            "Blackjack  -  an Ace + a 10-value card as your first two:",
            "                    paid 3 to 2  (bet 10, get 25 back)",
            "Push  -  same total as the dealer, you get your bet back",
            "",
            "Good luck!",
        },
    },
}

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------
local function create(className, props, children)
    local instance = Instance.new(className)
    for key, value in props do
        if key ~= "Parent" then
            instance[key] = value
        end
    end
    for _, child in children or {} do
        child.Parent = instance
    end
    instance.Parent = props.Parent
    return instance
end

local function tween(instance, duration, props, style, direction)
    local t = TweenService:Create(
        instance,
        TweenInfo.new(duration, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out),
        props
    )
    t:Play()
    return t
end

local function arrowPart(size, parent)
    return create("WedgePart", {
        Name = "ArrowHead",
        Size = size,
        Anchored = true,
        CanCollide = false,
        CanQuery = false,
        CanTouch = false,
        CastShadow = false,
        Material = Enum.Material.Neon,
        Color = CFG.ArrowColor,
        Parent = parent,
    })
end

local function plainPart(name, size, parent)
    return create("Part", {
        Name = name,
        Size = size,
        Anchored = true,
        CanCollide = false,
        CanQuery = false,
        CanTouch = false,
        CastShadow = false,
        Material = Enum.Material.Neon,
        Color = CFG.ArrowColor,
        Parent = parent,
    })
end

local function makeTag(parent, text, color, studsOffset)
    local gui = create("BillboardGui", {
        Size = UDim2.fromOffset(110, 34),
        StudsOffsetWorldSpace = studsOffset or Vector3.zero,
        AlwaysOnTop = true,
        LightInfluence = 0,
        MaxDistance = 80,
        Parent = parent,
    })
    create("TextLabel", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = THEME.PanelBottom,
        BackgroundTransparency = 0.15,
        Text = text,
        Font = Enum.Font.GothamBlack,
        TextSize = 18,
        TextColor3 = color,
        Parent = gui,
    }, {
        create("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
        create("UIStroke", { Color = color, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
    })
    return gui
end

--------------------------------------------------------------------------------
-- "Your side" arrow and tags (only for the seated player)
--------------------------------------------------------------------------------
local layouts = {} -- [tableId] = layout from the server
local markers = nil -- { Folder, Parts = { { Part, Rel } }, Base, Lift, Bob }

local function clearMarkers()
    if markers then
        markers.Folder:Destroy()
        markers = nil
    end
end

local function buildMarkers(layout)
    clearMarkers()

    local cardW = layout.CardSize.X
    local cardL = layout.CardSize.Z
    local folder = create("Folder", { Name = "BlackjackYourSide", Parent = workspace })

    -- Row frames: X = the player's right, Y = up, Z = toward the player
    local base = layout.PlayerRow * CFrame.new(CFG.ArrowSide * cardW, 0, 0)

    -- A flat downward arrow facing the player: a shaft plus a triangular head
    -- made of two wedges, all laid out in the row's X/Y plane.
    local w = CFG.ArrowSize * cardW
    local headH = w * 0.75
    local shaftH = w * 0.9
    local thick = math.max(0.06, w * 0.12)
    local half = w / 2

    local parts = {}
    local function add(part, rel)
        table.insert(parts, { Part = part, Rel = rel })
    end

    -- Head (tip at y = 0, top at y = headH). WedgePart's right angle is at its
    -- local -Y/+Z corner, so local Y is pointed down and local +Z at the centre line.
    local right = arrowPart(Vector3.new(thick, headH, half), folder)
    add(right, CFrame.fromMatrix(Vector3.new(half / 2, headH / 2, 0), -Vector3.zAxis, -Vector3.yAxis, -Vector3.xAxis))
    local left = arrowPart(Vector3.new(thick, headH, half), folder)
    add(left, CFrame.fromMatrix(Vector3.new(-half / 2, headH / 2, 0), Vector3.zAxis, -Vector3.yAxis, Vector3.xAxis))

    local shaft = plainPart("ArrowShaft", Vector3.new(w * 0.34, shaftH, thick), folder)
    add(shaft, CFrame.new(0, headH + shaftH / 2 - 0.01, 0))

    -- Soft glowing spot on the felt under the arrow
    local spot = plainPart("FeltSpot", Vector3.new(0.04, cardL * 1.3, cardL * 1.3), folder)
    spot.Shape = Enum.PartType.Cylinder
    spot.Transparency = 0.55
    spot.CFrame = base * CFrame.new(0, 0.03, 0) * CFrame.Angles(0, 0, math.pi / 2)

    create("PointLight", {
        Color = CFG.ArrowColor,
        Brightness = 1.2,
        Range = cardL * 3,
        Parent = shaft,
    })

    -- Tags: "YOU" above the arrow, "DEALER" over the dealer's side
    local youAnchor = create("Attachment", { Parent = workspace.Terrain })
    makeTag(youAnchor, "▼  YOU", CFG.ArrowColor)
    local dealerAnchor = create("Attachment", { Parent = workspace.Terrain })
    dealerAnchor.WorldPosition = (layout.DealerRow * CFrame.new(CFG.ArrowSide * cardW, cardL * 1.6, 0)).Position
    makeTag(dealerAnchor, "DEALER", CFG.DealerColor)

    -- the attachments live on Terrain, so tie their lifetime to the folder
    folder.Destroying:Connect(function()
        youAnchor:Destroy()
        dealerAnchor:Destroy()
    end)

    markers = {
        Folder = folder,
        Parts = parts,
        Base = base,
        Lift = CFG.ArrowHeight * cardL,
        Bob = CFG.BobAmount * cardL,
        TagLift = CFG.ArrowHeight * cardL + headH + shaftH + cardL * 0.5,
        YouAnchor = youAnchor,
        Start = os.clock(),
    }
end

RunService.RenderStepped:Connect(function()
    if not markers then
        return
    end
    local t = os.clock() - markers.Start
    local y = markers.Lift + math.sin(t * CFG.BobSpeed) * markers.Bob
    local top = markers.Base * CFrame.new(0, y, 0)
    for _, item in markers.Parts do
        item.Part.CFrame = top * item.Rel
    end
    markers.YouAnchor.WorldPosition = (markers.Base * CFrame.new(0, markers.TagLift + math.sin(t * CFG.BobSpeed) * markers.Bob, 0)).Position
end)

--------------------------------------------------------------------------------
-- Tutorial panel
--------------------------------------------------------------------------------
local screenGui = create("ScreenGui", {
    Name = "BlackjackTutorialUI",
    ResetOnSpawn = false,
    DisplayOrder = 7, -- just above BlackjackUI
    Enabled = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    Parent = playerGui,
})

local helpButton = create("TextButton", {
    AnchorPoint = Vector2.new(0.5, 1),
    Position = UDim2.new(0.5, 0, 1, -182), -- sits just above the 150px blackjack panel
    Size = UDim2.fromOffset(150, 30),
    BackgroundColor3 = THEME.PanelLight,
    AutoButtonColor = true,
    Text = "?  HOW TO PLAY",
    Font = Enum.Font.GothamBlack,
    TextSize = 13,
    TextColor3 = THEME.Gold,
    Parent = screenGui,
}, {
    create("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
    create("UIStroke", { Color = THEME.Gold, Thickness = 1.2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
})

local panel = create("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.4),
    Size = UDim2.fromOffset(520, 300),
    BackgroundColor3 = Color3.new(1, 1, 1),
    BackgroundTransparency = 0.04,
    Visible = false,
    Parent = screenGui,
}, {
    create("UICorner", { CornerRadius = UDim.new(0, 14) }),
    create("UIGradient", { Color = ColorSequence.new(THEME.PanelTop, THEME.PanelBottom), Rotation = 90 }),
    create("UIStroke", { Color = THEME.Gold, Thickness = 1.6, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
})
local panelScale = create("UIScale", { Parent = panel })

create("TextLabel", {
    Text = "♠ HOW TO PLAY",
    Font = Enum.Font.GothamBold,
    TextSize = 12,
    TextColor3 = THEME.GoldDark,
    TextXAlignment = Enum.TextXAlignment.Left,
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(18, 12),
    Size = UDim2.fromOffset(200, 16),
    Parent = panel,
})

local pageCounter = create("TextLabel", {
    Text = "",
    Font = Enum.Font.GothamBold,
    TextSize = 12,
    TextColor3 = THEME.SubText,
    TextXAlignment = Enum.TextXAlignment.Right,
    BackgroundTransparency = 1,
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, -46, 0, 12),
    Size = UDim2.fromOffset(80, 16),
    Parent = panel,
})

local closeButton = create("TextButton", {
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, -10, 0, 8),
    Size = UDim2.fromOffset(26, 24),
    BackgroundColor3 = THEME.PanelLight,
    Text = "X",
    Font = Enum.Font.GothamBlack,
    TextSize = 12,
    TextColor3 = THEME.SubText,
    Parent = panel,
}, {
    create("UICorner", { CornerRadius = UDim.new(0, 6) }),
})

local pageTitle = create("TextLabel", {
    Text = "",
    Font = Enum.Font.GothamBlack,
    TextSize = 22,
    TextColor3 = THEME.Gold,
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(18, 36),
    Size = UDim2.new(1, -36, 0, 30),
    Parent = panel,
})

local pageBody = create("TextLabel", {
    Text = "",
    Font = Enum.Font.GothamMedium,
    TextSize = 16,
    LineHeight = 1.15,
    TextColor3 = THEME.Text,
    TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top,
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(26, 76),
    Size = UDim2.new(1, -52, 0, 150),
    Parent = panel,
})

-- page dots
local dotsRow = create("Frame", {
    AnchorPoint = Vector2.new(0.5, 1),
    Position = UDim2.new(0.5, 0, 1, -62),
    Size = UDim2.fromOffset(200, 10),
    BackgroundTransparency = 1,
    Parent = panel,
}, {
    create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        Padding = UDim.new(0, 8),
    }),
})
local dots = {}
for i = 1, #PAGES do
    dots[i] = create("Frame", {
        Size = UDim2.fromOffset(8, 8),
        BackgroundColor3 = THEME.PanelLight,
        LayoutOrder = i,
        Parent = dotsRow,
    }, {
        create("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
    })
end

local function navButton(text, color, textColor, xScale, xOffset, anchorX)
    return create("TextButton", {
        AnchorPoint = Vector2.new(anchorX, 1),
        Position = UDim2.new(xScale, xOffset, 1, -14),
        Size = UDim2.fromOffset(124, 38),
        BackgroundColor3 = color,
        AutoButtonColor = true,
        Text = text,
        Font = Enum.Font.GothamBlack,
        TextSize = 15,
        TextColor3 = textColor,
        Parent = panel,
    }, {
        create("UICorner", { CornerRadius = UDim.new(0, 10) }),
    })
end
local backButton = navButton("BACK", THEME.PanelLight, THEME.Text, 0, 18, 0)
local nextButton = navButton("NEXT", THEME.Gold, THEME.PanelBottom, 1, -18, 1)

local page = 1

local function showPage(n)
    page = math.clamp(n, 1, #PAGES)
    local data = PAGES[page]
    pageTitle.Text = data.Title
    pageBody.Text = table.concat(data.Body, NL)
    pageCounter.Text = page .. " / " .. #PAGES
    backButton.Visible = page > 1
    nextButton.Text = (page == #PAGES) and "LET'S PLAY!" or "NEXT"
    for i, dot in dots do
        dot.BackgroundColor3 = (i == page) and THEME.Gold or THEME.PanelLight
    end
    pageBody.TextTransparency = 1
    tween(pageBody, 0.25, { TextTransparency = 0 })
end

local function openTutorial()
    showPage(1)
    panel.Visible = true
    helpButton.Visible = false
    panelScale.Scale = 0.85
    tween(panelScale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
end

local function closeTutorial()
    panel.Visible = false
    helpButton.Visible = true
end

nextButton.Activated:Connect(function()
    if page >= #PAGES then
        closeTutorial()
    else
        showPage(page + 1)
    end
end)
backButton.Activated:Connect(function()
    showPage(page - 1)
end)
closeButton.Activated:Connect(closeTutorial)
helpButton.Activated:Connect(openTutorial)

local function updateScale()
    local camera = workspace.CurrentCamera
    if camera then
        local s = math.clamp(camera.ViewportSize.Y / 900, 0.7, 1.1)
        helpButton.Size = UDim2.fromOffset(150 * s, 30 * s)
        helpButton.Position = UDim2.new(0.5, 0, 1, -(20 + 150 * s + 12))
    end
end
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
updateScale()

--------------------------------------------------------------------------------
-- Server events (same remote BlackjackClient uses)
--------------------------------------------------------------------------------
local seenThisVisit = false

remote.OnClientEvent:Connect(function(event, tableId, data)
    if event == "Open" then
        layouts[tableId] = data
    elseif event == "Joined" then
        local layout = layouts[tableId]
        if layout then
            buildMarkers(layout)
        end
        screenGui.Enabled = true
        if CFG.ShowTutorialOnFirstSeat and not seenThisVisit then
            seenThisVisit = true
            task.delay(0.9, openTutorial) -- after the camera swoops in
        else
            closeTutorial()
        end
    elseif event == "Left" then
        clearMarkers()
        closeTutorial()
        screenGui.Enabled = false
    end
end)

print("[Casino] BlackjackTutorial ready")
