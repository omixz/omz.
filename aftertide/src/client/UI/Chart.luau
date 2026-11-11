--!nonstrict
-- The tide chart: choose the next encounter route (type, conditions, bonus).
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Encounters = require(Shared.Config.Encounters)
local Modifiers = require(Shared.Config.Modifiers)
local Theme = require(script.Parent.Theme)
local State = require(script.Parent.Parent.State)

local Chart = {}
local C = Theme.Colors
local backdrop, header, list
local request

local function modifierById(id)
	for _, m in Modifiers.List do
		if m.id == id then
			return m
		end
	end
	return Modifiers.None
end

local function rebuild()
	Theme.clear(list)
	local R = ReplicatedStorage
	header.Text = ("STOP %d OF %d  ·  PALL %d"):format(R:GetAttribute("RunIndex") or 1, R:GetAttribute("RunLength") or 4, R:GetAttribute("Pall") or 1)
	local ok, options = pcall(function()
		return HttpService:JSONDecode(R:GetAttribute("RouteOptions") or "[]")
	end)
	options = ok and options or {}
	local first
	for i, option in options do
		local def = option.type == "Finale" and Encounters.Finale or Encounters.Types[option.type]
		local mod = modifierById(option.modifier)
		local card = Theme.panel({ LayoutOrder = i, Size = UDim2.new(1, 0, 0, 124), BackgroundColor3 = C.panelHi, Parent = list })
		Theme.padding(10).Parent = card
		Theme.heading({ Text = string.upper(option.name), TextSize = 20, Size = UDim2.new(1, -170, 0, 24), Parent = card })
		local desc = def and def.desc or ""
		if option.type == "Salvage" then
			desc = desc:format(def.crates)
		end
		Theme.label({ Text = desc, Position = UDim2.new(0, 0, 0, 26), Size = UDim2.new(1, -170, 0, 34), TextSize = 13, Parent = card })
		Theme.label({
			Text = ("%s  ·  %s\nConditions: %s · %s%s"):format(option.mapName or "", option.factionName or "The Hushed", mod.name, mod.desc, (option.bonus or 0) > 0 and ("  ·  +" .. option.bonus .. " Salvage") or ""),
			Position = UDim2.new(0, 0, 0, 62),
			Size = UDim2.new(1, -170, 0, 44),
			TextSize = 12,
			TextColor3 = C.salt,
			Parent = card,
		})
		local go = Theme.button({ Text = "SET COURSE", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, 150, 0, 40), Parent = card })
		go.Activated:Connect(function()
			request("ChooseRoute", i)
			Chart.close()
		end)
		first = first or go
	end
	Theme.focus(first)
end

function Chart.build(gui, requestFn)
	request = requestFn
	local panel
	backdrop, panel = Theme.modal(gui, "Chart", UDim2.new(0.94, 0, 0.9, 0), Vector2.new(720, 560))
	Theme.heading({ Text = "THE TIDE CHART", TextSize = 28, Size = UDim2.new(1, -120, 0, 32), Parent = panel })
	header = Theme.label({ Position = UDim2.new(0, 0, 0, 34), Size = UDim2.new(1, 0, 0, 20), TextColor3 = C.lantern, Font = Theme.Head, Parent = panel })
	local close = Theme.button({ Text = "CLOSE", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0, 100, 0, 32), Parent = panel })
	close.Activated:Connect(Chart.close)
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
	Theme.list(Enum.FillDirection.Vertical, 8).Parent = list
	ReplicatedStorage:GetAttributeChangedSignal("RouteOptions"):Connect(function()
		if backdrop.Visible then
			rebuild()
		end
	end)
end

function Chart.open()
	if backdrop then
		backdrop.Visible = true
		State.setModal("chart", true)
		rebuild()
	end
end

function Chart.close()
	if backdrop then
		backdrop.Visible = false
		State.setModal("chart", false)
	end
end

return Chart
