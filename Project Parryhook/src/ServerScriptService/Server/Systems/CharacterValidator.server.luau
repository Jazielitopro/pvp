-- CharacterValidator (Script — server only)
-- Tracks player positions each frame and teleports back anyone moving
-- faster than the allowed maximum. Runs silently — no client notification.
-- Handles DashRequest: validates cooldown and opens a speed window so the
-- dash burst is not incorrectly flagged as a cheat.
-- Handles GrappleRequest: opens a speed window for the entire grapple
-- duration so the LinearVelocity pull is not flagged as a cheat.
-- Resets position baseline on CharacterAdded to prevent false violations
-- caused by the respawn teleport.

local Players         = game:GetService("Players")
local RunService      = game:GetService("RunService")
local Workspace       = game:GetService("Workspace")
local Constants       = require(game.ReplicatedStorage.Shared.Constants.MovementConstants)
local GrappleConstants = require(game.ReplicatedStorage.Shared.Constants.GrappleConstants)
local StatsTracker    = require(script.Parent.StatsTracker)

local MAX_ALLOWED_SPEED = Constants.SPRINT_SPEED * Constants.MAX_SPEED_TOLERANCE
local MAX_GRAPPLE_CAMERA_OFFSET = 24
local GRAPPLE_POST_WINDOW = 2.0

-- [Player] = { position: Vector3, timestamp: number }
local lastValid = {}

-- [Player] = expiry os.clock() timestamp while dash speed window is open
local dashWindows = {}

-- [Player] = expiry os.clock() timestamp while grapple speed window is open
local grappleWindows = {}

-- [Player] = os.clock() of last server-validated dash (server-side cooldown)
local dashCooldowns = {}

-- [Player] = os.clock() of last server-validated grapple (server-side cooldown)
local grappleCooldowns = {}

-- [Player] = true while the server has accepted a grapple start without an end.
local activeGrapples = {}

-- DashRequest / GrappleRequest handlers
local remotes      = game.ReplicatedStorage:WaitForChild("Remotes")
local dashRequest  = remotes:WaitForChild("DashRequest")
local grappleRequest = remotes:WaitForChild("GrappleRequest")
local grappleResult = remotes:WaitForChild("GrappleResult")
local grappleEnded = remotes:WaitForChild("GrappleEnded")

local function isPlayerCharacter(instance)
	local ancestor = instance
	while ancestor do
		if ancestor:IsA("Model") and Players:GetPlayerFromCharacter(ancestor) then
			return true
		end
		ancestor = ancestor.Parent
	end
	return false
end

local function validateGrappleAttachPoint(player, attachPoint)
	if typeof(attachPoint) ~= "Vector3" then
		return false, "non-Vector3 attach point"
	end

	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not head or not root then
		return false, "missing character parts"
	end

	local offset = attachPoint - head.Position
	local distance = offset.Magnitude
	if distance <= 0 or distance > GrappleConstants.MAX_RANGE + 4 then
		return false, string.format("attach point out of range (%.1f)", distance)
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }

	local result = Workspace:Raycast(head.Position, offset, params)
	if not result then
		return false, "server raycast missed"
	end

	if isPlayerCharacter(result.Instance) then
		return false, "hit a player character"
	end

	if (result.Position - attachPoint).Magnitude > 5 then
		return false, "attach point does not match server raycast"
	end

	if (result.Position - root.Position).Magnitude > GrappleConstants.MAX_RANGE + 8 then
		return false, "root too far from attach point"
	end

	return true
end

local function sendGrappleResult(player, requestId, accepted, attachPoint, reason)
	grappleResult:FireClient(player, requestId, accepted, attachPoint or Vector3.zero, reason or "")
end

