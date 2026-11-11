--!nonstrict
-- The Hushed. Only the Drifter exists in Slice 0; other types (Lantern-eye, Bellwether,
-- Tidewalker, Mire) arrive in Stage 6.
return {
	TickRate = 10, -- brain updates per second

	Drifter = {
		patrolSpeed = 5.5,
		investigateSpeed = 9,
		chaseSpeed = 16.5, -- slower than a sprint (20), so you CAN break away, loudly
		sightRange = 70,
		fovDeg = 110,
		closeRange = 9, -- inside this, sight builds suspicion much faster
		suspicionGain = 1.1,
		suspicionDecay = 0.18,
		noticeThreshold = 0.15, -- stops and stares
		investigateThreshold = 0.35,
		alertThreshold = 1,
		loseSightTime = 4,
		searchTime = 10,
		grabRange = 3.6,
		grabDamage = 34,
		grabRecover = 2.2,
	},
}
