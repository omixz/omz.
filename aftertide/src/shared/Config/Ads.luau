--!nonstrict
-- Rewarded video ads: the player CHOOSES to watch a short ad and gets a free item they could
-- otherwise buy. Roblox's rules (create.roblox.com > Rewarded video ads):
--   * the reward must be one of this experience's developer products (we reuse the shop ones)
--   * it must NOT be a randomised item (so the Lucky Spin is not offered), and must not hand out
--     currency that unbalances the economy (so no Scrip or Materials)
--   * a clear player action starts the ad, the reward is stated before it, and it is granted the
--     moment the ad finishes (the normal purchase receipt does that)
--   * ads never block progress: every offer here is optional
-- Needs "Rewarded Video > Serving enabled" in the Creator Hub (Monetization > Ads) and an
-- experience that meets Roblox's visitor / compliance requirements; until then no ad is available
-- and the buttons stay hidden.
return {
	Enabled = true,
	-- per offer: which shop product it gives (Config/Commerce), what the player sees
	Offers = {
		secondWind = { product = "SecondWind", title = "Second Wind", gives = "1 Second Wind: get back up once when you're downed", cooldown = 180 },
		ammoCache = { product = "AmmoCache", title = "Ammo Cache", gives = "1 Ammo Cache: refills reserve ammo for both guns in a mission", cooldown = 150 },
		resupply = { product = "Resupply", title = "Resupply Satchel", gives = "1 Resupply: +6 revolver rounds, +1 dressing, +1 bottle", cooldown = 150 },
		pocketRounds = { product = "PocketRounds", title = "Pocket Rounds", gives = "+5 revolver rounds, packed for your next crossing", cooldown = 120 },
		bandage = { product = "Bandage", title = "Bandage Roll", gives = "+1 Field Dressing, packed for your next crossing", cooldown = 120 },
	},
	Order = { "secondWind", "ammoCache", "resupply", "pocketRounds", "bandage" },
	MaxPerHour = 10, -- per player, so ads stay an occasional choice
}
