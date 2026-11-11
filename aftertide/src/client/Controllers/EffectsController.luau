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
local Controllers
local Debris = game:GetService("Debris")
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

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

local function localPart(position, size)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = size or Vector3.new(0.2, 0.2, 0.2)
	p.CFrame = CFrame.new(position)
	p.Parent = Workspace
	return p
end

local function tracer(from, to)
	local length = (to - from).Magnitude
	if length < 0.5 then
		return
	end
	local beam = localPart(from)
	beam.Transparency = 0.35
	beam.Material = Enum.Material.Neon
	beam.Color = Color3.fromRGB(255, 225, 180)
	beam.Size = Vector3.new(0.05, 0.05, length)
	beam.CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -length / 2)
	TweenService:Create(beam, TweenInfo.new(0.08), { Transparency = 1 }):Play()
	Debris:AddItem(beam, 0.1)
end

local function impact(position, kind)
	if kind == "none" then
		return
	end
	local holder = localPart(position)
	local puff = Instance.new("ParticleEmitter")
	puff.Texture = SMOKE
	puff.Rate = 0
	puff.Lifetime = NumberRange.new(0.4, 0.9)
	puff.Speed = NumberRange.new(2, 6)
	puff.SpreadAngle = Vector2.new(60, 60)
	puff.Drag = 4
	puff.LightInfluence = 1
	if kind == "enemy" then
		puff.Color = ColorSequence.new(Color3.fromRGB(225, 220, 205)) -- salt, never blood
		puff.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 2) })
	else
		puff.Color = ColorSequence.new(Color3.fromRGB(120, 116, 108))
		puff.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1.4) })
		local sparks = Instance.new("ParticleEmitter")
		sparks.Rate = 0
		sparks.Lifetime = NumberRange.new(0.1, 0.25)
		sparks.Speed = NumberRange.new(8, 16)
		sparks.SpreadAngle = Vector2.new(50, 50)
		sparks.LightEmission = 1
		sparks.Color = ColorSequence.new(Color3.fromRGB(255, 200, 140))
		sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.12), NumberSequenceKeypoint.new(1, 0) })
		sparks.Parent = holder
		sparks:Emit(5)
	end
	puff.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	puff.Parent = holder
	puff:Emit(kind == "enemy" and 10 or 6)
	Debris:AddItem(holder, 1.5)
end

local function shot(data)
	if typeof(data.from) ~= "Vector3" then
		return
	end
	if data.shooter ~= player.UserId then
		local holder = localPart(data.from)
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 200, 140)
		light.Range = 16
		light.Brightness = 5
		light.Parent = holder
		Debris:AddItem(holder, 0.06)
	end
	for _, hit in data.hits or {} do
		if typeof(hit.position) == "Vector3" then
			tracer(data.from, hit.position)
			impact(hit.position, hit.kind)
		end
	end
end

local shake = 0
local function explosion(data)
	local root = State.root
	if not root or typeof(data.position) ~= "Vector3" then
		return
	end
	local dist = (root.Position - data.position).Magnitude
	shake = math.max(shake, math.clamp(1 - dist / 80, 0, 1))
end

local function humRing(data, color)
	if typeof(data.position) ~= "Vector3" then
		return
	end
	local ring = localPart(data.position + Vector3.new(0, 0.2, 0))
	ring.Shape = Enum.PartType.Cylinder
	ring.Material = Enum.Material.ForceField
	ring.Color = color or Color3.fromRGB(200, 230, 230)
	ring.Transparency = 0.2
	ring.Size = Vector3.new(0.2, 2, 2)
	ring.CFrame = CFrame.new(data.position + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	local r = (tonumber(data.radius) or 60) * 2
	TweenService:Create(ring, TweenInfo.new(1.2, Enum.EasingStyle.Quad), { Size = Vector3.new(0.2, r, r), Transparency = 1 }):Play()
	Debris:AddItem(ring, 1.3)
end

function EffectsController.getShake()
	return shake
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

function EffectsController.init(registry)
	Controllers = registry
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
		elseif kind == "Shot" then
			shot(data)
		elseif kind == "Impact" then
			if typeof(data.position) == "Vector3" then
				impact(data.position, data.kind)
			end
		elseif kind == "Explosion" then
			explosion(data)
		elseif kind == "Hum" then
			humRing(data)
		elseif kind == "NoiseRing" then
			-- how far that sound carried: every Hushed inside this ring heard it
			humRing(data, data.kind == "gunshot" and Color3.fromRGB(232, 168, 92) or Color3.fromRGB(226, 220, 206))
		end
	end)

	RunService.RenderStepped:Connect(function(dt)
		shake = math.max(0, shake - dt * 2.5)
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
