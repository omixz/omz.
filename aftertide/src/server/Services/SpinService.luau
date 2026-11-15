--!nonstrict
-- The Lucky Spin: one free spin per UTC day, extra spins from Spin tokens (Robux or won).
-- The server picks the prize; the client only animates to it. Odds: Config/Spin (shown in UI).
local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Spin = require(Shared.Config.Spin)
local Quartermaster = require(Shared.Config.Quartermaster)
local Weapons = require(Shared.Config.Weapons)
local Net = require(Shared.Net)

local SpinService = {}
local Services
local rng = Random.new()
local busy = {}

local TOTAL = 0
for _, p in Spin.Prizes do
	TOTAL += p.weight
end

local function today()
	return os.date("!%Y-%m-%d")
end

-- Unix time of the next 00:00 UTC (os.time() is UTC seconds).
local function nextReset()
	local now = os.time()
	return now - now % 86400 + 86400
end

-- Players in regions where paid random items are restricted can't buy spins.
function SpinService.paidRestricted(player)
	local cached = player:GetAttribute("PaidSpinRestricted")
	if cached ~= nil then
		return cached
	end
	local restricted = true -- safest default if the policy can't be read
	local ok, info = pcall(function()
		return PolicyService:GetPolicyInfoForPlayerAsync(player)
	end)
	if ok and info then
		restricted = info.ArePaidRandomItemsRestricted == true
	end
	player:SetAttribute("PaidSpinRestricted", restricted)
	return restricted
end

function SpinService.publish(player)
	local data = Services.PlayerDataService.get(player)
	if not data then
		return
	end
	player:SetAttribute("FreeSpinReady", data.spinDay ~= today())
	player:SetAttribute("NextFreeSpinAt", nextReset())
end

local function pick()
	local roll = rng:NextInteger(1, TOTAL)
	for i, p in Spin.Prizes do
		roll -= p.weight
		if roll <= 0 then
			return i, p
		end
	end
	return 1, Spin.Prizes[1]
end

local function grant(player, data, prize)
	local g = prize.grant
	local detail
	if g.gun then
		-- a real gun: unlock one you don't have yet (Scrip if you own them all)
		data.guns = data.guns or { revolver = true }
		local locked = {}
		for _, gun in Quartermaster.Guns do
			if not data.guns[gun.id] then
				table.insert(locked, gun.id)
			end
		end
		if #locked > 0 then
			local id = locked[rng:NextInteger(1, #locked)]
			data.guns[id] = true
			data.loadout = data.loadout or { long = "", pack = {} }
			if data.loadout.long == "" or data.loadout.long == nil then
				data.loadout.long = id -- holstered and ready for the next crossing
			end
			detail = Weapons.List[id].name .. " unlocked! Choose it at the Quartermaster."
		else
			Services.PlayerDataService.addScrip(player, 300)
			detail = "You own every gun: 300 Scrip instead."
		end
	elseif g.kit then
		detail = "Packed in your kit bag: you get it at the start of your next crossing."
	end
	if g.scrip then
		Services.PlayerDataService.addScrip(player, g.scrip)
	end
	if g.materials then
		Services.PlayerDataService.addMaterials(player, g.materials)
	end
	for kind, n in g.tokens or {} do
		Services.PlayerDataService.addTokens(player, kind, n)
	end
	for kitId, n in g.kit or {} do
		data.kit = data.kit or {}
		local have = data.kit[kitId] or 0
		if have >= Spin.MaxKitStack then
			Services.PlayerDataService.addScrip(player, 30) -- kit bag full: pay it out as Scrip
		else
			data.kit[kitId] = have + n
		end
	end
	Services.PlayerDataService.publish(player)
	return detail
end

function SpinService.spin(player)
	if busy[player] then
		return
	end
	local data = Services.PlayerDataService.get(player)
	if not data then
		return
	end
	local free = data.spinDay ~= today()
	if free then
		data.spinDay = today()
	elseif (data.tokens.spin or 0) > 0 then
		data.tokens.spin -= 1
	else
		if SpinService.paidRestricted(player) then
			Net.notify(player, "Toast", { text = "Your free spin is back at midnight (UTC)." })
		else
			Net.notify(player, "NeedProduct", { productKey = "LuckySpin" })
		end
		return
	end
	busy[player] = true
	local index, prize = pick()
	local detail = grant(player, data, prize)
	SpinService.publish(player)
	Services.AnalyticsHelper.economy(player, "source", 0, Enum.AnalyticsEconomyTransactionType.Gameplay.Name, "Spin_" .. prize.id)
	Net.notify(player, "SpinResult", { index = index, free = free, detail = detail })
	task.spawn(Services.PlayerDataService.save, player)
	task.delay(4, function()
		busy[player] = nil
	end)
end

function SpinService.init(registry)
	Services = registry
end

function SpinService.start()
	local function onPlayer(player)
		task.spawn(function()
			Services.PlayerDataService.waitFor(player, 20)
			SpinService.paidRestricted(player)
			SpinService.publish(player)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in Players:GetPlayers() do
		onPlayer(p)
	end
	Players.PlayerRemoving:Connect(function(p)
		busy[p] = nil
	end)
	-- the free spin comes back at midnight UTC for players who stay online
	task.spawn(function()
		while true do
			task.wait(30)
			for _, p in Players:GetPlayers() do
				SpinService.publish(p)
			end
		end
	end)
	assert(Workspace)
end

return SpinService
