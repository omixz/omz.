--!nonstrict
-- POWERWORKS: a decommissioned power station: two steaming cooling towers, a turbine hall and
-- control building, a transformer yard behind a fence, lattice pylons with sagging wires, a
-- coal conveyor and hazard-striped lanes. Hazy yellow-green afternoon.
local MapKit = require(script.Parent.MapKit)
local Gen = require(script.Parent.MapGen)
local V, rgb = Vector3.new, Gen.rgb
local block = MapKit.block

local Map = {
	id = "Powerworks",
	name = "Powerworks",
	lighting = { sky = "cannery", clouds = 0.55, cloudDensity = 0.6, cloudColor = { 236, 238, 214 }, wind = { 8, 0, 3 }, clock = 14.2, brightness = 2.8, ambient = { 108, 114, 98 }, outdoor = { 150, 156, 134 }, fog = 0.34, haze = 1.8, fogColor = { 214, 222, 190 }, tint = { 244, 250, 230 }, saturation = 0.08, contrast = 0.14, shift = { 255, 236, 190 } },
}

local function coolingTower(gen, x, z, y)
	local M = Enum.Material
	for i = 0, 11 do
		local t = i / 11
		local r = 17 - 5.5 * math.sin(t * math.pi * 0.85) + 2.2 * t
		block(gen.parent, V(3, r * 2, r * 2), V(x, y + 1.5 + i * 3, z), rgb(176, 174, 166), M.Concrete, { Shape = Enum.PartType.Cylinder, CFrame = CFrame.new(x, y + 1.5 + i * 3, z) * CFrame.Angles(0, 0, math.pi / 2) })
	end
	local steam = Instance.new("ParticleEmitter")
	steam.Texture = "rbxasset://textures/particles/smoke_main.dds"
	steam.Rate = 12
	steam.Lifetime = NumberRange.new(8, 12)
	steam.Speed = NumberRange.new(4, 7)
	steam.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 8), NumberSequenceKeypoint.new(1, 30) })
	steam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
	steam.Color = ColorSequence.new(rgb(244, 246, 240))
	steam.Acceleration = Vector3.new(3, 1, 1)
	steam.Parent = block(gen.parent, V(1, 1, 1), V(x, y + 35, z), rgb(255, 255, 255), M.SmoothPlastic, { Transparency = 1, CanCollide = false, CanQuery = false })
	gen:zone(x, z, 19)
	gen:lootAt(x + 21, z)
end

local function pylon(gen, x, z, y, h)
	local steel = rgb(150, 154, 158)
	for _, o in { { -2.4, -2.4 }, { 2.4, -2.4 }, { -2.4, 2.4 }, { 2.4, 2.4 } } do
		gen:pipe(V(x + o[1] * 1.6, y, z + o[2] * 1.6), V(x + o[1] * 0.4, y + h, z + o[2] * 0.4), 0.3, steel)
	end
	for k = 1, 5 do
		local yy = y + h * k / 6
		local half = 3.8 - k * 0.55
		block(gen.parent, V(half * 2, 0.3, 0.3), V(x, yy, z - half), steel, Enum.Material.Metal, { CanCollide = false })
		block(gen.parent, V(half * 2, 0.3, 0.3), V(x, yy, z + half), steel, Enum.Material.Metal, { CanCollide = false })
	end
	block(gen.parent, V(1, 1, 22), V(x, y + h, z), steel, Enum.Material.Metal, { CanCollide = false })
	block(gen.parent, V(1, 1, 16), V(x, y + h - 5, z), steel, Enum.Material.Metal, { CanCollide = false })
	gen:zone(x, z, 4)
end

