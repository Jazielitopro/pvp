-- MatchController (LocalScript)
-- Receives match state events from the server and mirrors them locally.
-- Phase 8 will replace all print() calls with HUD elements.
--
-- Events received:
--   ScoreUpdated(scoreList)          — sorted array of {userId,name,kills}
--   MatchStarted()                   — new round began
--   MatchEnded(winnerName, scores)   — round over
--   PlayerDied(victim, attacker)     — reused here for kill-feed display

local Players  = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player   = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotes      = game.ReplicatedStorage:WaitForChild("Remotes")
local scoreUpdated = remotes:WaitForChild("ScoreUpdated")
local matchStarted = remotes:WaitForChild("MatchStarted")
local matchEnded   = remotes:WaitForChild("MatchEnded")
local playerDied   = remotes:WaitForChild("PlayerDied")

local MatchConstants = require(game.ReplicatedStorage.Shared.Constants.MatchConstants)
local HUD            = require(game.ReplicatedStorage.Client.HUD)

-- ── Local score mirror ────────────────────────────────────────────────────────

local localScores = {}   -- sorted array kept in sync with server

-- ── Announcement UI ───────────────────────────────────────────────────────────
-- Simple center-screen label for match start / end announcements.
-- Phase 8: replace with polished HUD.

local gui = Instance.new("ScreenGui")
gui.Name            = "MatchUI"
gui.ResetOnSpawn    = false
gui.IgnoreGuiInset  = true
gui.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
gui.Parent          = playerGui

local announceLbl = Instance.new("TextLabel")
announceLbl.Name                 = "Announce"
announceLbl.Size                 = UDim2.new(0, 500, 0, 60)
announceLbl.AnchorPoint          = Vector2.new(0.5, 0.2)
announceLbl.Position             = UDim2.new(0.5, 0, 0.18, 0)
announceLbl.BackgroundTransparency = 1
announceLbl.TextColor3           = Color3.new(1, 1, 1)
announceLbl.TextScaled           = true
announceLbl.Font                 = Enum.Font.GothamBold
announceLbl.Text                 = ""
announceLbl.TextTransparency     = 1
announceLbl.ZIndex               = 25
announceLbl.Parent               = gui

local FADE_IN  = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local FADE_OUT = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

local announceThread
local function showAnnouncement(text, duration)
	if announceThread then task.cancel(announceThread) end
	announceLbl.Text = text
	TweenService:Create(announceLbl, FADE_IN,  { TextTransparency = 0 }):Play()
	announceThread = task.delay(duration, function()
		TweenService:Create(announceLbl, FADE_OUT, { TextTransparency = 1 }):Play()
	end)
end

-- ── Kill feed (center-left toast) ─────────────────────────────────────────────
-- Phase 8: replace with scrolling kill feed panel.

local killFeedFrame = Instance.new("Frame")
killFeedFrame.Name                   = "KillFeed"
killFeedFrame.Size                   = UDim2.new(0, 320, 0, 160)
killFeedFrame.AnchorPoint            = Vector2.new(1, 0)
killFeedFrame.Position               = UDim2.new(1, -12, 0, 12)
killFeedFrame.BackgroundTransparency = 1
killFeedFrame.ZIndex                 = 24
killFeedFrame.Parent                 = gui

local killFeedLayout = Instance.new("UIListLayout")
killFeedLayout.SortOrder        = Enum.SortOrder.LayoutOrder
killFeedLayout.VerticalAlignment = Enum.VerticalAlignment.Top
killFeedLayout.Padding          = UDim.new(0, 4)
killFeedLayout.Parent           = killFeedFrame

local FEED_MAX = 4  -- max simultaneous entries shown

local function addKillFeedEntry(text)
	-- Remove oldest entry if at max
	local entries = killFeedFrame:GetChildren()
	local labels  = {}
	for _, c in ipairs(entries) do
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

	-- Fade out after 4 seconds
	task.delay(4, function()
		TweenService:Create(lbl, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
		task.delay(0.5, function() lbl:Destroy() end)
	end)
end

-- ── Remote handlers ───────────────────────────────────────────────────────────

scoreUpdated.OnClientEvent:Connect(function(scoreList)
	localScores = scoreList
	HUD.setScores(scoreList)
end)

matchStarted.OnClientEvent:Connect(function()
	showAnnouncement("FIGHT!", 2.5)
	print("[Match] Match started!")
end)

matchEnded.OnClientEvent:Connect(function(winnerName, scoreList)
	localScores = scoreList
	local msg = winnerName == player.DisplayName
		and "YOU WIN!"
		or  winnerName .. " wins!"
	showAnnouncement(msg, MatchConstants.END_RESET_DELAY - 1)
	print(string.format("[Match] Match over. Winner: %s", winnerName))
end)

-- Reuse PlayerDied for kill feed entries
playerDied.OnClientEvent:Connect(function(victim, attacker)
	local victimName   = victim  and victim.DisplayName  or "?"
	local attackerName = attacker and attacker.DisplayName or "?"
	if attacker then
		addKillFeedEntry(string.format("☠ %s → %s", attackerName, victimName))
	else
		addKillFeedEntry(string.format("☠ %s", victimName))
	end
end)
