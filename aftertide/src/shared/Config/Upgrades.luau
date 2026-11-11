--!nonstrict
-- Two kinds of upgrade:
--   * Workbench (per run, paid with Salvage found in the run): weapon parts, satchel, perks.
--   * Meridian repairs (permanent, paid with Scrip earned by playing): the homebase.
-- Neither can be bought with Robux.
local Upgrades = {}

-- mods: damageMult, reloadMult, noiseMult, recoilMult, spreadMult, aimSpreadMult,
--       fireDelayMult, magBonus (+n), aimFovMult
Upgrades.Weapon = {
	revolver = {
		{ id = "loads", name = "Hand-loaded rounds", desc = "+25% damage", cost = 25, mods = { damageMult = 1.25 } },
		{ id = "loader", name = "Speed loader", desc = "Reload 40% faster", cost = 20, mods = { reloadMult = 0.6 } },
		{ id = "baffle", name = "Baffle", desc = "Shots are 60% quieter", cost = 40, mods = { noiseMult = 0.4 } },
		{ id = "grip", name = "Weighted grip", desc = "-40% recoil, tighter spread", cost = 20, mods = { recoilMult = 0.6, spreadMult = 0.75 } },
	},
	carbine = {
		{ id = "tube", name = "Long tube", desc = "+3 rounds per load", cost = 30, mods = { magBonus = 3 } },
		{ id = "lever", name = "Smoothed lever", desc = "Fires 30% faster", cost = 30, mods = { fireDelayMult = 0.7 } },
		{ id = "sights", name = "Peep sights", desc = "Much tighter aim", cost = 20, mods = { aimSpreadMult = 0.4 } },
		{ id = "pad", name = "Recoil pad", desc = "-45% recoil", cost = 15, mods = { recoilMult = 0.55 } },
	},
	rifle = {
		{ id = "scope", name = "Salvaged scope", desc = "Zoomed, pinpoint aim", cost = 35, mods = { aimSpreadMult = 0.1, aimFovMult = 0.6 } },
		{ id = "bolt", name = "Polished bolt", desc = "Cycles 35% faster", cost = 30, mods = { fireDelayMult = 0.65 } },
		{ id = "mag", name = "Extended magazine", desc = "+2 rounds", cost = 25, mods = { magBonus = 2 } },
		{ id = "pad", name = "Stock pad", desc = "-45% recoil", cost = 15, mods = { recoilMult = 0.55 } },
	},
	shotgun = {
		{ id = "choke", name = "Choke", desc = "30% tighter spread", cost = 25, mods = { spreadMult = 0.7, aimSpreadMult = 0.7 } },
		{ id = "tube", name = "Tube extension", desc = "+2 shells", cost = 30, mods = { magBonus = 2 } },
		{ id = "pump", name = "Quick pump", desc = "Fires 25% faster", cost = 25, mods = { fireDelayMult = 0.75 } },
		{ id = "loads", name = "Heavy shot", desc = "+25% damage", cost = 30, mods = { damageMult = 1.25 } },
	},
	bow = {
		{ id = "draw", name = "Heavier draw", desc = "+30% damage", cost = 30, mods = { damageMult = 1.3 } },
		{ id = "nock", name = "Quick nock", desc = "Fires 35% faster", cost = 20, mods = { fireDelayMult = 0.65, reloadMult = 0.65 } },
		{ id = "stab", name = "Stabiliser", desc = "Much tighter aim", cost = 20, mods = { aimSpreadMult = 0.4, spreadMult = 0.7 } },
	},
}

Upgrades.General = {
	{ id = "satchel", name = "Bigger satchel", desc = "+1 capacity for every part, throwable and consumable", cost = 30 },
	{ id = "ammoPouch", name = "Ammo pouch", desc = "+50% ammo capacity", cost = 30 },
	{ id = "holster", name = "Holster rig", desc = "Swap weapons twice as fast", cost = 15 },
}

Upgrades.PerkCost = 30 -- buy each of your character's other perks during a run

Upgrades.Repairs = {
	{ id = "lights", name = "Deck lights", desc = "String the Meridian with lights again. (Cosmetic)", cost = 40 },
	{ id = "generator", name = "Generator", desc = "Start every crossing with +15 Salvage.", cost = 60 },
	{ id = "sickbay", name = "Sick bay", desc = "Start every crossing with an extra Field Dressing.", cost = 80 },
	{ id = "workshop", name = "Workshop tools", desc = "Workbench upgrades cost 15% less.", cost = 100 },
	{ id = "radio", name = "Radio mast", desc = "The tide chart offers 3 routes instead of 2.", cost = 120 },
	{ id = "armory", name = "Armory rack", desc = "Choose any long gun before a crossing.", cost = 150 },
}

return Upgrades
