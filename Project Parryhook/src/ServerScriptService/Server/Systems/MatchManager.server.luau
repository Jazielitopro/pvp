-- MatchManager (Script — server only)
-- Drives the match state machine and selects the game mode automatically
-- based on how many players are connected when a round is about to start.
--
-- State machine:
--   WAITING      → not enough players; fires IntermissionTick{type="waiting"} every second
--   INTERMISSION → countdown before next round; fires IntermissionTick{type="intermission"}
--   ACTIVE       → match in progress; kill tracking, optional timer
--   ENDED        → winner found or timer expired; brief winner screen, then back to INTERMISSION
--
-- Mode selection (GameModeConfig):
--   2 players   → DUEL  (first to 5 kills, 3 min)
--   3-5 players → FFA   (first to 10 kills, 5 min)
--   6+ players  → TEAM  (2 teams, first team to 15 kills, 6 min)
--
-- Kill signal: HealthSystem.KillBind (BindableEvent) — never trusts client.

local Players      = game:GetService("Players")
local HealthSystem = require(script.Parent.HealthSystem)
local Constants    = require(game.ReplicatedStorage.Shared.Constants.MatchConstants)
local GameModes    = require(game.ReplicatedStorage.Shared.Constants.GameModeConfig)

local remotes          = game.ReplicatedStorage:WaitForChild("Remotes")
local scoreUpdated     = remotes:WaitForChild("ScoreUpdated")
local matchStarted     = remotes:WaitForChild("MatchStarted")
local matchEnded       = remotes:WaitForChild("MatchEnded")
local playerDied       = remotes:WaitForChild("PlayerDied")
local intermissionTick = remotes:WaitForChild("IntermissionTick")
local modeSelectedEvt  = remotes:WaitForChild("ModeSelected")
local teamAssignedEvt  = remotes:WaitForChild("TeamAssigned")

-- ── State ─────────────────────────────────────────────────────────────────────

local WAITING      = "WAITING"
local INTERMISSION = "INTERMISSION"
local ACTIVE       = "ACTIVE"
local ENDED        = "ENDED"

local matchState  = WAITING
local currentMode = nil    -- GameModeConfig entry for the running/upcoming round

-- Per-player kill counts  [userId] = number
local scores = {}

-- Team state (only used when currentMode.teamBased == true)
local playerTeams = {}              -- [userId] = "A" | "B"
local teamScores  = { A = 0, B = 0 }

-- Task threads (cancelled on state transitions)
local countdownThread = nil   -- intermission countdown OR waiting poll
local timerThread     = nil   -- optional round timer

-- ── Forward declarations ──────────────────────────────────────────────────────

local startMatch
local endMatch
local startIntermission
local enterWaiting

-- ── Score helpers ─────────────────────────────────────────────────────────────

local function buildScorePayload()
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		table.insert(list, {
			userId = p.UserId,
			name   = p.DisplayName,
			kills  = scores[p.UserId] or 0,
			team   = playerTeams[p.UserId],   -- nil when FFA/DUEL
		})
	end
	table.sort(list, function(a, b) return a.kills > b.kills end)
	return list, { A = teamScores.A, B = teamScores.B }
end

local function broadcastScores()
	local playerList, teams = buildScorePayload()
	scoreUpdated:FireAllClients(playerList, teams)
end

local function resetScores()
	scores     = {}
	teamScores = { A = 0, B = 0 }
	for _, p in ipairs(Players:GetPlayers()) do
		scores[p.UserId] = 0
	end
end

-- ── Team helpers ──────────────────────────────────────────────────────────────

local function assignTeams()
	playerTeams = {}
	local players = Players:GetPlayers()
	for i, p in ipairs(players) do
		-- Alternate A/B so teams are balanced in size
		local team = (i % 2 == 1) and "A" or "B"
		playerTeams[p.UserId] = team
		teamAssignedEvt:FireClient(p, team)
		print(string.format("[MatchManager]   %s → Team %s", p.DisplayName, team))
	end
