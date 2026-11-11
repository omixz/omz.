--!nonstrict
-- Builds the grey-box world in code so the project is fully self-contained:
--   * The Meridian (ferry hideout deck) far from the encounter
--   * "Cannery Row" encounter map (cannery, container yard, shallows, reed beds, net shed)
-- and resets per-encounter objects (supply crates, part pickups, extraction flare).
-- Stage 4+ replaces the grey-box with hand-built art (docs/05-roadmap-and-prototype.md).
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Game = require(Shared.Config.Game)
local Items = require(Shared.Config.Items)

local MapService = {}
local Services

local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

local C = {
	ground = Color3.fromRGB(58, 62, 64),
	wall = Color3.fromRGB(84, 86, 84),
	wallDark = Color3.fromRGB(62, 64, 64),
	roof = Color3.fromRGB(74, 70, 64),
	metal = Color3.fromRGB(46, 48, 50),
	crate = Color3.fromRGB(92, 72, 52),
	machine = Color3.fromRGB(70, 78, 80),
	supply = Color3.fromRGB(150, 92, 44),
	bone = Color3.fromRGB(226, 220, 206),
	water = Color3.fromRGB(52, 70, 74),
	reed = Color3.fromRGB(92, 94, 70),
	warm = Color3.fromRGB(255, 190, 120),
	flare = Color3.fromRGB(255, 70, 50),
	containers = {
		Color3.fromRGB(110, 54, 42),
		Color3.fromRGB(42, 78, 80),
		Color3.fromRGB(52, 62, 82),
		Color3.fromRGB(128, 104, 52),
	},
}

local PART_COLORS = {
	glass = Color3.fromRGB(120, 170, 150),
	cloth = Color3.fromRGB(170, 160, 140),
	scrap = Color3.fromRGB(120, 110, 100),
}

-- Encounter layout data -------------------------------------------------------------------

MapService.StartSpawns = {
	Vector3.new(-6, 3, 100),
	Vector3.new(-2, 3, 102),
	Vector3.new(2, 3, 102),
	Vector3.new(6, 3, 100),
}

MapService.ExtractionPos = Vector3.new(-92, 0, -100)

MapService.SupplyCandidates = {
	Vector3.new(24, 0, -45), -- cannery, north aisle
	Vector3.new(5, 0, -5), -- cannery, south-west corner
	Vector3.new(52, 0, -10), -- cannery, east bay
	Vector3.new(88, 0, -38), -- container yard
	Vector3.new(90, 0, 62), -- container yard, south
	Vector3.new(-80, 0, 20), -- shallows
	Vector3.new(-45, 0, -100), -- net shed
	Vector3.new(-40, 0, 75), -- south-west reed bed
	Vector3.new(30, 0, 75), -- south lot
	Vector3.new(-30, 0, -50), -- mid-west
}

MapService.LootSpots = {
	Vector3.new(-25, 0, 45), Vector3.new(-15, 0, 60), Vector3.new(15, 0, 50), Vector3.new(35, 0, 65),
	Vector3.new(45, 0, 25), Vector3.new(-40, 0, 15), Vector3.new(-30, 0, -25), Vector3.new(-45, 0, -75),
	Vector3.new(-15, 0, -85), Vector3.new(15, 0, -80), Vector3.new(35, 0, -95), Vector3.new(55, 0, -75),
	Vector3.new(70, 0, 30), Vector3.new(88, 0, 0), Vector3.new(108, 0, -40), Vector3.new(88, 0, 78),
	Vector3.new(0, 0, -30), Vector3.new(30, 0, -5), Vector3.new(45, 0, -45), Vector3.new(10, 0, -45),
	Vector3.new(-90, 0, -30), Vector3.new(-85, 0, 50), Vector3.new(-60, 0, 80), Vector3.new(60, 0, 90),
}

