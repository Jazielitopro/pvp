-- MatchManager (Script — server only)
-- Drives the match state machine and score tracking.
--
-- States:
--   WAITING      — fewer than MIN_PLAYERS connected; loop polls every second
--   INTERMISSION — between rounds; countdown fires IntermissionTick to clients
--   ACTIVE       — match in progress; kill tracking + optional timer
--   ENDED        — winner found or timer expired; brief winner screen, then
--                  transitions to INTERMISSION (or WAITING if players left)
--
-- Kill signal: listens to HealthSystem.KillBind (BindableEvent) so it never
-- depends on client trust.

local Players      = game:GetService("Players")
local HealthSystem = require(script.Parent.HealthSystem)
local Constants    = require(game.ReplicatedStorage.Shared.Constants.MatchConstants)

local remotes          = game.ReplicatedStorage:WaitForChild("Remotes")
local scoreUpdated     = remotes:WaitForChild("ScoreUpdated")
local matchStarted     = remotes:WaitForChild("MatchStarted")
local matchEnded       = remotes:WaitForChild("MatchEnded")
local playerDied       = remotes:WaitForChild("PlayerDied")
local intermissionTick = remotes:WaitForChild("IntermissionTick")

-- ── State ─────────────────────────────────────────────────────────────────────

local WAITING      = "WAITING"
local INTERMISSION = "INTERMISSION"
local ACTIVE       = "ACTIVE"
local ENDED        = "ENDED"

local matchState          = WAITING
local scores              = {}   -- [userId] = killCount
local timerThread         = nil  -- task thread for round timer
local intermissionThread  = nil  -- task thread for countdown

-- ── Score helpers ─────────────────────────────────────────────────────────────

local function buildScoreList()
	local list = {}
	for _, player in ipairs(Players:GetPlayers()) do
		table.insert(list, {
			userId = player.UserId,
			name   = player.DisplayName,
			kills  = scores[player.UserId] or 0,
		})
	end
	table.sort(list, function(a, b) return a.kills > b.kills end)
	return list
end

local function broadcastScores()
	scoreUpdated:FireAllClients(buildScoreList())
end

local function resetScores()
	scores = {}
	for _, player in ipairs(Players:GetPlayers()) do
		scores[player.UserId] = 0
	end
end

-- ── Forward declarations ──────────────────────────────────────────────────────

local startIntermission  -- declared here, defined below
local endMatch

-- ── Match lifecycle ───────────────────────────────────────────────────────────

local function startMatch()
	if matchState == ACTIVE then return end
	matchState = ACTIVE
	if intermissionThread then task.cancel(intermissionThread); intermissionThread = nil end

	resetScores()
	broadcastScores()
	matchStarted:FireAllClients()
	print("[MatchManager] Match started.")

	-- Optional round timer
	if Constants.ROUND_DURATION > 0 then
		if timerThread then task.cancel(timerThread) end
		timerThread = task.delay(Constants.ROUND_DURATION, function()
			if matchState ~= ACTIVE then return end
			-- Time expired — most kills wins
			local winner  = nil
			local topKills = -1
			for _, player in ipairs(Players:GetPlayers()) do
				local k = scores[player.UserId] or 0
				if k > topKills then
					topKills = k
					winner   = player
				end
			end
			endMatch(winner, "time")
		end)
	end
end

endMatch = function(winner, reason)
	if matchState == ENDED then return end
	matchState = ENDED
	if timerThread then task.cancel(timerThread); timerThread = nil end

	local winnerName = winner and winner.DisplayName or "Nobody"
	local scoreList  = buildScoreList()

	matchEnded:FireAllClients(winnerName, scoreList)
	print(string.format("[MatchManager] Match ended (%s). Winner: %s", reason or "kill limit", winnerName))

	-- Show winner screen for END_RESET_DELAY seconds, then go to intermission
	task.delay(Constants.END_RESET_DELAY, function()
		if matchState ~= ENDED then return end
		if #Players:GetPlayers() >= Constants.MIN_PLAYERS then
			startIntermission()
		else
			matchState = WAITING
			print("[MatchManager] Waiting for players...")
		end
	end)
end

startIntermission = function()
	if matchState == INTERMISSION or matchState == ACTIVE then return end
	matchState = INTERMISSION
	print(string.format("[MatchManager] Intermission started (%ds).", Constants.INTERMISSION_DURATION))

	intermissionThread = task.spawn(function()
		for i = Constants.INTERMISSION_DURATION, 1, -1 do
			if matchState ~= INTERMISSION then return end
			intermissionTick:FireAllClients(i)
			print(string.format("[MatchManager] Intermission: %d", i))
			task.wait(1)
		end

		if matchState ~= INTERMISSION then return end

		if #Players:GetPlayers() >= Constants.MIN_PLAYERS then
			startMatch()
		else
			matchState = WAITING
			print("[MatchManager] Not enough players after intermission. Waiting...")
		end
	end)
end

local function checkWinCondition(attacker)
	if matchState ~= ACTIVE then return end
	if not attacker then return end

	local kills = scores[attacker.UserId] or 0
	if kills >= Constants.SCORE_LIMIT then
		endMatch(attacker, "kill limit")
	end
end

-- ── Kill handling ─────────────────────────────────────────────────────────────

HealthSystem.KillBind.Event:Connect(function(victim, attacker)
	if matchState ~= ACTIVE then return end

	if attacker and attacker ~= victim then
		scores[attacker.UserId] = (scores[attacker.UserId] or 0) + 1
		print(string.format("[MatchManager] Kill: %s → %s (kills: %d)",
			attacker.DisplayName, victim.DisplayName, scores[attacker.UserId]))
	end

	broadcastScores()
	checkWinCondition(attacker)
end)

-- ── Player lifecycle ──────────────────────────────────────────────────────────

Players.PlayerAdded:Connect(function(player)
	scores[player.UserId] = 0
	print(string.format("[MatchManager] Player joined: %s (total: %d, state: %s)",
		player.Name, #Players:GetPlayers(), matchState))

	-- Start intermission as soon as we hit MIN_PLAYERS (from WAITING)
	if matchState == WAITING and #Players:GetPlayers() >= Constants.MIN_PLAYERS then
		task.wait(2)  -- brief grace period for the new player to finish loading
		if matchState == WAITING then
			startIntermission()
		end
	end

	-- Send current scores to the new player
	task.wait(1)
	scoreUpdated:FireClient(player, buildScoreList())
end)

Players.PlayerRemoving:Connect(function(player)
	scores[player.UserId] = nil
	local remaining = #Players:GetPlayers() - 1
	print(string.format("[MatchManager] Player left: %s (remaining: %d, state: %s)",
		player.Name, remaining, matchState))

	if remaining < Constants.MIN_PLAYERS then
		-- Not enough players — abort whatever is running
		if matchState == ACTIVE then
			if timerThread then task.cancel(timerThread); timerThread = nil end
			matchState = WAITING
			print("[MatchManager] Not enough players. Waiting...")
		elseif matchState == INTERMISSION then
			if intermissionThread then task.cancel(intermissionThread); intermissionThread = nil end
			matchState = WAITING
			print("[MatchManager] Intermission cancelled — not enough players. Waiting...")
		end
	end
end)
