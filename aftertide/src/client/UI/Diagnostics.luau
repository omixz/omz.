--!nonstrict
-- F2 diagnostics: what the game is actually doing on your machine, so problems can be fixed
-- from facts instead of guesses. Shows client + server warnings/errors, the animator's
-- state, the last keys / actions received, open menus, and the asset-fitting report.
-- Everything is in a text box you can select and copy (Ctrl+A, Ctrl+C) to paste in a report.
local LogService = game:GetService("LogService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Theme = require(script.Parent.Theme)
local State = require(script.Parent.Parent.State)

local Diagnostics = {}
local C = Theme.Colors
local player = Players.LocalPlayer
local panel, box, badge
local lines = {} -- recent log lines
local errorCount = 0
local statusFn = nil

local function push(prefix, text)
	table.insert(lines, ("[%s %s] %s"):format(os.date("%H:%M:%S"), prefix, text))
	while #lines > 60 do
		table.remove(lines, 1)
	end
end

function Diagnostics.serverLine(kind, text)
	push("server " .. tostring(kind), tostring(text))
	if kind == "error" or kind == "warning" then
		errorCount += 1
	end
end

-- Notes the last few actions / keys the game received (ActionController / UIController).
function Diagnostics.noteInput(what)
	State.inputLog = State.inputLog or {}
	table.insert(State.inputLog, ("%s %s"):format(os.date("%H:%M:%S"), what))
	while #State.inputLog > 12 do
		table.remove(State.inputLog, 1)
	end
end

function Diagnostics.setStatusProvider(fn)
	statusFn = fn
end

function Diagnostics.build(gui)
	panel = Theme.panel({ Name = "Diagnostics", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 70), Size = UDim2.new(0, 560, 0.8, 0), BackgroundTransparency = 0.08, Visible = false, ZIndex = 50, Parent = gui })
	Theme.padding(10).Parent = panel
	Theme.heading({ Text = "DIAGNOSTICS  (F2)  ·  select all + copy, then paste it in your report", TextSize = 13, Size = UDim2.new(1, 0, 0, 16), ZIndex = 50, Parent = panel })
	local scroll = Instance.new("ScrollingFrame")
	scroll.Position = UDim2.new(0, 0, 0, 22)
	scroll.Size = UDim2.new(1, 0, 1, -22)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.ScrollBarThickness = 4
	scroll.ZIndex = 50
	scroll.Parent = panel
	box = Instance.new("TextBox")
	box.Size = UDim2.new(1, -6, 0, 0)
	box.AutomaticSize = Enum.AutomaticSize.Y
	box.BackgroundTransparency = 1
	box.TextColor3 = C.text
	box.Font = Enum.Font.Code
	box.TextSize = 12
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.TextYAlignment = Enum.TextYAlignment.Top
	box.TextWrapped = true
	box.ClearTextOnFocus = false
	box.TextEditable = false
	box.MultiLine = true
	box.ZIndex = 50
	box.Parent = scroll
	badge = Theme.label({ Text = "", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 50), Size = UDim2.new(0, 260, 0, 16), TextXAlignment = Enum.TextXAlignment.Right, Font = Theme.Head, TextSize = 12, TextColor3 = C.danger, ZIndex = 50, Parent = gui })

	LogService.MessageOut:Connect(function(message, messageType)
		if messageType == Enum.MessageType.MessageError then
			errorCount += 1
			push("client error", message)
		elseif messageType == Enum.MessageType.MessageWarning then
			errorCount += 1
			push("client warning", message)
		elseif message:sub(1, 1) == "[" then
			push("client", message)
		end
	end)

	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		badge.Text = errorCount > 0 and ("F2 · %d warning%s / error%s"):format(errorCount, errorCount == 1 and "" or "s", errorCount == 1 and "" or "s") or ""
		if not panel.Visible then
			return
		end
		acc += dt
		if acc < 0.25 then
			return
		end
		acc = 0
		local out = {}
		local status = statusFn and statusFn() or {}
		table.insert(out, "== STATUS ==")
		for _, line in status do
			table.insert(out, line)
		end
		table.insert(out, "")
		table.insert(out, "== LAST INPUT ==")
		for _, line in State.inputLog or {} do
			table.insert(out, line)
		end
		table.insert(out, "")
		table.insert(out, "== LOG (newest last) ==")
		for _, line in lines do
			table.insert(out, line)
		end
		box.Text = table.concat(out, "\n")
	end)
end

function Diagnostics.toggle()
	if panel then
		panel.Visible = not panel.Visible
	end
end

return Diagnostics
