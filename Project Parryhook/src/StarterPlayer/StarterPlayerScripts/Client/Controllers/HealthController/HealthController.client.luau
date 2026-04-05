-- HealthController (LocalScript)
-- Mirrors server HP locally. Handles death fade-to-black + respawn fade-in.
-- Phase 8 will replace print() calls with proper HUD health bar.

local TweenService = game:GetService("TweenService")
local Players      = game:GetService("Players")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotes       = game.ReplicatedStorage:WaitForChild("Remotes")
local healthUpdated = remotes:WaitForChild("HealthUpdated")
local playerDied    = remotes:WaitForChild("PlayerDied")

local HealthConstants = require(game.ReplicatedStorage.Shared.Constants.HealthConstants)
local SoundManager    = require(game.ReplicatedStorage.Client.SoundManager)

-- Local HP mirror (display only)
local currentHP = HealthConstants.MAX_HEALTH

-- ── Death / respawn fade UI ───────────────────────────────────────────────────

local gui = Instance.new("ScreenGui")
gui.Name            = "DeathFade"
gui.ResetOnSpawn    = false
gui.IgnoreGuiInset  = true
gui.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
gui.Parent          = playerGui

local fadeFrame = Instance.new("Frame")
fadeFrame.Name                   = "Fade"
fadeFrame.Size                   = UDim2.fromScale(1, 1)
fadeFrame.BackgroundColor3       = Color3.new(0, 0, 0)
fadeFrame.BackgroundTransparency = 1
fadeFrame.BorderSizePixel        = 0
fadeFrame.ZIndex                 = 30   -- above all other UI
fadeFrame.Parent                 = gui

local FADE_TO_BLACK = TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local FADE_TO_CLEAR = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function fadeOut()   -- black → clear
	TweenService:Create(fadeFrame, FADE_TO_CLEAR, { BackgroundTransparency = 1 }):Play()
end

local function fadeIn(callback)   -- clear → black → callback
	local tw = TweenService:Create(fadeFrame, FADE_TO_BLACK, { BackgroundTransparency = 0 })
	tw:Play()
	if callback then
		tw.Completed:Connect(callback)
	end
end

-- ── Respawn detection: fade back in when character respawns ───────────────────

player.CharacterAdded:Connect(function()
	-- Wait one frame for the character to load, then fade back in
	task.wait(0.1)
	fadeOut()
end)

-- ── Server sync ───────────────────────────────────────────────────────────────

healthUpdated.OnClientEvent:Connect(function(hp, maxHp)
	currentHP = hp
	-- TODO Phase 8: push hp to HUD health bar here
	print(string.format("[Health] HP: %d / %d", hp, maxHp))
end)

playerDied.OnClientEvent:Connect(function(victim, attacker)
	if victim == player then
		-- Fade to black on death; respawn will trigger CharacterAdded → fadeOut
		fadeIn()
		print("[Health] You died.")
	elseif attacker == player then
		print(string.format("[Health] You killed %s", victim.DisplayName))
	else
		print(string.format("[Health] %s was eliminated by %s",
			victim.DisplayName,
			attacker and attacker.DisplayName or "the environment"))
	end
end)
