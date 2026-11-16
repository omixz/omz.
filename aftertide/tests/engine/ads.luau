-- Ad offers must each point at a real developer product, and the service must load.
local Ads = require(Shared.Config.Ads)
local Commerce = require(Shared.Config.Commerce)
local AdsService = registry.AdsService
local out = { loaded = AdsService ~= nil, offers = {} }
for _, kind in Ads.Order do
	local offer = Ads.Offers[kind]
	local product = Commerce.Products[offer.product]
	table.insert(out.offers, { kind = kind, product = offer.product, id = product and product.productId or 0, random = product and product.randomItem or false })
end
return out
