--!nonstrict
-- The Hushed. Server-simulated, one state machine per enemy:
--   Patrol -> (notice) -> Investigate -> Search -> Patrol
--   any    -> (suspicion >= 1 or shot) -> Chase -> (lost sight) -> Search
--   Stunned / Pinned / Quieted are timed overrides.
-- Types (Config/Enemies): Drifter, Bellwether (hums to alert others), Tidewalker (tank).
-- Encounter behaviours: `objective` (walk to and attack the signal lantern) and `hunt`
-- (periodically told roughly where the players are).
-- Replicated model attributes: State, Target (UserId), Sus_<UserId>, Type, HP (0..1).
local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local EnemyConfig = require(Shared.Config.Enemies)
local AssetIds = require(Shared.Config.AssetIds)
local MeshKit = require(Shared.MeshKit)
local Geometry = require(Shared.Util.Geometry)
local Sfx = require(Shared.Util.Sfx)
local Net = require(Shared.Net)

local EnemyService = {}
local Services

local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

local folder
local enemies = {}
local byModel = {}
local fireZones = {}
local rng = Random.new()
local occlusionParams = RaycastParams.new()
occlusionParams.FilterType = Enum.RaycastFilterType.Exclude

-- Model -----------------------------------------------------------------------------------

local RAG_COLORS = {
	Color3.fromRGB(70, 66, 58), Color3.fromRGB(58, 64, 70), Color3.fromRGB(86, 70, 52),
	Color3.fromRGB(64, 58, 66), Color3.fromRGB(92, 88, 78), Color3.fromRGB(54, 60, 52),
}

