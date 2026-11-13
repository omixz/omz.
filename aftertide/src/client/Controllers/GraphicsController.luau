--!nonstrict
-- Graphics presets. Roblox decides the core render quality per device (from the player's
-- graphics slider); these presets layer extra effects on top and decide how many costly
-- things run:
--   Cinematic   (PC / PlayStation / Xbox): depth of field with aim focus, sun rays, filmic
--               grade, stronger bloom, shadows on every practical light, dense local ground
--               mist, dust motes, heavy rain in a Squall
--   Balanced    lighter mist, no DoF, standard shadows
--   Performance (phones): no extra effects, fewer fog particles, fewer shadow-casting lights
-- "Auto" picks by device and the player's Roblox graphics level.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local State = require(script.Parent.Parent.State)

local GraphicsController = {}
local Controllers
local player = Players.LocalPlayer

local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

local dof, rays, bloom, grade, vignette
local mistPart, mist, dust, rainPart, rain
local current = nil

function GraphicsController.resolve(setting)
	if setting and setting ~= "Auto" then
		return setting
	end
	local touchOnly = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local consoleLike = UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled and not UserInputService.TouchEnabled
	if touchOnly then
		return "Performance"
	elseif consoleLike then
		return "Cinematic"
	end
	local ok, level = pcall(function()
		return UserSettings():GetService("UserGameSettings").SavedQualityLevel
	end)
	if not ok or level == Enum.SavedQualitySetting.Automatic then
		return "Cinematic"
	end
	local n = tonumber(tostring(level.Value)) or 10
	if n >= 7 then
		return "Cinematic"
	elseif n >= 4 then
		return "Balanced"
	end
	return "Performance"
end

function GraphicsController.current()
	return current
end

local function setLightShadows(enabled)
	local world = Workspace:FindFirstChild("World")
	if not world then
		return
	end
	for _, d in world:GetDescendants() do
		if d:IsA("PointLight") or d:IsA("SpotLight") then
			if d:GetAttribute("BaseShadows") == nil then
				d:SetAttribute("BaseShadows", d.Shadows)
			end
			d.Shadows = enabled == "all" or (enabled == "base" and d:GetAttribute("BaseShadows"))
		end
	end
end

local function scaleWorldFog(mult)
	local world = Workspace:FindFirstChild("World")
	if not world then
		return
	end
	for _, d in world:GetDescendants() do
		if d:IsA("ParticleEmitter") and d.Texture == SMOKE and d.Parent and d.Parent.Parent and d.Parent.Parent.Name:sub(1, 4) == "Map_" then
			if d:GetAttribute("BaseRate") == nil then
				d:SetAttribute("BaseRate", d.Rate)
			end
			d.Rate = d:GetAttribute("BaseRate") * mult
		end
	end
end

local function apply(mode)
	current = mode
	local cinematic = mode == "Cinematic"
	local performance = mode == "Performance"
	dof.Enabled = cinematic
	rays.Enabled = cinematic
	bloom.Enabled = not performance
	bloom.Intensity = cinematic and 0.5 or 0.25
	grade.Enabled = not performance
	grade.Contrast = cinematic and 0.1 or 0.05
	grade.Saturation = cinematic and -0.04 or 0
	grade.TintColor = cinematic and Color3.fromRGB(255, 246, 236) or Color3.new(1, 1, 1)
	mist.Rate = cinematic and 5 or (performance and 0 or 2)
	dust.Rate = cinematic and 18 or 0
	for _, f in vignette or {} do
		f.Visible = not performance
		f.BackgroundTransparency = cinematic and 0.5 or 0.68
	end
	-- wind-swayed terrain grass (cheap on PC/console, off on phones)
	pcall(function()
		Workspace.Terrain.Decoration = not performance
	end)
	setLightShadows(cinematic and "all" or (performance and "none" or "base"))
	scaleWorldFog(cinematic and 1.6 or (performance and 0.35 or 1))
	player:SetAttribute("GraphicsMode", mode)
end

function GraphicsController.refresh()
	apply(GraphicsController.resolve(player:GetAttribute("Set_graphics")))
end

