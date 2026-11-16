--!nonstrict
-- What the Harbour Watch and the Tidebound say: a speech bubble over the speaker (hover above
-- their head, fades out) and a subtitle at the bottom with an arrow showing where it came from.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Theme = require(script.Parent.Theme)

local Callouts = {}
local player = Players.LocalPlayer
local holder
local MAX_LINES = 4

local COLORS = {
	Watch = Color3.fromRGB(255, 206, 110),
	Tidebound = Color3.fromRGB(190, 226, 232),
}

local function arrowFor(position)
	local cam = Workspace.CurrentCamera
	local to = position - cam.CFrame.Position
	local look = Vector3.new(cam.CFrame.LookVector.X, 0, cam.CFrame.LookVector.Z)
	to = Vector3.new(to.X, 0, to.Z)
	if look.Magnitude < 0.01 or to.Magnitude < 0.01 then
		return ""
	end
	local angle = math.deg(math.atan2(look.X * to.Z - look.Z * to.X, look.X * to.X + look.Z * to.Z)) -- + = to the right (screen)
	if math.abs(angle) < 35 then
		return "▲ "
	elseif math.abs(angle) > 145 then
		return "▼ behind · "
	elseif angle > 0 then
		return "▶ "
	end
	return "◀ "
end

function Callouts.build(gui)
	holder = Theme.make("Frame", {
		Name = "Subtitles",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -170),
		Size = UDim2.new(0, 640, 0, 120),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	local layout = Theme.list(Enum.FillDirection.Vertical, 3)
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = holder
end

function Callouts.show(data)
	if type(data) ~= "table" or not holder then
		return
	end
	local model, text, name = data.model, tostring(data.text or ""), tostring(data.name or "")
	local color = COLORS[data.faction] or COLORS.Watch
	local head = model and model.Parent and model:FindFirstChild("Head")
	local pos = head and head.Position or (model and model:FindFirstChild("HumanoidRootPart") and model.HumanoidRootPart.Position)
	local cam = Workspace.CurrentCamera
	local dist = pos and (pos - cam.CFrame.Position).Magnitude or math.huge
	if dist > 85 then
		return
	end

	-- the bubble over their head
	if head then
		local old = head:FindFirstChild("CalloutBubble")
		if old then
			old:Destroy()
		end
		local bb = Instance.new("BillboardGui")
		bb.Name = "CalloutBubble"
		bb.Size = UDim2.fromOffset(190, 44)
		bb.StudsOffsetWorldSpace = Vector3.new(0, 2.4, 0)
		bb.MaxDistance = 85
		bb.AlwaysOnTop = true
		bb.LightInfluence = 0
		bb.Parent = head
		local f = Instance.new("Frame")
		f.Size = UDim2.fromScale(1, 1)
		f.BackgroundColor3 = Color3.fromRGB(14, 18, 22)
		f.BackgroundTransparency = 0.2
		f.Parent = bb
		Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)
		local st = Instance.new("UIStroke")
		st.Color = color
		st.Thickness = 1.5
		st.Parent = f
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.new(1, -10, 1, 0)
		t.Position = UDim2.fromOffset(5, 0)
		t.Font = Enum.Font.GothamMedium
		t.TextSize = 15
		t.TextWrapped = true
		t.TextColor3 = Color3.fromRGB(240, 240, 232)
		t.Text = text
		t.Parent = f
		task.delay(2.8, function()
			if bb.Parent then
				bb:Destroy()
			end
		end)
	end

	-- the subtitle
	local lines = {}
	for _, c in holder:GetChildren() do
		if c:IsA("TextLabel") then
			table.insert(lines, c)
		end
	end
	table.sort(lines, function(x, y)
		return x.LayoutOrder < y.LayoutOrder
	end)
	while #lines >= MAX_LINES do
		table.remove(lines, 1):Destroy()
	end
	local line = Theme.label({
		Text = ("%s%s: %s"):format(pos and arrowFor(pos) or "", string.upper(name), text),
		Font = Enum.Font.GothamMedium,
		TextSize = 18,
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 24),
		LayoutOrder = math.floor(os.clock() * 100),
		Parent = holder,
	})
	line.TextStrokeTransparency = 0.4
	task.delay(3.4, function()
		if line.Parent then
			line:Destroy()
		end
	end)
end

return Callouts
