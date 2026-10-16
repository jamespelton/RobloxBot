-- CASINO TIDY-UP (Script in ServerScriptService, run once in Studio)
--
-- Fixes the things a walk-through of the casino turned up. Safe to run again:
-- every step measures where things are now and only moves what is still off.
-- Run it again after re-running any of the Luxury table scripts.
--
--   1. FURNITURE SUNK INTO THE FLOOR. The roulette, poker, craps and blackjack
--      builds took the floor height from the bottom of the old furniture,
--      which sat at y 0. The casino carpet, the pit floor and the raised aisle
--      down the middle are 0.30 to 0.63 above that, so every stool's gold
--      foot was buried and the posts grew straight out of the carpet. The bar
--      stools standing on the aisle had the same problem. Each stool or chair
--      now stands on the floor directly under it, and each table on the floor
--      under its middle.
--   2. LAMP RODS THROUGH A CHANDELIER. The craps table's hanging lamp sits
--      under a chandelier, and its rods ran up through the chandelier's arms
--      to the ceiling. Any lamp rod that meets a chandelier now stops at it,
--      so the lamp hangs from the chandelier.
--   3. LOBBY DESKS IN THE COLUMNS. The coat check and rewards desks are 26
--      studs long and their outer ends ran about 4.5 studs into a column.
--      They are shortened evenly, staying centred under their signs, to clear
--      the column by 0.3.

local CFG = {
    STOOL_RADIUS = 1.6,   -- parts this close to a seat (sideways) belong to its stool
    MAX_MOVE = 1.0,       -- never move anything further than this up or down
    COLUMN_GAP = 0.3,     -- space left between a desk and a column
}

local V = Vector3.new
local casino = workspace:FindFirstChild("Casino")
if not casino then
    warn("[TidyUp] no Workspace.Casino")
    return
end

local function bounds(part)
    local half = part.Size / 2
    local mn, mx = V(math.huge, math.huge, math.huge), V(-math.huge, -math.huge, -math.huge)
    for _, sx in ipairs({ -1, 1 }) do
        for _, sy in ipairs({ -1, 1 }) do
            for _, sz in ipairs({ -1, 1 }) do
                local c = part.CFrame * V(half.X * sx, half.Y * sy, half.Z * sz)
                mn, mx = mn:Min(c), mx:Max(c)
            end
        end
    end
    return mn, mx
end
local function flat(v)
    return V(v.X, 0, v.Z)
end
local function shift(parts, dy)
    for _, p in ipairs(parts) do
        p.CFrame = p.CFrame + V(0, dy, 0)
    end
end

----------------------------------------------------------------
-- 1. Stand furniture on the real floor
----------------------------------------------------------------
local floorParams = RaycastParams.new()
floorParams.FilterType = Enum.RaycastFilterType.Include
floorParams.FilterDescendantsInstances = { casino:FindFirstChild("Floor"), casino:FindFirstChild("Shell") }
local function floorAt(p)
    local hit = workspace:Raycast(V(p.X, p.Y + 2, p.Z), V(0, -20, 0), floorParams)
    return hit and hit.Position.Y
end
local function lowest(parts)
    local y = math.huge
    for _, p in ipairs(parts) do
        y = math.min(y, (bounds(p)).Y)
    end
    return y
end

