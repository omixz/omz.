--!nonstrict
-- Shared building blocks for the encounter maps: parts, volumes, walls, lights, terrain,
-- grass, props (sculpted meshes when loaded, part fallbacks otherwise) and houses.
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local MeshKit = require(Shared.MeshKit)

local MapKit = {}
local Assets -- AssetService, set by MapService

local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

MapKit.C = {
	ground = Color3.fromRGB(70, 72, 70),
	wall = Color3.fromRGB(96, 94, 88),
	wallDark = Color3.fromRGB(70, 70, 68),
	roof = Color3.fromRGB(74, 70, 64),
	metal = Color3.fromRGB(46, 48, 50),
	crate = Color3.fromRGB(92, 72, 52),
	machine = Color3.fromRGB(70, 78, 80),
	bone = Color3.fromRGB(226, 220, 206),
	water = Color3.fromRGB(52, 70, 74),
	reed = Color3.fromRGB(110, 112, 76),
	warm = Color3.fromRGB(255, 196, 130),
	containers = { Color3.fromRGB(120, 58, 44), Color3.fromRGB(44, 86, 88), Color3.fromRGB(58, 68, 90), Color3.fromRGB(140, 112, 56) },
}
local C = MapKit.C

function MapKit.setAssets(assetService)
	Assets = assetService
end

function MapKit.block(parent, size, position, color, material, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.CFrame = typeof(position) == "CFrame" and position or CFrame.new(position)
	p.Color = color
	p.Material = material or Enum.Material.Concrete
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props then
		for key, value in props do
			p[key] = value
		end
	end
	p.Parent = parent
	return p
end
local block = MapKit.block

function MapKit.wedge(parent, size, cframe, color, material)
	local w = Instance.new("WedgePart")
	w.Anchored = true
	w.Size = size
	w.CFrame = cframe
	w.Color = color
	w.Material = material
	w.Parent = parent
	return w
end

function MapKit.volume(parent, size, position, tag)
	local p = block(parent, size, position, Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, {
		Name = tag,
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
	})
	CollectionService:AddTag(p, tag)
	return p
end

local function splitGaps(a, b, gaps)
	local segments, cursor = {}, a
	table.sort(gaps, function(x, y)
		return x[1] < y[1]
	end)
	for _, gap in gaps do
		if gap[1] > cursor then
			table.insert(segments, { cursor, gap[1] })
		end
		cursor = math.max(cursor, gap[2])
	end
	if b > cursor then
		table.insert(segments, { cursor, b })
	end
	return segments
end

-- Wall along X at depth z (y0 = base height), door gaps {{x1,x2}} with lintels.
function MapKit.wallX(parent, z, x1, x2, height, gaps, color, material, y0)
	y0 = y0 or 0
	for _, s in splitGaps(x1, x2, gaps or {}) do
		block(parent, Vector3.new(s[2] - s[1], height, 1.2), Vector3.new((s[1] + s[2]) / 2, y0 + height / 2, z), color, material)
	end
	for _, g in gaps or {} do
		if height > 9 then
			block(parent, Vector3.new(g[2] - g[1], height - 9, 1.2), Vector3.new((g[1] + g[2]) / 2, y0 + 9 + (height - 9) / 2, z), color, material)
		end
	end
end

function MapKit.wallZ(parent, x, z1, z2, height, gaps, color, material, y0)
	y0 = y0 or 0
	for _, s in splitGaps(z1, z2, gaps or {}) do
		block(parent, Vector3.new(1.2, height, s[2] - s[1]), Vector3.new(x, y0 + height / 2, (s[1] + s[2]) / 2), color, material)
	end
	for _, g in gaps or {} do
		if height > 9 then
			block(parent, Vector3.new(1.2, height - 9, g[2] - g[1]), Vector3.new(x, y0 + 9 + (height - 9) / 2, (g[1] + g[2]) / 2), color, material)
		end
	end
end

function MapKit.lamp(parent, base, lit)
	block(parent, Vector3.new(0.6, 12, 0.6), base + Vector3.new(0, 6, 0), C.metal, Enum.Material.Metal)
	block(parent, Vector3.new(0.3, 0.3, 2.4), base + Vector3.new(0, 11.9, -1.1), C.metal, Enum.Material.Metal)
	local head = block(parent, Vector3.new(1.4, 0.5, 1.0), base + Vector3.new(0, 11.7, -2.2), lit == false and C.metal or C.warm, lit == false and Enum.Material.Metal or Enum.Material.Neon)
	if lit ~= false then
		local light = Instance.new("SpotLight")
		light.Face = Enum.NormalId.Bottom
		light.Range = 28
		light.Angle = 100
		light.Brightness = 2
		light.Color = C.warm
		light.Shadows = true
		light.Parent = head
		MapKit.volume(parent, Vector3.new(20, 10, 20), base + Vector3.new(0, 5, -2), "LitZone")
	end
end

function MapKit.bulb(parent, position, range)
	local bulb = block(parent, Vector3.new(0.7, 0.7, 0.7), position, C.warm, Enum.Material.Neon, { Shape = Enum.PartType.Ball, CanCollide = false })
	local light = Instance.new("PointLight")
	light.Range = range or 18
	light.Brightness = 1.3
	light.Color = C.warm
	light.Shadows = true
	light.Parent = bulb
	MapKit.volume(parent, Vector3.new(14, 10, 14), Vector3.new(position.X, position.Y - 6, position.Z), "LitZone")
end

function MapKit.fog(parent, position, size)
	local p = block(parent, Vector3.new(size.X, 1, size.Z), position, Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
	})
	local e = Instance.new("ParticleEmitter")
	e.Texture = SMOKE
	e.Rate = 1.2
	e.Lifetime = NumberRange.new(14, 20)
	e.Speed = NumberRange.new(0.3, 1)
	e.SpreadAngle = Vector2.new(60, 60)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-4, 4)
	e.LightInfluence = 1
	e.Color = ColorSequence.new(Color3.fromRGB(215, 220, 220))
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 16), NumberSequenceKeypoint.new(1, 28) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.9), NumberSequenceKeypoint.new(0.7, 0.92), NumberSequenceKeypoint.new(1, 1) })
	e.Drag = 0.4
	e.WindAffectsDrag = true -- fog drifts with the map's wind
	e.Parent = p
