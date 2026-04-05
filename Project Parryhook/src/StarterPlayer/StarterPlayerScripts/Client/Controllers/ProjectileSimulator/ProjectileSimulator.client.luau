-- ProjectileSimulator (LocalScript — client only)
-- Visual-only bullet simulation. No hit detection — server is authoritative.
-- Creates a glowing Part per bullet and moves it each RenderStepped.
-- Removes the part when the server confirms a hit (ImpactEffect) or on lifetime expiry.
--
-- SpawnProjectile : (id, ownerId, origin: Vector3, direction: Vector3, speed: number)
-- ImpactEffect    : (position: Vector3, normal: Vector3, isKill: boolean)

local RunService       = game:GetService("RunService")
local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")

local player           = Players.LocalPlayer

local remotes          = game.ReplicatedStorage:WaitForChild("Remotes")
local spawnProjectile  = remotes:WaitForChild("SpawnProjectile")
local impactEffect     = remotes:WaitForChild("ImpactEffect")
local WeaponConstants  = require(game.ReplicatedStorage.Shared.Constants.WeaponConstants)

-- ── Active visual bullets ─────────────────────────────────────────────────────
-- [id] = { part, position, velocity, spawnTime }

local bullets = {}

-- ── Bullet part factory ───────────────────────────────────────────────────────

local function makeBulletPart(origin, direction)
	local part           = Instance.new("Part")
	part.Name            = "Bullet"
	part.Size            = Vector3.new(0.12, 0.12, 0.45)
	part.Material        = Enum.Material.Neon
	part.Color           = Color3.fromRGB(255, 215, 80)   -- golden revolver bullet
	part.CastShadow      = false
	part.CanCollide      = false
	part.Anchored        = true
	part.CFrame          = CFrame.lookAt(origin, origin + direction)
	part.Parent          = workspace

	-- Brief faint trail using a Beam between two attachments
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0,  0,  0.225)  -- front
	a0.Parent   = part

	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0,  0, -0.225)  -- back
	a1.Parent   = part

	local trail       = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime    = 0.06
	trail.MinLength   = 0
	trail.FaceCamera  = true
	trail.Color       = ColorSequence.new(Color3.fromRGB(255, 215, 80), Color3.fromRGB(255, 140, 30))
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.WidthScale  = NumberSequence.new(1, 0)
	trail.Parent      = part

	return part
end

-- ── Spawn handler ─────────────────────────────────────────────────────────────

spawnProjectile.OnClientEvent:Connect(function(id, _ownerId, origin, direction, speed)
	local part = makeBulletPart(origin, direction)

	bullets[id] = {
		part      = part,
		position  = origin,
		velocity  = direction * speed,
		spawnTime = os.clock(),
	}
end)

-- ── Simulation (visual only) ──────────────────────────────────────────────────

RunService.RenderStepped:Connect(function(dt)
	local now = os.clock()

	for id, bullet in pairs(bullets) do
		-- Expire if server lifetime reached
		if (now - bullet.spawnTime) >= WeaponConstants.BULLET_LIFETIME then
			bullet.part:Destroy()
			bullets[id] = nil
			continue
		end

		local newPos = bullet.position + bullet.velocity * dt
		bullet.position = newPos
		bullet.part.CFrame = CFrame.lookAt(newPos, newPos + bullet.velocity.Unit)
	end
end)

-- ── Impact effect ─────────────────────────────────────────────────────────────
-- Spawns a ParticleEmitter burst + small neon core at the hit position.
-- The anchor Part is destroyed after the particles finish emitting.

local function spawnImpact(position, normal, isKill)
	local hitColor  = isKill
		and Color3.fromRGB(220, 30,  30)   -- red on kill
		or  Color3.fromRGB(255, 200, 80)   -- golden on hit

	-- Tiny anchor part so ParticleEmitter has somewhere to live
	local anchor        = Instance.new("Part")
	anchor.Name         = "ImpactFX"
	anchor.Anchored     = true
	anchor.CanCollide   = false
	anchor.CastShadow   = false
	anchor.Transparency = 1
	anchor.Size         = Vector3.new(0.1, 0.1, 0.1)
	-- Orient Part so +Y aligns with surface normal (particles emit upward from surface)
	anchor.CFrame       = CFrame.new(position, position + normal)
		* CFrame.Angles(math.pi / 2, 0, 0)
	anchor.Parent       = workspace

	-- Core flash: small neon sphere that quickly fades
	local core          = Instance.new("Part")
	core.Anchored       = true
	core.CanCollide     = false
	core.CastShadow     = false
	core.Shape          = Enum.PartType.Ball
	core.Material       = Enum.Material.Neon
	core.Color          = hitColor
	core.Size           = Vector3.new(0.3, 0.3, 0.3)
	core.Position       = position
	core.Parent         = workspace

	local CORE_FADE = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	local coreTween = TweenService:Create(core, CORE_FADE, {
		Transparency = 1,
		Size         = Vector3.new(0.08, 0.08, 0.08),
	})
	coreTween:Play()
	coreTween.Completed:Connect(function() core:Destroy() end)

	-- Spark particles
	local emitter                   = Instance.new("ParticleEmitter")
	emitter.Color                   = ColorSequence.new(hitColor, Color3.fromRGB(255, 255, 200))
	emitter.LightEmission           = 0.8
	emitter.LightInfluence          = 0.2
	emitter.Size                    = NumberSequence.new({
		NumberSequenceKeypoint.new(0,   0.08),
		NumberSequenceKeypoint.new(0.4, 0.04),
		NumberSequenceKeypoint.new(1,   0),
	})
	emitter.Transparency            = NumberSequence.new({
		NumberSequenceKeypoint.new(0,   0),
		NumberSequenceKeypoint.new(0.7, 0.4),
		NumberSequenceKeypoint.new(1,   1),
	})
	emitter.Speed                   = NumberRange.new(8, 22)
	emitter.SpreadAngle             = Vector2.new(60, 60)
	emitter.Lifetime                = NumberRange.new(0.15, 0.35)
	emitter.Rate                    = 0     -- burst only, not continuous
	emitter.RotSpeed                = NumberRange.new(-180, 180)
	emitter.Rotation                = NumberRange.new(0, 360)
	emitter.Parent                  = anchor

	-- Fire a one-shot burst then clean up
	emitter:Emit(isKill and 20 or 10)

	task.delay(0.5, function()
		anchor:Destroy()
	end)
end

impactEffect.OnClientEvent:Connect(function(position, normal, isKill)
	spawnImpact(position, normal, isKill)
end)