MapService.PatrolRoutes = {
	{ Vector3.new(24, 0, -30), Vector3.new(24, 0, -2), Vector3.new(52, 0, -30), Vector3.new(5, 0, -35) }, -- cannery
	{ Vector3.new(88, 0, -80), Vector3.new(88, 0, -38), Vector3.new(88, 0, 20), Vector3.new(88, 0, 62) }, -- yard
	{ Vector3.new(-30, 0, 50), Vector3.new(30, 0, 55), Vector3.new(40, 0, 25), Vector3.new(-20, 0, 35) }, -- south lot
	{ Vector3.new(-90, 0, -60), Vector3.new(-90, 0, 40), Vector3.new(-75, 0, 60), Vector3.new(-80, 0, -20) }, -- shallows
	{ Vector3.new(-40, 0, -60), Vector3.new(0, 0, -85), Vector3.new(50, 0, -85), Vector3.new(-20, 0, -70) }, -- north
	{ Vector3.new(-45, 0, -10), Vector3.new(-45, 0, 30), Vector3.new(-25, 0, 0) }, -- mid-west
}

-- Builders --------------------------------------------------------------------------------

local function block(parent, size, position, color, material, props)
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

local function volume(parent, size, position, tag)
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

-- Wall running along X at depth z, with door gaps {{x1, x2}, ...} and lintels above them.
local function wallX(parent, z, x1, x2, height, gaps, color, material)
	for _, s in splitGaps(x1, x2, gaps) do
		block(parent, Vector3.new(s[2] - s[1], height, 2), Vector3.new((s[1] + s[2]) / 2, height / 2, z), color, material)
	end
	for _, g in gaps do
		if height > 9 then
			block(parent, Vector3.new(g[2] - g[1], height - 9, 2), Vector3.new((g[1] + g[2]) / 2, 9 + (height - 9) / 2, z), color, material)
		end
	end
end

local function wallZ(parent, x, z1, z2, height, gaps, color, material)
	for _, s in splitGaps(z1, z2, gaps) do
		block(parent, Vector3.new(2, height, s[2] - s[1]), Vector3.new(x, height / 2, (s[1] + s[2]) / 2), color, material)
	end
	for _, g in gaps do
		if height > 9 then
			block(parent, Vector3.new(2, height - 9, g[2] - g[1]), Vector3.new(x, 9 + (height - 9) / 2, (g[1] + g[2]) / 2), color, material)
		end
	end
end

local function lamp(parent, base)
	block(parent, Vector3.new(0.6, 12, 0.6), base + Vector3.new(0, 6, 0), C.metal, Enum.Material.Metal)
	local head = block(parent, Vector3.new(1.6, 0.8, 1.6), base + Vector3.new(0, 12.2, 0), C.warm, Enum.Material.Neon)
	local light = Instance.new("PointLight")
	light.Range = 24
	light.Brightness = 1.8
	light.Color = C.warm
	light.Shadows = true
	light.Parent = head
	volume(parent, Vector3.new(20, 10, 20), base + Vector3.new(0, 5, 0), "LitZone")
end

local function hangingBulb(parent, position)
	local bulb = block(parent, Vector3.new(0.8, 0.8, 0.8), position, C.warm, Enum.Material.Neon, { Shape = Enum.PartType.Ball })
	local light = Instance.new("PointLight")
	light.Range = 18
	light.Brightness = 1.2
	light.Color = C.warm
	light.Shadows = true
	light.Parent = bulb
	volume(parent, Vector3.new(14, 10, 14), Vector3.new(position.X, 5, position.Z), "LitZone")
end

local function reeds(parent, center, size, rng)
	volume(parent, Vector3.new(size.X, 6, size.Z), center + Vector3.new(0, 3, 0), "TallGrass")
	local count = math.floor(size.X * size.Z * 0.3)
	for _ = 1, count do
		local h = rng:NextNumber(3.6, 5.6)
		local x = center.X + rng:NextNumber(-size.X / 2, size.X / 2)
		local z = center.Z + rng:NextNumber(-size.Z / 2, size.Z / 2)
		local tilt = CFrame.Angles(rng:NextNumber(-0.18, 0.18), rng:NextNumber(0, 6.28), rng:NextNumber(-0.18, 0.18))
		local shade = rng:NextNumber(0.8, 1.15)
		block(parent, Vector3.new(0.22, h, 0.22), CFrame.new(x, h / 2, z) * tilt, Color3.new(C.reed.R * shade, C.reed.G * shade, C.reed.B * shade), Enum.Material.Grass, {
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
		})
	end
end

