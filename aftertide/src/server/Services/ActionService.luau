--!nonstrict
-- Every player action, validated server-side. The client only sends intent:
--   Action("Quiet")                     takedown from behind, else shove
--   Action("Fire", aimDirection)        slingshot (Salt Shot)
--   Action("Throw", aimDirection)       bottle
--   Action("Ability")                   character signature ability
--   Action("Heal") / ("Torch") / ("Craft", recipeId)
--   Action("SecondWind") / ("Resupply") run aids (tokens; limited to once per crossing)
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Characters = require(Shared.Config.Characters)
local Commerce = require(Shared.Config.Commerce)
local Game = require(Shared.Config.Game)
local Items = require(Shared.Config.Items)
local Net = require(Shared.Net)
local Geometry = require(Shared.Util.Geometry)
local Sfx = require(Shared.Util.Sfx)

local ActionService = {}
local Services

local function serverTime()
	return Workspace:GetServerTimeNow()
end

local function toast(player, text)
	Net.notify(player, "Toast", { text = text })
end

local function setBusy(info, seconds)
	info.session.busyUntil = os.clock() + seconds
	info.char:SetAttribute("BusyUntil", serverTime() + seconds)
end

local function isBusy(info)
	return os.clock() < info.session.busyUntil
end

-- Runs `fn` after `seconds` unless the player was hurt/downed meanwhile (channelId changes).
local function channel(info, seconds, fn)
	local session = info.session
	session.channelId += 1
	local id = session.channelId
	setBusy(info, seconds)
	task.delay(seconds, function()
		if session.channelId == id and not session.downed and not session.out then
			fn()
		end
	end)
end

local function rayParamsFor(char)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char }
	return params
end

local function tracer(from, to, color)
	local length = (to - from).Magnitude
	if length < 0.1 then
		return
	end
	local beam = Instance.new("Part")
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.CanTouch = false
	beam.CastShadow = false
	beam.Material = Enum.Material.Neon
	beam.Color = color
	beam.Transparency = 0.4
	beam.Size = Vector3.new(0.08, 0.08, length)
	beam.CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -length / 2)
	beam.Parent = Workspace
	Debris:AddItem(beam, 0.12)
end

-- Actions ---------------------------------------------------------------------------------

local function quiet(player, info)
	if isBusy(info) then
		return
	end
	local pos = info.root.Position
	local near = Services.EnemyService.findNear(pos, math.max(Items.Quieting.range, Items.Shove.range))
	for _, entry in near do
		local e = entry.enemy
		if entry.distance <= Items.Quieting.range and Services.EnemyService.canQuiet(e, pos) then
			local duration = Items.Quieting.time * info.session.mods.takedownTimeMult
			Services.EnemyService.stun(e, duration + 5, nil, "Quieted")
			setBusy(info, duration)
			Net.notify(player, "Takedown", { duration = duration })
			task.delay(duration, function()
				Services.EnemyService.disperse(e)
				Services.PerceptionService.emitNoise(e.root.Position, Items.Quieting.noise, "quieting", nil)
			end)
			info.session.stats.takedowns += 1
			return
		end
	end
	-- no takedown available: shove whatever is in front
	if os.clock() < info.session.shoveReadyAt then
		return
	end
	local look = info.root.CFrame.LookVector
	for _, entry in near do
		local e = entry.enemy
		local to = Geometry.flat(e.root.Position - pos)
		if entry.distance <= Items.Shove.range and to.Magnitude > 0.01 and look:Dot(to.Unit) > 0.3 then
			info.session.shoveReadyAt = os.clock() + Items.Shove.cooldown * info.session.mods.shoveCooldownMult
			Services.EnemyService.stun(e, Items.Shove.stun, player)
			e.root.AssemblyLinearVelocity = to.Unit * 30
			Sfx.at(e.root.Position, "Shove", 0.5, 60)
			Services.PerceptionService.emitNoise(pos, Items.Shove.noise, "shove", player)
			setBusy(info, 0.4)
			return
		end
	end
