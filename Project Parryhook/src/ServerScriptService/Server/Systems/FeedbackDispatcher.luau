-- FeedbackDispatcher (ModuleScript — server only)
-- Bridges server hit results to all clients for VFX and SFX.
-- CollisionHandler calls this; nothing else should fire these remotes.
--
-- Phase 6 polish: add per-client distance culling (don't send to players >500 studs away).

local remotes       = game.ReplicatedStorage:WaitForChild("Remotes")
local impactEffect  = remotes:WaitForChild("ImpactEffect")

local FeedbackDispatcher = {}

-- Fire impact VFX at hit world position.
-- position : Vector3
-- normal   : Vector3  (surface normal, used for spark/decal orientation)
-- isKill   : boolean
function FeedbackDispatcher.fireImpact(position, normal, isKill)
	impactEffect:FireAllClients(position, normal, isKill)
end

return FeedbackDispatcher
