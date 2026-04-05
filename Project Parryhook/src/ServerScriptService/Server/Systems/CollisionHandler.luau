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
		-- ── Parry check ──────────────────────────────────────────────────────
		if ParryHandler.isParrying(victim) then
			-- Reflect: update projectile in registry (do NOT remove it).
			-- It keeps flying in the reversed direction with the parrier as new owner.
			ParryHandler.reflect(projectile, victim)
			-- projectile.position stays at hitPos so it starts from the collision point
			projectile.position = hitPos
			FeedbackDispatcher.fireParry(victim.UserId, hitPos)
			return   -- no damage, no impact flash
		end

		-- ── Normal hit ───────────────────────────────────────────────────────
		ProjectileRegistry.remove(projectile.id)
		local isKill = DamageApplicator.applyDamage(victim, attacker)
		FeedbackDispatcher.fireImpact(hitPos, hitNormal, isKill)
	else
		-- Hit environment (or self — guard)
		ProjectileRegistry.remove(projectile.id)
		FeedbackDispatcher.fireImpact(hitPos, hitNormal, false)
	end
end

return CollisionHandler
