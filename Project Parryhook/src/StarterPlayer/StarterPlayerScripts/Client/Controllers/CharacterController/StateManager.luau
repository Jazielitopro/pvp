-- StateManager
-- Tracks the player's current movement state.
-- Step 1 states: IDLE, WALKING, SPRINTING, AIRBORNE
-- Dash and Slide states will be added in Steps 2 and 3.

local States = {
	IDLE      = "idle",
	WALKING   = "walking",
	SPRINTING = "sprinting",
	AIRBORNE  = "airborne",
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
function StateManager:update(input, isGrounded)
	self._wasGrounded = self._grounded
	self._grounded    = isGrounded

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
