--!nonstrict
-- Every non-gun player action, validated server-side. The client only sends intent:
--   Action("Quiet")                     Quieting from behind / with a Tide Spike, else shove
--   Action("Throw", {dir, item})        bottle / flare pot / fog pot / salt bomb
--   Action("Ability")                   character signature ability
--   Action("Heal") / ("Torch") / ("Craft", recipeId)
--   Action("Equip", slot) / ("Fire", {dir, aim}) / ("Reload")   -> WeaponService
--   Action("SecondWind") / ("Resupply") run aids (tokens; once per crossing)
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Characters = require(Shared.Config.Characters)
local Game = require(Shared.Config.Game)
local Items = require(Shared.Config.Items)
local Net = require(Shared.Net)
local Geometry = require(Shared.Util.Geometry)
local Sfx = require(Shared.Util.Sfx)

local ActionService = {}
local Services

local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

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

local function effectHolder(position, lifetime)
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	holder.CFrame = CFrame.new(position)
	holder.Parent = Workspace
	Debris:AddItem(holder, lifetime)
	return holder
end

-- Quieting / spike / shove -------------------------------------------------------------------

local function cue(info, name)
	info.char:SetAttribute(name, serverTime())
end

local MELEE = { damage = { 24, 24, 40 }, range = 5.5, interval = 0.42, comboWindow = 0.95, noise = 10 }

local function melee(player, info)
	local session = info.session
	local now = os.clock()
	if now < (session.meleeReadyAt or 0) then
		return
	end
	session.meleeCombo = (now - (session.lastMeleeAt or 0) < MELEE.comboWindow) and ((session.meleeCombo or 0) % 3 + 1) or 1
	session.lastMeleeAt = now
	session.meleeReadyAt = now + MELEE.interval
	local combo = session.meleeCombo
	info.char:SetAttribute("MeleeCombo", combo)
	cue(info, "MeleeAt")
	setBusy(info, 0.3)
	Sfx.at(info.root.Position, "Swing", 0.5, 30, 0.1)
	local pos, look = info.root.Position, info.root.CFrame.LookVector
	task.delay(0.12, function() -- strike lands mid-swing
		for _, entry in Services.EnemyService.findNear(pos, MELEE.range) do
			local e = entry.enemy
			local to = Geometry.flat(e.root.Position - pos)
			if to.Magnitude > 0.01 and look:Dot(to.Unit) > 0.35 then
				local damage = MELEE.damage[combo] * (e.cfg.shoveable and 1 or 0.5)
				local killed = Services.EnemyService.damage(e, damage, player, false)
				Sfx.at(e.root.Position, "MeleeHit", 0.7, 50, 0.1)
				Net.notify(player, "Hit", { kill = killed, melee = true })
				if not killed and combo == 3 and e.cfg.shoveable then
					Services.EnemyService.stun(e, Items.Shove.stun, player)
					e.root.AssemblyLinearVelocity = to.Unit * 34
				end
				break
			end
		end
	end)
	Services.PerceptionService.emitNoise(pos, MELEE.noise, "melee", player)
end

local function dodge(player, info, direction)
	local session = info.session
	local now = os.clock()
	if now < (session.dodgeReadyAt or 0) or isBusy(info) then
		return
	end
	if not Geometry.isSaneVector(direction, 2) then
		return
	end
	local dive = info.char:GetAttribute("Sprint") == true
	session.dodgeReadyAt = now + (dive and 1.3 or 0.85)
	session.dodgeUntil = now + (dive and 0.6 or 0.42) -- grabs miss during the dodge
	Services.CharacterService.setGrace(player, 1.2)
	info.char:SetAttribute("DodgeDive", dive)
	cue(info, "DodgeAt")
	Services.PerceptionService.emitNoise(info.root.Position, dive and 14 or 8, "dodge", player)
end

local function quietEnemy(player, info, e, duration)
	Services.EnemyService.stun(e, duration + 5, nil, "Quieted")
	setBusy(info, duration)
	cue(info, "TakedownAt")
	Net.notify(player, "Takedown", { duration = duration })
	task.delay(duration, function()
		Services.EnemyService.disperse(e, player)
		Services.PerceptionService.emitNoise(e.root.Position, Items.Quieting.noise, "quieting", nil)
	end)
	info.session.stats.takedowns += 1
	Services.InventoryService.add(player, "salvage", Items.Quieting.salvage)
end

