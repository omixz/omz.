--!nonstrict
-- Plays a one-shot 3D sound at a position (server: everyone hears it; client: only you).
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

local Sounds = require(script.Parent.Parent.Config.Sounds)

local Sfx = {}

function Sfx.at(position, soundKey, volume, maxDistance)
	local id = Sounds[soundKey]
	if not id or id == "" then
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
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume or 0.6
	sound.RollOffMaxDistance = maxDistance or 120
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.Parent = holder
	holder.Parent = Workspace
	sound:Play()
	Debris:AddItem(holder, 4)
end

return Sfx
