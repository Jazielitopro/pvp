-- EconomyConfig
-- Shared cosmetic/economy definitions. Prices are intentionally cosmetic-only:
-- no damage, cooldown, movement, or match advantage should live here.

local EconomyConfig = {}

EconomyConfig.DATASTORE_NAME = "ParryhookEconomy_v1"

EconomyConfig.LEVEL_XP = 500

EconomyConfig.DAILY_LOGIN_REWARD = {
	BASE_COINS = 40,
	BASE_XP = 80,
	STREAK_COIN_STEP = 10,
	STREAK_XP_STEP = 15,
	MAX_STREAK_BONUS_DAYS = 7,
}

EconomyConfig.MATCH_REWARDS = {
	PARTICIPATION_XP = 25,
	WIN_XP = 150,
	XP_TO_COINS_DIVISOR = 10,
	KILL_COINS = 5,
	CONTRACT_COINS = 25,
}

EconomyConfig.RANKING = {
	START_RATING = 1000,
	WIN_DELTA = 25,
	LOSS_DELTA = -12,
	DRAW_DELTA = 0,
	PERFORMANCE_BONUS_CAP = 8,
}

EconomyConfig.RANKS = {
	{ id = "bronze", name = "Bronze", minRating = 0, color = Color3.fromRGB(205, 127, 70) },
	{ id = "silver", name = "Silver", minRating = 900, color = Color3.fromRGB(190, 205, 220) },
	{ id = "gold", name = "Gold", minRating = 1100, color = Color3.fromRGB(255, 216, 84) },
	{ id = "diamond", name = "Diamond", minRating = 1350, color = Color3.fromRGB(90, 230, 255) },
	{ id = "legend", name = "Parry Legend", minRating = 1650, color = Color3.fromRGB(180, 100, 255) },
}

EconomyConfig.SHOP_ROTATION = {
	DAILY_COUNT = 4,
	WEEKLY_COUNT = 5,
	CANDIDATE_IDS = {
		"projectile_neon",
		"projectile_solar",
		"projectile_ruby",
		"projectile_lime",
		"hook_comet",
		"hook_ember",
		"hook_ghost",
		"parry_circuit",
		"parry_solar",
		"parry_rose",
		"title_perfect",
		"title_clutch",
		"title_skybreaker",
	},
}

EconomyConfig.SEASON_REWARDS = {
	{
		id = "season_l2_coins",
		level = 2,
		name = "Starter Cache",
		coins = 100,
	},
	{
		id = "season_l3_projectile",
		level = 3,
		name = "Void Bolt",
		cosmeticId = "projectile_void",
	},
	{
		id = "season_l4_coins",
		level = 4,
		name = "Momentum Cache",
		coins = 150,
	},
	{
		id = "season_l5_title",
		level = 5,
		name = "Hooksmith Title",
		cosmeticId = "title_hooksmith",
	},
	{
		id = "season_l6_hook",
		level = 6,
		name = "Golden Hook",
		cosmeticId = "hook_gold",
	},
	{
		id = "season_l8_parry",
		level = 8,
		name = "Void Parry",
		cosmeticId = "parry_void",
	},
	{
		id = "season_l10_title",
		level = 10,
		name = "Parry Legend Title",
		cosmeticId = "title_parry_legend",
	},
}

EconomyConfig.DAILY_CHALLENGE_COUNT = 3

EconomyConfig.DAILY_CHALLENGES = {
	{
		id = "daily_kills",
		name = "Daily Finisher",
		description = "Score 8 eliminations",
		stat = "kills",
		target = 8,
		xp = 150,
		coins = 60,
	},
	{
		id = "daily_damage",
		name = "Pressure Loop",
		description = "Deal 1200 damage",
		stat = "damageDealt",
		target = 1200,
		xp = 180,
		coins = 70,
	},
	{
		id = "daily_parry",
		name = "Clean Reflects",
		description = "Land 6 perfect parries",
		stat = "perfectParries",
		target = 6,
		xp = 170,
		coins = 70,
	},
	{
		id = "daily_air",
		name = "Air Control",
		description = "Hit 5 air shots",
		stat = "airShots",
		target = 5,
		xp = 160,
		coins = 65,
	},
	{
		id = "daily_hook",
		name = "Momentum Habit",
		description = "Use 5 grapple slingshots",
		stat = "grappleSlingshots",
		target = 5,
		xp = 160,
		coins = 65,
	},
	{
		id = "daily_clash",
		name = "Clash Reader",
		description = "Win 3 parry clashes",
		stat = "parryClashes",
		target = 3,
		xp = 150,
		coins = 60,
	},
}

EconomyConfig.DEFAULT_EQUIPPED = {
	projectileSkin = "projectile_default",
	hookTrail = "hook_default",
	parryAura = "parry_default",
	title = "title_rookie",
}

