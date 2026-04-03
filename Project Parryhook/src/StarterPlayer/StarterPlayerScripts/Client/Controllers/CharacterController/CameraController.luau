-- CameraController
-- Manages first-person lock, movement head bob, and FOV transitions.
-- Runs on RenderStepped (before rendering) for smooth visual output.
--
-- Bob uses Humanoid.CameraOffset — Roblox applies this in camera-local space
-- automatically, so it integrates cleanly with mouse look.
-- FOV changes via camera.FieldOfView lerped per state.

local RunService = game:GetService("RunService")
local Players    = game:GetService("Players")
local Constants  = require(game.ReplicatedStorage.Shared.Constants.MovementConstants)

-- Bob target parameters per movement state.
-- States not listed here default to amplitude = 0 (no bob).
local BOB_PARAMS = {
	walking   = { amplitude = Constants.BOB_WALK_AMPLITUDE,   frequency = Constants.BOB_WALK_FREQUENCY   },
	sprinting = { amplitude = Constants.BOB_SPRINT_AMPLITUDE, frequency = Constants.BOB_SPRINT_FREQUENCY },
}

-- FOV target per state. Unlisted states use FOV_NORMAL.
local FOV_TARGETS = {
	sprinting = Constants.FOV_SPRINT,
	dashing   = Constants.FOV_DASH,
}

local CameraController = {}
CameraController.__index = CameraController

-- camera   : workspace.CurrentCamera
-- humanoid : character Humanoid
function CameraController.new(camera, humanoid)
	-- Lock to first person. Roblox hides body parts automatically.
	Players.LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson

	return setmetatable({
		_camera    = camera,
		_humanoid  = humanoid,
		_bobTime   = 0,
		_bobAmp    = 0,  -- current smoothed amplitude
		_bobFreq   = Constants.BOB_WALK_FREQUENCY,
		_currentFOV = Constants.FOV_NORMAL,
		_connection = nil,
	}, CameraController)
end

-- Begin updating the camera. getState() is called each frame to read movement state.
function CameraController:start(getState)
	self._connection = RunService.RenderStepped:Connect(function(dt)
		self:_update(getState(), dt)
	end)
end

function CameraController:_update(state, dt)
	local lerpAlpha = math.min(Constants.BOB_LERP_SPEED * dt, 1)

	-- ── Head bob ───────────────────────────────────────────────────────────
	local params = BOB_PARAMS[state]
	local targetAmp  = params and params.amplitude  or 0
	local targetFreq = params and params.frequency  or Constants.BOB_WALK_FREQUENCY

	-- Smooth amplitude and frequency toward targets
	self._bobAmp  = self._bobAmp  + (targetAmp  - self._bobAmp)  * lerpAlpha
	self._bobFreq = self._bobFreq + (targetFreq - self._bobFreq) * lerpAlpha

	-- Advance bob timer only when amplitude is meaningful (avoids drift at rest)
	if self._bobAmp > 0.001 then
		self._bobTime += dt * self._bobFreq
	end

	-- Vertical bob + subtle horizontal sway (half frequency, one-third amplitude)
	local bobY = math.sin(self._bobTime)       * self._bobAmp
	local bobX = math.sin(self._bobTime * 0.5) * self._bobAmp * 0.3

	self._humanoid.CameraOffset = Vector3.new(bobX, bobY, 0)

	-- ── Field of view ──────────────────────────────────────────────────────
	local targetFOV = FOV_TARGETS[state] or Constants.FOV_NORMAL
	local fovAlpha  = math.min(Constants.FOV_LERP_SPEED * dt, 1)
	self._currentFOV = self._currentFOV + (targetFOV - self._currentFOV) * fovAlpha
	self._camera.FieldOfView = self._currentFOV
end

-- Stop updating (call on character removal / respawn).
function CameraController:stop()
	if self._connection then
		self._connection:Disconnect()
		self._connection = nil
	end
	-- Reset camera offset so it does not persist across respawns
	self._humanoid.CameraOffset = Vector3.zero
	self._camera.FieldOfView    = Constants.FOV_NORMAL
end

return CameraController
