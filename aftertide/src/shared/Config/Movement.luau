--!nonstrict
-- Speeds are studs/second. Noise values are the radius (studs) in which Hushed can hear you.
return {
	Speeds = {
		Crouch = 6.5,
		Prone = 3.2,
		Walk = 9,
		Jog = 14,
		Sprint = 20,
		Aim = 7,
		Downed = 2.5,
	},
	Noise = {
		Crouch = 3,
		Prone = 1.5,
		Walk = 9,
		Jog = 16,
		Sprint = 30,
	},
	Accel = 38, -- how fast WalkSpeed ramps up (studs/s^2): gives weight to starts
	Decel = 70,
	WaterNoiseMult = 1.6, -- wading is louder...
	WaterSpeedMult = 0.75, -- ...and slower
	CrouchHipMult = 0.66, -- procedural crouch pose lowers hips to this fraction
}
