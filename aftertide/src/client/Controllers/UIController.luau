--!nonstrict
-- Owns the ScreenGui and routes server notifications to the UI modules.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Sfx = require(Shared.Util.Sfx)
local UI = script.Parent.Parent:WaitForChild("UI")
local HUD = require(UI:WaitForChild("HUD"))
local CharacterSelect = require(UI:WaitForChild("CharacterSelect"))
local Satchel = require(UI:WaitForChild("Satchel"))
local Shop = require(UI:WaitForChild("Shop"))
local Results = require(UI:WaitForChild("Results"))
local Chart = require(UI:WaitForChild("Chart"))
local Workbench = require(UI:WaitForChild("Workbench"))
local Repairs = require(UI:WaitForChild("Repairs"))
local Settings = require(UI:WaitForChild("Settings"))

local UIController = {}
local Controllers
local player = Players.LocalPlayer

function UIController.toggleSatchel()
	Satchel.toggle()
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

	local function send(name, payload)
		Controllers.ActionController.sendAction(name, payload)
	end
	local function request(kind, a, b)
		Controllers.ActionController.request(kind, a, b)
	end
	HUD.build(gui, function()
		send("SecondWind")
	end, Controllers.WeaponController)
	CharacterSelect.build(gui)
	Satchel.build(gui, send)
	Shop.build(gui)
	Results.build(gui)
	Chart.build(gui, request)
	Workbench.build(gui, request)
	Repairs.build(gui, request)
	Settings.build(gui, request)

	Net.event("Notify").OnClientEvent:Connect(function(kind, data)
		data = data or {}
		if kind == "Toast" then
			HUD.toast(tostring(data.text or ""))
		elseif kind == "OpenCharacterSelect" then
			CharacterSelect.open()
		elseif kind == "OpenShop" then
			Shop.open()
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

	RunService.RenderStepped:Connect(function(dt)
		HUD.update(dt)
		Satchel.refresh()
		Shop.refresh()
	end)
end

return UIController
