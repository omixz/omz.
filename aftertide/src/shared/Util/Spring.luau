--!nonstrict
-- Critically damped spring. Works for numbers and Vector3s.
-- frequency = how quickly it settles (higher = snappier).
local Spring = {}
Spring.__index = Spring

function Spring.new(initial, frequency)
	return setmetatable({
		position = initial,
		velocity = initial * 0,
		target = initial,
		frequency = frequency or 8,
	}, Spring)
end

function Spring:reset(value)
	self.position = value
	self.velocity = value * 0
	self.target = value
end

function Spring:update(dt)
	local w = self.frequency * 2 * math.pi
	local disp = self.position - self.target
	local decay = math.exp(-w * dt)
	local k = self.velocity + disp * w
	self.position = self.target + (disp + k * dt) * decay
	self.velocity = (self.velocity - k * w * dt) * decay
	return self.position
end

return Spring
