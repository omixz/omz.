--!nonstrict
-- The Meridian repairs board: permanent homebase upgrades bought with Scrip (earned only by
-- playing), plus the armory once its rack is repaired.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Upgrades = require(Shared.Config.Upgrades)
local Weapons = require(Shared.Config.Weapons)
local Theme = require(script.Parent.Theme)
local State = require(script.Parent.Parent.State)

local Repairs = {}
local C = Theme.Colors
local player = Players.LocalPlayer
local backdrop, list, scripLabel
local request

local function owned()
	local ok, value = pcall(function()
		return HttpService:JSONDecode(player:GetAttribute("Repairs") or "{}")
	end)
	return ok and value or {}
end

local function rebuild()
	Theme.clear(list)
	scripLabel.Text = ("SCRIP %d   ·   earned by clearing encounters"):format(player:GetAttribute("Scrip") or 0)
	local have = owned()
	local first
	for i, r in Upgrades.Repairs do
		local done = have[r.id] == true
		local row = Theme.panel({ LayoutOrder = i, Size = UDim2.new(1, 0, 0, 56), BackgroundColor3 = C.panelHi, Parent = list })
		Theme.padding(8).Parent = row
		Theme.heading({ Text = string.upper(r.name), TextSize = 15, Size = UDim2.new(1, -130, 0, 18), Parent = row })
		Theme.label({ Text = r.desc, Position = UDim2.new(0, 0, 0, 20), Size = UDim2.new(1, -130, 0, 20), TextSize = 12, TextColor3 = C.dim, Parent = row })
		local b = Theme.button({
			Text = done and "REPAIRED" or (r.cost .. " SCRIP"),
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.new(0, 120, 0, 34),
			TextSize = 14,
			AutoButtonColor = not done,
			Parent = row,
		})
		if done then
			b.TextColor3 = C.ok
		else
			b.Activated:Connect(function()
				request("Repair", r.id)
			end)
			first = first or b
		end
	end
	if have.armory then
		Theme.heading({ LayoutOrder = 50, Text = "ARMORY: LONG GUN FOR YOUR NEXT CROSSING", TextSize = 16, TextColor3 = C.salt, Size = UDim2.new(1, 0, 0, 24), Parent = list })
		local rowFrame = Theme.make("Frame", { LayoutOrder = 51, Size = UDim2.new(1, 0, 0, 38), BackgroundTransparency = 1, Parent = list })
		Theme.list(Enum.FillDirection.Horizontal, 6).Parent = rowFrame
		local choice = player:GetAttribute("LongGunChoice")
		for i, id in Weapons.LongGuns do
			local b = Theme.button({ LayoutOrder = i, Text = Weapons.List[id].name, TextSize = 13, Size = UDim2.new(0.25, -5, 1, 0), Parent = rowFrame })
			if choice == id then
				b.BackgroundColor3 = C.lantern
				b.TextColor3 = C.backdrop
			end
			b.Activated:Connect(function()
				request("SetLongGun", id)
				task.delay(0.3, rebuild)
			end)
		end
	end
	Theme.focus(first)
end

function Repairs.build(gui, requestFn)
	request = requestFn
	local panel
	backdrop, panel = Theme.modal(gui, "Repairs", UDim2.new(0.94, 0, 0.9, 0), Vector2.new(660, 600))
	Theme.heading({ Text = "REPAIRING THE MERIDIAN", TextSize = 26, Size = UDim2.new(1, -120, 0, 32), Parent = panel })
	scripLabel = Theme.heading({ Position = UDim2.new(0, 0, 0, 34), Size = UDim2.new(1, 0, 0, 22), TextSize = 15, TextColor3 = C.lantern, Parent = panel })
	local close = Theme.button({ Text = "CLOSE", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0, 100, 0, 32), Parent = panel })
	close.Activated:Connect(Repairs.close)
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
	for _, attr in { "Scrip", "Repairs" } do
		player:GetAttributeChangedSignal(attr):Connect(function()
			if backdrop.Visible then
				rebuild()
			end
		end)
	end
end

function Repairs.open()
	if backdrop then
		backdrop.Visible = true
		State.setModal("repairs", true)
		rebuild()
	end
end

function Repairs.close()
	if backdrop then
		backdrop.Visible = false
		State.setModal("repairs", false)
	end
end

return Repairs
