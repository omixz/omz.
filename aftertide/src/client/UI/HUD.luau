--!nonstrict
-- In-run HUD: objective (with lantern health / waves / timers), run info, health + ability,
-- weapon & ammo panel, dynamic crosshair + hitmarkers, noise ring, detection indicators,
-- toasts, downed overlay and the ferry panel. Updated every frame from attributes.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
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
local Weapon -- WeaponController (set in build)

local root
local objectiveTitle, objectiveText, lanternBack, lanternFill
local runLabel
local statusName, hpFill, abilityLabel, salvageLabel
local weaponName, ammoLabel, slotsLabel, throwLabel, kitLabel, reloadLabel
local ring, ringLabel
local hintLabel
local ticks = {}
local dot, hitmarker
local toastHolder
local downed, downedText, secondWindButton
local ferryPanel, ferryText
local indicatorLayer
local indicators = {}
local noiseSmoothed = 0
local hitUntil = 0

local function inv(id)
	return player:GetAttribute("Inv_" .. id) or 0
end

local function clock(seconds)
	seconds = math.max(0, math.floor(seconds))
	return ("%d:%02d"):format(math.floor(seconds / 60), seconds % 60)
end

function HUD.build(gui, onSecondWind, weaponController)
	Weapon = weaponController
	root = Theme.make("Frame", { Name = "HUD", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = gui })

	-- objective
	local obj = Theme.panel({
		Name = "Objective",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 14),
		Size = UDim2.new(0.9, 0, 0, 74),
		BackgroundTransparency = 0.3,
		Parent = root,
	})
	Theme.make("UISizeConstraint", { MaxSize = Vector2.new(560, 74), Parent = obj })
	Theme.padding(10).Parent = obj
	objectiveTitle = Theme.heading({ Text = "", TextSize = 18, Size = UDim2.new(1, 0, 0, 22), TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = C.lantern, Parent = obj })
	objectiveText = Theme.label({ Text = "", TextSize = 14, Position = UDim2.new(0, 0, 0, 22), Size = UDim2.new(1, 0, 0, 20), TextXAlignment = Enum.TextXAlignment.Center, Parent = obj })
	lanternBack = Theme.make("Frame", { Position = UDim2.new(0.15, 0, 0, 46), Size = UDim2.new(0.7, 0, 0, 5), BackgroundColor3 = C.panelHi, BorderSizePixel = 0, Visible = false, Parent = obj })
	Theme.corner(3).Parent = lanternBack
	lanternFill = Theme.make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.lantern, BorderSizePixel = 0, Parent = lanternBack })
	Theme.corner(3).Parent = lanternFill

	runLabel = Theme.heading({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -18, 0, 16),
		Size = UDim2.new(0, 220, 0, 40),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextSize = 15,
		TextColor3 = C.salt,
		TextWrapped = true,
		Parent = root,
	})

	-- status
	local status = Theme.panel({
		Name = "Status",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 18, 1, -18),
		Size = UDim2.new(0, 280, 0, 100),
		BackgroundTransparency = 0.3,
		Parent = root,
	})
	Theme.padding(10).Parent = status
	statusName = Theme.heading({ Text = "", TextSize = 18, Size = UDim2.new(1, 0, 0, 20), Parent = status })
	local hpBack = Theme.make("Frame", { Position = UDim2.new(0, 0, 0, 26), Size = UDim2.new(1, 0, 0, 6), BackgroundColor3 = C.panelHi, BorderSizePixel = 0, Parent = status })
	Theme.corner(3).Parent = hpBack
	hpFill = Theme.make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.text, BorderSizePixel = 0, Parent = hpBack })
	Theme.corner(3).Parent = hpFill
	abilityLabel = Theme.label({ Text = "", TextSize = 13, Position = UDim2.new(0, 0, 0, 38), Size = UDim2.new(1, 0, 0, 18), TextColor3 = C.salt, Parent = status })
	salvageLabel = Theme.label({ Text = "", TextSize = 13, Position = UDim2.new(0, 0, 0, 58), Size = UDim2.new(1, 0, 0, 18), Font = Theme.Head, TextColor3 = C.lantern, Parent = status })

	-- weapon panel
	local wp = Theme.panel({
		Name = "Weapon",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -18, 1, -40),
		Size = UDim2.new(0, 300, 0, 128),
		BackgroundTransparency = 0.3,
		Parent = root,
	})
	Theme.padding(10).Parent = wp
	weaponName = Theme.heading({ Text = "", TextSize = 16, Size = UDim2.new(1, 0, 0, 18), TextXAlignment = Enum.TextXAlignment.Right, Parent = wp })
	ammoLabel = Theme.heading({ Text = "", TextSize = 30, Position = UDim2.new(0, 0, 0, 18), Size = UDim2.new(1, 0, 0, 34), TextXAlignment = Enum.TextXAlignment.Right, Parent = wp })
	reloadLabel = Theme.heading({ Text = "RELOADING", TextSize = 14, Position = UDim2.new(0, 0, 0, 30), Size = UDim2.new(0.5, 0, 0, 18), TextColor3 = C.lantern, Visible = false, Parent = wp })
	slotsLabel = Theme.label({ Text = "", TextSize = 12, Position = UDim2.new(0, 0, 0, 54), Size = UDim2.new(1, 0, 0, 16), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = C.dim, Parent = wp })
	throwLabel = Theme.label({ Text = "", TextSize = 13, Position = UDim2.new(0, 0, 0, 72), Size = UDim2.new(1, 0, 0, 16), TextXAlignment = Enum.TextXAlignment.Right, Font = Theme.Head, Parent = wp })
	kitLabel = Theme.label({ Text = "", TextSize = 12, Position = UDim2.new(0, 0, 0, 90), Size = UDim2.new(1, 0, 0, 16), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = C.dim, Parent = wp })

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

	hintLabel = Theme.label({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -18, 1, -16),
		Size = UDim2.new(0, 900, 0, 20),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextYAlignment = Enum.TextYAlignment.Bottom,
		TextSize = 12,
		TextColor3 = C.dim,
		Text = "1/2/3 weapons · RMB aim · LMB fire · R reload · F quiet · G throw · Z next throwable · C crouch · Shift sprint · Q skill · H heal · T torch · Tab satchel · P settings",
		Visible = UserInputService.KeyboardEnabled and not UserInputService.TouchEnabled,
		Parent = root,
	})

	-- crosshair (4 ticks that spread with accuracy) + centre dot + hitmarker
	for i = 1, 4 do
		local horizontal = i <= 2
		ticks[i] = Theme.make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = horizontal and UDim2.new(0, 9, 0, 2) or UDim2.new(0, 2, 0, 9),
			BackgroundColor3 = C.text,
			BackgroundTransparency = 0.15,
			BorderSizePixel = 0,
			Visible = false,
			Parent = root,
		})
	end
	dot = Theme.make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 4, 0, 4), BackgroundColor3 = C.text, BorderSizePixel = 0, Visible = false, Parent = root })
	Theme.make("UICorner", { CornerRadius = UDim.new(1, 0), Parent = dot })
	hitmarker = Theme.make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 26, 0, 26), BackgroundTransparency = 1, Visible = false, Parent = root })
	for _, rot in { 45, -45 } do
		Theme.make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 0, 0, 2), Rotation = rot, BackgroundColor3 = C.text, BorderSizePixel = 0, Parent = hitmarker })
	end

	indicatorLayer = Theme.make("Frame", { Name = "Indicators", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = root })

	toastHolder = Theme.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 96),
		Size = UDim2.new(0, 640, 0, 200),
		BackgroundTransparency = 1,
		Parent = root,
	})
	Theme.list(Enum.FillDirection.Vertical, 4, Enum.HorizontalAlignment.Center).Parent = toastHolder

	downed = Theme.make("Frame", { Name = "Downed", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.55, Visible = false, Parent = root })
	downedText = Theme.heading({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.new(0.9, 0, 0, 80), TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = true, TextSize = 24, Parent = downed })
	secondWindButton = Theme.button({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.new(0, 320, 0, 44), Text = "SECOND WIND  [R]", Parent = downed })
	secondWindButton.Activated:Connect(onSecondWind)

	ferryPanel = Theme.panel({
		Name = "Ferry",
		Position = UDim2.new(0, 18, 0, 100),
		Size = UDim2.new(0, 310, 0, 150),
		BackgroundTransparency = 0.25,
		Visible = false,
		Parent = root,
	})
	Theme.padding(12).Parent = ferryPanel
	Theme.heading({ Text = "THE MERIDIAN", TextSize = 18, Size = UDim2.new(1, 0, 0, 22), TextColor3 = C.lantern, Parent = ferryPanel })
	ferryText = Theme.label({ Position = UDim2.new(0, 0, 0, 26), Size = UDim2.new(1, 0, 1, -26), TextSize = 13, Parent = ferryPanel })
