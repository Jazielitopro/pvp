-- HitMarker (LocalScript)
-- Four-tick crosshair flash on hit; red X + kill sound on kill.
-- Subscribes to HitConfirmed (server fires only to attacker).

local TweenService = game:GetService("TweenService")
local Players      = game:GetService("Players")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotes      = game.ReplicatedStorage:WaitForChild("Remotes")
local hitConfirmed = remotes:WaitForChild("HitConfirmed")

local SoundManager = require(game.ReplicatedStorage.Client.SoundManager)

-- ── Hit Marker UI ─────────────────────────────────────────────────────────────

local gui = Instance.new("ScreenGui")
gui.Name           = "HitMarker"
gui.ResetOnSpawn   = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent         = playerGui

local CENTER    = UDim2.fromScale(0.5, 0.5)
local TICK_SIZE = UDim2.new(0, 6, 0, 2)

local ticks   = {}
local offsets = {
	UDim2.new(0,  10, 0, -1),
	UDim2.new(0, -16, 0, -1),
	UDim2.new(0,  -3, 0,  10),
	UDim2.new(0,  -3, 0, -12),
}

for i, offset in ipairs(offsets) do
	local tick                   = Instance.new("Frame")
	tick.Name                    = "Tick" .. i
	tick.Size                    = TICK_SIZE
	tick.AnchorPoint             = Vector2.new(0.5, 0.5)
	tick.Position                = CENTER + offset
	tick.BackgroundColor3        = Color3.new(1, 1, 1)
	tick.BackgroundTransparency  = 1
	tick.BorderSizePixel         = 0
	tick.ZIndex                  = 20
	tick.Parent                  = gui
	ticks[i] = tick
end

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
	for _, t in ipairs(activeTickTweens) do t:Cancel() end
	activeTickTweens = {}

	local tickColor = isKill and Color3.fromRGB(220, 30, 30) or Color3.new(1, 1, 1)

	for _, tick in ipairs(ticks) do
		tick.BackgroundColor3      = tickColor
		tick.BackgroundTransparency = 0
		local tw = TweenService:Create(tick, FADE_OUT, { BackgroundTransparency = 1 })
		tw:Play()
		table.insert(activeTickTweens, tw)
	end

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
	SoundManager.play(wasKill and "kill" or "hit")
end)
