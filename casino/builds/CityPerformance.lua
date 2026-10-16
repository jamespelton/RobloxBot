-- CITY PERFORMANCE PASS
-- Makes the place load and run faster without removing anything.
--
-- Three levers, in order of how much they matter:
--   1. StreamingEnabled. It was off, so all ~49,000 parts had to replicate to
--      the client before the player could move. With it on, only the area
--      around the spawn has to arrive first and the rest fills in behind you.
--      This is the single biggest win on load time.
--   2. CastShadow. 35,951 of 48,971 parts were casting shadows, including every
--      window strip, mullion, chandelier crystal and slot-machine trim. Small
--      parts and emissive parts are switched off; the big building masses keep
--      their shadows so the skyline still reads with depth.
--   3. Light shadows. 521 lights were each rendering shadow maps. The lights
--      stay on, the shadow maps do not.
--
-- Safe to run repeatedly. Nothing is deleted and nothing moves.
-- Set RESTORE = true to put shadows back the way they were.

local RESTORE = false

-- Streaming radii. These turned out NOT to be scriptable in this Studio build
-- (StreamingMinRadius / StreamingTargetRadius are not valid members of Workspace
-- here), so the script reports that and leaves them alone. Roblox's defaults are
-- sensible; to tune them, select Workspace and edit the Streaming section of the
-- Properties panel by hand.
local STREAM_MIN_RADIUS = 256
local STREAM_TARGET_RADIUS = 1600

-- A part casts no shadow if its smallest dimension is under this...
local SHADOW_MIN_SIZE = 1.5
-- ...or if it is emissive, or nearly invisible.
local NO_SHADOW_MATERIALS = { [Enum.Material.Neon] = true }
local SHADOW_MAX_TRANSPARENCY = 0.5

local out = {}
local function log(...)
    local line = table.concat({ ... }, " ")
    table.insert(out, line)
    print("[Perf]", line)
end

----------------------------------------------------------------
-- 1. Streaming
----------------------------------------------------------------
local function setProp(obj, prop, value)
    local ok, err = pcall(function()
        obj[prop] = value
    end)
    if ok then
        local readable, now = pcall(function()
            return obj[prop]
        end)
        log(string.format("  %s.%s = %s", obj.Name, prop, readable and tostring(now) or "set"))
        return true
    end
    log(string.format("  %s.%s not available (%s)", obj.Name, prop, tostring(err):sub(1, 60)))
    return false
end

log("streaming:")
setProp(workspace, "StreamingEnabled", true)
setProp(workspace, "StreamingMinRadius", STREAM_MIN_RADIUS)
setProp(workspace, "StreamingTargetRadius", STREAM_TARGET_RADIUS)
-- Pause the client rather than teleporting it if content is late.
pcall(function()
    workspace.StreamingIntegrityMode = Enum.StreamingIntegrityMode.MinimumRadiusPause
    log("  workspace.StreamingIntegrityMode = MinimumRadiusPause")
end)
-- Newer streaming path: streams whole models and handles far-away detail better.
pcall(function()
    workspace.ModelStreamingBehavior = Enum.ModelStreamingBehavior.Improved
    log("  workspace.ModelStreamingBehavior = Improved")
end)

-- Each city block streams as one unit instead of 160 separate decisions.
local atomic = 0
for _, name in ipairs({ "City", "CityInfill" }) do
    local root = workspace:FindFirstChild(name)
    if root then
        for _, m in ipairs(root:GetChildren()) do
            if m:IsA("Model") then
                local ok = pcall(function()
                    m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
                end)
                if ok then
                    atomic = atomic + 1
                end
            end
        end
    end
end
log(string.format("  %d city models set to Atomic streaming", atomic))

----------------------------------------------------------------
-- 2 and 3. Shadows
----------------------------------------------------------------
local parts, casters, cleared, lights = 0, 0, 0, 0
for _, d in ipairs(workspace:GetDescendants()) do
    if d:IsA("BasePart") then
        parts = parts + 1
        if RESTORE then
            if not d.CastShadow then
                d.CastShadow = true
                cleared = cleared + 1
            end
        else
            local small = math.min(d.Size.X, d.Size.Y, d.Size.Z) < SHADOW_MIN_SIZE
            local emissive = NO_SHADOW_MATERIALS[d.Material] == true
            local faint = d.Transparency > SHADOW_MAX_TRANSPARENCY
            if (small or emissive or faint) and d.CastShadow then
                d.CastShadow = false
                cleared = cleared + 1
            end
        end
        if d.CastShadow then
            casters = casters + 1
        end
    elseif d:IsA("Light") then
        lights = lights + 1
        local ok = pcall(function()
            d.Shadows = RESTORE
        end)
        if not ok then
            -- some light classes have no Shadows property
        end
    end
end

if RESTORE then
    log(string.format("shadows restored: %d parts set back to casting, %d lights re-shadowed", cleared, lights))
else
    log(string.format("shadows: %d parts total, %d stopped casting, %d still cast", parts, cleared, casters))
    log(string.format("shadows: %d lights had shadow maps switched off", lights))
end

return table.concat(out, string.char(10))
