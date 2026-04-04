-- DamageApplicator (ModuleScript — server only)
-- Single entry point for all damage in the game.
-- Called by Phase 3 CollisionHandler after a projectile hit is validated.
--
-- Usage:
--   local DamageApplicator = require(path.to.DamageApplicator)
--   DamageApplicator.applyDamage(victim, attacker, damage)

local WeaponConstants = require(game.ReplicatedStorage.Shared.Constants.WeaponConstants)
local HealthSystem    = require(script.Parent.HealthSystem)

local DamageApplicator = {}

-- Apply a fixed damage chunk to victim.
-- attacker may be nil (environmental damage).
-- Returns true if the hit was lethal.
function DamageApplicator.applyDamage(victim, attacker, damage)
	damage = damage or WeaponConstants.DAMAGE_PER_HIT
	return HealthSystem.takeDamage(victim, attacker, damage)
end

return DamageApplicator
