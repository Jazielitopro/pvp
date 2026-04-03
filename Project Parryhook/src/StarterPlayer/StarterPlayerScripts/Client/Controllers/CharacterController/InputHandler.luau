-- InputHandler
-- Reads raw player input. Returns normalized directions and action states.
-- No game logic here — only input detection.

local UserInputService = game:GetService("UserInputService")

local InputHandler = {}

-- Returns a world-space movement direction relative to the camera.
-- Returns Vector3.zero if no directional input.
function InputHandler.getMoveDirection(camera)
	local moveX = 0
	local moveZ = 0

	if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveZ -= 1 end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveZ += 1 end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveX -= 1 end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveX += 1 end

	if moveX == 0 and moveZ == 0 then
		return Vector3.zero
	end

	-- Project input onto flat camera-relative axes
	local lookFlat = Vector3.new(
		camera.CFrame.LookVector.X,
		0,
		camera.CFrame.LookVector.Z
	).Unit

	-- right = lookFlat rotated 90° clockwise on XZ plane
	-- Fix: was (lookFlat.Z, 0, -lookFlat.X) which pointed LEFT — sign was inverted
	local right = Vector3.new(-lookFlat.Z, 0, lookFlat.X)

	return (lookFlat * -moveZ + right * moveX).Unit
end

function InputHandler.isSprinting()
	return UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
end

-- Dash key: Q. Change here to rebind.
function InputHandler.isDashPressed()
	return UserInputService:IsKeyDown(Enum.KeyCode.Q)
end

-- Slide key: LeftControl. Change here to rebind.
function InputHandler.isSlidePressed()
	return UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
end

return InputHandler
