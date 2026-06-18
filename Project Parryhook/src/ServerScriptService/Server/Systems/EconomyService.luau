-- EconomyService (ModuleScript - server only)
-- Persistent cosmetic economy. This deliberately grants only style/progression,
-- never competitive power.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local EconomyConfig = require(game.ReplicatedStorage.Shared.Constants.EconomyConfig)

local remotes = game.ReplicatedStorage:WaitForChild("Remotes")
local profileUpdated = remotes:WaitForChild("EconomyProfileUpdated")
local profileRequested = remotes:WaitForChild("EconomyProfileRequested")
local purchaseRequested = remotes:WaitForChild("CosmeticPurchaseRequested")
local equipRequested = remotes:WaitForChild("CosmeticEquipRequested")
local dailyLoginClaimed = remotes:WaitForChild("DailyLoginRewardClaimed")
local seasonRewardClaimed = remotes:WaitForChild("SeasonRewardClaimed")

local store = DataStoreService:GetDataStore(EconomyConfig.DATASTORE_NAME)

local EconomyService = {}

local profiles = {}
local dirty = {}
local saveQueued = {}
local remoteCooldowns = {}
local saveBlocked = {}
local queueSave = nil

local function currentDayNumber()
	return math.floor(os.time() / 86400)
end

local function defaultRanked()
	return {
		rating = EconomyConfig.RANKING.START_RATING,
		peakRating = EconomyConfig.RANKING.START_RATING,
		matches = 0,
		wins = 0,
	}
end

local function defaultLifetimeStats()
	return {
		kills = 0,
		deaths = 0,
		wins = 0,
		damageDealt = 0,
		perfectParries = 0,
		parryClashes = 0,
		airShots = 0,
		grappleSlingshots = 0,
		matchesPlayed = 0,
	}
end

local function defaultProfile()
	return {
		coins = 0,
		xp = 0,
		ownedCosmetics = EconomyConfig.getDefaultOwned(),
		equipped = table.clone(EconomyConfig.DEFAULT_EQUIPPED),
		daily = nil,
		loginReward = {
			lastClaimDay = nil,
			streak = 0,
		},
		season = {
			claimedRewards = {},
		},
		ranked = defaultRanked(),
		lifetimeStats = defaultLifetimeStats(),
	}
end

local function ensureDaily(profile)
	local dayNumber = currentDayNumber()
	local dayKey = tostring(dayNumber)
	if type(profile.daily) == "table" and profile.daily.date == dayKey then
		profile.daily.challenges = profile.daily.challenges or {}
		for _, challenge in ipairs(EconomyConfig.getDailyChallengeSet(dayNumber)) do
			if not profile.daily.challenges[challenge.id] then
				profile.daily.challenges[challenge.id] = {
					progress = 0,
					completed = false,
					rewarded = false,
				}
			end
		end
		return profile.daily
	end

	local daily = {
		date = dayKey,
		challenges = {},
	}

	for _, challenge in ipairs(EconomyConfig.getDailyChallengeSet(dayNumber)) do
		daily.challenges[challenge.id] = {
			progress = 0,
			completed = false,
			rewarded = false,
		}
	end

	profile.daily = daily
	return daily
end

local function sanitizeProfile(data)
	local profile = defaultProfile()
	if type(data) ~= "table" then
		return profile
	end

	profile.coins = math.max(0, math.floor(tonumber(data.coins) or 0))
	profile.xp = math.max(0, math.floor(tonumber(data.xp) or 0))

	if type(data.ownedCosmetics) == "table" then
		for id, owned in pairs(data.ownedCosmetics) do
			if owned == true and EconomyConfig.COSMETICS[id] then
				profile.ownedCosmetics[id] = true
			end
		end
	end

	if type(data.equipped) == "table" then
		for slot, id in pairs(data.equipped) do
			local cosmetic = EconomyConfig.COSMETICS[id]
			if cosmetic and cosmetic.slot == slot and profile.ownedCosmetics[id] then
				profile.equipped[slot] = id
			end
		end
	end

	if type(data.daily) == "table" then
		profile.daily = data.daily
	end
	if type(data.loginReward) == "table" then
		profile.loginReward = {
			lastClaimDay = data.loginReward.lastClaimDay,
			streak = math.max(0, math.floor(tonumber(data.loginReward.streak) or 0)),
		}
	end
	if type(data.season) == "table" and type(data.season.claimedRewards) == "table" then
		profile.season = { claimedRewards = {} }
		for rewardId, claimed in pairs(data.season.claimedRewards) do
			if claimed == true then
				profile.season.claimedRewards[rewardId] = true
			end
		end
	end
	if type(data.ranked) == "table" then
		profile.ranked = {
			rating = math.max(0, math.floor(tonumber(data.ranked.rating) or EconomyConfig.RANKING.START_RATING)),
			peakRating = math.max(0, math.floor(tonumber(data.ranked.peakRating) or EconomyConfig.RANKING.START_RATING)),
			matches = math.max(0, math.floor(tonumber(data.ranked.matches) or 0)),
			wins = math.max(0, math.floor(tonumber(data.ranked.wins) or 0)),
		}
		profile.ranked.peakRating = math.max(profile.ranked.peakRating, profile.ranked.rating)
	end
	if type(data.lifetimeStats) == "table" then
		profile.lifetimeStats = defaultLifetimeStats()
		for statName, defaultValue in pairs(profile.lifetimeStats) do
			profile.lifetimeStats[statName] = math.max(0, math.floor(tonumber(data.lifetimeStats[statName]) or defaultValue))
		end
	end
	ensureDaily(profile)

	return profile
