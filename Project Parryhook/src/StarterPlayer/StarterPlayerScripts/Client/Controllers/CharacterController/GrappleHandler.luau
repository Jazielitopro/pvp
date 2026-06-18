-- GrappleHandler
-- Client-side grapple logic. Attaches to environment surfaces only.
-- Uses a LinearVelocity constraint (MaxForce = 1e6) to pull the character;
-- this overrides the Humanoid's internal movement forces so they no longer
-- fight the grapple pull.  AssemblyLinearVelocity is intentionally NOT used
-- for the pull — it would be cancelled each frame by the Humanoid's PID.
--
-- Visual: straight Beam rope + small glowing sphere at hook point.
-- Server is notified via GrappleRequest (recorded for CharacterValidator).
--
-- Detach conditions (in priority order):
--   1. Press F again while grappling (toggle)
--   2. Reach MIN_DETACH_DIST of the hook
--   3. MAX_DURATION seconds elapsed

local Players   = game:GetService("Players")
local Constants = require(game.ReplicatedStorage.Shared.Constants.GrappleConstants)
local CosmeticState = require(game.ReplicatedStorage.Client.CosmeticState)
local ClientActionGate = require(game.ReplicatedStorage.Client.ClientActionGate)

local player = Players.LocalPlayer

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function isPlayerCharacter(instance)
	local ancestor = instance
	while ancestor do
		if ancestor:IsA("Model") and Players:GetPlayerFromCharacter(ancestor) then
			return true
		end
		ancestor = ancestor.Parent
	end
	return false
end

-- ── Module ────────────────────────────────────────────────────────────────────

local GrappleHandler = {}
GrappleHandler.__index = GrappleHandler

function GrappleHandler.new(rootPart)
	local self = setmetatable({
		_rootPart       = rootPart,
		_grappling      = false,
		_attachPoint    = nil,
		_hookVisual     = nil,
		_hookAtt        = nil,
		_beam           = nil,
		_linearVelocity = nil,   -- LinearVelocity constraint that owns physics
		_currentVel     = Vector3.zero, -- tracked internally; not read from part
		_cooldownUntil  = 0,
		_remote         = nil,
		_resultRemote   = nil,
		_endRemote      = nil,
		_resultConnection = nil,
		_pending        = false,
		_requestId      = 0,
		_startTime      = 0,
	}, GrappleHandler)

	self._handAtt          = Instance.new("Attachment")
	self._handAtt.Name     = "GrappleHandAtt"
	self._handAtt.Position = Vector3.new(0.6, 0, -0.4)
	self._handAtt.Parent   = rootPart

	return self
end

function GrappleHandler:setRemote(remote)
	self._remote = remote
end

function GrappleHandler:setResultRemote(remote)
	if self._resultConnection then
		self._resultConnection:Disconnect()
		self._resultConnection = nil
	end

	self._resultRemote = remote
	self._resultConnection = remote.OnClientEvent:Connect(function(requestId, accepted, attachPoint, reason)
		if requestId ~= self._requestId then
			return
		end

		self._pending = false

		if not accepted then
			print(string.format("[Grapple] Server rejected grapple — %s", reason or "unknown"))
			ClientActionGate.clear("movement.grapple.request")
			return
		end

		if typeof(attachPoint) ~= "Vector3" then
			print("[Grapple] Server accepted grapple without a valid attach point")
			ClientActionGate.clear("movement.grapple.request")
			return
		end

		self:_beginGrapple(attachPoint)
	end)
end

function GrappleHandler:setEndRemote(remote)
	self._endRemote = remote
end

-- ── Beam visual ───────────────────────────────────────────────────────────────

