--!nonstrict
-- Builds stylised weapon models from parts (placeholders until Stage 5 meshes).
-- Each model: PrimaryPart "Grip" (held in the right hand), barrel along -Z, and an
-- Attachment "Muzzle" at the barrel tip. Parts are massless and ignored by raycasts.
local WeaponModels = {}

local METAL = Color3.fromRGB(44, 46, 50)
local STEEL = Color3.fromRGB(88, 90, 94)
local WOOD = Color3.fromRGB(96, 64, 42)
local DARKWOOD = Color3.fromRGB(70, 46, 32)
local BONE = Color3.fromRGB(214, 206, 188)

-- { size, offset CFrame from grip, color, material, shape? }
local SPECS = {
	revolver = {
		muzzle = Vector3.new(0, 0.38, -1.25),
		parts = {
			{ Vector3.new(0.24, 0.55, 0.34), CFrame.new(0, 0, 0.05) * CFrame.Angles(math.rad(-12), 0, 0), DARKWOOD, Enum.Material.Wood },
			{ Vector3.new(0.22, 0.34, 0.7), CFrame.new(0, 0.3, -0.25), METAL, Enum.Material.Metal },
			{ Vector3.new(0.36, 0.32, 0.32), CFrame.new(0, 0.3, -0.2) * CFrame.Angles(0, math.rad(90), 0), STEEL, Enum.Material.Metal, Enum.PartType.Cylinder },
			{ Vector3.new(0.14, 0.14, 0.82), CFrame.new(0, 0.38, -0.85), METAL, Enum.Material.Metal },
		},
	},
	rifle = {
		muzzle = Vector3.new(0, 0.18, -2.85),
		parts = {
			{ Vector3.new(0.24, 0.45, 1.2), CFrame.new(0, -0.02, 0.75), WOOD, Enum.Material.Wood },
			{ Vector3.new(0.22, 0.28, 1.1), CFrame.new(0, 0.15, -0.4), WOOD, Enum.Material.Wood },
			{ Vector3.new(0.18, 0.2, 0.9), CFrame.new(0, 0.3, -0.25), METAL, Enum.Material.Metal },
			{ Vector3.new(0.12, 0.12, 1.9), CFrame.new(0, 0.18, -1.9), METAL, Enum.Material.Metal },
			{ Vector3.new(0.06, 0.06, 0.3), CFrame.new(0.16, 0.32, 0.05), STEEL, Enum.Material.Metal }, -- bolt
		},
	},
	carbine = {
		muzzle = Vector3.new(0, 0.2, -2.2),
		parts = {
			{ Vector3.new(0.24, 0.42, 1.0), CFrame.new(0, -0.02, 0.65), WOOD, Enum.Material.Wood },
			{ Vector3.new(0.22, 0.3, 0.9), CFrame.new(0, 0.15, -0.3), METAL, Enum.Material.Metal },
			{ Vector3.new(0.13, 0.13, 1.5), CFrame.new(0, 0.22, -1.45), METAL, Enum.Material.Metal },
			{ Vector3.new(0.15, 0.15, 1.2), CFrame.new(0, 0.06, -1.3), WOOD, Enum.Material.Wood }, -- fore-end
			{ Vector3.new(0.08, 0.26, 0.36), CFrame.new(0, -0.17, -0.1), STEEL, Enum.Material.Metal }, -- lever
		},
	},
	shotgun = {
		muzzle = Vector3.new(0, 0.22, -2.3),
		parts = {
			{ Vector3.new(0.26, 0.45, 1.0), CFrame.new(0, -0.02, 0.6), DARKWOOD, Enum.Material.Wood },
			{ Vector3.new(0.26, 0.32, 0.9), CFrame.new(0, 0.15, -0.35), METAL, Enum.Material.Metal },
			{ Vector3.new(0.18, 0.18, 1.6), CFrame.new(0, 0.24, -1.5), METAL, Enum.Material.Metal },
			{ Vector3.new(0.16, 0.16, 1.4), CFrame.new(0, 0.06, -1.4), STEEL, Enum.Material.Metal }, -- magazine tube
			{ Vector3.new(0.26, 0.24, 0.6), CFrame.new(0, 0.06, -1.25), DARKWOOD, Enum.Material.Wood }, -- pump
		},
	},
	bow = {
		muzzle = Vector3.new(0, 0.1, -0.5),
		parts = {
			{ Vector3.new(0.2, 0.6, 0.26), CFrame.new(0, 0, 0), DARKWOOD, Enum.Material.Wood },
			{ Vector3.new(0.12, 1.8, 0.18), CFrame.new(0, 1.15, 0.12) * CFrame.Angles(math.rad(-14), 0, 0), WOOD, Enum.Material.Wood },
			{ Vector3.new(0.12, 1.8, 0.18), CFrame.new(0, -1.15, 0.12) * CFrame.Angles(math.rad(14), 0, 0), WOOD, Enum.Material.Wood },
			{ Vector3.new(0.03, 4.1, 0.03), CFrame.new(0, 0, 0.5), BONE, Enum.Material.Fabric },
			{ Vector3.new(0.05, 0.05, 1.6), CFrame.new(0, 0.1, -0.2), BONE, Enum.Material.Wood }, -- nocked arrow
		},
	},
}

local function prep(part)
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
end

function WeaponModels.build(weaponId)
	local spec = SPECS[weaponId]
	if not spec then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = "Weapon_" .. weaponId

	local grip = Instance.new("Part")
	grip.Name = "Grip"
	grip.Size = Vector3.new(0.2, 0.2, 0.2)
	grip.Transparency = 1
	grip.CFrame = CFrame.new()
	prep(grip)
	grip.Parent = model
	model.PrimaryPart = grip

	for i, p in spec.parts do
		local part = Instance.new("Part")
		part.Name = "Piece" .. i
		part.Size = p[1]
		part.CFrame = p[2]
		part.Color = p[3]
		part.Material = p[4]
		if p[5] then
			part.Shape = p[5]
		end
		prep(part)
		part.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = grip
		weld.Part1 = part
		weld.Parent = part
	end

	local muzzle = Instance.new("Attachment")
	muzzle.Name = "Muzzle"
	muzzle.Position = spec.muzzle
	muzzle.Parent = grip
	return model
end

-- Where each weapon sits relative to its parent part.
WeaponModels.HandOffset = CFrame.new(0, -0.15, 0) * CFrame.Angles(-math.pi / 2, 0, 0)
WeaponModels.BackOffset = CFrame.new(0, 0, 0.62) * CFrame.Angles(0, 0, math.rad(35)) * CFrame.Angles(math.rad(90), 0, 0)
WeaponModels.HipOffset = CFrame.new(0.95, -0.2, 0) * CFrame.Angles(math.rad(-90), 0, 0)

return WeaponModels
