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

	local attachment = root:FindFirstChild("RootAttachment")
	if attachment then
		local lv = Instance.new("LinearVelocity")
		lv.Attachment0 = attachment
		lv.MaxForce = 1e6
		lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
		lv.PrimaryTangentAxis = Vector3.new(1, 0, 0)
		lv.SecondaryTangentAxis = Vector3.new(0, 0, 1)
		lv.RelativeTo = Enum.ActuatorRelativeTo.World
		local speed = dive and 36 or 30
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

	local busy = (char:GetAttribute("BusyUntil") or 0) > Workspace:GetServerTimeNow()
	local moving = humanoid.MoveDirection.Magnitude > 0.05
	local S = Movement.Speeds
	local target
	if char:GetAttribute("Out") then
		target = 0
	elseif State.downed then
		target = S.Downed
	elseif busy then
		target = 1.5
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
	if State.aiming and not State.downed then
		humanoid.AutoRotate = false
		local yaw = Controllers.CameraController.getYaw()
		local _, current = root.CFrame:ToEulerAnglesYXZ()
		local diff = (yaw - current + math.pi) % (2 * math.pi) - math.pi
		root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, current + diff * math.min(1, dt * 18), 0)
	else
		humanoid.AutoRotate = true
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