function Map.build(parent, rng)
	local M = Enum.Material
	local gen = Gen.new(parent, rng)
	MapKit.outskirts("coast")
	MapKit.slab(-120, -120, 120, 120, M.Concrete, 0)
	for _ = 1, 6 do
		local x, z = rng:NextNumber(-95, 95), rng:NextNumber(-95, 95)
		MapKit.slab(x - 14, z - 12, x + 14, z + 12, M.Pebble, 0.04)
	end
	local y = gen:flat()

	coolingTower(gen, -62, 62, y)
	coolingTower(gen, -62, 18, y)
	-- turbine hall and control building, joined by a pipe bridge
	gen:building({ -30, 40, 28, 78 }, y, { color = rgb(120, 128, 134), inner = rgb(196, 198, 190), material = M.Concrete, h = 16 })
	gen:building({ 40, 50, 74, 74 }, y, { color = rgb(168, 150, 120), inner = rgb(226, 220, 204), material = M.Brick, h = 10 })
	gen:pipe(V(28, y + 9, 60), V(40, y + 9, 62), 1.4, rgb(196, 70, 54))
	-- a big smokestack
	for i = 0, 7 do
		block(parent, V(5, 9 - i * 0.6, 9 - i * 0.6), V(100, y + 2.5 + i * 5, 90), i % 2 == 0 and rgb(206, 200, 190) or rgb(200, 56, 48), M.Concrete, { Shape = Enum.PartType.Cylinder, CFrame = CFrame.new(100, y + 2.5 + i * 5, 90) * CFrame.Angles(0, 0, math.pi / 2) })
	end
	gen:zone(100, 90, 8)

	-- the transformer yard: a grid of transformers in a fenced compound
	local tx0, tz0 = 30, -90
	for i = 0, 3 do
		for j = 0, 2 do
			local x, z = tx0 + i * 16, tz0 + j * 20
			block(parent, V(7, 6, 5), V(x, y + 3, z), rgb(120, 130, 120), M.Metal)
			for k = -2, 2 do
				block(parent, V(0.6, 2.4, 0.6), V(x + k * 1.3, y + 7.2, z), rgb(236, 226, 206), M.SmoothPlastic)
			end
			block(parent, V(7.4, 0.5, 5.4), V(x, y + 0.3, z), rgb(236, 190, 40), M.SmoothPlastic, { CanCollide = false })
			gen:zone(x, z, 6)
		end
	end
	for _, e in { { 54, -90 - 14, 62, 0.4 }, { 54, -90 + 54, 62, 0.4 }, { 24, -90 + 20, 0.4, 70 }, { 84, -90 + 20, 0.4, 70 } } do
		block(parent, V(e[3], 5, e[4]), V(e[1], y + 2.5, e[2]), rgb(150, 154, 158), M.Metal, { Transparency = 0.55 })
	end
	gen:container(30, -70, "Locker", 90)
	gen:container(76, -100, "Toolbox", 0)
	gen:lootAt(54, -70)
	table.insert(gen.doors, { hinge = V(24, y, -80), width = 6, dir = V(1, 0, 0) })

	-- pylons marching across the map with sagging wires
	local pylons = {}
	for i = 0, 4 do
		local p = V(-100 + i * 50, 0, -40)
		pylon(gen, p.X, p.Z, y, 30)
		table.insert(pylons, p)
	end
	for i = 1, #pylons - 1 do
		for _, dz in { -10, 0, 10 } do
			local a, b = V(pylons[i].X, y + 30, pylons[i].Z + dz), V(pylons[i + 1].X, y + 30, pylons[i + 1].Z + dz)
			for k = 0, 9 do
				local p0 = a:Lerp(b, k / 10) - V(0, math.sin(k / 10 * math.pi) * 3, 0)
				local p1 = a:Lerp(b, (k + 1) / 10) - V(0, math.sin((k + 1) / 10 * math.pi) * 3, 0)
				gen:pipe(p0, p1, 0.12, rgb(40, 40, 44)).CanCollide = false
			end
		end
	end

	-- the coal conveyor and pile
	gen:pipe(V(-20, y + 3, 24), V(30, y + 12, 24), 1.2, rgb(70, 74, 78))
	for _, x in { -10, 10, 30 } do
		block(parent, V(0.8, 12, 0.8), V(x, y + 6, 24), rgb(90, 94, 98), M.Metal)
	end
	for i = 1, 4 do
		block(parent, V(18 - i * 2, 7 - i, 16 - i * 2), V(-40, y + 3 - i * 0.2, -4), rgb(30, 30, 32), M.Slate, { Shape = Enum.PartType.Ball })
	end
	gen:zone(-40, -4, 14)

	-- hazard-striped lanes, drums, crates, wrecks, lamp posts
	for i = -5, 5 do
		block(parent, V(4, 0.1, 1.2), V(-100 + i * 2.4, y + 0.1, 0), rgb(i % 2 == 0 and 236 or 40, i % 2 == 0 and 190 or 40, i % 2 == 0 and 40 or 44), M.SmoothPlastic, { CanCollide = false, CanQuery = false })
	end
	gen:scatter({ "Barrel_1", "Rubble_1" }, 30, -108, -108, 108, 108, 0.8, 1.1, 0, 3)
	for _ = 1, 8 do
		local x, z = gen:open(-108, -108, 108, 108, 6)
		if x then
			gen:crate(x, z, 4, rgb(120, 130, 110))
		end
	end
	gen:car(-96, -90, 0.8, "CarVan_1")
	gen:car(90, 40, 2.0, "CarSedan_2")
	for x = -100, 100, 40 do
		MapKit.lamp(parent, V(x, y, 8), false)
	end
	MapKit.tallGrass(parent, V(-96, y, 96), V(30, 0, 22), rng, nil, 0.8)
	MapKit.tallGrass(parent, V(96, y, -20), V(24, 0, 36), rng, nil, 0.8)
	MapKit.fog(parent, V(-62, 4, 40), V(140, 0, 140))
	gen:fence(rgb(120, 124, 118), 7, 6)

	return gen:finish({
		start = { V(100, 3, -100), V(96, 3, -102), V(104, 3, -96), V(92, 3, -98) },
		extraction = V(-104, 0, 100),
		lantern = V(0, 0, 0),
	})
end

return Map
