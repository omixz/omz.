--!nonstrict
-- The quest board: today's three challenges and this week's two, with progress.
-- Data comes from the server as the JSON attribute "Quests" (QuestService).
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local Theme = require(script.Parent.Theme)
local State = require(script.Parent.Parent.State)

local Quests = {}
local C = Theme.Colors
local player = Players.LocalPlayer
local backdrop, list

local function rebuild()
	Theme.clear(list)
	local ok, entries = pcall(function()
		return HttpService:JSONDecode(player:GetAttribute("Quests") or "[]")
	end)
	entries = ok and entries or {}
	local order = 0
	for _, kind in { "daily", "weekly" } do
		order += 1
		Theme.heading({ LayoutOrder = order, Text = kind == "daily" and "TODAY" or "THIS WEEK", TextSize = 16, TextColor3 = C.salt, Size = UDim2.new(1, 0, 0, 22), Parent = list })
		for _, q in entries do
			if q.kind == kind then
				order += 1
				local row = Theme.panel({ LayoutOrder = order, Size = UDim2.new(1, -8, 0, 64), BackgroundColor3 = C.panelHi, Parent = list })
				Theme.padding(8).Parent = row
				Theme.heading({ Text = string.upper(q.name), TextSize = 14, Size = UDim2.new(1, -150, 0, 18), Parent = row })
				Theme.label({ Text = q.desc, Position = UDim2.new(0, 0, 0, 20), Size = UDim2.new(1, -150, 0, 16), TextSize = 12, Parent = row })
				local bar = Theme.make("Frame", { Position = UDim2.new(0, 0, 0, 40), Size = UDim2.new(1, -150, 0, 6), BackgroundColor3 = Color3.fromRGB(40, 40, 38), BorderSizePixel = 0, Parent = row })
				Theme.make("Frame", { Size = UDim2.fromScale(math.clamp(q.p / math.max(1, q.target), 0, 1), 1), BackgroundColor3 = q.done and C.ok or C.lantern, BorderSizePixel = 0, Parent = bar })
				Theme.label({ Text = q.done and "DONE" or ("%d / %d"):format(q.p, q.target), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0, 140, 0, 18), TextXAlignment = Enum.TextXAlignment.Right, Font = Theme.Head, TextSize = 14, TextColor3 = q.done and C.ok or C.text, Parent = row })
				Theme.label({ Text = q.reward, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 22), Size = UDim2.new(0, 140, 0, 30), TextXAlignment = Enum.TextXAlignment.Right, TextWrapped = true, TextSize = 11, TextColor3 = C.dim, Parent = row })
			end
		end
	end
	if #entries == 0 then
		Theme.label({ LayoutOrder = 99, Text = "The board is being written up. Check back in a moment.", TextSize = 13, Size = UDim2.new(1, 0, 0, 20), Parent = list })
	end
end

function Quests.build(gui)
	local panel
	backdrop, panel = Theme.modal(gui, "Quests", UDim2.new(0.9, 0, 0.82, 0), Vector2.new(620, 560))
	Theme.heading({ Text = "QUEST BOARD", TextSize = 26, Size = UDim2.new(1, -120, 0, 32), Parent = panel })
	Theme.label({ Position = UDim2.new(0, 0, 0, 32), Text = "New challenges every day and every week. Rewards pay out the moment you finish.", TextSize = 12, TextColor3 = C.dim, Size = UDim2.new(1, -120, 0, 18), Parent = panel })
	local close = Theme.button({ Text = "CLOSE", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0, 100, 0, 32), Parent = panel })
	close.Activated:Connect(Quests.close)
	list = Theme.make("ScrollingFrame", {
		Position = UDim2.new(0, 0, 0, 58),
		Size = UDim2.new(1, 0, 1, -58),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = panel,
	})
	Theme.list(Enum.FillDirection.Vertical, 6).Parent = list
	player:GetAttributeChangedSignal("Quests"):Connect(function()
		if backdrop.Visible then
			rebuild()
		end
	end)
end

function Quests.open()
	if backdrop then
		backdrop.Visible = true
		State.setModal("quests", true)
		rebuild()
	end
end

function Quests.close()
	if backdrop then
		backdrop.Visible = false
		State.setModal("quests", false)
	end
end

return Quests
