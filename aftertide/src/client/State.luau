--!nonstrict
-- Shared client-side state for controllers and UI.
local State = {
	character = nil,
	humanoid = nil,
	root = nil,
	baseHipHeight = 2,

	crouched = false,
	sprinting = false,
	aiming = false,
	downed = false,
	shoulder = 1, -- 1 = right shoulder, -1 = left

	takedownUntil = 0,
	modals = {},
}

function State.setModal(name, open)
	State.modals[name] = open or nil
end

function State.uiOpen()
	return next(State.modals) ~= nil
end

return State
