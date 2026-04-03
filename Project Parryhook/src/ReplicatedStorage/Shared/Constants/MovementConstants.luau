-- MovementConstants
-- Shared between client and server. Edit values here to tune feel.

return {
	-- Ground movement
	WALK_SPEED          = 16,   -- studs/s
	SPRINT_SPEED        = 28,   -- studs/s
	ACCELERATION        = 60,   -- studs/s² toward target speed on ground
	DECELERATION        = 80,   -- studs/s² when no input on ground

	-- Jump
	JUMP_FORCE          = 50,   -- studs/s upward impulse

	-- Air
	AIR_CONTROL_FACTOR  = 0.4,  -- 0 = no air control, 1 = full control

	-- Dash
	DASH_SPEED          = 80,   -- studs/s burst velocity
	DASH_DURATION       = 0.18, -- seconds the dash burst lasts
	DASH_COOLDOWN       = 0.85, -- seconds before next dash is allowed

	-- Physics / detection
	GROUND_CHECK_DIST   = 2.5,  -- raycast length downward from RootPart
	MAX_SPEED_TOLERANCE = 1.5,  -- server validator: multiplier above SPRINT_SPEED before correcting
}
