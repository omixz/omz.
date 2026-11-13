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
				-- safety net: fell through the world or got pushed outside the walls (physics can
				-- squeeze a character through thin geometry): put them back where they last stood
				local t0 = track[player]
				local p = root.Position
				local onMap = math.abs(p.X) < 130 and math.abs(p.Z) < 130
				local onFerry = math.abs(p.X) < 90 and math.abs(p.Z - 700) < 90
				local lost = p.Y < -30 or not (onMap or onFerry)
				if lost and t0 and t0.lastSafe then
					char:PivotTo(t0.lastSafe)
					root.AssemblyLinearVelocity = Vector3.zero
					Services.CharacterService.setGrace(player, 1)
					t0.pos, t0.t = t0.lastSafe.Position, now
				end
				local humanoid = char:FindFirstChildOfClass("Humanoid")
				if t0 and not lost and humanoid and humanoid.FloorMaterial ~= Enum.Material.Air then
					t0.lastSafe = root.CFrame + Vector3.new(0, 0.5, 0)
				end
				local t = track[player]
				if not t or t.char ~= char or now < session.graceUntil then
					track[player] = { char = char, pos = root.Position, t = now, strikes = 0, lastGood = root.CFrame, lastSafe = t and t.char == char and t.lastSafe or root.CFrame }
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