local function fog(parent, position, size)
	local p = block(parent, Vector3.new(size.X, 1, size.Z), position, Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
	})
	local e = Instance.new("ParticleEmitter")
	e.Texture = SMOKE
	e.Rate = 1.4
	e.Lifetime = NumberRange.new(14, 20)
	e.Speed = NumberRange.new(0.3, 1)
	e.SpreadAngle = Vector2.new(60, 60)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-4, 4)
	e.LightInfluence = 1
	e.Color = ColorSequence.new(Color3.fromRGB(205, 212, 212))
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 16), NumberSequenceKeypoint.new(1, 28) })
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 0.86),
		NumberSequenceKeypoint.new(0.7, 0.9),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Parent = p
end

-- The Meridian (hideout) ------------------------------------------------------------------

local function buildFerry(parent)
	local o = Game.FerryOrigin
	local deckColor = Color3.fromRGB(70, 66, 60)
	local hull = Color3.fromRGB(176, 176, 166)
	-- sea + sandbar
	block(parent, Vector3.new(700, 1, 700), o + Vector3.new(0, -7, 0), Color3.fromRGB(30, 40, 44), Enum.Material.Glass, { Reflectance = 0.12, CanQuery = false })
	block(parent, Vector3.new(120, 4, 60), o + Vector3.new(0, -6, 0), Color3.fromRGB(120, 112, 96), Enum.Material.Sand)
	-- deck and railings
	block(parent, Vector3.new(64, 2, 28), o + Vector3.new(0, -1, 0), deckColor, Enum.Material.DiamondPlate)
	block(parent, Vector3.new(64, 3.5, 0.5), o + Vector3.new(0, 1.75, -14), C.metal, Enum.Material.Metal)
	block(parent, Vector3.new(64, 3.5, 0.5), o + Vector3.new(0, 1.75, 14), C.metal, Enum.Material.Metal)
	block(parent, Vector3.new(0.5, 3.5, 28), o + Vector3.new(32, 1.75, 0), C.metal, Enum.Material.Metal)
	block(parent, Vector3.new(0.5, 3.5, 28), o + Vector3.new(-32, 1.75, 0), C.metal, Enum.Material.Metal)
	-- bridge superstructure + hull flank
	block(parent, Vector3.new(14, 12, 20), o + Vector3.new(-23, 6, 0), hull, Enum.Material.CorrodedMetal)
	block(parent, Vector3.new(16, 1, 22), o + Vector3.new(-23, 12.5, 0), C.metal, Enum.Material.Metal)
	block(parent, Vector3.new(64, 8, 1), o + Vector3.new(0, -5, 14.5), hull, Enum.Material.CorrodedMetal)
	block(parent, Vector3.new(64, 8, 1), o + Vector3.new(0, -5, -14.5), hull, Enum.Material.CorrodedMetal)
	-- containers on deck
	block(parent, Vector3.new(16, 8.6, 7), o + Vector3.new(16, 4.3, -9), C.containers[2], Enum.Material.CorrodedMetal)
	block(parent, Vector3.new(7, 8.6, 7), o + Vector3.new(26, 4.3, 9), C.containers[1], Enum.Material.CorrodedMetal)
	-- string lights
	for i = 0, 7 do
		local x = -14 + i * 6
		local bulb = block(parent, Vector3.new(0.5, 0.5, 0.5), o + Vector3.new(x, 7.5 - math.abs(i - 3.5) * 0.25, 0), C.warm, Enum.Material.Neon, { Shape = Enum.PartType.Ball, CanCollide = false })
		local light = Instance.new("PointLight")
		light.Range = 12
		light.Brightness = 0.9
		light.Color = C.warm
		light.Parent = bulb
	end
	block(parent, Vector3.new(44, 0.15, 0.15), o + Vector3.new(7, 7.6, 0), C.metal, Enum.Material.Metal, { CanCollide = false })

	-- Chart table: starts the crossing
	local chart = block(parent, Vector3.new(5, 3, 3), o + Vector3.new(4, 1.5, -4), Color3.fromRGB(96, 70, 48), Enum.Material.WoodPlanks, { Name = "ChartTable" })
	block(parent, Vector3.new(4.4, 0.1, 2.4), o + Vector3.new(4, 3.05, -4), Color3.fromRGB(214, 204, 176), Enum.Material.SmoothPlastic)
	local chartPrompt = Instance.new("ProximityPrompt")
	chartPrompt.Name = "ChartPrompt"
	chartPrompt.ActionText = "Begin the Crossing"
	chartPrompt.ObjectText = "Tide chart"
	chartPrompt.HoldDuration = 0.8
	chartPrompt.MaxActivationDistance = 9
	chartPrompt.RequiresLineOfSight = false
	chartPrompt.GamepadKeyCode = Enum.KeyCode.ButtonA
	chartPrompt.Parent = chart
	chartPrompt.Triggered:Connect(function(player)
		Services.MatchService.requestStart(player)
	end)

	-- Crew cabin door: change character
	local cabin = block(parent, Vector3.new(4, 8, 0.6), o + Vector3.new(-15.8, 4, 6), Color3.fromRGB(90, 96, 92), Enum.Material.Metal, { Name = "CabinDoor" })
	local cabinPrompt = Instance.new("ProximityPrompt")
	cabinPrompt.ActionText = "Change crew member"
	cabinPrompt.ObjectText = "Crew cabins"
	cabinPrompt.MaxActivationDistance = 9
	cabinPrompt.RequiresLineOfSight = false
	cabinPrompt.GamepadKeyCode = Enum.KeyCode.ButtonA
	cabinPrompt.Parent = cabin
	cabinPrompt.Triggered:Connect(function(player)
		Services.MatchService.openCharacterSelect(player)
	end)

	-- The Purser's Office: the in-world shop
	local booth = block(parent, Vector3.new(7, 8, 5), o + Vector3.new(24, 4, -1), Color3.fromRGB(150, 146, 134), Enum.Material.CorrodedMetal, { Name = "PursersOffice" })
	for i = -2, 2 do
		block(parent, Vector3.new(0.15, 3, 0.15), o + Vector3.new(24 + i * 0.7, 4.5, 1.6), C.metal, Enum.Material.Metal, { CanCollide = false })
	end
	local boothLight = Instance.new("PointLight")
	boothLight.Range = 10
	boothLight.Brightness = 1
	boothLight.Color = C.warm
	boothLight.Parent = booth
	local shopPrompt = Instance.new("ProximityPrompt")
	shopPrompt.ActionText = "Open the ledger"
	shopPrompt.ObjectText = "The Purser's Office"
	shopPrompt.MaxActivationDistance = 9
	shopPrompt.RequiresLineOfSight = false
	shopPrompt.GamepadKeyCode = Enum.KeyCode.ButtonA
	shopPrompt.Parent = booth
	shopPrompt.Triggered:Connect(function(player)
		Services.MatchService.openShop(player)
	end)
