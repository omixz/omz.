--!nonstrict
-- Spawns crew characters (never the player's Roblox avatar), and owns health, downed state,
-- revives and bleed-out. Health is our own "HP" attribute: the Humanoid is never damaged.
--
-- Realistic characters: if ServerStorage > Rigs contains a custom R15-compatible model for
-- the crew member (Config/Rigs), it is used. Otherwise Marketplace body parts from
-- Config/Rigs.BodyParts, otherwise the faceless placeholder mannequin.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Characters = require(Shared.Config.Characters)
local Game = require(Shared.Config.Game)
local Stats = require(Shared.Stats)
local Net = require(Shared.Net)
local Geometry = require(Shared.Util.Geometry)
local Rigs = require(Shared.Config.Rigs)
local BodyBuilder = require(Shared.BodyBuilder)

local CharacterService = {}
local Services

local sessions = {} -- [Player] = session

local function newSession()
	return {
		charId = nil,
		perkId = nil,
		mods = Stats.compute(nil, nil),
		hp = Game.MaxHP,
		downed = false,
		out = false,
		bleedOutAt = 0,
		busyUntil = 0,
		channelId = 0,
		abilityReadyAt = 0,
		fireReadyAt = 0,
		shoveReadyAt = 0,
		calmUntil = 0,
		graceUntil = 0,
		usedSecondWind = false,
		usedResupply = false,
		stats = { takedowns = 0, detections = 0, crates = 0, kills = 0 },
		runId = nil,
		run = { weapons = {}, general = {}, perks = {} }, -- workbench upgrades this run
	}
end

function CharacterService.getSession(player)
	local session = sessions[player]
	if not session and player.Parent then
		session = newSession()
		sessions[player] = session
	end
	return session
end

function CharacterService.setCharacter(player, charId, perkId)
	local session = sessions[player]
	if not session or not Characters.List[charId] then
		return false
	end
	if not Stats.findPerk(charId, perkId) then
		perkId = Characters.List[charId].perks[1].id
	end
	session.charId = charId
	session.perkId = perkId
	CharacterService.refreshMods(player)
	player:SetAttribute("CharId", charId)
	player:SetAttribute("PerkId", perkId)
	return true
end

function CharacterService.publishRun(player)
	local session = sessions[player]
	if session then
		player:SetAttribute("RunUpgrades", HttpService:JSONEncode(session.run))
	end
end

function CharacterService.refreshMods(player)
	local session = sessions[player]
	if not session then
		return
	end
	session.mods = Stats.compute(session.charId, session.perkId, session.run.perks)
	CharacterService.publishRun(player)
end

-- Starts a new crossing for this player: fresh loadout (+ homebase bonuses), no upgrades.
function CharacterService.beginRun(player, runId, bonus)
	local session = CharacterService.getSession(player)
	if not session or not session.charId then
		return false
	end
	session.runId = runId
	session.run = { weapons = {}, general = {}, perks = {} }
	session.usedSecondWind = false
	session.usedResupply = false
	session.stats = { takedowns = 0, detections = 0, crates = 0, kills = 0 }
	CharacterService.refreshMods(player)
	Services.InventoryService.reset(player, Characters.List[session.charId].loadout, session.mods, bonus)
	return true
end

function CharacterService.endRun(player)
	local session = sessions[player]
	if session then
		session.runId = nil
		session.run = { weapons = {}, general = {}, perks = {} }
		CharacterService.refreshMods(player)
	end
end

function CharacterService.setGrace(player, seconds)
	local session = sessions[player]
	if session then
		session.graceUntil = math.max(session.graceUntil, os.clock() + seconds)
	end
end

local function buildDescription(def, charId)
	local desc = Instance.new("HumanoidDescription")
	desc.HeightScale = def.height or 1
	desc.WidthScale = 0.82
	desc.DepthScale = 0.85
	desc.HeadScale = 0.88
	desc.ProportionScale = 0
	desc.BodyTypeScale = 0
	local c = def.colors
	desc.HeadColor = c.skin
	desc.TorsoColor = c.torso
	desc.LeftArmColor = c.arms
	desc.RightArmColor = c.arms
	desc.LeftLegColor = c.legs
	desc.RightLegColor = c.legs
	local parts = Rigs.BodyParts[charId]
	if parts then
		for slot, assetId in parts do
			if type(assetId) == "number" and assetId > 0 then
				pcall(function()
					desc[slot] = assetId
				end)
			end
		end
	end
	return desc
end

local function customRig(charId)
	local folder = ServerStorage:FindFirstChild("Rigs")
	local name = Rigs.Custom[charId]
	local template = folder and name and folder:FindFirstChild(name)
	if template and template:IsA("Model") and template:FindFirstChildOfClass("Humanoid") and template:FindFirstChild("HumanoidRootPart") then
		return template
	end
	return nil
end

-- Spawns a custom rig as the player's character (keeps Animate if the rig contains one).
local function spawnCustomRig(player, template)
	local rig = template:Clone()
	rig.Name = player.Name
	local old = player.Character
	for _, child in StarterPlayer:WaitForChild("StarterCharacterScripts"):GetChildren() do
		if not rig:FindFirstChild(child.Name) then
			child:Clone().Parent = rig
		end
	end
	player.Character = rig
	rig.Parent = Workspace
	if old and old ~= rig then
		old:Destroy()
	end
	pcall(function()
		rig.HumanoidRootPart:SetNetworkOwner(player)
	end)
	return rig
end

local function setupCharacter(player, char, session, isCustomRig)
	local humanoid = char:WaitForChild("Humanoid")
	local root = char:WaitForChild("HumanoidRootPart")
	local head = char:WaitForChild("Head")

	humanoid.UseJumpPower = true
	humanoid.JumpPower = 0 -- grounded movement; vaulting comes in Stage 5
	humanoid.BreakJointsOnDeath = false
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.NameDisplayDistance = 60
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)

	if not isCustomRig then
		-- Replace the Roblox look and motion: sculpted, clothed body + our own animation
		-- (client PlayerAnimator) instead of the default Animate script.
		local animate = char:FindFirstChild("Animate")
		if animate then
			animate:Destroy()
		end
		local ok, err = pcall(BodyBuilder.build, char, Characters.List[session.charId])
		if not ok then
			warn("[CharacterService] body build failed: " .. tostring(err))
		end
		char:SetAttribute("Procedural", true)
	end

	local torch = Instance.new("SpotLight")
	torch.Name = "Torch"
	torch.Angle = 48
	torch.Range = 70
	torch.Brightness = 3.2
	torch.Color = Color3.fromRGB(255, 236, 205)
	torch.Shadows = true
	torch.Enabled = false
	torch.Parent = head

	char:SetAttribute("HP", session.hp)
	char:SetAttribute("MaxHP", Game.MaxHP)
	char:SetAttribute("Downed", false)
	char:SetAttribute("Out", false)
	char:SetAttribute("Torch", false)
	char:SetAttribute("Stance", "Stand")
	char:SetAttribute("Sprint", false)
	char:SetAttribute("Aim", false)
	char:SetAttribute("BusyUntil", 0)
	char:SetAttribute("Noise", 0)
	char:SetAttribute("AbilityReadyAt", 0)
	char:SetAttribute("CharId", session.charId)
	return root