end

-- ── Win-condition checker ─────────────────────────────────────────────────────

local function checkWinCondition(attacker)
	if matchState ~= ACTIVE or not currentMode then return end

	if currentMode.teamBased then
		local team = attacker and playerTeams[attacker.UserId]
		if team and (teamScores[team] or 0) >= currentMode.scoreLimit then
			endMatch(nil, team, "kill limit")
		end
	else
		if not attacker then return end
		if (scores[attacker.UserId] or 0) >= currentMode.scoreLimit then
			endMatch(attacker, nil, "kill limit")
		end
	end
end

-- ── Match lifecycle ───────────────────────────────────────────────────────────

startMatch = function()
	if matchState == ACTIVE then return end
	if countdownThread then task.cancel(countdownThread); countdownThread = nil end
	matchState = ACTIVE

	-- Select mode for this round based on current player count
	local count = #Players:GetPlayers()
	currentMode = GameModes.selectForCount(count)
	print(string.format("[MatchManager] Mode: %s | Players: %d | Limit: %d kills",
		currentMode.key, count, currentMode.scoreLimit))

	resetScores()

	if currentMode.teamBased then
		assignTeams()
	else
		playerTeams = {}
	end

	local playerList, teams = buildScorePayload()
	scoreUpdated:FireAllClients(playerList, teams)
	matchStarted:FireAllClients()
	modeSelectedEvt:FireAllClients(
		currentMode.key,
		currentMode.displayName,
		currentMode.description,
		currentMode.teamBased,
		currentMode.scoreLimit
	)

	print(string.format("[MatchManager] Match started — %s", currentMode.displayName))

	-- Optional round timer
	if currentMode.roundDuration > 0 then
		if timerThread then task.cancel(timerThread) end
		timerThread = task.delay(currentMode.roundDuration, function()
			if matchState ~= ACTIVE then return end
			-- Time expired: find winner by kill count / team score
			local winner, winnerTeam
			if currentMode.teamBased then
				winnerTeam = (teamScores.A >= teamScores.B) and "A" or "B"
			else
				local topKills = -1
				for _, p in ipairs(Players:GetPlayers()) do
					local k = scores[p.UserId] or 0
					if k > topKills then topKills = k; winner = p end
				end
			end
			endMatch(winner, winnerTeam, "time")
		end)
	end
end

endMatch = function(winner, winnerTeam, reason)
	if matchState == ENDED then return end
	matchState = ENDED
	if timerThread then task.cancel(timerThread); timerThread = nil end

	local winnerName
	if currentMode and currentMode.teamBased then
		winnerName = winnerTeam and ("Team " .. winnerTeam) or "Draw"
	else
		winnerName = winner and winner.DisplayName or "Nobody"
	end

	local playerList, teams = buildScorePayload()
	matchEnded:FireAllClients(winnerName, playerList, teams)
	print(string.format("[MatchManager] Match ended (%s). Winner: %s",
		reason or "kill limit", winnerName))

	-- Brief winner screen, then transition
	task.delay(Constants.END_RESET_DELAY, function()
		if matchState ~= ENDED then return end
		if #Players:GetPlayers() >= Constants.MIN_PLAYERS then
			startIntermission()
		else
			enterWaiting()
		end
	end)
end

