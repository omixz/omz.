--!nonstrict
-- Global tuning for a Crossing. Everything a designer may want to change lives in Config/.
local Game = {
	MaxPartySize = 4, -- per server; also set "Server size" to this in Creator Hub (docs/06-publishing.md)
	CratesRequired = 5,
	StartCountdown = 5,
	ResultsDuration = 15,
	MaxHP = 100,
	BleedOutTime = 30,
	ReviveTime = 2.5, -- seconds a teammate holds the revive prompt
	ReviveHP = 40,
	ExtractionRadius = 12,
	BaseEnemies = 5,
	EnemiesPerExtraPlayer = 2,
	MaxEnemies = 13,

	-- Paid / earnable run aids (Second Wind, Resupply). Set false to make the game cosmetics-only.
	RunAidsEnabled = true,
	SecondWindHP = 60,
	StartingTokens = { secondWind = 1, resupply = 1 }, -- new players
	WinReward = { resupply = 1 }, -- every successful crossing
	DailyWinReward = { secondWind = 1 }, -- first successful crossing each UTC day

	FerryOrigin = Vector3.new(0, 0, 700),
}

return Game
