--!nonstrict
-- Items, satchel caps and crafting recipes. The satchel is deliberately small: choices matter.
-- Satchel size is NEVER sold (docs/03-monetisation.md).
return {
	Items = {
		shot = { name = "Salt Shot", cap = 12, desc = "Slingshot ammo. Stuns a Hushed, or makes noise where it lands." },
		bottle = { name = "Bottle", cap = 3, throwable = true, desc = "Throw it. The noise pulls Hushed away." },
		bandage = { name = "Bandage", cap = 3, desc = "Heals over a short, interruptible channel." },
		glass = { name = "Glass", cap = 6, part = true },
		cloth = { name = "Cloth", cap = 6, part = true },
		scrap = { name = "Scrap", cap = 6, part = true },
	},
	Order = { "shot", "bottle", "bandage", "glass", "cloth", "scrap" },

	Recipes = {
		bottle = { name = "Bottle", output = "bottle", amount = 1, cost = { glass = 2 } },
		bandage = { name = "Bandage", output = "bandage", amount = 1, cost = { cloth = 2 } },
		shot = { name = "Salt Shot x3", output = "shot", amount = 3, cost = { scrap = 1 } },
	},
	RecipeOrder = { "bottle", "bandage", "shot" },
	CraftTime = 1,

	Bandage = { heal = 35, channel = 1.5 },
	Bottle = { noiseRadius = 45, speed = 75, lift = 16 },
	Slingshot = { range = 140, stun = 3, cooldown = 0.7, impactNoise = 22, hitNoise = 14 },
	Quieting = { range = 4.5, time = 0.9, noise = 6 },
	Shove = { range = 5.5, cooldown = 4, stun = 2.2, noise = 12 },

	-- What one Resupply token gives (fixed, never random).
	Resupply = { shot = 4, bottle = 1, bandage = 1 },

	-- Loot scattered per encounter.
	PartsPerType = 4,
}
