-- MatchController (LocalScript)
-- Handles all match UI: mode selection screen, waiting/intermission panel,
-- team assignment banner, kill feed, score updates, and round announcements.
--
-- Events received from server:
--   IntermissionTick  { type="waiting"|"intermission", secondsLeft, modeName, ... }
--   MatchStarted      ()
--   MatchEnded        (winnerName, playerList, teamScores)
--   ModeSelected      (key, displayName, description, teamBased, scoreLimit)
--   TeamAssigned      (team: "A"|"B")
--   ScoreUpdated      (playerList, teamScores)
--   PlayerDied        (victim, attacker)

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotes          = game.ReplicatedStorage:WaitForChild("Remotes", 15)
if not remotes then error("[MatchController] Remotes folder not found — RemoteSetup may not have run") end

local scoreUpdated     = remotes:WaitForChild("ScoreUpdated",     15)
local matchStarted     = remotes:WaitForChild("MatchStarted",     15)
local matchEnded       = remotes:WaitForChild("MatchEnded",       15)
local matchSummary     = remotes:WaitForChild("MatchSummary",     15)
local medalAwarded     = remotes:WaitForChild("MedalAwarded",     15)
local roundContract    = remotes:WaitForChild("RoundContract",    15)
local contractUpdated  = remotes:WaitForChild("RoundContractUpdated", 15)
local playerDied       = remotes:WaitForChild("PlayerDied",       15)
local intermissionTick = remotes:WaitForChild("IntermissionTick", 15)
-- ModeSelected and TeamAssigned are new — warn clearly if missing instead of hanging forever
local modeSelectedEvt  = remotes:WaitForChild("ModeSelected", 10)
local teamAssignedEvt  = remotes:WaitForChild("TeamAssigned",  10)
if not modeSelectedEvt then warn("[MatchController] ModeSelected remote missing — create it in Studio under Remotes") end
if not teamAssignedEvt then warn("[MatchController] TeamAssigned remote missing — create it in Studio under Remotes") end

local MatchConstants = require(game.ReplicatedStorage.Shared.Constants.MatchConstants)
local HUD            = require(game.ReplicatedStorage.Client.HUD)
local Theme          = require(game.ReplicatedStorage.Client.UITheme)

print("[MatchController] Initialized for", player.Name)
if typeof(HUD.setScores) ~= "function" then
	warn("[MatchController] HUD.setScores missing — paste HUD.luau into Studio")
end

-- ── Team config ───────────────────────────────────────────────────────────────

local TEAM_COLOR = {
	A = Color3.fromRGB(70, 130, 255),   -- Blue
	B = Color3.fromRGB(255, 70,  70),   -- Red
}
local TEAM_LABEL = { A = "TEAM A", B = "TEAM B" }

-- ── Root ScreenGui ────────────────────────────────────────────────────────────

local gui = Instance.new("ScreenGui")
gui.Name            = "MatchUI"
gui.ResetOnSpawn    = false
gui.IgnoreGuiInset  = true
gui.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
gui.Parent          = playerGui

-- ── Tween configs ─────────────────────────────────────────────────────────────