end

local function fire(player, info, direction)
	if not Geometry.isSaneVector(direction, 2) or direction.Magnitude < 0.5 then
		return
	end
	direction = direction.Unit
	if isBusy(info) or os.clock() < info.session.fireReadyAt then
		return
	end
	if not Services.InventoryService.take(player, "shot", 1) then
		toast(player, "Out of Salt Shot")
		return
	end
	local cfg = Items.Slingshot
	info.session.fireReadyAt = os.clock() + cfg.cooldown
	local head = info.char:FindFirstChild("Head")
	local origin = (head and head.Position or info.root.Position) + direction * 1.2
	local result = Workspace:Raycast(origin, direction * cfg.range, rayParamsFor(info.char))
	local hitPos = result and result.Position or origin + direction * cfg.range
	tracer(origin, hitPos, Color3.fromRGB(230, 230, 220))
	Sfx.at(origin, "SlingshotFire", 0.35, 40)
	local e = result and Services.EnemyService.fromInstance(result.Instance)
	if e then
		Services.EnemyService.stun(e, cfg.stun, player)
		Services.PerceptionService.emitNoise(hitPos, cfg.hitNoise, "impact", nil)
	elseif result then
		Services.PerceptionService.emitNoise(hitPos, cfg.impactNoise, "impact", nil)
	end
end

local function shatter(position, player, mods)
	local radius = Items.Bottle.noiseRadius * mods.throwNoiseMult
	Services.PerceptionService.emitNoise(position, radius, "bottle", nil)
	Sfx.at(position, "BottleBreak", 0.8, 160)
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.Transparency = 1
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	holder.CFrame = CFrame.new(position)
	holder.Parent = Workspace
	local shards = Instance.new("ParticleEmitter")
	shards.Rate = 0
	shards.Lifetime = NumberRange.new(0.4, 0.8)
	shards.Speed = NumberRange.new(8, 16)
	shards.SpreadAngle = Vector2.new(70, 70)
	shards.Acceleration = Vector3.new(0, -40, 0)
	shards.Color = ColorSequence.new(Color3.fromRGB(150, 200, 170))
	shards.Size = NumberSequence.new(0.15)
	shards.Parent = holder
	shards:Emit(25)
	Debris:AddItem(holder, 2)
	Net.notify(player, "Toast", { text = "Bottle shattered: Hushed nearby will come to look" })
end

local function throw(player, info, direction)
	if not Geometry.isSaneVector(direction, 2) or direction.Magnitude < 0.5 then
		return
	end
	direction = direction.Unit
	if isBusy(info) then
		return
	end
	if not Services.InventoryService.take(player, "bottle", 1) then
		toast(player, "No bottles")
		return
	end
	setBusy(info, 0.35)
	local head = info.char:FindFirstChild("Head")
	local position = (head and head.Position or info.root.Position) + direction * 1.5
	local velocity = direction * Items.Bottle.speed + Vector3.new(0, Items.Bottle.lift, 0)
	local bottle = Instance.new("Part")
	bottle.Anchored = true
	bottle.CanCollide = false
	bottle.CanQuery = false
	bottle.Shape = Enum.PartType.Cylinder
	bottle.Size = Vector3.new(0.9, 0.4, 0.4)
	bottle.Material = Enum.Material.Glass
	bottle.Color = Color3.fromRGB(70, 120, 90)
	bottle.Transparency = 0.2
	bottle.CFrame = CFrame.new(position)
	bottle.Parent = Workspace
	local params = rayParamsFor(info.char)
	local mods = info.session.mods
	local age = 0
	local conn
	conn = RunService.Heartbeat:Connect(function(dt)
		age += dt
		velocity += Vector3.new(0, -Workspace.Gravity * 0.5, 0) * dt
		local step = velocity * dt
		local result = Workspace:Raycast(position, step, params)
		if result or age > 4 then
			conn:Disconnect()
			bottle:Destroy()
			shatter(result and result.Position or position, player, mods)
			return
		end
		position += step
		bottle.CFrame = CFrame.new(position) * CFrame.Angles(age * 9, age * 5, 0)
	end)
