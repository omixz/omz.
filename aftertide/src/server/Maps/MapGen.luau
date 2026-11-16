--!nonstrict
-- Shared scaffolding for the encounter maps: keeps track of what is placed where, so each map
-- only has to describe its scenery. Records loot, containers and doorways from every building,
-- avoids placing props inside buildings, and assembles the data table MapService expects
-- (spawns, extraction, lantern, supply spots, loot, containers, edge spawns, patrols, doorways).
local MapKit = require(script.Parent.MapKit)

local V = Vector3.new
local Gen = {}
Gen.__index = Gen

function Gen.new(parent, rng)
	return setmetatable({ parent = parent, rng = rng, zones = {}, loot = {}, containers = {}, doors = {}, groundFn = nil }, Gen)
end

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end
Gen.rgb = rgb

-- Keep-out circles ------------------------------------------------------------------------------

function Gen:zone(x, z, r)
	table.insert(self.zones, { x, z, r })
end

function Gen:free(x, z, pad)
	pad = pad or 0
	for _, zone in self.zones do
		local dx, dz = x - zone[1], z - zone[2]
		if dx * dx + dz * dz < (zone[3] + pad) ^ 2 then
			return false
		end
	end
	return true
end

-- Call once the terrain is filled: waits for it to become queryable (a fresh fill is not for a
-- few physics steps), then reads the real surface height of flat ground.
function Gen:flat()
	task.wait(0.35)
	local y = MapKit.ground(0, 0)
	self.flatY = y
	self.groundFn = function()
		return y
	end
	return y
end

-- Same for rolling ground: every ground query is a ray cast against the terrain.
function Gen:rolling()
	task.wait(0.35)
	self.groundFn = nil
end

