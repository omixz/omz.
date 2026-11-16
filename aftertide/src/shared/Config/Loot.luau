--!nonstrict
-- Searchable containers and loose items. Loot rolls are free and random (never paid).
-- Ammo is deliberately scarce: a box gives 1 to 3 rounds, so every shot is a decision.
-- entry = { item, weight, min, max }; item "salvage" is the run currency.
return {
	Containers = {
		Drawer = { rolls = 1, table = "household", hold = 0.9 },
		Locker = { rolls = 2, table = "household", hold = 1.2 },
		Toolbox = { rolls = 2, table = "workshop", hold = 1.0 },
		AmmoCrate = { rolls = 2, table = "ammo", hold = 1.4 },
	},
	Tables = {
		household = {
			{ "cloth", 30, 1, 1 }, { "alcohol", 26, 1, 1 }, { "tape", 14, 1, 1 }, { "canister", 10, 1, 1 },
			{ "dressing", 4, 1, 1 }, { "bottle", 12, 1, 1 }, { "salvage", 22, 4, 9 }, { "pistolAmmo", 6, 1, 2 },
		},
		workshop = {
			{ "scrap", 30, 1, 1 }, { "tape", 22, 1, 1 }, { "powder", 18, 1, 1 }, { "canister", 14, 1, 1 },
			{ "salvage", 26, 6, 12 }, { "arrows", 6, 1, 2 },
		},
		ammo = {
			{ "pistolAmmo", 24, 1, 3 }, { "rifleAmmo", 14, 1, 2 }, { "shells", 12, 1, 2 }, { "arrows", 12, 1, 3 },
			{ "powder", 14, 1, 1 }, { "salvage", 18, 5, 10 },
		},
		loose = {
			{ "cloth", 18, 1, 1 }, { "alcohol", 16, 1, 1 }, { "scrap", 18, 1, 1 }, { "tape", 10, 1, 1 },
			{ "powder", 8, 1, 1 }, { "canister", 8, 1, 1 }, { "bottle", 14, 1, 1 }, { "pistolAmmo", 5, 1, 2 },
			{ "salvage", 12, 3, 6 },
		},
	},
	LooseItems = 14, -- per encounter
	MaxContainers = 11, -- searchable containers per encounter (random subset of the map's spots)
	PallBonusRolls = 0.15, -- extra roll chance per Pall level
}
