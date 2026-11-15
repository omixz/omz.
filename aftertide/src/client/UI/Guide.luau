--!nonstrict
-- First-time help on the Meridian, so a new player knows exactly how to start:
--   * a small "Captain's orders" card (3 steps) until you've set sail once
--   * a gold guide line on the deck from you to the SET SAIL chart table
--   * for everyone on deck: a SET SAIL button (opens the tide chart from anywhere on the ship)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Game = require(Shared.Config.Game)
local Theme = require(script.Parent.Theme)
local State = require(script.Parent.Parent.State)

local Guide = {}
local C = Theme.Colors
local player = Players.LocalPlayer
local card, steps, sailButton, spinBadge
local beam, a0
local request

local function onDeck()
	local s = ReplicatedStorage:GetAttribute("MatchState")
	local root = State.root
	return (s == "Ferry" or s == "Planning") and root ~= nil and (root.Position - Game.FerryOrigin).Magnitude < 140
end

local function chartTarget()
	local world = Workspace:FindFirstChild("World")
	local ferry = world and world:FindFirstChild("Meridian")
	local chart = ferry and ferry:FindFirstChild("ChartTable")
	return chart and chart:FindFirstChild("GuideTarget"), chart
end

function Guide.build(gui, requestFn)
	request = requestFn
	card = Theme.panel({ Name = "Guide", AnchorPoint = Vector2.new(0, 0), Position = UDim2.new(0, 22, 0, 90), Size = UDim2.new(0, 330, 0, 132), BackgroundTransparency = 0.12, Visible = false, Parent = gui })
	Theme.padding(12).Parent = card
	Theme.heading({ Text = "CAPTAIN'S ORDERS", TextSize = 18, TextColor3 = Color3.fromRGB(255, 200, 90), Size = UDim2.new(1, 0, 0, 22), Parent = card })
	steps = {}
	for i = 1, 3 do
		steps[i] = Theme.label({ Position = UDim2.new(0, 0, 0, 4 + i * 30), Size = UDim2.new(1, 0, 0, 28), TextWrapped = true, TextSize = 13, Parent = card })
	end
	sailButton = Theme.button({ Name = "SetSail", Text = "⚓  SET SAIL", TextSize = 20, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -24, 1, -150), Size = UDim2.new(0, 190, 0, 48), BackgroundColor3 = Color3.fromRGB(214, 150, 50), TextColor3 = Color3.fromRGB(30, 20, 8), Visible = false, Parent = gui })
	sailButton.Activated:Connect(function()
		request("OpenChart")
	end)
	spinBadge = Theme.button({ Name = "SpinBadge", Text = "🎡  FREE SPIN!", TextSize = 16, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -24, 1, -206), Size = UDim2.new(0, 190, 0, 38), BackgroundColor3 = Color3.fromRGB(120, 80, 200), Visible = false, Parent = gui })
	spinBadge.Activated:Connect(function()
		request("OpenSpin")
	end)
end

local function setBeam(show)
	local target = chartTarget()
	if show and target and State.root then
		if not beam then
			a0 = Instance.new("Attachment")
			a0.Name = "GuideFrom"
			beam = Instance.new("Beam")
			beam.Name = "SetSailGuide"
			beam.Color = ColorSequence.new(Color3.fromRGB(255, 210, 100))
			beam.LightEmission = 1
			beam.LightInfluence = 0
			beam.Width0, beam.Width1 = 0.6, 0.6
			beam.FaceCamera = true
			beam.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			beam.TextureMode = Enum.TextureMode.Wrap
			beam.TextureLength = 2
			beam.TextureSpeed = 1.5
			beam.Transparency = NumberSequence.new(0.25)
			beam.Segments = 12
			beam.CurveSize0, beam.CurveSize1 = 2, -2
		end
		a0.Position = Vector3.new(0, -2.2, 0) -- along the deck, from your feet
		a0.Parent = State.root
		beam.Attachment0, beam.Attachment1 = a0, target
		beam.Parent = State.root
		beam.Enabled = true
	elseif beam then
		beam.Enabled = false
	end
end

function Guide.update()
	if not card then
		return
	end
	local deck = onDeck()
	local newPlayer = player:GetAttribute("NewPlayer") == true
	local menus = State.uiOpen()
	sailButton.Visible = deck and not menus and ReplicatedStorage:GetAttribute("MatchState") ~= "Starting"
	spinBadge.Visible = deck and not menus and player:GetAttribute("FreeSpinReady") == true
	local showGuide = deck and newPlayer and not menus
	card.Visible = showGuide
	setBeam(showGuide)
	if showGuide then
		local hasCrew = player:GetAttribute("CharId") ~= nil
		local _, chart = chartTarget()
		local dist = chart and State.root and math.floor((chart.Position - State.root.Position).Magnitude) or 0
		local near = dist < 12
		local tick = "✔  "
		steps[1].Text = (hasCrew and tick or "1  ") .. "Choose your crew member"
		steps[1].TextColor3 = hasCrew and C.ok or C.text
		steps[2].Text = (near and tick or "2  ") .. ("Follow the gold light to the SET SAIL table%s"):format(near and "" or ("  (" .. dist .. " studs)"))
		steps[2].TextColor3 = near and C.ok or C.text
		steps[3].Text = "3  " .. (State.gamepad and "Press A at the table" or "Hold E at the table (or click SET SAIL)") .. ", then pick a mission"
	end
end

return Guide
