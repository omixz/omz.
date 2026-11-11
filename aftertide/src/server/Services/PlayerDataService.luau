--!nonstrict
-- Persistent player data (tokens, stats, purchase receipts) in a DataStore.
-- Stage 9 replaces this with ProfileStore (session locking); the API stays the same.
-- In Studio without "Enable Studio Access to API Services", it falls back to memory only.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Game = require(Shared.Config.Game)

local PlayerDataService = {}

local STORE_NAME = "Aftertide_Player_v1"
local AUTOSAVE_INTERVAL = 120
local MAX_RECEIPTS = 50

local store = nil
local memoryOnly = false
local profiles = {} -- [Player] = { data = table, noSave = bool, loaded = bool }

local function defaultData()
	return {
		version = 1,
		tokens = { secondWind = Game.StartingTokens.secondWind, resupply = Game.StartingTokens.resupply },
		stats = { runs = 0, wins = 0, takedowns = 0 },
		receipts = {},
		receiptOrder = {},
		lastDailyWin = "",
	}
end

local function reconcile(data)
	local template = defaultData()
	for key, value in template do
		if data[key] == nil then
			data[key] = value
		elseif type(value) == "table" and type(data[key]) == "table" and key ~= "receipts" and key ~= "receiptOrder" then
			for k2, v2 in value do
				if data[key][k2] == nil then
					data[key][k2] = v2
				end
			end
		end
	end
	return data
end

local function keyFor(player)
	return "u_" .. player.UserId
end

local function publishTokens(player, data)
	for kind, amount in data.tokens do
		player:SetAttribute("Tokens_" .. kind, amount)
	end
end

local function load(player)
	if memoryOnly then
		return defaultData(), false
	end
	for attempt = 1, 3 do
		local ok, result = pcall(function()
			return store:GetAsync(keyFor(player))
		end)
		if ok then
			return reconcile(result or defaultData()), false
		end
		warn(("[PlayerData] load attempt %d failed for %s: %s"):format(attempt, player.Name, tostring(result)))
		task.wait(attempt)
	end
	-- Don't overwrite real data with defaults if loading failed.
	return defaultData(), true
end

function PlayerDataService.save(player)
	local profile = profiles[player]
	if not profile or not profile.loaded then
		return false
	end
	if memoryOnly then
		return true
	end
	if profile.noSave then
		return false
	end
	local ok, err = pcall(function()
		store:UpdateAsync(keyFor(player), function()
			return profile.data
		end)
	end)
	if not ok then
		warn(("[PlayerData] save failed for %s: %s"):format(player.Name, tostring(err)))
	end
	return ok
end

function PlayerDataService.isMemoryOnly()
	return memoryOnly
end

function PlayerDataService.get(player)
	local profile = profiles[player]
	return profile and profile.loaded and profile.data or nil
end

function PlayerDataService.waitFor(player, timeout)
	local deadline = os.clock() + (timeout or 15)
	while player.Parent and os.clock() < deadline do
		local data = PlayerDataService.get(player)
		if data then
			return data
		end
		task.wait(0.2)
	end
	return nil
end

function PlayerDataService.addTokens(player, kind, amount)
	local data = PlayerDataService.get(player)
	if not data or data.tokens[kind] == nil then
		return false
	end
	data.tokens[kind] += amount
	publishTokens(player, data)
	return true
end

function PlayerDataService.useToken(player, kind)
	local data = PlayerDataService.get(player)
	if not data or (data.tokens[kind] or 0) < 1 then
		return false
	end
	data.tokens[kind] -= 1
	publishTokens(player, data)
	return true
end

function PlayerDataService.hasReceipt(player, purchaseId)
	local data = PlayerDataService.get(player)
	return data ~= nil and data.receipts[purchaseId] == true
end

function PlayerDataService.recordReceipt(player, purchaseId)
	local data = PlayerDataService.get(player)
	if not data then
		return
	end
	data.receipts[purchaseId] = true
	table.insert(data.receiptOrder, purchaseId)
	while #data.receiptOrder > MAX_RECEIPTS do
		local oldest = table.remove(data.receiptOrder, 1)
		data.receipts[oldest] = nil
	end
end

local function onPlayerAdded(player)
	profiles[player] = { loaded = false }
	local data, noSave = load(player)
	if not player.Parent then
		profiles[player] = nil
		return
	end
	profiles[player] = { data = data, noSave = noSave, loaded = true }
	publishTokens(player, data)
	if noSave then
		warn("[PlayerData] " .. player.Name .. " is in no-save mode (DataStore unavailable)")
	end
end

local function onPlayerRemoving(player)
	PlayerDataService.save(player)
	profiles[player] = nil
end

function PlayerDataService.init()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
		if RunService:IsStudio() then
			-- Probe once: Studio without API access throws here.
			local probeOk = pcall(function()
				store:GetAsync("probe")
			end)
			if not probeOk then
				memoryOnly = true
			end
		end
	else
		memoryOnly = true
	end
	if memoryOnly then
		warn("[PlayerData] DataStores unavailable: using memory only (enable Studio API access to test saving)")
	end
end

function PlayerDataService.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	game:BindToClose(function()
		local pending = 0
		for _, player in Players:GetPlayers() do
			pending += 1
			task.spawn(function()
				PlayerDataService.save(player)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)

	while true do
		task.wait(AUTOSAVE_INTERVAL)
		for _, player in Players:GetPlayers() do
			task.spawn(PlayerDataService.save, player)
		end
	end
end

return PlayerDataService
