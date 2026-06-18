-- FeedbackDispatcher (ModuleScript — server only)
-- Bridges server hit results to all clients for VFX and SFX.
-- CollisionHandler calls this; nothing else should fire these remotes.
--
-- Phase 6 polish: add per-client distance culling (don't send to players >500 studs away).

local remotes       = game.ReplicatedStorage:WaitForChild("Remotes")
local impactEffect  = remotes:WaitForChild("ImpactEffect")
local parryEffect   = remotes:WaitForChild("ParryEffect")

local FeedbackDispatcher = {}

-- Fire impact VFX at hit world position.
-- position : Vector3
-- normal   : Vector3  (surface normal, used for spark/decal orientation)
-- isKill   : boolean
function FeedbackDispatcher.fireImpact(position, normal, isKill)
	print(string.format("[Feedback] Impact at (%.1f,%.1f,%.1f) — %s",
		position.X, position.Y, position.Z, isKill and "KILL" or "hit"))
	impactEffect:FireAllClients(position, normal, isKill)
end

-- Fire parry VFX at the parry world position.
-- parrierUserId : number (so clients can skip their own flash if needed)
-- position      : Vector3
function FeedbackDispatcher.fireParry(parrierUserId, position, parryKind)
	print(string.format("[Feedback] Parry VFX at (%.1f,%.1f,%.1f) — userId=%d",
		position.X, position.Y, position.Z, parrierUserId))
	parryEffect:FireAllClients(parrierUserId, position, parryKind)
end

return FeedbackDispatcher
