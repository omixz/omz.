--!nonstrict
-- Scavenging: searchable containers (drawers, lockers, toolboxes, ammo crates) that open
-- with a short animation, and loose items that glint in the fog. Loot is rolled from
-- Config/Loot tables (free, never paid). What doesn't fit your satchel is dropped on the
-- floor for a crewmate.
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Loot = require(Shared.Config.Loot)
local Items = require(Shared.Config.Items)
local Net = require(Shared.Net)
local Sfx = require(Shared.Util.Sfx)

local LootService = {}
local Services

local ITEM_COLORS = {
	part = Color3.fromRGB(176, 166, 140),
	ammo = Color3.fromRGB(196, 160, 70),
	consumable = Color3.fromRGB(190, 70, 60),
	throwable = Color3.fromRGB(80, 130, 100),
	tool = Color3.fromRGB(150, 150, 150),
	salvage = Color3.fromRGB(120, 112, 100),
}

local function part(parent, size, cframe, color, material, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props then
		for k, v in props do
			p[k] = v
		end
	end
	p.Parent = parent
	return p
end

function LootService.roll(tableName, rolls, rng, pall)
	local entries = Loot.Tables[tableName]
	local total = 0
	for _, e in entries do
		total += e[2]
	end
	local extra = rng:NextNumber() < (pall - 1) * Loot.PallBonusRolls and 1 or 0
	local merged = {}
	for _ = 1, rolls + extra do
		local r = rng:NextNumber() * total
		for _, e in entries do
			r -= e[2]
			if r <= 0 then
				local amount = rng:NextInteger(e[3], e[4])
				merged[e[1]] = (merged[e[1]] or 0) + amount
				break
			end
		end
	end
	local list = {}
	for itemId, amount in merged do
		table.insert(list, { itemId, amount })
	end
	return list
end

function LootService.dropPickup(parent, position, itemId, amount)
	local kind = itemId == "salvage" and "salvage" or (Items.Items[itemId] and Items.Items[itemId].kind or "part")
	local p = part(parent, Vector3.new(0.9, 0.5, 0.7), CFrame.new(position + Vector3.new(0, 0.25, 0)) * CFrame.Angles(0, math.random() * 6.28, 0), ITEM_COLORS[kind], Enum.Material.SmoothPlastic, {
		Name = "Pickup_" .. itemId,
		CanCollide = false,
	})
	p:SetAttribute("Amount", amount)
	local glint = Instance.new("PointLight")
	glint.Range = 4
	glint.Brightness = 0.5
	glint.Color = Color3.fromRGB(255, 230, 190)
	glint.Parent = p
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Rate = 1.2
	sparkle.Lifetime = NumberRange.new(0.5, 0.8)
	sparkle.Speed = NumberRange.new(0, 0)
	sparkle.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.35), NumberSequenceKeypoint.new(1, 0) })
	sparkle.LightEmission = 1
	sparkle.Parent = p
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Take"
	prompt.ObjectText = Services.InventoryService.itemName(itemId)
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 7
	prompt.RequiresLineOfSight = false
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonA
	prompt.Parent = p
	prompt.Triggered:Connect(function(player)
		Services.InventoryService.pickup(player, p, itemId, amount)
	end)
	return p
end

-- Puts a point on whatever is really beneath it (floor, terrain, a step), so nothing floats
-- or sinks however the spot was authored. Ignores encounter objects and characters.
local settleParams = RaycastParams.new()
settleParams.FilterType = Enum.RaycastFilterType.Exclude
local function settle(position, parent)
	local ignore = { parent }
	for _, p in game:GetService("Players"):GetPlayers() do
		if p.Character then
			table.insert(ignore, p.Character)
		end
	end
	local enemies = workspace:FindFirstChild("Enemies")
	if enemies then
		table.insert(ignore, enemies)
	end
	settleParams.FilterDescendantsInstances = ignore
	settleParams.IgnoreWater = true
	local hit = workspace:Raycast(position + Vector3.new(0, 3, 0), Vector3.new(0, -14, 0), settleParams)
	return hit and Vector3.new(position.X, hit.Position.Y, position.Z) or position
end
LootService.settle = settle

-- Container models: { body, moving part, open transform }
local BUILDERS = {}

