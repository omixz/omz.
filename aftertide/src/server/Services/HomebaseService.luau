--!nonstrict
-- The Meridian as a homebase that persists between crossings:
--   * Repairs bought with Scrip (earned only by playing) unlock permanent bonuses and change
--     how the ferry looks (deck lights, generator, radio mast, sick bay, armory rack).
--   * Armory: pick your long gun before a crossing (once the rack is repaired).
--   * Settings (graphics mode, sensitivity) are saved with your profile.
-- Also routes every ferry menu Request from clients to the right service.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Upgrades = require(Shared.Config.Upgrades)
local Weapons = require(Shared.Config.Weapons)
local Net = require(Shared.Net)

local HomebaseService = {}
local Services

local GRAPHICS = { Auto = true, Performance = true, Balanced = true, Cinematic = true }

local function toast(player, text)
	Net.notify(player, "Toast", { text = text })
end

-- Bonuses applied when this player starts a crossing.
function HomebaseService.bonusesFor(player)
	local has = function(id)
		return Services.PlayerDataService.hasRepair(player, id)
	end
	local bonus = { salvage = 0, items = {} }
	if has("generator") then
		bonus.salvage += 15
	end
	if has("sickbay") then
		bonus.items.dressing = 1
	end
	local choice = player:GetAttribute("LongGunChoice")
	if has("armory") and type(choice) == "string" and Weapons.List[choice] and Weapons.List[choice].slot == "long" then
		bonus.longGun = choice
	end
	return bonus
end

-- A repair is "visible" on the shared ferry if anyone in the server owns it.
function HomebaseService.anyoneHas(repairId)
	for _, p in Players:GetPlayers() do
		if Services.PlayerDataService.hasRepair(p, repairId) then
			return true
		end
	end
	return false
end

function HomebaseService.refreshVisuals()
	local owned = {}
	for _, r in Upgrades.Repairs do
		owned[r.id] = HomebaseService.anyoneHas(r.id)
	end
	Services.MapService.setFerryRepairs(owned)
end

local function repair(player, repairId)
	if type(repairId) ~= "string" then
		return
	end
	for _, r in Upgrades.Repairs do
		if r.id == repairId then
			if Services.PlayerDataService.hasRepair(player, repairId) then
				return
			end
			if not Services.PlayerDataService.spendScrip(player, r.cost) then
				toast(player, ("Need %d Scrip. Earn it by clearing encounters."):format(r.cost))
				return
			end
			Services.PlayerDataService.addRepair(player, repairId)
			task.spawn(Services.PlayerDataService.save, player)
			toast(player, "Repaired: " .. r.name)
			HomebaseService.refreshVisuals()
			return
		end
	end
end

local function setLongGun(player, weaponId)
	if type(weaponId) ~= "string" or not Weapons.List[weaponId] or Weapons.List[weaponId].slot ~= "long" then
		return
	end
	if not Services.PlayerDataService.hasRepair(player, "armory") then
		toast(player, "Repair the armory rack first")
		return
	end
	player:SetAttribute("LongGunChoice", weaponId)
	toast(player, "Next crossing you'll carry the " .. Weapons.List[weaponId].name)
end

local function saveSettings(player, settings)
	if type(settings) ~= "table" then
		return
	end
	local graphics = GRAPHICS[settings.graphics] and settings.graphics or "Auto"
	local sensitivity = tonumber(settings.sensitivity) or 1
	if sensitivity ~= sensitivity then
		sensitivity = 1
	end
	Services.PlayerDataService.setSettings(player, {
		graphics = graphics,
		sensitivity = math.clamp(sensitivity, 0.2, 3),
		reduceMotion = settings.reduceMotion == true,
	})
end

function HomebaseService.init(registry)
	Services = registry
end

function HomebaseService.start()
	local handlers = {
		ChooseRoute = function(player, a)
			Services.MatchService.chooseRoute(player, a)
		end,
		OpenChart = function(player)
			Services.MatchService.requestChart(player)
		end,
		BuyWeaponUpgrade = function(player, a, b)
			Services.WorkbenchService.buyWeapon(player, a, b)
		end,
		BuyGeneral = function(player, a)
			Services.WorkbenchService.buyGeneral(player, a)
		end,
		BuyPerk = function(player, a)
			Services.WorkbenchService.buyPerk(player, a)
		end,
		Repair = repair,
		SetLongGun = setLongGun,
		SaveSettings = saveSettings,
	}
	Net.onServer("Request", 8, function(player, kind, a, b)
		local handler = type(kind) == "string" and handlers[kind]
		if handler then
			handler(player, a, b)
		end
	end)
	Players.PlayerAdded:Connect(function(player)
		task.spawn(function()
			Services.PlayerDataService.waitFor(player, 20)
			HomebaseService.refreshVisuals()
		end)
	end)
	Players.PlayerRemoving:Connect(function()
		task.defer(HomebaseService.refreshVisuals)
	end)
	assert(HttpService)
end

return HomebaseService