end

-- Terrain --------------------------------------------------------------------------------------

local terrain = Workspace.Terrain

function MapKit.clearTerrain()
	terrain:Clear()
	pcall(function()
		terrain.Decoration = true -- animated grass blades on Grass terrain
	end)
	terrain.WaterColor = Color3.fromRGB(38, 56, 60)
	terrain.WaterTransparency = 0.55
	terrain.WaterReflectance = 0.6
	terrain.WaterWaveSize = 0.08
	terrain.WaterWaveSpeed = 6
end

-- A flat slab of terrain material whose top surface is at y = top.
function MapKit.slab(x0, z0, x1, z1, material, top, depth)
	depth = depth or 8
	local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
	terrain:FillBlock(CFrame.new(cx, top - depth / 2, cz), Vector3.new(math.abs(x1 - x0), depth, math.abs(z1 - z0)), material)
end

-- Removes terrain above height y in a rectangle (carving dips, clearing for water).
function MapKit.clearAbove(x0, z0, x1, z1, y)
	local top = 60
	terrain:FillBlock(CFrame.new((x0 + x1) / 2, (y + top) / 2, (z0 + z1) / 2), Vector3.new(math.abs(x1 - x0), top - y, math.abs(z1 - z0)), Enum.Material.Air)
end

function MapKit.water(x0, z0, x1, z1, surface, depth)
	local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
	terrain:FillBlock(CFrame.new(cx, surface - depth / 2, cz), Vector3.new(math.abs(x1 - x0), depth, math.abs(z1 - z0)), Enum.Material.Water)
end

-- Rolling ground: columns of terrain following heightFn(x, z), material by materialFn.
function MapKit.heightfield(x0, z0, x1, z1, step, heightFn, materialFn)
	for x = x0, x1 - step, step do
		for z = z0, z1 - step, step do
			local h = heightFn(x + step / 2, z + step / 2)
			terrain:FillBlock(CFrame.new(x + step / 2, (h - 12) / 2, z + step / 2), Vector3.new(step, h + 12, step), materialFn(x, z, h))
		end
	end
end

