--!nonstrict
-- Rewarded video ads. The client asks to watch an ad for one of the Config/Ads offers; the
-- server checks it is allowed, creates the reward from the offer's developer product and shows
-- the ad. When the player has watched it to the end, Roblox sends the normal purchase receipt
-- for that product, which CommerceService grants like a purchase (Robux spent: 0).
local AdService = game:GetService("AdService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Ads = require(Shared.Config.Ads)
local Commerce = require(Shared.Config.Commerce)
local Net = require(Shared.Net)

local AdsService = {}
local Services

local state = {} -- [Player] = { busy, last = { kind = time }, hour = { times }, pending = { [productId] = time } }

local function st(player)
	state[player] = state[player] or { busy = false, last = {}, hour = {}, pending = {} }
	return state[player]
end

local function notify(player, kind, ok, text)
	Net.notify(player, "AdResult", { kind = kind, ok = ok, text = text })
end

function AdsService.watch(player, kind)
	if not Ads.Enabled or type(kind) ~= "string" then
		return
	end
	local offer = Ads.Offers[kind]
	local product = offer and Commerce.Products[offer.product]
	if not (offer and product and product.productId and product.productId ~= 0) then
		return
	end
	local s = st(player)
	local now = os.time()
	if s.busy then
		return
	end
	if now - (s.last[kind] or 0) < offer.cooldown then
		notify(player, kind, false, ("Another %s ad is available in %ds."):format(offer.title, offer.cooldown - (now - (s.last[kind] or 0))))
		return
	end
	local recent = {}
	for _, t in s.hour do
		if now - t < 3600 then
			table.insert(recent, t)
		end
	end
	s.hour = recent
	if #recent >= Ads.MaxPerHour then
		notify(player, kind, false, "That's plenty of ads for now. Try again a little later.")
		return
	end
	s.busy = true
	local ok, result = pcall(function()
		local reward = AdService:CreateAdRewardFromDevProductId(product.productId)
		s.pending[product.productId] = now
		return AdService:ShowRewardedVideoAdAsync(player, reward)
	end)
	s.busy = false
	if not ok then
		warn("[Ads] could not show an ad: " .. tostring(result))
		s.pending[product.productId] = nil
		notify(player, kind, false, "No ad is available right now.")
		return
	end
	if result == Enum.ShowAdResult.ShowCompleted then
		s.last[kind] = now
		table.insert(s.hour, now)
		notify(player, kind, true, offer.title .. " is on its way.")
		Services.AnalyticsHelper.economy(player, "source", 0, Enum.AnalyticsEconomyTransactionType.Gameplay.Name, "Ad_" .. kind)
	else
		s.pending[product.productId] = nil
		notify(player, kind, false, "The ad didn't finish, so there's no reward. Watch it to the end to get it.")
	end
end

-- CommerceService asks this for every receipt: was it an ad reward (so no Robux were spent)?
function AdsService.takeAdReceipt(player, productId)
	local s = state[player]
	if s and s.pending[productId] and os.time() - s.pending[productId] < 300 then
		s.pending[productId] = nil
		return true
	end
	return false
end

function AdsService.init(registry)
	Services = registry
end

function AdsService.start()
	Players.PlayerRemoving:Connect(function(p)
		state[p] = nil
	end)
end

return AdsService
