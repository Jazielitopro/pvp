-- GrappleConstants
-- Shared between client and server. Edit values here to tune grapple feel.

return {
	MAX_RANGE       = 80,    -- studs, maximum raycast distance
	PULL_ACCEL      = 130,   -- studs/s² — acceleration toward hook each frame
	MAX_PULL_SPEED  = 90,    -- studs/s — velocity cap while grappling
	COOLDOWN        = 2.5,   -- seconds after detach before next grapple
	MIN_DETACH_DIST = 5,     -- studs — auto-detach when this close to hook
	KEY             = Enum.KeyCode.F,
}
