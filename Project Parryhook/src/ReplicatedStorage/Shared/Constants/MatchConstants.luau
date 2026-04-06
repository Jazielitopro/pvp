-- MatchConstants
-- Shared between client and server.
-- Note: SCORE_LIMIT and ROUND_DURATION are now per-mode in GameModeConfig.
-- They are kept here only for backward compatibility with any system
-- that still references them directly.

return {
	-- ── Global match flow ──────────────────────────────────────────────────
	MIN_PLAYERS           = 2,   -- minimum players required to start any round
	END_RESET_DELAY       = 5,   -- seconds showing the winner screen before intermission
	INTERMISSION_DURATION = 15,  -- seconds of intermission countdown before next round
	RESPAWN_DELAY         = 3,   -- seconds before a dead player respawns (must match HealthSystem)

	-- ── Legacy (overridden by GameModeConfig per mode) ─────────────────────
	SCORE_LIMIT    = 10,
	ROUND_DURATION = 300,
}