-- Surface height at (x, z) (terrain or parts), for placing things on hills.
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
groundParams.IgnoreWater = true
function MapKit.ground(x, z, include)
	groundParams.FilterDescendantsInstances = include or { terrain }
	-- walk down through every surface (roofs, ceilings, floors, props) to the terrain, then
	-- pick the lowest non-prop surface that sits close to the terrain (a floor), else terrain
	local origin = Vector3.new(x, 300, z)
	local surfaces = {}
	local terrainY = nil
	for _ = 1, 10 do
		local hit = Workspace:Raycast(origin, Vector3.new(0, -600, 0), groundParams)
		if not hit then
			break
		end
		if hit.Instance == terrain then
			terrainY = hit.Position.Y
			break
		end
		local inProp = hit.Instance.Parent and hit.Instance.Parent:IsA("Model")
		if not inProp and hit.Normal.Y > 0.7 then
			table.insert(surfaces, hit.Position.Y)
		end
		origin = hit.Position - Vector3.new(0, 0.05, 0)
	end
	local base = terrainY or 0
	local best = base
	for _, y in surfaces do
		if y - base < 2.5 and y > best then
			best = y
		end
	end
	return best
end

function MapKit.onGround(v, include)
	return Vector3.new(v.X, MapKit.ground(v.X, v.Z, include), v.Z)
end

-- Props ------------------------------------------------------------------------------------------

local FALLBACK = {}
function FALLBACK.rock(parent, cf, scale)
	block(parent, Vector3.new(4, 2.6, 3.4) * scale, cf * CFrame.new(0, 1.1 * scale, 0) * CFrame.Angles(0.2, 0.7, 0.1), Color3.fromRGB(104, 102, 98), Enum.Material.Rock)
end
function FALLBACK.tree(parent, cf, scale)
	block(parent, Vector3.new(1.2, 14, 1.2) * scale, cf * CFrame.new(0, 7 * scale, 0), Color3.fromRGB(70, 54, 42), Enum.Material.Wood)
	block(parent, Vector3.new(9, 12, 9) * scale, cf * CFrame.new(0, 15 * scale, 0), Color3.fromRGB(40, 56, 36), Enum.Material.LeafyGrass, { Shape = Enum.PartType.Ball })
end
function FALLBACK.car(parent, cf, scale)
	block(parent, Vector3.new(4, 1.4, 9) * scale, cf * CFrame.new(0, 1.3 * scale, 0), Color3.fromRGB(90, 96, 98), Enum.Material.Metal)
	block(parent, Vector3.new(3.6, 1.2, 4.6) * scale, cf * CFrame.new(0, 2.6 * scale, 0.4), Color3.fromRGB(40, 44, 46), Enum.Material.Glass)
end
function FALLBACK.bush(parent, cf, scale)
	block(parent, Vector3.new(3, 2.4, 3) * scale, cf * CFrame.new(0, 1.2 * scale, 0), Color3.fromRGB(46, 62, 40), Enum.Material.LeafyGrass, { Shape = Enum.PartType.Ball, CanCollide = false })
end

local KIND = {
	Rock_1 = "rock", Rock_2 = "rock", Boulder_1 = "rock",
	Pine_1 = "tree", Pine_2 = "tree", DeadTree_1 = "tree",
	CarSedan_1 = "car", CarSedan_2 = "car", CarVan_1 = "car",
	Bush_1 = "bush", Bush_2 = "bush",
}

-- Place a sculpted prop (or a simple stand-in). cf = ground point + facing.
function MapKit.prop(parent, name, cf, scale)
	scale = scale or 1
	if Assets and Assets.hasKit(name) then
		local m = MeshKit.buildProp(Assets.meta(name), Assets.part, cf, scale, parent)
		if m then
			if KIND[name] == "car" or KIND[name] == "rock" then
				for _, p in m:GetChildren() do
					if p:IsA("BasePart") then
						p.CanCollide = true
					end
				end
			else
				for _, p in m:GetChildren() do
					if p:IsA("BasePart") then
						p.CanCollide = KIND[name] == "tree" and p.Name == "Trunk"
					end
				end
			end
			return m
		end
	end
	local fb = FALLBACK[KIND[name] or ""]
	if fb then
		fb(parent, cf, scale)
	end
	return nil
end

