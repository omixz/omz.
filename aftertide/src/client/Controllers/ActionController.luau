--!nonstrict
-- Input bindings (keyboard/mouse, gamepad, touch buttons) -> intents sent to the server.
--
--   Keyboard/mouse                     Gamepad (Xbox names; PlayStation in brackets)
--   WASD move, Shift sprint            L-stick, L3 sprint (toggle)
--   (Shift / L3 while aiming: hold breath to steady your aim)
--   C / Ctrl crouch (hold: prone)      B [Circle] crouch (hold: prone)
--   RMB aim, LMB fire                  L2 aim, R2 fire (aim assist while aiming)
--   R reload (Second Wind if downed)   R1 reload (Second Wind if downed)
--   F Quieting / grab / melee          X [Square] (reloads when nobody is in reach)
--   Space dodge (dive when sprinting)  L1 dodge
--   G throw, Q ability                 Y [Triangle] tap: throw · hold: ability
--   1 long gun, 2 sidearm, 3 holster   D-pad right tap: next weapon · hold: holster
--   Z next throwable, 4 backpack gun   D-pad down tap: next throwable · hold: backpack gun
--   T torch, V ammo cache              D-pad left tap: torch · hold: ammo cache
--   H heal, B resupply                 D-pad up tap: heal · hold: resupply
--   X swap shoulder, Tab / I satchel   R3 shoulder, View [Share/Touchpad] satchel
--   P settings, F1 controls            in the satchel; A interacts, B closes menus
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

local bindUnsafe
local function noteInput(what)
	State.inputLog = State.inputLog or {}
	table.insert(State.inputLog, ("%s action %s"):format(os.date("%H:%M:%S"), what))
	while #State.inputLog > 12 do
		table.remove(State.inputLog, 1)
	end
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
	local inputs = { ... }
	local ok, err = pcall(function()
		bindUnsafe(name, handler, table.unpack(inputs))
	end)
	if not ok then
		-- one bad binding must never stop the ones after it (satchel, sprint, F1, settings...)
		warn("[ActionController] could not bind " .. name .. ": " .. tostring(err))
	end
end

bindUnsafe = function(name, handler, ...)
	local touch = touchLayout[name] ~= nil
	-- above Roblox's own scripts (default camera input grabs right-click, the player list
	-- grabs Tab), otherwise aiming and the satchel never receive their keys
	ContextActionService:BindActionAtPriority(name, function(_, inputState, input)
		if inputState == Begin then
			noteInput(name .. (input and input.KeyCode ~= Enum.KeyCode.Unknown and (" (" .. input.KeyCode.Name .. ")") or (input and (" (" .. input.UserInputType.Name .. ")") or "")))
		end
		return handler(inputState, input) or Sink
	end, touch, Enum.ContextActionPriority.High.Value + 100, ...)
	if touch then
		ContextActionService:SetTitle(name, touchLayout[name].title)
		ContextActionService:SetPosition(name, touchLayout[name].pos)
	end
end