EconomyConfig.COSMETICS = {
	projectile_default = {
		id = "projectile_default",
		slot = "projectileSkin",
		name = "Default Bolt",
		rarity = "Common",
		price = 0,
		defaultOwned = true,
		primaryColor = Color3.fromRGB(255, 215, 80),
		secondaryColor = Color3.fromRGB(255, 140, 30),
	},
	projectile_neon = {
		id = "projectile_neon",
		slot = "projectileSkin",
		name = "Neon Bolt",
		rarity = "Rare",
		price = 300,
		primaryColor = Color3.fromRGB(80, 240, 255),
		secondaryColor = Color3.fromRGB(40, 120, 255),
	},
	projectile_solar = {
		id = "projectile_solar",
		slot = "projectileSkin",
		name = "Solar Bolt",
		rarity = "Epic",
		price = 600,
		primaryColor = Color3.fromRGB(255, 110, 40),
		secondaryColor = Color3.fromRGB(255, 230, 90),
	},
	projectile_ruby = {
		id = "projectile_ruby",
		slot = "projectileSkin",
		name = "Ruby Bolt",
		rarity = "Rare",
		price = 360,
		primaryColor = Color3.fromRGB(255, 70, 110),
		secondaryColor = Color3.fromRGB(255, 180, 200),
	},
	projectile_lime = {
		id = "projectile_lime",
		slot = "projectileSkin",
		name = "Lime Bolt",
		rarity = "Rare",
		price = 360,
		primaryColor = Color3.fromRGB(130, 255, 80),
		secondaryColor = Color3.fromRGB(220, 255, 120),
	},
	projectile_void = {
		id = "projectile_void",
		slot = "projectileSkin",
		name = "Void Bolt",
		rarity = "Season",
		price = 0,
		seasonOnly = true,
		primaryColor = Color3.fromRGB(160, 90, 255),
		secondaryColor = Color3.fromRGB(40, 10, 70),
	},
	hook_default = {
		id = "hook_default",
		slot = "hookTrail",
		name = "Default Hook",
		rarity = "Common",
		price = 0,
		defaultOwned = true,
		primaryColor = Color3.fromRGB(220, 175, 55),
		secondaryColor = Color3.fromRGB(190, 190, 190),
	},
	hook_comet = {
		id = "hook_comet",
		slot = "hookTrail",
		name = "Comet Hook",
		rarity = "Rare",
		price = 350,
		primaryColor = Color3.fromRGB(120, 220, 255),
		secondaryColor = Color3.fromRGB(255, 255, 255),
	},
	hook_ember = {
		id = "hook_ember",
		slot = "hookTrail",
		name = "Ember Hook",
		rarity = "Rare",
		price = 420,
		primaryColor = Color3.fromRGB(255, 120, 55),
		secondaryColor = Color3.fromRGB(255, 220, 80),
	},
	hook_ghost = {
		id = "hook_ghost",
		slot = "hookTrail",
		name = "Ghost Hook",
		rarity = "Epic",
		price = 680,
		primaryColor = Color3.fromRGB(200, 245, 255),
		secondaryColor = Color3.fromRGB(120, 150, 255),
	},
	hook_gold = {
		id = "hook_gold",
		slot = "hookTrail",
		name = "Golden Hook",
		rarity = "Season",
		price = 0,
		seasonOnly = true,
		primaryColor = Color3.fromRGB(255, 205, 70),
		secondaryColor = Color3.fromRGB(255, 245, 170),
	},
	parry_default = {
		id = "parry_default",
		slot = "parryAura",
		name = "Default Parry",
		rarity = "Common",
		price = 0,
		defaultOwned = true,
		primaryColor = Color3.fromRGB(80, 220, 200),
		secondaryColor = Color3.fromRGB(255, 255, 255),
	},
	parry_circuit = {
		id = "parry_circuit",
		slot = "parryAura",
		name = "Circuit Parry",
		rarity = "Epic",
		price = 700,
		primaryColor = Color3.fromRGB(130, 255, 90),
		secondaryColor = Color3.fromRGB(80, 220, 255),
	},
	parry_solar = {
		id = "parry_solar",
		slot = "parryAura",
		name = "Solar Parry",
		rarity = "Rare",
		price = 520,
		primaryColor = Color3.fromRGB(255, 210, 80),
		secondaryColor = Color3.fromRGB(255, 95, 55),
	},
	parry_rose = {
		id = "parry_rose",
		slot = "parryAura",
		name = "Rose Parry",
		rarity = "Epic",
		price = 760,
		primaryColor = Color3.fromRGB(255, 90, 180),
		secondaryColor = Color3.fromRGB(170, 90, 255),
	},
	parry_void = {
		id = "parry_void",
		slot = "parryAura",
		name = "Void Parry",
		rarity = "Season",
		price = 0,
		seasonOnly = true,
		primaryColor = Color3.fromRGB(180, 80, 255),
		secondaryColor = Color3.fromRGB(40, 10, 70),
	},
	title_rookie = {
		id = "title_rookie",
		slot = "title",
		name = "Rookie",
		rarity = "Common",
		price = 0,
		defaultOwned = true,
	},
	title_perfect = {
		id = "title_perfect",
		slot = "title",
		name = "Perfect Timing",
		rarity = "Rare",
		price = 500,
	},
	title_clutch = {
		id = "title_clutch",
		slot = "title",
		name = "Clutch",
		rarity = "Rare",
		price = 450,
	},
	title_skybreaker = {
		id = "title_skybreaker",
		slot = "title",
		name = "Skybreaker",
		rarity = "Epic",
		price = 800,
	},
	title_hooksmith = {
		id = "title_hooksmith",
		slot = "title",
		name = "Hooksmith",
		rarity = "Season",
		price = 0,
		seasonOnly = true,
	},
	title_parry_legend = {
		id = "title_parry_legend",
		slot = "title",
		name = "Parry Legend",
		rarity = "Season",
		price = 0,
		seasonOnly = true,
	},
}

