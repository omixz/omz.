--!nonstrict
-- The Hushed: people taken by the Pall, in stages. Original designs (salt-crusted, faceless,
-- never gory: they burst into salt). Bodies are built in code from jointed parts and
-- animated procedurally on clients (EnemyService builds, EnemyAnimator animates).
--
-- Senses: sightRange 0 = blind. hearingMult scales how far they hear every noise
-- (footsteps, gunshots, thrown bottles, explosions, doors). `rushToNoise` = sprints at sounds.
local Drifter = {
	hp = 100, scale = 1, color = Color3.fromRGB(206, 201, 189),
	patrolSpeed = 5.5, investigateSpeed = 9, chaseSpeed = 16.5,
	sightRange = 70, fovDeg = 110, closeRange = 9, hearingMult = 1,
	suspicionGain = 1.1, suspicionDecay = 0.18,
	noticeThreshold = 0.15, investigateThreshold = 0.35, alertThreshold = 1,
	loseSightTime = 4, searchTime = 10,
	grabRange = 3.6, grabDamage = 34, grabRecover = 2.2,
	staggerTime = 0.3, shoveable = true, quietable = true, headMultScale = 1,
	salvage = 2,
	-- body: proportions + look (see EnemyService.buildModel)
	body = { torso = 1, arms = 1, legs = 1, hunch = 8, head = "round", crust = 5, rags = 3 },
	gait = "shamble",
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
		-- Stage 1: freshly taken. Fast, twitchy, still sees well. Comes in groups.
		Rusher = variant({
			hp = 70, scale = 0.95, color = Color3.fromRGB(176, 160, 146),
			patrolSpeed = 7, investigateSpeed = 15, chaseSpeed = 19, rushToNoise = true,
			sightRange = 80, suspicionGain = 1.6, hearingMult = 1.2,
			grabDamage = 26, grabRecover = 1.8, salvage = 2,
			body = { torso = 0.9, arms = 1, legs = 1.05, hunch = 18, head = "half", crust = 2, rags = 5 },
			gait = "rush",
		}),
		-- Stage 2: the drifting majority. Slow, half-blind in fog.
		Drifter = Drifter,
		-- Stage 3: sealed in salt, completely blind. Hears everything. Deadly up close.
		Seeker = variant({
			hp = 130, scale = 1.05, color = Color3.fromRGB(222, 218, 206),
			patrolSpeed = 4, investigateSpeed = 13, chaseSpeed = 15, rushToNoise = true,
			sightRange = 0, closeRange = 3, hearingMult = 1.9,
			grabRange = 3.4, grabDamage = 65, grabRecover = 2.6,
			shoveable = false, headMultScale = 0.8, salvage = 5,
			body = { torso = 1, arms = 1.2, legs = 1, hunch = 4, head = "shell", crust = 9, rags = 1 },
			gait = "feel",
		}),
		-- Calls the others: a low hum that alerts every Hushed in range.
		Bellwether = variant({
			hp = 120, scale = 1.08, color = Color3.fromRGB(176, 182, 178),
			hum = { radius = 85, cooldown = 8 }, chaseSpeed = 15, salvage = 4,
			body = { torso = 1, arms = 1.1, legs = 1.05, hunch = 2, head = "disc", crust = 6, rags = 2 },
		}),
		-- The last stage: a walking salt reef. Can't be shoved or Quieted.
		Tidewalker = variant({
			hp = 700, scale = 1.45, color = Color3.fromRGB(150, 146, 136),
			patrolSpeed = 4.5, investigateSpeed = 7, chaseSpeed = 12.5,
			sightRange = 55, grabRange = 5, grabDamage = 60, grabRecover = 2.8, hearingMult = 1.3,
			staggerTime = 0.08, shoveable = false, quietable = false, headMultScale = 0.6,
			salvage = 25,
			body = { torso = 1.45, arms = 1.25, legs = 1.1, hunch = 20, head = "sunk", crust = 16, rags = 0 },
			gait = "heavy",
		}),
	},
}