local function quiet(player, info)
	if isBusy(info) then
		return
	end
	local pos = info.root.Position
	local near = Services.EnemyService.findNear(pos, math.max(Items.Quieting.range, Items.Shove.range))
	local look = info.root.CFrame.LookVector
	local duration = Items.Quieting.time * info.session.mods.takedownTimeMult
	for _, entry in near do
		local e = entry.enemy
		if entry.distance <= Items.Quieting.range and Services.EnemyService.canQuiet(e, pos) then
			quietEnemy(player, info, e, duration)
			return
		end
	end
	-- a Tide Spike lets you Quiet from the front (not Tidewalkers)
	for _, entry in near do
		local e = entry.enemy
		local to = Geometry.flat(e.root.Position - pos)
		if entry.distance <= Items.Quieting.range and e.cfg.quietable and e.state ~= "Quieted" and to.Magnitude > 0.01 and look:Dot(to.Unit) > 0.3 then
			if Services.InventoryService.take(player, "spike", 1) then
				quietEnemy(player, info, e, duration * 0.8)
				toast(player, "Tide Spike used")
				return
			end
			break
		end
	end
	-- otherwise: melee combo (third hit knocks them back)
	melee(player, info)
end

-- Called by EnemyService when a Hushed grabs someone. Returns true if a spike saved them.
function ActionService.trySpikeCounter(player, e)
	if not e.cfg.quietable then
		return false
	end
	local info = Services.MatchService.getActiveInfo(player)
	if not info or not Services.InventoryService.take(player, "spike", 1) then
		return false
	end
	toast(player, "Spike! You broke free.")
	quietEnemy(player, info, e, 0.6)
	return true
end

-- Throwables ---------------------------------------------------------------------------------

local landing = {}

function landing.bottle(position, player, mods)
	local radius = Items.Throw.bottle.noise * mods.throwNoiseMult
	Services.PerceptionService.emitNoise(position, radius, "bottle", nil)
	Sfx.at(position, "BottleBreak", 0.8, 160)
	local shards = Instance.new("ParticleEmitter")
	shards.Rate = 0
	shards.Lifetime = NumberRange.new(0.4, 0.8)
	shards.Speed = NumberRange.new(8, 16)
	shards.SpreadAngle = Vector2.new(70, 70)
	shards.Acceleration = Vector3.new(0, -40, 0)
	shards.Color = ColorSequence.new(Color3.fromRGB(150, 200, 170))
	shards.Size = NumberSequence.new(0.15)
	shards.Parent = effectHolder(position, 2)
	shards:Emit(25)
end

function landing.flarePot(position, player, mods)
	local cfg = Items.Throw.flarePot
	Services.EnemyService.addFireZone(position, cfg.radius, cfg.duration, cfg.dps, player)
	Services.PerceptionService.emitNoise(position, cfg.noise * mods.throwNoiseMult, "flare", nil)
	local holder = effectHolder(position + Vector3.new(0, 0.3, 0), cfg.duration + 1)
	Sfx.attach(holder, "FireLoop", 0.8, 70, true)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 120, 60)
	light.Range = cfg.radius * 2.5
	light.Brightness = 3
	light.Shadows = true
	light.Parent = holder
	local sparks = Instance.new("ParticleEmitter")
	sparks.Rate = 60
	sparks.Lifetime = NumberRange.new(0.6, 1.2)
	sparks.Speed = NumberRange.new(2, 6)
	sparks.SpreadAngle = Vector2.new(60, 60)
	sparks.Color = ColorSequence.new(Color3.fromRGB(255, 160, 80), Color3.fromRGB(255, 70, 40))
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 0) })
	sparks.Parent = holder
	local glow = Instance.new("ParticleEmitter")
	glow.Texture = SMOKE
	glow.Rate = 8
	glow.Lifetime = NumberRange.new(1.5, 2.5)
	glow.Speed = NumberRange.new(1, 3)
	glow.Color = ColorSequence.new(Color3.fromRGB(255, 120, 70))
	glow.LightEmission = 0.6
	glow.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, cfg.radius) })
	glow.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
	glow.Parent = holder
	task.delay(cfg.duration, function()
		sparks.Enabled = false
		glow.Enabled = false
		light.Enabled = false
	end)
end