end

-- (Re)spawns the player's chosen crew member at `cframe`.
-- resetInventory: give a fresh loadout (outside a run). During a run the satchel is kept.
function CharacterService.spawn(player, cframe, resetInventory)
	local session = sessions[player]
	if not session or not session.charId then
		return nil
	end
	local def = Characters.List[session.charId]

	session.hp = Game.MaxHP
	session.downed = false
	session.out = false
	session.busyUntil = 0
	session.channelId += 1
	session.abilityReadyAt = 0
	session.calmUntil = 0

	local char
	local template = customRig(session.charId)
	if template then
		char = spawnCustomRig(player, template)
	else
		local spawned
		local conn = player.CharacterAdded:Connect(function(c)
			spawned = c
		end)
		local ok, err = pcall(function()
			player:LoadCharacterWithHumanoidDescription(buildDescription(def, session.charId))
		end)
		local deadline = os.clock() + 8
		while ok and not spawned and player.Parent and os.clock() < deadline do
			task.wait()
		end
		conn:Disconnect()
		if not ok then
			warn("[CharacterService] spawn failed: " .. tostring(err))
			return nil
		end
		char = spawned or player.Character
	end
	if not char then
		return nil
	end
	setupCharacter(player, char, session, template ~= nil)
	CharacterService.setGrace(player, 3)
	char:PivotTo(cframe)
	if resetInventory or not Services.InventoryService.has(player) then
		Services.InventoryService.reset(player, def.loadout, session.mods)
	else
		Services.InventoryService.publish(player)
	end
	Services.WeaponService.onSpawn(player, char)
	return char
end

function CharacterService.heal(player, amount)
	local session = sessions[player]
	local char = player.Character
	if not session or not char or session.downed or session.out then
		return
	end
	session.hp = math.min(Game.MaxHP, session.hp + amount)
	char:SetAttribute("HP", session.hp)
end

local function removeRevivePrompt(char)
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local prompt = root and root:FindFirstChild("Revive")
	if prompt then
		prompt:Destroy()
	end
end