function Gen:flowers(center, radius, color)
	local colors = { rgb(240, 90, 110), rgb(255, 208, 60), rgb(250, 250, 250), rgb(180, 110, 230), rgb(255, 140, 60), rgb(110, 170, 250) }
	color = color or colors[self.rng:NextInteger(1, #colors)]
	for _ = 1, 14 do
		local a, r = self.rng:NextNumber(0, 6.28), self.rng:NextNumber(0, radius)
		local x, z = center.X + math.cos(a) * r, center.Z + math.sin(a) * r
		local y = self:ground(x, z)
		MapKit.block(self.parent, V(0.18, 0.9, 0.18), V(x, y + 0.45, z), rgb(70, 130, 60), Enum.Material.Grass, { CanCollide = false, CanQuery = false })
		MapKit.block(self.parent, V(0.55, 0.55, 0.55), V(x, y + 1, z), color, Enum.Material.SmoothPlastic, { Shape = Enum.PartType.Ball, CanCollide = false, CanQuery = false })
	end
end

function Gen:ground(x, z)
	if self.groundFn then
		return self.groundFn(x, z)
	end
	return MapKit.ground(x, z)
end

-- A random free point in a rectangle (nil after many failed tries).
function Gen:open(x0, z0, x1, z1, pad)
	for _ = 1, 40 do
		local x, z = self.rng:NextNumber(x0, x1), self.rng:NextNumber(z0, z1)
		if self:free(x, z, pad or 3) then
			return x, z
		end
	end
	return nil
end

-- Buildings ----------------------------------------------------------------------------------------

local function record(self, result)
	for _, d in result.doorways or {} do
		table.insert(self.doors, d)
	end
	for _, c in result.containers or {} do
		table.insert(self.containers, c)
	end
	for _, l in result.loot or {} do
		table.insert(self.loot, l)
	end
end

-- A generated house / shop / apartment / garage / chapel / cabin (see MapKit.house).
function Gen:house(origin, yaw, style)
	local r = MapKit.house(self.parent, origin, yaw, self.rng, style)
	record(self, r)
	local cf = CFrame.new(origin) * CFrame.Angles(0, yaw, 0)
	local mid = (cf * CFrame.new(0, 0, 11)).Position
	self:zone(mid.X, mid.Z, 20)
	return r
end

-- A multi-room building (see MapKit.building). rect = { x0, z0, x1, z1 }.
function Gen:building(rect, y, style)
	local r = MapKit.building(self.parent, rect, y, self.rng, style)
	record(self, r)
	self:zone((rect[1] + rect[3]) / 2, (rect[2] + rect[4]) / 2, math.max(rect[3] - rect[1], rect[4] - rect[2]) / 2 + 3)
	return r
end

-- Scenery ---------------------------------------------------------------------------------------

-- Scatter props over an area: names = { "Pine_1", ... }, scale = { min, max }.
function Gen:scatter(names, count, x0, z0, x1, z1, smin, smax, sink, pad)
	local placed = 0
	for _ = 1, count * 3 do
		if placed >= count then
			break
		end
		local x, z = self.rng:NextNumber(x0, x1), self.rng:NextNumber(z0, z1)
		if self:free(x, z, pad or 2) then
			local y = self:ground(x, z) - (sink or 0)
			MapKit.prop(self.parent, names[self.rng:NextInteger(1, #names)], CFrame.new(x, y, z) * CFrame.Angles(0, self.rng:NextNumber(0, 6.28), 0), self.rng:NextNumber(smin or 0.8, smax or 1.2))
			placed += 1
		end
	end
end

function Gen:car(x, z, yaw, name)
	MapKit.prop(self.parent, name or ({ "CarSedan_1", "CarSedan_2", "CarVan_1" })[self.rng:NextInteger(1, 3)], CFrame.new(x, self:ground(x, z), z) * CFrame.Angles(0, yaw or self.rng:NextNumber(0, 6.28), 0))
	self:zone(x, z, 5)
end

function Gen:block(size, pos, color, material, props)
	return MapKit.block(self.parent, size, pos, color, material, props)
end

-- A cylinder log / pipe / pole between two points.
function Gen:pipe(a, b, radius, color, material)
	local mid = (a + b) / 2
	return MapKit.block(self.parent, V((b - a).Magnitude, radius * 2, radius * 2), CFrame.lookAt(mid, b) * CFrame.Angles(0, math.pi / 2, 0), color, material or Enum.Material.Metal, { Shape = Enum.PartType.Cylinder })
end

function Gen:crate(x, z, size, color)
	size = size or 3.6
	local y = self:ground(x, z)
	MapKit.block(self.parent, V(size, size, size), CFrame.new(x, y + size / 2, z) * CFrame.Angles(0, self.rng:NextNumber(0, 1.57), 0), color or rgb(150, 108, 70), Enum.Material.WoodPlanks)
	self:zone(x, z, size)
end

function Gen:container(x, z, kind, yaw)
	table.insert(self.containers, { pos = V(x, self:ground(x, z), z), type = kind or "Toolbox", yaw = yaw or 0 })
end

function Gen:lootAt(x, z)
	table.insert(self.loot, V(x, self:ground(x, z), z))
end

-- Edges ---------------------------------------------------------------------------------------------

-- A fence round the whole map: posts and rails (chain-link look), gaps for the sea beyond.
function Gen:fence(color, height, step)
	height = height or 7
	step = step or 6
	local E = 117
	for t = -E, E, step do
		for _, side in { { t, E }, { t, -E }, { E, t }, { -E, t } } do
			MapKit.block(self.parent, V(0.5, height, 0.5), V(side[1], self:ground(side[1], side[2]) + height / 2, side[2]), color or rgb(120, 124, 128), Enum.Material.Metal)
		end
	end
	for _, rail in { { 0, E, 240, 0.3 }, { 0, -E, 240, 0.3 }, { E, 0, 0.3, 240 }, { -E, 0, 0.3, 240 } } do
		for _, h in { 1.2, height - 0.6 } do
			MapKit.block(self.parent, V(math.max(rail[3], 0.3), 0.3, math.max(rail[4], 0.3)), V(rail[1], h, rail[2]), color or rgb(120, 124, 128), Enum.Material.Metal)
		end
		MapKit.block(self.parent, V(math.max(rail[3], 0.2), height - 1.4, math.max(rail[4], 0.2)), V(rail[1], height / 2 + 0.2, rail[2]), color or rgb(160, 164, 168), Enum.Material.Metal, { Transparency = 0.7 })
	end
end

-- A string of bulbs between two points (festival / camp lights).
function Gen:lights(a, b, count, color, sag)
	for i = 0, count do
		local k = i / count
		local p = a:Lerp(b, k) - V(0, math.sin(k * math.pi) * (sag or 1.2), 0)
		local bulb = MapKit.block(self.parent, V(0.6, 0.6, 0.6), p, color or rgb(255, 214, 140), Enum.Material.Neon, { Shape = Enum.PartType.Ball, CanCollide = false, CanQuery = false })
		if i % 3 == 1 then
			local l = Instance.new("PointLight")
			l.Range = 14
			l.Brightness = 0.9
			l.Color = color or rgb(255, 214, 140)
			l.Parent = bulb
		end
	end
end

function Gen:sign(x, z, yaw, text, color)
	local y = self:ground(x, z)
	local cf = CFrame.new(x, y, z) * CFrame.Angles(0, yaw, 0)
	MapKit.block(self.parent, V(0.4, 7, 0.4), cf * CFrame.new(0, 3.5, 0), rgb(96, 70, 48), Enum.Material.Wood)
	local board = MapKit.block(self.parent, V(7, 2, 0.3), cf * CFrame.new(0, 6.2, 0), color or rgb(46, 96, 62), Enum.Material.WoodPlanks)
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

-- Assembling the map data ----------------------------------------------------------------------------

-- spec: { start = {Vector3...}, extraction, lantern }
function Gen:finish(spec)
	local rng = self.rng
	local loot = table.clone(self.loot)
	-- top up with loose-item spots in open ground, spread across the map
	local want = 22
	for _ = 1, 60 do
		if #loot >= want then
			break
		end
		local x, z = self:open(-108, -108, 108, 108, 4)
		if x then
			table.insert(loot, V(x, 0, z))
		end
	end
	local supply = {}
	for i = 1, #loot, math.max(1, math.floor(#loot / 10)) do
		table.insert(supply, loot[i])
	end
	local containers = self.containers
	if #containers < 8 then
		for _ = 1, 8 - #containers do
			local x, z = self:open(-100, -100, 100, 100, 3)
			if x then
				table.insert(containers, { pos = V(x, 0, z), type = ({ "Toolbox", "AmmoCrate", "Locker", "Drawer" })[rng:NextInteger(1, 4)], yaw = rng:NextInteger(0, 3) * 90 })
			end
		end
	end
	local edge = {}
	for _, p in { { -105, -105 }, { 105, -105 }, { 105, 105 }, { -105, 105 }, { 0, -110 }, { 0, 110 }, { 110, 0 }, { -110, 0 } } do
		table.insert(edge, V(p[1], 0, p[2]))
	end
	local patrols = {}
	for _ = 1, 6 do
		local route = {}
		for _ = 1, 3 + rng:NextInteger(0, 1) do
			local x, z = self:open(-100, -100, 100, 100, 5)
			if x then
				table.insert(route, V(x, 0, z))
			end
		end
		if #route >= 2 then
			table.insert(patrols, route)
		end
	end
	return {
		StartSpawns = spec.start,
		ExtractionPos = spec.extraction,
		LanternPos = spec.lantern or V(0, 0, 0),
		SupplyCandidates = supply,
		LootSpots = loot,
		ContainerSpots = containers,
		EdgeSpawns = edge,
		PatrolRoutes = patrols,
		Doorways = self.doors,
	}
end

return Gen