function landing.fogPot(position, player, mods)
	local cfg = Items.Throw.fogPot
	Services.PerceptionService.addFogCloud(position + Vector3.new(0, 3, 0), cfg.radius, cfg.duration)
	Services.PerceptionService.emitNoise(position, cfg.noise * mods.throwNoiseMult, "fog", nil)
	for _, entry in Services.EnemyService.findNear(position, cfg.radius) do
		Services.EnemyService.stun(entry.enemy, cfg.stun, nil)
	end
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = SMOKE
	smoke.Rate = 40
	smoke.Lifetime = NumberRange.new(3, 4)
	smoke.Speed = NumberRange.new(2, 5)
	smoke.SpreadAngle = Vector2.new(180, 30)
	smoke.Drag = 1.5
	smoke.Color = ColorSequence.new(Color3.fromRGB(200, 205, 205))
	smoke.LightInfluence = 1
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 4), NumberSequenceKeypoint.new(1, cfg.radius * 1.2) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.8, 0.4), NumberSequenceKeypoint.new(1, 1) })
	smoke.Parent = effectHolder(position + Vector3.new(0, 1, 0), cfg.duration + 5)
	Sfx.at(position, "FogHiss", 0.8, 60)
	task.delay(cfg.duration, function()
		smoke.Enabled = false
	end)
end

function landing.saltBomb(position, player, mods)
	local cfg = Items.Throw.saltBomb
	local mine = Instance.new("Part")
	mine.Name = "SaltBomb"
	mine.Anchored = true
	mine.CanCollide = false
	mine.CanQuery = false
	mine.Shape = Enum.PartType.Cylinder
	mine.Size = Vector3.new(0.35, 1.1, 1.1)
	mine.Color = Color3.fromRGB(60, 58, 54)
	mine.Material = Enum.Material.Metal
	mine.CFrame = CFrame.new(position + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	mine.Parent = Workspace
	local blink = Instance.new("PointLight")
	blink.Color = Color3.fromRGB(255, 80, 60)
	blink.Range = 4
	blink.Brightness = 2
	blink.Parent = mine
	task.spawn(function()
		task.wait(cfg.armTime)
		local expires = os.clock() + cfg.lifetime
		while mine.Parent and os.clock() < expires and Services.MatchService.state == "Encounter" do
			blink.Enabled = not blink.Enabled
			if #Services.EnemyService.findNear(mine.Position, cfg.triggerRadius) > 0 then
				break
			end
			task.wait(0.25)
		end
		if not mine.Parent then
			return
		end
		local at = mine.Position
		mine:Destroy()
		Services.EnemyService.explode(at, cfg.radius, cfg.damage, player)
		Services.PerceptionService.emitNoise(at, cfg.noise, "explosion", nil)
		Sfx.at(at, "Explosion", 1, 250)
		Net.notifyAll("Explosion", { position = at, radius = cfg.radius })
		local burst = Instance.new("ParticleEmitter")
		burst.Texture = SMOKE
		burst.Rate = 0
		burst.Lifetime = NumberRange.new(1, 2)
		burst.Speed = NumberRange.new(10, 22)
		burst.SpreadAngle = Vector2.new(180, 180)
		burst.Drag = 4
		burst.Color = ColorSequence.new(Color3.fromRGB(230, 225, 210))
		burst.LightEmission = 0.3
		burst.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 8) })
		burst.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
		local holder = effectHolder(at, 3)
		burst.Parent = holder
		burst:Emit(60)
		local flash = Instance.new("PointLight")
		flash.Range = 30
		flash.Brightness = 6
		flash.Color = Color3.fromRGB(255, 220, 180)
		flash.Parent = holder
		task.delay(0.15, function()
			flash.Enabled = false
		end)
	end)
end

local THROW_COLORS = {
	bottle = Color3.fromRGB(70, 120, 90),
	flarePot = Color3.fromRGB(170, 90, 50),
	fogPot = Color3.fromRGB(150, 150, 140),
	saltBomb = Color3.fromRGB(60, 58, 54),
}

local function throw(player, info, payload)
	if type(payload) ~= "table" then
		return
	end
	local direction, itemId = payload.dir, payload.item
	if type(itemId) ~= "string" or not landing[itemId] then
		return
	end
	if not Geometry.isSaneVector(direction, 2) or direction.Magnitude < 0.5 then
		return
	end
	direction = direction.Unit
	if isBusy(info) then
		return
	end
	if not Services.InventoryService.take(player, itemId, 1) then
		toast(player, "No " .. Items.Items[itemId].name)
		return
	end
	setBusy(info, 0.35)
	cue(info, "ThrowAt")
	Sfx.at(info.root.Position, "Throw", 0.5, 30)
	local head = info.char:FindFirstChild("Head")
	local position = (head and head.Position or info.root.Position) + direction * 1.5
	local velocity = direction * Items.Throw.speed + Vector3.new(0, Items.Throw.lift, 0)
	local object = Instance.new("Part")
	object.Anchored = true
	object.CanCollide = false
	object.CanQuery = false
	object.Size = Vector3.new(0.5, 0.8, 0.5)
	object.Material = itemId == "bottle" and Enum.Material.Glass or Enum.Material.Metal
	object.Color = THROW_COLORS[itemId]
	object.Transparency = itemId == "bottle" and 0.2 or 0
	object.CFrame = CFrame.new(position)
	object.Parent = Workspace
	if itemId == "flarePot" then
		local spark = Instance.new("PointLight")
		spark.Color = Color3.fromRGB(255, 140, 70)
		spark.Range = 6
		spark.Parent = object
	end
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
			object:Destroy()
			landing[itemId](result and result.Position or position, player, mods)
			return
		end
		position += step
		object.CFrame = CFrame.new(position) * CFrame.Angles(age * 9, age * 5, 0)
	end)
