-- EconomyController (LocalScript)
-- Progression hub: rotating shop, full Season Road, and ranked profile.
-- Purchases and claims remain server-authoritative.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remotes = game.ReplicatedStorage:WaitForChild("Remotes", 15)
if not remotes then
	error("[EconomyController] Remotes folder missing")
end

local profileUpdated = remotes:WaitForChild("EconomyProfileUpdated", 15)
local profileRequested = remotes:WaitForChild("EconomyProfileRequested", 15)
local purchaseRequested = remotes:WaitForChild("CosmeticPurchaseRequested", 15)
local equipRequested = remotes:WaitForChild("CosmeticEquipRequested", 15)
local dailyLoginClaimed = remotes:WaitForChild("DailyLoginRewardClaimed", 15)
local seasonRewardClaimed = remotes:WaitForChild("SeasonRewardClaimed", 15)

local CosmeticState = require(game.ReplicatedStorage.Client.CosmeticState)
local Theme = require(game.ReplicatedStorage.Client.UITheme)

local profile = nil
local currentTab = "Shop"
local shopRows = {}
local seasonRows = {}
local profileLabels = {}
local tabButtons = {}
local selectedCosmeticId = nil

local gui = Instance.new("ScreenGui")
gui.Name = "EconomyUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local wallet = Instance.new("Frame")
wallet.Name = "Wallet"
wallet.Size = UDim2.new(0, 260, 0, 52)
wallet.Position = UDim2.new(0, 14, 0, 14)
wallet.ZIndex = 35
wallet.Parent = gui
Theme.stylePanel(wallet, {
	transparency = 0.08,
	strokeColor = Theme.colors.gold,
	strokeTransparency = 0.42,
	corner = Theme.smallCorner,
})

local walletLabel = Instance.new("TextLabel")
walletLabel.Size = UDim2.new(1, -14, 1, -8)
walletLabel.Position = UDim2.new(0, 8, 0, 4)
walletLabel.TextColor3 = Theme.colors.gold
walletLabel.TextScaled = true
walletLabel.Font = Theme.fonts.title
walletLabel.TextXAlignment = Enum.TextXAlignment.Left
walletLabel.Text = "Coins 0 | Lv 1 | Bronze"
walletLabel.ZIndex = 36
walletLabel.Parent = wallet
Theme.styleLabel(walletLabel, Theme.colors.gold, Theme.fonts.title)

local overlay = Instance.new("Frame")
overlay.Name = "ProgressionOverlay"
overlay.Size = UDim2.fromScale(1, 1)
overlay.BackgroundColor3 = Color3.new(0, 0, 0)
overlay.BackgroundTransparency = 0.42
overlay.BorderSizePixel = 0
overlay.Visible = false
overlay.ZIndex = 40
overlay.Parent = gui

local panel = Instance.new("Frame")
panel.Name = "ProgressionPanel"
panel.Size = UDim2.new(0, 680, 0, 760)
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.ZIndex = 41
panel.Parent = overlay
Theme.stylePanel(panel, {
	transparency = 0.04,
	strokeColor = Theme.colors.cyan,
	strokeTransparency = 0.24,
	strokeThickness = 2,
})

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -28, 0, 44)
title.Position = UDim2.new(0, 14, 0, 10)
title.Text = "PARRYHOOK PROGRESSION  [M]"
title.TextScaled = true
title.TextXAlignment = Enum.TextXAlignment.Left
title.ZIndex = 42
title.Parent = panel
Theme.styleLabel(title, Theme.colors.cyan, Theme.fonts.title)

local subtitle = Instance.new("TextLabel")
subtitle.Size = UDim2.new(1, -28, 0, 24)
subtitle.Position = UDim2.new(0, 14, 0, 52)
subtitle.Text = "Cosmetics only. Rank is status, not power."
subtitle.TextScaled = true
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.ZIndex = 42
subtitle.Parent = panel
Theme.styleLabel(subtitle, Theme.colors.muted, Theme.fonts.body)

local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1, -28, 0, 42)
tabBar.Position = UDim2.new(0, 14, 0, 86)
tabBar.BackgroundTransparency = 1
tabBar.ZIndex = 42
tabBar.Parent = panel

