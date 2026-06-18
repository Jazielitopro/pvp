-- StatsTracker (ModuleScript - server only)
-- In-memory per-round performance stats. Keep this non-persistent until the
-- mastery loop feels right, then DataStore can sit behind this API.

local Players = game:GetService("Players")

local StatsTracker = {}

local roundStats = {}
local roundContracts = {}
local completedContractNotified = {}
local contractUpdateCallback = nil
local medalCallback = nil
local progressCallback = nil

local CONTRACTS = {
	{
		id = "perfect_timing",
		name = "Perfect Timing",
		description = "Land 2 perfect parries",
		stat = "perfectParries",
		target = 2,
		xp = 100,
	},
	{
		id = "air_hunter",
		name = "Air Hunter",
		description = "Hit 2 airborne shots",
		stat = "airShots",
		target = 2,
		xp = 90,
	},
	{
		id = "hook_momentum",
		name = "Hook Momentum",
		description = "Use 2 grapple slingshots",
		stat = "grappleSlingshots",
		target = 2,
		xp = 80,
	},
	{
		id = "mirror_breaker",
		name = "Mirror Breaker",
		description = "Win 1 parry clash",
		stat = "parryClashes",
		target = 1,
		xp = 80,
	},
	{
		id = "pressure_dealer",
		name = "Pressure Dealer",
		description = "Deal 250 damage",
		stat = "damageDealt",
		target = 250,
		xp = 100,
	},
	{
		id = "finisher",
		name = "Finisher",
		description = "Score 3 eliminations",
		stat = "kills",
		target = 3,
		xp = 120,
	},
}

local STAT_DEFAULTS = {
	kills = 0,
	deaths = 0,
	wins = 0,
	damageDealt = 0,
	airShots = 0,
	perfectParries = 0,
	parryClashes = 0,
	selfBoosts = 0,
	grappleSlingshots = 0,
}

local MEDALS = {
	firstBlood = {
		id = "first_blood",
		name = "FIRST BLOOD",
		description = "First elimination of the round",
		color = "gold",
	},
	perfectParry = {
		id = "perfect_parry",
		name = "PERFECT PARRY",
		description = "Frame-perfect reflect",
		color = "cyan",
	},
	parryClash = {
		id = "parry_clash",
		name = "CLASH WIN",
		description = "Won a parry clash",
		color = "red",
	},
	airShot = {
		id = "air_shot",
		name = "AIR SHOT",
		description = "Landed an airborne hit",
		color = "white",
	},
	hookMaster = {
		id = "hook_master",
		name = "HOOK MASTER",
		description = "Converted grapple momentum",
		color = "cyan",
	},
	hatTrick = {
		id = "hat_trick",
		name = "HAT TRICK",
		description = "Three eliminations this round",
		color = "gold",
	},
}

local firstBloodAwarded = false

local function newStats()
	local stats = {}
	for key, value in pairs(STAT_DEFAULTS) do
		stats[key] = value
	end
	return stats
end

local function getStats(player)
	if not player then return nil end
	local userId = player.UserId
	if not roundStats[userId] then
		roundStats[userId] = newStats()
	end
	return roundStats[userId]
end

local function increment(player, statName, amount)
	local stats = getStats(player)
	if not stats then return end
	stats[statName] = (stats[statName] or 0) + (amount or 1)
	return stats
end

