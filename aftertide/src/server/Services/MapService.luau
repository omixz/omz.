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

-- The Meridian: a beached car ferry, 96 x 32 studs of deck, bridge at the stern (-X).
-- Deck plan (x along the ship, z across; o = FerryOrigin):
--   x -47..-31  bridge (cabins door, projects board, leaderboard on its front face)
--   x -28..-9   aft deck: lockers, quest board, generator, workshop (+ workbench)
--   x  -6.. 6   midships: chart table, spawn line
--   x   8..25   infirmary (port) / chart room (starboard)
--   x  26..46   Purser's Office, cargo, armory, lookout tower at the bow
local function buildFerry(parent)
	table.clear(layoutBoxes)
	local o = Game.FerryOrigin
	local deckColor = Color3.fromRGB(70, 66, 60)
	local hull = Color3.fromRGB(176, 176, 166)
	local M = Enum.Material
	-- sea, sandbar, hull, deck, railings
	block(parent, Vector3.new(900, 1, 900), o + Vector3.new(0, -7, 0), Color3.fromRGB(30, 40, 44), M.Glass, { Reflectance = 0.12, CanQuery = false })
	block(parent, Vector3.new(170, 4, 70), o + Vector3.new(0, -6, 0), Color3.fromRGB(120, 112, 96), M.Sand)
	block(parent, Vector3.new(96, 2, 32), o + Vector3.new(0, -1, 0), deckColor, M.DiamondPlate)
	for _, z in { -16.5, 16.5 } do
		block(parent, Vector3.new(97, 8, 1), o + Vector3.new(0, -5, z), hull, M.CorrodedMetal)
		block(parent, Vector3.new(96, 3.5, 0.5), o + Vector3.new(0, 1.75, z * 0.97), C.metal, M.Metal)
	end
	for _, x in { -48.25, 48.25 } do
		block(parent, Vector3.new(0.5, 3.5, 32), o + Vector3.new(x, 1.75, 0), C.metal, M.Metal)
		block(parent, Vector3.new(1, 8, 33), o + Vector3.new(x * 1.01, -5, 0), hull, M.CorrodedMetal)
	end

	-- bridge superstructure
	fixture(parent, "Bridge", Vector3.new(16, 12, 22), o + Vector3.new(-39, 6, 0), hull, M.CorrodedMetal)
	block(parent, Vector3.new(18, 1, 24), o + Vector3.new(-39, 12.5, 0), C.metal, M.Metal)
	block(parent, Vector3.new(0.3, 2.4, 18), o + Vector3.new(-30.9, 9, 0), Color3.fromRGB(40, 48, 52), M.Glass, { Transparency = 0.3 })

	-- on the bridge's front face (x = -31)
	local cabin = fixture(parent, "CabinDoor", Vector3.new(0.6, 8, 4), o + Vector3.new(-30.65, 4, 6), Color3.fromRGB(90, 96, 92), M.Metal)
	prompt(cabin, "Change crew member", "Crew cabins", function(player)
		Services.MatchService.openCharacterSelect(player)
	end)
	local board = fixture(parent, "ProjectsBoard", Vector3.new(0.3, 4, 5), o + Vector3.new(-30.8, 4, -1.5), Color3.fromRGB(120, 100, 76), M.WoodPlanks)
	prompt(board, "Plan projects", "The Meridian", function(player)
		Services.MatchService.openMenu(player, "OpenRepairs")
	end)
	local leaderboard = fixture(parent, "Leaderboard", Vector3.new(0.3, 5, 6), o + Vector3.new(-30.8, 4.5, -7.8), Color3.fromRGB(46, 52, 56), M.Slate)
	MapService.leaderboardPart = leaderboard

	-- aft deck
	local lockers = fixture(parent, "CrewLockers", Vector3.new(4, 7, 1.4), o + Vector3.new(-26, 3.5, 14.6), Color3.fromRGB(72, 80, 78), M.DiamondPlate)
	prompt(lockers, "Open wardrobe", "Crew lockers", function(player)
		Services.MatchService.openShop(player, "Wardrobe")
	end)
	local quests = fixture(parent, "QuestBoard", Vector3.new(5, 4, 0.4), o + Vector3.new(-18, 3.6, 14.8), Color3.fromRGB(130, 108, 80), M.WoodPlanks)
	for _, x in { -20.75, -15.25 } do
		fixture(parent, "QuestBoardPost", Vector3.new(0.4, 5.6, 0.4), o + Vector3.new(x, 2.8, 14.8), Color3.fromRGB(86, 70, 54), M.Wood)
	end
	prompt(quests, "Read the board", "Quests", function(player)
		Services.MatchService.openMenu(player, "OpenQuests")
	end)
	local bench = fixture(parent, "Workbench", Vector3.new(6, 3, 2.6), o + Vector3.new(-14, 1.5, -13.6), Color3.fromRGB(86, 66, 46), M.WoodPlanks)
	block(parent, Vector3.new(0.6, 0.6, 0.6), o + Vector3.new(-12, 3.3, -13.6), Color3.fromRGB(110, 40, 30), M.Metal) -- vice
	prompt(bench, "Use workbench", "Workbench", function(player)
		Services.MatchService.openMenu(player, "OpenWorkbench")
	end)

	-- midships: the tide chart
	local chart = fixture(parent, "ChartTable", Vector3.new(5, 3, 3), o + Vector3.new(0, 1.5, -2), Color3.fromRGB(96, 70, 48), M.WoodPlanks)
	block(parent, Vector3.new(4.4, 0.1, 2.4), o + Vector3.new(0, 3.05, -2), Color3.fromRGB(214, 204, 176), M.SmoothPlastic)
	local chartPrompt = prompt(chart, "Read the tide chart", "Tide chart", function(player)
		Services.MatchService.requestChart(player)
	end, 0.8)
	chartPrompt.Name = "ChartPrompt"

	-- the Purser's Office (shop)
	local booth = fixture(parent, "PursersOffice", Vector3.new(7, 8, 5), o + Vector3.new(30, 4, -12.5), Color3.fromRGB(150, 146, 134), M.CorrodedMetal)
	local boothLight = Instance.new("PointLight")
	boothLight.Range = 10
	boothLight.Brightness = 1
	boothLight.Color = C.warm
	boothLight.Parent = booth
	prompt(booth, "Open the ledger", "The Purser's Office", function(player)
		Services.MatchService.openShop(player)
	end)

	-- cargo
	fixture(parent, "Cargo", Vector3.new(10, 8.6, 6), o + Vector3.new(40, 4.3, 0), C.containers[2], M.CorrodedMetal)

	-- string lights (lit by the Deck Lights project)
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
			local light = d:FindFirstChildOfClass("PointLight")
			if light then
				light.Enabled = owned.lights == true
			end
			d.Material = owned.lights and Enum.Material.Neon or Enum.Material.Glass
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
