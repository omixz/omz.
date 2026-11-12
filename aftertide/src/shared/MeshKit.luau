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

-- getPart(name) -> MeshPart clone or nil. Returns true if every segment was fitted.
function MeshKit.applyRig(model, meta, getPart, format, yawFix)
	local own, byParent = jointsOf(model)
	local scales = {}
	local fitted = {}
	local yaw = CFrame.Angles(0, math.rad(yawFix or 0), 0)
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
					mp.Color = Color3.new(layer.color[1], layer.color[2], layer.color[3])
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
			mp.CFrame = cframe * CFrame.new(v3(layer.center) * scale)
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
				mp.CFrame = grip.CFrame * CFrame.new(v3(layer.center))
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
