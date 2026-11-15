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
local Buttons = require(script.Parent.Buttons)
local Quartermaster = require(Shared.Config.Quartermaster)
local Projects = require(Shared.Config.Projects)
local HttpService = game:GetService("HttpService")
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

local function stationTarget(name)
	local world = Workspace:FindFirstChild("World")
	local ferry = world and world:FindFirstChild("Meridian")
	local part = ferry and ferry:FindFirstChild(name)
	if not part then
		return nil, nil
	end
	local a = part:FindFirstChild("GuideTarget")
	if not a then
		a = Instance.new("Attachment")
		a.Name = "GuideTarget"
		a.Parent = part
	end
	return a, part
end
local function chartTarget()
	return stationTarget("ChartTable")
end

local function decode(attr)
	local ok, v = pcall(function()
		return HttpService:JSONDecode(player:GetAttribute(attr) or "{}")
	end)
	return ok and type(v) == "table" and v or {}
end

-- What can you do with what you've earned? Returns tip text and the station to point at.
local dismissed = {}
local function upgradeTip()
	local scrip = player:GetAttribute("Scrip") or 0
	local materials = player:GetAttribute("Materials") or 0
	local guns, repairs = decode("Guns"), decode("Repairs")
	local armory = repairs.armory == true
	for _, g in Quartermaster.Guns do
		local price = math.floor(g.price * (armory and 0.85 or 1) + 0.5)
		if not guns[g.id] and scrip >= price and not dismissed["gun" .. g.id] then
			return ("You have %d Scrip: buy the %s at the QUARTERMASTER."):format(scrip, (require(Shared.Config.Weapons).List[g.id] or {}).name or g.id), "Quartermaster", "gun" .. g.id
		end
	end
	for _, p in Projects.List do
		if not repairs[p.id] and (not p.requires or repairs[p.requires]) and materials >= p.materials and not dismissed["proj" .. p.id] then
			return ("You have %d Materials: build the %s at the PROJECTS board. %s"):format(materials, p.name, p.desc), "ProjectsBoard", "proj" .. p.id
		end
	end
	if player:GetAttribute("FreeSpinReady") == true and not dismissed.spin then
		return "Your free Lucky Spin is ready at the wheel.", "SpinWheelStand", "spin"
	end
	return nil
end

function Guide.build(gui, requestFn)
	request = requestFn
	card = Theme.panel({ Name = "Guide", AnchorPoint = Vector2.new(0, 0), Position = UDim2.new(0, 22, 0, 90), Size = UDim2.new(0, 360, 0, 140), BackgroundTransparency = 0.12, Visible = false, Parent = gui })
	Theme.padding(12).Parent = card
	Theme.heading({ Text = "CAPTAIN'S ORDERS", TextSize = 18, TextColor3 = Color3.fromRGB(255, 200, 90), Size = UDim2.new(1, 0, 0, 22), Parent = card })
	local gotIt = Theme.button({ Name = "GotIt", Text = "GOT IT", TextSize = 13, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0, 70, 0, 22), Visible = false, Parent = card })
	gotIt.Activated:Connect(function()
		if card:GetAttribute("TipKey") then
			dismissed[card:GetAttribute("TipKey")] = true
		end
	end)
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

local function setBeam(show, target)
	target = target or chartTarget()
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
	local tip, station, key
	if deck and not newPlayer and not menus then
		tip, station, key = upgradeTip()
	end
	card.Visible = showGuide or tip ~= nil
	card.GotIt.Visible = tip ~= nil
	card:SetAttribute("TipKey", key)
	if tip then
		local target = stationTarget(station)
		setBeam(true, target)
		card:FindFirstChildWhichIsA("TextLabel").Text = "NEXT STEP"
		steps[1].Text = tip
		steps[1].Size = UDim2.new(1, 0, 0, 58)
		steps[1].TextColor3 = C.text
		steps[2].Text = "Follow the gold line. Scrip = guns & kits (Quartermaster) · Materials = ship upgrades (Projects) · Salvage = gun parts (Workbench)"
		steps[2].Position = UDim2.new(0, 0, 0, 92)
		steps[2].TextSize = 11
		steps[2].TextColor3 = C.dim
		steps[3].Text = ""
		return
	end
	steps[1].Size = UDim2.new(1, 0, 0, 28)
	steps[2].Position = UDim2.new(0, 0, 0, 64)
	steps[2].TextSize = 13
	card:FindFirstChildWhichIsA("TextLabel").Text = "CAPTAIN'S ORDERS"
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
		steps[3].Text = "3  " .. (State.gamepad and ("Hold " .. Buttons.name("ButtonA") .. " at the table") or "Hold E at the table (or click SET SAIL)") .. ", then pick a mission"
	end
end

return Guide
