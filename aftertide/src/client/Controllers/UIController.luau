--!nonstrict
-- Owns the ScreenGui and routes server notifications to the UI modules.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Sfx = require(Shared.Util.Sfx)
local UI = script.Parent.Parent:WaitForChild("UI")
local HUD = require(UI:WaitForChild("HUD"))
local Diagnostics = require(UI:WaitForChild("Diagnostics"))
local State = require(script.Parent.Parent.State)
local Theme = require(UI:WaitForChild("Theme"))
local CharacterSelect = require(UI:WaitForChild("CharacterSelect"))
local Satchel = require(UI:WaitForChild("Satchel"))
local Shop = require(UI:WaitForChild("Shop"))
local Results = require(UI:WaitForChild("Results"))
local Chart = require(UI:WaitForChild("Chart"))
local Workbench = require(UI:WaitForChild("Workbench"))
local Repairs = require(UI:WaitForChild("Repairs"))
local Settings = require(UI:WaitForChild("Settings"))
local Quests = require(UI:WaitForChild("Quests"))
local Quartermaster = require(UI:WaitForChild("Quartermaster"))
local Spin = require(UI:WaitForChild("Spin"))
local Guide = require(UI:WaitForChild("Guide"))
local Logbook = require(UI:WaitForChild("Logbook"))
local Callouts = require(UI:WaitForChild("Callouts"))
local AdOffers = require(UI:WaitForChild("AdOffers"))

local UIController = {}
local Controllers
local player = Players.LocalPlayer

function UIController.toggleSatchel()
	Satchel.toggle()
end

-- First time you're in the world: show the controls for a while.
local shownControls = false
function UIController.onCharacter()
	if shownControls then
		return
	end
	shownControls = true
	task.delay(1.5, function()
		HUD.toggleControls(true)
		task.delay(14, function()
			HUD.toggleControls(false)
		end)
	end)
end

function UIController.toggleControls(force)
	HUD.toggleControls(force)
end

function UIController.openSpin()
	Spin.open()
end

function UIController.setSetting(key, value)
	Settings.setValue(key, value)
end

function UIController.toggleSettings()
	Settings.toggle()
end

local function closeMenus()
	Chart.close()
	Workbench.close()
	Repairs.close()
	Shop.close()
	Satchel.close()
	CharacterSelect.close()
	Quests.close()
	Quartermaster.close()
	Spin.close()
	Logbook.close()
	AdOffers.close()
end

function UIController.init(registry)
	Controllers = registry
end

