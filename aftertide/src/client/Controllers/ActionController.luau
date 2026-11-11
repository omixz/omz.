--!nonstrict
-- Input bindings (keyboard/mouse, gamepad, touch buttons) -> intents sent to the server.
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
	return State.character ~= nil and not State.uiOpen()
end

local touchLayout = {
	Fire = { title = "Fire", pos = UDim2.new(1, -95, 1, -230) },
	Aim = { title = "Aim", pos = UDim2.new(1, -170, 1, -230) },
	Quiet = { title = "Quiet", pos = UDim2.new(1, -95, 1, -160) },
	Throw = { title = "Throw", pos = UDim2.new(1, -170, 1, -160) },
	Ability = { title = "Skill", pos = UDim2.new(1, -245, 1, -160) },
	Crouch = { title = "Crouch", pos = UDim2.new(1, -95, 1, -300) },
	Sprint = { title = "Sprint", pos = UDim2.new(1, -170, 1, -300) },
	Heal = { title = "Heal", pos = UDim2.new(1, -245, 1, -230) },
	Torch = { title = "Torch", pos = UDim2.new(1, -245, 1, -300) },
	Satchel = { title = "Bag", pos = UDim2.new(1, -320, 1, -300) },
}

local function bind(name, handler, ...)
	local touch = touchLayout[name] ~= nil
	ContextActionService:BindAction(name, function(_, inputState, input)
		local result = handler(inputState, input)
		return result or Sink
	end, touch, ...)
	if touch then
		ContextActionService:SetTitle(name, touchLayout[name].title)
		ContextActionService:SetPosition(name, touchLayout[name].pos)
	end
end

function ActionController.init(registry)
	Controllers = registry
end

function ActionController.start()
	local Movement = Controllers.MovementController
	local Camera = Controllers.CameraController

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
		elseif state == End then
			Movement.setAim(false)
		end
	end, Enum.UserInputType.MouseButton2, Enum.KeyCode.ButtonL2)

	bind("Fire", function(state)
		if not canAct() then
			return Pass
		end
		if state == Begin and not State.downed then
			act("Fire", Camera.aimDirection())
		end
	end, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)

	bind("Quiet", function(state)
		if state == Begin and canAct() and not State.downed then
			act("Quiet")
		end
	end, Enum.KeyCode.F, Enum.KeyCode.ButtonX)

	bind("Throw", function(state)
		if state == Begin and canAct() and not State.downed then
			act("Throw", Camera.aimDirection())
		end
	end, Enum.KeyCode.G, Enum.KeyCode.ButtonR1)

	bind("Ability", function(state)
		if state == Begin and canAct() and not State.downed then
			act("Ability")
		end
	end, Enum.KeyCode.Q, Enum.KeyCode.ButtonY)

	bind("Heal", function(state)
		if state == Begin and canAct() and not State.downed then
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
	end, Enum.KeyCode.Tab, Enum.KeyCode.DPadDown)

	bind("SecondWind", function(state)
		if state == Begin and State.downed then
			act("SecondWind")
		end
	end, Enum.KeyCode.R)

	bind("Resupply", function(state)
		if state == Begin and canAct() and not State.downed then
			act("Resupply")
		end
	end, Enum.KeyCode.B)

	-- keep the workspace referenced for aim raycasts in Studio play-solo
	assert(Workspace)
end

function ActionController.sendAction(name, payload)
	act(name, payload)
end

return ActionController