-- Each builder returns: the body (holds the prompt), the parts that open (list), and the opening
-- offset. Painted, detailed furniture: drawers with knobs and legs, lockers with vents.
local WOODS = { Color3.fromRGB(150, 104, 66), Color3.fromRGB(120, 84, 56), Color3.fromRGB(176, 136, 96) }
local PAINTS = { Color3.fromRGB(236, 230, 214), Color3.fromRGB(150, 196, 214), Color3.fromRGB(196, 214, 170), Color3.fromRGB(230, 190, 120), Color3.fromRGB(210, 150, 140) }
local function pick(list)
	return list[math.random(1, #list)]
end

function BUILDERS.Drawer(parent, cf)
	local painted = math.random() < 0.5
	local bodyColor = painted and pick(PAINTS) or pick(WOODS)
	local front = bodyColor:Lerp(Color3.new(1, 1, 1), 0.12)
	local mat = painted and Enum.Material.SmoothPlastic or Enum.Material.WoodPlanks
	local body = part(parent, Vector3.new(2.8, 2.6, 1.5), cf * CFrame.new(0, 1.6, 0), bodyColor, mat)
	part(parent, Vector3.new(3.0, 0.15, 1.65), cf * CFrame.new(0, 2.97, 0), bodyColor:Lerp(Color3.new(0, 0, 0), 0.15), Enum.Material.WoodPlanks) -- top
	for _, x in { -1.25, 1.25 } do
		for _, z in { -0.6, 0.6 } do
			part(parent, Vector3.new(0.2, 0.3, 0.2), cf * CFrame.new(x, 0.15, z), bodyColor:Lerp(Color3.new(0, 0, 0), 0.3), Enum.Material.Wood)
		end
	end
	local moving = {}
	for i, y in { 2.45, 1.65, 0.85 } do
		local d = part(parent, Vector3.new(2.5, 0.65, 0.12), cf * CFrame.new(0, y, -0.78), front, mat)
		local knob = part(parent, Vector3.new(0.18, 0.18, 0.12), cf * CFrame.new(0, y, -0.88), Color3.fromRGB(196, 160, 80), Enum.Material.Metal, { Shape = Enum.PartType.Ball })
		if i == 1 then
			table.insert(moving, d)
			table.insert(moving, knob)
			-- the drawer box behind the front, seen when it slides out
			table.insert(moving, part(parent, Vector3.new(2.3, 0.5, 1.25), cf * CFrame.new(0, y - 0.02, -0.08), bodyColor:Lerp(Color3.new(0, 0, 0), 0.2), Enum.Material.WoodPlanks))
		end
	end
	return body, moving, CFrame.new(0, 0, -0.9)
end

function BUILDERS.Locker(parent, cf)
	local color = pick({ Color3.fromRGB(70, 130, 180), Color3.fromRGB(90, 150, 110), Color3.fromRGB(200, 80, 70), Color3.fromRGB(150, 156, 160) })
	local body = part(parent, Vector3.new(1.8, 6, 1.6), cf * CFrame.new(0, 3, 0), color, Enum.Material.Metal)
	local door = part(parent, Vector3.new(1.7, 5.8, 0.1), cf * CFrame.new(0, 3, -0.85), color:Lerp(Color3.new(1, 1, 1), 0.12), Enum.Material.Metal)
	local moving = { door }
	for i = 0, 2 do
		table.insert(moving, part(parent, Vector3.new(1.0, 0.08, 0.04), cf * CFrame.new(0, 5.2 - i * 0.25, -0.92), color:Lerp(Color3.new(0, 0, 0), 0.35), Enum.Material.Metal))
	end
	table.insert(moving, part(parent, Vector3.new(0.1, 0.5, 0.1), cf * CFrame.new(0.6, 3, -0.94), Color3.fromRGB(200, 200, 196), Enum.Material.Metal))
	return body, moving, CFrame.new(-0.85, 0, 0) * CFrame.Angles(0, math.rad(100), 0) * CFrame.new(0.85, 0, 0)
end

function BUILDERS.Toolbox(parent, cf)
	local color = pick({ Color3.fromRGB(200, 50, 40), Color3.fromRGB(40, 90, 170), Color3.fromRGB(230, 170, 40) })
	local body = part(parent, Vector3.new(2.2, 0.9, 1), cf * CFrame.new(0, 0.45, 0), color, Enum.Material.Metal)
	local lid = part(parent, Vector3.new(2.2, 0.15, 1), cf * CFrame.new(0, 0.97, 0), color:Lerp(Color3.new(1, 1, 1), 0.1), Enum.Material.Metal)
	local handle = part(parent, Vector3.new(1.0, 0.12, 0.12), cf * CFrame.new(0, 1.2, 0), Color3.fromRGB(40, 40, 44), Enum.Material.Metal)
	for _, x in { -0.8, 0.8 } do
		part(parent, Vector3.new(0.2, 0.25, 0.06), cf * CFrame.new(x, 0.75, -0.52), Color3.fromRGB(200, 200, 196), Enum.Material.Metal)
	end
	return body, { lid, handle }, CFrame.new(0, 0, 0.5) * CFrame.Angles(math.rad(100), 0, 0) * CFrame.new(0, 0, -0.5)
end

function BUILDERS.AmmoCrate(parent, cf)
	local body = part(parent, Vector3.new(2.6, 1.3, 1.6), cf * CFrame.new(0, 0.65, 0), Color3.fromRGB(96, 110, 66), Enum.Material.WoodPlanks)
	part(parent, Vector3.new(2.62, 0.3, 1.62), cf * CFrame.new(0, 0.65, 0), Color3.fromRGB(230, 200, 70), Enum.Material.SmoothPlastic) -- stencil band
	for _, x in { -1.35, 1.35 } do
		part(parent, Vector3.new(0.1, 0.25, 0.7), cf * CFrame.new(x, 0.9, 0), Color3.fromRGB(150, 120, 80), Enum.Material.Fabric) -- rope handles
	end
	local lid = part(parent, Vector3.new(2.6, 0.2, 1.6), cf * CFrame.new(0, 1.4, 0), Color3.fromRGB(106, 120, 74), Enum.Material.WoodPlanks)
	return body, { lid }, CFrame.new(0, 0, 0.8) * CFrame.Angles(math.rad(110), 0, 0) * CFrame.new(0, 0, -0.8)
end

local function container(parent, spot, rng, pall)
	local def = Loot.Containers[spot.type]
	local builder = BUILDERS[spot.type]
	if not def or not builder then
		return
	end
	local cf = CFrame.new(settle(spot.pos, parent)) * CFrame.Angles(0, math.rad(spot.yaw or 0), 0)
	local body, moving, openOffset = builder(parent, cf)
	body.Name = spot.type
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Search"
	prompt.ObjectText = spot.type == "AmmoCrate" and "Ammo crate" or spot.type
	prompt.HoldDuration = def.hold
	prompt.MaxActivationDistance = 7
	prompt.RequiresLineOfSight = false
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonA
	prompt.Parent = body
	local searched = false
	prompt.Triggered:Connect(function(player)
		if searched then
			return
		end
		local info = Services.MatchService.getActiveInfo(player)
		if not info or (info.root.Position - body.Position).Magnitude > 12 then
			return
		end
		searched = true
		prompt:Destroy()
		-- everything that opens pivots together around the first moving part
		local pivot = moving[1].CFrame
		for _, m in moving do
			local rel = pivot:ToObjectSpace(m.CFrame)
			TweenService:Create(m, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = pivot * openOffset * rel }):Play()
		end
		Sfx.at(body.Position, "Search", 0.3, 30)
		Services.PerceptionService.emitNoise(body.Position, 5, "search", player)
		local list = LootService.roll(def.table, def.rolls, rng, pall)
		local found, leftovers = Services.InventoryService.grantList(player, list)
		for i, entry in leftovers do
			LootService.dropPickup(parent, body.Position + Vector3.new(i * 0.9 - 1, -body.Position.Y + 0.1, -1.6), entry[1], entry[2])
		end
		local text = #found > 0 and ("Found: " .. table.concat(found, ", ")) or "Nothing useful."
		if #leftovers > 0 then
			text ..= " (no room for some: left on the floor)"
		end
		Net.notify(player, "Toast", { text = text })
	end)
end

-- Fills an encounter with containers and loose items.
function LootService.populate(parent, rng, pall, containerSpots, looseSpots)
	-- a handful of containers per map, picked at random (not one in every corner)
	local pool = table.clone(containerSpots)
	for i = #pool, 2, -1 do
		local j = rng:NextInteger(1, i)
		pool[i], pool[j] = pool[j], pool[i]
	end
	for i = 1, math.min(Loot.MaxContainers or 12, #pool) do
		container(parent, pool[i], rng, pall)
	end
	local spots = table.clone(looseSpots)
	for i = #spots, 2, -1 do
		local j = rng:NextInteger(1, i)
		spots[i], spots[j] = spots[j], spots[i]
	end
	for i = 1, math.min(Loot.LooseItems, #spots) do
		local entry = LootService.roll("loose", 1, rng, 1)[1]
		if entry then
			local jitter = Vector3.new(rng:NextNumber(-1.5, 1.5), 0, rng:NextNumber(-1.5, 1.5))
			LootService.dropPickup(parent, settle(spots[i] + jitter, parent), entry[1], entry[2])
		end
	end
end

function LootService.init(registry)
	Services = registry
end

return LootService
