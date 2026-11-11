--!nonstrict
-- Client-only feedback: Tide Sense highlights, knockback, hit flash, low-health grade,
-- takedown framing, Squall lightning, and hiding your own revive prompt.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Geometry = require(Shared.Util.Geometry)
local State = require(script.Parent.Parent.State)

local EffectsController = {}

local player = Players.LocalPlayer
local grade -- our own ColorCorrection layer for health feedback
local hitFlash = 0

local function tideSense(data)
	local enemies = Workspace:FindFirstChild("Enemies")
	local root = State.root
	if not enemies or not root then
		return
	end
	local radius = tonumber(data.radius) or 70
	local duration = tonumber(data.duration) or 4
	for _, model in enemies:GetChildren() do
		local r = model:FindFirstChild("HumanoidRootPart")
		if r and (r.Position - root.Position).Magnitude <= radius then
			local h = Instance.new("Highlight")
			h.FillColor = Color3.fromRGB(170, 215, 215)
			h.FillTransparency = 0.88
			h.OutlineColor = Color3.fromRGB(225, 245, 245)
			h.OutlineTransparency = 0.1
			h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			h.Adornee = model
			h.Parent = model
			task.delay(duration, function()
				if h.Parent then
					local tween = TweenService:Create(h, TweenInfo.new(0.6), { OutlineTransparency = 1, FillTransparency = 1 })
					tween:Play()
					tween.Completed:Wait()
					h:Destroy()
				end
			end)
		end
	end
end

local function knockback(data)
	local root = State.root
	if root and Geometry.isSaneVector(data.velocity, 200) then
		root.AssemblyLinearVelocity = data.velocity
	end
end

local function hideOwnRevivePrompt(char)
	local function check(inst)
		if inst:IsA("ProximityPrompt") and inst.Name == "Revive" then
			inst.Enabled = false
		end
	end
	for _, d in char:GetDescendants() do
		check(d)
	end
	char.DescendantAdded:Connect(check)
end

function EffectsController.onCharacter(char)
	hideOwnRevivePrompt(char)
end

local nextLightning = 0
local function lightning()
	local before = Lighting.Brightness
	Lighting.Brightness = before + 3
	task.wait(0.06)
	Lighting.Brightness = before
	task.wait(0.09)
	Lighting.Brightness = before + 2
	task.wait(0.05)
	Lighting.Brightness = before
end

function EffectsController.start()
	grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "AftertideHealth"
	grade.Parent = Lighting

	Net.event("Notify").OnClientEvent:Connect(function(kind, data)
		data = data or {}
		if kind == "TideSense" then
			tideSense(data)
		elseif kind == "Knockback" then
			knockback(data)
		elseif kind == "Hurt" then
			hitFlash = 1
		elseif kind == "Takedown" then
			State.takedownUntil = os.clock() + (tonumber(data.duration) or 0.9)
		end
	end)

	RunService.RenderStepped:Connect(function(dt)
		local char = State.character
		local hp = char and char:GetAttribute("HP") or 100
		local maxHp = char and char:GetAttribute("MaxHP") or 100
		local low = 1 - math.clamp(hp / maxHp, 0, 1)
		hitFlash = math.max(0, hitFlash - dt * 2.5)
		grade.Saturation = -0.5 * low - 0.3 * hitFlash
		grade.TintColor = Color3.new(1, 1 - 0.35 * hitFlash - 0.1 * low, 1 - 0.4 * hitFlash - 0.15 * low)
		grade.Contrast = 0.1 * low
		if State.downed then
			grade.Saturation = -0.8
		end

		if ReplicatedStorage:GetAttribute("ModifierId") == "Squall" and ReplicatedStorage:GetAttribute("MatchState") == "Encounter" then
			local now = os.clock()
			if now > nextLightning then
				nextLightning = now + math.random(8, 20)
				task.spawn(lightning)
			end
		end
	end)
end

return EffectsController
