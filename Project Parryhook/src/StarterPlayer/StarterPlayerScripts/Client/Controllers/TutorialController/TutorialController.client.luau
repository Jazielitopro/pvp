-- TutorialController (LocalScript)
-- Lightweight onboarding for Parryhook's core loop. This is intentionally
-- client-only: it teaches controls without granting rewards or affecting match
-- state, so it is safe if a modified client ignores it.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Theme = require(game.ReplicatedStorage.Client.UITheme)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotes = game.ReplicatedStorage:WaitForChild("Remotes", 15)
local matchStarted = remotes and remotes:WaitForChild("MatchStarted", 15)
local roundContract = remotes and remotes:WaitForChild("RoundContract", 15)
local medalAwarded = remotes and remotes:WaitForChild("MedalAwarded", 15)

local STEPS = {
	{
		id = "move",
		title = "Move First",
		body = "Use WASD to build momentum. Space jumps; Q dashes.",
		keys = {
			[Enum.KeyCode.W] = true,
			[Enum.KeyCode.A] = true,
			[Enum.KeyCode.S] = true,
			[Enum.KeyCode.D] = true,
			[Enum.KeyCode.Q] = true,
			[Enum.KeyCode.Space] = true,
		},
	},
	{
		id = "grapple",
		title = "Hook Momentum",
		body = "Press F while aiming at geometry. Release into speed for slingshots.",
		keys = {
			[Enum.KeyCode.F] = true,
		},
	},
	{
		id = "combat",
		title = "Shoot And Reload",
		body = "Left click fires. Press R to reload before you are empty.",
		mouse = true,
		keys = {
			[Enum.KeyCode.R] = true,
		},
	},
	{
		id = "parry",
		title = "Parry Timing",
		body = "Press G right before danger. Perfect parries and clashes earn medals.",
		keys = {
			[Enum.KeyCode.G] = true,
		},
	},
	{
		id = "objectives",
		title = "Contracts Matter",
		body = "Round contracts, daily challenges, and Season Road feed coins and cosmetics.",
		manualAdvanceSeconds = 6,
	},
	{
		id = "shop",
		title = "Cosmetic Loop",
		body = "Press M to open the shop. Buy style, claim dailies, and equip titles.",
		keys = {
			[Enum.KeyCode.M] = true,
		},
	},
}

local currentIndex = 1
local completed = {}
local hideToken = 0
local inputSeen = false
local dismissed = false

local gui = Instance.new("ScreenGui")
gui.Name = "TutorialUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local card = Instance.new("Frame")
card.Name = "HintCard"
card.Size = UDim2.new(0, 380, 0, 116)
card.AnchorPoint = Vector2.new(0, 1)
card.Position = UDim2.new(0, 14, 1, -18)
card.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
card.BackgroundTransparency = 0.18
card.BorderSizePixel = 0
card.Visible = false
card.ZIndex = 60
card.Parent = gui
Theme.stylePanel(card, {
	transparency = 0.08,
	strokeColor = Theme.colors.cyan,
	strokeTransparency = 0.32,
	strokeThickness = 2,
})

local accent = Instance.new("Frame")
accent.Size = UDim2.new(0, 5, 1, 0)
accent.BackgroundColor3 = Theme.colors.cyan
accent.BorderSizePixel = 0
accent.ZIndex = 61
accent.Parent = card

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -24, 0, 30)
titleLabel.Position = UDim2.new(0, 14, 0, 10)
titleLabel.BackgroundTransparency = 1
titleLabel.TextColor3 = Theme.colors.gold
titleLabel.TextScaled = true
titleLabel.Font = Theme.fonts.title
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Text = ""
titleLabel.ZIndex = 62
titleLabel.Parent = card

local bodyLabel = Instance.new("TextLabel")
bodyLabel.Size = UDim2.new(1, -24, 0, 44)
bodyLabel.Position = UDim2.new(0, 14, 0, 42)
bodyLabel.BackgroundTransparency = 1
bodyLabel.TextColor3 = Theme.colors.text
bodyLabel.TextScaled = true
bodyLabel.Font = Theme.fonts.body
bodyLabel.TextWrapped = true
bodyLabel.TextXAlignment = Enum.TextXAlignment.Left
bodyLabel.Text = ""
bodyLabel.ZIndex = 62
bodyLabel.Parent = card

local footerLabel = Instance.new("TextLabel")
footerLabel.Size = UDim2.new(1, -24, 0, 20)
footerLabel.Position = UDim2.new(0, 14, 1, -26)
footerLabel.BackgroundTransparency = 1
footerLabel.TextColor3 = Theme.colors.muted
footerLabel.TextScaled = true
footerLabel.Font = Theme.fonts.body
footerLabel.TextXAlignment = Enum.TextXAlignment.Left
footerLabel.Text = "Press H to hide tips"
footerLabel.ZIndex = 62
footerLabel.Parent = card

local function showStep(step)
	if dismissed or not step then return end

	card.Visible = true
	card.BackgroundTransparency = 0.08
	titleLabel.TextTransparency = 0
	bodyLabel.TextTransparency = 0
	footerLabel.TextTransparency = 0
	titleLabel.Text = step.title
	bodyLabel.Text = step.body
	footerLabel.Text = string.format("Tip %d/%d  |  Press H to hide tips", currentIndex, #STEPS)

	hideToken += 1
	local token = hideToken
	if step.manualAdvanceSeconds then
		task.delay(step.manualAdvanceSeconds, function()
			if token ~= hideToken or completed[step.id] then return end
			completed[step.id] = true
			currentIndex += 1
			showStep(STEPS[currentIndex])
		end)
	end
end

local function fadeCard()
	hideToken += 1
	TweenService:Create(card, TweenInfo.new(0.25), { BackgroundTransparency = 1 }):Play()
	TweenService:Create(titleLabel, TweenInfo.new(0.25), { TextTransparency = 1 }):Play()
	TweenService:Create(bodyLabel, TweenInfo.new(0.25), { TextTransparency = 1 }):Play()
	TweenService:Create(footerLabel, TweenInfo.new(0.25), { TextTransparency = 1 }):Play()
	task.delay(0.25, function()
		card.Visible = false
	end)
end

local function completeCurrent()
	local step = STEPS[currentIndex]
	if not step or completed[step.id] then return end

	completed[step.id] = true
	currentIndex += 1
	if STEPS[currentIndex] then
		showStep(STEPS[currentIndex])
	else
		fadeCard()
	end
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end

	if input.KeyCode == Enum.KeyCode.H then
		dismissed = true
		fadeCard()
		return
	end

	inputSeen = true
	local step = STEPS[currentIndex]
	if not step then return end

	if input.UserInputType == Enum.UserInputType.MouseButton1 and step.mouse then
		completeCurrent()
		return
	end

	if step.keys and step.keys[input.KeyCode] then
		completeCurrent()
	end
end)

if matchStarted then
	matchStarted.OnClientEvent:Connect(function()
		if dismissed or inputSeen then return end
		showStep(STEPS[currentIndex])
	end)
end

if roundContract then
	roundContract.OnClientEvent:Connect(function()
		if dismissed or completed.objectives then return end
		if currentIndex < 5 then return end
		showStep(STEPS[currentIndex])
	end)
end

if medalAwarded then
	medalAwarded.OnClientEvent:Connect(function()
		if dismissed or completed.shop then return end
		if currentIndex < #STEPS then
			currentIndex = #STEPS
			showStep(STEPS[currentIndex])
		end
	end)
end

task.delay(4, function()
	if dismissed or inputSeen then return end
	showStep(STEPS[currentIndex])
end)