startIntermission = function()
	if matchState == INTERMISSION or matchState == ACTIVE then return end
	if countdownThread then task.cancel(countdownThread); countdownThread = nil end
	matchState = INTERMISSION

	-- Pre-select mode so the client can show it during the countdown
	local count = #Players:GetPlayers()
	currentMode = GameModes.selectForCount(count)

	print(string.format("[MatchManager] Intermission (%ds) — upcoming: %s",
		Constants.INTERMISSION_DURATION, currentMode.key))

	countdownThread = task.spawn(function()
		for i = Constants.INTERMISSION_DURATION, 1, -1 do
			if matchState ~= INTERMISSION then return end
			intermissionTick:FireAllClients({
				type        = "intermission",
				secondsLeft = i,
				modeKey     = currentMode.key,
				modeName    = currentMode.displayName,
				modeDesc    = currentMode.description,
				playerCount = #Players:GetPlayers(),
				minPlayers  = Constants.MIN_PLAYERS,
			})
			task.wait(1)
		end

		if matchState ~= INTERMISSION then return end

		if #Players:GetPlayers() >= Constants.MIN_PLAYERS then
			startMatch()
		else
			enterWaiting()
		end
	end)
end

enterWaiting = function()
	if countdownThread then task.cancel(countdownThread); countdownThread = nil end
	if timerThread     then task.cancel(timerThread);     timerThread     = nil end
	matchState  = WAITING
	currentMode = nil
	print("[MatchManager] Waiting for players...")

	-- Poll every second so clients show the waiting panel
	countdownThread = task.spawn(function()
		while matchState == WAITING do
			intermissionTick:FireAllClients({
				type        = "waiting",
				secondsLeft = nil,
				playerCount = #Players:GetPlayers(),
				minPlayers  = Constants.MIN_PLAYERS,
			})
			task.wait(1)
		end
	end)
end

-- ── Kill handling ─────────────────────────────────────────────────────────────

HealthSystem.KillBind.Event:Connect(function(victim, attacker)
	if matchState ~= ACTIVE then return end

	if attacker and attacker ~= victim then
		scores[attacker.UserId] = (scores[attacker.UserId] or 0) + 1

		if currentMode and currentMode.teamBased then
			local team = playerTeams[attacker.UserId]
			if team then
				teamScores[team] = (teamScores[team] or 0) + 1
			end
		end

		print(string.format("[MatchManager] Kill: %s → %s  (kills: %d%s)",
			attacker.DisplayName,
			victim.DisplayName,
			scores[attacker.UserId],
			(currentMode and currentMode.teamBased)
				and string.format(" | Team %s: %d",
					playerTeams[attacker.UserId] or "?",
					teamScores[playerTeams[attacker.UserId] or "A"] or 0)
				or ""))
	end

	broadcastScores()
	checkWinCondition(attacker)
end)

-- ── Player lifecycle ──────────────────────────────────────────────────────────

Players.PlayerAdded:Connect(function(player)
	scores[player.UserId] = 0
	local count = #Players:GetPlayers()
	print(string.format("[MatchManager] %s joined (total: %d, state: %s)",
		player.Name, count, matchState))

	-- Start intermission as soon as MIN_PLAYERS threshold is reached from WAITING
	if matchState == WAITING and count >= Constants.MIN_PLAYERS then
		task.wait(2)  -- grace period for the joining player to finish loading
		if matchState == WAITING then
			startIntermission()
		end
	end

	-- Send current scores to the new player
	task.wait(1)
	local playerList, teams = buildScorePayload()
	scoreUpdated:FireClient(player, playerList, teams)
end)

Players.PlayerRemoving:Connect(function(player)
	scores[player.UserId]      = nil
	playerTeams[player.UserId] = nil
	local remaining = #Players:GetPlayers() - 1
	print(string.format("[MatchManager] %s left (remaining: %d, state: %s)",
		player.Name, remaining, matchState))

	if remaining < Constants.MIN_PLAYERS then
		if matchState == ACTIVE then
			if timerThread then task.cancel(timerThread); timerThread = nil end
			enterWaiting()
		elseif matchState == INTERMISSION then
			if countdownThread then task.cancel(countdownThread); countdownThread = nil end
			enterWaiting()
		end
	end
end)

-- ── Startup ───────────────────────────────────────────────────────────────────

task.wait(1)   -- let RemoteSetup finish creating all RemoteEvents first
enterWaiting()
print("[MatchManager] Ready. Min players:", Constants.MIN_PLAYERS)
