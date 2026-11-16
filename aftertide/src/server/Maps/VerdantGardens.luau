--!nonstrict
-- VERDANT GARDENS: an abandoned botanical garden grown wild: a hedge maze, two glasshouses full
-- of planters, a fountain plaza, gazebo, statues, flower beds and a orangery cafe. Bright and green.
local MapKit = require(script.Parent.MapKit)
local Gen = require(script.Parent.MapGen)
local V, rgb = Vector3.new, Gen.rgb
local block = MapKit.block

local Map = {
	id = "VerdantGardens",
	name = "Verdant Gardens",
	lighting = { sky = "ferry", clouds = 0.35, cloudDensity = 0.5, cloudColor = { 255, 255, 255 }, wind = { 5, 0, 3 }, clock = 13.0, brightness = 3.3, ambient = { 112, 120, 112 }, outdoor = { 160, 168, 156 }, fog = 0.14, haze = 0.5, fogColor = { 214, 232, 236 }, tint = { 252, 255, 246 }, saturation = 0.22, contrast = 0.08, shift = { 255, 238, 214 } },
}

local HEDGE = rgb(52, 118, 46)

-- A square hedge maze (recursive backtracker). Returns the centre cell position.
local function maze(gen, x0, z0, n, cell)
	local rng = gen.rng
	local y = gen.flatY
	local open = {} -- open[i][j] = { N, S, E, W } removed walls
	for i = 1, n do
		open[i] = {}
		for j = 1, n do
			open[i][j] = { visited = false, E = false, S = false }
		end
	end
	local function carve(i, j)
		open[i][j].visited = true
		local dirs = { { 1, 0, "S" }, { -1, 0, "N" }, { 0, 1, "E" }, { 0, -1, "W" } }
		for k = #dirs, 2, -1 do
			local r = rng:NextInteger(1, k)
			dirs[k], dirs[r] = dirs[r], dirs[k]
		end
		for _, d in dirs do
			local ni, nj = i + d[1], j + d[2]
			if ni >= 1 and ni <= n and nj >= 1 and nj <= n and not open[ni][nj].visited then
				if d[3] == "S" then
					open[i][j].S = true
				elseif d[3] == "N" then
					open[ni][nj].S = true
				elseif d[3] == "E" then
					open[i][j].E = true
				else
					open[ni][nj].E = true
				end
				carve(ni, nj)
			end
		end
	end
	carve(1, 1)
	local function wall(x, z, w, d)
		block(gen.parent, V(w, 6, d), V(x, y + 3, z), HEDGE, Enum.Material.LeafyGrass)
	end
	local size = n * cell
	-- outer walls with an entrance on the south-west corner
	wall(x0 + size / 2, z0, size, 1.4)
	wall(x0 + size / 2, z0 + size, size, 1.4)
	wall(x0, z0 + size / 2 + cell / 2, 1.4, size - cell)
	wall(x0 + size, z0 + size / 2, 1.4, size)
	for i = 1, n do
		for j = 1, n do
			local cx, cz = x0 + (j - 0.5) * cell, z0 + (i - 0.5) * cell
			if not open[i][j].E and j < n then
				wall(cx + cell / 2, cz, 1.4, cell + 1.4)
			end
			if not open[i][j].S and i < n then
				wall(cx, cz + cell / 2, cell + 1.4, 1.4)
			end
		end
	end
	gen:zone(x0 + size / 2, z0 + size / 2, size * 0.72)
	local mid = V(x0 + (math.floor(n / 2) + 0.5) * cell, y, z0 + (math.floor(n / 2) + 0.5) * cell)
	-- a statue and a chest at the heart of it
	block(gen.parent, V(2.4, 1.4, 2.4), mid + V(0, 0.7, 0), rgb(200, 196, 188), Enum.Material.Marble)
	block(gen.parent, V(1.2, 3, 1.2), mid + V(0, 2.9, 0), rgb(220, 216, 208), Enum.Material.Marble)
	block(gen.parent, V(1.6, 1.6, 1.6), mid + V(0, 5, 0), rgb(220, 216, 208), Enum.Material.Marble, { Shape = Enum.PartType.Ball })
	gen:container(mid.X + 3, mid.Z, "AmmoCrate", 0)
	gen:lootAt(mid.X, mid.Z + 3)
	return mid
end