-- Builds a jointed body (Motor6D skeleton) so clients can animate it procedurally:
--   Root -> Torso (Waist) -> Head (Neck), UpperArms (Shoulders) -> LowerArms (Elbows)
--   Root -> UpperLegs (Hips) -> LowerLegs (Knees)
-- Each type gets its own proportions, head shape, salt-crust growths and clothing rags.
local function buildModel(position, typeName, cfg)
	local k = cfg.scale
	local body = cfg.body
	local model = Instance.new("Model")
	model.Name = "Hushed_" .. typeName

	local legLen = 1.6 * body.legs
	-- legs end 0.2 + 2*legLen below the root centre; the root's bottom is 1 below it
	local hipHeight = (legLen * 2 - 0.8) * k
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1) * k
	root.Transparency = 1
	root.CanCollide = true
	root.CFrame = CFrame.new(position + Vector3.new(0, hipHeight + 1 * k, 0))
	root.Name = "HumanoidRootPart"
	root.Parent = model
	model.PrimaryPart = root

	local base = cfg.color
	local function part(name, size, color, material, shape)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size * k
		p.Color = color or base
		p.Material = material or Enum.Material.SmoothPlastic
		if not material then
			p.Reflectance = 0.06 -- wet, charred skin
		end
		p.CanCollide = false
		p.CanTouch = false
		p.Massless = true
		if shape then
			p.Shape = shape
		end
		p.CFrame = root.CFrame
		p.Parent = model
		return p
	end
	local function joint(name, part0, part1, c0, c1)
		local m = Instance.new("Motor6D")
		m.Name = name
		m.Part0 = part0
		m.Part1 = part1
		m.C0 = CFrame.new(c0.Position * k) * c0.Rotation
		m.C1 = CFrame.new(c1.Position * k) * c1.Rotation
		m.Parent = part0
		return m
	end
	local function attach(name, target, size, offset, color, material, shape)
		local p = part(name, size, color, material, shape)
		local w = Instance.new("Weld")
		w.Part0 = target
		w.Part1 = p
		w.C0 = CFrame.new(offset.Position * k) * offset.Rotation
		w.Parent = p
		return p
	end

	local tw = body.torso
	local torso = part("Torso", Vector3.new(1.5 * tw, 2.0, 0.85 * tw))
	joint("Waist", root, torso, CFrame.new(0, 0.3, 0) * CFrame.Angles(math.rad(-body.hunch), 0, 0), CFrame.new(0, -1.0, 0))

	local CRUST = Color3.fromRGB(232, 228, 216)
	local headColor = body.head == "shell" and CRUST or Color3.new(math.min(1, base.R * 1.15), math.min(1, base.G * 1.15), math.min(1, base.B * 1.15))
	local headSize = ({
		round = Vector3.new(1.0, 1.25, 1.0),
		half = Vector3.new(0.95, 1.2, 0.95),
		shell = Vector3.new(1.55, 1.5, 1.55),
		disc = Vector3.new(1.5, 0.95, 1.5),
		sunk = Vector3.new(1.05, 1.05, 1.05),
	})[body.head] or Vector3.new(1, 1.25, 1)
	local head = part("Head", headSize, headColor, body.head == "shell" and Enum.Material.Sand or nil)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = head
	local neckY = body.head == "sunk" and 0.75 or 1.0
	joint("Neck", torso, head, CFrame.new(0, neckY, -0.1), CFrame.new(0, -headSize.Y * 0.5 + 0.1, 0.1))
	if body.head == "half" then
		-- salt has sealed half the face
		attach("FaceCrust", head, Vector3.new(0.55, 0.9, 0.5), CFrame.new(0.25, 0.05, -0.32), Color3.fromRGB(232, 228, 216), Enum.Material.Sand, Enum.PartType.Ball)
	end

	local armLen = 1.5 * body.arms
	for _, side in { -1, 1 } do
		local name = side < 0 and "Left" or "Right"
		local upper = part(name .. "UpperArm", Vector3.new(0.42 * tw, armLen, 0.42 * tw))
		local lower = part(name .. "LowerArm", Vector3.new(0.38 * tw, armLen * 1.07, 0.38 * tw))
		joint(name .. "Shoulder", torso, upper, CFrame.new(side * (0.75 * tw + 0.2), 0.85, 0) * CFrame.Angles(math.rad(8), 0, math.rad(side * 4)), CFrame.new(0, armLen * 0.5, 0))
		joint(name .. "Elbow", upper, lower, CFrame.new(0, -armLen * 0.5, 0), CFrame.new(0, armLen * 0.535, 0))
		local upperLeg = part(name .. "UpperLeg", Vector3.new(0.56 * tw, legLen, 0.56 * tw))
		local lowerLeg = part(name .. "LowerLeg", Vector3.new(0.5 * tw, legLen, 0.5 * tw))
		joint(name .. "Hip", root, upperLeg, CFrame.new(side * 0.42 * tw, -0.2, 0), CFrame.new(0, legLen * 0.5, 0))
		joint(name .. "Knee", upperLeg, lowerLeg, CFrame.new(0, -legLen * 0.5, 0), CFrame.new(0, legLen * 0.5, 0))
	end

	-- what's left of their clothes: rags over torso and thighs
	local rng = Random.new()
	local ragColor = RAG_COLORS[rng:NextInteger(1, #RAG_COLORS)]
	for i = 1, body.rags do
		local onLeg = i % 2 == 0
		local target = onLeg and model[(rng:NextNumber() < 0.5 and "Left" or "Right") .. "UpperLeg"] or torso
		local size = onLeg and Vector3.new(0.62 * tw, 0.9, 0.62 * tw) or Vector3.new(1.55 * tw, rng:NextNumber(0.5, 1.1), 0.9 * tw)
		local offset = onLeg and CFrame.new(0, rng:NextNumber(-0.2, 0.4), 0) or CFrame.new(0, rng:NextNumber(-0.6, 0.6), 0) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-10, 10)))
		attach("Rag" .. i, target, size, offset, ragColor, Enum.Material.Fabric)
	end

	-- the maw: a black, gaping hollow where the face was (clients open it when they hunt)
	if body.maw then
		local maw = attach("Maw", head, Vector3.new(headSize.X * 0.42, headSize.Y * 0.36, 0.3), CFrame.new(0, -headSize.Y * 0.12, -headSize.Z * 0.42), Color3.fromRGB(8, 6, 6), Enum.Material.SmoothPlastic)
		local mm = Instance.new("SpecialMesh")
		mm.MeshType = Enum.MeshType.Sphere
		mm.Parent = maw
	end
	-- jagged salt spines out of the back and shoulders
	for i = 1, body.spines or 0 do
		local w = Instance.new("WedgePart")
		w.Name = "Spine" .. i
		local len = rng:NextNumber(0.5, 1.3)
		w.Size = Vector3.new(0.18, len, rng:NextNumber(0.3, 0.6)) * k
		w.Color = CRUST
		w.Material = Enum.Material.Sand
		w.CanCollide = false
		w.CanTouch = false
		w.Massless = true
		w.CFrame = torso.CFrame
		w.Parent = model
		local weld = Instance.new("Weld")
		weld.Part0 = torso
		weld.Part1 = w
		weld.C0 = CFrame.new(rng:NextNumber(-0.6, 0.6) * torso.Size.X / 2, rng:NextNumber(-0.2, 0.9) * torso.Size.Y / 2, torso.Size.Z / 2 + len * 0.3 * k)
			* CFrame.Angles(math.rad(rng:NextNumber(20, 60)), math.rad(rng:NextNumber(-30, 30)), math.rad(rng:NextNumber(-25, 25)))
		weld.Parent = w
	end
	-- salt growths: lumpy crust on shoulders, back and head
	local spots = { torso, torso, head, model.LeftUpperArm, model.RightUpperArm }
	for i = 1, body.crust do
		local target = spots[(i - 1) % #spots + 1]
		local r = rng:NextNumber(0.25, 0.6) * (target == torso and 1.4 or 1)
		local offset = CFrame.new(rng:NextNumber(-0.5, 0.5) * target.Size.X / k, rng:NextNumber(-0.3, 0.5) * target.Size.Y / k, (target == head and -1 or 1) * rng:NextNumber(0.2, 0.5) * target.Size.Z / k)
		attach("Crust" .. i, target, Vector3.new(r, r * rng:NextNumber(0.7, 1.2), r), offset, CRUST, Enum.Material.Sand, Enum.PartType.Ball)
	end

	local drift = Instance.new("ParticleEmitter")
	drift.Rate = 3 + body.crust * 0.5
	drift.Lifetime = NumberRange.new(2, 3)
	drift.Speed = NumberRange.new(0.4, 1.2)
	drift.SpreadAngle = Vector2.new(180, 180)
	drift.Acceleration = Vector3.new(0, 0.8, 0)
	drift.Color = ColorSequence.new(base)
	drift.LightInfluence = 1
	drift.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.12 * k), NumberSequenceKeypoint.new(1, 0) })
	drift.Enabled = not cfg.human -- people don't shed salt
	drift.Parent = torso

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15 -- R15 so HipHeight (not leg parts) sets floor height
	humanoid.HipHeight = hipHeight
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.WalkSpeed = 5
	humanoid.UseJumpPower = true
	humanoid.JumpPower = 0
	humanoid.AutoJumpEnabled = false
	humanoid.RequiresNeck = false
	humanoid.BreakJointsOnDeath = false
	humanoid.Parent = model
	for _, st in {
		Enum.HumanoidStateType.Climbing,
		Enum.HumanoidStateType.FallingDown,
		Enum.HumanoidStateType.Ragdoll,
		Enum.HumanoidStateType.Seated,
		Enum.HumanoidStateType.Jumping,
	} do
		humanoid:SetStateEnabled(st, false)
	end
	model:SetAttribute("Type", typeName)
	model:SetAttribute("Gait", cfg.gait or "shamble")
	model:SetAttribute("HP", 1)
	return model, humanoid, root, head