function GrappleHandler:_createBeam(attachPoint)
	local primaryColor, secondaryColor = CosmeticState.getColors("hookTrail")
	local hook           = Instance.new("Part")
	hook.Name            = "GrappleHook"
	hook.Anchored        = true
	hook.CanCollide      = false
	hook.CastShadow      = false
	hook.Size            = Vector3.new(0.22, 0.22, 0.22)
	hook.Shape           = Enum.PartType.Ball
	hook.Material        = Enum.Material.Neon
	hook.Color           = primaryColor
	hook.Position        = attachPoint
	hook.Parent          = workspace

	local hookAtt        = Instance.new("Attachment")
	hookAtt.Parent       = hook

	local beam              = Instance.new("Beam")
	beam.Attachment0        = self._handAtt
	beam.Attachment1        = hookAtt
	beam.Width0             = 0.07
	beam.Width1             = 0.04
	beam.Color              = ColorSequence.new(primaryColor, secondaryColor)
	beam.Transparency       = NumberSequence.new(0.1)
	beam.LightEmission      = 0.35
	beam.CurveSize0         = 0
	beam.CurveSize1         = 0
	beam.FaceCamera         = false
	beam.Parent             = workspace

	self._hookVisual = hook
	self._hookAtt    = hookAtt
	self._beam       = beam
end

function GrappleHandler:_destroyBeam()
	if self._beam       then self._beam:Destroy();       self._beam       = nil end
	if self._hookAtt    then self._hookAtt:Destroy();    self._hookAtt    = nil end
	if self._hookVisual then self._hookVisual:Destroy(); self._hookVisual = nil end
end

-- ── LinearVelocity constraint ─────────────────────────────────────────────────
-- This constraint continuously applies force to maintain VectorVelocity.
-- MaxForce = 1e6 ensures it dominates the Humanoid's movement forces.

function GrappleHandler:_createLinearVelocity()
	local lv = Instance.new("LinearVelocity")
	lv.Name           = "GrapplePull"
	lv.MaxForce       = 1e6
	lv.RelativeTo     = Enum.ActuatorRelativeTo.World
	lv.VectorVelocity = self._currentVel
	lv.Attachment0    = self._handAtt
	lv.Parent         = self._rootPart
	self._linearVelocity = lv
end

function GrappleHandler:_destroyLinearVelocity()
	if self._linearVelocity then
		self._linearVelocity:Destroy()
		self._linearVelocity = nil
	end
end

-- ── Attach / detach ───────────────────────────────────────────────────────────

local function makeParams(character)
	local p = RaycastParams.new()
	p.FilterType = Enum.RaycastFilterType.Exclude
	p.FilterDescendantsInstances = { character }
	return p
end

function GrappleHandler:_beginGrapple(attachPoint)
	if not self._rootPart or not self._rootPart.Parent then
		return
	end

	self._attachPoint = attachPoint
	self._grappling   = true
	self._startTime   = os.clock()
	-- Seed internal velocity from current part velocity so the pull feels continuous.
	self._currentVel  = self._rootPart.AssemblyLinearVelocity

	print(string.format("[Grapple] Server accepted attach at (%.1f,%.1f,%.1f) — dist=%.1f",
		attachPoint.X, attachPoint.Y, attachPoint.Z,
		(attachPoint - self._rootPart.Position).Magnitude))

	self:_createBeam(attachPoint)
	self:_createLinearVelocity()
end

function GrappleHandler:tryGrapple(character, camera)
	-- Toggle off
	if self._grappling then
		print("[Grapple] Toggled off by player")
		self:cancel("toggle")
		return
	end

	if self._pending then
		print("[Grapple] Request already pending")
		return
	end

	local now = os.clock()
	if now < self._cooldownUntil then
		print(string.format("[Grapple] On cooldown (%.2fs remaining)", self._cooldownUntil - now))
		return
	end

	local canRequest = ClientActionGate.try("movement.grapple.request", 0.18)
	if not canRequest then
		print("[Grapple] Duplicate grapple request ignored")
		return
	end

	local origin = camera.CFrame.Position
	local dir    = camera.CFrame.LookVector
	local result = workspace:Raycast(origin, dir * Constants.MAX_RANGE, makeParams(character))
	if not result then
		print("[Grapple] Raycast missed — no surface in range")
		return
	end
	if isPlayerCharacter(result.Instance) then
		print("[Grapple] Hit a player character — attachment blocked")
		return
	end

	print(string.format("[Grapple] Requesting attach to '%s' at (%.1f,%.1f,%.1f) — dist=%.1f",
		result.Instance.Name,
		result.Position.X, result.Position.Y, result.Position.Z,
		(result.Position - self._rootPart.Position).Magnitude))

	if not self._remote or not self._resultRemote then
		print("[Grapple] Remote handshake unavailable — request cancelled")
		ClientActionGate.clear("movement.grapple.request")
		return
	end

	self._pending = true
	self._requestId += 1
	self._remote:FireServer(self._requestId, origin, dir, result.Position)
	local requestId = self._requestId
	task.delay(1.0, function()
		if self._pending and self._requestId == requestId then
			self._pending = false
			ClientActionGate.clear("movement.grapple.request")
			print("[Grapple] Server response timed out")
		end
	end)
	return