local stoolsMoved, tablesMoved, biggest = 0, 0, 0
local function ground(model, withBody)
    local all = {}
    for _, p in ipairs(model:GetDescendants()) do
        if p:IsA("BasePart") then
            table.insert(all, p)
        end
    end
    local taken = {}
    for _, seat in ipairs(model:GetDescendants()) do
        if seat:IsA("Seat") then
            local centre = flat(seat.Position)
            local stool = {}
            for _, p in ipairs(all) do
                if not taken[p] and (flat(p.Position) - centre).Magnitude <= CFG.STOOL_RADIUS
                    and p.Position.Y <= seat.Position.Y + 3 then
                    table.insert(stool, p)
                    taken[p] = true
                end
            end
            local floor = floorAt(seat.Position)
            local dy = floor and floor - lowest(stool) or 0
            if math.abs(dy) > 0.01 and math.abs(dy) <= CFG.MAX_MOVE then
                shift(stool, dy)
                stoolsMoved += 1
                biggest = math.max(biggest, math.abs(dy))
            end
        end
    end
    if withBody then
        local body = {}
        for _, p in ipairs(all) do
            if not taken[p] then
                table.insert(body, p)
            end
        end
        local link = model:FindFirstChild("OriginalTable")
        local centre = link and link.Value and link.Value:GetBoundingBox().Position or model:GetBoundingBox().Position
        local floor = floorAt(V(centre.X, lowest(body) + 1, centre.Z))
        local dy = floor and floor - lowest(body) or 0
        if math.abs(dy) > 0.01 and math.abs(dy) <= CFG.MAX_MOVE then
            shift(body, dy)
            -- the roulette WheelMirror turns the rotor about this point
            local wheelCentre = model:GetAttribute("WheelCentre")
            if typeof(wheelCentre) == "Vector3" then
                model:SetAttribute("WheelCentre", wheelCentre + V(0, dy, 0))
            end
            tablesMoved += 1
            biggest = math.max(biggest, math.abs(dy))
        end
    end
end

for _, name in ipairs({ "LuxuryRoulette", "LuxuryPoker", "LuxuryCraps" }) do
    local folder = casino:FindFirstChild(name)
    if folder then
        for _, m in ipairs(folder:GetChildren()) do
            if m:IsA("Model") then
                ground(m, true)
            end
        end
    end
end
local chairs = casino:FindFirstChild("LuxuryChairs")
if chairs then
    for _, m in ipairs(chairs:GetChildren()) do
        ground(m, false)
    end
end
local bar = casino:FindFirstChild("LuxuryBar")
if bar then
    ground(bar, false)
end
print(string.format("[TidyUp] 1. stood %d stools/chairs and %d tables on the floor (largest move %.2f)", stoolsMoved, tablesMoved, biggest))

