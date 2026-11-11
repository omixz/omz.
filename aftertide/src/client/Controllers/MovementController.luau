--!nonstrict
-- Stances and speed states with acceleration ramps, wading, aim-facing, and a procedural
-- crouch/downed pose applied to every character (from their replicated attributes).
-- Stage 5 replaces the procedural pose with authored crouch locomotion animations.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Movement = require(Shared.Config.Movement)
local Stats = require(Shared.Stats)
local Net = require(Shared.Net)
local Geometry = require(Shared.Util.Geometry)
local State = require(script.Parent.Parent.State)

local MovementController = {}
local Controllers

local player = Players.LocalPlayer
local currentSpeed = 0
local stillTime = 0
local lastSent = ""
local poseAlpha = setmetatable({}, { __mode = "k" })
local aimAlpha = setmetatable({}, { __mode = "k" })
local readyAlpha = setmetatable({}, { __mode = "k" })
local lastLookSent, lastLookAt = 0, 0

local function send()
	local stance = State.crouched and "Crouch" or "Stand"
	local key = stance .. tostring(State.sprinting) .. tostring(State.aiming)
	if key ~= lastSent then
		lastSent = key
		Net.event("SetMoveState"):FireServer(stance, State.sprinting, State.aiming)
	end
end

function MovementController.toggleCrouch()
	if State.downed then
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
	end
	send()
end

function MovementController.setAim(on)
	State.aiming = on and not State.downed
	if State.aiming then
		State.sprinting = false
	end
	send()
end

function MovementController.onCharacter()
	currentSpeed = 0
	lastSent = ""
	send()
end

local function mods()
	return Stats.compute(player:GetAttribute("CharId"), player:GetAttribute("PerkId"))
end

local cachedMods, cachedKey = nil, nil
local function getMods()
	local key = tostring(player:GetAttribute("CharId")) .. tostring(player:GetAttribute("PerkId"))
	if key ~= cachedKey then
		cachedKey = key
		cachedMods = mods()
	end
	return cachedMods
end

local function stepLocal(dt)
	local char, humanoid, root = State.character, State.humanoid, State.root
	if not char or not humanoid or not root or not root.Parent then
		return
	end
	local wasDowned = State.downed
	State.downed = char:GetAttribute("Downed") == true or char:GetAttribute("Out") == true
	if State.downed and not wasDowned then
		State.aiming, State.sprinting, State.crouched = false, false, false
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
		target = 0
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
		currentSpeed = math.min(currentSpeed, 4) -- next start ramps up again
	end
	if target > currentSpeed then
		currentSpeed = math.min(target, currentSpeed + Movement.Accel * dt)
	else
		currentSpeed = math.max(target, currentSpeed - Movement.Decel * dt)
	end
	humanoid.WalkSpeed = currentSpeed

	if State.aiming and not State.downed then
		humanoid.AutoRotate = false
		root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, Controllers.CameraController.getYaw(), 0)
	else
		humanoid.AutoRotate = true
	end
	stillTime = moving and 0 or stillTime + dt
	if State.sprinting and State.sprintToggled and stillTime > 0.6 then
		-- releasing the stick ends a toggled sprint (gamepad / touch)
		State.sprinting = false
		State.sprintToggled = false
		send()
	end
end

local function joint(char, partName, jointName)
	local part = char:FindFirstChild(partName)
	return part and part:FindFirstChild(jointName)
end

local function bend(motor, angle)
	if motor and motor:IsA("Motor6D") then
		motor.Transform = motor.Transform * CFrame.Angles(angle, 0, 0)
	end
end

local function applyPose(char, alpha)
	local legs = math.min(alpha, 1)
	bend(joint(char, "UpperTorso", "Waist"), -0.45 * alpha)
	bend(joint(char, "LeftUpperLeg", "LeftHip"), 1.15 * legs)
	bend(joint(char, "RightUpperLeg", "RightHip"), 1.15 * legs)
	bend(joint(char, "LeftLowerLeg", "LeftKnee"), -1.7 * legs)
	bend(joint(char, "RightLowerLeg", "RightKnee"), -1.7 * legs)
