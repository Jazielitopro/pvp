-- AnimationHandler
-- Creates visible pose animations using TweenService + RootJoint.C0.
-- Does NOT require external Roblox asset IDs — works immediately.
--
-- Why RootJoint.C0 and not Animator tracks?
--   The Animator modifies Motor6D.Transform. Tweening C0 is additive
--   on top of Transform, so it blends cleanly with default locomotion
--   without fighting the Animate script.
--
-- Poses:
--   Slide → forward pitch (character leans into the slide)
--   Dash  → quick forward lean then snaps back (burst feel)

local TweenService = game:GetService("TweenService")

-- Tween configs
local SLIDE_ENTER_INFO = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local SLIDE_EXIT_INFO  = TweenInfo.new(0.20, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local DASH_LEAN_INFO   = TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local DASH_RETURN_INFO = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local DEATH_ENTER_INFO = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- Pitch angles
local SLIDE_PITCH = math.rad(-22) -- forward lean during slide
local DASH_PITCH  = math.rad(-14) -- brief forward lean on dash start
local DEATH_ROLL  = math.rad(88)  -- fall sideways on death

-- ─────────────────────────────────────────────────────────────────────────────

local AnimationHandler = {}
AnimationHandler.__index = AnimationHandler

function AnimationHandler.new(humanoid)
	-- RootJoint connects HumanoidRootPart → LowerTorso in R15.
	-- Tweening its C0 tilts the entire character body.
	local rootPart  = humanoid.RootPart
	local rootJoint = rootPart and rootPart:FindFirstChild("RootJoint")

	if not rootJoint then
		warn("AnimationHandler: RootJoint not found — poses disabled.")
	end

	local defaultC0 = rootJoint and rootJoint.C0 or CFrame.new()
	local slideC0   = defaultC0 * CFrame.Angles(SLIDE_PITCH, 0, 0)
	local dashC0    = defaultC0 * CFrame.Angles(DASH_PITCH,  0, 0)

	return setmetatable({
		_joint      = rootJoint,
		_defaultC0  = defaultC0,
		_slideC0    = slideC0,
		_dashC0     = dashC0,
		_prevState  = "",
		_dashTween  = nil,
	}, AnimationHandler)
end

-- Called every frame from Heartbeat. Only acts on state transitions.
function AnimationHandler:update(state)
	if state == self._prevState then return end
	local prev = self._prevState
	self._prevState = state

	if not self._joint then return end

	-- ── Exiting slide ──────────────────────────────────────────────────────
	if prev == "sliding" and state ~= "sliding" then
		TweenService:Create(self._joint, SLIDE_EXIT_INFO, { C0 = self._defaultC0 }):Play()
	end

	-- ── Entering slide ─────────────────────────────────────────────────────
	if state == "sliding" then
		TweenService:Create(self._joint, SLIDE_ENTER_INFO, { C0 = self._slideC0 }):Play()
	end

	-- ── Entering dash: lean forward then snap back ─────────────────────────
	if state == "dashing" then
		-- Cancel any ongoing dash return tween
		if self._dashTween then self._dashTween:Cancel() end

		TweenService:Create(self._joint, DASH_LEAN_INFO, { C0 = self._dashC0 }):Play()

		-- Return to default after the lean reaches peak
		self._dashTween = TweenService:Create(self._joint, DASH_RETURN_INFO, { C0 = self._defaultC0 })
		task.delay(0.08, function()
			if self._dashTween then self._dashTween:Play() end
		end)
	end
end

-- Play death fall pose. Called by HealthController when local player dies.
-- The fade-to-black covers the end of the tween so the transition is clean.
function AnimationHandler:playDeath()
	if not self._joint then return end
	local deathC0 = self._defaultC0 * CFrame.Angles(0, 0, DEATH_ROLL)
	TweenService:Create(self._joint, DEATH_ENTER_INFO, { C0 = deathC0 }):Play()
end

-- Reset character to default pose (call on cleanup / respawn).
function AnimationHandler:destroy()
	if self._joint then
		self._joint.C0 = self._defaultC0
	end
	if self._dashTween then
		self._dashTween:Cancel()
	end
end

return AnimationHandler