----------------------------------------------------------------
-- 2. Lamp rods that run into a chandelier stop at it
----------------------------------------------------------------
local chandeliers = casino:FindFirstChild("Chandeliers")
local rodsCut = 0
if chandeliers then
    local chandelierParts = {}
    for _, p in ipairs(chandeliers:GetDescendants()) do
        if p:IsA("BasePart") and p.Transparency < 1 then
            table.insert(chandelierParts, { part = p, mn = select(1, bounds(p)), mx = select(2, bounds(p)) })
        end
    end
    -- (chandelier parts don't answer spatial queries, so their boxes are
    -- compared directly below rather than asked with GetPartsInPart)
    for _, folder in ipairs(casino:GetChildren()) do
        if string.sub(folder.Name, 1, 6) == "Luxury" then
            for _, rod in ipairs(folder:GetDescendants()) do
                -- a hanging rod: a thin vertical cylinder
                if rod:IsA("Part") and rod.Shape == Enum.PartType.Cylinder and rod.Size.Y <= 0.2
                    and rod.Size.X >= 3 and math.abs(rod.CFrame.RightVector.Y) > 0.98 then
                    local mn, mx = bounds(rod)
                    local x, z, bottom = rod.Position.X, rod.Position.Z, mn.Y
                    -- the chandelier parts whose box the rod passes through...
                    local near = {}
                    for _, c in ipairs(chandelierParts) do
                        if x >= c.mn.X - 0.1 and x <= c.mx.X + 0.1 and z >= c.mn.Z - 0.1 and z <= c.mx.Z + 0.1
                            and c.mx.Y > bottom + 1 and c.mn.Y < mx.Y then
                            table.insert(near, c.part)
                        end
                    end
                    -- ...then walk up the rod to where it first enters one of
                    -- them for real (an angled arm's box is bigger than the arm)
                    local function inside(p, point)
                        local lp = p.CFrame:PointToObjectSpace(point)
                        local h = p.Size / 2
                        if p:IsA("Part") and p.Shape == Enum.PartType.Ball then
                            return lp.Magnitude <= h.X
                        elseif p:IsA("Part") and p.Shape == Enum.PartType.Cylinder then
                            return math.abs(lp.X) <= h.X and V(0, lp.Y, lp.Z).Magnitude <= h.Y
                        end
                        return math.abs(lp.X) <= h.X and math.abs(lp.Y) <= h.Y and math.abs(lp.Z) <= h.Z
                    end
                    local stopAt = mx.Y
                    if #near > 0 then
                        for y = bottom + 1, mx.Y, 0.05 do
                            local hit = false
                            for _, p in ipairs(near) do
                                if inside(p, V(x, y, z)) then
                                    hit = true
                                    break
                                end
                            end
                            if hit then
                                stopAt = y
                                break
                            end
                        end
                    end
                    if stopAt < mx.Y - 0.05 then
                        local length = stopAt + 0.1 - bottom -- 0.1 into it, so it visibly attaches
                        rod.Size = V(length, rod.Size.Y, rod.Size.Z)
                        rod.CFrame = CFrame.new(x, bottom + length / 2, z) * rod.CFrame.Rotation
                        rodsCut += 1
                    end
                end
            end
        end
    end
end
print(string.format("[TidyUp] 2. %d lamp rod(s) now stop at a chandelier", rodsCut))

----------------------------------------------------------------
-- 3. Lobby desks clear of the columns
----------------------------------------------------------------
local desksFixed = 0
local venue = casino:FindFirstChild("Venue")
local lobby = venue and venue:FindFirstChild("Lobby")
local decor = casino:FindFirstChild("Decor")
if lobby and decor then
    local columnParts = {}
    for _, col in ipairs(decor:GetChildren()) do
        if col.Name == "Column" then
            for _, p in ipairs(col:GetDescendants()) do
                if p:IsA("BasePart") and p.Transparency < 1 then
                    local mn, mx = bounds(p)
                    table.insert(columnParts, { mn = mn, mx = mx })
                end
            end
        end
    end
    -- how far a desk part can reach along X before it meets a column
    local function clearHalf(part)
        local mn, mx = bounds(part)
        local cx = part.Position.X
        local half = part:GetAttribute("TidyOriginalSizeX") / 2
        for _, c in ipairs(columnParts) do
            local overlapsY = c.mx.Y > mn.Y and c.mn.Y < mx.Y
            local overlapsZ = c.mx.Z > mn.Z and c.mn.Z < mx.Z
            if overlapsY and overlapsZ then
                if c.mn.X > cx then
                    half = math.min(half, c.mn.X - cx - CFG.COLUMN_GAP)
                elseif c.mx.X < cx then
                    half = math.min(half, cx - c.mx.X - CFG.COLUMN_GAP)
                end
            end
        end
        return half
    end
    local desks = {}
    for _, p in ipairs(lobby:GetDescendants()) do
        if p:IsA("BasePart") and (p.Name == "Desk" or p.Name == "Coat") then
            table.insert(desks, p)
        end
    end
    for _, desk in ipairs(desks) do
        local pieces = { desk }
        for _, p in ipairs(lobby:GetDescendants()) do
            if p:IsA("BasePart") and p ~= desk and (p.Name == "DeskTop" or p.Name == "CoatTop" or p.Name == "DeskGlow")
                and math.abs(p.Position.X - desk.Position.X) < 1 and math.abs(p.Position.Z - desk.Position.Z) < 4 then
                table.insert(pieces, p)
            end
        end
        for _, p in ipairs(pieces) do
            if p:GetAttribute("TidyOriginalSizeX") == nil then
                p:SetAttribute("TidyOriginalSizeX", p.Size.X)
            end
            -- check against the original length, so a second run is the same
            p.Size = V(p:GetAttribute("TidyOriginalSizeX"), p.Size.Y, p.Size.Z)
        end
        -- the desk body sets the length; the top keeps its overhang and the
        -- glow strip its inset, each as far as its own clearance allows
        local deskHalf = clearHalf(desk)
        local deskOrig = desk:GetAttribute("TidyOriginalSizeX")
        for _, p in ipairs(pieces) do
            local orig = p:GetAttribute("TidyOriginalSizeX")
            local want = deskHalf + (orig - deskOrig) / 2
            local half = math.max(0.5, math.min(want, clearHalf(p)))
            p.Size = V(half * 2, p.Size.Y, p.Size.Z)
        end
        if deskHalf * 2 < deskOrig - 0.01 then
            desksFixed += 1
        end
    end
end
print(string.format("[TidyUp] 3. %d lobby desk(s) sized to clear the columns", desksFixed))
