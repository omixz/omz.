-- Shared setup for engine tests (prepended by tools/engine_test.py). Scripts don't run on their
-- own in a Luau execution session, so services are required here and wired by hand.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local Players = game:GetService("Players")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local ServicesFolder = ServerScriptService:WaitForChild("Server"):WaitForChild("Services")
local ClientFolder = StarterPlayer:WaitForChild("StarterPlayerScripts"):WaitForChild("Client")

local registry = {}
setmetatable(registry, {
	__index = function(t, k)
		local mod = ServicesFolder:FindFirstChild(k)
		if not mod then
			return nil
		end
		local m = require(mod)
		rawset(t, k, m)
		if m.init then
			m.init(t)
		end
		return m
	end,
})

local function cf12(cf)
	return { cf:GetComponents() }
end

local function v3t(v)
	return { v.X, v.Y, v.Z }
end

-- Every sculpted piece on a model, in world space, after posing joints from the root
-- (physics doesn't run here, so we chain Motor6D C0 * Transform * C1^-1 ourselves).
local function posedPieces(model)
	local root = model:FindFirstChild("HumanoidRootPart")
	local world = { [root] = root.CFrame }
	local motors = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") and d.Part0 and d.Part1 then
			table.insert(motors, d)
		end
	end
	for _ = 1, 8 do
		for _, m in motors do
			if world[m.Part0] and not world[m.Part1] then
				world[m.Part1] = world[m.Part0] * m.C0 * m.Transform * m.C1:Inverse()
			end
		end
	end
	local out = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Weld") and d.Part1 and d.Part1:IsA("MeshPart") and world[d.Part0] then
			local mp = d.Part1
			table.insert(out, {
				name = mp.Name,
				cframe = cf12(world[d.Part0] * d.C0 * d.C1:Inverse()),
				size = v3t(mp.Size),
				meshSize = v3t(mp.MeshSize),
				fitRot = mp:GetAttribute("FitRot") and cf12(mp:GetAttribute("FitRot")) or nil,
				source = mp:GetAttribute("SourceName"),
			})
		end
	end
	local bones = {}
	for part, cf in world do
		bones[part.Name] = { cframe = cf12(cf), size = v3t(part.Size) }
	end
	return out, bones
end
