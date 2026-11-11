--!nonstrict
-- CANNERY ROW: a coastal fish cannery, container yard, net shed and tidal shallows.
-- Bright overcast midday. Terrain ground (asphalt yard, concrete, grass verges, mud),
-- real terrain water in the shallows, reeds and tall grass to hide in.
local MapKit = require(script.Parent.MapKit)
local C = MapKit.C
local block, volume = MapKit.block, MapKit.volume

local Map = {
	id = "CanneryRow",
	name = "Cannery Row",
	lighting = { clock = 13.6, brightness = 2.7, ambient = { 92, 98, 104 }, outdoor = { 140, 146, 150 }, fog = 0.3, haze = 1.2, fogColor = { 200, 206, 208 }, tint = { 236, 240, 242 }, saturation = -0.12, contrast = 0.12, shift = { 255, 238, 220 } },
}

function Map.build(parent, rng)
	local M = Enum.Material
	-- terrain base: concrete yard, asphalt lanes, grass verges, mud by the water
	MapKit.slab(-118, -118, 118, 118, M.Concrete, 0)
	MapKit.slab(-12, 14, 118, 30, M.Asphalt, 0.02)
	MapKit.slab(66, -118, 118, 118, M.Asphalt, 0.02)
	MapKit.slab(-70, 30, -10, 118, M.Grass, 0.05)
	MapKit.slab(-70, -118, -30, -40, M.Grass, 0.05)
	MapKit.slab(-75, -118, -64, 118, M.Mud, 0.0)
	-- the shallows: ground dips, terrain water on top
	MapKit.clearAbove(-118, -92, -70, 72, -1.6)
	MapKit.slab(-118, -92, -70, 72, M.Mud, -1.6)
	MapKit.water(-118, -92, -70, 72, 0.3, 1.9)
	volume(parent, Vector3.new(48, 6, 164), Vector3.new(-94, 2, -10), "Shallows")

	-- perimeter wall
	block(parent, Vector3.new(236, 16, 2), Vector3.new(0, 8, -118), C.wallDark, M.Concrete)
	block(parent, Vector3.new(236, 16, 2), Vector3.new(0, 8, 118), C.wallDark, M.Concrete)
	block(parent, Vector3.new(2, 16, 236), Vector3.new(118, 8, 0), C.wallDark, M.Concrete)
	block(parent, Vector3.new(2, 16, 236), Vector3.new(-118, 8, 0), C.wallDark, M.Concrete)

	-- the cannery
	local h = 16
	MapKit.wallX(parent, -50, -10, 60, h, { { 20, 28 } }, C.wall, M.Brick)
	MapKit.wallX(parent, 10, -10, 60, h, { { 5, 13 }, { 40, 48 } }, C.wall, M.Brick)
	MapKit.wallZ(parent, -10, -50, 10, h, { { -24, -16 } }, C.wall, M.Brick)
	MapKit.wallZ(parent, 60, -50, 10, h, { { -30, -22 } }, C.wall, M.Brick)
	block(parent, Vector3.new(72, 1, 62), Vector3.new(25, h + 0.5, -20), C.roof, M.CorrodedMetal)
	for i = 0, 4 do -- skylights let daylight in
		block(parent, Vector3.new(8, 0.3, 10), Vector3.new(4 + i * 15, h + 1.05, -20), Color3.fromRGB(180, 190, 196), M.Glass, { Transparency = 0.5 })
	end
	block(parent, Vector3.new(70, 0.2, 60), Vector3.new(25, 0.1, -20), Color3.fromRGB(80, 80, 78), M.Concrete)
	for _, x in { 5, 14, 34, 46 } do
		block(parent, Vector3.new(6, 4, 16), Vector3.new(x, 2, -20), C.machine, M.Metal)
		block(parent, Vector3.new(2, 2.5, 2), Vector3.new(x, 5.25, -24), C.metal, M.Metal)
	end
	block(parent, Vector3.new(50, 2.5, 2), Vector3.new(25, 1.25, -40), C.machine, M.DiamondPlate)
	for i = 0, 5 do
		block(parent, Vector3.new(70, 0.8, 0.8), CFrame.new(25, 12 + (i % 2) * 1.2, -48 + i * 10), C.metal, M.CorrodedMetal, { Shape = Enum.PartType.Cylinder })
	end
	MapKit.bulb(parent, Vector3.new(24, 13, -20))
	MapKit.bulb(parent, Vector3.new(3, 13, -2))

	-- container yard
	for i, c in {
		{ Vector3.new(78, 0, -85), Vector3.new(8, 8.6, 20) }, { Vector3.new(96, 0, -60), Vector3.new(20, 8.6, 8) },
		{ Vector3.new(78, 0, -35), Vector3.new(8, 8.6, 20) }, { Vector3.new(100, 0, -15), Vector3.new(8, 8.6, 20) },
		{ Vector3.new(80, 0, 10), Vector3.new(20, 8.6, 8) }, { Vector3.new(100, 0, 40), Vector3.new(8, 8.6, 20) },
		{ Vector3.new(78, 0, 60), Vector3.new(8, 8.6, 20) }, { Vector3.new(96, 0, 85), Vector3.new(20, 8.6, 8) },
	} do
		local box = block(parent, c[2], c[1] + Vector3.new(0, 4.3, 0), C.containers[(i - 1) % #C.containers + 1], M.CorrodedMetal)
		-- ribbed sides
		local long = c[2].Z > c[2].X
		for r = -4, 4 do
			local offset = long and Vector3.new(c[2].X / 2 + 0.1, 0, r * 2.1) or Vector3.new(r * 2.1, 0, c[2].Z / 2 + 0.1)
			for _, sgn in { 1, -1 } do
				block(parent, long and Vector3.new(0.2, 8.2, 0.4) or Vector3.new(0.4, 8.2, 0.2), box.Position + Vector3.new(offset.X * (long and sgn or 1), 0, offset.Z * (long and 1 or sgn)), box.Color, M.CorrodedMetal)
			end
		end
	end
	block(parent, Vector3.new(8, 8.6, 20), Vector3.new(78, 12.9, -35), C.containers[4], M.CorrodedMetal)

	-- net shed
	MapKit.wallX(parent, -84, -60, -30, 10, {}, C.wall, M.WoodPlanks)
	MapKit.wallZ(parent, -60, -112, -84, 10, {}, C.wall, M.WoodPlanks)
	MapKit.wallZ(parent, -30, -112, -84, 10, { { -100, -94 } }, C.wall, M.WoodPlanks)
	block(parent, Vector3.new(32, 1, 30), Vector3.new(-45, 10.5, -98), C.roof, M.CorrodedMetal)

	-- tall grass and reeds to hide in
	MapKit.tallGrass(parent, Vector3.new(-66, 0, -60), Vector3.new(10, 0, 30), rng)
	MapKit.tallGrass(parent, Vector3.new(-66, 0, 30), Vector3.new(10, 0, 30), rng)
	MapKit.tallGrass(parent, Vector3.new(-40, 0, 72), Vector3.new(34, 0, 18), rng)
	MapKit.tallGrass(parent, Vector3.new(62, 0, 40), Vector3.new(10, 0, 20), rng)
	MapKit.tallGrass(parent, Vector3.new(-48, 0, -60), Vector3.new(26, 0, 18), rng)
	MapKit.shortGrass(parent, Vector3.new(-40, 0, 74), Vector3.new(60, 0, 80), 90, rng)

	-- cover: crates, low walls, wrecks, barrels, rubble
	for _, pos in {
		Vector3.new(-30, 0, 40), Vector3.new(-20, 0, 55), Vector3.new(10, 0, 42), Vector3.new(25, 0, 60),
		Vector3.new(40, 0, 32), Vector3.new(-45, 0, 8), Vector3.new(-35, 0, -32), Vector3.new(-50, 0, -70),
		Vector3.new(-20, 0, -80), Vector3.new(10, 0, -72), Vector3.new(30, 0, -90), Vector3.new(50, 0, -68),
	} do
		block(parent, Vector3.new(4, 4, 4), pos + Vector3.new(0, 2, 0), C.crate, M.WoodPlanks)
		if rng:NextNumber() < 0.4 then
			block(parent, Vector3.new(3, 3, 3), pos + Vector3.new(0.4, 5.5, -0.3), C.crate, M.WoodPlanks)
		end
	end
	block(parent, Vector3.new(24, 3.5, 1.5), Vector3.new(-20, 1.75, 25), C.wall, M.Concrete)
	block(parent, Vector3.new(1.5, 3.5, 18), Vector3.new(20, 1.75, 30), C.wall, M.Concrete)
	block(parent, Vector3.new(18, 3.5, 1.5), Vector3.new(-40, 1.75, -45), C.wall, M.Concrete)
	MapKit.prop(parent, "CarVan_1", CFrame.new(20, 0, 95) * CFrame.Angles(0, 1.4, 0))
	MapKit.prop(parent, "CarSedan_1", CFrame.new(-10, 0, 22) * CFrame.Angles(0, 0.3, 0))
	MapKit.prop(parent, "CarSedan_2", CFrame.new(88, 0, -100) * CFrame.Angles(0, 2.2, 0))
	for _ = 1, 14 do
		local x, z = rng:NextNumber(-60, 105), rng:NextNumber(-105, 105)
		if not (x > -12 and x < 62 and z > -52 and z < 12) then
			MapKit.prop(parent, "Barrel_1", CFrame.new(x, 0, z) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), 0.9)
		end
	end
	MapKit.prop(parent, "Rubble_1", CFrame.new(-25, 0, -60), 1.4)
	MapKit.prop(parent, "Rubble_1", CFrame.new(55, 0, 100) * CFrame.Angles(0, 2, 0), 1.1)
	MapKit.prop(parent, "Rock_1", CFrame.new(-72, -1.6, -20), 1.2)
	MapKit.prop(parent, "Rock_2", CFrame.new(-100, -1.6, 40) * CFrame.Angles(0, 1, 0), 1)
	MapKit.prop(parent, "DeadTree_1", CFrame.new(-55, 0, 95), 0.8)
	MapKit.prop(parent, "Bush_1", CFrame.new(-30, 0, 100), 1.1)

	-- lamp posts (light pools make you easier to see)
	MapKit.lamp(parent, Vector3.new(0, 0, 70))
	MapKit.lamp(parent, Vector3.new(65, 0, -50))
	MapKit.lamp(parent, Vector3.new(-50, 0, -20))
	MapKit.lamp(parent, Vector3.new(40, 0, 18))
	for _, f in { { Vector3.new(-60, 1, 40), Vector3.new(60, 0, 60) }, { Vector3.new(-90, 1, -10), Vector3.new(40, 0, 160) }, { Vector3.new(85, 1, 0), Vector3.new(40, 0, 200) } } do
		MapKit.fog(parent, f[1], f[2])
	end

	return {
		StartSpawns = { Vector3.new(-6, 3, 100), Vector3.new(-2, 3, 102), Vector3.new(2, 3, 102), Vector3.new(6, 3, 100) },
		ExtractionPos = Vector3.new(-92, 0, -102),
		LanternPos = Vector3.new(5, 0, 55),
		SupplyCandidates = {
			Vector3.new(24, 0, -45), Vector3.new(5, 0, -5), Vector3.new(52, 0, -10), Vector3.new(88, 0, -38), Vector3.new(90, 0, 62),
			Vector3.new(-80, 0, 20), Vector3.new(-45, 0, -100), Vector3.new(-40, 0, 75), Vector3.new(30, 0, 75), Vector3.new(-30, 0, -50),
		},
		LootSpots = {
			Vector3.new(-25, 0, 45), Vector3.new(-15, 0, 60), Vector3.new(15, 0, 50), Vector3.new(35, 0, 65), Vector3.new(45, 0, 25), Vector3.new(-40, 0, 15),
			Vector3.new(-30, 0, -25), Vector3.new(-45, 0, -75), Vector3.new(-15, 0, -85), Vector3.new(15, 0, -80), Vector3.new(35, 0, -95), Vector3.new(55, 0, -75),
			Vector3.new(70, 0, 30), Vector3.new(88, 0, 0), Vector3.new(108, 0, -40), Vector3.new(88, 0, 78), Vector3.new(0, 0, -30), Vector3.new(30, 0, -5),
			Vector3.new(45, 0, -45), Vector3.new(10, 0, -45), Vector3.new(-55, 0, -30), Vector3.new(-60, 0, 50), Vector3.new(-60, 0, 80), Vector3.new(60, 0, 90),
		},
		ContainerSpots = {
			{ pos = Vector3.new(-6, 0, -46), type = "Locker", yaw = 0 }, { pos = Vector3.new(-4, 0, -46), type = "Locker", yaw = 0 },
			{ pos = Vector3.new(56, 0, -46), type = "Toolbox", yaw = 0 }, { pos = Vector3.new(56, 0, 5), type = "Drawer", yaw = 180 },
			{ pos = Vector3.new(-6, 0, 5), type = "Drawer", yaw = 180 }, { pos = Vector3.new(30, 0, -12), type = "AmmoCrate", yaw = 90 },
			{ pos = Vector3.new(90, 0, -50), type = "AmmoCrate", yaw = 0 }, { pos = Vector3.new(108, 0, 20), type = "Toolbox", yaw = -90 },
			{ pos = Vector3.new(86, 0, 70), type = "Locker", yaw = 90 }, { pos = Vector3.new(-56, 0, -88), type = "Drawer", yaw = 0 },
			{ pos = Vector3.new(-34, 0, -108), type = "Toolbox", yaw = 180 }, { pos = Vector3.new(-56, 0, -108), type = "AmmoCrate", yaw = 90 },
			{ pos = Vector3.new(-10, 0, 85), type = "Drawer", yaw = 180 }, { pos = Vector3.new(45, 0, 95), type = "Toolbox", yaw = 180 },
			{ pos = Vector3.new(-40, 0, -40), type = "Locker", yaw = 180 }, { pos = Vector3.new(70, 0, -100), type = "Drawer", yaw = 0 },
		},
		EdgeSpawns = {
			Vector3.new(-60, 0, 108), Vector3.new(100, 0, 100), Vector3.new(105, 0, -100), Vector3.new(0, 0, -105),
			Vector3.new(105, 0, 0), Vector3.new(-50, 0, 108), Vector3.new(60, 0, -105), Vector3.new(-62, 0, -40),
		},
		PatrolRoutes = {
			{ Vector3.new(24, 0, -30), Vector3.new(24, 0, -2), Vector3.new(52, 0, -30), Vector3.new(5, 0, -35) },
			{ Vector3.new(88, 0, -80), Vector3.new(88, 0, -38), Vector3.new(88, 0, 20), Vector3.new(88, 0, 62) },
			{ Vector3.new(-30, 0, 50), Vector3.new(30, 0, 55), Vector3.new(40, 0, 25), Vector3.new(-20, 0, 35) },
			{ Vector3.new(-90, 0, -60), Vector3.new(-90, 0, 40), Vector3.new(-80, 0, 60), Vector3.new(-80, 0, -20) },
			{ Vector3.new(-40, 0, -60), Vector3.new(0, 0, -85), Vector3.new(50, 0, -85), Vector3.new(-20, 0, -70) },
			{ Vector3.new(-45, 0, -10), Vector3.new(-45, 0, 30), Vector3.new(-25, 0, 0) },
		},
		Doorways = {
			{ hinge = Vector3.new(20, 0, -50), width = 8, dir = Vector3.new(1, 0, 0) },
			{ hinge = Vector3.new(5, 0, 10), width = 8, dir = Vector3.new(1, 0, 0) },
			{ hinge = Vector3.new(40, 0, 10), width = 8, dir = Vector3.new(1, 0, 0) },
			{ hinge = Vector3.new(-10, 0, -24), width = 8, dir = Vector3.new(0, 0, 1) },
			{ hinge = Vector3.new(60, 0, -30), width = 8, dir = Vector3.new(0, 0, 1) },
			{ hinge = Vector3.new(-30, 0, -100), width = 6, dir = Vector3.new(0, 0, 1) },
		},
	}
end

return Map
