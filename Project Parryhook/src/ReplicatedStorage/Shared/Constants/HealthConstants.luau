-- HealthConstants
-- Shared between client and server.

return {
	MAX_HEALTH  = 100,  -- starting and cap HP

	-- Passive regen — starts after no damage for REGEN_DELAY seconds
	REGEN_DELAY = 4.0,  -- seconds before regen begins
	REGEN_RATE  = 8,    -- HP per second while regenerating
}
