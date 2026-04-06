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

local remotes          = game.ReplicatedStorage:WaitForChild("Remotes")
local scoreUpdated     = remotes:WaitForChild("ScoreUpdated")
local matchStarted     = remotes:WaitForChild("MatchStarted")
local matchEnded       = remotes:WaitForChild("MatchEnded")
local playerDied       = remotes:WaitForChild("PlayerDied")
local intermissionTick = remotes:WaitForChild("IntermissionTick")
local modeSelectedEvt  = remotes:WaitForChild("ModeSelected")
local teamAssignedEvt  = remotes:WaitForChild("TeamAssigned")

local MatchConstants = require(game.ReplicatedStorage.Shared.Constants.MatchConstants)
local HUD            = require(game.ReplicatedStorage.Client.HUD)

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
	showAnnouncement("FIGHT!", 2.5)
	print("[MatchController] Match started!")
end)

-- ── Remote: MatchEnded ───────────────────────────────────────────────────────

matchEnded.OnClientEvent:Connect(function(winnerName, playerList, teams)
	localScores = playerList or {}
	if HUD.setScores then HUD.setScores(localScores, teams) end

	local isMyWin = (winnerName == player.DisplayName)
		or (myTeam and winnerName == ("Team " .. myTeam))
	local msg = isMyWin and "YOU WIN!" or (winnerName .. " wins!")
	showAnnouncement(msg, MatchConstants.END_RESET_DELAY - 1)
	print(string.format("[MatchController] Match over. Winner: %s", winnerName))
end)

-- ── Remote: ModeSelected ─────────────────────────────────────────────────────

modeSelectedEvt.OnClientEvent:Connect(function(modeKey, modeName, modeDesc, isTeamBased, scoreLimit)
	activeModeKey = modeKey
	print(string.format("[MatchController] Mode: %s — %s (limit: %d)",
		modeKey, modeName, scoreLimit or 0))
	-- Team banner is triggered separately via TeamAssigned
end)

-- ── Remote: TeamAssigned ──────────────────────────────────────────────────────

teamAssignedEvt.OnClientEvent:Connect(function(team)
	print(string.format("[MatchController] Assigned to Team %s", team))
	showTeamBanner(team)
end)

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
