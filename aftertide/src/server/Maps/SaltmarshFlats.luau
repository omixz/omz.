--!nonstrict
-- SALTMARSH FLATS: tidal mud flats, shallow pools you wade through, long boardwalks on stilts,
-- fishermen's huts, wrecked boats and reed beds to hide in. Grey-green morning fog.
local MapKit = require(script.Parent.MapKit)
local Gen = require(script.Parent.MapGen)
local V, rgb = Vector3.new, Gen.rgb
local block = MapKit.block

local Map = {
	id = "SaltmarshFlats",
	name = "Saltmarsh Flats",
	lighting = { sky = "cannery", clouds = 0.6, cloudDensity = 0.6, cloudColor = { 236, 240, 236 }, wind = { 7, 0, 3 }, clock = 7.6, brightness = 2.7, ambient = { 100, 112, 106 }, outdoor = { 142, 156, 148 }, fog = 0.5, haze = 1.5, fogColor = { 204, 218, 206 }, tint = { 240, 250, 240 }, saturation = 0.1, contrast = 0.08, shift = { 255, 232, 200 } },
}

local function boat(gen, x, z, yaw, color)
	local y = gen:ground(x, z)
	local cf = CFrame.new(x, y, z) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(0, 0, 0.12)
	block(gen.parent, V(14, 2.4, 4.4), cf * CFrame.new(0, 1.2, 0), color, Enum.Material.WoodPlanks)
	MapKit.wedge(gen.parent, V(4.4, 2.4, 3.4), cf * CFrame.new(8.6, 1.2, 0) * CFrame.Angles(0, -math.pi / 2, 0), color, Enum.Material.WoodPlanks)
	block(gen.parent, V(4, 3, 3.4), cf * CFrame.new(-2.5, 3.6, 0), rgb(236, 230, 214), Enum.Material.WoodPlanks)
	block(gen.parent, V(0.4, 9, 0.4), cf * CFrame.new(2, 6, 0), rgb(110, 76, 50), Enum.Material.Wood)
	gen:zone(x, z, 9)
	gen:container(x + 4, z + 3, "Toolbox", 0)
end

