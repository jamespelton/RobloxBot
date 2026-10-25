-- LUXURY BLACKJACK TABLE (Script in ServerScriptService)
-- Builds a new table over each blackjack table so dealt cards lie flat on the felt.
-- Casino change: the felt is found from each part's world-space corners (the table parts are rotated,
-- so Size.Y / Size.X * Size.Z don't point up / lie flat), and the new parts' model is named
-- LuxuryTableParts so the blackjack scripts don't count it as a second table.
local FELT_COLOR = Color3.fromRGB(18, 92, 52)
local WOOD_COLOR = Color3.fromRGB(70, 28, 18)
local LEATHER_COLOR = Color3.fromRGB(32, 16, 14)
local GOLD = Color3.fromRGB(212, 175, 55)
local SEGMENTS = 28 -- how smooth the curve is

local V = Vector3.new
local UP = V(0, 1, 0)
local function flat(v)
    return V(v.X, 0, v.Z)
end

task.wait(1) -- build before the chair script (3s) and the blackjack game (6s)

local function newPart(parent, size, cf, color, material, solid)
    local p = Instance.new("Part")
    p.Anchored = true
    p.Size = size
    p.CFrame = cf
    p.Color = color
    p.Material = material or Enum.Material.SmoothPlastic
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.CanCollide = solid ~= false
    p.CanQuery = solid ~= false -- decorations are ignored by the card placement
    p.CanTouch = false
    p.Parent = parent
    return p
end

