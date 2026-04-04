-- HealthBootstrap (Script — server only)
-- Requires HealthSystem (ModuleScript) to start the player lifecycle.
-- This is intentionally thin — all logic lives in HealthSystem.luau.

local HealthSystem = require(script.Parent.HealthSystem)
HealthSystem.init()
