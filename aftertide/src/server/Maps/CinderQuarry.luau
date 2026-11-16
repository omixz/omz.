--!nonstrict
-- CINDER QUARRY: a terraced open pit with a switchback ramp down to a dusty floor, a crusher
-- building, excavators and dump trucks, conveyors climbing the wall, ore piles and site huts on
-- the rim. Dry, orange late afternoon.
local MapKit = require(script.Parent.MapKit)
local Gen = require(script.Parent.MapGen)
local V, rgb = Vector3.new, Gen.rgb
local block = MapKit.block

local Map = {
	id = "CinderQuarry",
	name = "Cinder Quarry",
	hilly = true,
	lighting = { sky = "larkspur", clouds = 0.25, cloudDensity = 0.4, cloudColor = { 255, 226, 190 }, wind = { 9, 0, 2 }, clock = 17.2, brightness = 3.1, ambient = { 118, 100, 88 }, outdoor = { 170, 148, 124 }, fog = 0.28, haze = 1.6, fogColor = { 236, 200, 156 }, tint = { 255, 232, 204 }, saturation = 0.18, contrast = 0.12, shift = { 255, 214, 168 } },
}

local CX, CZ = -10, 5
local RAMP = 3.5 -- the direction of the smooth ramp (radians)

local function wrap(a)
	return (a + math.pi) % (2 * math.pi) - math.pi
end

local function pitHeight(x, z)
	local r = math.sqrt((x - CX) ^ 2 + (z - CZ) ^ 2)
	local t = math.clamp((r - 30) / 62, 0, 1)
	local h = -8 + 24 * t
	local ang = math.atan2(z - CZ, x - CX)
	if math.abs(wrap(ang - RAMP)) > 0.4 then
		h = math.floor(h / 3 + 0.5) * 3 + math.noise(x / 17, z / 17, 2) * 0.5 -- terraces
	end
	return h + math.noise(x / 40, z / 40, 9) * 1.2
end

local function excavator(gen, x, z, yaw)
	local y = gen:ground(x, z)
	local cf = CFrame.new(x, y, z) * CFrame.Angles(0, yaw, 0)
	local yellow = rgb(236, 180, 40)
	for _, s in { -2.2, 2.2 } do
		block(gen.parent, V(9, 1.6, 2), cf * CFrame.new(0, 0.8, s), rgb(60, 60, 62), Enum.Material.Metal)
	end
	block(gen.parent, V(7, 2.2, 5), cf * CFrame.new(0, 2.7, 0), yellow, Enum.Material.Metal)
	block(gen.parent, V(3, 3, 3.4), cf * CFrame.new(1.8, 5.2, 0), yellow, Enum.Material.Metal)
	block(gen.parent, V(0.2, 2.2, 2.8), cf * CFrame.new(3.35, 5.4, 0), rgb(70, 110, 130), Enum.Material.Glass, { Transparency = 0.3 })
	gen:pipe((cf * CFrame.new(2, 3.5, 0)).Position, (cf * CFrame.new(9, 9, 0)).Position, 0.5, yellow)
	gen:pipe((cf * CFrame.new(9, 9, 0)).Position, (cf * CFrame.new(13, 4, 0)).Position, 0.4, yellow)
	block(gen.parent, V(2.6, 2, 3.4), cf * CFrame.new(13.4, 3.6, 0) * CFrame.Angles(0, 0, 0.5), rgb(120, 118, 112), Enum.Material.Metal)
	gen:zone(x, z, 9)
end

local function truck(gen, x, z, yaw)
	local y = gen:ground(x, z)
	local cf = CFrame.new(x, y, z) * CFrame.Angles(0, yaw, 0)
	block(gen.parent, V(14, 4.6, 7.4), cf * CFrame.new(-1, 4.6, 0) * CFrame.Angles(0, 0, 0.08), rgb(232, 150, 40), Enum.Material.Metal)
	block(gen.parent, V(4.4, 4.6, 7), cf * CFrame.new(7.6, 3.6, 0), rgb(236, 180, 40), Enum.Material.Metal)
	block(gen.parent, V(0.2, 2, 5.6), cf * CFrame.new(9.8, 4.4, 0), rgb(70, 110, 130), Enum.Material.Glass, { Transparency = 0.3 })
	for _, wx in { -4.5, 4, 8 } do
		for _, wz in { -3.8, 3.8 } do
			block(gen.parent, V(3, 3, 1.6), cf * CFrame.new(wx, 1.5, wz) * CFrame.Angles(0, 0, math.pi / 2), rgb(30, 30, 32), Enum.Material.Rubber, { Shape = Enum.PartType.Cylinder })
		end
	end
	gen:zone(x, z, 9)
end

