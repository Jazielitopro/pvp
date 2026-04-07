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

-- ── Ground check ──────────────────────────────────────────────────────────────
-- Uses Humanoid.FloorMaterial instead of a manual raycast.
-- The engine updates FloorMaterial every physics step, so it is always accurate
-- regardless of character scale, HipHeight, or terrain type.
-- FloorMaterial == Air  →  character is in the air
-- FloorMaterial != Air  →  character is standing on something

local function checkGrounded()
	if not currentHum then return false end
	return currentHum.FloorMaterial ~= Enum.Material.Air
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
	print("[CharacterController] Cleaning up previous character for", player.Name)
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
	print("[CharacterController] Setting up character for", player.Name)
	cleanupCharacter()

	currentChar = character
	currentHum  = character:WaitForChild("Humanoid")
	currentRoot = character:WaitForChild("HumanoidRootPart")

	currentHum.JumpPower  = 0
	currentHum.AutoRotate = false

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
		if not remotes then
			warn("[CharacterController] Remotes folder not found after 10s — DashRequest/GrappleRequest unavailable")
			return
		end
		local dr = remotes:WaitForChild("DashRequest", 10)
		if dr and dashHandler then
			dashHandler:setRemote(dr)
			print("[CharacterController] DashRequest remote connected for", player.Name)
		elseif not dr then
			warn("[CharacterController] DashRequest not found after 10s")
		end
		local gr = remotes:WaitForChild("GrappleRequest", 10)
		if gr and grappleHandler then
			grappleHandler:setRemote(gr)
			print("[CharacterController] GrappleRequest remote connected for", player.Name)
		elseif not gr then
			warn("[CharacterController] GrappleRequest not found after 10s")
		end
	end)

	cameraCtrl:start(function() return stateManager.current end)

	-- Per-character Heartbeat loop
	heartbeat = RunService.Heartbeat:Connect(function(dt)
		if not currentRoot or not currentRoot.Parent then return end

		local grounded = checkGrounded()

		if slideHandler:isSliding() then
			-- Grace window: the HipHeight change on the first sliding frame (2.0 → 0.5)
			-- causes FloorMaterial to briefly read Air on the very next frame.
			-- Suppress the airborne-cancel for the first 0.15 s so the physics settle.
			if not grounded and slideHandler:getElapsed() > 0.15 then
				slideHandler:cancel()
			else
				slideHandler:tick(dt)
			end
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
