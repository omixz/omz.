--!nonstrict
-- How the Hushed sense players.
--   Sight: range + field-of-view cone + line-of-sight raycasts, scaled by stance, cover (reeds),
--          light (lamp pools, your torch), movement and fog.
--   Hearing: every gameplay sound is a server "noise event" {position, radius, kind, player}.
--          Footsteps are generated here from real velocity + stance, 4 times a second.
-- The current footstep noise radius is published as the character attribute "Noise" for the HUD.
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Movement = require(Shared.Config.Movement)
local Geometry = require(Shared.Util.Geometry)

local PerceptionService = {}
local Services

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

function PerceptionService.setEnemyFolder(folder)
	rayParams.FilterDescendantsInstances = { folder }
end

-- Returns 0 (unseen) or a positive visibility factor (higher = noticed faster).
function PerceptionService.sightFactor(enemy, info)
	local cfg = enemy.cfg
	local char, root = info.char, info.root
	local head = char:FindFirstChild("Head")
	if not head then
		return 0
	end
	local modifier = Services.MatchService.modifier or {}
	local eyes = enemy.head.Position
	local toPlayer = root.Position - eyes
	local dist = toPlayer.Magnitude
	local range = cfg.sightRange * (modifier.sightMult or 1)
	local lit = char:GetAttribute("Torch") == true or Geometry.inTagged(root.Position, "LitZone")
	if lit then
		range *= 1.45
	end
	if dist > range or dist < 0.01 then
		return 0
	end
	if dist > 4.5 and enemy.root.CFrame.LookVector:Dot(toPlayer.Unit) < enemy.fovCos then
		return 0
	end

	local visible = false
	for _, target in { head.Position, root.Position } do
		local result = Workspace:Raycast(eyes, target - eyes, rayParams)
		if not result or result.Instance:IsDescendantOf(char) then
			visible = true
			break
		end
	end
	if not visible then
		return 0
	end

	local f = 1 - (dist / range) * 0.75
	if char:GetAttribute("Stance") == "Crouch" then
		f *= 0.55
	end
	if Geometry.inTagged(root.Position, "TallGrass") then
		f *= 0.35
	end
	if lit then
		f *= 1.8
	end
	local speed = Geometry.flat(root.AssemblyLinearVelocity).Magnitude
	if speed < 1 then
		f *= 0.6
	elseif speed > 17 then
		f *= 1.3
	end
	if dist < cfg.closeRange then
		f *= 2.5
	end
	return f
end

-- Any sound in the world that Hushed may react to.
function PerceptionService.emitNoise(position, radius, kind, player)
	local modifier = Services.MatchService.modifier or {}
	radius *= modifier.noiseMult or 1
	if radius <= 0 then
		return
	end
	Services.EnemyService.onNoise({ position = position, radius = radius, kind = kind, player = player })
end

local function footstepRadius(info, now)
	local char, root, session = info.char, info.root, info.session
	local mods = session.mods
	local speed = Geometry.flat(root.AssemblyLinearVelocity).Magnitude
	if speed < 1 or char:GetAttribute("Downed") then
		return 0
	end
	local radius
	if char:GetAttribute("Stance") == "Crouch" then
		radius = Movement.Noise.Crouch * mods.crouchNoiseMult
	elseif speed < 10.5 then
		radius = Movement.Noise.Walk
	elseif speed < 17 then
		radius = Movement.Noise.Jog
	else
		radius = Movement.Noise.Sprint
	end
	if Geometry.inTagged(root.Position, "Shallows") then
		radius *= 1 + (Movement.WaterNoiseMult - 1) * mods.waterNoiseMult
	end
	local modifier = Services.MatchService.modifier or {}
	radius *= mods.noiseMult * (modifier.footstepMult or 1)
	if (session.calmUntil or 0) > now then
		radius *= 0.5
	end
	return radius
end

function PerceptionService.init(registry)
	Services = registry
end

function PerceptionService.start()
	while true do
		task.wait(0.25)
		if Services.MatchService.state == "Encounter" then
			local now = os.clock()
			for _, info in Services.MatchService.getActivePlayers() do
				local radius = footstepRadius(info, now)
				info.char:SetAttribute("Noise", math.floor(radius + 0.5))
				if radius > 0 then
					PerceptionService.emitNoise(info.root.Position, radius, "footstep", info.player)
				end
			end
		end
	end
end

return PerceptionService
