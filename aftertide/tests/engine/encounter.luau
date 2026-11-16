-- Sets up a real mission on each map (objects, containers, loot, logbook pages) and reports
-- what got placed, plus any error.
local AssetService = registry.AssetService
AssetService.load()
local MapService = registry.MapService
local MapKit = require(ServerScriptService.Server.Maps.MapKit)
MapKit.setAssets(AssetService)
local _l = registry.LootService
local _r = registry.RewardsService
task.spawn(MapService.start)
task.wait(1)
local out = {}
for _, id in { ENC_MAP or "LarkspurStreet" } do
	local ok, err = pcall(MapService.resetEncounter, {}, Random.new(4), "Salvage", 1, id)
	local folder = MapService.getEncounterFolder()
	local counts = {}
	if folder then
		for _, c in folder:GetChildren() do
			counts[c.Name] = (counts[c.Name] or 0) + 1
		end
	end
	out[id] = { ok = ok, err = err and tostring(err), counts = counts }
end
return out