end

local function publicProfile(profile)
	local daily = ensureDaily(profile)
	profile.season = profile.season or { claimedRewards = {} }
	local loginReward = profile.loginReward or { streak = 0 }
	local today = currentDayNumber()
	local lastClaimDay = tonumber(loginReward.lastClaimDay)
	local nextStreak = 1
	if lastClaimDay == today - 1 then
		nextStreak = (loginReward.streak or 0) + 1
	elseif lastClaimDay == today then
		nextStreak = loginReward.streak or 1
	end
	local rewardPreview = EconomyConfig.getDailyLoginReward(nextStreak)
	local dailyChallenges = {}
	local level = EconomyConfig.getLevelFromXp(profile.xp)
	profile.ranked = profile.ranked or defaultRanked()
	profile.lifetimeStats = profile.lifetimeStats or defaultLifetimeStats()
	local rank = EconomyConfig.getRankFromRating(profile.ranked.rating)
	local shopRotation = EconomyConfig.getShopRotation(today)
	local seasonRewards = {}
	local challengeDefs = EconomyConfig.getDailyChallengeSet(tonumber(daily.date) or currentDayNumber())
	for _, challenge in ipairs(challengeDefs) do
		local state = daily.challenges[challenge.id] or {}
		table.insert(dailyChallenges, {
			id = challenge.id,
			name = challenge.name,
			description = challenge.description,
			stat = challenge.stat,
			target = challenge.target,
			progress = math.floor(math.min(state.progress or 0, challenge.target)),
			completed = state.completed == true,
			xp = challenge.xp,
			coins = challenge.coins,
		})
	end
	for _, reward in ipairs(EconomyConfig.SEASON_REWARDS) do
		table.insert(seasonRewards, {
			id = reward.id,
			level = reward.level,
			name = reward.name,
			coins = reward.coins or 0,
			cosmeticId = reward.cosmeticId,
			unlocked = level >= reward.level,
			claimed = profile.season.claimedRewards[reward.id] == true,
		})
	end

	local payload = {
		coins = profile.coins,
		xp = profile.xp,
		level = level,
		ownedCosmetics = table.clone(profile.ownedCosmetics),
		equipped = table.clone(profile.equipped),
		cosmetics = EconomyConfig.COSMETICS,
		daily = {
			date = daily.date,
			challenges = dailyChallenges,
		},
		loginReward = {
			canClaim = lastClaimDay ~= today,
			streak = loginReward.streak or 0,
			nextStreak = nextStreak,
			coins = rewardPreview.coins,
			xp = rewardPreview.xp,
		},
		season = {
			rewards = seasonRewards,
		},
		ranked = {
			rating = profile.ranked.rating,
			peakRating = profile.ranked.peakRating,
			matches = profile.ranked.matches,
			wins = profile.ranked.wins,
			rank = {
				id = rank.id,
				name = rank.name,
				minRating = rank.minRating,
				color = rank.color,
			},
		},
		lifetimeStats = table.clone(profile.lifetimeStats),
		shop = shopRotation,
	}
	return payload
end

local function getKey(player)
	return "player_" .. player.UserId
end

