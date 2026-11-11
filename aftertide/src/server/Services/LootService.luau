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

-- Container models: { body, moving part, open transform }
local BUILDERS = {}

function BUILDERS.Drawer(parent, cf)
	local body = part(parent, Vector3.new(2.6, 2.8, 1.6), cf * CFrame.new(0, 1.4, 0), Color3.fromRGB(96, 80, 62), Enum.Material.WoodPlanks)
	local drawer = part(parent, Vector3.new(2.3, 0.7, 1.4), cf * CFrame.new(0, 2.1, -0.15), Color3.fromRGB(110, 92, 70), Enum.Material.WoodPlanks)
	return body, drawer, CFrame.new(0, 0, -1)
end

function BUILDERS.Locker(parent, cf)
	local body = part(parent, Vector3.new(1.8, 6, 1.6), cf * CFrame.new(0, 3, 0), Color3.fromRGB(70, 84, 88), Enum.Material.Metal)
	local door = part(parent, Vector3.new(1.7, 5.8, 0.1), cf * CFrame.new(0, 3, -0.85), Color3.fromRGB(80, 96, 100), Enum.Material.DiamondPlate)
	return body, door, CFrame.new(-0.85, 0, 0) * CFrame.Angles(0, math.rad(100), 0) * CFrame.new(0.85, 0, 0)
end

function BUILDERS.Toolbox(parent, cf)
	local body = part(parent, Vector3.new(2.2, 0.9, 1), cf * CFrame.new(0, 0.45, 0), Color3.fromRGB(140, 50, 40), Enum.Material.Metal)
	local lid = part(parent, Vector3.new(2.2, 0.15, 1), cf * CFrame.new(0, 0.97, 0), Color3.fromRGB(150, 56, 44), Enum.Material.Metal)
	return body, lid, CFrame.new(0, 0, 0.5) * CFrame.Angles(math.rad(100), 0, 0) * CFrame.new(0, 0, -0.5)
end

function BUILDERS.AmmoCrate(parent, cf)
	local body = part(parent, Vector3.new(2.6, 1.3, 1.6), cf * CFrame.new(0, 0.65, 0), Color3.fromRGB(78, 86, 58), Enum.Material.WoodPlanks)
	local lid = part(parent, Vector3.new(2.6, 0.2, 1.6), cf * CFrame.new(0, 1.4, 0), Color3.fromRGB(86, 94, 64), Enum.Material.WoodPlanks)
	return body, lid, CFrame.new(0, 0, 0.8) * CFrame.Angles(math.rad(110), 0, 0) * CFrame.new(0, 0, -0.8)
end

local function container(parent, spot, rng, pall)
	local def = Loot.Containers[spot.type]
	local builder = BUILDERS[spot.type]
	if not def or not builder then
		return
	end
	local cf = CFrame.new(spot.pos) * CFrame.Angles(0, math.rad(spot.yaw or 0), 0)
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
		TweenService:Create(moving, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = moving.CFrame * openOffset }):Play()
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
	for _, spot in containerSpots do
		container(parent, spot, rng, pall)
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
			LootService.dropPickup(parent, spots[i] + jitter, entry[1], entry[2])
		end
	end
end

function LootService.init(registry)
	Services = registry
end

return LootService
