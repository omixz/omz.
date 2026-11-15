-- Exports every visible part of the Meridian (or a map, via SCENE_TARGET) for the preview renderer.
local AssetService = registry.AssetService
AssetService.load()
local MapService = registry.MapService
local MapKit = require(ServerScriptService.Server.Maps.MapKit)
MapKit.setAssets(AssetService)
local world = Instance.new("Folder")
world.Name = "World"
world.Parent = workspace
local target = SCENE_TARGET or "Meridian"
local folder
if target == "Meridian" then
	folder = MapService.buildFerryForTest(SCENE_OWNED or {})
else
	MapService.loadMap(target, Random.new(SCENE_SEED or 7))
	folder = world:FindFirstChild("Map_" .. target)
end
local parts = {}
for _, p in folder:GetDescendants() do
	if p:IsA("BasePart") and p.Transparency < 0.95 then
		local c = p.Color
		table.insert(parts, {
			c = cf12(p.CFrame),
			s = v3t(p.Size),
			col = { math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255) },
			t = p.Transparency,
			m = p.Material.Name,
			sh = p:IsA("Part") and p.Shape.Name or (p:IsA("WedgePart") and "Wedge" or (p:IsA("MeshPart") and "Mesh" or "Block")),
			n = p.Name,
		})
	end
end
return { parts = parts, origin = v3t(target == "Meridian" and require(Shared.Config.Game).FerryOrigin or Vector3.zero) }
