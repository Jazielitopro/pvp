-- MovementResolver
-- Calculates the desired horizontal velocity for this frame.
-- Does NOT apply physics — that is PhysicsApplier's job.

local Constants  = require(game.ReplicatedStorage.Shared.Constants.MovementConstants)
local States     = require(script.Parent.StateManager).States

local MovementResolver = {}

function MovementResolver.resolve(state, input, currentVelocity, dt)
	local currentHorizontal = Vector3.new(currentVelocity.X, 0, currentVelocity.Z)
	local targetSpeed        = 0

	-- During dash: hold the locked direction at DASH_SPEED for the full duration.
	-- LinearVelocity maintains this — no steering, no deceleration.
	if state == States.DASHING then
		return input.dashDirection * Constants.DASH_SPEED
	end

	if state == States.WALKING then
		targetSpeed = Constants.WALK_SPEED
	elseif state == States.SPRINTING then
		targetSpeed = Constants.SPRINT_SPEED
	elseif state == States.AIRBORNE then
		-- In air: maintain current horizontal speed as base, blend in steering
		local baseSpeed = math.max(
			currentHorizontal.Magnitude,
			input.isSprinting and Constants.SPRINT_SPEED or Constants.WALK_SPEED
		)
		local steerContribution = input.moveDirection * baseSpeed * Constants.AIR_CONTROL_FACTOR
		local blended = currentHorizontal + steerContribution

		-- Clamp to prevent air acceleration beyond max speed
		local maxAirSpeed = input.isSprinting and Constants.SPRINT_SPEED or Constants.WALK_SPEED
		if blended.Magnitude > maxAirSpeed then
			blended = blended.Unit * maxAirSpeed
		end

		return blended
	end

	-- Ground movement: accelerate toward target, decelerate when no input
	local targetVelocity = input.moveDirection * targetSpeed
	local hasInput       = input.moveDirection.Magnitude > 0
	local rate           = hasInput and Constants.ACCELERATION or Constants.DECELERATION
	local alpha          = math.min(rate * dt, 1)

	return currentHorizontal:Lerp(targetVelocity, alpha)
end

return MovementResolver
