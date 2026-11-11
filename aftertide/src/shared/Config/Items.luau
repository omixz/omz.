--!nonstrict
-- Everything that can live in the satchel. Scarcity is the point: several recipes compete
-- for the same parts, so every craft is a decision. Satchel capacity is NEVER sold;
-- it is upgraded at the workbench with Salvage earned in the run.
return {
	Items = {
		-- crafting parts
		cloth = { name = "Cloth", kind = "part", cap = 3 },
		alcohol = { name = "Alcohol", kind = "part", cap = 3 },
		powder = { name = "Black Salt", kind = "part", cap = 3 },
		scrap = { name = "Scrap", kind = "part", cap = 3 },
		tape = { name = "Tape", kind = "part", cap = 3 },
		canister = { name = "Canister", kind = "part", cap = 3 },
		-- ammunition (reserve; magazines live on the weapon)
		pistolAmmo = { name = "Revolver rounds", kind = "ammo", cap = 18 },
		rifleAmmo = { name = "Rifle rounds", kind = "ammo", cap = 12 },
		shells = { name = "Shells", kind = "ammo", cap = 8 },
		arrows = { name = "Arrows", kind = "ammo", cap = 10 },
		-- consumables, throwables, tools
		dressing = { name = "Field Dressing", kind = "consumable", cap = 2 },
		bottle = { name = "Bottle", kind = "throwable", cap = 3 },
		flarePot = { name = "Flare Pot", kind = "throwable", cap = 2 },
		fogPot = { name = "Fog Pot", kind = "throwable", cap = 2 },
		saltBomb = { name = "Salt Bomb", kind = "throwable", cap = 2 },
		spike = { name = "Tide Spike", kind = "tool", cap = 2 },
	},
	Order = {
		"cloth", "alcohol", "powder", "scrap", "tape", "canister",
		"pistolAmmo", "rifleAmmo", "shells", "arrows",
		"dressing", "bottle", "flarePot", "fogPot", "saltBomb", "spike",
	},
	Parts = { "cloth", "alcohol", "powder", "scrap", "tape", "canister" },
	Throwables = { "bottle", "flarePot", "fogPot", "saltBomb" },

	Recipes = {
		dressing = { name = "Field Dressing", output = "dressing", amount = 1, cost = { cloth = 1, alcohol = 1 }, time = 2 },
		flarePot = { name = "Flare Pot", output = "flarePot", amount = 1, cost = { alcohol = 1, cloth = 1 }, time = 1.5 },
		fogPot = { name = "Fog Pot", output = "fogPot", amount = 1, cost = { powder = 1, canister = 1 }, time = 1.5 },
		saltBomb = { name = "Salt Bomb", output = "saltBomb", amount = 1, cost = { powder = 1, scrap = 1 }, time = 2, perkYield = true },
		spike = { name = "Tide Spike", output = "spike", amount = 1, cost = { scrap = 1, tape = 1 }, time = 1.2, perkYield = true },
		arrows = { name = "Arrows x2", output = "arrows", amount = 2, cost = { scrap = 1 }, time = 1, perkYield = true },
	},
	RecipeOrder = { "dressing", "flarePot", "fogPot", "saltBomb", "spike", "arrows" },

	Dressing = { heal = 60, channel = 2.2 },
	Throw = {
		speed = 75,
		lift = 16,
		bottle = { noise = 45 },
		flarePot = { radius = 7, duration = 7, dps = 32, noise = 30 },
		fogPot = { radius = 10, duration = 10, stun = 2.5, noise = 14 },
		saltBomb = { radius = 9, damage = 150, armTime = 0.8, triggerRadius = 5, noise = 90, lifetime = 90 },
	},
	Quieting = { range = 4.5, time = 0.9, noise = 6, salvage = 3 },
	Shove = { range = 5.5, cooldown = 4, stun = 2.2, noise = 12 },

	-- What one Resupply token gives (fixed, never random).
	Resupply = { pistolAmmo = 6, dressing = 1, bottle = 1 },

	-- Satchel upgrades (workbench) raise these.
	CapBonus = { satchel = 1, ammoPouch = 0.5 },
}
