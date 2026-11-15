--!nonstrict
-- The Meridian projects board: permanent homebase upgrades built with Scrip + Materials (both
-- earned from missions) or a Shipwright's Crew token, plus the armory once it's built.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Projects = require(Shared.Config.Projects)
local Commerce = require(Shared.Config.Commerce)
local MarketplaceService = game:GetService("MarketplaceService")
local Weapons = require(Shared.Config.Weapons)
local Theme = require(script.Parent.Theme)
local State = require(script.Parent.Parent.State)

local Repairs = {}
local C = Theme.Colors
local player = Players.LocalPlayer
local backdrop, list, scripLabel
local request

local function owned()
	local ok, value = pcall(function()
		return HttpService:JSONDecode(player:GetAttribute("Repairs") or "{}")
	end)
	return ok and value or {}
end

local function rebuild()
	Theme.clear(list)
	scripLabel.Text = ("SCRIP %d   ·   MATERIALS %d   ·   SHIPWRIGHT TOKENS %d"):format(player:GetAttribute("Scrip") or 0, player:GetAttribute("Materials") or 0, player:GetAttribute("Tokens_build") or 0)
	local have = owned()
	local first
	for i, r in Projects.List do
		local done = have[r.id] == true
		local locked = r.requires and not have[r.requires]
		local row = Theme.panel({ LayoutOrder = i, Size = UDim2.new(1, -8, 0, 70), BackgroundColor3 = C.panelHi, Parent = list })
		Theme.padding(8).Parent = row
		Theme.heading({ Text = string.upper(r.name), TextSize = 15, Size = UDim2.new(1, -270, 0, 18), Parent = row })
		local note = r.desc
		if locked then
			note = ("Needs the %s first. "):format(Projects.get(r.requires).name) .. note
		end
		Theme.label({ Text = note, Position = UDim2.new(0, 0, 0, 20), Size = UDim2.new(1, -270, 0, 34), TextSize = 12, TextWrapped = true, TextColor3 = locked and C.dim or C.text, Parent = row })
		local buttons = Theme.make("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, 262, 0, 34), BackgroundTransparency = 1, Parent = row })
		local l = Theme.list(Enum.FillDirection.Horizontal, 6)
		l.HorizontalAlignment = Enum.HorizontalAlignment.Right
		l.Parent = buttons
		if done then
			local b = Theme.button({ Text = "BUILT", Size = UDim2.new(0, 120, 1, 0), TextSize = 13, AutoButtonColor = false, Parent = buttons })
			b.TextColor3 = C.ok
		else
			local afford = (player:GetAttribute("Scrip") or 0) >= r.scrip and (player:GetAttribute("Materials") or 0) >= r.materials
			local build = Theme.button({ LayoutOrder = 1, Text = ("%d S · %d M"):format(r.scrip, r.materials), Size = UDim2.new(0, 128, 1, 0), TextSize = 13, AutoButtonColor = afford and not locked, Parent = buttons })
			if not afford or locked then
				build.TextTransparency = 0.45
			end
			build.Activated:Connect(function()
				request("Repair", r.id, false)
			end)
			local tokens = player:GetAttribute("Tokens_build") or 0
			local skip = Theme.button({ LayoutOrder = 2, Text = tokens > 0 and "USE CREW TOKEN" or ("BUILD NOW  R$" .. Commerce.Products.ShipwrightCrew.price), Size = UDim2.new(0, 128, 1, 0), TextSize = 12, Parent = buttons })
			skip.BackgroundColor3 = C.lantern
			skip.TextColor3 = C.panel
			skip.Activated:Connect(function()
				if (player:GetAttribute("Tokens_build") or 0) > 0 then
					request("Repair", r.id, true)
				elseif Commerce.Products.ShipwrightCrew.productId ~= 0 then
					MarketplaceService:PromptProductPurchase(player, Commerce.Products.ShipwrightCrew.productId)
				end
			end)
			first = first or build
		end
	end
	if have.armory then
		Theme.heading({ LayoutOrder = 50, Text = "ARMORY: LONG GUN FOR YOUR NEXT CROSSING", TextSize = 16, TextColor3 = C.salt, Size = UDim2.new(1, 0, 0, 24), Parent = list })
		local rowFrame = Theme.make("Frame", { LayoutOrder = 51, Size = UDim2.new(1, 0, 0, 38), BackgroundTransparency = 1, Parent = list })
		Theme.list(Enum.FillDirection.Horizontal, 6).Parent = rowFrame
		local choice = player:GetAttribute("LongGunChoice")
		for i, id in Weapons.LongGuns do
			local b = Theme.button({ LayoutOrder = i, Text = Weapons.List[id].name, TextSize = 13, Size = UDim2.new(0.25, -5, 1, 0), Parent = rowFrame })
			if choice == id then
				b.BackgroundColor3 = C.lantern
				b.TextColor3 = C.backdrop
			end
			b.Activated:Connect(function()
				request("SetLongGun", id)
				task.delay(0.3, rebuild)
			end)
		end
	end
	Theme.focus(first)
end

function Repairs.build(gui, requestFn)
	request = requestFn
	local panel
	backdrop, panel = Theme.modal(gui, "Repairs", UDim2.new(0.94, 0, 0.9, 0), Vector2.new(660, 600))
	Theme.heading({ Text = "MERIDIAN PROJECTS", TextSize = 26, Size = UDim2.new(1, -120, 0, 32), Parent = panel })
	scripLabel = Theme.heading({ Position = UDim2.new(0, 0, 0, 34), Size = UDim2.new(1, 0, 0, 22), TextSize = 15, TextColor3 = C.lantern, Parent = panel })
	local close = Theme.button({ Text = "CLOSE", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0, 100, 0, 32), Parent = panel })
	close.Activated:Connect(Repairs.close)
	list = Theme.make("ScrollingFrame", {
		Position = UDim2.new(0, 0, 0, 64),
		Size = UDim2.new(1, 0, 1, -64),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		Parent = panel,
	})
	Theme.list(Enum.FillDirection.Vertical, 6).Parent = list
	for _, attr in { "Scrip", "Repairs", "Materials", "Tokens_build" } do
		player:GetAttributeChangedSignal(attr):Connect(function()
			if backdrop.Visible then
				rebuild()
			end
		end)
	end
end

function Repairs.open()
	if backdrop then
		backdrop.Visible = true
		State.setModal("repairs", true)
		rebuild()
	end
end

function Repairs.close()
	if backdrop then
		backdrop.Visible = false
		State.setModal("repairs", false)
	end
end

return Repairs
