-- AnimationHandler
-- Plays state-specific overlay animations (dash, slide) using Action priority,
-- which blends on top of the default Animate script locomotion tracks.
--
-- ┌─────────────────────────────────────────────────────────────┐
-- │  HOW TO ADD REAL ANIMATIONS                                 │
-- │  1. Create the animation in Roblox Studio Animation Editor  │
-- │  2. Publish it (requires the game to be published)          │
-- │  3. Copy the asset ID into ANIMATION_IDS below              │
-- │  4. The system loads and plays it automatically             │
-- └─────────────────────────────────────────────────────────────┘

-- Replace "0" with real Roblox animation asset IDs when available.
-- Entries with ID = "0" are silently skipped (no error, no crash).
local ANIMATION_IDS = {
	dash  = "0",   -- TODO: paste dash/roll animation ID here
	slide = "0",   -- TODO: paste slide/crouch animation ID here
}

-- ──────────────────────────────────────────────────────────────────────────────

local AnimationHandler = {}
AnimationHandler.__index = AnimationHandler

local function loadTrack(animator, id, looped)
	if id == "0" or id == "" then return nil end

	local anim = Instance.new("Animation")
	anim.AnimationId = "rbxassetid://" .. id

	local ok, track = pcall(function()
		return animator:LoadAnimation(anim)
	end)

	if not ok or not track then
		warn("AnimationHandler: failed to load animation ID " .. id)
		return nil
	end

	track.Priority = Enum.AnimationPriority.Action
	track.Looped   = looped or false
	return track
end

function AnimationHandler.new(humanoid)
	local animator = humanoid:WaitForChild("Animator")

	local tracks = {
		dash  = loadTrack(animator, ANIMATION_IDS.dash,  false), -- one-shot
		slide = loadTrack(animator, ANIMATION_IDS.slide, true),  -- loops while sliding
	}

	return setmetatable({
		_tracks       = tracks,
		_activeState  = "",
	}, AnimationHandler)
end

-- Call once per frame (or on state change).
-- Starts the correct animation and stops the previous one.
function AnimationHandler:update(state)
	if state == self._activeState then return end

	local prev = self._activeState
	self._activeState = state

	-- Stop previous special animation
	if prev == "dashing" and self._tracks.dash then
		self._tracks.dash:Stop(0.1)
	end
	if prev == "sliding" and self._tracks.slide then
		self._tracks.slide:Stop(0.2)
	end

	-- Play new special animation
	if state == "dashing" and self._tracks.dash then
		self._tracks.dash:Play(0.05)
	end
	if state == "sliding" and self._tracks.slide then
		self._tracks.slide:Play(0.1)
	end
end

function AnimationHandler:destroy()
	for _, track in pairs(self._tracks) do
		if track then
			track:Stop()
			track:Destroy()
		end
	end
end

return AnimationHandler
