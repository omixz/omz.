--!nonstrict
-- Everything sold for Robux. Create the products automatically with tools/create_products.py
-- (Open Cloud) or by hand in Creator Hub > your experience > Monetization, then paste the IDs.
-- An ID of 0 means "not configured": the shop shows the item but will not prompt a purchase.
--
-- `price` is the Robux price the creation tool sets; the shop always shows Roblox's live price.
-- Rules (docs/03-monetisation.md): fixed contents, never random; every run aid has a per-crossing
-- or per-encounter limit and can also be earned free by playing; cosmetics never change stats.
--
-- grant kinds:  tokens = { secondWind | resupply | ammo = n }   outfit = "<Cosmetics outfit id>"
--               outfits = { ids }   oneTime = true (can only be bought once per account)
return {
	Products = {
		SecondWind = {
			productId = 0,
			name = "Second Wind",
			price = 49,
			desc = "Get back up once when you're downed. Max one per crossing.",
			grant = { tokens = { secondWind = 1 } },
		},
		SecondWind3 = {
			productId = 0,
			name = "Second Wind x3",
			price = 129,
			desc = "Three Second Wind tokens. Same limit: one per crossing.",
			grant = { tokens = { secondWind = 3 } },
		},
		Resupply = {
			productId = 0,
			name = "Resupply Satchel",
			price = 29,
			desc = "+6 revolver rounds, +1 Field Dressing, +1 Bottle. Once per crossing.",
			grant = { tokens = { resupply = 1 } },
		},
		AmmoCache = {
			productId = 0,
			name = "Ammo Cache",
			price = 25,
			desc = "Refills reserve ammo for both your guns mid-encounter. Once per encounter.",
			grant = { tokens = { ammo = 1 } },
		},
		AmmoCache5 = {
			productId = 0,
			name = "Ammo Cache x5",
			price = 99,
			desc = "Five Ammo Cache tokens. Same limit: one per encounter.",
			grant = { tokens = { ammo = 5 } },
		},
		StarterPack = {
			productId = 0,
			name = "Deckhand Starter Pack",
			price = 99,
			desc = "One time only: 2 Second Wind, 2 Resupply, 3 Ammo Cache and the Deckhand outfit for all four crew.",
			grant = { oneTime = true, tokens = { secondWind = 2, resupply = 2, ammo = 3 }, outfits = { "mara_deckhand", "tobias_deckhand", "ines_deckhand", "sefa_deckhand" } },
		},
		Outfit_mara_pilot = {
			productId = 0,
			name = "Mara: Night Pilot",
			price = 79,
			desc = "Navy oilskin, brass-buttoned cap and a red signal scarf. Cosmetic.",
			grant = { outfit = "mara_pilot" },
		},
		Outfit_tobias_stoker = {
			productId = 0,
			name = "Tobias: Boiler Stoker",
			price = 79,
			desc = "Soot-black overalls, leather apron tones and a welder's cap. Cosmetic.",
			grant = { outfit = "tobias_stoker" },
		},
		Outfit_ines_field = {
			productId = 0,
			name = "Ines: Field Surgeon",
			price = 79,
			desc = "Bone-white coat, slate trousers, red-cross satchel. Cosmetic.",
			grant = { outfit = "ines_field" },
		},
		Outfit_sefa_reef = {
			productId = 0,
			name = "Sefa: Reef Diver",
			price = 79,
			desc = "Kelp-green wetsuit layers and a sun-faded diver's hood. Cosmetic.",
			grant = { outfit = "sefa_reef" },
		},
	},
	-- Supplies tab, top to bottom (outfits are listed in the Wardrobe tab).
	Order = { "StarterPack", "SecondWind", "SecondWind3", "Resupply", "AmmoCache", "AmmoCache5" },

	-- Game passes (permanent). Created by tools/create_products.py like the products above.
	Passes = {
		Supporter = {
			passId = 0,
			name = "Meridian Supporter",
			price = 149,
			desc = "Supporter outfits for every crew member (officer's colours), a Supporter badge on your name and +10% Scrip from crossings. Thank you for keeping the lights on.",
			scripBonus = 0.10,
		},
	},
}
