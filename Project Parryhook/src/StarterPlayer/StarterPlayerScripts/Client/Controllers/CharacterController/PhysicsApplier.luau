-- PhysicsApplier
-- Owns the LinearVelocity constraint and applies horizontal movement.
-- Y axis MaxForce is 0 so gravity acts naturally.
-- Jump is applied as a direct velocity impulse on AssemblyLinearVelocity.

local Constants = require(game.ReplicatedStorage.Shared.Constants.MovementConstants)

local PhysicsApplier = {}
PhysicsApplier.__index = PhysicsApplier

function PhysicsApplier.new(rootPart)
	-- LinearVelocity requires an Attachment. RootRigAttachment exists by default on R15.
	local attachment = rootPart:FindFirstChild("RootRigAttachment")
	assert(attachment, "PhysicsApplier: RootRigAttachment not found on HumanoidRootPart")

	local lv = Instance.new("LinearVelocity")
	lv.Attachment0           = attachment
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	lv.MaxForce              = Vector3.new(1e5, 0, 1e5) -- Y=0: gravity is untouched
	lv.VectorVelocity        = Vector3.zero
	lv.Parent                = rootPart

	return setmetatable({
		_lv   = lv,
		_root = rootPart,
	}, PhysicsApplier)
end

-- Set target horizontal velocity this frame.
function PhysicsApplier:applyVelocity(horizontalVelocity)
	self._lv.VectorVelocity = horizontalVelocity
end

-- Apply vertical jump impulse while preserving current horizontal velocity.
function PhysicsApplier:applyJump()
	local current = self._root.AssemblyLinearVelocity
	self._root.AssemblyLinearVelocity = Vector3.new(
		current.X,
		Constants.JUMP_FORCE,
		current.Z
	)
end

-- Apply horizontal dash burst while preserving current vertical velocity.
-- Direction must be a unit Vector3 on the XZ plane.
function PhysicsApplier:applyDash(direction)
	local current = self._root.AssemblyLinearVelocity
	self._root.AssemblyLinearVelocity = Vector3.new(
		direction.X * Constants.DASH_SPEED,
		current.Y,
		direction.Z * Constants.DASH_SPEED
	)
end

function PhysicsApplier:destroy()
	self._lv:Destroy()
end

return PhysicsApplier
