--!nonstrict
-- Fits sculpted meshes (from tools/build_assets.py) onto a live skeleton.
--
-- Each segment mesh was sculpted around canonical joints (MeshMeta: top / bottom anchors).
-- At runtime we read the real joint positions from the rig's Motor6Ds, scale the segment
-- uniformly so its anchor-to-anchor length matches, and weld it so its top anchor sits
-- exactly on the real joint. Proportions stay realistic whatever the skeleton's sizes are.
local MeshKit = {}

local CHILD = {
	r15 = {
		LowerTorso = "UpperTorso", UpperTorso = "Head",
		RightUpperArm = "RightLowerArm", RightLowerArm = "RightHand",
		LeftUpperArm = "LeftLowerArm", LeftLowerArm = "LeftHand",
		RightUpperLeg = "RightLowerLeg", RightLowerLeg = "RightFoot",
		LeftUpperLeg = "LeftLowerLeg", LeftLowerLeg = "LeftFoot",
	},
	enemy = {
		Torso = "Head",
		RightUpperArm = "RightLowerArm", LeftUpperArm = "LeftLowerArm",
		RightUpperLeg = "RightLowerLeg", LeftUpperLeg = "LeftLowerLeg",
	},
}

-- Segments without their own child joint borrow the scale of this segment.
local SCALE_FROM = {
	r15 = { Head = "UpperTorso", RightHand = "RightLowerArm", LeftHand = "LeftLowerArm", RightFoot = "RightLowerLeg", LeftFoot = "LeftLowerLeg" },
	enemy = { Head = "Torso", Pelvis = "Torso" },
}

-- Order matters: scale donors first.
local ORDER = {
	r15 = { "UpperTorso", "LowerTorso", "Head", "RightUpperArm", "LeftUpperArm", "RightLowerArm", "LeftLowerArm", "RightHand", "LeftHand", "RightUpperLeg", "LeftUpperLeg", "RightLowerLeg", "LeftLowerLeg", "RightFoot", "LeftFoot" },
	enemy = { "Torso", "Pelvis", "Head", "RightUpperArm", "LeftUpperArm", "RightLowerArm", "LeftLowerArm", "RightUpperLeg", "LeftUpperLeg", "RightLowerLeg", "LeftLowerLeg" },
}

local function material(name)
	local ok, m = pcall(function()
		return Enum.Material[name]
	end)
	return ok and m or Enum.Material.SmoothPlastic
end

local function v3(t)
	return Vector3.new(t[1], t[2], t[3])
end

local function jointsOf(model)
	local own, byParent = {}, {}
	for _, m in model:GetDescendants() do
		if m:IsA("Motor6D") and m.Part0 and m.Part1 then
			own[m.Part1] = m
			byParent[m.Part0] = byParent[m.Part0] or {}
			byParent[m.Part0][m.Part1.Name] = m
		end
	end
	return own, byParent
end

-- Canonical joint positions (sculpt space) from the kit's segment anchors.
local function canonicalJoints(meta, format)
	local seg = meta.segments
	local function top(name)
		return seg[name] and seg[name].top and v3(seg[name].top)
	end
	local function bottom(name)
		return seg[name] and seg[name].bottom and v3(seg[name].bottom)
	end
	local J = {}
	if format == "r15" then
		J.root, J.waist, J.neck = top("LowerTorso"), top("UpperTorso"), bottom("UpperTorso")
		for _, side in { "Left", "Right" } do
			J[side .. "Shoulder"] = top(side .. "UpperArm")
			J[side .. "Elbow"] = top(side .. "LowerArm")
			J[side .. "Wrist"] = top(side .. "Hand")
			J[side .. "Hip"] = top(side .. "UpperLeg")
			J[side .. "Knee"] = top(side .. "LowerLeg")
			J[side .. "Ankle"] = top(side .. "Foot")
		end
	else
		J.root, J.waist, J.neck = top("Pelvis"), top("Torso"), bottom("Torso")
		for _, side in { "Left", "Right" } do
			J[side .. "Shoulder"] = top(side .. "UpperArm")
			J[side .. "Elbow"] = top(side .. "LowerArm")
			J[side .. "HandEnd"] = bottom(side .. "LowerArm")
			J[side .. "Hip"] = top(side .. "UpperLeg")
			J[side .. "Knee"] = top(side .. "LowerLeg")
			J[side .. "Ground"] = bottom(side .. "LowerLeg")
		end
	end
	for _, v in J do
		if not v then
			return nil
		end
	end
	return J