local content = Instance.new("Frame")
content.Size = UDim2.new(1, -28, 1, -142)
content.Position = UDim2.new(0, 14, 0, 134)
content.BackgroundTransparency = 1
content.ZIndex = 42
content.Parent = panel

local pages = {}
for _, name in ipairs({ "Shop", "Season", "Profile" }) do
	local page = Instance.new("Frame")
	page.Name = name .. "Page"
	page.Size = UDim2.fromScale(1, 1)
	page.BackgroundTransparency = 1
	page.Visible = name == currentTab
	page.ZIndex = 42
	page.Parent = content
	pages[name] = page
end

local function makeLabel(parent, text, position, size, color, font, zIndex)
	local label = Instance.new("TextLabel")
	label.Size = size
	label.Position = position
	label.Text = text or ""
	label.TextScaled = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.ZIndex = zIndex or 43
	label.Parent = parent
	Theme.styleLabel(label, color or Theme.colors.text, font or Theme.fonts.body)
	return label
end

local function makeButton(parent, text, position, size, accentColor)
	local button = Instance.new("TextButton")
	button.Size = size
	button.Position = position
	button.Text = text or ""
	button.TextScaled = true
	button.TextXAlignment = Enum.TextXAlignment.Left
	button.ZIndex = 44
	button.Parent = parent
	Theme.styleButton(button, accentColor or Theme.colors.cyan)
	return button
end

local function setPage(name)
	currentTab = name
	for pageName, page in pairs(pages) do
		page.Visible = pageName == name
	end
	for tabName, button in pairs(tabButtons) do
		button.TextColor3 = (tabName == name) and Theme.colors.gold or Theme.colors.text
	end
end

for index, name in ipairs({ "Shop", "Season", "Profile" }) do
	local button = makeButton(
		tabBar,
		"  " .. string.upper(name),
		UDim2.new((index - 1) / 3, (index - 1) * 6, 0, 0),
		UDim2.new(1 / 3, -8, 1, 0),
		name == "Season" and Theme.colors.violet or Theme.colors.cyan
	)
	button.Activated:Connect(function()
		setPage(name)
	end)
	tabButtons[name] = button
end

local dailyClaimButton = makeButton(
	pages.Shop,
	"  DAILY REWARD",
	UDim2.new(0, 0, 0, 0),
	UDim2.new(1, 0, 0, 42),
	Theme.colors.gold
)

makeLabel(pages.Shop, "DAILY SHOP", UDim2.new(0, 0, 0, 52), UDim2.new(0.48, 0, 0, 26), Theme.colors.gold, Theme.fonts.title)
makeLabel(pages.Shop, "WEEKLY SHOP", UDim2.new(0.52, 0, 0, 52), UDim2.new(0.48, 0, 0, 26), Theme.colors.violet, Theme.fonts.title)
makeLabel(pages.Shop, "CATALOG", UDim2.new(0, 0, 0, 236), UDim2.new(1, 0, 0, 26), Theme.colors.cyan, Theme.fonts.title)

local shopResetLabel = makeLabel(
	pages.Shop,
	"",
	UDim2.new(0, 0, 0, 206),
	UDim2.new(1, 0, 0, 24),
	Theme.colors.muted,
	Theme.fonts.body
)

for index = 1, 13 do
	local xScale = 0
	local y = 82 + (index - 1) * 44
	local widthScale = 1
	if index <= 4 then
		xScale = 0
		y = 82 + (index - 1) * 30
		widthScale = 0.48
	elseif index <= 9 then
		xScale = 0.52
		y = 82 + (index - 5) * 30
		widthScale = 0.48
	else
		xScale = 0
		y = 266 + (index - 10) * 48
		widthScale = 1
	end

	local button = makeButton(
		pages.Shop,
		"",
		UDim2.new(xScale, 0, 0, y),
		UDim2.new(widthScale, 0, 0, index <= 9 and 26 or 42),
		index <= 4 and Theme.colors.gold or Theme.colors.cyan
	)
	shopRows[index] = {
		button = button,
		cosmeticId = nil,
	}
end

