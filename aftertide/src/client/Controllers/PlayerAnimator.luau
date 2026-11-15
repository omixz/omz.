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
local WeaponModels = require(Shared.WeaponModels)
local State = require(script.Parent.Parent.State)

local PlayerAnimator = {}
local player = Players.LocalPlayer
local rigs = setmetatable({}, { __mode = "k" })

-- What the animator is doing, for the F2 diagnostics panel.
local diag = { setupFail = "not started", lastError = nil, animatedLastFrame = 0, frames = 0, animatorsRemoved = 0 }
function PlayerAnimator.status()
	return diag
end

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
		diag.setupFail = "waiting for the server to mark the character (Procedural attribute)"
		return nil
	end
	local rig = { joints = {}, phase = 0, crouch = 0, aim = 0, ready = 0, lastSlot = "none", drawAt = -10, seed = math.random() * 10 }
	for key, path in JOINTS do
		local part = char:FindFirstChild(path[1])
		local motor = part and part:FindFirstChild(path[2])
		if not (motor and motor:IsA("Motor6D")) then
			diag.setupFail = ("joint missing: %s.%s"):format(path[1], path[2])
			return nil
		end
		rig.joints[key] = motor
	end
	rig.root = char:FindFirstChild("HumanoidRootPart")
	rig.humanoid = char:FindFirstChildOfClass("Humanoid")
	if not rig.root or not rig.humanoid then
		return nil
	end
	-- an Animator overwrites Motor6D.Transform every frame: make sure none survives here
	-- (the server removes it too; this covers one created locally before that replicated)
	local function kill(child)
		if child:IsA("Animator") then
			diag.animatorsRemoved += 1
			pcall(function()
				for _, track in child:GetPlayingAnimationTracks() do
					track:Stop(0)
				end
			end)
			task.defer(function()
				pcall(child.Destroy, child)
			end)
		end
	end
	for _, child in rig.humanoid:GetChildren() do
		kill(child)
	end
	rig.humanoid.ChildAdded:Connect(kill)
	diag.setupFail = nil
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

-- Two-bone IK: solves the left shoulder + elbow so the left hand lands on `target` (world).
-- Works in the shoulder joint's frame. The elbow is a hinge about the upper arm's X axis
-- (positive = forearm forward), the same convention the procedural poses use.
local POLES = { L = Vector3.new(-0.55, -1, 0.2), R = Vector3.new(0.55, -1, 0.2) } -- elbows down and out

-- This frame's posed CFrames of the torso parts, from the root part through the joints we just
-- set. (The parts' own CFrames still hold last frame's pose until physics runs: using them made
-- the hands miss the gun whenever the body moved quickly, e.g. dropping prone.)
local function posedTorso(J)
	local hrp = J.root.Part0
	local lower = hrp.CFrame * J.root.C0 * J.root.Transform * J.root.C1:Inverse()
	local upper = lower * J.waist.C0 * J.waist.Transform * J.waist.C1:Inverse()
	return upper, lower
end

local function solveArm(J, side, target, torsoCF)
	local shoulder, elbow, wrist = J[side == "L" and "ls" or "rs"], J[side == "L" and "le" or "re"], J[side == "L" and "lw" or "rw"]
	local torso, upper, lower = shoulder.Part0, shoulder.Part1, elbow.Part1
	local hand = wrist.Part1
	if not (torso and upper and lower and hand) then
		return nil
	end
	local a = (elbow.C0.Position - shoulder.C1.Position).Magnitude
	local b = (wrist.C0.Position - elbow.C1.Position).Magnitude + hand.Size.Y * 0.45
	local frame = (torsoCF or torso.CFrame) * shoulder.C0
	local t = frame:PointToObjectSpace(target)
	if t.Magnitude < 1e-3 then
		return nil
	end
	local d = math.clamp(t.Magnitude, math.abs(a - b) + 0.05, a + b - 0.02)
	local cosB = math.clamp((d * d - a * a - b * b) / (2 * a * b), -1, 1)
	local beta = math.acos(cosB) -- elbow flex
	local h = Vector3.new(0, -a - b * math.cos(beta), -b * math.sin(beta))
	local u1 = h.Unit
	local u2 = Vector3.new(1, 0, 0)
	local u3 = u1:Cross(u2)
	local e3 = Vector3.new(0, -a, 0):Dot(u3)
	local w1 = t.Unit
	local pole = POLES[side]
	local q = pole - w1 * pole:Dot(w1)
	if q.Magnitude < 1e-3 then
		return nil
	end
	q = q.Unit
	local w3 = e3 >= 0 and q or -q
	local w2 = w3:Cross(w1)
	local function R(v)
		return w1 * u1:Dot(v) + w2 * u2:Dot(v) + w3 * u3:Dot(v)
	end
	local rot = CFrame.fromMatrix(Vector3.zero, R(Vector3.xAxis), R(Vector3.yAxis), R(Vector3.zAxis))
	return rot, CFrame.Angles(beta, 0, 0)
