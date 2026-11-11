--!nonstrict
-- The Meridian's workbench, used between encounters (Planning phase) with Salvage found in
-- the run: weapon parts, satchel upgrades, and your character's other perks.
-- Upgrades last for the current crossing only (roguelike), like everything in the satchel.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Characters = require(Shared.Config.Characters)
local Upgrades = require(Shared.Config.Upgrades)
local Net = require(Shared.Net)

local WorkbenchService = {}
local Services

local function toast(player, text)
	Net.notify(player, "Toast", { text = text })
end

local function cost(player, base)
	local discount = Services.PlayerDataService.hasRepair(player, "workshop") and 0.85 or 1
	return math.ceil(base * discount)
end

local function canUse(player)
	local session = Services.CharacterService.getSession(player)
	if not session or not session.runId or not Services.MatchService.isPlanning() then
		toast(player, "The workbench is used between encounters during a crossing")
		return nil
	end
	return session
end

local function pay(player, amount)
	if Services.InventoryService.spendSalvage(player, amount) then
		return true
	end
	toast(player, ("Need %d Salvage"):format(amount))
	return false
end

function WorkbenchService.costFor(player, base)
	return cost(player, base)
end

function WorkbenchService.buyWeapon(player, weaponId, upgradeId)
	local session = canUse(player)
	if not session or type(weaponId) ~= "string" or type(upgradeId) ~= "string" then
		return
	end
	local owns = false
	for _, w in Services.InventoryService.weaponSlots(player) do
		if w.id == weaponId then
			owns = true
		end
	end
	if not owns then
		return
	end
	local upgrade
	for _, u in Upgrades.Weapon[weaponId] or {} do
		if u.id == upgradeId then
			upgrade = u
		end
	end
	session.run.weapons[weaponId] = session.run.weapons[weaponId] or {}
	if not upgrade or session.run.weapons[weaponId][upgradeId] then
		return
	end
	if pay(player, cost(player, upgrade.cost)) then
		session.run.weapons[weaponId][upgradeId] = true
		Services.CharacterService.publishRun(player)
		Services.WeaponService.publishStats(player)
		toast(player, "Fitted: " .. upgrade.name)
	end
end

function WorkbenchService.buyGeneral(player, upgradeId)
	local session = canUse(player)
	if not session or type(upgradeId) ~= "string" then
		return
	end
	for _, u in Upgrades.General do
		if u.id == upgradeId and not session.run.general[upgradeId] then
			if pay(player, cost(player, u.cost)) then
				session.run.general[upgradeId] = true
				Services.CharacterService.publishRun(player)
				Services.InventoryService.publish(player)
				toast(player, "Upgraded: " .. u.name)
			end
			return
		end
	end
end

function WorkbenchService.buyPerk(player, perkId)
	local session = canUse(player)
	if not session or type(perkId) ~= "string" or perkId == session.perkId or session.run.perks[perkId] then
		return
	end
	for _, perk in Characters.List[session.charId].perks do
		if perk.id == perkId then
			if pay(player, cost(player, Upgrades.PerkCost)) then
				session.run.perks[perkId] = true
				Services.CharacterService.refreshMods(player)
				Services.InventoryService.publish(player)
				toast(player, "Learned: " .. perk.name)
			end
			return
		end
	end
end

function WorkbenchService.init(registry)
	Services = registry
end

return WorkbenchService