local function validateGrappleRequest(player, origin, direction, clientAttachPoint)
	if typeof(origin) ~= "Vector3" then
		return false, "non-Vector3 ray origin"
	end
	if typeof(direction) ~= "Vector3" then
		return false, "non-Vector3 ray direction"
	end
	if direction.Magnitude < 0.8 or direction.Magnitude > 1.2 then
		return false, string.format("bad ray direction magnitude=%.3f", direction.Magnitude)
	end
	if clientAttachPoint ~= nil and typeof(clientAttachPoint) ~= "Vector3" then
		return false, "non-Vector3 client attach point"
	end

	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not head or not root then
		return false, "missing character parts"
	end

	if (origin - head.Position).Magnitude > MAX_GRAPPLE_CAMERA_OFFSET then
		return false, "ray origin too far from character"
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }

	local result = Workspace:Raycast(origin, direction.Unit * GrappleConstants.MAX_RANGE, params)
	if not result then
		return false, "server raycast missed"
	end

	if isPlayerCharacter(result.Instance) then
		return false, "hit a player character"
	end

	if clientAttachPoint and (result.Position - clientAttachPoint).Magnitude > 7 then
		return false, "client attach point does not match server raycast"
	end

	if (result.Position - root.Position).Magnitude > GrappleConstants.MAX_RANGE + 8 then
		return false, "root too far from attach point"
	end

	return true, nil, result.Position
end

