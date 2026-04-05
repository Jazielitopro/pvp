-- MatchConstants
-- Shared between client and server.

return {
	SCORE_LIMIT           = 10,  -- first player to reach this kill count wins
	ROUND_DURATION        = 300, -- seconds per round (0 = no timer, kill limit only)
	MIN_PLAYERS           = 2,   -- players needed to start a match
	END_RESET_DELAY       = 5,   -- seconds showing the winner screen before intermission
	INTERMISSION_DURATION = 15,  -- seconds of intermission countdown before next round
	RESPAWN_DELAY         = 3,   -- seconds before a dead player respawns (must match HealthSystem)
}
