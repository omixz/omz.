--!nonstrict
-- The Purser's Office ledger: the in-world shop, in three tabs.
--   SUPPLIES   run aids (tokens) and the one-time Starter Pack. Fixed contents, never random.
--   WARDROBE   outfits for each crew member: equip, buy with Scrip, or buy with Robux.
--   SUPPORTER  the Supporter game pass.
-- Prices come live from Roblox; every run aid says how to earn it for free.
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Characters = require(Shared.Config.Characters)
local Commerce = require(Shared.Config.Commerce)
local Cosmetics = require(Shared.Config.Cosmetics)
local Game = require(Shared.Config.Game)
local Net = require(Shared.Net)
local Theme = require(script.Parent.Theme)
local State = require(script.Parent.Parent.State)

local Shop = {}
local C = Theme.Colors
local player = Players.LocalPlayer
local backdrop, body, tokenText, scripText
local tabButtons = {}
local currentTab = "Supplies"
local wardrobeChar = nil
local lastSig = ""
local livePrices = {}

local function decode(attr)
	local ok, t = pcall(function()
		return HttpService:JSONDecode(player:GetAttribute(attr) or "{}")
	end)
	return ok and t or {}
end

local function request(kind, a)
	Net.event("Request"):FireServer(kind, a)
end

function Shop.prompt(productKey)
	local product = Commerce.Products[productKey]
	if not product or product.productId == 0 then
		return false
	end
	MarketplaceService:PromptProductPurchase(player, product.productId)
	return true
end

local function promptPass(key)
	local pass = Commerce.Passes[key]
	if pass and pass.passId ~= 0 then
		MarketplaceService:PromptGamePassPurchase(player, pass.passId)
	end
end

local function priceLabel(productKey)
	local product = Commerce.Products[productKey]
	if not product or product.productId == 0 then
		return "NOT SET UP"
	end
	if livePrices[productKey] == nil then
		livePrices[productKey] = product.price
		task.spawn(function()
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfo(product.productId, Enum.InfoType.Product)
			end)
			if ok and info and info.PriceInRobux then
				livePrices[productKey] = info.PriceInRobux
				lastSig = "" -- redraw with the live price
			end
		end)
	end
	return "R$ " .. tostring(livePrices[productKey])
end

