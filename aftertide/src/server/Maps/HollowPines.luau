--!nonstrict
-- HOLLOW PINES: forest hills above the coast. Pines, rocks, ferns, a creek, meadows of tall
-- grass, three cabins and an old ranger lookout. Misty morning.
local MapKit = require(script.Parent.MapKit)
local C = MapKit.C
local block = MapKit.block

local Map = {
	id = "HollowPines",
	name = "Hollow Pines",
	hilly = true,
	lighting = { clouds = 0.6, cloudDensity = 0.75, cloudColor = { 236, 238, 240 }, wind = { 4, 0, -3 }, clock = 7.9, brightness = 2.5, ambient = { 90, 98, 102 }, outdoor = { 132, 144, 150 }, fog = 0.4, haze = 1.9, fogColor = { 205, 214, 220 }, tint = { 234, 242, 246 }, saturation = -0.12, contrast = 0.1, shift = { 255, 222, 196 } },
}

local function creekX(z)
	return -15 + 26 * math.sin(z / 46)
end

local function baseHeight(x, z)
	local h = math.noise(x / 70, z / 70, 3.1) * 9 + math.noise(x / 28, z / 28, 7.7) * 3.5
	h += math.max(0, (math.abs(x) - 70) / 50) * 8 + math.max(0, (math.abs(z) - 80) / 40) * 6 -- rising edges
	local dc = x - creekX(z)
	h -= 3.2 * math.exp(-(dc / 7) ^ 2)
	return h + 6
end

