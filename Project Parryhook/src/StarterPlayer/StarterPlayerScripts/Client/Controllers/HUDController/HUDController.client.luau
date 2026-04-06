-- HUDController (LocalScript)
-- Bootstraps the HUD singleton and wires the Tab key for scoreboard toggle.
-- All other HUD updates are driven by the individual game controllers.

local UserInputService = game:GetService("UserInputService")
local Players          = game:GetService("Players")

local HUD    = require(game.ReplicatedStorage.Client.HUD)
local player = Players.LocalPlayer

print("[HUDController] Initialized for", player.Name)

if typeof(HUD.showScoreboard) ~= "function" then
	warn("[HUDController] HUD.showScoreboard is missing — check HUD.luau")
else
	print("[HUDController] HUD module OK")
end

-- ── Scoreboard — hold Tab to view ─────────────────────────────────────────────

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.Tab then
		print("[HUDController] Tab pressed — showing scoreboard")
		HUD.showScoreboard(true)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.Tab then
		print("[HUDController] Tab released — hiding scoreboard")
		HUD.showScoreboard(false)
	end
end)
