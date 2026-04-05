-- ParryHandler (ModuleScript — server only)
-- Manages per-player parry windows and projectile reflection.
-- Called by CollisionHandler before any damage is applied.
--
-- Option B (MVP): server opens a time window on parry input.
--   Any projectile that physically hits the player during that window is reflected.
--   No extra proximity or rewind logic needed — the raycast IS the proximity check.
--
-- Option C (polish upgrade — contained here):
--   Replace isParrying() with a rewind check:
--     rewind projectile position to clientTimestamp using ProjectileRegistry history,
--     check if rewound position is within PARRY_RADIUS of the player at that time.
--   No other module needs to change.

local Players   = game:GetService("Players")
local Constants = require(game.ReplicatedStorage.Shared.Constants.ParryConstants)
local WeaponConstants = require(game.ReplicatedStorage.Shared.Constants.WeaponConstants)

local remotes      = game.ReplicatedStorage:WaitForChild("Remotes")
local parryRequest = remotes:WaitForChild("ParryRequest")
local parryEffect  = remotes:WaitForChild("ParryEffect")

-- [player] = { windowEnd: number, cooldownUntil: number }
local state = {}

local function getState(player)
	if not state[player] then
		state[player] = { windowEnd = 0, cooldownUntil = 0 }
	end
	return state[player]
end

-- ── Public API ────────────────────────────────────────────────────────────────

local ParryHandler = {}

-- Returns true if `player` currently has an active parry window.
-- Option B: pure time window check.
-- Option C upgrade: add rewind + proximity check here.
function ParryHandler.isParrying(player)
	local s = state[player]
	if not s then return false end
	return os.clock() < s.windowEnd
end

-- Reflect a projectile back toward its original owner.
-- Sets new velocity (reversed), swaps owner to parrier, updates filterParams.
-- The projectile stays in the registry — it keeps flying.
function ParryHandler.reflect(projectile, parrier)
	local character = parrier.Character
	if not character then return end

	-- Flip direction, keep same speed
	projectile.velocity    = -projectile.velocity.Unit * WeaponConstants.BULLET_SPEED
	projectile.owner       = parrier

	-- Exclude the parrier's character from future raycasts (not the original shooter)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	projectile.filterParams = params

	-- Broadcast parry VFX/SFX to all clients
	parryEffect:FireAllClients(parrier.UserId, projectile.position)
end

-- ── Incoming parry request ─────────────────────────────────────────────────────

parryRequest.OnServerEvent:Connect(function(player, _clientTimestamp)
	-- _clientTimestamp is preserved for Option C upgrade; unused in Option B.

	local s   = getState(player)
	local now = os.clock()

	if now < s.cooldownUntil then return end  -- still on cooldown

	-- Open the parry window
	s.windowEnd    = now + Constants.PARRY_WINDOW
	s.cooldownUntil = now + Constants.COOLDOWN
end)

-- ── Player lifecycle ──────────────────────────────────────────────────────────

Players.PlayerRemoving:Connect(function(player)
	state[player] = nil
end)

return ParryHandler
