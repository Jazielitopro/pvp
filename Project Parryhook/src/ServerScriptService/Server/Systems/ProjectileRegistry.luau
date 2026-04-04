-- ProjectileRegistry (ModuleScript — server only)
-- Single source of truth for all in-flight projectiles.
-- Required by ProjectileSpawner (register), ProjectileSimulator (iterate/update),
-- and CollisionHandler (remove on hit).
--
-- Projectile data shape:
--   id           : number       — unique, auto-assigned
--   owner        : Player       — who fired
--   position     : Vector3      — current server position (updated every heartbeat)
--   velocity     : Vector3      — constant direction × speed (no gravity for revolver)
--   spawnTime    : number       — os.clock() at registration
--   filterParams : RaycastParams — excludes owner's character

local ProjectileRegistry = {}

local registry = {}  -- [id] = projectileData
local nextId   = 1

function ProjectileRegistry.register(data)
	data.id = nextId
	nextId  += 1
	registry[data.id] = data
	return data.id
end

function ProjectileRegistry.get(id)
	return registry[id]
end

function ProjectileRegistry.remove(id)
	registry[id] = nil
end

-- Returns the live table — callers must not store the reference across yields.
function ProjectileRegistry.getAll()
	return registry
end

function ProjectileRegistry.count()
	local n = 0
	for _ in pairs(registry) do n += 1 end
	return n
end

return ProjectileRegistry