local function saveProfile(player)
	local profile = profiles[player.UserId]
	if not profile then return end
	if saveBlocked[player.UserId] then
		warn(string.format("[Economy] Skipping save for %s because profile load failed", player.Name))
		return
	end

	local ok, err = pcall(function()
		store:SetAsync(getKey(player), profile)
	end)
	if ok then
		dirty[player.UserId] = nil
	else
		warn(string.format("[Economy] Failed to save %s: %s", player.Name, tostring(err)))
		queueSave(player)
	end
end

queueSave = function(player)
	if saveQueued[player.UserId] then return end
	saveQueued[player.UserId] = true

	task.delay(8, function()
		saveQueued[player.UserId] = nil
		if dirty[player.UserId] then
			saveProfile(player)
		end
	end)
end

local function markDirty(player)
	dirty[player.UserId] = true
	queueSave(player)
end

local function canUseRemote(player, action, cooldown)
	if not player then return false end
	local userCooldowns = remoteCooldowns[player.UserId]
	if not userCooldowns then
		userCooldowns = {}
		remoteCooldowns[player.UserId] = userCooldowns
	end

	local now = os.clock()
	local lastUsed = userCooldowns[action] or 0
	if now - lastUsed < cooldown then
		return false
	end
	userCooldowns[action] = now
	return true
end

local function sendProfile(player)
	local profile = profiles[player.UserId]
	if not profile then return end
	profileUpdated:FireClient(player, publicProfile(profile))
end

local function loadProfile(player)
	local data = nil
	local ok, err = pcall(function()
		data = store:GetAsync(getKey(player))
	end)
	if not ok then
		warn(string.format("[Economy] Failed to load %s: %s", player.Name, tostring(err)))
		saveBlocked[player.UserId] = true
	else
		saveBlocked[player.UserId] = nil
	end

	profiles[player.UserId] = sanitizeProfile(data)
	sendProfile(player)
end

function EconomyService.getProfile(player)
	local profile = profiles[player.UserId]
	if not profile then
		profile = defaultProfile()
		profiles[player.UserId] = profile
	end
	ensureDaily(profile)
	return profile
end

function EconomyService.getEquippedCosmetic(player, slot)
	local profile = EconomyService.getProfile(player)
	local cosmeticId = profile.equipped and profile.equipped[slot]
	if cosmeticId and EconomyConfig.COSMETICS[cosmeticId] then
		return cosmeticId
	end
	return EconomyConfig.DEFAULT_EQUIPPED[slot]
end

local function performanceBonus(entry)
	local bonus = 0
	bonus += math.min(4, math.max(0, entry.kills or 0))
	bonus += math.min(2, math.floor(math.max(0, entry.damageDealt or 0) / 350))
	bonus += math.min(2, math.max(0, entry.perfectParries or 0))
	bonus += math.min(2, math.max(0, entry.grappleSlingshots or 0))
	return math.min(EconomyConfig.RANKING.PERFORMANCE_BONUS_CAP, bonus)
end

local function applyRankedResult(profile, entry, isDraw)
	profile.ranked = profile.ranked or defaultRanked()
	profile.ranked.matches += 1
	if isDraw then
		return 0
	end

	local won = (entry.wins or 0) > 0
	local delta = won and EconomyConfig.RANKING.WIN_DELTA or EconomyConfig.RANKING.LOSS_DELTA
	if won then
		delta += performanceBonus(entry)
		profile.ranked.wins += 1
	end

	profile.ranked.rating = math.max(0, profile.ranked.rating + delta)
	profile.ranked.peakRating = math.max(profile.ranked.peakRating or 0, profile.ranked.rating)
	return delta
end

local function addLifetimeStats(profile, entry)
	profile.lifetimeStats = profile.lifetimeStats or defaultLifetimeStats()
	profile.lifetimeStats.matchesPlayed += 1
	profile.lifetimeStats.kills += math.max(0, entry.kills or 0)
	profile.lifetimeStats.deaths += math.max(0, entry.deaths or 0)
	profile.lifetimeStats.wins += math.max(0, entry.wins or 0)
	profile.lifetimeStats.damageDealt += math.max(0, math.floor((entry.damageDealt or 0) + 0.5))
	profile.lifetimeStats.perfectParries += math.max(0, entry.perfectParries or 0)
	profile.lifetimeStats.parryClashes += math.max(0, entry.parryClashes or 0)
	profile.lifetimeStats.airShots += math.max(0, entry.airShots or 0)
	profile.lifetimeStats.grappleSlingshots += math.max(0, entry.grappleSlingshots or 0)
