--!nonstrict
-- AFTERTIDE client bootstrap.
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local State = require(script.Parent:WaitForChild("State"))
local Controllers = script.Parent:WaitForChild("Controllers")

-- Hide the default Roblox HUD pieces we replace (health bar, backpack). Chat and the player
-- list stay: co-op players need them.
task.spawn(function()
	for _ = 1, 20 do
		local ok = pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.EmotesMenu, false)
		end)
		if ok then
			break
		end
		task.wait(0.5)
	end
end)

local ORDER = { "CameraController", "MovementController", "ActionController", "EffectsController", "UIController" }
local controllers = {}
for _, name in ORDER do
	controllers[name] = require(Controllers:WaitForChild(name))
end
for _, name in ORDER do
	if controllers[name].init then
		controllers[name].init(controllers)
	end
end
for _, name in ORDER do
	if controllers[name].start then
		task.spawn(controllers[name].start)
	end
end

local function bindCharacter(char)
	local humanoid = char:WaitForChild("Humanoid")
	local root = char:WaitForChild("HumanoidRootPart")
	State.character = char
	State.humanoid = humanoid
	State.root = root
	State.baseHipHeight = humanoid.HipHeight
	State.crouched = false
	State.sprinting = false
	State.aiming = false
	State.downed = false
	for _, name in ORDER do
		if controllers[name].onCharacter then
			task.spawn(controllers[name].onCharacter, char)
		end
	end
end

player.CharacterAdded:Connect(bindCharacter)
player.CharacterRemoving:Connect(function(char)
	if State.character == char then
		State.character, State.humanoid, State.root = nil, nil, nil
	end
end)
if player.Character then
	task.spawn(bindCharacter, player.Character)
end
