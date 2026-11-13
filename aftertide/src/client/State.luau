--!nonstrict
-- Shared client-side state for controllers and UI.
local State = {
	character = nil,
	humanoid = nil,
	root = nil,
	baseHipHeight = 2,

	crouched = false,
	prone = false,
	sprinting = false,
	aiming = false,
	downed = false,
	shoulder = 1, -- 1 = right shoulder, -1 = left

	takedownUntil = 0,
	modals = {},

	throwable = "bottle", -- selected throwable
	bloom = 0, -- extra crosshair spread from recent shots (degrees)
	pitch = 0, -- camera pitch (radians), mirrored for poses
}

function State.setModal(name, open)
	State.modals[name] = open or nil
end

function State.uiOpen()
	return next(State.modals) ~= nil
end

return State