local function getHorizontalSpeed(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return 0
	end

	local velocity = root.AssemblyLinearVelocity
	return Vector3.new(velocity.X, 0, velocity.Z).Magnitude
end

dashRequest.OnServerEvent:Connect(function(player, direction)
	-- Validate direction is a unit vector on the XZ plane (reject spoofed values)
	if typeof(direction) ~= "Vector3" then
		warn(string.format("[Validator] %s sent non-Vector3 dash direction — rejected", player.Name))
		return
	end
	if direction.Magnitude < 0.9 or direction.Magnitude > 1.1 then
		warn(string.format("[Validator] %s sent bad dash direction magnitude=%.3f — rejected",
			player.Name, direction.Magnitude))
		return
	end
	if math.abs(direction.Y) > 0.1 then
		warn(string.format("[Validator] %s sent vertical dash (Y=%.3f) — rejected",
			player.Name, direction.Y))
		return
	end

	local now = os.clock()

	-- Enforce server-side cooldown
	local lastDash = dashCooldowns[player]
	if lastDash and (now - lastDash) < Constants.DASH_COOLDOWN then
		print(string.format("[Validator] %s dash on cooldown (%.2fs remaining) — rejected",
			player.Name, Constants.DASH_COOLDOWN - (now - lastDash)))
		return
	end

	-- Record cooldown and open speed window for dash duration + momentum bleed-off.
	-- 0.1 s was too short — dash velocity (75 studs/s) takes ~0.5 s to decay below
	-- the validator threshold, so violations fired immediately after the window closed.
	dashCooldowns[player] = now
	dashWindows[player]   = now + Constants.DASH_DURATION + 0.5
	print(string.format("[Validator] %s dash accepted — speed window open for %.2fs",
		player.Name, Constants.DASH_DURATION + 0.5))
end)

-- Grapple speed window: validate the requested hook before allowing speed bursts.
grappleRequest.OnServerEvent:Connect(function(player, requestId, origin, direction, clientAttachPoint)
	local now = os.clock()

	if typeof(requestId) ~= "number" then
		warn(string.format("[Validator] %s sent grapple without numeric request id — rejected", player.Name))
		return
	end

	if activeGrapples[player] then
		print(string.format("[Validator] %s grapple already active — rejected", player.Name))
		sendGrappleResult(player, requestId, false, nil, "grapple already active")
		return
	end

	local lastGrapple = grappleCooldowns[player]
	if lastGrapple and (now - lastGrapple) < GrappleConstants.COOLDOWN then
		print(string.format("[Validator] %s grapple on cooldown (%.2fs remaining) — rejected",
			player.Name, GrappleConstants.COOLDOWN - (now - lastGrapple)))
		sendGrappleResult(player, requestId, false, nil, "grapple on cooldown")
		return
	end

	local ok, reason, canonicalAttachPoint = validateGrappleRequest(player, origin, direction, clientAttachPoint)
	if not ok then
		warn(string.format("[Validator] %s grapple rejected — %s", player.Name, reason))
		sendGrappleResult(player, requestId, false, nil, reason)
		return
	end

	local windowLen = GrappleConstants.MAX_DURATION + 2
	activeGrapples[player] = true
	grappleWindows[player] = now + windowLen
	task.delay(windowLen, function()
		if activeGrapples[player] and grappleWindows[player] and os.clock() >= grappleWindows[player] then
			activeGrapples[player] = nil
			grappleCooldowns[player] = os.clock()
		end
	end)
	sendGrappleResult(player, requestId, true, canonicalAttachPoint, nil)
	print(string.format("[Validator] %s grapple started — speed window open for %.1fs",
		player.Name, windowLen))
end)

grappleEnded.OnServerEvent:Connect(function(player, didSlingshot)
	if not activeGrapples[player] then
		return
	end

	local now = os.clock()
	activeGrapples[player] = nil
	grappleCooldowns[player] = now
	grappleWindows[player] = now + GRAPPLE_POST_WINDOW
	if didSlingshot == true then
		task.delay(0.08, function()
			local horizontalSpeed = getHorizontalSpeed(player)
			if horizontalSpeed >= GrappleConstants.SLINGSHOT_MIN_SPEED then
				StatsTracker.recordGrappleSlingshot(player)
			else
				print(string.format("[Validator] %s slingshot claim rejected (%.1f < %.1f)",
					player.Name, horizontalSpeed, GrappleConstants.SLINGSHOT_MIN_SPEED))
			end
		end)
	end
	print(string.format("[Validator] %s grapple ended — speed window closing", player.Name))
end)

-- ── Respawn baseline reset ────────────────────────────────────────────────────
-- When a character respawns it teleports from the death position to the spawn
-- point in one frame, producing a huge apparent speed.  Clearing lastValid
-- forces validate() to establish a fresh baseline at the new spawn position.

local function connectCharacterAdded(player)
	player.CharacterAdded:Connect(function()
		lastValid[player] = nil
		print(string.format("[Validator] %s character spawned — position baseline reset", player.Name))
	end)
end

Players.PlayerAdded:Connect(connectCharacterAdded)

for _, player in Players:GetPlayers() do
	connectCharacterAdded(player)
end

local function validate(player)
	local character = player.Character
	if not character then return end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	local now     = os.clock()
	local current = rootPart.Position

	local record = lastValid[player]
	if not record then
		lastValid[player] = { position = current, timestamp = now }
		return
	end

	local dt = now - record.timestamp
	if dt <= 0 then return end

	local speed = (current - record.position).Magnitude / dt

	-- Skip speed check during an active server-validated dash or grapple window
	local dashExpiry    = dashWindows[player]
	local grappleExpiry = grappleWindows[player]
	local inSpeedWindow = (dashExpiry    and now < dashExpiry)
	                   or (grappleExpiry and now < grappleExpiry)

	if speed > MAX_ALLOWED_SPEED and not inSpeedWindow then
		warn(string.format("[Validator] %s speed violation — %.1f studs/s > %.1f max — reset to last valid",
			player.Name, speed, MAX_ALLOWED_SPEED))
		-- Return to last valid position without touching Y (preserve fall state)
		rootPart.CFrame = CFrame.new(
			record.position.X,
			rootPart.Position.Y,
			record.position.Z
		)
		-- Do not update record — keep last valid position as the reference
		return
	end

	lastValid[player] = { position = current, timestamp = now }
end

RunService.Heartbeat:Connect(function()
	for _, player in Players:GetPlayers() do
		validate(player)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	lastValid[player]      = nil
	dashWindows[player]    = nil
	grappleWindows[player] = nil
	dashCooldowns[player]  = nil
	grappleCooldowns[player] = nil
	activeGrapples[player] = nil
	print(string.format("[Validator] Cleaned up state for %s", player.Name))
end)

print(string.format("[Validator] CharacterValidator running — MAX_SPEED=%.1f studs/s", MAX_ALLOWED_SPEED))
