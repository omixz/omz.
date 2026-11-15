--!nonstrict
-- AFTERTIDE server bootstrap. Every service exposes optional init(registry) and start().
-- init wires dependencies (no yielding); start begins loops and connections.
local Players = game:GetService("Players")

Players.CharacterAutoLoads = false -- CharacterService spawns the crew rigs itself

local Services = script.Parent:WaitForChild("Services")

local ORDER = {
	"PlayerDataService",
	"AnalyticsHelper",
	"CosmeticsService",
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
	"QuestService",
	"LeaderboardService",
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

-- Forward server warnings / errors (and our own [Tagged] prints) to players' F2 diagnostics.
local LogService = game:GetService("LogService")
local Net = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Net)
local sentThisMinute, minuteStart = 0, os.clock()
LogService.MessageOut:Connect(function(message, messageType)
	local kind = (messageType == Enum.MessageType.MessageError and "error") or (messageType == Enum.MessageType.MessageWarning and "warning") or nil
	if not kind and message:sub(1, 1) ~= "[" then
		return
	end
	if os.clock() - minuteStart > 60 then
		sentThisMinute, minuteStart = 0, os.clock()
	end
	if sentThisMinute < 80 then
		sentThisMinute += 1
		pcall(Net.notifyAll, "Diag", { k = kind or "info", m = message:sub(1, 400) })
	end
end)

print("[AFTERTIDE] server ready")
