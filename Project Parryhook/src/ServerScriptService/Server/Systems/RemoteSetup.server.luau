-- RemoteSetup (Script — server only)
-- Creates all RemoteEvents in ReplicatedStorage at game start.
-- Must run before any client script tries to access these.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotes = Instance.new("Folder")
remotes.Name   = "Remotes"
remotes.Parent = ReplicatedStorage

-- Movement
local dashRequest = Instance.new("RemoteEvent")
dashRequest.Name   = "DashRequest"
dashRequest.Parent = remotes

-- Weapon — Phase 2
local fireRequest = Instance.new("RemoteEvent")
fireRequest.Name   = "FireRequest"
fireRequest.Parent = remotes

local reloadRequest = Instance.new("RemoteEvent")
reloadRequest.Name   = "ReloadRequest"
reloadRequest.Parent = remotes

local ammoUpdated = Instance.new("RemoteEvent")
ammoUpdated.Name   = "AmmoUpdated"
ammoUpdated.Parent = remotes

-- Health — Phase 2
local healthUpdated = Instance.new("RemoteEvent")
healthUpdated.Name   = "HealthUpdated"
healthUpdated.Parent = remotes

local playerDied = Instance.new("RemoteEvent")
playerDied.Name   = "PlayerDied"
playerDied.Parent = remotes

-- Combat feedback — Phase 2 (Steps 6-7)
local hitConfirmed = Instance.new("RemoteEvent")
hitConfirmed.Name   = "HitConfirmed"   -- fired to attacker: (wasKill, victimName)
hitConfirmed.Parent = remotes

-- Grapple — Phase 4
local grappleRequest = Instance.new("RemoteEvent")
grappleRequest.Name   = "GrappleRequest"  -- client → server: (attachPoint: Vector3)
grappleRequest.Parent = remotes

-- Parry — Phase 5
local parryRequest = Instance.new("RemoteEvent")
parryRequest.Name   = "ParryRequest"  -- client → server: (clientTimestamp: number)
parryRequest.Parent = remotes

local parryEffect = Instance.new("RemoteEvent")
parryEffect.Name   = "ParryEffect"    -- server → all: (parrierUserId: number, position: Vector3)
parryEffect.Parent = remotes

-- Projectile — Phase 3
local spawnProjectile = Instance.new("RemoteEvent")
spawnProjectile.Name   = "SpawnProjectile"  -- server → all: (id, ownerId, origin, dir, speed)
spawnProjectile.Parent = remotes

local impactEffect = Instance.new("RemoteEvent")
impactEffect.Name   = "ImpactEffect"        -- server → all: (position, normal, isKill)
impactEffect.Parent = remotes