end

function HUD.toast(text)
	if not toastHolder or text == "" then
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

function HUD.hit(data)
	if not hitmarker then
		return
	end
	hitUntil = os.clock() + (data.kill and 0.35 or 0.15)
	local color = data.kill and C.danger or (data.headshot and C.lantern or C.text)
	hitmarker.Size = UDim2.new(0, data.headshot and 34 or 24, 0, data.headshot and 34 or 24)
	for _, line in hitmarker:GetChildren() do
		if line:IsA("Frame") then
			line.BackgroundColor3 = color
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
			local enemyState = model:GetAttribute("State")
			local sus = model:GetAttribute(key) or 0
			local hunting = enemyState == "Chase" and model:GetAttribute("Target") == player.UserId
			if r and enemyState ~= "Dispersed" and (sus > 0.04 or hunting) then
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
				label.TextColor3 = hunting and C.danger or (level >= 0.35 and C.lantern or C.text)
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

local function updateObjective(matchState, inEncounter)
	local R = ReplicatedStorage
	local runIndex, runLength = R:GetAttribute("RunIndex") or 0, R:GetAttribute("RunLength") or 4
	lanternBack.Visible = false
	if matchState == "Encounter" and inEncounter then
		local modName = R:GetAttribute("ModifierName") or ""
		objectiveTitle.Text = ("%s  ·  %s"):format(string.upper(R:GetAttribute("EncounterName") or ""), string.upper(modName))
		local kind = R:GetAttribute("EncounterType")
		local timeLeft = (R:GetAttribute("EndsAt") or 0) - Workspace:GetServerTimeNow()
		if kind == "Salvage" then
			objectiveText.Text = R:GetAttribute("ExtractionOpen") and "Reach the Slipway flare (north-west). All standing crew must be there."
				or ("Salvage supply crates  %d / %d"):format(R:GetAttribute("Crates") or 0, R:GetAttribute("CratesRequired") or 0)
		elseif kind == "LanternWatch" then
			local hp, max = R:GetAttribute("LanternHP") or 0, math.max(1, R:GetAttribute("LanternMax") or 1)
			objectiveText.Text = ("Keep the lantern lit  ·  Wave %d / %d  ·  %s"):format(R:GetAttribute("Wave") or 0, R:GetAttribute("Waves") or 0, clock(timeLeft))
			lanternBack.Visible = true
			lanternFill.Size = UDim2.fromScale(math.clamp(hp / max, 0, 1), 1)
			lanternFill.BackgroundColor3 = hp / max < 0.3 and C.danger or C.lantern
		elseif kind == "Drift" then
			objectiveText.Text = R:GetAttribute("ExtractionOpen") and "The tide turned. Reach the Slipway flare!" or ("They know you're here. Survive  %s"):format(clock(timeLeft))
		end
	elseif matchState == "Starting" then
		objectiveTitle.Text = "CASTING OFF"
		objectiveText.Text = ("Crossing begins in %d"):format(math.max(0, math.ceil((R:GetAttribute("StartsAt") or 0) - Workspace:GetServerTimeNow())))
	elseif matchState == "Planning" then
		objectiveTitle.Text = ("THE MERIDIAN  ·  STOP %d OF %d"):format(runIndex, runLength)
		objectiveText.Text = "Upgrade at the workbench, craft, then choose a route at the tide chart."
	elseif matchState == "Encounter" then
		objectiveTitle.Text = "A CROSSING IS UNDERWAY"
		objectiveText.Text = "Wait on the Meridian. You can join at the next stop."
	elseif matchState == "Results" then
		objectiveTitle.Text = "DEBRIEF"
		objectiveText.Text = ""
	else
		objectiveTitle.Text = "THE MERIDIAN"
		objectiveText.Text = "Rest and prepare, then read the tide chart to start a crossing."
	end
	if R:GetAttribute("RunActive") and player:GetAttribute("InCrossing") then
		runLabel.Text = ("CROSSING %d / %d\nPALL %d"):format(runIndex, runLength, R:GetAttribute("Pall") or 1)
	else
		runLabel.Text = ""
	end
