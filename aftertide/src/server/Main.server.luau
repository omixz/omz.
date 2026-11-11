--!nonstrict
-- AFTERTIDE server bootstrap. Every service exposes optional init(registry) and start().
-- init wires dependencies (no yielding); start begins loops and connections.
local Players = game:GetService("Players")

Players.CharacterAutoLoads = false -- CharacterService spawns the crew rigs itself

local Services = script.Parent:WaitForChild("Services")

local ORDER = {
	"PlayerDataService",
	"AssetService",
	"MapService",
	"PerceptionService",
	"InventoryService",
	"CharacterService",
	"WeaponService",
	"EnemyService",
	"LootService",
	"ActionService",
	"WorkbenchService",
	"HomebaseService",
	"CommerceService",
	"MatchService",
	"AntiCheatService",
}

local registry = {}
for _, name in ORDER do
	registry[name] = require(Services:WaitForChild(name))
end
for _, name in ORDER do
	local service = registry[name]
	if service.init then
		service.init(registry)
	end
end
for _, name in ORDER do
	local service = registry[name]
	if service.start then
		task.spawn(service.start)
	end
end

print("[AFTERTIDE] server ready")