-- Grass ------------------------------------------------------------------------------------------

local function grassMesh(parent, name, cf, scale)
	if Assets and Assets.hasKit(name) then
		local m = MeshKit.buildProp(Assets.meta(name), Assets.part, cf, scale, parent)
		if m then
			for _, p in m:GetChildren() do
				if p:IsA("BasePart") then
					p.CanCollide = false
					p.CanQuery = false
					p.CanTouch = false
					p.CastShadow = false
				end
			end
			return true
		end
	end
	return false
end

-- A patch of tall grass you can hide in (stealth volume + clumps).
-- groundFn(x, z) gives the height (default flat 0).
function MapKit.tallGrass(parent, center, size, rng, groundFn, density)
	-- on hills the hiding volume follows the ground at the patch centre and is taller
	local gy = groundFn and groundFn(center.X, center.Z) or center.Y
	local vh = groundFn and 22 or 7
	MapKit.volume(parent, Vector3.new(size.X, vh, size.Z), Vector3.new(center.X, gy + (groundFn and 4 or 3.5), center.Z), "TallGrass")
	local count = math.floor(size.X * size.Z / 7 * (density or 1))
	for _ = 1, count do
		local x = center.X + rng:NextNumber(-size.X / 2, size.X / 2)
		local z = center.Z + rng:NextNumber(-size.Z / 2, size.Z / 2)
		local y = groundFn and groundFn(x, z) or center.Y
		local cf = CFrame.new(x, y, z) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0)
		if not grassMesh(parent, "GrassTall_" .. rng:NextInteger(1, 3), cf, rng:NextNumber(0.85, 1.2)) then
			local h = rng:NextNumber(3.6, 5.6)
			block(parent, Vector3.new(0.22, h, 0.22), CFrame.new(x, y + h / 2, z) * CFrame.Angles(rng:NextNumber(-0.18, 0.18), rng:NextNumber(0, 6.28), rng:NextNumber(-0.18, 0.18)), C.reed, Enum.Material.Grass, {
				CanCollide = false,
				CanQuery = false,
				CanTouch = false,
				CastShadow = false,
			})
		end
	end
end

-- Short grass and ferns sprinkled over an area (decorative only).
function MapKit.shortGrass(parent, center, size, count, rng, groundFn, ferns)
	if not (Assets and Assets.hasKit("GrassShort_1")) then
		return
	end
	for _ = 1, count do
		local x = center.X + rng:NextNumber(-size.X / 2, size.X / 2)
		local z = center.Z + rng:NextNumber(-size.Z / 2, size.Z / 2)
		local y = groundFn and groundFn(x, z) or center.Y
		local name = (ferns and rng:NextNumber() < 0.3) and "Fern_1" or ("GrassShort_" .. rng:NextInteger(1, 2))
		grassMesh(parent, name, CFrame.new(x, y, z) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), rng:NextNumber(0.8, 1.3))
	end
end

-- Houses -------------------------------------------------------------------------------------------

