-- GrappleHandler
-- Client-side grapple logic. Attaches to environment surfaces only.
-- Applies acceleration-based pull toward hook point each frame.
-- CharacterController calls tryGrapple() on input, tick() every Heartbeat.
--
-- Visual: straight Beam rope + small glowing sphere at hook point.
-- Server is notified via GrappleRequest (recorded for CharacterValidator).

local Players  = game:GetService("Players")
local Constants = require(game.ReplicatedStorage.Shared.Constants.GrappleConstants)

local player = Players.LocalPlayer

-- ── Helpers ───────────────────────────────────────────────────────────────────

-- Returns true if `instance` is part of any player's character.
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

-- rootPart : HumanoidRootPart — used for physics and beam origin
function GrappleHandler.new(rootPart)
	local self = setmetatable({
		_rootPart      = rootPart,
		_grappling     = false,
		_attachPoint   = nil,
		_hookVisual    = nil,
		_hookAtt       = nil,
		_beam          = nil,
		_cooldownUntil = 0,
		_remote        = nil,
	}, GrappleHandler)

	-- Permanent hand attachment: Beam origin, parented to the root part.
	-- Offset slightly right and forward so the rope appears to come from the hand.
	self._handAtt          = Instance.new("Attachment")
	self._handAtt.Position = Vector3.new(0.6, 0, -0.4)
	self._handAtt.Parent   = rootPart

	return self
end

function GrappleHandler:setRemote(remote)
	self._remote = remote
end

-- ── Beam visual ───────────────────────────────────────────────────────────────

function GrappleHandler:_createBeam(attachPoint)
	-- Hook point: small glowing sphere at impact location
	local hook           = Instance.new("Part")
	hook.Name            = "GrappleHook"
	hook.Anchored        = true
	hook.CanCollide      = false
	hook.CastShadow      = false
	hook.Size            = Vector3.new(0.22, 0.22, 0.22)
	hook.Shape           = Enum.PartType.Ball
	hook.Material        = Enum.Material.Neon
	hook.Color           = Color3.fromRGB(220, 175, 55)
	hook.Position        = attachPoint
	hook.Parent          = workspace

	local hookAtt        = Instance.new("Attachment")
	hookAtt.Parent       = hook

	-- Rope beam between hand and hook
	local beam              = Instance.new("Beam")
	beam.Attachment0        = self._handAtt
	beam.Attachment1        = hookAtt
	beam.Width0             = 0.07
	beam.Width1             = 0.04
	beam.Color              = ColorSequence.new(Color3.fromRGB(190, 190, 190))
	beam.Transparency       = NumberSequence.new(0.15)
	beam.LightEmission      = 0
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

-- ── Attach / detach ───────────────────────────────────────────────────────────

-- Returns a RaycastParams that excludes the local player's character.
local function makeParams(character)
	local p = RaycastParams.new()
	p.FilterType = Enum.RaycastFilterType.Exclude
	p.FilterDescendantsInstances = { character }
	return p
end

-- Called on F key press. Toggles grapple on/off.
function GrappleHandler:tryGrapple(character, camera)
	if self._grappling then
		self:cancel()
		return
	end

	if os.clock() < self._cooldownUntil then return end

	-- Raycast from camera position along look vector
	local origin = camera.CFrame.Position
	local dir    = camera.CFrame.LookVector

	local result = workspace:Raycast(origin, dir * Constants.MAX_RANGE, makeParams(character))
	if not result then return end

	-- Reject player characters — environment only in MVP
	if isPlayerCharacter(result.Instance) then return end

	self._attachPoint = result.Position
	self._grappling   = true

	self:_createBeam(result.Position)

	-- Notify server (recorded for CharacterValidator speed checks)
	if self._remote then
		self._remote:FireServer(result.Position)
	end
end

-- Force-cancel grapple (e.g. called by dash input).
function GrappleHandler:cancel()
	if not self._grappling then return end
	self._grappling   = false
	self._attachPoint = nil
	self._cooldownUntil = os.clock() + Constants.COOLDOWN
	self:_destroyBeam()
end

-- ── Tick (called every Heartbeat while GRAPPLING state is active) ─────────────

function GrappleHandler:tick(dt, rootPart, grounded)
	if not self._grappling then return end

	-- Auto-detach when player lands
	if grounded then
		self:cancel()
		return
	end

	local toHook = self._attachPoint - rootPart.Position
	local dist   = toHook.Magnitude

	-- Auto-detach when close enough
	if dist < Constants.MIN_DETACH_DIST then
		self:cancel()
		return
	end

	-- Apply pull: add acceleration toward hook, cap total speed
	local pullDir  = toHook.Unit
	local vel      = rootPart.AssemblyLinearVelocity + pullDir * Constants.PULL_ACCEL * dt

	if vel.Magnitude > Constants.MAX_PULL_SPEED then
		vel = vel.Unit * Constants.MAX_PULL_SPEED
	end

	rootPart.AssemblyLinearVelocity = vel
end

-- ── Queries ───────────────────────────────────────────────────────────────────

function GrappleHandler:isGrappling()
	return self._grappling
end

-- ── Cleanup ───────────────────────────────────────────────────────────────────

function GrappleHandler:destroy()
	self:cancel()
	if self._handAtt then
		self._handAtt:Destroy()
		self._handAtt = nil
	end
end

return GrappleHandler
