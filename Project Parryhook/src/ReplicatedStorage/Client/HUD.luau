-- HUD (ModuleScript — client only)
-- Owns every persistent HUD panel. A singleton: first require builds the UI,
-- subsequent requires return the same API table.
--
-- API:
--   HUD.setHP(hp, maxHp)
--   HUD.setAmmo(ammo, maxAmmo, isReloading)
--   HUD.setScores(scoreList)    -- array of { userId, name, kills }
--   HUD.showScoreboard(visible) -- called by HUDController on Tab hold/release

local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ── Constants ─────────────────────────────────────────────────────────────────

local C = {
	panelBg      = Color3.fromRGB(14,  14,  14),
	panelAlpha   = 0.45,
	hpHigh       = Color3.fromRGB(85,  200, 85),    -- > 60 %
	hpMid        = Color3.fromRGB(220, 180, 50),    -- 30–60 %
	hpLow        = Color3.fromRGB(210, 50,  50),    -- < 30 %
	bulletLoaded = Color3.fromRGB(220, 175, 55),    -- gold
	bulletSpent  = Color3.fromRGB(45,  45,  45),    -- dark
	textWhite    = Color3.new(1, 1, 1),
	textDim      = Color3.fromRGB(160, 160, 160),
	reloadOrange = Color3.fromRGB(255, 155, 40),
	scoreGold    = Color3.fromRGB(255, 210, 60),
}

-- ── Root ScreenGui ────────────────────────────────────────────────────────────

local screen = Instance.new("ScreenGui")
screen.Name           = "HUD"
screen.ResetOnSpawn   = false
screen.IgnoreGuiInset = true
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.Parent         = playerGui

-- ── Helper ────────────────────────────────────────────────────────────────────

local function panel(anchorX, anchorY, scaleX, offsetY, w, h)
	local f = Instance.new("Frame")
	f.Size                   = UDim2.new(0, w, 0, h)
	f.AnchorPoint            = Vector2.new(anchorX, anchorY)
	f.Position               = UDim2.new(scaleX, 0, 1, offsetY)
	f.BackgroundColor3       = C.panelBg
	f.BackgroundTransparency = C.panelAlpha
	f.BorderSizePixel        = 0
	f.ZIndex                 = 14
	f.Parent                 = screen
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 7)
	corner.Parent = f
	return f
end

local function label(parent, size, pos, text, color, font, align, zIndex)
	local l = Instance.new("TextLabel")
	l.Size                   = size
	l.Position               = pos
	l.BackgroundTransparency = 1
	l.TextColor3             = color or C.textWhite
	l.Font                   = font  or Enum.Font.Gotham
	l.Text                   = text  or ""
	l.TextScaled             = true
	l.TextXAlignment         = align or Enum.TextXAlignment.Center
	l.ZIndex                 = zIndex or 15
	l.Parent                 = parent
	return l
end

-- ── Crosshair ─────────────────────────────────────────────────────────────────

local GAP, LEN, THICK = 5, 8, 2

local function crossTick(ox, oy, w, h)
	local f = Instance.new("Frame")
	f.Size                   = UDim2.new(0, w, 0, h)
	f.AnchorPoint            = Vector2.new(0.5, 0.5)
	f.Position               = UDim2.new(0.5, ox, 0.5, oy)
	f.BackgroundColor3       = Color3.new(1, 1, 1)
	f.BackgroundTransparency = 0.25
	f.BorderSizePixel        = 0
	f.ZIndex                 = 15
	f.Parent                 = screen
end

crossTick(0, -(GAP + LEN/2), THICK, LEN)  -- up
crossTick(0,  (GAP + LEN/2), THICK, LEN)  -- down
crossTick(-(GAP + LEN/2), 0, LEN, THICK)  -- left
crossTick( (GAP + LEN/2), 0, LEN, THICK)  -- right

local dot = Instance.new("Frame")
dot.Size                   = UDim2.new(0, 3, 0, 3)
dot.AnchorPoint            = Vector2.new(0.5, 0.5)
dot.Position               = UDim2.fromScale(0.5, 0.5)
dot.BackgroundColor3       = Color3.new(1, 1, 1)
dot.BackgroundTransparency = 0.25
dot.BorderSizePixel        = 0
dot.ZIndex                 = 15
local dotCorner = Instance.new("UICorner")
dotCorner.CornerRadius = UDim.new(1, 0)
dotCorner.Parent = dot
dot.Parent = screen

-- ── Health panel (bottom-left) ────────────────────────────────────────────────

local HP_W, HP_H = 245, 48
local hpPanel = panel(0, 1, 0.018, -14, HP_W, HP_H)

label(hpPanel, UDim2.new(0, 28, 0, 28),
	UDim2.new(0, 8, 0.5, -14),
	"♥", Color3.fromRGB(220, 60, 60), Enum.Font.GothamBold)

