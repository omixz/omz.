-- Does the vault probe find low walls and refuse tall ones / open ground? Uses the real maps.
local AssetService = registry.AssetService
AssetService.load()
local MapService = registry.MapService
local MapKit = require(ServerScriptService.Server.Maps.MapKit)
MapKit.setAssets(AssetService)
local world = Instance.new("Folder")
world.Name = "World"
world.Parent = workspace
MapService.loadMap("CanneryRow", Random.new(7))
task.wait(0.3)
local State = require(ClientFolder.State)
local Movement = require(ClientFolder.Controllers.MovementController)
local rig = Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
rig.Parent = workspace
local out = {}
local function try(label, pos, dir)
	rig:PivotTo(CFrame.new(pos))
	State.character, State.humanoid, State.root = rig, rig.Humanoid, rig.HumanoidRootPart
	local ok, res = pcall(Movement.debugProbe, dir)
	table.insert(out, { label = label, ok = ok, result = ok and res or tostring(res) })
end
local standY = 5.3
try("low concrete wall (3.5 high) at z=25, from the south", Vector3.new(-20, standY, 21), Vector3.new(0, 0, 1))
try("same wall from the north side", Vector3.new(-20, standY, 29), Vector3.new(0, 0, -1))
try("open ground", Vector3.new(-20, standY, 60), Vector3.new(0, 0, 1))
try("tall perimeter wall (16 high)", Vector3.new(0, standY, 112), Vector3.new(0, 0, 1))
try("crate (4 high) at -18,40", Vector3.new(-18, standY, 36), Vector3.new(0, 0, 1))
return out
