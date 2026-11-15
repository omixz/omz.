--!nonstrict
-- Daily login streak (claimed automatically when you join each UTC day) and the Logbook:
-- torn pages placed on missions; reading one keeps it, and every few pages pays out.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Rewards = require(Shared.Config.Rewards)
local Net = require(Shared.Net)

local RewardsService = {}
local Services

local function dayNumber()
	return math.floor(os.time() / 86400)
end

local function grant(player, data, g)
	if g.scrip then
		Services.PlayerDataService.addScrip(player, g.scrip)
	end
	if g.materials then
		Services.PlayerDataService.addMaterials(player, g.materials)
	end
	for kind, n in g.tokens or {} do
		Services.PlayerDataService.addTokens(player, kind, n)
	end
	for kitId, n in g.kit or {} do
		data.kit = data.kit or {}
		data.kit[kitId] = (data.kit[kitId] or 0) + n
	end
	Services.PlayerDataService.publish(player)
end

local function publish(player, data)
	player:SetAttribute("Streak", data.streak or 0)
	player:SetAttribute("Pages", HttpService:JSONEncode(data.pages or {}))
end

function RewardsService.claimDaily(player)
	local data = Services.PlayerDataService.get(player)
	if not data then
		return
	end
	local today = dayNumber()
	if data.lastLoginDay == today then
		publish(player, data)
		return
	end
	local streak = (data.lastLoginDay == today - 1) and ((data.streak or 0) % #Rewards.Streak) + 1 or 1
	data.lastLoginDay = today
	data.streak = streak
	local reward = Rewards.Streak[streak]
	grant(player, data, reward.grant)
	publish(player, data)
	task.spawn(Services.PlayerDataService.save, player)
	Net.notify(player, "DailyReward", { day = streak, text = reward.text })
end

-- A page was picked up on a mission.
function RewardsService.findPage(player, pageId)
	local data = Services.PlayerDataService.get(player)
	local page = Rewards.page(pageId)
	if not data or not page then
		return
	end
	data.pages = data.pages or {}
	if data.pages[pageId] then
		Net.notify(player, "Toast", { text = "You've read this page before: " .. page.title })
		return
	end
	data.pages[pageId] = true
	local count = 0
	for _ in data.pages do
		count += 1
	end
	local text = ("Logbook page found (%d/%d): %s"):format(count, #Rewards.Pages, page.title)
	if count % Rewards.PageReward.every == 0 then
		grant(player, data, { scrip = Rewards.PageReward.scrip, materials = Rewards.PageReward.materials })
		text ..= ("  ·  +%d Scrip, +%d Materials"):format(Rewards.PageReward.scrip, Rewards.PageReward.materials)
	end
	publish(player, data)
	Net.notify(player, "Toast", { text = text })
	Net.notify(player, "PageFound", { id = pageId })
end

-- Which pages to put on the next mission: ones nobody in the crew has yet, if possible.
function RewardsService.pickPages(rng, count)
	local missing = {}
	local owned = {}
	for _, p in Players:GetPlayers() do
		local data = Services.PlayerDataService.get(p)
		for id in (data and data.pages) or {} do
			owned[id] = (owned[id] or 0) + 1
		end
	end
	for _, page in Rewards.Pages do
		table.insert(missing, { id = page.id, have = owned[page.id] or 0, r = rng:NextNumber() })
	end
	table.sort(missing, function(a, b)
		if a.have ~= b.have then
			return a.have < b.have
		end
		return a.r < b.r
	end)
	local out = {}
	for i = 1, math.min(count, #missing) do
		table.insert(out, missing[i].id)
	end
	return out
end

function RewardsService.init(registry)
	Services = registry
end

function RewardsService.start()
	local function onPlayer(player)
		task.spawn(function()
			if Services.PlayerDataService.waitFor(player, 20) then
				task.wait(4) -- let them see the deck first
				if player.Parent then
					RewardsService.claimDaily(player)
				end
			end
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in Players:GetPlayers() do
		onPlayer(p)
	end
end

return RewardsService
