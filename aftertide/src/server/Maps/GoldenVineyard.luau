--!nonstrict
-- GOLDEN VINEYARD: rolling hills of vine rows and orchard trees, a stone farmhouse, a big barn,
-- a wine cellar, a windmill, hay bales, tractors and stone walls. Warm golden hour.
local MapKit = require(script.Parent.MapKit)
local Gen = require(script.Parent.MapGen)
local V, rgb = Vector3.new, Gen.rgb
local block = MapKit.block

local Map = {
	id = "GoldenVineyard",
	name = "Golden Vineyard",
	hilly = true,
	lighting = { sky = "larkspur", clouds = 0.3, cloudDensity = 0.45, cloudColor = { 255, 236, 206 }, wind = { 6, 0, 2 }, clock = 17.7, brightness = 3.2, ambient = { 116, 106, 92 }, outdoor = { 168, 154, 130 }, fog = 0.18, haze = 0.9, fogColor = { 240, 216, 170 }, tint = { 255, 240, 214 }, saturation = 0.24, contrast = 0.1, shift = { 255, 212, 160 } },
}

local function baseHeight(x, z)
	return math.noise(x / 60, z / 60, 5.5) * 7 + math.noise(x / 22, z / 22, 1.3) * 1.6 + 5
end

local function windmill(gen, x, z, y)
	local M = Enum.Material
	for i = 0, 5 do
		block(gen.parent, V(1, 16 - i * 1.8, 16 - i * 1.8), V(x, y + 2 + i * 3.4, z), i % 2 == 0 and rgb(236, 226, 206) or rgb(214, 200, 176), M.Brick, { Shape = Enum.PartType.Cylinder, CFrame = CFrame.new(x, y + 2 + i * 3.4, z) * CFrame.Angles(0, 0, math.pi / 2) })
	end
	block(gen.parent, V(1.2, 12, 12), V(x, y + 22.5, z), rgb(120, 70, 50), M.WoodPlanks, { Shape = Enum.PartType.Cylinder, CFrame = CFrame.new(x, y + 22.5, z) * CFrame.Angles(0, 0, math.pi / 2) })
	for i = 0, 3 do
		local a = i * math.pi / 2 + 0.4
		local tip = V(x, y + 20 + math.sin(a) * 14, z - 6.4 + math.cos(a) * 14)
		gen:pipe(V(x, y + 20, z - 6.4), tip, 0.35, rgb(150, 104, 66), M.Wood)
		block(gen.parent, V(0.2, 5, 11), CFrame.new((V(x, y + 20, z - 6.4) + tip) / 2) * CFrame.Angles(a, 0, 0), rgb(240, 236, 222), M.Fabric, { CanCollide = false })
	end
	gen:zone(x, z, 12)
	gen:container(x + 9, z, "Toolbox", 90)
	gen:lootAt(x - 9, z)
end

local function tractor(gen, x, z, yaw)
	local y = gen:ground(x, z)
	local cf = CFrame.new(x, y, z) * CFrame.Angles(0, yaw, 0)
	block(gen.parent, V(6, 2.6, 3.6), cf * CFrame.new(0, 2.4, 0), rgb(60, 130, 70), Enum.Material.Metal)
	block(gen.parent, V(2.6, 3, 3), cf * CFrame.new(-1.6, 4.6, 0), rgb(70, 140, 80), Enum.Material.Metal)
	for _, s in { -2, 2 } do
		block(gen.parent, V(3.4, 3.4, 1), cf * CFrame.new(-2, 1.7, s) * CFrame.Angles(0, 0, math.pi / 2), rgb(30, 30, 32), Enum.Material.Rubber, { Shape = Enum.PartType.Cylinder })
		block(gen.parent, V(2, 2, 0.8), cf * CFrame.new(2.4, 1, s * 1.1) * CFrame.Angles(0, 0, math.pi / 2), rgb(30, 30, 32), Enum.Material.Rubber, { Shape = Enum.PartType.Cylinder })
	end
	gen:zone(x, z, 5)
end