local FADE_IN     = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local FADE_OUT    = TweenInfo.new(0.5,  Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local PULSE_TWEEN = TweenInfo.new(0.2,  Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local COLOR_TWEEN = TweenInfo.new(0.4,  Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- ── Announcement label (FIGHT! / "X wins!") ──────────────────────────────────

local announceLbl = Instance.new("TextLabel")
announceLbl.Name                   = "Announce"
announceLbl.Size                   = UDim2.new(0, 560, 0, 64)
announceLbl.AnchorPoint            = Vector2.new(0.5, 0.5)
announceLbl.Position               = UDim2.new(0.5, 0, 0.22, 0)
announceLbl.BackgroundTransparency = 1
announceLbl.TextColor3             = Color3.new(1, 1, 1)
announceLbl.TextScaled             = true
announceLbl.Font                   = Enum.Font.GothamBold
announceLbl.Text                   = ""
announceLbl.TextTransparency       = 1
announceLbl.ZIndex                 = 25
announceLbl.Parent                 = gui

-- ── Status panel (Waiting / Intermission) ─────────────────────────────────────
-- Centered on-screen. Shows mode info + countdown or player-count.

local panel = Instance.new("Frame")
panel.Name                   = "StatusPanel"
panel.Size                   = UDim2.new(0, 360, 0, 116)
panel.AnchorPoint            = Vector2.new(0.5, 0.5)
panel.Position               = UDim2.new(0.5, 0, 0.5, 0)
panel.BackgroundColor3       = Color3.fromRGB(10, 10, 10)
panel.BackgroundTransparency = 0.25
panel.BorderSizePixel        = 0
panel.ZIndex                 = 26
panel.Visible                = false
panel.Parent                 = gui

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 12)
panelCorner.Parent = panel
Theme.applyStroke(panel, Theme.colors.cyan, 0.5, 1.5)
Theme.applyGradient(panel, Theme.colors.panelLift, Theme.colors.panel, 90)

-- Top accent bar (color-coded per mode)
local accentBar = Instance.new("Frame")
accentBar.Name             = "Accent"
accentBar.Size             = UDim2.new(1, 0, 0, 4)
accentBar.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
accentBar.BorderSizePixel  = 0
accentBar.ZIndex           = 27
accentBar.Parent           = panel
local accentCorner = Instance.new("UICorner")
accentCorner.CornerRadius = UDim.new(0, 12)
accentCorner.Parent       = accentBar

-- Mode / status title  (left side)
local panelTitle = Instance.new("TextLabel")
panelTitle.Name                   = "Title"
panelTitle.Size                   = UDim2.new(0.68, -12, 0, 36)
panelTitle.Position               = UDim2.new(0, 12, 0, 10)
panelTitle.BackgroundTransparency = 1
panelTitle.TextColor3             = Color3.fromRGB(255, 255, 255)
panelTitle.TextScaled             = true
panelTitle.Font                   = Enum.Font.GothamBold
panelTitle.TextXAlignment         = Enum.TextXAlignment.Left
panelTitle.Text                   = "NEXT ROUND"
panelTitle.ZIndex                 = 27
panelTitle.Parent                 = panel

-- Mode description (small subtitle)
local panelDesc = Instance.new("TextLabel")
panelDesc.Name                   = "Desc"
panelDesc.Size                   = UDim2.new(0.68, -12, 0, 24)
panelDesc.Position               = UDim2.new(0, 12, 0, 50)
panelDesc.BackgroundTransparency = 1
panelDesc.TextColor3             = Color3.fromRGB(150, 150, 150)
panelDesc.TextScaled             = true
panelDesc.Font                   = Enum.Font.Gotham
panelDesc.TextXAlignment         = Enum.TextXAlignment.Left
panelDesc.Text                   = ""
panelDesc.ZIndex                 = 27
panelDesc.Parent                 = panel

-- Player count badge (bottom-left, shown during WAITING)
local playerCountLbl = Instance.new("TextLabel")
playerCountLbl.Name                   = "PlayerCount"
playerCountLbl.Size                   = UDim2.new(0.68, -12, 0, 22)
playerCountLbl.Position               = UDim2.new(0, 12, 0, 80)
playerCountLbl.BackgroundTransparency = 1
playerCountLbl.TextColor3             = Color3.fromRGB(120, 120, 120)
playerCountLbl.TextScaled             = true
playerCountLbl.Font                   = Enum.Font.Gotham
playerCountLbl.TextXAlignment         = Enum.TextXAlignment.Left
playerCountLbl.Text                   = ""
playerCountLbl.ZIndex                 = 27
playerCountLbl.Parent                 = panel

-- Countdown number (right column)
local panelCountdown = Instance.new("TextLabel")
panelCountdown.Name                   = "Countdown"
panelCountdown.Size                   = UDim2.new(0.3, 0, 1, -10)
panelCountdown.AnchorPoint            = Vector2.new(1, 0.5)
panelCountdown.Position               = UDim2.new(1, -8, 0.5, 0)
panelCountdown.BackgroundTransparency = 1
panelCountdown.TextColor3             = Color3.fromRGB(255, 200, 50)
panelCountdown.TextScaled             = true
panelCountdown.Font                   = Enum.Font.GothamBold
panelCountdown.Text                   = "–"
panelCountdown.ZIndex                 = 27
panelCountdown.Parent                 = panel

-- Divider between left text and right countdown
local divider = Instance.new("Frame")
divider.Name             = "Divider"
divider.Size             = UDim2.new(0, 1, 0.7, 0)
divider.AnchorPoint      = Vector2.new(1, 0.5)
divider.Position         = UDim2.new(0.7, -8, 0.5, 0)
divider.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
divider.BorderSizePixel  = 0
divider.ZIndex           = 27
divider.Parent           = panel

-- ── Team assignment banner ────────────────────────────────────────────────────
-- Fades in at round start when the mode is team-based.

local teamBannerFrame = Instance.new("Frame")
teamBannerFrame.Name                   = "TeamBanner"
teamBannerFrame.Size                   = UDim2.new(0, 380, 0, 84)
teamBannerFrame.AnchorPoint            = Vector2.new(0.5, 0.5)
teamBannerFrame.Position               = UDim2.new(0.5, 0, 0.5, 0)
teamBannerFrame.BackgroundColor3       = TEAM_COLOR.A
teamBannerFrame.BackgroundTransparency = 1
teamBannerFrame.BorderSizePixel        = 0
teamBannerFrame.ZIndex                 = 30
teamBannerFrame.Parent                 = gui
local tbCorner = Instance.new("UICorner")
tbCorner.CornerRadius = UDim.new(0, 14)
tbCorner.Parent       = teamBannerFrame

local teamBannerLbl = Instance.new("TextLabel")
teamBannerLbl.Name                   = "Label"
teamBannerLbl.Size                   = UDim2.new(1, 0, 0.6, 0)
teamBannerLbl.AnchorPoint            = Vector2.new(0.5, 0.5)
teamBannerLbl.Position               = UDim2.new(0.5, 0, 0.42, 0)
teamBannerLbl.BackgroundTransparency = 1
teamBannerLbl.TextColor3             = Color3.fromRGB(255, 255, 255)
teamBannerLbl.TextTransparency       = 1
teamBannerLbl.TextScaled             = true
teamBannerLbl.Font                   = Enum.Font.GothamBold
teamBannerLbl.Text                   = "TEAM A"
teamBannerLbl.ZIndex                 = 31
teamBannerLbl.Parent                 = teamBannerFrame

local teamBannerSub = Instance.new("TextLabel")
teamBannerSub.Name                   = "Sub"
teamBannerSub.Size                   = UDim2.new(1, 0, 0.35, 0)
teamBannerSub.AnchorPoint            = Vector2.new(0.5, 0)
teamBannerSub.Position               = UDim2.new(0.5, 0, 0.65, 0)
teamBannerSub.BackgroundTransparency = 1
teamBannerSub.TextColor3             = Color3.fromRGB(220, 220, 220)
teamBannerSub.TextTransparency       = 1
teamBannerSub.TextScaled             = true
teamBannerSub.Font                   = Enum.Font.Gotham
teamBannerSub.Text                   = "Fight together"
teamBannerSub.ZIndex                 = 31
teamBannerSub.Parent                 = teamBannerFrame

-- ── Kill feed (top-right) ─────────────────────────────────────────────────────

local killFeedFrame = Instance.new("Frame")
killFeedFrame.Name                   = "KillFeed"
killFeedFrame.Size                   = UDim2.new(0, 320, 0, 160)
killFeedFrame.AnchorPoint            = Vector2.new(1, 0)
killFeedFrame.Position               = UDim2.new(1, -12, 0, 12)
killFeedFrame.BackgroundTransparency = 1
killFeedFrame.ZIndex                 = 24
killFeedFrame.Parent                 = gui

local killFeedLayout = Instance.new("UIListLayout")
killFeedLayout.SortOrder         = Enum.SortOrder.LayoutOrder
killFeedLayout.VerticalAlignment  = Enum.VerticalAlignment.Top
killFeedLayout.Padding           = UDim.new(0, 4)
killFeedLayout.Parent            = killFeedFrame

-- Skill medal popups.
local medalPanel = Instance.new("Frame")
medalPanel.Name                   = "MedalPopup"
medalPanel.Size                   = UDim2.new(0, 320, 0, 78)
medalPanel.AnchorPoint            = Vector2.new(0.5, 0)
medalPanel.Position               = UDim2.new(0.5, 0, 0.31, 0)
medalPanel.BackgroundColor3       = Color3.fromRGB(10, 10, 10)
medalPanel.BackgroundTransparency = 1
medalPanel.BorderSizePixel        = 0
medalPanel.Visible                = false
medalPanel.ZIndex                 = 34
medalPanel.Parent                 = gui
local medalCorner = Instance.new("UICorner")
medalCorner.CornerRadius = UDim.new(0, 12)
medalCorner.Parent = medalPanel
Theme.applyStroke(medalPanel, Theme.colors.gold, 0.42, 1.5)
Theme.applyGradient(medalPanel, Theme.colors.panelLift, Theme.colors.panel, 90)

local medalTitle = Instance.new("TextLabel")
medalTitle.Size                   = UDim2.new(1, -20, 0, 34)
medalTitle.Position               = UDim2.new(0, 10, 0, 8)
medalTitle.BackgroundTransparency = 1
medalTitle.TextColor3             = Color3.fromRGB(255, 210, 60)
medalTitle.TextScaled             = true
medalTitle.Font                   = Enum.Font.GothamBold
medalTitle.Text                   = ""
medalTitle.ZIndex                 = 35
medalTitle.Parent                 = medalPanel

local medalDesc = Instance.new("TextLabel")
medalDesc.Size                   = UDim2.new(1, -20, 0, 24)
medalDesc.Position               = UDim2.new(0, 10, 0, 44)
medalDesc.BackgroundTransparency = 1
medalDesc.TextColor3             = Color3.fromRGB(230, 230, 230)
medalDesc.TextScaled             = true
medalDesc.Font                   = Enum.Font.Gotham
medalDesc.Text                   = ""
medalDesc.ZIndex                 = 35
medalDesc.Parent                 = medalPanel

-- Round contract card. This is intentionally lightweight until contracts are
-- proven fun enough to persist as progression.
local contractPanel = Instance.new("Frame")
contractPanel.Name                   = "RoundContract"
contractPanel.Size                   = UDim2.new(0, 340, 0, 74)
contractPanel.AnchorPoint            = Vector2.new(0, 0)
contractPanel.Position               = UDim2.new(0, 14, 0.18, 0)
contractPanel.BackgroundColor3       = Color3.fromRGB(12, 12, 12)
contractPanel.BackgroundTransparency = 0.22
contractPanel.BorderSizePixel        = 0
contractPanel.Visible                = false
contractPanel.ZIndex                 = 31
contractPanel.Parent                 = gui
local contractCorner = Instance.new("UICorner")
contractCorner.CornerRadius = UDim.new(0, 10)
contractCorner.Parent = contractPanel
Theme.applyStroke(contractPanel, Theme.colors.cyan, 0.46, 1.5)
Theme.applyGradient(contractPanel, Theme.colors.panelLift, Theme.colors.panel, 90)

local contractTitle = Instance.new("TextLabel")
contractTitle.Name                   = "Title"
contractTitle.Size                   = UDim2.new(1, -20, 0, 28)
contractTitle.Position               = UDim2.new(0, 10, 0, 8)
contractTitle.BackgroundTransparency = 1
contractTitle.TextColor3             = Color3.fromRGB(80, 220, 255)
contractTitle.TextScaled             = true
contractTitle.Font                   = Enum.Font.GothamBold
contractTitle.TextXAlignment         = Enum.TextXAlignment.Left
contractTitle.Text                   = "ROUND CONTRACT"
contractTitle.ZIndex                 = 32
contractTitle.Parent                 = contractPanel

local contractDesc = Instance.new("TextLabel")
contractDesc.Name                   = "Desc"
contractDesc.Size                   = UDim2.new(1, -20, 0, 26)
contractDesc.Position               = UDim2.new(0, 10, 0, 40)
contractDesc.BackgroundTransparency = 1
contractDesc.TextColor3             = Color3.fromRGB(235, 235, 235)
contractDesc.TextScaled             = true
contractDesc.Font                   = Enum.Font.Gotham
contractDesc.TextXAlignment         = Enum.TextXAlignment.Left
contractDesc.Text                   = ""
contractDesc.ZIndex                 = 32
contractDesc.Parent                 = contractPanel

-- Post-match performance summary.
local summaryPanel = Instance.new("Frame")
summaryPanel.Name                   = "MatchSummary"
summaryPanel.Size                   = UDim2.new(0, 560, 0, 340)
summaryPanel.AnchorPoint            = Vector2.new(0.5, 0.5)
summaryPanel.Position               = UDim2.new(0.5, 0, 0.58, 0)
summaryPanel.BackgroundColor3       = Color3.fromRGB(10, 10, 10)
summaryPanel.BackgroundTransparency = 0.18
summaryPanel.BorderSizePixel        = 0
summaryPanel.Visible                = false
summaryPanel.ZIndex                 = 32
summaryPanel.Parent                 = gui
local summaryCorner = Instance.new("UICorner")
summaryCorner.CornerRadius = UDim.new(0, 10)
summaryCorner.Parent = summaryPanel
Theme.applyStroke(summaryPanel, Theme.colors.gold, 0.32, 2)
Theme.applyGradient(summaryPanel, Theme.colors.panelLift, Theme.colors.panel, 90)

local summaryTitle = Instance.new("TextLabel")
summaryTitle.Name                   = "Title"
summaryTitle.Size                   = UDim2.new(1, -24, 0, 32)
summaryTitle.Position               = UDim2.new(0, 12, 0, 10)
summaryTitle.BackgroundTransparency = 1
summaryTitle.TextColor3             = Color3.fromRGB(255, 210, 60)
summaryTitle.TextScaled             = true
summaryTitle.Font                   = Enum.Font.GothamBold
summaryTitle.TextXAlignment         = Enum.TextXAlignment.Left
summaryTitle.Text                   = "MATCH BREAKDOWN"
summaryTitle.ZIndex                 = 33
summaryTitle.Parent                 = summaryPanel

local summaryRows = {}
local mvpRows = {}

local function makeSummaryRow(index)
	local row = Instance.new("TextLabel")
	row.Name                   = "Row" .. index
	row.Size                   = UDim2.new(1, -24, 0, 34)
	row.Position               = UDim2.new(0, 12, 0, 48 + (index - 1) * 38)
	row.BackgroundTransparency = 1
	row.TextColor3             = Color3.fromRGB(235, 235, 235)
	row.TextScaled             = true
	row.Font                   = Enum.Font.Gotham
	row.TextXAlignment         = Enum.TextXAlignment.Left
	row.Text                   = ""
	row.ZIndex                 = 33
	row.Parent                 = summaryPanel
	return row
end

for i = 1, 5 do
	summaryRows[i] = makeSummaryRow(i)
end

local function makeMvpRow(index)
	local row = Instance.new("TextLabel")
	row.Name                   = "MVP" .. index
	row.Size                   = UDim2.new(1, -24, 0, 28)
	row.Position               = UDim2.new(0, 12, 0, 244 + (index - 1) * 30)
	row.BackgroundTransparency = 1
	row.TextColor3             = Color3.fromRGB(80, 220, 255)
	row.TextScaled             = true
	row.Font                   = Enum.Font.GothamBold
	row.TextXAlignment         = Enum.TextXAlignment.Left
	row.Text                   = ""
	row.ZIndex                 = 33
	row.Parent                 = summaryPanel
	return row
end

for i = 1, 3 do
	mvpRows[i] = makeMvpRow(i)
end

local contractHideToken = 0
local medalToken = 0

local function formatSummaryRow(index, entry)
	local contract = entry.contract
	local contractMark = "--"
	if contract then
		contractMark = contract.completed and "OK" or string.format("%d/%d", contract.progress or 0, contract.target or 0)
	end
	local displayName = entry.name or "?"
	if entry.rank then
		displayName = string.format("{%s} %s", entry.rank, displayName)
	end
	if entry.title then
		displayName = string.format("[%s] %s", entry.title, displayName)
	end
	local ratingText = entry.rating and string.format(" R:%d(%+d)", entry.rating, entry.ratingDelta or 0) or ""

	return string.format(
		"#%d %s  K:%d D:%d DMG:%d  PP:%d CL:%d AIR:%d SL:%d  C:%s XP:%d +%dC Lv:%d%s",
		index,
		displayName,
		entry.kills or 0,
		entry.deaths or 0,
		entry.damageDealt or 0,
		entry.perfectParries or 0,
		entry.parryClashes or 0,
		entry.airShots or 0,
		entry.grappleSlingshots or 0,
		contractMark,
		entry.xpEarned or 0,
		entry.coinsEarned or 0,
		entry.level or 1,
		ratingText
	)
end

local function showRoundContract(contract, isProgressUpdate)
	if not contract then return end

	if contract.completed then
		contractTitle.Text = "CONTRACT COMPLETE"
		contractTitle.TextColor3 = Color3.fromRGB(120, 255, 140)
	else
		contractTitle.Text = "CONTRACT: " .. (contract.name or "Round Goal")
		contractTitle.TextColor3 = Color3.fromRGB(80, 220, 255)
	end

	contractDesc.Text = string.format(
		"%s  %d/%d  (%d XP)",
		contract.description or "Play your style",
		contract.progress or 0,
		contract.target or 0,
		contract.rewardXp or 0
	)
	contractPanel.Visible = true

	contractHideToken += 1
	local hideToken = contractHideToken
	local duration = contract.completed and 5 or (isProgressUpdate and 3 or 6)
	task.delay(duration, function()
		if hideToken ~= contractHideToken then return end
		contractPanel.Visible = false
	end)
end

local function medalColor(colorKey)
	if colorKey == "cyan" then
		return Color3.fromRGB(80, 220, 255)
	elseif colorKey == "red" then
		return Color3.fromRGB(255, 90, 90)
	elseif colorKey == "white" then
		return Color3.fromRGB(245, 245, 245)
	end
	return Color3.fromRGB(255, 210, 60)
end

local function showMedal(medal)
	if not medal then return end

	medalToken += 1
	local token = medalToken
	medalTitle.Text = medal.name or "MEDAL"
	medalDesc.Text = medal.description or ""
	medalTitle.TextColor3 = medalColor(medal.color)
	medalPanel.Visible = true
	medalPanel.BackgroundTransparency = 0.18
	medalTitle.TextTransparency = 0
	medalDesc.TextTransparency = 0

	task.delay(1.8, function()
		if token ~= medalToken then return end
		TweenService:Create(medalPanel, FADE_OUT, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(medalTitle, FADE_OUT, { TextTransparency = 1 }):Play()
		TweenService:Create(medalDesc, FADE_OUT, { TextTransparency = 1 }):Play()
		task.delay(0.5, function()
			if token == medalToken then
				medalPanel.Visible = false
			end
		end)
	end)
end

local function showMatchSummary(summary)
	local winnerName = summary and summary.winnerName or "Draw"
	local players = summary and summary.players or {}
	local mvps = summary and summary.mvps or {}

	summaryPanel.Visible = true
	summaryTitle.Text = (winnerName == "Draw") and "MATCH DRAW" or ("WINNER: " .. winnerName)

	for index, row in ipairs(summaryRows) do
		local entry = players[index]
		row.Visible = entry ~= nil
		if entry then
			row.TextColor3 = (entry.userId == player.UserId)
				and Color3.fromRGB(255, 210, 60)
				or Color3.fromRGB(235, 235, 235)
			row.Text = formatSummaryRow(index, entry)
		end
	end

	for index, row in ipairs(mvpRows) do
		local entry = mvps[index]
		row.Visible = entry ~= nil
		if entry then
			local displayName = entry.name or "?"
			if entry.rank then
				displayName = string.format("{%s} %s", entry.rank, displayName)
			end
			if entry.title then
				displayName = string.format("[%s] %s", entry.title, displayName)
			end
			row.Text = string.format("%s: %s (%d)", entry.label or "MVP", displayName, entry.value or 0)
		end
	end

	task.delay(math.max((MatchConstants.END_RESET_DELAY or 4) - 0.5, 1), function()
		summaryPanel.Visible = false
	end)
end

-- ── Local state ───────────────────────────────────────────────────────────────

local localScores    = {}
local myTeam         = nil   -- "A" | "B" | nil
local activeModeKey  = nil   -- "DUEL" | "FFA" | "TEAM"
local announceThread = nil

-- ── Helper: announcement ──────────────────────────────────────────────────────

local function showAnnouncement(text, duration)
	if announceThread then task.cancel(announceThread) end
	announceLbl.Text = text
	TweenService:Create(announceLbl, FADE_IN,  { TextTransparency = 0 }):Play()
	announceThread = task.delay(duration, function()
		TweenService:Create(announceLbl, FADE_OUT, { TextTransparency = 1 }):Play()
	end)
end

-- ── Helper: accent color ──────────────────────────────────────────────────────

local function setAccentColor(color)
	TweenService:Create(accentBar,       COLOR_TWEEN, { BackgroundColor3 = color }):Play()
	TweenService:Create(panelCountdown,  COLOR_TWEEN, { TextColor3       = color }):Play()
end

-- ── Helper: kill feed entry ───────────────────────────────────────────────────

local FEED_MAX = 4

local function addKillFeedEntry(text)
	local labels = {}
	for _, c in ipairs(killFeedFrame:GetChildren()) do
		if c:IsA("TextLabel") then table.insert(labels, c) end
	end
	if #labels >= FEED_MAX then labels[1]:Destroy() end

	local lbl = Instance.new("TextLabel")
	lbl.Size                   = UDim2.new(1, 0, 0, 28)
	lbl.BackgroundTransparency = 1
	lbl.TextColor3             = Color3.new(1, 1, 1)
	lbl.TextScaled             = true
	lbl.Font                   = Enum.Font.Gotham
	lbl.TextXAlignment         = Enum.TextXAlignment.Right
	lbl.Text                   = text
	lbl.TextTransparency       = 0
	lbl.ZIndex                 = 24
	lbl.LayoutOrder            = tick()
	lbl.Parent                 = killFeedFrame

	task.delay(4, function()
		TweenService:Create(lbl, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
		task.delay(0.5, function() lbl:Destroy() end)
	end)
end

-- ── Helper: team banner ───────────────────────────────────────────────────────

local function showTeamBanner(team)
	myTeam = team
	local color = TEAM_COLOR[team] or Color3.fromRGB(180, 180, 180)
	teamBannerFrame.BackgroundColor3 = color
	teamBannerLbl.Text = TEAM_LABEL[team] or ("TEAM " .. team)

	TweenService:Create(teamBannerFrame, FADE_IN, { BackgroundTransparency = 0.2 }):Play()
	TweenService:Create(teamBannerLbl,   FADE_IN, { TextTransparency = 0 }):Play()
	TweenService:Create(teamBannerSub,   FADE_IN, { TextTransparency = 0.2 }):Play()

	task.delay(2.8, function()
		TweenService:Create(teamBannerFrame, FADE_OUT, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(teamBannerLbl,   FADE_OUT, { TextTransparency = 1 }):Play()
		TweenService:Create(teamBannerSub,   FADE_OUT, { TextTransparency = 1 }):Play()
	end)
end

-- ── Remote: IntermissionTick ──────────────────────────────────────────────────
-- Receives a table from the server with type="waiting" or type="intermission".
-- Legacy number format (old server) is handled gracefully.

intermissionTick.OnClientEvent:Connect(function(data)
	summaryPanel.Visible = false
	contractPanel.Visible = false
	medalPanel.Visible = false

	-- Backward-compat: old server sent a plain number
	if type(data) == "number" then
		panel.Visible = true
		panelTitle.Text      = "NEXT ROUND"
		panelDesc.Text       = ""
		playerCountLbl.Text  = ""
		panelCountdown.Text  = tostring(data)
		setAccentColor(Color3.fromRGB(255, 200, 50))
		return
	end

	panel.Visible = true

	if data.type == "waiting" then
		local count = data.playerCount or 0
		local minP  = data.minPlayers  or 2

		panelTitle.Text     = "WAITING FOR PLAYERS"
		panelDesc.Text      = "Match starts when enough players join"
		playerCountLbl.Text = string.format("  %d / %d connected", count, minP)
		panelCountdown.Text = "–"
		setAccentColor(Color3.fromRGB(130, 130, 130))

	elseif data.type == "intermission" then
		local modeName = data.modeName or "NEXT ROUND"
		local modeDesc = data.modeDesc  or ""
		local secs     = data.secondsLeft or 0

		panelTitle.Text     = modeName
		panelDesc.Text      = modeDesc
		playerCountLbl.Text = ""
		panelCountdown.Text = tostring(secs)

		-- Color the accent by mode
		if data.modeKey == "DUEL" then
			setAccentColor(Color3.fromRGB(255, 200, 50))
		elseif data.modeKey == "FFA" then
			setAccentColor(Color3.fromRGB(240, 240, 240))
		elseif data.modeKey == "TEAM" then
			setAccentColor(Color3.fromRGB(80, 190, 255))
		end

		-- Pulse the countdown number on each tick
		panelCountdown.TextTransparency = 0.5
		TweenService:Create(panelCountdown, PULSE_TWEEN, { TextTransparency = 0 }):Play()
	end
end)

-- ── Remote: MatchStarted ──────────────────────────────────────────────────────

matchStarted.OnClientEvent:Connect(function()
	panel.Visible = false
	summaryPanel.Visible = false
	showAnnouncement("FIGHT!", 2.5)
	print("[MatchController] Match started!")
end)

-- ── Remote: MatchEnded ───────────────────────────────────────────────────────

matchEnded.OnClientEvent:Connect(function(winnerName, playerList, teams)
	localScores = playerList or {}
	if HUD.setScores then HUD.setScores(localScores, teams) end

	local isMyWin = (winnerName == player.DisplayName)
		or (myTeam and winnerName == ("Team " .. myTeam))
	local msg
	if winnerName == "Draw" then
		msg = "DRAW!"
	else
		msg = isMyWin and "YOU WIN!" or (winnerName .. " wins!")
	end
	showAnnouncement(msg, MatchConstants.END_RESET_DELAY - 1)
	print(string.format("[MatchController] Match over. Winner: %s", winnerName))
end)

if matchSummary then
	matchSummary.OnClientEvent:Connect(showMatchSummary)
end

if medalAwarded then
	medalAwarded.OnClientEvent:Connect(showMedal)
end

if roundContract then
	roundContract.OnClientEvent:Connect(showRoundContract)
end

if contractUpdated then
	contractUpdated.OnClientEvent:Connect(function(contract)
		showRoundContract(contract, true)
	end)
end

-- ── Remote: ModeSelected ─────────────────────────────────────────────────────

if modeSelectedEvt then
	modeSelectedEvt.OnClientEvent:Connect(function(modeKey, modeName, modeDesc, isTeamBased, scoreLimit)
		activeModeKey = modeKey
		if not isTeamBased then
			myTeam = nil
		end
		if HUD.setActiveMode then
			HUD.setActiveMode(modeKey, modeName, modeDesc, isTeamBased, scoreLimit)
		end
		print(string.format("[MatchController] Mode: %s — %s (limit: %d)",
			modeKey, modeName, scoreLimit or 0))
	end)
end

-- ── Remote: TeamAssigned ──────────────────────────────────────────────────────

if teamAssignedEvt then
	teamAssignedEvt.OnClientEvent:Connect(function(team)
		print(string.format("[MatchController] Assigned to Team %s", team))
		showTeamBanner(team)
	end)
end

-- ── Remote: ScoreUpdated ─────────────────────────────────────────────────────

scoreUpdated.OnClientEvent:Connect(function(playerList, teams)
	localScores = playerList or {}
	if HUD.setScores then
		HUD.setScores(localScores, teams)
	else
		warn("[MatchController] HUD.setScores still nil")
	end
end)

-- ── Remote: PlayerDied (kill feed) ───────────────────────────────────────────

playerDied.OnClientEvent:Connect(function(victim, attacker)
	local victimName   = victim   and victim.DisplayName   or "?"
	local attackerName = attacker and attacker.DisplayName or "?"
	if attacker then
		addKillFeedEntry(string.format("☠  %s  →  %s", attackerName, victimName))
	else
		addKillFeedEntry(string.format("☠  %s", victimName))
	end
end)
