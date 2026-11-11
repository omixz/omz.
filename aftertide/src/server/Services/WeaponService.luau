--!nonstrict
-- Guns and the bow, fully server-authoritative:
--   * equip/holster (long gun on the back, sidearm on the hip; models replicate to everyone)
--   * fire: client sends only aim direction + whether it's aiming; the server applies spread
--     (hip/aim/moving/crouched + upgrades), raycasts, scores headshots, deals damage,
--     emits gunshot NOISE (stealth trade-off) and broadcasts shot FX to all clients
--   * reload from reserve ammo (timed; cancelled by swapping or going down)
--   * bow arrows are simulated projectiles with drop
-- Character attributes: Equipped (weapon id or ""), EquippedSlot, ReloadUntil (server time).
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Weapons = require(Shared.Config.Weapons)
local Upgrades = require(Shared.Config.Upgrades)
local WeaponModels = require(Shared.WeaponModels)
local Net = require(Shared.Net)
local Geometry = require(Shared.Util.Geometry)
local Sfx = require(Shared.Util.Sfx)

local WeaponService = {}
local Services

local rng = Random.new()
local models = {} -- [Player] = { long = Model?, sidearm = Model? }
local state = {} -- [Player] = { nextFireAt, equipReadyAt, reloadId, reloadSlot }

local MOD_DEFAULTS = {
	damageMult = 1, reloadMult = 1, noiseMult = 1, recoilMult = 1, spreadMult = 1,
	aimSpreadMult = 1, fireDelayMult = 1, magBonus = 0, aimFovMult = 1,
}

local function st(player)
	local s = state[player]
	if not s then
		s = { nextFireAt = 0, equipReadyAt = 0, reloadId = 0 }
		state[player] = s
	end
	return s
end

-- Combined modifiers from workbench upgrades for one weapon.
function WeaponService.mods(player, weaponId)
	local result = table.clone(MOD_DEFAULTS)
	local session = Services.CharacterService.getSession(player)
	local owned = session and session.run and session.run.weapons[weaponId]
	if owned then
		for _, upg in Upgrades.Weapon[weaponId] or {} do
			if owned[upg.id] then
				for key, value in upg.mods do
					if key == "magBonus" then
						result[key] += value
					else
						result[key] *= value
					end
				end
			end
		end
	end
	if session and session.mods then
		result.aimSpreadMult *= session.mods.aimSpreadMult
	end
	return result
end

function WeaponService.magSize(player, weaponId)
	local def = Weapons.List[weaponId]
	return def and (def.mag + WeaponService.mods(player, weaponId).magBonus) or 0
end

-- Replicates per-weapon stats the client needs (mag size, fov, recoil) as JSON.
function WeaponService.publishStats(player)
	local out = {}
	for slot, w in Services.InventoryService.weaponSlots(player) do
		local mods = WeaponService.mods(player, w.id)
		local def = Weapons.List[w.id]
		out[slot] = {
			id = w.id,
			mag = WeaponService.magSize(player, w.id),
			fov = def.aimFov * mods.aimFovMult,
			recoil = def.recoil * mods.recoilMult,
			spreadHip = def.spreadHip * mods.spreadMult,
			spreadAim = def.spreadAim * mods.spreadMult * mods.aimSpreadMult,
			fireDelay = def.fireDelay * mods.fireDelayMult,
		}
	end
	player:SetAttribute("WeaponStats", HttpService:JSONEncode(out))
end

-- Models ------------------------------------------------------------------------------------

local function mount(model, part0, offset)
	local grip = model.PrimaryPart
	local weld = grip:FindFirstChild("Mount")
	if not weld then
		weld = Instance.new("Weld")
		weld.Name = "Mount"
		weld.Parent = grip
	end
	weld.Part0 = part0
	weld.Part1 = grip
	weld.C0 = offset
	weld.C1 = CFrame.new()
end

