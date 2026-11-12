--!nonstrict
-- Over-the-shoulder camera: spring-smoothed focus and offset, spherecast collision that snaps
-- in and eases out, per-state framing (explore / crouch / sprint / aim / takedown), shoulder
-- swap, and mouse / gamepad / touch look.
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Game = require(Shared.Config.Game)
local Spring = require(Shared.Util.Spring)
local State = require(script.Parent.Parent.State)

local CameraController = {}
local Controllers
local player = Players.LocalPlayer
local recoilYaw = 0
local recoilPitch = 0 -- temporary kick that springs back (most of it)
local fovPunch = 0

local SENS_MOUSE = 0.0028
local SENS_PAD = 3.0
local SENS_TOUCH = 0.0065
local PITCH_MIN, PITCH_MAX = -1.2, 0.95

local yaw, pitch = 0, -0.12
local padLook = Vector2.zero
local touchInput, lastTouchPos = nil, nil

local focusSpring = Spring.new(Vector3.zero, 7)
local offsetSpring = Spring.new(Vector3.new(1.7, 0.5, 6.2), 5)
local fovSpring = Spring.new(70, 4)
local currentDist = 6
local needsSnap = true
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
local aimParams = RaycastParams.new()
aimParams.FilterType = Enum.RaycastFilterType.Exclude

function CameraController.getYaw()
	return yaw
end

function CameraController.getPitch()
	return pitch
end

-- Recoil: the view climbs (you pull it back down), with a little sideways jitter.
local breath = { holding = false, since = 0, spentUntil = 0 }
local BREATH_HOLD = 4 -- seconds of steady aim before you have to breathe

-- Hold breath while aiming (sprint key): sway stops for a few seconds, then you gasp.
function CameraController.holdBreath(on)
	local now = os.clock()
	if on and State.aiming and now >= breath.spentUntil then
		breath.holding, breath.since = true, now
	elseif not on and breath.holding then
		breath.holding = false
		breath.spentUntil = now + 1
	end
end

function CameraController.isHoldingBreath()
	return breath.holding
end

-- Recoil: the view climbs (you pull it back down); `side` is the gun's pattern step.
function CameraController.kick(degrees, side)
	recoilPitch += math.rad(degrees) * 0.6
	pitch += math.rad(degrees) * 0.08 -- a little permanent climb to manage
	recoilYaw += math.rad(degrees) * ((side or 0) * 0.45 + (math.random() - 0.5) * 0.08)
	fovPunch = math.min(fovPunch + degrees * 0.35, 4)
end

local function sensitivity()
	return player:GetAttribute("Set_sensitivity") or 1
end

-- Direction from the character's head toward whatever is under the screen centre.
function CameraController.aimDirection()
	local camera = Workspace.CurrentCamera
	local origin = camera.CFrame.Position
	local look = camera.CFrame.LookVector * 250
	-- enemies must stop this ray: the shot leaves from the head, not the camera, so aiming
	-- at the wall behind a target would send the bullet past it
	local hit = Workspace:Raycast(origin, look, aimParams)
	local point = hit and hit.Position or origin + look
	local head = State.character and State.character:FindFirstChild("Head")
	local from = head and head.Position or origin
	local dir = point - from
	if dir.Magnitude < 0.5 then
		return camera.CFrame.LookVector
	end
	return dir.Unit
end

function CameraController.onCharacter(char)
	needsSnap = true
	local root = char:WaitForChild("HumanoidRootPart")
	local _, ry = root.CFrame:ToEulerAnglesYXZ()
	yaw = ry
	pitch = -0.12
end

local function refreshFilter()
	local list = {}
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(list, p.Character)
		end
	end
	aimParams.FilterDescendantsInstances = table.clone(list)
	local enemies = Workspace:FindFirstChild("Enemies")
	if enemies then
		table.insert(list, enemies)
	end
	params.FilterDescendantsInstances = list
end

