--!nonstrict
-- The Quartermaster: the Meridian's store, paid with Scrip (earned at the end of every mission).
-- Separate from Meridian projects (Materials). Nothing here is sold for Robux.
--   Guns: permanent unlocks. Everyone starts with only the Service Revolver.
--   Kits: supplies delivered at the start of your NEXT crossing (up to 2 of each).
-- The Armory project takes 15% off.
return {
	Guns = {
		{ id = "carbine", price = 150, desc = "Lever carbine: steady, mid-range, 6 rounds." },
		{ id = "bow", price = 180, desc = "Recurve bow: silent; arrows can be recovered and crafted." },
		{ id = "shotgun", price = 220, desc = "Pump shotgun: devastating up close, 4 shells, reload shell by shell." },
		{ id = "rifle", price = 300, desc = "Bolt rifle: long range and powerful, 4 rounds; takes a scope at the workbench." },
	},
	Kits = {
		{ id = "rounds", name = "Spare rounds", desc = "+4 revolver rounds", price = 20, items = { pistolAmmo = 4 } },
		{ id = "longrounds", name = "Long-gun ammunition", desc = "+3 rifle rounds, +2 shells, +3 arrows", price = 35, items = { rifleAmmo = 3, shells = 2, arrows = 3 } },
		{ id = "medkit", name = "Field kit", desc = "+1 Field Dressing, +1 Cloth", price = 30, items = { dressing = 1, cloth = 1 } },
		-- Robux only (Ammo Crate products); not listed at the Quartermaster
		{ id = "ammocrate", robux = true, name = "Ammo Crate", desc = "+8 revolver rounds, +4 rifle rounds, +4 shells, +6 arrows", price = 0, items = { pistolAmmo = 8, rifleAmmo = 4, shells = 4, arrows = 6 } },
		{ id = "throwables", name = "Throwables", desc = "+1 Bottle, +1 Flare Pot", price = 35, items = { bottle = 1, flarePot = 1 } },
	},
	MaxKitsEach = 2,
	BackpackSlots = 1, -- +1 with the Armory project
}
