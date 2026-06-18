-- ParryConstants
-- Shared between client and server.

return {
	-- How long the parry window stays active after the server receives the request.
	-- Accounts for round-trip latency on top of the intended reactive window.
	PARRY_WINDOW   = 0.28,   -- seconds

	-- Smaller high-skill window inside PARRY_WINDOW.
	PERFECT_WINDOW = 0.10,   -- seconds

	-- Minimum time between parry attempts (prevents spam).
	COOLDOWN        = 1.4,   -- seconds

	-- Input key
	KEY             = Enum.KeyCode.G,

	-- Client-side visual window (shown to player as feedback).
	-- Slightly wider than server window so the "active" flash always covers the real window.
	CLIENT_WINDOW   = 0.32,  -- seconds

	-- Projectile rewards.
	PERFECT_SPEED_MULT = 1.35,
	PERFECT_DAMAGE_MULT = 1.35,
	CLASH_SPEED_MULT = 1.15,
	CLASH_DAMAGE_MULT = 1.10,
	MAX_REFLECTS = 5,

	-- Punching your own fresh projectile redirects and empowers it.
	SELF_BOOST_MAX_AGE = 0.22,
	SELF_BOOST_RADIUS = 28,
	SELF_BOOST_SPEED_MULT = 1.25,
	SELF_BOOST_DAMAGE_MULT = 1.20,

	-- Option C upgrade cap: maximum rewind applied when computing projectile position.
	-- Must match HISTORY_DURATION in ProjectileSimulator.
	MAX_REWIND_CAP  = 0.15,  -- seconds (150 ms)
}