end

-- Gun poses, as the grip's CFrame in UpperTorso space (barrel along -Z).
local GUN_POSES = {
	long = {
		ready = CFrame.new(0.3, -0.05, -0.95) * CFrame.Angles(-0.55, 0.45, 0.25), -- low ready, across the body
		sprint = CFrame.new(0.25, 0.05, -0.8) * CFrame.Angles(-0.9, 0.9, 0.4),
		aim = CFrame.new(0.36, 0.42, -0.7), -- stock in the shoulder pocket
		reload = CFrame.new(0.15, -0.1, -0.95) * CFrame.Angles(-0.2, 0.55, 0.75), -- rolled toward you
	},
	sidearm = {
		ready = CFrame.new(0.35, -0.25, -0.95) * CFrame.Angles(-0.7, 0.15, 0),
		sprint = CFrame.new(0.45, -0.45, -0.7) * CFrame.Angles(-1.2, 0.1, 0),
		aim = CFrame.new(0.12, 0.42, -1.75), -- arms out, two-handed
		reload = CFrame.new(0.1, 0.05, -1.0) * CFrame.Angles(0.9, 0.2, 0.5), -- muzzle up, cylinder open
	},
}
-- where the left hand goes while reloading (grip space): magazine / loading gate / cylinder
local RELOAD_HAND = { long = Vector3.new(0, -0.12, -0.45), sidearm = Vector3.new(-0.12, 0.25, -0.15) }

local shotAt = setmetatable({}, { __mode = "k" }) -- [character] = os.clock() of its last shot

function PlayerAnimator.noteShot(char)
	if char then
		shotAt[char] = os.clock()
	end
end

-- Moving parts: a gun layer (forend, cylinder, arrow...) gets a local Weld we can drive.
-- Every client builds its own, so everyone sees the same motion.
local function movePart(model, layer, offset, aboutCentre)
	local grip = model.PrimaryPart
	local mp = model:FindFirstChild("Mesh_" .. layer)
	if not (grip and mp and mp:IsA("BasePart")) then
		return nil
	end
	local w = mp:FindFirstChild("AnimWeld")
	if not w then
		local rest = grip.CFrame:ToObjectSpace(mp.CFrame)
		for _, c in mp:GetChildren() do
			if c:IsA("WeldConstraint") then
				c.Enabled = false
			end
		end
		w = Instance.new("Weld")
		w.Name = "AnimWeld"
		w.Part0, w.Part1, w.C0 = grip, mp, rest
		w:SetAttribute("Rest", rest) -- kept on the weld (a weak Lua table can lose it)
		w.Parent = mp
	end
	local rest = w:GetAttribute("Rest") or w.C0
	if aboutCentre then
		w.C0 = CFrame.new(rest.Position) * offset * CFrame.new(-rest.Position) * rest
	else
		w.C0 = offset * rest
	end
	return mp, rest
end

local function bell(t, a, b)
	if t <= a or t >= b then
		return 0
	end
	return math.sin((t - a) / (b - a) * math.pi)
end
local function ramp(t, a, b)
	local k = math.clamp((t - a) / (b - a), 0, 1)
	return k * k * (3 - 2 * k)
end

