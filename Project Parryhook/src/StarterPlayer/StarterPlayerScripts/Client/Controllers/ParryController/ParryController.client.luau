-- ParryController (LocalScript)
-- G key → ParryRequest → server opens parry window.
-- ParryEffect ← server → parry ring VFX + reflect flash + shake.

local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local Players          = game:GetService("Players")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotes      = game.ReplicatedStorage:WaitForChild("Remotes")
local parryRequest = remotes:WaitForChild("ParryRequest")
local parryEffect  = remotes:WaitForChild("ParryEffect")

local ParryConstants = require(game.ReplicatedStorage.Shared.Constants.ParryConstants)
local SoundManager   = require(game.ReplicatedStorage.Client.SoundManager)
local ScreenEffects  = require(game.ReplicatedStorage.Client.ScreenEffects)

-- ── Screen flash UI ───────────────────────────────────────────────────────────

local gui = Instance.new("ScreenGui")
gui.Name            = "ParryUI"
gui.ResetOnSpawn    = false
gui.IgnoreGuiInset  = true
gui.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
gui.Parent          = playerGui

-- Cyan edge vignette during active parry window
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

-- Full-screen white flash on confirmed reflect
local reflectFlash = Instance.new("Frame")
reflectFlash.Name                   = "ReflectFlash"
reflectFlash.Size                   = UDim2.fromScale(1, 1)
reflectFlash.BackgroundColor3       = Color3.new(1, 1, 1)
reflectFlash.BackgroundTransparency = 1
reflectFlash.BorderSizePixel        = 0
reflectFlash.ZIndex                 = 22
reflectFlash.Parent                 = gui

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
	reflectFlash.BackgroundTransparency = 0.1
	TweenService:Create(reflectFlash, REFLECT_OUT,
		{ BackgroundTransparency = 1 }):Play()
end

-- ── 3D Parry ring VFX ─────────────────────────────────────────────────────────
-- Expanding flat disk (CylinderMesh) that blooms outward and fades at the hit point.

local function spawnParryRing(position)
	local part          = Instance.new("Part")
	part.Anchored       = true
	part.CanCollide     = false
	part.CastShadow     = false
	part.Size           = Vector3.new(0.3, 0.15, 0.3)
	part.Material       = Enum.Material.Neon
	part.Color          = Color3.fromRGB(80, 220, 200)   -- cyan ring
	part.Transparency   = 0
	part.CFrame         = CFrame.new(position)
	part.Parent         = workspace

	local mesh          = Instance.new("SpecialMesh")
	mesh.MeshType       = Enum.MeshType.Cylinder
	mesh.Scale          = Vector3.new(0.05, 1, 1)   -- very flat disk
	mesh.Parent         = part

	-- Expand + fade over 0.35s
	local RING_EXPAND = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(part, RING_EXPAND, { Size = Vector3.new(0.3, 8, 8) }):Play()
	local fadeTween = TweenService:Create(part, RING_EXPAND, { Transparency = 1 })
	fadeTween:Play()
	fadeTween.Completed:Connect(function() part:Destroy() end)
end

-- ── Cooldown tracking ─────────────────────────────────────────────────────────

local cooldownUntil = 0

-- ── Input ─────────────────────────────────────────────────────────────────────

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode ~= ParryConstants.KEY then return end

	local now = os.clock()
	if now < cooldownUntil then return end
	cooldownUntil = now + ParryConstants.COOLDOWN

	parryRequest:FireServer(now)
	showParryWindow()
	SoundManager.play("parry_swing")
end)

-- ── Parry confirmed ───────────────────────────────────────────────────────────

parryEffect.OnClientEvent:Connect(function(_parrierUserId, position)
	showReflectFlash()
	spawnParryRing(position)
	SoundManager.play("parry_hit")
	ScreenEffects.shake(0.18)   -- satisfying punch on successful reflect
end)
