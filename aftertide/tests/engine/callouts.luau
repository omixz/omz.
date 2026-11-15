-- Spawns a Watch rifleman and a Tidebound archer and makes each say every kind of line.
local AssetService = registry.AssetService
AssetService.load()
local EnemyService = registry.EnemyService
local MapService = registry.MapService
local Net = require(Shared.Net)
local world = Instance.new("Folder")
world.Name = "World"
world.Parent = workspace
local folder = Instance.new("Folder")
folder.Name = "Encounter"
folder.Parent = world
local sent = {}
local real = Net.notifyAll
Net.notifyAll = function(kind, data)
	if kind == "Callout" then
		table.insert(sent, { name = data.name, text = data.text, kind = data.kind, faction = data.faction })
	end
end
local out = { errors = {} }
for _, typeName in { "WatchRifleman", "TideboundArcher" } do
	local ok, e = pcall(EnemyService.spawn, typeName, Vector3.new(0, 5, 0), {})
	if not ok then
		table.insert(out.errors, typeName .. ": " .. tostring(e))
	else
		out[typeName] = { name = e.name, voice = e.voice }
		for _, kind in { "spotted", "lost", "flank", "ack", "down", "heard", "hostage", "idle", "hurt" } do
			e.sayAt = 0
			local okSay, err = pcall(EnemyService.say, e, kind, "Wren")
			if not okSay then
				table.insert(out.errors, kind .. ": " .. tostring(err))
			end
		end
	end
end
Net.notifyAll = real
out.lines = sent
return out
