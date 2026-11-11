--!nonstrict
-- The satchel: inventory, field crafting and run-aid tokens.
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Items = require(Shared.Config.Items)
local Stats = require(Shared.Stats)
local Theme = require(script.Parent.Theme)
local State = require(script.Parent.Parent.State)

local Satchel = {}
local C = Theme.Colors
local player = Players.LocalPlayer
local backdrop, invText, tokenText
local recipeLabels = {}
local sendAction

local function costText(recipe)
	local mods = Stats.compute(player:GetAttribute("CharId"), player:GetAttribute("PerkId"))
	local parts = {}
	for itemId, amount in recipe.cost do
		table.insert(parts, math.max(1, amount - mods.craftDiscount) .. " " .. Items.Items[itemId].name)
	end
	return table.concat(parts, " + ")
end

function Satchel.build(gui, actionSender)
	sendAction = actionSender
	local panel
	backdrop, panel = Theme.modal(gui, "Satchel", UDim2.new(0.92, 0, 0.8, 0), Vector2.new(560, 520))
	Theme.list(Enum.FillDirection.Vertical, 8).Parent = panel
	Theme.heading({ LayoutOrder = 1, Text = "SATCHEL", TextSize = 28, Size = UDim2.new(1, 0, 0, 32), Parent = panel })
	invText = Theme.label({ LayoutOrder = 2, Text = "", Font = Theme.Head, TextSize = 16, Size = UDim2.new(1, 0, 0, 44), Parent = panel })

	Theme.heading({ LayoutOrder = 3, Text = "CRAFT", TextSize = 18, TextColor3 = C.salt, Size = UDim2.new(1, 0, 0, 22), Parent = panel })
	for i, recipeId in Items.RecipeOrder do
		local recipe = Items.Recipes[recipeId]
		local row = Theme.make("Frame", { LayoutOrder = 3 + i, Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1, Parent = panel })
		recipeLabels[recipeId] = Theme.label({ Text = recipe.name, Size = UDim2.new(1, -130, 1, 0), TextYAlignment = Enum.TextYAlignment.Center, TextSize = 14, Parent = row })
		local b = Theme.button({ Text = "CRAFT", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0, 120, 1, 0), Parent = row })
		b.Activated:Connect(function()
			sendAction("Craft", recipeId)
		end)
	end

	Theme.heading({ LayoutOrder = 10, Text = "RUN AIDS", TextSize = 18, TextColor3 = C.salt, Size = UDim2.new(1, 0, 0, 22), Parent = panel })
	tokenText = Theme.label({ LayoutOrder = 11, Text = "", TextSize = 13, Size = UDim2.new(1, 0, 0, 52), Parent = panel })
	local resupply = Theme.button({ LayoutOrder = 12, Text = "USE RESUPPLY  [B]", Size = UDim2.new(0, 220, 0, 36), Parent = panel })
	resupply.Activated:Connect(function()
		sendAction("Resupply")
	end)
	local close = Theme.button({ LayoutOrder = 13, Text = "CLOSE  [Tab]", Size = UDim2.new(0, 160, 0, 36), Parent = panel })
	close.Activated:Connect(Satchel.close)
end

function Satchel.refresh()
	if not backdrop or not backdrop.Visible then
		return
	end
	local function inv(id)
		return player:GetAttribute("Inv_" .. id) or 0
	end
	invText.Text = ("Salt Shot %d · Bottle %d/%d · Bandage %d\nGlass %d · Cloth %d · Scrap %d"):format(
		inv("shot"), inv("bottle"), player:GetAttribute("Cap_bottle") or 3, inv("bandage"), inv("glass"), inv("cloth"), inv("scrap"))
	for recipeId, label in recipeLabels do
		local recipe = Items.Recipes[recipeId]
		label.Text = recipe.name .. "  ·  " .. costText(recipe)
	end
	tokenText.Text = ("Second Wind tokens: %d (use when downed, once per crossing)\nResupply tokens: %d (+4 shot, +1 bottle, +1 bandage, once per crossing)\nEarn more free by finishing crossings, or at the Purser's Office."):format(
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
	end
end

function Satchel.close()
	if backdrop then
		backdrop.Visible = false
		State.setModal("satchel", false)
	end
end

return Satchel
