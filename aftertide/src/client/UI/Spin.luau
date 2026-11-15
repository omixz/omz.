--!nonstrict
-- The Lucky Spin screen: a prize reel that rolls to the prize the server picked.
-- One free spin a day (00:00 UTC reset); extra spins are Spin tokens (won, or R$10 each).
-- Every prize's odds are listed on this screen before you spin or buy (paid random items
-- policy); spins aren't sold where paid random items are restricted.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local SpinConfig = require(Shared.Config.Spin)
local Commerce = require(Shared.Config.Commerce)
local Sfx = require(Shared.Util.Sfx)
local Theme = require(script.Parent.Theme)
local State = require(script.Parent.Parent.State)

local Spin = {}
local C = Theme.Colors
local player = Players.LocalPlayer
local backdrop, reel, strip, spinButton, buyOne, buyFive, status, wonLabel
local request, promptProduct
local spinning, rolling = false, false

local TILE, GAP = 118, 8
local TOTAL = 0
for _, p in SpinConfig.Prizes do
	TOTAL += p.weight
end

local function rgb(t)
	return Color3.fromRGB(t[1], t[2], t[3])
end

local function weightedIndex(rng)
	local roll = rng:NextInteger(1, TOTAL)
	for i, p in SpinConfig.Prizes do
		roll -= p.weight
		if roll <= 0 then
			return i
		end
	end
	return 1
end

local function tile(parent, prize, x)
	local t = Theme.make("Frame", {
		Position = UDim2.new(0, x, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		Size = UDim2.new(0, TILE, 0, 110),
		BackgroundColor3 = rgb(prize.color):Lerp(Color3.fromRGB(20, 22, 26), 0.55),
		BorderSizePixel = 0,
		Parent = parent,
	})
	Theme.corner(8).Parent = t
	Theme.stroke(rgb(prize.color), 2, 0.1).Parent = t
	Theme.make("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0.35) }),
		Parent = t,
	})
	Theme.label({ Text = prize.short, Font = Theme.Head, TextSize = 30, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = rgb(prize.color), Position = UDim2.new(0, 0, 0, 14), Size = UDim2.new(1, 0, 0, 40), Parent = t })
	Theme.label({ Text = prize.name, TextWrapped = true, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.new(0, 6, 0, 58), Size = UDim2.new(1, -12, 0, 44), Parent = t })
	return t
end

local function fillStrip(winIndex, winSlot)
	Theme.clear(strip)
	local rng = Random.new()
	for slot = 1, winSlot + 4 do
		local index = slot == winSlot and winIndex or weightedIndex(rng)
		tile(strip, SpinConfig.Prizes[index], (slot - 1) * (TILE + GAP))
	end
end