local function placeModels(player, char, equippedSlot)
	local set = models[player]
	if not set then
		return
	end
	local hand = char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm")
	local back = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
	local hip = char:FindFirstChild("LowerTorso") or char:FindFirstChild("Torso")
	for slot, model in set do
		if slot == equippedSlot and hand then
			mount(model, hand, WeaponModels.HandOffset)
		elseif slot == "long" and back then
			mount(model, back, WeaponModels.BackOffset)
		elseif hip then
			mount(model, hip, WeaponModels.HipOffset)
		end
	end
end

function WeaponService.onSpawn(player, char)
	if models[player] then
		for _, m in models[player] do
			m:Destroy()
		end
	end
	models[player] = {}
	for slot, w in Services.InventoryService.weaponSlots(player) do
		local model = WeaponModels.build(w.id)
		if model then
			model.Name = "Weapon_" .. slot
			model:PivotTo(char:GetPivot())
			model.Parent = char
			models[player][slot] = model
		end
	end
	char:SetAttribute("Equipped", "")
	char:SetAttribute("EquippedSlot", "none")
	char:SetAttribute("ReloadUntil", 0)
	placeModels(player, char, "none")
	local s = st(player)
	s.reloadId += 1
	s.nextFireAt = 0
	WeaponService.publishStats(player)
end

function WeaponService.muzzlePosition(player)
	local char = player.Character
	local slot = char and char:GetAttribute("EquippedSlot")
	local model = models[player] and models[player][slot]
	local muzzle = model and model.PrimaryPart and model.PrimaryPart:FindFirstChild("Muzzle")
	return muzzle and muzzle.WorldPosition or nil
end

-- Actions -----------------------------------------------------------------------------------

local function swapTime(player)
	local session = Services.CharacterService.getSession(player)
	local fast = session and session.run and session.run.general.holster
	return Weapons.SwapTime * (fast and 0.5 or 1)
end

function WeaponService.equip(player, slot)
	if slot ~= "long" and slot ~= "sidearm" and slot ~= "none" then
		return
	end
	local char = player.Character
	if not char then
		return
	end
	local session = Services.CharacterService.getSession(player)
	if session and (session.downed or session.out) then
		return
	end
	local weaponId = ""
	if slot ~= "none" then
		local w = Services.InventoryService.weapon(player, slot)
		if not w then
			return
		end
		weaponId = w.id
	end
	if char:GetAttribute("EquippedSlot") == slot then
		return
	end
	local s = st(player)
	s.reloadId += 1 -- cancel reload
	char:SetAttribute("ReloadUntil", 0)
	s.equipReadyAt = os.clock() + swapTime(player)
	char:SetAttribute("Equipped", weaponId)
	char:SetAttribute("EquippedSlot", slot)
	placeModels(player, char, slot)
end

function WeaponService.holster(player)
	WeaponService.equip(player, "none")
end

local function spreadDirection(dir, degrees)
	if degrees <= 0 then
		return dir
	end
	local angle = math.rad(degrees) * math.sqrt(rng:NextNumber())
	local roll = rng:NextNumber() * math.pi * 2
	local up = math.abs(dir.Y) > 0.98 and Vector3.new(1, 0, 0) or Vector3.new(0, 1, 0)
	local basis = CFrame.lookAt(Vector3.zero, dir, up)
	return (basis * CFrame.Angles(0, 0, roll) * CFrame.Angles(angle, 0, 0)).LookVector
end

local function excludeList(char)
	local list = {}
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(list, p.Character)
		end
	end
	if not table.find(list, char) then
		table.insert(list, char)
	end
	return list
end

-- Applies damage for a hit. Returns "enemy" | "world" | nil plus hit flags.
local function applyHit(player, def, mods, result, distance)
	if not result then
		return nil
	end
	local e = Services.EnemyService.fromInstance(result.Instance)
	if not e then
		return "world"
	end
	local headshot = result.Instance.Name == "Head"
	local headMult = 1 + (def.headMult - 1) * (e.cfg.headMultScale or 1)
	local damage = def.damage * mods.damageMult * (headshot and headMult or 1)
	if def.falloff then
		damage *= math.clamp(1 - (distance / def.range) * 0.6, 0.35, 1)
	end
	local killed = Services.EnemyService.damage(e, damage, player, headshot)
	return "enemy", headshot, killed
