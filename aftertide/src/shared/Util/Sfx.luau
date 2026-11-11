--!nonstrict
-- One-shot 3D sounds (server: everyone hears it; client: only you) and attached loops.
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

local Sounds = require(script.Parent.Parent.Config.Sounds)

local Sfx = {}

local function make(soundKey, volume, maxDistance, pitchJitter)
	local id = Sounds[soundKey]
	if type(id) ~= "string" or id == "" then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = (volume or 0.6) * ((Sounds.Volume and Sounds.Volume[soundKey]) or 1)
	sound.RollOffMaxDistance = maxDistance or 120
	sound.RollOffMinDistance = 6
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	if pitchJitter and pitchJitter > 0 then
		sound.PlaybackSpeed = 1 + (math.random() * 2 - 1) * pitchJitter
	end
	return sound
end

function Sfx.has(soundKey)
	local id = Sounds[soundKey]
	return type(id) == "string" and id ~= ""
end

function Sfx.at(position, soundKey, volume, maxDistance, pitchJitter)
	local sound = make(soundKey, volume, maxDistance, pitchJitter or 0.06)
	if not sound then
		return
	end
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	holder.CFrame = CFrame.new(position)
	sound.Parent = holder
	holder.Parent = Workspace
	sound:Play()
	Debris:AddItem(holder, 8)
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
	sound.Parent = game:GetService("SoundService")
	sound:Play()
	if not looped then
		Debris:AddItem(sound, 12)
	end
	return sound
end

return Sfx
