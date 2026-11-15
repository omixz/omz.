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

-- Layout check: every solid fixture registers its box; overlaps are reported (Output / F2),
-- so nothing ends up lodged in the bridge or another fixture again.
local layoutBoxes = {}
local function register(name, cf, size)
	local half = size / 2
	local corners = {}
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			for _, sz in { -1, 1 } do
				table.insert(corners, (typeof(cf) == "CFrame" and cf or CFrame.new(cf)) * Vector3.new(half.X * sx, half.Y * sy, half.Z * sz))
			end
		end
	end
	local lo, hi = corners[1], corners[1]
	for _, c in corners do
		lo = lo:Min(c)
		hi = hi:Max(c)
	end
	table.insert(layoutBoxes, { name = name, lo = lo, hi = hi })
end

function MapService.getLeaderboardPart()
	return MapService.leaderboardPart
end

function MapService.checkLayout(label)
	local problems = 0
	local EPS = 0.05
	for i = 1, #layoutBoxes do
		for j = i + 1, #layoutBoxes do
			local a, b = layoutBoxes[i], layoutBoxes[j]
			if a.lo.X < b.hi.X - EPS and b.lo.X < a.hi.X - EPS and a.lo.Y < b.hi.Y - EPS and b.lo.Y < a.hi.Y - EPS and a.lo.Z < b.hi.Z - EPS and b.lo.Z < a.hi.Z - EPS then
				problems += 1
				warn(("[Layout] %s: %s overlaps %s"):format(label, a.name, b.name))
			end
		end
	end
	print(("[Layout] %s: %d fixtures, %d overlaps"):format(label, #layoutBoxes, problems))
	return problems
end

local function fixture(parent, name, size, position, color, material, props)
	local cf = typeof(position) == "CFrame" and position or CFrame.new(position)
	register(name, cf, size)
	local part = block(parent, size, cf, color, material, props)
	part.Name = name
	return part
end

local function prompt(parent, action, object, onTriggered, hold)
	local p = Instance.new("ProximityPrompt")
	p.ActionText = action
	p.ObjectText = object
	p.HoldDuration = hold or 0
	p.MaxActivationDistance = 9
	p.RequiresLineOfSight = false
	p.GamepadKeyCode = Enum.KeyCode.ButtonA
	p.Parent = parent
	p.Triggered:Connect(onTriggered)
	return p
end

-- Station signs: a floating name card above each station, readable from across the deck.
-- `hero` = the big gold "start here" card for the chart table.
local function stationSign(part, title, subtitle, color, offsetY, hero)
	local gui = Instance.new("BillboardGui")
	gui.Name = "StationSign"
	gui.Size = hero and UDim2.new(11, 0, 3.4, 0) or UDim2.new(7.5, 0, 2.2, 0)
	gui.StudsOffsetWorldSpace = Vector3.new(0, offsetY or 4, 0)
	gui.MaxDistance = hero and 220 or 70
	gui.LightInfluence = 0
	gui.Parent = part
	local card = Instance.new("Frame")
	card.Size = UDim2.fromScale(1, 1)
	card.BackgroundColor3 = hero and Color3.fromRGB(255, 196, 70) or Color3.fromRGB(20, 26, 30)
	card.BackgroundTransparency = hero and 0 or 0.15
	card.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.25, 0)
	corner.Parent = card
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = hero and 4 or 3
	stroke.Parent = card
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 0.62)
	t.Font = Enum.Font.Oswald
	t.TextScaled = true
	t.Text = title
	t.TextColor3 = hero and Color3.fromRGB(40, 24, 8) or color
	t.Parent = card
	local s = Instance.new("TextLabel")
	s.BackgroundTransparency = 1
	s.Position = UDim2.fromScale(0.05, 0.6)
	s.Size = UDim2.fromScale(0.9, 0.34)
	s.Font = Enum.Font.GothamMedium
	s.TextScaled = true
	s.Text = subtitle
	s.TextColor3 = hero and Color3.fromRGB(70, 44, 14) or Color3.fromRGB(230, 226, 214)
	s.Parent = card
	return gui
end

-- A striped canvas awning (market-stall style) over a station.
local function awning(parent, center, sizeX, sizeZ, height, colorA, colorB, alongX)
	local stripes = 6
	for i = 0, stripes - 1 do
		local col = i % 2 == 0 and colorA or colorB
		local w = (alongX and sizeX or sizeZ) / stripes
		local off = -((alongX and sizeX or sizeZ) / 2) + w * (i + 0.5)
		local size = alongX and Vector3.new(w, 0.25, sizeZ) or Vector3.new(sizeX, 0.25, w)
		local pos = center + (alongX and Vector3.new(off, height, 0) or Vector3.new(0, height, off))
		block(parent, size, CFrame.new(pos) * CFrame.Angles(alongX and 0.12 or 0, 0, alongX and 0 or 0.12), col, Enum.Material.Fabric, { CanCollide = false, CastShadow = true })
	end
end

local function potPlant(parent, at, scale)
	scale = scale or 1
	block(parent, Vector3.new(1.6, 1.4, 1.6) * scale, at + Vector3.new(0, 0.7 * scale, 0), Color3.fromRGB(196, 104, 64), Enum.Material.Slate, { Shape = Enum.PartType.Cylinder, CFrame = CFrame.new(at + Vector3.new(0, 0.7 * scale, 0)) * CFrame.Angles(0, 0, math.pi / 2) })
	for i, c in { { 0, 2.1, 0, 2.2 }, { 0.5, 2.6, 0.3, 1.5 }, { -0.4, 2.5, -0.3, 1.4 } } do
		local green = i == 1 and Color3.fromRGB(76, 150, 70) or Color3.fromRGB(96, 172, 80)
		block(parent, Vector3.new(c[4], c[4], c[4]) * scale, at + Vector3.new(c[1], c[2], c[3]) * scale, green, Enum.Material.LeafyGrass, { Shape = Enum.PartType.Ball, CanCollide = false })
	end
	if scale >= 1 then
		block(parent, Vector3.new(0.5, 0.5, 0.5), at + Vector3.new(0.4, 3.0, -0.2) * scale, Color3.fromRGB(240, 90, 110), Enum.Material.SmoothPlastic, { Shape = Enum.PartType.Ball, CanCollide = false })
	end
end