-- Gamepad buttons with two jobs: tap for one action, hold (0.4 s) for the other.
local function bindPad(name, key, onTap, onHold)
	local pressedAt, press = 0, 0
	bind(name, function(state)
		if state == Begin then
			pressedAt = os.clock()
			press += 1
			local mine = press
			task.delay(0.4, function()
				if mine == press and pressedAt > 0 then
					pressedAt = 0
					onHold()
				end
			end)
		elseif state == End and pressedAt > 0 then
			pressedAt = 0
			onTap()
		end
	end, key)
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
	end, Enum.KeyCode.R, Enum.KeyCode.ButtonR1)

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
	end)

	bind("Throw", function(state)
		if state == Begin and canAct() then
			Weapon.throw()
		end
	end, Enum.KeyCode.G)
	bind("NextThrowable", function(state)
		if state == Begin and State.character then
			Weapon.cycleThrowable()
		end
	end, Enum.KeyCode.Z)

	bind("Dodge", function(state)
		if state == Begin and canAct() then
			Movement.dodge()
		end
	end, Enum.KeyCode.Space, Enum.KeyCode.ButtonL1)

	bind("Ability", function(state)
		if state == Begin and canAct() then
			act("Ability")
		end
	end, Enum.KeyCode.Q)
	bind("Heal", function(state)
		if state == Begin and canAct() then
			act("Heal")
		end
	end, Enum.KeyCode.H)
	bind("Torch", function(state)
		if state == Begin and State.character and not State.downed then
			act("Torch")
		end
	end, Enum.KeyCode.T)

	-- Interact on a controller: Cross / A presses the nearest prompt you can see, whatever else
	-- might be listening to that button (some consoles never delivered it to the prompt).
	local ProximityPromptService = game:GetService("ProximityPromptService")
	local shown = {}
	ProximityPromptService.PromptShown:Connect(function(p)
		shown[p] = true
	end)
	ProximityPromptService.PromptHidden:Connect(function(p)
		shown[p] = nil
	end)
	local holding = nil
	local function nearestPrompt()
		local root = State.root
		if not root then
			return nil
		end
		local best, bestD = nil, math.huge
		for p in shown do
			local part = p.Parent
			local pos = part and (part:IsA("BasePart") and part.Position or (part:IsA("Attachment") and part.WorldPosition))
			if pos and p.Enabled then
				local d = (pos - root.Position).Magnitude
				if d <= p.MaxActivationDistance + 1 and d < bestD then
					best, bestD = p, d
				end
			end
		end
		return best
	end
	bind("PadInteract", function(state)
		if State.uiOpen() then
			return Pass -- menus: A presses the selected button
		end
		if state == Begin then
			local p = nearestPrompt()
			if not p then
				return Pass
			end
			holding = p
			p:InputHoldBegin()
		elseif state == End and holding then
			holding:InputHoldEnd()
			holding = nil
		end
	end, Enum.KeyCode.ButtonA)

	-- gamepad: buttons with a tap and a hold action
	bindPad("PadY", Enum.KeyCode.ButtonY, function()
		if canAct() then
			Weapon.throw()
		end
	end, function()
		if canAct() then
			act("Ability")
		end
	end)
	bindPad("PadRight", Enum.KeyCode.DPadRight, function()
		if canAct() then
			Weapon.cycleWeapon()
		end
	end, function()
		if canAct() then
			act("Equip", "none")
		end
	end)
	bindPad("PadDown", Enum.KeyCode.DPadDown, function()
		if State.character then
			Weapon.cycleThrowable()
		end
	end, function()
		if State.character and not State.downed and not State.uiOpen() then
			act("SwapPack", 1)
		end
	end)
	bindPad("PadLeft", Enum.KeyCode.DPadLeft, function()
		if State.character and not State.downed then
			act("Torch")
		end
	end, function()
		if canAct() then
			act("AmmoCache")
		end
	end)
	bindPad("PadUp", Enum.KeyCode.DPadUp, function()
		if canAct() then
			act("Heal")
		end
	end, function()
		if canAct() then
			act("Resupply")
		end
	end)

	-- tap: crouch / stand (or up from prone);  hold: go prone
	local crouchPressedAt, crouchPress = 0, 0
	bind("Crouch", function(state, input)
		if not State.character or State.uiOpen() then
			return Pass -- B closes menus while one is open
		end
		if isTouch(input) then
			if state == Begin then
				Movement.toggleCrouch()
			end
			return
		end
		if state == Begin then
			crouchPressedAt = os.clock()
			crouchPress += 1
			local press = crouchPress
			task.delay(0.42, function()
				if press == crouchPress and crouchPressedAt > 0 and not State.prone then
					crouchPressedAt = 0
					Movement.setProne(true)
				end
			end)
		elseif state == End and crouchPressedAt > 0 then
			crouchPressedAt = 0
			Movement.toggleCrouch()
		end
	end, Enum.KeyCode.C, Enum.KeyCode.LeftControl, Enum.KeyCode.ButtonB)


	bind("Sprint", function(state, input)
		if not State.character then
			return Pass
		end
		if State.aiming and not isTouch(input) then
			Controllers.CameraController.holdBreath(state == Begin)
			return
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

	bind("Resupply", function(state)
		if state == Begin and canAct() then
			act("Resupply")
		end
	end, Enum.KeyCode.B)

	bind("Backpack", function(state)
		if state == Begin and State.character and not State.downed and not State.uiOpen() then
			act("SwapPack", 1) -- dig the backpack gun out (slow; you can't shoot meanwhile)
		end
	end, Enum.KeyCode.Four)

	bind("AmmoCache", function(state)
		if state == Begin and canAct() then
			act("AmmoCache")
		end
	end, Enum.KeyCode.V)
end

function ActionController.sendAction(name, payload)
	act(name, payload)
end

function ActionController.request(kind, a, b)
	Net.event("Request"):FireServer(kind, a, b)
end

return ActionController
