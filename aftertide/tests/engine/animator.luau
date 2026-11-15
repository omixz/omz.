-- Runs one frame of the client's procedural animator on a fitted rig holding a carbine, aimed.
local AssetService = registry.AssetService
AssetService.load()
local MeshKit = require(Shared.MeshKit)
local WeaponModels = require(Shared.WeaponModels)
local desc = Instance.new("HumanoidDescription")
local rig = Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
rig.Parent = workspace
rig:PivotTo(CFrame.new(0, 20, 0))
local meta = AssetService.meta("Crew_mara")
MeshKit.conformSkeleton(rig, meta, "r15", 0.88)
MeshKit.applyRig(rig, meta, AssetService.part, "r15", 0, {})
local gun = WeaponModels.build("carbine", AssetService.part, AssetService.meta("Weapon_carbine"))
gun.Name = "Weapon_long"
gun:PivotTo(rig:GetPivot())
gun.Parent = rig
local weld = Instance.new("Weld")
weld.Name = "Mount"
weld.Part0 = rig.RightHand
weld.Part1 = gun.PrimaryPart
weld.C0 = WeaponModels.HandOffset
weld.Parent = gun.PrimaryPart
rig:SetAttribute("Procedural", true)
rig:SetAttribute("Equipped", "carbine")
rig:SetAttribute("EquippedSlot", "long")
rig:SetAttribute("Aim", true)
rig:SetAttribute("Stance", "Stand")
local State = require(ClientFolder.State)
State.aiming = true
State.pitch = 0
local PlayerAnimator = require(ClientFolder.Controllers.PlayerAnimator)
local results = {}
for frame = 1, 30 do -- let the blends settle
	local ok, err = PlayerAnimator.debugAnimate(rig, true)
	if not ok then
		results.error = tostring(err)
		break
	end
end
local pieces, bones = posedPieces(rig)
-- the gun's pieces are welded to its grip, which the animator re-welds to the torso
local gunPieces = {}
local mount = gun.PrimaryPart:FindFirstChild("Mount")
results.mount = mount and { part0 = mount.Part0 and mount.Part0.Name, c0 = cf12(mount.C0) } or nil
results.pieces = pieces
results.bones = bones
return results