local function buildTable(model)
    if model:GetAttribute("LuxuryBuilt") then
        return
    end
    model:SetAttribute("LuxuryBuilt", true)
    local boxCF, boxSize = model:GetBoundingBox()
    local boxCenter = boxCF.Position

    -- Which side the players sit on (where the chairs are)
    local avg = V(0, 0, 0)
    for _, s in ipairs(workspace:GetDescendants()) do
        if s:IsA("Seat") and not s:IsDescendantOf(model) then
            local d = flat(s.Position - boxCenter)
            if d.Magnitude < math.max(boxSize.X, boxSize.Z) / 2 + 8 and math.abs(s.Position.Y - boxCenter.Y) < 8 and d.Magnitude > 0.1 then
                avg += d.Unit
            end
        end
    end
    local toPlayers = avg.Magnitude > 0.01 and avg.Unit or flat(boxCF.LookVector).Unit
    local right = UP:Cross(toPlayers)

    -- Measure the old table, then hide it (fake cards and chips too)
    local frame = CFrame.fromMatrix(boxCenter, right, UP, toPlayers)
    local minX, maxX, minY, maxY, minZ = math.huge, -math.huge, math.huge, -math.huge, math.huge
    local feltTop, bestArea = nil, 0
    for _, p in ipairs(model:GetDescendants()) do
        if p:IsA("BasePart") then
            local pMinX, pMaxX, pMaxY, pMinZ, pMaxZ = math.huge, -math.huge, -math.huge, math.huge, -math.huge
            for _, sx in ipairs({ -1, 1 }) do
                for _, sy in ipairs({ -1, 1 }) do
                    for _, sz in ipairs({ -1, 1 }) do
                        local corner = frame:PointToObjectSpace((p.CFrame * CFrame.new(p.Size.X / 2 * sx, p.Size.Y / 2 * sy, p.Size.Z / 2 * sz)).Position)
                        minX, maxX = math.min(minX, corner.X), math.max(maxX, corner.X)
                        minY, maxY = math.min(minY, corner.Y), math.max(maxY, corner.Y)
                        minZ = math.min(minZ, corner.Z)
                        pMinX, pMaxX = math.min(pMinX, corner.X), math.max(pMaxX, corner.X)
                        pMaxY = math.max(pMaxY, corner.Y)
                        pMinZ, pMaxZ = math.min(pMinZ, corner.Z), math.max(pMaxZ, corner.Z)
                    end
                end
            end
            local area = (pMaxX - pMinX) * (pMaxZ - pMinZ)
            if area > bestArea and p.Transparency < 1 then
                bestArea, feltTop = area, boxCenter.Y + pMaxY
            end
            p:SetAttribute("OldTransparency", p.Transparency)
            p.Transparency = 1
            p.CanCollide = false
            p.CanQuery = false
            p.CanTouch = false
            for _, d in ipairs(p:GetChildren()) do
                if d:IsA("Decal") or d:IsA("Texture") then
                    d.Transparency = 1
                elseif d:IsA("SurfaceGui") then
                    d.Enabled = false
                end
            end
        end
    end

    local floorY = boxCenter.Y + minY
    local topY = boxCenter.Y + maxY
    local feltY = math.clamp(feltTop or topY, floorY + 2.5, topY)
    local R = math.max((maxX - minX) / 2, 4)
    local COUNTER = 1.4
    local centerX = (minX + maxX) / 2
    local arcCenter = frame:PointToWorldSpace(V(centerX, 0, minZ + COUNTER))
    -- base: +Z points to the players, -Z to the dealer, Y = 0 at the floor
    local base = CFrame.fromMatrix(V(arcCenter.X, floorY, arcCenter.Z), right, UP, toPlayers)
    local fy = feltY - floorY -- felt height in base space

    local folder = Instance.new("Model")
    folder.Name = "LuxuryTableParts" -- no "blackjack" in the name, or V3 / TableAdjust treat it as another table
    folder.Parent = model

    -- A curved band of segments (half circle on the players' side)
    local function arcRing(rIn, rOut, y0, y1, color, material, solid, every)
        local step = math.pi / SEGMENTS
        for i = 1, SEGMENTS do
            if not every or i % every == 0 then
                local a = -math.pi / 2 + (i - 0.5) * step
                local width = every and 0.12 or (2 * rOut * math.tan(step / 2) + 0.04)
                local mid = (rIn + rOut) / 2
                local cf = base * CFrame.new(math.sin(a) * mid, (y0 + y1) / 2, math.cos(a) * mid) * CFrame.Angles(0, a, 0)
                newPart(folder, V(width, y1 - y0, rOut - rIn), cf, color, material, solid)
            end
        end
    end

    -- Base and pedestal
    arcRing(0, R * 0.55, 0, 0.18, GOLD, Enum.Material.Metal)
    arcRing(0, R * 0.48, 0.18, 1.0, WOOD_COLOR, Enum.Material.Wood)
    newPart(folder, V(R * 1.1, 0.18, COUNTER + 0.4), base * CFrame.new(0, 0.09, -COUNTER / 2), GOLD, Enum.Material.Metal)
    newPart(folder, V(R * 0.96, 0.82, COUNTER + 0.2), base * CFrame.new(0, 0.59, -COUNTER / 2), WOOD_COLOR, Enum.Material.Wood)

    -- Body (wood apron under the felt)
    arcRing(0, R - 0.55, 1.0, fy - 0.25, WOOD_COLOR, Enum.Material.Wood)
    arcRing(R - 0.62, R - 0.5, 1.15, fy - 0.55, GOLD, Enum.Material.Metal, false, 2) -- gold pinstripes
    arcRing(R - 0.6, R - 0.5, 1.0, 1.15, GOLD, Enum.Material.Metal, false)

    -- Felt
    arcRing(0, R - 0.85, fy - 0.25, fy, FELT_COLOR, Enum.Material.Fabric)

    -- Padded leather armrest with gold trim
    arcRing(R - 0.95, R, fy - 0.35, fy + 0.3, LEATHER_COLOR, Enum.Material.Leather)
    arcRing(R - 0.6, R + 0.03, fy - 0.5, fy - 0.35, GOLD, Enum.Material.Metal)
    arcRing(R - 1.0, R - 0.9, fy, fy + 0.05, GOLD, Enum.Material.Metal, false)

    -- Dealer counter on the flat side
    newPart(folder, V(2 * R, fy - 1.25, COUNTER), base * CFrame.new(0, (1.0 + fy - 0.25) / 2, -COUNTER / 2), WOOD_COLOR, Enum.Material.Wood)
    newPart(folder, V(2 * R - 1.7, 0.25, COUNTER + 0.02), base * CFrame.new(0, fy - 0.125, -COUNTER / 2), FELT_COLOR, Enum.Material.Fabric)
    newPart(folder, V(2 * R, 0.4, 0.3), base * CFrame.new(0, fy - 0.1, -COUNTER - 0.15), WOOD_COLOR, Enum.Material.Wood)
    newPart(folder, V(2 * R, 0.08, 0.32), base * CFrame.new(0, fy + 0.12, -COUNTER - 0.15), GOLD, Enum.Material.Metal, false)

    -- Dealer chip rack with chip stacks
    local rackCF = base * CFrame.new(0, fy + 0.06, -COUNTER * 0.55)
    newPart(folder, V(4.2, 0.12, 0.9), rackCF, Color3.fromRGB(20, 18, 22), Enum.Material.SmoothPlastic, false)
    local chipColors = {
        Color3.fromRGB(240, 240, 235), Color3.fromRGB(200, 30, 35), Color3.fromRGB(30, 120, 65),
        Color3.fromRGB(25, 25, 28), Color3.fromRGB(110, 50, 150), Color3.fromRGB(230, 170, 40),
    }
    for i, color in ipairs(chipColors) do
        local height = 0.3 + (i % 3) * 0.1
        local x = -1.75 + (i - 1) * 0.7
        local stack = newPart(folder, V(height, 0.55, 0.55), rackCF * CFrame.new(x, 0.06 + height / 2, 0) * CFrame.Angles(0, 0, math.rad(90)), color, Enum.Material.SmoothPlastic, false)
        stack.Shape = Enum.PartType.Cylinder
    end

    -- Discard tray (left of the dealer)
    newPart(folder, V(1.1, 0.35, 0.8), base * CFrame.new(-R + 1.6, fy + 0.175, -COUNTER * 0.55), Color3.fromRGB(180, 200, 210), Enum.Material.Glass, false).Transparency = 0.5

    -- Printing on the felt
    local textPart = newPart(folder, V(R * 1.5, 0.02, 2.2), base * CFrame.new(0, fy + 0.012, R * 0.36), FELT_COLOR, Enum.Material.Fabric, false)
    textPart.Transparency = 1
    local gui = Instance.new("SurfaceGui")
    gui.Face = Enum.NormalId.Top
    gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    gui.PixelsPerStud = 60
    gui.LightInfluence = 0.6
    gui.Parent = textPart
    local function line(txt, y, h, color, font)
        local l = Instance.new("TextLabel")
        l.BackgroundTransparency = 1
        l.Position = UDim2.fromScale(0, y)
        l.Size = UDim2.fromScale(1, h)
        l.Text = txt
        l.TextScaled = true
        l.Font = font
        l.TextColor3 = color
        l.TextTransparency = 0.1
        l.Parent = gui
    end
    line("BLACKJACK PAYS 3 TO 2", 0.05, 0.38, GOLD, Enum.Font.Garamond)
    line("Dealer must draw to 16 and stand on all 17s", 0.48, 0.22, Color3.fromRGB(235, 235, 225), Enum.Font.Garamond)
    line("GOLDEN SPIRE CASINO", 0.74, 0.18, Color3.fromRGB(235, 235, 225), Enum.Font.Garamond)

    -- Soft light over the felt
    local lampCF = base * CFrame.new(0, fy + 11, R * 0.35)
    local lamp = newPart(folder, V(0.5, 0.5, 0.5), lampCF, Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, false)
    lamp.Transparency = 1
    local light = Instance.new("SpotLight")
    light.Face = Enum.NormalId.Bottom
    light.Angle = 70
    light.Brightness = 1.6
    light.Range = 18
    light.Color = Color3.fromRGB(255, 236, 200)
    light.Shadows = true
    light.Parent = lamp
end

local count = 0
for _, m in ipairs(workspace:GetDescendants()) do
    if m:IsA("Model") then
        local name = string.lower(m.Name)
        if string.find(name, "blackjack") and not string.find(name, "_chairs") and not string.find(name, "blackjackgame")
            and not string.find(name, "extra") and not string.find(name, "luxury") then
            buildTable(m)
            count += 1
        end
    end
end
print("[Blackjack] Built " .. count .. " luxury table(s)")
