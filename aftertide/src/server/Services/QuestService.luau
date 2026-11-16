--!nonstrict
-- Quest board: daily and weekly challenges (Config/Quests). The same picks for everyone that
-- day / week; progress from encounters; rewards (Scrip + Materials) pay out on completion.
-- Published to the client as the JSON attribute "Quests".
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Quests = require(Shared.Config.Quests)
local Net = require(Shared.Net)

local QuestService = {}
local Services

local lastStats = {} -- [Player] = { runId, takedowns, kills, crates } already counted

local function hash(text)
	local h = 0
	for i = 1, #text do
		h = (h * 31 + string.byte(text, i)) % 2147483647
	end
	return h
end

local function pick(pool, count, seedText)
	local rng = Random.new(hash(seedText))
	local ids = {}
	for _, q in pool do
		table.insert(ids, q)
	end
	for i = #ids, 2, -1 do
		local j = rng:NextInteger(1, i)
		ids[i], ids[j] = ids[j], ids[i]
	end
	local out = {}
	for i = 1, math.min(count, #ids) do
		table.insert(out, { id = ids[i].id, p = 0, done = false })
	end
	return out
end

local function keys()
	local now = os.time()
	local day = os.date("!%Y-%m-%d", now)
	local week = "W" .. tostring(math.floor((now / 86400 + 3) / 7)) -- weeks start Monday (UTC)
	return day, week
end

local function find(pool, id)
	for _, q in pool do
		if q.id == id then
			return q
		end
	end
	return nil
end

-- Rolls over to today's / this week's quests when needed. Returns the state table.
local function state(player)
	local data = Services.PlayerDataService.get(player)
	if not data then
		return nil
	end
	data.quests = data.quests or {}
	local q = data.quests
	local day, week = keys()
	if q.day ~= day then
		q.day = day
		q.daily = pick(Quests.Daily, Quests.DailyCount, "daily" .. day)
	end
	if q.week ~= week then
		q.week = week
		q.weekly = pick(Quests.Weekly, Quests.WeeklyCount, "weekly" .. week)
	end
	return q
end

local function publish(player)
	local q = state(player)
	if not q then
		return
	end
	local out = {}
	for _, group in { { "daily", Quests.Daily, q.daily }, { "weekly", Quests.Weekly, q.weekly } } do
		for _, entry in group[3] do
			local def = find(group[2], entry.id)
			if def then
				table.insert(out, {
					kind = group[1],
					name = def.name,
					desc = def.desc:format(def.target),
					p = math.min(entry.p, def.target),
					target = def.target,
					done = entry.done,
					reward = ("%d Scrip · %d Materials"):format(def.scrip, def.materials),
				})
			end
		end
	end
	player:SetAttribute("Quests", HttpService:JSONEncode(out))
end

local function add(player, stat, amount)
	if amount <= 0 then
		return
	end
	local q = state(player)
	if not q then
		return
	end
	for _, group in { { Quests.Daily, q.daily }, { Quests.Weekly, q.weekly } } do
		for _, entry in group[2] do
			local def = find(group[1], entry.id)
			if def and def.stat == stat and not entry.done then
				entry.p += amount
				if entry.p >= def.target then
					entry.done = true
					Services.PlayerDataService.addScrip(player, def.scrip)
					Services.PlayerDataService.addMaterials(player, def.materials)
					Net.notify(player, "Toast", { text = ("Quest complete: %s  (+%d Scrip, +%d Materials)"):format(def.name, def.scrip, def.materials) })
				end
			end
		end
	end
end

-- Called by MatchService at the end of every encounter.
function QuestService.onEncounterEnd(player, stats, win, enc, runOver)
	local session = Services.CharacterService.getSession(player)
	local runId = session and session.runId or "none"
	local last = lastStats[player]
	if not last or last.runId ~= runId then
		last = { runId = runId, takedowns = 0, kills = 0, crates = 0 }
		lastStats[player] = last
	end
	-- run stats accumulate over a crossing: count only what's new since the last encounter
	add(player, "takedowns", (stats.takedowns or 0) - last.takedowns)
	add(player, "kills", (stats.kills or 0) - last.kills)
	add(player, "objectives", (stats.crates or 0) - last.crates)
	last.takedowns, last.kills, last.crates = stats.takedowns or 0, stats.kills or 0, stats.crates or 0
	if win then
		add(player, "wins", 1)
		if (stats.detectionsThisEncounter or 0) == 0 then
			add(player, "unseenWins", 1)
		end
		if enc and enc.finale then
			add(player, "crossings", 1)
			add(player, "breakwater", 1)
		end
	end
	publish(player)
	assert(runOver ~= nil or true)
end

function QuestService.init(registry)
	Services = registry
end

function QuestService.start()
	local function onJoin(player)
		task.spawn(function()
			if Services.PlayerDataService.waitFor(player, 20) then
				publish(player)
			end
		end)
	end
	Players.PlayerAdded:Connect(onJoin)
	for _, p in Players:GetPlayers() do
		onJoin(p)
	end
	Players.PlayerRemoving:Connect(function(p)
		lastStats[p] = nil
	end)
	-- roll over at midnight UTC for anyone still playing
	while true do
		task.wait(300)
		for _, p in Players:GetPlayers() do
			publish(p)
		end
	end
end

return QuestService