end

function GrappleHandler:cancel(reason)
	if self._pending then
		self._pending = false
		ClientActionGate.clear("movement.grapple.request")
		return
	end
	if not self._grappling then return end
	local exitVelocity = self._currentVel
	self._grappling     = false
	self._attachPoint   = nil
	self._cooldownUntil = os.clock() + Constants.COOLDOWN
	self._currentVel    = Vector3.zero
	print(string.format("[Grapple] Detached — reason: %s", reason or "unknown"))
	self:_destroyBeam()
	self:_destroyLinearVelocity()

	local horizontal = Vector3.new(exitVelocity.X, 0, exitVelocity.Z)
	local didSlingshot = false
	if horizontal.Magnitude >= Constants.SLINGSHOT_MIN_SPEED and self._rootPart then
		local boostedHorizontal = horizontal.Unit * math.min(
			horizontal.Magnitude * Constants.SLINGSHOT_MULT,
			Constants.SLINGSHOT_MAX_SPEED
		)
		self._rootPart.AssemblyLinearVelocity = Vector3.new(
			boostedHorizontal.X,
			math.max(exitVelocity.Y, self._rootPart.AssemblyLinearVelocity.Y),
			boostedHorizontal.Z
		)
		didSlingshot = true
		print(string.format("[Grapple] Slingshot launch — %.1f studs/s", boostedHorizontal.Magnitude))
	end
	if self._endRemote then
		self._endRemote:FireServer(didSlingshot)
	end
end

-- ── Tick (called every Heartbeat while grappling) ─────────────────────────────

function GrappleHandler:tick(dt, rootPart, _grounded)
	if not self._grappling then return end

	-- Force-cancel after MAX_DURATION
	if os.clock() - self._startTime > Constants.MAX_DURATION then
		self:cancel("max duration reached")
		return
	end

	local toHook = self._attachPoint - rootPart.Position
	local dist   = toHook.Magnitude

	-- Auto-detach when close enough
	if dist < Constants.MIN_DETACH_DIST then
		self:cancel("reached hook point")
		return
	end

	-- Accumulate pull velocity internally (do NOT read AssemblyLinearVelocity —
	-- it lags behind the LinearVelocity target and creates feedback instability)
	local pullDir    = toHook.Unit
	self._currentVel = self._currentVel + pullDir * Constants.PULL_ACCEL * dt

	if self._currentVel.Magnitude > Constants.MAX_PULL_SPEED then
		self._currentVel = self._currentVel.Unit * Constants.MAX_PULL_SPEED
	end

	-- Push target velocity into the constraint
	if self._linearVelocity then
		self._linearVelocity.VectorVelocity = self._currentVel
	end
end

-- ── Queries ───────────────────────────────────────────────────────────────────

function GrappleHandler:isGrappling()
	return self._grappling
end

-- ── Cleanup ───────────────────────────────────────────────────────────────────

function GrappleHandler:destroy()
	self:cancel()
	if self._resultConnection then
		self._resultConnection:Disconnect()
		self._resultConnection = nil
	end
	if self._handAtt then
		self._handAtt:Destroy()
		self._handAtt = nil
	end
end

return GrappleHandler
