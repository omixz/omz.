--!nonstrict
-- WHITEOUT DEPOT: a snowbound railway depot: three tracks with parked freight and a locomotive,
-- a platform with a canopy and station house, a signal tower, a water tower and coal shed.
-- Snow falls all the time. Cold blue morning.
local MapKit = require(script.Parent.MapKit)
local Gen = require(script.Parent.MapGen)
local V, rgb = Vector3.new, Gen.rgb
local block = MapKit.block

local Map = {
	id = "WhiteoutDepot",
	name = "Whiteout Depot",
	lighting = { sky = "pines", clouds = 0.85, cloudDensity = 0.8, cloudColor = { 232, 238, 246 }, wind = { 12, 0, 6 }, clock = 10.2, brightness = 2.5, ambient = { 110, 118, 132 }, outdoor = { 150, 160, 176 }, fog = 0.5, haze = 1.9, fogColor = { 226, 234, 246 }, tint = { 226, 238, 255 }, saturation = -0.05, contrast = 0.1, shift = { 232, 238, 255 } },
}

local function track(gen, z, y)
	local M = Enum.Material
	for _, s in { -1.1, 1.1 } do
		block(gen.parent, V(236, 0.35, 0.3), V(0, y + 0.75, z + s), rgb(100, 100, 104), M.Metal, { CanCollide = false })
	end
	for x = -116, 116, 3 do
		block(gen.parent, V(0.8, 0.4, 3.8), V(x, y + 0.45, z), rgb(70, 56, 46), M.Wood, { CanCollide = false })
	end
	block(gen.parent, V(236, 0.5, 5.6), V(0, y + 0.2, z), rgb(150, 150, 154), M.Pebble, { CanCollide = false })
end

local function boxcar(gen, x, z, y, color)
	local M = Enum.Material
	block(gen.parent, V(24, 11, 8.4), V(x, y + 7.2, z), color, M.CorrodedMetal)
	block(gen.parent, V(24.6, 0.6, 9), V(x, y + 12.9, z), rgb(60, 60, 64), M.Metal, { CanCollide = false })
	block(gen.parent, V(24, 1.2, 8), V(x, y + 1.6, z), rgb(50, 50, 54), M.Metal)
	for _, wx in { -9, -6, 6, 9 } do
		for _, wz in { -4, 4 } do
			block(gen.parent, V(2.6, 2.6, 0.6), V(x + wx, y + 1.3, z + wz), rgb(36, 36, 40), M.Metal, { Shape = Enum.PartType.Cylinder, CFrame = CFrame.new(x + wx, y + 1.3, z + wz) * CFrame.Angles(0, math.pi / 2, 0), CanCollide = false })
		end
	end
	-- a sliding door standing open on the south side, with a ramp of snow up to it
	block(gen.parent, V(7, 9, 0.3), V(x + 3, y + 7, z - 4.3), rgb(40, 38, 36), M.Metal, { CanCollide = false })
	gen:zone(x, z, 13)
end

