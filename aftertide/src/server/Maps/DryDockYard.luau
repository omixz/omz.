--!nonstrict
-- DRY DOCK YARD: a flooded dry dock holding a half-built ship, two gantry cranes on rails,
-- catwalk bridges, container stacks, chandlery and workshop, a port office. Steel-grey overcast.
local MapKit = require(script.Parent.MapKit)
local Gen = require(script.Parent.MapGen)
local V, rgb = Vector3.new, Gen.rgb
local block = MapKit.block

local Map = {
	id = "DryDockYard",
	name = "Dry Dock Yard",
	lighting = { sky = "cannery", clouds = 0.7, cloudDensity = 0.55, cloudColor = { 226, 232, 238 }, wind = { 11, 0, 4 }, clock = 11.4, brightness = 2.8, ambient = { 104, 112, 122 }, outdoor = { 146, 154, 164 }, fog = 0.26, haze = 1.0, fogColor = { 204, 214, 224 }, tint = { 238, 244, 252 }, saturation = 0.1, contrast = 0.12, shift = { 255, 240, 220 } },
}

local function crane(gen, x, y)
	local steel = rgb(226, 170, 40)
	for _, dz in { -22, 22 } do
		for _, dx in { -1.6, 1.6 } do
			block(gen.parent, V(1.4, 34, 1.4), V(x + dx, y + 17, dz), steel, Enum.Material.Metal)
		end
	end
	block(gen.parent, V(5, 1.6, 62), V(x, y + 34, 0), steel, Enum.Material.Metal)
	block(gen.parent, V(5, 1, 62), V(x, y + 0.5, 0), rgb(70, 72, 76), Enum.Material.Metal, { CanCollide = false })
	-- the trolley, the hoist cable and a hook block
	block(gen.parent, V(4, 2.6, 5), V(x, y + 32, -6), rgb(200, 60, 48), Enum.Material.Metal)
	block(gen.parent, V(0.2, 18, 0.2), V(x, y + 22, -6), rgb(40, 40, 44), Enum.Material.Metal, { CanCollide = false })
	block(gen.parent, V(2, 1.6, 2), V(x, y + 13, -6), rgb(60, 60, 64), Enum.Material.Metal)
	gen:zone(x, 0, 4)
end

