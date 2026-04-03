-- PhysicsApplier
-- Drives character movement using humanoid:Move() + dynamic WalkSpeed.
-- This works WITH Roblox's Humanoid physics instead of fighting it.
-- LinearVelocity was removed — it competed with Humanoid friction/damping.
--
-- Jump:  temporarily sets JumpPower, fires ChangeState(Jumping), resets.
-- Dash:  sets AssemblyLinearVelocity burst + WalkSpeed for sustained speed.

local Constants = require(game.ReplicatedStorage.Shared.Constants.MovementConstants)

local PhysicsApplier = {}
PhysicsApplier.__index = PhysicsApplier

function PhysicsApplier.new(rootPart, humanoid)
	return setmetatable({
		_root     = rootPart,
		_humanoid = humanoid,
	}, PhysicsApplier)
end

-- Called every frame. Extracts speed and direction from the velocity vector,
-- sets WalkSpeed, and drives direction with humanoid:Move().
function PhysicsApplier:applyVelocity(horizontalVelocity)
	local speed = horizontalVelocity.Magnitude

	self._humanoid.WalkSpeed = speed

	if speed > 0.1 then
		self._humanoid:Move(horizontalVelocity.Unit, false) -- false = world space
	else
		self._humanoid:Move(Vector3.zero, false)
	end
end

-- Jump: set JumpPower temporarily so the Humanoid fires the jump,
-- then reset to 0 so we remain in full control.
function PhysicsApplier:applyJump()
	self._humanoid.JumpPower = Constants.JUMP_FORCE
	self._humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	task.delay(0.05, function()
		self._humanoid.JumpPower = 0
	end)
end

-- Dash: direct AssemblyLinearVelocity burst for the instant impulse feel.
-- WalkSpeed is also set to DASH_SPEED via applyVelocity during DASHING state.
function PhysicsApplier:applyDash(direction)
	local current = self._root.AssemblyLinearVelocity
	self._root.AssemblyLinearVelocity = Vector3.new(
		direction.X * Constants.DASH_SPEED,
		current.Y,
		direction.Z * Constants.DASH_SPEED
	)
end

function PhysicsApplier:destroy()
	-- No constraints to destroy in this implementation
end

return PhysicsApplier
