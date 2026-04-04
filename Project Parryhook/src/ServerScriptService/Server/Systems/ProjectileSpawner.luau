-- ProjectileSpawner (ModuleScript — server only)
-- Creates and registers a projectile after WeaponSystem validates the fire request.
-- Notifies all clients so they can show the visual bullet.
--
-- direction is a unit Vector3 sent by the client (camera LookVector).
-- Server accepts it as-is; Phase 5 lag compensation will harden this further.

local Workspace          = game:GetService("Workspace")
local ProjectileRegistry = require(script.Parent.ProjectileRegistry)
local WeaponConstants    = require(game.ReplicatedStorage.Shared.Constants.WeaponConstants)

local remotes          = game.ReplicatedStorage:WaitForChild("Remotes")
local spawnProjectile  = remotes:WaitForChild("SpawnProjectile")

local ProjectileSpawner = {}

-- Validate that `direction` is a reasonable unit vector.
-- Rejects zero vectors or wildly un-normalised submissions.
local function validateDirection(dir)
	if typeof(dir) ~= "Vector3" then return false end
	local mag = dir.Magnitude
	return mag > 0.8 and mag < 1.2  -- allow small floating-point drift
end

-- Called by WeaponSystem.onFire after ammo has been consumed.
function ProjectileSpawner.onFire(player, direction)
	if not validateDirection(direction) then return end

	local character = player.Character
	if not character then return end

	local head = character:FindFirstChild("Head")
	if not head then return end

	-- Spawn origin: just in front of the head (no weapon model yet).
	-- Phase 8: swap this for the actual muzzle attachment position.
	local origin = head.Position + direction * 2.5

	local velocity = direction.Unit * WeaponConstants.BULLET_SPEED

	-- Exclude the shooter's own character from raycasts
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }

	local id = ProjectileRegistry.register({
		owner        = player,
		position     = origin,
		velocity     = velocity,
		spawnTime    = os.clock(),
		filterParams = params,
	})

	-- Tell every client: create a visual bullet
	spawnProjectile:FireAllClients(id, player.UserId, origin, direction.Unit, WeaponConstants.BULLET_SPEED)
end

return ProjectileSpawner