local function glasshouse(gen, cx, cz, w, d, yaw)
	local y = gen.flatY
	local cf = CFrame.new(cx, y, cz) * CFrame.Angles(0, yaw, 0)
	local frame = rgb(236, 238, 236)
	local glass = rgb(150, 200, 210)
	local H = 11
	block(gen.parent, V(w, 0.6, d), cf * CFrame.new(0, 0.3, 0), rgb(150, 150, 146), Enum.Material.Concrete)
	-- long walls: glass panels between frame posts
	for _, sz in { -d / 2, d / 2 } do
		block(gen.parent, V(w, H, 0.3), cf * CFrame.new(0, H / 2, sz), glass, Enum.Material.Glass, { Transparency = 0.55 })
		for x = -w / 2, w / 2, 6 do
			block(gen.parent, V(0.4, H + 3, 0.4), cf * CFrame.new(x, (H + 3) / 2, sz), frame, Enum.Material.Metal)
		end
	end
	-- end walls with a doorway in the middle
	for _, sx in { -w / 2, w / 2 } do
		for _, off in { -d / 2 + (d / 2 - 3) / 2, d / 2 - (d / 2 - 3) / 2 } do
			block(gen.parent, V(0.3, H, d / 2 - 3), cf * CFrame.new(sx, H / 2, off), glass, Enum.Material.Glass, { Transparency = 0.55 })
		end
		block(gen.parent, V(0.3, H - 8, 6), cf * CFrame.new(sx, 8 + (H - 8) / 2, 0), glass, Enum.Material.Glass, { Transparency = 0.55 })
	end
	-- a pitched glass roof
	MapKit.wedge(gen.parent, V(w + 0.6, 4.5, d / 2 + 0.3), cf * CFrame.new(0, H + 2.25, -d / 4), glass, Enum.Material.Glass)
	MapKit.wedge(gen.parent, V(w + 0.6, 4.5, d / 2 + 0.3), cf * CFrame.new(0, H + 2.25, d / 4) * CFrame.Angles(0, math.pi, 0), glass, Enum.Material.Glass)
	for _, mesh in gen.parent:GetChildren() do
		if mesh:IsA("WedgePart") and mesh.Material == Enum.Material.Glass then
			mesh.Transparency = 0.55
		end
	end
	-- planters of lush leaves
	for i = -2, 2 do
		for _, sz in { -d / 2 + 3, d / 2 - 3 } do
			block(gen.parent, V(5, 1.6, 2.4), cf * CFrame.new(i * 7, 1, sz), rgb(150, 100, 70), Enum.Material.Brick)
			block(gen.parent, V(4.2, 3, 2.4), cf * CFrame.new(i * 7, 3, sz), rgb(60, 140, 60), Enum.Material.LeafyGrass, { Shape = Enum.PartType.Ball, CanCollide = false })
		end
	end
	MapKit.bulb(gen.parent, cf.Position + V(0, H - 1, 0), 22)
	gen:zone(cx, cz, math.max(w, d) / 2 + 3)
	gen:container(cx + 6, cz + 2, "Toolbox", 0)
	gen:container(cx - 8, cz - 2, "Drawer", 90)
	gen:lootAt(cx, cz)
	gen:lootAt(cx + 12, cz + 3)
	table.insert(gen.doors, { hinge = (cf * CFrame.new(-w / 2, 0, -3)).Position, width = 6, dir = cf.LookVector })
end

