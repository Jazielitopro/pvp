-- WeaponSystem (Script — server only)
-- Single source of truth for all weapon state.
-- Client NEVER owns ammo count — every change originates here.
--
-- Phase 2 scope: ammo counter, fire validation, reload timer.
-- Phase 3 will add: ProjectileSpawner call inside onFire().

local Players  = game:GetService("Players")
local Constants = require(game.ReplicatedStorage.Shared.Constants.WeaponConstants)

local remotes       = game.ReplicatedStorage:WaitForChild("Remotes")
local fireRequest   = remotes:WaitForChild("FireRequest")
local reloadRequest = remotes:WaitForChild("ReloadRequest")
local ammoUpdated   = remotes:WaitForChild("AmmoUpdated")

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

fireRequest.OnServerEvent:Connect(function(player)
	local s   = getState(player)
	local now = os.clock()

	-- Validation
	if s.isReloading                              then return end
	if s.ammo <= 0                                then return end
	if (now - s.lastFireTime) < Constants.FIRE_COOLDOWN then return end

	-- Consume one bullet
	s.ammo         -= 1
	s.lastFireTime  = now

	syncAmmo(player)

	-- ── Phase 3 hook ─────────────────────────────────────────────────────
	-- ProjectileSpawner.onFire(player) will be called here.
	-- ─────────────────────────────────────────────────────────────────────
end)

-- ── Reload ────────────────────────────────────────────────────────────────────

reloadRequest.OnServerEvent:Connect(function(player)
	local s = getState(player)

	-- Validation
	if s.isReloading               then return end
	if s.ammo >= Constants.MAX_AMMO then return end

	s.isReloading = true
	syncAmmo(player) -- tell client reload has started

	task.delay(Constants.RELOAD_TIME, function()
		-- Guard against player leaving mid-reload
		if not state[player] then return end
		s.ammo        = Constants.MAX_AMMO
		s.isReloading = false
		syncAmmo(player) -- tell client reload finished
	end)
end)

-- ── Player lifecycle ──────────────────────────────────────────────────────────

Players.PlayerAdded:Connect(function(player)
	getState(player) -- initialise state early

	player.CharacterAdded:Connect(function()
		-- Reset ammo on each spawn
		local s       = getState(player)
		s.ammo        = Constants.MAX_AMMO
		s.isReloading = false

		-- Brief wait for the client WeaponController to finish initialising
		task.wait(0.5)
		syncAmmo(player)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	state[player] = nil
end)
