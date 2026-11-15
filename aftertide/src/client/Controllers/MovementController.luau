--!nonstrict
-- Stances, speed states with acceleration, wading, aim-facing (strafe while aiming), and the
-- dodge / sprint-dive movement. Poses are drawn by PlayerAnimator.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Movement = require(Shared.Config.Movement)
local Stats = require(Shared.Stats)
local Net = require(Shared.Net)
local Geometry = require(Shared.Util.Geometry)
local Sfx = require(Shared.Util.Sfx)
local State = require(script.Parent.Parent.State)

local MovementController = {}
local Controllers

local player = Players.LocalPlayer
local currentSpeed = 0
local stillTime = 0
local lastSent = ""
local lastLookSent, lastLookAt = 0, 0
local dodgeReadyAt = 0
local sprintTime = 0

local function send()
	local stance = State.prone and "Prone" or (State.crouched and "Crouch" or "Stand")
	local key = stance .. tostring(State.sprinting) .. tostring(State.aiming)
	if key ~= lastSent then
		lastSent = key
		Net.event("SetMoveState"):FireServer(stance, State.sprinting, State.aiming)
	end
end

function MovementController.setProne(on)
	if State.downed then
		return
	end
	State.prone = on
	if on then
		State.crouched = false
		State.sprinting = false
	end
	send()
end

function MovementController.toggleCrouch()
	if State.downed then
		return
	end
	if State.prone then -- tap from prone: up to a crouch
		State.prone = false
		State.crouched = true
		send()
		return
	end
	State.crouched = not State.crouched
	if State.crouched then
		State.sprinting = false
	end
	send()
end

function MovementController.setSprint(on, toggled)
	if State.downed then
		return
	end
	State.sprinting = on
	State.sprintToggled = on and toggled == true
	if on then
		State.crouched = false
		State.prone = false
	end
	send()
end

function MovementController.setAim(on)
	local was = State.aiming
	State.aiming = on and not State.downed
	if State.aiming and not was then
		State.aimSince = os.clock()
	end
	if State.aiming then
		State.sprinting = false
	end
	send()
end

-- Quick sidestep in the move direction (backstep if standing still); a dive when sprinting.
function MovementController.dodge()
	local root, humanoid = State.root, State.humanoid
	if not root or not humanoid or State.downed or State.uiOpen() or State.prone then
		return
	end
	local now = os.clock()
	if now < dodgeReadyAt then
		return
	end
	local dive = State.sprinting
	dodgeReadyAt = now + (dive and 1.3 or 0.85)
	local dir = humanoid.MoveDirection
	if dir.Magnitude < 0.1 then
		dir = -Geometry.flat(root.CFrame.LookVector)
	end
	dir = Geometry.flat(dir).Unit
	Net.event("Action"):FireServer("Dodge", dir)
	Sfx.ui("Dodge", 0.6)

	-- never dash into (and through) a wall: shorten the dodge to the space available
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { State.character }
	local room = Workspace:Raycast(root.Position, dir * 9, params)
	local roomScale = room and math.clamp((room.Distance - 1.5) / 9, 0, 1) or 1
	local attachment = root:FindFirstChild("RootAttachment")
	if attachment and roomScale > 0.1 then
		local lv = Instance.new("LinearVelocity")
		lv.Attachment0 = attachment
		lv.MaxForce = 4e4
		lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
		lv.PrimaryTangentAxis = Vector3.new(1, 0, 0)
		lv.SecondaryTangentAxis = Vector3.new(0, 0, 1)
		lv.RelativeTo = Enum.ActuatorRelativeTo.World
		local speed = (dive and 36 or 30) * roomScale
		lv.PlaneVelocity = Vector2.new(dir.X * speed, dir.Z * speed)
		lv.Parent = root
		task.delay(dive and 0.38 or 0.22, function()
			lv:Destroy()
		end)
	end
	if dive then
		State.sprinting = false
		task.delay(0.5, function()
			State.crouched = true
			send()
		end)
	end
end

-- Jump and vault ---------------------------------------------------------------------------------

local probeParams = RaycastParams.new()
probeParams.FilterType = Enum.RaycastFilterType.Exclude
probeParams.IgnoreWater = true
local jumpReadyAt = 0