function Map.build(parent, rng)
	local M = Enum.Material
	local gen = Gen.new(parent, rng)
	MapKit.outskirts("coast")
	MapKit.heightfield(-120, -120, 120, 120, 6, pitHeight, function(x, z, h)
		if h < -6 then
			return M.Sand
		end
		local n = math.noise(x / 25, z / 25, 4)
		if h > 12 then
			return M.Ground
		end
		return n > 0.15 and M.Basalt or M.Rock
	end)
	gen:rolling()

	-- the crusher building on the pit floor, and a fuel store
	local crusher = gen:building({ CX - 22, CZ + 2, CX + 6, CZ + 26 }, pitHeight(CX - 8, CZ + 14), { color = rgb(150, 150, 146), inner = rgb(200, 196, 186), material = M.Concrete, h = 12 })
	-- the conveyor from the crusher up the pit wall to a stockpile on the rim
	local a = V(CX - 8, pitHeight(CX - 8, CZ + 14) + 12, CZ + 26)
	local bPoint = V(CX + 6, pitHeight(CX + 6, CZ + 90) + 5, CZ + 90)
	gen:pipe(a, bPoint, 1.1, rgb(80, 84, 88), M.Metal)
	for k = 0.2, 0.9, 0.2 do
		local p = a:Lerp(bPoint, k)
		block(parent, V(1, p.Y - gen:ground(p.X, p.Z), 1), V(p.X, (p.Y + gen:ground(p.X, p.Z)) / 2, p.Z), rgb(100, 104, 108), M.Metal)
	end
	gen:zone(CX + 6, CZ + 58, 6)
	for i = 1, 5 do -- ore stockpile
		block(parent, V(10 - i, 5 - i * 0.6, 10 - i), V(CX + 6, pitHeight(CX + 6, CZ + 94) + (5 - i * 0.6) / 2 + (i - 1) * 2, CZ + 94), rgb(70, 66, 64), M.Slate, { Shape = Enum.PartType.Ball })
	end

	-- machines on the pit floor
	excavator(gen, CX + 12, CZ - 10, 0.5)
	excavator(gen, CX - 18, CZ - 14, 2.6)
	truck(gen, CX + 10, CZ + 14, 1.6)
	truck(gen, CX - 4, CZ - 24, 0.2)
	-- ore piles and boulders
	for _ = 1, 9 do
		local x, z = gen:open(CX - 22, CZ - 22, CX + 24, CZ + 22, 5)
		if x then
			MapKit.prop(parent, ({ "Boulder_1", "Rock_1", "Rock_2" })[rng:NextInteger(1, 3)], CFrame.new(x, gen:ground(x, z) - 0.4, z) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), rng:NextNumber(1, 2))
		end
	end

	-- the site on the northern rim: huts, an office, a fuel tank, a generator
	for i, x in { -60, -20, 30 } do
		local y = pitHeight(x, -92)
		MapKit.clearAbove(x - 16, -112, x + 16, -76, y)
		MapKit.slab(x - 16, -112, x + 16, -76, M.Ground, y, 16)
		gen:house(V(x, y, -108), i % 2 == 0 and math.pi or math.pi, { kinds = { "garage", "house", "apartment" } })
	end
	local fy = pitHeight(70, -60)
	MapKit.clearAbove(58, -72, 82, -48, fy)
	MapKit.slab(58, -72, 82, -48, M.Ground, fy, 16)
	block(parent, V(8, 8, 8), V(70, fy + 4, -60), rgb(200, 60, 48), M.Metal, { Shape = Enum.PartType.Cylinder, CFrame = CFrame.new(70, fy + 4, -60) * CFrame.Angles(0, 0, math.pi / 2) })
	gen:zone(70, -60, 10)
	gen:container(60, -66, "Toolbox", 0)
	gen:container(80, -52, "AmmoCrate", 90)

	-- warning signs, barrels, parked wrecks and the road in
	gen:sign(-60, 95, 0.4, "BLASTING IN PROGRESS", rgb(206, 150, 30))
	gen:scatter({ "Barrel_1" }, 18, -105, -105, 105, 105, 0.8, 1, 0, 3)
	gen:car(-80, 80, 0.4, "CarVan_1")
	gen:car(60, 90, 2.1, "CarSedan_2")
	gen:scatter({ "Rock_1", "Rock_2", "DeadTree_1", "Bush_1" }, 50, -112, -112, 112, 112, 0.8, 1.6, 0.5, 4)
	MapKit.tallGrass(parent, V(-90, gen:ground(-90, -20), -20), V(24, 0, 40), rng, MapKit.ground)
	MapKit.tallGrass(parent, V(90, gen:ground(90, 30), 30), V(24, 0, 40), rng, MapKit.ground)
	for _, f in { { V(CX, -4, CZ), V(90, 0, 90) } } do
		MapKit.fog(parent, f[1], f[2])
	end

	return gen:finish({
		start = { V(-96, 3, 96), V(-92, 3, 98), V(-100, 3, 92), V(-88, 3, 94) },
		extraction = V(98, 0, -96),
		lantern = V(CX, 0, CZ - 4),
	})
end

return Map
