--!nonstrict
-- HOLLOW PINES: a lakeside logging valley above the coast. A creek with a plank bridge, a lake with
-- a dock and rowboat, a campground round a fire, a gas station and shop on the logging road, a
-- sawmill, a ranger station and lookout, cabins, wrecks along the road, dense pine forest, flowers
-- and meadows of tall grass to hide in. Bright morning.
local MapKit = require(script.Parent.MapKit)
local C = MapKit.C
local block = MapKit.block

local Map = {
	id = "HollowPines",
	name = "Hollow Pines",
	hilly = true,
	lighting = { sky = "pines", clouds = 0.35, cloudDensity = 0.55, cloudColor = { 255, 255, 255 }, wind = { 4, 0, -3 }, clock = 8.6, brightness = 3.0, ambient = { 100, 108, 106 }, outdoor = { 146, 156, 150 }, fog = 0.3, haze = 1.0, fogColor = { 214, 230, 236 }, tint = { 250, 252, 244 }, saturation = 0.14, contrast = 0.08, shift = { 255, 230, 200 } },
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

local STATION = { -106, 18, -70, 46 }

-- Scenery helpers ----------------------------------------------------------------------------

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

-- A cylinder log between two points.
local function log(parent, a, b, radius, color, material)
	local mid = (a + b) / 2
	local len = (b - a).Magnitude
	return block(parent, Vector3.new(len, radius * 2, radius * 2), CFrame.lookAt(mid, b) * CFrame.Angles(0, math.pi / 2, 0), color or rgb(120, 84, 56), material or Enum.Material.Wood, { Shape = Enum.PartType.Cylinder })
end

local function tent(parent, pos, yaw, color)
	local M = Enum.Material
	local cf = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
	MapKit.wedge(parent, Vector3.new(5.4, 3.4, 2.6), cf * CFrame.new(0, 1.7, -1.3), color, M.Fabric)
	MapKit.wedge(parent, Vector3.new(5.4, 3.4, 2.6), cf * CFrame.new(0, 1.7, 1.3) * CFrame.Angles(0, math.pi, 0), color, M.Fabric)
	block(parent, Vector3.new(2, 2.4, 0.15), cf * CFrame.new(0, 1.2, -2.62), rgb(30, 34, 38), M.Fabric, { CanCollide = false }) -- the doorway
	block(parent, Vector3.new(5.6, 0.2, 0.2), cf * CFrame.new(0, 3.45, 0), rgb(240, 240, 236), M.Fabric, { CanCollide = false })
	block(parent, Vector3.new(1.4, 0.5, 3), cf * CFrame.new(1.2, 0.35, 0), rgb(214, 90, 70), M.Fabric, { CanCollide = false }) -- sleeping bag
end

local function campfire(parent, pos)
	local M = Enum.Material
	for i = 0, 9 do
		local a = i / 10 * math.pi * 2
		block(parent, Vector3.new(0.9, 0.7, 0.9), CFrame.new(pos + Vector3.new(math.cos(a) * 1.7, 0.35, math.sin(a) * 1.7)) * CFrame.Angles(0, a, 0), rgb(120, 118, 112), M.Rock)
	end
	for i = 0, 2 do
		local a = i / 3 * math.pi
		log(parent, pos + Vector3.new(math.cos(a) * 1.1, 0.5, math.sin(a) * 1.1), pos + Vector3.new(-math.cos(a) * 1.1, 0.7, -math.sin(a) * 1.1), 0.22, rgb(70, 50, 36))
	end
	local core = block(parent, Vector3.new(1.4, 0.4, 1.4), pos + Vector3.new(0, 0.4, 0), rgb(255, 120, 40), M.Neon, { CanCollide = false })
	local fire = Instance.new("Fire")
	fire.Size = 6
	fire.Heat = 8
	fire.Color = rgb(255, 150, 50)
	fire.SecondaryColor = rgb(255, 60, 20)
	fire.Parent = core
	local light = Instance.new("PointLight")
	light.Range = 26
	light.Brightness = 1.6
	light.Color = rgb(255, 170, 90)
	light.Shadows = true
	light.Parent = core
	MapKit.volume(parent, Vector3.new(16, 8, 16), pos + Vector3.new(0, 3, 0), "LitZone")
end

local function bench(parent, pos, yaw)
	local cf = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
	block(parent, Vector3.new(4.4, 0.35, 1.1), cf * CFrame.new(0, 1.4, 0), rgb(150, 104, 66), Enum.Material.WoodPlanks)
	for _, x in { -1.8, 1.8 } do
		block(parent, Vector3.new(0.3, 1.4, 0.9), cf * CFrame.new(x, 0.7, 0), rgb(110, 76, 50), Enum.Material.Wood)
	end
end

local function picnic(parent, pos, yaw)
	local cf = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
	block(parent, Vector3.new(5, 0.3, 2.6), cf * CFrame.new(0, 2.4, 0), rgb(176, 130, 86), Enum.Material.WoodPlanks)
	for _, z in { -2, 2 } do
		block(parent, Vector3.new(5, 0.3, 1), cf * CFrame.new(0, 1.4, z), rgb(150, 104, 66), Enum.Material.WoodPlanks)
	end
	for _, x in { -2, 2 } do
		block(parent, Vector3.new(0.3, 2.4, 4.6), cf * CFrame.new(x, 1.2, 0), rgb(110, 76, 50), Enum.Material.Wood, { CanCollide = false })
	end
end

local function sign(parent, pos, yaw, text, color)
	local cf = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
	block(parent, Vector3.new(0.4, 7, 0.4), cf * CFrame.new(0, 3.5, 0), rgb(96, 70, 48), Enum.Material.Wood)
	local board = block(parent, Vector3.new(6, 2, 0.3), cf * CFrame.new(0, 6.2, 0), color or rgb(46, 96, 62), Enum.Material.WoodPlanks)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.Parent = board
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.Oswald
		label.TextScaled = true
		label.Text = text
		label.TextColor3 = rgb(250, 244, 220)
		label.Parent = gui
	end
end

local function flowerPatch(parent, center, radius, rng, groundFn)
	local colors = { rgb(240, 90, 110), rgb(255, 208, 60), rgb(250, 250, 250), rgb(180, 110, 230), rgb(255, 140, 60), rgb(110, 170, 250) }
	local color = colors[rng:NextInteger(1, #colors)]
	for _ = 1, 14 do
		local a, r = rng:NextNumber(0, 6.28), rng:NextNumber(0, radius)
		local x, z = center.X + math.cos(a) * r, center.Z + math.sin(a) * r
		local y = groundFn(x, z)
		block(parent, Vector3.new(0.18, 0.9, 0.18), Vector3.new(x, y + 0.45, z), rgb(70, 130, 60), Enum.Material.Grass, { CanCollide = false, CanQuery = false })
		block(parent, Vector3.new(0.55, 0.55, 0.55), Vector3.new(x, y + 1, z), color, Enum.Material.SmoothPlastic, { Shape = Enum.PartType.Ball, CanCollide = false, CanQuery = false })
	end
end

function Map.build(parent, rng)
	local M = Enum.Material
	MapKit.outskirts("forest")
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
		local h = MapKit.house(parent, Vector3.new(spot.X, y, spot.Z), 0, rng, { cabin = true })
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

	-- the ranger station: a flattened pad and a building with rooms
	local sy = baseHeight(-88, 32)
	MapKit.clearAbove(STATION[1] - 6, STATION[2] - 8, STATION[3] + 6, STATION[4] + 8, sy)
	MapKit.slab(STATION[1] - 6, STATION[2] - 8, STATION[3] + 6, STATION[4] + 8, M.Ground, sy, 16)
	local station = MapKit.building(parent, STATION, sy, rng, { color = Color3.fromRGB(150, 104, 66), inner = Color3.fromRGB(226, 214, 190), material = Enum.Material.WoodPlanks, h = 10 })
	for _, d in station.doorways do
		table.insert(doorways, d)
	end
	for _, c in station.containers do
		table.insert(containers, c)
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

	local extraLoot, extraContainers, extraDoors = {}, {}, {}
	local function pad(cx, cz, w, d, material)
		local y = baseHeight(cx, cz)
		MapKit.clearAbove(cx - w / 2, cz - d / 2, cx + w / 2, cz + d / 2, y)
		MapKit.slab(cx - w / 2, cz - d / 2, cx + w / 2, cz + d / 2, material or M.Ground, y, 16)
		return y
	end

	-- the campground: tents round a fire, log benches, a cooler, a lantern line
	do
		local cx, cz = -18, -62
		local y = pad(cx, cz, 34, 30, M.Mud)
		campfire(parent, Vector3.new(cx, y, cz))
		for i, color in { rgb(236, 120, 60), rgb(70, 140, 200), rgb(120, 190, 100), rgb(220, 70, 90) } do
			local a = i / 4 * math.pi * 2 + 0.4
			local p = Vector3.new(cx + math.cos(a) * 11, y, cz + math.sin(a) * 9)
			tent(parent, p, a + math.pi / 2 + math.pi, color)
			table.insert(extraLoot, p + Vector3.new(math.cos(a) * -3.5, 0, math.sin(a) * -3))
		end
		for i = 0, 3 do
			local a = i / 4 * math.pi * 2
			bench(parent, Vector3.new(cx + math.cos(a) * 4.6, y, cz + math.sin(a) * 4.6), a + math.pi / 2)
		end
		block(parent, Vector3.new(2.4, 1.6, 1.4), Vector3.new(cx + 6, y + 0.8, cz - 6), rgb(70, 130, 200), Enum.Material.SmoothPlastic) -- cooler
		block(parent, Vector3.new(2.5, 0.3, 1.5), Vector3.new(cx + 6, y + 1.7, cz - 6), rgb(240, 240, 236), Enum.Material.SmoothPlastic)
		table.insert(extraContainers, { pos = Vector3.new(cx + 8, y, cz + 4), type = "AmmoCrate", yaw = 0 })
		table.insert(extraContainers, { pos = Vector3.new(cx - 10, y, cz + 8), type = "Toolbox", yaw = 90 })
		picnic(parent, Vector3.new(cx - 2, y, cz + 11), 0)
		-- a string of lanterns between two poles
		for _, px in { cx - 13, cx + 13 } do
			block(parent, Vector3.new(0.4, 9, 0.4), Vector3.new(px, y + 4.5, cz - 12), rgb(96, 70, 48), M.Wood)
		end
		for i = 0, 8 do
			local k = i / 8
			local bulb = block(parent, Vector3.new(0.7, 0.7, 0.7), Vector3.new(cx - 13 + 26 * k, y + 8.6 - math.sin(k * math.pi) * 1.5, cz - 12), rgb(255, 214, 140), M.Neon, { Shape = Enum.PartType.Ball, CanCollide = false })
			if i % 3 == 1 then
				local l = Instance.new("PointLight")
				l.Range = 14
				l.Color = rgb(255, 200, 120)
				l.Parent = bulb
			end
		end
		sign(parent, Vector3.new(cx + 18, y, cz + 16), -0.6, "CAMP BRINEWAKE", rgb(46, 96, 62))
	end

	-- the gas station and shop on the logging road
	local store
	do
		local cx, cz = 25, 82
		local y = pad(cx, cz, 46, 50, M.Ground)
		store = MapKit.house(parent, Vector3.new(cx, y, cz + 6), 0, rng, { kind = "shop", w = 26, d = 18 })
		-- canopy over two pumps, on four posts, with a lit sign
		local canopyZ = cz - 12
		for _, px in { cx - 10, cx + 10 } do
			for _, pz in { canopyZ - 4, canopyZ + 4 } do
				block(parent, Vector3.new(0.9, 11, 0.9), Vector3.new(px, y + 5.5, pz), rgb(236, 236, 232), M.Metal)
			end
		end
		block(parent, Vector3.new(24, 0.8, 12), Vector3.new(cx, y + 11.4, canopyZ), rgb(214, 60, 52), M.SmoothPlastic)
		block(parent, Vector3.new(24.4, 0.5, 12.4), Vector3.new(cx, y + 10.9, canopyZ), rgb(250, 250, 246), M.SmoothPlastic)
		for _, px in { cx - 5, cx + 5 } do
			block(parent, Vector3.new(1.6, 4, 1.2), Vector3.new(px, y + 2, canopyZ), rgb(226, 60, 52), M.Metal)
			block(parent, Vector3.new(1.2, 1, 0.1), Vector3.new(px, y + 3.2, canopyZ - 0.62), rgb(120, 240, 150), M.Neon, { CanCollide = false })
			MapKit.bulb(parent, Vector3.new(px, y + 10, canopyZ), 18)
		end
		sign(parent, Vector3.new(cx - 22, y, cz - 18), 0.4, "GAS · SHOP", rgb(196, 60, 48))
		MapKit.prop(parent, "CarSedan_1", CFrame.new(cx + 2, y, canopyZ - 1) * CFrame.Angles(0, math.pi / 2, 0))
		MapKit.prop(parent, "CarVan_1", CFrame.new(cx - 18, y, cz + 8) * CFrame.Angles(0, 0.3, 0), 1.1)
		for _, d in store.doorways do
			table.insert(extraDoors, d)
		end
		for _, c in store.containers do
			table.insert(extraContainers, c)
		end
		for _, l in store.loot do
			table.insert(extraLoot, l)
		end
		table.insert(extraContainers, { pos = Vector3.new(cx + 16, y, canopyZ + 6), type = "Toolbox", yaw = 180 })
	end

	-- the lake: sandy beach, a dock, a rowboat, picnic tables
	do
		local cx, cz = 82, 88
		local gy = baseHeight(cx, cz)
		local terrain = workspace.Terrain
		terrain:FillCylinder(CFrame.new(cx, gy + 1, cz), 12, 20, M.Air) -- carve the basin
		terrain:FillCylinder(CFrame.new(cx, gy - 1.6, cz), 1.2, 20, M.Sand) -- the beach
		terrain:FillCylinder(CFrame.new(cx, gy - 2, cz), 4.2, 14.5, M.Air) -- clear the middle
		terrain:FillCylinder(CFrame.new(cx, gy - 4.4, cz), 1.2, 15, M.Mud) -- the lake bed
		terrain:FillCylinder(CFrame.new(cx, gy - 2.6, cz), 2.4, 14.5, M.Water) -- the water, just under the beach
		-- the dock
		for i = 0, 5 do
			block(parent, Vector3.new(3.4, 0.35, 2.6), Vector3.new(cx - 18 + i * 2.7, gy - 0.5, cz), rgb(150, 112, 76), M.WoodPlanks)
		end
		for i = 0, 3 do
			for _, dz in { -1.4, 1.4 } do
				block(parent, Vector3.new(0.4, 3.4, 0.4), Vector3.new(cx - 17 + i * 4.4, gy - 2, cz + dz), rgb(90, 66, 46), M.Wood)
			end
		end
		-- the rowboat
		local boat = Vector3.new(cx - 9, gy - 1.2, cz + 8)
		block(parent, Vector3.new(7, 1.2, 2.8), CFrame.new(boat) * CFrame.Angles(0, 0.35, 0), rgb(214, 80, 60), M.WoodPlanks)
		block(parent, Vector3.new(2, 1.2, 2.2), CFrame.new(boat + Vector3.new(4, 0.2, 1.4)) * CFrame.Angles(0, 0.35, 0), rgb(214, 80, 60), M.WoodPlanks)
		block(parent, Vector3.new(6, 0.3, 2.2), CFrame.new(boat + Vector3.new(0, 0.7, 0)) * CFrame.Angles(0, 0.35, 0), rgb(240, 226, 190), M.WoodPlanks, { CanCollide = false })
		picnic(parent, Vector3.new(cx - 24, gy + 0.5, cz - 8), 1.2)
		picnic(parent, Vector3.new(cx - 26, gy + 0.5, cz + 12), 1.8)
		sign(parent, Vector3.new(cx - 30, gy + 0.5, cz), 1.57, "LAKE · NO SWIMMING", rgb(40, 110, 150))
		table.insert(extraLoot, Vector3.new(cx - 14, gy, cz))
		table.insert(extraLoot, Vector3.new(cx - 26, gy + 0.5, cz + 2))
		table.insert(extraContainers, { pos = Vector3.new(cx - 28, gy + 0.5, cz - 14), type = "Locker", yaw = 90 })
	end

	-- the sawmill: an open shed over a saw table, log stacks, a crane arm
	do
		local cx, cz = 94, -50
		local y = pad(cx, cz, 30, 26, M.Ground)
		for _, px in { cx - 11, cx, cx + 11 } do
			for _, pz in { cz - 7, cz + 7 } do
				block(parent, Vector3.new(1, 11, 1), Vector3.new(px, y + 5.5, pz), rgb(104, 76, 52), M.Wood)
			end
		end
		MapKit.wedge(parent, Vector3.new(26, 4, 8.5), CFrame.new(cx, y + 13, cz - 4.2), rgb(150, 70, 56), M.CorrodedMetal)
		MapKit.wedge(parent, Vector3.new(26, 4, 8.5), CFrame.new(cx, y + 13, cz + 4.2) * CFrame.Angles(0, math.pi, 0), rgb(150, 70, 56), M.CorrodedMetal)
		block(parent, Vector3.new(9, 2.2, 3), Vector3.new(cx - 2, y + 1.1, cz), rgb(226, 170, 50), M.Metal) -- the saw table
		local blade = block(parent, Vector3.new(0.2, 3.4, 3.4), Vector3.new(cx - 2, y + 3.2, cz), rgb(196, 200, 204), M.Metal, { Shape = Enum.PartType.Cylinder, CanCollide = false })
		blade.CFrame = CFrame.new(cx - 2, y + 3.2, cz) * CFrame.Angles(0, 0, 0)
		for i = 0, 3 do -- log pile
			for j = 0, 3 - i do
				log(parent, Vector3.new(cx + 6 - 6, y + 0.9 + i * 1.5, cz - 10.5 + j * 1.5 + i * 0.75), Vector3.new(cx + 6 + 6, y + 0.9 + i * 1.5, cz - 10.5 + j * 1.5 + i * 0.75), 0.8, rgb(150, 100, 66))
			end
		end
		for i = 0, 5 do -- sawdust and cut planks
			block(parent, Vector3.new(3, 0.25, 0.7), Vector3.new(cx - 9, y + 0.15 + i * 0.28, cz + 11), rgb(220, 186, 130), M.WoodPlanks)
		end
		sign(parent, Vector3.new(cx - 18, y, cz - 16), 0.2, "RIDGE SAWMILL", rgb(120, 74, 40))
		table.insert(extraLoot, Vector3.new(cx - 8, y, cz + 4))
		table.insert(extraLoot, Vector3.new(cx + 8, y, cz + 9))
		table.insert(extraContainers, { pos = Vector3.new(cx + 12, y, cz + 10), type = "Toolbox", yaw = 180 })
		table.insert(extraContainers, { pos = Vector3.new(cx - 13, y, cz + 9), type = "Drawer", yaw = 90 })
	end

	-- a plank bridge over the creek
	do
		local bz = -6
		local x0, x1 = creekX(bz) - 14, creekX(bz) + 14
		local y0, y1 = baseHeight(x0, bz), baseHeight(x1, bz)
		local deckY = math.max(y0, y1) + 0.5
		for x = x0, x1, 2 do
			block(parent, Vector3.new(2.05, 0.4, 7), Vector3.new(x + 1, deckY, bz), rgb(150, 108, 72), M.WoodPlanks)
		end
		for _, dz in { -3.4, 3.4 } do
			block(parent, Vector3.new(x1 - x0, 0.3, 0.3), Vector3.new((x0 + x1) / 2, deckY + 2.8, bz + dz), rgb(110, 76, 50), M.Wood)
			block(parent, Vector3.new(x1 - x0, 0.3, 0.3), Vector3.new((x0 + x1) / 2, deckY + 1.4, bz + dz), rgb(110, 76, 50), M.Wood)
			for x = x0, x1, 7 do
				block(parent, Vector3.new(0.4, 3.2, 0.4), Vector3.new(x + 1, deckY + 1.4, bz + dz), rgb(96, 70, 48), M.Wood)
			end
		end
		for _, x in { creekX(bz) - 4, creekX(bz) + 4 } do
			block(parent, Vector3.new(1.2, deckY - baseHeight(x, bz) + 2, 1.2), Vector3.new(x, (deckY + baseHeight(x, bz) - 2) / 2, bz - 2.8), rgb(90, 66, 46), M.Wood)
			block(parent, Vector3.new(1.2, deckY - baseHeight(x, bz) + 2, 1.2), Vector3.new(x, (deckY + baseHeight(x, bz) - 2) / 2, bz + 2.8), rgb(90, 66, 46), M.Wood)
		end
	end

	-- a radio mast on the north ridge, wrecks and signposts along the logging road
	do
		local mx, mz = -100, -92
		local my = baseHeight(mx, mz)
		for _, o in { { -1.2, -1.2 }, { 1.2, -1.2 }, { -1.2, 1.2 }, { 1.2, 1.2 } } do
			block(parent, Vector3.new(0.3, 34, 0.3), Vector3.new(mx + o[1], my + 17, mz + o[2]), rgb(196, 60, 52), M.Metal)
		end
		for i = 1, 7 do
			block(parent, Vector3.new(3, 0.2, 0.2), Vector3.new(mx, my + i * 4.6, mz - 1.2), rgb(236, 236, 232), M.Metal, { CanCollide = false })
		end
		local beacon = block(parent, Vector3.new(1, 1, 1), Vector3.new(mx, my + 34.5, mz), rgb(255, 60, 50), M.Neon, { Shape = Enum.PartType.Ball, CanCollide = false })
		local bl = Instance.new("PointLight")
		bl.Color = rgb(255, 60, 50)
		bl.Range = 30
		bl.Parent = beacon
		local road = {
			{ Vector3.new(-48, 0, 92), "CarSedan_2", 0.5 }, { Vector3.new(-10, 0, 66), "CarSedan_1", 2.7 }, { Vector3.new(14, 0, 40), "CarVan_1", 1.0 },
			{ Vector3.new(50, 0, 6), "CarSedan_2", 0.2 }, { Vector3.new(66, 0, -22), "CarSedan_1", 3.0 }, { Vector3.new(-58, 0, 70), "CarVan_1", 2.2 },
		}
		for _, v in road do
			MapKit.prop(parent, v[2], CFrame.new(v[1].X, g(v[1].X, v[1].Z), v[1].Z) * CFrame.Angles(0, v[3], 0))
		end
		sign(parent, Vector3.new(-38, g(-38, 88), 88), 0.4, "NORTH: CAMP · SAWMILL", rgb(46, 96, 62))
		sign(parent, Vector3.new(36, g(36, 12), 12), -0.5, "LAKE 2 MI", rgb(40, 110, 150))
	end

	-- wildflowers in the meadows
	for _ = 1, 26 do
		local x, z = rng:NextNumber(-105, 105), rng:NextNumber(-105, 105)
		if math.abs(x - creekX(z)) > 10 then
			flowerPatch(parent, Vector3.new(x, 0, z), rng:NextNumber(2.5, 5), rng, g)
		end
	end

	-- forest
	local function clear(x, z)
		if math.abs(x - creekX(z)) < 9 then
			return false
		end
		for _, spot in { Vector3.new(55, 0, 48), Vector3.new(-70, 0, -22), Vector3.new(40, 0, -62), Vector3.new(0, 0, 10), Vector3.new(-88, 0, 32) } do
			if (Vector3.new(x, 0, z) - spot).Magnitude < 24 then
				return false
			end
		end
		-- the camp, gas station, lake, sawmill and bridge keep their space
		for _, area in { { -18, -62, 24 }, { 25, 82, 32 }, { 82, 88, 30 }, { 94, -50, 24 }, { creekX(-6), -6, 20 }, { -100, -92, 6 } } do
			if (Vector3.new(x, 0, z) - Vector3.new(area[1], 0, area[2])).Magnitude < area[3] then
				return false
			end
		end
		return true
	end
	local placed = 0
	while placed < 150 do
		local x, z = rng:NextNumber(-115, 115), rng:NextNumber(-115, 115)
		if clear(x, z) and not (z > 70 and x < -20) then -- keep the south-west meadow open
			MapKit.prop(parent, rng:NextNumber() < 0.85 and ("Pine_" .. rng:NextInteger(1, 2)) or "DeadTree_1", CFrame.new(x, g(x, z) - 0.5, z) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), rng:NextNumber(0.75, 1.15))
			placed += 1
		end
	end
	for _ = 1, 34 do
		local x, z = rng:NextNumber(-115, 115), rng:NextNumber(-115, 115)
		if clear(x, z) then
			MapKit.prop(parent, rng:NextNumber() < 0.2 and "Boulder_1" or ("Rock_" .. rng:NextInteger(1, 2)), CFrame.new(x, g(x, z) - 0.6, z) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), rng:NextNumber(0.7, 1.2))
		end
	end
	for _ = 1, 60 do
		local x, z = rng:NextNumber(-115, 115), rng:NextNumber(-115, 115)
		if clear(x, z) then
			MapKit.prop(parent, "Bush_" .. rng:NextInteger(1, 2), CFrame.new(x, g(x, z), z) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), rng:NextNumber(0.8, 1.4))
		end
	end
	-- fallen logs
	for _ = 1, 14 do
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
	-- the edge of the valley is a wooded rock ridge, not a wall: a cliff of rock with a tree line
	MapKit.ridge(baseHeight, 5)
	for i = 1, 90 do
		local edge = rng:NextInteger(1, 4)
		local t = rng:NextNumber(-114, 114)
		local x = edge == 1 and 114 or (edge == 2 and -114 or t)
		local z = edge == 3 and 114 or (edge == 4 and -114 or t)
		if edge <= 2 then
			x += rng:NextNumber(-5, 5)
		else
			z += rng:NextNumber(-5, 5)
		end
		MapKit.prop(parent, "Pine_" .. rng:NextInteger(1, 2), CFrame.new(x, g(x, z) - 0.5, z) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), rng:NextNumber(1.0, 1.5))
		assert(i)
	end
	for _, f in { { Vector3.new(-15, 6, 0), Vector3.new(40, 0, 220) }, { Vector3.new(60, 8, 60), Vector3.new(80, 0, 80) }, { Vector3.new(-60, 8, -60), Vector3.new(80, 0, 80) } } do
		MapKit.fog(parent, f[1], f[2])
	end

	local data = {
		StartSpawns = { Vector3.new(-62, 0, 100), Vector3.new(-58, 0, 102), Vector3.new(-54, 0, 100), Vector3.new(-66, 0, 102) },
		ExtractionPos = Vector3.new(70, 0, -104),
		LanternPos = Vector3.new(0, 0, 32),
		SupplyCandidates = { loot[1], loot[2], loot[4], loot[5], loot[7], loot[8], Vector3.new(-20, 0, -40), Vector3.new(90, 0, 10), Vector3.new(-95, 0, 40), Vector3.new(20, 0, 80) },
		LootSpots = {
			loot[3], loot[6], loot[9], station.loot[1], station.loot[2] or loot[1], station.loot[3] or loot[2], station.loot[4] or loot[4], Vector3.new(-40, 0, 60), Vector3.new(-10, 0, 40), Vector3.new(30, 0, 20), Vector3.new(70, 0, 0),
			Vector3.new(-80, 0, 0), Vector3.new(-50, 0, -70), Vector3.new(0, 0, -60), Vector3.new(60, 0, -90), Vector3.new(90, 0, 60),
			Vector3.new(-90, 0, 70), Vector3.new(20, 0, 100), Vector3.new(-30, 0, -100), Vector3.new(100, 0, -40),
		},
		ContainerSpots = (function()
			for _, c in extraContainers do
				table.insert(containers, c)
			end
			return containers
		end)(),
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
		Doorways = (function()
			for _, d in extraDoors do
				table.insert(doorways, d)
			end
			return doorways
		end)(),
	}
	for _, l in extraLoot do
		table.insert(data.LootSpots, l)
	end
	for _, spot in { Vector3.new(-18, 0, -62), Vector3.new(25, 0, 72), Vector3.new(80, 0, 80), Vector3.new(94, 0, -50) } do
		table.insert(data.SupplyCandidates, spot)
	end
	table.insert(data.PatrolRoutes, { Vector3.new(-18, 0, -48), Vector3.new(-5, 0, -20), Vector3.new(20, 0, 30), Vector3.new(25, 0, 62) })
	table.insert(data.PatrolRoutes, { Vector3.new(60, 0, 80), Vector3.new(80, 0, 70), Vector3.new(95, 0, 60) })
	table.insert(data.PatrolRoutes, { Vector3.new(94, 0, -34), Vector3.new(80, 0, -70), Vector3.new(60, 0, -95) })
	return data
end

return Map
