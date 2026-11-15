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

local samples = {} -- (reading real vertices needs EditableMesh enabled in Experience Settings > Security)
return { report = report, hip = hip, pieces = pieces, bones = bones, samples = samples, kit = kit }