function Map.build(parent, rng)
	local M = Enum.Material
	MapKit.heightfield(-120, -120, 120, 120, 6, baseHeight, function(x, z, h)
		local slope = math.abs(baseHeight(x + 6, z) - h) + math.abs(baseHeight(x, z + 6) - h)
		if slope > 5 then
			return M.Rock
		elseif math.abs(x - creekX(z)) < 6 then
			return M.Mud
		end
		return (math.noise(x / 30, z / 30, 1) > 0.25) and M.LeafyGrass or M.Grass
	end)
	-- creek water
	for z = -120, 114, 6 do
		local cx = creekX(z + 3)
		local surface = baseHeight(cx, z + 3) + 0.9
		MapKit.water(cx - 6, z, cx + 6, z + 6, surface, 2.2)
	end
	local function g(x, z)
		return MapKit.ground(x, z)
	end

	-- flatten pads and build cabins
	local doorways, containers, loot = {}, {}, {}
	for _, spot in { Vector3.new(55, 0, 40), Vector3.new(-70, 0, -30), Vector3.new(40, 0, -70) } do
		local y = baseHeight(spot.X, spot.Z + 9)
		-- every cabin faces -Z so it sits on the pad flattened for it
		MapKit.clearAbove(spot.X - 16, spot.Z - 12, spot.X + 16, spot.Z + 26, y)
		MapKit.slab(spot.X - 16, spot.Z - 12, spot.X + 16, spot.Z + 26, M.Ground, y, 16)
		local h = MapKit.house(parent, Vector3.new(spot.X, y, spot.Z), 0, rng, { w = 18, d = 16, h = 9, color = Color3.fromRGB(110, 84, 62) })
		for _, d in h.doorways do
			table.insert(doorways, d)
		end
		for _, c in h.containers do
			table.insert(containers, c)
		end
		for _, l in h.loot do
			table.insert(loot, l)
		end
	end

	-- the ranger lookout
	local ly = g(0, 10)
	for _, o in { Vector3.new(-4, 0, -4), Vector3.new(4, 0, -4), Vector3.new(-4, 0, 4), Vector3.new(4, 0, 4) } do
		block(parent, Vector3.new(0.8, 24, 0.8), Vector3.new(o.X, ly + 12, o.Z + 10), Color3.fromRGB(92, 74, 56), M.Wood)
	end
	block(parent, Vector3.new(12, 0.8, 12), Vector3.new(0, ly + 24, 10), Color3.fromRGB(100, 82, 62), M.WoodPlanks)
	block(parent, Vector3.new(12, 7, 12), Vector3.new(0, ly + 28, 10), Color3.fromRGB(110, 90, 70), M.WoodPlanks, { Transparency = 0 })
	MapKit.wedge(parent, Vector3.new(13, 3, 6.5), CFrame.new(0, ly + 33, 6.75), C.roof, M.RoofShingles)
	MapKit.wedge(parent, Vector3.new(13, 3, 6.5), CFrame.new(0, ly + 33, 13.25) * CFrame.Angles(0, math.pi, 0), C.roof, M.RoofShingles)

	-- forest
	local function clear(x, z)
		if math.abs(x - creekX(z)) < 9 then
			return false
		end
		for _, spot in { Vector3.new(55, 0, 48), Vector3.new(-70, 0, -22), Vector3.new(40, 0, -62), Vector3.new(0, 0, 10) } do
			if (Vector3.new(x, 0, z) - spot).Magnitude < 24 then
				return false
			end
		end
		return true
	end
	local placed = 0
	while placed < 70 do
		local x, z = rng:NextNumber(-115, 115), rng:NextNumber(-115, 115)
		if clear(x, z) and not (z > 70 and x < -20) then -- keep the south-west meadow open
			MapKit.prop(parent, rng:NextNumber() < 0.85 and ("Pine_" .. rng:NextInteger(1, 2)) or "DeadTree_1", CFrame.new(x, g(x, z) - 0.5, z) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), rng:NextNumber(0.75, 1.15))
			placed += 1
		end
	end
	for _ = 1, 22 do
		local x, z = rng:NextNumber(-115, 115), rng:NextNumber(-115, 115)
		if clear(x, z) then
			MapKit.prop(parent, rng:NextNumber() < 0.2 and "Boulder_1" or ("Rock_" .. rng:NextInteger(1, 2)), CFrame.new(x, g(x, z) - 0.6, z) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), rng:NextNumber(0.7, 1.2))
		end
	end
	for _ = 1, 30 do
		local x, z = rng:NextNumber(-115, 115), rng:NextNumber(-115, 115)
		if clear(x, z) then
			MapKit.prop(parent, "Bush_" .. rng:NextInteger(1, 2), CFrame.new(x, g(x, z), z) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), rng:NextNumber(0.8, 1.4))
		end
	end
	-- fallen logs
	for _ = 1, 6 do
		local x, z = rng:NextNumber(-100, 100), rng:NextNumber(-100, 100)
		if clear(x, z) then
			MapKit.prop(parent, "DeadTree_1", CFrame.new(x, g(x, z) + 0.6, z) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0) * CFrame.Angles(0, 0, math.rad(88)), 0.55)
		end
	end
	MapKit.tallGrass(parent, Vector3.new(-60, 0, 90), Vector3.new(60, 0, 40), rng, g)
	MapKit.tallGrass(parent, Vector3.new(80, 0, -20), Vector3.new(26, 0, 40), rng, g)
	MapKit.tallGrass(parent, Vector3.new(-30, 0, 20), Vector3.new(24, 0, 30), rng, g)
	MapKit.tallGrass(parent, Vector3.new(10, 0, -100), Vector3.new(50, 0, 20), rng, g)
	MapKit.shortGrass(parent, Vector3.new(0, 0, 0), Vector3.new(230, 0, 230), 260, rng, g, true)
	for _, f in { { Vector3.new(-15, 6, 0), Vector3.new(40, 0, 220) }, { Vector3.new(60, 8, 60), Vector3.new(80, 0, 80) }, { Vector3.new(-60, 8, -60), Vector3.new(80, 0, 80) } } do
		MapKit.fog(parent, f[1], f[2])
	end

	return {
		StartSpawns = { Vector3.new(-62, 0, 100), Vector3.new(-58, 0, 102), Vector3.new(-54, 0, 100), Vector3.new(-66, 0, 102) },
		ExtractionPos = Vector3.new(70, 0, -104),
		LanternPos = Vector3.new(0, 0, 32),
		SupplyCandidates = { loot[1], loot[2], loot[4], loot[5], loot[7], loot[8], Vector3.new(-20, 0, -40), Vector3.new(90, 0, 10), Vector3.new(-95, 0, 40), Vector3.new(20, 0, 80) },
		LootSpots = {
			loot[3], loot[6], loot[9], Vector3.new(-40, 0, 60), Vector3.new(-10, 0, 40), Vector3.new(30, 0, 20), Vector3.new(70, 0, 0),
			Vector3.new(-80, 0, 0), Vector3.new(-50, 0, -70), Vector3.new(0, 0, -60), Vector3.new(60, 0, -90), Vector3.new(90, 0, 60),
			Vector3.new(-90, 0, 70), Vector3.new(20, 0, 100), Vector3.new(-30, 0, -100), Vector3.new(100, 0, -40),
		},
		ContainerSpots = containers,
		EdgeSpawns = {
			Vector3.new(-105, 0, -105), Vector3.new(105, 0, -105), Vector3.new(105, 0, 105), Vector3.new(-20, 0, -110),
			Vector3.new(110, 0, 0), Vector3.new(-110, 0, 0), Vector3.new(40, 0, 110), Vector3.new(-110, 0, -60),
		},
		PatrolRoutes = {
			{ Vector3.new(-60, 0, 60), Vector3.new(-20, 0, 30), Vector3.new(20, 0, 60) },
			{ Vector3.new(40, 0, 20), Vector3.new(80, 0, 20), Vector3.new(60, 0, -30) },
			{ Vector3.new(-80, 0, -60), Vector3.new(-40, 0, -20), Vector3.new(-90, 0, 10) },
			{ Vector3.new(0, 0, -40), Vector3.new(40, 0, -90), Vector3.new(-30, 0, -80) },
			{ Vector3.new(creekX(-60), 0, -60), Vector3.new(creekX(0), 0, 0), Vector3.new(creekX(60), 0, 60) },
			{ Vector3.new(80, 0, -80), Vector3.new(100, 0, 40) },
		},
		Doorways = doorways,
	}
end

return Map
