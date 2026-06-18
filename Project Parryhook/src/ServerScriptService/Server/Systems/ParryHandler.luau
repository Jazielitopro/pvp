-- ParryHandler (ModuleScript - server only)
-- Manages parry windows, projectile reflection, parry clashes, perfect parries,
-- and self projectile boosts.

local Players = game:GetService("Players")

local Constants = require(game.ReplicatedStorage.Shared.Constants.ParryConstants)
local WeaponConstants = require(game.ReplicatedStorage.Shared.Constants.WeaponConstants)
local ProjectileRegistry = require(script.Parent.ProjectileRegistry)
local StatsTracker = require(script.Parent.StatsTracker)

local remotes = game.ReplicatedStorage:WaitForChild("Remotes")
local parryRequest = remotes:WaitForChild("ParryRequest")
local projectileUpdated = remotes:WaitForChild("ProjectileUpdated")

-- [player] = { windowStart, windowEnd, cooldownUntil, aimDirection }
local state = {}

local function getState(player)
	if not state[player] then
		state[player] = {
			windowStart = 0,
			windowEnd = 0,
			cooldownUntil = 0,
			aimDirection = nil,
		}
	end
	return state[player]
end

local function validateAimDirection(direction)
	if typeof(direction) ~= "Vector3" then return nil end
	if direction.X ~= direction.X or direction.Y ~= direction.Y or direction.Z ~= direction.Z then return nil end
	if direction.Magnitude < 0.8 or direction.Magnitude > 1.2 then return nil end
	return direction.Unit
end

local function getFallbackAimDirection(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return root and root.CFrame.LookVector or Vector3.new(0, 0, -1)
end

local function buildFilterParams(player)
	local character = player.Character
	if not character then return nil end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	return params
end

local function classifyParry(player, projectile)
	local s = state[player]
	local elapsed = s and (os.clock() - s.windowStart) or math.huge
	local isPerfect = elapsed <= Constants.PERFECT_WINDOW
	local isClash = (projectile.reflectCount or 0) > 0

	if isPerfect and isClash then
		return "perfect_clash"
	elseif isPerfect then
		return "perfect"
	elseif isClash then
		return "clash"
	end

	return "normal"
end

local function applyParryStats(projectile, parryKind)
	projectile.reflectCount = math.min((projectile.reflectCount or 0) + 1, Constants.MAX_REFLECTS)

	local speedMult = 1
	local damageMult = 1
	if parryKind == "perfect" or parryKind == "perfect_clash" then
		speedMult *= Constants.PERFECT_SPEED_MULT
		damageMult *= Constants.PERFECT_DAMAGE_MULT
	end
	if parryKind == "clash" or parryKind == "perfect_clash" then
		speedMult *= Constants.CLASH_SPEED_MULT
		damageMult *= Constants.CLASH_DAMAGE_MULT
	end

	projectile.damage = (projectile.damage or WeaponConstants.DAMAGE_PER_HIT) * damageMult
	return speedMult
end

local function tryBoostOwnProjectile(player, aimDirection)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head then return nil end

	local now = os.clock()
	local bestProjectile = nil
	local bestDistance = math.huge

	for _, projectile in pairs(ProjectileRegistry.getAll()) do
		if projectile.owner == player and not projectile.boosted then
			local age = now - (projectile.spawnTime or now)
			local distance = (projectile.position - head.Position).Magnitude
			local canBoost = age <= Constants.SELF_BOOST_MAX_AGE
				and distance <= Constants.SELF_BOOST_RADIUS
				and distance < bestDistance
			if canBoost then
				bestProjectile = projectile
				bestDistance = distance
			end
		end
	end

	if not bestProjectile then return nil end

	bestProjectile.boosted = true
	bestProjectile.reflectCount = (bestProjectile.reflectCount or 0) + 1
	bestProjectile.damage = (bestProjectile.damage or WeaponConstants.DAMAGE_PER_HIT)
		* Constants.SELF_BOOST_DAMAGE_MULT
	bestProjectile.velocity = aimDirection.Unit * WeaponConstants.BULLET_SPEED
		* Constants.SELF_BOOST_SPEED_MULT
	bestProjectile.filterParams = buildFilterParams(player) or bestProjectile.filterParams
	StatsTracker.recordSelfBoost(player)
	projectileUpdated:FireAllClients(
		bestProjectile.id,
		player.UserId,
		bestProjectile.position,
		bestProjectile.velocity.Unit,
		bestProjectile.velocity.Magnitude,
		"self_boost"
	)
	return bestProjectile
end

local ParryHandler = {}

function ParryHandler.isParrying(player)
	local s = state[player]
	if not s then return false end
	return os.clock() < s.windowEnd
end

function ParryHandler.getParryKind(player, projectile)
	return classifyParry(player, projectile)
end

function ParryHandler.reflect(projectile, parrier, parryKind)
	if not parrier.Character then return end

	local speedMult = applyParryStats(projectile, parryKind or "normal")
	StatsTracker.recordParry(parrier, parryKind or "normal")
	projectile.velocity = -projectile.velocity.Unit * WeaponConstants.BULLET_SPEED * speedMult
	projectile.owner = parrier
	projectile.filterParams = buildFilterParams(parrier) or projectile.filterParams
	projectileUpdated:FireAllClients(
		projectile.id,
		parrier.UserId,
		projectile.position,
		projectile.velocity.Unit,
		projectile.velocity.Magnitude,
		parryKind or "normal"
	)
end

parryRequest.OnServerEvent:Connect(function(player, _clientTimestamp, aimDirection)
	local s = getState(player)
	local now = os.clock()

	if now < s.cooldownUntil then
		print(string.format("[Parry] %s tried to parry but on cooldown (%.2fs remaining)",
			player.Name, s.cooldownUntil - now))
		return
	end

	local validatedAim = validateAimDirection(aimDirection) or getFallbackAimDirection(player)

	s.windowStart = now
	s.windowEnd = now + Constants.PARRY_WINDOW
	s.cooldownUntil = now + Constants.COOLDOWN
	s.aimDirection = validatedAim

	print(string.format("[Parry] %s opened parry window (%.2fs window, %.2fs cooldown)",
		player.Name, Constants.PARRY_WINDOW, Constants.COOLDOWN))

	local boosted = tryBoostOwnProjectile(player, validatedAim)
	if boosted then
		print(string.format("[Parry] %s projectile-boosted id=%d", player.Name, boosted.id))
	end
end)

Players.PlayerRemoving:Connect(function(player)
	state[player] = nil
	print(string.format("[Parry] State cleaned up for %s", player.Name))
end)

print("[Parry] ParryHandler ready")

return ParryHandler
