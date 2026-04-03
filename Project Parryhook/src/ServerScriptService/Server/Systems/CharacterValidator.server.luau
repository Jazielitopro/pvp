-- CharacterValidator (Script — server only)
-- Tracks player positions each frame and teleports back anyone moving
-- faster than the allowed maximum. Runs silently — no client notification.

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local Constants  = require(game.ReplicatedStorage.Shared.Constants.MovementConstants)

local MAX_ALLOWED_SPEED = Constants.SPRINT_SPEED * Constants.MAX_SPEED_TOLERANCE

-- [Player] = { position: Vector3, timestamp: number }
local lastValid = {}

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

	if speed > MAX_ALLOWED_SPEED then
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
	lastValid[player] = nil
end)
