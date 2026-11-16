--!nonstrict
-- Leaderboards:
--   * leaderstats (Roblox's player list): Wins and Best Pall for everyone in the server
--   * a global top 10 (most wins) on the Meridian's board, from an OrderedDataStore
-- In Studio without API access the board shows the players in this server instead.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local LeaderboardService = {}
local Services

local store = nil
local names = {} -- userId -> display name cache
local lastWritten = {} -- [userId] = wins written

local function stats(player)
	local data = Services.PlayerDataService.get(player)
	return data and data.stats or nil
end

local function ensureStats(player)
	local folder = player:FindFirstChild("leaderstats")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "leaderstats"
		local wins = Instance.new("IntValue")
		wins.Name = "Wins"
		wins.Parent = folder
		local pall = Instance.new("IntValue")
		pall.Name = "Best Pall"
		pall.Parent = folder
		folder.Parent = player
	end
	return folder
end

-- Updates this player's leaderstats and their global score (called after every encounter).
function LeaderboardService.refreshPlayer(player)
	local s = stats(player)
	if not s then
		return
	end
	local folder = ensureStats(player)
	folder.Wins.Value = s.wins or 0
	folder["Best Pall"].Value = s.bestPall or 0
	if store and lastWritten[player.UserId] ~= s.wins and (s.wins or 0) > 0 then
		lastWritten[player.UserId] = s.wins
		task.spawn(function()
			pcall(function()
				store:SetAsync(tostring(player.UserId), s.wins)
			end)
		end)
	end
end

local function nameOf(userId)
	if names[userId] then
		return names[userId]
	end
	local p = Players:GetPlayerByUserId(userId)
	local name = p and p.DisplayName
	if not name then
		local ok, result = pcall(function()
			return Players:GetNameFromUserIdAsync(userId)
		end)
		name = ok and result or ("#" .. userId)
	end
	names[userId] = name
	return name
end

local board -- { title, rows = {TextLabel} }
local function buildBoard()
	local part = Services.MapService.getLeaderboardPart()
	if not part or board then
		return
	end
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Right -- faces down the deck (+X)
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.LightInfluence = 0.4
	gui.Parent = part
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(28, 32, 34)
	bg.BorderSizePixel = 0
	bg.Parent = gui
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0.14, 0)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.Oswald
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(232, 168, 92)
	title.Text = "SURVIVORS · MOST TIDES TURNED"
	title.Parent = bg
	local rows = {}
	for i = 1, 10 do
		local row = Instance.new("TextLabel")
		row.Position = UDim2.new(0.05, 0, 0.14 + (i - 1) * 0.084, 0)
		row.Size = UDim2.new(0.9, 0, 0.08, 0)
		row.BackgroundTransparency = 1
		row.Font = Enum.Font.Merriweather
		row.TextScaled = true
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextColor3 = Color3.fromRGB(226, 220, 206)
		row.Text = ""
		row.Parent = bg
		rows[i] = row
	end
	board = { title = title, rows = rows }
end

local function refreshBoard()
	buildBoard()
	if not board then
		return
	end
	local entries = {}
	local ok = false
	if store then
		ok = pcall(function()
			local page = store:GetSortedAsync(false, 10):GetCurrentPage()
			for _, e in page do
				table.insert(entries, { name = nameOf(tonumber(e.key)), wins = e.value })
			end
		end)
	end
	if not ok then
		board.title.Text = "SURVIVORS ABOARD · TIDES TURNED"
		for _, p in Players:GetPlayers() do
			local s = stats(p)
			table.insert(entries, { name = p.DisplayName, wins = s and s.wins or 0 })
		end
		table.sort(entries, function(a, b)
			return a.wins > b.wins
		end)
	end
	for i, row in board.rows do
		local e = entries[i]
		row.Text = e and ("%d.  %s  ·  %d"):format(i, e.name, e.wins) or ""
	end
end

function LeaderboardService.init(registry)
	Services = registry
end

function LeaderboardService.start()
	local ok, result = pcall(function()
		return DataStoreService:GetOrderedDataStore("Aftertide_Wins_v1")
	end)
	if ok and not Services.PlayerDataService.isMemoryOnly() then
		store = result
	end
	local function onJoin(player)
		task.spawn(function()
			ensureStats(player)
			if Services.PlayerDataService.waitFor(player, 20) then
				LeaderboardService.refreshPlayer(player)
			end
		end)
	end
	Players.PlayerAdded:Connect(onJoin)
	for _, p in Players:GetPlayers() do
		onJoin(p)
	end
	while true do
		task.wait(3)
		pcall(refreshBoard)
		task.wait(87)
	end
end

return LeaderboardService