function Map.build(parent, rng)
	local M = Enum.Material
	local gen = Gen.new(parent, rng)
	MapKit.outskirts("forest")
	MapKit.heightfield(-120, -120, 120, 120, 6, baseHeight, function(x, z)
		return math.noise(x / 30, z / 30, 1) > 0.1 and M.Grass or M.LeafyGrass
	end)
	gen:rolling()
	local function pad(cx, cz, w, d)
		local y = baseHeight(cx, cz)
		MapKit.clearAbove(cx - w / 2, cz - d / 2, cx + w / 2, cz + d / 2, y)
		MapKit.slab(cx - w / 2, cz - d / 2, cx + w / 2, cz + d / 2, M.Ground, y, 16)
		return y
	end

	-- the estate in the middle: farmhouse, barn, cellar, windmill
	local fy = pad(0, 20, 44, 40)
	gen:house(V(0, fy, 8), 0, { kind = "house", w = 28, d = 22, roof = "crossGable", color = rgb(226, 206, 170) })
	local by = pad(-60, 10, 40, 38)
	gen:house(V(-60, by, 0), 0, { kind = "garage", w = 34, d = 26, color = rgb(170, 70, 56) })
	local cy = pad(60, 14, 34, 30)
	gen:building({ 46, 4, 76, 26 }, cy, { color = rgb(160, 150, 136), inner = rgb(206, 196, 178), material = M.Slate, h = 9 })
	local wy = pad(90, -60, 24, 24)
	windmill(gen, 90, -60, wy)

	-- vine rows over the hills
	local posts = 0
	for row = 0, 11 do
		local z = -100 + row * 9
		for x = -98, 98, 5 do
			if gen:free(x, z, 3) and posts < 520 and not (x > -78 and x < -42 and z > -12 and z < 28) then
				local y = gen:ground(x, z)
				block(parent, V(0.3, 4, 0.3), V(x, y + 2, z), rgb(110, 80, 56), M.Wood, { CanCollide = false })
				block(parent, V(1.8, 3.2, 1.4), V(x + 2.5, y + 1.8, z), rgb(70, 140, 56), M.LeafyGrass, { CanCollide = false, CanQuery = false })
				if x % 15 == 0 then
					block(parent, V(0.8, 0.8, 0.8), V(x + 2.5, y + 3.4, z), rgb(110, 40, 120), M.SmoothPlastic, { Shape = Enum.PartType.Ball, CanCollide = false, CanQuery = false })
				end
				posts += 1
			end
		end
	end
	-- the orchard: rows of round-crowned trees
	for i = 0, 5 do
		for j = 0, 4 do
			local x, z = 20 + i * 12, -90 + j * 12
			if gen:free(x, z, 4) then
				MapKit.prop(parent, "Bush_" .. rng:NextInteger(1, 2), CFrame.new(x, gen:ground(x, z), z), 2.2)
				gen:zone(x, z, 3)
			end
		end
	end
	-- hay bales, stone walls, tractors, barrels
	for _ = 1, 16 do
		local x, z = gen:open(-108, -108, 108, 108, 6)
		if x then
			local y = gen:ground(x, z)
			block(parent, V(3.4, 2.6, 2.6), CFrame.new(x, y + 1.3, z) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), rgb(226, 190, 90), M.Fabric)
			gen:zone(x, z, 3)
		end
	end
	for _ = 1, 8 do
		local x, z = gen:open(-108, -108, 100, 100, 8)
		if x then
			local yaw = rng:NextNumber(0, 3.14)
			for k = 0, 5 do
				local px, pz = x + math.cos(yaw) * k * 3.2, z + math.sin(yaw) * k * 3.2
				block(parent, V(3.4, 1.8, 1.2), CFrame.new(px, gen:ground(px, pz) + 0.8, pz) * CFrame.Angles(0, -yaw, 0), rgb(150, 146, 138), M.Rock)
			end
			gen:zone(x, z, 8)
		end
	end
	tractor(gen, -30, -40, 0.7)
	tractor(gen, 40, 50, 2.4)
	gen:car(10, 90, 0.4, "CarVan_1")
	gen:scatter({ "Barrel_1" }, 8, -108, -108, 108, 108, 0.8, 1, 0, 3)
	gen:scatter({ "Pine_1", "Pine_2" }, 30, -112, -112, 112, 112, 0.5, 0.8, 0.4, 4) -- tall slim cypress-like trees
	gen:scatter({ "Rock_1", "Rock_2", "Bush_1" }, 30, -112, -112, 112, 112, 0.8, 1.4, 0.4, 3)
	MapKit.tallGrass(parent, V(-90, gen:ground(-90, 70), 70), V(30, 0, 40), rng, MapKit.ground)
	MapKit.tallGrass(parent, V(90, gen:ground(90, 70), 70), V(26, 0, 36), rng, MapKit.ground)
	for _ = 1, 20 do
		local x, z = gen:open(-108, -108, 108, 108, 3)
		if x then
			gen:flowers(V(x, 0, z), rng:NextNumber(2, 5))
		end
	end
	MapKit.ridge(baseHeight, 7)

	return gen:finish({
		start = { V(100, 3, 100), V(96, 3, 102), V(104, 3, 96), V(92, 3, 98) },
		extraction = V(-104, 0, -100),
		lantern = V(0, 0, 40),
	})
end

return Map