end

-- Helpers ---------------------------------------------------------------------------------

local function setState(e, newState)
	if e.state == newState then
		return
	end
	e.state = newState
	e.stateTime = os.clock()
	e.waypoints = nil
	e.pathGoal = nil
	e.searchPoint = nil
	e.model:SetAttribute("State", newState)
	if newState ~= "Chase" and e.model:GetAttribute("Aiming") then
		e.model:SetAttribute("Aiming", false)
	end
end

local function face(e, position)
	local pos = e.root.Position
	local flatTarget = Vector3.new(position.X, pos.Y, position.Z)
	if (flatTarget - pos).Magnitude < 0.1 then
		return
	end
	e.root.CFrame = e.root.CFrame:Lerp(CFrame.lookAt(pos, flatTarget), 0.3)
end

local function stop(e)
	e.humanoid.WalkSpeed = 0
	e.humanoid:MoveTo(e.root.Position)
end

local function computePath(e, goal)
	e.computing = true
	e.lastPathTime = os.clock()
	local start = e.root.Position
	task.spawn(function()
		local ok = pcall(function()
			e.path:ComputeAsync(start, goal)
		end)
		e.computing = false
		if e.dead then
			return
		end
		if ok and e.path.Status == Enum.PathStatus.Success then
			e.waypoints = e.path:GetWaypoints()
			e.wpIndex = math.min(2, #e.waypoints)
		else
			e.waypoints = nil
		end
		e.pathGoal = goal
	end)
end

local function moveTo(e, goal, speed)
	local now = os.clock()
	local pos = e.root.Position
	e.humanoid.WalkSpeed = speed
	if Geometry.flatDistance(pos, goal) < 2.5 then
		e.humanoid:MoveTo(pos)
		return true
	end
	local goalChanged = not e.pathGoal or Geometry.flatDistance(e.pathGoal, goal) > 4
	if not e.computing and (goalChanged or now - e.lastPathTime > 4) then
		computePath(e, goal)
	end
	local target = goal
	if e.waypoints and e.pathGoal and Geometry.flatDistance(e.pathGoal, goal) <= 4 then
		local wp = e.waypoints[e.wpIndex]
		while wp and e.wpIndex < #e.waypoints and Geometry.flatDistance(pos, wp.Position) < 2.2 do
			e.wpIndex += 1
			wp = e.waypoints[e.wpIndex]
		end
		if wp then
			target = wp.Position
		end
	end
	e.humanoid:MoveTo(target)
	if now - e.progressTime > 2 then
		if (pos - e.progressPos).Magnitude < 1 then
			e.pathGoal = nil
			e.lastPathTime = 0
		end
		e.progressPos = pos
		e.progressTime = now
	end
	return false
end

local function findInfo(list, player)
	for _, info in list do
		if info.player == player then
			return info
		end
	end
	return nil
end

local function publishSuspicion(e, active)
	for _, info in active do
		local value = math.floor((e.suspicion[info.player] or 0) * 20 + 0.5) / 20
		local key = "Sus_" .. info.player.UserId
		if e.model:GetAttribute(key) ~= value then
			e.model:SetAttribute(key, value)
		end
	end
	local targetId = e.target and e.target.UserId or 0
	if e.model:GetAttribute("Target") ~= targetId then
		e.model:SetAttribute("Target", targetId)
	end
end

local function alertTo(e, player)
	if e.dead or e.state == "Quieted" then
		return
	end
	e.suspicion[player] = math.max(e.suspicion[player] or 0, e.cfg.alertThreshold)
end

local function hum(e, now)
	local h = e.cfg.hum
	if not h or now < (e.nextHum or 0) or not e.target then
		return
	end
	e.nextHum = now + h.cooldown
	Sfx.at(e.root.Position, "Hum", 0.8, h.radius * 2)
	Net.notifyAll("Hum", { position = e.root.Position, radius = h.radius })
	Services.PerceptionService.emitNoise(e.root.Position, h.radius, "hum", e.target)
end

-- Human combat --------------------------------------------------------------------------------

local shotParams = RaycastParams.new()
shotParams.FilterType = Enum.RaycastFilterType.Exclude

local function humanAttack(e, info, dist, seen, now)
	local cfg, atk = e.cfg, e.cfg.attack
	if now - (e.lastSeen[e.target] or 0) > cfg.loseSightTime then
		e.suspicion[e.target] = 0.6
		e.target = nil
		e.searchOrigin = e.lastKnown
		setState(e, "Search")
		return
	end
	if atk.kind == "melee" then
		if dist <= atk.range then
			stop(e)
			face(e, info.root.Position)
			if now >= (e.nextShotAt or 0) then
				e.nextShotAt = now + atk.fireDelay
				e.model:SetAttribute("AttackAt", workspace:GetServerTimeNow())
				task.delay(0.25, function()
					if not e.dead and info.root.Parent and (info.root.Position - e.root.Position).Magnitude <= atk.range + 1 then
						Services.CharacterService.damage(info.player, atk.damage, e.root.Position)
						Sfx.at(info.root.Position, "MeleeHit", 0.7, 50)
					end
				end)
				Sfx.at(e.root.Position, "Swing", 0.6, 40)
			end
		elseif seen then
			e.humanoid.WalkSpeed = cfg.chaseSpeed
			e.humanoid:MoveTo(info.root.Position)
		else
			moveTo(e, e.lastKnown, cfg.chaseSpeed)
		end
		return
	end
	-- ranged: hold position and fire while in sight and range, otherwise close in
	if seen and dist <= atk.range then
		stop(e)
		face(e, info.root.Position)
		e.model:SetAttribute("Aiming", true)
		if now >= (e.nextShotAt or 0) then
			e.nextShotAt = now + atk.fireDelay * (0.8 + rng:NextNumber() * 0.5)
			local muzzle = e.head.Position + e.root.CFrame.LookVector * 1.2 - Vector3.new(0, 0.4, 0)
			local char = info.char
			local chance = atk.accuracy * math.clamp(1.15 - dist / atk.range * 0.7, 0.2, 1)
			if char:GetAttribute("Stance") == "Crouch" then
				chance *= 0.75
			end
			if info.root.AssemblyLinearVelocity.Magnitude > 14 then
				chance *= 0.7
			end
			local aim = info.root.Position + Vector3.new(0, 0.8, 0)
			local hit = rng:NextNumber() < chance
			if not hit then
				aim += Vector3.new(rng:NextNumber(-3, 3), rng:NextNumber(-1, 2), rng:NextNumber(-3, 3))
			end
			shotParams.FilterDescendantsInstances = { folder }
			local result = Workspace:Raycast(muzzle, (aim - muzzle).Unit * (atk.range + 10), shotParams)
			local hitPos = result and result.Position or aim
			local hitPlayer = result and result.Instance:IsDescendantOf(char)
			if hitPlayer then
				Services.CharacterService.damage(info.player, atk.damage, nil)
			end
			Net.notifyAll("Shot", { shooter = 0, weapon = atk.weapon, from = muzzle, hits = { { position = hitPos, kind = hitPlayer and "none" or "world" } }, quiet = atk.noise < 20 })
			Services.PerceptionService.emitNoise(e.root.Position, atk.noise, "gunshot", nil)
		end
	else
		e.model:SetAttribute("Aiming", false)
		if seen then
			e.humanoid.WalkSpeed = cfg.chaseSpeed
			e.humanoid:MoveTo(info.root.Position)
		else
			moveTo(e, e.lastKnown, cfg.chaseSpeed)
		end
	end
end

-- Brain -----------------------------------------------------------------------------------

local function update(e, dt, now, active)
	local cfg = e.cfg

	if now < e.stunUntil then
		stop(e)
		publishSuspicion(e, active)
		return
	elseif e.state == "Stunned" or e.state == "Pinned" then
		if e.net then
			e.net:Destroy()
			e.net = nil
		end
		setState(e, e.investigatePos and "Investigate" or "Search")
		e.searchOrigin = e.root.Position
	end

	local bestPlayer, bestSus = nil, 0
	for _, info in active do
		local p = info.player
		local sus = e.suspicion[p] or 0
		local vis = Services.PerceptionService.sightFactor(e, info)
		if vis > 0 then
			sus += vis * cfg.suspicionGain * dt
			e.lastSeen[p] = now
			if sus >= cfg.investigateThreshold then
				e.investigatePos = info.root.Position
			end
		elseif not (e.state == "Chase" and e.target == p) then
			sus -= cfg.suspicionDecay * dt
		end
		sus = math.clamp(sus, 0, 1.2)
		e.suspicion[p] = sus
		if sus > bestSus then
			bestPlayer, bestSus = p, sus
		end
	end
	for p in e.suspicion do
		if not findInfo(active, p) then
			e.suspicion[p] = nil
		end
	end

	if e.state ~= "Chase" and bestPlayer and bestSus >= cfg.alertThreshold then
		e.target = bestPlayer
		e.lastKnown = findInfo(active, bestPlayer).root.Position
		e.lastSeen[bestPlayer] = e.lastSeen[bestPlayer] or now
		setState(e, "Chase")
		Services.MatchService.onSpotted(bestPlayer, e)
		if cfg.callout and now > (e.nextCallout or 0) then
			-- radio / bell: everyone nearby converges on the spotted player
			e.nextCallout = now + 10
			Sfx.at(e.root.Position, cfg.callout, 0.9, 140)
			Services.PerceptionService.emitNoise(e.lastKnown, 70, "callout", bestPlayer)
		end
	end

	if e.state == "Chase" then
		hum(e, now)
		local info = e.target and findInfo(active, e.target)
		if not info then
			e.target = nil
			e.searchOrigin = e.lastKnown or e.root.Position
			setState(e, "Search")
		else
			local seenRecently = now - (e.lastSeen[e.target] or 0) < 0.35
			if seenRecently then
				e.lastKnown = info.root.Position
			end
			local dist = (info.root.Position - e.root.Position).Magnitude
			if cfg.attack then
				humanAttack(e, info, dist, seenRecently, now)
				publishSuspicion(e, active)
				return
			end
			if dist <= cfg.grabRange and now >= e.recoverUntil then
				e.recoverUntil = now + cfg.grabRecover
				if not Services.ActionService.trySpikeCounter(info.player, e) then
					Services.CharacterService.damage(info.player, cfg.grabDamage, e.root.Position)
				end
			end
			if e.dead then
				return
			end
			if now < e.recoverUntil - cfg.grabRecover + 0.9 then
				stop(e)
			elseif now - (e.lastSeen[e.target] or 0) > cfg.loseSightTime then
				e.suspicion[e.target] = 0.6
				e.target = nil
				e.searchOrigin = e.lastKnown
				setState(e, "Search")
			elseif seenRecently and dist < 35 then
				e.humanoid.WalkSpeed = cfg.chaseSpeed
				e.humanoid:MoveTo(info.root.Position)
			else
				moveTo(e, e.lastKnown, cfg.chaseSpeed)
			end
		end
		publishSuspicion(e, active)
		return
	end

	if e.investigatePos and e.state ~= "Investigate" then
		setState(e, "Investigate")
	end

	if e.state == "Investigate" then
		if not e.investigatePos then
			setState(e, "Search")
		elseif bestSus >= cfg.noticeThreshold and bestSus < cfg.investigateThreshold and bestPlayer then
			stop(e)
			face(e, findInfo(active, bestPlayer).root.Position)
		elseif moveTo(e, e.investigatePos, (cfg.rushToNoise and os.clock() - (e.heardAt or 0) < 3) and cfg.chaseSpeed or cfg.investigateSpeed) then
			e.searchOrigin = e.investigatePos
			e.investigatePos = nil
			setState(e, "Search")
		end
	elseif e.state == "Search" then
		if now - e.stateTime > cfg.searchTime then
			setState(e, "Patrol")
		elseif e.searchPoint then
			if moveTo(e, e.searchPoint, cfg.patrolSpeed + 1.5) then
				e.searchPoint = nil
				e.searchPause = now + 1.2
			end
		elseif now >= (e.searchPause or 0) then
			local origin = e.searchOrigin or e.root.Position
			e.searchPoint = origin + Vector3.new(rng:NextNumber(-14, 14), 0, rng:NextNumber(-14, 14))
		else
			stop(e)
			face(e, e.root.Position + e.root.CFrame.RightVector * (rng:NextNumber() < 0.5 and -4 or 4))
		end
	else -- Patrol (or objective)
		if bestPlayer and bestSus >= cfg.noticeThreshold then
			stop(e)
			face(e, findInfo(active, bestPlayer).root.Position)
		elseif e.objective then
			if moveTo(e, e.objective, cfg.investigateSpeed) or (e.root.Position - e.objective).Magnitude < 6 then
				stop(e)
				face(e, e.objective)
				Services.MatchService.onObjectiveAttacked(e.objectiveDps * dt)
			end
		else
			local waypoint = e.route[e.routeIndex]
			if moveTo(e, waypoint, cfg.patrolSpeed) then
				e.routeIndex = e.routeIndex % #e.route + 1
			end
		end
	end

	publishSuspicion(e, active)
end

-- Public API ------------------------------------------------------------------------------

-- opts: { route = {Vector3...}, objective = Vector3, objectiveDps = n, hunt = bool, alertTo = Player }
function EnemyService.spawn(typeName, position, opts)
	opts = opts or {}
	local cfg = EnemyConfig.Types[typeName] or EnemyConfig.Types.Drifter
	local model, humanoid, root, head = buildModel(position, typeName, cfg)
	local kit = (cfg.human and "Faction_" or "Hushed_") .. typeName
	if Services.AssetService.hasKit(kit) then
		pcall(MeshKit.applyRig, model, Services.AssetService.meta(kit), Services.AssetService.part, "enemy", AssetIds.YawFix)
	end
	if cfg.flashlight then
		Services.CharacterService.addFlashlight(model, "Torso")
		Services.CharacterService.setFlashlight(model, true)
	end
	model:SetAttribute("Human", cfg.human == true)
	model.Parent = folder
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	local route = opts.route or { position }
	local e = {
		model = model,
		humanoid = humanoid,
		root = root,
		head = head,
		typeName = typeName,
		cfg = cfg,
		hp = cfg.hp,
		fovCos = math.cos(math.rad(cfg.fovDeg / 2)),
		route = route,
		routeIndex = rng:NextInteger(1, #route),
		objective = opts.objective,
		objectiveDps = opts.objectiveDps or 0,
		hunt = opts.hunt == true,
		path = PathfindingService:CreatePath({
			AgentRadius = 2 * cfg.scale,
			AgentHeight = 7 * cfg.scale,
			AgentCanJump = false,
			WaypointSpacing = 6,
		}),
		lastPathTime = 0,
		progressPos = root.Position,
		progressTime = os.clock(),
		stunUntil = 0,
		recoverUntil = 0,
		suspicion = {},
		lastSeen = {},
		state = "",
		stateTime = os.clock(),
	}
	setState(e, "Patrol")
	table.insert(enemies, e)
	byModel[model] = e
	return e
end

-- Weighted pick from { Type = weight }.
function EnemyService.pickType(weights)
	local total = 0
	for _, w in weights do
		total += w
	end
	local roll = rng:NextNumber() * total
	for typeName, w in weights do
		roll -= w
		if roll <= 0 then
			return typeName
		end
	end
	return "Drifter"
end

function EnemyService.clear()
	for _, e in enemies do
		e.dead = true
		e.model:Destroy()
	end
	table.clear(enemies)
	table.clear(byModel)
	table.clear(fireZones)
end

function EnemyService.count()
	return #enemies
end

function EnemyService.fromInstance(instance)
	local model = instance and instance:FindFirstAncestorOfClass("Model")
	while model and not byModel[model] do
		model = model.Parent and model.Parent:FindFirstAncestorOfClass("Model")
	end
	return model and byModel[model] or nil
end

function EnemyService.getAll()
	return enemies
end

function EnemyService.findNear(position, radius)
	local found = {}
	for _, e in enemies do
		if not e.dead then
			local d = (e.root.Position - position).Magnitude
			if d <= radius then
				table.insert(found, { enemy = e, distance = d })
			end
		end
	end
	table.sort(found, function(a, b)
		return a.distance < b.distance
	end)
	return found
end

function EnemyService.stun(e, duration, byPlayer, newState)
	if e.dead then
		return
	end
	e.stunUntil = math.max(e.stunUntil, os.clock() + duration)
	if byPlayer then
		e.suspicion[byPlayer] = math.max(e.suspicion[byPlayer] or 0, 0.6)
		local char = byPlayer.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if root then
			e.investigatePos = root.Position
		end
	end
	if e.state == "Chase" then
		e.target = nil
	end
	setState(e, newState or "Stunned")
	stop(e)
end

function EnemyService.pin(e, duration)
	EnemyService.stun(e, duration, nil, "Pinned")
	local net = Instance.new("Part")
	net.Name = "Net"
	net.Size = Vector3.new(3.4, 7.4, 2.4) * e.cfg.scale
	net.CFrame = e.root.CFrame * CFrame.new(0, -0.6, 0)
	net.Material = Enum.Material.Fabric
	net.Color = Color3.fromRGB(150, 130, 90)
	net.Transparency = 0.55
	net.CanCollide = false
	net.CanQuery = false
	net.Massless = true
	net.Parent = e.model
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = e.root
	weld.Part1 = net
	weld.Parent = net
	e.net = net
end

function EnemyService.canQuiet(e, playerPosition)
	if e.dead or not e.cfg.quietable or e.state == "Chase" or e.state == "Quieted" then
		return false
	end
	if e.state == "Stunned" or e.state == "Pinned" then
		return true
	end
	local toPlayer = Geometry.flat(playerPosition - e.root.Position)
	if toPlayer.Magnitude < 0.01 then
		return true
	end
	return e.root.CFrame.LookVector:Dot(toPlayer.Unit) < -0.2
end

function EnemyService.disperse(e, byPlayer)
	if e.dead then
		return
	end
	e.dead = true
	byModel[e.model] = nil
	local index = table.find(enemies, e)
	if index then
		table.remove(enemies, index)
	end
	e.model:SetAttribute("State", "Dispersed")
	e.model:SetAttribute("HP", 0)
	e.root.Anchored = true
	if e.cfg.human then
		-- people are knocked down, not turned to salt
		e.model:SetAttribute("State", "Down")
		Services.CharacterService.setFlashlight(e.model, false)
		Services.MatchService.onEnemyKilled(byPlayer, e)
		local model = e.model
		task.delay(8, function()
			for _, part in model:GetDescendants() do
				if part:IsA("BasePart") then
					TweenService:Create(part, TweenInfo.new(1.5), { Transparency = 1 }):Play()
				end
			end
			task.wait(1.6)
			model:Destroy()
		end)
		return
	end

	local attachment = Instance.new("Attachment")
	attachment.Position = Vector3.new(0, 0.8, 0)
	attachment.Parent = e.root
	local burst = Instance.new("ParticleEmitter")
	burst.Texture = SMOKE
	burst.Rate = 0
	burst.Lifetime = NumberRange.new(1.4, 2.4)
	burst.Speed = NumberRange.new(3, 8)
	burst.SpreadAngle = Vector2.new(180, 180)
	burst.Drag = 3
	burst.Acceleration = Vector3.new(0, 2.5, 0)
	burst.Color = ColorSequence.new(e.cfg.color)
	burst.LightInfluence = 1
	burst.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1 * e.cfg.scale), NumberSequenceKeypoint.new(1, 4 * e.cfg.scale) })
	burst.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	burst.Parent = attachment
	burst:Emit(70)

	for _, part in e.model:GetDescendants() do
		if part:IsA("BasePart") and part ~= e.root then
			TweenService:Create(part, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Transparency = 1 }):Play()
		elseif part:IsA("ParticleEmitter") and part ~= burst then
			part.Enabled = false
		end
	end
	Sfx.at(e.root.Position, "Quieting", 0.5, 60)
	Services.MatchService.onEnemyKilled(byPlayer, e)
	local model = e.model
	task.delay(2.6, function()
		model:Destroy()
	end)
