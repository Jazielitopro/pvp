-- UITheme (ModuleScript - client only)
-- Shared front-page Roblox-inspired interface language: compact glass panels,
-- bold neon accents, high contrast, and large mobile-friendly hit targets.

local Theme = {}

Theme.colors = {
	ink = Color3.fromRGB(6, 8, 14),
	panel = Color3.fromRGB(11, 14, 24),
	panelSoft = Color3.fromRGB(18, 23, 38),
	panelLift = Color3.fromRGB(29, 36, 58),
	stroke = Color3.fromRGB(82, 105, 150),
	cyan = Color3.fromRGB(64, 230, 255),
	gold = Color3.fromRGB(255, 216, 84),
	pink = Color3.fromRGB(255, 86, 174),
	violet = Color3.fromRGB(154, 101, 255),
	green = Color3.fromRGB(112, 255, 151),
	red = Color3.fromRGB(255, 82, 92),
	text = Color3.fromRGB(245, 248, 255),
	muted = Color3.fromRGB(158, 172, 198),
	shadow = Color3.fromRGB(0, 0, 0),
}

Theme.fonts = {
	title = Enum.Font.GothamBlack,
	bold = Enum.Font.GothamBold,
	body = Enum.Font.GothamMedium,
}

Theme.corner = UDim.new(0, 14)
Theme.smallCorner = UDim.new(0, 9)

function Theme.applyCorner(instance, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius or Theme.corner
	corner.Parent = instance
	return corner
end

function Theme.applyStroke(instance, color, transparency, thickness)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or Theme.colors.stroke
	stroke.Transparency = transparency or 0.48
	stroke.Thickness = thickness or 1.5
	stroke.Parent = instance
	return stroke
end

function Theme.applyGradient(instance, fromColor, toColor, rotation)
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, fromColor or Theme.colors.panelLift),
		ColorSequenceKeypoint.new(1, toColor or Theme.colors.panel),
	})
	gradient.Rotation = rotation or 90
	gradient.Parent = instance
	return gradient
end

function Theme.stylePanel(instance, options)
	options = options or {}
	instance.BackgroundColor3 = options.color or Theme.colors.panel
	instance.BackgroundTransparency = options.transparency or 0.12
	instance.BorderSizePixel = 0
	Theme.applyCorner(instance, options.corner or Theme.corner)
	Theme.applyStroke(instance, options.strokeColor, options.strokeTransparency, options.strokeThickness)
	Theme.applyGradient(instance, options.gradientFrom, options.gradientTo, options.gradientRotation)
	return instance
end

function Theme.styleButton(instance, accentColor)
	instance.BackgroundColor3 = Theme.colors.panelLift
	instance.BackgroundTransparency = 0.04
	instance.BorderSizePixel = 0
	instance.TextColor3 = accentColor or Theme.colors.text
	instance.Font = Theme.fonts.bold
	Theme.applyCorner(instance, Theme.smallCorner)
	Theme.applyStroke(instance, accentColor or Theme.colors.cyan, 0.38, 1.5)
	Theme.applyGradient(instance, Theme.colors.panelLift, Theme.colors.panel, 0)
	return instance
end

function Theme.styleLabel(instance, color, font)
	instance.BackgroundTransparency = 1
	instance.TextColor3 = color or Theme.colors.text
	instance.Font = font or Theme.fonts.body
	return instance
end

return Theme
