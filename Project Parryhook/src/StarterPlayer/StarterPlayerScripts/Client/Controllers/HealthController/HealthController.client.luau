-- HealthController (LocalScript)
-- Mirrors server HP state locally for HUD display.
-- This script NEVER modifies HP — the server is authoritative.
--
-- HealthUpdated → fired by HealthSystem after every HP change
-- PlayerDied    → fired to all clients on kill (Phase 7 kill feed)
--
-- Phase 8 will replace the print() calls with proper HUD updates.

local Players = game:GetService("Players")

local player = Players.LocalPlayer

local remotes       = game.ReplicatedStorage:WaitForChild("Remotes")
local healthUpdated = remotes:WaitForChild("HealthUpdated")
local playerDied    = remotes:WaitForChild("PlayerDied")

local HealthConstants = require(game.ReplicatedStorage.Shared.Constants.HealthConstants)

-- Local mirror of server HP (display only)
local currentHP = HealthConstants.MAX_HEALTH

-- ── Server sync ───────────────────────────────────────────────────────────────

healthUpdated.OnClientEvent:Connect(function(hp, maxHp)
	currentHP = hp
	-- TODO Phase 8: push hp to HUD module here
	print(string.format("[Health] HP: %d / %d", hp, maxHp))
end)

playerDied.OnClientEvent:Connect(function(victim, attacker)
	if victim == player then
		-- TODO Phase 8: death screen / respawn UI
		print("[Health] You died.")
	elseif attacker == player then
		-- TODO Phase 7: kill confirmation sound / feed
		print(string.format("[Health] You killed %s", victim.DisplayName))
	else
		print(string.format("[Health] %s was killed by %s",
			victim.DisplayName,
			attacker and attacker.DisplayName or "unknown"))
	end
end)
