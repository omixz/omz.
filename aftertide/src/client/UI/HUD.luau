--!nonstrict
-- In-run HUD: objective, health + ability, noise ring, satchel strip, detection indicators,
-- crosshair, toasts, downed overlay and the ferry panel. Updated every frame from attributes.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Characters = require(Shared.Config.Characters)
local Movement = require(Shared.Config.Movement)
local Theme = require(script.Parent.Theme)
local State = require(script.Parent.Parent.State)

local HUD = {}
local C = Theme.Colors
local player = Players.LocalPlayer

local root -- container frame
local objectiveTitle, objectiveText
local statusName, hpFill, abilityLabel
local ring, ringLabel
local invLabel, hintLabel
local crosshair
local toastHolder
local downed, downedText, secondWindButton
local ferryPanel, ferryText
local indicatorLayer
local indicators = {} -- [Model] = TextLabel
local noiseSmoothed = 0

function HUD.build(gui, onSecondWind)
	root = Theme.make("Frame", { Name = "HUD", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = gui })

	-- objective
	local obj = Theme.panel({
		Name = "Objective",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 14),
		Size = UDim2.new(0, 520, 0, 62),
		BackgroundTransparency = 0.3,
		Parent = root,
	})
	Theme.make("UISizeConstraint", { MaxSize = Vector2.new(520, 62), Parent = obj })
	obj.Size = UDim2.new(0.9, 0, 0, 62)
	Theme.padding(10).Parent = obj
	objectiveTitle = Theme.heading({ Text = "", TextSize = 19, Size = UDim2.new(1, 0, 0, 22), TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = C.lantern, Parent = obj })
	objectiveText = Theme.label({ Text = "", TextSize = 14, Position = UDim2.new(0, 0, 0, 22), Size = UDim2.new(1, 0, 0, 20), TextXAlignment = Enum.TextXAlignment.Center, Parent = obj })

	-- status
	local status = Theme.panel({
		Name = "Status",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 18, 1, -18),
		Size = UDim2.new(0, 280, 0, 84),
		BackgroundTransparency = 0.3,
		Parent = root,
	})
	Theme.padding(10).Parent = status
	statusName = Theme.heading({ Text = "", TextSize = 18, Size = UDim2.new(1, 0, 0, 20), Parent = status })
	local hpBack = Theme.make("Frame", { Position = UDim2.new(0, 0, 0, 26), Size = UDim2.new(1, 0, 0, 6), BackgroundColor3 = C.panelHi, BorderSizePixel = 0, Parent = status })
	Theme.corner(3).Parent = hpBack
	hpFill = Theme.make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.text, BorderSizePixel = 0, Parent = hpBack })
	Theme.corner(3).Parent = hpFill
	abilityLabel = Theme.label({ Text = "", TextSize = 13, Position = UDim2.new(0, 0, 0, 38), Size = UDim2.new(1, 0, 0, 30), TextColor3 = C.salt, Parent = status })

	-- noise ring
	local ringHolder = Theme.make("Frame", {
		Name = "Noise",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -34),
		Size = UDim2.new(0, 110, 0, 110),
		BackgroundTransparency = 1,
		Parent = root,
	})
	ring = Theme.make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.1, 0.1), BackgroundTransparency = 1, Parent = ringHolder })
	Theme.make("UICorner", { CornerRadius = UDim.new(1, 0), Parent = ring })
	Theme.make("UIStroke", { Color = C.text, Thickness = 2, Transparency = 0.4, Parent = ring })
	Theme.make("UIAspectRatioConstraint", { Parent = ring })
	ringLabel = Theme.heading({ Text = "SILENT", TextSize = 13, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 2), Size = UDim2.new(0, 120, 0, 16), TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = C.dim, Parent = ringHolder })

	-- satchel strip + key hints
	invLabel = Theme.label({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -18, 1, -40),
		Size = UDim2.new(0, 420, 0, 40),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextYAlignment = Enum.TextYAlignment.Bottom,
		Font = Theme.Head,
		TextSize = 16,
		Parent = root,
	})
	hintLabel = Theme.label({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -18, 1, -16),
		Size = UDim2.new(0, 760, 0, 20),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextYAlignment = Enum.TextYAlignment.Bottom,
		TextSize = 12,
		TextColor3 = C.dim,
		Text = "WASD move · Shift sprint · C crouch · RMB aim · LMB slingshot · G bottle · F quiet/shove · Q skill · H heal · T torch · X shoulder · Tab satchel · B resupply",
		Visible = UserInputService.KeyboardEnabled and not UserInputService.TouchEnabled,
		Parent = root,
	})

	crosshair = Theme.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, 5, 0, 5),
		BackgroundColor3 = C.text,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		Visible = false,
		Parent = root,
	})
	Theme.make("UICorner", { CornerRadius = UDim.new(1, 0), Parent = crosshair })

	indicatorLayer = Theme.make("Frame", { Name = "Indicators", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = root })

	toastHolder = Theme.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 86),
		Size = UDim2.new(0, 600, 0, 200),
		BackgroundTransparency = 1,
		Parent = root,
	})
	Theme.list(Enum.FillDirection.Vertical, 4, Enum.HorizontalAlignment.Center).Parent = toastHolder

	-- downed overlay
	downed = Theme.make("Frame", { Name = "Downed", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.55, Visible = false, Parent = root })
	downedText = Theme.heading({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.new(0.9, 0, 0, 80), TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = true, TextSize = 24, Parent = downed })
	secondWindButton = Theme.button({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.new(0, 300, 0, 44), Text = "SECOND WIND  [R]", Parent = downed })
	secondWindButton.Activated:Connect(onSecondWind)

	-- ferry panel
	ferryPanel = Theme.panel({
		Name = "Ferry",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0, 18, 0, 90),
		Size = UDim2.new(0, 300, 0, 132),
		BackgroundTransparency = 0.25,
		Visible = false,
		Parent = root,
	})
	Theme.padding(12).Parent = ferryPanel
	Theme.heading({ Text = "THE MERIDIAN", TextSize = 18, Size = UDim2.new(1, 0, 0, 22), TextColor3 = C.lantern, Parent = ferryPanel })
	ferryText = Theme.label({ Position = UDim2.new(0, 0, 0, 26), Size = UDim2.new(1, 0, 1, -26), TextSize = 13, Parent = ferryPanel })
