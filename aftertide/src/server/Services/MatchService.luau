--!nonstrict
-- The Crossing loop for Slice 0:
--   Ferry (the Meridian: pick crew, shop, chart table) -> Starting (countdown)
--   -> Encounter (Salvage: find supply crates, then reach the Slipway flare)
--   -> Results -> back to the Ferry.
-- Stage 7 replaces the single encounter with the branching tide chart of several encounters.
-- Replicated state lives as attributes on ReplicatedStorage (MatchState, Crates, ...).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Characters = require(Shared.Config.Characters)
local Game = require(Shared.Config.Game)
local Modifiers = require(Shared.Config.Modifiers)
local Net = require(Shared.Net)
local Sfx = require(Shared.Util.Sfx)

local MatchService = {}
local Services

MatchService.state = "Ferry"
MatchService.modifier = Modifiers.None

local participants = {} -- [Player] = true for the current encounter
local cratesCollected = 0
local extractionOpen = false
local encounterStartedAt = 0
local resultsAcknowledged = {}

local function setState(state)
	MatchService.state = state
	ReplicatedStorage:SetAttribute("MatchState", state)
end

local function publish()
	ReplicatedStorage:SetAttribute("Crates", cratesCollected)
	ReplicatedStorage:SetAttribute("CratesRequired", Game.CratesRequired)
	ReplicatedStorage:SetAttribute("ExtractionOpen", extractionOpen)
	ReplicatedStorage:SetAttribute("ModifierName", MatchService.modifier.name)
	ReplicatedStorage:SetAttribute("ModifierDesc", MatchService.modifier.desc)
	ReplicatedStorage:SetAttribute("ModifierId", MatchService.modifier.id)
end

-- Players currently in the encounter, alive and not downed: { player, char, root, session }.
function MatchService.getActivePlayers()
	local list = {}
	if MatchService.state ~= "Encounter" then
		return list
	end
	for player in participants do
		local info = MatchService.getActiveInfo(player)
		if info then
			table.insert(list, info)
		end
	end
	return list
end

function MatchService.getActiveInfo(player)
	if MatchService.state ~= "Encounter" or not participants[player] then
		return nil
	end
	local session = Services.CharacterService.getSession(player)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not session or not root or session.downed or session.out then
		return nil
	end
	return { player = player, char = char, root = root, session = session }
end

function MatchService.isParticipant(player)
	return participants[player] == true
end

-- Ferry -----------------------------------------------------------------------------------

local function spawnAtFerry(player, index)
	return Services.CharacterService.spawn(player, Services.MapService.ferrySpawn(index or 1), false)
end

function MatchService.openCharacterSelect(player)
	if MatchService.state == "Encounter" and participants[player] then
		return
	end
	Net.notify(player, "OpenCharacterSelect", {})
end

function MatchService.openShop(player)
	Net.notify(player, "OpenShop", {})
end

