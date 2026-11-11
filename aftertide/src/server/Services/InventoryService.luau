--!nonstrict
-- The satchel. Server-owned truth; replicated to the owner as player attributes "Inv_<item>".
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Items = require(Shared.Config.Items)
local Net = require(Shared.Net)

local InventoryService = {}
local Services

local inventories = {} -- [Player] = { [itemId] = count }

local function publish(player)
	local inv = inventories[player]
	if not inv then
		return
	end
	for _, itemId in Items.Order do
		player:SetAttribute("Inv_" .. itemId, inv[itemId] or 0)
	end
	player:SetAttribute("Cap_bottle", InventoryService.cap(player, "bottle"))
end

function InventoryService.cap(player, itemId)
	local def = Items.Items[itemId]
	if not def then
		return 0
	end
	local cap = def.cap
	if def.throwable then
		local session = Services.CharacterService.getSession(player)
		if session and session.mods then
			cap += session.mods.throwCapBonus
		end
	end
	return cap
end

function InventoryService.reset(player, loadout, mods)
	local inv = {}
	for _, itemId in Items.Order do
		inv[itemId] = 0
	end
	inventories[player] = inv
	for itemId, amount in loadout do
		InventoryService.add(player, itemId, amount)
	end
	if mods and mods.ammoBonus > 0 then
		InventoryService.add(player, "shot", mods.ammoBonus)
	end
	publish(player)
end

function InventoryService.count(player, itemId)
	local inv = inventories[player]
	return inv and inv[itemId] or 0
end

-- Returns how many were actually added (caps apply).
function InventoryService.add(player, itemId, amount)
	local inv = inventories[player]
	if not inv or not Items.Items[itemId] then
		return 0
	end
	local space = InventoryService.cap(player, itemId) - inv[itemId]
	local added = math.clamp(amount, 0, math.max(space, 0))
	inv[itemId] += added
	publish(player)
	return added
end

function InventoryService.take(player, itemId, amount)
	local inv = inventories[player]
	if not inv or (inv[itemId] or 0) < amount then
		return false
	end
	inv[itemId] -= amount
	publish(player)
	return true
end

function InventoryService.recipeCost(player, recipe)
	local session = Services.CharacterService.getSession(player)
	local discount = session and session.mods and session.mods.craftDiscount or 0
	local cost = {}
	for itemId, amount in recipe.cost do
		cost[itemId] = math.max(1, amount - discount)
	end
	return cost
end

function InventoryService.canCraft(player, recipeId)
	local recipe = Items.Recipes[recipeId]
	local inv = inventories[player]
	if not recipe or not inv then
		return false, "Unknown recipe"
	end
	if inv[recipe.output] >= InventoryService.cap(player, recipe.output) then
		return false, "Satchel full"
	end
	for itemId, amount in InventoryService.recipeCost(player, recipe) do
		if inv[itemId] < amount then
			return false, "Not enough " .. Items.Items[itemId].name
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
	for itemId, amount in InventoryService.recipeCost(player, recipe) do
		inventories[player][itemId] -= amount
	end
	InventoryService.add(player, recipe.output, recipe.amount)
	return true
end

function InventoryService.pickup(player, pickupPart, itemId, amount)
	if not pickupPart.Parent then
		return
	end
	local info = Services.MatchService.getActiveInfo(player)
	if not info then
		return
	end
	if (info.root.Position - pickupPart.Position).Magnitude > 12 then
		return
	end
	local added = InventoryService.add(player, itemId, amount)
	if added > 0 then
		pickupPart:Destroy()
		Net.notify(player, "Toast", { text = "+" .. added .. " " .. Items.Items[itemId].name })
	else
		Net.notify(player, "Toast", { text = "Satchel full: " .. Items.Items[itemId].name })
	end
end

function InventoryService.init(registry)
	Services = registry
end

function InventoryService.start()
	Players.PlayerRemoving:Connect(function(player)
		inventories[player] = nil
	end)
end

return InventoryService
