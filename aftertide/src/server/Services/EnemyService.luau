--!nonstrict
-- The Hushed (Slice 0: Drifters). Server-simulated, one state machine per enemy:
--   Patrol -> (notice) -> Investigate -> Search -> Patrol
--   any    -> (suspicion >= 1) -> Chase -> (lost sight) -> Search
--   Stunned / Pinned / Quieted are timed overrides.
-- Per-player suspicion is published as model attributes "Sus_<UserId>" so each client can draw
-- its own detection indicators. "State" and "Target" (UserId) are published too.
local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local EnemyConfig = require(Shared.Config.Enemies)
local Geometry = require(Shared.Util.Geometry)
local Sfx = require(Shared.Util.Sfx)

local EnemyService = {}
local Services

local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SALT = Color3.fromRGB(206, 201, 189)

local folder
local enemies = {} -- array of enemy records
local byModel = {} -- [Model] = record
local rng = Random.new()
local occlusionParams = RaycastParams.new()
occlusionParams.FilterType = Enum.RaycastFilterType.Exclude

-- Model -----------------------------------------------------------------------------------

local function buildModel(position)
	local model = Instance.new("Model")
	model.Name = "Hushed"

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Transparency = 1
	root.CanCollide = true
	root.CFrame = CFrame.new(position + Vector3.new(0, 4, 0))
	root.Parent = model
	model.PrimaryPart = root

	local function limb(name, size, offset, color)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Color = color or SALT
		p.Material = Enum.Material.Sand
		p.CanCollide = false
		p.CanTouch = false
		p.Massless = true
		p.CFrame = root.CFrame * offset
		p.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = p
		weld.Parent = p
		return p
	end

	local torso = limb("Torso", Vector3.new(1.7, 2.4, 0.9), CFrame.new(0, 0.7, 0) * CFrame.Angles(math.rad(-8), 0, 0))
	local head = limb("Head", Vector3.new(1.1, 1.45, 1.1), CFrame.new(0, 2.5, -0.3) * CFrame.Angles(math.rad(-18), 0, 0), Color3.fromRGB(222, 218, 207))
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = head
	limb("LeftArm", Vector3.new(0.45, 3.1, 0.45), CFrame.new(-1.12, 0.1, -0.15) * CFrame.Angles(math.rad(10), 0, math.rad(-4)))
	limb("RightArm", Vector3.new(0.45, 3.1, 0.45), CFrame.new(1.12, 0.1, -0.15) * CFrame.Angles(math.rad(10), 0, math.rad(4)))
	limb("LeftLeg", Vector3.new(0.6, 3, 0.6), CFrame.new(-0.45, -2.5, 0))
	limb("RightLeg", Vector3.new(0.6, 3, 0.6), CFrame.new(0.45, -2.5, 0))

	-- faint salt drifting off them: their visual signature
	local drift = Instance.new("ParticleEmitter")
	drift.Rate = 4
	drift.Lifetime = NumberRange.new(2, 3)
	drift.Speed = NumberRange.new(0.4, 1.2)
	drift.SpreadAngle = Vector2.new(180, 180)
	drift.Acceleration = Vector3.new(0, 0.8, 0)
	drift.Color = ColorSequence.new(SALT)
	drift.LightInfluence = 1
	drift.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.12), NumberSequenceKeypoint.new(1, 0) })
	drift.Parent = torso

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15 -- R15 so HipHeight (not leg parts) sets floor height
	humanoid.HipHeight = 3
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.WalkSpeed = 5
	humanoid.UseJumpPower = true
	humanoid.JumpPower = 0
	humanoid.AutoJumpEnabled = false
	humanoid.RequiresNeck = false
	humanoid.BreakJointsOnDeath = false
	humanoid.Parent = model
	for _, state in {
		Enum.HumanoidStateType.Climbing,
		Enum.HumanoidStateType.FallingDown,
		Enum.HumanoidStateType.Ragdoll,
		Enum.HumanoidStateType.Seated,
		Enum.HumanoidStateType.Jumping,
	} do
		humanoid:SetStateEnabled(state, false)
	end

	return model, humanoid, root, head
end

-- Helpers ---------------------------------------------------------------------------------

local function setState(e, state)
	if e.state == state then
		return
	end
	e.state = state
	e.stateTime = os.clock()
	e.waypoints = nil
	e.pathGoal = nil
	e.searchPoint = nil
	e.model:SetAttribute("State", state)
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

