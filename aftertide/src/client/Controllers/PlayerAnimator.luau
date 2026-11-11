--!nonstrict
-- Procedural full-body animation for every crew character (replaces Roblox's default
-- Animate script, so movement doesn't look like a Roblox avatar). Runs on each client for
-- all characters from replicated velocity + attributes:
--   locomotion  walk / jog / sprint gait with stride, knee lift, ankle roll, hip bob,
--               counter-rotating torso, arm swing; backpedal + strafe while aiming
--   stances     crouch + crouch-walk, downed crawl
--   weapons     carry (ready) and aim poses for long guns / sidearms, aim pitch, reload,
--               draw from back / hip on swap
--   actions     melee combo swings, dodge / dive, throw, takedown, field dressing
--   idle        breathing, weight shift
-- Cues come from server-set character attributes: MeleeAt, MeleeCombo, DodgeAt, DodgeDive,
-- ThrowAt, TakedownAt, HealAt, ReloadUntil, Equipped(Slot), Aim, AimPitch, Stance, Downed.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Movement = require(Shared.Config.Movement)
local State = require(script.Parent.Parent.State)

local PlayerAnimator = {}
local player = Players.LocalPlayer
local rigs = setmetatable({}, { __mode = "k" })

local JOINTS = {
	root = { "LowerTorso", "Root" },
	waist = { "UpperTorso", "Waist" },
	neck = { "Head", "Neck" },
	ls = { "LeftUpperArm", "LeftShoulder" },
	rs = { "RightUpperArm", "RightShoulder" },
	le = { "LeftLowerArm", "LeftElbow" },
	re = { "RightLowerArm", "RightElbow" },
	lw = { "LeftHand", "LeftWrist" },
	rw = { "RightHand", "RightWrist" },
	lh = { "LeftUpperLeg", "LeftHip" },
	rh = { "RightUpperLeg", "RightHip" },
	lk = { "LeftLowerLeg", "LeftKnee" },
	rk = { "RightLowerLeg", "RightKnee" },
	la = { "LeftFoot", "LeftAnkle" },
	ra = { "RightFoot", "RightAnkle" },
}

local function setup(char)
	if not char:GetAttribute("Procedural") then
		return nil
	end
	local rig = { joints = {}, phase = 0, crouch = 0, aim = 0, ready = 0, lastSlot = "none", drawAt = -10, seed = math.random() * 10 }
	for key, path in JOINTS do
		local part = char:FindFirstChild(path[1])
		local motor = part and part:FindFirstChild(path[2])
		if not (motor and motor:IsA("Motor6D")) then
			return nil
		end
		rig.joints[key] = motor
	end
	rig.root = char:FindFirstChild("HumanoidRootPart")
	rig.humanoid = char:FindFirstChildOfClass("Humanoid")
	if not rig.root or not rig.humanoid then
		return nil
	end
	-- stop anything the default Animate script may have started before it was removed
	local animator = rig.humanoid:FindFirstChildOfClass("Animator")
	if animator then
		for _, track in animator:GetPlayingAnimationTracks() do
			track:Stop(0)
		end
	end
	return rig
end

local function ang(x, y, z)
	return CFrame.Angles(x or 0, y or 0, z or 0)
end

local function since(char, attr, serverNow)
	local at = char:GetAttribute(attr)
	return at and (serverNow - at) or math.huge
end

local function approach(current, target, rate, dt)
	return current + (target - current) * math.min(1, dt * rate)
end

local function animate(char, rig, dt, serverNow, isLocal)
	local J = rig.joints
	local root = rig.root
	local v = root.AssemblyLinearVelocity
	local flat = Vector3.new(v.X, 0, v.Z)
	local speed = flat.Magnitude
	local localVel = root.CFrame:VectorToObjectSpace(flat)
	local fwd, side = -localVel.Z, localVel.X

	local downed = char:GetAttribute("Downed") == true or char:GetAttribute("Out") == true
	local crouched = isLocal and State.crouched or char:GetAttribute("Stance") == "Crouch"
	local equipped = char:GetAttribute("Equipped")
	local armed = equipped ~= nil and equipped ~= "" and not downed
	local slot = char:GetAttribute("EquippedSlot") or "none"
	local longGun = slot == "long"
	local aiming = armed and (isLocal and State.aiming or char:GetAttribute("Aim") == true)
	local pitch = isLocal and State.pitch or (char:GetAttribute("AimPitch") or 0)

	if slot ~= rig.lastSlot then
		rig.lastSlot = slot
		rig.drawAt = os.clock()
		rig.drawSlot = slot
	end

	rig.crouch = approach(rig.crouch, (crouched or downed) and 1 or 0, 10, dt)
	rig.aim = approach(rig.aim, aiming and 1 or 0, 14, dt)
	rig.ready = approach(rig.ready, armed and 1 or 0, 10, dt)
	local c, a, r = rig.crouch, rig.aim, rig.ready * (1 - rig.aim)

	-- gait
	local moving = math.clamp(speed / 2.5, 0, 1)
	local run = math.clamp((speed - Movement.Speeds.Walk) / (Movement.Speeds.Sprint - Movement.Speeds.Walk), 0, 1)
	local stride = 2.0 + 2.2 * run
	rig.phase += dt * (speed / stride) * math.pi
	local p = rig.phase
	local back = (fwd < -1 and math.abs(fwd) > math.abs(side)) and -1 or 1
	local strafe = math.abs(side) > math.abs(fwd) * 1.2 and math.clamp(side / 8, -1, 1) or 0
	local amp = (0.34 + 0.42 * run) * moving * (1 - 0.45 * c)
	local sL, sR = math.sin(p), math.sin(p + math.pi)

	local lHip = sL * amp * back * (1 - math.abs(strafe))
	local rHip = sR * amp * back * (1 - math.abs(strafe))
	local hipRollL, hipRollR = sL * amp * strafe * 0.7, sR * amp * strafe * 0.7
	local liftL = math.max(0, math.sin(p + 1.3)) * (0.5 + 1.0 * run) * moving
	local liftR = math.max(0, math.sin(p + math.pi + 1.3)) * (0.5 + 1.0 * run) * moving
	local lKnee, rKnee = -liftL - 0.06, -liftR - 0.06
	local lAnk, rAnk = liftL * 0.35 - lHip * 0.25, liftR * 0.35 - rHip * 0.25
	local bob = -math.abs(math.cos(p)) * (0.05 + 0.1 * run) * moving
	local leanFwd = (0.04 + 0.2 * run) * moving * (back > 0 and 1 or -0.5)
	local twist = math.sin(p) * (0.06 + 0.1 * run) * moving
	local t = os.clock() + rig.seed
	local breathe = math.sin(t * 1.7) * 0.025 * (1 - moving)
	local shift = math.sin(t * 0.35) * 0.04 * (1 - moving)

	-- crouch pose blended in
	lHip += 1.1 * c
	rHip += 1.1 * c
	lKnee -= 1.6 * c
	rKnee -= 1.6 * c
	lAnk += 0.5 * c
	rAnk += 0.5 * c
	local waistLean = -(0.42 * c) - leanFwd * 0.6 + breathe

	-- arms: natural swing (unarmed)
	local swing = (0.35 + 0.55 * run) * moving * (1 - 0.6 * c)
	local lSh, rSh = -sL * swing * back + 0.05, -sR * swing * back + 0.05
	local lEl, rEl = 0.2 + 0.9 * run * moving, 0.2 + 0.9 * run * moving
	local lShZ, rShZ = -0.06, 0.06
	local lShY, rShY = 0, 0

	-- weapon carry / aim (two-handed); aim pitch bends the upper body
	if rig.ready > 0.01 or a > 0.01 then
		local hold = math.max(r, a)
		local pp = pitch * a
		waistLean += pp * 0.45
		local aimR = 1.55 + pp * 0.5
		local readyR = longGun and 0.75 or 0.5
		rSh = rSh * (1 - hold) + (aimR * a + readyR * r)
		rEl = rEl * (1 - hold) + (0.12 * a + (longGun and 1.1 or 0.9) * r)
		rShZ = rShZ * (1 - hold) + (longGun and 0.2 or 0.1) * hold
		if longGun or a > 0.01 then
			local lh = longGun and hold or a
			lSh = lSh * (1 - lh) + ((1.45 + pp * 0.5) * a + 0.85 * r) * (lh > 0 and 1 or 0)
			lEl = lEl * (1 - lh) + ((longGun and 0.6 or 0.4) * a + 1.0 * r)
			lShZ = lShZ * (1 - lh) + (longGun and 0.6 or 0.8) * lh
			lShY = (longGun and -0.3 or -0.2) * lh
		end
	end

	-- reload: left hand works the weapon, gun tilts in
	local reloadUntil = char:GetAttribute("ReloadUntil") or 0
	if reloadUntil > serverNow and armed then
		local cycle = math.sin((serverNow % 0.8) / 0.8 * math.pi * 2)
		lSh = 0.9 + cycle * 0.15
		lEl = 1.3 + cycle * 0.2
		lShZ = 0.7
		rSh = math.min(rSh, 0.8)
		waistLean -= 0.08
	end

	-- draw / holster: reach over the shoulder (long) or down to the hip (sidearm)
	local drawT = os.clock() - rig.drawAt
	if drawT < 0.4 then
		local k = math.sin(drawT / 0.4 * math.pi)
		if rig.drawSlot == "long" or (rig.drawSlot == "none" and longGun) then
			rSh = rSh + (2.7 - rSh) * k
			rEl = rEl + (1.4 - rEl) * k
			rShZ = rShZ + 0.3 * k
		else
			rSh = rSh + (-0.3 - rSh) * k
			rShZ = rShZ + 0.25 * k
		end
	end

	-- one-shot actions (server cues)
	local rootX, rootZ, rootY = -leanFwd, 0, 0
	local rootOffset = Vector3.new(0, bob, 0)

	local melee = since(char, "MeleeAt", serverNow)
	if melee < 0.45 then
		local combo = char:GetAttribute("MeleeCombo") or 1
		local k = melee / 0.45
		local wind = k < 0.3 and (k / 0.3) or (1 - (k - 0.3) / 0.7)
		local dir = combo == 2 and -1 or 1
		if combo == 3 then
			-- overhead finisher with both arms
			rSh, lSh = 2.6 * wind + 0.4, 2.4 * wind + 0.4
			rEl, lEl = 0.6, 0.6
			waistLean += 0.35 * (1 - wind) - 0.2 * wind
		else
			local arm = dir > 0 and "r" or "l"
			local raise, elbow = 1.7 * wind + 0.3, 1.2 * wind + 0.3
			if arm == "r" then
				rSh, rEl, rShZ = raise, elbow, 0.3 + 0.8 * wind
			else
				lSh, lEl, lShZ = raise, elbow, -0.3 - 0.8 * wind
			end
			rootY = dir * (0.5 * wind - 0.4 * (1 - wind))
		end
		rootX -= 0.15
	end

	local dodge = since(char, "DodgeAt", serverNow)
	local dive = char:GetAttribute("DodgeDive") == true
	local dodgeLen = dive and 0.75 or 0.45
	if dodge < dodgeLen then
		local k = math.sin(dodge / dodgeLen * math.pi)
		if dive then
			rootX -= 1.1 * k
			rootOffset += Vector3.new(0, -0.9 * k, 0)
			lSh, rSh = 2.4 * k, 2.4 * k
			lEl, rEl = 0.3, 0.3
			lHip, rHip = -0.2 * k, -0.3 * k
			lKnee, rKnee = -0.4 * k, -0.6 * k
		else
			rootX -= 0.35 * k
			rootZ += (side > 0 and -0.35 or 0.35) * k
			lHip += 0.7 * k
			rHip += 0.7 * k
			lKnee -= 1.1 * k
			rKnee -= 1.1 * k
			rootOffset += Vector3.new(0, -0.45 * k, 0)
		end
	end

	local throw = since(char, "ThrowAt", serverNow)
	if throw < 0.5 then
		local k = throw / 0.5
		if k < 0.35 then
			rSh, rEl, rShZ = -0.6 - (k / 0.35) * 1.2, 1.2, 0.2 -- wind back
		else
			local f = (k - 0.35) / 0.65
			rSh, rEl, rShZ = -1.8 + f * 4.2, 1.2 - f * 1.0, 0.1 -- release overhead
		end
		rootY += 0.25 * math.sin(k * math.pi)
	end

	local takedown = since(char, "TakedownAt", serverNow)
	if takedown < 1.2 then
		local k = math.min(1, takedown / 0.2) * math.max(0, math.min(1, (1.2 - takedown) / 0.3))
		lSh, rSh = lSh + (1.4 - lSh) * k, rSh + (1.5 - rSh) * k
		lEl, rEl = 1.3 * k, 1.1 * k
		lShZ, rShZ = 0.5 * k, -0.4 * k
		waistLean -= 0.3 * k
	end

	local heal = since(char, "HealAt", serverNow)
	if heal < 2.2 then
		local k = math.min(1, heal / 0.25) * math.max(0, math.min(1, (2.2 - heal) / 0.3))
		local work = math.sin(heal * 9) * 0.12
		lSh, rSh = 0.9 * k + lSh * (1 - k), 0.8 * k + rSh * (1 - k)
		lEl, rEl = 1.6 * k + work, 1.5 * k - work
		lShZ, rShZ = 0.6 * k, -0.6 * k
		waistLean -= 0.15 * k
	end

	if downed then
		-- slumped, crawling on one arm
		local crawl = math.sin(p) * 0.4 * moving
		waistLean = -0.9
		rootX = -0.35
		lHip, rHip = 1.4, 1.2
		lKnee, rKnee = -1.9, -1.7
		lSh, rSh = 1.0 + crawl, 0.4 - crawl
		lEl, rEl = 1.2, 0.8
	end

	local neckPitch = pitch * (0.35 + 0.25 * a) - waistLean * 0.5 + shift * 0.3
	J.root.Transform = CFrame.new(rootOffset) * ang(rootX, rootY + shift, rootZ)
	J.waist.Transform = ang(waistLean, -twist + rootY * -0.3, shift * 0.5)
	J.neck.Transform = ang(neckPitch, twist * 0.5, 0)
	J.lh.Transform = ang(lHip, 0, hipRollL)
	J.rh.Transform = ang(rHip, 0, hipRollR)
	J.lk.Transform = ang(lKnee, 0, 0)
	J.rk.Transform = ang(rKnee, 0, 0)
	J.la.Transform = ang(lAnk, 0, 0)
	J.ra.Transform = ang(rAnk, 0, 0)
	J.ls.Transform = ang(lSh, lShY, lShZ)
	J.rs.Transform = ang(rSh, rShY, rShZ)
	J.le.Transform = ang(lEl, 0, 0)
	J.re.Transform = ang(rEl, 0, 0)
	J.lw.Transform = ang(0, 0, 0)
	J.rw.Transform = ang(a * 0.1, 0, 0)

	-- local player's hips physically lower when crouched
	if isLocal and rig.humanoid then
		rig.baseHip = rig.baseHip or rig.humanoid.HipHeight
		rig.humanoid.HipHeight = rig.baseHip * (1 - (1 - Movement.CrouchHipMult) * math.min(c, 1))
	end
end

function PlayerAnimator.start()
	RunService.Stepped:Connect(function(_, dt)
		local serverNow = Workspace:GetServerTimeNow()
		local camPos = Workspace.CurrentCamera.CFrame.Position
		for _, p in Players:GetPlayers() do
			local char = p.Character
			if char then
				local rig = rigs[char]
				if rig == nil then
					rig = setup(char)
					rigs[char] = rig
				end
				if rig and rig.root.Parent and (rig.root.Position - camPos).Magnitude < 220 then
					local ok, err = pcall(animate, char, rig, dt, serverNow, p == player)
					if not ok then
						warn("[PlayerAnimator] " .. tostring(err))
						rigs[char] = false
					end
				end
			end
		end
	end)
end

return PlayerAnimator
