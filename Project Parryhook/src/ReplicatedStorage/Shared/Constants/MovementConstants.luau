-- MovementConstants
-- Shared between client and server. Edit values here to tune feel.

return {
	-- Ground movement
	WALK_SPEED          = 16,   -- studs/s
	SPRINT_SPEED        = 28,   -- studs/s
	ACCELERATION        = 60,   -- studs/s² toward target speed on ground
	DECELERATION        = 80,   -- studs/s² when no input on ground

	-- Jump
	JUMP_FORCE          = 50,   -- studs/s upward impulse

	-- Air
	AIR_CONTROL_FACTOR  = 0.4,  -- 0 = no air control, 1 = full control

	-- Dash
	DASH_SPEED          = 75,   -- studs/s burst velocity
	DASH_DURATION       = 0.28, -- seconds the dash burst lasts
	DASH_COOLDOWN       = 0.85, -- seconds before next dash is allowed

	-- Slide
	SLIDE_SPEED_START   = 52,   -- studs/s at slide entry (momentum boost from sprint)
	SLIDE_SPEED_END     = 8,    -- studs/s at slide exit (skidding to a stop)
	SLIDE_DURATION      = 0.85, -- seconds the slide lasts at full length
	SLIDE_COOLDOWN      = 0.60, -- seconds before next slide is allowed
	SLIDE_HIP_HEIGHT    = 0.5,  -- Humanoid.HipHeight while crouched (R15 default is 2.0)
	NORMAL_HIP_HEIGHT   = 2.0,  -- Humanoid.HipHeight when standing

	-- Camera
	FOV_NORMAL          = 90,   -- default field of view
	FOV_SPRINT          = 95,   -- slight zoom-out while sprinting
	FOV_DASH            = 108,  -- rush-of-speed feel during dash
	FOV_LERP_SPEED      = 10,   -- how fast FOV transitions between states

	-- Camera lean offsets (studs, applied via CameraOffset)
	LEAN_DASH_Z         = -0.5, -- forward lean during dash (negative Z = forward)
	LEAN_SLIDE_Z        = -0.35,-- forward lean during slide
	LEAN_LERP_SPEED     = 14,   -- how fast lean transitions

	-- Head bob
	BOB_WALK_AMPLITUDE  = 0.08, -- vertical offset in studs while walking
	BOB_WALK_FREQUENCY  = 8,    -- oscillations per second while walking
	BOB_SPRINT_AMPLITUDE = 0.14,
	BOB_SPRINT_FREQUENCY = 13,
	BOB_LERP_SPEED      = 10,   -- how fast bob fades in/out between states

	-- Physics / detection
	GROUND_CHECK_DIST   = 2.5,  -- raycast length downward from RootPart
	MAX_SPEED_TOLERANCE = 1.5,  -- server validator: multiplier above SPRINT_SPEED before correcting
}
