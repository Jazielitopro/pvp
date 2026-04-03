-- CharacterValidator (Script — server only)
-- Tracks player positions each frame and teleports back anyone moving
-- faster than the allowed maximum. Runs silently — no client notification.
-- Handles DashRequest: validates cooldown and opens a speed window so the
-- dash burst is not incorrectly flagged as a cheat.

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local Constants  = require(game.ReplicatedStorage.Shared.Constants.MovementConstants)

local MAX_ALLOWED_SPEED = Constants.SPRINT_SPEED * Constants.MAX_SPEED_TOLERANCE

-- [Player] = { position: Vector3, timestamp: number }
local lastValid = {}

-- [Player] = expiry os.clock() timestamp while dash speed window is open
local dashWindows = {}

-- [Player] = os.clock() of last server-validated dash (server-side cooldown)
local dashCooldowns = {}

-- DashRequest handler
local remotes    = game.ReplicatedStorage:WaitForChild("Remotes")
local dashRequest = remotes:WaitForChild("DashRequest")

dashRequest.OnServerEvent:Connect(function(player, direction)
	-- Validate direction is a unit vector on the XZ plane (reject spoofed values)
	if typeof(direction) ~= "Vector3" then return end
	if direction.Magnitude < 0.9 or direction.Magnitude > 1.1 then return end
	if math.abs(direction.Y) > 0.1 then return end

	local now = os.clock()

	-- Enforce server-side cooldown
	local lastDash = dashCooldowns[player]
	if lastDash and (now - lastDash) < Constants.DASH_COOLDOWN then return end

	-- Record cooldown and open speed window for the dash duration + small buffer
	dashCooldowns[player] = now
	dashWindows[player]   = now + Constants.DASH_DURATION + 0.1
end)

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

	-- Skip speed check during an active server-validated dash window
	local dashExpiry = dashWindows[player]
	local inDashWindow = dashExpiry and now < dashExpiry

	if speed > MAX_ALLOWED_SPEED and not inDashWindow then
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
	lastValid[player]     = nil
	dashWindows[player]   = nil
	dashCooldowns[player] = nil
end)
