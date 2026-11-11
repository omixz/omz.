--!nonstrict
-- The run ("crossing"): RunLength encounters chosen on the tide chart, each followed by a
-- return to the Meridian, then the finale. The Pall rises after every encounter.
return {
	RunLength = 3, -- encounters before the finale
	Types = {
		Salvage = {
			name = "Salvage",
			desc = "Salvage %d supply crates, then reach the Slipway flare.",
			crates = 4,
		},
		LanternWatch = {
			name = "Lantern Watch",
			desc = "Keep the signal lantern lit until the tide turns.",
			waves = 3, waveTime = 40, perWave = 4, lanternHP = 400, dps = 18,
		},
		Drift = {
			name = "Drift",
			desc = "They know you're here. Survive until the tide turns, then reach the flare.",
			duration = 150, huntInterval = 14, spawnInterval = 22, perSpawn = 2,
		},
	},
	Finale = {
		name = "The Breakwater",
		desc = "Keep the lantern lit through the last tide. Something big is coming.",
		type = "LanternWatch", waves = 4, waveTime = 45, perWave = 5, lanternHP = 600, dps = 18,
		boss = "Tidewalker",
	},
	-- Base enemies on the map, plus per-Pall and per-extra-player scaling.
	BaseEnemies = 5,
	PerPall = 1,
	PerExtraPlayer = 2,
	MaxEnemies = 16,
	-- Enemy type unlocks by Pall level (weights).
	TypeWeights = {
		[1] = { Drifter = 4, Rusher = 2 },
		[2] = { Drifter = 4, Rusher = 2, Seeker = 1.5, Bellwether = 1 },
		[3] = { Drifter = 3, Rusher = 2, Seeker = 2, Bellwether = 1, Tidewalker = 0.5 },
		[4] = { Drifter = 3, Rusher = 3, Seeker = 2, Bellwether = 1, Tidewalker = 1 },
	},
	Rewards = {
		salvagePerEncounter = 15, -- +5 per Pall
		scripPerEncounter = 10, -- +5 per encounter index
		scripRunComplete = 50,
	},
}