local barBg = Instance.new("Frame")
barBg.Size             = UDim2.new(0, 158, 0, 11)
barBg.Position         = UDim2.new(0, 44, 0.5, -6)
barBg.BackgroundColor3 = Color3.fromRGB(55, 18, 18)
barBg.BorderSizePixel  = 0
barBg.ZIndex           = 15
barBg.Parent           = hpPanel
local bgCorner = Instance.new("UICorner")
bgCorner.CornerRadius = UDim.new(0, 4)
bgCorner.Parent = barBg

local barFill = Instance.new("Frame")
barFill.Size             = UDim2.fromScale(1, 1)
barFill.BackgroundColor3 = C.hpHigh
barFill.BorderSizePixel  = 0
barFill.ZIndex           = 16
barFill.Parent           = barBg
local fillCorner = Instance.new("UICorner")
fillCorner.CornerRadius = UDim.new(0, 4)
fillCorner.Parent = barFill

local hpNum = label(hpPanel,
	UDim2.new(0, 38, 0, 28),
	UDim2.new(0, 206, 0.5, -14),
	"100", C.textWhite, Enum.Font.GothamBold, Enum.TextXAlignment.Right)

local BAR_TWEEN = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function hpColor(pct)
	if pct > 0.6 then return C.hpHigh
	elseif pct > 0.3 then return C.hpMid
	else return C.hpLow end
end

-- ── Ammo panel (bottom-right) ─────────────────────────────────────────────────

local AMMO_W, AMMO_H = 188, 48
local ammoPanel = panel(1, 1, 0.982, -14, AMMO_W, AMMO_H)

local reloadLbl = label(ammoPanel,
	UDim2.new(1, -12, 0.6, 0),
	UDim2.new(0, 6, 0.2, 0),
	"RELOADING", C.reloadOrange, Enum.Font.GothamBold)
reloadLbl.Visible = false

-- Bullet icon pool — rebuilt when maxAmmo changes
local bulletIcons = {}
local currentMaxAmmo = 0

local BULLET_W, BULLET_H, BULLET_GAP = 9, 24, 5

local function rebuildBullets(maxAmmo)
	for _, b in ipairs(bulletIcons) do b:Destroy() end
	bulletIcons = {}
	currentMaxAmmo = maxAmmo

	local totalW = maxAmmo * BULLET_W + (maxAmmo - 1) * BULLET_GAP
	local startX = math.floor((AMMO_W - totalW) / 2)

	for i = 1, maxAmmo do
		local b = Instance.new("Frame")
		b.Size             = UDim2.new(0, BULLET_W, 0, BULLET_H)
		b.Position         = UDim2.new(0, startX + (i - 1) * (BULLET_W + BULLET_GAP), 0.5, -BULLET_H / 2)
		b.BackgroundColor3 = C.bulletLoaded
		b.BorderSizePixel  = 0
		b.ZIndex           = 15
		b.Parent           = ammoPanel
		local bc = Instance.new("UICorner")
		bc.CornerRadius = UDim.new(0, 3)
		bc.Parent = b
		bulletIcons[i] = b
	end
end

-- ── Scoreboard (Tab hold) ─────────────────────────────────────────────────────

local sbOverlay = Instance.new("Frame")
sbOverlay.Name                   = "Scoreboard"
sbOverlay.Size                   = UDim2.fromScale(1, 1)
sbOverlay.BackgroundColor3       = Color3.new(0, 0, 0)
sbOverlay.BackgroundTransparency = 0.55
sbOverlay.BorderSizePixel        = 0
sbOverlay.ZIndex                 = 28
sbOverlay.Visible                = false
sbOverlay.Parent                 = screen

local sbPanel = Instance.new("Frame")
sbPanel.Size                   = UDim2.new(0, 400, 0, 320)
sbPanel.AnchorPoint            = Vector2.new(0.5, 0.5)
sbPanel.Position               = UDim2.fromScale(0.5, 0.5)
sbPanel.BackgroundColor3       = C.panelBg
sbPanel.BackgroundTransparency = 0.2
sbPanel.BorderSizePixel        = 0
sbPanel.ZIndex                 = 29
sbPanel.Parent                 = sbOverlay
local sbCorner = Instance.new("UICorner")
sbCorner.CornerRadius = UDim.new(0, 10)
sbCorner.Parent = sbPanel

-- Scoreboard header
local sbHeader = label(sbPanel,
	UDim2.new(1, 0, 0, 38),
	UDim2.new(0, 0, 0, 0),
	"SCOREBOARD", C.scoreGold, Enum.Font.GothamBold)
sbHeader.ZIndex = 30

local sbDivider = Instance.new("Frame")
sbDivider.Size             = UDim2.new(0.9, 0, 0, 1)
sbDivider.AnchorPoint      = Vector2.new(0.5, 0)
sbDivider.Position         = UDim2.new(0.5, 0, 0, 40)
sbDivider.BackgroundColor3 = C.textDim
sbDivider.BackgroundTransparency = 0.4
sbDivider.BorderSizePixel  = 0
sbDivider.ZIndex           = 30
sbDivider.Parent           = sbPanel