local function onSelectCharacter(player, charId, perkId)
	if type(charId) ~= "string" or (perkId ~= nil and type(perkId) ~= "string") then
		return
	end
	if not Characters.List[charId] then
		return
	end
	if MatchService.state == "Encounter" and participants[player] then
		Net.notify(player, "Toast", { text = "You can change crew back on the Meridian" })
		return
	end
	if not Services.CharacterService.setCharacter(player, charId, perkId) then
		return
	end
	spawnAtFerry(player, #Players:GetPlayers())
	if MatchService.state == "Encounter" then
		Net.notify(player, "Toast", { text = "A crossing is underway. You'll join the next one from the chart table." })
	end
end

function MatchService.requestStart(player)
	if MatchService.state ~= "Ferry" then
		return
	end
	local session = Services.CharacterService.getSession(player)
	if not session or not session.charId then
		Net.notify(player, "OpenCharacterSelect", {})
		return
	end
	setState("Starting")
	ReplicatedStorage:SetAttribute("StartsAt", Workspace:GetServerTimeNow() + Game.StartCountdown)
	Net.notifyAll("Toast", { text = player.DisplayName .. " is plotting a crossing. Gather at the chart table!" })
	task.delay(Game.StartCountdown, function()
		if MatchService.state == "Starting" then
			MatchService.beginEncounter()
		end
	end)
end

-- Encounter -------------------------------------------------------------------------------

local function rollModifier(rng)
	if rng:NextNumber() < Modifiers.NoneChance then
		return Modifiers.None
	end
	return Modifiers.List[rng:NextInteger(1, #Modifiers.List)]
end

function MatchService.beginEncounter()
	local rng = Random.new()
	table.clear(participants)
	table.clear(resultsAcknowledged)
	local index = 0
	for _, player in Players:GetPlayers() do
		local session = Services.CharacterService.getSession(player)
		if session and session.charId and index < Game.MaxPartySize then
			index += 1
			participants[player] = true
		end
	end
	if index == 0 then
		setState("Ferry")
		return
	end

	MatchService.modifier = rollModifier(rng)
	cratesCollected = 0
	extractionOpen = false
	Services.MapService.resetEncounter(MatchService.modifier, rng)
	Services.MapService.applyModifier(MatchService.modifier)
	publish()

	local i = 0
	for player in participants do
		i += 1
		player:SetAttribute("InCrossing", true)
		Services.CharacterService.spawn(player, Services.MapService.encounterSpawn(i), true)
		local data = Services.PlayerDataService.get(player)
		if data then
			data.stats.runs += 1
		end
	end

	local count = math.min(Game.MaxEnemies, Game.BaseEnemies + (index - 1) * Game.EnemiesPerExtraPlayer)
	Services.EnemyService.spawnWave(count, Services.MapService.PatrolRoutes)

	encounterStartedAt = os.clock()
	setState("Encounter")
	Net.notifyAll("EncounterStart", {
		name = "Cannery Row",
		objective = ("Salvage %d supply crates, then reach the Slipway flare."):format(Game.CratesRequired),
		modifierName = MatchService.modifier.name,
		modifierDesc = MatchService.modifier.desc,
	})
end

function MatchService.onCrateSalvaged(player, crate)
	if MatchService.state ~= "Encounter" or not crate.Parent then
		return
	end
	local info = MatchService.getActiveInfo(player)
	if not info or (info.root.Position - crate.Position).Magnitude > 12 then
		return
	end
	crate:Destroy()
	cratesCollected += 1
	info.session.stats.crates += 1
	Services.PerceptionService.emitNoise(info.root.Position, 7, "salvage", player)
	publish()
	if cratesCollected >= Game.CratesRequired and not extractionOpen then
		extractionOpen = true
		Services.MapService.activateExtraction()
		publish()
		Net.notifyAll("Toast", { text = "Quota met. The Slipway flare is lit: get everyone there." })
	else
		Net.notifyAll("Toast", { text = ("Supply crate %d/%d"):format(cratesCollected, Game.CratesRequired) })
	end
end

function MatchService.onSpotted(player, enemy)
	local session = Services.CharacterService.getSession(player)
	if session then
		session.stats.detections += 1
	end
	Net.notify(player, "Spotted", {})
	Sfx.at(enemy.root.Position, "Spotted", 0.25, 40)
end

function MatchService.onPlayerDowned(_player)
	-- checked by the encounter loop; kept as a hook for analytics
end

local function today()
	return os.date("!%Y-%m-%d")
end

local function grant(player, rewards, list)
	for kind, amount in rewards do
		if Services.PlayerDataService.addTokens(player, kind, amount) then
			table.insert(list, ("+%d %s"):format(amount, kind == "secondWind" and "Second Wind" or "Resupply"))
		end
	end
end

function MatchService.endEncounter(win)
	if MatchService.state ~= "Encounter" then
		return
	end
	setState("Results")
	local elapsed = os.clock() - encounterStartedAt
	for player in participants do
		if player.Parent then
			local session = Services.CharacterService.getSession(player)
			local data = Services.PlayerDataService.get(player)
			local rewards = {}
			if session and data then
				data.stats.takedowns += session.stats.takedowns
				if win and not session.out then
					data.stats.wins += 1
					if Game.RunAidsEnabled then
						grant(player, Game.WinReward, rewards)
						if data.lastDailyWin ~= today() then
							data.lastDailyWin = today()
							grant(player, Game.DailyWinReward, rewards)
						end
					end
				end
				task.spawn(Services.PlayerDataService.save, player)
			end
			Net.notify(player, "Results", {
				win = win,
				seconds = math.floor(elapsed),
				crates = cratesCollected,
				takedowns = session and session.stats.takedowns or 0,
				detections = session and session.stats.detections or 0,
				rewards = rewards,
			})
		end
	end
	Services.EnemyService.clear()

	local token = {}
	MatchService.resultsToken = token
	task.delay(Game.ResultsDuration, function()
		if MatchService.resultsToken == token then
			MatchService.returnToFerry()
		end
	end)
end

function MatchService.returnToFerry()
	if MatchService.state ~= "Results" then
		return
	end
	MatchService.resultsToken = nil
	Services.MapService.cleanupEncounter()
	MatchService.modifier = Modifiers.None
	Services.MapService.applyModifier(Modifiers.None)
	for player in participants do
		if player.Parent then
			player:SetAttribute("InCrossing", false)
		end
	end
	table.clear(participants)
	setState("Ferry")
	publish()
	local i = 0
	for _, player in Players:GetPlayers() do
		local session = Services.CharacterService.getSession(player)
		if session and session.charId then
			i += 1
			spawnAtFerry(player, i)
		end
	end
end

local function checkEncounter()
	if MatchService.state ~= "Encounter" then
		return
	end
	local anyStanding = false
	local allStandingInZone = true
	local extraction = Services.MapService.ExtractionPos
	for player in participants do
		if not player.Parent then
			participants[player] = nil
		else
			local session = Services.CharacterService.getSession(player)
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			if session and root and not session.out and not session.downed then
				anyStanding = true
				local flat = Vector3.new(root.Position.X - extraction.X, 0, root.Position.Z - extraction.Z)
				if flat.Magnitude > Game.ExtractionRadius then
					allStandingInZone = false
				end
			end
		end
	end
	if not anyStanding then
		MatchService.endEncounter(false)
	elseif extractionOpen and allStandingInZone then
		MatchService.endEncounter(true)
	end
end

function MatchService.init(registry)
	Services = registry
end

function MatchService.start()
	setState("Ferry")
	publish()

	Net.onServer("SelectCharacter", 2, onSelectCharacter)
	Net.onServer("ReturnToFerry", 2, function(player)
		if MatchService.state ~= "Results" then
			return
		end
		resultsAcknowledged[player] = true
		for p in participants do
			if p.Parent and not resultsAcknowledged[p] then
				return
			end
		end
		MatchService.returnToFerry()
	end)

	local function onJoin(player)
		task.defer(function()
			Net.notify(player, "OpenCharacterSelect", {})
		end)
	end
	Players.PlayerAdded:Connect(onJoin)
	for _, player in Players:GetPlayers() do
		onJoin(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		participants[player] = nil
		resultsAcknowledged[player] = nil
	end)

	while true do
		task.wait(0.5)
		local ok, err = pcall(checkEncounter)
		if not ok then
			warn("[MatchService] " .. tostring(err))
		end
	end
end

return MatchService