end

local function setJoint(model, partName, motorName, parentCenter, childCenter, joint)
	local part = model:FindFirstChild(partName)
	local motor
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") and d.Name == motorName and d.Part1 == part then
			motor = d
			break
		end
	end
	if not motor then
		return
	end
	motor.C0 = CFrame.new(joint - parentCenter)
	motor.C1 = CFrame.new(joint - childCenter)
	-- keep R15 rig attachments in step (Roblox uses them for accessories and rebuilds)
	local att0 = motor.Part0 and motor.Part0:FindFirstChild(motorName .. "RigAttachment")
	local att1 = part and part:FindFirstChild(motorName .. "RigAttachment")
	if att0 then
		att0.CFrame = motor.C0
	end
	if att1 then
		att1.CFrame = motor.C1
	end
end

-- Rebuilds a character's skeleton to the sculpt's own proportions (uniformly scaled by `s`),
-- so every mesh segment fits its bone exactly: no gaps, no stretched pieces.
-- Returns the HipHeight the Humanoid needs, or nil if the kit has no usable anchors.
function MeshKit.conformSkeleton(model, meta, format, s)
	local J0 = canonicalJoints(meta, format)
	if not J0 then
		return nil
	end
	local J = {}
	for k, v in J0 do
		J[k] = v * s
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		pcall(function()
			humanoid.AutomaticScalingEnabled = false
		end)
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	local C = {} -- part centres in rig space (root joint at the origin's height)
	local function size(name, v)
		local p = model:FindFirstChild(name)
		if p then
			p.Size = v
		end
	end
	C.HumanoidRootPart = J.root
	if format == "r15" then
		C.LowerTorso = (J.root + J.waist) / 2
		C.UpperTorso = (J.waist + J.neck) / 2
		C.Head = J.neck + Vector3.new(0, 0.55 * s, 0)
		size("LowerTorso", Vector3.new(1.1 * s, (J.waist - J.root).Magnitude + 0.2 * s, 0.7 * s))
		size("UpperTorso", Vector3.new(1.3 * s, (J.neck - J.waist).Magnitude, 0.75 * s))
		size("Head", Vector3.new(0.85 * s, 1.05 * s, 0.95 * s))
		setJoint(model, "LowerTorso", "Root", C.HumanoidRootPart, C.LowerTorso, J.root)
		setJoint(model, "UpperTorso", "Waist", C.LowerTorso, C.UpperTorso, J.waist)
		setJoint(model, "Head", "Neck", C.UpperTorso, C.Head, J.neck)
		for _, side in { "Left", "Right" } do
			local sh, el, wr = J[side .. "Shoulder"], J[side .. "Elbow"], J[side .. "Wrist"]
			local hip, kn, an = J[side .. "Hip"], J[side .. "Knee"], J[side .. "Ankle"]
			C[side .. "UpperArm"] = (sh + el) / 2
			C[side .. "LowerArm"] = (el + wr) / 2
			C[side .. "Hand"] = wr - Vector3.new(0, 0.22 * s, 0)
			C[side .. "UpperLeg"] = (hip + kn) / 2
			C[side .. "LowerLeg"] = (kn + an) / 2
			C[side .. "Foot"] = an - Vector3.new(0, 0.18 * s, 0.2 * s)
			size(side .. "UpperArm", Vector3.new(0.34 * s, (el - sh).Magnitude, 0.34 * s))
			size(side .. "LowerArm", Vector3.new(0.28 * s, (wr - el).Magnitude, 0.28 * s))
			size(side .. "Hand", Vector3.new(0.2 * s, 0.44 * s, 0.3 * s))
			size(side .. "UpperLeg", Vector3.new(0.45 * s, (kn - hip).Magnitude, 0.45 * s))
			size(side .. "LowerLeg", Vector3.new(0.34 * s, (an - kn).Magnitude, 0.34 * s))
			size(side .. "Foot", Vector3.new(0.32 * s, 0.36 * s, 0.8 * s))
			setJoint(model, side .. "UpperArm", side .. "Shoulder", C.UpperTorso, C[side .. "UpperArm"], sh)
			setJoint(model, side .. "LowerArm", side .. "Elbow", C[side .. "UpperArm"], C[side .. "LowerArm"], el)
			setJoint(model, side .. "Hand", side .. "Wrist", C[side .. "LowerArm"], C[side .. "Hand"], wr)
			setJoint(model, side .. "UpperLeg", side .. "Hip", C.LowerTorso, C[side .. "UpperLeg"], hip)
			setJoint(model, side .. "LowerLeg", side .. "Knee", C[side .. "UpperLeg"], C[side .. "LowerLeg"], kn)
			setJoint(model, side .. "Foot", side .. "Ankle", C[side .. "LowerLeg"], C[side .. "Foot"], an)
		end
	else
		C.Torso = (J.waist + J.neck) / 2
		C.Head = J.neck + Vector3.new(0, 0.55 * s, 0)
		size("Torso", Vector3.new(1.2 * s, (J.neck - J.waist).Magnitude, 0.7 * s))
		size("Head", Vector3.new(0.85 * s, 1.05 * s, 0.95 * s))
		setJoint(model, "Torso", "Waist", C.HumanoidRootPart, C.Torso, J.waist)
		setJoint(model, "Head", "Neck", C.Torso, C.Head, J.neck)
		for _, side in { "Left", "Right" } do
			local sh, el, he = J[side .. "Shoulder"], J[side .. "Elbow"], J[side .. "HandEnd"]
			local hip, kn, gr = J[side .. "Hip"], J[side .. "Knee"], J[side .. "Ground"]
			C[side .. "UpperArm"] = (sh + el) / 2
			C[side .. "LowerArm"] = (el + he) / 2
			C[side .. "UpperLeg"] = (hip + kn) / 2
			C[side .. "LowerLeg"] = (kn + gr) / 2
			size(side .. "UpperArm", Vector3.new(0.34 * s, (el - sh).Magnitude, 0.34 * s))
			size(side .. "LowerArm", Vector3.new(0.3 * s, (he - el).Magnitude, 0.3 * s))
			size(side .. "UpperLeg", Vector3.new(0.45 * s, (kn - hip).Magnitude, 0.45 * s))
			size(side .. "LowerLeg", Vector3.new(0.36 * s, (gr - kn).Magnitude, 0.36 * s))
			setJoint(model, side .. "UpperArm", side .. "Shoulder", C.Torso, C[side .. "UpperArm"], sh)
			setJoint(model, side .. "LowerArm", side .. "Elbow", C[side .. "UpperArm"], C[side .. "LowerArm"], el)
			setJoint(model, side .. "UpperLeg", side .. "Hip", C.HumanoidRootPart, C[side .. "UpperLeg"], hip)
			setJoint(model, side .. "LowerLeg", side .. "Knee", C[side .. "UpperLeg"], C[side .. "LowerLeg"], kn)
		end
	end
	-- the rest of the body follows the root: place every bone around it
	if root then
		local rootCF = root.CFrame
		for name, centre in C do
			local part = model:FindFirstChild(name)
			if part and part ~= root then
				part.CFrame = rootCF * CFrame.new(centre - C.HumanoidRootPart)
			end
		end
		return J.root.Y - root.Size.Y / 2
	end
	return nil
end

-- getPart(name) -> MeshPart clone or nil. Returns true if every segment was fitted.
-- colorOverrides (optional): { [layerName] = Color3 } for outfits.
function MeshKit.applyRig(model, meta, getPart, format, yawFix, colorOverrides)
	local own, byParent = jointsOf(model)
	local scales = {}
	local fitted = {}
	local yaw = yawFix and CFrame.Angles(0, math.rad(yawFix), 0) or MeshKit.yaw
	for _, segName in ORDER[format] do
		local seg = meta.segments[segName]
		local bone = segName == "Pelvis" and model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild(segName)
		if seg and bone then
			-- actual anchor positions in the bone's local space
			local ownJoint = own[bone]
			local A = ownJoint and ownJoint.C1.Position or Vector3.zero
			local B
			local childName = CHILD[format][segName]
			local childJoint = childName and byParent[bone] and byParent[bone][childName]
			if childJoint then
				B = childJoint.C0.Position
			elseif seg.bottom and ownJoint then
				B = Vector3.new(A.X, A.Y - bone.Size.Y, A.Z) -- limb ends at the bottom of the part
			end
			local s
			if B and seg.top and seg.bottom then
				local canon = (v3(seg.bottom) - v3(seg.top)).Magnitude
				s = canon > 0.01 and (B - A).Magnitude / canon or 1
			else
				s = scales[SCALE_FROM[format][segName] or ""] or 1
			end
			scales[segName] = s
			local top = seg.top and v3(seg.top) or Vector3.zero
			for layerName, layer in seg.layers do
				local mp = getPart(layer.part)
				if mp then
					mp.Name = "Mesh_" .. segName .. "_" .. layerName
					mp.Size = v3(layer.size) * s
					mp.Material = material(layer.material)
					mp.Color = (colorOverrides and colorOverrides[layerName]) or Color3.new(layer.color[1], layer.color[2], layer.color[3])
					mp.Anchored = false
					mp.CanCollide = false
					mp.CanQuery = false
					mp.CanTouch = false
					mp.Massless = true
					mp.CastShadow = true
					local offset = A + (v3(layer.center) - top) * s
					mp.CFrame = bone.CFrame * CFrame.new(offset) * yaw
					local weld = Instance.new("Weld")
					weld.Part0 = bone
					weld.Part1 = mp
					weld.C0 = CFrame.new(offset) * yaw
					weld.Parent = mp
					mp.Parent = model
				end
			end
			fitted[bone] = true
		end
	end
	-- hide the original body parts (keep them for joints, physics and hit detection)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" and not d.Name:match("^Mesh_") and d.Parent == model then
			d.Transparency = 1
		elseif d:IsA("Decal") then
			d.Transparency = 1
		elseif d:IsA("BasePart") and d.Parent ~= model and not d:FindFirstAncestorWhichIsA("Model").Name:match("^Weapon_") then
			d.Transparency = 1
		end
	end
	return true
end

-- Rotation applied to every imported mesh in place (set from AssetIds.YawFix at start-up).
MeshKit.yaw = CFrame.new()
function MeshKit.setYawFix(degrees)
	MeshKit.yaw = CFrame.Angles(0, math.rad(degrees or 0), 0)
end

-- Builds a static prop model (anchored) at `cframe` with uniform `scale`.
-- Props are generated with their base at y = 0, so cframe is the ground point.
function MeshKit.buildProp(meta, getPart, cframe, scale, parent)
	local model = Instance.new("Model")
	local any = false
	for layerName, layer in meta.layers do
		local mp = getPart(layer.part)
		if mp then
			mp.Name = layerName
			mp.Size = v3(layer.size) * scale
			mp.Material = material(layer.material)
			mp.Color = Color3.new(layer.color[1], layer.color[2], layer.color[3])
			mp.Anchored = true
			mp.CFrame = cframe * CFrame.new(v3(layer.center) * scale) * MeshKit.yaw
			mp.Parent = model
			any = true
		end
	end
	if not any then
		model:Destroy()
		return nil
	end
	model.Parent = parent
	return model
end

-- Welds weapon / tool layers onto a grip part (grip = origin, barrel along -Z).
function MeshKit.attachToGrip(meta, getPart, grip, skip)
	local any = false
	for layerName, layer in meta.layers do
		if not (skip and skip[layerName]) then
			local mp = getPart(layer.part)
			if mp then
				mp.Name = "Mesh_" .. layerName
				mp.Size = v3(layer.size)
				mp.Material = material(layer.material)
				mp.Color = Color3.new(layer.color[1], layer.color[2], layer.color[3])
				mp.Anchored = false
				mp.CanCollide = false
				mp.CanQuery = false
				mp.CanTouch = false
				mp.Massless = true
				mp.CFrame = grip.CFrame * CFrame.new(v3(layer.center)) * MeshKit.yaw
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = grip
				weld.Part1 = mp
				weld.Parent = mp
				mp.Parent = grip.Parent
				any = true
			end
		end
	end
	return any
end

return MeshKit
