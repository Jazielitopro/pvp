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

-- Remove all visual bullets when any impact fires
-- (server has already determined which bullet hit — we remove the oldest active one
--  heuristically; full id-based removal would need the projectile id in ImpactEffect)
local function spawnImpactFlash(position, _normal, isKill)
	local flash           = Instance.new("Part")
	flash.Name            = "ImpactFlash"
	flash.Size            = Vector3.new(0.6, 0.6, 0.6)
	flash.Shape           = Enum.PartType.Ball
	flash.Material        = Enum.Material.Neon
	flash.Color           = isKill
		and Color3.fromRGB(220, 30, 30)   -- red kill flash
		or  Color3.fromRGB(255, 200, 80)  -- golden hit flash
	flash.CastShadow      = false
	flash.CanCollide      = false
	flash.Anchored        = true
	flash.Position        = position
	flash.Parent          = workspace

	-- Tween: scale up and fade out
	local EXPAND = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(flash, EXPAND, {
		Size = Vector3.new(1.4, 1.4, 1.4),
	}):Play()

	local FADE = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	local fadeTween = TweenService:Create(flash, FADE, {
		Transparency = 1,
	})
	fadeTween:Play()
	fadeTween.Completed:Connect(function()
		flash:Destroy()
	end)
end

impactEffect.OnClientEvent:Connect(function(position, normal, isKill)
	spawnImpactFlash(position, normal, isKill)
end)
