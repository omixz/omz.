--!nonstrict
-- Builds a sculpted, clothed body over the (hidden) R15 skeleton so the crew don't look like
-- Roblox avatars: tapered limbs, shaped torso, jacket, trousers, boots, backpack, a hat or
-- hood, and a fog mask over the lower face (everyone wears one against the Pall).
-- Every piece is welded to an R15 part, so animation, weapons and gameplay keep working.
-- When you make real meshes (docs/07-characters-and-graphics.md), custom rigs replace this.
local BodyBuilder = {}

local SKIN_MAT = Enum.Material.SmoothPlastic
local CLOTH = Enum.Material.Fabric
local LEATHER = Enum.Material.Leather

local function piece(char, attachTo, name, size, offset, color, material, shape, mesh)
	local p = Instance.new("Part")
	p.Name = "Body_" .. name
	p.Size = size
	p.Color = color
	p.Material = material or CLOTH
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	if mesh then
		local m = Instance.new("SpecialMesh")
		m.MeshType = mesh
		m.Parent = p
	end
	p.CFrame = attachTo.CFrame * offset
	local w = Instance.new("Weld")
	w.Part0 = attachTo
	w.Part1 = p
	w.C0 = offset
	w.Parent = p
	p.Parent = char
	return p
end

-- vertical capsule-ish limb: cylinder along the part's Y axis + rounded end
local function limb(char, part, name, lengthMul, dia, color, material, yOffset)
	local len = part.Size.Y * lengthMul
	piece(char, part, name, Vector3.new(len, dia, dia), CFrame.new(0, yOffset or 0, 0) * CFrame.Angles(0, 0, math.rad(90)), color, material, Enum.PartType.Cylinder)
	piece(char, part, name .. "End", Vector3.new(dia, dia, dia), CFrame.new(0, (yOffset or 0) - len / 2, 0), color, material, Enum.PartType.Ball)
end

local function ellipsoid(char, part, name, size, offset, color, material)
	return piece(char, part, name, size, offset, color, material, nil, Enum.MeshType.Sphere)
end

