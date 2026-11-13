--!nonstrict
-- One-shot 3D sounds and attached loops, mixed through four SoundGroups (SFX, Ambience,
-- Music, UI).
--
-- Server: Sfx.at() does NOT play the sound on the server. It tells every client to play it
-- locally (Notify "Sfx"). Server-played one-shots replicate late: a 0.3 s gunshot or step can
-- be over before the client has even loaded it, which is why effects went silent.
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Sounds = require(script.Parent.Parent.Config.Sounds)

local Sfx = {}
local IS_SERVER = RunService:IsServer()

-- Mix levels per group (players can scale the master volume in Roblox's own menu).
local GROUPS = { SFX = 1.0, Ambience = 0.32, Music = 0.55, UI = 0.7 }
local GROUP_OF = {
	Amb_Wind = "Ambience", Amb_Sea = "Ambience", Amb_Drone = "Ambience", FireLoop = "SFX",
	Music_Tension = "Music", Stinger_Spotted = "Music", Stinger_Clear = "Music",
	Ui_Tick = "UI", Ui_Confirm = "UI",
}

local groups = {}
local function group(name)
	if groups[name] then
		return groups[name]
	end
	local g = SoundService:FindFirstChild("Mix_" .. name)
	if not g then
		g = Instance.new("SoundGroup")
		g.Name = "Mix_" .. name
		g.Volume = GROUPS[name] or 1
		g.Parent = SoundService
	end
	groups[name] = g
	return g
end

local function make(soundKey, volume, maxDistance, pitchJitter)
	local id = Sounds[soundKey]
	if type(id) ~= "string" or id == "" then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = (volume or 0.6) * ((Sounds.Volume and Sounds.Volume[soundKey]) or 1)
	sound.RollOffMaxDistance = maxDistance or 120
	sound.RollOffMinDistance = 8
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.SoundGroup = group(GROUP_OF[soundKey] or "SFX")
	if pitchJitter and pitchJitter > 0 then
		sound.PlaybackSpeed = 1 + (math.random() * 2 - 1) * pitchJitter
	end
	return sound
end

function Sfx.has(soundKey)
	local id = Sounds[soundKey]
	return type(id) == "string" and id ~= ""
end

-- Every sound instance, for ContentProvider:PreloadAsync on the client.
function Sfx.preloadList()
	local list = {}
	for key, id in Sounds do
		if type(id) == "string" and id:find("rbxassetid://") then
			local s = Instance.new("Sound")
			s.SoundId = id
			s.Name = key
			table.insert(list, s)
		end
	end
	return list
end

local function playLocal(position, soundKey, volume, maxDistance, pitchJitter)
	local sound = make(soundKey, volume, maxDistance, pitchJitter or 0.06)
	if not sound then
		return
	end
	local holder = Instance.new("Attachment")
	holder.Parent = Workspace.Terrain
	holder.WorldPosition = position
	sound.Parent = holder
	sound:Play()
	Debris:AddItem(holder, math.max(4, sound.TimeLength + 2))
end

function Sfx.at(position, soundKey, volume, maxDistance, pitchJitter)
	if typeof(position) ~= "Vector3" then
		return
	end
	if IS_SERVER then
		-- clients play it themselves (instant, and loaded ahead of time)
		local Net = require(script.Parent.Parent.Net)
		Net.notifyAll("Sfx", { p = position, k = soundKey, v = volume, d = maxDistance, j = pitchJitter })
		return
	end
	playLocal(position, soundKey, volume, maxDistance, pitchJitter)
end

-- Client: play a server request.
function Sfx.fromServer(data)
	if type(data) == "table" and type(data.k) == "string" then
		playLocal(data.p, data.k, tonumber(data.v), tonumber(data.d), tonumber(data.j))
	end
end

-- Attach a sound to a part (looping or one-shot). Returns the Sound or nil.
function Sfx.attach(part, soundKey, volume, maxDistance, looped)
	local sound = make(soundKey, volume, maxDistance, 0)
	if not sound then
		return nil
	end
	sound.Looped = looped == true
	sound.Parent = part
	sound:Play()
	if not looped then
		Debris:AddItem(sound, 10)
	end
	return sound
end

-- Non-positional (UI, music, ambience) on the client.
function Sfx.ui(soundKey, volume, looped)
	local sound = make(soundKey, volume, nil, 0)
	if not sound then
		return nil
	end
	sound.Looped = looped == true
	sound.Parent = SoundService
	sound:Play()
	if not looped then
		Debris:AddItem(sound, 12)
	end
	return sound
end

return Sfx