-- Looks for something waist- to chest-high in front of you that you can go over, and for open
-- ground beyond it. Returns the vault (start, apex, landing) or nil.
local function probeVault(dir)
	local root, humanoid = State.root, State.humanoid
	local enemies = Workspace:FindFirstChild("Enemies")
	probeParams.FilterDescendantsInstances = { State.character, enemies }
	local feet = root.Position.Y - (root.Size.Y / 2 + humanoid.HipHeight)
	local hit
	for _, h in { 1.2, 2.4 } do -- knee and waist
		local r = Workspace:Raycast(Vector3.new(root.Position.X, feet + h, root.Position.Z), dir * 3.6, probeParams)
		if r and r.Instance.CanCollide and r.Instance.Transparency < 1 then
			hit = r
			break
		end
	end
	if not hit then
		return nil, "no obstacle in front"
	end
	local into = hit.Position + dir * 0.7
	local top = Workspace:Raycast(Vector3.new(into.X, feet + 5.4, into.Z), Vector3.new(0, -5.4, 0), probeParams)
	if not top or top.Normal.Y < 0.6 then
		return nil, "no flat top"
	end
	local h = top.Position.Y - feet
	if h < 1.1 or h > 4.6 then
		return nil, "height " .. tostring(h)
	end
	if Workspace:Raycast(Vector3.new(into.X, top.Position.Y + 0.15, into.Z), Vector3.new(0, 3.4, 0), probeParams) then
		return nil, "no headroom"
	end
	local base = Vector3.new(hit.Position.X, top.Position.Y, hit.Position.Z)
	local lastWhy = "none"
	for d = 1.1, 9, 0.8 do
		local pt = base + dir * d
		local floor = Workspace:Raycast(pt + Vector3.new(0, 3.2, 0), Vector3.new(0, -(h + 9), 0), probeParams)
		if not floor then
			lastWhy = ("d=%.1f: no floor"):format(d)
		elseif not (floor.Position.Y < feet + 0.9 and floor.Normal.Y > 0.7) then
			lastWhy = ("d=%.1f: floor at %.2f (%s) feet %.2f"):format(d, floor.Position.Y, floor.Instance.Name, feet)
		else
			local clear = not Workspace:Raycast(base + Vector3.new(0, 1.4, 0), dir * d, probeParams)
			local room = not Workspace:Raycast(Vector3.new(pt.X, floor.Position.Y + 0.6, pt.Z), Vector3.new(0, 4.2, 0), probeParams)
			if not (clear and room) then
				lastWhy = ("d=%.1f: clear=%s room=%s"):format(d, tostring(clear), tostring(room))
			end
			if clear and room then
				local stand = root.Size.Y / 2 + humanoid.HipHeight
				return { top = top.Position.Y, height = h, dir = dir, target = Vector3.new(pt.X, floor.Position.Y + stand, pt.Z), stand = stand }
			end
		end
	end
	return nil, "no landing: " .. lastWhy
end

local function runVault(v)
	local root, humanoid = State.root, State.humanoid
	State.vaulting = true
	State.sprinting = false
	Net.event("Action"):FireServer("Vault", { target = v.target })
	if Sfx.has("Vault") then
		Sfx.at(root.Position, "Vault", 0.8, 60, 0.05)
	end
	local start = root.Position
	local rest = Geometry.flat(v.dir)
	local apexY = math.max(start.Y, v.top + v.stand + 0.5)
	local control = (start + v.target) / 2
	control = Vector3.new(control.X, 2 * apexY - (start.Y + v.target.Y) / 2, control.Z)
	local duration = 0.42 + 0.06 * v.height + 0.025 * (v.target - start).Magnitude
	local t0 = os.clock()
	root.Anchored = true
	local conn
	local function finish()
		if conn then
			conn:Disconnect()
			conn = nil
		end
		if root.Parent then
			root.Anchored = false
			root.AssemblyLinearVelocity = rest * 7
		end
		State.vaulting = false
	end
	conn = RunService.RenderStepped:Connect(function()
		if not root.Parent or State.downed then
			finish()
			return
		end
		local k = math.clamp((os.clock() - t0) / duration, 0, 1)
		local e = k * k * (3 - 2 * k)
		local pos = start * (1 - e) ^ 2 + control * (2 * (1 - e) * e) + v.target * (e * e)
		root.CFrame = CFrame.lookAt(pos, pos + rest)
		root.AssemblyLinearVelocity = Vector3.zero
		if k >= 1 then
			finish()
		end
	end)
	task.delay(duration + 0.5, finish) -- never stay frozen
end

-- Test hook: what would a vault from the current character in direction `dir` do? (engine tests)
function MovementController.debugProbe(dir)
	local v, why = probeVault(Geometry.flat(dir).Unit)
	if not v then
		return { fail = why }
	end
	return { top = v.top, height = v.height, target = { v.target.X, v.target.Y, v.target.Z } }
end

-- Space / A: vault whatever is in front of you if you can; otherwise a short hop.
function MovementController.jumpOrVault()
	local root, humanoid = State.root, State.humanoid
	if not root or not humanoid or State.downed or State.uiOpen() or State.vaulting or State.prone or State.listening then
		return
	end
	local now = os.clock()
	if now < jumpReadyAt then
		return
	end
	local dir = humanoid.MoveDirection
	if dir.Magnitude < 0.1 then
		dir = root.CFrame.LookVector
	end
	dir = Geometry.flat(dir).Unit
	local v = probeVault(dir)
	if v then
		jumpReadyAt = now + 0.9
		if State.crouched then
			State.crouched = false
			send()
		end
		runVault(v)
		return
	end
	if State.aiming or humanoid.FloorMaterial == Enum.Material.Air then
		return
	end
	jumpReadyAt = now + 0.75
	if State.crouched then
		State.crouched = false
		send()
	end
	humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	Net.event("Action"):FireServer("Jump")
	if Sfx.has("Jump") then
		Sfx.at(root.Position, "Jump", 0.6, 50, 0.08)
	end