local function update(dt)
	local camera = Workspace.CurrentCamera
	if camera.CameraType ~= Enum.CameraType.Scriptable then
		camera.CameraType = Enum.CameraType.Scriptable
	end

	local root = State.root
	if not root or not root.Parent then
		-- No character yet (choosing crew): a slow establishing shot of the Meridian.
		local o = Game.FerryOrigin
		local t = os.clock() * 0.05
		camera.CFrame = CFrame.lookAt(o + Vector3.new(math.cos(t) * 55, 16, math.sin(t) * 55), o + Vector3.new(0, 4, 0))
		camera.FieldOfView = 60
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
		return
	end

	local uiOpen = State.uiOpen()
	if uiOpen then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
	elseif not UserInputService.TouchEnabled or UserInputService.MouseEnabled then
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		UserInputService.MouseIconEnabled = false
	end

	if padLook.Magnitude > 0.15 then
		local aimSlow = State.aiming and 0.55 or 1
		yaw -= padLook.X * SENS_PAD * dt * sensitivity() * aimSlow
		pitch += padLook.Y * SENS_PAD * 0.7 * dt * sensitivity() * aimSlow
	end
	if recoilYaw ~= 0 then
		local step = recoilYaw * math.min(1, dt * 12)
		yaw += step
		recoilYaw -= step
	end
	recoilPitch -= recoilPitch * math.min(1, dt * 9)
	fovPunch -= fovPunch * math.min(1, dt * 10)
	pitch = math.clamp(pitch, PITCH_MIN, PITCH_MAX)
	State.pitch = pitch

	local takedown = os.clock() < State.takedownUntil
	local s = State.shoulder
	local height, offset, fov
	-- over-the-shoulder framing: character on the left third, tight when aiming
	if State.downed then
		height, offset, fov = 0.9, Vector3.new(1.4 * s, 1.3, 6.5), 64
	elseif takedown then
		height, offset, fov = 1.8, Vector3.new(2.3 * s, 0.1, 4.0), 56
	elseif State.aiming then
		local weaponFov = Controllers and Controllers.WeaponController.aimFov()
		local scoped = weaponFov and weaponFov < 40
		height, offset, fov = State.crouched and 1.45 or 2.25, Vector3.new(2.05 * s, 0.35, scoped and 1.9 or 2.7), weaponFov or 50
	elseif State.sprinting then
		height, offset, fov = 2.2, Vector3.new(1.5 * s, 0.55, 6.6), 74
	elseif State.crouched then
		height, offset, fov = 1.35, Vector3.new(1.95 * s, 0.6, 4.9), 64
	else
		height, offset, fov = 2.3, Vector3.new(1.95 * s, 0.5, 5.6), 66
	end

	local focusTarget = root.Position + Vector3.new(0, height, 0)
	if needsSnap or (focusSpring.position - focusTarget).Magnitude > 40 then
		focusSpring:reset(focusTarget)
		offsetSpring:reset(offset)
		currentDist = offset.Magnitude
		needsSnap = false
		refreshFilter()
	end
	focusSpring.target = focusTarget
	offsetSpring.target = offset
	fovSpring.target = fov
	fovSpring.frequency = State.aiming and 14 or 6 -- snap into the sights, ease back out
	local focus = focusSpring:update(dt)
	local off = offsetSpring:update(dt)
	camera.FieldOfView = fovSpring:update(dt) + fovPunch

	-- subtle breathing sway (scaled down while aiming)
	local t = os.clock()
	local reduce = player:GetAttribute("Set_reduceMotion") == true
	local sway = reduce and 0 or 0.006
	local aimSway = 0
	if State.aiming and not reduce then
		-- breathing sway: steadier crouched, worse while moving
		local v = State.root.AssemblyLinearVelocity
		local moving = math.clamp(Vector3.new(v.X, 0, v.Z).Magnitude / 8, 0, 1)
		aimSway = (State.crouched and 0.0018 or 0.003) * (1 + moving * 1.5)
		if breath.holding then
			if os.clock() - breath.since > BREATH_HOLD then
				breath.holding = false
				breath.spentUntil = os.clock() + 2.5 -- out of breath: shaky for a moment
			else
				aimSway *= 0.08
			end
		elseif os.clock() < breath.spentUntil then
			aimSway *= 2.2
		end
	elseif breath.holding then
		breath.holding = false
	end
	State.breath = breath.holding and "hold" or (os.clock() < breath.spentUntil and "spent" or "ready")
	local rot = CFrame.fromEulerAnglesYXZ(
		pitch + recoilPitch + math.sin(t * 1.3) * sway + math.sin(t * 0.9) * aimSway,
		yaw + math.sin(t * 0.7) * sway + math.sin(t * 0.45) * aimSway * 1.4,
		0
	)

	local desired = (CFrame.new(focus) * rot * CFrame.new(off)).Position
	local dir = desired - focus
	local dist = dir.Magnitude
	local allowed = dist
	if dist > 0.01 then
		local hit = Workspace:Spherecast(focus, 0.4, dir, params)
		if hit then
			allowed = math.max(hit.Distance - 0.15, 0.35)
		end
	end
	if allowed < currentDist then
		currentDist = allowed -- snap in so walls never block the view
	else
		currentDist += (allowed - currentDist) * math.min(1, dt * 3.5) -- ease back out
	end
	local position = dist > 0.01 and focus + dir.Unit * currentDist or desired
	local shake = Controllers and Controllers.EffectsController.getShake() or 0
	if shake > 0 and player:GetAttribute("Set_reduceMotion") ~= true then
		local k = shake * 0.03
		rot = rot * CFrame.Angles((math.random() - 0.5) * k, (math.random() - 0.5) * k, 0)
	end
	camera.CFrame = CFrame.new(position) * rot
	camera.Focus = CFrame.new(focus)
end

function CameraController.init(registry)
	Controllers = registry
end

function CameraController.start()
	UserInputService.InputChanged:Connect(function(input, processed)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			if not State.uiOpen() and State.root then
				local k = SENS_MOUSE * sensitivity() * (State.aiming and 0.6 or 1)
				yaw -= input.Delta.X * k
				pitch -= input.Delta.Y * k
			end
		elseif input.KeyCode == Enum.KeyCode.Thumbstick2 then
			padLook = Vector2.new(input.Position.X, input.Position.Y)
		end
	end)

	UserInputService.TouchStarted:Connect(function(input, processed)
		if processed or touchInput or State.uiOpen() then
			return
		end
		if input.Position.X > Workspace.CurrentCamera.ViewportSize.X * 0.4 then
			touchInput = input
			lastTouchPos = input.Position
		end
	end)
	UserInputService.TouchMoved:Connect(function(input)
		if input == touchInput and lastTouchPos then
			local delta = input.Position - lastTouchPos
			lastTouchPos = input.Position
			yaw -= delta.X * SENS_TOUCH * sensitivity()
			pitch -= delta.Y * SENS_TOUCH * sensitivity()
		end
	end)
	UserInputService.TouchEnded:Connect(function(input)
		if input == touchInput then
			touchInput = nil
		end
	end)

	Players.PlayerAdded:Connect(function()
		task.wait(2)
		refreshFilter()
	end)
	task.spawn(function()
		while true do
			task.wait(3)
			refreshFilter()
		end
	end)

	RunService:BindToRenderStep("AftertideCamera", Enum.RenderPriority.Camera.Value + 1, update)
end

return CameraController
