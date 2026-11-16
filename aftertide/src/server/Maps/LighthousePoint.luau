--!nonstrict
-- LIGHTHOUSE POINT: a storm-lashed headland: cliffs to the sea, a tall striped lighthouse with
-- the keeper's house, a foghorn station, concrete bunkers, a wooden stair down to a jetty, sea
-- stacks and a wrecked ship on the rocks. Grey, windy dusk.
local MapKit = require(script.Parent.MapKit)
local Gen = require(script.Parent.MapGen)
local V, rgb = Vector3.new, Gen.rgb
local block = MapKit.block

local Map = {
	id = "LighthousePoint",
	name = "Lighthouse Point",
	hilly = true,
	lighting = { sky = "cannery", clouds = 0.9, cloudDensity = 0.85, cloudColor = { 170, 176, 188 }, wind = { 18, 0, 8 }, clock = 18.0, brightness = 1.9, ambient = { 92, 98, 112 }, outdoor = { 128, 136, 152 }, fog = 0.38, haze = 1.6, fogColor = { 170, 182, 200 }, tint = { 226, 234, 248 }, saturation = 0.04, contrast = 0.14, shift = { 255, 214, 180 } },
}

local LX, LZ = 40, -30

local function smooth(a, b, t)
	t = math.clamp((t - a) / (b - a), 0, 1)
	return t * t * (3 - 2 * t)
end

local function height(x, z)
	local d = math.sqrt(x * x + z * z) / 105
	local h = 22 * (1 - smooth(0.5, 0.92, d)) - 5
	h += math.noise(x / 30, z / 30, 2.2) * 3.5 * (1 - smooth(0.7, 1, d))
	h += 8 * math.exp(-(((x - LX) ^ 2 + (z - LZ) ^ 2) / 700)) -- the hill under the lighthouse
	return h
end

