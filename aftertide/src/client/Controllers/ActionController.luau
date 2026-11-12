--!nonstrict
-- Input bindings (keyboard/mouse, gamepad, touch buttons) -> intents sent to the server.
--
--   Keyboard/mouse                     Gamepad
--   WASD move, Shift sprint            L-stick, L3 sprint (toggle)
--   C / Ctrl crouch                    B crouch
--   RMB aim, LMB fire                  L2 aim, R2 fire
--   1 long gun, 2 sidearm, 3 holster   D-pad right: cycle weapons
--   R reload (Second Wind if downed)   X: Quieting/shove near a Hushed, else reload
--   F Quieting / shove                 (X, contextual)
--   G throw, Z next throwable          R1 throw, D-pad down next throwable
--   Space dodge (dive when sprinting)  L1 dodge (dive when sprinting)
--   Q ability, H heal, T torch         Y ability, D-pad up heal, D-pad left torch
--   X swap shoulder, Tab satchel       R3 shoulder, View/Back satchel
--   B resupply, V ammo cache, P settings  Start/Menu: Roblox menu
local ContextActionService = game:GetService("ContextActionService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local State = require(script.Parent.Parent.State)

local ActionController = {}
local Controllers

local Begin = Enum.UserInputState.Begin
local End = Enum.UserInputState.End
local Sink = Enum.ContextActionResult.Sink
local Pass = Enum.ContextActionResult.Pass

local function act(name, payload)
	Net.event("Action"):FireServer(name, payload)
end

local function isTouch(input)
	return input and input.UserInputType == Enum.UserInputType.Touch
end

local function canAct()
	return State.character ~= nil and not State.uiOpen() and not State.downed
end

local touchLayout = {
	Fire = { title = "Fire", pos = UDim2.new(1, -95, 1, -230) },
	Aim = { title = "Aim", pos = UDim2.new(1, -170, 1, -230) },
	Reload = { title = "Reload", pos = UDim2.new(1, -245, 1, -230) },
	Quiet = { title = "Quiet", pos = UDim2.new(1, -95, 1, -160) },
	Throw = { title = "Throw", pos = UDim2.new(1, -170, 1, -160) },
	Ability = { title = "Skill", pos = UDim2.new(1, -245, 1, -160) },
	Crouch = { title = "Crouch", pos = UDim2.new(1, -95, 1, -300) },
	Sprint = { title = "Sprint", pos = UDim2.new(1, -170, 1, -300) },
	Weapon = { title = "Weapon", pos = UDim2.new(1, -245, 1, -300) },
	Heal = { title = "Heal", pos = UDim2.new(1, -320, 1, -230) },
	Satchel = { title = "Bag", pos = UDim2.new(1, -320, 1, -300) },
	Dodge = { title = "Dodge", pos = UDim2.new(1, -320, 1, -160) },
}

local function bind(name, handler, ...)
	local touch = touchLayout[name] ~= nil
	ContextActionService:BindAction(name, function(_, inputState, input)
		return handler(inputState, input) or Sink
	end, touch, ...)
	if touch then
		ContextActionService:SetTitle(name, touchLayout[name].title)
		ContextActionService:SetPosition(name, touchLayout[name].pos)
	end
end

local function enemyNearby(radius)
	local enemies = Workspace:FindFirstChild("Enemies")
	local root = State.root
	if not enemies or not root then
		return false
	end
	for _, model in enemies:GetChildren() do
		local r = model:FindFirstChild("HumanoidRootPart")
		if r and model:GetAttribute("State") ~= "Dispersed" and (r.Position - root.Position).Magnitude <= radius then
			return true
		end
	end
	return false
end

function ActionController.init(registry)
	Controllers = registry
end

function ActionController.start()
	local Movement = Controllers.MovementController
	local Weapon = Controllers.WeaponController

	bind("Aim", function(state, input)
		if state == End and not isTouch(input) then
			Movement.setAim(false)
			return
		end
		if not canAct() then
			return Pass
		end
		if isTouch(input) then
			if state == Begin then
				Movement.setAim(not State.aiming)
			end
		elseif state == Begin then
			Movement.setAim(true)
		end
	end, Enum.UserInputType.MouseButton2, Enum.KeyCode.ButtonL2)

	bind("Fire", function(state)
		if not canAct() then
			return Pass
		end
		if state == Begin then
			Weapon.fire()
		end
	end, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)

	bind("Reload", function(state)
		if state ~= Begin or not State.character then
			return
		end
		if State.downed then
			act("SecondWind")
		elseif canAct() then
			Weapon.reload()
		end
	end, Enum.KeyCode.R)

	bind("Quiet", function(state, input)
		if state ~= Begin or not canAct() then
			return
		end
		local isPad = input and input.KeyCode == Enum.KeyCode.ButtonX
		local _, equipped = Weapon.current()
		if isPad and equipped and not enemyNearby(6) then
			Weapon.reload() -- contextual: no Hushed in reach, so X reloads
		else
			act("Quiet")
		end
	end, Enum.KeyCode.F, Enum.KeyCode.ButtonX)

	bind("Equip1", function(state)
		if state == Begin and canAct() then
			Weapon.equip("long")
		end
	end, Enum.KeyCode.One)
	bind("Equip2", function(state)
		if state == Begin and canAct() then
			Weapon.equip("sidearm")
		end
	end, Enum.KeyCode.Two)
	bind("Holster", function(state)
		if state == Begin and canAct() then
			act("Equip", "none")
		end
	end, Enum.KeyCode.Three)
	bind("Weapon", function(state)
		if state == Begin and canAct() then
			Weapon.cycleWeapon()
		end
	end, Enum.KeyCode.DPadRight)

	bind("Throw", function(state)
		if state == Begin and canAct() then
			Weapon.throw()
		end
	end, Enum.KeyCode.G, Enum.KeyCode.ButtonR1)
	bind("NextThrowable", function(state)
		if state == Begin and State.character then
			Weapon.cycleThrowable()
		end
	end, Enum.KeyCode.Z, Enum.KeyCode.DPadDown)

	bind("Dodge", function(state)
		if state == Begin and canAct() then
			Movement.dodge()
		end
	end, Enum.KeyCode.Space, Enum.KeyCode.ButtonL1)

	bind("Ability", function(state)
		if state == Begin and canAct() then
			act("Ability")
		end
	end, Enum.KeyCode.Q, Enum.KeyCode.ButtonY)
	bind("Heal", function(state)
		if state == Begin and canAct() then
			act("Heal")
		end
	end, Enum.KeyCode.H, Enum.KeyCode.DPadUp)
	bind("Torch", function(state)
		if state == Begin and State.character and not State.downed then
			act("Torch")
		end
	end, Enum.KeyCode.T, Enum.KeyCode.DPadLeft)

	bind("Crouch", function(state)
		if state == Begin and State.character then
			Movement.toggleCrouch()
		end
	end, Enum.KeyCode.C, Enum.KeyCode.LeftControl, Enum.KeyCode.ButtonB)

	bind("Sprint", function(state, input)
		if not State.character then
			return Pass
		end
		local toggle = isTouch(input) or (input and input.KeyCode == Enum.KeyCode.ButtonL3)
		if toggle then
			if state == Begin then
				Movement.setSprint(not State.sprinting, true)
			end
		elseif state == Begin then
			Movement.setSprint(true, false)
		elseif state == End then
			Movement.setSprint(false, false)
		end
	end, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)

	bind("Shoulder", function(state)
		if state == Begin then
			State.shoulder = -State.shoulder
		end
	end, Enum.KeyCode.X, Enum.KeyCode.ButtonR3)

	bind("Satchel", function(state)
		if state == Begin and State.character then
			Controllers.UIController.toggleSatchel()
		end
	end, Enum.KeyCode.Tab, Enum.KeyCode.ButtonSelect)

	bind("Resupply", function(state)
		if state == Begin and canAct() then
			act("Resupply")
		end
	end, Enum.KeyCode.B)

	bind("AmmoCache", function(state)
		if state == Begin and canAct() then
			act("AmmoCache")
		end
	end, Enum.KeyCode.V)

	bind("Settings", function(state)
		if state == Begin then
			Controllers.UIController.toggleSettings()
		end
	end, Enum.KeyCode.P)
end

function ActionController.sendAction(name, payload)
	act(name, payload)
end

function ActionController.request(kind, a, b)
	Net.event("Request"):FireServer(kind, a, b)
end

return ActionController