function Map.build(parent, rng)
	local M = Enum.Material
	local gen = Gen.new(parent, rng)
	MapKit.outskirts("coast")
	MapKit.slab(-120, -120, 120, 120, M.Concrete, 0)
	local y = gen:flat()

	-- the dry dock: a long basin of water with a half-built hull in it
	local bx0, bx1, bz0, bz1 = -18, 18, -58, 58
	MapKit.clearAbove(bx0, bz0, bx1, bz1, y - 9)
	MapKit.slab(bx0, bz0, bx1, bz1, M.Concrete, y - 9.2, 4)
	MapKit.water(bx0, bz0, bx1, bz1, y - 3, 6)
	MapKit.volume(parent, V(36, 10, 116), V(0, y - 4, 0), "Shallows")
	gen:zone(0, 0, 66)
	local hull = rgb(150, 54, 44)
	block(parent, V(14, 11, 78), V(0, y - 2.5, 4), hull, M.CorrodedMetal)
	MapKit.wedge(parent, V(14, 11, 20), CFrame.new(0, y - 2.5, -45) * CFrame.Angles(0, math.pi, 0), hull, M.CorrodedMetal)
	block(parent, V(14.4, 1, 80), V(0, y + 3.2, 4), rgb(200, 190, 170), M.WoodPlanks) -- deck
	for z = -30, 40, 7 do -- ribs: the unplated bow
		for _, sx in { -7, 7 } do
			block(parent, V(0.5, 8, 0.5), V(sx, y + 7, z), rgb(110, 110, 108), M.Metal)
		end
		block(parent, V(14, 0.5, 0.5), V(0, y + 11, z), rgb(110, 110, 108), M.Metal)
	end
	block(parent, V(10, 7, 12), V(0, y + 7, 30), rgb(240, 238, 232), M.SmoothPlastic) -- deckhouse
	block(parent, V(10.2, 1.4, 12.2), V(0, y + 10.8, 30), rgb(40, 52, 80), M.Metal)
	for _, sx in { -9, 9 } do -- scaffolding along the hull
		for z = -30, 36, 6 do
			block(parent, V(0.4, 14, 0.4), V(sx * 1.05, y + 3, z), rgb(150, 150, 146), M.Metal)
		end
		block(parent, V(0.4, 0.4, 68), V(sx * 1.05, y + 8, 3), rgb(150, 150, 146), M.Metal)
		block(parent, V(2.4, 0.3, 68), V(sx * 1.05, y + 4, 3), rgb(176, 130, 86), M.WoodPlanks)
	end

	-- two catwalk bridges across the basin, and a gangway onto the ship
	for _, z in { -38, 38 } do
		block(parent, V(42, 0.5, 4), V(0, y + 1, z), rgb(120, 122, 126), M.DiamondPlate)
		for _, dz in { -2, 2 } do
			block(parent, V(42, 0.3, 0.3), V(0, y + 3.2, z + dz), rgb(226, 170, 40), M.Metal, { CanCollide = false })
		end
	end
	block(parent, V(14, 0.5, 3), V(-12, y + 2.6, 4), rgb(120, 122, 126), M.DiamondPlate)

	-- two gantry cranes on rails either side of the dock
	crane(gen, -32, y)
	crane(gen, 32, y)

	-- buildings: port office, chandlery, workshop, a tool store
	gen:building({ -108, -100, -72, -66 }, y, { color = rgb(120, 140, 160), inner = rgb(224, 224, 218), material = M.Concrete, h = 11 })
	gen:house(V(60, y, 70), math.pi, { kind = "shop", w = 26, d = 18 })
	gen:house(V(90, y, 70), math.pi, { kind = "garage", w = 28, d = 22 })
	gen:house(V(-60, y, 70), math.pi, { kind = "garage", w = 28, d = 22 })
	gen:house(V(-100, y, 40), math.pi / 2, { kind = "apartment", w = 24, d = 22 })

	-- container stacks in coloured rows, with lanes between
	local colors = { rgb(196, 74, 54), rgb(40, 140, 150), rgb(60, 100, 170), rgb(226, 170, 60), rgb(90, 150, 90), rgb(150, 70, 140) }
	for row = 0, 3 do
		for col = 0, 3 do
			local x, z = 52 + row * 14, -100 + col * 24
			if gen:free(x, z, 4) and math.random() < 0.85 then
				local stack = rng:NextInteger(1, 3)
				for s = 1, stack do
					block(parent, V(10, 8.6, 20), V(x, y + 4.3 + (s - 1) * 8.7, z), colors[rng:NextInteger(1, #colors)], M.CorrodedMetal)
				end
				gen:zone(x, z, 12)
			end
		end
	end
	for _ = 1, 8 do
		local x, z = gen:open(-108, -108, 108, 108, 6)
		if x then
			gen:crate(x, z, 4)
		end
	end
	gen:scatter({ "Barrel_1", "Rubble_1" }, 26, -108, -108, 108, 108, 0.8, 1.1, 0, 3)
	gen:car(80, 20, 1.6, "CarVan_1")
	gen:car(-84, -20, 0.2, "CarSedan_1")
	for x = -100, 100, 40 do
		MapKit.lamp(parent, V(x, y, -86), false)
		MapKit.lamp(parent, V(x, y, 96), false)
	end
	gen:fence(rgb(120, 124, 128), 7, 6)
	MapKit.fog(parent, V(0, 2, 0), V(120, 0, 120))

	return gen:finish({
		start = { V(-100, 3, -100), V(-96, 3, -102), V(-104, 3, -96), V(-92, 3, -98) },
		extraction = V(104, 0, 100),
		lantern = V(0, 0, 80),
	})
end

return Map
