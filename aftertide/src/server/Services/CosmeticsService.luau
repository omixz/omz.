--!nonstrict
-- The Wardrobe (server side): who owns which outfit, buying outfits with Scrip, equipping,
-- the Supporter game pass, and the colours a crew member should be dressed in.
-- Cosmetic only: nothing here touches stats.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Commerce = require(Shared.Config.Commerce)
local Cosmetics = require(Shared.Config.Cosmetics)
local Net = require(Shared.Net)

local CosmeticsService = {}
local Services

local supporter = {} -- [Player] = true

function CosmeticsService.isSupporter(player)
	return supporter[player] == true
end

local function setSupporter(player, on)
	supporter[player] = on or nil
	player:SetAttribute("Supporter", on == true)
end

function CosmeticsService.owns(player, outfitId)
	local outfit = Cosmetics.Outfits[outfitId]
	if not outfit then
		return false
	end
	if outfit.unlock == "default" then
		return true
	end
	if outfit.unlock == "supporter" then
		return supporter[player] == true
	end
	local data = Services.PlayerDataService.get(player)
	return data ~= nil and data.outfits[outfitId] == true
end

-- The outfit a player has on for a crew member (falls back to the default if not owned).
function CosmeticsService.equippedFor(player, charId)
	local data = Services.PlayerDataService.get(player)
	local id = data and data.equipped[charId]
	if id and Cosmetics.Outfits[id] and Cosmetics.Outfits[id].char == charId and CosmeticsService.owns(player, id) then
		return id
	end
	return Cosmetics.defaultFor(charId)
end

function CosmeticsService.layerColors(player, charId)
	return Cosmetics.layerColors(CosmeticsService.equippedFor(player, charId))
end

-- Scrip multiplier for crossing rewards (Supporter pass).
function CosmeticsService.scripMult(player)
	return supporter[player] and (1 + (Commerce.Passes.Supporter.scripBonus or 0)) or 1
end

local function respawnIfOnFerry(player)
	-- show the new look straight away when it's safe (not mid-encounter)
	local session = Services.CharacterService.getSession(player)
	if session and session.charId and not Services.MatchService.getActiveInfo(player) and player.Character then
		local root = player.Character:FindFirstChild("HumanoidRootPart")
		if root then
			Services.CharacterService.spawn(player, root.CFrame, false)
		end
	end
end

function CosmeticsService.equip(player, outfitId)
	local outfit = type(outfitId) == "string" and Cosmetics.Outfits[outfitId]
	if not outfit or not CosmeticsService.owns(player, outfitId) then
		return
	end
	Services.PlayerDataService.setEquipped(player, outfit.char, outfitId)
	if player:GetAttribute("CharId") == outfit.char then
		respawnIfOnFerry(player)
	end
end

function CosmeticsService.buyWithScrip(player, outfitId)
	local outfit = type(outfitId) == "string" and Cosmetics.Outfits[outfitId]
	if not outfit or not outfit.scrip or outfit.scrip <= 0 or CosmeticsService.owns(player, outfitId) then
		return
	end
	if not Services.PlayerDataService.spendScrip(player, outfit.scrip) then
		Net.notify(player, "Toast", { text = ("Not enough Scrip (%d needed). Earn it by finishing crossings."):format(outfit.scrip) })
		return
	end
	Services.PlayerDataService.ownOutfit(player, outfitId)
	Services.AnalyticsHelper.economy(player, "sink", outfit.scrip, Enum.AnalyticsEconomyTransactionType.Shop.Name, outfitId)
	Net.notify(player, "Toast", { text = outfit.name .. " added to your wardrobe" })
	CosmeticsService.equip(player, outfitId)
end

function CosmeticsService.init(registry)
	Services = registry
end

local function checkPass(player)
	local passId = Commerce.Passes.Supporter.passId
	if not passId or passId == 0 then
		return
	end
	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
	end)
	if ok then
		setSupporter(player, owns)
	end
end

function CosmeticsService.start()
	Players.PlayerAdded:Connect(function(player)
		task.spawn(checkPass, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(checkPass, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		supporter[player] = nil
	end)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if purchased and passId == Commerce.Passes.Supporter.passId then
			setSupporter(player, true)
			Services.AnalyticsHelper.purchase(player, "Pass_Supporter", Commerce.Passes.Supporter.price)
			Net.notify(player, "Toast", { text = "Welcome aboard, Supporter. Officer's colours are in your wardrobe." })
		end
	end)
end

return CosmeticsService
