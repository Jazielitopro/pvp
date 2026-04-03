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
