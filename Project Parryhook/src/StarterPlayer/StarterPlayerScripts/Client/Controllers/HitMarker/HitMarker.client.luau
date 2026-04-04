-- HitMarker (LocalScript)
-- Shows a brief crosshair-style hit indicator when a shot lands.
-- For kills, shows a skull marker and plays a kill sound.
-- Subscribes to HitConfirmed (fired by server to attacker only).
--
-- TODO: set HIT_SOUND_ID / KILL_SOUND_ID to real Roblox asset IDs.

local TweenService = game:GetService("TweenService")
local Players      = game:GetService("Players")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotes      = game.ReplicatedStorage:WaitForChild("Remotes")
local hitConfirmed = remotes:WaitForChild("HitConfirmed")

-- ── Sound IDs ─────────────────────────────────────────────────────────────────

local HIT_SOUND_ID  = 0  -- TODO: replace with real asset ID
local KILL_SOUND_ID = 0  -- TODO: replace with real asset ID

local hitSound = Instance.new("Sound")
hitSound.SoundId  = "rbxassetid://" .. HIT_SOUND_ID
hitSound.Volume   = 0.5
hitSound.Parent   = game.SoundService

local killSound = Instance.new("Sound")
killSound.SoundId  = "rbxassetid://" .. KILL_SOUND_ID
killSound.Volume   = 0.7
killSound.Parent   = game.SoundService

-- ── Hit Marker UI ─────────────────────────────────────────────────────────────

local gui = Instance.new("ScreenGui")
gui.Name           = "HitMarker"
gui.ResetOnSpawn   = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent         = playerGui

-- Four tick marks around screen center (classic crosshair hit marker)
local CENTER = UDim2.fromScale(0.5, 0.5)
local TICK_SIZE = UDim2.new(0, 6, 0, 2)

local ticks = {}
local offsets = {
	UDim2.new(0, 10,  0, -1),   -- right
	UDim2.new(0, -16, 0, -1),   -- left
	UDim2.new(0, -3,  0, 10),   -- down
	UDim2.new(0, -3,  0, -12),  -- up
}

for i, offset in ipairs(offsets) do
	local tick = Instance.new("Frame")
	tick.Name                   = "Tick" .. i
	tick.Size                   = TICK_SIZE
	tick.AnchorPoint            = Vector2.new(0.5, 0.5)
	tick.Position               = CENTER + offset
	tick.BackgroundColor3       = Color3.new(1, 1, 1)
	tick.BackgroundTransparency = 1
	tick.BorderSizePixel        = 0
	tick.ZIndex                 = 20
	tick.Parent                 = gui
	ticks[i] = tick
end

-- Kill indicator: a brief red X in the center
local killX = Instance.new("TextLabel")
killX.Name                   = "KillX"
killX.Size                   = UDim2.new(0, 24, 0, 24)
killX.AnchorPoint            = Vector2.new(0.5, 0.5)
killX.Position               = CENTER
killX.BackgroundTransparency = 1
killX.TextColor3             = Color3.fromRGB(220, 30, 30)
killX.TextScaled             = true
killX.Font                   = Enum.Font.GothamBold
killX.Text                   = "X"
killX.TextTransparency       = 1
killX.ZIndex                 = 21
killX.Parent                 = gui

local FADE_OUT = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local KILL_OUT = TweenInfo.new(0.5,  Enum.EasingStyle.Quad, Enum.EasingDirection.In)

local activeKillTween
local activeTickTweens = {}

local function showHitMarker(isKill)
	-- Cancel any running tick tweens
	for _, t in ipairs(activeTickTweens) do t:Cancel() end
	activeTickTweens = {}

	-- Snap ticks visible
	local tickColor = isKill
		and Color3.fromRGB(220, 30, 30)
		or  Color3.new(1, 1, 1)

	for _, tick in ipairs(ticks) do
		tick.BackgroundColor3       = tickColor
		tick.BackgroundTransparency = 0
		local tw = TweenService:Create(tick, FADE_OUT, { BackgroundTransparency = 1 })
		tw:Play()
		table.insert(activeTickTweens, tw)
	end

	-- Kill indicator
	if isKill then
		if activeKillTween then activeKillTween:Cancel() end
		killX.TextTransparency = 0
		activeKillTween = TweenService:Create(killX, KILL_OUT, { TextTransparency = 1 })
		activeKillTween:Play()
	end
end

-- ── Server event ──────────────────────────────────────────────────────────────

hitConfirmed.OnClientEvent:Connect(function(wasKill, _victimName)
	showHitMarker(wasKill)

	if wasKill then
		if KILL_SOUND_ID ~= 0 then killSound:Play() end
	else
		if HIT_SOUND_ID  ~= 0 then hitSound:Play()  end
	end
end)