-- Per-weapon action after a shot and during a reload. Returns:
--   poseMul  (applied to the gun pose), rightOff / leftAt (grip-space hand targets or nil),
--   leftWorld (a world hand target, e.g. the ammo pouch on the belt), handled (left hand set)
local function weaponAction(char, rig, model, id, since, reloading, rk, a, lowerCF)
	local poseMul, rightOff, leftAt, leftWorld = CFrame.new(), nil, nil, nil
	local now = os.clock()
	local belt = (lowerCF * CFrame.new(-0.42, -0.05, -0.38)).Position -- ammo pouch, left front
	local function loadCycle(rate, target)
		-- left hand: pouch -> port -> pouch, over and over
		local c = (now * rate) % 1
		local k = c < 0.5 and ramp(c, 0, 0.5) or 1 - ramp(c, 0.5, 1)
		return k, target
	end
	if id == "revolver" then
		-- the cylinder turns one chamber per shot; the muzzle flips up
		local stamp = shotAt[char]
		if stamp and rig.lastShotStamp ~= stamp then
			rig.lastShotStamp = stamp
			rig.cylTarget = (rig.cylTarget or 0) + math.pi / 3
		end
		rig.cyl = (rig.cyl or 0) + ((rig.cylTarget or 0) - (rig.cyl or 0)) * 0.35
		poseMul = CFrame.Angles(0.32 * bell(since, 0, 0.32), 0, 0)
		local out = reloading and (ramp(rk, 0, 0.15) * (1 - ramp(rk, 0.85, 1))) or 0
		movePart(model, "Cylinder", CFrame.new(-0.16 * out, -0.03 * out, 0) * CFrame.Angles(0, 0, rig.cyl + out * 0.6), true)
		if reloading then
			if rk < 0.3 then
				leftAt = Vector3.new(-0.12, 0.3, -0.2) -- thumb the ejector
			else
				local k = loadCycle(3, nil)
				leftWorld = { belt, Vector3.new(-0.2, 0.22, -0.16), k }
			end
		end
	elseif id == "shotgun" then
		local pump = bell(since, 0.2, 0.62)
		movePart(model, "Forend", CFrame.new(0, 0, 0.32 * pump))
		leftAt = Vector3.new(0, 0.05, -1.03 + 0.32 * pump)
		if reloading then
			poseMul = CFrame.Angles(0, 0, 1.1) -- loading port up
			local k = loadCycle(1.7, nil)
			leftWorld = { belt, Vector3.new(0, -0.12, -0.38), k }
		end
	elseif id == "carbine" then
		local lever = bell(since, 0.12, 0.5)
		poseMul = CFrame.Angles(0.12 * lever, 0, 0) * CFrame.new(0, -0.04 * lever, 0)
		rightOff = Vector3.new(0, -0.22 * lever, 0.06 * lever)
		if reloading then
			poseMul = CFrame.Angles(0, 0, -0.55) -- gate side towards you
			local k = loadCycle(1.5, nil)
			leftWorld = { belt, Vector3.new(0.12, 0.02, -0.22), k }
		end
	elseif id == "rifle" then
		local reach = bell(since, 0.3, 1.15)
		local pull = bell(since, 0.48, 0.98)
		if reloading then
			reach = ramp(rk, 0, 0.1) * (1 - ramp(rk, 0.9, 1))
			pull = reach
			local k = loadCycle(1.4, nil)
			leftWorld = { belt, Vector3.new(0, 0.24, -0.2), k }
		end
		rightOff = Vector3.new(0.2 * reach, 0.16 * reach, 0.28 * pull)
		poseMul = CFrame.Angles(0, 0, 0.22 * reach)
	elseif id == "bow" then
		-- draw while aiming; the arrow is gone after a shot until the next is nocked
		local nock = ramp(since, 0.55, 0.95)
		local draw = a * nock
		local arrow = movePart(model, "Arrow", CFrame.new(0, 0, 0.38 * draw))
		if arrow then
			arrow.LocalTransparencyModifier = (since < 0.55 or reloading) and 1 or 0
		end
		leftAt = Vector3.new(0, 0.08, 0.05 + 0.36 * draw)
		if reloading or since < 0.55 then
			-- reach back over the shoulder for an arrow
			leftWorld = { (lowerCF * CFrame.new(-0.35, 2.1, 0.55)).Position, Vector3.new(0, 0.08, 0.05), 1 - math.abs(((now * 1.4) % 1) * 2 - 1) }
		end
	end
	return poseMul, rightOff, leftAt, leftWorld
