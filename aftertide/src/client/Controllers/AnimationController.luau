--!nonstrict
-- Locomotion for custom realistic rigs that don't carry Roblox's default "Animate" script:
-- blends idle / walk / run (and crouch variants) by speed using the animation IDs in
-- Config/Rigs.Animations. Characters with an Animate script (the placeholder mannequin,
-- or rigs you gave one) are left alone.
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Rigs = require(Shared.Config.Rigs)
local State = require(script.Parent.Parent.State)

local AnimationController = {}

local tracks = nil

local function load(animator, id)
	if not id or id == "" then
		return nil
	end
	local anim = Instance.new("Animation")
	anim.AnimationId = id
	local ok, track = pcall(function()
		return animator:LoadAnimation(anim)
	end)
	if ok and track then
		track.Looped = true
		track:Play(0.2, 0.001)
		return track
	end
	return nil
end

function AnimationController.onCharacter(char)
	tracks = nil
	if char:FindFirstChild("Animate") or Rigs.Animations.idle == "" then
		return
	end
	local humanoid = char:WaitForChild("Humanoid")
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
	tracks = {}
	for name, id in Rigs.Animations do
		tracks[name] = load(animator, id)
	end
end

local function weight(track, w, dt)
	if track then
		track:AdjustWeight(math.max(0.001, w), math.min(0.2, dt * 4))
	end
end

function AnimationController.start()
	RunService.RenderStepped:Connect(function(dt)
		if not tracks or not State.root then
			return
		end
		local v = State.root.AssemblyLinearVelocity
		local speed = Vector3.new(v.X, 0, v.Z).Magnitude
		local crouch = State.crouched or State.downed
		local moving = math.clamp(speed / 8, 0, 1)
		local running = math.clamp((speed - 12) / 6, 0, 1)
		weight(tracks.idle, crouch and 0 or (1 - moving), dt)
		weight(tracks.walk, crouch and 0 or moving * (1 - running), dt)
		weight(tracks.run, crouch and 0 or running, dt)
		weight(tracks.crouchIdle, crouch and (1 - moving) or 0, dt)
		weight(tracks.crouchWalk, crouch and moving or 0, dt)
		for _, track in tracks do
			if track then
				track:AdjustSpeed(math.clamp(speed / 12, 0.6, 1.6))
			end
		end
	end)
end

return AnimationController