end

local function simulateArrow(player, def, mods, origin, direction, params)
	local position = origin
	local velocity = direction * def.projectile.speed
	local gravity = Vector3.new(0, -Workspace.Gravity * def.projectile.gravityScale, 0)
	local arrow = Instance.new("Part")
	arrow.Name = "Arrow"
	arrow.Anchored = true
	arrow.CanCollide = false
	arrow.CanQuery = false
	arrow.CanTouch = false
	arrow.Size = Vector3.new(0.06, 0.06, 1.6)
	arrow.Color = Color3.fromRGB(214, 206, 188)
	arrow.Material = Enum.Material.Wood
	arrow.CFrame = CFrame.lookAt(position, position + velocity)
	arrow.Parent = Workspace
	local travelled, age = 0, 0
	local conn
	conn = RunService.Heartbeat:Connect(function(dt)
		age += dt
		velocity += gravity * dt
		local step = velocity * dt
		local result = Workspace:Raycast(position, step, params)
		if result or travelled > def.range or age > 3 then
			conn:Disconnect()
			if result then
				arrow.CFrame = CFrame.lookAt(result.Position - step.Unit * 0.6, result.Position)
				local kind, headshot, killed = applyHit(player, def, mods, result, travelled)
				if kind ~= "enemy" then
					Services.PerceptionService.emitNoise(result.Position, 12, "impact", nil) -- arrows make a good distraction
				end
				if kind == "enemy" then
					Net.notify(player, "Hit", { headshot = headshot, kill = killed })
					arrow:Destroy()
				else
					task.delay(8, function()
						arrow:Destroy()
					end)
				end
				Net.notifyAll("Impact", { position = result.Position, kind = kind or "world" })
			else
				arrow:Destroy()
			end
			return
		end
		position += step
		travelled += step.Magnitude
		arrow.CFrame = CFrame.lookAt(position, position + velocity)
	end)
end

function WeaponService.reload(player, info)
	local char = info.char
	local slot = char:GetAttribute("EquippedSlot")
	local w = Services.InventoryService.weapon(player, slot)
	if not w then
		return
	end
	local def = Weapons.List[w.id]
	local size = WeaponService.magSize(player, w.id)
	local s = st(player)
	if w.mag >= size or Services.InventoryService.count(player, def.ammo) < 1 then
		return
	end
	if (char:GetAttribute("ReloadUntil") or 0) > Workspace:GetServerTimeNow() then
		return
	end
	local mods = WeaponService.mods(player, w.id)
	local duration = def.reload * mods.reloadMult
	s.reloadId += 1
	local id = s.reloadId
	char:SetAttribute("ReloadUntil", Workspace:GetServerTimeNow() + duration)
	Sfx.at(info.root.Position, "Reload", 0.4, 30)
	task.delay(duration, function()
		if s.reloadId ~= id or not char.Parent then
			return
		end
		char:SetAttribute("ReloadUntil", 0)
		local session = Services.CharacterService.getSession(player)
		if not session or session.downed or session.out or char:GetAttribute("EquippedSlot") ~= slot then
			return
		end
		local need = size - w.mag
		local have = Services.InventoryService.count(player, def.ammo)
		local moved = math.min(need, have)
		if moved > 0 and Services.InventoryService.take(player, def.ammo, moved) then
			Services.InventoryService.setMag(player, slot, w.mag + moved)
		end
	end)
end

