--!nonstrict
-- LARKSPUR STREET: an overgrown suburban street. Weatherboard houses you can enter, yards
-- gone to tall grass, wrecked cars, power poles, a corner store. Warm golden afternoon.
local MapKit = require(script.Parent.MapKit)
local C = MapKit.C
local block, volume = MapKit.block, MapKit.volume

local Map = {
	id = "LarkspurStreet",
	name = "Larkspur Street",
	lighting = { sky = "larkspur", clouds = 0.42, cloudDensity = 0.5, cloudColor = { 250, 238, 222 }, wind = { 5, 0, 2 }, clock = 16.3, brightness = 3.1, ambient = { 100, 94, 88 }, outdoor = { 160, 150, 136 }, fog = 0.22, haze = 0.9, fogColor = { 218, 208, 190 }, tint = { 255, 244, 230 }, saturation = -0.04, contrast = 0.1, shift = { 255, 226, 190 } },
}

local PHARMACY = { 62, 66, 106, 100 }

function Map.build(parent, rng)
	local M = Enum.Material
	MapKit.outskirts("suburb")
	MapKit.barricade(parent, rng, 13)
	MapKit.slab(-120, -120, 120, 120, M.Grass, 0)
	MapKit.slab(-120, -9, 120, 9, M.Asphalt, 0.05)
	MapKit.slab(-120, 9, 120, 13, M.Pavement, 0.15)
	MapKit.slab(-120, -13, 120, -9, M.Pavement, 0.15)
	-- painted road line (faded)
	for x = -115, 115, 12 do
		block(parent, Vector3.new(5, 0.05, 0.4), Vector3.new(x, 0.1, 0), Color3.fromRGB(200, 190, 150), M.SmoothPlastic, { CanCollide = false, Transparency = 0.35 })
	end

	local doorways, containers, loot = {}, {}, {}
	local function addHouse(origin, yaw, style)
		local h = MapKit.house(parent, origin, yaw, rng, style)
		for _, d in h.doorways do
			table.insert(doorways, d)
		end
		for _, c in h.containers do
			table.insert(containers, c)
		end
		for _, l in h.loot do
			table.insert(loot, l)
		end
		-- driveway
		local side = origin.Z > 0 and 1 or -1
		MapKit.slab(origin.X + 8, side > 0 and 13 or origin.Z, origin.X + 14, side > 0 and origin.Z or -13, M.Concrete, 0.12)
	end
	for _, x in { -82, -32, 18, 68 } do
		addHouse(Vector3.new(x, 0, 24), 0)
		addHouse(Vector3.new(x + 6, 0, -24), math.pi)
	end
	-- corner store at the west end
	addHouse(Vector3.new(-100, 0, 64), 0, { w = 30, d = 26, h = 12, color = Color3.fromRGB(150, 120, 100) })

	-- back fences and yards gone wild
	for _, z in { 58, -58 } do
		for x = -115, 115, 8 do
			if rng:NextNumber() > 0.15 and not (z > 0 and x > 64 and x < 84) then -- gap to the pharmacy
				block(parent, Vector3.new(7.6, 5, 0.3), CFrame.new(x, 2.5, z) * CFrame.Angles(0, 0, rng:NextNumber(-0.06, 0.06)), Color3.fromRGB(120, 100, 80), M.WoodPlanks)
			end
		end
	end
	for _, z in { 80, -80 } do
		MapKit.tallGrass(parent, Vector3.new(-60, 0, z), Vector3.new(60, 0, 30), rng, nil, 0.8)
		MapKit.tallGrass(parent, Vector3.new(z > 0 and 25 or 55, 0, z), Vector3.new(z > 0 and 50 or 70, 0, 30), rng, nil, 0.8)
	end
	for _, x in { -57, -7, 43, 93 } do
		MapKit.tallGrass(parent, Vector3.new(x, 0, 36), Vector3.new(10, 0, 18), rng)
		MapKit.tallGrass(parent, Vector3.new(x + 4, 0, -36), Vector3.new(10, 0, 18), rng)
	end
	MapKit.shortGrass(parent, Vector3.new(0, 0, 30), Vector3.new(230, 0, 30), 120, rng)
	MapKit.shortGrass(parent, Vector3.new(0, 0, -30), Vector3.new(230, 0, 30), 120, rng)

	-- trees and bushes
	for _ = 1, 22 do
		local x, z = rng:NextNumber(-115, 115), (rng:NextNumber() < 0.5 and 1 or -1) * rng:NextNumber(62, 112)
		if MapKit.inside(PHARMACY, Vector3.new(x, 0, z), 6) then
			continue
		end
		MapKit.prop(parent, rng:NextNumber() < 0.6 and "Pine_1" or "DeadTree_1", CFrame.new(x, 0, z) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), rng:NextNumber(0.55, 0.85))
	end
	for _ = 1, 26 do
		local x, z = rng:NextNumber(-115, 115), (rng:NextNumber() < 0.5 and 1 or -1) * rng:NextNumber(14, 56)
		MapKit.prop(parent, "Bush_" .. rng:NextInteger(1, 2), CFrame.new(x, 0, z) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), rng:NextNumber(0.8, 1.3))
	end

	-- the street: wrecks, barricade, power poles with sagging wires
	for i, spec in { { -70, 3, 0.2 }, { -40, -4, 2.9 }, { -5, 2, 1.4 }, { 30, -3, 0.1 }, { 58, 5, 2.3 }, { 92, -2, 1.0 } } do
		MapKit.prop(parent, ({ "CarSedan_1", "CarSedan_2", "CarVan_1" })[(i - 1) % 3 + 1], CFrame.new(spec[1], 0, spec[2]) * CFrame.Angles(0, spec[3], 0))
	end
	MapKit.prop(parent, "Rubble_1", CFrame.new(-100, 0, -2) * CFrame.Angles(0, 0.5, 0), 1.2)
	for x = -110, 110, 36 do
		block(parent, Vector3.new(0.8, 18, 0.8), Vector3.new(x, 9, 15), Color3.fromRGB(86, 70, 54), M.Wood)
		block(parent, Vector3.new(6, 0.4, 0.4), Vector3.new(x, 16.5, 15), Color3.fromRGB(86, 70, 54), M.Wood)
		if x + 36 <= 110 then
			for _, dz in { -2.5, 2.5 } do
				block(parent, Vector3.new(36, 0.08, 0.08), CFrame.new(x + 18, 15.4, 15 + dz * 0.2) * CFrame.Angles(0, 0, 0), Color3.fromRGB(20, 20, 20), M.SmoothPlastic, { CanCollide = false, CanQuery = false })
			end
		end
	end
	for _ = 1, 10 do
		MapKit.prop(parent, "Barrel_1", CFrame.new(rng:NextNumber(-110, 110), 0, rng:NextNumber(-12, 12)), 0.85)
	end
	MapKit.lamp(parent, Vector3.new(-60, 0, 12), false)
	MapKit.lamp(parent, Vector3.new(40, 0, -12), false)
	local pharmacy = MapKit.building(parent, PHARMACY, 0.1, rng, { color = Color3.fromRGB(150, 128, 110), inner = Color3.fromRGB(196, 190, 176), material = Enum.Material.Brick })
	for _, d in pharmacy.doorways do
		table.insert(doorways, d)
	end
	for _, c in pharmacy.containers do
		table.insert(containers, c)
	end
	for _, l in pharmacy.loot do
		table.insert(loot, l)
	end

	return {
		StartSpawns = { Vector3.new(108, 3, -3), Vector3.new(108, 3, 3), Vector3.new(104, 3, -6), Vector3.new(104, 3, 6) },
		ExtractionPos = Vector3.new(-108, 0, 0),
		LanternPos = Vector3.new(0, 0, 0),
		SupplyCandidates = { loot[1], loot[4], loot[7], loot[10], loot[13], loot[16], loot[19], loot[22], Vector3.new(-40, 0, 85), Vector3.new(60, 0, -85) },
		LootSpots = loot,
		ContainerSpots = containers,
		EdgeSpawns = {
			Vector3.new(-110, 0, 100), Vector3.new(110, 0, 100), Vector3.new(110, 0, -100), Vector3.new(-110, 0, -100),
			Vector3.new(0, 0, 110), Vector3.new(0, 0, -110), Vector3.new(-60, 0, 108), Vector3.new(60, 0, -108),
		},
		PatrolRoutes = {
			{ Vector3.new(-90, 0, 0), Vector3.new(90, 0, 0) },
			{ Vector3.new(-90, 0, 75), Vector3.new(0, 0, 70), Vector3.new(84, 0, 60), Vector3.new(84, 0, 84) },
			{ Vector3.new(-90, 0, -75), Vector3.new(0, 0, -70), Vector3.new(90, 0, -80) },
			{ Vector3.new(-30, 0, 34), Vector3.new(20, 0, 34), Vector3.new(70, 0, 34) },
			{ Vector3.new(-26, 0, -34), Vector3.new(24, 0, -34), Vector3.new(74, 0, -34) },
			{ Vector3.new(-100, 0, 76), Vector3.new(-100, 0, 30) },
		},
		Doorways = doorways,
	}
end

return Map
