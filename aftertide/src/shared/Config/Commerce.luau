--!nonstrict
-- Developer products. Create each one in Creator Hub > your experience > Monetization >
-- Developer Products, then paste its ID below (docs/06-publishing.md, step 5).
-- An ID of 0 means "not configured": the shop shows the item but will not prompt a purchase.
--
-- `price` is only a fallback label: the shop always shows the live price Roblox reports.
-- Rules (docs/03-monetisation.md): fixed contents, never random; Second Wind max once per
-- crossing; every aid can also be earned free by playing.
return {
	Products = {
		SecondWind = {
			productId = 0,
			name = "Second Wind",
			price = 49,
			desc = "Get back up once when you're downed. Max one per crossing.",
			grant = { secondWind = 1 },
		},
		SecondWind3 = {
			productId = 0,
			name = "Second Wind x3",
			price = 129,
			desc = "Three Second Wind tokens. Same limit: one per crossing.",
			grant = { secondWind = 3 },
		},
		Resupply = {
			productId = 0,
			name = "Resupply Satchel",
			price = 29,
			desc = "+4 Salt Shot, +1 Bottle, +1 Bandage, once per crossing.",
			grant = { resupply = 1 },
		},
	},
	Order = { "SecondWind", "SecondWind3", "Resupply" },
}
