-- CollisionHandler (ModuleScript — server only)
-- Called by ProjectileSimulator on every raycast hit.
-- Determines what was hit (player character or environment) and routes accordingly.
--
-- Phase 5 hook: parry detection will be added here before damage is applied.
-- Phase 5 hook: lag compensation rewind will be applied to victim position here.

local Players            = game:GetService("Players")
local ProjectileRegistry = require(script.Parent.ProjectileRegistry)
local DamageApplicator   = require(script.Parent.DamageApplicator)
local FeedbackDispatcher = require(script.Parent.FeedbackDispatcher)

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
-- projectile : table from ProjectileRegistry
-- hitResult  : RaycastResult
function CollisionHandler.onHit(projectile, hitResult)
	-- Remove from registry immediately — one hit per bullet.
	ProjectileRegistry.remove(projectile.id)

	local hitPos    = hitResult.Position
	local hitNormal = hitResult.Normal
	local attacker  = projectile.owner

	-- ── Phase 5 hook: parry check goes here ────────────────────────────────

	local victim = getPlayerFromInstance(hitResult.Instance)

	if victim and victim ~= attacker then
		-- Hit a player
		local isKill = DamageApplicator.applyDamage(victim, attacker)
		FeedbackDispatcher.fireImpact(hitPos, hitNormal, isKill)
	else
		-- Hit environment (or self — shouldn't happen with filter, but guard anyway)
		FeedbackDispatcher.fireImpact(hitPos, hitNormal, false)
	end
end

return CollisionHandler
