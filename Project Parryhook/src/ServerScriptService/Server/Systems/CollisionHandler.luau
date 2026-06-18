-- CollisionHandler (ModuleScript — server only)
-- Called by ProjectileSimulator on every raycast hit.
-- Determines what was hit (player character or environment) and routes accordingly.
--
-- Phase 5: parry check runs before damage. If the victim is parrying,
--   the projectile is reflected and damage is skipped.
--   Upgrade path to Option C is fully contained in ParryHandler.isParrying().

local Players            = game:GetService("Players")
local ProjectileRegistry = require(script.Parent.ProjectileRegistry)
local DamageApplicator   = require(script.Parent.DamageApplicator)
local FeedbackDispatcher = require(script.Parent.FeedbackDispatcher)
local ParryHandler       = require(script.Parent.ParryHandler)
local HealthSystem       = require(script.Parent.HealthSystem)

local CollisionHandler = {}

-- Walk up from a hit BasePart to find its owning Player, or nil.
local function getPlayerFromInstance(instance)
	local ancestor = instance
	while ancestor do
		if ancestor:IsA("Model") then
			local player = Players:GetPlayerFromCharacter(ancestor)
			if player then return player end
		end
		ancestor = ancestor.Parent
	end
	return nil
end

-- Called by ProjectileSimulator when a raycast hits something.
-- projectile : table from ProjectileRegistry (still live in registry when called)
-- hitResult  : RaycastResult
function CollisionHandler.onHit(projectile, hitResult)
	local hitPos    = hitResult.Position
	local hitNormal = hitResult.Normal
	local attacker  = projectile.owner

	local victim = getPlayerFromInstance(hitResult.Instance)

	if victim and victim ~= attacker then
		if not HealthSystem.isAlive(victim) then
			print(string.format("[Collision] Projectile id=%d hit dead player %s — ignored",
				projectile.id, victim.Name))
			ProjectileRegistry.remove(projectile.id)
			return
		end

		-- ── Parry check ──────────────────────────────────────────────────────
		if ParryHandler.isParrying(victim) then
			local parryKind = ParryHandler.getParryKind(victim, projectile)
			-- Reflect: update projectile in registry (do NOT remove it).
			-- It keeps flying in the reversed direction with the parrier as new owner.
			print(string.format("[Collision] Projectile id=%d PARRIED by %s — reflected back at %s",
				projectile.id, victim.Name, attacker and attacker.Name or "ENV"))
			-- projectile.position stays at hitPos so it starts from the collision point
			projectile.position = hitPos
			ParryHandler.reflect(projectile, victim, parryKind)
			FeedbackDispatcher.fireParry(victim.UserId, hitPos, parryKind)
			return   -- no damage, no impact flash
		end

		-- ── Normal hit ───────────────────────────────────────────────────────
		print(string.format("[Collision] Projectile id=%d HIT %s (fired by %s)",
			projectile.id, victim.Name, attacker and attacker.Name or "ENV"))
		ProjectileRegistry.remove(projectile.id)
		local hitTag = projectile.airborneShot and "AIR SHOT" or nil
		local isKill = DamageApplicator.applyDamage(victim, attacker, projectile.damage, hitTag)
		FeedbackDispatcher.fireImpact(hitPos, hitNormal, isKill)
	else
		-- Hit environment (or self — guard)
		if victim == attacker then
			print(string.format("[Collision] Projectile id=%d hit self (%s) — ignored",
				projectile.id, attacker and attacker.Name or "?"))
		else
			print(string.format("[Collision] Projectile id=%d hit environment at %s",
				projectile.id, tostring(hitPos)))
		end
		ProjectileRegistry.remove(projectile.id)
		FeedbackDispatcher.fireImpact(hitPos, hitNormal, false)
	end
end

return CollisionHandler