end

function EconomyService.grantMatchRewards(summary)
	if type(summary) ~= "table" or type(summary.players) ~= "table" then
		return summary
	end

	local isDraw = summary.winnerName == "Draw"
	for _, entry in ipairs(summary.players) do
		local player = Players:GetPlayerByUserId(entry.userId)
		if player then
			local profile = EconomyService.getProfile(player)
			local xpEarned = math.max(0, math.floor(entry.xpEarned or 0))
			local contract = entry.contract
			local coinsEarned = math.floor(xpEarned / EconomyConfig.MATCH_REWARDS.XP_TO_COINS_DIVISOR)
				+ math.max(0, entry.kills or 0) * EconomyConfig.MATCH_REWARDS.KILL_COINS

			if contract and contract.completed then
				coinsEarned += EconomyConfig.MATCH_REWARDS.CONTRACT_COINS
			end

			local titleId = profile.equipped and profile.equipped.title
			local titleCosmetic = titleId and EconomyConfig.COSMETICS[titleId]
			entry.title = titleCosmetic and titleCosmetic.name or nil
			addLifetimeStats(profile, entry)
			local ratingDelta = applyRankedResult(profile, entry, isDraw)
			local rank = EconomyConfig.getRankFromRating(profile.ranked.rating)
			profile.xp += xpEarned
			profile.coins += coinsEarned
			entry.coinsEarned = coinsEarned
			entry.totalCoins = profile.coins
			entry.totalXp = profile.xp
			entry.level = EconomyConfig.getLevelFromXp(profile.xp)
			entry.rating = profile.ranked.rating
			entry.ratingDelta = ratingDelta
			entry.rank = rank.name

			markDirty(player)
			sendProfile(player)
		end
	end

	for _, mvp in ipairs(summary.mvps or {}) do
		for _, entry in ipairs(summary.players) do
			if entry.name == mvp.name then
				mvp.title = entry.title
				mvp.rank = entry.rank
				break
			end
		end
	end

	return summary
end

function EconomyService.recordDailyProgress(player, statName, amount)
	if not player or type(statName) ~= "string" then return end
	local delta = math.max(0, amount or 1)
	if delta <= 0 then return end

	local profile = EconomyService.getProfile(player)
	local daily = ensureDaily(profile)
	local changed = false
	local rewardGranted = false

	for _, challenge in ipairs(EconomyConfig.getDailyChallengeSet(tonumber(daily.date) or currentDayNumber())) do
		if challenge.stat == statName then
			local state = daily.challenges[challenge.id]
			if state and not state.completed then
				state.progress = math.min((state.progress or 0) + delta, challenge.target)
				changed = true
				if state.progress >= challenge.target then
					state.completed = true
					state.rewarded = true
					profile.xp += challenge.xp
					profile.coins += challenge.coins
					rewardGranted = true
				end
			end
		end
	end

	if changed then
		markDirty(player)
		sendProfile(player)
		if rewardGranted then
			print(string.format("[Economy] %s completed a daily challenge", player.Name))
		end
	end
end

function EconomyService.claimDailyLoginReward(player)
	if not player then
		return false, "invalid_player"
	end

	local profile = EconomyService.getProfile(player)
	profile.loginReward = profile.loginReward or { streak = 0 }

	local today = currentDayNumber()
	local lastClaimDay = tonumber(profile.loginReward.lastClaimDay)
	if lastClaimDay == today then
		sendProfile(player)
		return false, "already_claimed"
	end

	if lastClaimDay == today - 1 then
		profile.loginReward.streak = (profile.loginReward.streak or 0) + 1
	else
		profile.loginReward.streak = 1
	end
	profile.loginReward.lastClaimDay = today

	local reward = EconomyConfig.getDailyLoginReward(profile.loginReward.streak)
	profile.coins += reward.coins
	profile.xp += reward.xp
	markDirty(player)
	sendProfile(player)
	print(string.format(
		"[Economy] %s claimed daily reward: +%d coins, +%d XP, streak %d",
		player.Name,
		reward.coins,
		reward.xp,
		profile.loginReward.streak
	))
	return true, reward
end

