-- CosmeticState (client singleton)
-- Stores the latest economy profile so gameplay VFX controllers can read
-- equipped cosmetic colors without each owning its own remote subscription.

local EconomyConfig = require(game.ReplicatedStorage.Shared.Constants.EconomyConfig)

local CosmeticState = {}

local profile = {
	equipped = table.clone(EconomyConfig.DEFAULT_EQUIPPED),
	cosmetics = EconomyConfig.COSMETICS,
}

function CosmeticState.setProfile(newProfile)
	if type(newProfile) ~= "table" then return end
	profile = newProfile
end

function CosmeticState.getEquipped(slot)
	local equipped = profile.equipped or EconomyConfig.DEFAULT_EQUIPPED
	return equipped[slot] or EconomyConfig.DEFAULT_EQUIPPED[slot]
end

function CosmeticState.getCosmetic(id)
	local cosmetics = profile.cosmetics or EconomyConfig.COSMETICS
	return cosmetics[id] or EconomyConfig.COSMETICS[id]
end

function CosmeticState.getColors(slot)
	local id = CosmeticState.getEquipped(slot)
	local cosmetic = CosmeticState.getCosmetic(id) or EconomyConfig.COSMETICS[EconomyConfig.DEFAULT_EQUIPPED[slot]]
	local primary = cosmetic and cosmetic.primaryColor or Color3.fromRGB(255, 215, 80)
	local secondary = cosmetic and cosmetic.secondaryColor or primary
	return primary, secondary
end

return CosmeticState
