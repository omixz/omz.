--!nonstrict
-- All client-side audio:
--   ambience     wind + sea + low drone, mixed by where you are (ferry vs encounter)
--   music        a tension loop that swells when Hushed are suspicious of / hunting you,
--                a stinger when you're spotted, a resolve when you clear an encounter
--   body         footsteps for every character (surface-aware, quieter when crouched),
--                heartbeat at low health, hurt, Roblox's default character sounds muted
--   the Hushed   per-enemy breath / grind / groan loops, growls and shrieks on spotting
--   weapons      your gunshots play instantly; other players' play from the Shot event,
--                with distance-based loudness so far shots sound far
-- Uses the IDs in Config/Sounds (empty = silent).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Sfx = require(Shared.Util.Sfx)
local Geometry = require(Shared.Util.Geometry)
local State = require(script.Parent.Parent.State)

local SoundController = {}
local player = Players.LocalPlayer

local amb = {}
local music
local heartbeat
local stepState = setmetatable({}, { __mode = "k" }) -- [character] = distance since last step
local enemyAudio = setmetatable({}, { __mode = "k" }) -- [model] = { loop, lastState }

local DEFAULT_CHARACTER_SOUNDS = {
	Running = true, Jumping = true, Landing = true, FreeFalling = true, GettingUp = true,
	Climbing = true, Swimming = true, Splash = true, Died = true,
}

local function muteDefaultSounds(char)
	local function check(inst)
		if inst:IsA("Sound") and DEFAULT_CHARACTER_SOUNDS[inst.Name] then
			inst.Volume = 0
		end
	end
	for _, d in char:GetDescendants() do
		check(d)
	end
	char.DescendantAdded:Connect(check)
end

local function loop(key, volume)
	local s = Sfx.ui(key, volume, true)
	if s then
		s.Volume = 0
	end
	return s
end

function SoundController.gunshot(weaponId, position, isMine, quiet)
	local key = "Gun_" .. tostring(weaponId)
	local camPos = Workspace.CurrentCamera.CFrame.Position
	local dist = (position - camPos).Magnitude
	local volume = (isMine and 0.9 or 1.0) * (quiet and 0.35 or 1)
	if isMine then
		Sfx.ui(key, volume)
	else
		Sfx.at(position, key, volume, 600, 0.05)
		if dist > 120 then
			Sfx.ui(key, 0.25 * (quiet and 0.3 or 1)) -- distant echo carries across the map
		end
	end
end

function SoundController.impact(position, kind)
	if kind == "enemy" then
		Sfx.at(position, "ImpactSalt", 0.7, 60, 0.1)
	elseif kind == "world" then
		Sfx.at(position, "ImpactWorld", 0.5, 70, 0.12)
	end
end

local function updateFootsteps(dt)
	for _, p in Players:GetPlayers() do
		local char = p.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if root then
			local v = root.AssemblyLinearVelocity
			local speed = Vector3.new(v.X, 0, v.Z).Magnitude
			local crouched = char:GetAttribute("Stance") == "Crouch"
			local stride = speed > 16 and 4.0 or (speed > 10 and 3.3 or 2.4)
			local acc = (stepState[char] or 0) + speed * dt
			if speed > 1.5 and acc >= stride then
				acc = 0
				local water = Geometry.inTagged(root.Position, "Shallows")
				local vol = math.clamp(speed / 20, 0.2, 1) * (crouched and 0.35 or 1) * (p == player and 0.8 or 1)
				Sfx.at(root.Position - Vector3.new(0, 2.5, 0), water and "StepWater" or "Step", vol, 60, 0.12)
			end
			stepState[char] = acc
		end
	end
end

local VOICE = {
	Drifter = "Hushed_Breath",
	Rusher = "Hushed_Breath",
	Bellwether = "Hushed_Breath",
	Seeker = "Seeker_Grind",
	Tidewalker = "Tidewalker_Groan",
}

