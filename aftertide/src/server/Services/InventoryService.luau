--!nonstrict
-- The satchel: items, reserve ammo, two weapon slots (long gun + sidearm, with magazines)
-- and Salvage (run currency). Server-owned; replicated to the owner as player attributes:
--   Inv_<item>, Cap_<item>, W_long, W_longMag, W_sidearm, W_sidearmMag, Salvage
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Items = require(Shared.Config.Items)
local Weapons = require(Shared.Config.Weapons)
local Net = require(Shared.Net)
local Sfx = require(Shared.Util.Sfx)

local InventoryService = {}
local Services

local inventories = {} -- [Player] = { items = {}, weapons = { long = {id, mag}, sidearm = {id, mag} }, salvage = n }

local function runUpgrades(player)
	local session = Services.CharacterService.getSession(player)
	return session and session.run or nil
end

function InventoryService.cap(player, itemId)
	local def = Items.Items[itemId]
	if not def then
		return 0
	end
	local cap = def.cap
	local run = runUpgrades(player)
	local session = Services.CharacterService.getSession(player)
	if def.kind == "ammo" then
		if run and run.general.ammoPouch then
			cap = math.floor(cap * (1 + Items.CapBonus.ammoPouch))
		end
	elseif run and run.general.satchel then
		cap += Items.CapBonus.satchel
	end
	if def.kind == "throwable" and session and session.mods then
		cap += session.mods.throwCapBonus
	end
	return cap
end

function InventoryService.publish(player)
	local inv = inventories[player]
	if not inv then
		return
	end
	for _, itemId in Items.Order do
		player:SetAttribute("Inv_" .. itemId, inv.items[itemId] or 0)
		player:SetAttribute("Cap_" .. itemId, InventoryService.cap(player, itemId))
	end
	for _, slot in { "long", "sidearm" } do
		local w = inv.weapons[slot]
		player:SetAttribute("W_" .. slot, w and w.id or "")
		player:SetAttribute("W_" .. slot .. "Mag", w and w.mag or 0)
	end
	player:SetAttribute("Salvage", inv.salvage)
	local pack = {}
	for _, w in inv.pack or {} do
		table.insert(pack, w.id .. ":" .. w.mag)
	end
	player:SetAttribute("Pack", table.concat(pack, ","))
end

-- loadout = { weapons = {long, sidearm}, items = {...} }; bonus = { salvage, items, longGun }
function InventoryService.reset(player, loadout, mods, bonus)
	bonus = bonus or {}
	local inv = { items = {}, weapons = {}, salvage = bonus.salvage or 0, pack = {} }
	for _, itemId in Items.Order do
		inv.items[itemId] = 0
	end
	inventories[player] = inv
	local long = bonus.longGun or loadout.weapons.long
	for slot, weaponId in { long = long, sidearm = loadout.weapons.sidearm } do
		if Weapons.List[weaponId] then
			inv.weapons[slot] = { id = weaponId, mag = Weapons.List[weaponId].mag }
		end
	end
	-- backpack guns (holster system): carried, but slow to get out
	for _, weaponId in bonus.pack or {} do
		if Weapons.List[weaponId] and Weapons.List[weaponId].slot == "long" and weaponId ~= long then
			table.insert(inv.pack, { id = weaponId, mag = Weapons.List[weaponId].mag })
		end
	end
	for itemId, amount in loadout.items do
		InventoryService.add(player, itemId, amount)
	end
	-- a crossing kit bought at the Quartermaster
	for itemId, amount in bonus.kit or {} do
		InventoryService.add(player, itemId, amount)
	end
	if bonus.items then
		for itemId, amount in bonus.items do
			InventoryService.add(player, itemId, amount)
		end
	end
	if mods and mods.ammoBonus > 0 then
		InventoryService.add(player, "pistolAmmo", mods.ammoBonus)
	end
	InventoryService.publish(player)
end

-- Holster system: swap backpack gun #index into the long-gun holster (the holstered one goes
-- into the backpack). The timing (kneel and dig) is enforced by ActionService.
function InventoryService.packList(player)
	local inv = inventories[player]
	return inv and inv.pack or {}
end

function InventoryService.swapPack(player, index)
	local inv = inventories[player]
	local entry = inv and inv.pack[index]
	if not entry then
		return false
	end
	local current = inv.weapons.long
	inv.weapons.long = { id = entry.id, mag = entry.mag }
	if current then
		inv.pack[index] = current
	else
		table.remove(inv.pack, index)
	end
	InventoryService.publish(player)
	return true
end

function InventoryService.has(player)
	return inventories[player] ~= nil
end

function InventoryService.count(player, itemId)
	local inv = inventories[player]
	return inv and inv.items[itemId] or 0
end

function InventoryService.add(player, itemId, amount)
	local inv = inventories[player]
	if not inv then
		return 0
	end
	if itemId == "salvage" then
		inv.salvage += amount
		InventoryService.publish(player)
		return amount
	end
	if not Items.Items[itemId] then
		return 0
	end
	local space = InventoryService.cap(player, itemId) - inv.items[itemId]
	local added = math.clamp(amount, 0, math.max(space, 0))
	inv.items[itemId] += added
	InventoryService.publish(player)
	return added
end

function InventoryService.take(player, itemId, amount)
	local inv = inventories[player]
	if not inv or (inv.items[itemId] or 0) < amount then
		return false
	end
	inv.items[itemId] -= amount
	InventoryService.publish(player)
	return true