end

function HUD.toast(text)
	if not toastHolder then
		return
	end
	local label = Theme.label({
		Text = text,
		Size = UDim2.new(1, 0, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 16,
		TextStrokeTransparency = 0.6,
		Parent = toastHolder,
	})
	task.delay(3.5, function()
		for i = 1, 10 do
			label.TextTransparency = i / 10
			label.TextStrokeTransparency = 0.6 + i / 25
			task.wait(0.04)
		end
		label:Destroy()
	end)
	local children = toastHolder:GetChildren()
	if #children > 6 then
		for _, child in children do
			if child:IsA("TextLabel") then
				child:Destroy()
				break
			end
		end
	end
end

local function noiseWord(radius)
	if radius < 1 then
		return "SILENT", C.dim
	elseif radius <= Movement.Noise.Crouch + 1 then
		return "QUIET", C.salt
	elseif radius <= Movement.Noise.Walk + 2 then
		return "AUDIBLE", C.text
	elseif radius <= Movement.Noise.Jog + 4 then
		return "LOUD", C.lantern
	end
	return "VERY LOUD", C.danger
end

local function updateIndicators(camera, active)
	local enemies = Workspace:FindFirstChild("Enemies")
	local seen = {}
	if active and enemies and State.root then
		local key = "Sus_" .. player.UserId
		local viewport = camera.ViewportSize
		local center = Vector2.new(viewport.X / 2, viewport.Y / 2)
		local radius = math.min(viewport.X, viewport.Y) * 0.22
		for _, model in enemies:GetChildren() do
			local r = model:FindFirstChild("HumanoidRootPart")
			local state = model:GetAttribute("State")
			local sus = model:GetAttribute(key) or 0
			local hunting = state == "Chase" and model:GetAttribute("Target") == player.UserId
			if r and state ~= "Dispersed" and (sus > 0.04 or hunting) then
				seen[model] = true
				local label = indicators[model]
				if not label then
					label = Theme.label({
						Text = "▲",
						Font = Enum.Font.GothamBold,
						TextSize = 26,
						AnchorPoint = Vector2.new(0.5, 0.5),
						Size = UDim2.new(0, 30, 0, 30),
						TextXAlignment = Enum.TextXAlignment.Center,
						TextYAlignment = Enum.TextYAlignment.Center,
						TextStrokeTransparency = 0.5,
						Parent = indicatorLayer,
					})
					indicators[model] = label
				end
				local rel = camera.CFrame:PointToObjectSpace(r.Position)
				local angle = math.atan2(rel.X, -rel.Z)
				label.Position = UDim2.fromOffset(center.X + math.sin(angle) * radius, center.Y - math.cos(angle) * radius)
				label.Rotation = math.deg(angle)
				local level = hunting and 1 or math.clamp(sus, 0, 1)
				if hunting then
					label.TextColor3 = C.danger
				elseif level >= 0.35 then
					label.TextColor3 = C.lantern
				else
					label.TextColor3 = C.text
				end
				label.TextTransparency = 0.75 - level * 0.75
				label.TextSize = 18 + level * 14
			end
		end
	end
	for model, label in indicators do
		if not seen[model] then
			label:Destroy()
			indicators[model] = nil
		end
	end
end

function HUD.update(dt)
	if not root then
		return
	end
	local camera = Workspace.CurrentCamera
	local char = State.character
	local matchState = ReplicatedStorage:GetAttribute("MatchState")
	local inEncounter = matchState == "Encounter" and char ~= nil and player:GetAttribute("InCrossing") == true

	-- objective
	if matchState == "Encounter" and inEncounter then
		local modName = ReplicatedStorage:GetAttribute("ModifierName") or ""
		objectiveTitle.Text = "CANNERY ROW  ·  " .. string.upper(modName)
		if ReplicatedStorage:GetAttribute("ExtractionOpen") then
			objectiveText.Text = "Reach the Slipway flare (north-west). All standing crew must be there."
		else
			objectiveText.Text = ("Salvage supply crates  %d / %d"):format(ReplicatedStorage:GetAttribute("Crates") or 0, ReplicatedStorage:GetAttribute("CratesRequired") or 5)
		end
	elseif matchState == "Starting" then
		local startsAt = ReplicatedStorage:GetAttribute("StartsAt") or 0
		objectiveTitle.Text = "CASTING OFF"
		objectiveText.Text = ("Crossing begins in %d"):format(math.max(0, math.ceil(startsAt - Workspace:GetServerTimeNow())))
	elseif matchState == "Encounter" then
		objectiveTitle.Text = "A CROSSING IS UNDERWAY"
		objectiveText.Text = "Wait on the Meridian. You'll join the next one."
	else
		objectiveTitle.Text = "THE MERIDIAN"
		objectiveText.Text = "Rest, resupply, then plot a crossing at the tide chart."
	end

	-- ferry panel
	ferryPanel.Visible = char ~= nil and not inEncounter
	ferryText.Text = "Tide chart: start a crossing (up to 4 crew).\nCrew cabins: change character & perk.\nPurser's Office: the ledger (run aids).\nSecond Wind: " .. tostring(player:GetAttribute("Tokens_secondWind") or 0) .. "   Resupply: " .. tostring(player:GetAttribute("Tokens_resupply") or 0)

	-- status
	local charId = player:GetAttribute("CharId")
	local def = charId and Characters.List[charId]
	statusName.Text = def and string.upper(def.name) or ""
	local hp = char and char:GetAttribute("HP") or 0
	local maxHp = char and char:GetAttribute("MaxHP") or 100
	hpFill.Size = UDim2.fromScale(math.clamp(hp / maxHp, 0, 1), 1)
	hpFill.BackgroundColor3 = hp / maxHp < 0.35 and C.danger or C.text
	if def and char then
		local remaining = (char:GetAttribute("AbilityReadyAt") or 0) - Workspace:GetServerTimeNow()
		abilityLabel.Text = ("[Q] %s  ·  %s"):format(string.upper(def.ability.name), remaining > 0 and (math.ceil(remaining) .. "s") or "READY")
	else
		abilityLabel.Text = ""
	end

	-- noise ring (server-authoritative radius, smoothed)
	local noise = char and char:GetAttribute("Noise") or 0
	if not inEncounter then
		noise = 0
	end
	noiseSmoothed += (noise - noiseSmoothed) * math.min(1, dt * 8)
	local scale = math.clamp(noiseSmoothed / Movement.Noise.Sprint, 0.08, 1)
	ring.Size = UDim2.fromScale(scale, scale)
	local word, color = noiseWord(noise)
	ringLabel.Text = word
	ringLabel.TextColor3 = color
	ring.UIStroke.Color = color

	-- satchel strip
	local function inv(id)
		return player:GetAttribute("Inv_" .. id) or 0
	end
	invLabel.Text = ("SHOT %d   BOTTLE %d/%d   BANDAGE %d\nGLASS %d   CLOTH %d   SCRAP %d"):format(
		inv("shot"),
		inv("bottle"),
		player:GetAttribute("Cap_bottle") or 3,
		inv("bandage"),
		inv("glass"),
		inv("cloth"),
		inv("scrap")
	)
	invLabel.Visible = char ~= nil

	crosshair.Visible = State.aiming and not State.uiOpen()

	-- downed overlay
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
		secondWindButton.Text = ("SECOND WIND  [R]   ·   tokens: %d"):format(player:GetAttribute("Tokens_secondWind") or 0)
	end

	updateIndicators(camera, inEncounter)
end

return HUD
