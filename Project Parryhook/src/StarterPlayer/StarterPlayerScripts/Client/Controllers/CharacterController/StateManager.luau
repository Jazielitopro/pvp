-- StateManager
-- Tracks the player's current movement state.
-- Step 1 states: IDLE, WALKING, SPRINTING, AIRBORNE
-- Step 2 adds: DASHING
-- Slide state will be added in Step 3.

local States = {
	IDLE      = "idle",
	WALKING   = "walking",
	SPRINTING = "sprinting",
	AIRBORNE  = "airborne",
	DASHING   = "dashing",
}

local StateManager = {}
StateManager.__index = StateManager

function StateManager.new()
	return setmetatable({
		current     = States.IDLE,
		_grounded    = false,
		_wasGrounded = false,
	}, StateManager)
end

-- Call once per frame. Returns the new current state.
-- input.isDashing takes highest priority — overrides grounded/airborne logic.
function StateManager:update(input, isGrounded)
	self._wasGrounded = self._grounded
	self._grounded    = isGrounded

	-- Dash overrides all other states
	if input.isDashing then
		self.current = States.DASHING
		return self.current
	end

	if not isGrounded then
		self.current = States.AIRBORNE
		return self.current
	end

	local hasInput = input.moveDirection.Magnitude > 0

	if not hasInput then
		self.current = States.IDLE
	elseif input.isSprinting then
		self.current = States.SPRINTING
	else
		self.current = States.WALKING
	end

	return self.current
end

-- True only on the frame the player lands.
function StateManager:justLanded()
	return self._grounded and not self._wasGrounded
end

function StateManager:isGrounded()
	return self._grounded
end

StateManager.States = States

return StateManager
