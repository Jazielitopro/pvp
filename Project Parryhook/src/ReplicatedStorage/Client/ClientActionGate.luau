-- ClientActionGate
-- Shared client-side guard for inputs that send RemoteEvents.
-- It prevents duplicated LocalScripts or repeated input events from sending the
-- same action twice before the server can answer.

local ClientActionGate = {}

local nextAllowedAt = {}
local singletons = {}

function ClientActionGate.startSingleton(name)
	if singletons[name] then
		return false
	end

	singletons[name] = true
	return true
end

function ClientActionGate.try(actionName, interval)
	local now = os.clock()
	local nextAllowed = nextAllowedAt[actionName]

	if nextAllowed and now < nextAllowed then
		return false, nextAllowed - now
	end

	nextAllowedAt[actionName] = now + (interval or 0)
	return true, 0
end

function ClientActionGate.hold(actionName, interval)
	nextAllowedAt[actionName] = os.clock() + (interval or 0)
end

function ClientActionGate.clear(actionName)
	nextAllowedAt[actionName] = nil
end

return ClientActionGate
