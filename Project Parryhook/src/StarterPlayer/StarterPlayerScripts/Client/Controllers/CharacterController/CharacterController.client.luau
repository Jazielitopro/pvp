-- CharacterController (LocalScript)
-- Entry point for client-side movement.
-- Supports full respawn: re-initializes every time CharacterAdded fires.
-- Each death cleans up the previous character's handlers before setting up new ones.

local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Players          = game:GetService("Players")

local InputHandler      = require(script.InputHandler)
local StateManager      = require(script.StateManager)
local MovementResolver  = require(script.MovementResolver)
local PhysicsApplier    = require(script.PhysicsApplier)
local DashHandler       = require(script.DashHandler)
local SlideHandler      = require(script.SlideHandler)
local GrappleHandler    = require(script.GrappleHandler)
local CameraController  = require(script.CameraController)
local AnimationHandler  = require(script.AnimationHandler)
local Constants         = require(game.ReplicatedStorage.Shared.Constants.MovementConstants)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- ── Per-character setup ───────────────────────────────────────────────────────
-- Called every time the character spawns (initial spawn + all respawns).
-- Returns a cleanup function that disconnects everything for that character.

local function setupCharacter(character)
	print("[CharacterController] Setting up character for", player.Name)

	local humanoid = character:WaitForChild("Humanoid")
	local rootPart = character:WaitForChild("HumanoidRootPart")

	-- Wait for RootJoint so AnimationHandler can find it
	if not rootPart:FindFirstChild("RootJoint") then
		rootPart:WaitForChild("RootJoint", 5)
	end

	humanoid.JumpPower  = 0
	humanoid.AutoRotate = false

	-- Initialise modules
	local stateManager   = StateManager.new()
	local physicsApplier = PhysicsApplier.new(rootPart, humanoid)
	local dashHandler    = DashHandler.new(physicsApplier, nil)

	-- Connect dash remote asynchronously
	task.spawn(function()
		local remotes = game.ReplicatedStorage:WaitForChild("Remotes", 10)
		if not remotes then return end
		local remote = remotes:WaitForChild("DashRequest", 10)
		if remote then dashHandler:setRemote(remote) end
	end)

	local slideHandler   = SlideHandler.new()
	local grappleHandler = GrappleHandler.new(rootPart)

	-- Connect grapple remote asynchronously
	task.spawn(function()
		local remotes = game.ReplicatedStorage:WaitForChild("Remotes", 10)
		if not remotes then return end
		local remote = remotes:WaitForChild("GrappleRequest", 10)
		if remote then grappleHandler:setRemote(remote) end
	end)

	local cameraController = CameraController.new(camera, humanoid)
	local animationHandler = AnimationHandler.new(humanoid)

	cameraController:start(function()
		return stateManager.current
	end)

	-- Jump state
	local jumpBuffered = false
	local jumpCooldown = false

	-- Ground detection
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

	local function alignToCamera()
		local yaw = math.atan2(-camera.CFrame.LookVector.X, -camera.CFrame.LookVector.Z)
		rootPart.CFrame = CFrame.new(rootPart.Position) * CFrame.fromEulerAnglesYXZ(0, yaw, 0)
	end

	-- Input events
	local inputConn = UserInputService.InputBegan:Connect(function(input, processed)
		if processed then return end

		if input.KeyCode == Enum.KeyCode.Space then
			if slideHandler:isSliding() then slideHandler:cancel() end
			jumpBuffered = true
		end

		if input.KeyCode == Enum.KeyCode.Q then
			local cameraForward = Vector3.new(
				camera.CFrame.LookVector.X,
				0,
				camera.CFrame.LookVector.Z
			).Unit
			if grappleHandler:isGrappling() then grappleHandler:cancel() end
			dashHandler:tryDash(InputHandler.getMoveDirection(camera), cameraForward)
		end

		if input.KeyCode == Enum.KeyCode.E then
			slideHandler:trySlide(InputHandler.getMoveDirection(camera), stateManager.current)
		end

		if input.KeyCode == Enum.KeyCode.F then
			grappleHandler:tryGrapple(character, camera)
		end
	end)

	-- Main heartbeat loop
	local heartbeat = RunService.Heartbeat:Connect(function(dt)
		local grounded = checkGrounded()

		if slideHandler:isSliding() then
			if not grounded then slideHandler:cancel()
			else slideHandler:tick(dt) end
		end

		if grappleHandler:isGrappling() then
			grappleHandler:tick(dt, rootPart, grounded)
		end

		local input = {
			moveDirection  = InputHandler.getMoveDirection(camera),
			isSprinting    = InputHandler.isSprinting(),
			isDashing      = dashHandler:isDashing(),
			dashDirection  = dashHandler:getDashDirection(),
			isSliding      = slideHandler:isSliding(),
			slideDirection = slideHandler:getSlideDirection(),
			slideProgress  = slideHandler:getProgress(),
			isGrappling    = grappleHandler:isGrappling(),
		}

		local state           = stateManager:update(input, grounded)
		local currentVelocity = rootPart.AssemblyLinearVelocity
		local horizontal      = MovementResolver.resolve(state, input, currentVelocity, dt)

		physicsApplier:applyVelocity(horizontal)
		animationHandler:update(state)
		alignToCamera()

		if state == "sliding" then
			humanoid.HipHeight = Constants.SLIDE_HIP_HEIGHT
		else
			humanoid.HipHeight = Constants.NORMAL_HIP_HEIGHT
		end

		if jumpBuffered and grounded and not jumpCooldown then
			physicsApplier:applyJump()
			jumpBuffered = false
			jumpCooldown = true
			task.delay(0.3, function() jumpCooldown = false end)
		end

		if not grounded then jumpBuffered = false end
	end)

	-- Return cleanup — called when this character is removed
	return function()
		heartbeat:Disconnect()
		inputConn:Disconnect()
		physicsApplier:destroy()
		cameraController:stop()
		animationHandler:destroy()
		grappleHandler:destroy()
		print("[CharacterController] Cleaned up character for", player.Name)
	end
end

-- ── Respawn loop ──────────────────────────────────────────────────────────────

local cleanup = nil

local function onCharacterAdded(character)
	-- Clean up the previous character's connections before setting up the new one
	if cleanup then
		cleanup()
		cleanup = nil
	end
	-- Small wait to ensure the character hierarchy is fully replicated
	task.wait(0.1)
	cleanup = setupCharacter(character)
end

player.CharacterAdded:Connect(onCharacterAdded)

-- Handle the character that may already exist when this script first runs
if player.Character then
	onCharacterAdded(player.Character)
end
