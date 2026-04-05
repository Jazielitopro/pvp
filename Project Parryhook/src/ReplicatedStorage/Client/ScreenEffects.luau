-- ScreenEffects (ModuleScript — client only)
-- Shared singleton for procedural screen effects.
-- Any LocalScript can require this and call shake() / flash().
-- CameraController calls consumeShake() each RenderStepped to apply the offset.
--
-- Usage:
--   local ScreenEffects = require(game.ReplicatedStorage.Client.ScreenEffects)
--   ScreenEffects.shake(0.25)   -- trigger a medium camera shake
--   ScreenEffects.shake(0.5)    -- stack a stronger shake (takes max)

local ScreenEffects = {}

-- ── Camera shake ──────────────────────────────────────────────────────────────

local SHAKE_DECAY = 14   -- units/s — higher = snappier decay

local shakeIntensity = 0

-- Call to request a shake. Stacks by taking the max, never adds blindly.
function ScreenEffects.shake(intensity)
	shakeIntensity = math.max(shakeIntensity, intensity)
end

-- Called once per frame by CameraController:_update().
-- Returns a Vector3 offset to add to humanoid.CameraOffset, then decays.
function ScreenEffects.consumeShake(dt)
	if shakeIntensity < 0.001 then
		shakeIntensity = 0
		return Vector3.zero
	end

	local x = (math.random() * 2 - 1) * shakeIntensity
	local y = (math.random() * 2 - 1) * shakeIntensity
	shakeIntensity = shakeIntensity * math.max(0, 1 - SHAKE_DECAY * dt)

	return Vector3.new(x, y, 0)
end

return ScreenEffects