function Map.build(parent, rng)
	local M = Enum.Material
	local gen = Gen.new(parent, rng)
	MapKit.outskirts("coast")
	MapKit.water(-120, -120, 120, 120, 0.4, 14)
	MapKit.heightfield(-120, -120, 120, 120, 6, height, function(x, z, h)
		if h < 1.5 then
			return M.Sand
		end
		local slope = math.abs(height(x + 6, z) - h) + math.abs(height(x, z + 6) - h)
		if slope > 6 then
			return M.Rock
		end
		return math.noise(x / 28, z / 28, 1) > 0.2 and M.LeafyGrass or M.Grass
	end)
	gen:rolling()
	local function pad(cx, cz, w, d)
		local y = height(cx, cz)
		MapKit.clearAbove(cx - w / 2, cz - d / 2, cx + w / 2, cz + d / 2, y)
		MapKit.slab(cx - w / 2, cz - d / 2, cx + w / 2, cz + d / 2, M.Ground, y, 16)
		return y
	end

	-- the lighthouse: tall tapered stripes, a gallery, a lamp room with a real light
	local ly = pad(LX, LZ, 26, 26)
	for i = 0, 9 do
		local r = 13 - i * 0.7
		block(parent, V(4.4, r, r), V(LX, ly + 2.2 + i * 4.4, LZ), i % 2 == 0 and rgb(236, 236, 232) or rgb(200, 56, 48), M.Concrete, { Shape = Enum.PartType.Cylinder, CFrame = CFrame.new(LX, ly + 2.2 + i * 4.4, LZ) * CFrame.Angles(0, 0, math.pi / 2) })
	end
	local top = ly + 46
	block(parent, V(1, 16, 16), V(LX, top, LZ), rgb(40, 44, 52), M.Metal, { Shape = Enum.PartType.Cylinder, CFrame = CFrame.new(LX, top, LZ) * CFrame.Angles(0, 0, math.pi / 2) })
	block(parent, V(7, 6.4, 6.4), V(LX, top + 3.6, LZ), rgb(255, 232, 150), M.Glass, { Shape = Enum.PartType.Cylinder, CFrame = CFrame.new(LX, top + 3.6, LZ) * CFrame.Angles(0, 0, math.pi / 2), Transparency = 0.3, CanCollide = false })
	block(parent, V(2, 8.4, 8.4), V(LX, top + 7.4, LZ), rgb(200, 56, 48), M.Metal, { Shape = Enum.PartType.Cylinder, CFrame = CFrame.new(LX, top + 7.4, LZ) * CFrame.Angles(0, 0, math.pi / 2) })
	local lamp = block(parent, V(2, 2, 2), V(LX, top + 3.6, LZ), rgb(255, 240, 180), M.Neon, { Shape = Enum.PartType.Ball, CanCollide = false })
	local beam = Instance.new("SpotLight")
	beam.Range = 110
	beam.Angle = 40
	beam.Brightness = 3
	beam.Color = rgb(255, 236, 170)
	beam.Face = Enum.NormalId.Front
	beam.Parent = lamp
	local glow = Instance.new("PointLight")
	glow.Range = 60
	glow.Brightness = 1.5
	glow.Color = rgb(255, 230, 160)
	glow.Parent = lamp
	block(parent, V(5, 8, 0.4), V(LX, ly + 4, LZ - 6.6), rgb(90, 60, 44), M.WoodPlanks) -- the door
	gen:zone(LX, LZ, 14)

	-- the keeper's house and foghorn station beside it, then two bunkers on the cliffs
	gen:house(V(LX - 30, pad(LX - 30, LZ + 8, 30, 30), LZ - 6), 0, { kind = "house", w = 22, d = 18, roof = "gable", color = rgb(236, 232, 222) })
	local fy = pad(10, -70, 26, 22)
	gen:building({ -2, -80, 22, -62 }, fy, { color = rgb(150, 152, 150), inner = rgb(210, 208, 200), material = M.Concrete, h = 9 })
	local b1 = pad(-70, 30, 30, 26)
	gen:building({ -82, 20, -58, 40 }, b1, { color = rgb(110, 116, 106), inner = rgb(180, 180, 170), material = M.Concrete, h = 8 })
	local b2 = pad(45, 45, 30, 26)
	gen:building({ 33, 35, 57, 55 }, b2, { color = rgb(110, 116, 106), inner = rgb(180, 180, 170), material = M.Concrete, h = 8 })

	-- the jetty and the long stair down to it
	local jx, jz = -58, -52
	for i = 0, 7 do
		block(parent, V(4, 0.4, 3), V(jx - i * 3.2, 1.2, jz), rgb(130, 96, 66), M.WoodPlanks)
		if i % 2 == 0 then
			block(parent, V(0.5, 4, 0.5), V(jx - i * 3.2, -0.8, jz - 1.4), rgb(80, 60, 44), M.Wood)
			block(parent, V(0.5, 4, 0.5), V(jx - i * 3.2, -0.8, jz + 1.4), rgb(80, 60, 44), M.Wood)
		end
	end
	gen:zone(jx - 8, jz, 12)
	gen:container(jx + 4, jz + 5, "Toolbox", 0)

	-- a wreck on the rocks, sea stacks, and a radar dish
	local wx, wz = 100, 20
	block(parent, V(30, 9, 9), CFrame.new(wx, 2, wz) * CFrame.Angles(0, 0.4, 0.32), rgb(120, 54, 44), M.CorrodedMetal)
	block(parent, V(7, 6, 7), CFrame.new(wx - 4, 8, wz + 1) * CFrame.Angles(0, 0.4, 0.32), rgb(200, 196, 186), M.CorrodedMetal)
	gen:zone(wx, wz, 16)
	for i = 1, 8 do
		local a = i / 8 * math.pi * 2 + 0.5
		local x, z = math.cos(a) * 112, math.sin(a) * 112
		MapKit.prop(parent, "Boulder_1", CFrame.new(x, 0, z) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), rng:NextNumber(2.4, 3.6))
	end
	local ry = height(-30, -40)
	block(parent, V(0.8, 10, 0.8), V(-30, ry + 5, -40), rgb(150, 150, 150), M.Metal)
	block(parent, V(10, 1, 10), CFrame.new(-30, ry + 10.5, -40) * CFrame.Angles(0.6, 0, 0), rgb(220, 220, 216), M.Metal)
	gen:zone(-30, -40, 6)

	gen:scatter({ "Pine_1", "DeadTree_1", "Bush_1", "Bush_2" }, 50, -100, -100, 100, 100, 0.6, 1.0, 0.4, 4)
	gen:scatter({ "Rock_1", "Rock_2", "Boulder_1" }, 36, -105, -105, 105, 105, 0.8, 1.5, 0.5, 3)
	gen:scatter({ "Barrel_1", "Rubble_1" }, 12, -80, -80, 80, 80, 0.8, 1.0, 0, 3)
	gen:car(20, 40, 0.4, "CarVan_1")
	MapKit.tallGrass(parent, V(-30, gen:ground(-30, 60), 60), V(40, 0, 30), rng, MapKit.ground)
	MapKit.tallGrass(parent, V(30, gen:ground(30, -80), -80), V(30, 0, 24), rng, MapKit.ground)
	MapKit.fog(parent, V(0, 4, 0), V(220, 0, 220))
	MapKit.fog(parent, V(-30, 6, 30), V(120, 0, 120))

	return gen:finish({
		start = { V(-40, 3, 55), V(-36, 3, 57), V(-44, 3, 51), V(-32, 3, 53) },
		extraction = V(-62, 0, -52),
		lantern = V(LX - 12, 0, LZ),
	})
end

return Map