function WeaponService.fire(player, info, direction, aiming)
	if not Geometry.isSaneVector(direction, 2) or direction.Magnitude < 0.5 then
		return
	end
	direction = direction.Unit
	local char = info.char
	local slot = char:GetAttribute("EquippedSlot")
	local w = Services.InventoryService.weapon(player, slot)
	if not w then
		return
	end
	local s = st(player)
	local now = os.clock()
	if now < s.nextFireAt or now < s.equipReadyAt then
		return
	end
	if (char:GetAttribute("ReloadUntil") or 0) > Workspace:GetServerTimeNow() then
		return
	end
	if os.clock() < info.session.busyUntil then
		return
	end
	local def = Weapons.List[w.id]
	local mods = WeaponService.mods(player, w.id)
	if w.mag < 1 then
		Sfx.at(info.root.Position, "DryFire", 0.4, 20)
		WeaponService.reload(player, info)
		return
	end
	s.nextFireAt = now + def.fireDelay * mods.fireDelayMult * 0.9 -- small latency allowance
	Services.InventoryService.setMag(player, slot, w.mag - 1)

	-- spread
	local spread = (aiming == true) and def.spreadAim * mods.spreadMult * mods.aimSpreadMult or def.spreadHip * mods.spreadMult
	local speed = Geometry.flat(info.root.AssemblyLinearVelocity).Magnitude
	if speed > 2 then
		spread += def.moveSpread * math.clamp(speed / 14, 0, 1.5)
	end
	if char:GetAttribute("Stance") == "Crouch" then
		spread *= 0.8
	end

	local head = char:FindFirstChild("Head")
	local origin = head and head.Position or info.root.Position + Vector3.new(0, 1.5, 0)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = excludeList(char)
	local muzzle = WeaponService.muzzlePosition(player) or origin

	Services.PerceptionService.emitNoise(origin, def.noise * mods.noiseMult, "gunshot", player)
	-- the gunshot sound is played by every client (instantly for the shooter) from the Shot event

	if def.projectile then
		simulateArrow(player, def, mods, origin + direction * 0.8, spreadDirection(direction, spread), params)
		Net.notifyAll("Shot", { shooter = player.UserId, weapon = w.id, from = muzzle, hits = {}, quiet = mods.noiseMult < 1 })
	else
		local hits, anyHead, anyKill, anyEnemy = {}, false, false, false
		local impactNoise = nil
		for _ = 1, def.pellets do
			local dir = spreadDirection(direction, spread)
			local result = Workspace:Raycast(origin, dir * def.range, params)
			local hitPos = result and result.Position or origin + dir * def.range
			local kind, headshot, killed = applyHit(player, def, mods, result, (hitPos - origin).Magnitude)
			table.insert(hits, { position = hitPos, kind = kind or "none" })
			if kind == "world" then
				impactNoise = hitPos -- stray rounds clatter: Hushed near the impact come to look
			end
			if kind == "enemy" then
				anyEnemy = true
				anyHead = anyHead or headshot
				anyKill = anyKill or killed
			end
		end
		if anyEnemy then
			Net.notify(player, "Hit", { headshot = anyHead, kill = anyKill })
		end
		if impactNoise then
			Services.PerceptionService.emitNoise(impactNoise, 14, "impact", nil)
		end
		Net.notifyAll("Shot", { shooter = player.UserId, weapon = w.id, from = muzzle, hits = hits, quiet = mods.noiseMult < 1 })
	end

	if def.autoReload and w.mag <= 0 then
		task.delay(def.fireDelay * mods.fireDelayMult * 0.5, function()
			local liveInfo = Services.MatchService.getActiveInfo(player)
			if liveInfo then
				WeaponService.reload(player, liveInfo)
			end
		end)
	end
end

function WeaponService.onDowned(player)
	local s = st(player)
	s.reloadId += 1
	local char = player.Character
	if char then
		char:SetAttribute("ReloadUntil", 0)
		char:SetAttribute("Equipped", "")
		char:SetAttribute("EquippedSlot", "none")
		placeModels(player, char, "none")
	end
end

function WeaponService.init(registry)
	Services = registry
end

function WeaponService.start()
	Players.PlayerRemoving:Connect(function(player)
		models[player] = nil
		state[player] = nil
	end)
	Net.onServer("Look", 12, function(player, pitch)
		if type(pitch) ~= "number" or pitch ~= pitch then
			return
		end
		local char = player.Character
		if char then
			char:SetAttribute("AimPitch", math.floor(math.clamp(pitch, -1.3, 1.3) * 100) / 100)
		end
	end)
end

return WeaponService
