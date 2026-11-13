--!nonstrict
-- Builds the grey-box world in code so the project is fully self-contained:
--   * The Meridian (ferry hideout deck) far from the encounter
--   * the encounter maps (src/server/Maps/*), one loaded at a time
-- and resets per-encounter objects (supply crates, part pickups, extraction flare).
-- Stage 4+ replaces the grey-box with hand-built art (docs/05-roadmap-and-prototype.md).
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Game = require(Shared.Config.Game)
local Encounters = require(Shared.Config.Encounters)
local Sfx = require(Shared.Util.Sfx)

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


-- Encounter layout data -------------------------------------------------------------------

-- Filled from the active map module when a map loads (see MapService.loadMap).
MapService.StartSpawns = {}
MapService.ExtractionPos = Vector3.zero
MapService.LanternPos = Vector3.zero
MapService.SupplyCandidates = {}
MapService.LootSpots = {}
MapService.ContainerSpots = {}
MapService.EdgeSpawns = {}
MapService.PatrolRoutes = {}
MapService.Doorways = {}
MapService.MapIds = { "CanneryRow", "LarkspurStreet", "HollowPines" }

local MapsFolder = script.Parent.Parent:WaitForChild("Maps")
local MapKit = require(MapsFolder:WaitForChild("MapKit"))
local MAP_MODULES = {}
for _, id in MapService.MapIds do
	MAP_MODULES[id] = require(MapsFolder:WaitForChild(id))
end

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
		local bulb = block(parent, Vector3.new(0.5, 0.5, 0.5), o + Vector3.new(x, 7.5 - math.abs(i - 3.5) * 0.25, 0), C.warm, Enum.Material.Neon, { Shape = Enum.PartType.Ball, CanCollide = false, Name = "DeckBulb" })
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
	chartPrompt.ActionText = "Read the tide chart"
	chartPrompt.Triggered:Connect(function(player)
		Services.MatchService.requestChart(player)
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

	-- Crew lockers: the wardrobe (outfits)
	local lockers = block(parent, Vector3.new(4, 7, 1.4), o + Vector3.new(-15.3, 3.5, 10.5), Color3.fromRGB(72, 80, 78), Enum.Material.DiamondPlate, { Name = "CrewLockers" })
	for i = -1, 1 do
		block(parent, Vector3.new(0.08, 6.4, 0.08), o + Vector3.new(-15.3 + i * 1.3 + 0.65, 3.5, 9.75), C.metal, Enum.Material.Metal, { CanCollide = false })
	end
	local lockerPrompt = Instance.new("ProximityPrompt")
	lockerPrompt.ActionText = "Open wardrobe"
	lockerPrompt.ObjectText = "Crew lockers"
	lockerPrompt.MaxActivationDistance = 9
	lockerPrompt.RequiresLineOfSight = false
	lockerPrompt.GamepadKeyCode = Enum.KeyCode.ButtonA
	lockerPrompt.Parent = lockers
	lockerPrompt.Triggered:Connect(function(player)
		Services.MatchService.openShop(player, "Wardrobe")
	end)

	-- Workbench: per-crossing upgrades
	local bench = block(parent, Vector3.new(6, 3, 2.6), o + Vector3.new(-6, 1.5, -10.5), Color3.fromRGB(86, 66, 46), Enum.Material.WoodPlanks, { Name = "Workbench" })
	block(parent, Vector3.new(5, 0.2, 0.2), o + Vector3.new(-6, 5.5, -11.6), C.metal, Enum.Material.Metal)
	for i = -2, 2 do
		block(parent, Vector3.new(0.15, 0.9, 0.15), o + Vector3.new(-6 + i, 4.9, -11.6), C.metal, Enum.Material.Metal, { CanCollide = false }) -- hanging tools
	end
	block(parent, Vector3.new(0.6, 0.6, 0.6), o + Vector3.new(-4.2, 3.3, -10.5), Color3.fromRGB(110, 40, 30), Enum.Material.Metal) -- vice
	local benchLight = Instance.new("PointLight")
	benchLight.Range = 12
	benchLight.Brightness = 1.4
	benchLight.Color = C.warm
	benchLight.Shadows = true
	benchLight.Parent = block(parent, Vector3.new(0.6, 0.4, 0.6), o + Vector3.new(-6, 7, -10.5), C.warm, Enum.Material.Neon, { CanCollide = false })
	local benchPrompt = Instance.new("ProximityPrompt")
	benchPrompt.ActionText = "Use workbench"
	benchPrompt.ObjectText = "Workbench"
	benchPrompt.MaxActivationDistance = 9
	benchPrompt.RequiresLineOfSight = false
	benchPrompt.GamepadKeyCode = Enum.KeyCode.ButtonA
	benchPrompt.Parent = bench
	benchPrompt.Triggered:Connect(function(player)
		Services.MatchService.openMenu(player, "OpenWorkbench")
	end)

	-- Repairs board: permanent homebase upgrades
	local board = block(parent, Vector3.new(4, 3, 0.3), o + Vector3.new(-15.9, 4, -4), Color3.fromRGB(120, 100, 76), Enum.Material.WoodPlanks, { Name = "RepairsBoard" })
	local boardPrompt = Instance.new("ProximityPrompt")
	boardPrompt.ActionText = "Plan repairs"
	boardPrompt.ObjectText = "The Meridian"
	boardPrompt.MaxActivationDistance = 9
	boardPrompt.RequiresLineOfSight = false
	boardPrompt.GamepadKeyCode = Enum.KeyCode.ButtonA
	boardPrompt.Parent = board
	boardPrompt.Triggered:Connect(function(player)
		Services.MatchService.openMenu(player, "OpenRepairs")
	end)

	-- Repairable stations (visuals toggled by setFerryRepairs)
	local stations = Instance.new("Folder")
	stations.Name = "Stations"
	stations.Parent = parent
	local gen = block(stations, Vector3.new(3, 2.4, 2), o + Vector3.new(-26, 1.2, 9), Color3.fromRGB(90, 80, 40), Enum.Material.Metal, { Name = "generator" })
	local genLight = Instance.new("PointLight")
	genLight.Name = "On"
	genLight.Color = Color3.fromRGB(140, 255, 120)
	genLight.Range = 6
	genLight.Enabled = false
	genLight.Parent = gen
	local mast = block(stations, Vector3.new(0.4, 14, 0.4), o + Vector3.new(-23, 19.5, 0), C.metal, Enum.Material.Metal, { Name = "radio" })
	local mastLight = Instance.new("PointLight")
	mastLight.Name = "On"
	mastLight.Color = Color3.fromRGB(255, 60, 50)
	mastLight.Range = 10
	mastLight.Enabled = false
	mastLight.Parent = block(stations, Vector3.new(0.5, 0.5, 0.5), o + Vector3.new(-23, 26.7, 0), Color3.fromRGB(255, 60, 50), Enum.Material.Neon, { Name = "radioBeacon" })
	block(stations, Vector3.new(6, 1.2, 2.6), o + Vector3.new(10, 0.6, 11), Color3.fromRGB(200, 196, 186), Enum.Material.Fabric, { Name = "sickbay", Transparency = 0.7 })
	block(stations, Vector3.new(5, 5, 0.6), o + Vector3.new(29, 2.5, -9), Color3.fromRGB(80, 64, 48), Enum.Material.WoodPlanks, { Name = "armory", Transparency = 0.7 })

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

-- Lighting --------------------------------------------------------------------------------

local atmosphere, colorCorrection

local function setupLighting()
	-- Overcast dusk: readable, cold and moody (night is a modifier, not the default)
	Lighting.ClockTime = 17.4
	Lighting.GeographicLatitude = 50
	Lighting.Brightness = 2.2
	Lighting.Ambient = Color3.fromRGB(62, 68, 74)
	Lighting.OutdoorAmbient = Color3.fromRGB(112, 120, 128)
	Lighting.ColorShift_Top = Color3.fromRGB(255, 224, 196)
	-- sky light on every surface: makes normal / roughness maps and wet metal read properly
	Lighting.EnvironmentDiffuseScale = 0.65
	Lighting.EnvironmentSpecularScale = 1
	Lighting.ShadowSoftness = 0.25
	Lighting.GlobalShadows = true
	Lighting.ExposureCompensation = 0.25

	atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Density = 0.34
	atmosphere.Offset = 0.3
	atmosphere.Color = Color3.fromRGB(196, 202, 204)
	atmosphere.Decay = Color3.fromRGB(118, 126, 128)
	atmosphere.Glare = 0
	atmosphere.Haze = 0.3
	atmosphere.Parent = Lighting

	colorCorrection = Instance.new("ColorCorrectionEffect")
	colorCorrection.Name = "AftertideGrade"
	colorCorrection.Saturation = -0.22
	colorCorrection.Contrast = 0.16
	colorCorrection.Brightness = 0.01
	colorCorrection.TintColor = Color3.fromRGB(230, 236, 240)
	colorCorrection.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.6
	bloom.Size = 24
	bloom.Threshold = 1.6
	bloom.Parent = Lighting
end

-- Custom skyboxes (Config/Skies). Each face ID is a Decal upload: the server reads the
-- Decal's underlying image once (InsertService), falling back to the ID itself.
local InsertService = game:GetService("InsertService")
local Skies = require(Shared.Config.Skies)
local skyObject
local textureCache = {}

local function skyTexture(id)
	if textureCache[id] then
		return textureCache[id]
	end
	local texture = "rbxassetid://" .. tostring(id)
	local ok, model = pcall(function()
		return InsertService:LoadAsset(id)
	end)
	if ok and model then
		local decal = model:FindFirstChildWhichIsA("Decal", true)
		if decal and decal.Texture ~= "" then
			texture = decal.Texture
		end
		model:Destroy()
	end
	textureCache[id] = texture
	return texture
end

local currentSky
local function applySky(name)
	local ids = Skies[name or "ferry"] or Skies.ferry
	if not ids or currentSky == name then
		return
	end
	currentSky = name
	if not skyObject then
		skyObject = Lighting:FindFirstChildOfClass("Sky") or Instance.new("Sky")
		skyObject.Name = "AftertideSky"
		skyObject.CelestialBodiesShown = true
		skyObject.SunAngularSize = 14
		skyObject.MoonAngularSize = 9
		skyObject.Parent = Lighting
	end
	task.spawn(function()
		local side = skyTexture(ids.Side)
		local up, dn = skyTexture(ids.Up), skyTexture(ids.Dn)
		if currentSky ~= name then
			return
		end
		skyObject.SkyboxBk, skyObject.SkyboxFt, skyObject.SkyboxLf, skyObject.SkyboxRt = side, side, side, side
		skyObject.SkyboxUp, skyObject.SkyboxDn = up, dn
		skyObject.StarCount = name == "night" and 2500 or 0
	end)
end

local clouds
local function setupSky()
	clouds = Workspace.Terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	clouds.Cover = 0.55
	clouds.Density = 0.6
	clouds.Color = Color3.fromRGB(230, 232, 234)
	clouds.Parent = Workspace.Terrain
end

local FERRY_LIGHT = { sky = "ferry", clouds = 0.62, cloudColor = { 240, 222, 206 }, wind = { 10, 0, 4 }, clock = 17.6, brightness = 2.4, ambient = { 86, 84, 84 }, outdoor = { 140, 134, 128 }, fog = 0.3, haze = 1.4, fogColor = { 226, 184, 150 }, tint = { 248, 238, 228 }, saturation = -0.1, contrast = 0.12, shift = { 255, 220, 184 } }

local function rgb(t)
	return Color3.fromRGB(t[1], t[2], t[3])
end

-- Map lighting preset, adjusted by the route's modifier (Nightfall turns it to night).
local function applyPreset(L, modifier)
	modifier = modifier or {}
	local night = modifier.night == true
	Lighting.ClockTime = night and 0.6 or L.clock
	Lighting.Brightness = night and 1.4 or L.brightness
	Lighting.Ambient = night and Color3.fromRGB(32, 36, 42) or rgb(L.ambient)
	local boost = (modifier.ambientBoost or 0) * 50
	local o = night and { 48, 54, 64 } or L.outdoor
	Lighting.OutdoorAmbient = Color3.fromRGB(math.min(255, o[1] + boost), math.min(255, o[2] + boost), math.min(255, o[3] + boost))
	Lighting.ColorShift_Top = rgb(L.shift)
	if atmosphere then
		-- light haze only: heavy Haze paints over the skybox and gives the stock Roblox look
		local density = L.fog * 0.8 + ((modifier.fogDensity or 0.34) - 0.34)
		TweenService:Create(atmosphere, TweenInfo.new(3), { Density = math.clamp(density, 0.12, 0.6) }):Play()
		atmosphere.Haze = math.min(L.haze, 2) * 0.25
		atmosphere.Glare = 0
		atmosphere.Offset = 0.15
		atmosphere.Color = night and Color3.fromRGB(40, 46, 58) or rgb(L.fogColor)
		atmosphere.Decay = night and Color3.fromRGB(20, 24, 32) or rgb(L.fogColor):Lerp(Color3.new(0.3, 0.32, 0.36), 0.5)
	end
	applySky(night and "night" or (L.sky or "ferry"))
	-- weather: volumetric clouds and wind (moves grass, clouds and particles)
	if clouds then
		local cover = L.clouds or 0.55
		TweenService:Create(clouds, TweenInfo.new(4), {
			Cover = night and math.max(cover, 0.6) or cover,
			Density = L.cloudDensity or 0.6,
			Color = night and Color3.fromRGB(70, 76, 86) or rgb(L.cloudColor or { 232, 234, 236 }),
		}):Play()
	end
	local wind = L.wind or { 6, 0, 3 }
	local gust = modifier.id == "Squall" and 3 or 1
	Workspace.GlobalWind = Vector3.new(wind[1], wind[2], wind[3]) * gust
	if colorCorrection then
		colorCorrection.TintColor = rgb(L.tint)
		colorCorrection.Saturation = L.saturation
		colorCorrection.Contrast = L.contrast
	end
end

function MapService.applyFerryLighting()
	applyPreset(FERRY_LIGHT, nil)
end

function MapService.applyModifier(modifier)
	applyPreset(MapService.currentMap and MapService.currentMap.lighting or FERRY_LIGHT, modifier)
end

-- Builds a map (terrain + geometry) and loads its data. Rebuilt only when it changes.
local mapFolder, currentMapId
function MapService.loadMap(mapId, rng)
	local def = MAP_MODULES[mapId] or MAP_MODULES.CanneryRow
	if currentMapId == def.id and mapFolder and mapFolder.Parent then
		return
	end
	if mapFolder then
		mapFolder:Destroy()
	end
	MapKit.clearTerrain()
	local world = Workspace:FindFirstChild("World")
	mapFolder = Instance.new("Folder")
	mapFolder.Name = "Map_" .. def.id
	mapFolder.Parent = world
	local data = def.build(mapFolder, Random.new(rng:NextInteger(1, 1e6)))
	-- invisible boundary so nobody can walk off the edge of the map
	for _, w in { { Vector3.new(246, 120, 2), Vector3.new(0, 40, -122) }, { Vector3.new(246, 120, 2), Vector3.new(0, 40, 122) }, { Vector3.new(2, 120, 246), Vector3.new(-122, 40, 0) }, { Vector3.new(2, 120, 246), Vector3.new(122, 40, 0) } } do
		block(mapFolder, w[1], w[2], Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, { Name = "Boundary", Transparency = 1, CanQuery = false, CastShadow = false })
	end
	-- snap every gameplay position onto the actual ground (hills, house floors)
	local function snap(v)
		return Vector3.new(v.X, MapKit.ground(v.X, v.Z, { Workspace.Terrain, mapFolder }), v.Z)
	end
	local function snapList(list)
		local out = {}
		for i, v in list do
			out[i] = snap(v)
		end
		return out
	end
	MapService.StartSpawns = snapList(data.StartSpawns)
	MapService.ExtractionPos = snap(data.ExtractionPos)
	MapService.LanternPos = snap(data.LanternPos)
	MapService.SupplyCandidates = snapList(data.SupplyCandidates)
	MapService.LootSpots = snapList(data.LootSpots)
	MapService.EdgeSpawns = snapList(data.EdgeSpawns)
	MapService.PatrolRoutes = {}
	for i, route in data.PatrolRoutes do
		MapService.PatrolRoutes[i] = snapList(route)
	end
	MapService.ContainerSpots = {}
	for i, c in data.ContainerSpots do
		MapService.ContainerSpots[i] = { pos = snap(c.pos), type = c.type, yaw = c.yaw }
	end
	MapService.Doorways = data.Doorways or {}
	MapService.currentMap = def
	currentMapId = def.id
	Workspace:SetAttribute("MapName", def.name)
end

function MapService.mapName(mapId)
	local def = MAP_MODULES[mapId]
	return def and def.name or mapId
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

local doors = {}

local function makeDoor(parent, hinge, width, along, closedNow)
	along = Vector3.new(along.X, 0, along.Z).Unit
	local size = Vector3.new(width, 8.6, 0.4)
	local closedCF = CFrame.fromMatrix(hinge + along * (width / 2) + Vector3.new(0, 4.3, 0), along, Vector3.new(0, 1, 0))
	local hingeCF = CFrame.new(hinge + Vector3.new(0, 4.3, 0))
	local openCF = hingeCF * CFrame.Angles(0, math.rad(95), 0) * hingeCF:ToObjectSpace(closedCF)
	local door = block(parent, size, closedNow and closedCF or openCF, Color3.fromRGB(92, 78, 62), Enum.Material.WoodPlanks, { Name = "Door" })
	local modifier = Instance.new("PathfindingModifier")
	modifier.PassThrough = true -- Hushed path through doors; they push them open
	modifier.Parent = door
	local record = { part = door, open = not closedNow, closedCF = closedCF, openCF = openCF }
	local prompt = makePrompt(door, closedNow and "Open" or "Close", "Door", 0)
	prompt.MaxActivationDistance = 7
	record.prompt = prompt
	function record.set(open, byPlayer)
		if record.open == open then
			return
		end
		record.open = open
		prompt.ActionText = open and "Close" or "Open"
		TweenService:Create(door, TweenInfo.new(0.5, Enum.EasingStyle.Quad), { CFrame = open and openCF or closedCF }):Play()
		Sfx.at(door.Position, "Door", 0.6, 60)
		if byPlayer then
			Services.PerceptionService.emitNoise(door.Position, 7, "door", byPlayer)
		end
	end
	prompt.Triggered:Connect(function(player)
		record.set(not record.open, player)
	end)
	table.insert(doors, record)
end

local lantern

function MapService.getLantern()
	return lantern
end

function MapService.resetEncounter(modifier, rng, encounterType, pall, mapId)
	MapService.loadMap(mapId or "CanneryRow", rng)
	encounterFolder:ClearAllChildren()
	table.clear(doors)
	lantern = nil

	-- supply crates (Salvage objective)
	if encounterType == "Salvage" then
		local picks = shuffled(MapService.SupplyCandidates, rng)
		for i = 1, math.min(Encounters.Types.Salvage.crates, #picks) do
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
	end

	-- the signal lantern (Lantern Watch / finale)
	if encounterType == "LanternWatch" then
		local base = MapService.LanternPos
		block(encounterFolder, Vector3.new(3, 1, 3), base + Vector3.new(0, 0.5, 0), C.metal, Enum.Material.Metal)
		block(encounterFolder, Vector3.new(0.5, 6, 0.5), base + Vector3.new(0, 4, 0), C.metal, Enum.Material.Metal)
		lantern = block(encounterFolder, Vector3.new(1.6, 2, 1.6), base + Vector3.new(0, 8, 0), C.warm, Enum.Material.Neon, { Name = "SignalLantern" })
		local light = Instance.new("PointLight")
		light.Range = 40
		light.Brightness = 2.5
		light.Color = C.warm
		light.Shadows = true
		light.Parent = lantern
		volume(encounterFolder, Vector3.new(30, 10, 30), base + Vector3.new(0, 5, 0), "LitZone")
	end

	-- doors (some start closed)
	for _, d in MapService.Doorways do
		makeDoor(encounterFolder, d.hinge, d.width, d.dir, rng:NextNumber() < 0.5)
	end

	-- scavenging: containers + loose items
	Services.LootService.populate(encounterFolder, rng, pall or 1, MapService.ContainerSpots, MapService.LootSpots)
	encounterFolder:SetAttribute("Modifier", modifier.id)

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

-- Shows which homebase repairs are done (any player in the server owns them).
function MapService.setFerryRepairs(owned)
	local ferry = Workspace:FindFirstChild("World") and Workspace.World:FindFirstChild("Meridian")
	if not ferry then
		return
	end
	local stations = ferry:FindFirstChild("Stations")
	for _, d in ferry:GetDescendants() do
		if d:IsA("BasePart") and d.Name == "DeckBulb" then
			local light = d:FindFirstChildOfClass("PointLight")
			if light then
				light.Enabled = owned.lights == true
			end
			d.Material = owned.lights and Enum.Material.Neon or Enum.Material.Glass
		end
	end
	if stations then
		for _, id in { "generator", "radio", "sickbay", "armory" } do
			local part = stations:FindFirstChild(id)
			if part then
				part.Transparency = owned[id] and 0 or 0.7
				for _, light in part:GetDescendants() do
					if light:IsA("PointLight") then
						light.Enabled = owned[id] == true
					end
				end
			end
		end
		local beacon = stations:FindFirstChild("radioBeacon")
		local beaconLight = beacon and beacon:FindFirstChild("On")
		if beaconLight then
			beaconLight.Enabled = owned.radio == true
		end
	end
end

function MapService.ferrySpawn(index)
	local o = Game.FerryOrigin
	local pos = o + Vector3.new(-4 + ((index - 1) % 4) * 3, 3, 6)
	return CFrame.lookAt(pos, pos + Vector3.new(1, 0, 0))
end

function MapService.encounterSpawn(index)
	local pos = MapService.StartSpawns[(index - 1) % #MapService.StartSpawns + 1] + Vector3.new(0, 3, 0)
	local toward = MapService.ExtractionPos - pos
	toward = Vector3.new(toward.X, 0, toward.Z)
	return CFrame.lookAt(pos, pos + (toward.Magnitude > 1 and toward.Unit or Vector3.new(0, 0, -1)))
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

	MapKit.setAssets(Services.AssetService)

	encounterFolder = Instance.new("Folder")
	encounterFolder.Name = "Encounter"
	encounterFolder.Parent = world

	setupLighting()
	setupSky()
	task.spawn(function()
		-- warm the texture cache for every sky so map changes are instant
		for _, ids in Skies do
			skyTexture(ids.Side)
			skyTexture(ids.Up)
			skyTexture(ids.Dn)
		end
	end)
	MapService.applyFerryLighting()
	MapService.setFerryRepairs({})
	MapService.ready = true

	-- Hushed shove closed doors open when they reach them.
	while true do
		task.wait(0.4)
		for _, d in doors do
			if not d.open and d.part.Parent and #Services.EnemyService.findNear(d.part.Position, 5) > 0 then
				d.set(true, nil)
			end
		end
	end
end

return MapService
