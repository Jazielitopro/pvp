-- ParryController (LocalScript)
-- Sends parry input to the server and shows client-side feedback.
--
-- G key → ParryRequest(os.clock()) → server opens parry window
-- ParryEffect ← server → flash the screen edge cyan (parry success VFX)
--
-- Client-side window flash: plays immediately on G press so the player
-- sees feedback without waiting for server round-trip.
-- The server window is slightly narrower — if the server rejects due to
-- cooldown, the flash still plays but no actual parry happens (acceptable UX).
--
-- Phase 8: replace screen flash with proper parry ring / spark VFX.
-- TODO: set PARRY_SOUND_ID and REFLECT_SOUND_ID to real Roblox asset IDs.

local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local Players          = game:GetService("Players")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotes      = game.ReplicatedStorage:WaitForChild("Remotes")
local parryRequest = remotes:WaitForChild("ParryRequest")
local parryEffect  = remotes:WaitForChild("ParryEffect")

local ParryConstants = require(game.ReplicatedStorage.Shared.Constants.ParryConstants)

-- ── Sound placeholders ────────────────────────────────────────────────────────

local PARRY_SOUND_ID   = 0   -- TODO: replace — sound on local parry attempt
local REFLECT_SOUND_ID = 0   -- TODO: replace — sound on confirmed parry (ParryEffect)

local parrySound = Instance.new("Sound")
parrySound.SoundId = "rbxassetid://" .. PARRY_SOUND_ID
parrySound.Volume  = 0.7
parrySound.Parent  = game.SoundService

local reflectSound = Instance.new("Sound")
reflectSound.SoundId = "rbxassetid://" .. REFLECT_SOUND_ID
reflectSound.Volume  = 0.8
reflectSound.Parent  = game.SoundService

-- ── Screen flash UI ───────────────────────────────────────────────────────────

local gui = Instance.new("ScreenGui")
gui.Name            = "ParryUI"
gui.ResetOnSpawn    = false
gui.IgnoreGuiInset  = true
gui.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
gui.Parent          = playerGui

-- Active window flash: cyan edge vignette while parry window is open
local windowFlash = Instance.new("Frame")
windowFlash.Name                   = "WindowFlash"
windowFlash.Size                   = UDim2.fromScale(1, 1)
windowFlash.BackgroundColor3       = Color3.fromRGB(80, 220, 200)
windowFlash.BackgroundTransparency = 1
windowFlash.BorderSizePixel        = 0
windowFlash.ZIndex                 = 19
windowFlash.Parent                 = gui

local windowGrad = Instance.new("UIGradient")
windowGrad.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0,   0.1),
	NumberSequenceKeypoint.new(0.3, 0.95),
	NumberSequenceKeypoint.new(1,   1),
})
windowGrad.Parent = windowFlash

-- Bright white flash on successful reflect (from ParryEffect event)
local reflectFlash = Instance.new("Frame")
reflectFlash.Name                   = "ReflectFlash"
reflectFlash.Size                   = UDim2.fromScale(1, 1)
reflectFlash.BackgroundColor3       = Color3.new(1, 1, 1)
reflectFlash.BackgroundTransparency = 1
reflectFlash.BorderSizePixel        = 0
reflectFlash.ZIndex                 = 22
reflectFlash.Parent                 = gui

local WINDOW_IN   = TweenInfo.new(0.05, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local WINDOW_OUT  = TweenInfo.new(ParryConstants.CLIENT_WINDOW, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local REFLECT_OUT = TweenInfo.new(0.2,  Enum.EasingStyle.Quad, Enum.EasingDirection.In)

local activeWindowTween
local function showParryWindow()
	if activeWindowTween then activeWindowTween:Cancel() end
	windowFlash.BackgroundTransparency = 0.3
	activeWindowTween = TweenService:Create(windowFlash, WINDOW_OUT,
		{ BackgroundTransparency = 1 })
	activeWindowTween:Play()
end

local function showReflectFlash()
	reflectFlash.BackgroundTransparency = 0.15
	local tw = TweenService:Create(reflectFlash, REFLECT_OUT,
		{ BackgroundTransparency = 1 })
	tw:Play()
end

-- ── Cooldown tracking (client-side only — prevents UI spam) ──────────────────

local cooldownUntil = 0

-- ── Input ─────────────────────────────────────────────────────────────────────

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode ~= ParryConstants.KEY then return end

	local now = os.clock()
	if now < cooldownUntil then return end

	cooldownUntil = now + ParryConstants.COOLDOWN

	-- Send server timestamp for Option C upgrade compatibility
	parryRequest:FireServer(now)

	-- Immediate local feedback
	showParryWindow()
	if PARRY_SOUND_ID ~= 0 then parrySound:Play() end
end)

-- ── Parry effect (server confirmed a successful reflection) ───────────────────

parryEffect.OnClientEvent:Connect(function(parrierUserId, _position)
	-- Show reflect flash to everyone (spectators too)
	-- For the parrier themselves, it's a brighter reward flash
	showReflectFlash()
	if REFLECT_SOUND_ID ~= 0 then reflectSound:Play() end

	-- TODO Phase 8: spawn 3D spark VFX at _position
	print(string.format("[Parry] Player %d reflected a bullet!", parrierUserId))
end)
