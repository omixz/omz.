--!nonstrict
-- The Quartermaster (Meridian store, Scrip): unlock guns, set your holster / backpack loadout,
-- and buy kits for your next crossing. Everyone starts with only the Service Revolver.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Quartermaster = require(Shared.Config.Quartermaster)
local Weapons = require(Shared.Config.Weapons)
local Theme = require(script.Parent.Theme)
local State = require(script.Parent.Parent.State)

local QM = {}
local C = Theme.Colors
local player = Players.LocalPlayer
local backdrop, list, header
local request

local function decode(attr, default)
	local ok, v = pcall(function()
		return HttpService:JSONDecode(player:GetAttribute(attr) or "")
	end)
	return ok and v or default
end

local function hasArmory()
	local repairs = decode("Repairs", {})
	return repairs.armory == true
end

local function price(p)
	return math.floor(p * (hasArmory() and 0.85 or 1) + 0.5)
end

local function section(order, text)
	Theme.heading({ LayoutOrder = order, Text = text, TextSize = 16, TextColor3 = C.salt, Size = UDim2.new(1, -8, 0, 22), Parent = list })
end

local function row(order, title, desc)
	local r = Theme.panel({ LayoutOrder = order, Size = UDim2.new(1, -8, 0, 58), BackgroundColor3 = C.panelHi, Parent = list })
	Theme.padding(8).Parent = r
	Theme.heading({ Text = string.upper(title), TextSize = 14, Size = UDim2.new(1, -280, 0, 18), Parent = r })
	Theme.label({ Text = desc, Position = UDim2.new(0, 0, 0, 20), Size = UDim2.new(1, -280, 0, 28), TextSize = 11, TextWrapped = true, Parent = r })
	local holder = Theme.make("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, 272, 0, 32), BackgroundTransparency = 1, Parent = r })
	local l = Theme.list(Enum.FillDirection.Horizontal, 6)
	l.HorizontalAlignment = Enum.HorizontalAlignment.Right
	l.Parent = holder
	return holder
end

local function button(parent, text, enabled, accent, onClick)
	local b = Theme.button({ Text = text, Size = UDim2.new(0, 130, 1, 0), TextSize = 12, AutoButtonColor = enabled, Parent = parent })
	if not enabled then
		b.TextTransparency = 0.5
	elseif accent then
		b.BackgroundColor3 = C.lantern
		b.TextColor3 = C.panel
	end
	if enabled then
		b.Activated:Connect(onClick)
	end
	return b
end

local function rebuild()
	Theme.clear(list)
	local scrip = player:GetAttribute("Scrip") or 0
	header.Text = ("SCRIP %d%s   ·   everyone starts a crossing with only the Service Revolver"):format(scrip, hasArmory() and "   ·   ARMORY: 15% OFF" or "")
	local guns = decode("Guns", { revolver = true })
	local loadout = decode("Loadout", { long = "", pack = {} })
	loadout.pack = loadout.pack or {}
	local slots = Quartermaster.BackpackSlots + (hasArmory() and 1 or 0)
	local order = 0

	section(1, "GUNS")
	order = 1
	for _, g in Quartermaster.Guns do
		order += 1
		local holder = row(order, Weapons.List[g.id].name, g.desc)
		if guns[g.id] then
			local inHolster = loadout.long == g.id
			local inPack = table.find(loadout.pack, g.id) ~= nil
			button(holder, inHolster and "HOLSTERED" or "HOLSTER", not inHolster, false, function()
				local pack = {}
				for _, id in loadout.pack do
					if id ~= g.id then
						table.insert(pack, id)
					end
				end
				if loadout.long ~= "" and loadout.long ~= g.id then
					table.insert(pack, 1, loadout.long)
				end
				request("SetLoadout", g.id, pack)
			end)
			button(holder, inPack and "IN BACKPACK ✓" or "BACKPACK", not inHolster and (inPack or #loadout.pack < slots), false, function()
				local pack = table.clone(loadout.pack)
				local at = table.find(pack, g.id)
				if at then
					table.remove(pack, at)
				else
					table.insert(pack, g.id)
				end
				request("SetLoadout", loadout.long, pack)
			end)
		else
			local cost = price(g.price)
			button(holder, ("UNLOCK  %d SCRIP"):format(cost), scrip >= cost, true, function()
				request("UnlockGun", g.id)
			end)
		end
	end
	order += 1
	Theme.label({ LayoutOrder = order, Text = ("Holster: one long gun, quick to draw (1). Backpack: %d more gun%s, but digging one out (4) takes a few seconds and you can't shoot meanwhile."):format(slots, slots == 1 and "" or "s"), TextSize = 12, TextWrapped = true, TextColor3 = C.dim, Size = UDim2.new(1, -8, 0, 32), Parent = list })

	order += 1
	section(order, "KITS FOR YOUR NEXT CROSSING")
	local kit = decode("Kit", {})
	for _, k in Quartermaster.Kits do
		if k.robux then
			continue -- Ammo Crates are in the Purser's Office (Robux)
		end
		order += 1
		local have = kit[k.id] or 0
		local holder = row(order, k.name .. (have > 0 and ("  ·  PACKED x" .. have) or ""), k.desc)
		local cost = price(k.price)
		button(holder, ("BUY  %d SCRIP"):format(cost), scrip >= cost and have < Quartermaster.MaxKitsEach, true, function()
			request("BuyKit", k.id)
		end)
	end
end

function QM.build(gui, requestFn)
	request = requestFn
	local panel
	backdrop, panel = Theme.modal(gui, "Quartermaster", UDim2.new(0.94, 0, 0.9, 0), Vector2.new(760, 640))
	Theme.heading({ Text = "THE QUARTERMASTER", TextSize = 26, Size = UDim2.new(1, -120, 0, 32), Parent = panel })
	header = Theme.label({ Position = UDim2.new(0, 0, 0, 34), Size = UDim2.new(1, -120, 0, 18), TextSize = 12, TextColor3 = C.lantern, Parent = panel })
	local close = Theme.button({ Text = "CLOSE", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0, 100, 0, 32), Parent = panel })
	close.Activated:Connect(QM.close)
	list = Theme.make("ScrollingFrame", {
		Position = UDim2.new(0, 0, 0, 60),
		Size = UDim2.new(1, 0, 1, -60),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = panel,
	})
	Theme.list(Enum.FillDirection.Vertical, 6).Parent = list
	for _, attr in { "Scrip", "Guns", "Loadout", "Kit", "Repairs" } do
		player:GetAttributeChangedSignal(attr):Connect(function()
			if backdrop.Visible then
				rebuild()
			end
		end)
	end
end

function QM.open()
	if backdrop then
		backdrop.Visible = true
		State.setModal("quartermaster", true)
		rebuild()
	end
end

function QM.close()
	if backdrop then
		backdrop.Visible = false
		State.setModal("quartermaster", false)
	end
end

return QM