end

function InventoryService.salvage(player)
	local inv = inventories[player]
	return inv and inv.salvage or 0
end

function InventoryService.spendSalvage(player, amount)
	local inv = inventories[player]
	if not inv or inv.salvage < amount then
		return false
	end
	inv.salvage -= amount
	InventoryService.publish(player)
	return true
end

function InventoryService.weapon(player, slot)
	local inv = inventories[player]
	return inv and inv.weapons[slot] or nil
end

function InventoryService.weaponSlots(player)
	local inv = inventories[player]
	return inv and inv.weapons or {}
end

function InventoryService.setMag(player, slot, mag)
	local w = InventoryService.weapon(player, slot)
	if w then
		w.mag = mag
		InventoryService.publish(player)
	end
end

-- Crafting -------------------------------------------------------------------------------

function InventoryService.recipeYield(player, recipe)
	local session = Services.CharacterService.getSession(player)
	local bonus = (recipe.perkYield and session and session.mods) and session.mods.craftYieldBonus or 0
	if recipe.perkYield and Services.PlayerDataService.hasRepair(player, "workshop") then
		bonus += 1 -- the Workshop's proper tools
	end
	return recipe.amount + bonus
end

function InventoryService.canCraft(player, recipeId)
	local recipe = Items.Recipes[recipeId]
	local inv = inventories[player]
	if not recipe or not inv then
		return false, "Unknown recipe"
	end
	-- the whole batch must fit: never charge the full price for a partial yield
	local space = InventoryService.cap(player, recipe.output) - inv.items[recipe.output]
	local yield = InventoryService.recipeYield(player, recipe)
	if space < yield then
		return false, space <= 0 and (Items.Items[recipe.output].name .. ": satchel full")
			or ("Room for only %d %s: this makes %d. Use some first."):format(space, Items.Items[recipe.output].name, yield)
	end
	for itemId, amount in recipe.cost do
		if inv.items[itemId] < amount then
			return false, "Need " .. amount .. " " .. Items.Items[itemId].name
		end
	end
	return true
end

function InventoryService.craft(player, recipeId)
	local ok, reason = InventoryService.canCraft(player, recipeId)
	if not ok then
		return false, reason
	end
	local recipe = Items.Recipes[recipeId]
	for itemId, amount in recipe.cost do
		inventories[player].items[itemId] -= amount
	end
	InventoryService.add(player, recipe.output, InventoryService.recipeYield(player, recipe))
	return true
end

-- Pickups ----------------------------------------------------------------------------------

local function itemName(itemId)
	return itemId == "salvage" and "Salvage" or (Items.Items[itemId] and Items.Items[itemId].name or itemId)
end

-- Grants a list of { itemId, amount }; returns found-text list and leftovers that didn't fit.
function InventoryService.grantList(player, list)
	local found, leftovers = {}, {}
	for _, entry in list do
		local itemId, amount = entry[1], entry[2]
		local added = InventoryService.add(player, itemId, amount)
		if added > 0 then
			table.insert(found, added .. " " .. itemName(itemId))
		end
		if added < amount then
			table.insert(leftovers, { itemId, amount - added })
		end
	end
	return found, leftovers
end

-- Taking a loose item. It must vanish the instant it is taken: the prompt is switched off and the
-- item hidden before anything else, so a second press (or a controller button that fires the
-- prompt twice) can never take it again, and nothing is left floating behind.
local taking = setmetatable({}, { __mode = "k" })
local function vanish(pickupPart)
	for _, d in pickupPart:GetDescendants() do
		if d:IsA("ProximityPrompt") then
			d.Enabled = false
		elseif d:IsA("ParticleEmitter") then
			d.Enabled = false
		elseif d:IsA("Light") then
			d.Enabled = false
		end
	end
	pickupPart.Transparency = 1
	pickupPart.CanTouch = false
end

function InventoryService.pickup(player, pickupPart, itemId, amount)
	if not pickupPart.Parent or taking[pickupPart] then
		return
	end
	local info = Services.MatchService.getActiveInfo(player)
	if not info or (info.root.Position - pickupPart.Position).Magnitude > 12 then
		return
	end
	taking[pickupPart] = true
	amount = pickupPart:GetAttribute("Amount") or amount
	local added = InventoryService.add(player, itemId, amount)
	if added > 0 then
		Sfx.at(pickupPart.Position, "Pickup", 0.5, 25)
		local remaining = amount - added
		if remaining > 0 then
			pickupPart:SetAttribute("Amount", remaining)
			local prompt = pickupPart:FindFirstChildOfClass("ProximityPrompt")
			if prompt then
				prompt.ObjectText = ("%s (%d left: satchel full)"):format(itemName(itemId), remaining)
			end
			taking[pickupPart] = nil
		else
			vanish(pickupPart)
			pickupPart:Destroy()
		end
		Net.notify(player, "Toast", { text = "+" .. added .. " " .. itemName(itemId) })
	else
		taking[pickupPart] = nil
		Net.notify(player, "Toast", { text = itemName(itemId) .. ": satchel full" })
	end
end

InventoryService.itemName = itemName

function InventoryService.init(registry)
	Services = registry
end

function InventoryService.start()
	Players.PlayerRemoving:Connect(function(player)
		inventories[player] = nil
	end)
end

return InventoryService
