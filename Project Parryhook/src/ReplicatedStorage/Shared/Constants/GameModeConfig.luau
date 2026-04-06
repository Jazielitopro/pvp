-- GameModeConfig
-- Defines each game mode that MatchManager selects automatically
-- based on connected player count when a round is about to start.
-- Shared between server (MatchManager) and client (MatchController).
--
-- Mode selection thresholds:
--   2 players         → DUEL    (1v1, first to 5 kills, 3 min)
--   3-5 players       → FFA     (free-for-all, first to 10 kills, 5 min)
--   6+ players        → TEAM    (2 teams, first team to 15 kills, 6 min)

local GameModeConfig = {

	DUEL = {
		key          = "DUEL",
		displayName  = "1v1 Duel",
		description  = "First to 5 kills wins",
		minPlayers   = 2,
		maxPlayers   = 2,
		scoreLimit   = 5,
		roundDuration = 180,   -- 3 minutes (0 = no timer)
		teamBased    = false,
		accentColor  = Color3.fromRGB(255, 200, 50),
	},

	FFA = {
		key          = "FFA",
		displayName  = "Free For All",
		description  = "First to 10 kills wins",
		minPlayers   = 3,
		maxPlayers   = 5,
		scoreLimit   = 10,
		roundDuration = 300,   -- 5 minutes
		teamBased    = false,
		accentColor  = Color3.fromRGB(240, 240, 240),
	},

	TEAM = {
		key          = "TEAM",
		displayName  = "Team Deathmatch",
		description  = "First team to 15 kills wins",
		minPlayers   = 6,
		maxPlayers   = math.huge,
		scoreLimit   = 15,
		roundDuration = 360,   -- 6 minutes
		teamBased    = true,
		accentColor  = Color3.fromRGB(80, 190, 255),
	},

}

-- ── Mode selector ─────────────────────────────────────────────────────────────
-- Returns the appropriate mode config for a given number of connected players.
-- Always returns a valid config; falls back to FFA for unexpected counts.

function GameModeConfig.selectForCount(count)
	if count <= 2 then
		return GameModeConfig.DUEL
	elseif count <= 5 then
		return GameModeConfig.FFA
	else
		return GameModeConfig.TEAM
	end
end

return GameModeConfig
