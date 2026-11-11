--!nonstrict
-- The workbench: spend Salvage (found during the crossing) on weapon parts, satchel upgrades
-- and your character's other perks. Upgrades last for this crossing.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Characters = require(Shared.Config.Characters)
local Upgrades = require(Shared.Config.Upgrades)
local Weapons = require(Shared.Config.Weapons)
local Theme = require(script.Parent.Theme)
local State = require(script.Parent.Parent.State)

local Workbench = {}
local C = Theme.Colors
local player = Players.LocalPlayer
local backdrop, list, salvageLabel
local request

local function decode(attr)
	local ok, value = pcall(function()
		return HttpService:JSONDecode(player:GetAttribute(attr) or "{}")
	end)
	return ok and value or {}
end

local function price(base)
	local repairs = decode("Repairs")
	return math.ceil(base * (repairs.workshop and 0.85 or 1))
end

local function section(order, text)
	Theme.heading({ LayoutOrder = order, Text = text, TextSize = 17, TextColor3 = C.salt, Size = UDim2.new(1, 0, 0, 24), Parent = list })
end

local function row(order, title, desc, owned, cost, onBuy)
	local r = Theme.panel({ LayoutOrder = order, Size = UDim2.new(1, 0, 0, 54), BackgroundColor3 = C.panelHi, Parent = list })
	Theme.padding(8).Parent = r
	Theme.heading({ Text = title, TextSize = 15, Size = UDim2.new(1, -130, 0, 18), Parent = r })
	Theme.label({ Text = desc, Position = UDim2.new(0, 0, 0, 20), Size = UDim2.new(1, -130, 0, 18), TextSize = 12, TextColor3 = C.dim, Parent = r })
	local b = Theme.button({
		Text = owned and "FITTED" or ("%d SALVAGE"):format(cost),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.new(0, 120, 0, 34),
		TextSize = 14,
		AutoButtonColor = not owned,
		Parent = r,
	})
	if owned then
		b.TextColor3 = C.ok
	else
		b.Activated:Connect(onBuy)
	end
	return b
end

local function rebuild()
	Theme.clear(list)
	salvageLabel.Text = ("SALVAGE %d"):format(player:GetAttribute("Salvage") or 0)
	local run = decode("RunUpgrades")
	local owned = run.weapons or {}
	local order, first = 0, nil
	local function nextOrder()
		order += 1
		return order
	end
	if not player:GetAttribute("InCrossing") then
		Theme.label({ LayoutOrder = 1, Text = "The workbench is used between encounters during a crossing. Start one at the tide chart.", TextSize = 14, Size = UDim2.new(1, 0, 0, 40), Parent = list })
		return
	end
	for _, slot in { "long", "sidearm" } do
		local id = player:GetAttribute("W_" .. slot)
		if id and id ~= "" and Upgrades.Weapon[id] then
			section(nextOrder(), string.upper(Weapons.List[id].name))
			for _, upg in Upgrades.Weapon[id] do
				local has = owned[id] and owned[id][upg.id]
				local b = row(nextOrder(), upg.name, upg.desc, has, price(upg.cost), function()
					request("BuyWeaponUpgrade", id, upg.id)
				end)
				first = first or b
			end
		end
	end
	section(nextOrder(), "SATCHEL & GEAR")
	for _, upg in Upgrades.General do
		row(nextOrder(), upg.name, upg.desc, run.general and run.general[upg.id], price(upg.cost), function()
			request("BuyGeneral", upg.id)
		end)
	end
	local charId = player:GetAttribute("CharId")
	local def = charId and Characters.List[charId]
	if def then
		section(nextOrder(), "TRAINING: " .. string.upper(def.name))
		for _, perk in def.perks do
			local has = perk.id == player:GetAttribute("PerkId") or (run.perks and run.perks[perk.id])
			row(nextOrder(), perk.name, perk.desc, has, price(Upgrades.PerkCost), function()
				request("BuyPerk", perk.id)
			end)
		end
	end
	Theme.focus(first)
end

function Workbench.build(gui, requestFn)
	request = requestFn
	local panel
	backdrop, panel = Theme.modal(gui, "Workbench", UDim2.new(0.94, 0, 0.9, 0), Vector2.new(680, 640))
	Theme.heading({ Text = "WORKBENCH", TextSize = 28, Size = UDim2.new(1, -120, 0, 32), Parent = panel })
	salvageLabel = Theme.heading({ Position = UDim2.new(0, 0, 0, 34), Size = UDim2.new(1, 0, 0, 22), TextSize = 17, TextColor3 = C.lantern, Parent = panel })
	local close = Theme.button({ Text = "CLOSE", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0, 100, 0, 32), Parent = panel })
	close.Activated:Connect(Workbench.close)
	list = Theme.make("ScrollingFrame", {
		Position = UDim2.new(0, 0, 0, 64),
		Size = UDim2.new(1, 0, 1, -64),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		Parent = panel,
	})
	Theme.list(Enum.FillDirection.Vertical, 6).Parent = list
	for _, attr in { "Salvage", "RunUpgrades", "W_long", "W_sidearm" } do
		player:GetAttributeChangedSignal(attr):Connect(function()
			if backdrop.Visible then
				rebuild()
			end
		end)
	end
end

function Workbench.open()
	if backdrop then
		backdrop.Visible = true
		State.setModal("workbench", true)
		rebuild()
	end
end

function Workbench.close()
	if backdrop then
		backdrop.Visible = false
		State.setModal("workbench", false)
	end
end

return Workbench
