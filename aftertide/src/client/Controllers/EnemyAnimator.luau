--!nonstrict
-- Procedural animation for the Hushed (no animation assets needed). Drives each enemy's
-- Motor6D skeleton from its replicated velocity, State and Gait:
--   shamble (Drifter)   uneven, dragging steps, arms hanging and swaying
--   rush    (Rusher)    frantic sprint, flailing arms, head jerks
--   feel    (Seeker)    blind: arms raised ahead, head cocked toward sounds, lunges
--   heavy   (Tidewalker) slow stomp, torso rolls, arms swinging like weights
-- Plus: stagger when stunned, knees buckling when Quieted, and a "?" / "!" marker above the
-- head when it hears something or has spotted you.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local State = require(script.Parent.Parent.State)

local EnemyAnimator = {}
local player = Players.LocalPlayer

local rigs = setmetatable({}, { __mode = "k" }) -- [Model] = rig data
local MAX_DISTANCE = 160

local GAITS = {
	shamble = { freq = 1.7, stride = 0.55, armSwing = 0.18, armHang = 0.15, lean = 0.12, twitch = 0.25, limp = 0.35 },
	rush = { freq = 2.9, stride = 0.95, armSwing = 0.9, armHang = 0.25, lean = 0.45, twitch = 0.6, limp = 0.1 },
	feel = { freq = 1.4, stride = 0.45, armSwing = 0.08, armHang = 1.1, lean = 0.05, twitch = 0.45, limp = 0.0 },
	heavy = { freq = 1.0, stride = 0.5, armSwing = 0.35, armHang = 0.25, lean = 0.3, twitch = 0.1, limp = 0.15 },
	soldier = { freq = 1.9, stride = 0.6, armSwing = 0.08, armHang = 0.7, lean = 0.06, twitch = 0, limp = 0 },
	cultist = { freq = 1.8, stride = 0.55, armSwing = 0.3, armHang = 0.15, lean = 0.12, twitch = 0.04, limp = 0 },
}

local function marker(model, head)
	local gui = Instance.new("BillboardGui")
	gui.Name = "StateMarker"
	gui.Size = UDim2.new(0, 40, 0, 40)
	gui.StudsOffset = Vector3.new(0, head.Size.Y * 0.5 + 1.6, 0)
	gui.MaxDistance = 90
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false
	gui.Adornee = head
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Oswald
	label.TextScaled = true
	label.TextStrokeTransparency = 0.4
	label.Text = ""
	label.Parent = gui
	gui.Parent = model
	return label
end

local function setup(model)
	local root = model:FindFirstChild("HumanoidRootPart")
	local torso = model:FindFirstChild("Torso")
	local head = model:FindFirstChild("Head")
	if not root or not torso or not head then
		return nil
	end
	local function m(parent, name)
		local p = model:FindFirstChild(parent)
		local j = p and p:FindFirstChild(name)
		return j and j:IsA("Motor6D") and j or nil
	end
	local rig = {
		root = root,
		head = head,
		waist = m("HumanoidRootPart", "Waist"),
		neck = m("Torso", "Neck"),
		ls = m("Torso", "LeftShoulder"),
		rs = m("Torso", "RightShoulder"),
		le = m("LeftUpperArm", "LeftElbow"),
		re = m("RightUpperArm", "RightElbow"),
		lh = m("HumanoidRootPart", "LeftHip"),
		rh = m("HumanoidRootPart", "RightHip"),
		lk = m("LeftUpperLeg", "LeftKnee"),
		rk = m("RightUpperLeg", "RightKnee"),
		phase = math.random() * 6.28,
		seed = math.random() * 100,
		twitchAt = 0,
		twitch = CFrame.new(),
		spasmAt = os.clock() + math.random() * 4,
		spasm = 0,
		lastHP = model:GetAttribute("HP") or 1,
		flinch = 0,
	}
	for _, d in model:GetDescendants() do
		if d.Name == "Maw" and d:IsA("BasePart") then
			rig.maw = d
			rig.mawSize = d.Size
		end
	end
	if not rig.waist or not rig.lh then
		return nil
	end
	rig.label = marker(model, head)
	return rig
end

local function set(motor, cf)
	if motor then
		motor.Transform = cf
	end
end

