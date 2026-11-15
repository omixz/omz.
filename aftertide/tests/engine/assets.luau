-- Loads the uploaded packs, fits Crew_mara onto a real R15 rig, exports every piece.
local AssetService = registry.AssetService
AssetService.load()
local MeshKit = require(Shared.MeshKit)
local report = AssetService.report()

local desc = Instance.new("HumanoidDescription")
local rig = Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
rig.Parent = workspace
rig:PivotTo(CFrame.new(0, 20, 0))
local kit = "Crew_mara"
local meta = AssetService.meta(kit)
local hip = MeshKit.conformSkeleton(rig, meta, "r15", 0.88)
MeshKit.applyRig(rig, meta, AssetService.part, "r15", 0, {})
local pieces, bones = posedPieces(rig)

-- real vertices of a few imported meshes (if the engine lets us read them)
local samples = {}
local AS = game:GetService("AssetService")
for _, p in pieces do
	if #samples >= 40 then
		break
	end
	local mp = rig:FindFirstChild(p.name)
	if mp then
		local ok, em = pcall(function()
			return AS:CreateEditableMeshAsync(Content.fromUri(mp.MeshId))
		end)
		if ok and em then
			local pts = {}
			local ids = em:GetVertices()
			local step = math.max(1, math.floor(#ids / 120))
			for i = 1, #ids, step do
				table.insert(pts, v3t(em:GetPosition(ids[i])))
			end
			table.insert(samples, { name = p.name, points = pts })
		else
			samples.error = tostring(em)
		end
	end
end
return { report = report, hip = hip, pieces = pieces, bones = bones, samples = samples, kit = kit }