local function lifeRing(parent, cf)
	-- an orange ring of 8 short segments with white bands
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		local col = i % 2 == 0 and Color3.fromRGB(240, 110, 40) or Color3.fromRGB(245, 240, 230)
		block(parent, Vector3.new(0.5, 0.5, 0.95), cf * CFrame.Angles(0, 0, a) * CFrame.new(0, 1, 0) * CFrame.Angles(0, math.pi / 2, 0), col, Enum.Material.SmoothPlastic, { CanCollide = false })
	end
end

-- The Meridian: a car ferry turned home, moored at a sunny harbour pier.
-- 96 x 32 studs of deck, bridge at the stern (-X). Everything starts at the CHART TABLE in the
-- middle of the deck (gold light, "SET SAIL"); the other stations ring the deck with signs.
--   x -47..-31  bridge (crew cabin door, projects board, leaderboard on its front face)
--   x -28..-9   aft deck: crew lockers + quest board (starboard), workbench (port)
--   x  -9.. 9   midships plaza: chart table, Lucky Spin wheel (starboard), spawn line
--   x  26..34   Quartermaster (starboard), Purser's Office shop (port)
--   project rooms go where the scaffolding stands (see ROOMS)
local function buildFerry(parent)
	table.clear(layoutBoxes)
	local o = Game.FerryOrigin
	local M = Enum.Material
	local teak = Color3.fromRGB(164, 112, 70)
	local white = Color3.fromRGB(240, 236, 226)
	local teal = Color3.fromRGB(32, 150, 160)
	local red = Color3.fromRGB(196, 54, 46)
	local navy = Color3.fromRGB(30, 52, 84)

	-- harbour: clear turquoise water, a sandy shallows strip, the pier, a distant island
	block(parent, Vector3.new(1400, 1, 1400), o + Vector3.new(0, -6, 0), Color3.fromRGB(40, 150, 170), M.Glass, { Reflectance = 0.18, Transparency = 0.1, CanQuery = false })
	block(parent, Vector3.new(1400, 1, 1400), o + Vector3.new(0, -9, 0), Color3.fromRGB(196, 188, 140), M.Sand, { CanQuery = false })
	-- pier along the port side, with bollards and lamp posts
	block(parent, Vector3.new(140, 1.2, 12), o + Vector3.new(0, -0.4, -24), Color3.fromRGB(150, 116, 80), M.WoodPlanks)
	for x = -66, 66, 12 do
		block(parent, Vector3.new(1.2, 8, 1.2), o + Vector3.new(x, -4.5, -18.6), Color3.fromRGB(96, 74, 52), M.Wood)
		block(parent, Vector3.new(1.2, 8, 1.2), o + Vector3.new(x, -4.5, -29.4), Color3.fromRGB(96, 74, 52), M.Wood)
		block(parent, Vector3.new(0.9, 1.2, 0.9), o + Vector3.new(x + 6, 0.8, -19.2), Color3.fromRGB(40, 40, 44), M.Metal, { Shape = Enum.PartType.Cylinder, CFrame = CFrame.new(o + Vector3.new(x + 6, 0.8, -19.2)) * CFrame.Angles(0, 0, math.pi / 2) })
	end
	for _, x in { -54, -18, 18, 54 } do
		block(parent, Vector3.new(0.4, 9, 0.4), o + Vector3.new(x, 4.3, -29), Color3.fromRGB(40, 60, 70), M.Metal)
		MapKit.bulb(parent, o + Vector3.new(x, 9, -29), 20)
	end
	-- the island across the bay and a lighthouse
	for _, h in { { -160, 260, 120, 46 }, { -60, 300, 160, 60 }, { 70, 280, 130, 50 }, { 180, 250, 110, 40 } } do
		block(parent, Vector3.new(h[3], h[4] * 2, h[3] * 0.8), o + Vector3.new(h[1], -10, h[2]), Color3.fromRGB(86, 150, 74), M.Grass, { Shape = Enum.PartType.Ball, CanQuery = false, CanCollide = false })
	end
	for i = 0, 5 do
		block(parent, Vector3.new(5.2 - i * 0.3, 5, 5.2 - i * 0.3), o + Vector3.new(120, -3 + i * 5, 190), i % 2 == 0 and white or red, M.SmoothPlastic, { Shape = Enum.PartType.Cylinder, CFrame = CFrame.new(o + Vector3.new(120, -3 + i * 5, 190)) * CFrame.Angles(0, 0, math.pi / 2), CanQuery = false })
	end
	local lamp = block(parent, Vector3.new(2.4, 2.4, 2.4), o + Vector3.new(120, 28, 190), Color3.fromRGB(255, 230, 150), M.Neon, { Shape = Enum.PartType.Ball, CanQuery = false })
	local lampLight = Instance.new("PointLight")
	lampLight.Range = 40
	lampLight.Color = Color3.fromRGB(255, 220, 150)
	lampLight.Parent = lamp

	-- hull: white topsides, teal band, red below the waterline; teak deck
	block(parent, Vector3.new(96, 2, 32), o + Vector3.new(0, -1, 0), teak, M.WoodPlanks)
	for i = -5, 5 do -- deck seams
		block(parent, Vector3.new(96, 0.05, 0.12), o + Vector3.new(0, 0.02, i * 2.8), Color3.fromRGB(110, 76, 50), M.SmoothPlastic, { CanCollide = false, CanQuery = false })
	end
	for _, z in { -16.5, 16.5 } do
		block(parent, Vector3.new(97, 4, 1), o + Vector3.new(0, -3, z), white, M.SmoothPlastic)
		block(parent, Vector3.new(97.2, 1.1, 1.1), o + Vector3.new(0, -2.2, z), teal, M.SmoothPlastic)
		block(parent, Vector3.new(97, 3, 1), o + Vector3.new(0, -6.5, z), red, M.SmoothPlastic)
		-- railing: white posts and a teal top rail
		block(parent, Vector3.new(96, 0.35, 0.35), o + Vector3.new(0, 3.3, z * 0.97), teal, M.Metal)
		block(parent, Vector3.new(96, 0.2, 0.2), o + Vector3.new(0, 1.8, z * 0.97), white, M.Metal)
		for x = -46, 46, 4 do
			block(parent, Vector3.new(0.25, 3.4, 0.25), o + Vector3.new(x, 1.7, z * 0.97), white, M.Metal)
		end
		block(parent, Vector3.new(96, 3.5, 0.2), o + Vector3.new(0, 1.75, z * 0.985), white, M.SmoothPlastic, { Transparency = 1 }) -- invisible railing collision
		for _, x in { -22, 6, 34 } do
			lifeRing(parent, CFrame.new(o + Vector3.new(x, 2.4, z * 1.005)) * CFrame.Angles(0, z > 0 and 0 or math.pi, 0))
		end
	end
	for _, x in { -48.25, 48.25 } do
		block(parent, Vector3.new(0.35, 0.35, 32), o + Vector3.new(x, 3.3, 0), teal, M.Metal)
		block(parent, Vector3.new(0.2, 3.5, 32), o + Vector3.new(x, 1.75, 0), white, M.SmoothPlastic, { Transparency = 1 })
		block(parent, Vector3.new(1, 4, 33), o + Vector3.new(x * 1.01, -3, 0), white, M.SmoothPlastic)
		block(parent, Vector3.new(1.1, 1.1, 33.2), o + Vector3.new(x * 1.01, -2.2, 0), teal, M.SmoothPlastic)
		block(parent, Vector3.new(1, 3, 33), o + Vector3.new(x * 1.01, -6.5, 0), red, M.SmoothPlastic)
	end
	-- the name on both sides of the bow
	for _, z in { -17.05, 17.05 } do
		local plate = block(parent, Vector3.new(22, 2.6, 0.1), o + Vector3.new(30, -3.4, z), white, M.SmoothPlastic, { CanCollide = false, CanQuery = false })
		local gui = Instance.new("SurfaceGui")
		gui.Face = z < 0 and Enum.NormalId.Front or Enum.NormalId.Back
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 30
		gui.Parent = plate
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.Oswald
		label.TextScaled = true
		label.Text = "M E R I D I A N"
		label.TextColor3 = navy
		label.Parent = gui
	end

	-- bridge superstructure: white with a teal trim, a window band, a red-and-white funnel
	fixture(parent, "Bridge", Vector3.new(16, 12, 22), o + Vector3.new(-39, 6, 0), white, M.SmoothPlastic)
	block(parent, Vector3.new(16.2, 0.8, 22.2), o + Vector3.new(-39, 0.4, 0), teal, M.SmoothPlastic)
	block(parent, Vector3.new(18, 1, 24), o + Vector3.new(-39, 12.5, 0), navy, M.Metal)
	block(parent, Vector3.new(0.3, 2.6, 19), o + Vector3.new(-30.9, 9, 0), Color3.fromRGB(60, 110, 140), M.Glass, { Transparency = 0.25, Reflectance = 0.3 })
	for _, z in { -11.05, 11.05 } do
		block(parent, Vector3.new(14, 2.4, 0.3), o + Vector3.new(-39, 9, z), Color3.fromRGB(60, 110, 140), M.Glass, { Transparency = 0.25, Reflectance = 0.3 })
	end
	local funnelAt = o + Vector3.new(-39, 16.5, -9)
	register("Funnel", CFrame.new(funnelAt), Vector3.new(4.4, 7, 4.4))
	for i, band in { { -2.5, red, 2 }, { -0.5, white, 2 }, { 1.5, red, 2 }, { 3.0, Color3.fromRGB(30, 30, 32), 1 } } do
		block(parent, Vector3.new(band[3], 4.4, 4.4), funnelAt + Vector3.new(0, band[1], 0), band[2], M.SmoothPlastic, { Shape = Enum.PartType.Cylinder, CFrame = CFrame.new(funnelAt + Vector3.new(0, band[1], 0)) * CFrame.Angles(0, 0, math.pi / 2) })
		assert(i)
	end
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = SMOKE
	smoke.Rate = 3
	smoke.Lifetime = NumberRange.new(5, 8)
	smoke.Speed = NumberRange.new(2, 4)
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 9) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) })
	smoke.Color = ColorSequence.new(Color3.fromRGB(230, 230, 228))
	smoke.Acceleration = Vector3.new(3, 1, 1)
	smoke.Parent = block(parent, Vector3.new(1, 1, 1), funnelAt + Vector3.new(0, 4, 0), white, M.SmoothPlastic, { Transparency = 1, CanCollide = false, CanQuery = false })
	-- flags on a line from the funnel to the bow mast
	block(parent, Vector3.new(0.4, 14, 0.4), o + Vector3.new(44, 7, 0), white, M.Metal)
	local flagColors = { red, Color3.fromRGB(250, 200, 60), teal, Color3.fromRGB(70, 130, 220), Color3.fromRGB(240, 120, 60), white }
	for i = 1, 18 do
		local k = i / 19
		local p = funnelAt:Lerp(o + Vector3.new(44, 13.5, 0), k) + Vector3.new(0, -math.sin(k * math.pi) * 3, 0)
		block(parent, Vector3.new(0.1, 1.1, 0.9), CFrame.new(p) * CFrame.Angles(0, math.rad(90 + 12), 0) * CFrame.new(0, -0.5, 0), flagColors[i % #flagColors + 1], M.Fabric, { CanCollide = false, CanQuery = false })
	end

	-- on the bridge's front face (x = -31)
	local cabin = fixture(parent, "CabinDoor", Vector3.new(0.6, 8, 4), o + Vector3.new(-30.65, 4, 6), navy, M.Metal)
	stationSign(cabin, "CREW CABINS", "Change character", Color3.fromRGB(160, 200, 255), 5.5)
	prompt(cabin, "Change crew member", "Crew cabins", function(player)
		Services.MatchService.openCharacterSelect(player)
	end)
	local board = fixture(parent, "ProjectsBoard", Vector3.new(0.3, 4, 5), o + Vector3.new(-30.8, 4, -1.5), Color3.fromRGB(150, 116, 80), M.WoodPlanks)
	stationSign(board, "PROJECTS", "Upgrade the Meridian", Color3.fromRGB(120, 200, 230), 3.6)
	prompt(board, "Plan projects", "The Meridian", function(player)
		Services.MatchService.openMenu(player, "OpenRepairs")
	end)
	local leaderboard = fixture(parent, "Leaderboard", Vector3.new(0.3, 5, 6), o + Vector3.new(-30.8, 4.5, -7.8), Color3.fromRGB(30, 46, 64), M.SmoothPlastic)
	MapService.leaderboardPart = leaderboard

	-- aft deck, starboard: crew lockers (wardrobe) and the quest board
	local lockers = fixture(parent, "CrewLockers", Vector3.new(4, 7, 1.4), o + Vector3.new(-26, 3.5, 14.6), Color3.fromRGB(70, 130, 200), M.Metal)
	for i = -1, 1 do
		block(parent, Vector3.new(0.08, 6.4, 1.42), o + Vector3.new(-26 + i * 1.33 + 0.66, 3.5, 14.6), Color3.fromRGB(40, 80, 140), M.Metal, { CanCollide = false })
	end
	stationSign(lockers, "WARDROBE", "Outfits", Color3.fromRGB(240, 150, 200), 5.2)
	prompt(lockers, "Open wardrobe", "Crew lockers", function(player)
		Services.MatchService.openShop(player, "Wardrobe")
	end)
	local quests = fixture(parent, "QuestBoard", Vector3.new(5, 4, 0.4), o + Vector3.new(-18, 3.6, 14.8), Color3.fromRGB(176, 134, 88), M.WoodPlanks)
	for _, x in { -20.75, -15.25 } do
		fixture(parent, "QuestBoardPost", Vector3.new(0.4, 5.6, 0.4), o + Vector3.new(x, 2.8, 14.8), Color3.fromRGB(110, 80, 54), M.Wood)
	end
	for i, c in { Color3.fromRGB(250, 240, 200), Color3.fromRGB(255, 220, 160), Color3.fromRGB(230, 245, 255) } do
		block(parent, Vector3.new(1.2, 1.5, 0.05), o + Vector3.new(-19.6 + i * 1.3, 3.7 + (i % 2) * 0.3, 14.57), c, M.SmoothPlastic, { CanCollide = false })
	end
	stationSign(quests, "QUESTS", "Daily & weekly rewards", Color3.fromRGB(250, 210, 110), 3.8)
	prompt(quests, "Read the board", "Quests", function(player)
		Services.MatchService.openMenu(player, "OpenQuests")
	end)

	-- aft deck, port: the workbench
	local bench = fixture(parent, "Workbench", Vector3.new(6, 3, 2.6), o + Vector3.new(-14, 1.5, -13.6), Color3.fromRGB(140, 100, 64), M.WoodPlanks)
	block(parent, Vector3.new(0.6, 0.6, 0.6), o + Vector3.new(-12, 3.3, -13.6), Color3.fromRGB(200, 60, 40), M.Metal) -- vice
	block(parent, Vector3.new(1.4, 0.5, 0.8), o + Vector3.new(-15.5, 3.25, -13.4), Color3.fromRGB(230, 170, 40), M.Metal) -- toolbox
	stationSign(bench, "WORKBENCH", "Upgrade your guns", Color3.fromRGB(255, 170, 90), 4.2)
	prompt(bench, "Use workbench", "Workbench", function(player)
		Services.MatchService.openMenu(player, "OpenWorkbench")
	end)

	-- midships plaza: compass rose and the CHART TABLE (start here)
	block(parent, Vector3.new(0.12, 15, 15), o + Vector3.new(0, 0.06, -1), Color3.fromRGB(196, 150, 96), M.SmoothPlastic, { Shape = Enum.PartType.Cylinder, CFrame = CFrame.new(o + Vector3.new(0, 0.06, -1)) * CFrame.Angles(0, 0, math.pi / 2), CanCollide = false })
	block(parent, Vector3.new(0.14, 12.6, 12.6), o + Vector3.new(0, 0.07, -1), Color3.fromRGB(150, 104, 62), M.WoodPlanks, { Shape = Enum.PartType.Cylinder, CFrame = CFrame.new(o + Vector3.new(0, 0.07, -1)) * CFrame.Angles(0, 0, math.pi / 2), CanCollide = false })
	for i = 0, 3 do
		block(parent, Vector3.new(0.6, 0.06, 12), CFrame.new(o + Vector3.new(0, 0.12, -1)) * CFrame.Angles(0, i * math.pi / 4, 0), Color3.fromRGB(240, 220, 170), M.SmoothPlastic, { CanCollide = false })
	end
	local chart = fixture(parent, "ChartTable", Vector3.new(5, 3, 3), o + Vector3.new(0, 1.5, -2), Color3.fromRGB(110, 76, 48), M.WoodPlanks)
	block(parent, Vector3.new(4.6, 0.1, 2.6), o + Vector3.new(0, 3.05, -2), Color3.fromRGB(236, 222, 186), M.SmoothPlastic)
	block(parent, Vector3.new(1.2, 0.12, 0.12), o + Vector3.new(0.6, 3.15, -2.2), red, M.SmoothPlastic, { CanCollide = false })
	-- the beacon: a column of warm light over the table, visible from anywhere on deck
	local beam = block(parent, Vector3.new(30, 1.3, 1.3), o + Vector3.new(0, 18.2, -2), Color3.fromRGB(255, 210, 110), M.Neon, { Shape = Enum.PartType.Cylinder, CFrame = CFrame.new(o + Vector3.new(0, 18.2, -2)) * CFrame.Angles(0, 0, math.pi / 2), Transparency = 0.55, CanCollide = false, CanQuery = false, CastShadow = false, Name = "SailBeacon" })
	local glow = Instance.new("PointLight")
	glow.Range = 16
	glow.Brightness = 2
	glow.Color = Color3.fromRGB(255, 210, 120)
	glow.Parent = chart
	stationSign(beam, "SET SAIL", "Start here: choose a mission", Color3.fromRGB(255, 255, 255), -10.5, true)
	local chartPrompt = prompt(chart, "Set sail (choose a mission)", "Tide chart", function(player)
		Services.MatchService.requestChart(player)
	end, 0.5)
	chartPrompt.Name = "ChartPrompt"
	chartPrompt.MaxActivationDistance = 12
	local guide = Instance.new("Attachment")
	guide.Name = "GuideTarget"
	guide.Position = Vector3.new(0, 2, 0)
	guide.Parent = chart

	-- midships, starboard: the Lucky Spin wheel (free daily spin)
	local wheelAt = o + Vector3.new(-3, 4.6, 14.6)
	local wheelBase = fixture(parent, "SpinWheelStand", Vector3.new(5, 1.2, 1.6), o + Vector3.new(-3, 0.6, 14.6), navy, M.Metal)
	register("SpinWheel", CFrame.new(wheelAt), Vector3.new(6.2, 6.2, 0.8))
	local wheel = Instance.new("Model")
	wheel.Name = "SpinWheel"
	wheel.Parent = parent
	local disc = block(wheel, Vector3.new(0.4, 6, 6), CFrame.new(wheelAt) * CFrame.Angles(0, math.pi / 2, 0), white, M.SmoothPlastic, { Shape = Enum.PartType.Cylinder, CanCollide = false })
	wheel.PrimaryPart = disc
	local wedgeColors = { red, Color3.fromRGB(250, 200, 60), teal, Color3.fromRGB(150, 110, 230), Color3.fromRGB(240, 120, 60), Color3.fromRGB(90, 190, 110), Color3.fromRGB(70, 130, 220), Color3.fromRGB(240, 90, 150) }
	for i = 0, 7 do
		block(wheel, Vector3.new(0.9, 2.7, 0.2), CFrame.new(wheelAt) * CFrame.Angles(0, 0, i * math.pi / 4) * CFrame.new(0, 1.5, -0.25), wedgeColors[i + 1], M.SmoothPlastic, { CanCollide = false })
	end
	block(wheel, Vector3.new(0.5, 1, 1), CFrame.new(wheelAt + Vector3.new(0, 0, -0.4)) * CFrame.Angles(0, math.pi / 2, 0), Color3.fromRGB(250, 210, 80), M.Metal, { Shape = Enum.PartType.Cylinder, CanCollide = false })
	block(parent, Vector3.new(0.5, 0.9, 0.5), wheelAt + Vector3.new(0, 3.3, -0.4), Color3.fromRGB(250, 210, 80), M.Metal, { CanCollide = false }) -- pointer
	for _, x in { -2.7, 2.7 } do
		block(parent, Vector3.new(0.4, 4.4, 0.4), o + Vector3.new(-3 + x, 3.2, 14.9), navy, M.Metal)
	end
	CollectionService:AddTag(wheel, "SpinWheel")
	stationSign(wheelBase, "LUCKY SPIN", "1 free spin every day!", Color3.fromRGB(250, 200, 60), 9)
	prompt(wheelBase, "Spin the wheel", "Lucky Spin", function(player)
		Services.MatchService.openMenu(player, "OpenSpin")
	end)

	-- the Purser's Office (Robux shop): a yellow kiosk with a striped awning
	local booth = fixture(parent, "PursersOffice", Vector3.new(7, 8, 5), o + Vector3.new(30, 4, -12.5), Color3.fromRGB(250, 206, 90), M.SmoothPlastic)
	block(parent, Vector3.new(5, 2.4, 0.2), o + Vector3.new(30, 3.6, -9.95), Color3.fromRGB(70, 120, 160), M.Glass, { Transparency = 0.3, CanCollide = false })
	awning(parent, o + Vector3.new(30, 0, -8.6), 8, 3, 7.4, red, white, true)
	local boothLight = Instance.new("PointLight")
	boothLight.Range = 12
	boothLight.Brightness = 1.2
	boothLight.Color = C.warm
	boothLight.Parent = booth
	stationSign(booth, "SHOP", "Supplies, ammo & outfits", Color3.fromRGB(255, 120, 110), 6)
	prompt(booth, "Open the shop", "The Purser's Office", function(player)
		Services.MatchService.openShop(player)
	end)

	-- the Quartermaster's stall (Scrip store: guns, loadout, kits)
	local qm = fixture(parent, "Quartermaster", Vector3.new(6, 3, 2.4), o + Vector3.new(27, 1.5, 13.6), Color3.fromRGB(140, 104, 64), M.WoodPlanks)
	fixture(parent, "QuartermasterRack", Vector3.new(6, 6, 0.6), o + Vector3.new(27, 3, 15.4), Color3.fromRGB(96, 74, 52), M.WoodPlanks)
	for i = -2, 2 do -- guns on the rack
		block(parent, Vector3.new(0.2, 3.2, 0.25), o + Vector3.new(27 + i * 1.1, 3.6, 15.0), Color3.fromRGB(70, 56, 44), M.Wood, { CanCollide = false })
	end
	awning(parent, o + Vector3.new(27, 0, 12.6), 7, 3.2, 7.2, Color3.fromRGB(40, 110, 70), Color3.fromRGB(236, 226, 196), true)
	local qmLight = Instance.new("PointLight")
	qmLight.Range = 10
	qmLight.Color = C.warm
	qmLight.Parent = qm
	stationSign(qm, "QUARTERMASTER", "Unlock guns · loadout · kits", Color3.fromRGB(140, 220, 140), 6.2)
	prompt(qm, "Trade", "The Quartermaster", function(player)
		Services.MatchService.openMenu(player, "OpenQuartermaster")
	end)

	-- cargo with bright tarps
	fixture(parent, "Cargo", Vector3.new(10, 8.6, 6), o + Vector3.new(40, 4.3, 0), Color3.fromRGB(32, 120, 150), M.CorrodedMetal)
	block(parent, Vector3.new(10.4, 0.3, 6.4), o + Vector3.new(40, 8.75, 0), Color3.fromRGB(240, 120, 50), M.Fabric)

	-- plants, benches and crates around the plaza (registered so nothing ends up in them)
	for _, spot in { { -8, -14.6 }, { 8, -14.6 }, { -10, 14.6 }, { 4.5, 14.6 }, { -29, -9 }, { 22, 14.6 } } do
		local at = o + Vector3.new(spot[1], 0, spot[2])
		register("Planter", CFrame.new(at + Vector3.new(0, 1.2, 0)), Vector3.new(2.2, 2.4, 2.2))
		potPlant(parent, at, 1)
	end
	for _, spot in { { -4, -14.8 }, { 4, -14.8 } } do
		fixture(parent, "Bench", Vector3.new(4, 1.2, 1.4), o + Vector3.new(spot[1], 0.6, spot[2]), Color3.fromRGB(150, 104, 66), M.WoodPlanks)
	end

	-- string lights over the deck (always on; the Deck Lights project adds colour)
	for i = 0, 9 do
		local x = -27 + i * 6
		local bulb = block(parent, Vector3.new(0.5, 0.5, 0.5), o + Vector3.new(x, 7.5 - math.abs(i - 4.5) * 0.2, 2), C.warm, M.Neon, { Shape = Enum.PartType.Ball, CanCollide = false, Name = "DeckBulb" })
		local light = Instance.new("PointLight")
		light.Range = 12
		light.Brightness = 0.9
		light.Color = C.warm
		light.Parent = bulb
	end
	block(parent, Vector3.new(56, 0.15, 0.15), o + Vector3.new(0, 7.6, 2), C.metal, M.Metal, { CanCollide = false })

	local rooms = Instance.new("Folder")
	rooms.Name = "Rooms"
	rooms.Parent = parent
	MapService.checkLayout("Meridian")
end

-- Project rooms: built when anyone in the server owns the project, scaffolding otherwise.
local ROOMS = {}
local function shell(parent, name, lo, hi, color, doorSide)
	-- a simple room: walls with a door gap, a roof, one light
	local o = Game.FerryOrigin
	local M = Enum.Material
	local h = hi.Y - lo.Y
	local cx, cz = (lo.X + hi.X) / 2, (lo.Z + hi.Z) / 2
	local w, d = hi.X - lo.X, hi.Z - lo.Z
	register(name, CFrame.new(o + Vector3.new(cx, lo.Y + h / 2, cz)), Vector3.new(w, h, d))
	for _, side in { "N", "S", "E", "W" } do
		local alongX = side == "N" or side == "S"
		local len = alongX and w or d
		local pos = side == "N" and Vector3.new(cx, 0, hi.Z) or side == "S" and Vector3.new(cx, 0, lo.Z) or side == "E" and Vector3.new(hi.X, 0, cz) or Vector3.new(lo.X, 0, cz)
		if side == doorSide then
			local seg = (len - 4) / 2
			for _, sgn in { -1, 1 } do
				local off = (2 + seg / 2) * sgn
				local p2 = pos + (alongX and Vector3.new(off, 0, 0) or Vector3.new(0, 0, off))
				block(parent, alongX and Vector3.new(seg, h, 0.4) or Vector3.new(0.4, h, seg), o + p2 + Vector3.new(0, lo.Y + h / 2, 0), color, M.CorrodedMetal)
			end
			block(parent, alongX and Vector3.new(4, h - 7.5, 0.4) or Vector3.new(0.4, h - 7.5, 4), o + pos + Vector3.new(0, lo.Y + 7.5 + (h - 7.5) / 2, 0), color, M.CorrodedMetal)
		else
			block(parent, alongX and Vector3.new(len, h, 0.4) or Vector3.new(0.4, h, len), o + pos + Vector3.new(0, lo.Y + h / 2, 0), color, M.CorrodedMetal)
		end
	end
	block(parent, Vector3.new(w + 0.6, 0.5, d + 0.6), o + Vector3.new(cx, hi.Y + 0.25, cz), C.metal, M.Metal)
	MapKit.bulb(parent, o + Vector3.new(cx, hi.Y - 1, cz), 14)
end

ROOMS.lights = { lo = nil } -- the string lights themselves
ROOMS.generator = { lo = Vector3.new(-28.5, 0, -15.2), hi = Vector3.new(-23.5, 4, -11), build = function(parent, r)
	local o = Game.FerryOrigin
	local g = block(parent, Vector3.new(5, 3.4, 4), o + Vector3.new(-26, 1.7, -13.1), Color3.fromRGB(90, 80, 40), Enum.Material.Metal, { Name = "generator" })
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(140, 255, 120)
	light.Range = 8
	light.Parent = g
	block(parent, Vector3.new(0.5, 6, 0.5), o + Vector3.new(-24.2, 6.4, -14.6), C.metal, Enum.Material.Metal) -- exhaust
	assert(r)
end }
ROOMS.workshop = { lo = Vector3.new(-19.5, 0, -15.6), hi = Vector3.new(-8.5, 9, -10), build = function(parent, r)
	local o = Game.FerryOrigin
	-- an open-fronted shed over the workbench: side walls, back wall, roof, tool rack
	for _, x in { r.lo.X, r.hi.X } do
		block(parent, Vector3.new(0.4, 9, r.hi.Z - r.lo.Z), o + Vector3.new(x, 4.5, (r.lo.Z + r.hi.Z) / 2), Color3.fromRGB(120, 104, 80), Enum.Material.WoodPlanks)
	end
	block(parent, Vector3.new(r.hi.X - r.lo.X, 9, 0.4), o + Vector3.new((r.lo.X + r.hi.X) / 2, 4.5, r.lo.Z), Color3.fromRGB(120, 104, 80), Enum.Material.WoodPlanks)
	block(parent, Vector3.new(r.hi.X - r.lo.X + 1, 0.5, r.hi.Z - r.lo.Z + 1), o + Vector3.new((r.lo.X + r.hi.X) / 2, 9.25, (r.lo.Z + r.hi.Z) / 2), C.roof, Enum.Material.CorrodedMetal)
	for i = -2, 2 do
		block(parent, Vector3.new(0.15, 1, 0.15), o + Vector3.new(-14 + i, 5, r.lo.Z + 0.4), C.metal, Enum.Material.Metal, { CanCollide = false })
	end
	MapKit.bulb(parent, o + Vector3.new(-14, 8, -12.8), 14)
end, noRegister = true }
ROOMS.sickbay = { lo = Vector3.new(8, 0, 9), hi = Vector3.new(20, 9, 15.6), build = function(parent, r)
	shell(parent, "Infirmary", r.lo, r.hi, Color3.fromRGB(200, 198, 190), "S")
	local o = Game.FerryOrigin
	block(parent, Vector3.new(6, 1.4, 2.6), o + Vector3.new(14, 0.7, 13.8), Color3.fromRGB(220, 216, 206), Enum.Material.Fabric) -- cot
	block(parent, Vector3.new(1.6, 3, 1), o + Vector3.new(9.5, 1.5, 14.6), Color3.fromRGB(170, 40, 34), Enum.Material.Metal) -- red-cross cabinet
end }
ROOMS.radio = { lo = Vector3.new(-44, 13, -5), hi = Vector3.new(-34, 19, 5), build = function(parent, r)
	shell(parent, "RadioRoom", r.lo, r.hi, Color3.fromRGB(150, 150, 140), "E")
	local o = Game.FerryOrigin
	block(parent, Vector3.new(0.4, 12, 0.4), o + Vector3.new(-39, 25.5, 0), C.metal, Enum.Material.Metal)
	local beacon = block(parent, Vector3.new(0.6, 0.6, 0.6), o + Vector3.new(-39, 31.8, 0), Color3.fromRGB(255, 60, 50), Enum.Material.Neon)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 60, 50)
	light.Range = 12
	light.Parent = beacon
end }
ROOMS.armory = { lo = Vector3.new(34, 0, 6), hi = Vector3.new(46, 9, 15.6), build = function(parent, r)
	shell(parent, "Armory", r.lo, r.hi, Color3.fromRGB(96, 104, 90), "S")
	local o = Game.FerryOrigin
	block(parent, Vector3.new(8, 5, 0.6), o + Vector3.new(40, 2.5, 15), Color3.fromRGB(80, 64, 48), Enum.Material.WoodPlanks) -- gun rack
end }
ROOMS.chartroom = { lo = Vector3.new(13, 0, -15.6), hi = Vector3.new(25, 9, -9), build = function(parent, r)
	shell(parent, "ChartRoom", r.lo, r.hi, Color3.fromRGB(140, 120, 96), "N")
	local o = Game.FerryOrigin
	block(parent, Vector3.new(5, 3, 3), o + Vector3.new(19, 1.5, -13), Color3.fromRGB(96, 70, 48), Enum.Material.WoodPlanks)
end }
ROOMS.lookout = { lo = Vector3.new(41, 0, -15.4), hi = Vector3.new(47, 22, -9.4), build = function(parent, r)
	local o = Game.FerryOrigin
	for _, x in { 41.5, 46.5 } do
		for _, z in { -15, -9.8 } do
			block(parent, Vector3.new(0.6, 18, 0.6), o + Vector3.new(x, 9, z), C.metal, Enum.Material.Metal)
		end
	end
	block(parent, Vector3.new(7, 0.6, 7), o + Vector3.new(44, 18.3, -12.4), C.metal, Enum.Material.DiamondPlate)
	block(parent, Vector3.new(7, 3, 0.3), o + Vector3.new(44, 20, -15.8), C.metal, Enum.Material.Metal)
	assert(r)
end }

-- Shows which projects are built (any player in the server owns them): rooms or scaffolding.
function MapService.setFerryRepairs(owned)
	local ferry = Workspace:FindFirstChild("World") and Workspace.World:FindFirstChild("Meridian")
	if not ferry then
		return
	end
	for _, d in ferry:GetDescendants() do
		if d:IsA("BasePart") and d.Name == "DeckBulb" then
			-- always lit; the Deck Lights project turns them into coloured festival lights
			local festive = { Color3.fromRGB(255, 120, 110), Color3.fromRGB(255, 210, 90), Color3.fromRGB(120, 220, 160), Color3.fromRGB(120, 180, 255), Color3.fromRGB(230, 140, 255) }
			local i = math.floor((d.Position.X + 100) / 6) % #festive + 1
			d.Color = owned.lights and festive[i] or C.warm
			local light = d:FindFirstChildOfClass("PointLight")
			if light then
				light.Color = d.Color
				light.Brightness = owned.lights and 1.3 or 0.9
			end
		end
	end
	local rooms = ferry:FindFirstChild("Rooms")
	if not rooms then
		return
	end
	rooms:ClearAllChildren()
	local o = Game.FerryOrigin
	-- re-register the static fixtures' boxes, then add rooms and check them all
	local static = {}
	for _, b in layoutBoxes do
		if not b.room then
			table.insert(static, b)
		end
	end
	table.clear(layoutBoxes)
	for _, b in static do
		table.insert(layoutBoxes, b)
	end
	for id, r in ROOMS do
		if r.lo then
			local folder = Instance.new("Folder")
			folder.Name = id
			folder.Parent = rooms
			local before = #layoutBoxes
			if owned[id] then
				r.build(folder, r)
			else
				-- scaffolding where the room will go, with a sign
				local M = Enum.Material
				local h = r.hi.Y - r.lo.Y
				for _, x in { r.lo.X + 0.3, r.hi.X - 0.3 } do
					for _, z in { r.lo.Z + 0.3, r.hi.Z - 0.3 } do
						block(folder, Vector3.new(0.3, h, 0.3), o + Vector3.new(x, r.lo.Y + h / 2, z), Color3.fromRGB(150, 110, 60), M.Metal, { CanCollide = false })
					end
				end
				block(folder, Vector3.new(r.hi.X - r.lo.X, 0.25, r.hi.Z - r.lo.Z), o + Vector3.new((r.lo.X + r.hi.X) / 2, r.hi.Y, (r.lo.Z + r.hi.Z) / 2), Color3.fromRGB(120, 140, 150), M.Fabric, { Transparency = 0.35, CanCollide = false })
				local sign = block(folder, Vector3.new(3, 1.4, 0.2), o + Vector3.new((r.lo.X + r.hi.X) / 2, r.lo.Y + 3, (r.lo.Z + r.hi.Z) / 2), Color3.fromRGB(230, 220, 190), M.SmoothPlastic, { CanCollide = false })
				local gui = Instance.new("SurfaceGui")
				gui.Face = Enum.NormalId.Front
				gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
				gui.PixelsPerStud = 40
				gui.Parent = sign
				local label = Instance.new("TextLabel")
				label.Size = UDim2.fromScale(1, 1)
				label.BackgroundTransparency = 1
				label.Font = Enum.Font.Oswald
				label.TextScaled = true
				label.TextColor3 = Color3.fromRGB(40, 36, 30)
				local p = require(Shared.Config.Projects).get(id)
				label.Text = "PROJECT: " .. (p and string.upper(p.name) or id)
				label.Parent = gui
			end
			if not r.noRegister and #layoutBoxes == before then
				register("Room_" .. id, CFrame.new(o + (r.lo + r.hi) / 2), r.hi - r.lo)
			end
			for i = before + 1, #layoutBoxes do
				layoutBoxes[i].room = true
			end
		end
	end
	MapService.checkLayout("Meridian + rooms")
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
	Lighting.EnvironmentDiffuseScale = 1
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
	colorCorrection.Saturation = 0.12
	colorCorrection.Contrast = 0.08
	colorCorrection.Brightness = 0.02
	colorCorrection.TintColor = Color3.fromRGB(255, 250, 242)
	colorCorrection.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.5
	bloom.Size = 26
	bloom.Threshold = 1.35
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

-- Test hook: resolve every sky face (used by tests/engine/sky.luau).
function MapService.resolveSkyTextures()
	local out = {}
	for name, ids in Skies do
		out[name] = { Side = skyTexture(ids.Side), Up = skyTexture(ids.Up), Dn = skyTexture(ids.Dn) }
	end
	return out
end

local clouds
local function setupSky()
	clouds = Workspace.Terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	clouds.Cover = 0.55
	clouds.Density = 0.6
	clouds.Color = Color3.fromRGB(230, 232, 234)
	clouds.Parent = Workspace.Terrain
end

-- sunny harbour afternoon: bright, warm, saturated
local FERRY_LIGHT = { sky = "ferry", clouds = 0.38, cloudDensity = 0.5, cloudColor = { 255, 255, 255 }, wind = { 8, 0, 4 }, clock = 15.2, brightness = 3.1, ambient = { 112, 110, 106 }, outdoor = { 152, 152, 150 }, fog = 0.2, haze = 0.6, fogColor = { 200, 222, 238 }, tint = { 255, 250, 242 }, saturation = 0.14, contrast = 0.08, shift = { 255, 236, 214 } }

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
	task.wait(0.2) -- terrain writes reach ray casts on the next physics steps (the engine scan showed this)
	local okTidy, removed, lowered, raised = pcall(MapKit.tidy, mapFolder)
	if okTidy then
		print(("[Layout] %s: removed %d lodged props, lowered %d, raised %d"):format(def.id, removed, lowered, raised))
	else
		warn("[Layout] tidy failed: " .. tostring(removed))
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

function MapService.getEncounterFolder()
	return encounterFolder
end
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
			local pos = Services.LootService.settle(picks[i], encounterFolder)
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

	-- Medicine Run: medical caches, mostly indoors
	if encounterType == "Medicine" then
		local picks = shuffled(MapService.LootSpots, rng)
		for i = 1, math.min(Encounters.Types.Medicine.count, #picks) do
			local pos = Services.LootService.settle(picks[i], encounterFolder)
			local case = block(encounterFolder, Vector3.new(2.2, 1.2, 1.5), pos + Vector3.new(0, 0.6, 0), Color3.fromRGB(226, 222, 212), Enum.Material.SmoothPlastic, { Name = "MedCache" })
			block(case, Vector3.new(0.9, 0.25, 0.05), pos + Vector3.new(0, 0.7, -0.78), Color3.fromRGB(180, 30, 30), Enum.Material.SmoothPlastic, { CanCollide = false })
			block(case, Vector3.new(0.25, 0.9, 0.05), pos + Vector3.new(0, 0.7, -0.78), Color3.fromRGB(180, 30, 30), Enum.Material.SmoothPlastic, { CanCollide = false })
			local glint = Instance.new("PointLight")
			glint.Range = 5
			glint.Brightness = 0.4
			glint.Color = Color3.fromRGB(255, 220, 220)
			glint.Parent = case
			makePrompt(case, "Take", "Medical cache", 1).Triggered:Connect(function(player)
				Services.MatchService.onCrateSalvaged(player, case)
			end)
		end
	end

	-- Restore the Signal: radio relays; repairing one is loud
	if encounterType == "Relay" then
		local cfg = Encounters.Types.Relay
		local picks = shuffled(MapService.SupplyCandidates, rng)
		for i = 1, math.min(cfg.count, #picks) do
			local pos = Services.LootService.settle(picks[i], encounterFolder)
			local box = block(encounterFolder, Vector3.new(2, 4, 1.4), pos + Vector3.new(0, 2, 0), Color3.fromRGB(96, 100, 104), Enum.Material.Metal, { Name = "Relay" })
			block(box, Vector3.new(0.15, 6, 0.15), pos + Vector3.new(0.6, 7, 0), C.metal, Enum.Material.Metal, { CanCollide = false })
			local lamp = block(box, Vector3.new(0.4, 0.4, 0.4), pos + Vector3.new(0.6, 10.2, 0), Color3.fromRGB(200, 60, 50), Enum.Material.Neon, { CanCollide = false })
			local p = makePrompt(box, "Repair relay", "Radio relay", cfg.hold)
			local holding = {}
			p.PromptButtonHoldBegan:Connect(function(player)
				holding[player] = true
				task.spawn(function()
					while holding[player] and p.Parent do
						Services.PerceptionService.emitNoise(box.Position, cfg.noise, "repair", player)
						Sfx.at(box.Position, "Search", 0.6, 60)
						task.wait(1.5)
					end
				end)
			end)
			p.PromptButtonHoldEnded:Connect(function(player)
				holding[player] = nil
			end)
			p.Triggered:Connect(function(player)
				holding[player] = nil
				lamp.Color = Color3.fromRGB(90, 230, 120)
				local light = Instance.new("PointLight")
				light.Color = lamp.Color
				light.Range = 10
				light.Parent = lamp
				Services.MatchService.onCrateSalvaged(player, box, true)
			end)
		end
	end

	-- Burn the Nests: salt crystal nests that take damage from guns, melee, fire, explosions
	if encounterType == "Nests" then
		local cfg = Encounters.Types.Nests
		local picks = shuffled(MapService.SupplyCandidates, rng)
		for i = 1, math.min(cfg.count, #picks) do
			local pos = Services.LootService.settle(picks[i], encounterFolder)
			local nest = Instance.new("Model")
			nest.Name = "Nest"
			nest:SetAttribute("NestHP", cfg.hp)
			nest:SetAttribute("NestMax", cfg.hp)
			local core = block(nest, Vector3.new(3.2, 2.2, 3.2), pos + Vector3.new(0, 1.1, 0), Color3.fromRGB(70, 66, 62), Enum.Material.Slate, { Name = "NestCore" })
			for k = 1, 9 do
				local a = k / 9 * math.pi * 2
				local hgt = rng:NextNumber(1.6, 4.2)
				block(nest, Vector3.new(rng:NextNumber(0.5, 0.9), hgt, rng:NextNumber(0.5, 0.9)), CFrame.new(pos + Vector3.new(math.cos(a) * 1.2, hgt / 2 + 0.6, math.sin(a) * 1.2)) * CFrame.Angles(rng:NextNumber(-0.5, 0.5), a, rng:NextNumber(-0.5, 0.5)), Color3.fromRGB(232, 228, 216), Enum.Material.Salt, { Name = "NestCrystal" })
			end
			local glow = Instance.new("PointLight")
			glow.Color = Color3.fromRGB(200, 220, 230)
			glow.Range = 9
			glow.Brightness = 0.6
			glow.Parent = core
			nest.PrimaryPart = core
			nest.Parent = encounterFolder
			CollectionService:AddTag(nest, "SaltNest")
		end
	end

	-- the signal lantern (Lantern Watch / finale)
	if encounterType == "LanternWatch" then
		local base = Services.LootService.settle(MapService.LanternPos, encounterFolder)
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

-- Test hook: build the Meridian (with rooms for `owned`) without starting the game loop.
function MapService.buildFerryForTest(owned)
	local world = Workspace:FindFirstChild("World") or Instance.new("Folder")
	world.Name = "World"
	world.Parent = Workspace
	local ferry = Instance.new("Folder")
	ferry.Name = "Meridian"
	ferry.Parent = world
	buildFerry(ferry)
	MapService.setFerryRepairs(owned or {})
	return ferry
end

-- Spawn line in front of the chart table, facing it: the first thing you see is SET SAIL.
function MapService.ferrySpawn(index)
	local o = Game.FerryOrigin
	local pos = o + Vector3.new(-4.5 + ((index - 1) % 4) * 3, 3, 8)
	local look = o + Vector3.new(0, 3, -2)
	return CFrame.lookAt(pos, Vector3.new(look.X, pos.Y, look.Z))
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