function BodyBuilder.build(char, def)
	local c = def.colors
	local o = def.outfit or {}
	local skin, jacket, trousers = c.skin, c.torso, c.legs
	local boots = o.boots or Color3.fromRGB(40, 34, 30)
	local get = function(n)
		return char:FindFirstChild(n)
	end
	local head, ut, lt = get("Head"), get("UpperTorso"), get("LowerTorso")
	if not head or not ut or not lt then
		return false
	end

	-- hide the Roblox body (keep it for joints, physics and hit detection)
	for _, d in char:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" and not d.Name:match("^Body_") and not d:FindFirstAncestorWhichIsA("Model").Name:match("^Weapon_") then
			d.Transparency = 1
		elseif d:IsA("Decal") then
			d.Transparency = 1
		end
	end

	-- head: skull, ears, eyes, hair / hat, fog mask
	local H = head.Size
	local hw = math.min(H.X, H.Z)
	ellipsoid(char, head, "Skull", Vector3.new(hw * 0.74, H.Y * 0.98, hw * 0.84), CFrame.new(0, 0.02, 0), skin, SKIN_MAT)
	for _, sx in { -1, 1 } do
		ellipsoid(char, head, "Ear", Vector3.new(0.08, hw * 0.2, hw * 0.13), CFrame.new(sx * hw * 0.37, 0, 0.02), skin, SKIN_MAT)
		ellipsoid(char, head, "Eye", Vector3.new(hw * 0.09, hw * 0.05, 0.04), CFrame.new(sx * hw * 0.14, H.Y * 0.06, -hw * 0.41), Color3.fromRGB(26, 22, 20), SKIN_MAT)
		ellipsoid(char, head, "Brow", Vector3.new(hw * 0.14, hw * 0.035, 0.05), CFrame.new(sx * hw * 0.14, H.Y * 0.14, -hw * 0.395) * CFrame.Angles(0, 0, sx * -0.12), o.hair or Color3.fromRGB(40, 30, 24), SKIN_MAT)
	end
	ellipsoid(char, head, "Mask", Vector3.new(hw * 0.8, H.Y * 0.5, hw * 0.74), CFrame.new(0, -H.Y * 0.2, -hw * 0.1), o.mask or Color3.fromRGB(110, 104, 94), CLOTH)
	local hat = o.hat
	if hat == "beanie" then
		ellipsoid(char, head, "Beanie", Vector3.new(hw * 0.82, H.Y * 0.6, hw * 0.9), CFrame.new(0, H.Y * 0.26, 0.02), o.hatColor, CLOTH)
		piece(char, head, "BeanieCuff", Vector3.new(0.18, hw * 0.86, hw * 0.86), CFrame.new(0, H.Y * 0.08, 0.02) * CFrame.Angles(0, 0, math.rad(90)), o.hatColor, CLOTH, Enum.PartType.Cylinder)
	elseif hat == "cap" then
		ellipsoid(char, head, "Cap", Vector3.new(hw * 0.8, H.Y * 0.5, hw * 0.88), CFrame.new(0, H.Y * 0.25, 0.02), o.hatColor, CLOTH)
		piece(char, head, "Brim", Vector3.new(hw * 0.6, 0.06, hw * 0.45), CFrame.new(0, H.Y * 0.16, -hw * 0.5) * CFrame.Angles(math.rad(-8), 0, 0), o.hatColor, CLOTH)
		ellipsoid(char, head, "HairBack", Vector3.new(hw * 0.72, H.Y * 0.45, hw * 0.4), CFrame.new(0, H.Y * 0.02, hw * 0.28), o.hair, CLOTH)
	elseif hat == "bun" then
		ellipsoid(char, head, "Hair", Vector3.new(hw * 0.8, H.Y * 0.62, hw * 0.9), CFrame.new(0, H.Y * 0.22, 0.04), o.hair, CLOTH)
		ellipsoid(char, head, "Bun", Vector3.new(hw * 0.36, hw * 0.36, hw * 0.36), CFrame.new(0, H.Y * 0.3, hw * 0.44), o.hair, CLOTH)
	elseif hat == "hood" then
		ellipsoid(char, head, "Hood", Vector3.new(hw * 0.98, H.Y * 1.08, hw * 1.02), CFrame.new(0, H.Y * 0.08, 0.1), o.hatColor, CLOTH)
	end

	-- torso: shaped chest, shoulders, collar, zip, pockets
	local T = ut.Size
	piece(char, ut, "Chest", Vector3.new(T.X * 0.74, T.Y * 0.96, T.Z * 0.66), CFrame.new(0, 0, 0), jacket, CLOTH)
	ellipsoid(char, ut, "ChestFront", Vector3.new(T.X * 0.72, T.Y * 0.7, T.Z * 0.3), CFrame.new(0, T.Y * 0.08, -T.Z * 0.3), jacket, CLOTH)
	for _, sx in { -1, 1 } do
		piece(char, ut, "Shoulder", Vector3.new(T.Y * 0.44, T.Y * 0.44, T.Y * 0.44), CFrame.new(sx * T.X * 0.36, T.Y * 0.28, 0), jacket, CLOTH, Enum.PartType.Ball)
		piece(char, ut, "Pocket", Vector3.new(T.X * 0.18, T.Y * 0.16, 0.06), CFrame.new(sx * T.X * 0.18, -T.Y * 0.24, -T.Z * 0.34), Color3.new(jacket.R * 0.85, jacket.G * 0.85, jacket.B * 0.85), CLOTH)
		-- backpack straps over the shoulders
		piece(char, ut, "Strap", Vector3.new(0.12, T.Y * 0.9, 0.08), CFrame.new(sx * T.X * 0.2, 0.02, -T.Z * 0.35), Color3.fromRGB(42, 36, 30), LEATHER)
	end
	piece(char, ut, "Collar", Vector3.new(0.3, hw * 0.62, hw * 0.62), CFrame.new(0, T.Y * 0.5, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.new(jacket.R * 0.9, jacket.G * 0.9, jacket.B * 0.9), CLOTH, Enum.PartType.Cylinder)
	piece(char, ut, "Neck", Vector3.new(0.45, hw * 0.36, hw * 0.36), CFrame.new(0, T.Y * 0.6, 0) * CFrame.Angles(0, 0, math.rad(90)), skin, SKIN_MAT, Enum.PartType.Cylinder)
	piece(char, ut, "Zip", Vector3.new(0.05, T.Y * 0.9, 0.04), CFrame.new(0, 0, -T.Z * 0.45), Color3.fromRGB(30, 30, 30), Enum.Material.Metal)
	if o.scarf then
		piece(char, ut, "Scarf", Vector3.new(0.36, hw * 0.75, hw * 0.75), CFrame.new(0, T.Y * 0.46, -0.02) * CFrame.Angles(0, 0, math.rad(90)), o.scarf, CLOTH, Enum.PartType.Cylinder)
		piece(char, ut, "ScarfTail", Vector3.new(0.22, T.Y * 0.6, 0.08), CFrame.new(T.X * 0.12, T.Y * 0.05, -T.Z * 0.42) * CFrame.Angles(0, 0, math.rad(-6)), o.scarf, CLOTH)
	end
	if o.medic then
		piece(char, ut, "MedicBand", Vector3.new(0.26, hw * 0.5, hw * 0.5), CFrame.new(-T.X * 0.42, T.Y * 0.05, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(220, 214, 200), CLOTH, Enum.PartType.Cylinder)
	end

	-- backpack with bedroll
	local pack = o.pack or Color3.fromRGB(80, 76, 60)
	piece(char, ut, "Pack", Vector3.new(T.X * 0.6, T.Y * 0.78, 0.48), CFrame.new(0, -T.Y * 0.04, T.Z * 0.33 + 0.24), pack, CLOTH)
	piece(char, ut, "PackPocket", Vector3.new(T.X * 0.4, T.Y * 0.3, 0.16), CFrame.new(0, -T.Y * 0.18, T.Z * 0.33 + 0.55), Color3.new(pack.R * 0.85, pack.G * 0.85, pack.B * 0.85), CLOTH)
	piece(char, ut, "Bedroll", Vector3.new(T.X * 0.78, 0.4, 0.4), CFrame.new(0, T.Y * 0.42, T.Z * 0.33 + 0.24), Color3.fromRGB(110, 96, 74), CLOTH, Enum.PartType.Cylinder)

	-- hips, belt
	local L = lt.Size
	piece(char, lt, "Hips", Vector3.new(L.X * 0.74, L.Y * 1.9, T.Z * 0.62), CFrame.new(0, -L.Y * 0.2, 0), trousers, CLOTH)
	piece(char, lt, "Belt", Vector3.new(L.X * 0.77, 0.14, T.Z * 0.65), CFrame.new(0, L.Y * 0.4, 0), Color3.fromRGB(42, 34, 28), LEATHER)
	piece(char, lt, "Buckle", Vector3.new(0.16, 0.12, 0.05), CFrame.new(0, L.Y * 0.4, -T.Z * 0.33), Color3.fromRGB(150, 140, 110), Enum.Material.Metal)
	if o.toolbelt then
		for i, x in { -0.3, 0.32 } do
			piece(char, lt, "Tool" .. i, Vector3.new(0.18, 0.4, 0.22), CFrame.new(x * L.X, 0, -T.Z * 0.3), Color3.fromRGB(70, 56, 40), LEATHER)
		end
	end

	-- arms & hands
	for _, side in { "Left", "Right" } do
		local ua, la, hand = get(side .. "UpperArm"), get(side .. "LowerArm"), get(side .. "Hand")
		if ua then
			limb(char, ua, side .. "Sleeve", 1.0, math.min(ua.Size.X, ua.Size.Z) * 0.56, jacket, CLOTH)
		end
		if la then
			limb(char, la, side .. "Forearm", 1.0, math.min(la.Size.X, la.Size.Z) * 0.5, jacket, CLOTH)
			piece(char, la, side .. "Cuff", Vector3.new(0.16, math.min(la.Size.X, la.Size.Z) * 0.56, math.min(la.Size.X, la.Size.Z) * 0.56), CFrame.new(0, -la.Size.Y * 0.45, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.new(jacket.R * 0.8, jacket.G * 0.8, jacket.B * 0.8), CLOTH, Enum.PartType.Cylinder)
		end
		if hand then
			local w = math.min(hand.Size.X, hand.Size.Z)
			piece(char, hand, side .. "Palm", Vector3.new(w * 0.36, hand.Size.Y * 1.5, w * 0.5), CFrame.new(0, -hand.Size.Y * 0.2, 0), skin, SKIN_MAT)
			ellipsoid(char, hand, side .. "Fingers", Vector3.new(w * 0.34, hand.Size.Y * 0.9, w * 0.46), CFrame.new(0, -hand.Size.Y * 0.95, -0.02), skin, SKIN_MAT)
			ellipsoid(char, hand, side .. "Thumb", Vector3.new(0.12, hand.Size.Y * 0.8, 0.12), CFrame.new(0, -hand.Size.Y * 0.3, -w * 0.28), skin, SKIN_MAT)
		end
	end

	-- legs & boots
	for _, side in { "Left", "Right" } do
		local ul, ll, foot = get(side .. "UpperLeg"), get(side .. "LowerLeg"), get(side .. "Foot")
		if ul then
			limb(char, ul, side .. "Thigh", 1.02, math.min(ul.Size.X, ul.Size.Z) * 0.66, trousers, CLOTH)
		end
		if ll then
			local d = math.min(ll.Size.X, ll.Size.Z)
			limb(char, ll, side .. "Shin", 1.0, d * 0.54, trousers, CLOTH)
			piece(char, ll, side .. "BootShaft", Vector3.new(ll.Size.Y * 0.42, d * 0.6, d * 0.6), CFrame.new(0, -ll.Size.Y * 0.32, 0) * CFrame.Angles(0, 0, math.rad(90)), boots, LEATHER, Enum.PartType.Cylinder)
		end
		if foot then
			local F = foot.Size
			piece(char, foot, side .. "Boot", Vector3.new(F.X * 0.56, F.Y * 1.3, F.Z * 0.95), CFrame.new(0, -F.Y * 0.1, -F.Z * 0.06), boots, LEATHER)
			ellipsoid(char, foot, side .. "Toe", Vector3.new(F.X * 0.56, F.Y * 1.25, F.Z * 0.5), CFrame.new(0, -F.Y * 0.12, -F.Z * 0.48), boots, LEATHER)
			piece(char, foot, side .. "Sole", Vector3.new(F.X * 0.6, 0.08, F.Z * 1.1), CFrame.new(0, -F.Y * 0.72, -F.Z * 0.12), Color3.fromRGB(24, 22, 20), Enum.Material.Rubber)
		end
	end
	return true
end

return BodyBuilder
