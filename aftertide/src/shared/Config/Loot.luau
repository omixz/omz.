--!nonstrict
-- Searchable containers and loose items. Loot rolls are free and random (never paid).
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
			{ "dressing", 4, 1, 1 }, { "bottle", 12, 1, 1 }, { "salvage", 22, 4, 9 }, { "pistolAmmo", 10, 2, 4 },
		},
		workshop = {
			{ "scrap", 30, 1, 1 }, { "tape", 22, 1, 1 }, { "powder", 18, 1, 1 }, { "canister", 14, 1, 1 },
			{ "salvage", 26, 6, 12 }, { "arrows", 8, 2, 3 },
		},
		ammo = {
			{ "pistolAmmo", 30, 3, 6 }, { "rifleAmmo", 18, 2, 3 }, { "shells", 16, 2, 3 }, { "arrows", 14, 2, 4 },
			{ "powder", 10, 1, 1 }, { "salvage", 12, 5, 10 },
		},
		loose = {
			{ "cloth", 18, 1, 1 }, { "alcohol", 16, 1, 1 }, { "scrap", 18, 1, 1 }, { "tape", 10, 1, 1 },
			{ "powder", 8, 1, 1 }, { "canister", 8, 1, 1 }, { "bottle", 14, 1, 1 }, { "pistolAmmo", 10, 2, 3 },
			{ "salvage", 12, 3, 6 },
		},
	},
	LooseItems = 14, -- per encounter
	PallBonusRolls = 0.15, -- extra roll chance per Pall level
}
