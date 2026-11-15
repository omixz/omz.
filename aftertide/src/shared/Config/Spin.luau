--!nonstrict
-- The Lucky Spin (Meridian deck and the HUD).
--   * One FREE spin every day (resets at 00:00 UTC).
--   * Extra spins are Spin tokens: bought for Robux (LuckySpin products) or won on the wheel.
--   * The odds below are shown to players in the Spin screen BEFORE they spin or buy, as
--     Roblox's paid random items policy requires. Where PolicyService says paid random items
--     are restricted for a player, spin tokens are not sold to them (the free daily spin stays).
-- weights add up to 1000, so the odds read as exact percentages with one decimal.
return {
	Prizes = {
		{ id = "scrip40", name = "40 Scrip", short = "40", icon = "S", weight = 250, color = { 214, 176, 92 }, grant = { scrip = 40 } },
		{ id = "mat25", name = "25 Materials", short = "25", icon = "M", weight = 160, color = { 120, 170, 210 }, grant = { materials = 25 } },
		{ id = "rounds", name = "Revolver ammo (next crossing)", short = "AMMO", icon = "A", weight = 140, color = { 230, 120, 80 }, grant = { kit = { rounds = 1 } } },
		{ id = "scrip100", name = "100 Scrip", short = "100", icon = "S", weight = 130, color = { 240, 200, 90 }, grant = { scrip = 100 } },
		{ id = "longrounds", name = "Rifle, shell & arrow ammo (next crossing)", short = "AMMO+", icon = "A", weight = 90, color = { 240, 140, 70 }, grant = { kit = { longrounds = 1 } } },
		{ id = "mat60", name = "60 Materials", short = "60", icon = "M", weight = 70, color = { 100, 190, 240 }, grant = { materials = 60 } },
		{ id = "ammo", name = "Ammo Cache token", short = "CACHE", icon = "C", weight = 60, color = { 250, 110, 90 }, grant = { tokens = { ammo = 1 } } },
		{ id = "spin", name = "Free re-spin", short = "AGAIN", icon = "R", weight = 40, color = { 170, 130, 240 }, grant = { tokens = { spin = 1 } } },
		{ id = "secondWind", name = "Second Wind token", short = "LIFE", icon = "W", weight = 30, color = { 120, 220, 140 }, grant = { tokens = { secondWind = 1 } } },
		{ id = "build", name = "Shipwright's Crew token", short = "BUILD", icon = "B", weight = 15, color = { 90, 210, 200 }, grant = { tokens = { build = 1 } } },
		{ id = "gun", name = "A new gun (unlocks a locked long gun)", short = "GUN!", icon = "G", weight = 10, color = { 255, 120, 60 }, grant = { gun = true } },
		{ id = "jackpot", name = "JACKPOT: 500 Scrip", short = "500!", icon = "J", weight = 5, color = { 255, 214, 60 }, grant = { scrip = 500 } },
	},
	-- products in Config/Commerce: LuckySpin (1 spin), LuckySpin5 (5 spins)
	MaxKitStack = 4, -- kits won on the wheel stack up to this many per kit type
}