function CharacterService.revive(player, hp)
	local session = sessions[player]
	local char = player.Character
	if not session or not char or not session.downed or session.out then
		return false
	end
	session.downed = false
	session.hp = math.clamp(hp, 1, Game.MaxHP)
	char:SetAttribute("Downed", false)
	char:SetAttribute("HP", session.hp)
	removeRevivePrompt(char)
	Net.notifyAll("Toast", { text = player.DisplayName .. " is back up" })
	return true
end

function CharacterService.markOut(player)
	local session = sessions[player]
	if not session or session.out then
		return
	end
	session.out = true
	local char = player.Character
	if char then
		char:SetAttribute("Out", true)
		removeRevivePrompt(char)
	end
	Net.notifyAll("Toast", { text = player.DisplayName .. " was lost to the Pall" })
	Services.MatchService.onPlayerDowned(player)
end

function CharacterService.down(player)
	local session = sessions[player]
	local char = player.Character
	if not session or not char or session.downed then
		return
	end
	session.downed = true
	session.hp = 0
	session.channelId += 1
	Services.WeaponService.onDowned(player)
	local bleed = Game.BleedOutTime + session.mods.bleedOutBonus
	session.bleedOutAt = os.clock() + bleed
	char:SetAttribute("Downed", true)
	char:SetAttribute("HP", 0)
	char:SetAttribute("BleedOutAt", Workspace:GetServerTimeNow() + bleed)
	char:SetAttribute("Torch", false)
	local head = char:FindFirstChild("Head")
	local torch = head and head:FindFirstChild("Torch")
	if torch then
		torch.Enabled = false
	end

	local root = char:FindFirstChild("HumanoidRootPart")
	if root then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "Revive"
		prompt.ActionText = "Revive"
		prompt.ObjectText = player.DisplayName
		prompt.HoldDuration = Game.ReviveTime
		prompt.MaxActivationDistance = 8
		prompt.RequiresLineOfSight = false
		prompt.GamepadKeyCode = Enum.KeyCode.ButtonA
		prompt.Parent = root
		prompt.Triggered:Connect(function(reviver)
			if reviver == player then
				return
			end
			local info = Services.MatchService.getActiveInfo(reviver)
			if not info or (info.root.Position - root.Position).Magnitude > 12 then
				return
			end
			local reviverSession = sessions[reviver]
			CharacterService.revive(player, Game.ReviveHP + reviverSession.mods.reviveHPBonus)
		end)
	end

	Net.notifyAll("Toast", { text = player.DisplayName .. " is down!" })
	Services.MatchService.onPlayerDowned(player)
end

-- Damage from a Hushed grab. `fromPosition` drives the knockback direction.
function CharacterService.damage(player, amount, fromPosition)
	local session = sessions[player]
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not session or not root or session.downed or session.out then
		return
	end
	if os.clock() < (session.dodgeUntil or 0) then
		Net.notify(player, "Toast", { text = "Dodged!" })
		return
	end
	amount *= session.mods.damageTakenMult
	session.hp = math.max(0, session.hp - amount)
	session.channelId += 1 -- interrupts healing/crafting
	char:SetAttribute("HP", session.hp)
	char:SetAttribute("BusyUntil", 0)
	session.busyUntil = 0

	if fromPosition then
		local away = Geometry.flat(root.Position - fromPosition)
		if away.Magnitude > 0.01 then
			CharacterService.setGrace(player, 1.5)
			Net.notify(player, "Knockback", { velocity = away.Unit * 38 + Vector3.new(0, 14, 0) })
		end
	end
	Net.notify(player, "Hurt", { amount = amount })

	if session.hp <= 0 then
		CharacterService.down(player)
	end
end

function CharacterService.init(registry)
	Services = registry
end

function CharacterService.start()
	Players.PlayerAdded:Connect(function(player)
		CharacterService.getSession(player)
	end)
	for _, player in Players:GetPlayers() do
		if not sessions[player] then
			sessions[player] = newSession()
		end
	end
	Players.PlayerRemoving:Connect(function(player)
		sessions[player] = nil
	end)

	-- Stance/sprint/aim replicate as character attributes (used by AI, noise and other clients).
	Net.onServer("SetMoveState", 15, function(player, stance, sprinting, aiming)
		if stance ~= "Stand" and stance ~= "Crouch" then
			return
		end
		local char = player.Character
		local session = sessions[player]
		if not char or not session or session.downed then
			return
		end
		char:SetAttribute("Stance", stance)
		char:SetAttribute("Sprint", sprinting == true and stance == "Stand")
		char:SetAttribute("Aim", aiming == true)
	end)

	while true do
		task.wait(0.5)
		local now = os.clock()
		for player, session in sessions do
			if session.downed and not session.out and now >= session.bleedOutAt then
				CharacterService.markOut(player)
			end
		end
	end
end

return CharacterService
