--!nonstrict
-- Every client<->server message goes through these RemoteEvents. The server creates them;
-- clients wait for them. Server handlers are rate-limited and wrapped in pcall so a bad
-- payload can never crash a service. Validate EVERY argument in the handler.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}

local EVENTS = {
	"SelectCharacter", -- client -> server (charId, perkId)
	"SetMoveState", -- client -> server (stance, sprinting, aiming)
	"Action", -- client -> server (actionName, payload)
	"ReturnToFerry", -- client -> server ()
	"Request", -- client -> server (kind, a, b): ferry menus (chart, workbench, repairs, settings)
	"Look", -- client -> server (pitch): aim pitch for other players' upper-body pose
	"Notify", -- server -> client (kind, data)
}

local folder
if RunService:IsServer() then
	folder = ReplicatedStorage:FindFirstChild("Net")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Net"
	end
	for _, name in EVENTS do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end
	folder.Parent = ReplicatedStorage
else
	folder = ReplicatedStorage:WaitForChild("Net")
end

function Net.event(name)
	return folder:WaitForChild(name)
end

local buckets = {}

-- Server only. `rate` = max messages per second per player (token bucket).
function Net.onServer(name, rate, handler)
	local remote = Net.event(name)
	remote.OnServerEvent:Connect(function(player, ...)
		local key = player.UserId
		local perPlayer = buckets[key]
		if not perPlayer then
			perPlayer = {}
			buckets[key] = perPlayer
		end
		local now = os.clock()
		local bucket = perPlayer[name]
		if not bucket then
			bucket = { tokens = rate, t = now }
			perPlayer[name] = bucket
		end
		bucket.tokens = math.min(rate, bucket.tokens + (now - bucket.t) * rate)
		bucket.t = now
		if bucket.tokens < 1 then
			return -- dropped: flooding
		end
		bucket.tokens -= 1
		local ok, err = pcall(handler, player, ...)
		if not ok then
			warn(("[Net] %s handler error for %s: %s"):format(name, player.Name, tostring(err)))
		end
	end)
end

function Net.notify(player, kind, data)
	Net.event("Notify"):FireClient(player, kind, data)
end

function Net.notifyAll(kind, data)
	Net.event("Notify"):FireAllClients(kind, data)
end

if RunService:IsServer() then
	Players.PlayerRemoving:Connect(function(player)
		buckets[player.UserId] = nil
	end)
end

return Net