end

-- Cannery Row (encounter) -----------------------------------------------------------------

local function buildCannery(parent)
	local rng = Random.new(1137) -- fixed seed: the static layout never changes between runs
	block(parent, Vector3.new(230, 2, 230), Vector3.new(0, -1, 0), C.ground, Enum.Material.Concrete, { Name = "Ground" })

	-- perimeter
	block(parent, Vector3.new(232, 16, 2), Vector3.new(0, 8, -116), C.wallDark, Enum.Material.Concrete)
	block(parent, Vector3.new(232, 16, 2), Vector3.new(0, 8, 116), C.wallDark, Enum.Material.Concrete)
	block(parent, Vector3.new(2, 16, 232), Vector3.new(116, 8, 0), C.wallDark, Enum.Material.Concrete)
	block(parent, Vector3.new(2, 16, 232), Vector3.new(-116, 8, 0), C.wallDark, Enum.Material.Concrete)

	-- the cannery (x -10..60, z -50..10)
	local h = 16
	wallX(parent, -50, -10, 60, h, { { 20, 28 } }, C.wall, Enum.Material.Brick)
	wallX(parent, 10, -10, 60, h, { { 5, 13 }, { 40, 48 } }, C.wall, Enum.Material.Brick)
	wallZ(parent, -10, -50, 10, h, { { -24, -16 } }, C.wall, Enum.Material.Brick)
	wallZ(parent, 60, -50, 10, h, { { -30, -22 } }, C.wall, Enum.Material.Brick)
	block(parent, Vector3.new(72, 1, 62), Vector3.new(25, h + 0.5, -20), C.roof, Enum.Material.CorrodedMetal)
	for _, x in { 5, 14, 34, 46 } do
		block(parent, Vector3.new(6, 4, 16), Vector3.new(x, 2, -20), C.machine, Enum.Material.Metal)
		block(parent, Vector3.new(2, 2.5, 2), Vector3.new(x, 5.25, -24), C.metal, Enum.Material.Metal)
	end
	block(parent, Vector3.new(50, 2.5, 2), Vector3.new(25, 1.25, -40), C.machine, Enum.Material.DiamondPlate) -- conveyor
	hangingBulb(parent, Vector3.new(24, 13, -20))
	hangingBulb(parent, Vector3.new(3, 13, -2))

	-- container yard (east)
	local containers = {
		{ Vector3.new(78, 0, -85), Vector3.new(8, 8.6, 20) },
		{ Vector3.new(96, 0, -60), Vector3.new(20, 8.6, 8) },
		{ Vector3.new(78, 0, -35), Vector3.new(8, 8.6, 20) },
		{ Vector3.new(100, 0, -15), Vector3.new(8, 8.6, 20) },
		{ Vector3.new(80, 0, 10), Vector3.new(20, 8.6, 8) },
		{ Vector3.new(100, 0, 40), Vector3.new(8, 8.6, 20) },
		{ Vector3.new(78, 0, 60), Vector3.new(8, 8.6, 20) },
		{ Vector3.new(96, 0, 85), Vector3.new(20, 8.6, 8) },
	}
	for i, c in containers do
		block(parent, c[2], c[1] + Vector3.new(0, 4.3, 0), C.containers[(i - 1) % #C.containers + 1], Enum.Material.CorrodedMetal)
	end
	block(parent, Vector3.new(8, 8.6, 20), Vector3.new(78, 12.9, -35), C.containers[4], Enum.Material.CorrodedMetal) -- stacked

	-- net shed (north-west, x -60..-30, z -112..-84)
	wallX(parent, -84, -60, -30, 10, {}, C.wall, Enum.Material.WoodPlanks)
	wallZ(parent, -60, -112, -84, 10, {}, C.wall, Enum.Material.WoodPlanks)
	wallZ(parent, -30, -112, -84, 10, { { -100, -94 } }, C.wall, Enum.Material.WoodPlanks)
	block(parent, Vector3.new(32, 1, 30), Vector3.new(-45, 10.5, -98), C.roof, Enum.Material.CorrodedMetal)

	-- shallows (west): visual water + noise/slow volume
	block(parent, Vector3.new(42, 1, 160), Vector3.new(-91, 0.5, -10), C.water, Enum.Material.Glass, {
		Name = "Water",
		Transparency = 0.35,
		Reflectance = 0.15,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	})
	volume(parent, Vector3.new(42, 6, 160), Vector3.new(-91, 3, -10), "Shallows")

	-- reed beds (concealment)
	reeds(parent, Vector3.new(-66, 0, -60), Vector3.new(10, 0, 30), rng)
	reeds(parent, Vector3.new(-66, 0, 30), Vector3.new(10, 0, 30), rng)
	reeds(parent, Vector3.new(-40, 0, 70), Vector3.new(30, 0, 14), rng)
	reeds(parent, Vector3.new(62, 0, 40), Vector3.new(10, 0, 20), rng)

	-- cover: crates, pallets, low walls
	local crates = {
		Vector3.new(-30, 0, 40), Vector3.new(-20, 0, 55), Vector3.new(10, 0, 42), Vector3.new(25, 0, 60),
		Vector3.new(40, 0, 32), Vector3.new(-45, 0, 8), Vector3.new(-35, 0, -32), Vector3.new(-50, 0, -70),
		Vector3.new(-20, 0, -80), Vector3.new(10, 0, -72), Vector3.new(30, 0, -90), Vector3.new(50, 0, -68),
		Vector3.new(64, 0, 22), Vector3.new(-5, 0, 80), Vector3.new(68, 0, -95), Vector3.new(-70, 0, -100),
	}
	for _, pos in crates do
		block(parent, Vector3.new(4, 4, 4), pos + Vector3.new(0, 2, 0), C.crate, Enum.Material.WoodPlanks)
		if rng:NextNumber() < 0.4 then
			block(parent, Vector3.new(3, 3, 3), pos + Vector3.new(0.4, 5.5, -0.3), C.crate, Enum.Material.WoodPlanks)
		end
	end
	block(parent, Vector3.new(24, 3.5, 1.5), Vector3.new(-20, 1.75, 25), C.wall, Enum.Material.Concrete)
	block(parent, Vector3.new(1.5, 3.5, 18), Vector3.new(20, 1.75, 30), C.wall, Enum.Material.Concrete)
	block(parent, Vector3.new(18, 3.5, 1.5), Vector3.new(-40, 1.75, -45), C.wall, Enum.Material.Concrete)

	-- lamp posts: light pools are dangerous (you are easier to see inside them)
	lamp(parent, Vector3.new(0, 0, 70))
	lamp(parent, Vector3.new(65, 0, -50))
	lamp(parent, Vector3.new(-50, 0, -20))
	lamp(parent, Vector3.new(40, 0, 18))

	-- ground fog
	for _, f in {
		{ Vector3.new(-60, 1, 40), Vector3.new(60, 0, 60) },
		{ Vector3.new(30, 1, 60), Vector3.new(80, 0, 60) },
		{ Vector3.new(-60, 1, -70), Vector3.new(60, 0, 60) },
		{ Vector3.new(85, 1, 0), Vector3.new(40, 0, 200) },
		{ Vector3.new(15, 1, -85), Vector3.new(60, 0, 40) },
	} do
		fog(parent, f[1], f[2])
	end
end

-- Lighting --------------------------------------------------------------------------------

local atmosphere, colorCorrection

local function setupLighting()
	Lighting.ClockTime = 1.4
	Lighting.Brightness = 1.2
	Lighting.Ambient = Color3.fromRGB(24, 28, 32)
	Lighting.OutdoorAmbient = Color3.fromRGB(58, 66, 72)
	Lighting.EnvironmentDiffuseScale = 0.4
	Lighting.EnvironmentSpecularScale = 0.6
	Lighting.GlobalShadows = true
	Lighting.ExposureCompensation = 0.1

	atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Density = 0.45
	atmosphere.Offset = 0.1
	atmosphere.Color = Color3.fromRGB(199, 206, 206)
	atmosphere.Decay = Color3.fromRGB(92, 108, 112)
	atmosphere.Glare = 0
	atmosphere.Haze = 2.2
	atmosphere.Parent = Lighting

	colorCorrection = Instance.new("ColorCorrectionEffect")
	colorCorrection.Name = "AftertideGrade"
	colorCorrection.Saturation = -0.25
	colorCorrection.Contrast = 0.12
	colorCorrection.Brightness = -0.02
	colorCorrection.TintColor = Color3.fromRGB(225, 235, 240)
	colorCorrection.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.6
	bloom.Size = 24
	bloom.Threshold = 1.6
	bloom.Parent = Lighting
end

function MapService.applyModifier(modifier)
	if not atmosphere then
		return
	end
	TweenService:Create(atmosphere, TweenInfo.new(3), { Density = modifier.fogDensity or 0.45 }):Play()
	local boost = modifier.ambientBoost or 0
	Lighting.OutdoorAmbient = Color3.fromRGB(58 + boost * 80, 66 + boost * 80, 72 + boost * 80)
end

-- Encounter objects -----------------------------------------------------------------------

local encounterFolder
local extraction

local function shuffled(list, rng)
	local copy = table.clone(list)
	for i = #copy, 2, -1 do
		local j = rng:NextInteger(1, i)
		copy[i], copy[j] = copy[j], copy[i]
	end
	return copy
end

local function makePrompt(parent, action, object, hold)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = action
	prompt.ObjectText = object
	prompt.HoldDuration = hold or 0
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonA
	prompt.Parent = parent
	return prompt
end

function MapService.resetEncounter(modifier, rng)
	encounterFolder:ClearAllChildren()

	-- supply crates (objective)
	local picks = shuffled(MapService.SupplyCandidates, rng)
	for i = 1, Game.CratesRequired do
		local pos = picks[i]
		local crate = block(encounterFolder, Vector3.new(3, 2.4, 2.2), pos + Vector3.new(0, 1.2, 0), C.supply, Enum.Material.WoodPlanks, { Name = "SupplyCrate" })
		block(crate, Vector3.new(3.05, 0.35, 2.25), pos + Vector3.new(0, 1.7, 0), C.bone, Enum.Material.SmoothPlastic, { CanCollide = false, CanQuery = false })
		local glint = Instance.new("PointLight")
		glint.Range = 5
		glint.Brightness = 0.35
		glint.Color = C.warm
		glint.Parent = crate
		local prompt = makePrompt(crate, "Salvage", "Supply crate", 1.2)
		prompt.Triggered:Connect(function(player)
			Services.MatchService.onCrateSalvaged(player, crate)
		end)
	end

	-- crafting parts
	local spots = shuffled(MapService.LootSpots, rng)
	local perType = math.max(1, math.floor(Items.PartsPerType * (modifier.partsMult or 1) + 0.5))
	local index = 1
	for _, itemId in { "glass", "cloth", "scrap" } do
		for _ = 1, perType do
			local pos = spots[index]
			index += 1
			if not pos then
				break
			end
			local jitter = Vector3.new(rng:NextNumber(-1.5, 1.5), 0, rng:NextNumber(-1.5, 1.5))
			local pickup = block(encounterFolder, Vector3.new(1.2, 0.6, 1.2), pos + jitter + Vector3.new(0, 0.3, 0), PART_COLORS[itemId], Enum.Material.SmoothPlastic, {
				Name = "Pickup_" .. itemId,
				CanCollide = false,
			})
			local prompt = makePrompt(pickup, "Pick up", Items.Items[itemId].name, 0)
			prompt.MaxActivationDistance = 7
			prompt.Triggered:Connect(function(player)
				Services.InventoryService.pickup(player, pickup, itemId, 1)
			end)
		end
	end

	-- extraction: the Slipway flare (inactive until the quota is met)
	local base = MapService.ExtractionPos
	local ring = block(encounterFolder, Vector3.new(0.2, Game.ExtractionRadius * 2, Game.ExtractionRadius * 2), CFrame.new(base + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90)), C.flare, Enum.Material.Neon, {
		Name = "ExtractionRing",
		Shape = Enum.PartType.Cylinder,
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	})
	local flare = block(encounterFolder, Vector3.new(0.6, 1.4, 0.6), base + Vector3.new(0, 0.7, 0), C.flare, Enum.Material.Neon, {
		Name = "Flare",
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	})
	local light = Instance.new("PointLight")
	light.Color = C.flare
	light.Range = 32
	light.Brightness = 3
	light.Shadows = true
	light.Enabled = false
	light.Parent = flare
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = SMOKE
	smoke.Enabled = false
	smoke.Rate = 6
	smoke.Lifetime = NumberRange.new(5, 7)
	smoke.Speed = NumberRange.new(6, 9)
	smoke.SpreadAngle = Vector2.new(8, 8)
	smoke.Color = ColorSequence.new(Color3.fromRGB(255, 120, 100))
	smoke.LightEmission = 0.4
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 9) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
	smoke.Parent = flare
	extraction = { ring = ring, flare = flare, light = light, smoke = smoke }
