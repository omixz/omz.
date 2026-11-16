--!nonstrict
-- FUNFAIR PIER: a seaside amusement pier at dusk: a slowly turning ferris wheel, carousel, big
-- top, game stalls, a bumper-car arena, coaster arches and strings of lights over a plank
-- boardwalk with the sea all round. Pink and violet dusk.
local CollectionService = game:GetService("CollectionService")
local MapKit = require(script.Parent.MapKit)
local Gen = require(script.Parent.MapGen)
local V, rgb = Vector3.new, Gen.rgb
local block = MapKit.block

local Map = {
	id = "FunfairPier",
	name = "Funfair Pier",
	lighting = { sky = "larkspur", clouds = 0.4, cloudDensity = 0.5, cloudColor = { 255, 210, 220 }, wind = { 8, 0, 4 }, clock = 18.9, brightness = 2.3, ambient = { 110, 96, 120 }, outdoor = { 150, 130, 156 }, fog = 0.2, haze = 0.9, fogColor = { 232, 196, 214 }, tint = { 255, 236, 244 }, saturation = 0.28, contrast = 0.1, shift = { 255, 198, 180 } },
}

local COLORS = { rgb(236, 70, 90), rgb(250, 200, 60), rgb(70, 170, 230), rgb(120, 210, 130), rgb(190, 110, 240), rgb(250, 140, 60) }