end

function MovementController.onCharacter()
	currentSpeed = 0
	lastSent = ""
	send()
end

local cachedMods, cachedKey = nil, nil
local function getMods()
	local key = tostring(player:GetAttribute("CharId")) .. tostring(player:GetAttribute("PerkId"))
	if key ~= cachedKey then
		cachedKey = key
		cachedMods = Stats.compute(player:GetAttribute("CharId"), player:GetAttribute("PerkId"))
	end
	return cachedMods
end

local function step(dt)
	local char, humanoid, root = State.character, State.humanoid, State.root
	if not char or not humanoid or not root or not root.Parent then
		return
	end
	local wasDowned = State.downed
	State.downed = char:GetAttribute("Downed") == true or char:GetAttribute("Out") == true
	if State.downed and not wasDowned then
		State.aiming, State.sprinting, State.crouched, State.prone = false, false, false, false
		send()
	end

	-- landing: the dip, the thud, and the noise other things can hear
	local airborne = humanoid.FloorMaterial == Enum.Material.Air
	if airborne then
		State.fallSpeed = math.max(State.fallSpeed or 0, -root.AssemblyLinearVelocity.Y)
	elseif State.wasAirborne then
		local fs = State.fallSpeed or 0
		if fs > 14 and not State.vaulting then
			State.landKick = math.clamp((fs - 10) * 0.012, 0.05, 0.4)
			if Sfx.has("Land") then
				Sfx.at(root.Position - Vector3.new(0, 2.5, 0), "Land", math.clamp(fs / 40, 0.3, 1), 70, 0.1)
			else
				Sfx.at(root.Position - Vector3.new(0, 2.5, 0), "Step", math.clamp(fs / 30, 0.4, 1), 70, 0.2)
			end
			Net.event("Action"):FireServer("Land", fs)
		end
		State.fallSpeed = 0
	end
	State.wasAirborne = airborne

	local busy = (char:GetAttribute("BusyUntil") or 0) > Workspace:GetServerTimeNow()
	local moving = humanoid.MoveDirection.Magnitude > 0.05
	local S = Movement.Speeds
	local target
	if char:GetAttribute("Out") then
		target = 0
	elseif State.downed then
		target = S.Downed
	elseif State.vaulting then
		target = 0
	elseif busy then
		target = 1.5
	elseif char:GetAttribute("Grabbing") then
		target = 5 -- dragging someone
	elseif State.listening then
		target = S.Crouch * 0.7 -- listening: you creep (and you can't shoot)
	elseif State.prone then
		target = State.aiming and S.Prone * 0.5 or S.Prone
	elseif State.aiming then
		target = State.crouched and S.Crouch * 0.8 or S.Aim
	elseif State.crouched then
		target = S.Crouch
	elseif State.sprinting then
		target = S.Sprint * getMods().sprintSpeedMult
	else
		target = S.Jog
	end
	if Geometry.inTagged(root.Position, "Shallows") then
		target *= Movement.WaterSpeedMult
	end
	if not moving then
		currentSpeed = math.min(currentSpeed, 4)
	end
	if target > currentSpeed then
		currentSpeed = math.min(target, currentSpeed + Movement.Accel * dt)
	else
		currentSpeed = math.max(target, currentSpeed - Movement.Decel * dt)
	end
	humanoid.WalkSpeed = currentSpeed

	-- aiming: the body faces the camera so you strafe around your target
	if (State.aiming or State.firstPerson or State.listening) and not State.downed and not State.vaulting then
		humanoid.AutoRotate = false
		local yaw = Controllers.CameraController.getYaw()
		local _, current = root.CFrame:ToEulerAnglesYXZ()
		local diff = (yaw - current + math.pi) % (2 * math.pi) - math.pi
		root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, current + diff * math.min(1, dt * 18), 0)
	else
		humanoid.AutoRotate = true
	end

	-- out of breath after a long sprint
	if State.sprinting then
		sprintTime += dt
	else
		if sprintTime > 4 and Sfx.has("Breath_Heavy") then
			Sfx.ui("Breath_Heavy", 0.45)
		end
		sprintTime = 0
	end

	stillTime = moving and 0 or stillTime + dt
	if State.sprinting and State.sprintToggled and stillTime > 0.6 then
		State.sprinting = false
		State.sprintToggled = false
		send()
	end

	-- replicate aim pitch for other players' upper-body pose
	if State.aiming then
		local now = os.clock()
		if now - lastLookAt > 0.12 and math.abs(State.pitch - lastLookSent) > 0.04 then
			lastLookAt = now
			lastLookSent = State.pitch
			Net.event("Look"):FireServer(State.pitch)
		end
	end
end

function MovementController.init(registry)
	Controllers = registry
end

function MovementController.start()
	RunService:BindToRenderStep("AftertideMovement", Enum.RenderPriority.Input.Value + 1, step)
end

return MovementController
