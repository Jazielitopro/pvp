-- WeaponSystem (Script — server only)
-- Single source of truth for all weapon state.
-- Client NEVER owns ammo count — every change originates here.
--
-- Phase 2 scope: ammo counter, fire validation, reload timer.
-- Phase 3 will add: ProjectileSpawner call inside onFire().

local Players           = game:GetService("Players")
local Constants         = require(game.ReplicatedStorage.Shared.Constants.WeaponConstants)
local ProjectileSpawner = require(script.Parent.ProjectileSpawner)

local remotes       = game.ReplicatedStorage:WaitForChild("Remotes")
local fireRequest   = remotes:WaitForChild("FireRequest")
local reloadRequest = remotes:WaitForChild("ReloadRequest")
local ammoUpdated   = remotes:WaitForChild("AmmoUpdated")
local ammoStateRequested = remotes:WaitForChild("AmmoStateRequested")

-- [Player] = { ammo, isReloading, lastFireTime }
local state = {}

local function getState(player)
	if not state[player] then
		state[player] = {
			ammo         = Constants.MAX_AMMO,
			isReloading  = false,
			lastFireTime = 0,
		}
	end
	return state[player]
end

-- Push current ammo state to the owning client (display only).
local function syncAmmo(player)
	local s = getState(player)
	ammoUpdated:FireClient(player, s.ammo, s.isReloading)
end

-- ── Fire ──────────────────────────────────────────────────────────────────────

-- direction is the client's camera LookVector (unit Vector3).
-- ProjectileSpawner validates it before use.
fireRequest.OnServerEvent:Connect(function(player, direction)
	local s   = getState(player)
	local now = os.clock()

	-- Validation
	if s.isReloading then
		print(string.format("[Weapon] %s fired while reloading — blocked", player.Name))
		return
	end
	if s.ammo <= 0 then
		print(string.format("[Weapon] %s fired with 0 ammo — blocked", player.Name))
		return
	end
	local cooldownLeft = Constants.FIRE_COOLDOWN - (now - s.lastFireTime)
	if cooldownLeft > 0 then
		print(string.format("[Weapon] %s fired too fast — blocked (%.3fs remaining)", player.Name, cooldownLeft))
		return
	end

	-- Consume one bullet
	s.ammo         -= 1
	s.lastFireTime  = now

	local spawned = ProjectileSpawner.onFire(player, direction)
	if not spawned then
		s.ammo += 1
		syncAmmo(player)
		return
	end

	print(string.format("[Weapon] %s fired → %d / %d ammo remaining",
		player.Name, s.ammo, Constants.MAX_AMMO))

	syncAmmo(player)

end)

-- ── Reload ────────────────────────────────────────────────────────────────────

reloadRequest.OnServerEvent:Connect(function(player)
	local s = getState(player)

	-- Validation
	if s.isReloading then
		print(string.format("[Weapon] %s reload ignored — already reloading", player.Name))
		return
	end
	if s.ammo >= Constants.MAX_AMMO then
		print(string.format("[Weapon] %s reload ignored — ammo full (%d/%d)", player.Name, s.ammo, Constants.MAX_AMMO))
		return
	end

	s.isReloading = true
	print(string.format("[Weapon] %s reloading... (%.1fs)", player.Name, Constants.RELOAD_TIME))
	syncAmmo(player) -- tell client reload has started

	task.delay(Constants.RELOAD_TIME, function()
		-- Guard against player leaving mid-reload
		if not state[player] then return end
		s.ammo        = Constants.MAX_AMMO
		s.isReloading = false
		print(string.format("[Weapon] %s reload complete (%d / %d)",
			player.Name, s.ammo, Constants.MAX_AMMO))
		syncAmmo(player) -- tell client reload finished
	end)
end)

-- ── Player lifecycle ──────────────────────────────────────────────────────────

ammoStateRequested.OnServerEvent:Connect(function(player)
	syncAmmo(player)
end)

Players.PlayerAdded:Connect(function(player)
	getState(player) -- initialise state early
	print(string.format("[Weapon] State created for %s", player.Name))

	player.CharacterAdded:Connect(function()
		-- Reset ammo on each spawn
		local s       = getState(player)
		s.ammo        = Constants.MAX_AMMO
		s.isReloading = false
		print(string.format("[Weapon] %s character spawned — ammo reset to %d",
			player.Name, Constants.MAX_AMMO))

		syncAmmo(player)
		print(string.format("[Weapon] Synced ammo for %s (%d / %d)",
			player.Name, s.ammo, Constants.MAX_AMMO))
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	state[player] = nil
	print(string.format("[Weapon] State cleaned up for %s", player.Name))
end)

print("[Weapon] WeaponSystem ready")
