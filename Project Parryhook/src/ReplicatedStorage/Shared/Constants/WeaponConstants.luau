-- WeaponConstants
-- Shared between client and server. Edit values here to tune weapon feel.

return {
	-- Revolver
	MAX_AMMO      = 6,    -- bullets per cylinder
	RELOAD_TIME   = 1.8,  -- seconds to fully reload
	FIRE_COOLDOWN = 0.22, -- minimum seconds between shots (semi-auto gate)

	-- Damage (chunk model — fixed per-hit, no spread)
	-- 3 hits to kill at 100 HP: 34 × 3 = 102 (third shot always kills)
	DAMAGE_PER_HIT = 34,
}