function UIController.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "AftertideUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Everything is built inside one scaler: text and menus are scaled up together (bigger on big
	-- screens and consoles, and by the "Text and menu size" setting) so nothing is tiny.
	local UserInputService = game:GetService("UserInputService")
	local ui = Instance.new("Frame")
	ui.Name = "Scaler"
	ui.BackgroundTransparency = 1
	ui.BorderSizePixel = 0
	ui.Size = UDim2.fromScale(1, 1)
	ui.Parent = gui
	local uiScale = Instance.new("UIScale")
	uiScale.Parent = ui
	local function applyScale()
		local vh = Workspace.CurrentCamera.ViewportSize.Y
		local mult = ({ Normal = 1, Large = 1.2, Huge = 1.4 })[player:GetAttribute("Set_uiSize") or "Large"] or 1.2
		local scale = math.clamp(vh / 860, 1, 1.5) * mult * (State.gamepad and 1.12 or 1)
		if vh < 520 then
			scale = 1 -- phones: the screen is already small
		end
		scale = math.clamp(scale, 1, 2.1)
		if math.abs(uiScale.Scale - scale) > 0.001 then
			uiScale.Scale = scale
			ui.Size = UDim2.fromScale(1 / scale, 1 / scale)
			Theme.scale = scale
		end
	end
	applyScale()
	player:GetAttributeChangedSignal("Set_uiSize"):Connect(applyScale)
	Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(applyScale)
	task.spawn(function()
		while true do
			task.wait(0.5)
			applyScale() -- picks up a switch between mouse and controller
		end
	end)

	local function send(name, payload)
		Controllers.ActionController.sendAction(name, payload)
	end
	local function request(kind, a, b)
		Controllers.ActionController.request(kind, a, b)
	end
	-- each panel builds on its own: one failing must not leave the rest (satchel, shop...) unbuilt
	local function build(name, fn)
		local ok, err = pcall(fn)
		if not ok then
			warn(("[UI] %s failed to build: %s"):format(name, tostring(err)))
		end
	end
	build("HUD", function()
		HUD.build(ui, function()
			send("SecondWind")
		end, Controllers.WeaponController)
	end)
	build("CharacterSelect", function()
		CharacterSelect.build(ui)
	end)
	build("Satchel", function()
		Satchel.build(ui, send)
	end)
	build("Shop", function()
		Shop.build(ui)
	end)
	build("Results", function()
		Results.build(ui)
	end)
	build("Chart", function()
		Chart.build(ui, request)
	end)
	build("Workbench", function()
		Workbench.build(ui, request)
	end)
	build("Repairs", function()
		Repairs.build(ui, request)
	end)
	build("Settings", function()
		Settings.build(ui, request)
	end)
	build("Quests", function()
		Quests.build(ui)
	end)
	build("Quartermaster", function()
		Quartermaster.build(ui, request)
	end)
	build("AdOffers", function()
		AdOffers.build(ui, request, HUD.toast)
	end)
	build("Callouts", function()
		Callouts.build(ui)
	end)
	build("Logbook", function()
		Logbook.build(ui)
	end)
	build("Guide", function()
		Guide.build(ui, request)
	end)
	build("Spin", function()
		Spin.build(ui, request, Shop.prompt)
	end)
	build("Diagnostics", function()
		local dgui = Instance.new("ScreenGui")
		dgui.Name = "AftertideDiagnostics"
		dgui.ResetOnSpawn = false
		dgui.DisplayOrder = 100
		dgui.IgnoreGuiInset = true
		dgui.Parent = player:WaitForChild("PlayerGui")
		Diagnostics.build(dgui)
	end)
	Satchel.setMenuHandlers({
		spin = function()
			Spin.open()
		end,
		freeStuff = function()
			AdOffers.open()
		end,
		logbook = function()
			Logbook.open()
		end,
		view = function()
			Controllers.CameraController.toggleFirstPerson()
			HUD.toast(State.firstPerson and "First person" or "Third person")
		end,
		shop = function()
			Shop.open()
		end,
		settings = function()
			UIController.toggleSettings()
		end,
		controls = function()
			HUD.toggleControls(true)
		end,
	})
	Diagnostics.setStatusProvider(function()
		local out = {}
		local anim = Controllers.PlayerAnimator.status()
		table.insert(out, ("animator: %d character(s) animated last frame, %d frames; setup: %s"):format(anim.animatedLastFrame, anim.frames, anim.setupFail or "ok"))
		table.insert(out, "animator last error: " .. tostring(anim.lastError or "none"))
		table.insert(out, ("Roblox Animators removed: %d"):format(anim.animatorsRemoved))
		local char = State.character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		table.insert(out, ("character: %s · procedural=%s · Animator present=%s · HipHeight=%.2f (base %s)"):format(
			char and char.Name or "none", tostring(char and char:GetAttribute("Procedural")), tostring(hum and hum:FindFirstChildOfClass("Animator") ~= nil),
			hum and hum.HipHeight or -1, tostring(char and char:GetAttribute("BaseHipHeight"))))
		local meshes = 0
		if char then
			for _, d in char:GetChildren() do
				if d:IsA("MeshPart") and d.Name:sub(1, 5) == "Mesh_" then
					meshes += 1
				end
			end
		end
		table.insert(out, ("sculpted body pieces on character: %d"):format(meshes))
		table.insert(out, ("stance: %s · crouched=%s prone=%s aiming=%s sprinting=%s downed=%s"):format(
			tostring(char and char:GetAttribute("Stance")), tostring(State.crouched), tostring(State.prone), tostring(State.aiming), tostring(State.sprinting), tostring(State.downed)))
		local open = {}
		for name in State.modals do
			table.insert(open, name)
		end
		table.insert(out, "open menus: " .. (#open > 0 and table.concat(open, ", ") or "none"))
		table.insert(out, ("equipped: %s (%s)"):format(tostring(char and char:GetAttribute("Equipped")), tostring(char and char:GetAttribute("EquippedSlot"))))
		local sky = game:GetService("Lighting"):FindFirstChildOfClass("Sky")
		table.insert(out, "sky: " .. (sky and ("Bk=" .. sky.SkyboxBk .. " Up=" .. sky.SkyboxUp) or "no Sky object"))
		return out
	end)

	-- Menu keys go through a direct input listener. Roblox's own scripts (player list on Tab,
	-- default camera on right-click) can take keys before ContextActionService sees them.
	local UserInputService = game:GetService("UserInputService")
	UserInputService.InputBegan:Connect(function(input)
		if UserInputService:GetFocusedTextBox() then
			return
		end
		local key = input.KeyCode
		if key == Enum.KeyCode.Tab or key == Enum.KeyCode.I or key == Enum.KeyCode.ButtonSelect then
			Diagnostics.noteInput("key " .. key.Name .. " -> satchel")
			if State.character then
				Satchel.toggle()
			end
		elseif key == Enum.KeyCode.ButtonB and State.uiOpen() then
			Diagnostics.noteInput("pad B -> close menus")
			closeMenus()
			Settings.close()
			Results.close()
		elseif key == Enum.KeyCode.K and State.character then
			Controllers.CameraController.toggleFirstPerson()
			HUD.toast(State.firstPerson and "First person" or "Third person")
		elseif key == Enum.KeyCode.F1 then
			Diagnostics.noteInput("key F1 -> controls")
			HUD.toggleControls()
		elseif key == Enum.KeyCode.F2 then
			Diagnostics.toggle()
		elseif key == Enum.KeyCode.P then
			Diagnostics.noteInput("key P -> settings")
			UIController.toggleSettings()
		end
	end)

	Net.event("Notify").OnClientEvent:Connect(function(kind, data)
		data = data or {}
		if kind == "Diag" then
			Diagnostics.serverLine(data.k, data.m)
		elseif kind == "Toast" then
			HUD.toast(tostring(data.text or ""))
		elseif kind == "OpenCharacterSelect" then
			CharacterSelect.open()
		elseif kind == "OpenShop" then
			Shop.open(data and data.tab)
		elseif kind == "Results" then
			Satchel.close()
			Results.show(data)
		elseif kind == "OpenChart" then
			Sfx.ui("Ui_Confirm", 0.5)
			Chart.open()
		elseif kind == "OpenWorkbench" then
			Sfx.ui("Ui_Tick", 0.5)
			Workbench.open()
		elseif kind == "OpenRepairs" then
			Repairs.open()
		elseif kind == "OpenQuests" then
			Quests.open()
		elseif kind == "OpenQuartermaster" then
			Quartermaster.open()
		elseif kind == "AdResult" then
			AdOffers.result(data)
		elseif kind == "Callout" then
			Callouts.show(data)
		elseif kind == "DailyReward" then
			Logbook.showDaily(data.day, data.text)
		elseif kind == "OpenSpin" then
			Spin.open()
		elseif kind == "SpinResult" then
			task.spawn(Spin.result, data)
		elseif kind == "CloseMenus" then
			closeMenus()
		elseif kind == "Hit" then
			HUD.hit(data)
		elseif kind == "Hurt" then
			HUD.hurt()
		elseif kind == "EncounterStart" then
			closeMenus()
			Results.close()
			HUD.toast(("%s · %s"):format(tostring(data.name), tostring(data.modifierName)))
			HUD.toast(tostring(data.modifierDesc or ""))
			HUD.toast(tostring(data.objective or ""))
		elseif kind == "Spotted" then
			HUD.toast("You've been seen. Break line of sight!")
		elseif kind == "NeedProduct" then
			if not Shop.prompt(data.productKey) then
				HUD.toast("No tokens left. Earn more by finishing crossings.")
			end
		end
	end)

	ReplicatedStorage:GetAttributeChangedSignal("MatchState"):Connect(function()
		local matchState = ReplicatedStorage:GetAttribute("MatchState")
		if matchState == "Ferry" or matchState == "Planning" then
			Results.close()
		end
	end)

	-- First visit: choose a crew member (also covers a missed server notification).
	task.delay(1.5, function()
		if not player:GetAttribute("CharId") then
			CharacterSelect.open()
		end
	end)

	local reported = {}
	local function safe(name, fn, ...)
		local ok, err = pcall(fn, ...)
		if not ok and not reported[name] then
			reported[name] = true
			warn(("[UI] %s: %s"):format(name, tostring(err)))
		end
	end
	-- Console: keep the selection cursor inside whatever menu is open; drop it when none is.
	local GuiService = game:GetService("GuiService")
	local function firstButton()
		local best, bestY, bestX
		for _, d in gui:GetDescendants() do
			if d:IsA("GuiButton") and d.Visible and d.Selectable then
				local shown, modal = true, false
				local a = d
				while a and a ~= gui do
					if a:IsA("GuiObject") then
						if not a.Visible then
							shown = false
							break
						end
						if a.ZIndex >= 20 then
							modal = true
						end
					end
					a = a.Parent
				end
				if shown and modal then
					local p = d.AbsolutePosition
					if not best or p.Y < bestY - 4 or (math.abs(p.Y - bestY) <= 4 and p.X < bestX) then
						best, bestY, bestX = d, p.Y, p.X
					end
				end
			end
		end
		return best
	end
	local function manageSelection()
		local sel = GuiService.SelectedObject
		if not State.uiOpen() then
			if sel and sel:IsDescendantOf(gui) then
				GuiService.SelectedObject = nil
			end
		elseif State.gamepad and (sel == nil or not sel.Visible or not sel:IsDescendantOf(gui)) then
			GuiService.SelectedObject = firstButton()
		end
	end
	RunService.RenderStepped:Connect(function(dt)
		safe("Selection", manageSelection)
		safe("HUD", HUD.update, dt)
		safe("Satchel", Satchel.refresh)
		safe("Shop", Shop.refresh)
		safe("Spin", Spin.refresh)
		safe("Guide", Guide.update)
	end)
end

return UIController
