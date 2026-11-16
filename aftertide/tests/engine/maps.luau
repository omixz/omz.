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
params.IgnoreWater = true -- rocks in the harbour are meant to be under water
for _, id in MapService.MapIds do
	MapService.loadMap(id, Random.new(7))
	local folder = world:FindFirstChild("Map_" .. id)
	local floating, lodged = {}, {}
	task.wait(0.2) -- let terrain writes settle before ray casts
	local terrainHits = 0
	local allProps = {}
	for _, m in folder:GetDescendants() do
		if m:IsA("Model") and m:GetAttribute("Prop") then
			table.insert(allProps, m)
		end
	end
	for _, m in folder:GetDescendants() do
		local solid = false
		if m:IsA("Model") and m:GetAttribute("Prop") then
			for _, p in m:GetChildren() do
				if p:IsA("BasePart") and p.CanQuery then
					solid = true
				end
			end
		end
		if solid then
			local cf, size = m:GetBoundingBox()
			local bottom = cf.Position - Vector3.new(0, size.Y / 2, 0)
			params.FilterDescendantsInstances = allProps -- ground only, not a neighbouring tree's canopy
			local hit = workspace:Raycast(bottom + Vector3.new(0, 0.5, 0), Vector3.new(0, -12, 0), params)
			local gap = hit and (bottom.Y - hit.Position.Y) or 0
			local up = workspace:Raycast(bottom + Vector3.new(0, 7, 0), Vector3.new(0, -7, 0), params)
			if up and up.Position.Y - bottom.Y > 2.5 then
				gap = -(up.Position.Y - bottom.Y) -- buried
				hit = up
			end
			if hit and hit.Instance == workspace.Terrain then
				terrainHits += 1
			end
			if gap > 0.7 or gap < -2.5 then
				table.insert(floating, { name = m.Name, at = v3t(bottom), gap = gap, on = hit and hit.Instance.Name or "nothing" })
			end
			local op = OverlapParams.new()
			op.FilterType = Enum.RaycastFilterType.Exclude
			op.FilterDescendantsInstances = { m }
			local inside = workspace:GetPartBoundsInBox(cf, size * 0.6, op)
			for _, p in inside do
				if not p:IsA("Terrain") and not p.Parent:IsA("Model") and p.CanCollide and p.Transparency < 1 and p.Size.Magnitude > 6 then
					table.insert(lodged, { name = m.Name, into = p.Name .. " " .. p.Material.Name .. " " .. tostring(p.Size), at = v3t(cf.Position) })
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
	out.maps[id] = { floating = floating, lodged = lodged, misplacedSpots = spots, terrainHits = terrainHits, terrainAt0 = workspace:Raycast(Vector3.new(3, 50, 3), Vector3.new(0, -100, 0)) and true or false }
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