function Map.build(parent, rng)
	local M = Enum.Material
	local gen = Gen.new(parent, rng)
	MapKit.outskirts("coast")
	MapKit.slab(-120, -120, 120, 120, M.Mud, 0)
	for _ = 1, 9 do -- low sandbars
		local x, z = rng:NextNumber(-95, 95), rng:NextNumber(-95, 95)
		MapKit.slab(x - 13, z - 9, x + 13, z + 9, M.Sand, 0.05)
	end
	local y = gen:flat()

	-- tidal pools you wade through
	for _ = 1, 8 do
		local x, z = gen:open(-88, -88, 88, 88, 18)
		if x then
			local w, d = rng:NextNumber(16, 28), rng:NextNumber(14, 24)
			MapKit.clearAbove(x - w / 2, z - d / 2, x + w / 2, z + d / 2, y - 2)
			MapKit.slab(x - w / 2, z - d / 2, x + w / 2, z + d / 2, M.Mud, y - 2.2, 4)
			MapKit.water(x - w / 2, z - d / 2, x + w / 2, z + d / 2, y - 0.6, 2.4)
			MapKit.volume(parent, V(w, 6, d), V(x, y, z), "Shallows")
			gen:zone(x, z, math.max(w, d) / 2 + 1)
		end
	end

	-- boardwalks on stilts: east-west and north-south, with rails
	local function boardwalk(a, b)
		local len = (b - a).Magnitude
		local dir = (b - a).Unit
		local mid = (a + b) / 2
		local cf = CFrame.lookAt(mid, mid + dir)
		block(parent, V(5, 0.4, len), cf * CFrame.new(0, 0.6, 0) + V(0, y, 0), rgb(150, 112, 76), M.WoodPlanks)
		for t = 0, len, 8 do
			for _, side in { -2.3, 2.3 } do
				local p = cf * CFrame.new(side, 0, -len / 2 + t)
				block(parent, V(0.4, 3.4, 0.4), p + V(0, y - 0.9, 0), rgb(90, 66, 46), M.Wood)
				block(parent, V(0.3, 0.3, 8), p * CFrame.new(0, 0, 4) + V(0, y + 2, 0), rgb(110, 76, 50), M.Wood, { CanCollide = false })
			end
		end
	end
	boardwalk(V(-110, 0, -20), V(110, 0, -20))
	boardwalk(V(28, 0, -108), V(28, 0, 108))
	boardwalk(V(-70, 0, 20), V(-70, 0, 105))

	-- stilt huts on platforms
	for _, h in { { -48, 48 }, { 62, 42 }, { -36, -72 }, { 70, -66 } } do
		block(parent, V(32, 1, 28), V(h[1], y + 0.5, h[2] + 11), rgb(130, 98, 68), M.WoodPlanks)
		for _, sx in { -14, 14 } do
			for _, sz in { -2, 24 } do
				block(parent, V(0.8, 3, 0.8), V(h[1] + sx, y + 0.5, h[2] + sz), rgb(90, 66, 46), M.Wood)
			end
		end
		gen:house(V(h[1], y + 1, h[2]), 0, { cabin = true })
		MapKit.lamp(parent, V(h[1] + 12, y + 1, h[2] - 5), false)
	end

	-- wrecked fishing boats half sunk in the mud
	boat(gen, -88, -60, 0.6, rgb(70, 130, 170))
	boat(gen, 90, 8, 2.2, rgb(196, 90, 60))
	boat(gen, -10, 70, 1.4, rgb(210, 190, 90))
	boat(gen, 4, -75, 3.4, rgb(90, 150, 110))

	-- the lookout: four legs, a platform, a ladder
	for _, o in { { -3, -3 }, { 3, -3 }, { -3, 3 }, { 3, 3 } } do
		block(parent, V(0.8, 22, 0.8), V(-96 + o[1], y + 11, 92 + o[2]), rgb(96, 74, 56), M.Wood)
	end
	block(parent, V(10, 0.8, 10), V(-96, y + 22, 92), rgb(120, 90, 64), M.WoodPlanks)
	block(parent, V(10, 5, 10), V(-96, y + 25, 92), rgb(140, 110, 80), M.WoodPlanks, { Transparency = 0.1 })
	gen:zone(-96, 92, 8)

	-- fish racks and crab pots
	for _ = 1, 10 do
		local x, z = gen:open(-100, -100, 100, 100, 6)
		if x then
			block(parent, V(0.4, 4, 0.4), V(x - 2, y + 2, z), rgb(96, 70, 48), M.Wood)
			block(parent, V(0.4, 4, 0.4), V(x + 2, y + 2, z), rgb(96, 70, 48), M.Wood)
			block(parent, V(4.4, 0.3, 0.3), V(x, y + 3.8, z), rgb(110, 80, 56), M.Wood)
			for i = -1, 1 do
				block(parent, V(0.5, 1.8, 0.2), V(x + i * 1.2, y + 2.8, z), rgb(190, 180, 170), M.SmoothPlastic, { CanCollide = false })
			end
			gen:zone(x, z, 3)
		end
	end

	-- reeds, reeds, reeds
	for _ = 1, 9 do
		local x, z = gen:open(-100, -100, 100, 100, 6)
		if x then
			MapKit.tallGrass(parent, V(x, y, z), V(rng:NextNumber(18, 30), 0, rng:NextNumber(14, 24)), rng, nil, 1.1)
		end
	end
	gen:scatter({ "Rock_1", "Rock_2", "Bush_1", "DeadTree_1" }, 40, -108, -108, 108, 108, 0.7, 1.3, 0.3)
	for _, f in { { V(-20, 3, 20), V(60, 0, 200) }, { V(40, 3, -50), V(80, 0, 80) }, { V(-60, 3, -40), V(80, 0, 80) } } do
		MapKit.fog(parent, f[1], f[2])
	end

	return gen:finish({
		start = { V(-100, 3, 100), V(-96, 3, 102), V(-104, 3, 96), V(-92, 3, 98) },
		extraction = V(104, 0, -100),
		lantern = V(0, 0, 0),
	})
end

return Map
