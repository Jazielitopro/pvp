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
local Workspace        = game:GetService("Workspace")
local TweenService     = game:GetService("TweenService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotes       = game.ReplicatedStorage:WaitForChild("Remotes")
local fireRequest   = remotes:WaitForChild("FireRequest")
local reloadRequest = remotes:WaitForChild("ReloadRequest")
local ammoUpdated   = remotes:WaitForChild("AmmoUpdated")

local WeaponConstants = require(game.ReplicatedStorage.Shared.Constants.WeaponConstants)
local SoundManager    = require(game.ReplicatedStorage.Client.SoundManager)
local ScreenEffects   = require(game.ReplicatedStorage.Client.ScreenEffects)

-- ── Muzzle flash UI ───────────────────────────────────────────────────────────
-- Screen-space burst of light at the bottom-center, simulating gun discharge.

local flashGui = Instance.new("ScreenGui")
flashGui.Name           = "MuzzleFlash"
flashGui.ResetOnSpawn   = false
flashGui.IgnoreGuiInset = true
flashGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
flashGui.Parent         = playerGui

local muzzleFlash = Instance.new("Frame")
muzzleFlash.Name                   = "Flash"
muzzleFlash.Size                   = UDim2.new(0, 180, 0, 180)
muzzleFlash.AnchorPoint            = Vector2.new(0.5, 1)
muzzleFlash.Position               = UDim2.new(0.5, 0, 1, 30)  -- below center
muzzleFlash.BackgroundColor3       = Color3.fromRGB(255, 230, 120)
muzzleFlash.BackgroundTransparency = 1
muzzleFlash.BorderSizePixel        = 0
muzzleFlash.ZIndex                 = 18
muzzleFlash.Parent                 = flashGui

local flashCorner = Instance.new("UICorner")
flashCorner.CornerRadius = UDim.new(1, 0)  -- circular
flashCorner.Parent       = muzzleFlash

local FLASH_OUT = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local activeFlashTween

local function showMuzzleFlash()
	if activeFlashTween then activeFlashTween:Cancel() end
	muzzleFlash.BackgroundTransparency = 0.15
	muzzleFlash.Size = UDim2.new(0, 200, 0, 200)
	activeFlashTween = TweenService:Create(muzzleFlash, FLASH_OUT, {
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 120, 0, 120),
	})
	activeFlashTween:Play()
end

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

		-- Send the exact camera look direction so the server can spawn the projectile.
		local direction = Workspace.CurrentCamera.CFrame.LookVector
		fireRequest:FireServer(direction)

		-- Local VFX — no round-trip wait
		SoundManager.play("fire")
		showMuzzleFlash()
		ScreenEffects.shake(0.06)   -- subtle recoil kick
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
