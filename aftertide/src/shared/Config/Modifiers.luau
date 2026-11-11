--!nonstrict
-- Environmental modifiers. One is rolled per encounter (or none) for replayability.
-- Fields: sightMult, noiseMult (all noise), footstepMult, partsMult, fogDensity, ambientBoost, lightning, night
return {
	None = { id = "None", name = "Still Water", desc = "An ordinary grey evening on the Marrow Coast.", fogDensity = 0.34 },
	List = {
		{ id = "HeavyPall", name = "Heavy Pall", desc = "Thick fog. Everyone sees less.", sightMult = 0.65, fogDensity = 0.55 },
		{ id = "Squall", name = "Squall", desc = "Wind masks your footsteps.", footstepMult = 0.6, sightMult = 0.9, fogDensity = 0.42, lightning = true },
		{ id = "Nightfall", name = "Nightfall", desc = "Full dark. Your torch is the only light, and they see it.", sightMult = 0.8, fogDensity = 0.36, night = true },
		{ id = "Echoing", name = "Echoing", desc = "Every sound carries further.", noiseMult = 1.5, fogDensity = 0.34 },
		{ id = "Moonbreak", name = "Moonbreak", desc = "The fog thins. You see them. They see you.", sightMult = 1.3, fogDensity = 0.18, ambientBoost = 0.35 },
		{ id = "ScavengedOut", name = "Scavenged Out", desc = "Someone got here first. Half the parts.", partsMult = 0.5, fogDensity = 0.34 },
	},
	NoneChance = 0.2,
}