local function fmtTime(seconds)
	seconds = math.max(0, math.floor(seconds))
	return ("%02d:%02d:%02d"):format(seconds // 3600, (seconds % 3600) // 60, seconds % 60)
end

local function restricted()
	return player:GetAttribute("PaidSpinRestricted") ~= false
end

function Spin.refresh()
	if not (backdrop and backdrop.Visible) then
		return
	end
	local free = player:GetAttribute("FreeSpinReady") == true
	local tokens = player:GetAttribute("Tokens_spin") or 0
	local wait = (player:GetAttribute("NextFreeSpinAt") or 0) - Workspace:GetServerTimeNow()
	if spinning then
		spinButton.Text = "SPINNING…"
	elseif free then
		spinButton.Text = "SPIN  ·  FREE TODAY"
	elseif tokens > 0 then
		spinButton.Text = ("SPIN  ·  %d SPIN%s LEFT"):format(tokens, tokens == 1 and "" or "S")
	elseif restricted() then
		spinButton.Text = "NEXT FREE SPIN " .. fmtTime(wait)
	else
		spinButton.Text = ("SPIN  ·  R$%d"):format(Commerce.Products.LuckySpin.price)
	end
	spinButton.AutoButtonColor = not spinning
	status.Text = free and "Your free spin for today is ready." or ("Next free spin in %s (resets 00:00 UTC)."):format(fmtTime(wait))
	buyOne.Visible = not restricted()
	buyFive.Visible = not restricted()
end

local function doSpin()
	if spinning then
		return
	end
	local free = player:GetAttribute("FreeSpinReady") == true
	local tokens = player:GetAttribute("Tokens_spin") or 0
	if not free and tokens <= 0 then
		if not restricted() then
			promptProduct("LuckySpin")
		end
		return
	end
	spinning = true
	wonLabel.Text = ""
	Sfx.ui("Ui_Confirm", 0.5)
	request("Spin")
	task.delay(6, function()
		if spinning and not rolling then
			spinning = false -- no answer from the server
		end
	end)
end

-- The server's pick arrives: roll the reel onto it.
function Spin.result(data)
	if not backdrop then
		return
	end
	local index = tonumber(data and data.index) or 1
	local prize = SpinConfig.Prizes[index] or SpinConfig.Prizes[1]
	if not backdrop.Visible then
		Spin.open()
	end
	spinning, rolling = true, true
	local winSlot = 34
	fillStrip(index, winSlot)
	strip.Position = UDim2.new(0, 0, 0, 0)
	local center = reel.AbsoluteSize.X / 2
	local jitter = Random.new():NextNumber(-TILE * 0.32, TILE * 0.32)
	local target = -((winSlot - 1) * (TILE + GAP) + TILE / 2 - center + jitter)
	local duration = 4.2
	local tween = TweenService:Create(strip, TweenInfo.new(duration, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Position = UDim2.new(0, target, 0, 0) })
	tween:Play()
	-- a tick each time a tile passes the marker
	task.spawn(function()
		local last = 0
		while tween.PlaybackState == Enum.PlaybackState.Playing do
			local passed = math.floor((-strip.Position.X.Offset + center) / (TILE + GAP))
			if passed ~= last then
				last = passed
				Sfx.ui("Ui_Tick", 0.35)
			end
			task.wait()
		end
	end)
	tween.Completed:Wait()
	Sfx.ui("Ui_Confirm", 0.9)
	wonLabel.TextColor3 = rgb(prize.color)
	wonLabel.Text = "YOU WON:  " .. string.upper(prize.name)
	spinning, rolling = false, false
end

function Spin.build(gui, requestFn, promptFn)
	request, promptProduct = requestFn, promptFn
	local panel
	backdrop, panel = Theme.modal(gui, "Spin", UDim2.new(0.94, 0, 0.88, 0), Vector2.new(820, 600))
	Theme.heading({ Text = "LUCKY SPIN", TextSize = 28, Size = UDim2.new(1, -120, 0, 34), Parent = panel })
	Theme.label({ Position = UDim2.new(0, 0, 0, 34), Text = "One free spin every day. Prizes go straight to you (kits are packed for your next crossing).", TextSize = 12, TextColor3 = C.dim, Size = UDim2.new(1, -120, 0, 18), Parent = panel })
	local close = Theme.button({ Text = "CLOSE", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0, 100, 0, 32), Parent = panel })
	close.Activated:Connect(Spin.close)

	reel = Theme.make("Frame", { Position = UDim2.new(0, 0, 0, 62), Size = UDim2.new(1, 0, 0, 132), BackgroundColor3 = Color3.fromRGB(10, 12, 14), BorderSizePixel = 0, ClipsDescendants = true, Parent = panel })
	Theme.corner(8).Parent = reel
	strip = Theme.make("Frame", { Size = UDim2.new(0, 10, 1, 0), BackgroundTransparency = 1, Parent = reel })
	-- the marker
	Theme.make("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.new(0, 4, 1, 0), BackgroundColor3 = C.lantern, BorderSizePixel = 0, ZIndex = 30, Parent = reel })
	for _, side in { 0, 1 } do
		Theme.make("Frame", {
			AnchorPoint = Vector2.new(side, 0),
			Position = UDim2.new(side, 0, 0, 0),
			Size = UDim2.new(0.18, 0, 1, 0),
			BackgroundColor3 = Color3.fromRGB(10, 12, 14),
			BorderSizePixel = 0,
			ZIndex = 25,
			Parent = reel,
		}):SetAttribute("Fade", side)
	end
	for _, f in reel:GetChildren() do
		if f:GetAttribute("Fade") ~= nil then
			Theme.make("UIGradient", {
				Transparency = f:GetAttribute("Fade") == 0 and NumberSequence.new(0, 1) or NumberSequence.new(1, 0),
				Parent = f,
			})
		end
	end
	fillStrip(#SpinConfig.Prizes, 4)

	wonLabel = Theme.heading({ Text = "", TextSize = 22, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.new(0, 0, 0, 200), Size = UDim2.new(1, 0, 0, 30), Parent = panel })

	-- left: buttons
	local left = Theme.make("Frame", { Position = UDim2.new(0, 0, 0, 240), Size = UDim2.new(0.48, 0, 1, -240), BackgroundTransparency = 1, Parent = panel })
	spinButton = Theme.button({ Text = "SPIN", TextSize = 22, Size = UDim2.new(1, 0, 0, 56), BackgroundColor3 = Color3.fromRGB(150, 96, 40), Parent = left })
	spinButton.Activated:Connect(doSpin)
	status = Theme.label({ Text = "", TextSize = 12, TextColor3 = C.dim, TextWrapped = true, Position = UDim2.new(0, 0, 0, 62), Size = UDim2.new(1, 0, 0, 32), Parent = left })
	buyOne = Theme.button({ Text = ("BUY 1 SPIN  ·  R$%d"):format(Commerce.Products.LuckySpin.price), Position = UDim2.new(0, 0, 0, 100), Size = UDim2.new(1, 0, 0, 36), Parent = left })
	buyOne.Activated:Connect(function()
		promptProduct("LuckySpin")
	end)
	buyFive = Theme.button({ Text = ("BUY 5 SPINS  ·  R$%d"):format(Commerce.Products.LuckySpin5.price), Position = UDim2.new(0, 0, 0, 142), Size = UDim2.new(1, 0, 0, 36), Parent = left })
	buyFive.Activated:Connect(function()
		promptProduct("LuckySpin5")
	end)

	-- right: the odds, always visible
	local right = Theme.panel({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 240), Size = UDim2.new(0.5, 0, 1, -240), BackgroundColor3 = C.panelHi, Parent = panel })
	Theme.padding(10).Parent = right
	Theme.heading({ Text = "ODDS PER SPIN", TextSize = 15, TextColor3 = C.salt, Size = UDim2.new(1, 0, 0, 20), Parent = right })
	local list = Theme.make("ScrollingFrame", { Position = UDim2.new(0, 0, 0, 24), Size = UDim2.new(1, 0, 1, -24), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = right })
	Theme.list(Enum.FillDirection.Vertical, 2).Parent = list
	for i, p in SpinConfig.Prizes do
		local row = Theme.make("Frame", { LayoutOrder = i, Size = UDim2.new(1, -6, 0, 18), BackgroundTransparency = 1, Parent = list })
		Theme.make("Frame", { Size = UDim2.new(0, 10, 0, 10), Position = UDim2.new(0, 0, 0.5, -5), BackgroundColor3 = rgb(p.color), BorderSizePixel = 0, Parent = row })
		Theme.label({ Text = p.name, TextSize = 12, Position = UDim2.new(0, 16, 0, 0), Size = UDim2.new(1, -76, 1, 0), Parent = row })
		Theme.label({ Text = ("%.1f%%"):format(p.weight / TOTAL * 100), TextSize = 12, Font = Theme.Head, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0, 60, 1, 0), Parent = row })
	end
end

function Spin.open()
	if backdrop then
		backdrop.Visible = true
		State.setModal("spin", true)
		Spin.refresh()
		Theme.focus(spinButton)
	end
end

function Spin.close()
	if backdrop and not spinning then
		backdrop.Visible = false
		State.setModal("spin", false)
	end
end

function Spin.toggle()
	if backdrop and backdrop.Visible then
		Spin.close()
	else
		Spin.open()
	end
end

return Spin
