--!nonstrict
-- The Crossing director (the roguelike run):
--   Ferry      no crossing; pick crew, shop, repairs. Tide chart -> start a crossing.
--   Planning   at the Meridian mid-crossing: workbench, crafting, choose the next route.
--   Starting   short countdown, then the encounter.
--   Encounter  Salvage / Lantern Watch / Drift, or the finale (The Breakwater).
--   Results    debrief. Then back to Planning (next encounter) or Ferry (crossing over).
-- The satchel, weapons and workbench upgrades carry across a crossing; the Pall (difficulty)
-- rises after every encounter. Losing everyone ends the crossing; Scrip earned is kept.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Characters = require(Shared.Config.Characters)
local Encounters = require(Shared.Config.Encounters)
local Game = require(Shared.Config.Game)
local Modifiers = require(Shared.Config.Modifiers)
local Net = require(Shared.Net)
local Sfx = require(Shared.Util.Sfx)

local MatchService = {}
local Services

MatchService.state = "Ferry"
MatchService.modifier = Modifiers.None

local run = nil -- { id, index, pall, options, participants = { [Player] = true } }
local enc = nil -- current encounter state
local resultsAcknowledged = {}
local rng = Random.new()

local function now()
	return os.clock()
end

local function setState(newState)
	MatchService.state = newState
	ReplicatedStorage:SetAttribute("MatchState", newState)
end

local function publish()
	ReplicatedStorage:SetAttribute("RunActive", run ~= nil)
	ReplicatedStorage:SetAttribute("RunIndex", run and run.index or 0)
	ReplicatedStorage:SetAttribute("RunLength", Encounters.RunLength + 1)
	ReplicatedStorage:SetAttribute("Pall", run and run.pall or 0)
	ReplicatedStorage:SetAttribute("ModifierName", MatchService.modifier.name)
	ReplicatedStorage:SetAttribute("ModifierDesc", MatchService.modifier.desc)
	ReplicatedStorage:SetAttribute("ModifierId", MatchService.modifier.id)
	ReplicatedStorage:SetAttribute("EncounterType", enc and enc.type or "")
	ReplicatedStorage:SetAttribute("EncounterName", enc and enc.name or "")
	ReplicatedStorage:SetAttribute("Objective", enc and enc.objective or "")
	ReplicatedStorage:SetAttribute("Crates", enc and enc.crates or 0)
	ReplicatedStorage:SetAttribute("CratesRequired", enc and enc.cratesRequired or 0)
	ReplicatedStorage:SetAttribute("ExtractionOpen", enc and enc.extractionOpen or false)
	ReplicatedStorage:SetAttribute("LanternHP", enc and enc.lanternHP or 0)
	ReplicatedStorage:SetAttribute("LanternMax", enc and enc.lanternMax or 0)
	ReplicatedStorage:SetAttribute("Wave", enc and enc.wave or 0)
	ReplicatedStorage:SetAttribute("Waves", enc and enc.waves or 0)
	ReplicatedStorage:SetAttribute("EndsAt", enc and enc.endsAtServer or 0)
	ReplicatedStorage:SetAttribute("RouteOptions", run and HttpService:JSONEncode(run.options or {}) or "[]")
end

-- Queries --------------------------------------------------------------------------------

function MatchService.getActiveInfo(player)
	if MatchService.state ~= "Encounter" or not run or not run.participants[player] then
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

function MatchService.getActivePlayers()
	local list = {}
	if MatchService.state ~= "Encounter" or not run then
		return list
	end
	for player in run.participants do
		local info = MatchService.getActiveInfo(player)
		if info then
			table.insert(list, info)
		end
	end
	return list
end

-- For actions allowed on the Meridian (crafting, equipping).
function MatchService.getFerryInfo(player)
	if MatchService.state == "Encounter" and run and run.participants[player] then
		return nil
	end
	local session = Services.CharacterService.getSession(player)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not session or not session.charId or not root then
		return nil
	end
	return { player = player, char = char, root = root, session = session }
end

