--!nonstrict
local CollectionService = game:GetService("CollectionService")

local Geometry = {}

function Geometry.pointInPart(point, part)
	local rel = part.CFrame:PointToObjectSpace(point)
	local half = part.Size * 0.5
	return math.abs(rel.X) <= half.X and math.abs(rel.Y) <= half.Y and math.abs(rel.Z) <= half.Z
end

-- True if `point` lies inside any part tagged `tag` (volumes such as TallGrass, LitZone, Shallows).
function Geometry.inTagged(point, tag)
	for _, part in CollectionService:GetTagged(tag) do
		if part:IsA("BasePart") and Geometry.pointInPart(point, part) then
			return true
		end
	end
	return false
end

function Geometry.flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

function Geometry.flatDistance(a, b)
	local dx, dz = a.X - b.X, a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

-- Rejects NaN, infinities and absurd values sent by clients.
function Geometry.isSaneVector(v, maxMagnitude)
	if typeof(v) ~= "Vector3" then
		return false
	end
	if v.X ~= v.X or v.Y ~= v.Y or v.Z ~= v.Z then
		return false
	end
	return v.Magnitude <= (maxMagnitude or 1e5)
end

return Geometry
