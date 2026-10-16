-- SLOT REEL MIRROR (Script in ServerScriptService)
--
-- LuxurySlots hides the original slot machines and builds new cabinets over
-- them, but SlotService still shows every spin on the ORIGINAL machine's
-- reels. This copies each reel's symbol onto the new machine's payline as it
-- changes, so the reels you can see are the ones that spin and land.
--
-- SlotService stays in charge of the game; nothing here touches chips, odds
-- or results. It only reads the original reel labels and repeats them.

-- What each of SlotService's symbols looks like on the new reels.
-- Change the right-hand side to restyle a symbol.
local GLYPHS = {
    ["$"] = "$",
    ["C"] = "🍒",
    ["H"] = "♥",
    ["*"] = "⭐",
    ["7"] = "7",
    ["D"] = "💎",
}

local casino = workspace:WaitForChild("Casino", 30)
local lux = casino and casino:WaitForChild("LuxurySlots", 30)
if not lux then
    warn("[SlotReelMirror] no Workspace.Casino.LuxurySlots; nothing to mirror")
    return
end

local function hook(model)
    local link = model:FindFirstChild("OriginalMachine")
    local original = link and link.Value
    local wheels = original and original:FindFirstChild("Ruedas Jackpot")
    if not wheels then
        return false
    end

    -- the same three parts SlotService draws on: the ones carrying a reel decal
    local olds = {}
    for _, d in ipairs(wheels:GetDescendants()) do
        if d:IsA("BasePart") and d:FindFirstChildOfClass("Decal") then
            table.insert(olds, d)
        end
    end
    local news = {}
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("BasePart") and d.Name == "ReelFace" then
            table.insert(news, d)
        end
    end
    if #olds < 3 or #news < 3 then
        return false
    end

    -- pair them left to right along the machine, the way SlotService orders them
    local right = original:GetPivot().RightVector
    local function byRight(a, b)
        return a.Position:Dot(right) < b.Position:Dot(right)
    end
    table.sort(olds, byRight)
    table.sort(news, byRight)

    for i = 1, 3 do
        task.spawn(function()
            local reelGui = olds[i]:WaitForChild("ReelGui", 60)
            local source = reelGui and reelGui:FindFirstChildWhichIsA("TextLabel", true)
            local target = news[i]:FindFirstChild("PayLine", true)
            if not source or not target then
                return
            end
            -- the old reel is hidden inside the new cabinet; the new one shows it now
            reelGui.Enabled = false
            local function copy()
                target.Text = GLYPHS[source.Text] or source.Text
                target.TextColor3 = source.TextColor3
            end
            copy()
            source:GetPropertyChangedSignal("Text"):Connect(copy)
            source:GetPropertyChangedSignal("TextColor3"):Connect(copy)
        end)
    end
    return true
end

local hooked = 0
for _, model in ipairs(lux:GetChildren()) do
    if hook(model) then
        hooked += 1
    end
end
print("[SlotReelMirror] mirroring " .. hooked .. " machines")