end

local function rotate(motor, cf)
	if motor and motor:IsA("Motor6D") then
		motor.Transform = motor.Transform * cf
	end
end

-- Holding / aiming a weapon: both hands on the gun, upper body follows aim pitch.
local function applyArms(char, aimAlpha, readyAlpha, pitchValue, longGun)
	local a, r = aimAlpha, readyAlpha * (1 - aimAlpha)
	local p = pitchValue * aimAlpha
	rotate(joint(char, "UpperTorso", "Waist"), CFrame.Angles(p * 0.45, 0, 0))
	rotate(joint(char, "RightUpperArm", "RightShoulder"), CFrame.Angles(1.55 * a + 0.55 * r + p * 0.5, 0, 0))
	rotate(joint(char, "RightLowerArm", "RightElbow"), CFrame.Angles(0.15 * a + 0.9 * r, 0, 0))
	if longGun or a > 0 then
		rotate(joint(char, "LeftUpperArm", "LeftShoulder"), CFrame.Angles(1.4 * a + 0.5 * r + p * 0.5, 0, (longGun and 0.55 or 0.75) * (a + r)))
		rotate(joint(char, "LeftLowerArm", "LeftElbow"), CFrame.Angles((longGun and 0.55 or 0.35) * a + 0.9 * r, 0, 0))
	end
end

local function stepPoses(_, dt)
	for _, p in Players:GetPlayers() do
		local char = p.Character
		if char then
			local goal
			if p == player then
				goal = State.downed and 1.25 or (State.crouched and 1 or 0)
			else
				goal = char:GetAttribute("Downed") and 1.25 or (char:GetAttribute("Stance") == "Crouch" and 1 or 0)
			end
			local a = poseAlpha[char] or 0
			a += (goal - a) * math.min(1, dt * 10)
			poseAlpha[char] = a
			if a > 0.01 then
				applyPose(char, a)
			end
			-- weapon pose
			local equipped = char:GetAttribute("Equipped")
			local armed = equipped ~= nil and equipped ~= "" and not char:GetAttribute("Downed")
			local aiming = armed and (p == player and State.aiming or (p ~= player and char:GetAttribute("Aim") == true))
			local ai = aimAlpha[char] or 0
			ai += ((aiming and 1 or 0) - ai) * math.min(1, dt * 14)
			aimAlpha[char] = ai
			local ri = readyAlpha[char] or 0
			ri += ((armed and 1 or 0) - ri) * math.min(1, dt * 10)
			readyAlpha[char] = ri
			if ai > 0.01 or ri > 0.01 then
				local pitchValue = p == player and State.pitch or (char:GetAttribute("AimPitch") or 0)
				applyArms(char, ai, ri, pitchValue, char:GetAttribute("EquippedSlot") == "long")
			end
			if p == player and State.humanoid then
				local legs = math.min(a, 1)
				State.humanoid.HipHeight = State.baseHipHeight * (1 - (1 - Movement.CrouchHipMult) * legs)
			end
		end
	end
end

function MovementController.init(registry)
	Controllers = registry
end

local function sendLook()
	if not State.aiming then
		return
	end
	local now = os.clock()
	if now - lastLookAt > 0.12 and math.abs(State.pitch - lastLookSent) > 0.04 then
		lastLookAt = now
		lastLookSent = State.pitch
		Net.event("Look"):FireServer(State.pitch)
	end
end

function MovementController.start()
	RunService.Heartbeat:Connect(sendLook)
	RunService:BindToRenderStep("AftertideMovement", Enum.RenderPriority.Input.Value + 1, stepLocal)
	RunService.Stepped:Connect(stepPoses)
end

return MovementController