-- A weatherboard house. origin = front-door ground point, facing = yaw (radians,
-- front faces -Z when 0). Returns { doorways = {...}, containers = {...}, loot = {...} }.
function MapKit.house(parent, origin, yaw, rng, style)
	style = style or {}
	local W, D, H = style.w or 26, style.d or 22, style.h or 11
	local cf = CFrame.new(origin) * CFrame.Angles(0, yaw, 0)
	local function at(x, y, z)
		return cf * CFrame.new(x, y, z)
	end
	local siding = style.color or ({ Color3.fromRGB(150, 156, 150), Color3.fromRGB(176, 160, 132), Color3.fromRGB(120, 132, 140), Color3.fromRGB(168, 150, 140) })[rng:NextInteger(1, 4)]
	local trim = Color3.fromRGB(200, 196, 186)
	local wallMat = Enum.Material.WoodPlanks
	local function wall(size, pos)
		return block(parent, size, at(pos.X, pos.Y, pos.Z), siding, wallMat)
	end
	-- floor + porch
	block(parent, Vector3.new(W, 1, D), at(0, 0.5, D / 2), Color3.fromRGB(96, 82, 66), Enum.Material.WoodPlanks)
	block(parent, Vector3.new(10, 0.8, 5), at(0, 0.4, -2.5), Color3.fromRGB(110, 96, 80), Enum.Material.WoodPlanks)
	for _, sx in { -4.5, 4.5 } do
		block(parent, Vector3.new(0.5, H - 1, 0.5), at(sx, H / 2, -4.6), trim, Enum.Material.Wood)
	end
	block(parent, Vector3.new(11, 0.5, 6), at(0, H - 0.6, -2.4), C.roof, Enum.Material.RoofShingles)
	-- walls: front (door gap + windows), back, sides
	local t = 1
	local doorW = 5
	wall(Vector3.new((W - doorW) / 2, H, t), Vector3.new(-(W + doorW) / 4, H / 2, 0))
	wall(Vector3.new((W - doorW) / 2, H, t), Vector3.new((W + doorW) / 4, H / 2, 0))
	wall(Vector3.new(doorW, H - 8, t), Vector3.new(0, 8 + (H - 8) / 2, 0))
	wall(Vector3.new(W, H, t), Vector3.new(0, H / 2, D))
	wall(Vector3.new(t, H, D), Vector3.new(-W / 2, H / 2, D / 2))
	wall(Vector3.new(t, H, D), Vector3.new(W / 2, H / 2, D / 2))
	-- windows (dark glass with trim) on front and sides
	for _, wx in { -W * 0.32, W * 0.32 } do
		block(parent, Vector3.new(4, 3.4, 0.3), at(wx, 5.2, -0.6), Color3.fromRGB(30, 34, 36), Enum.Material.Glass, { Transparency = 0.25 })
		block(parent, Vector3.new(4.6, 0.3, 0.6), at(wx, 3.4, -0.7), trim, Enum.Material.Wood)
	end
	for _, sz in { D * 0.3, D * 0.7 } do
		for _, sx in { -1, 1 } do
			block(parent, Vector3.new(0.3, 3.4, 4), at(sx * (W / 2 + 0.6), 5.2, sz), Color3.fromRGB(30, 34, 36), Enum.Material.Glass, { Transparency = 0.25 })
		end
	end
	-- interior: one partition with a doorway, a few furniture blocks
	wall(Vector3.new(W * 0.35, H, t), Vector3.new(-W * 0.325, H / 2, D * 0.55))
	wall(Vector3.new(W * 0.35, H, t), Vector3.new(W * 0.325, H / 2, D * 0.55))
	block(parent, Vector3.new(6, 2.4, 3), at(-W * 0.3, 1.7, D * 0.3), Color3.fromRGB(86, 70, 60), Enum.Material.Fabric) -- sofa
	block(parent, Vector3.new(5, 3, 2.5), at(W * 0.3, 2, D * 0.85), Color3.fromRGB(120, 110, 96), Enum.Material.Wood) -- counter
	-- roof: two sloped wedges
	local rise = 7
	-- WedgePart: tall edge at +Z, slope descending to -Z
	MapKit.wedge(parent, Vector3.new(W + 2, rise, D / 2 + 1), at(0, H + rise / 2, D * 0.25 - 0.5), C.roof, Enum.Material.RoofShingles)
	MapKit.wedge(parent, Vector3.new(W + 2, rise, D / 2 + 1), at(0, H + rise / 2, D * 0.75 + 0.5) * CFrame.Angles(0, math.pi, 0), C.roof, Enum.Material.RoofShingles)
	block(parent, Vector3.new(W, 1, D), at(0, H + 0.5, D / 2), siding, wallMat) -- ceiling
	-- a dim lamp inside
	MapKit.bulb(parent, at(0, H - 1.5, D * 0.3).Position, 16)
	local function world(x, z)
		return at(x, 0, z).Position
	end
	return {
		doorways = { { hinge = world(-doorW / 2, -0.1), width = doorW, dir = cf.RightVector } },
		containers = {
			{ pos = world(-W * 0.38, D * 0.85), type = "Drawer", yaw = math.deg(yaw) + 180 },
			{ pos = world(W * 0.4, D * 0.4), type = rng:NextNumber() < 0.5 and "Locker" or "Toolbox", yaw = math.deg(yaw) - 90 },
		},
		loot = { world(0, D * 0.3), world(-W * 0.25, D * 0.75), world(W * 0.2, D * 0.25) },
	}
end

return MapKit