end

local function updateWeapon(viewport, camera)
	local slot, id = Weapon.current()
	local def = id and Weapons.List[id]
	if def then
		weaponName.Text = string.upper(def.name)
		local mag = player:GetAttribute("W_" .. slot .. "Mag") or 0
		ammoLabel.Text = ("%d  |  %d"):format(mag, inv(def.ammo))
		ammoLabel.TextColor3 = mag == 0 and C.danger or C.text
	else
		weaponName.Text = "HANDS"
		ammoLabel.Text = ""
	end
	reloadLabel.Visible = Weapon.isReloading()
	local long, side = player:GetAttribute("W_long") or "", player:GetAttribute("W_sidearm") or ""
	local function slotText(n, wId, s)
		local name = wId ~= "" and Weapons.List[wId] and string.upper(Weapons.List[wId].name) or "—"
		return (slot == s and "[%d %s]" or "%d %s"):format(n, name)
	end
	slotsLabel.Text = slotText(1, long, "long") .. "   " .. slotText(2, side, "sidearm") .. "   " .. (slot == "none" and "[3 HANDS]" or "3 HANDS")
	local throwable = State.throwable
	throwLabel.Text = ("%s ×%d  (G throw · Z next)"):format(string.upper(Items.Items[throwable].name), inv(throwable))
	kitLabel.Text = ("Dressing %d · Spike %d"):format(inv("dressing"), inv("spike"))

	-- crosshair
	local show = def ~= nil and not State.uiOpen() and not State.downed
	local gapPx = 0
	if show then
		local spread = Weapon.spread()
		local fov = math.rad(camera.FieldOfView)
		gapPx = math.tan(math.rad(spread)) * viewport.Y / (2 * math.tan(fov / 2)) + 4
	end
	local cx, cy = viewport.X / 2, viewport.Y / 2
	local offsets = { Vector2.new(-gapPx - 5, 0), Vector2.new(gapPx + 5, 0), Vector2.new(0, -gapPx - 5), Vector2.new(0, gapPx + 5) }
	for i, tick in ticks do
		tick.Visible = show
		tick.Position = UDim2.fromOffset(cx + offsets[i].X, cy + offsets[i].Y)
	end
	dot.Visible = (show and State.aiming) or (not def and State.aiming and not State.uiOpen())
	hitmarker.Visible = os.clock() < hitUntil
