--!nonstrict
-- The HUD, designed to stay out of the way (survival-game minimal, not a Roblox overlay):
--   top        compass bar with objective / teammate markers and distances; one-line objective
--   bottom-right  fading cluster: segmented health, weapon + ammo pips, throwable;
--                 a weapon strip pops up when you switch
--   screen     thin crosshair + hitmarker, red damage vignette, detection arrows, noise ring
-- Everything fades out when you're idle and comes back when it matters.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Characters = require(Shared.Config.Characters)
local Items = require(Shared.Config.Items)
local Movement = require(Shared.Config.Movement)
local Weapons = require(Shared.Config.Weapons)
local Theme = require(script.Parent.Theme)
local State = require(script.Parent.Parent.State)

local HUD = {}
local C = Theme.Colors
local player = Players.LocalPlayer
local Weapon

local root
local compass, compassStrip, compassTicks, compassMarkers, objectiveLine, locationLabel
local cluster, segments, weaponName, magLabel, reserveLabel, pipHolder, pips, throwLabel, abilityLabel
local strip, stripSlots
local ticks, dot, hitmarker, breathLabel
local vignette
local ring, ringLabel
local toastHolder
local downed, downedText, secondWindButton
local indicatorLayer
local indicators = {}
local controlsPanel, controlsHint

local CONTROLS = {
	{ "MOVE", "WASD", "Left stick" },
	{ "SPRINT", "Shift (hold)", "L3" },
	{ "CROUCH", "C / Ctrl", "B" },
	{ "DODGE · DIVE", "Space (dive while sprinting)", "L1" },
	{ "AIM", "Right mouse", "L2" },
	{ "HOLD BREATH", "Shift while aiming", "L3 while aiming" },
	{ "FIRE", "Left mouse", "R2" },
	{ "RELOAD", "R", "X (no enemy near)" },
	{ "WEAPONS", "1 long gun · 2 sidearm · 3 holster", "D-pad right" },
	{ "QUIETING · MELEE", "F", "X" },
	{ "THROW · NEXT ITEM", "G · Z", "R1 · D-pad down" },
	{ "ABILITY", "Q", "Y" },
	{ "HEAL", "H", "D-pad up" },
	{ "FLASHLIGHT", "T", "D-pad left" },
	{ "AMMO CACHE · RESUPPLY", "V · B", "" },
	{ "SATCHEL", "Tab", "View / Back" },
	{ "SWAP SHOULDER", "X", "R3" },
	{ "SETTINGS · CONTROLS", "P · F1", "" },
	{ "INTERACT", "E (hold)", "A" },
}

function HUD.toggleControls(force)
	if not controlsPanel then
		return
	end
	if force == nil then
		controlsPanel.Visible = not controlsPanel.Visible
	else
		controlsPanel.Visible = force
	end
end
local noiseSmoothed, lastActivity, hitUntil, hurtFlash = 0, 0, 0, 0
local lastSig = ""

local SEGMENTS = 5
local COMPASS_W, COMPASS_FOV = 460, math.rad(150)

local function inv(id)
	return player:GetAttribute("Inv_" .. id) or 0
end

local function clock(seconds)
	seconds = math.max(0, math.floor(seconds))
	return ("%d:%02d"):format(math.floor(seconds / 60), seconds % 60)
end

local function label(props)
	props.TextStrokeTransparency = props.TextStrokeTransparency or 0.75
	return Theme.label(props)
end

