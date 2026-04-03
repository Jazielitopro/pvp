-- CharacterController (LocalScript)
-- Entry point for client-side movement.
-- Wires InputHandler → StateManager → MovementResolver → PhysicsApplier each frame.

local RunService      = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Players         = game:GetService("Players")

local InputHandler      = require(script.InputHandler)
local StateManager      = require(script.StateManager)
local MovementResolver  = require(script.MovementResolver)
local PhysicsApplier    = require(script.PhysicsApplier)
local DashHandler       = require(script.DashHandler)
local SlideHandler      = require(script.SlideHandler)
local CameraController  = require(script.CameraController)
local Constants         = require(game.ReplicatedStorage.Shared.Constants.MovementConstants)

local player  = Players.LocalPlayer
local camera  = workspace.CurrentCamera

-- Wait for character to be ready
local character  = player.Character or player.CharacterAdded:Wait()
local humanoid   = character:WaitForChild("Humanoid")
local rootPart   = character:WaitForChild("HumanoidRootPart")

-- Disable auto-rotation and jump — PhysicsApplier manages both dynamically
humanoid.JumpPower  = 0
humanoid.AutoRotate = false

-- Initialize modules — movement starts immediately, no blocking calls
local stateManager      = StateManager.new()
local physicsApplier    = PhysicsApplier.new(rootPart, humanoid)
local dashHandler       = DashHandler.new(physicsApplier, nil) -- remote set async below

-- Connect dash remote asynchronously so it never blocks movement startup
task.spawn(function()
	local remotes = game.ReplicatedStorage:WaitForChild("Remotes", 10)
	if not remotes then return end
	local remote = remotes:WaitForChild("DashRequest", 10)
	if remote then
		dashHandler:setRemote(remote)
	end
end)
local slideHandler      = SlideHandler.new()
local cameraController  = CameraController.new(camera, humanoid)

-- Start camera — passes a getter so CameraController always reads the latest state
cameraController:start(function()
	return stateManager.current
end)

-- Jump state
local jumpBuffered  = false
local jumpCooldown  = false

-- Ground detection via downward raycast
local groundParams = RaycastParams.new()
groundParams.FilterDescendantsInstances = { character }
groundParams.FilterType = Enum.RaycastFilterType.Exclude

local function checkGrounded()
	local result = workspace:Raycast(
		rootPart.Position,
		Vector3.new(0, -Constants.GROUND_CHECK_DIST, 0),
		groundParams
	)
	return result ~= nil
end

-- Align character Y rotation to camera yaw.
-- Only modifies rotation, NEVER position — prevents physics drift.
-- In first-person: body always faces where the camera looks.
local function alignToCamera()
	local yaw = math.atan2(-camera.CFrame.LookVector.X, -camera.CFrame.LookVector.Z)
	rootPart.CFrame = CFrame.new(rootPart.Position) * CFrame.fromEulerAnglesYXZ(0, yaw, 0)
end

-- Input events: jump, dash, slide — all handled once per press
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end

	if input.KeyCode == Enum.KeyCode.Space then
		-- Jump cancels an active slide before buffering
		if slideHandler:isSliding() then
			slideHandler:cancel()
		end
		jumpBuffered = true
	end

	if input.KeyCode == Enum.KeyCode.Q then
		local cameraForward = Vector3.new(
			camera.CFrame.LookVector.X,
			0,
			camera.CFrame.LookVector.Z
		).Unit
		dashHandler:tryDash(InputHandler.getMoveDirection(camera), cameraForward)
	end

	if input.KeyCode == Enum.KeyCode.LeftControl then
		-- Pass current state so SlideHandler enforces the SPRINTING entry rule
		slideHandler:trySlide(InputHandler.getMoveDirection(camera), stateManager.current)
	end
end)

-- Main update loop
local heartbeat = RunService.Heartbeat:Connect(function(dt)
	local grounded = checkGrounded()

	-- Advance slide timer each frame; cancel if player leaves the ground
	if slideHandler:isSliding() then
		if not grounded then
			slideHandler:cancel()
		else
			slideHandler:tick(dt)
		end
	end

	local input = {
		moveDirection  = InputHandler.getMoveDirection(camera),
		isSprinting    = InputHandler.isSprinting(),
		isDashing      = dashHandler:isDashing(),
		dashDirection  = dashHandler:getDashDirection(),
		isSliding      = slideHandler:isSliding(),
		slideDirection = slideHandler:getSlideDirection(),
		slideProgress  = slideHandler:getProgress(),
	}

	local state           = stateManager:update(input, grounded)
	local currentVelocity = rootPart.AssemblyLinearVelocity
	local horizontal      = MovementResolver.resolve(state, input, currentVelocity, dt)

	physicsApplier:applyVelocity(horizontal)

	-- Align body to camera every frame (first-person standard)
	alignToCamera()

	-- Crouch effect: lower HipHeight while sliding, restore otherwise
	if state == "sliding" then
		humanoid.HipHeight = Constants.SLIDE_HIP_HEIGHT
	else
		humanoid.HipHeight = Constants.NORMAL_HIP_HEIGHT
	end

	-- Jump: only when grounded, buffered input, and not on cooldown
	if jumpBuffered and grounded and not jumpCooldown then
		physicsApplier:applyJump() -- sets JumpPower + ChangeState internally
		jumpBuffered = false
		jumpCooldown = true
		task.delay(0.3, function()
			jumpCooldown = false
		end)
	end

	-- Clear buffer if player left the ground without jumping (walked off edge)
	if not grounded then
		jumpBuffered = false
	end
end)

-- Cleanup when character is removed (respawn)
player.CharacterRemoving:Connect(function()
	heartbeat:Disconnect()
	physicsApplier:destroy()
	cameraController:stop()
end)
