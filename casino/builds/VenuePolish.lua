-- =============================================================================
-- VENUE POLISH
--
-- Fixes for signage that was built facing the wrong way or buried. Found by
-- probing a thin slab just in front of every SurfaceGui's text face and asking
-- what else is in there; 5 of the venue's 86 text surfaces came back blocked.
--
--   1. The four WallSign neons (SLOTS x2, LUCKY 7, JACKPOT) are stacked
--      back-to-front. A sign is three layers - Halo, Panel, Neon - and the
--      Neon carries the text. On the west wall they sit at X -146.9 / -147.5
--      / -148.4 all facing -X, so the text layer is the DEEPEST into the wall
--      and points away from the room. The wall spans -152..-148, which leaves
--      3.35 studs of solid wall in front of the lettering. Rotating each sign
--      180 degrees reverses the layer order and turns it to face the room;
--      nudging it inward clears the halo off the wall face.
--
--   2. MarqueeFrame sits 0.9 studs in FRONT of MarqueeBoard, so the venue's
--      own name is covered by 0.65 studs. The frame is 58x15 against a 54x13
--      board, i.e. a border, so it belongs concentric and recessed.
--
-- Idempotent: each fixed instance stores its original CFrame as an attribute
-- and the corrected position is always recomputed from that, so re-running
-- never double-flips.
-- =============================================================================

local CFG = {
	PARENT_NAME = "Casino",
	SIGN_CLEARANCE = 0.6, -- how far to pull a wall sign clear of the wall face
}

local casino = workspace:FindFirstChild(CFG.PARENT_NAME) or workspace

local function originalPivot(model)
	local stored = model:GetAttribute("PolishOriginalCFrame")
	if stored == nil then
		local cf = model:GetBoundingBox()
		model:SetAttribute("PolishOriginalCFrame", cf)
		return cf
	end
	return stored
end

local function originalCFrame(part)
	local stored = part:GetAttribute("PolishOriginalCFrame")
	if stored == nil then
		part:SetAttribute("PolishOriginalCFrame", part.CFrame)
		return part.CFrame
	end
	return stored
end

-- ------------------------------------------------------- 1. wall neon signs --
local signsFixed = 0
for _, model in ipairs(casino:GetDescendants()) do
	if model:IsA("Model") and model.Name == "WallSign" then
		local origin = originalPivot(model)

		-- the room is toward the origin, so inward is whichever way that is
		local inward = (origin.Position.X < 0) and Vector3.new(1, 0, 0) or Vector3.new(-1, 0, 0)

		local rotation = origin - origin.Position
		local target = CFrame.new(origin.Position + inward * CFG.SIGN_CLEARANCE)
			* rotation
			* CFrame.Angles(0, math.pi, 0)

		model.WorldPivot = origin
		model:PivotTo(target)
		signsFixed = signsFixed + 1
	end
end

-- -------------------------------------------------------- 2. marquee frame --
local board, frame
for _, d in ipairs(casino:GetDescendants()) do
	if d:IsA("BasePart") then
		if d.Name == "MarqueeBoard" then
			board = d
		elseif d.Name == "MarqueeFrame" then
			frame = d
		end
	end
end

local marqueeFixed = false
if board and frame then
	originalCFrame(frame)
	-- sit the frame concentric with the board. The board is deeper than the
	-- frame, so its lettered face then stands proud and the frame reads as a
	-- border around it rather than a lid over it.
	frame.CFrame = CFrame.new(board.Position) * (board.CFrame - board.Position)
	marqueeFixed = true
end

print(string.format("[VenuePolish] wall signs re-faced: %d | marquee frame recessed: %s",
	signsFixed, tostring(marqueeFixed)))

return casino