end

-- Places the held gun (client-side, every frame) and IKs both hands onto it.
local function poseGun(char, rig, J, slot, a, sprinting, reloading, drawK, pitch)
	local torso = char:FindFirstChild("UpperTorso")
	local model = char:FindFirstChild("Weapon_" .. slot)
	local grip = model and model.PrimaryPart
	local weld = grip and grip:FindFirstChild("Mount")
	local set = GUN_POSES[slot]
	if not (torso and weld and set) then
		return false
	end
	local now = os.clock()
	local pose = set.ready
	if reloading then
		local wobble = math.sin(now * 6) * 0.04
		pose = set.reload * CFrame.new(0, wobble, 0) * CFrame.Angles(wobble, 0, 0)
	elseif a > 0.01 then
		local aimPose = set.aim * CFrame.Angles(pitch * 0.55, 0, 0)
		pose = (sprinting and set.sprint or set.ready):Lerp(aimPose, a)
	elseif sprinting then
		pose = set.sprint
	end
	local since = now - (shotAt[char] or -10)
	-- living hands: breathing sway at rest, a bob in step with your feet when moving, a lift
	-- as the gun comes up to aim
	local t = now + (rig.seed or 0)
	local moving = rig.moving or 0
	local steady = 1 - 0.75 * a
	local p = rig.phase or 0
	pose = pose
		* CFrame.new(math.sin(p) * 0.045 * moving, -math.abs(math.cos(p)) * 0.06 * moving + math.sin(t * 1.6) * 0.012 * steady, 0)
		* CFrame.Angles(math.sin(t * 1.3) * 0.02 * steady + math.cos(p * 2) * 0.03 * moving, math.sin(t * 0.9) * 0.025 * steady + math.sin(p) * 0.05 * moving, math.sin(p) * 0.04 * moving)
	if a > 0.05 and a < 0.95 then
		pose = pose * CFrame.new(0, 0.1 * math.sin(a * math.pi), 0) * CFrame.Angles(0.12 * math.sin(a * math.pi), 0, 0)
	end
	-- weapon check: standing idle with the gun out, now and then you turn it over and look at it
	if a < 0.05 and moving < 0.1 and not reloading and since > 6 then
		rig.fidgetAt = rig.fidgetAt or (now + 8 + math.random() * 6)
		local f = now - rig.fidgetAt
		if f > 0 and f < 2.6 then
			local k = math.sin(f / 2.6 * math.pi)
			pose = pose * CFrame.new(-0.1 * k, 0.25 * k, 0.15 * k) * CFrame.Angles(0.25 * k, 0.35 * k, 0.95 * k)
		elseif f >= 2.6 then
			rig.fidgetAt = now + 10 + math.random() * 8
		end
	else
		rig.fidgetAt = nil
	end
	-- recoil: a hard kick back into the shoulder and up, settling fast
	local recoilLen = slot == "long" and 0.32 or 0.26
	if since < recoilLen then
		local k = (1 - since / recoilLen) ^ 2
		if slot == "long" then
			pose = pose * CFrame.new(0, 0.06 * k, 0.32 * k) * CFrame.Angles(0.24 * k, 0.03 * k, 0)
		else
			pose = pose * CFrame.new(0, 0.05 * k, 0.2 * k) * CFrame.Angles(0.38 * k, 0, 0.05 * k)
		end
	end
	local upperCF, lowerCF = posedTorso(J)
	-- the gun's own action: lever / pump / bolt / cylinder / bow draw, and per-gun reloads
	local id = char:GetAttribute("Equipped")
	local serverNow = Workspace:GetServerTimeNow()
	local rk = 0
	if reloading then
		local untilT = char:GetAttribute("ReloadUntil") or 0
		if untilT > serverNow then
			rk = math.clamp(1 - (untilT - serverNow) / math.max(char:GetAttribute("ReloadDur") or 2.5, 0.1), 0, 1)
		else
			rk = (now * 0.5) % 1 -- shell by shell: keep cycling
		end
	end
	local okAct, poseMul, rightOff, leftAt, leftWorld = pcall(weaponAction, char, rig, model, id, since, reloading, rk, a, lowerCF)
	if not okAct then
		poseMul, rightOff, leftAt, leftWorld = CFrame.new(), nil, nil, nil
	end
	pose = pose * (poseMul or CFrame.new())
	-- drawing: from where it was holstered into the hands
	if drawK < 1 then
		local holster = slot == "long" and WeaponModels.BackOffset or (upperCF:ToObjectSpace(lowerCF) * WeaponModels.HipOffset)
		pose = holster:Lerp(pose, drawK * drawK * (3 - 2 * drawK))
	end
	local anchor, anchorCF = torso, upperCF
	if (rig.prone or 0) > 0.5 then
		-- prone: the gun rests out in front of you, just off the ground
		local hrp = rig.root
		local standH = (rig.baseHip or rig.humanoid.HipHeight) + hrp.Size.Y / 2
		anchor, anchorCF = hrp, hrp.CFrame
		pose = CFrame.new(slot == "long" and 0.35 or 0.2, -(standH - 0.95), slot == "long" and -1.9 or -2.3) * CFrame.Angles(pitch * 0.4, 0, 0)
	end
	weld.Part0 = anchor
	weld.C0 = pose
	weld.C1 = CFrame.new()
	rig.posedWeld = weld
	-- hands onto the gun
	local gripWorld = anchorCF * pose
	local rightTarget = rightOff and (gripWorld * rightOff) or gripWorld.Position
	local support = grip:FindFirstChild("Support")
	local leftTarget = support and (gripWorld * support.CFrame).Position or nil
	if leftAt then
		leftTarget = gripWorld * leftAt
	end
	if leftWorld then
		-- between the ammo pouch (world) and the gun (grip space)
		leftTarget = leftWorld[1]:Lerp(gripWorld * leftWorld[2], leftWorld[3])
	elseif reloading and not leftAt then
		local cycle = (math.sin(now * 5) * 0.5 + 0.5)
		leftTarget = (gripWorld * CFrame.new(RELOAD_HAND[slot] + Vector3.new(0, -0.25 * cycle, 0.1 * cycle))).Position
	elseif drawK < 0.6 then
		leftTarget = nil -- the off hand joins once the gun is out
	end
	local ok, rs, re = pcall(solveArm, J, "R", rightTarget, upperCF)
	if ok and rs then
		J.rs.Transform, J.re.Transform = rs, re
		J.rw.Transform = CFrame.Angles(-0.2, 0, 0)
	end
	if leftTarget and (slot == "long" or a > 0.3 or reloading) then
		local okL, ls, le = pcall(solveArm, J, "L", leftTarget, upperCF)
		if okL and ls then
			J.ls.Transform, J.le.Transform = ls, le
			J.lw.Transform = CFrame.Angles(0.3, 0, 0)
		end
	end
	return true
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
	local crouched = (isLocal and State.crouched or char:GetAttribute("Stance") == "Crouch") and not (isLocal and State.prone)
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
	if (reloadUntil > serverNow or char:GetAttribute("Reloading") == true) and armed then
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
		-- wrapping a dressing round the forearm, hands in front of the stomach, head down
		local work = math.sin(heal * 9) * 0.12
		lSh, rSh = 0.5 * k + lSh * (1 - k), 0.42 * k + rSh * (1 - k)
		lEl, rEl = 1.55 * k + work, 1.45 * k - work
		lShZ, rShZ = 0.5 * k, -0.5 * k
		lShY, rShY = 0.25 * k, -0.25 * k
		waistLean -= 0.15 * k
	end

	-- digging a gun out of the backpack: down on one knee, both hands behind
	local packT = since(char, "PackAt", serverNow)
	if packT < 2.4 then
		local k = math.min(1, packT / 0.3) * math.max(0, math.min(1, (2.4 - packT) / 0.3))
		lHip, rHip = lHip + 1.4 * k, rHip + 0.3 * k
		lKnee, rKnee = lKnee - 1.7 * k, rKnee - 1.9 * k
		rootOffset += Vector3.new(0, -1.0 * k, 0)
		lSh, rSh = lSh * (1 - k) - 0.8 * k, rSh * (1 - k) - 0.9 * k
		lEl, rEl = 1.4 * k, 1.5 * k
		waistLean -= 0.3 * k
	end

	-- holding someone: left arm round their neck, right arm in front
	if char:GetAttribute("Grabbing") then
		lSh, lEl, lShZ = 1.6, 1.9, 0.6
		if not armed then
			rSh, rEl, rShZ = 1.3, 1.6, -0.4
		end
		waistLean -= 0.05
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

	-- prone: flat on the belly, head up, crawling on elbows and knees
	local prone = (isLocal and State.prone or char:GetAttribute("Stance") == "Prone") and not downed
	rig.prone = approach(rig.prone or 0, prone and 1 or 0, 7, dt)
	local pk = rig.prone
	if pk > 0.01 then
		local crawl = math.sin(p) * 0.35 * moving
		local standH = (rig.baseHip or rig.humanoid.HipHeight) + root.Size.Y / 2
		local function mix(x, y)
			return x + (y - x) * pk
		end
		rootX = mix(rootX, -1.45)
		rootOffset = rootOffset:Lerp(Vector3.new(0, -(standH - 0.7), 0), pk)
		waistLean = mix(waistLean, 0.12)
		lHip, rHip = mix(lHip, -0.05 + crawl), mix(rHip, -0.05 - crawl)
		lKnee, rKnee = mix(lKnee, -0.15 - math.max(0, crawl) * 1.5), mix(rKnee, -0.15 - math.max(0, -crawl) * 1.5)
		lSh, rSh = mix(lSh, 1.55 + crawl), mix(rSh, 1.55 - crawl)
		lEl, rEl = mix(lEl, 1.3), mix(rEl, 1.3)
		lShZ, rShZ = mix(lShZ, -0.35), mix(rShZ, 0.35)
	end

	-- shooting moves the whole body: shoulders rock back, then settle
	local shotK = 0
	if armed then
		local ss = os.clock() - (shotAt[char] or -10)
		if ss < 0.35 then
			shotK = (1 - ss / 0.35) ^ 2 * (longGun and 1 or 0.6)
			waistLean -= 0.14 * shotK
			rootY -= 0.05 * shotK
		end
	end
	rig.moving = moving

	-- hit flinch: the body jolts away from the hit and the head snaps, then recovers
	local hurt = since(char, "HurtAt", serverNow)
	local hurtNeck = 0
	if hurt < 0.45 and not downed then
		local k = math.sin(math.min(1, hurt / 0.45) * math.pi) * (1 - hurt / 0.45 * 0.5)
		local from = char:GetAttribute("HurtFrom")
		local sideSign = 1
		if typeof(from) == "Vector3" then
			sideSign = root.CFrame:PointToObjectSpace(from).X > 0 and -1 or 1
		end
		waistLean += 0.28 * k
		rootY += 0.22 * k * sideSign
		rootZ += 0.08 * k * sideSign
		hurtNeck = 0.3 * k
		lSh, rSh = lSh + 0.25 * k, rSh + 0.25 * k
	end

	local neckPitch = pitch * (0.35 + 0.25 * a) - waistLean * 0.5 + shift * 0.3 + 1.15 * pk + hurtNeck
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

	-- the gun in your hands: pose it against the chest and put both hands on it
	local busyHands = melee < 0.45 or throw < 0.5 or takedown < 1.2 or heal < 2.2 or dodge < dodgeLen
	local reloading = (reloadUntil > serverNow) or char:GetAttribute("Reloading") == true
	local drawK = math.clamp((os.clock() - (rig.drawAt or -10)) / 0.4, 0, 1)
	if armed and not downed and not busyHands and rig.healHolstered then
		rig.healHolstered = nil
		rig.drawAt = os.clock() -- draw it again after healing
		drawK = 0
	end
	if armed and not downed and not busyHands then
		local sprinting = (isLocal and State.sprinting or char:GetAttribute("Sprint") == true) and moving > 0.5
		local okPose, err = pcall(poseGun, char, rig, J, slot, a, sprinting, reloading, drawK, pitch)
		if not okPose and not rig.poseWarned then
			rig.poseWarned = true
			warn("[PlayerAnimator] gun pose: " .. tostring(err))
		end
	elseif armed and not downed and heal < 2.2 then
		-- both hands on the dressing: the gun goes back in its holster, then is drawn again
		local model = char:FindFirstChild("Weapon_" .. slot)
		local w = model and model.PrimaryPart and model.PrimaryPart:FindFirstChild("Mount")
		local holsterPart = char:FindFirstChild(slot == "long" and "UpperTorso" or "LowerTorso")
		if w and holsterPart then
			w.Part0 = holsterPart
			w.C0 = slot == "long" and WeaponModels.BackOffset or WeaponModels.HipOffset
			w.C1 = CFrame.new()
			rig.posedWeld = w
			rig.healHolstered = true
		end
	elseif rig.posedWeld then
		-- hands busy or holstered: give the weld back to the server's mount (hand / back / hip)
		local w = rig.posedWeld
		rig.posedWeld = nil
		local model = w.Parent and w.Parent.Parent
		if model and model.Name == "Weapon_" .. slot and armed then
			local hand = char:FindFirstChild("RightHand")
			if hand then
				w.Part0 = hand
				w.C0 = WeaponModels.HandOffset
			end
		end
	end

	-- local player's hips physically lower when crouched
	if isLocal and rig.humanoid then
		local base = char:GetAttribute("BaseHipHeight")
		if base then
			rig.baseHip = base
			rig.humanoid.HipHeight = base * (1 - (1 - Movement.CrouchHipMult) * math.min(c, 1))
		end
	end