end

local abilities = {}

function abilities.TideSense(player, info, ability, mods)
	Net.notify(player, "TideSense", {
		radius = ability.radius * mods.abilityRadiusMult,
		duration = ability.duration * mods.abilityDurationMult,
	})
	return true
end

function abilities.RattleBox(player, info, ability, mods)
	local look = Geometry.flat(info.root.CFrame.LookVector)
	look = look.Magnitude > 0.01 and look.Unit or Vector3.new(0, 0, -1)
	local spot = info.root.Position + look * 3
	local down = Workspace:Raycast(spot + Vector3.new(0, 3, 0), Vector3.new(0, -12, 0), rayParamsFor(info.char))
	local ground = down and down.Position or Vector3.new(spot.X, 0, spot.Z)
	local box = Instance.new("Part")
	box.Name = "RattleBox"
	box.Anchored = true
	box.CanCollide = false
	box.Size = Vector3.new(1, 0.8, 1)
	box.Material = Enum.Material.Metal
	box.Color = Color3.fromRGB(150, 120, 60)
	box.CFrame = CFrame.new(ground + Vector3.new(0, 0.4, 0))
	box.Parent = Workspace
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 200, 120)
	light.Range = 6
	light.Parent = box
	local radius = ability.radius * mods.abilityRadiusMult
	local duration = ability.duration * mods.abilityDurationMult
	task.spawn(function()
		local elapsed = 0
		while elapsed < duration and box.Parent do
			light.Enabled = not light.Enabled
			Services.PerceptionService.emitNoise(box.Position, radius, "rattle", nil)
			Sfx.at(box.Position, "Rattle", 0.4, radius * 2)
			task.wait(1.5)
			elapsed += 1.5
		end
		box:Destroy()
	end)
	return true
end

function abilities.SteadyHands(player, info, ability, mods)
	Services.CharacterService.heal(player, 40 * mods.healMult)
	for _, other in Services.MatchService.getActivePlayers() do
		if other.player ~= player and (other.root.Position - info.root.Position).Magnitude <= ability.radius then
			Services.CharacterService.heal(other.player, 20 * mods.healMult)
			toast(other.player, player.DisplayName .. " patched you up")
		end
	end
	info.session.calmUntil = os.clock() + ability.duration * mods.abilityDurationMult
	return true
end

function abilities.ThrowNet(player, info, ability, mods)
	local look = info.root.CFrame.LookVector
	local params = rayParamsFor(info.char)
	for _, entry in Services.EnemyService.findNear(info.root.Position, ability.radius) do
		local e = entry.enemy
		local to = e.root.Position - info.root.Position
		if to.Magnitude > 0.01 and look:Dot(to.Unit) > 0.8 then
			local hit = Workspace:Raycast(info.root.Position, to, params)
			if not hit or Services.EnemyService.fromInstance(hit.Instance) == e then
				Services.EnemyService.pin(e, ability.duration * mods.abilityDurationMult)
				return true
			end
		end
	end
	toast(player, "No Hushed in front of you to net")
	return false
end

local function useAbility(player, info)
	local session = info.session
	if isBusy(info) or os.clock() < session.abilityReadyAt then
		return
	end
	local def = Characters.List[session.charId]
	local ability = def.ability
	local handler = abilities[ability.id]
	if handler and handler(player, info, ability, session.mods) then
		local cooldown = ability.cooldown * session.mods.abilityCooldownMult
		session.abilityReadyAt = os.clock() + cooldown
		info.char:SetAttribute("AbilityReadyAt", serverTime() + cooldown)
	end
end

