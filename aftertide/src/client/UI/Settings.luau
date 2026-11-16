--!nonstrict
-- Settings: view (first / third person, field of view), text and menu size, graphics preset,
-- look sensitivity, reduce camera motion. Saved to your profile.
local Players = game:GetService("Players")

local Theme = require(script.Parent.Theme)
local State = require(script.Parent.Parent.State)

local Settings = {}
local C = Theme.Colors
local player = Players.LocalPlayer
local backdrop, modeButtons, activeLabel, sensLabel, motionButton
local request
local pending = { graphics = "Auto", sensitivity = 1, reduceMotion = false, camera = "First", uiSize = "Large", fov = 80 }
local camButtons, sizeButtons, fovLabel

local MODES = { "Auto", "Performance", "Balanced", "Cinematic" }

local function refresh()
	for mode, b in modeButtons do
		local on = pending.graphics == mode
		b.BackgroundColor3 = on and C.lantern or C.panelHi
		b.TextColor3 = on and C.backdrop or C.text
	end
	activeLabel.Text = ("Running: %s. Cinematic adds depth of field with aim focus, sun rays, a filmic grade, denser fog and rain, and shadows on every light. Best on PC and PlayStation."):format(player:GetAttribute("GraphicsMode") or "?")
	sensLabel.Text = ("Look sensitivity  %.1f"):format(pending.sensitivity)
	motionButton.Text = pending.reduceMotion and "REDUCE CAMERA MOTION: ON" or "REDUCE CAMERA MOTION: OFF"
	for mode, b in camButtons do
		local on = pending.camera == mode
		b.BackgroundColor3 = on and C.lantern or C.panelHi
		b.TextColor3 = on and C.backdrop or C.text
	end
	for mode, b in sizeButtons do
		local on = pending.uiSize == mode
		b.BackgroundColor3 = on and C.lantern or C.panelHi
		b.TextColor3 = on and C.backdrop or C.text
	end
	fovLabel.Text = ("Field of view  %d"):format(pending.fov)
end

local function save()
	request("SaveSettings", pending)
end