function Map.build(parent, rng)
	local M = Enum.Material
	local gen = Gen.new(parent, rng)
	MapKit.outskirts("suburb")
	MapKit.slab(-120, -120, 120, 120, M.Grass, 0)
	-- paved paths: a cross and a plaza
	MapKit.slab(-120, -5, 120, 5, M.Pavement, 0.1)
	MapKit.slab(-5, -120, 5, 120, M.Pavement, 0.1)
	MapKit.slab(-20, -20, 20, 20, M.Pavement, 0.1)
	local y = gen:flat()

	-- the fountain
	block(parent, V(1.6, 16, 16), V(0, y + 0.8, 0), rgb(196, 192, 184), M.Marble, { Shape = Enum.PartType.Cylinder, CFrame = CFrame.new(0, y + 0.8, 0) * CFrame.Angles(0, 0, math.pi / 2) })
	block(parent, V(0.8, 14.4, 14.4), V(0, y + 1.5, 0), rgb(70, 150, 190), M.Glass, { Shape = Enum.PartType.Cylinder, CFrame = CFrame.new(0, y + 1.5, 0) * CFrame.Angles(0, 0, math.pi / 2), Transparency = 0.35, CanCollide = false })
	block(parent, V(7, 3, 3), V(0, y + 3.5, 0), rgb(210, 206, 198), M.Marble, { Shape = Enum.PartType.Cylinder, CFrame = CFrame.new(0, y + 3.5, 0) * CFrame.Angles(0, 0, math.pi / 2) })
	block(parent, V(5, 2.2, 2.2), V(0, y + 6.5, 0), rgb(210, 206, 198), M.Marble, { Shape = Enum.PartType.Cylinder, CFrame = CFrame.new(0, y + 6.5, 0) * CFrame.Angles(0, 0, math.pi / 2) })
	local spray = Instance.new("ParticleEmitter")
	spray.Texture = "rbxasset://textures/particles/smoke_main.dds"
	spray.Rate = 22
	spray.Lifetime = NumberRange.new(1.2, 1.8)
	spray.Speed = NumberRange.new(6, 9)
	spray.SpreadAngle = Vector2.new(25, 25)
	spray.Acceleration = Vector3.new(0, -14, 0)
	spray.Size = NumberSequence.new(0.5, 0.2)
	spray.Transparency = NumberSequence.new(0.4, 1)
	spray.Color = ColorSequence.new(rgb(200, 230, 255))
	spray.Parent = block(parent, V(1, 1, 1), V(0, y + 8, 0), rgb(255, 255, 255), M.SmoothPlastic, { Transparency = 1, CanCollide = false, CanQuery = false })
	gen:zone(0, 0, 11)
	for a = 0, 3 do -- benches round the plaza
		local ang = a * math.pi / 2 + math.pi / 4
		block(parent, V(4.4, 0.4, 1.2), CFrame.new(math.cos(ang) * 14, y + 1.4, math.sin(ang) * 14) * CFrame.Angles(0, -ang + math.pi / 2, 0), rgb(150, 104, 66), M.WoodPlanks)
		gen:zone(math.cos(ang) * 14, math.sin(ang) * 14, 3)
	end

	-- hedge maze in the south-west, glasshouses north-east and south-east
	maze(gen, -105, -105, 8, 7.5)
	glasshouse(gen, 62, 62, 40, 22, 0)
	glasshouse(gen, 62, -62, 40, 22, 0)

	-- the gazebo: eight posts and a pointed roof
	local gx, gz = -62, 62
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		block(parent, V(0.6, 8, 0.6), V(gx + math.cos(a) * 6, y + 4, gz + math.sin(a) * 6), rgb(244, 242, 236), M.Wood)
	end
	block(parent, V(14, 0.8, 14), V(gx, y + 8.4, gz), rgb(244, 242, 236), M.Wood)
	for i = 1, 4 do
		block(parent, V(14 - i * 3, 1.2, 14 - i * 3), V(gx, y + 8.8 + i * 1.1, gz), rgb(70, 130, 110), M.Metal)
	end
	gen:zone(gx, gz, 9)
	gen:lootAt(gx, gz)

	-- the orangery cafe: a shop building with a courtyard
	gen:house(V(-60, y, -60), 0, { kind = "shop", w = 28, d = 20 })
	gen:house(V(100, y, 0), math.pi / 2, { kind = "house", w = 22, d = 20 })

	-- statues, urns, flower beds
	for _ = 1, 8 do
		local x, z = gen:open(-108, -108, 108, 108, 8)
		if x then
			block(parent, V(2.2, 1.4, 2.2), V(x, y + 0.7, z), rgb(200, 196, 188), M.Marble)
			block(parent, V(1, 3.6, 1), V(x, y + 3.2, z), rgb(222, 218, 210), M.Marble)
			block(parent, V(1.4, 1.4, 1.4), V(x, y + 5.6, z), rgb(222, 218, 210), M.Marble, { Shape = Enum.PartType.Ball })
			gen:zone(x, z, 2.6)
		end
	end
	for _ = 1, 40 do
		local x, z = gen:open(-108, -108, 108, 108, 3)
		if x then
			gen:flowers(V(x, y, z), rng:NextNumber(2, 5))
		end
	end
	gen:scatter({ "Bush_1", "Bush_2" }, 70, -112, -112, 112, 112, 1.0, 1.8, 0, 3)
	gen:scatter({ "Pine_1", "Pine_2", "DeadTree_1" }, 18, -112, -112, 112, 112, 0.7, 1.0, 0.4, 5)
	MapKit.tallGrass(parent, V(-40, y, 100), V(50, 0, 20), rng, nil, 0.9)
	MapKit.tallGrass(parent, V(40, y, -100), V(50, 0, 20), rng, nil, 0.9)
	gen:fence(rgb(36, 60, 44), 8, 4)

	return gen:finish({
		start = { V(100, 3, -100), V(96, 3, -102), V(104, 3, -96), V(92, 3, -98) },
		extraction = V(-104, 0, 100),
		lantern = V(0, 0, -30),
	})
end

return Map
