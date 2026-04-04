-- WeaponController (LocalScript)
-- Handles weapon input and keeps a local ammo mirror synced from server.
-- This script NEVER modifies ammo directly — the server is authoritative.
--
-- Input:
--   Left Mouse Button → fire (sends FireRequest to server)
--   R                 → manual reload (sends ReloadRequest to server)
--
-- Ammo display:
--   Server sends AmmoUpdated after every change.
--   Phase 8 will replace the print() with a proper HUD update.

local UserInputService = game:GetService("UserInputService")
local Players          = game:GetService("Players")

local player = Players.LocalPlayer

local remotes       = game.ReplicatedStorage:WaitForChild("Remotes")
local fireRequest   = remotes:WaitForChild("FireRequest")
local reloadRequest = remotes:WaitForChild("ReloadRequest")
local ammoUpdated   = remotes:WaitForChild("AmmoUpdated")

local WeaponConstants = require(game.ReplicatedStorage.Shared.Constants.WeaponConstants)

-- Local mirror of server ammo state (display only)
local currentAmmo  = WeaponConstants.MAX_AMMO
local isReloading  = false

-- ── Input ─────────────────────────────────────────────────────────────────────

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end

	-- Fire
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if isReloading then return end

		if currentAmmo <= 0 then
			-- Empty mag: auto-trigger reload instead of firing
			reloadRequest:FireServer()
			return
		end

		fireRequest:FireServer()
	end

	-- Manual reload
	if input.KeyCode == Enum.KeyCode.R then
		if isReloading then return end
		if currentAmmo >= WeaponConstants.MAX_AMMO then return end
		reloadRequest:FireServer()
	end
end)

-- ── Server sync ───────────────────────────────────────────────────────────────

ammoUpdated.OnClientEvent:Connect(function(ammo, reloading)
	currentAmmo = ammo
	isReloading = reloading

	-- TODO Phase 8: push ammo + reloading state to HUD module here
	if reloading then
		print(string.format("[Weapon] Reloading... (%ds)", WeaponConstants.RELOAD_TIME))
	else
		print(string.format("[Weapon] Ammo: %d / %d", ammo, WeaponConstants.MAX_AMMO))
	end
end)