end

-- Test hook: run one animation frame on a rig (used by the engine tests) and report errors.
-- The rig state is kept between calls (like the live loop), so blends settle over frames.
-- `settled` skips the draw-from-holster timer (test frames run faster than real time).
-- Test hook: pretend this character fired `age` seconds ago (engine pose tests).
function PlayerAnimator.debugShotAge(char, age)
	shotAt[char] = os.clock() - age
end

function PlayerAnimator.debugAnimate(char, isLocal, settled)
	local rig = rigs[char] or setup(char)
	if not rig then
		return false, "setup failed: " .. tostring(diag.setupFail)
	end
	rigs[char] = rig
	if settled then
		rig.lastSlot = char:GetAttribute("EquippedSlot") or "none"
		rig.drawAt = -10
	end
	local ok, err = pcall(animate, char, rig, 1 / 60, Workspace:GetServerTimeNow(), isLocal == true)
	return ok, err, rig
end

function PlayerAnimator.start()
	local Net = require(Shared.Net)
	Net.event("Notify").OnClientEvent:Connect(function(kind, data)
		if kind == "Shot" and type(data) == "table" and data.shooter and data.shooter ~= player.UserId then
			local shooter = Players:GetPlayerByUserId(data.shooter)
			PlayerAnimator.noteShot(shooter and shooter.Character)
		end
	end)
	RunService.Stepped:Connect(function(_, dt)
		local serverNow = Workspace:GetServerTimeNow()
		local camPos = Workspace.CurrentCamera.CFrame.Position
		diag.frames += 1
		local animated = 0
		-- players, plus any rescued survivors (same rig, same procedural animation)
		local subjects = {}
		for _, p in Players:GetPlayers() do
			if p.Character then
				table.insert(subjects, { char = p.Character, isLocal = p == player })
			end
		end
		for _, m in game:GetService("CollectionService"):GetTagged("Survivor") do
			table.insert(subjects, { char = m, isLocal = false })
		end
		for _, subject in subjects do
			local char = subject.char
			local p = { } -- kept for the isLocal flag below
			p.isLocal = subject.isLocal
			if char then
				local rig = rigs[char]
				if rig == nil then
					rig = setup(char)
					rigs[char] = rig
				end
				if rig and rig.root.Parent and (rig.root.Position - camPos).Magnitude < 220 then
					local ok, err = pcall(animate, char, rig, dt, serverNow, p.isLocal)
					if ok then
						animated += 1
					else
						diag.lastError = tostring(err)
					end
					if not ok then
						-- report once, fall back to Roblox's own animation, try again shortly
						if not rig.reported then
							rig.reported = true
							warn("[PlayerAnimator] " .. tostring(err))
						end
						rigs[char] = false
						task.delay(2, function()
							if rigs[char] == false then
								rigs[char] = nil
							end
						end)
					end
				end
			end
		end
		diag.animatedLastFrame = animated
	end)
end

return PlayerAnimator
