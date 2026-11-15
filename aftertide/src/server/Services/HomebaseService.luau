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
local Quartermaster = require(Shared.Config.Quartermaster)
local Characters = require(Shared.Config.Characters)
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
	local bonus = { salvage = 0, items = {}, pack = {}, kit = {} }
	if has("generator") then
		bonus.salvage += 20
	end
	if has("sickbay") then
		bonus.items.dressing = 1
	end
	-- the loadout chosen at the Quartermaster (only guns you've unlocked)
	local data = Services.PlayerDataService.get(player)
	if data then
		local guns = data.guns or {}
		local loadout = data.loadout or {}
		if type(loadout.long) == "string" and guns[loadout.long] and Weapons.List[loadout.long] and Weapons.List[loadout.long].slot == "long" then
			bonus.longGun = loadout.long
		end
		local slots = Quartermaster.BackpackSlots + (has("armory") and 1 or 0)
		for _, id in loadout.pack or {} do
			if #bonus.pack < slots and guns[id] and id ~= bonus.longGun and Weapons.List[id] and Weapons.List[id].slot == "long" then
				table.insert(bonus.pack, id)
			end
		end
		-- your signature gun stays with you: in the backpack if you chose another long gun
		local session = Services.CharacterService.getSession(player)
		local def = session and Characters.List[session.charId]
		local sig = def and def.loadout.weapons.long
		if sig and bonus.longGun and sig ~= bonus.longGun and #bonus.pack < slots and not table.find(bonus.pack, sig) then
			table.insert(bonus.pack, 1, sig)
		end
		-- crossing kits (Quartermaster, Lucky Spin, Ammo Crates): delivered now, then used up.
		-- At most MaxKitsEach of each kind per crossing; extra Ammo Crates wait for the next one.
		local left = {}
		for kitId, count in data.kit or {} do
			for _, k in Quartermaster.Kits do
				if k.id == kitId then
					local use = math.min(count, Quartermaster.MaxKitsEach)
					for itemId, amount in k.items do
						bonus.kit[itemId] = (bonus.kit[itemId] or 0) + amount * use
					end
					if count > use then
						left[kitId] = count - use
					end
				end
			end
		end
		data.kit = left
		Services.PlayerDataService.publish(player)
	end
	return bonus
end

-- Quartermaster -------------------------------------------------------------------------------

local function qmPrice(player, price)
	return math.floor(price * (Services.PlayerDataService.hasRepair(player, "armory") and 0.85 or 1) + 0.5)
end

local function unlockGun(player, gunId)
	local data = Services.PlayerDataService.get(player)
	if not data or type(gunId) ~= "string" then
		return
	end
	for _, g in Quartermaster.Guns do
		if g.id == gunId then
			data.guns = data.guns or { revolver = true }
			if data.guns[gunId] then
				return
			end
			local price = qmPrice(player, g.price)
			if not Services.PlayerDataService.spendScrip(player, price) then
				toast(player, ("Need %d Scrip. Earn it by finishing missions."):format(price))
				return
			end
			data.guns[gunId] = true
			-- first long gun: put it straight in the holster
			data.loadout = data.loadout or { long = "", pack = {} }
			if data.loadout.long == "" or data.loadout.long == nil then
				data.loadout.long = gunId
			end
			Services.PlayerDataService.publish(player)
			Services.AnalyticsHelper.economy(player, "sink", price, Enum.AnalyticsEconomyTransactionType.Shop.Name, "Gun_" .. gunId)
			toast(player, ("Unlocked: %s. Set your loadout at the Quartermaster."):format(Weapons.List[gunId].name))
			task.spawn(Services.PlayerDataService.save, player)
			return
		end
	end
end

local function setLoadout(player, long, pack)
	local data = Services.PlayerDataService.get(player)
	if not data then
		return
	end
	local guns = data.guns or {}
	local clean = { long = "", pack = {} }
	if type(long) == "string" and guns[long] and Weapons.List[long] and Weapons.List[long].slot == "long" then
		clean.long = long
	end
	local slots = Quartermaster.BackpackSlots + (Services.PlayerDataService.hasRepair(player, "armory") and 1 or 0)
	if type(pack) == "table" then
		for _, id in pack do
			if #clean.pack < slots and type(id) == "string" and guns[id] and id ~= clean.long and Weapons.List[id] and Weapons.List[id].slot == "long" and not table.find(clean.pack, id) then
				table.insert(clean.pack, id)
			end
		end
	end
	data.loadout = clean
	Services.PlayerDataService.publish(player)
end

local function buyKit(player, kitId)
	local data = Services.PlayerDataService.get(player)
	if not data or type(kitId) ~= "string" then
		return
	end
	for _, k in Quartermaster.Kits do
		if k.id == kitId and not k.robux then
			data.kit = data.kit or {}
			if (data.kit[kitId] or 0) >= Quartermaster.MaxKitsEach then
				toast(player, "That's as many as the Quartermaster will pack for one crossing.")
				return
			end
			local price = qmPrice(player, k.price)
			if not Services.PlayerDataService.spendScrip(player, price) then
				toast(player, ("Need %d Scrip."):format(price))
				return
			end
			data.kit[kitId] = (data.kit[kitId] or 0) + 1
			Services.PlayerDataService.publish(player)
			toast(player, k.name .. " packed for your next crossing.")
			return
		end
	end
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
		UnlockGun = unlockGun,
		SetLoadout = setLoadout,
		BuyKit = buyKit,
		Spin = function(player)
			Services.SpinService.spin(player)
		end,
		OpenSpin = function(player)
			Net.notify(player, "OpenSpin", {})
		end,
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
