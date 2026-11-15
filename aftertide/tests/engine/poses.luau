-- Runs the client's procedural animator through several poses on a fitted rig that carries a
-- carbine (long slot) and a revolver (sidearm), mounted the way the server mounts them, and
-- exports every posed piece (body and both guns) per pose.
local AssetService = registry.AssetService
AssetService.load()
local MeshKit = require(Shared.MeshKit)
local WeaponModels = require(Shared.WeaponModels)
local rig = Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
rig.Parent = workspace
rig:PivotTo(CFrame.new(0, 20, 0))
local meta = AssetService.meta("Crew_mara")
local hip = MeshKit.conformSkeleton(rig, meta, "r15", 0.88)
rig.Humanoid.HipHeight = hip
rig:SetAttribute("BaseHipHeight", hip)
MeshKit.applyRig(rig, meta, AssetService.part, "r15", 0, {})
local guns = {}
for slot, id in { long = LONG_GUN or "carbine", sidearm = "revolver" } do
	local gun = WeaponModels.build(id, AssetService.part, AssetService.meta("Weapon_" .. id))
	gun.Name = "Weapon_" .. slot
	gun:PivotTo(rig:GetPivot())
	gun.Parent = rig
	local weld = Instance.new("Weld")
	weld.Name = "Mount"
	weld.Part1 = gun.PrimaryPart
	weld.Parent = gun.PrimaryPart
	guns[slot] = gun
end
local function mountAll(equippedSlot)
	for slot, gun in guns do
		local w = gun.PrimaryPart.Mount
		if slot == equippedSlot then
			w.Part0, w.C0 = rig.RightHand, WeaponModels.HandOffset
		elseif slot == "long" then
			w.Part0, w.C0 = rig.UpperTorso, WeaponModels.BackOffset
		else
			w.Part0, w.C0 = rig.LowerTorso, WeaponModels.HipOffset
		end
		w.C1 = CFrame.new()
	end
end
rig:SetAttribute("Procedural", true)
local State = require(ClientFolder.State)
local PlayerAnimator = require(ClientFolder.Controllers.PlayerAnimator)
local now = workspace:GetServerTimeNow()
NOW = now
local SCEN = SCENARIOS or {
	{ name = "aim_long", slot = "long", aim = true },
	{ name = "ready_long", slot = "long" },
	{ name = "sidearm_holstered_long", slot = "sidearm" },
	{ name = "aim_sidearm", slot = "sidearm", aim = true },
	{ name = "reload_long", slot = "long", attrs = { ReloadUntil = now + 100 } },
	{ name = "heal", slot = "sidearm", attrs = { HealAt = now - 1.0 } },
	{ name = "prone_sidearm", slot = "sidearm", prone = true },
	{ name = "crouch_long", slot = "long", crouch = true },
	{ name = "vault", slot = "sidearm", attrs = { VaultAt = now - 0.4 } },
	{ name = "jump_up", slot = "long", vel = Vector3.new(0, 14, 0) },
}
if ACTION_TEST then
	-- each gun mid-action: just fired (lever / pump / bolt / cylinder), and half-way through a reload
	SCEN = {
		{ name = "fired_long", slot = "long", aim = true, shotAge = 0.42 },
		{ name = "reload_long_mid", slot = "long", attrs = { ReloadUntil = now + 1.2 }, reloadDur = 3 },
		{ name = "fired_sidearm", slot = "sidearm", aim = true, shotAge = 0.12 },
		{ name = "reload_sidearm_mid", slot = "sidearm", attrs = { ReloadUntil = now + 1.2 }, reloadDur = 2.5 },
	}
end
local out = { scenarios = {} }
for _, sc in SCEN do
	rig.HumanoidRootPart.AssemblyLinearVelocity = sc.vel or Vector3.zero
	for _, a in { "ReloadUntil", "HealAt", "ReloadDur", "VaultAt" } do
		rig:SetAttribute(a, nil)
	end
	for k, v in sc.attrs or {} do
		rig:SetAttribute(k, v)
	end
	rig:SetAttribute("Equipped", sc.slot == "long" and (LONG_GUN or "carbine") or "revolver")
	rig:SetAttribute("ReloadDur", sc.reloadDur)
	rig:SetAttribute("EquippedSlot", sc.slot)
	mountAll(sc.slot)
	State.aiming = sc.aim == true
	State.prone = sc.prone == true
	State.crouched = sc.crouch == true
	State.pitch = 0
	local err
	for _ = 1, 45 do
		if sc.shotAge then
			PlayerAnimator.debugShotAge(rig, sc.shotAge)
		end
		local ok, e = PlayerAnimator.debugAnimate(rig, true, true)
		if not ok then
			err = tostring(e)
			break
		end
	end
	local pieces, bones = posedPieces(rig)
	for _, gun in guns do
		local w = gun.PrimaryPart.Mount
		local b = w.Part0 and bones[w.Part0.Name]
		local base = b and CFrame.new(table.unpack(b.cframe)) or (w.Part0 and w.Part0.CFrame)
		if base then
			local gripCF = base * w.C0 * w.C1:Inverse()
			for _, mp in gun:GetDescendants() do
				if mp:IsA("MeshPart") then
					local aw = mp:FindFirstChild("AnimWeld")
					local rel = aw and (aw.C0 * aw.C1:Inverse()) or gun.PrimaryPart.CFrame:ToObjectSpace(mp.CFrame)
					table.insert(pieces, { name = gun.Name .. "." .. mp.Name, cframe = cf12(gripCF * rel), size = v3t(mp.Size), source = mp:GetAttribute("SourceName"), fitRot = mp:GetAttribute("FitRot") and cf12(mp:GetAttribute("FitRot")) or nil })
				end
			end
		end
	end
	out.scenarios[sc.name] = { error = err, pieces = pieces, mount = guns.long.PrimaryPart.Mount.Part0 and guns.long.PrimaryPart.Mount.Part0.Name }
end
return out