function EconomyConfig.getDefaultOwned()
	local owned = {}
	for id, cosmetic in pairs(EconomyConfig.COSMETICS) do
		if cosmetic.defaultOwned then
			owned[id] = true
		end
	end
	return owned
end

function EconomyConfig.getLevelFromXp(xp)
	return math.floor((xp or 0) / EconomyConfig.LEVEL_XP) + 1
end

function EconomyConfig.getRankFromRating(rating)
	local currentRank = EconomyConfig.RANKS[1]
	local safeRating = math.max(0, math.floor(tonumber(rating) or EconomyConfig.RANKING.START_RATING))
	for _, rank in ipairs(EconomyConfig.RANKS) do
		if safeRating >= rank.minRating then
			currentRank = rank
		end
	end
	return currentRank
end

local function selectRotationItems(seed, count)
	local candidates = EconomyConfig.SHOP_ROTATION.CANDIDATE_IDS
	local selected = {}
	local used = {}
	local total = #candidates
	if total == 0 then
		return selected
	end

	local startIndex = (seed % total) + 1
	local step = (seed % math.max(total - 1, 1)) + 1
	if total > 1 and total % step == 0 then
		step += 1
	end

	local index = startIndex
	while #selected < math.min(count, total) do
		local cosmeticId = candidates[index]
		local cosmetic = EconomyConfig.COSMETICS[cosmeticId]
		if cosmetic and not cosmetic.seasonOnly and not cosmetic.defaultOwned and not used[cosmeticId] then
			table.insert(selected, cosmeticId)
			used[cosmeticId] = true
		end
		index = ((index + step - 1) % total) + 1
	end
	return selected
end

function EconomyConfig.getShopRotation(dayNumber)
	local safeDay = math.max(0, math.floor(tonumber(dayNumber) or 0))
	local weekNumber = math.floor(safeDay / 7)
	return {
		dailyItems = selectRotationItems(safeDay, EconomyConfig.SHOP_ROTATION.DAILY_COUNT),
		weeklyItems = selectRotationItems(weekNumber + 1000, EconomyConfig.SHOP_ROTATION.WEEKLY_COUNT),
		resetDay = safeDay + 1,
		weeklyResetDay = (weekNumber + 1) * 7,
	}
end

function EconomyConfig.getDailyLoginReward(streak)
	local bonusDays = math.clamp((streak or 1) - 1, 0, EconomyConfig.DAILY_LOGIN_REWARD.MAX_STREAK_BONUS_DAYS - 1)
	return {
		coins = EconomyConfig.DAILY_LOGIN_REWARD.BASE_COINS
			+ bonusDays * EconomyConfig.DAILY_LOGIN_REWARD.STREAK_COIN_STEP,
		xp = EconomyConfig.DAILY_LOGIN_REWARD.BASE_XP
			+ bonusDays * EconomyConfig.DAILY_LOGIN_REWARD.STREAK_XP_STEP,
	}
end

function EconomyConfig.getDailyChallengeSet(dayNumber)
	local challenges = {}
	local total = #EconomyConfig.DAILY_CHALLENGES
	for i = 1, EconomyConfig.DAILY_CHALLENGE_COUNT do
		local index = ((dayNumber or 0) + i - 1) % total + 1
		table.insert(challenges, EconomyConfig.DAILY_CHALLENGES[index])
	end
	return challenges
end

return EconomyConfig