local previewPanel = Instance.new("Frame")
previewPanel.Size = UDim2.new(1, 0, 0, 130)
previewPanel.Position = UDim2.new(0, 0, 1, -130)
previewPanel.ZIndex = 43
previewPanel.Parent = pages.Shop
Theme.stylePanel(previewPanel, {
	transparency = 0.08,
	strokeColor = Theme.colors.pink,
	strokeTransparency = 0.42,
	corner = Theme.smallCorner,
})

local previewTitle = makeLabel(
	previewPanel,
	"PREVIEW",
	UDim2.new(0, 12, 0, 8),
	UDim2.new(0.56, -12, 0, 28),
	Theme.colors.pink,
	Theme.fonts.title,
	44
)

local previewDesc = makeLabel(
	previewPanel,
	"Select a cosmetic to inspect it before buying or equipping.",
	UDim2.new(0, 12, 0, 40),
	UDim2.new(0.56, -12, 0, 44),
	Theme.colors.text,
	Theme.fonts.body,
	44
)
previewDesc.TextWrapped = true

local previewActionButton = makeButton(
	previewPanel,
	"  SELECT ITEM",
	UDim2.new(0, 12, 1, -38),
	UDim2.new(0.56, -12, 0, 30),
	Theme.colors.pink
)
previewActionButton.ZIndex = 45
previewActionButton.Active = false

local previewArt = Instance.new("Frame")
previewArt.Size = UDim2.new(0.38, -10, 1, -24)
previewArt.Position = UDim2.new(0.6, 0, 0, 12)
previewArt.BackgroundColor3 = Theme.colors.panelLift
previewArt.BackgroundTransparency = 0.08
previewArt.ZIndex = 44
previewArt.Parent = previewPanel
Theme.applyCorner(previewArt, Theme.smallCorner)
Theme.applyStroke(previewArt, Theme.colors.pink, 0.48, 1)

local previewPrimary = Instance.new("Frame")
previewPrimary.Size = UDim2.new(0, 86, 0, 20)
previewPrimary.AnchorPoint = Vector2.new(0.5, 0.5)
previewPrimary.Position = UDim2.fromScale(0.5, 0.42)
previewPrimary.BackgroundColor3 = Theme.colors.cyan
previewPrimary.ZIndex = 45
previewPrimary.Parent = previewArt
Theme.applyCorner(previewPrimary, UDim.new(1, 0))

local previewSecondary = Instance.new("Frame")
previewSecondary.Size = UDim2.new(0, 132, 0, 6)
previewSecondary.AnchorPoint = Vector2.new(0.5, 0.5)
previewSecondary.Position = UDim2.fromScale(0.5, 0.62)
previewSecondary.BackgroundColor3 = Theme.colors.gold
previewSecondary.ZIndex = 45
previewSecondary.Parent = previewArt
Theme.applyCorner(previewSecondary, UDim.new(1, 0))

local previewSlot = makeLabel(
	previewArt,
	"",
	UDim2.new(0, 8, 1, -28),
	UDim2.new(1, -16, 0, 20),
	Theme.colors.muted,
	Theme.fonts.bold,
	46
)
previewSlot.TextXAlignment = Enum.TextXAlignment.Center

makeLabel(pages.Season, "SEASON ROAD", UDim2.new(0, 0, 0, 0), UDim2.new(0.5, 0, 0, 34), Theme.colors.violet, Theme.fonts.title)
local seasonProgressLabel = makeLabel(
	pages.Season,
	"",
	UDim2.new(0.5, 0, 0, 4),
	UDim2.new(0.5, 0, 0, 24),
	Theme.colors.muted,
	Theme.fonts.body
)

for index = 1, 10 do
	local row = makeButton(
		pages.Season,
		"",
		UDim2.new(0, 0, 0, 44 + (index - 1) * 52),
		UDim2.new(1, 0, 0, 46),
		Theme.colors.violet
	)
	seasonRows[index] = {
		button = row,
		rewardId = nil,
	}
end