-- Scrollable list frame
local sbList = Instance.new("Frame")
sbList.Size             = UDim2.new(1, -24, 1, -52)
sbList.Position         = UDim2.new(0, 12, 0, 46)
sbList.BackgroundTransparency = 1
sbList.BorderSizePixel  = 0
sbList.ZIndex           = 30
sbList.Parent           = sbPanel

local sbLayout = Instance.new("UIListLayout")
sbLayout.SortOrder        = Enum.SortOrder.LayoutOrder
sbLayout.Padding          = UDim.new(0, 4)
sbLayout.Parent           = sbList

-- Row factory
local sbRows = {}

local function ensureRows(count)
	for i = #sbRows + 1, count do
		local row = Instance.new("Frame")
		row.Size                   = UDim2.new(1, 0, 0, 34)
		row.BackgroundColor3       = Color3.new(1, 1, 1)
		row.BackgroundTransparency = 0.92
		row.BorderSizePixel        = 0
		row.LayoutOrder            = i
		row.ZIndex                 = 31
		row.Parent                 = sbList
		local rc = Instance.new("UICorner")
		rc.CornerRadius = UDim.new(0, 5)
		rc.Parent = row

		-- Rank
		local rank = Instance.new("TextLabel")
		rank.Name                   = "Rank"
		rank.Size                   = UDim2.new(0, 28, 1, 0)
		rank.Position               = UDim2.new(0, 8, 0, 0)
		rank.BackgroundTransparency = 1
		rank.TextColor3             = C.textDim
		rank.Font                   = Enum.Font.GothamBold
		rank.TextScaled             = true
		rank.TextXAlignment         = Enum.TextXAlignment.Left
		rank.ZIndex                 = 32
		rank.Parent                 = row

		-- Name
		local name = Instance.new("TextLabel")
		name.Name                   = "Name"
		name.Size                   = UDim2.new(1, -80, 1, 0)
		name.Position               = UDim2.new(0, 44, 0, 0)
		name.BackgroundTransparency = 1
		name.TextColor3             = C.textWhite
		name.Font                   = Enum.Font.Gotham
		name.TextScaled             = true
		name.TextXAlignment         = Enum.TextXAlignment.Left
		name.ZIndex                 = 32
		name.Parent                 = row

		-- Kills
		local kills = Instance.new("TextLabel")
		kills.Name                   = "Kills"
		kills.Size                   = UDim2.new(0, 50, 1, 0)
		kills.Position               = UDim2.new(1, -58, 0, 0)
		kills.BackgroundTransparency = 1
		kills.TextColor3             = C.scoreGold
		kills.Font                   = Enum.Font.GothamBold
		kills.TextScaled             = true
		kills.TextXAlignment         = Enum.TextXAlignment.Right
		kills.ZIndex                 = 32
		kills.Parent                 = row

		sbRows[i] = row
	end
end

local storedScores = {}

local function refreshScoreboard()
	ensureRows(#storedScores)
	local localUserId = player.UserId

	for i, entry in ipairs(storedScores) do
		local row  = sbRows[i]
		row.Visible = true

		-- Highlight local player
		local isLocal = entry.userId == localUserId
		row.BackgroundTransparency = isLocal and 0.78 or 0.92
		row.BackgroundColor3       = isLocal
			and Color3.fromRGB(80, 60, 20)
			or  Color3.new(1, 1, 1)

		row:FindFirstChild("Rank").Text  = "#" .. i
		row:FindFirstChild("Name").Text  = entry.name
		row:FindFirstChild("Kills").Text = tostring(entry.kills)
	end

	-- Hide unused rows
	for i = #storedScores + 1, #sbRows do
		sbRows[i].Visible = false
	end
end

-- ── Public API ────────────────────────────────────────────────────────────────

local HUD = {}

function HUD.setHP(hp, maxHp)
	local pct = math.clamp(hp / maxHp, 0, 1)
	hpNum.Text = tostring(math.ceil(hp))
	TweenService:Create(barFill, BAR_TWEEN, {
		Size             = UDim2.new(pct, 0, 1, 0),
		BackgroundColor3 = hpColor(pct),
	}):Play()
end

function HUD.setAmmo(ammo, maxAmmo, isReloading)
	-- Rebuild bullet icons if max ammo changed
	if maxAmmo ~= currentMaxAmmo then
		rebuildBullets(maxAmmo)
	end

	reloadLbl.Visible = isReloading
	for i, icon in ipairs(bulletIcons) do
		icon.BackgroundColor3 = (i <= ammo) and C.bulletLoaded or C.bulletSpent
	end
end

function HUD.setScores(scoreList)
	storedScores = scoreList
	if sbOverlay.Visible then
		refreshScoreboard()
	end
end

function HUD.showScoreboard(visible)
	sbOverlay.Visible = visible
	if visible then
		refreshScoreboard()
	end
end

return HUD
