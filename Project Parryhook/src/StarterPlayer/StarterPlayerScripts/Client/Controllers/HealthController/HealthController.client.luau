-- HealthController (LocalScript)
-- Mirrors server HP locally. Handles death animation + fade-to-black + respawn fade-in.
--
-- Death sequence:
--   1. playerDied fires → freeze humanoid movement
--   2. RootJoint tweens to a sideways fall pose (0.35 s)
--   3. Screen fades to black (0.6 s, overlapping the pose)
--   4. Server respawns character after 3 s → CharacterAdded fires → fade clear

local TweenService = game:GetService("TweenService")
local Players      = game:GetService("Players")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotes       = game.ReplicatedStorage:WaitForChild("Remotes")
local healthUpdated = remotes:WaitForChild("HealthUpdated")
local playerDied    = remotes:WaitForChild("PlayerDied")

local HealthConstants = require(game.ReplicatedStorage.Shared.Constants.HealthConstants)
local SoundManager    = require(game.ReplicatedStorage.Client.SoundManager)
local HUD             = require(game.ReplicatedStorage.Client.HUD)

-- ── Startup diagnostics ───────────────────────────────────────────────────────

print("[HealthController] Initialized for", player.Name)

if typeof(HUD.setHP) ~= "function" then
	warn("[HealthController] HUD.setHP is missing — paste HUD.luau content into Studio")
else
	print("[HealthController] HUD.setHP OK")
end

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

local function fadeIn(callback)   -- clear → black
	local tw = TweenService:Create(fadeFrame, FADE_TO_BLACK, { BackgroundTransparency = 0 })
	tw:Play()
	if callback then
		tw.Completed:Connect(callback)
	end
end

-- ── Death animation ───────────────────────────────────────────────────────────
-- Tweens the RootJoint sideways to simulate falling over.
-- Works without any Animation asset IDs.

local DEATH_TWEEN   = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local DEATH_DELAY   = 0.25   -- seconds before fade starts, so pose is visible briefly

local function playDeathAnimation()
	local char = player.Character
	if not char then return end

	-- Freeze character movement
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
	end

	-- Tilt RootJoint to fall-sideways pose
	local rootPart  = char:FindFirstChild("HumanoidRootPart")
	local rootJoint = rootPart and rootPart:FindFirstChild("RootJoint")
	if rootJoint then
		local fallC0 = rootJoint.C0 * CFrame.Angles(0, 0, math.rad(88))
		TweenService:Create(rootJoint, DEATH_TWEEN, { C0 = fallC0 }):Play()
	else
		warn("[HealthController] RootJoint not found — death pose skipped")
	end
end

-- ── Respawn detection: fade back in when character respawns ───────────────────

player.CharacterAdded:Connect(function()
	print("[HealthController] Character respawned —", player.Name)
	-- Wait one frame for the character to fully load, then fade in
	task.wait(0.1)
	fadeOut()
end)

-- ── Server sync ───────────────────────────────────────────────────────────────

healthUpdated.OnClientEvent:Connect(function(hp, maxHp)
	currentHP = hp
	print(string.format("[HealthController] HP update → %.0f / %.0f", hp, maxHp))
	if HUD.setHP then
		HUD.setHP(hp, maxHp)
	else
		warn("[HealthController] HUD.setHP still nil — HUD module not loaded")
	end
end)

playerDied.OnClientEvent:Connect(function(victim, attacker)
	if victim == player then
		print("[HealthController] You died — playing death animation")
		-- 1. Play death pose
		playDeathAnimation()
		-- 2. Short pause so the pose is visible, then fade to black
		task.delay(DEATH_DELAY, function()
			fadeIn()
		end)

	elseif attacker == player then
		print(string.format("[HealthController] You killed %s", victim.DisplayName))

	else
		print(string.format("[HealthController] %s was eliminated by %s",
			victim.DisplayName,
			attacker and attacker.DisplayName or "the environment"))
	end
end)
