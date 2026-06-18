-- GrappleConstants
-- Shared between client and server. Edit values here to tune grapple feel.

return {
	MAX_RANGE        = 80,   -- studs, maximum raycast distance
	PULL_ACCEL       = 520,  -- studs/s² — acceleration toward hook each frame (was 130, felt sluggish)
	MAX_PULL_SPEED   = 130,  -- studs/s — velocity cap while grappling (was 90)
	COOLDOWN         = 1.8,  -- seconds after detach before next grapple
	MIN_DETACH_DIST  = 4,    -- studs — auto-detach when this close to hook
	MAX_DURATION     = 6,    -- seconds — force-cancel if grapple lasts too long
	SLINGSHOT_MIN_SPEED = 75,
	SLINGSHOT_MULT   = 1.14,
	SLINGSHOT_MAX_SPEED = 155,
	KEY              = Enum.KeyCode.F,
}