function EconomyService.claimSeasonReward(player, rewardId)
	if not player or type(rewardId) ~= "string" then
		return false, "invalid_request"
	end

	local profile = EconomyService.getProfile(player)
	profile.season = profile.season or { claimedRewards = {} }
	if profile.season.claimedRewards[rewardId] then
		sendProfile(player)
		return false, "already_claimed"
	end

	local reward = nil
	for _, candidate in ipairs(EconomyConfig.SEASON_REWARDS) do
		if candidate.id == rewardId then
			reward = candidate
			break
		end
	end
	if not reward then
		return false, "unknown_reward"
	end

	local level = EconomyConfig.getLevelFromXp(profile.xp)
	if level < reward.level then
		sendProfile(player)
		return false, "locked"
	end

	profile.season.claimedRewards[rewardId] = true
	if reward.coins and reward.coins > 0 then
		profile.coins += reward.coins
	end
	if reward.cosmeticId and EconomyConfig.COSMETICS[reward.cosmeticId] then
		profile.ownedCosmetics[reward.cosmeticId] = true
	end

	markDirty(player)
	sendProfile(player)
	print(string.format("[Economy] %s claimed season reward %s", player.Name, rewardId))
	return true, reward
end

function EconomyService.purchaseCosmetic(player, cosmeticId)
	local cosmetic = EconomyConfig.COSMETICS[cosmeticId]
	if not cosmetic then
		return false, "Unknown cosmetic"
	end
	if cosmetic.seasonOnly then
		return false, "Season reward only"
	end

	local profile = EconomyService.getProfile(player)
	if profile.ownedCosmetics[cosmeticId] then
		return false, "Already owned"
	end

	local price = cosmetic.price or 0
	if profile.coins < price then
		return false, "Not enough coins"
	end

	profile.coins -= price
	profile.ownedCosmetics[cosmeticId] = true
	markDirty(player)
	sendProfile(player)
	return true
end

function EconomyService.equipCosmetic(player, cosmeticId)
	local cosmetic = EconomyConfig.COSMETICS[cosmeticId]
	if not cosmetic then
		return false, "Unknown cosmetic"
	end

	local profile = EconomyService.getProfile(player)
	if not profile.ownedCosmetics[cosmeticId] then
		return false, "Not owned"
	end

	profile.equipped[cosmetic.slot] = cosmeticId
	markDirty(player)
	sendProfile(player)
	return true
end

profileRequested.OnServerEvent:Connect(function(player)
	if not canUseRemote(player, "profile", 0.5) then return end
	sendProfile(player)
end)

purchaseRequested.OnServerEvent:Connect(function(player, cosmeticId)
	if not canUseRemote(player, "purchase", 0.35) then return end
	if type(cosmeticId) ~= "string" then return end
	local ok, reason = EconomyService.purchaseCosmetic(player, cosmeticId)
	if not ok then
		local log = reason == "Not enough coins" and print or warn
		log(string.format("[Economy] %s purchase rejected: %s", player.Name, reason))
	end
end)

equipRequested.OnServerEvent:Connect(function(player, cosmeticId)
	if not canUseRemote(player, "equip", 0.25) then return end
	if type(cosmeticId) ~= "string" then return end
	local ok, reason = EconomyService.equipCosmetic(player, cosmeticId)
	if not ok then
		warn(string.format("[Economy] %s equip rejected: %s", player.Name, reason))
	end
end)

dailyLoginClaimed.OnServerEvent:Connect(function(player)
	if not canUseRemote(player, "daily_login", 1) then return end
	local ok, reason = EconomyService.claimDailyLoginReward(player)
	if not ok and reason ~= "already_claimed" then
		warn(string.format("[Economy] %s daily reward rejected: %s", player.Name, tostring(reason)))
	end
end)

seasonRewardClaimed.OnServerEvent:Connect(function(player, rewardId)
	if not canUseRemote(player, "season_reward", 0.5) then return end
	local ok, reason = EconomyService.claimSeasonReward(player, rewardId)
	if not ok and reason ~= "already_claimed" and reason ~= "locked" then
		warn(string.format("[Economy] %s season reward rejected: %s", player.Name, tostring(reason)))
	end
end)

Players.PlayerAdded:Connect(loadProfile)

Players.PlayerRemoving:Connect(function(player)
	if dirty[player.UserId] then
		saveProfile(player)
	end
	profiles[player.UserId] = nil
	dirty[player.UserId] = nil
	saveQueued[player.UserId] = nil
	remoteCooldowns[player.UserId] = nil
	saveBlocked[player.UserId] = nil
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		saveProfile(player)
	end
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(loadProfile, player)
end

return EconomyService