local function ferrisWheel(gen, cx, cz, y)
	local R, hubY = 18, y + 22
	local model = Instance.new("Model")
	model.Name = "FerrisWheel"
	model.Parent = gen.parent
	local hub = block(model, V(2, 2.4, 2.4), V(cx, hubY, cz), rgb(240, 240, 236), Enum.Material.Metal, { Shape = Enum.PartType.Cylinder, CanCollide = false })
	model.PrimaryPart = hub
	local n = 24
	for i = 0, n - 1 do
		local a = i / n * math.pi * 2
		local p = V(cx, hubY + math.sin(a) * R, cz + math.cos(a) * R)
		local q = V(cx, hubY + math.sin(a + math.pi * 2 / n) * R, cz + math.cos(a + math.pi * 2 / n) * R)
		gen:pipe(p, q, 0.35, rgb(240, 240, 236), Enum.Material.Metal).Parent = model
		if i % 2 == 0 then
			local spoke = gen:pipe(V(cx, hubY, cz), p, 0.2, rgb(200, 200, 196), Enum.Material.Metal)
			spoke.Parent = model
			local cabin = block(model, V(3, 3.4, 4), V(cx, p.Y - 2.4, p.Z), COLORS[(i / 2) % #COLORS + 1], Enum.Material.SmoothPlastic, { CanCollide = false })
			cabin.Name = "Gondola"
		end
	end
	for _, sz in { -6, 6 } do -- the A-frame legs
		gen:pipe(V(cx, y, cz + sz * 1.4), V(cx, hubY, cz), 0.7, rgb(226, 70, 80))
	end
	CollectionService:AddTag(model, "SpinWheel")
	gen:zone(cx, cz, 14)
end

local function carousel(gen, cx, cz, y)
	local M = Enum.Material
	block(gen.parent, V(1, 24, 24), V(cx, y + 0.5, cz), rgb(196, 150, 96), M.WoodPlanks, { Shape = Enum.PartType.Cylinder, CFrame = CFrame.new(cx, y + 0.5, cz) * CFrame.Angles(0, 0, math.pi / 2) })
	block(gen.parent, V(14, 1.6, 1.6), V(cx, y + 8, cz), rgb(250, 200, 60), M.Metal, { Shape = Enum.PartType.Cylinder, CFrame = CFrame.new(cx, y + 5, cz) * CFrame.Angles(0, 0, math.pi / 2) })
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		local p = V(cx + math.cos(a) * 8, y, cz + math.sin(a) * 8)
		gen:pipe(p + V(0, 1, 0), p + V(0, 9, 0), 0.25, rgb(250, 230, 120))
		block(gen.parent, V(1.2, 1.6, 3), V(p.X, y + 3, p.Z), COLORS[i % #COLORS + 1], M.SmoothPlastic, { CanCollide = false })
		block(gen.parent, V(0.8, 1.4, 0.8), V(p.X, y + 4.4, p.Z - 0.9), COLORS[i % #COLORS + 1], M.SmoothPlastic, { CanCollide = false })
	end
	for i = 1, 5 do -- the striped canopy, stacked
		block(gen.parent, V(1.2, 26 - i * 4.6, 26 - i * 4.6), V(cx, y + 9 + i * 1.2, cz), i % 2 == 1 and rgb(236, 70, 90) or rgb(250, 248, 240), M.Fabric, { Shape = Enum.PartType.Cylinder, CFrame = CFrame.new(cx, y + 9 + i * 1.2, cz) * CFrame.Angles(0, 0, math.pi / 2), CanCollide = false })
	end
	gen:zone(cx, cz, 15)
	gen:lootAt(cx + 13, cz)
end

local function bigTop(gen, cx, cz, y)
	local M = Enum.Material
	local R = 22
	for i = 0, 15 do -- ring of poles and low fabric walls, one gap for the door
		local a = i / 16 * math.pi * 2
		local p = V(cx + math.cos(a) * R, y, cz + math.sin(a) * R)
		gen:pipe(p, p + V(0, 12, 0), 0.4, rgb(250, 248, 240))
		if i ~= 0 then
			block(gen.parent, V(2 * math.pi * R / 16 + 0.6, 4, 0.3), CFrame.new(p + V(0, 2, 0)) * CFrame.Angles(0, -a + math.pi / 2, 0), COLORS[i % #COLORS + 1], M.Fabric)
		end
	end
	for i = 1, 8 do -- the cone of the roof, alternating stripes
		block(gen.parent, V(1.2, 2 * R - i * 5, 2 * R - i * 5), V(cx, y + 12 + i * 1.4, cz), i % 2 == 1 and rgb(236, 70, 90) or rgb(250, 248, 240), M.Fabric, { Shape = Enum.PartType.Cylinder, CFrame = CFrame.new(cx, y + 12 + i * 1.4, cz) * CFrame.Angles(0, 0, math.pi / 2) })
	end
	block(gen.parent, V(0.4, 4, 0.4), V(cx, y + 26, cz), rgb(250, 200, 60), M.Metal)
	block(gen.parent, V(10, 1.2, 8), V(cx - 8, y + 0.6, cz), rgb(120, 70, 50), M.WoodPlanks) -- the stage
	for r = 0, 2 do
		block(gen.parent, V(14, 0.6 + r * 0.5, 1.4), V(cx + 6, y + 0.4 + r * 0.25, cz - 4 + r * 4), rgb(150, 70, 70), M.Fabric, { CanCollide = false })
	end
	MapKit.bulb(gen.parent, V(cx, y + 14, cz), 26)
	gen:zone(cx, cz, R + 2)
	gen:container(cx - 8, cz + 4, "Locker", 90)
	gen:container(cx + 8, cz - 8, "AmmoCrate", 0)
	gen:lootAt(cx, cz + 6)
	gen:lootAt(cx - 10, cz - 6)
end

function Map.build(parent, rng)
	local M = Enum.Material
	local gen = Gen.new(parent, rng)
	MapKit.outskirts("coast")
	MapKit.slab(-120, -120, 120, 120, M.Sand, 0)
	local y = gen:flat()
	-- the boardwalk deck over everything, with railings and lifebuoys round the edge
	block(parent, V(240, 0.6, 240), V(0, y + 0.3, 0), rgb(150, 112, 76), M.WoodPlanks)
	for i = -10, 10 do
		block(parent, V(240, 0.05, 0.15), V(0, y + 0.62, i * 11), rgb(100, 72, 48), M.SmoothPlastic, { CanCollide = false, CanQuery = false })
	end
	y += 0.6
	gen.flatY = y
	gen.groundFn = function()
		return y
	end
	for t = -118, 118, 4 do
		for _, p in { { t, 118 }, { t, -118 }, { 118, t }, { -118, t } } do
			block(parent, V(0.4, 3.4, 0.4), V(p[1], y + 1.7, p[2]), rgb(240, 240, 236), M.Metal)
		end
	end
	for _, r in { { 0, 118, 240, 0.3 }, { 0, -118, 240, 0.3 }, { 118, 0, 0.3, 240 }, { -118, 0, 0.3, 240 } } do
		block(parent, V(r[3], 0.35, r[4]), V(r[1], y + 3.2, r[2]), rgb(70, 170, 230), M.Metal)
		block(parent, V(r[3], 0.25, r[4]), V(r[1], y + 1.6, r[2]), rgb(240, 240, 236), M.Metal, { CanCollide = false })
	end

	ferrisWheel(gen, -55, 35, y)
	carousel(gen, 40, 55, y)
	bigTop(gen, 55, -55, y)

	-- game stalls in a row: shops you can walk into, and open-fronted booths
	for i, x in { -90, -60, -30, 0 } do
		gen:house(V(x, y, -100), math.pi, { kind = "shop", w = 22, d = 14 })
		assert(i)
	end
	for i = 0, 7 do
		local x = -95 + i * 13
		local z = 96
		local cf = CFrame.new(x, y, z)
		block(parent, V(9, 3.4, 3), cf * CFrame.new(0, 1.7, 0), COLORS[i % #COLORS + 1], M.WoodPlanks)
		block(parent, V(9.4, 0.4, 3.6), cf * CFrame.new(0, 3.6, 0), rgb(250, 248, 240), M.Fabric)
		for k = 0, 4 do
			block(parent, V(9.4 / 5, 0.5, 4.2), cf * CFrame.new(-3.76 + k * 1.88, 7.6, -0.4) * CFrame.Angles(0.35, 0, 0), k % 2 == 0 and COLORS[i % #COLORS + 1] or rgb(250, 248, 240), M.Fabric, { CanCollide = false })
		end
		for _, px in { -4.3, 4.3 } do
			block(parent, V(0.3, 7.2, 0.3), cf * CFrame.new(px, 3.6, -1.8), rgb(240, 240, 236), M.Metal)
		end
		gen:zone(x, z, 5)
		if i % 3 == 0 then
			gen:container(x, z - 3, "Drawer", 180)
		end
	end

	-- the bumper-car arena: a low fenced rink with cars parked in it
	local ax, az = -58, -50
	for _, e in { { 0, -16, 32, 1 }, { 0, 16, 32, 1 }, { -16, 0, 1, 32 }, { 16, 0, 1, 32 } } do
		block(parent, V(e[3], 3, e[4]), V(ax + e[1], y + 1.5, az + e[2]), rgb(70, 170, 230), M.Metal)
	end
	for i = 1, 6 do
		block(parent, V(3.4, 1.6, 2.6), V(ax - 8 + (i % 3) * 8, y + 0.9, az - 6 + math.floor(i / 3) * 10), COLORS[i % #COLORS + 1], M.SmoothPlastic, { CanCollide = false })
	end
	gen:zone(ax, az, 18)
	gen:lootAt(ax, az)

	-- coaster arches along the east side (decor only), and light strings between poles
	for i = 0, 9 do
		local z = -85 + i * 17
		local h = 8 + math.sin(i * 0.7) * 6
		block(parent, V(1, h + 4, 1), V(100, y + (h + 4) / 2, z - 3), rgb(236, 70, 90), M.Metal)
		block(parent, V(1, h + 4, 1), V(100, y + (h + 4) / 2, z + 3), rgb(236, 70, 90), M.Metal)
		block(parent, V(1, 0.8, 18), V(100, y + h + 4, z), rgb(60, 60, 66), M.Metal, { CanCollide = false })
		gen:zone(100, z, 5)
	end
	for x = -100, 100, 40 do
		block(parent, V(0.5, 14, 0.5), V(x, y + 7, 0), rgb(240, 240, 236), M.Metal)
		gen:zone(x, 0, 2)
	end
	for x = -100, 60, 40 do
		gen:lights(V(x, y + 13, 0), V(x + 40, y + 13, 0), 12, COLORS[math.floor((x + 100) / 40) % #COLORS + 1], 2.2)
	end
	gen:scatter({ "Barrel_1" }, 14, -110, -110, 110, 110, 0.8, 1, 0, 3)
	gen:car(100, -100, 0.6, "CarVan_1")
	for _, p in { { -20, 60 }, { 20, -20 }, { 70, 10 }, { -80, 70 } } do
		block(parent, V(2.6, 3, 2.6), V(p[1], y + 1.5, p[2]), rgb(250, 248, 240), M.SmoothPlastic) -- bins
		gen:zone(p[1], p[2], 3)
	end
	MapKit.fog(parent, V(0, 3, 0), V(160, 0, 160))

	return gen:finish({
		start = { V(100, 3, 100), V(96, 3, 102), V(104, 3, 96), V(92, 3, 98) },
		extraction = V(-104, 0, -100),
		lantern = V(0, 0, 20),
	})
end

return Map
