-- SlideHandler
-- Manages slide execution: entry condition, direction lock, deceleration
-- progress tracking, cooldown, and early cancellation (e.g. jump).
--
-- Entry rule: player must be in SPRINTING state to start a slide.
-- No server remote needed — slide speed stays within validator tolerance.

local Constants = require(game.ReplicatedStorage.Shared.Constants.MovementConstants)

local SlideHandler = {}
SlideHandler.__index = SlideHandler

function SlideHandler.new()
	return setmetatable({
		_isSliding      = false,
		_onCooldown     = false,
		_slideDirection = Vector3.zero,
		_progress       = 0,       -- 0 (start) → 1 (end of slide)
		_elapsed        = 0,
	}, SlideHandler)
end

-- Attempt to start a slide.
-- currentState must be SPRINTING — slide cannot enter from walk, idle, or air.
-- moveDirection: current input direction (locked at slide start).
function SlideHandler:trySlide(moveDirection, currentState)
	if self._isSliding or self._onCooldown then return end
	if currentState ~= "sprinting" then return end

	self._isSliding      = true
	self._elapsed        = 0
	self._progress       = 0
	self._slideDirection = moveDirection.Magnitude > 0
		and moveDirection
		or Vector3.new(0, 0, -1) -- fallback: forward (should not happen from sprint)
end

-- Cancel the slide early (e.g. player jumps mid-slide).
function SlideHandler:cancel()
	if not self._isSliding then return end
	self._isSliding  = false
	self._onCooldown = true
	task.delay(Constants.SLIDE_COOLDOWN, function()
		self._onCooldown = false
	end)
end

-- Call every frame while sliding to advance the timer.
-- Returns true while still sliding, false when slide has expired naturally.
function SlideHandler:tick(dt)
	if not self._isSliding then return false end

	self._elapsed  = self._elapsed + dt
	self._progress = math.min(self._elapsed / Constants.SLIDE_DURATION, 1)

	if self._progress >= 1 then
		self._isSliding  = false
		self._onCooldown = true
		task.delay(Constants.SLIDE_COOLDOWN, function()
			self._onCooldown = false
		end)
		return false
	end

	return true
end

function SlideHandler:isSliding()
	return self._isSliding
end

-- Direction locked at slide entry. Valid only while isSliding() is true.
function SlideHandler:getSlideDirection()
	return self._slideDirection
end

-- Progress from 0 (entry) to 1 (end). Used by MovementResolver to interpolate speed.
function SlideHandler:getProgress()
	return self._progress
end

function SlideHandler:isOnCooldown()
	return self._onCooldown
end

return SlideHandler
