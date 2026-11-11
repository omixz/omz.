--!nonstrict
-- Settings: graphics preset (Auto / Performance / Balanced / Cinematic), look sensitivity,
-- reduce camera motion. Saved to your profile.
local Players = game:GetService("Players")

local Theme = require(script.Parent.Theme)
local State = require(script.Parent.Parent.State)

local Settings = {}
local C = Theme.Colors
local player = Players.LocalPlayer
local backdrop, modeButtons, activeLabel, sensLabel, motionButton
local request
local pending = { graphics = "Auto", sensitivity = 1, reduceMotion = false }

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
end

local function save()
	request("SaveSettings", pending)
end

function Settings.build(gui, requestFn)
	request = requestFn
	modeButtons = {}
	local panel
	backdrop, panel = Theme.modal(gui, "Settings", UDim2.new(0.92, 0, 0.8, 0), Vector2.new(620, 440))
	Theme.list(Enum.FillDirection.Vertical, 10).Parent = panel
	Theme.heading({ LayoutOrder = 1, Text = "SETTINGS", TextSize = 28, Size = UDim2.new(1, 0, 0, 32), Parent = panel })
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
	local close = Theme.button({ LayoutOrder = 8, Text = "CLOSE  [P]", Size = UDim2.new(0, 160, 0, 36), Parent = panel })
	close.Activated:Connect(Settings.close)
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
