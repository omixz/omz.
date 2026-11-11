--!nonstrict
-- The Purser's Office ledger: the in-world shop. Prices come live from Roblox, contents are
-- fixed and shown in full, and every item says how to earn it for free.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Commerce = require(Shared.Config.Commerce)
local Game = require(Shared.Config.Game)
local Theme = require(script.Parent.Theme)
local State = require(script.Parent.Parent.State)

local Shop = {}
local C = Theme.Colors
local player = Players.LocalPlayer
local backdrop, tokenText

function Shop.prompt(productKey)
	local product = Commerce.Products[productKey]
	if not product or product.productId == 0 then
		return false
	end
	MarketplaceService:PromptProductPurchase(player, product.productId)
	return true
end

function Shop.build(gui)
	local panel
	backdrop, panel = Theme.modal(gui, "Shop", UDim2.new(0.92, 0, 0.86, 0), Vector2.new(640, 600))
	Theme.list(Enum.FillDirection.Vertical, 8).Parent = panel
	Theme.heading({ LayoutOrder = 1, Text = "THE PURSER'S LEDGER", TextSize = 28, Size = UDim2.new(1, 0, 0, 32), Parent = panel })
	Theme.label({ LayoutOrder = 2, Text = "\"Fair trade only. Nothing comes in a sealed box.\"  (Agnes Pell, Purser of the Meridian)", TextColor3 = C.dim, TextSize = 13, Size = UDim2.new(1, 0, 0, 34), Parent = panel })

	for i, key in Commerce.Order do
		local product = Commerce.Products[key]
		local row = Theme.panel({ LayoutOrder = 2 + i, Size = UDim2.new(1, 0, 0, 74), BackgroundColor3 = C.panelHi, Parent = panel })
		Theme.padding(10).Parent = row
		Theme.heading({ Text = string.upper(product.name), TextSize = 17, Size = UDim2.new(1, -150, 0, 20), Parent = row })
		Theme.label({ Text = product.desc, Position = UDim2.new(0, 0, 0, 22), Size = UDim2.new(1, -150, 0, 32), TextSize = 12, Parent = row })
		local configured = product.productId ~= 0
		local buy = Theme.button({
			Text = configured and ("R$ " .. product.price) or "NOT SET UP",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.new(0, 136, 0, 38),
			AutoButtonColor = configured,
			Parent = row,
		})
		if configured then
			task.spawn(function()
				local ok, info = pcall(function()
					return MarketplaceService:GetProductInfo(product.productId, Enum.InfoType.Product)
				end)
				if ok and info and info.PriceInRobux then
					buy.Text = "R$ " .. info.PriceInRobux
				end
			end)
			buy.Activated:Connect(function()
				Shop.prompt(key)
			end)
		end
	end

	tokenText = Theme.label({ LayoutOrder = 10, Text = "", TextSize = 13, Size = UDim2.new(1, 0, 0, 70), Parent = panel })
	Theme.label({
		LayoutOrder = 11,
		Text = "Coming soon in this office: crew outfits, lantern skins and cabin décor. Cosmetic only, never random.",
		TextColor3 = C.dim,
		TextSize = 12,
		Size = UDim2.new(1, 0, 0, 32),
		Parent = panel,
	})
	local close = Theme.button({ LayoutOrder = 12, Text = "CLOSE", Size = UDim2.new(0, 140, 0, 36), Parent = panel })
	close.Activated:Connect(Shop.close)
end

function Shop.refresh()
	if not backdrop or not backdrop.Visible then
		return
	end
	local winR = Game.WinReward.resupply or 0
	local dailySW = Game.DailyWinReward.secondWind or 0
	tokenText.Text = ("You hold: %d Second Wind · %d Resupply\nFree: +%d Resupply for every successful crossing, +%d Second Wind for your first successful crossing each day.%s"):format(
		player:GetAttribute("Tokens_secondWind") or 0,
		player:GetAttribute("Tokens_resupply") or 0,
		winR,
		dailySW,
		Game.RunAidsEnabled and "" or "\n(Run aids are switched off on this server.)"
	)
end

function Shop.open()
	if backdrop then
		backdrop.Visible = true
		State.setModal("shop", true)
		Shop.refresh()
	end
end

function Shop.close()
	if backdrop then
		backdrop.Visible = false
		State.setModal("shop", false)
	end
end

return Shop
