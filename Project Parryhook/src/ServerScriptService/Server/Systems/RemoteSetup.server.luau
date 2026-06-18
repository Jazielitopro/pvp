-- RemoteSetup (Script - server only)
-- Creates all RemoteEvents in ReplicatedStorage at game start.
-- Idempotent so Studio reloads or accidental pre-created remotes stay safe.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end

local function getOrCreateRemote(name)
	local remote = remotes:FindFirstChild(name)
	if remote and remote:IsA("RemoteEvent") then
		return remote
	end
	if remote then
		warn(string.format("[RemoteSetup] %s exists but is not a RemoteEvent", name))
		return remote
	end

	remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = remotes
	return remote
end

-- Movement
getOrCreateRemote("DashRequest")
getOrCreateRemote("GrappleRequest") -- client -> server: requestId, ray origin/direction, client attach point
getOrCreateRemote("GrappleResult") -- server -> client: accepted, canonical attach point, rejection reason
getOrCreateRemote("GrappleEnded") -- client -> server: grapple detach notification

-- Weapon
getOrCreateRemote("FireRequest")
getOrCreateRemote("ReloadRequest")
getOrCreateRemote("AmmoUpdated")
getOrCreateRemote("AmmoStateRequested")

-- Health
getOrCreateRemote("HealthUpdated")
getOrCreateRemote("HealthStateRequested")
getOrCreateRemote("PlayerDied")
getOrCreateRemote("HitConfirmed")

-- Match
getOrCreateRemote("ScoreUpdated")
getOrCreateRemote("MatchStarted")
getOrCreateRemote("MatchEnded")
getOrCreateRemote("MatchSummary")
getOrCreateRemote("MedalAwarded")
getOrCreateRemote("RoundContract")
getOrCreateRemote("RoundContractUpdated")
getOrCreateRemote("IntermissionTick")
getOrCreateRemote("ModeSelected")
getOrCreateRemote("TeamAssigned")

-- Economy / cosmetics
getOrCreateRemote("EconomyProfileUpdated")
getOrCreateRemote("EconomyProfileRequested")
getOrCreateRemote("CosmeticPurchaseRequested")
getOrCreateRemote("CosmeticEquipRequested")
getOrCreateRemote("DailyLoginRewardClaimed")
getOrCreateRemote("SeasonRewardClaimed")

-- Parry
getOrCreateRemote("ParryRequest")
getOrCreateRemote("ParryEffect")

-- Projectile feedback
getOrCreateRemote("SpawnProjectile")
getOrCreateRemote("ProjectileUpdated")
getOrCreateRemote("ImpactEffect")