function MatchService.isParticipant(player)
	return run ~= nil and run.participants[player] == true
end

function MatchService.isPlanning()
	return MatchService.state == "Planning"
end

-- Ferry menus -----------------------------------------------------------------------------

function MatchService.openCharacterSelect(player)
	if MatchService.isParticipant(player) then
		Net.notify(player, "Toast", { text = "You can change crew once this crossing ends" })
		return
	end
	Net.notify(player, "OpenCharacterSelect", {})
end

function MatchService.openShop(player)
	Net.notify(player, "OpenShop", {})
end

function MatchService.openMenu(player, kind)
	Net.notify(player, kind, {})
end

local function ferrySpawnAll(resetInventory)
	local i = 0
	for _, player in Players:GetPlayers() do
		local session = Services.CharacterService.getSession(player)
		if session and session.charId then
			i += 1
			Services.CharacterService.spawn(player, Services.MapService.ferrySpawn(i), resetInventory and not MatchService.isParticipant(player))
		end
	end
end

local function rollModifier()
	if rng:NextNumber() < Modifiers.NoneChance then
		return Modifiers.None
	end
	return Modifiers.List[rng:NextInteger(1, #Modifiers.List)]
end

local function anyoneHas(repairId)
	for player in run and run.participants or {} do
		if Services.PlayerDataService.hasRepair(player, repairId) then
			return true
		end
	end
	return false
end

local function generateOptions()
	local options = {}
	if run.index > Encounters.RunLength then
		table.insert(options, { type = "Finale", name = Encounters.Finale.name, modifier = rollModifier().id, bonus = 0, map = "CanneryRow", mapName = "Cannery Row", factionName = "The Hushed" })
	else
		local types = { "Salvage", "LanternWatch", "Drift" }
		for i = #types, 2, -1 do
			local j = rng:NextInteger(1, i)
			types[i], types[j] = types[j], types[i]
		end
		local count = anyoneHas("radio") and 3 or 2
		local maps = table.clone(Services.MapService.MapIds)
		for i = #maps, 2, -1 do
			local j = rng:NextInteger(1, i)
			maps[i], maps[j] = maps[j], maps[i]
		end
		local factionIds = {}
		for id in Encounters.Factions do
			table.insert(factionIds, id)
		end
		table.sort(factionIds)
		for i = 1, count do
			local t = types[i]
			local faction = nil
			if run.index >= 2 and rng:NextNumber() < Encounters.FactionChance and t ~= "LanternWatch" then
				faction = factionIds[rng:NextInteger(1, #factionIds)]
			end
			table.insert(options, {
				type = t,
				name = Encounters.Types[t].name,
				modifier = rollModifier().id,
				bonus = ({ 0, 5, 10 })[rng:NextInteger(1, 3)],
				map = maps[(i - 1) % #maps + 1],
				mapName = Services.MapService.mapName(maps[(i - 1) % #maps + 1]),
				faction = faction,
				factionName = faction and Encounters.Factions[faction].name or "The Hushed",
			})
		end
	end
	run.options = options
	publish()
end

local function addToRun(player)
	if not run or run.participants[player] then
		return
	end
	local count = 0
	for _ in run.participants do
		count += 1
	end
	if count >= Game.MaxPartySize then
		Net.notify(player, "Toast", { text = "This crossing's crew is full. You'll join the next one." })
		return
	end
	if Services.CharacterService.beginRun(player, run.id, Services.HomebaseService.bonusesFor(player)) then
		run.participants[player] = true
		player:SetAttribute("InCrossing", true)
		if player.Character and MatchService.state == "Planning" then
			Services.WeaponService.onSpawn(player, player.Character) -- loadout may have changed
		end
	end
end

local function startRun()
	run = { id = HttpService:GenerateGUID(false), index = 1, pall = 1, participants = {} }
	for _, player in Players:GetPlayers() do
		local session = Services.CharacterService.getSession(player)
		if session and session.charId then
			addToRun(player)
		end
	end
	generateOptions()
	setState("Planning")
	ferrySpawnAll(false)
	Net.notifyAll("Toast", { text = "A crossing begins. Prepare at the workbench, then choose a route on the tide chart." })
end

function MatchService.requestChart(player)
	local session = Services.CharacterService.getSession(player)
	if not session or not session.charId then
		Net.notify(player, "OpenCharacterSelect", {})
		return
	end
	if MatchService.state == "Ferry" then
		startRun()
		Net.notifyAll("OpenChart", {})
	elseif MatchService.state == "Planning" then
		addToRun(player)
		Net.notify(player, "OpenChart", {})
	else
		Net.notify(player, "Toast", { text = "The crossing is already underway" })
	end
end

function MatchService.chooseRoute(player, index)
	if MatchService.state ~= "Planning" or not run or type(index) ~= "number" then
		return
	end
	addToRun(player)
	local option = run.options and run.options[math.floor(index)]
	if not option or not run.participants[player] then
		return
	end
	run.choice = option
	setState("Starting")
	ReplicatedStorage:SetAttribute("StartsAt", Workspace:GetServerTimeNow() + Game.StartCountdown)
	Net.notifyAll("CloseMenus", {})
	Net.notifyAll("Toast", { text = ("%s chose %s. Casting off…"):format(player.DisplayName, option.name) })
	task.delay(Game.StartCountdown, function()
		if MatchService.state == "Starting" then
			MatchService.beginEncounter(option)
		end
	end)
end

local function onSelectCharacter(player, charId, perkId)
	if type(charId) ~= "string" or (perkId ~= nil and type(perkId) ~= "string") or not Characters.List[charId] then
		return
	end
	if MatchService.isParticipant(player) then
		Net.notify(player, "Toast", { text = "You can change crew once this crossing ends" })
		return
	end
	if not Services.CharacterService.setCharacter(player, charId, perkId) then
		return
	end
	Services.CharacterService.spawn(player, Services.MapService.ferrySpawn(#Players:GetPlayers()), true)
	if MatchService.state == "Planning" then
		Net.notify(player, "Toast", { text = "A crossing is being planned: use the tide chart to join it." })
	elseif MatchService.state ~= "Ferry" then
		Net.notify(player, "Toast", { text = "A crossing is underway. You'll join at the next stop." })
	end
end

-- Encounters ------------------------------------------------------------------------------

local function participantsCount()
	local n = 0
	for p in run.participants do
		if p.Parent then
			n += 1
		end
	end
	return n
end

local function enemyBudget()
	local players = math.max(1, participantsCount())
	return math.min(Encounters.MaxEnemies, Encounters.BaseEnemies + (run.pall - 1) * Encounters.PerPall + (players - 1) * Encounters.PerExtraPlayer)
end

local function weightsForPall()
	local faction = enc and enc.option and enc.option.faction
	if faction and Encounters.Factions[faction] then
		return Encounters.Factions[faction].weights
	end
	local level = math.clamp(run.pall, 1, 4)
	return Encounters.TypeWeights[level]
end

local function farEdgeSpawn()
	local active = MatchService.getActivePlayers()
	local best, bestDist = nil, -1
	for _, pos in Services.MapService.EdgeSpawns do
		local nearest = math.huge
		for _, info in active do
			nearest = math.min(nearest, (info.root.Position - pos).Magnitude)
		end
		local score = nearest + rng:NextNumber() * 30
		if score > bestDist then
			best, bestDist = pos, score
		end
	end
	return best or Services.MapService.EdgeSpawns[1]
end

local function spawnPatrols(count)
	local routes = Services.MapService.PatrolRoutes
	for i = 1, count do
		local route = routes[(i - 1) % #routes + 1]
		local start = route[rng:NextInteger(1, #route)] + Vector3.new(rng:NextNumber(-3, 3), 0, rng:NextNumber(-3, 3))
		Services.EnemyService.spawn(Services.EnemyService.pickType(weightsForPall()), start, { route = route })
	end
end

function MatchService.beginEncounter(option)
	table.clear(resultsAcknowledged)
	local isFinale = option.type == "Finale"
	local def = isFinale and Encounters.Finale or Encounters.Types[option.type]
	local kind = isFinale and def.type or option.type
	MatchService.modifier = Modifiers.None
	for _, m in Modifiers.List do
		if m.id == option.modifier then
			MatchService.modifier = m
		end
	end

	enc = {
		type = kind,
		finale = isFinale,
		name = def.name,
		option = option,
		startedAt = now(),
		crates = 0,
		cratesRequired = kind == "Salvage" and def.crates or 0,
		extractionOpen = false,
		wave = 0,
		waves = def.waves or 0,
		lanternHP = def.lanternHP or 0,
		lanternMax = def.lanternHP or 0,
		endsAtServer = 0,
		nextHunt = 0,
		nextSpawn = 0,
	}
	if kind == "Salvage" then
		enc.objective = def.desc:format(def.crates)
	else
		enc.objective = def.desc
	end

	Services.EnemyService.clear()
	Services.PerceptionService.clearFog()
	Services.MapService.resetEncounter(MatchService.modifier, rng, kind, run.pall, option.map)
	Services.MapService.applyModifier(MatchService.modifier)

	local i = 0
	for player in run.participants do
		if player.Parent then
			i += 1
			Services.CharacterService.spawn(player, Services.MapService.encounterSpawn(i), false)
		end
	end

	local budget = enemyBudget()
	if kind == "Salvage" then
		spawnPatrols(budget)
	elseif kind == "LanternWatch" then
		spawnPatrols(math.ceil(budget * 0.4))
		enc.nextWaveAt = now() + 8
		enc.endsAt = now() + 8 + def.waves * def.waveTime
		enc.endsAtServer = Workspace:GetServerTimeNow() + 8 + def.waves * def.waveTime
	elseif kind == "Drift" then
		spawnPatrols(math.ceil(budget * 0.6))
		enc.endsAt = now() + def.duration
		enc.endsAtServer = Workspace:GetServerTimeNow() + def.duration
		enc.nextHunt = now() + 6
		enc.nextSpawn = now() + def.spawnInterval
	end

	setState("Encounter")
	publish()
	Net.notifyAll("EncounterStart", {
		name = def.name .. " · " .. (option.mapName or ""),
		faction = option.factionName,
		objective = enc.objective,
		modifierName = MatchService.modifier.name,
		modifierDesc = MatchService.modifier.desc,
		pall = run.pall,
	})
end

function MatchService.onCrateSalvaged(player, crate)
	if MatchService.state ~= "Encounter" or not enc or not crate.Parent then
		return
	end
	local info = MatchService.getActiveInfo(player)
	if not info or (info.root.Position - crate.Position).Magnitude > 12 then
		return
	end
	crate:Destroy()
	enc.crates += 1
	info.session.stats.crates += 1
	Services.InventoryService.add(player, "salvage", 4)
	Services.PerceptionService.emitNoise(info.root.Position, 7, "salvage", player)
	if enc.crates >= enc.cratesRequired and not enc.extractionOpen then
		enc.extractionOpen = true
		Services.MapService.activateExtraction()
		Net.notifyAll("Toast", { text = "Quota met. The Slipway flare is lit: get everyone there." })
	else
		Net.notifyAll("Toast", { text = ("Supply crate %d/%d"):format(enc.crates, enc.cratesRequired) })
	end
	publish()
end

function MatchService.onSpotted(player, enemy)
	local session = Services.CharacterService.getSession(player)
	if session then
		session.stats.detections += 1
	end
	Net.notify(player, "Spotted", {})
	Sfx.at(enemy.root.Position, "Spotted", 0.25, 40)
end

function MatchService.onEnemyKilled(player, e)
	if not player or not player.Parent then
		return
	end
	local session = Services.CharacterService.getSession(player)
	if session then
		session.stats.kills += 1
	end
	Services.InventoryService.add(player, "salvage", e.cfg.salvage or 2)
end

function MatchService.onObjectiveAttacked(amount)
	if not enc or enc.type ~= "LanternWatch" or MatchService.state ~= "Encounter" then
		return
	end
	enc.lanternHP = math.max(0, enc.lanternHP - amount)
	ReplicatedStorage:SetAttribute("LanternHP", enc.lanternHP)
end

function MatchService.onPlayerDowned(_player)
	-- the encounter loop checks for a wipe
end

-- Results -----------------------------------------------------------------------------------

local function today()
	return os.date("!%Y-%m-%d")
end

local function grantTokens(player, rewards, list)
	for kind, amount in rewards do
		if Services.PlayerDataService.addTokens(player, kind, amount) then
			table.insert(list, ("+%d %s"):format(amount, kind == "secondWind" and "Second Wind" or "Resupply"))
		end
	end
end

local function finishRun(win)
	for player in run.participants do
		if player.Parent then
			Services.CharacterService.endRun(player)
			player:SetAttribute("InCrossing", false)
			local data = Services.PlayerDataService.get(player)
			if data then
				data.stats.runs += 1
				if win then
					data.stats.wins += 1
				end
				data.stats.bestPall = math.max(data.stats.bestPall, run.pall)
			end
		end
	end
	run = nil
end

function MatchService.endEncounter(win)
	if MatchService.state ~= "Encounter" or not enc then
		return
	end
	setState("Results")
	MatchService.resultPlayers = {}
	for player in run.participants do
		MatchService.resultPlayers[player] = true
	end
	local elapsed = now() - enc.startedAt
	local runOver = (not win) or enc.finale
	local R = Encounters.Rewards
	for player in run.participants do
		if player.Parent then
			local session = Services.CharacterService.getSession(player)
			local data = Services.PlayerDataService.get(player)
			local rewards = {}
			if session and data then
				data.stats.takedowns += session.stats.takedowns
				if win then
					data.stats.encounters += 1
					local salvage = R.salvagePerEncounter + 5 * run.pall + (enc.option.bonus or 0)
					Services.InventoryService.add(player, "salvage", salvage)
					table.insert(rewards, ("+%d Salvage"):format(salvage))
					local scrip = R.scripPerEncounter + 5 * run.index + (enc.finale and R.scripRunComplete or 0)
					Services.PlayerDataService.addScrip(player, scrip)
					table.insert(rewards, ("+%d Scrip"):format(scrip))
					if enc.finale and Game.RunAidsEnabled then
						grantTokens(player, Game.WinReward, rewards)
						if data.lastDailyWin ~= today() then
							data.lastDailyWin = today()
							grantTokens(player, Game.DailyWinReward, rewards)
						end
					end
				end
				task.spawn(Services.PlayerDataService.save, player)
			end
			Net.notify(player, "Results", {
				win = win,
				runOver = runOver,
				runWon = win and enc.finale,
				name = enc.name,
				index = run.index,
				pall = run.pall,
				seconds = math.floor(elapsed),
				crates = enc.crates,
				takedowns = session and session.stats.takedowns or 0,
				kills = session and session.stats.kills or 0,
				detections = session and session.stats.detections or 0,
				rewards = rewards,
			})
		end
	end
	Services.EnemyService.clear()
	Services.PerceptionService.clearFog()

	if runOver then
		finishRun(win)
	else
		run.index += 1
		run.pall += 1
	end

	local token = {}
	MatchService.resultsToken = token
	task.delay(Game.ResultsDuration, function()
		if MatchService.resultsToken == token then
			MatchService.leaveResults()
		end
	end)
end

function MatchService.leaveResults()
	if MatchService.state ~= "Results" then
		return
	end
	MatchService.resultsToken = nil
	enc = nil
	Services.MapService.cleanupEncounter()
	MatchService.modifier = Modifiers.None
	Services.MapService.applyFerryLighting()
	if run then
		generateOptions()
		setState("Planning")
		publish()
		ferrySpawnAll(false)
		Net.notifyAll("Toast", { text = ("Back aboard. Pall level %d. Upgrade at the workbench, then read the tide chart."):format(run.pall) })
	else
		setState("Ferry")
		publish()
		ferrySpawnAll(true)
	end
end

-- Encounter loop ------------------------------------------------------------------------------

local function allStandingAtExtraction()
	local extraction = Services.MapService.ExtractionPos
	local anyStanding, allIn = false, true
	for player in run.participants do
		local info = MatchService.getActiveInfo(player)
		if info then
			anyStanding = true
			local flat = Vector3.new(info.root.Position.X - extraction.X, 0, info.root.Position.Z - extraction.Z)
			if flat.Magnitude > Game.ExtractionRadius then
				allIn = false
			end
		end
	end
	return anyStanding and allIn
end

local function tickEncounter()
	if MatchService.state ~= "Encounter" or not enc or not run then
		return
	end
	for player in run.participants do
		if not player.Parent then
			run.participants[player] = nil
		end
	end
	local active = MatchService.getActivePlayers()
	if #active == 0 then
		MatchService.endEncounter(false)
		return
	end
	local t = now()
	local def = enc.finale and Encounters.Finale or Encounters.Types[enc.type]

	if enc.type == "Salvage" then
		if enc.extractionOpen and allStandingAtExtraction() then
			MatchService.endEncounter(true)
		end
	elseif enc.type == "LanternWatch" then
		if enc.lanternHP <= 0 then
			Net.notifyAll("Toast", { text = "The lantern went dark." })
			MatchService.endEncounter(false)
			return
		end
		if enc.wave < enc.waves and t >= enc.nextWaveAt then
			enc.wave += 1
			enc.nextWaveAt = t + def.waveTime
			local count = def.perWave + (run.pall - 1) + (#active - 1)
			local lanternPos = Services.MapService.LanternPos
			for k = 1, count do
				local typeName = Services.EnemyService.pickType(weightsForPall())
				if enc.finale and enc.wave == enc.waves and k == 1 then
					typeName = def.boss
				end
				local origin = farEdgeSpawn() + Vector3.new(rng:NextNumber(-4, 4), 0, rng:NextNumber(-4, 4))
				Services.EnemyService.spawn(typeName, origin, { objective = lanternPos, objectiveDps = def.dps })
			end
			Net.notifyAll("Toast", { text = ("Wave %d of %d: they're coming for the light."):format(enc.wave, enc.waves) })
			publish()
		end
		if t >= enc.endsAt then
			Net.notifyAll("Toast", { text = "The tide turns. The lantern held." })
			MatchService.endEncounter(true)
		end
	elseif enc.type == "Drift" then
		if t >= enc.nextHunt and not enc.extractionOpen then
			enc.nextHunt = t + def.huntInterval
			Services.EnemyService.huntPulse(active)
		end
		if t >= enc.nextSpawn and not enc.extractionOpen and Services.EnemyService.count() < Encounters.MaxEnemies then
			enc.nextSpawn = t + def.spawnInterval
			for _ = 1, def.perSpawn + math.floor((run.pall - 1) / 2) do
				Services.EnemyService.spawn(Services.EnemyService.pickType(weightsForPall()), farEdgeSpawn(), { hunt = true, route = { farEdgeSpawn() } })
			end
		end
		if not enc.extractionOpen and t >= enc.endsAt then
			enc.extractionOpen = true
			Services.MapService.activateExtraction()
			Net.notifyAll("Toast", { text = "The tide turns. Get to the Slipway flare!" })
			publish()
		end
		if enc.extractionOpen and allStandingAtExtraction() then
			MatchService.endEncounter(true)
		end
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
		for p in MatchService.resultPlayers or {} do
			if p.Parent and not resultsAcknowledged[p] then
				return
			end
		end
		MatchService.leaveResults()
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
		if run then
			run.participants[player] = nil
		end
		resultsAcknowledged[player] = nil
	end)

	while true do
		task.wait(0.5)
		local ok, err = pcall(tickEncounter)
		if not ok then
			warn("[MatchService] " .. tostring(err))
		end
	end
end

return MatchService