makeLabel(pages.Profile, "RANKED PROFILE", UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 0, 38), Theme.colors.gold, Theme.fonts.title)
local profileKeys = {
	"rank",
	"rating",
	"record",
	"winrate",
	"kills",
	"damage",
	"parry",
	"mobility",
	"equipped",
}
for index, key in ipairs(profileKeys) do
	profileLabels[key] = makeLabel(
		pages.Profile,
		"",
		UDim2.new(0, 0, 0, 52 + (index - 1) * 44),
		UDim2.new(1, 0, 0, 34),
		index <= 2 and Theme.colors.cyan or Theme.colors.text,
		index <= 2 and Theme.fonts.title or Theme.fonts.body
	)
end

local function setHubVisible(visible)
	overlay.Visible = visible
end

local function cosmeticLabel(cosmeticId)
	local cosmetic = profile and profile.cosmetics and profile.cosmetics[cosmeticId]
	if not cosmetic then
		return cosmeticId or "Unknown"
	end
	return string.format("%s [%s] - %dC", cosmetic.name, cosmetic.rarity or "Common", cosmetic.price or 0)
end

local function cosmeticAction(cosmetic)
	if not profile or not cosmetic then return "" end
	local owned = profile.ownedCosmetics and profile.ownedCosmetics[cosmetic.id]
	local equipped = profile.equipped and profile.equipped[cosmetic.slot] == cosmetic.id
	if equipped then return "EQUIPPED" end
	if owned then return "EQUIP" end
	return "BUY"
end

local function slotLabel(slot)
	if slot == "projectileSkin" then return "PROJECTILE" end
	if slot == "hookTrail" then return "HOOK TRAIL" end
	if slot == "parryAura" then return "PARRY AURA" end
	if slot == "title" then return "TITLE" end
	return string.upper(tostring(slot or "COSMETIC"))
end

local function updatePreview(cosmeticId)
	selectedCosmeticId = cosmeticId
	local cosmetic = profile and profile.cosmetics and cosmeticId and profile.cosmetics[cosmeticId]
	if not cosmetic then
		previewTitle.Text = "PREVIEW"
		previewDesc.Text = "Select a cosmetic to inspect it before buying or equipping."
		previewActionButton.Text = "  SELECT ITEM"
		previewActionButton.Active = false
		previewActionButton.AutoButtonColor = false
		previewPrimary.BackgroundColor3 = Theme.colors.cyan
		previewSecondary.BackgroundColor3 = Theme.colors.gold
		previewSlot.Text = ""
		return
	end

	local action = cosmeticAction(cosmetic)
	local primary = cosmetic.primaryColor or Theme.colors.gold
	local secondary = cosmetic.secondaryColor or Theme.colors.cyan
	previewTitle.Text = string.format("%s  [%s]", cosmetic.name, cosmetic.rarity or "Common")
	previewDesc.Text = string.format(
		"%s cosmetic. Price: %d coins. Status: %s.",
		slotLabel(cosmetic.slot),
		cosmetic.price or 0,
		action
	)
	previewActionButton.Active = action ~= "EQUIPPED"
	previewActionButton.AutoButtonColor = action ~= "EQUIPPED"
	previewActionButton.TextColor3 = action == "EQUIPPED" and Theme.colors.muted or Theme.colors.gold
	previewActionButton.Text = "  " .. action
	previewPrimary.BackgroundColor3 = primary
	previewSecondary.BackgroundColor3 = secondary
	previewSlot.Text = slotLabel(cosmetic.slot)

	if cosmetic.slot == "title" then
		previewPrimary.Size = UDim2.new(0, 150, 0, 28)
		previewSecondary.Size = UDim2.new(0, 110, 0, 4)
	else
		previewPrimary.Size = UDim2.new(0, 86, 0, 20)
		previewSecondary.Size = UDim2.new(0, 132, 0, 6)
	end
end

local function refreshDailyReward()
	local loginReward = profile and profile.loginReward
	if not loginReward then
		dailyClaimButton.Visible = false
		return
	end
	dailyClaimButton.Visible = true
	dailyClaimButton.Active = loginReward.canClaim == true
	dailyClaimButton.AutoButtonColor = loginReward.canClaim == true
	local status = loginReward.canClaim and "CLAIM" or "CLAIMED"
	dailyClaimButton.TextColor3 = loginReward.canClaim and Theme.colors.gold or Theme.colors.muted
	dailyClaimButton.Text = string.format(
		"  DAILY REWARD  |  Streak %d  |  +%dC / +%dXP  [%s]",
		loginReward.nextStreak or loginReward.streak or 1,
		loginReward.coins or 0,
		loginReward.xp or 0,
		status
	)
