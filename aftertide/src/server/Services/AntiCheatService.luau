--!nonstrict
-- Lightweight movement sanity checks. Roblox lets clients simulate their own character, so
-- speed hacks are possible; we detect impossible displacement and pull the player back.
-- PvE-only design keeps the stakes low (docs/02-technical-architecture.md section 2.4).
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Movement = require(Shared.Config.Movement)

local AntiCheatService = {}
local Services

local INTERVAL = 0.5
local track = {} -- [Player] = { pos, t, strikes, lastGood }

function AntiCheatService.init(registry)
	Services = registry
end

function AntiCheatService.start()
	Players.PlayerRemoving:Connect(function(player)
		track[player] = nil
	end)
	while true do
		task.wait(INTERVAL)
		local now = os.clock()
		for _, player in Players:GetPlayers() do
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			local session = Services.CharacterService.getSession(player)
			if root and session then
				local t = track[player]
				if not t or t.char ~= char or now < session.graceUntil then
					track[player] = { char = char, pos = root.Position, t = now, strikes = 0, lastGood = root.CFrame }
				else
					local dt = now - t.t
					local moved = Vector3.new(root.Position.X - t.pos.X, 0, root.Position.Z - t.pos.Z).Magnitude
					local allowed = (Movement.Speeds.Sprint * session.mods.sprintSpeedMult * 1.5 + 6) * dt
					if moved > allowed then
						t.strikes += 1
						if t.strikes >= 2 then
							warn(("[AntiCheat] %s moved %.1f studs in %.2fs; resetting"):format(player.Name, moved, dt))
							char:PivotTo(t.lastGood)
							t.strikes = 0
						end
					else
						t.strikes = math.max(0, t.strikes - 1)
						t.lastGood = root.CFrame
					end
					t.pos = root.Position
					t.t = now
				end
			end
		end
	end
end

return AntiCheatService
