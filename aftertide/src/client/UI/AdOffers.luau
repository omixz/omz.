--!nonstrict
-- Optional rewarded video ads: "Free supplies". The player chooses an item, watches a short ad,
-- and gets the item free (the same item the shop sells). Nothing is ever forced behind an ad.
-- Buttons only appear when Roblox says an ad can be shown to this player right now.
local AdService = game:GetService("AdService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Ads = require(Shared.Config.Ads)
local Theme = require(script.Parent.Theme)
local State = require(script.Parent.Parent.State)

local AdOffers = {}
local C = Theme.Colors
local player = Players.LocalPlayer
local backdrop, list, statusLabel
local request, toast
local available, checkedAt, checking = false, -100, false
local cooldownUntil = {} -- [kind] = os.clock()

-- Asks Roblox whether a rewarded ad can be shown now (at most once every 45 s).
function AdOffers.refresh(force)
	if not Ads.Enabled or checking or (not force and os.clock() - checkedAt < 45) then
		return
	end
	checking = true
	task.spawn(function()
		local ok, result = pcall(function()
			return AdService:GetAdAvailabilityNowAsync(Enum.AdFormat.RewardedVideo)
		end)
		available = ok and result ~= nil and result.AdAvailabilityResult == Enum.AdAvailabilityResult.IsAvailable
		checkedAt = os.clock()
		checking = false
		if backdrop and backdrop.Visible then
			AdOffers.rebuild()
		end
	end)
end

function AdOffers.isAvailable()
	return Ads.Enabled and available
end

function AdOffers.watch(kind)
	if request then
		request("WatchAd", kind)
	end
end

function AdOffers.result(data)
	if type(data) ~= "table" then
		return
	end
	if data.ok then
		local offer = Ads.Offers[data.kind]
		cooldownUntil[data.kind] = os.clock() + (offer and offer.cooldown or 120)
	end
	if toast and data.text then
		toast(tostring(data.text))
	end
	checkedAt = -100
	AdOffers.refresh(true)
	if backdrop and backdrop.Visible then
		AdOffers.rebuild()
	end
end

function AdOffers.rebuild()
	if not list then
		return
	end
	Theme.clear(list)
	statusLabel.Text = available and "A short ad is ready. You choose what you want; it's free after you watch it to the end." or "No ad is available right now (or ads aren't enabled for you yet). Check back later: nothing here is required."
	statusLabel.TextColor3 = available and C.ok or C.dim
	for i, kind in Ads.Order do
		local offer = Ads.Offers[kind]
		local row = Theme.panel({ LayoutOrder = i, Size = UDim2.new(1, -8, 0, 74), BackgroundColor3 = C.panelHi, Parent = list })
		Theme.padding(10).Parent = row
		Theme.heading({ Text = string.upper(offer.title), TextSize = 18, Size = UDim2.new(1, -200, 0, 22), Parent = row })
		Theme.label({ Text = offer.gives, TextSize = 14, TextWrapped = true, Position = UDim2.new(0, 0, 0, 24), Size = UDim2.new(1, -200, 0, 40), Parent = row })
		local wait = math.ceil((cooldownUntil[kind] or 0) - os.clock())
		local text = not available and "NO AD AVAILABLE" or (wait > 0 and ("AGAIN IN %ds"):format(wait) or "WATCH AD · FREE")
		local b = Theme.button({ Text = text, TextSize = 15, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, 186, 0, 44), BackgroundColor3 = (available and wait <= 0) and Color3.fromRGB(150, 96, 40) or C.panel, Parent = row })
		b.Activated:Connect(function()
			if available and wait <= 0 then
				AdOffers.close()
				AdOffers.watch(kind)
			end
		end)
	end
end

function AdOffers.build(gui, requestFn, toastFn)
	request, toast = requestFn, toastFn
	local panel
	backdrop, panel = Theme.modal(gui, "AdOffers", UDim2.new(0.92, 0, 0.8, 0), Vector2.new(720, 560))
	Theme.heading({ Text = "FREE SUPPLIES · WATCH AN AD", TextSize = 26, Size = UDim2.new(1, -120, 0, 32), Parent = panel })
	statusLabel = Theme.label({ Position = UDim2.new(0, 0, 0, 36), Size = UDim2.new(1, -120, 0, 40), TextSize = 14, TextWrapped = true, Parent = panel })
	local close = Theme.button({ Text = "CLOSE", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0, 100, 0, 32), Parent = panel })
	close.Activated:Connect(AdOffers.close)
	list = Theme.make("ScrollingFrame", { Position = UDim2.new(0, 0, 0, 84), Size = UDim2.new(1, 0, 1, -84), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 5, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = panel })
	Theme.list(Enum.FillDirection.Vertical, 8).Parent = list
	task.spawn(function()
		while true do
			task.wait(1)
			if backdrop.Visible then
				AdOffers.rebuild() -- the cooldown counters tick
			end
		end
	end)
	AdOffers.refresh(true)
end

function AdOffers.open()
	if backdrop then
		backdrop.Visible = true
		State.setModal("adoffers", true)
		AdOffers.refresh(true)
		AdOffers.rebuild()
	end
end

function AdOffers.close()
	if backdrop then
		backdrop.Visible = false
		State.setModal("adoffers", false)
	end
end

return AdOffers