local function animate(model, rig, dt, now)
	local gait = GAITS[model:GetAttribute("Gait") or "shamble"] or GAITS.shamble
	local state = model:GetAttribute("State") or "Patrol"
	local v = rig.root.AssemblyLinearVelocity
	local speed = Vector3.new(v.X, 0, v.Z).Magnitude
	local moving = math.clamp(speed / 6, 0, 1)
	local chasing = state == "Chase"

	rig.phase += dt * gait.freq * math.clamp(speed / 6, 0.3, 2.6) * math.pi
	local p = rig.phase
	local stride = gait.stride * moving * (chasing and 1.15 or 1)
	local sinL, sinR = math.sin(p), math.sin(p + math.pi)
	local limp = 1 - gait.limp * (sinR > 0 and 1 or 0) -- one leg drags

	-- legs
	local lHip = sinL * stride
	local rHip = sinR * stride * limp
	local lKnee = -math.max(0, -sinL) * stride * 1.6 - 0.08
	local rKnee = -math.max(0, -sinR) * stride * 1.6 * limp - 0.08

	-- torso: lean forward when moving or chasing, slow sway when still
	local idle = (1 - moving)
	local sway = math.sin(now * 0.9 + rig.seed) * 0.05 * idle
	local lean = gait.lean * moving + (chasing and 0.15 or 0)
	local roll = math.sin(p) * 0.06 * moving + sway

	-- arms
	local hang = gait.armHang
	local lArm = hang + -sinL * gait.armSwing * moving
	local rArm = hang + -sinR * gait.armSwing * moving
	local elbow = gait == GAITS.feel and 0.5 or 0.25

	-- head twitches (sharper when they've just heard something)
	local heard = Workspace:GetServerTimeNow() - (model:GetAttribute("Heard") or -100) < 2
	if now > rig.twitchAt then
		local strength = gait.twitch * (heard and 2 or 1)
		rig.twitch = CFrame.Angles((math.random() - 0.5) * strength, (math.random() - 0.5) * strength * 1.5, (math.random() - 0.5) * strength)
		rig.twitchAt = now + (heard and 0.15 or 0.6 + math.random() * 1.8)
	end

	-- spasms: sudden violent jerks of the whole upper body (the Hushed only)
	local human = model:GetAttribute("Human") == true
	if not human and now > rig.spasmAt then
		rig.spasm = 1
		rig.spasmAt = now + (model:GetAttribute("Gait") == "rush" and 1.2 or 2.5) + math.random() * 4
		rig.spasmDir = (math.random() < 0.5) and -1 or 1
	end
	rig.spasm = math.max(0, rig.spasm - dt * 5)
	local sp = rig.spasm ^ 2 * (rig.spasmDir or 1)

	-- flinch when hit
	local hp = model:GetAttribute("HP") or 1
	if hp < rig.lastHP - 0.001 then
		rig.flinch = 1
	end
	rig.lastHP = hp
	rig.flinch = math.max(0, rig.flinch - dt * 4)
	local fl = rig.flinch

	-- the maw gapes when it hunts or screams
	if rig.maw then
		local open = (chasing and 1.6 or 1) + (heard and 0.3 or 0) + math.sin(now * 13) * (chasing and 0.15 or 0)
		rig.maw.Size = Vector3.new(rig.mawSize.X, rig.mawSize.Y * open, rig.mawSize.Z)
	end

	-- states that override the gait
	if state == "Stunned" or state == "Pinned" then
		local wobble = math.sin(now * 9 + rig.seed) * 0.15
		lean, roll = -0.25, wobble
		lArm, rArm = 0.6 + wobble, 0.5 - wobble
		lHip, rHip, lKnee, rKnee = -0.15, 0.2, -0.3, -0.35
	elseif state == "Quieted" or state == "Dispersed" or state == "Down" then
		lean, roll = 0.5, 0.1
		lHip, rHip, lKnee, rKnee = 0.9, 0.85, -1.6, -1.5
		lArm, rArm = 0.1, 0.05
	elseif human then
		if model:GetAttribute("Aiming") then
			lArm, rArm, elbow = 1.45, 1.55, 0.2 -- weapon raised
			lean = 0.02
		end
		local attackAt = model:GetAttribute("AttackAt")
		local since = attackAt and (Workspace:GetServerTimeNow() - attackAt) or 99
		if since < 0.45 then
			local k = since / 0.45
			rArm = k < 0.35 and (2.6 * k / 0.35) or (2.6 - (k - 0.35) / 0.65 * 2.4)
			lean = 0.25 * math.sin(k * math.pi)
		end
	elseif chasing then
		-- arms reach toward their prey
		lArm = math.max(lArm, 1.1 + math.sin(p) * 0.25)
		rArm = math.max(rArm, 1.0 + math.sin(p + 1) * 0.25)
	end

	set(rig.waist, CFrame.Angles(-lean + fl * 0.45, math.sin(p * 0.5) * 0.08 * moving + sp * 0.5, roll + sp * 0.3))
	set(rig.neck, CFrame.Angles(lean * 0.6 - fl * 0.5, sp * 0.9, sp * 0.6) * rig.twitch)
	lArm += sp * 0.8
	rArm -= sp * 0.6
	set(rig.lh, CFrame.Angles(lHip, 0, 0))
	set(rig.rh, CFrame.Angles(rHip, 0, 0))
	set(rig.lk, CFrame.Angles(lKnee, 0, 0))
	set(rig.rk, CFrame.Angles(rKnee, 0, 0))
	set(rig.ls, CFrame.Angles(lArm, 0, -0.08))
	set(rig.rs, CFrame.Angles(rArm, 0, 0.08))
	set(rig.le, CFrame.Angles(elbow + (chasing and 0.2 or 0), 0, 0))
	set(rig.re, CFrame.Angles(elbow + (chasing and 0.3 or 0), 0, 0))

	-- "?" heard / searching, "!" chasing you
	local label = rig.label
	if label then
		local hunting = chasing and model:GetAttribute("Target") == player.UserId
		if hunting or chasing then
			label.Text = "!"
			label.TextColor3 = Color3.fromRGB(200, 74, 60)
		elseif state == "Investigate" or state == "Search" or heard then
			label.Text = "?"
			label.TextColor3 = Color3.fromRGB(232, 168, 92)
		else
			label.Text = ""
		end
	end
end

function EnemyAnimator.start()
	RunService.RenderStepped:Connect(function(dt)
		local folder = Workspace:FindFirstChild("Enemies")
		local camera = Workspace.CurrentCamera
		if not folder then
			return
		end
		local now = os.clock()
		local origin = camera.CFrame.Position
		for _, model in folder:GetChildren() do
			local rig = rigs[model]
			if rig == nil then
				rig = setup(model) -- retried next frame until all parts have replicated
				rigs[model] = rig
			end
			if rig and (rig.root.Position - origin).Magnitude < MAX_DISTANCE then
				animate(model, rig, dt, now)
			end
		end
	end)
	assert(State)
end

return EnemyAnimator
