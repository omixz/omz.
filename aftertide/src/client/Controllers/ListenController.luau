--!nonstrict
-- Listen mode (hold L, or hold R3 on a controller): you stop, crouch low and strain to hear.
-- The world greys out and everything making noise near you shows as a silhouette through
-- walls: pale for the Hushed, amber for people, red when they are hunting you. A soft tick
-- speeds up the closer the nearest one is. You creep while listening and cannot shoot.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Sfx = require(Shared.Util.Sfx)
local State = require(script.Parent.Parent.State)

local ListenController = {}
local Controllers
local player = Players.LocalPlayer

local RADIUS = 46
local MAX_SHOWN = 10
local grade, blur, label, gui
local shown = {} -- [model] = Highlight
local nextPing = 0
local loop

local function ensureEffects()
	if grade then
		return
	end
	grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "AftertideListen"
	grade.Enabled = false
	grade.Parent = Lighting
	blur = Instance.new("BlurEffect")
	blur.Name = "AftertideListenBlur"
	blur.Size = 0
	blur.Parent = Lighting
	gui = Instance.new("ScreenGui")
	gui.Name = "AftertideListenHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 5
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")
	label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Position = UDim2.new(0.5, 0, 1, -120)
	label.Size = UDim2.new(0, 360, 0, 26)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Oswald
	label.TextSize = 22
	label.TextColor3 = Color3.fromRGB(225, 232, 236)
	label.Text = "LISTENING"
	label.Parent = gui
end

local function clearShown()
	for model, hl in shown do
		hl:Destroy()
		shown[model] = nil
	end
end

function ListenController.set(on)
	ensureEffects()
	if on == State.listening then
		return
	end
	if on then
		if State.downed or State.uiOpen() or State.vaulting or not State.character then
			return
		end
		State.listening = true
		if State.aiming then
			Controllers.MovementController.setAim(false)
		end
		Controllers.MovementController.setSprint(false, false)
		grade.Enabled = true
		TweenService:Create(grade, TweenInfo.new(0.35), { Saturation = -0.85, Brightness = -0.06, Contrast = 0.12, TintColor = Color3.fromRGB(210, 224, 240) }):Play()
		TweenService:Create(blur, TweenInfo.new(0.35), { Size = 5 }):Play()
		gui.Enabled = true
		if Sfx.has("Listen_On") then
			Sfx.ui("Listen_On", 0.7)
		else
			Sfx.ui("Ui_Confirm", 0.4)
		end
		if Sfx.has("Listen_Loop") and not loop then
			loop = Sfx.ui("Listen_Loop", 0.5, true)
		end
	else
		State.listening = false
		TweenService:Create(grade, TweenInfo.new(0.3), { Saturation = 0, Brightness = 0, Contrast = 0, TintColor = Color3.new(1, 1, 1) }):Play()
		TweenService:Create(blur, TweenInfo.new(0.3), { Size = 0 }):Play()
		task.delay(0.32, function()
			if not State.listening then
				grade.Enabled = false
			end
		end)
		gui.Enabled = false
		clearShown()
		if Sfx.has("Listen_Off") then
			Sfx.ui("Listen_Off", 0.6)
		end
		if loop then
			loop:Destroy()
			loop = nil
		end
	end
end

local function update(dt)
	if not State.listening then
		return
	end
	if State.downed or State.uiOpen() or not State.root then
		ListenController.set(false)
		return
	end
	local folder = Workspace:FindFirstChild("Enemies")
	local origin = State.root.Position
	local radius = RADIUS * (State.crouched and 1.15 or 1)
	local list = {}
	if folder then
		for _, model in folder:GetChildren() do
			local root = model:FindFirstChild("HumanoidRootPart")
			local st = model:GetAttribute("State")
			if root and st ~= "Dispersed" and st ~= "Down" then
				local d = (root.Position - origin).Magnitude
				if d <= radius then
					table.insert(list, { model = model, dist = d, state = st })
				end
			end
		end
	end
	table.sort(list, function(a, b)
		return a.dist < b.dist
	end)
	local keep = {}
	for i = 1, math.min(#list, MAX_SHOWN) do
		local e = list[i]
		keep[e.model] = true
		local hl = shown[e.model]
		if not hl then
			hl = Instance.new("Highlight")
			hl.Name = "ListenHL"
			hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			hl.Adornee = e.model
			hl.Parent = e.model
			shown[e.model] = hl
		end
		local hunting = e.state == "Chase" and e.model:GetAttribute("Target") == player.UserId
		local human = e.model:GetAttribute("Human") == true
		local color = hunting and Color3.fromRGB(255, 70, 60) or (human and Color3.fromRGB(255, 200, 90) or Color3.fromRGB(190, 225, 255))
		hl.FillColor = color
		hl.OutlineColor = color
		local fade = e.dist / radius
		hl.FillTransparency = 0.45 + 0.5 * fade
		hl.OutlineTransparency = 0.1 + 0.6 * fade
	end
	for model, hl in shown do
		if not keep[model] or not model.Parent then
			hl:Destroy()
			shown[model] = nil
		end
	end
	-- the tick: faster the closer the nearest one is
	local now = os.clock()
	if now >= nextPing then
		if #list > 0 then
			local d = list[1].dist
			nextPing = now + math.clamp(d / radius * 1.3 + 0.3, 0.3, 1.6)
			Sfx.ui(Sfx.has("Listen_Ping") and "Listen_Ping" or "Ui_Tick", math.clamp(1.1 - d / radius, 0.25, 0.9))
		else
			nextPing = now + 1.2
		end
	end
	label.Text = #list == 0 and "LISTENING · quiet" or ("LISTENING · %d nearby · closest %d studs"):format(#list, math.floor(list[1].dist))
end

function ListenController.init(registry)
	Controllers = registry
end

function ListenController.onCharacter()
	State.listening = false
	State.vaulting = false
	if grade then
		grade.Enabled = false
		blur.Size = 0
		gui.Enabled = false
	end
	clearShown()
end

function ListenController.start()
	ensureEffects()
	RunService.RenderStepped:Connect(update)
end

return ListenController
