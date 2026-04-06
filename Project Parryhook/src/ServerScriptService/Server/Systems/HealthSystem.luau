-- HealthSystem (ModuleScript — server only)
-- Manages per-player HP, passive regen, and death.
-- Required by HealthBootstrap (to start lifecycle) and DamageApplicator (to apply damage).

local Players       = game:GetService("Players")
local Constants     = require(game.ReplicatedStorage.Shared.Constants.HealthConstants)

local remotes       = game.ReplicatedStorage:WaitForChild("Remotes")
local healthUpdated = remotes:WaitForChild("HealthUpdated")
local playerDied    = remotes:WaitForChild("PlayerDied")
local hitConfirmed  = remotes:WaitForChild("HitConfirmed")

-- [Player] = { hp, isDead, regenThread }
local state = {}

local function getState(player)
	if not state[player] then
		state[player] = {
			hp          = Constants.MAX_HEALTH,
			isDead      = false,
			regenThread = nil,
		}
	end
	return state[player]
end

-- ── Sync ──────────────────────────────────────────────────────────────────────

local function syncHealth(player)
	local s = getState(player)
	healthUpdated:FireClient(player, s.hp, Constants.MAX_HEALTH)
end

-- ── Regen ─────────────────────────────────────────────────────────────────────

local function cancelRegen(player)
	local s = getState(player)
	if s.regenThread then
		task.cancel(s.regenThread)
		s.regenThread = nil
		print(string.format("[Health] Regen cancelled for %s", player.Name))
	end
end

local function startRegen(player)
	cancelRegen(player)
	local s = getState(player)
	print(string.format("[Health] Regen scheduled for %s in %.1fs", player.Name, Constants.REGEN_DELAY))

	s.regenThread = task.delay(Constants.REGEN_DELAY, function()
		print(string.format("[Health] Regen active — %s (%.0f → %.0f HP)",
			player.Name, s.hp, Constants.MAX_HEALTH))
		while state[player] and not s.isDead and s.hp < Constants.MAX_HEALTH do
			s.hp = math.min(s.hp + Constants.REGEN_RATE * 0.1, Constants.MAX_HEALTH)
			syncHealth(player)
			task.wait(0.1)
		end
		if state[player] then
			s.regenThread = nil
			print(string.format("[Health] Regen complete — %s at %.0f HP", player.Name, s.hp))
		end
	end)
end

-- ── Public API ────────────────────────────────────────────────────────────────

local HealthSystem = {}

-- Server-side kill signal. MatchManager subscribes to this.
HealthSystem.KillBind = Instance.new("BindableEvent")

-- Returns true if the hit was lethal.
function HealthSystem.takeDamage(victim, attacker, amount)
	local s = getState(victim)

	if s.isDead then
		warn(string.format("[Health] takeDamage on DEAD player %s — ignored", victim.Name))
		return false
	end

	local hpBefore = s.hp
	cancelRegen(victim)
	s.hp = math.max(s.hp - amount, 0)
	syncHealth(victim)

	local isKill = s.hp <= 0

	if isKill then
		s.isDead = true
		print(string.format("[Health] *** %s KILLED by %s (%.0f → 0 HP) ***",
			victim.Name, attacker and attacker.Name or "ENV", hpBefore))
		playerDied:FireAllClients(victim, attacker)
		HealthSystem.KillBind:Fire(victim, attacker)
		task.delay(3, function()
			if state[victim] then
				print(string.format("[Health] Respawning %s...", victim.Name))
				victim:LoadCharacter()
			end
		end)
	else
		print(string.format("[Health] %s hit by %s — %.0f → %.0f HP (−%.0f)",
			victim.Name, attacker and attacker.Name or "ENV",
			hpBefore, s.hp, amount))
		startRegen(victim)
	end

	if attacker then
		hitConfirmed:FireClient(attacker, isKill, victim.DisplayName)
	end

	return isKill
end

function HealthSystem.getHP(player)
	return getState(player).hp
end

-- ── Lifecycle (called once by HealthBootstrap) ────────────────────────────────

function HealthSystem.init()
	Players.PlayerAdded:Connect(function(player)
		getState(player)
		print(string.format("[Health] State initialised for %s", player.Name))

		player.CharacterAdded:Connect(function()
			local s = getState(player)
			cancelRegen(player)
			s.hp     = Constants.MAX_HEALTH
			s.isDead = false
			print(string.format("[Health] Character added — %s reset to %.0f HP", player.Name, s.hp))

			task.wait(2)
			syncHealth(player)
			print(string.format("[Health] Synced HP for %s (%.0f / %.0f)",
				player.Name, s.hp, Constants.MAX_HEALTH))
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		cancelRegen(player)
		state[player] = nil
		print(string.format("[Health] State cleaned up for %s", player.Name))
	end)

	print("[Health] HealthSystem.init() complete")
end

return HealthSystem