local function row(order, title, desc, height)
	local r = Theme.panel({ LayoutOrder = order, Size = UDim2.new(1, -8, 0, height or 74), BackgroundColor3 = C.panelHi, Parent = body })
	Theme.padding(10).Parent = r
	Theme.heading({ Text = string.upper(title), TextSize = 17, Size = UDim2.new(1, -300, 0, 20), Parent = r })
	Theme.label({ Text = desc, Position = UDim2.new(0, 0, 0, 22), Size = UDim2.new(1, -300, 1, -22), TextSize = 12, TextWrapped = true, Parent = r })
	local buttons = Theme.make("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, 290, 0, 38), BackgroundTransparency = 1, Parent = r })
	local l = Theme.list(Enum.FillDirection.Horizontal, 6)
	l.HorizontalAlignment = Enum.HorizontalAlignment.Right
	l.Parent = buttons
	return r, buttons
end

local function button(parent, text, enabled, onClick, accent)
	local b = Theme.button({ Text = text, Size = UDim2.new(0, 136, 1, 0), AutoButtonColor = enabled, Parent = parent })
	if not enabled then
		b.TextTransparency = 0.5
		b.BackgroundTransparency = 0.5
	elseif accent then
		b.BackgroundColor3 = C.lantern
		b.TextColor3 = C.panel
	end
	if enabled and onClick then
		b.Activated:Connect(onClick)
	end
	return b
end

-- Tabs ---------------------------------------------------------------------------------------

local function drawSupplies()
	local oneTime = decode("OneTime")
	local order = 0
	for _, key in Commerce.Order do
		local product = Commerce.Products[key]
		if not (product.grant.oneTime and oneTime[key]) then
			order += 1
			local _, buttons = row(order, product.name, product.desc)
			button(buttons, priceLabel(key), product.productId ~= 0, function()
				Shop.prompt(key)
			end, key == "StarterPack")
		end
	end
	tokenText = Theme.label({ LayoutOrder = 50, Text = "", TextSize = 13, Size = UDim2.new(1, -8, 0, 74), TextWrapped = true, Parent = body })
end

local function unlockText(outfit)
	if outfit.unlock == "default" then
		return "Included"
	elseif outfit.unlock == "scrip" then
		return ("Earn it: %d Scrip"):format(outfit.scrip)
	elseif outfit.unlock == "product" then
		return ("Robux, or earn it with %d Scrip"):format(outfit.scrip or 0)
	elseif outfit.unlock == "pack" then
		return "Comes with the Deckhand Starter Pack"
	elseif outfit.unlock == "supporter" then
		return "Meridian Supporter pass"
	end
	return ""
end

local function drawWardrobe()
	local owned = decode("Outfits")
	local equipped = decode("EquippedOutfits")
	local supporter = player:GetAttribute("Supporter") == true
	wardrobeChar = wardrobeChar or player:GetAttribute("CharId") or Characters.Order[1]

	local picker = Theme.make("Frame", { LayoutOrder = 1, Size = UDim2.new(1, -8, 0, 34), BackgroundTransparency = 1, Parent = body })
	Theme.list(Enum.FillDirection.Horizontal, 6).Parent = picker
	for i, charId in Characters.Order do
		local b = Theme.button({ LayoutOrder = i, Text = string.upper(Characters.List[charId].name:match("^(%S+)")), Size = UDim2.new(0, 120, 1, 0), Parent = picker })
		if charId == wardrobeChar then
			b.BackgroundColor3 = C.lantern
			b.TextColor3 = C.panel
		end
		b.Activated:Connect(function()
			wardrobeChar = charId
			lastSig = ""
		end)
	end

	for i, id in Cosmetics.Order[wardrobeChar] or {} do
		local outfit = Cosmetics.Outfits[id]
		local has = outfit.unlock == "default" or owned[id] == true or (outfit.unlock == "supporter" and supporter)
		local isOn = (equipped[wardrobeChar] or Cosmetics.defaultFor(wardrobeChar)) == id
		local r, buttons = row(1 + i, outfit.name, unlockText(outfit), 64)
		-- colour swatches
		local sw = Theme.make("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -300, 0, 2), Size = UDim2.new(0, 100, 0, 16), BackgroundTransparency = 1, Parent = r })
		Theme.list(Enum.FillDirection.Horizontal, 3).Parent = sw
		for j, slot in { "top", "pants", "hat", "pack", "scarf" } do
			local color = outfit.colors[slot]
			if color then
				Theme.make("Frame", { LayoutOrder = j, Size = UDim2.new(0, 16, 0, 16), BackgroundColor3 = color, BorderSizePixel = 0, Parent = sw })
			end
		end
		if has then
			button(buttons, isOn and "WEARING" or "WEAR", not isOn, function()
				request("EquipOutfit", id)
			end)
		else
			if outfit.unlock == "product" and outfit.product then
				button(buttons, priceLabel(outfit.product), Commerce.Products[outfit.product].productId ~= 0, function()
					Shop.prompt(outfit.product)
				end, true)
			end
			if outfit.scrip and outfit.scrip > 0 then
				local afford = (player:GetAttribute("Scrip") or 0) >= outfit.scrip
				button(buttons, ("%d SCRIP"):format(outfit.scrip), afford, function()
					request("BuyOutfit", id)
				end)
			elseif outfit.unlock == "pack" then
				button(buttons, "STARTER PACK", not decode("OneTime").StarterPack, function()
					currentTab = "Supplies"
					lastSig = ""
				end)
			elseif outfit.unlock == "supporter" then
				button(buttons, "SUPPORTER", true, function()
					currentTab = "Supporter"
					lastSig = ""
				end)
			end
		end
	end
	Theme.label({ LayoutOrder = 50, Text = "Outfits are cosmetic only. Your look changes straight away aboard the Meridian.", TextColor3 = C.dim, TextSize = 12, Size = UDim2.new(1, -8, 0, 30), TextWrapped = true, Parent = body })
end

local function drawSupporter()
	local pass = Commerce.Passes.Supporter
	local has = player:GetAttribute("Supporter") == true
	Theme.heading({ LayoutOrder = 1, Text = string.upper(pass.name), TextSize = 22, Size = UDim2.new(1, -8, 0, 28), Parent = body })
	Theme.label({ LayoutOrder = 2, Text = pass.desc, TextSize = 14, Size = UDim2.new(1, -8, 0, 70), TextWrapped = true, Parent = body })
	local holder = Theme.make("Frame", { LayoutOrder = 3, Size = UDim2.new(1, -8, 0, 40), BackgroundTransparency = 1, Parent = body })
	if has then
		Theme.label({ Text = "You're a Supporter. Thank you.", TextColor3 = C.ok, TextSize = 16, Size = UDim2.fromScale(1, 1), Parent = holder })
	else
		local b = button(holder, pass.passId ~= 0 and ("R$ " .. pass.price) or "NOT SET UP", pass.passId ~= 0, function()
			promptPass("Supporter")
		end, true)
		b.Size = UDim2.new(0, 200, 1, 0)
	end
end

local DRAW = { Supplies = drawSupplies, Wardrobe = drawWardrobe, Supporter = drawSupporter }

local function redraw()
	Theme.clear(body)
	tokenText = nil
	for name, b in tabButtons do
		b.BackgroundColor3 = name == currentTab and C.lantern or C.panelHi
		b.TextColor3 = name == currentTab and C.panel or C.text
	end
	DRAW[currentTab]()
end

function Shop.build(gui)
	local panel
	backdrop, panel = Theme.modal(gui, "Shop", UDim2.new(0.92, 0, 0.88, 0), Vector2.new(820, 640))
	Theme.list(Enum.FillDirection.Vertical, 8).Parent = panel
	Theme.heading({ LayoutOrder = 1, Text = "THE PURSER'S LEDGER", TextSize = 28, Size = UDim2.new(1, 0, 0, 32), Parent = panel })
	Theme.label({ LayoutOrder = 2, Text = "\"Fair trade only. Nothing comes in a sealed box.\"  (Agnes Pell, Purser of the Meridian)", TextColor3 = C.dim, TextSize = 13, Size = UDim2.new(1, 0, 0, 20), Parent = panel })

	local tabs = Theme.make("Frame", { LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, Parent = panel })
	Theme.list(Enum.FillDirection.Horizontal, 6).Parent = tabs
	for i, name in { "Supplies", "Wardrobe", "Supporter" } do
		local b = Theme.button({ LayoutOrder = i, Text = string.upper(name), Size = UDim2.new(0, 150, 1, 0), Parent = tabs })
		b.Activated:Connect(function()
			currentTab = name
			lastSig = ""
		end)
		tabButtons[name] = b
	end
	scripText = Theme.label({ LayoutOrder = 4, Text = "", TextSize = 13, TextColor3 = C.salt, Size = UDim2.new(1, 0, 0, 18), Parent = panel })

	body = Theme.make("ScrollingFrame", {
		LayoutOrder = 5,
		Size = UDim2.new(1, 0, 1, -170),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = panel,
	})
	Theme.list(Enum.FillDirection.Vertical, 6).Parent = body

	local close = Theme.button({ LayoutOrder = 6, Text = "CLOSE", Size = UDim2.new(0, 140, 0, 36), Parent = panel })
	close.Activated:Connect(Shop.close)
end

function Shop.refresh()
	if not backdrop or not backdrop.Visible then
		return
	end
	-- redraw only when something the shop shows has changed
	local sig = table.concat({
		currentTab, tostring(wardrobeChar), tostring(player:GetAttribute("Outfits")), tostring(player:GetAttribute("EquippedOutfits")),
		tostring(player:GetAttribute("OneTime")), tostring(player:GetAttribute("Supporter")), tostring(player:GetAttribute("Scrip")),
	}, "|")
	if sig ~= lastSig then
		lastSig = sig
		redraw()
	end
	scripText.Text = ("SCRIP %d%s"):format(player:GetAttribute("Scrip") or 0, player:GetAttribute("Supporter") and "   ·   SUPPORTER +10%" or "")
	if tokenText then
		local winR, winA = Game.WinReward.resupply or 0, Game.WinReward.ammo or 0
		local dailySW = Game.DailyWinReward.secondWind or 0
		tokenText.Text = ("You hold: %d Second Wind · %d Resupply · %d Ammo Cache   (use: R when downed · B · V)\nFree: +%d Resupply and +%d Ammo Cache for every successful crossing, +%d Second Wind for your first successful crossing each day.%s"):format(
			player:GetAttribute("Tokens_secondWind") or 0,
			player:GetAttribute("Tokens_resupply") or 0,
			player:GetAttribute("Tokens_ammo") or 0,
			winR,
			winA,
			dailySW,
			Game.RunAidsEnabled and "" or "\n(Run aids are switched off on this server.)"
		)
	end
end

function Shop.open(tab)
	if backdrop then
		currentTab = tab or currentTab
		wardrobeChar = player:GetAttribute("CharId") or wardrobeChar
		lastSig = ""
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
