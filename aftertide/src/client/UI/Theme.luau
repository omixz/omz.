--!nonstrict
-- Visual language for all UI: slate panels, bone text, lantern-warm accents. No default
-- Roblox look: custom panels, Oswald (stencil-like headings) + Merriweather (logbook body).
local Theme = {}

Theme.Colors = {
	backdrop = Color3.fromRGB(6, 8, 10),
	panel = Color3.fromRGB(18, 22, 25),
	panelHi = Color3.fromRGB(30, 35, 38),
	line = Color3.fromRGB(70, 76, 78),
	text = Color3.fromRGB(226, 220, 206),
	dim = Color3.fromRGB(150, 148, 138),
	lantern = Color3.fromRGB(232, 168, 92),
	danger = Color3.fromRGB(200, 74, 60),
	salt = Color3.fromRGB(170, 205, 205),
	ok = Color3.fromRGB(140, 180, 130),
}

Theme.Head = Enum.Font.Oswald
Theme.Body = Enum.Font.Merriweather

local function apply(inst, defaults, props)
	for key, value in defaults do
		if props == nil or props[key] == nil then
			inst[key] = value
		end
	end
	local parent
	for key, value in props or {} do
		if key == "Parent" then
			parent = value
		elseif key ~= "Children" then
			inst[key] = value
		end
	end
	for _, child in (props and props.Children) or {} do
		child.Parent = inst
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

function Theme.make(className, props)
	return apply(Instance.new(className), {}, props)
end

function Theme.corner(radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 4)
	return c
end

function Theme.stroke(color, thickness, transparency)
	local s = Instance.new("UIStroke")
	s.Color = color or Theme.Colors.line
	s.Thickness = thickness or 1
	s.Transparency = transparency or 0.2
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	return s
end

function Theme.padding(px)
	local p = Instance.new("UIPadding")
	p.PaddingLeft = UDim.new(0, px)
	p.PaddingRight = UDim.new(0, px)
	p.PaddingTop = UDim.new(0, px)
	p.PaddingBottom = UDim.new(0, px)
	return p
end

function Theme.list(direction, gap, align)
	local l = Instance.new("UIListLayout")
	l.FillDirection = direction or Enum.FillDirection.Vertical
	l.Padding = UDim.new(0, gap or 6)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	if align then
		l.HorizontalAlignment = align
	end
	return l
end

function Theme.label(props)
	return apply(Instance.new("TextLabel"), {
		BackgroundTransparency = 1,
		TextColor3 = Theme.Colors.text,
		Font = Theme.Body,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		Size = UDim2.new(1, 0, 0, 20),
	}, props)
end

function Theme.heading(props)
	return apply(Instance.new("TextLabel"), {
		BackgroundTransparency = 1,
		TextColor3 = Theme.Colors.text,
		Font = Theme.Head,
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 28),
	}, props)
end

function Theme.panel(props)
	local frame = apply(Instance.new("Frame"), {
		BackgroundColor3 = Theme.Colors.panel,
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
	}, props)
	Theme.corner(6).Parent = frame
	Theme.stroke().Parent = frame
	return frame
end

function Theme.button(props)
	local button = apply(Instance.new("TextButton"), {
		BackgroundColor3 = Theme.Colors.panelHi,
		BorderSizePixel = 0,
		AutoButtonColor = true,
		TextColor3 = Theme.Colors.text,
		Font = Theme.Head,
		TextSize = 17,
		Size = UDim2.new(0, 160, 0, 36),
	}, props)
	Theme.corner(4).Parent = button
	Theme.stroke(Theme.Colors.lantern, 1, 0.5).Parent = button
	return button
end

-- A full-screen dark backdrop + centred panel for modal screens.
function Theme.modal(parent, name, size, maxSize)
	local backdrop = Theme.make("Frame", {
		Name = name,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Colors.backdrop,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 20,
		Parent = parent,
	})
	local panel = Theme.panel({
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = size,
		ZIndex = 21,
		Parent = backdrop,
	})
	local constraint = Instance.new("UISizeConstraint")
	constraint.MaxSize = maxSize or Vector2.new(1100, 680)
	constraint.Parent = panel
	Theme.padding(18).Parent = panel
	return backdrop, panel
end

return Theme
