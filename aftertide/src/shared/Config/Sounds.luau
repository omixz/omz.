--!nonstrict
-- Placeholder sounds use files that ship inside the Roblox client (rbxasset://).
-- Replace with original or Roblox-licensed audio (Creator Store > Audio) and log each one in
-- the asset register (docs/04-ip-compliance.md). An empty string disables that sound.
return {
	Quieting = "rbxasset://sounds/swordslash.wav",
	Shove = "rbxasset://sounds/swordlunge.wav",
	BottleBreak = "rbxasset://sounds/impact_water.mp3",
	SlingshotFire = "rbxasset://sounds/swordlunge.wav",
	Spotted = "rbxasset://sounds/electronicpingshort.wav",
	Rattle = "rbxasset://sounds/electronicpingshort.wav",
	Splash = "rbxasset://sounds/impact_water.mp3",
	Search = "rbxasset://sounds/swordlunge.wav",
	Explosion = "",
	Hum = "",
	-- Gunshots: pick free Roblox-licensed sounds in Creator Store > Audio and paste
	-- "rbxassetid://<id>" here. Empty = silent (the noise event still alerts the Hushed).
	Gun_revolver = "",
	Gun_carbine = "",
	Gun_rifle = "",
	Gun_shotgun = "",
	Gun_bow = "",
	Reload = "",
	DryFire = "",
}