function Map.build(parent, rng)
	local M = Enum.Material
	local gen = Gen.new(parent, rng)
	MapKit.outskirts("forest")
	MapKit.slab(-120, -120, 120, 120, M.Snow, 0)
	local y = gen:flat()

	for _, z in { -34, 0, 34 } do
		track(gen, z, y)
		for x = -112, 112, 14 do
			gen:zone(x, z, 5)
		end
	end

	-- freight: boxcars, a tank car and a locomotive on the middle track, more on the others
	local colors = { rgb(150, 56, 46), rgb(70, 100, 76), rgb(120, 84, 56), rgb(70, 86, 120), rgb(170, 150, 110) }
	for i = 0, 3 do
		boxcar(gen, -88 + i * 26, 0, y, colors[i % #colors + 1])
	end
	block(parent, V(22, 9, 9), V(30, y + 6.5, 0), rgb(60, 60, 64), M.Metal, { Shape = Enum.PartType.Cylinder, CFrame = CFrame.new(30, y + 6.5, 0) * CFrame.Angles(0, 0, 0) })
	gen:zone(30, 0, 12)
	-- the locomotive
	block(parent, V(20, 8, 8.6), V(62, y + 5.6, 0), rgb(30, 30, 34), M.Metal)
	block(parent, V(7, 5.6, 8.6), V(54, y + 12, 0), rgb(30, 30, 34), M.Metal)
	block(parent, V(1.8, 4.5, 1.8), V(68, y + 12, 0), rgb(236, 180, 40), M.Metal, { Shape = Enum.PartType.Cylinder, CFrame = CFrame.new(68, y + 12, 0) * CFrame.Angles(0, 0, math.pi / 2) })
	block(parent, V(0.3, 3, 2.8), V(57.6, y + 12.4, -4.35), rgb(70, 110, 130), M.Glass, { Transparency = 0.3 })
	local steam = Instance.new("ParticleEmitter")
	steam.Texture = "rbxasset://textures/particles/smoke_main.dds"
	steam.Rate = 14
	steam.Lifetime = NumberRange.new(4, 7)
	steam.Speed = NumberRange.new(3, 5)
	steam.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 9) })
	steam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
	steam.Color = ColorSequence.new(rgb(240, 242, 246))
	steam.Acceleration = Vector3.new(2, 1, 0)
	steam.Parent = block(parent, V(1, 1, 1), V(68, y + 15, 0), rgb(255, 255, 255), M.SmoothPlastic, { Transparency = 1, CanCollide = false, CanQuery = false })
	gen:zone(62, 0, 12)
	for i = 0, 2 do
		boxcar(gen, -60 + i * 28, 34, y, colors[(i + 2) % #colors + 1])
	end
	boxcar(gen, 70, -34, y, colors[1])
	boxcar(gen, 44, -34, y, colors[3])

	-- the platform between the tracks' north side, with a canopy and benches, and the station house
	block(parent, V(110, 1, 10), V(-30, y + 0.5, 56), rgb(176, 176, 170), M.Concrete)
	for x = -80, 20, 20 do
		block(parent, V(0.8, 9, 0.8), V(x, y + 4.5, 56), rgb(70, 76, 84), M.Metal)
	end
	block(parent, V(104, 0.6, 12), V(-30, y + 9.3, 56), rgb(60, 110, 90), M.Metal)
	for x = -72, 12, 28 do
		block(parent, V(4.4, 0.4, 1.2), V(x, y + 1.7, 56), rgb(130, 90, 60), M.WoodPlanks)
	end
	gen:zone(-30, 56, 14)
	gen:building({ -70, 64, -30, 90 }, y, { color = rgb(150, 70, 56), inner = rgb(224, 218, 204), material = M.Brick, h = 10 })
	gen:house(V(20, y, 82), math.pi, { kind = "garage", w = 26, d = 20 })
	gen:house(V(60, y, 76), math.pi, { kind = "house", w = 22, d = 18 })

	-- water tower, signal gantry, coal shed
	for _, o in { { -5, -5 }, { 5, -5 }, { -5, 5 }, { 5, 5 } } do
		block(parent, V(0.8, 22, 0.8), V(85 + o[1], y + 11, 60 + o[2]), rgb(96, 76, 60), M.Wood)
	end
	block(parent, V(13, 8, 13), V(85, y + 25, 60), rgb(130, 96, 70), M.WoodPlanks, { Shape = Enum.PartType.Cylinder, CFrame = CFrame.new(85, y + 25, 60) * CFrame.Angles(0, 0, math.pi / 2) })
	MapKit.wedge(parent, V(14, 3, 7), CFrame.new(85, y + 31, 56.5), rgb(70, 60, 56), M.WoodPlanks)
	MapKit.wedge(parent, V(14, 3, 7), CFrame.new(85, y + 31, 63.5) * CFrame.Angles(0, math.pi, 0), rgb(70, 60, 56), M.WoodPlanks)
	gen:zone(85, 60, 9)
	for i, x in { -40, 10 } do
		block(parent, V(1, 14, 1), V(x, y + 7, -17), rgb(70, 76, 84), M.Metal)
		block(parent, V(1, 1, 36), V(x, y + 14, 0), rgb(70, 76, 84), M.Metal, { CanCollide = false })
		for k, z in { -34, 0, 34 } do
			local lamp = block(parent, V(1.2, 1.2, 1.2), V(x, y + 13, z), k == 2 and rgb(255, 60, 50) or rgb(80, 255, 120), M.Neon, { Shape = Enum.PartType.Ball, CanCollide = false })
			local l = Instance.new("PointLight")
			l.Range = 16
			l.Color = lamp.Color
			l.Parent = lamp
		end
		assert(i)
	end
	for x = 80, 100, 7 do -- coal pile
		block(parent, V(14, 5, 12), V(x, y + 2, -80), rgb(30, 30, 32), M.Slate, { Shape = Enum.PartType.Ball })
	end
	gen:zone(90, -80, 14)
	gen:container(76, -70, "Toolbox", 90)

	-- snowdrifts, snowy pines, drums and a stranded truck
	for _ = 1, 28 do
		local x, z = gen:open(-110, -110, 110, 110, 5)
		if x then
			block(parent, V(rng:NextNumber(8, 16), rng:NextNumber(2, 4.5), rng:NextNumber(5, 10)), CFrame.new(x, y + 0.4, z) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), rgb(246, 250, 255), M.Snow, { Shape = Enum.PartType.Ball })
		end
	end
	gen:scatter({ "Pine_1", "Pine_2" }, 46, -112, -112, 112, 112, 0.8, 1.3, 0.4, 4)
	gen:scatter({ "Barrel_1", "Rock_1" }, 20, -108, -108, 108, 108, 0.8, 1.1, 0, 3)
	gen:car(-100, 60, 0.4, "CarVan_1")
	gen:car(94, -20, 2.4, "CarSedan_1")
	for x = -100, 100, 40 do
		MapKit.lamp(parent, V(x, y, 18), false)
	end
	MapKit.tallGrass(parent, V(-90, y, -88), V(36, 0, 24), rng, nil, 0.7)
	MapKit.tallGrass(parent, V(40, y, -100), V(40, 0, 18), rng, nil, 0.7)
	-- falling snow: one big emitter above the whole depot
	local snow = Instance.new("ParticleEmitter")
	snow.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	snow.Rate = 500
	snow.Lifetime = NumberRange.new(7, 9)
	snow.Speed = NumberRange.new(6, 9)
	snow.EmissionDirection = Enum.NormalId.Bottom
	snow.SpreadAngle = Vector2.new(15, 15)
	snow.Size = NumberSequence.new(0.35)
	snow.LightEmission = 0.5
	snow.Color = ColorSequence.new(rgb(255, 255, 255))
	snow.Acceleration = Vector3.new(4, -1, 2)
	snow.Parent = block(parent, V(236, 1, 236), V(0, y + 48, 0), rgb(255, 255, 255), M.SmoothPlastic, { Transparency = 1, CanCollide = false, CanQuery = false })
	MapKit.fog(parent, V(0, 3, 0), V(200, 0, 200))
	gen:fence(rgb(110, 116, 124), 6, 8)

	return gen:finish({
		start = { V(100, 3, -100), V(96, 3, -102), V(104, 3, -96), V(92, 3, -98) },
		extraction = V(-104, 0, 100),
		lantern = V(0, 0, 20),
	})
end

return Map
