-- HealthSystem (ModuleScript — server only)
-- Manages per-player HP, passive regen, and death.
-- Required by HealthBootstrap (to start lifecycle) and DamageApplicator (to apply damage).
--
-- Phase 3 hook: DamageApplicator.applyDamage() calls takeDamage().
-- Phase 6 will extend syncHealth() with screen shake / damage numbers.

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
	end
end

local function startRegen(player)
	cancelRegen(player)
	local s = getState(player)

	s.regenThread = task.delay(Constants.REGEN_DELAY, function()
		while state[player] and not s.isDead and s.hp < Constants.MAX_HEALTH do
			s.hp = math.min(s.hp + Constants.REGEN_RATE * 0.1, Constants.MAX_HEALTH)
			syncHealth(player)
			task.wait(0.1)
		end
		if state[player] then s.regenThread = nil end
	end)
end

-- ── Public API ────────────────────────────────────────────────────────────────

local HealthSystem = {}

-- Server-side kill signal. MatchManager subscribes to this.
-- Fired with (victim: Player, attacker: Player | nil) on every lethal hit.
-- BindableEvent is safe for server-to-server communication without remotes.
HealthSystem.KillBind = Instance.new("BindableEvent")

-- Returns true if the hit was lethal.
function HealthSystem.takeDamage(victim, attacker, amount)
	local s = getState(victim)
	if s.isDead then return false end

	cancelRegen(victim)

	s.hp = math.max(s.hp - amount, 0)
	syncHealth(victim)

	local isKill = s.hp <= 0

	if isKill then
		s.isDead = true
		playerDied:FireAllClients(victim, attacker)
		HealthSystem.KillBind:Fire(victim, attacker)   -- Phase 6: MatchManager listens here
		task.delay(3, function()
			if state[victim] then
				victim:LoadCharacter()
			end
		end)
	else
		startRegen(victim)
	end

	-- Notify attacker: hit landed (wasKill, victim display name)
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

		player.CharacterAdded:Connect(function()
			local s = getState(player)
			cancelRegen(player)
			s.hp     = Constants.MAX_HEALTH
			s.isDead = false

			task.wait(0.5)
			syncHealth(player)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		cancelRegen(player)
		state[player] = nil
	end)
end

return HealthSystem