function Settings.build(gui, requestFn)
	request = requestFn
	modeButtons, camButtons, sizeButtons = {}, {}, {}
	local panel
	backdrop, panel = Theme.modal(gui, "Settings", UDim2.new(0.92, 0, 0.9, 0), Vector2.new(720, 700))
	panel = Theme.make("ScrollingFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = panel })
	Theme.list(Enum.FillDirection.Vertical, 10).Parent = panel
	Theme.heading({ LayoutOrder = 1, Text = "SETTINGS", TextSize = 28, Size = UDim2.new(1, 0, 0, 32), Parent = panel })
	-- the view: Brinewake is played in first person; third person is an option here
	Theme.heading({ LayoutOrder = 10, Text = "VIEW", TextSize = 16, TextColor3 = C.salt, Size = UDim2.new(1, 0, 0, 20), Parent = panel })
	local camRow = Theme.make("Frame", { LayoutOrder = 11, Size = UDim2.new(1, 0, 0, 38), BackgroundTransparency = 1, Parent = panel })
	Theme.list(Enum.FillDirection.Horizontal, 6).Parent = camRow
	for i, entry in { { "First", "FIRST PERSON (recommended)" }, { "Third", "THIRD PERSON" } } do
		local b = Theme.button({ LayoutOrder = i, Text = entry[2], TextSize = 14, Size = UDim2.new(0.5, -3, 1, 0), Parent = camRow })
		camButtons[entry[1]] = b
		b.Activated:Connect(function()
			pending.camera = entry[1]
			save()
			refresh()
		end)
	end
	fovLabel = Theme.heading({ LayoutOrder = 12, TextSize = 16, Size = UDim2.new(1, 0, 0, 20), Parent = panel })
	local fovRow = Theme.make("Frame", { LayoutOrder = 13, Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1, Parent = panel })
	Theme.list(Enum.FillDirection.Horizontal, 6).Parent = fovRow
	for i, delta in { -5, 5 } do
		local b = Theme.button({ LayoutOrder = i, Text = delta < 0 and "–" or "+", Size = UDim2.new(0, 60, 1, 0), Parent = fovRow })
		b.Activated:Connect(function()
			pending.fov = math.clamp(pending.fov + delta, 60, 110)
			save()
			refresh()
		end)
	end
	Theme.heading({ LayoutOrder = 14, Text = "TEXT AND MENU SIZE", TextSize = 16, TextColor3 = C.salt, Size = UDim2.new(1, 0, 0, 20), Parent = panel })
	local sizeRow = Theme.make("Frame", { LayoutOrder = 15, Size = UDim2.new(1, 0, 0, 38), BackgroundTransparency = 1, Parent = panel })
	Theme.list(Enum.FillDirection.Horizontal, 6).Parent = sizeRow
	for i, mode in { "Normal", "Large", "Huge" } do
		local b = Theme.button({ LayoutOrder = i, Text = string.upper(mode), TextSize = 14, Size = UDim2.new(1 / 3, -4, 1, 0), Parent = sizeRow })
		sizeButtons[mode] = b
		b.Activated:Connect(function()
			pending.uiSize = mode
			save()
			refresh()
		end)
	end
	Theme.heading({ LayoutOrder = 2, Text = "GRAPHICS", TextSize = 16, TextColor3 = C.salt, Size = UDim2.new(1, 0, 0, 20), Parent = panel })
	local row = Theme.make("Frame", { LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 38), BackgroundTransparency = 1, Parent = panel })
	Theme.list(Enum.FillDirection.Horizontal, 6).Parent = row
	for i, mode in MODES do
		local b = Theme.button({ LayoutOrder = i, Text = string.upper(mode), TextSize = 13, Size = UDim2.new(0.25, -5, 1, 0), Parent = row })
		modeButtons[mode] = b
		b.Activated:Connect(function()
			pending.graphics = mode
			save()
			task.delay(0.3, refresh)
		end)
	end
	activeLabel = Theme.label({ LayoutOrder = 4, TextSize = 12, TextColor3 = C.dim, Size = UDim2.new(1, 0, 0, 48), Parent = panel })
	sensLabel = Theme.heading({ LayoutOrder = 5, TextSize = 16, Size = UDim2.new(1, 0, 0, 20), Parent = panel })
	local sensRow = Theme.make("Frame", { LayoutOrder = 6, Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1, Parent = panel })
	Theme.list(Enum.FillDirection.Horizontal, 6).Parent = sensRow
	for i, delta in { -0.1, 0.1 } do
		local b = Theme.button({ LayoutOrder = i, Text = delta < 0 and "–" or "+", Size = UDim2.new(0, 60, 1, 0), Parent = sensRow })
		b.Activated:Connect(function()
			pending.sensitivity = math.clamp(math.floor((pending.sensitivity + delta) * 10 + 0.5) / 10, 0.2, 3)
			save()
			refresh()
		end)
	end
	motionButton = Theme.button({ LayoutOrder = 7, Size = UDim2.new(0, 320, 0, 36), Parent = panel })
	motionButton.Activated:Connect(function()
		pending.reduceMotion = not pending.reduceMotion
		save()
		refresh()
	end)
	local close = Theme.button({ LayoutOrder = 20, Text = "CLOSE  [P]", Size = UDim2.new(0, 160, 0, 36), Parent = panel })
	close.Activated:Connect(Settings.close)
end

-- Change one setting from anywhere (the camera key): builds the full set from what is saved now.
function Settings.setValue(key, value)
	local current = {
		graphics = player:GetAttribute("Set_graphics") or "Auto",
		sensitivity = player:GetAttribute("Set_sensitivity") or 1,
		reduceMotion = player:GetAttribute("Set_reduceMotion") == true,
		camera = player:GetAttribute("Set_camera") or "First",
		uiSize = player:GetAttribute("Set_uiSize") or "Large",
		fov = player:GetAttribute("Set_fov") or 80,
	}
	current[key] = value
	player:SetAttribute("Set_" .. key, value) -- immediate; the server confirms and saves
	if request then
		request("SaveSettings", current)
	end
end

function Settings.toggle()
	if not backdrop then
		return
	end
	if backdrop.Visible then
		Settings.close()
		return
	end
	pending = {
		graphics = player:GetAttribute("Set_graphics") or "Auto",
		sensitivity = player:GetAttribute("Set_sensitivity") or 1,
		reduceMotion = player:GetAttribute("Set_reduceMotion") == true,
		camera = player:GetAttribute("Set_camera") or "First",
		uiSize = player:GetAttribute("Set_uiSize") or "Large",
		fov = player:GetAttribute("Set_fov") or 80,
	}
	backdrop.Visible = true
	State.setModal("settings", true)
	refresh()
	Theme.focus(modeButtons.Auto)
end

function Settings.close()
	if backdrop then
		backdrop.Visible = false
		State.setModal("settings", false)
	end
end

return Settings
