-- DashHandler
-- Manages dash execution on the client: direction lock, duration timer, cooldown.
-- Notifies the server via DashRequest RemoteEvent for validation.
-- No iframes — player can be hit freely during a dash.

local Constants = require(game.ReplicatedStorage.Shared.Constants.MovementConstants)

local DashHandler = {}
DashHandler.__index = DashHandler

function DashHandler.new(physicsApplier, dashRequestRemote)
	return setmetatable({
		_physics       = physicsApplier,
		_remote        = dashRequestRemote,
		_isDashing     = false,
		_onCooldown    = false,
		_dashDirection = Vector3.zero,
	}, DashHandler)
end

-- Returns true if a dash can be executed right now.
function DashHandler:canDash()
	return not self._isDashing and not self._onCooldown
end

-- Attempt to execute a dash.
-- moveDirection: current input direction (Vector3, may be zero)
-- cameraForward: flat camera look vector used as fallback if no input
function DashHandler:tryDash(moveDirection, cameraForward)
	if not self:canDash() then return end

	-- Lock direction at dash start: input direction or camera forward if idle
	local dir = moveDirection.Magnitude > 0 and moveDirection or cameraForward
	self._dashDirection = dir
	self._isDashing     = true

	-- Apply the burst impulse
	self._physics:applyDash(dir)

	-- Notify server: validate cooldown and open speed window
	self._remote:FireServer(dir)

	-- End dash after duration, then start cooldown
	task.delay(Constants.DASH_DURATION, function()
		self._isDashing  = false
		self._onCooldown = true
		task.delay(Constants.DASH_COOLDOWN, function()
			self._onCooldown = false
		end)
	end)
end

function DashHandler:isDashing()
	return self._isDashing
end

-- Returns the locked direction during an active dash.
function DashHandler:getDashDirection()
	return self._dashDirection
end

function DashHandler:isOnCooldown()
	return self._onCooldown
end

return DashHandler
