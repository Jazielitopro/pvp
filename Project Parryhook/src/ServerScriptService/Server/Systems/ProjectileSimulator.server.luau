-- ProjectileSimulator (Script — server only)
-- Authoritative simulation loop. Runs every Heartbeat.
-- Advances each projectile's position, raycasts for hits, and expires old projectiles.
--
-- Lag compensation (Phase 5): position history per player is recorded here.
-- ParryHandler (Phase 5) will query posHistory to rewind projectile positions.

local RunService         = game:GetService("RunService")
local Workspace          = game:GetService("Workspace")
local Players            = game:GetService("Players")

local ProjectileRegistry = require(script.Parent.ProjectileRegistry)
local CollisionHandler   = require(script.Parent.CollisionHandler)
local WeaponConstants    = require(game.ReplicatedStorage.Shared.Constants.WeaponConstants)

-- ── Position history for lag compensation (Phase 5) ──────────────────────────
-- [player] = array of { pos = Vector3, t = number }, newest last

local HISTORY_DURATION = 0.25  -- keep 250 ms of history
local posHistory = {}

local function recordPositions()
	local now = os.clock()

	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if not root then continue end

		if not posHistory[player] then posHistory[player] = {} end
		local hist = posHistory[player]
		table.insert(hist, { pos = root.Position, t = now })

		-- Trim entries older than HISTORY_DURATION
		while hist[1] and (now - hist[1].t) > HISTORY_DURATION do
			table.remove(hist, 1)
		end
	end
end

-- Returns the interpolated position of `player` at time `t`, or nil.
-- Used by Phase 5 ParryHandler for lag-compensated rewind.
function getHistoricalPosition(player, t)
	local hist = posHistory[player]
	if not hist or #hist == 0 then return nil end

	-- Find surrounding entries
	for i = #hist, 2, -1 do
		if hist[i - 1].t <= t and hist[i].t >= t then
			local a, b  = hist[i - 1], hist[i]
			local frac  = (t - a.t) / (b.t - a.t)
			return a.pos:Lerp(b.pos, frac)
		end
	end
	-- Clamp to earliest/latest available
	if t <= hist[1].t  then return hist[1].pos  end
	if t >= hist[#hist].t then return hist[#hist].pos end
	return nil
end

-- ── Simulation loop ───────────────────────────────────────────────────────────

RunService.Heartbeat:Connect(function(dt)
	recordPositions()

	local now = os.clock()
	local registry = ProjectileRegistry.getAll()

	for id, proj in pairs(registry) do
		-- Lifetime check
		if (now - proj.spawnTime) >= WeaponConstants.BULLET_LIFETIME then
			ProjectileRegistry.remove(id)
			continue
		end

		-- Step position
		local step    = proj.velocity * dt
		local newPos  = proj.position + step

		-- Raycast along the step
		local result = Workspace:Raycast(proj.position, step, proj.filterParams)

		if result then
			-- Hit something — hand off to CollisionHandler
			CollisionHandler.onHit(proj, result)
		else
			proj.position = newPos
		end
	end
end)

-- ── Player lifecycle ──────────────────────────────────────────────────────────

Players.PlayerRemoving:Connect(function(player)
	posHistory[player] = nil
end)
