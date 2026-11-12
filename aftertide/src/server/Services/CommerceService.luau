--!nonstrict
-- Developer product receipts. Rules that matter:
--   * Idempotent: a receipt (PurchaseId) is granted exactly once, even if Roblox retries.
--   * Only report PurchaseGranted once the grant is saved (or we're in memory-only Studio mode).
--   * Purchases grant TOKENS (persistent). Using a token is a separate, limited action
--     (Second Wind: once per crossing). If you're downed when a Second Wind purchase
--     completes, it is used straight away.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Commerce = require(Shared.Config.Commerce)
local Net = require(Shared.Net)

local CommerceService = {}
local Services

local byProductId = {}

local function processReceipt(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local data = Services.PlayerDataService.waitFor(player, 10)
	if not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local entry = byProductId[receipt.ProductId]
	if not entry then
		warn("[Commerce] unknown product id " .. tostring(receipt.ProductId) .. ": add it to Config/Commerce.luau")
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if Services.PlayerDataService.hasReceipt(player, receipt.PurchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local grant = entry.product.grant
	local data_ = Services.PlayerDataService.get(player)
	if grant.oneTime and data_.oneTime[entry.key] then
		-- already bought (e.g. a second prompt slipped through): give the tokens anyway so
		-- nobody loses Robux, but the outfits are already owned
		warn("[Commerce] one-time product bought again by " .. player.Name .. ": " .. entry.key)
	end
	for kind, amount in grant.tokens or {} do
		Services.PlayerDataService.addTokens(player, kind, amount)
	end
	if grant.outfit then
		Services.PlayerDataService.ownOutfit(player, grant.outfit)
	end
	for _, outfitId in grant.outfits or {} do
		Services.PlayerDataService.ownOutfit(player, outfitId)
	end
	if grant.oneTime then
		Services.PlayerDataService.markOneTime(player, entry.key)
	end
	data_.spent = (data_.spent or 0) + (receipt.CurrencySpent or entry.product.price or 0)
	Services.AnalyticsHelper.purchase(player, entry.key, receipt.CurrencySpent)
	Services.PlayerDataService.recordReceipt(player, receipt.PurchaseId)

	if not Services.PlayerDataService.save(player) and not Services.PlayerDataService.isMemoryOnly() then
		-- Granted in memory and receipt recorded, so a retry in this session won't double-grant.
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	Net.notify(player, "Toast", { text = "Thank you! " .. entry.product.name .. " added." })
	if grant.outfit then
		task.defer(Services.CosmeticsService.equip, player, grant.outfit)
	end
	if entry.key == "AmmoCache" or entry.key == "AmmoCache5" then
		task.defer(function()
			if Services.MatchService.getActiveInfo(player) then
				Services.ActionService.useAmmoCache(player)
			end
		end)
	end
	if entry.key == "SecondWind" or entry.key == "SecondWind3" then
		task.defer(function()
			local session = Services.CharacterService.getSession(player)
			if session and session.downed and not session.usedSecondWind then
				Services.ActionService.useSecondWind(player)
			end
		end)
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function CommerceService.init(registry)
	Services = registry
	for key, product in Commerce.Products do
		if product.productId and product.productId ~= 0 then
			byProductId[product.productId] = { key = key, product = product }
		end
	end
end

function CommerceService.start()
	MarketplaceService.ProcessReceipt = processReceipt
end

return CommerceService
