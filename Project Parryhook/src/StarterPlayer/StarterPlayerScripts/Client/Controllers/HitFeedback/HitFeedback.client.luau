-- HitFeedback (LocalScript)
-- Red vignette + hurt sound + camera shake when the local player takes damage.

local TweenService  = game:GetService("TweenService")
local Players       = game:GetService("Players")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotes       = game.ReplicatedStorage:WaitForChild("Remotes")
local healthUpdated = remotes:WaitForChild("HealthUpdated")

local HealthConstants = require(game.ReplicatedStorage.Shared.Constants.HealthConstants)
local SoundManager    = require(game.ReplicatedStorage.Client.SoundManager)
local ScreenEffects   = require(game.ReplicatedStorage.Client.ScreenEffects)

-- ── Vignette UI ───────────────────────────────────────────────────────────────

local gui = Instance.new("ScreenGui")
gui.Name            = "HitFeedback"
gui.ResetOnSpawn    = false
gui.IgnoreGuiInset  = true
gui.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
gui.Parent          = playerGui

local vignette = Instance.new("Frame")
vignette.Name                   = "Vignette"
vignette.Size                   = UDim2.fromScale(1, 1)
vignette.BackgroundColor3       = Color3.fromRGB(180, 0, 0)
vignette.BackgroundTransparency = 1
vignette.BorderSizePixel        = 0
vignette.ZIndex                 = 20
vignette.Parent                 = gui

local gradient = Instance.new("UIGradient")
gradient.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0,   0),
	NumberSequenceKeypoint.new(0.4, 0.9),
	NumberSequenceKeypoint.new(1,   1),
})
gradient.Parent = vignette

local FLASH_OUT = TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local activeTween

local function flashDamage()
	if activeTween then activeTween:Cancel() end
	vignette.BackgroundTransparency = 0
	activeTween = TweenService:Create(vignette, FLASH_OUT, { BackgroundTransparency = 1 })
	activeTween:Play()
end

-- ── HP tracking ───────────────────────────────────────────────────────────────

local lastHP = HealthConstants.MAX_HEALTH

healthUpdated.OnClientEvent:Connect(function(hp, _maxHp)
	if hp < lastHP then
		flashDamage()
		SoundManager.play("hurt")
		ScreenEffects.shake(0.28)   -- medium shake on taking a hit
	end
	lastHP = hp
end)
