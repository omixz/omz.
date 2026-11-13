--!nonstrict
-- The crew cabins: pick a character and ONE starting perk. Shows ability, loadout, innate perk.
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Characters = require(Shared.Config.Characters)
local Items = require(Shared.Config.Items)
local Weapons = require(Shared.Config.Weapons)
local Net = require(Shared.Net)
local Theme = require(script.Parent.Theme)
local State = require(script.Parent.Parent.State)

local CharacterSelect = {}
local C = Theme.Colors
local player = Players.LocalPlayer
local backdrop, closeButton

local function loadoutText(loadout)
	local guns = {}
	for _, slot in { "long", "sidearm" } do
		local id = loadout.weapons[slot]
		if id and Weapons.List[id] then
			table.insert(guns, Weapons.List[id].name)
		end
	end
	local parts = {}
	for _, itemId in Items.Order do
		local amount = loadout.items[itemId]
		if amount and amount > 0 then
			table.insert(parts, amount .. " " .. Items.Items[itemId].name)
		end
	end
	return table.concat(guns, " + ") .. "\n" .. table.concat(parts, " · ")
end

local function card(parent, charId, order)
	local def = Characters.List[charId]
	local selectedPerk = def.perks[1].id
	if player:GetAttribute("CharId") == charId and player:GetAttribute("PerkId") then
		selectedPerk = player:GetAttribute("PerkId")
	end

	local frame = Theme.panel({ Name = charId, LayoutOrder = order, Size = UDim2.new(0, 258, 0, 520), BackgroundColor3 = C.panelHi, Parent = parent })
	Theme.padding(12).Parent = frame
	Theme.list(Enum.FillDirection.Vertical, 5).Parent = frame

	local swatch = Theme.make("Frame", { LayoutOrder = 0, Size = UDim2.new(1, 0, 0, 6), BackgroundColor3 = def.colors.torso, BorderSizePixel = 0, Parent = frame })
	Theme.corner(3).Parent = swatch
	Theme.heading({ LayoutOrder = 1, Text = string.upper(def.name), TextSize = 22, Parent = frame })
	Theme.label({ LayoutOrder = 2, Text = def.role, TextColor3 = C.lantern, Font = Theme.Head, TextSize = 15, Size = UDim2.new(1, 0, 0, 18), Parent = frame })
	Theme.label({ LayoutOrder = 3, Text = def.bio, TextSize = 12, TextColor3 = C.dim, Size = UDim2.new(1, 0, 0, 32), Parent = frame })
	Theme.label({ LayoutOrder = 4, Text = "ABILITY · " .. def.ability.name, Font = Theme.Head, TextSize = 14, TextColor3 = C.salt, Size = UDim2.new(1, 0, 0, 16), Parent = frame })
	Theme.label({ LayoutOrder = 5, Text = def.ability.desc, TextSize = 12, Size = UDim2.new(1, 0, 0, 44), Parent = frame })
	Theme.label({ LayoutOrder = 6, Text = "LOADOUT", Font = Theme.Head, TextSize = 14, TextColor3 = C.salt, Size = UDim2.new(1, 0, 0, 16), Parent = frame })
	Theme.label({ LayoutOrder = 7, Text = loadoutText(def.loadout), TextSize = 12, Size = UDim2.new(1, 0, 0, 44), Parent = frame })
	Theme.label({ LayoutOrder = 8, Text = "INNATE · " .. def.innate.name, Font = Theme.Head, TextSize = 14, TextColor3 = C.salt, Size = UDim2.new(1, 0, 0, 16), Parent = frame })
	Theme.label({ LayoutOrder = 9, Text = def.innate.desc, TextSize = 12, Size = UDim2.new(1, 0, 0, 30), Parent = frame })
	Theme.label({ LayoutOrder = 10, Text = "STARTING PERK (choose one)", Font = Theme.Head, TextSize = 14, TextColor3 = C.salt, Size = UDim2.new(1, 0, 0, 16), Parent = frame })

	local perkRow = Theme.make("Frame", { LayoutOrder = 11, Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, Parent = frame })
	Theme.list(Enum.FillDirection.Horizontal, 4).Parent = perkRow
	local perkDesc = Theme.label({ LayoutOrder = 12, Text = "", TextSize = 12, Size = UDim2.new(1, 0, 0, 30), Parent = frame })
	local buttons = {}
	local function refresh()
		for id, button in buttons do
			local on = id == selectedPerk
			button.BackgroundColor3 = on and C.lantern or C.panel
			button.TextColor3 = on and C.backdrop or C.text
		end
		for _, perk in def.perks do
			if perk.id == selectedPerk then
				perkDesc.Text = perk.desc
			end
		end
	end
	for i, perk in def.perks do
		local b = Theme.button({ LayoutOrder = i, Text = perk.name, TextSize = 12, Size = UDim2.new(1 / 3, -3, 1, 0), Parent = perkRow })
		buttons[perk.id] = b
		b.Activated:Connect(function()
			selectedPerk = perk.id
			refresh()
		end)
	end
	refresh()

	local choose = Theme.button({ LayoutOrder = 13, Text = "CHOOSE " .. string.upper(def.name:match("^(%S+)")), Size = UDim2.new(1, 0, 0, 36), Parent = frame })
	choose.Activated:Connect(function()
		Net.event("SelectCharacter"):FireServer(charId, selectedPerk)
		CharacterSelect.close()
	end)
end

function CharacterSelect.build(gui)
	local panel
	backdrop, panel = Theme.modal(gui, "CharacterSelect", UDim2.new(0.96, 0, 0.92, 0), Vector2.new(1120, 640))
	Theme.heading({ Text = "THE CREW", TextSize = 30, Size = UDim2.new(1, -120, 0, 34), Parent = panel })
	Theme.label({ Text = "Every crew member is free. Each plays differently: own ability, loadout and perks.", Position = UDim2.new(0, 0, 0, 36), Size = UDim2.new(1, 0, 0, 20), TextColor3 = C.dim, TextSize = 13, Parent = panel })
	closeButton = Theme.button({ Text = "CLOSE", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0, 100, 0, 32), Parent = panel })
	closeButton.Activated:Connect(CharacterSelect.close)

	local scroller = Theme.make("ScrollingFrame", {
		Position = UDim2.new(0, 0, 0, 64),
		Size = UDim2.new(1, 0, 1, -64),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		ScrollingDirection = Enum.ScrollingDirection.XY,
		AutomaticCanvasSize = Enum.AutomaticSize.XY,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		Parent = panel,
	})
	Theme.list(Enum.FillDirection.Horizontal, 10).Parent = scroller
	for i, charId in Characters.Order do
		card(scroller, charId, i)
	end
end

function CharacterSelect.open()
	if not backdrop then
		return
	end
	closeButton.Visible = player:GetAttribute("CharId") ~= nil
	backdrop.Visible = true
	State.setModal("select", true)
end

function CharacterSelect.close()
	if not backdrop then
		return
	end
	backdrop.Visible = false
	State.setModal("select", false)
end

return CharacterSelect