-- Walks toward `goal` using pathfinding. Returns true on arrival.
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
			e.pathGoal = nil -- stuck: force a re-path next tick
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

-- Brain -----------------------------------------------------------------------------------

local function update(e, dt, now, active)
	local cfg = e.cfg

	if now < e.stunUntil then
		stop(e)
		publishSuspicion(e, active)
		return
	elseif e.state == "Stunned" or e.state == "Pinned" then
		e.net = e.net and e.net:Destroy()
		setState(e, e.investigatePos and "Investigate" or "Search")
		e.searchOrigin = e.root.Position
	end

	-- perception
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
		setState(e, "Chase")
		Services.MatchService.onSpotted(bestPlayer, e)
	end

	if e.state == "Chase" then
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
			if dist <= cfg.grabRange and now >= e.recoverUntil then
				e.recoverUntil = now + cfg.grabRecover
				Services.CharacterService.damage(info.player, cfg.grabDamage, e.root.Position)
			end
			if now < e.recoverUntil - cfg.grabRecover + 0.9 then
				stop(e) -- brief stagger after a grab so you can break away
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
			-- something's there: stop and stare before committing
			stop(e)
			face(e, findInfo(active, bestPlayer).root.Position)
		elseif moveTo(e, e.investigatePos, cfg.investigateSpeed) then
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
	else -- Patrol
		if bestPlayer and bestSus >= cfg.noticeThreshold then
			stop(e)
			face(e, findInfo(active, bestPlayer).root.Position)
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

function EnemyService.spawnWave(count, routes)
	for i = 1, count do
		local route = routes[(i - 1) % #routes + 1]
		local startIndex = rng:NextInteger(1, #route)
		local spawnAt = route[startIndex] + Vector3.new(rng:NextNumber(-3, 3), 0, rng:NextNumber(-3, 3))
		local model, humanoid, root, head = buildModel(spawnAt)
		model.Parent = folder
		pcall(function()
			root:SetNetworkOwner(nil)
		end)
		local cfg = EnemyConfig.Drifter
		local e = {
			model = model,
			humanoid = humanoid,
			root = root,
			head = head,
			cfg = cfg,
			fovCos = math.cos(math.rad(cfg.fovDeg / 2)),
			route = route,
			routeIndex = startIndex % #route + 1,
			path = PathfindingService:CreatePath({
				AgentRadius = 2,
				AgentHeight = 7,
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
	end
end

function EnemyService.clear()
	for _, e in enemies do
		e.dead = true
		e.model:Destroy()
	end
	table.clear(enemies)
	table.clear(byModel)
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

-- Living enemies within radius of position, nearest first.
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

function EnemyService.stun(e, duration, byPlayer, state)
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
	setState(e, state or "Stunned")
	stop(e)
end

function EnemyService.pin(e, duration)
	EnemyService.stun(e, duration, nil, "Pinned")
	local net = Instance.new("Part")
	net.Name = "Net"
	net.Size = Vector3.new(3.4, 7.4, 2.4)
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

-- True if a Quieting is allowed: from behind and unaware, or any side while stunned/pinned.
function EnemyService.canQuiet(e, playerPosition)
	if e.dead or e.state == "Chase" or e.state == "Quieted" then
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

function EnemyService.disperse(e)
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
	e.root.Anchored = true

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
	burst.Color = ColorSequence.new(SALT)
	burst.LightInfluence = 1
	burst.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 4) })
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
	local model = e.model
	task.delay(2.6, function()
		model:Destroy()
	end)
end

-- Called by PerceptionService for every noise event.
function EnemyService.onNoise(event)
	for _, e in enemies do
		if not e.dead and e.state ~= "Chase" and e.state ~= "Quieted" and os.clock() >= e.stunUntil then
			local eyes = e.head.Position
			local dist = (event.position - eyes).Magnitude
			local radius = event.radius
			if dist <= radius then
				local hit = Workspace:Raycast(eyes, event.position - eyes, occlusionParams)
				if hit and (hit.Position - event.position).Magnitude > 3 then
					radius *= 0.5 -- muffled through walls
				end
				if dist <= radius then
					local loud = 1 - dist / radius
					if event.player then
						local footstep = event.kind == "footstep"
						local add = (footstep and 0.08 or 0.3) + loud * (footstep and 0.3 or 0.6)
						e.suspicion[event.player] = math.min(1.2, (e.suspicion[event.player] or 0) + add)
					end
					e.investigatePos = event.position
				end
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