end

function HUD.update(dt)
	if not root then
		return
	end
	local camera = Workspace.CurrentCamera
	local viewport = camera.ViewportSize
	local char = State.character
	local matchState = ReplicatedStorage:GetAttribute("MatchState")
	local inEncounter = matchState == "Encounter" and char ~= nil and player:GetAttribute("InCrossing") == true

	updateObjective(matchState, inEncounter)

	ferryPanel.Visible = char ~= nil and not inEncounter and matchState ~= "Results"
	local planning = matchState == "Planning" and player:GetAttribute("InCrossing")
	ferryText.Text = (planning and "Workbench: weapon parts, satchel, perks (Salvage).\nTide chart: choose the next route.\n" or "Tide chart: start a crossing (1 to 4 crew).\nCrew cabins: change character & perk.\n")
		.. "Repairs board: homebase upgrades (Scrip).\nPurser's Office: run aids.\n"
		.. ("Scrip %d · Second Wind %d · Resupply %d"):format(player:GetAttribute("Scrip") or 0, player:GetAttribute("Tokens_secondWind") or 0, player:GetAttribute("Tokens_resupply") or 0)

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
	salvageLabel.Text = player:GetAttribute("InCrossing") and ("SALVAGE %d"):format(player:GetAttribute("Salvage") or 0) or ""

	if char then
		updateWeapon(viewport, camera)
	end

	local noise = inEncounter and char and char:GetAttribute("Noise") or 0
	noiseSmoothed += (noise - noiseSmoothed) * math.min(1, dt * 8)
	local scale = math.clamp(noiseSmoothed / Movement.Noise.Sprint, 0.08, 1)
	ring.Size = UDim2.fromScale(scale, scale)
	local word, color = noiseWord(noise)
	ringLabel.Text = word
	ringLabel.TextColor3 = color
	ring.UIStroke.Color = color

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
