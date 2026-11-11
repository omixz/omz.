--!nonstrict
-- Client side of the gun system: input -> server intents, plus instant local feedback
-- (muzzle flash, recoil kick, crosshair bloom) so shooting feels responsive. The server
-- decides every hit (WeaponService).
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Items = require(Shared.Config.Items)
local Weapons = require(Shared.Config.Weapons)
local Net = require(Shared.Net)
local State = require(script.Parent.Parent.State)

local WeaponController = {}
local Controllers
local player = Players.LocalPlayer

local nextFireAt = 0
local cachedJson, cachedStats = nil, {}

local function act(name, payload)
	Net.event("Action"):FireServer(name, payload)
end

function WeaponController.stats()
	local json = player:GetAttribute("WeaponStats")
	if json ~= cachedJson then
		cachedJson = json
		local ok, decoded = pcall(function()
			return HttpService:JSONDecode(json or "{}")
		end)
		cachedStats = ok and decoded or {}
	end
	return cachedStats
end

-- slot, weaponId, stats (or nil when holstered)
function WeaponController.current()
	local char = State.character
	if not char then
		return "none", nil, nil
	end
	local slot = char:GetAttribute("EquippedSlot") or "none"
	local id = char:GetAttribute("Equipped")
	if not id or id == "" then
		return "none", nil, nil
	end
	return slot, id, WeaponController.stats()[slot]
end

function WeaponController.isReloading()
	local char = State.character
	return char ~= nil and (char:GetAttribute("ReloadUntil") or 0) > Workspace:GetServerTimeNow()
end

function WeaponController.equip(slot)
	if not State.character or State.downed then
		return
	end
	local current = WeaponController.current()
	if current == slot then
		slot = "none"
	end
	if slot ~= "none" and (player:GetAttribute("W_" .. slot) or "") == "" then
		return
	end
	act("Equip", slot)
end

function WeaponController.cycleWeapon()
	local current = WeaponController.current()
	local order = { "long", "sidearm", "none" }
	local index = table.find(order, current) or 3
	for step = 1, 3 do
		local slot = order[(index + step - 1) % 3 + 1]
		if slot == "none" or (player:GetAttribute("W_" .. slot) or "") ~= "" then
			act("Equip", slot)
			return
		end
	end
end

local function muzzleFlash(slot)
	local char = State.character
	local model = char and char:FindFirstChild("Weapon_" .. slot)
	local grip = model and model.PrimaryPart
	local muzzle = grip and grip:FindFirstChild("Muzzle")
	if not muzzle then
		return
	end
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 200, 140)
	light.Range = 16
	light.Brightness = 5
	light.Shadows = true
	light.Parent = muzzle
	local flash = Instance.new("ParticleEmitter")
	flash.Rate = 0
	flash.Lifetime = NumberRange.new(0.04, 0.07)
	flash.Speed = NumberRange.new(2, 6)
	flash.SpreadAngle = Vector2.new(18, 18)
	flash.EmissionDirection = Enum.NormalId.Front
	flash.LightEmission = 1
	flash.Color = ColorSequence.new(Color3.fromRGB(255, 210, 150))
	flash.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
	flash.Parent = muzzle
	flash:Emit(6)
	task.delay(0.06, function()
		light:Destroy()
	end)
	task.delay(0.3, function()
		flash:Destroy()
	end)
end

function WeaponController.fire()
	if not State.character or State.downed or State.uiOpen() then
		return
	end
	local slot, id, stat = WeaponController.current()
	if not id or not stat then
		return
	end
	local now = os.clock()
	if now < nextFireAt or WeaponController.isReloading() then
		return
	end
	local mag = player:GetAttribute("W_" .. slot .. "Mag") or 0
	if mag <= 0 then
		act("Reload")
		return
	end
	nextFireAt = now + (stat.fireDelay or 0.5)
	act("Fire", { dir = Controllers.CameraController.aimDirection(), aim = State.aiming })
	if Weapons.List[id] and not Weapons.List[id].projectile then
		muzzleFlash(slot)
	end
	Controllers.CameraController.kick(stat.recoil or 3)
	State.bloom = math.min(State.bloom + (stat.recoil or 3) * 0.5, 8)
end

function WeaponController.reload()
	local _, id = WeaponController.current()
	if id then
		act("Reload")
	end
end

-- Current spread in degrees (drives the crosshair; mirrors the server formula).
function WeaponController.spread()
	local _, id, stat = WeaponController.current()
	if not id or not stat then
		return 0
	end
	local def = Weapons.List[id]
	local spread = State.aiming and stat.spreadAim or stat.spreadHip
	local root = State.root
	if root then
		local v = root.AssemblyLinearVelocity
		local speed = Vector3.new(v.X, 0, v.Z).Magnitude
		if speed > 2 then
			spread += def.moveSpread * math.clamp(speed / 14, 0, 1.5)
		end
	end
	if State.crouched then
		spread *= 0.8
	end
	return spread + State.bloom
end

function WeaponController.aimFov()
	local _, id, stat = WeaponController.current()
	return id and stat and stat.fov or nil
end

function WeaponController.cycleThrowable()
	local list = Items.Throwables
	local index = table.find(list, State.throwable) or 1
	for step = 1, #list do
		local candidate = list[(index + step - 1) % #list + 1]
		if (player:GetAttribute("Inv_" .. candidate) or 0) > 0 then
			State.throwable = candidate
			return
		end
	end
end

function WeaponController.throw()
	if not State.character or State.downed or State.uiOpen() then
		return
	end
	if (player:GetAttribute("Inv_" .. State.throwable) or 0) < 1 then
		WeaponController.cycleThrowable()
	end
	if (player:GetAttribute("Inv_" .. State.throwable) or 0) < 1 then
		return
	end
	act("Throw", { dir = Controllers.CameraController.aimDirection(), item = State.throwable })
end

function WeaponController.init(registry)
	Controllers = registry
end

function WeaponController.start()
	game:GetService("RunService").RenderStepped:Connect(function(dt)
		State.bloom = math.max(0, State.bloom - dt * 6)
	end)
end

return WeaponController
