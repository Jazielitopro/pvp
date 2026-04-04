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
