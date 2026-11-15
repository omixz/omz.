-- Builds every map and the Meridian; reports floating / lodged props and fixture overlaps.
local AssetService = registry.AssetService
AssetService.load()
local MapService = registry.MapService
local MapKit = require(ServerScriptService.Server.Maps.MapKit)
MapKit.setAssets(AssetService)
local world = Instance.new("Folder")
world.Name = "World"
world.Parent = workspace
local out = { maps = {} }
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
for _, id in MapService.MapIds do
	MapService.loadMap(id, Random.new(7))
	local folder = world:FindFirstChild("Map_" .. id)
	local floating, lodged = {}, {}
	for _, m in folder:GetChildren() do
		if m:IsA("Model") then
			local cf, size = m:GetBoundingBox()
			local bottom = cf.Position - Vector3.new(0, size.Y / 2, 0)
			params.FilterDescendantsInstances = { m }
			local hit = workspace:Raycast(bottom + Vector3.new(0, 0.3, 0), Vector3.new(0, -6, 0), params)
			local gap = hit and (bottom.Y - hit.Position.Y) or 99
			if gap > 0.7 then
				table.insert(floating, { name = m.Name, at = v3t(bottom), gap = gap })
			end
			local op = OverlapParams.new()
			op.FilterType = Enum.RaycastFilterType.Exclude
			op.FilterDescendantsInstances = { m }
			local inside = workspace:GetPartBoundsInBox(cf, size * 0.6, op)
			for _, p in inside do
				if p.Parent == folder and p.CanCollide and p.Size.Magnitude > 6 then
					table.insert(lodged, { name = m.Name, into = p.Name .. " " .. p.Material.Name, at = v3t(cf.Position) })
					break
				end
			end
		end
	end
	local spots = {}
	for _, list in { MapService.LootSpots, MapService.SupplyCandidates } do
		for _, v in list do
			local hit = workspace:Raycast(v + Vector3.new(0, 2, 0), Vector3.new(0, -10, 0))
			if hit and math.abs(hit.Position.Y - v.Y) > 0.6 then
				table.insert(spots, { at = v3t(v), ground = hit.Position.Y })
			end
		end
	end
	out.maps[id] = { floating = floating, lodged = lodged, misplacedSpots = spots }
end
MapService.buildFerryForTest({})
local overlapsEmpty = MapService.checkLayout("test: Meridian (nothing built)")
local all = {}
for _, p in require(Shared.Config.Projects).List do
	all[p.id] = true
end
MapService.setFerryRepairs(all)
local overlapsFull = MapService.checkLayout("test: Meridian (everything built)")
out.meridian = { overlapsEmpty = overlapsEmpty, overlapsFull = overlapsFull }
return out
