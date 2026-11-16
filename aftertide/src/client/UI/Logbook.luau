--!nonstrict
-- The Logbook: torn pages found on missions (lore), and the daily streak calendar.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Rewards = require(Shared.Config.Rewards)
local Theme = require(script.Parent.Theme)
local State = require(script.Parent.Parent.State)

local Logbook = {}
local C = Theme.Colors
local player = Players.LocalPlayer
local backdrop, list, reader, readerTitle, readerText, streakCard

local function found()
	local ok, v = pcall(function()
		return HttpService:JSONDecode(player:GetAttribute("Pages") or "{}")
	end)
	return ok and type(v) == "table" and v or {}
end

local function rebuild()
	Theme.clear(list)
	local have = found()
	local n = 0
	for _ in have do
		n += 1
	end
	Theme.heading({ LayoutOrder = 0, Text = ("PAGES FOUND  %d / %d   ·   every %d pages: +%d Scrip, +%d Materials"):format(n, #Rewards.Pages, Rewards.PageReward.every, Rewards.PageReward.scrip, Rewards.PageReward.materials), TextSize = 14, TextColor3 = C.salt, Size = UDim2.new(1, 0, 0, 20), Parent = list })
	for i, page in Rewards.Pages do
		local got = have[page.id] == true
		local b = Theme.button({ LayoutOrder = i, Text = got and page.title or "? ? ?   (find it on a mission)", TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -8, 0, 32), AutoButtonColor = got, TextColor3 = got and C.text or C.dim, Parent = list })
		Theme.padding(8).Parent = b
		b.Activated:Connect(function()
			if got then
				readerTitle.Text = page.title
				readerText.Text = page.text
			end
		end)
	end
end

function Logbook.build(gui)
	local panel
	backdrop, panel = Theme.modal(gui, "Logbook", UDim2.new(0.92, 0, 0.85, 0), Vector2.new(980, 600))
	Theme.heading({ Text = "LOGBOOK", TextSize = 28, Size = UDim2.new(1, -120, 0, 34), Parent = panel })
	Theme.label({ Position = UDim2.new(0, 0, 0, 34), Text = "Torn pages lie somewhere on every mission (look for the glint). Pick one to read it.", TextSize = 12, TextColor3 = C.dim, Size = UDim2.new(1, -120, 0, 18), Parent = panel })
	local close = Theme.button({ Text = "CLOSE", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0, 100, 0, 32), Parent = panel })
	close.Activated:Connect(Logbook.close)
	list = Theme.make("ScrollingFrame", { Position = UDim2.new(0, 0, 0, 60), Size = UDim2.new(0.45, 0, 1, -60), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = panel })
	Theme.list(Enum.FillDirection.Vertical, 4).Parent = list
	reader = Theme.panel({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 60), Size = UDim2.new(0.53, 0, 1, -60), BackgroundColor3 = Color3.fromRGB(236, 226, 196), Parent = panel })
	Theme.padding(18).Parent = reader
	readerTitle = Theme.heading({ Text = "", TextSize = 20, TextColor3 = Color3.fromRGB(60, 44, 30), TextWrapped = true, Size = UDim2.new(1, 0, 0, 52), Parent = reader })
	readerText = Theme.label({ Text = "Pick a page you've found.", Font = Enum.Font.Merriweather, TextSize = 16, TextColor3 = Color3.fromRGB(50, 40, 30), TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Position = UDim2.new(0, 0, 0, 58), Size = UDim2.new(1, 0, 1, -58), Parent = reader })

	-- daily streak card (shown when the day's reward lands)
	streakCard = Theme.panel({ Name = "Streak", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 120), Size = UDim2.new(0, 640, 0, 150), Visible = false, ZIndex = 30, Parent = gui })
	Theme.padding(12).Parent = streakCard
	Theme.heading({ Name = "Title", Text = "DAILY REWARD", TextSize = 20, TextColor3 = Color3.fromRGB(255, 200, 90), Size = UDim2.new(1, -90, 0, 24), ZIndex = 31, Parent = streakCard })
	local ok = Theme.button({ Text = "NICE", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0, 80, 0, 26), ZIndex = 31, Parent = streakCard })
	ok.Activated:Connect(function()
		streakCard.Visible = false
	end)
	local row = Theme.make("Frame", { Name = "Days", Position = UDim2.new(0, 0, 0, 32), Size = UDim2.new(1, 0, 0, 90), BackgroundTransparency = 1, ZIndex = 31, Parent = streakCard })
	Theme.list(Enum.FillDirection.Horizontal, 6).Parent = row
	for i, d in Rewards.Streak do
		local cell = Theme.panel({ Name = "Day" .. i, LayoutOrder = i, Size = UDim2.new(1 / 7, -6, 1, 0), BackgroundColor3 = C.panelHi, ZIndex = 31, Parent = row })
		Theme.label({ Text = "DAY " .. i, Font = Theme.Head, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 18), ZIndex = 32, Parent = cell })
		Theme.label({ Text = d.text, TextSize = 11, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.new(0, 2, 0, 20), Size = UDim2.new(1, -4, 1, -22), ZIndex = 32, Parent = cell })
	end
	player:GetAttributeChangedSignal("Pages"):Connect(function()
		if backdrop.Visible then
			rebuild()
		end
	end)
end

function Logbook.showDaily(day, text)
	if not streakCard then
		return
	end
	streakCard.Title.Text = ("DAILY REWARD  ·  DAY %d: %s  ·  come back tomorrow for day %d"):format(day, tostring(text), day % #Rewards.Streak + 1)
	for i = 1, #Rewards.Streak do
		local cell = streakCard.Days:FindFirstChild("Day" .. i)
		if cell then
			cell.BackgroundColor3 = i == day and Color3.fromRGB(214, 150, 50) or (i < day and Color3.fromRGB(70, 110, 80) or C.panelHi)
		end
	end
	streakCard.Visible = true
	task.delay(12, function()
		streakCard.Visible = false
	end)
end

function Logbook.open()
	if backdrop then
		backdrop.Visible = true
		State.setModal("logbook", true)
		rebuild()
	end
end

function Logbook.close()
	if backdrop then
		backdrop.Visible = false
		State.setModal("logbook", false)
	end
end

return Logbook
