-- SoundManager (ModuleScript — client only)
-- Single place to define every game sound ID and volume.
-- Replace any id = 0 entry with a real Roblox asset ID when available.
--
-- Usage:
--   local SoundManager = require(game.ReplicatedStorage.Client.SoundManager)
--   SoundManager.play("fire")
--   SoundManager.play("kill")

local SoundService = game:GetService("SoundService")

-- ── Sound definitions ─────────────────────────────────────────────────────────
-- id     : Roblox asset ID (0 = silent placeholder)
-- volume : 0–1
-- pitch  : optional RNG pitch variance [min, max] for variety

local DEFINITIONS = {
	-- Weapon
	fire         = { id = 0, volume = 0.8 },   -- gunshot
	reload_start = { id = 0, volume = 0.6 },   -- cylinder spin begin
	reload_end   = { id = 0, volume = 0.6 },   -- cylinder click shut
	empty_click  = { id = 0, volume = 0.5 },   -- dry fire

	-- Hit feedback (attacker side)
	hit          = { id = 0, volume = 0.55, pitch = { 0.95, 1.05 } },
	kill         = { id = 0, volume = 0.75 },

	-- Damage (victim side)
	hurt         = { id = 0, volume = 0.65, pitch = { 0.9, 1.1 } },

	-- Parry
	parry_swing  = { id = 0, volume = 0.7 },   -- arm swing on parry attempt
	parry_hit    = { id = 0, volume = 0.85 },  -- successful deflect "ding"

	-- Movement
	dash         = { id = 0, volume = 0.5 },
	slide_start  = { id = 0, volume = 0.5 },
	land         = { id = 0, volume = 0.4, pitch = { 0.9, 1.1 } },

	-- Match events
	match_start  = { id = 0, volume = 0.8 },
	match_end    = { id = 0, volume = 0.8 },
}

-- ── Internal cache ────────────────────────────────────────────────────────────

local cache = {}  -- [name] = Sound instance

local function getSound(name)
	if cache[name] then return cache[name] end

	local def = DEFINITIONS[name]
	if not def then
		warn("[SoundManager] Unknown sound: " .. tostring(name))
		return nil
	end

	local sound        = Instance.new("Sound")
	sound.Name         = "SFX_" .. name
	sound.SoundId      = "rbxassetid://" .. def.id
	sound.Volume       = def.volume
	sound.RollOffMaxDistance = 0   -- 2D (no spatial falloff for UI sounds)
	sound.Parent       = SoundService

	cache[name] = sound
	return sound
end

-- ── Public API ────────────────────────────────────────────────────────────────

local SoundManager = {}

-- Play a sound by name. Silent if id = 0.
function SoundManager.play(name)
	local s = getSound(name)
	if not s then return end
	if s.SoundId == "rbxassetid://0" then return end  -- placeholder, skip

	-- Optional pitch variance
	local def = DEFINITIONS[name]
	if def and def.pitch then
		local lo, hi = def.pitch[1], def.pitch[2]
		s.PlaybackSpeed = lo + math.random() * (hi - lo)
	else
		s.PlaybackSpeed = 1
	end

	s:Play()
end

-- Stop a looping sound.
function SoundManager.stop(name)
	local s = cache[name]
	if s then s:Stop() end
end

return SoundManager