end

-- Weapon / explosive / fire damage. Returns true if this killed it.
function EnemyService.damage(e, amount, byPlayer, headshot)
	if e.dead or amount <= 0 then
		return false
	end
	e.hp -= amount
	e.model:SetAttribute("HP", math.max(0, e.hp / e.cfg.hp))
	if e.hp <= 0 then
		EnemyService.disperse(e, byPlayer)
		return true
	end
	-- stagger, and being shot always alerts it to the shooter
	local stagger = e.cfg.staggerTime * (headshot and 2 or 1)
	if stagger > 0.05 and e.state ~= "Quieted" then
		e.stunUntil = math.max(e.stunUntil, os.clock() + stagger)
	end
	if byPlayer then
		alertTo(e, byPlayer)
		local char = byPlayer.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if root then
			e.lastKnown = root.Position
			e.investigatePos = root.Position
		end
	end
	return false
end

function EnemyService.explode(position, radius, damage, byPlayer)
	for _, entry in EnemyService.findNear(position, radius) do
		local falloff = 1 - (entry.distance / radius) * 0.6
		local e = entry.enemy
		if not EnemyService.damage(e, damage * falloff, byPlayer, false) then
			EnemyService.stun(e, 2, byPlayer)
		end
	end
end

function EnemyService.addFireZone(position, radius, duration, dps, byPlayer)
	table.insert(fireZones, { position = position, radius = radius, untilTime = os.clock() + duration, dps = dps, player = byPlayer })