end

-- Abilities ----------------------------------------------------------------------------------

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
	local ability = Characters.List[session.charId].ability
	local handler = abilities[ability.id]
	if handler and handler(player, info, ability, session.mods) then
		local cooldown = ability.cooldown * session.mods.abilityCooldownMult
		session.abilityReadyAt = os.clock() + cooldown
		info.char:SetAttribute("AbilityReadyAt", serverTime() + cooldown)
	end
end

-- Healing, torch, crafting -----------------------------------------------------------------

local function heal(player, info)
	if isBusy(info) then
		return
	end
	if info.session.hp >= Game.MaxHP then
		toast(player, "Already at full health")
		return
	end
	if Services.InventoryService.count(player, "dressing") < 1 then
		toast(player, "No Field Dressings: craft one from Cloth + Alcohol")
		return
	end
	Services.WeaponService.holster(player)
	cue(info, "HealAt")
	Sfx.at(info.root.Position, "Bandage", 0.6, 30)
	channel(info, Items.Dressing.channel, function()
		if Services.InventoryService.take(player, "dressing", 1) then
			Services.CharacterService.heal(player, Items.Dressing.heal * info.session.mods.healMult)
		end
	end)
end

local function toggleTorch(_player, char)
	Services.CharacterService.toggleFlashlight(char)
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
	local recipe = Items.Recipes[recipeId]
	Services.WeaponService.holster(player)
	channel(info, recipe.time * info.session.mods.craftTimeMult, function()
		local crafted, why = Services.InventoryService.craft(player, recipeId)
		toast(player, crafted and ("Crafted " .. recipe.name) or why)
	end)
end

-- Run aids ---------------------------------------------------------------------------------

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
	local session = Services.CharacterService.getSession(player)
	if not session or not session.runId or session.downed then
		toast(player, "Resupply works during a crossing")
		return false
	end
	if session.usedResupply then
		toast(player, "Resupply is limited to once per crossing")
		return false
	end
	if not Services.PlayerDataService.useToken(player, "resupply") then
		Net.notify(player, "NeedProduct", { productKey = "Resupply" })
		return false
	end
	session.usedResupply = true
	for itemId, amount in Items.Resupply do
		Services.InventoryService.add(player, itemId, amount)
	end
	toast(player, "Resupplied")
	return true
end

-- Dispatcher ---------------------------------------------------------------------------------

local HANDLERS = {
	Quiet = quiet,
	Throw = throw,
	Ability = useAbility,
	Heal = heal,
	Craft = craft,
	Equip = function(player, _info, slot)
		Services.WeaponService.equip(player, slot)
	end,
	Fire = function(player, info, payload)
		if type(payload) == "table" then
			Services.WeaponService.fire(player, info, payload.dir, payload.aim == true)
		end
	end,
	Reload = function(player, info)
		Services.WeaponService.reload(player, info)
	end,
	Dodge = function(player, info, direction)
		dodge(player, info, direction)
	end,
}

-- Actions allowed on the Meridian (no encounter running).
local FERRY_OK = { Craft = true, Equip = true, Reload = true, Dodge = true }

function ActionService.init(registry)
	Services = registry
end

function ActionService.start()
	Net.onServer("Action", 25, function(player, action, payload)
		if type(action) ~= "string" then
			return
		end
		if action == "SecondWind" then
			ActionService.useSecondWind(player)
			return
		elseif action == "Resupply" then
			ActionService.useResupply(player)
			return
		elseif action == "Torch" then
			local char = player.Character
			local session = Services.CharacterService.getSession(player)
			if char and session and not session.downed then
				toggleTorch(player, char)
			end
			return
		end
		local handler = HANDLERS[action]
		if not handler then
			return
		end
		local info = Services.MatchService.getActiveInfo(player)
		if not info and FERRY_OK[action] then
			info = Services.MatchService.getFerryInfo(player)
		end
		if info then
			handler(player, info, payload)
		end
	end)
end

return ActionService
