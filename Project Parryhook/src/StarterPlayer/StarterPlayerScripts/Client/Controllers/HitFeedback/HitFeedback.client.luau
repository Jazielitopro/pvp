-- HitFeedback (LocalScript)
-- Shows a red vignette flash and plays a hurt sound when the local player takes damage.
-- Subscribes to HealthUpdated and triggers whenever HP drops.
--
-- Phase 8: replace print() with proper HUD integration.
-- TODO: set HURT_SOUND_ID to a real Roblox asset ID (e.g. from the Roblox audio catalog).

local TweenService = game:GetService("TweenService")
local Players      = game:GetService("Players")

local player   = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotes       = game.ReplicatedStorage:WaitForChild("Remotes")
local healthUpdated = remotes:WaitForChild("HealthUpdated")

local HealthConstants = require(game.ReplicatedStorage.Shared.Constants.HealthConstants)

-- ── Sound ─────────────────────────────────────────────────────────────────────

local HURT_SOUND_ID = 0  -- TODO: replace with real asset ID

local hurtSound = Instance.new("Sound")
hurtSound.SoundId  = "rbxassetid://" .. HURT_SOUND_ID
hurtSound.Volume   = 0.6
hurtSound.RollOffMaxDistance = 0
hurtSound.Parent   = game.SoundService

-- ── Vignette UI ───────────────────────────────────────────────────────────────

local gui = Instance.new("ScreenGui")
gui.Name            = "HitFeedback"
gui.ResetOnSpawn    = false
gui.IgnoreGuiInset  = true
gui.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
gui.Parent          = playerGui

local vignette = Instance.new("Frame")
vignette.Name                 = "Vignette"
vignette.Size                 = UDim2.fromScale(1, 1)
vignette.BackgroundColor3     = Color3.fromRGB(180, 0, 0)
vignette.BackgroundTransparency = 1   -- invisible by default
vignette.BorderSizePixel      = 0
vignette.ZIndex               = 20
vignette.Parent               = gui

-- Inner UIGradient so only the screen edges turn red (vignette shape)
local gradient = Instance.new("UIGradient")
gradient.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0,   0),   -- edges: fully opaque
	NumberSequenceKeypoint.new(0.4, 0.9), -- fade toward center
	NumberSequenceKeypoint.new(1,   1),   -- center: fully transparent
})
gradient.Rotation = 0
gradient.Parent   = vignette

local FLASH_IN  = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local FLASH_OUT = TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

local activeTween
local function flashDamage()
	if activeTween then activeTween:Cancel() end

	-- Snap visible
	vignette.BackgroundTransparency = 0
	-- Fade out
	activeTween = TweenService:Create(vignette, FLASH_OUT,
		{ BackgroundTransparency = 1 })
	activeTween:Play()
end

-- ── HP tracking ───────────────────────────────────────────────────────────────

local lastHP = HealthConstants.MAX_HEALTH

healthUpdated.OnClientEvent:Connect(function(hp, _maxHp)
	if hp < lastHP then
		flashDamage()
		if HURT_SOUND_ID ~= 0 then
			hurtSound:Play()
		end
	end
	lastHP = hp
end)
