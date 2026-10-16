-- REMOVE THE LOBBY FOUNTAIN (Script in ServerScriptService, run once in Studio)
--
-- The fountain in Venue.Lobby stood 22 studs inside the front doors, 26 studs
-- across, right on the entrance carpet, so everyone walking in had to go
-- round it. It's nine loose parts in the Lobby model: the outer and inner
-- basins, the water, the centre column, stem, upper bowl and its water, and
-- the gold statue with its glowing orb on top.
--
-- They are moved to ServerStorage > RemovedFountain rather than deleted, so
-- the fountain can be put back by dragging that folder's parts into
-- Workspace.Casino.Venue.Lobby. The rope posts and the red runner carpet
-- around it are separate and stay: they still line the way in.
--
-- Safe to re-run: once the parts are gone there is nothing left to move.

local ServerStorage = game:GetService("ServerStorage")

local FOUNTAIN_PARTS = {
    BasinOut = true, BasinIn = true, Water = true,
    Column = true, Stem = true, Bowl = true, BowlWater = true,
    Statue = true, StatueOrb = true,
}

local casino = workspace:FindFirstChild("Casino")
local venue = casino and casino:FindFirstChild("Venue")
local lobby = venue and venue:FindFirstChild("Lobby")
if not lobby then
    warn("[Fountain] no Workspace.Casino.Venue.Lobby")
    return
end

-- the fountain's centre is the outer basin; only parts stacked on that spot
-- are taken, so a part elsewhere in the lobby that shares a name is left alone
local basin = lobby:FindFirstChild("BasinOut")
if not basin then
    print("[Fountain] already removed")
    return
end
local centre = Vector3.new(basin.Position.X, 0, basin.Position.Z)

local storage = ServerStorage:FindFirstChild("RemovedFountain")
if not storage then
    storage = Instance.new("Folder")
    storage.Name = "RemovedFountain"
    storage.Parent = ServerStorage
end

local moved = {}
for _, p in ipairs(lobby:GetChildren()) do
    if p:IsA("BasePart") and FOUNTAIN_PARTS[p.Name]
        and (Vector3.new(p.Position.X, 0, p.Position.Z) - centre).Magnitude < 1 then
        table.insert(moved, p.Name)
        p.Parent = storage
    end
end
print(string.format("[Fountain] moved %d parts to ServerStorage.RemovedFountain: %s", #moved, table.concat(moved, ", ")))
