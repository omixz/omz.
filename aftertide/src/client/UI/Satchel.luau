--!nonstrict
-- The satchel: everything you carry, throwable selection, field crafting and run aids.
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Items = require(Shared.Config.Items)
local Stats = require(Shared.Stats)
local Theme = require(script.Parent.Theme)
local State = require(script.Parent.Parent.State)

local Satchel = {}
local C = Theme.Colors
local player = Players.LocalPlayer
local backdrop, partsText, ammoText, kitText, tokenText
local throwButtons = {}
local recipeLabels = {}
local firstButton
local sendAction

local function inv(id)
	return player:GetAttribute("Inv_" .. id) or 0
end

local function cap(id)
	return player:GetAttribute("Cap_" .. id) or Items.Items[id].cap
end

local function line(ids)
	local parts = {}
	for _, id in ids do
		table.insert(parts, ("%s %d/%d"):format(Items.Items[id].name, inv(id), cap(id)))
	end
	return table.concat(parts, "   ")
end

local function costText(recipe)
	local parts = {}
	for itemId, amount in recipe.cost do
		local have = inv(itemId)
		table.insert(parts, ("%d %s%s"):format(amount, Items.Items[itemId].name, have < amount and " ✕" or ""))
	end
	local mods = Stats.compute(player:GetAttribute("CharId"), player:GetAttribute("PerkId"))
	local yield = recipe.amount + ((recipe.perkYield and mods.craftYieldBonus) or 0)
	return table.concat(parts, " + ") .. (yield > 1 and ("  →  ×" .. yield) or "")
end

function Satchel.build(gui, actionSender)
	sendAction = actionSender
	local panel
	backdrop, panel = Theme.modal(gui, "Satchel", UDim2.new(0.94, 0, 0.9, 0), Vector2.new(640, 640))
	local scroller = Theme.make("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		Parent = panel,
	})
	Theme.list(Enum.FillDirection.Vertical, 8).Parent = scroller
	Theme.heading({ LayoutOrder = 1, Text = "SATCHEL", TextSize = 28, Size = UDim2.new(1, 0, 0, 32), Parent = scroller })
	partsText = Theme.label({ LayoutOrder = 2, Font = Theme.Head, TextSize = 14, Size = UDim2.new(1, 0, 0, 36), Parent = scroller })
	ammoText = Theme.label({ LayoutOrder = 3, Font = Theme.Head, TextSize = 14, Size = UDim2.new(1, 0, 0, 20), TextColor3 = C.lantern, Parent = scroller })
	kitText = Theme.label({ LayoutOrder = 4, Font = Theme.Head, TextSize = 14, Size = UDim2.new(1, 0, 0, 20), Parent = scroller })

	Theme.heading({ LayoutOrder = 5, Text = "THROWABLE (G to throw)", TextSize = 17, TextColor3 = C.salt, Size = UDim2.new(1, 0, 0, 22), Parent = scroller })
	local row = Theme.make("Frame", { LayoutOrder = 6, Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1, Parent = scroller })
	Theme.list(Enum.FillDirection.Horizontal, 6).Parent = row
	for i, id in Items.Throwables do
		local b = Theme.button({ LayoutOrder = i, Text = Items.Items[id].name, TextSize = 13, Size = UDim2.new(0.25, -5, 1, 0), Parent = row })
		throwButtons[id] = b
		b.Activated:Connect(function()
			State.throwable = id
		end)
		firstButton = firstButton or b
	end

	Theme.heading({ LayoutOrder = 7, Text = "CRAFT", TextSize = 17, TextColor3 = C.salt, Size = UDim2.new(1, 0, 0, 22), Parent = scroller })
	for i, recipeId in Items.RecipeOrder do
		local r = Theme.make("Frame", { LayoutOrder = 7 + i, Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1, Parent = scroller })
		recipeLabels[recipeId] = Theme.label({ Size = UDim2.new(1, -130, 1, 0), TextYAlignment = Enum.TextYAlignment.Center, TextSize = 13, Parent = r })
		local b = Theme.button({ Text = "CRAFT", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0, 120, 1, 0), Parent = r })
		b.Activated:Connect(function()
			sendAction("Craft", recipeId)
		end)
	end

	Theme.heading({ LayoutOrder = 20, Text = "RUN AIDS", TextSize = 17, TextColor3 = C.salt, Size = UDim2.new(1, 0, 0, 22), Parent = scroller })
	tokenText = Theme.label({ LayoutOrder = 21, TextSize = 12, Size = UDim2.new(1, 0, 0, 48), Parent = scroller })
	local resupply = Theme.button({ LayoutOrder = 22, Text = "USE RESUPPLY  [B]", Size = UDim2.new(0, 220, 0, 36), Parent = scroller })
	resupply.Activated:Connect(function()
		sendAction("Resupply")
	end)
	local close = Theme.button({ LayoutOrder = 23, Text = "CLOSE  [Tab]", Size = UDim2.new(0, 160, 0, 36), Parent = scroller })
	close.Activated:Connect(Satchel.close)
end

function Satchel.refresh()
	if not backdrop or not backdrop.Visible then
		return
	end
	partsText.Text = line({ "cloth", "alcohol", "powder" }) .. "\n" .. line({ "scrap", "tape", "canister" })
	ammoText.Text = line({ "pistolAmmo", "rifleAmmo", "shells", "arrows" })
	kitText.Text = line({ "dressing", "spike" })
	for id, b in throwButtons do
		local on = State.throwable == id
		b.Text = ("%s %d"):format(Items.Items[id].name, inv(id))
		b.BackgroundColor3 = on and C.lantern or C.panelHi
		b.TextColor3 = on and C.backdrop or C.text
	end
	for recipeId, label in recipeLabels do
		local recipe = Items.Recipes[recipeId]
		label.Text = recipe.name .. "  ·  " .. costText(recipe)
	end
	tokenText.Text = ("Second Wind: %d (when downed, once per crossing) · Resupply: %d (once per crossing)\nEarn more free by finishing crossings, or at the Purser's Office."):format(
		player:GetAttribute("Tokens_secondWind") or 0, player:GetAttribute("Tokens_resupply") or 0)
end

function Satchel.toggle()
	if not backdrop then
		return
	end
	if backdrop.Visible then
		Satchel.close()
	else
		backdrop.Visible = true
		State.setModal("satchel", true)
		Satchel.refresh()
		Theme.focus(firstButton)
	end
end

function Satchel.close()
	if backdrop then
		backdrop.Visible = false
		State.setModal("satchel", false)
	end
end

return Satchel
