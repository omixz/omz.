--!nonstrict
-- Button names for the player's controller: PlayStation symbols on PlayStation, Xbox letters
-- otherwise. Used by the guide, the controls card and hints.
local UserInputService = game:GetService("UserInputService")

local Buttons = {}

local PS = { ButtonA = "✕", ButtonB = "○", ButtonX = "□", ButtonY = "△", ButtonSelect = "Touchpad", ButtonL1 = "L1", ButtonR1 = "R1", ButtonL2 = "L2", ButtonR2 = "R2", ButtonL3 = "L3", ButtonR3 = "R3" }
local XBOX = { ButtonA = "A", ButtonB = "B", ButtonX = "X", ButtonY = "Y", ButtonSelect = "View", ButtonL1 = "LB", ButtonR1 = "RB", ButtonL2 = "LT", ButtonR2 = "RT", ButtonL3 = "LS", ButtonR3 = "RS" }

function Buttons.isPlayStation()
	local ok, s = pcall(function()
		return UserInputService:GetStringForKeyCode(Enum.KeyCode.ButtonA)
	end)
	return ok and type(s) == "string" and s:find("Cross") ~= nil
end

function Buttons.name(keyName)
	local map = Buttons.isPlayStation() and PS or XBOX
	return map[keyName] or keyName
end

return Buttons