local function chooseContract(player, index)
	local contractIndex = ((player.UserId + index) % #CONTRACTS) + 1
	return CONTRACTS[contractIndex]
end

local function buildContractPayload(contract, stats)
	if not contract then return nil end

	local progress = stats[contract.stat] or 0
	local completed = progress >= contract.target
	return {
		id = contract.id,
		name = contract.name,
		description = contract.description,
		stat = contract.stat,
		target = contract.target,
		progress = math.min(progress, contract.target),
		completed = completed,
		xp = completed and contract.xp or 0,
		rewardXp = contract.xp,
	}
end

local function emitContractUpdate(player, statName)
	local contract = roundContracts[player.UserId]
	if not contract or contract.stat ~= statName then return end
	if not contractUpdateCallback then return end

	local stats = getStats(player) or newStats()
	local payload = buildContractPayload(contract, stats)
	if payload.completed then
		if completedContractNotified[player.UserId] then return end
		completedContractNotified[player.UserId] = true
	end
	contractUpdateCallback(player, payload)
end

local function emitMedal(player, medal)
	if not medalCallback or not player or not medal then return end
	medalCallback(player, medal)
end

local function emitProgress(player, statName, amount)
	if not progressCallback or not player then return end
	progressCallback(player, statName, amount or 1)
end

function StatsTracker.resetRound(players)
	roundStats = {}
	roundContracts = {}
	completedContractNotified = {}
	firstBloodAwarded = false
	for index, player in ipairs(players or Players:GetPlayers()) do
		roundStats[player.UserId] = newStats()
		roundContracts[player.UserId] = chooseContract(player, index)
	end
end

function StatsTracker.getContract(player)
	local stats = getStats(player) or newStats()
	return buildContractPayload(roundContracts[player.UserId], stats)
end

function StatsTracker.setContractUpdateCallback(callback)
	contractUpdateCallback = callback
end

function StatsTracker.setMedalCallback(callback)
	medalCallback = callback
end

function StatsTracker.setProgressCallback(callback)
	progressCallback = callback
end

function StatsTracker.recordDamage(attacker, amount, hitTag)
	if not attacker then return end
	increment(attacker, "damageDealt", amount or 0)
	emitContractUpdate(attacker, "damageDealt")
	emitProgress(attacker, "damageDealt", amount or 0)
	if hitTag == "AIR SHOT" then
		increment(attacker, "airShots", 1)
		emitContractUpdate(attacker, "airShots")
		emitProgress(attacker, "airShots", 1)
		emitMedal(attacker, MEDALS.airShot)
	end
end

function StatsTracker.recordKill(attacker, victim)
	if attacker and attacker ~= victim then
		local stats = increment(attacker, "kills", 1)
		emitContractUpdate(attacker, "kills")
		emitProgress(attacker, "kills", 1)
		if not firstBloodAwarded then
			firstBloodAwarded = true
			emitMedal(attacker, MEDALS.firstBlood)
		end
		if stats and stats.kills == 3 then
			emitMedal(attacker, MEDALS.hatTrick)
		end
	end
	if victim then
		increment(victim, "deaths", 1)
	end
end

function StatsTracker.recordParry(player, parryKind)
	if parryKind == "perfect" or parryKind == "perfect_clash" then
		increment(player, "perfectParries", 1)
		emitContractUpdate(player, "perfectParries")
		emitProgress(player, "perfectParries", 1)
		emitMedal(player, MEDALS.perfectParry)
	end
	if parryKind == "clash" or parryKind == "perfect_clash" then
		increment(player, "parryClashes", 1)
		emitContractUpdate(player, "parryClashes")
		emitProgress(player, "parryClashes", 1)
		emitMedal(player, MEDALS.parryClash)
	end
end

function StatsTracker.recordSelfBoost(player)
	increment(player, "selfBoosts", 1)
end

function StatsTracker.recordGrappleSlingshot(player)
	increment(player, "grappleSlingshots", 1)
	emitContractUpdate(player, "grappleSlingshots")
	emitProgress(player, "grappleSlingshots", 1)
	emitMedal(player, MEDALS.hookMaster)
end

function StatsTracker.recordWin(player)
	increment(player, "wins", 1)
end

local function buildMvps(players)
	local awards = {}

	local function addBest(label, statName)
		local best = nil
		for _, entry in ipairs(players) do
			if (entry[statName] or 0) > 0 and (not best or (entry[statName] or 0) > (best[statName] or 0)) then
				best = entry
			end
		end
		if best then
			table.insert(awards, {
				label = label,
				name = best.name,
				title = best.title,
				value = best[statName] or 0,
			})
		end
	end

	addBest("Most Damage", "damageDealt")
	addBest("Best Parry", "perfectParries")
	addBest("Hook Master", "grappleSlingshots")

	return awards
end

function StatsTracker.buildSummary(winnerName)
	local players = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local stats = getStats(player) or newStats()
		local contract = buildContractPayload(roundContracts[player.UserId], stats)
		table.insert(players, {
			userId = player.UserId,
			name = player.DisplayName,
			kills = stats.kills or 0,
			deaths = stats.deaths or 0,
			wins = stats.wins or 0,
			damageDealt = math.floor((stats.damageDealt or 0) + 0.5),
			airShots = stats.airShots or 0,
			perfectParries = stats.perfectParries or 0,
			parryClashes = stats.parryClashes or 0,
			selfBoosts = stats.selfBoosts or 0,
			grappleSlingshots = stats.grappleSlingshots or 0,
			contract = contract,
			xpEarned = 25 + (stats.wins or 0) * 150 + (contract and contract.xp or 0),
		})
	end

	table.sort(players, function(a, b)
		if a.kills ~= b.kills then
			return a.kills > b.kills
		end
		return a.damageDealt > b.damageDealt
	end)

	return {
		winnerName = winnerName or "Draw",
		players = players,
		mvps = buildMvps(players),
	}
end

Players.PlayerRemoving:Connect(function(player)
	roundStats[player.UserId] = nil
	roundContracts[player.UserId] = nil
	completedContractNotified[player.UserId] = nil
end)

return StatsTracker
