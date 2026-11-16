--!nonstrict
-- OLD TOWN MARKET: a cobbled square with a fountain and a clock tower, ringed by tall shops,
-- flats and a chapel, market stalls under awnings, bunting between the roofs and narrow alleys.
-- Sunny afternoon.
local MapKit = require(script.Parent.MapKit)
local Gen = require(script.Parent.MapGen)
local V, rgb = Vector3.new, Gen.rgb
local block = MapKit.block

local Map = {
	id = "OldTownMarket",
	name = "Old Town Market",
	lighting = { sky = "ferry", clouds = 0.3, cloudDensity = 0.45, cloudColor = { 255, 255, 252 }, wind = { 4, 0, 2 }, clock = 14.6, brightness = 3.3, ambient = { 116, 112, 106 }, outdoor = { 164, 158, 148 }, fog = 0.14, haze = 0.6, fogColor = { 228, 226, 214 }, tint = { 255, 246, 232 }, saturation = 0.22, contrast = 0.1, shift = { 255, 226, 190 } },
}

local COLORS = { rgb(214, 70, 60), rgb(240, 190, 60), rgb(70, 150, 200), rgb(110, 180, 110), rgb(180, 100, 190), rgb(240, 140, 60) }

local function stall(gen, x, z, yaw, color)
	local y = gen.flatY
	local cf = CFrame.new(x, y, z) * CFrame.Angles(0, yaw, 0)
	local M = Enum.Material
	block(gen.parent, V(6.4, 3, 2.4), cf * CFrame.new(0, 1.5, 0), rgb(150, 104, 66), M.WoodPlanks)
	for k = 0, 5 do
		block(gen.parent, V(1.1, 0.4, 4.6), cf * CFrame.new(-2.75 + k * 1.1, 7.2, -0.6) * CFrame.Angles(0.3, 0, 0), k % 2 == 0 and color or rgb(250, 248, 240), M.Fabric, { CanCollide = false })
	end
	for _, px in { -3, 3 } do
		block(gen.parent, V(0.3, 7, 0.3), cf * CFrame.new(px, 3.5, -2.2), rgb(110, 76, 50), M.Wood)
	end
	-- goods on the counter: crates of colourful fruit
	for k = -1, 1 do
		block(gen.parent, V(1.5, 0.9, 1.5), cf * CFrame.new(k * 2, 3.4, 0), COLORS[(k + 4) % #COLORS + 1], M.SmoothPlastic, { CanCollide = false })
	end
	gen:zone(x, z, 5)
end

function Map.build(parent, rng)
	local M = Enum.Material
	local gen = Gen.new(parent, rng)
	MapKit.outskirts("suburb")
	MapKit.slab(-120, -120, 120, 120, M.Cobblestone, 0)
	local y = gen:flat()

	-- the square: a paler paved area, a big fountain, a clock tower on the north side
	block(parent, V(80, 0.2, 80), V(0, y + 0.1, 0), rgb(196, 188, 170), M.Pavement, { CanCollide = false })
	block(parent, V(1.4, 20, 20), V(0, y + 0.7, 0), rgb(200, 196, 186), M.Marble, { Shape = Enum.PartType.Cylinder, CFrame = CFrame.new(0, y + 0.7, 0) * CFrame.Angles(0, 0, math.pi / 2) })
	block(parent, V(0.6, 18, 18), V(0, y + 1.3, 0), rgb(70, 150, 190), M.Glass, { Shape = Enum.PartType.Cylinder, CFrame = CFrame.new(0, y + 1.3, 0) * CFrame.Angles(0, 0, math.pi / 2), Transparency = 0.35, CanCollide = false })
	for i = 1, 3 do
		block(parent, V(2.4, 9 - i * 2.2, 9 - i * 2.2), V(0, y + 1.5 + i * 2.4, 0), rgb(214, 210, 200), M.Marble, { Shape = Enum.PartType.Cylinder, CFrame = CFrame.new(0, y + 1.5 + i * 2.4, 0) * CFrame.Angles(0, 0, math.pi / 2) })
	end
	gen:zone(0, 0, 12)
	local tx, tz = 0, 34
	block(parent, V(9, 30, 9), V(tx, y + 15, tz), rgb(190, 176, 150), M.Brick)
	block(parent, V(10.4, 5, 10.4), V(tx, y + 32.5, tz), rgb(214, 204, 180), M.Brick)
	for _, f in { { 0, -5.3 }, { 0, 5.3 }, { -5.3, 0 }, { 5.3, 0 } } do
		local face = block(parent, V(f[1] == 0 and 4.2 or 0.2, 4.2, f[2] == 0 and 4.2 or 0.2), V(tx + f[1], y + 32.5, tz + f[2]), rgb(250, 248, 238), M.SmoothPlastic, { Shape = Enum.PartType.Cylinder, CanCollide = false })
		face.CFrame = CFrame.new(face.Position) * (f[1] == 0 and CFrame.Angles(math.pi / 2, 0, 0) or CFrame.Angles(0, 0, 0)) * CFrame.Angles(0, 0, 0)
		face.Size = f[1] == 0 and V(0.2, 4.2, 4.2) or V(0.2, 4.2, 4.2)
		face.CFrame = CFrame.new(tx + f[1], y + 32.5, tz + f[2]) * CFrame.Angles(0, f[1] == 0 and math.pi / 2 or 0, 0)
	end
	for i = 1, 4 do
		block(parent, V(11 - i * 2.4, 1.6, 11 - i * 2.4), V(tx, y + 35.8 + i * 1.5, tz), rgb(70, 110, 100), M.Metal)
	end
	gen:zone(tx, tz, 9)
	gen:container(tx + 7, tz - 3, "Locker", 0)

	-- the ring of buildings facing the square (a mix of shops, flats, houses and a chapel)
	local kinds = { "shop", "apartment", "house", "shop", "apartment", "garage" }
	local function row(fixed, along, yaw, skipMiddle)
		for i, t in { -52, -18, 18, 52 } do
			if not (skipMiddle and math.abs(t) == 18) then
				local kind = kinds[(i + math.floor(math.abs(fixed) / 10)) % #kinds + 1]
				local pos = along == "x" and V(t, y, fixed) or V(fixed, y, t)
				gen:house(pos, yaw, { kind = kind, w = 26, d = 22 })
			end
		end
	end
	row(-66, "x", math.pi) -- south side, facing the square (+Z)
	row(66, "x", 0, true) -- north side (front faces -Z); the chapel takes the middle
	row(66, "z", math.pi / 2) -- east side, facing -X
	row(-66, "z", -math.pi / 2) -- west side, facing +X
	gen:house(V(0, y, 68), 0, { kind = "chapel" })

	-- market stalls across the square, bunting overhead, planters and carts
	local n = 0
	for gx = -28, 28, 14 do
		for gz = -28, 28, 14 do
			if (math.abs(gx) > 8 or math.abs(gz) > 8) and not (math.abs(gx) < 12 and gz > 24) then
				n += 1
				stall(gen, gx + rng:NextNumber(-2, 2), gz + rng:NextNumber(-2, 2), rng:NextInteger(0, 3) * math.pi / 2, COLORS[n % #COLORS + 1])
			end
		end
	end
	for _, side in { -1, 1 } do
		gen:lights(V(-60, y + 16, side * 40), V(60, y + 16, side * 40), 18, COLORS[(side + 3) % #COLORS + 1], 2.6)
	end
	for _ = 1, 24 do
		local x, z = gen:open(-108, -108, 108, 108, 3)
		if x then
			block(parent, V(2.2, 2.2, 2.2), V(x, y + 1.1, z), rgb(150, 104, 66), M.WoodPlanks)
			block(parent, V(1.8, 2.2, 1.8), V(x, y + 2.8, z), rgb(60, 140, 60), M.LeafyGrass, { Shape = Enum.PartType.Ball, CanCollide = false })
			gen:zone(x, z, 2.5)
		end
	end
	gen:car(-100, 20, 1.57, "CarSedan_2")
	gen:car(100, -30, -1.57, "CarVan_1")
	gen:car(20, -100, 0, "CarSedan_1")
	gen:scatter({ "Barrel_1", "Rubble_1" }, 26, -112, -112, 112, 112, 0.8, 1.1, 0, 3)
	for _, p in { { -40, 0 }, { 40, 0 }, { 0, -40 } } do
		MapKit.lamp(parent, V(p[1], y, p[2]), false)
	end
	MapKit.tallGrass(parent, V(-100, y, -100), V(22, 0, 22), rng, nil, 0.8)
	MapKit.tallGrass(parent, V(100, y, 100), V(22, 0, 22), rng, nil, 0.8)
	gen:fence(rgb(110, 100, 88), 8, 6)

	return gen:finish({
		start = { V(-100, 3, -100), V(-96, 3, -102), V(-104, 3, -96), V(-92, 3, -98) },
		extraction = V(104, 0, 104),
		lantern = V(0, 0, -20),
	})
end

return Map
