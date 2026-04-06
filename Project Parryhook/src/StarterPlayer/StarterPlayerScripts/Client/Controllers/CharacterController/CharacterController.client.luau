-- CharacterController (LocalScript)
-- Entry point for client-side movement.
-- Single InputBegan connection (never recreated). Handlers stored as upvalues
-- and replaced on each CharacterAdded so respawn works correctly.

local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Players          = game:GetService("Players")

local InputHandler     = require(script.InputHandler)
local StateManager     = require(script.StateManager)
local MovementResolver = require(script.MovementResolver)
local PhysicsApplier   = require(script.PhysicsApplier)
local DashHandler      = require(script.DashHandler)
local SlideHandler     = require(script.SlideHandler)
local GrappleHandler   = require(script.GrappleHandler)
local CameraController = require(script.CameraController)
local AnimationHandler = require(script.AnimationHandler)
local Constants        = require(game.ReplicatedStorage.Shared.Constants.MovementConstants)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- ── Upvalues (replaced every respawn, read by the global InputBegan) ──────────

local heartbeat      = nil
local stateManager   = nil
local physicsApplier = nil
local dashHandler    = nil
local slideHandler   = nil
local grappleHandler = nil
local cameraCtrl     = nil
local animHandler    = nil
local currentChar    = nil
local currentHum     = nil
local currentRoot    = nil
local jumpBuffered   = false
local jumpCooldown   = false

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude

-- ── Ground check ──────────────────────────────────────────────────────────────

local function checkGrounded()
	if not currentRoot then return false end
	return workspace:Raycast(
		currentRoot.Position,
		Vector3.new(0, -Constants.GROUND_CHECK_DIST, 0),
		groundParams
	) ~= nil
end

-- ── Camera align ──────────────────────────────────────────────────────────────

local function alignToCamera()
	if not currentRoot then return end
	local yaw = math.atan2(-camera.CFrame.LookVector.X, -camera.CFrame.LookVector.Z)
	currentRoot.CFrame = CFrame.new(currentRoot.Position) * CFrame.fromEulerAnglesYXZ(0, yaw, 0)
end

-- ── Single global InputBegan (never disconnected or recreated) ────────────────
-- Reads current handlers through upvalues — safe across all respawns.

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if not currentHum then return end   -- guard: no character loaded yet

	if input.KeyCode == Enum.KeyCode.Space then
		if slideHandler and slideHandler:isSliding() then slideHandler:cancel() end
		jumpBuffered = true
	end

	if input.KeyCode == Enum.KeyCode.Q then
		if dashHandler and grappleHandler then
			local camFwd = Vector3.new(
				camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z
			).Unit
			if grappleHandler:isGrappling() then grappleHandler:cancel() end
			dashHandler:tryDash(InputHandler.getMoveDirection(camera), camFwd)
		end
	end

	if input.KeyCode == Enum.KeyCode.E then
		if slideHandler and stateManager then
			slideHandler:trySlide(InputHandler.getMoveDirection(camera), stateManager.current)
		end
	end

	if input.KeyCode == Enum.KeyCode.F then
		if grappleHandler and currentChar then
			grappleHandler:tryGrapple(currentChar, camera)
		end
	end
end)

-- ── Character setup / teardown ────────────────────────────────────────────────

local function cleanupCharacter()
	if heartbeat      then heartbeat:Disconnect();   heartbeat      = nil end
	if cameraCtrl     then cameraCtrl:stop();         cameraCtrl     = nil end
	if animHandler    then animHandler:destroy();      animHandler    = nil end
	if grappleHandler then grappleHandler:destroy();   grappleHandler = nil end
	if physicsApplier then physicsApplier:destroy();   physicsApplier = nil end
	stateManager  = nil
	dashHandler   = nil
	slideHandler  = nil
	currentChar   = nil
	currentHum    = nil
	currentRoot   = nil
	jumpBuffered  = false
	jumpCooldown  = false
end

local function setupCharacter(character)
	cleanupCharacter()

	currentChar = character
	currentHum  = character:WaitForChild("Humanoid")
	currentRoot = character:WaitForChild("HumanoidRootPart")

	-- Wait for RootJoint so AnimationHandler can find it without warning
	if not currentRoot:FindFirstChild("RootJoint") then
		currentRoot:WaitForChild("RootJoint", 5)
	end

	currentHum.JumpPower  = 0
	currentHum.AutoRotate = false

	groundParams.FilterDescendantsInstances = { character }

	-- Build handlers for this character
	stateManager   = StateManager.new()
	physicsApplier = PhysicsApplier.new(currentRoot, currentHum)
	dashHandler    = DashHandler.new(physicsApplier, nil)
	slideHandler   = SlideHandler.new()
	grappleHandler = GrappleHandler.new(currentRoot)
	cameraCtrl     = CameraController.new(camera, currentHum)
	animHandler    = AnimationHandler.new(currentHum)

	-- Connect remotes asynchronously (don't block movement startup)
	task.spawn(function()
		local remotes = game.ReplicatedStorage:WaitForChild("Remotes", 10)
		if not remotes then return end
		local dr = remotes:WaitForChild("DashRequest", 10)
		if dr and dashHandler    then dashHandler:setRemote(dr) end
		local gr = remotes:WaitForChild("GrappleRequest", 10)
		if gr and grappleHandler then grappleHandler:setRemote(gr) end
	end)

	cameraCtrl:start(function() return stateManager.current end)

	-- Per-character Heartbeat loop
	heartbeat = RunService.Heartbeat:Connect(function(dt)
		if not currentRoot or not currentRoot.Parent then return end

		local grounded = checkGrounded()

		if slideHandler:isSliding() then
			if not grounded then slideHandler:cancel()
			else slideHandler:tick(dt) end
		end

		if grappleHandler:isGrappling() then
			grappleHandler:tick(dt, currentRoot, grounded)
		end

		local inp = {
			moveDirection  = InputHandler.getMoveDirection(camera),
			isSprinting    = InputHandler.isSprinting(),
			isDashing      = dashHandler:isDashing(),
			dashDirection  = dashHandler:getDashDirection(),
			isSliding      = slideHandler:isSliding(),
			slideDirection = slideHandler:getSlideDirection(),
			slideProgress  = slideHandler:getProgress(),
			isGrappling    = grappleHandler:isGrappling(),
		}

		local state      = stateManager:update(inp, grounded)
		local curVel     = currentRoot.AssemblyLinearVelocity
		local horizontal = MovementResolver.resolve(state, inp, curVel, dt)

		-- During grapple the LinearVelocity constraint owns physics entirely.
		-- Calling applyVelocity would set WalkSpeed=0 and humanoid:Move(zero),
		-- which tells the Humanoid to brake — fighting the constraint.
		if not inp.isGrappling then
			physicsApplier:applyVelocity(horizontal)
		end
		animHandler:update(state)
		alignToCamera()

		if state == "sliding" then
			currentHum.HipHeight = Constants.SLIDE_HIP_HEIGHT
		else
			currentHum.HipHeight = Constants.NORMAL_HIP_HEIGHT
		end

		if jumpBuffered and grounded and not jumpCooldown then
			physicsApplier:applyJump()
			jumpBuffered = false
			jumpCooldown = true
			task.delay(0.3, function() jumpCooldown = false end)
		end

		if not grounded then jumpBuffered = false end
	end)

	print("[CharacterController] Ready —", player.Name)
end

-- ── Lifecycle ─────────────────────────────────────────────────────────────────

player.CharacterAdded:Connect(setupCharacter)

-- Handle character that already exists when this script first runs
if player.Character then
	setupCharacter(player.Character)
end