end

local function refreshShop()
	if not profile then return end
	refreshDailyReward()

	local dailyItems = profile.shop and profile.shop.dailyItems or {}
	local weeklyItems = profile.shop and profile.shop.weeklyItems or {}
	local firstSelectable = nil
	shopResetLabel.Text = string.format(
		"Daily reset day %s | Weekly reset day %s",
		tostring(profile.shop and profile.shop.resetDay or "?"),
		tostring(profile.shop and profile.shop.weeklyResetDay or "?")
	)

	local rowIndex = 1
	for _, cosmeticId in ipairs(dailyItems) do
		local row = shopRows[rowIndex]
		local cosmetic = profile.cosmetics and profile.cosmetics[cosmeticId]
		if row and cosmetic then
			firstSelectable = firstSelectable or cosmeticId
			row.cosmeticId = cosmeticId
			row.button.Visible = true
			row.button.Text = "  " .. cosmeticLabel(cosmeticId) .. "  [" .. cosmeticAction(cosmetic) .. "]"
			rowIndex += 1
		end
	end

	rowIndex = 5
	for _, cosmeticId in ipairs(weeklyItems) do
		local row = shopRows[rowIndex]
		local cosmetic = profile.cosmetics and profile.cosmetics[cosmeticId]
		if row and cosmetic then
			firstSelectable = firstSelectable or cosmeticId
			row.cosmeticId = cosmeticId
			row.button.Visible = true
			row.button.Text = "  " .. cosmeticLabel(cosmeticId) .. "  [" .. cosmeticAction(cosmetic) .. "]"
			rowIndex += 1
		end
	end

	local catalog = {}
	for _, cosmetic in pairs(profile.cosmetics or {}) do
		local owned = profile.ownedCosmetics and profile.ownedCosmetics[cosmetic.id]
		if not cosmetic.defaultOwned and (not cosmetic.seasonOnly or owned) then
			table.insert(catalog, cosmetic)
		end
	end
	table.sort(catalog, function(a, b)
		if a.slot ~= b.slot then return a.slot < b.slot end
		return (a.price or 0) < (b.price or 0)
	end)

	for index = 10, #shopRows do
		local row = shopRows[index]
		local cosmetic = catalog[index - 9]
		row.cosmeticId = cosmetic and cosmetic.id or nil
		row.button.Visible = cosmetic ~= nil
		if cosmetic then
			firstSelectable = firstSelectable or cosmetic.id
			row.button.Text = string.format(
				"  %s [%s]  %s  |  %d coins  |  %s",
				cosmetic.name,
				cosmetic.rarity or "Common",
				cosmetic.slot,
				cosmetic.price or 0,
				cosmeticAction(cosmetic)
			)
		end
	end

	if not selectedCosmeticId or not (profile.cosmetics and profile.cosmetics[selectedCosmeticId]) then
		selectedCosmeticId = firstSelectable
	end
	updatePreview(selectedCosmeticId)
end

local function seasonRewardText(reward)
	if reward.cosmeticId then
		local cosmetic = profile and profile.cosmetics and profile.cosmetics[reward.cosmeticId]
		return cosmetic and cosmetic.name or reward.name or "Cosmetic"
	end
	if reward.coins and reward.coins > 0 then
		return string.format("%d coins", reward.coins)
	end
	return reward.name or "Reward"
end

local function refreshSeason()
	if not profile then return end
	seasonProgressLabel.Text = string.format("Level %d | XP %d", profile.level or 1, profile.xp or 0)
	local rewards = profile.season and profile.season.rewards or {}
	for index, row in ipairs(seasonRows) do
		local reward = rewards[index]
		row.rewardId = reward and reward.id or nil
		row.button.Visible = reward ~= nil
		if reward then
			local status = "LOCKED"
			if reward.claimed then
				status = "CLAIMED"
			elseif reward.unlocked then
				status = "CLAIM"
			end
			row.button.Active = reward.unlocked and not reward.claimed
			row.button.AutoButtonColor = row.button.Active
			row.button.TextColor3 = row.button.Active and Theme.colors.gold or Theme.colors.muted
			row.button.Text = string.format(
				"  Lv %d  |  %s  |  %s",
				reward.level or 1,
				seasonRewardText(reward),
				status
			)
		end
	end