function HUD.build(gui, onSecondWind, weaponController)
	Weapon = weaponController
	root = Theme.make("Frame", { Name = "HUD", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = gui })

	-- damage vignette (four soft red edges)
	vignette = {}
	for i, spec in {
		{ UDim2.new(0.18, 0, 1, 0), UDim2.new(0, 0, 0, 0), 0 },
		{ UDim2.new(0.18, 0, 1, 0), UDim2.new(0.82, 0, 0, 0), 180 },
		{ UDim2.new(1, 0, 0.2, 0), UDim2.new(0, 0, 0, 0), 90 },
		{ UDim2.new(1, 0, 0.2, 0), UDim2.new(0, 0, 0.8, 0), 270 },
	} do
		local f = Theme.make("Frame", { Size = spec[1], Position = spec[2], BackgroundColor3 = Color3.fromRGB(120, 10, 8), BorderSizePixel = 0, BackgroundTransparency = 1, Parent = root })
		local g = Instance.new("UIGradient")
		g.Rotation = spec[3]
		g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
		g.Parent = f
		vignette[i] = f
	end

	-- compass
	compass = Theme.make("CanvasGroup", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 18),
		Size = UDim2.new(0, COMPASS_W, 0, 30),
		BackgroundTransparency = 1,
		Parent = root,
	})
	local fade = Instance.new("UIGradient")
	fade.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, 0), NumberSequenceKeypoint.new(0.85, 0), NumberSequenceKeypoint.new(1, 1) })
	fade.Parent = compass
	Theme.make("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 22), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = C.text, BackgroundTransparency = 0.6, BorderSizePixel = 0, Parent = compass })
	Theme.make("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 18), Size = UDim2.new(0, 2, 0, 9), BackgroundColor3 = C.lantern, BorderSizePixel = 0, Parent = compass })
	compassStrip = Theme.make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = compass })
	compassTicks = {}
	for deg = 0, 345, 15 do
		local major = deg % 90 == 0
		local text = ({ [0] = "N", [90] = "E", [180] = "S", [270] = "W" })[deg] or (deg % 45 == 0 and "·" or "")
		local t = label({ Text = text, Font = Theme.Head, TextSize = major and 15 or 12, Size = UDim2.new(0, 24, 0, 18), AnchorPoint = Vector2.new(0.5, 0), TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = major and C.text or C.dim, Parent = compassStrip })
		compassTicks[deg] = t
	end
	compassMarkers = {}
	objectiveLine = label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 50), Size = UDim2.new(0, 520, 0, 18), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 13, TextColor3 = C.text, Font = Theme.Head, Parent = root })
	locationLabel = label({ Position = UDim2.new(0, 22, 0, 18), Size = UDim2.new(0, 360, 0, 40), TextSize = 14, Font = Theme.Head, TextColor3 = C.salt, TextWrapped = true, Parent = root })

	-- bottom-right cluster
	cluster = Theme.make("CanvasGroup", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -34, 1, -30), Size = UDim2.new(0, 260, 0, 120), BackgroundTransparency = 1, Parent = root })
	weaponName = label({ Size = UDim2.new(1, 0, 0, 16), TextXAlignment = Enum.TextXAlignment.Right, Font = Theme.Head, TextSize = 14, TextColor3 = C.dim, Parent = cluster })
	magLabel = label({ Position = UDim2.new(0, 0, 0, 14), Size = UDim2.new(1, -56, 0, 44), TextXAlignment = Enum.TextXAlignment.Right, Font = Theme.Head, TextSize = 44, Parent = cluster })
	reserveLabel = label({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 30), Size = UDim2.new(0, 52, 0, 24), TextXAlignment = Enum.TextXAlignment.Left, Font = Theme.Head, TextSize = 20, TextColor3 = C.dim, Parent = cluster })
	pipHolder = Theme.make("Frame", { Position = UDim2.new(0, 0, 0, 62), Size = UDim2.new(1, 0, 0, 10), BackgroundTransparency = 1, Parent = cluster })
	local pipLayout = Theme.list(Enum.FillDirection.Horizontal, 3)
	pipLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	pipLayout.Parent = pipHolder
	pips = {}
	for i = 1, 12 do
		pips[i] = Theme.make("Frame", { LayoutOrder = i, Size = UDim2.new(0, 4, 0, 10), BackgroundColor3 = C.text, BorderSizePixel = 0, Parent = pipHolder })
	end
	throwLabel = label({ Position = UDim2.new(0, 0, 0, 76), Size = UDim2.new(1, 0, 0, 16), TextXAlignment = Enum.TextXAlignment.Right, Font = Theme.Head, TextSize = 13, Parent = cluster })
	local healthRow = Theme.make("Frame", { Position = UDim2.new(0, 0, 0, 100), Size = UDim2.new(1, 0, 0, 7), BackgroundTransparency = 1, Parent = cluster })
	local hl = Theme.list(Enum.FillDirection.Horizontal, 3)
	hl.HorizontalAlignment = Enum.HorizontalAlignment.Right
	hl.Parent = healthRow
	segments = {}
	for i = 1, SEGMENTS do
		local back = Theme.make("Frame", { LayoutOrder = i, Size = UDim2.new(0, 46, 1, 0), BackgroundColor3 = Color3.fromRGB(40, 40, 38), BackgroundTransparency = 0.3, BorderSizePixel = 0, Parent = healthRow })
		segments[i] = Theme.make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.text, BorderSizePixel = 0, Parent = back })
	end
	abilityLabel = label({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 24, 1, -30), Size = UDim2.new(0, 300, 0, 18), Font = Theme.Head, TextSize = 13, TextColor3 = C.salt, Parent = root })

	-- weapon switch strip
	strip = Theme.make("CanvasGroup", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -34, 1, -158), Size = UDim2.new(0, 360, 0, 34), BackgroundTransparency = 1, GroupTransparency = 1, Parent = root })
	local sl = Theme.list(Enum.FillDirection.Horizontal, 6)
	sl.HorizontalAlignment = Enum.HorizontalAlignment.Right
	sl.Parent = strip
	stripSlots = {}
	for i, slot in { "long", "sidearm", "none" } do
		local f = Theme.make("Frame", { LayoutOrder = i, Size = UDim2.new(0, 112, 1, 0), BackgroundColor3 = C.panel, BackgroundTransparency = 0.25, BorderSizePixel = 0, Parent = strip })
		Theme.make("UIStroke", { Color = C.line, Transparency = 0.4, Parent = f })
		stripSlots[slot] = label({ Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center, Font = Theme.Head, TextSize = 13, Parent = f })
	end

	-- noise ring (small, bottom centre)
	local ringHolder = Theme.make("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -26), Size = UDim2.new(0, 70, 0, 70), BackgroundTransparency = 1, Parent = root })
	ring = Theme.make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.1, 0.1), BackgroundTransparency = 1, Parent = ringHolder })
	Theme.make("UICorner", { CornerRadius = UDim.new(1, 0), Parent = ring })
	Theme.make("UIStroke", { Color = C.text, Thickness = 1.5, Transparency = 0.45, Parent = ring })
	Theme.make("UIAspectRatioConstraint", { Parent = ring })
	ringLabel = label({ Text = "", TextSize = 11, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.new(0, 120, 0, 14), TextXAlignment = Enum.TextXAlignment.Center, Font = Theme.Head, TextColor3 = C.dim, Parent = ringHolder })

	-- crosshair
	ticks = {}
	for i = 1, 4 do
		local horizontal = i <= 2
		ticks[i] = Theme.make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = horizontal and UDim2.new(0, 8, 0, 1) or UDim2.new(0, 1, 0, 8), BackgroundColor3 = C.text, BackgroundTransparency = 0.1, BorderSizePixel = 0, Visible = false, Parent = root })
	end
	dot = Theme.make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 3, 0, 3), BackgroundColor3 = C.text, BorderSizePixel = 0, Visible = false, Parent = root })
	Theme.make("UICorner", { CornerRadius = UDim.new(1, 0), Parent = dot })
	hitmarker = Theme.make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 22, 0, 22), BackgroundTransparency = 1, Visible = false, Parent = root })
	for _, rot in { 45, -45 } do
		Theme.make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 0, 0, 2), Rotation = rot, BackgroundColor3 = C.text, BorderSizePixel = 0, Parent = hitmarker })
	end

	breathLabel = label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.5, 34), Size = UDim2.new(0, 220, 0, 14), TextXAlignment = Enum.TextXAlignment.Center, Font = Theme.Head, TextSize = 11, TextColor3 = C.dim, Text = "", Parent = root })

	-- controls card (F1)
	controlsPanel = Theme.panel({ Name = "Controls", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 22, 0.5, 0), Size = UDim2.new(0, 470, 0, 30 + #CONTROLS * 19), BackgroundTransparency = 0.18, Visible = false, ZIndex = 5, Parent = root })
	Theme.padding(12).Parent = controlsPanel
	Theme.heading({ Text = "CONTROLS", TextSize = 16, Size = UDim2.new(1, 0, 0, 18), ZIndex = 5, Parent = controlsPanel })
	for i, row in CONTROLS do
		local y = 22 + (i - 1) * 19
		label({ Text = row[1], Position = UDim2.new(0, 0, 0, y), Size = UDim2.new(0.36, 0, 0, 18), Font = Theme.Head, TextSize = 12, TextColor3 = C.dim, ZIndex = 5, Parent = controlsPanel })
		label({ Text = row[2], Position = UDim2.new(0.36, 0, 0, y), Size = UDim2.new(0.4, 0, 0, 18), TextSize = 12, ZIndex = 5, Parent = controlsPanel })
		label({ Text = row[3], Position = UDim2.new(0.76, 0, 0, y), Size = UDim2.new(0.24, 0, 0, 18), TextSize = 11, TextColor3 = C.dim, ZIndex = 5, Parent = controlsPanel })
	end
	controlsHint = label({ Text = "F1  CONTROLS", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 24, 1, -52), Size = UDim2.new(0, 200, 0, 14), Font = Theme.Head, TextSize = 11, TextColor3 = C.dim, Parent = root })

	indicatorLayer = Theme.make("Frame", { Name = "Indicators", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = root })

	toastHolder = Theme.make("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 76), Size = UDim2.new(0, 620, 0, 160), BackgroundTransparency = 1, Parent = root })
	Theme.list(Enum.FillDirection.Vertical, 2, Enum.HorizontalAlignment.Center).Parent = toastHolder

	downed = Theme.make("Frame", { Name = "Downed", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.5, Visible = false, Parent = root })
	downedText = Theme.heading({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.new(0.9, 0, 0, 80), TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = true, TextSize = 26, Parent = downed })
	secondWindButton = Theme.button({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.53), Size = UDim2.new(0, 320, 0, 44), Text = "SECOND WIND  [R]", Parent = downed })
	secondWindButton.Activated:Connect(onSecondWind)
end

function HUD.toast(text)
	if not toastHolder or text == "" then
		return
	end
	local l = label({ Text = text, Size = UDim2.new(1, 0, 0, 20), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 14, Font = Theme.Head, TextStrokeTransparency = 0.6, Parent = toastHolder })
	task.delay(3.2, function()
		for i = 1, 10 do
			l.TextTransparency = i / 10
			l.TextStrokeTransparency = 0.6 + i / 25
			task.wait(0.04)
		end
		l:Destroy()
	end)
	local children = toastHolder:GetChildren()
	if #children > 5 then
		for _, child in children do
			if child:IsA("TextLabel") then
				child:Destroy()
				break
			end
		end
	end
end

function HUD.hit(data)
	if not hitmarker then
		return
	end
	hitUntil = os.clock() + (data.kill and 0.35 or 0.15)
	local color = data.kill and C.danger or (data.headshot and C.lantern or C.text)
	hitmarker.Size = UDim2.new(0, data.headshot and 30 or 22, 0, data.headshot and 30 or 22)
	for _, line in hitmarker:GetChildren() do
		if line:IsA("Frame") then
			line.BackgroundColor3 = color
		end
	end
end

function HUD.hurt()
	hurtFlash = 1
	lastActivity = os.clock()
end

-- Compass ------------------------------------------------------------------------------------

local function headingOf(dir)
	return math.atan2(dir.X, -dir.Z) -- 0 = north (-Z)
end

local function compassX(angle, camHeading)
	local rel = (angle - camHeading + math.pi) % (2 * math.pi) - math.pi
	return rel / (COMPASS_FOV / 2) * (COMPASS_W / 2) + COMPASS_W / 2, math.abs(rel) < COMPASS_FOV / 2
end

local function objectiveTargets()
	local list = {}
	local world = Workspace:FindFirstChild("World")
	local encounter = world and world:FindFirstChild("Encounter")
	local R = ReplicatedStorage
	if R:GetAttribute("MatchState") == "Encounter" and player:GetAttribute("InCrossing") then
		if encounter then
			for _, p in encounter:GetChildren() do
				if p.Name == "SupplyCrate" then
					table.insert(list, { pos = p.Position, color = C.lantern, text = "◆" })
				elseif p.Name == "Flare" and R:GetAttribute("ExtractionOpen") then
					table.insert(list, { pos = p.Position, color = C.danger, text = "▼", label = "FLARE" })
				elseif p.Name == "SignalLantern" then
					table.insert(list, { pos = p.Position, color = C.lantern, text = "✦", label = "LANTERN" })
				end
			end
		end
	else
		local ferry = world and world:FindFirstChild("Meridian")
		local chart = ferry and ferry:FindFirstChild("ChartTable")
		local bench = ferry and ferry:FindFirstChild("Workbench")
		if chart then
			table.insert(list, { pos = chart.Position, color = C.lantern, text = "◆", label = "TIDE CHART" })
		end
		if bench and R:GetAttribute("MatchState") == "Planning" then
			table.insert(list, { pos = bench.Position, color = C.salt, text = "◇", label = "WORKBENCH" })
		end
	end
	for _, p in Players:GetPlayers() do
		local char = p ~= player and p.Character
		local r = char and char:FindFirstChild("HumanoidRootPart")
		if r then
			table.insert(list, { pos = r.Position, color = char:GetAttribute("Downed") and C.danger or C.salt, text = "●", label = p.DisplayName })
		end
	end
	return list
end

local function updateCompass(camera)
	local look = camera.CFrame.LookVector
	local heading = headingOf(Vector3.new(look.X, 0, look.Z))
	for deg, t in compassTicks do
		local x, visible = compassX(math.rad(deg), heading)
		t.Visible = visible
		t.Position = UDim2.fromOffset(x, 0)
	end
	local targets = objectiveTargets()
	local origin = State.root and State.root.Position or camera.CFrame.Position
	for i, target in targets do
		local m = compassMarkers[i]
		if not m then
			m = label({ Size = UDim2.new(0, 80, 0, 30), AnchorPoint = Vector2.new(0.5, 0), TextXAlignment = Enum.TextXAlignment.Center, Font = Theme.Head, TextSize = 12, Parent = compassStrip })
			compassMarkers[i] = m
		end
		local d = target.pos - origin
		local x, visible = compassX(headingOf(Vector3.new(d.X, 0, d.Z)), heading)
		m.Visible = true
		m.Position = UDim2.fromOffset(math.clamp(x, 10, COMPASS_W - 10), -2)
		m.TextColor3 = target.color
		local meters = math.floor(d.Magnitude * 0.28 + 0.5)
		m.Text = target.text .. (visible and ("\n" .. meters .. "m") or "")
	end
	for i = #targets + 1, #compassMarkers do
		compassMarkers[i].Visible = false
	end
end

-- Detection arrows ------------------------------------------------------------------------------

local function updateIndicators(camera, active)
	local enemies = Workspace:FindFirstChild("Enemies")
	local seen = {}
	if active and enemies and State.root then
		local key = "Sus_" .. player.UserId
		local viewport = camera.ViewportSize
		local center = Vector2.new(viewport.X / 2, viewport.Y / 2)
		local radius = math.min(viewport.X, viewport.Y) * 0.2
		for _, model in enemies:GetChildren() do
			local r = model:FindFirstChild("HumanoidRootPart")
			local st = model:GetAttribute("State")
			local sus = model:GetAttribute(key) or 0
			local hunting = st == "Chase" and model:GetAttribute("Target") == player.UserId
			if r and st ~= "Dispersed" and (sus > 0.04 or hunting) then
				seen[model] = true
				local l = indicators[model]
				if not l then
					l = label({ Text = "▲", Font = Enum.Font.GothamBold, TextSize = 22, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(0, 28, 0, 28), TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center, Parent = indicatorLayer })
					indicators[model] = l
				end
				local rel = camera.CFrame:PointToObjectSpace(r.Position)
				local angle = math.atan2(rel.X, -rel.Z)
				l.Position = UDim2.fromOffset(center.X + math.sin(angle) * radius, center.Y - math.cos(angle) * radius)
				l.Rotation = math.deg(angle)
				local level = hunting and 1 or math.clamp(sus, 0, 1)
				l.TextColor3 = hunting and C.danger or (level >= 0.35 and C.lantern or C.text)
				l.TextTransparency = 0.8 - level * 0.8
				l.TextSize = 16 + level * 12
			end
		end
	end
	for model, l in indicators do
		if not seen[model] then
			l:Destroy()
			indicators[model] = nil
		end
	end
end

-- Frame update ----------------------------------------------------------------------------------

local function objectiveText(matchState, inEncounter)
	local R = ReplicatedStorage
	if matchState == "Encounter" and inEncounter then
		local kind = R:GetAttribute("EncounterType")
		local left = (R:GetAttribute("EndsAt") or 0) - Workspace:GetServerTimeNow()
		local name = string.upper(R:GetAttribute("EncounterName") or "")
		if kind == "Salvage" then
			return R:GetAttribute("ExtractionOpen") and (name .. "  ·  REACH THE FLARE")
				or ("%s  ·  CRATES %d / %d"):format(name, R:GetAttribute("Crates") or 0, R:GetAttribute("CratesRequired") or 0)
		elseif kind == "LanternWatch" then
			local hp, max = R:GetAttribute("LanternHP") or 0, math.max(1, R:GetAttribute("LanternMax") or 1)
			return ("%s  ·  LANTERN %d%%  ·  WAVE %d / %d  ·  %s"):format(name, math.floor(hp / max * 100), R:GetAttribute("Wave") or 0, R:GetAttribute("Waves") or 0, clock(left))
		elseif kind == "Drift" then
			return R:GetAttribute("ExtractionOpen") and (name .. "  ·  REACH THE FLARE") or (name .. "  ·  SURVIVE  " .. clock(left))
		end
	elseif matchState == "Starting" then
		return ("CASTING OFF IN %d"):format(math.max(0, math.ceil((R:GetAttribute("StartsAt") or 0) - Workspace:GetServerTimeNow())))
	elseif matchState == "Planning" then
		return "UPGRADE AT THE WORKBENCH  ·  CHOOSE A ROUTE AT THE TIDE CHART"
	elseif matchState == "Ferry" then
		return "READ THE TIDE CHART TO BEGIN A CROSSING"
	end
	return ""
end

function HUD.update(dt)
	if not root then
		return
	end
	local camera = Workspace.CurrentCamera
	local viewport = camera.ViewportSize
	local char = State.character
	local R = ReplicatedStorage
	local matchState = R:GetAttribute("MatchState")
	local inEncounter = matchState == "Encounter" and char ~= nil and player:GetAttribute("InCrossing") == true
	local now = os.clock()

	updateCompass(camera)
	objectiveLine.Text = objectiveText(matchState, inEncounter)
	if inEncounter then
		locationLabel.Text = ("%s\n%s · PALL %d"):format(string.upper(Workspace:GetAttribute("MapName") or ""), string.upper(R:GetAttribute("ModifierName") or ""), R:GetAttribute("Pall") or 1)
	elseif char then
		locationLabel.Text = R:GetAttribute("RunActive") and player:GetAttribute("InCrossing") and ("THE MERIDIAN\nSTOP %d OF %d · SALVAGE %d"):format(R:GetAttribute("RunIndex") or 1, R:GetAttribute("RunLength") or 4, player:GetAttribute("Salvage") or 0) or ("THE MERIDIAN\nSCRIP %d"):format(player:GetAttribute("Scrip") or 0)
	else
		locationLabel.Text = ""
	end

	-- health segments
	local hp = char and char:GetAttribute("HP") or 0
	local maxHp = char and char:GetAttribute("MaxHP") or 100
	local frac = math.clamp(hp / maxHp, 0, 1)
	for i, seg in segments do
		local segFrac = math.clamp(frac * SEGMENTS - (i - 1), 0, 1)
		seg.Size = UDim2.fromScale(segFrac, 1)
		seg.BackgroundColor3 = frac < 0.35 and C.danger or C.text
	end

	-- weapon
	local slot, id = Weapon.current()
	local def = id and Weapons.List[id]
	local mag = def and (player:GetAttribute("W_" .. slot .. "Mag") or 0) or 0
	if def then
		weaponName.Text = string.upper(def.name) .. (Weapon.isReloading() and "  ·  RELOADING" or "")
		magLabel.Text = tostring(mag)
		magLabel.TextColor3 = mag == 0 and C.danger or C.text
		reserveLabel.Text = "/ " .. inv(def.ammo)
		local stats = Weapon.stats()[slot]
		local size = stats and stats.mag or def.mag
		for i, pip in pips do
			pip.Visible = i <= math.min(size, 12)
			pip.BackgroundTransparency = i <= mag and 0 or 0.75
		end
	else
		weaponName.Text = "UNARMED"
		magLabel.Text = ""
		reserveLabel.Text = ""
		for _, pip in pips do
			pip.Visible = false
		end
	end
	throwLabel.Text = ("%s  %d"):format(string.upper(Items.Items[State.throwable].name), inv(State.throwable))
	local charId = player:GetAttribute("CharId")
	local cdef = charId and Characters.List[charId]
	if cdef and char then
		local remaining = (char:GetAttribute("AbilityReadyAt") or 0) - Workspace:GetServerTimeNow()
		abilityLabel.Text = ("%s  %s"):format(string.upper(cdef.ability.name), remaining > 0 and (math.ceil(remaining) .. "s") or "· READY")
		abilityLabel.TextTransparency = remaining > 0 and 0.5 or 0.1
	else
		abilityLabel.Text = ""
	end

	-- contextual fade: show when aiming, hurt, low, reloading, just changed, or in a fight
	local sig = ("%s|%s|%d|%d|%s|%d"):format(tostring(id), tostring(slot), mag, inv(State.throwable), State.throwable, math.floor(hp))
	if sig ~= lastSig then
		lastSig = sig
		lastActivity = now
	end
	local wanted = State.aiming or frac < 0.5 or Weapon.isReloading() or (now - lastActivity) < 4 or not inEncounter
	cluster.GroupTransparency += ((wanted and 0 or 0.65) - cluster.GroupTransparency) * math.min(1, dt * 4)
	cluster.Visible = char ~= nil

	-- weapon strip after a switch
	local switched = State.weaponSwitchedAt and (now - State.weaponSwitchedAt) < 1.6
	strip.GroupTransparency += ((switched and 0 or 1) - strip.GroupTransparency) * math.min(1, dt * 8)
	for s, l in stripSlots do
		local wid = s ~= "none" and (player:GetAttribute("W_" .. s) or "") or ""
		l.Text = s == "none" and "UNARMED" or (wid ~= "" and Weapons.List[wid] and string.upper(Weapons.List[wid].name) or "—")
		l.TextColor3 = (slot == s) and C.lantern or C.dim
	end

	-- crosshair
	local show = def ~= nil and not State.uiOpen() and not State.downed
	local gap = 0
	if show then
		gap = math.tan(math.rad(Weapon.spread())) * viewport.Y / (2 * math.tan(math.rad(camera.FieldOfView) / 2)) + 3
	end
	local cx, cy = viewport.X / 2, viewport.Y / 2
	local offs = { Vector2.new(-gap - 4, 0), Vector2.new(gap + 4, 0), Vector2.new(0, -gap - 4), Vector2.new(0, gap + 4) }
	for i, t in ticks do
		t.Visible = show and State.aiming
		t.Position = UDim2.fromOffset(cx + offs[i].X, cy + offs[i].Y)
	end
	dot.Visible = show or (State.aiming and not State.uiOpen())
	hitmarker.Visible = now < hitUntil
	if show and State.aiming then
		breathLabel.Text = State.breath == "hold" and "STEADY" or (State.breath == "spent" and "CATCHING BREATH" or "SHIFT  HOLD BREATH")
		breathLabel.TextColor3 = State.breath == "hold" and C.salt or (State.breath == "spent" and C.danger or C.dim)
	else
		breathLabel.Text = ""
	end

	-- vignette: hits flash it, low health keeps it
	hurtFlash = math.max(0, hurtFlash - dt * 1.6)
	local vig = math.clamp(math.max(hurtFlash, (inEncounter and frac < 0.35) and (0.45 + math.sin(now * 3) * 0.1) or 0), 0, 1)
	for _, f in vignette do
		f.BackgroundTransparency = 1 - vig * 0.8
	end

	-- noise ring
	local noise = inEncounter and char and char:GetAttribute("Noise") or 0
	noiseSmoothed += (noise - noiseSmoothed) * math.min(1, dt * 8)
	local scale = math.clamp(noiseSmoothed / Movement.Noise.Sprint, 0.1, 1)
	ring.Size = UDim2.fromScale(scale, scale)
	ring.UIStroke.Transparency = inEncounter and 0.45 or 1
	ringLabel.Text = (inEncounter and noise > Movement.Noise.Walk + 2) and "LOUD" or ""
	ringLabel.TextColor3 = noise > Movement.Noise.Jog + 4 and C.danger or C.lantern

	-- downed
	local isDowned = char and char:GetAttribute("Downed") == true
	local isOut = char and char:GetAttribute("Out") == true
	downed.Visible = (isDowned or isOut) and inEncounter or false
	if isOut then
		downedText.Text = "LOST TO THE PALL\nWaiting for your crew…"
		secondWindButton.Visible = false
	elseif isDowned then
		local bleed = math.max(0, math.ceil((char:GetAttribute("BleedOutAt") or 0) - Workspace:GetServerTimeNow()))
		downedText.Text = ("YOU'RE DOWN\nA crewmate can revive you · %ds"):format(bleed)
		secondWindButton.Visible = true
		secondWindButton.Text = ("SECOND WIND  [R]   ·   %d"):format(player:GetAttribute("Tokens_secondWind") or 0)
	end

	updateIndicators(camera, inEncounter)
	assert(CollectionService)
end

return HUD
