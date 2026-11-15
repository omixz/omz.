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
		Hunt = {
			name = "Cut the Head Off",
			desc = "A marked leader is out there (%d). Find them, put them down, then reach the flare.",
			count = 1, hpMult = 3,
			elite = { Watch = { type = "WatchRifleman", title = "Watch Captain" }, Tidebound = { type = "TideboundHook", title = "Tidebound Priest" }, Hushed = { type = "Bellwether", title = "The Matriarch" } },
		},
		Rescue = {
			name = "Bring Them Home",
			desc = "A survivor is hiding out there (%d). Find them and lead them to the Slipway flare alive.",
			count = 1, hp = 100, grabDamage = 22,
		},
		Medicine = {
			name = "Medicine Run",
			desc = "Find %d medical caches (look inside buildings), then reach the Slipway flare.",
			count = 3,
		},
		Relay = {
			name = "Restore the Signal",
			desc = "Repair %d radio relays. It's loud work: expect company. Then reach the flare.",
			count = 3, hold = 6, noise = 50,
		},
		Nests = {
			name = "Burn the Nests",
			desc = "Destroy %d salt nests (fire and explosives work best), then reach the flare.",
			count = 4, hp = 160,
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
	-- Who holds the ground on a route. Factions appear from the second stop.
	Factions = {
		Watch = { name = "Harbour Watch", desc = "Armed militia patrols with flashlights and radios.", weights = { WatchRifleman = 3, WatchScout = 2, Drifter = 1 } },
		Tidebound = { name = "The Tidebound", desc = "Cultists with silent bows and hooks. Listen for the bell.", weights = { TideboundHook = 3, TideboundArcher = 2, Drifter = 1 } },
	},
	FactionChance = 0.45,
	-- Enemy type unlocks by Pall level (weights).
	TypeWeights = {
		[1] = { Drifter = 4, Rusher = 2 },
		[2] = { Drifter = 4, Rusher = 2, Seeker = 1.5, Bellwether = 1 },
		[3] = { Drifter = 3, Rusher = 2, Seeker = 2, Bellwether = 1, Tidewalker = 0.5 },
		[4] = { Drifter = 3, Rusher = 3, Seeker = 2, Bellwether = 1, Tidewalker = 1 },
	},
	Rewards = {
		salvagePerEncounter = 15, -- +5 per Pall
		scripPerEncounter = 25, -- +10 per encounter index (spent at the Quartermaster)
		scripRunComplete = 80,
	},
}