local function buildEffects()
	dof = Instance.new("DepthOfFieldEffect")
	dof.Name = "AftertideDoF"
	dof.FarIntensity = 0.18
	dof.NearIntensity = 0
	dof.FocusDistance = 40
	dof.InFocusRadius = 35
	dof.Parent = Lighting

	rays = Instance.new("SunRaysEffect")
	rays.Name = "AftertideRays"
	rays.Intensity = 0.03
	rays.Spread = 0.6
	rays.Parent = Lighting

	bloom = Instance.new("BloomEffect")
	bloom.Name = "AftertideBloomHQ"
	bloom.Size = 32
	bloom.Threshold = 1.2
	bloom.Parent = Lighting

	grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "AftertideFilmic"
	grade.Parent = Lighting

	-- a soft lens vignette (darkened corners), like a film camera
	local gui = Instance.new("ScreenGui")
	gui.Name = "CinematicVignette"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = -5
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")
	vignette = {}
	for i, spec in {
		{ UDim2.new(0.22, 0, 1, 0), UDim2.new(0, 0, 0, 0), 0 },
		{ UDim2.new(0.22, 0, 1, 0), UDim2.new(0.78, 0, 0, 0), 180 },
		{ UDim2.new(1, 0, 0.22, 0), UDim2.new(0, 0, 0, 0), 90 },
		{ UDim2.new(1, 0, 0.22, 0), UDim2.new(0, 0, 0.78, 0), 270 },
	} do
		local f = Instance.new("Frame")
		f.Size, f.Position = spec[1], spec[2]
		f.BackgroundColor3 = Color3.new(0, 0, 0)
		f.BorderSizePixel = 0
		f.BackgroundTransparency = 0.55
		local g = Instance.new("UIGradient")
		g.Rotation = spec[3]
		g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
		g.Parent = f
		f.Parent = gui
		vignette[i] = f
	end

	-- local ground mist and dust that follow the camera (client-only, costs nothing on the server)
	mistPart = Instance.new("Part")
	mistPart.Name = "LocalMist"
	mistPart.Anchored = true
	mistPart.CanCollide = false
	mistPart.CanQuery = false
	mistPart.CanTouch = false
	mistPart.Transparency = 1
	mistPart.Size = Vector3.new(90, 1, 90)
	mistPart.Parent = Workspace

	mist = Instance.new("ParticleEmitter")
	mist.Texture = SMOKE
	mist.Lifetime = NumberRange.new(10, 16)
	mist.Speed = NumberRange.new(0.2, 0.8)
	mist.SpreadAngle = Vector2.new(80, 80)
	mist.Rotation = NumberRange.new(0, 360)
	mist.RotSpeed = NumberRange.new(-3, 3)
	mist.LightInfluence = 1
	mist.Color = ColorSequence.new(Color3.fromRGB(205, 212, 212))
	mist.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 12), NumberSequenceKeypoint.new(1, 22) })
	mist.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.35, 0.9), NumberSequenceKeypoint.new(0.7, 0.92), NumberSequenceKeypoint.new(1, 1) })
	mist.Drag = 0.4
	mist.WindAffectsDrag = true -- fog drifts with the map's wind
	mist.Parent = mistPart

	dust = Instance.new("ParticleEmitter")
	dust.Lifetime = NumberRange.new(4, 7)
	dust.Speed = NumberRange.new(0.1, 0.4)
	dust.SpreadAngle = Vector2.new(180, 180)
	dust.LightInfluence = 1
	dust.Color = ColorSequence.new(Color3.fromRGB(230, 225, 210))
	dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.06), NumberSequenceKeypoint.new(1, 0) })
	dust.Parent = mistPart

	rainPart = Instance.new("Part")
	rainPart.Name = "LocalRain"
	rainPart.Anchored = true
	rainPart.CanCollide = false
	rainPart.CanQuery = false
	rainPart.CanTouch = false
	rainPart.Transparency = 1
	rainPart.Size = Vector3.new(80, 1, 80)
	rainPart.Parent = Workspace
	rain = Instance.new("ParticleEmitter")
	rain.Rate = 0
	rain.Lifetime = NumberRange.new(0.8, 1)
	rain.Speed = NumberRange.new(70, 90)
	rain.EmissionDirection = Enum.NormalId.Bottom
	rain.Orientation = Enum.ParticleOrientation.VelocityParallel
	rain.LightInfluence = 1
	rain.Color = ColorSequence.new(Color3.fromRGB(190, 200, 205))
	rain.Transparency = NumberSequence.new(0.55)
	rain.Size = NumberSequence.new(0.08)
	rain.Squash = NumberSequence.new(2.5)
	rain.Parent = rainPart
end

function GraphicsController.init(registry)
	Controllers = registry
end

function GraphicsController.start()
	buildEffects()
	GraphicsController.refresh()
	player:GetAttributeChangedSignal("Set_graphics"):Connect(GraphicsController.refresh)
	-- world lights are built by the server shortly after join; re-apply once they exist
	task.delay(5, GraphicsController.refresh)
	ReplicatedStorage:GetAttributeChangedSignal("MatchState"):Connect(function()
		task.delay(1, GraphicsController.refresh)
	end)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	RunService.RenderStepped:Connect(function(dt)
		local camera = Workspace.CurrentCamera
		local pos = camera.CFrame.Position
		-- ground mist hugs the ground you stand on (hills, the ferry deck), not sea level
		local feet = State.root and State.root.Parent and (State.root.Position.Y - 3.5) or (pos.Y - 6)
		mistPart.CFrame = CFrame.new(pos.X, feet, pos.Z)
		rainPart.CFrame = CFrame.new(pos.X, pos.Y + 28, pos.Z)
		local squall = ReplicatedStorage:GetAttribute("ModifierId") == "Squall" and ReplicatedStorage:GetAttribute("MatchState") == "Encounter"
		rain.Rate = squall and (current == "Cinematic" and 500 or (current == "Balanced" and 220 or 60)) or 0

		-- aim focus: in Cinematic, focus depth of field on what you're aiming at
		if current == "Cinematic" then
			local focusDist, radius, far = 40, 35, 0.18
			if State.aiming then
				params.FilterDescendantsInstances = State.character and { State.character } or {}
				local hit = Workspace:Raycast(pos, camera.CFrame.LookVector * 250, params)
				focusDist = hit and hit.Distance or 200
				radius, far = math.max(6, focusDist * 0.35), 0.4
			end
			dof.FocusDistance += (focusDist - dof.FocusDistance) * math.min(1, dt * 6)
			dof.InFocusRadius += (radius - dof.InFocusRadius) * math.min(1, dt * 6)
			dof.FarIntensity += (far - dof.FarIntensity) * math.min(1, dt * 6)
		end
	end)
end

return GraphicsController
