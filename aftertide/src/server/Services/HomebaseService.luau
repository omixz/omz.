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
local Projects = require(Shared.Config.Projects)
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
	for _, r in Projects.List do
		owned[r.id] = HomebaseService.anyoneHas(r.id)
	end
	Services.MapService.setFerryRepairs(owned)
end

-- Builds a Meridian project: Scrip + Materials, or one Shipwright's Crew token (useToken).
local function repair(player, repairId, useToken)
	local p = type(repairId) == "string" and Projects.get(repairId)
	if not p then
		return
	end
	local data = Services.PlayerDataService
	if data.hasRepair(player, p.id) then
		return
	end
	if p.requires and not data.hasRepair(player, p.requires) then
		toast(player, ("Build the %s first."):format(Projects.get(p.requires).name))
		return
	end
	if useToken == true then
		if not data.useToken(player, "build") then
			Net.notify(player, "NeedProduct", { productKey = "ShipwrightCrew" })
			return
		end
	else
		local d = data.get(player)
		if not d or d.scrip < p.scrip or (d.materials or 0) < p.materials then
			toast(player, ("Need %d Scrip and %d Materials. Both come from missions."):format(p.scrip, p.materials))
			return
		end
		data.spendScrip(player, p.scrip)
		data.spendMaterials(player, p.materials)
		Services.AnalyticsHelper.economy(player, "sink", p.scrip, Enum.AnalyticsEconomyTransactionType.Shop.Name, "Project_" .. p.id)
	end
	data.addRepair(player, p.id)
	task.spawn(data.save, player)
	Net.notifyAll("Toast", { text = ("%s built the %s."):format(player.DisplayName, p.name) })
	HomebaseService.refreshVisuals()
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
		OpenProjects = function(player)
			Net.notify(player, "OpenRepairs", {})
		end,
		SetLongGun = setLongGun,
		SaveSettings = saveSettings,
		BuyOutfit = function(player, a)
			Services.CosmeticsService.buyWithScrip(player, a)
		end,
		EquipOutfit = function(player, a)
			Services.CosmeticsService.equip(player, a)
		end,
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
