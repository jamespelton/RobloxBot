-- MARQUEE BULBS (LocalScript in StarterPlayer > StarterPlayerScripts)
--
-- Chases the bulbs around the LuxurySigns marquees: two on, one off, stepping
-- every 0.3 seconds, the same pattern as James's sign script. It runs on each
-- player's own machine, so the server isn't sending hundreds of bulb changes
-- a second to everyone. Turn it off with ANIMATE_BULBS in LuxurySigns.

local STEP_TIME = 0.3
local BULB_OFF = Color3.fromRGB(110, 95, 60)
local BULB_ON = Color3.fromRGB(255, 230, 160)

local casino = workspace:WaitForChild("Casino", 60)
local folder = casino and casino:WaitForChild("LuxurySigns", 60)
if not folder or folder:GetAttribute("AnimateBulbs") == false then
    return
end

-- With streaming on, bulbs arrive as the player gets near them, so the list
-- is refreshed every few seconds rather than read once.
local bulbs = {}
local function refresh()
    local list = {}
    for _, d in ipairs(folder:GetDescendants()) do
        if d.Name == "MarqueeBulb" and d:IsA("BasePart") then
            table.insert(list, { part = d, index = d:GetAttribute("Index") or #list + 1, on = d.Material == Enum.Material.Neon })
        end
    end
    bulbs = list
end

refresh()
local step, sinceRefresh = 0, 0
while folder.Parent do
    step += 1
    for _, b in ipairs(bulbs) do
        local on = (b.index + step) % 3 ~= 0
        if on ~= b.on and b.part.Parent then
            b.on = on
            b.part.Material = on and Enum.Material.Neon or Enum.Material.SmoothPlastic
            b.part.Color = on and BULB_ON or BULB_OFF
        end
    end
    task.wait(STEP_TIME)
    sinceRefresh += STEP_TIME
    if sinceRefresh >= 5 then
        sinceRefresh = 0
        refresh()
    end
end