local function heal(player, info)
	if isBusy(info) then
		return
	end
	if info.session.hp >= Game.MaxHP then
		toast(player, "Already at full health")
		return
	end
	if Services.InventoryService.count(player, "bandage") < 1 then
		toast(player, "No bandages")
		return
	end
	channel(info, Items.Bandage.channel, function()
		if Services.InventoryService.take(player, "bandage", 1) then
			Services.CharacterService.heal(player, Items.Bandage.heal * info.session.mods.healMult)
		end
	end)
end

local function toggleTorch(player, info)
	local head = info.char:FindFirstChild("Head")
	local torch = head and head:FindFirstChild("Torch")
	if torch then
		torch.Enabled = not torch.Enabled
		info.char:SetAttribute("Torch", torch.Enabled)
	end
end

local function craft(player, info, recipeId)
	if type(recipeId) ~= "string" or not Items.Recipes[recipeId] or isBusy(info) then
		return
	end
	local ok, reason = Services.InventoryService.canCraft(player, recipeId)
	if not ok then
		toast(player, reason)
		return
	end
	channel(info, Items.CraftTime, function()
		local crafted, why = Services.InventoryService.craft(player, recipeId)
		toast(player, crafted and ("Crafted " .. Items.Recipes[recipeId].name) or why)
	end)
end

-- Run aids --------------------------------------------------------------------------------

function ActionService.useSecondWind(player)
	if not Game.RunAidsEnabled then
		return false
	end
	local session = Services.CharacterService.getSession(player)
	if not session or not session.downed or session.out or Services.MatchService.state ~= "Encounter" then
		return false
	end
	if session.usedSecondWind then
		toast(player, "Second Wind is limited to once per crossing")
		return false
	end
	if not Services.PlayerDataService.useToken(player, "secondWind") then
		Net.notify(player, "NeedProduct", { productKey = "SecondWind" })
		return false
	end
	session.usedSecondWind = true
	Services.CharacterService.revive(player, Game.SecondWindHP)
	return true
end

function ActionService.useResupply(player)
	if not Game.RunAidsEnabled then
		return false
	end
	local info = Services.MatchService.getActiveInfo(player)
	if not info then
		toast(player, "Resupply works during a crossing")
		return false
	end
	if info.session.usedResupply then
		toast(player, "Resupply is limited to once per crossing")
		return false
	end
	if not Services.PlayerDataService.useToken(player, "resupply") then
		Net.notify(player, "NeedProduct", { productKey = "Resupply" })
		return false
	end
	info.session.usedResupply = true
	for itemId, amount in Items.Resupply do
		Services.InventoryService.add(player, itemId, amount)
	end
	toast(player, "Resupplied")
	return true
end

-- Dispatcher ------------------------------------------------------------------------------

local HANDLERS = {
	Quiet = quiet,
	Fire = fire,
	Throw = throw,
	Ability = useAbility,
	Heal = heal,
	Torch = toggleTorch,
	Craft = craft,
}

function ActionService.init(registry)
	Services = registry
end

function ActionService.start()
	Net.onServer("Action", 20, function(player, action, payload)
		if type(action) ~= "string" then
			return
		end
		if action == "SecondWind" then
			ActionService.useSecondWind(player)
			return
		elseif action == "Resupply" then
			ActionService.useResupply(player)
			return
		end
		local handler = HANDLERS[action]
		if not handler then
			return
		end
		local info = Services.MatchService.getActiveInfo(player)
		if not info then
			-- Torch works on the ferry too
			if action == "Torch" then
				local session = Services.CharacterService.getSession(player)
				local char = player.Character
				if session and char and char:FindFirstChild("HumanoidRootPart") then
					toggleTorch(player, { char = char, session = session })
				end
			end
			return
		end
		handler(player, info, payload)
	end)
	-- keep Commerce referenced for product keys used in NeedProduct
	assert(Commerce.Products.SecondWind and Commerce.Products.Resupply, "Commerce config missing run aids")
end

return ActionService
