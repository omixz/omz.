--!nonstrict
-- The Hushed. Drifter (baseline), Bellwether (alerts others with a hum), Tidewalker (tank).
-- scale = model size multiplier; headMultScale scales headshot bonus.
local Drifter = {
	hp = 100, scale = 1, color = Color3.fromRGB(206, 201, 189),
	patrolSpeed = 5.5, investigateSpeed = 9, chaseSpeed = 16.5,
	sightRange = 70, fovDeg = 110, closeRange = 9,
	suspicionGain = 1.1, suspicionDecay = 0.18,
	noticeThreshold = 0.15, investigateThreshold = 0.35, alertThreshold = 1,
	loseSightTime = 4, searchTime = 10,
	grabRange = 3.6, grabDamage = 34, grabRecover = 2.2,
	staggerTime = 0.3, shoveable = true, quietable = true, headMultScale = 1,
	salvage = 2,
}

local function variant(overrides)
	local t = table.clone(Drifter)
	for k, v in overrides do
		t[k] = v
	end
	return t
end

return {
	TickRate = 10,
	Types = {
		Drifter = Drifter,
		Bellwether = variant({
			hp = 120, scale = 1.08, color = Color3.fromRGB(176, 182, 178),
			hum = { radius = 85, cooldown = 8 }, chaseSpeed = 15, salvage = 4,
		}),
		Tidewalker = variant({
			hp = 700, scale = 1.45, color = Color3.fromRGB(150, 146, 136),
			patrolSpeed = 4.5, investigateSpeed = 7, chaseSpeed = 12.5,
			sightRange = 55, grabRange = 5, grabDamage = 60, grabRecover = 2.8,
			staggerTime = 0.08, shoveable = false, quietable = false, headMultScale = 0.6,
			salvage = 25,
		}),
	},
}
