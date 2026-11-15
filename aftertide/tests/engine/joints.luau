local out = {}
local ok, v = pcall(function()
	return tostring(workspace.AvatarJointUpgrade)
end)
out.avatarJointUpgrade = ok and v or ("unreadable: " .. tostring(v))
local desc = Instance.new("HumanoidDescription")
local rig = Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
rig.Parent = workspace
local classes = {}
for _, d in rig:GetDescendants() do
	if d:IsA("Constraint") or d:IsA("JointInstance") or d:IsA("AnimationConstraint") then
		local key = d.ClassName .. ":" .. d.Name .. " in " .. d.Parent.Name
		table.insert(classes, key)
	end
end
table.sort(classes)
out.joints = classes
out.enumItems = {}
pcall(function()
	for _, item in Enum.AvatarJointUpgrade:GetEnumItems() do
		table.insert(out.enumItems, item.Name .. "=" .. item.Value)
	end
end)
local okSet, errSet = pcall(function()
	workspace.AvatarJointUpgrade = Enum.AvatarJointUpgrade.Disabled
end)
out.canSetAtRuntime = okSet and "yes" or tostring(errSet)
return out
