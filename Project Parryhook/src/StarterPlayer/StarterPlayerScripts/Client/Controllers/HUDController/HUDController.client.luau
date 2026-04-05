-- HUDController (LocalScript)
-- Bootstraps the HUD singleton and wires the Tab key for scoreboard toggle.
-- All other HUD updates are driven by the individual game controllers.

local UserInputService = game:GetService("UserInputService")

local HUD = require(game.ReplicatedStorage.Client.HUD)

-- ── Scoreboard — hold Tab to view ─────────────────────────────────────────────

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.Tab then
		HUD.showScoreboard(true)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.Tab then
		HUD.showScoreboard(false)
	end
end)