local function updateEnemies()
	local folder = Workspace:FindFirstChild("Enemies")
	if not folder then
		return 0
	end
	local camPos = Workspace.CurrentCamera.CFrame.Position
	local threat = 0
	local key = "Sus_" .. player.UserId
	for _, model in folder:GetChildren() do
		local torso = model:FindFirstChild("Torso")
		local state = model:GetAttribute("State")
		local typeName = model:GetAttribute("Type") or "Drifter"
		if torso then
			local a = enemyAudio[model]
			if not a then
				a = { loop = Sfx.attach(torso, VOICE[typeName] or "Hushed_Breath", 0.55, 70, true), lastState = state }
				if a.loop then
					a.loop.TimePosition = math.random() * 3
				end
				enemyAudio[model] = a
			end
			if a.loop then
				a.loop.Volume = (state == "Dispersed" and 0 or (state == "Chase" and 0.9 or 0.5))
				a.loop.PlaybackSpeed = state == "Chase" and 1.25 or 1
			end
			if state ~= a.lastState then
				if state == "Chase" then
					Sfx.at(torso.Position, typeName == "Rusher" and "Rusher_Shriek" or "Hushed_Growl", 1, 160, 0.08)
				elseif state == "Investigate" and math.random() < 0.5 then
					Sfx.at(torso.Position, "Hushed_Growl", 0.5, 70, 0.15)
				end
				a.lastState = state
			end
			-- tension: how much the Hushed near you care about you
			if (torso.Position - camPos).Magnitude < 120 then
				local sus = model:GetAttribute(key) or 0
				local hunting = state == "Chase" and model:GetAttribute("Target") == player.UserId
				threat = math.max(threat, hunting and 1 or (sus > 0.35 and 0.55 or sus))
			end
		end
	end
	return threat
end

function SoundController.start()
	amb.wind = loop("Amb_Wind")
	amb.sea = loop("Amb_Sea")
	amb.drone = loop("Amb_Drone")
	music = loop("Music_Tension")
	heartbeat = loop("Heartbeat")

	local function onChar(char)
		muteDefaultSounds(char)
	end
	for _, p in Players:GetPlayers() do
		if p.Character then
			onChar(p.Character)
		end
		p.CharacterAdded:Connect(onChar)
	end
	Players.PlayerAdded:Connect(function(p)
		p.CharacterAdded:Connect(onChar)
	end)

	Net.event("Notify").OnClientEvent:Connect(function(kind, data)
		data = data or {}
		if kind == "Shot" and typeof(data.from) == "Vector3" and data.shooter ~= player.UserId then
			SoundController.gunshot(data.weapon, data.from, false, data.quiet)
		elseif kind == "Spotted" then
			Sfx.ui("Stinger_Spotted", 0.7)
		elseif kind == "Hurt" then
			Sfx.ui("Hurt", 0.8)
		elseif kind == "Results" and data.win then
			Sfx.ui("Stinger_Clear", 0.6)
		end
	end)

	local musicLevel = 0
	RunService.Heartbeat:Connect(function(dt)
		updateFootsteps(dt)
		local threat = updateEnemies()
		local matchState = ReplicatedStorage:GetAttribute("MatchState")
		local inEncounter = matchState == "Encounter" and player:GetAttribute("InCrossing") == true
		local function fade(sound, target, rate)
			if sound then
				sound.Volume += (target - sound.Volume) * math.min(1, dt * (rate or 1.5))
			end
		end
		fade(amb.wind, inEncounter and 0.35 or 0.2)
		fade(amb.sea, inEncounter and 0.12 or 0.35)
		fade(amb.drone, inEncounter and (0.22 + threat * 0.1) or 0.08)
		musicLevel += ((inEncounter and threat or 0) - musicLevel) * math.min(1, dt * (threat > musicLevel and 2.5 or 0.4))
		fade(music, musicLevel * 0.45, 4)
		local char = State.character
		local hp = char and char:GetAttribute("HP") or 100
		local maxHp = char and char:GetAttribute("MaxHP") or 100
		local low = inEncounter and hp > 0 and hp / maxHp < 0.35
		fade(heartbeat, low and 0.6 or 0, 3)
		if heartbeat then
			heartbeat.PlaybackSpeed = low and (1.0 + (0.35 - hp / maxHp)) or 1
		end
	end)
end

return SoundController