end

function MapService.activateExtraction()
	if not extraction then
		return
	end
	extraction.ring.Transparency = 0.8
	extraction.flare.Transparency = 0
	extraction.light.Enabled = true
	extraction.smoke.Enabled = true
end

function MapService.cleanupEncounter()
	if encounterFolder then
		encounterFolder:ClearAllChildren()
	end
	extraction = nil
end

function MapService.ferrySpawn(index)
	local o = Game.FerryOrigin
	local pos = o + Vector3.new(-4 + ((index - 1) % 4) * 3, 3, 6)
	return CFrame.lookAt(pos, pos + Vector3.new(1, 0, 0))
end

function MapService.encounterSpawn(index)
	local pos = MapService.StartSpawns[(index - 1) % #MapService.StartSpawns + 1]
	return CFrame.lookAt(pos, pos + Vector3.new(0, 0, -1))
end

function MapService.init(registry)
	Services = registry
end

function MapService.start()
	local world = Instance.new("Folder")
	world.Name = "World"
	world.Parent = Workspace

	local ferry = Instance.new("Folder")
	ferry.Name = "Meridian"
	ferry.Parent = world
	buildFerry(ferry)

	local cannery = Instance.new("Folder")
	cannery.Name = "CanneryRow"
	cannery.Parent = world
	buildCannery(cannery)

	encounterFolder = Instance.new("Folder")
	encounterFolder.Name = "Encounter"
	encounterFolder.Parent = world

	setupLighting()
	MapService.ready = true
end

return MapService