end

local function equippedName(slot)
	local equippedId = profile and profile.equipped and profile.equipped[slot]
	local cosmetic = equippedId and profile.cosmetics and profile.cosmetics[equippedId]
	return cosmetic and cosmetic.name or "None"
end

local function refreshProfile()
	if not profile then return end
	local ranked = profile.ranked or {}
	local rank = ranked.rank or { name = "Bronze" }
	local stats = profile.lifetimeStats or {}
	local matches = math.max(0, stats.matchesPlayed or ranked.matches or 0)
	local wins = math.max(0, stats.wins or ranked.wins or 0)
	local winrate = matches > 0 and math.floor((wins / matches) * 100 + 0.5) or 0

	profileLabels.rank.Text = string.format("Rank: %s", rank.name or "Bronze")
	profileLabels.rating.Text = string.format("Rating: %d  |  Peak: %d", ranked.rating or 1000, ranked.peakRating or 1000)
	profileLabels.record.Text = string.format("Matches: %d  |  Wins: %d", matches, wins)
	profileLabels.winrate.Text = string.format("Win rate: %d%%", winrate)
	profileLabels.kills.Text = string.format("Kills: %d  |  Deaths: %d", stats.kills or 0, stats.deaths or 0)
	profileLabels.damage.Text = string.format("Damage dealt: %d", stats.damageDealt or 0)
	profileLabels.parry.Text = string.format(
		"Perfect Parries: %d  |  Clashes: %d",
		stats.perfectParries or 0,
		stats.parryClashes or 0
	)
	profileLabels.mobility.Text = string.format(
		"Air Shots: %d  |  Hook Slingshots: %d",
		stats.airShots or 0,
		stats.grappleSlingshots or 0
	)
	profileLabels.equipped.Text = string.format(
		"Equipped: %s / %s / %s / [%s]",
		equippedName("projectileSkin"),
		equippedName("hookTrail"),
		equippedName("parryAura"),
		equippedName("title")
	)
end

local function refreshWallet()
	if not profile then return end
	local rankName = profile.ranked and profile.ranked.rank and profile.ranked.rank.name or "Bronze"
	walletLabel.Text = string.format("Coins %d | Lv %d | %s", profile.coins or 0, profile.level or 1, rankName)
end

local function refresh()
	if not profile then return end
	refreshWallet()
	refreshShop()
	refreshSeason()
	refreshProfile()
	setPage(currentTab)
end

local function requestCosmeticAction(cosmeticId)
	if not profile or not cosmeticId then return end
	local cosmetic = profile.cosmetics and profile.cosmetics[cosmeticId]
	if not cosmetic then return end
	local owned = profile.ownedCosmetics and profile.ownedCosmetics[cosmeticId]
	local equipped = profile.equipped and profile.equipped[cosmetic.slot] == cosmeticId
	if equipped then return end
	if owned then
		equipRequested:FireServer(cosmeticId)
	else
		purchaseRequested:FireServer(cosmeticId)
	end
end

for _, row in ipairs(shopRows) do
	row.button.Activated:Connect(function()
		updatePreview(row.cosmeticId)
	end)
end

previewActionButton.Activated:Connect(function()
	requestCosmeticAction(selectedCosmeticId)
end)

for _, row in ipairs(seasonRows) do
	row.button.Activated:Connect(function()
		if not row.rewardId then return end
		seasonRewardClaimed:FireServer(row.rewardId)
	end)
end

dailyClaimButton.Activated:Connect(function()
	local loginReward = profile and profile.loginReward
	if not loginReward or not loginReward.canClaim then return end
	dailyLoginClaimed:FireServer()
end)

if profileUpdated then
	profileUpdated.OnClientEvent:Connect(function(newProfile)
		profile = newProfile
		CosmeticState.setProfile(newProfile)
		refresh()
	end)
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.M then
		setHubVisible(not overlay.Visible)
	end
end)

setPage(currentTab)
if profileRequested then
	profileRequested:FireServer()
end