end

-- Tell hunters roughly where the players are.
function EnemyService.huntPulse(active)
	if #active == 0 then
		return
	end
	for _, e in enemies do
		if e.hunt and not e.dead and e.state ~= "Chase" then
			local info = active[rng:NextInteger(1, #active)]
			e.investigatePos = info.root.Position + Vector3.new(rng:NextNumber(-10, 10), 0, rng:NextNumber(-10, 10))
		end
	end
end

function EnemyService.onNoise(event)
	for _, e in enemies do
		if not e.dead and e.state ~= "Chase" and e.state ~= "Quieted" and os.clock() >= e.stunUntil then
			local eyes = e.head.Position
			local dist = (event.position - eyes).Magnitude
			local radius = event.radius * (e.cfg.hearingMult or 1)
			if dist <= radius then
				local hit = Workspace:Raycast(eyes, event.position - eyes, occlusionParams)
				if hit and (hit.Position - event.position).Magnitude > 3 then
					radius *= 0.5
				end
				if dist <= radius then
					local loud = 1 - dist / radius
					if event.player then
						local footstep = event.kind == "footstep"
						local add = (footstep and 0.08 or 0.3) + loud * (footstep and 0.3 or 0.6)
						if event.kind == "gunshot" or event.kind == "hum" then
							add += 0.5
						end
						e.suspicion[event.player] = math.min(1.2, (e.suspicion[event.player] or 0) + add)
					end
					e.investigatePos = event.position
					e.heardAt = os.clock()
					if loud > 0.15 and event.kind ~= "footstep" then
						e.model:SetAttribute("Heard", Workspace:GetServerTimeNow()) -- clients show a "?" and turn the head
					end
				end
			end
		end
	end
end

local function tickFire(dt, now)
	for i = #fireZones, 1, -1 do
		local zone = fireZones[i]
		if now > zone.untilTime then
			table.remove(fireZones, i)
		else
			for _, entry in EnemyService.findNear(zone.position, zone.radius) do
				EnemyService.damage(entry.enemy, zone.dps * dt, zone.player, false)
			end
		end
	end
end

function EnemyService.init(registry)
	Services = registry
end

function EnemyService.start()
	folder = Instance.new("Folder")
	folder.Name = "Enemies"
	folder.Parent = Workspace
	occlusionParams.FilterDescendantsInstances = { folder }
	Services.PerceptionService.setEnemyFolder(folder)

	local step = 1 / EnemyConfig.TickRate
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < step then
			return
		end
		accumulator = 0
		if Services.MatchService.state ~= "Encounter" then
			return
		end
		local now = os.clock()
		local active = Services.MatchService.getActivePlayers()
		tickFire(step, now)
		for i = #enemies, 1, -1 do
			local e = enemies[i]
			if e and not e.dead then
				local ok, err = pcall(update, e, step, now, active)
				if not ok then
					warn("[EnemyService] brain error: " .. tostring(err))
				end
			end
		end
	end)
end

return EnemyService
