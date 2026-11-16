--!nonstrict
-- Thin wrapper over AnalyticsService so we can see (Creator Hub > Analytics) where Scrip is
-- earned and spent and which products sell. Never throws: analytics must not break gameplay.
local AnalyticsService = game:GetService("AnalyticsService")

local AnalyticsHelper = {}

-- flow "source" (earned) or "sink" (spent) of Scrip.
function AnalyticsHelper.economy(player, flow, amount, transactionType, itemSku)
	pcall(function()
		local data = AnalyticsHelper.balance and AnalyticsHelper.balance(player) or 0
		AnalyticsService:LogEconomyEvent(
			player,
			flow == "sink" and Enum.AnalyticsEconomyFlowType.Sink or Enum.AnalyticsEconomyFlowType.Source,
			"Scrip",
			amount,
			data,
			transactionType,
			itemSku
		)
	end)
end

function AnalyticsHelper.purchase(player, key, robux)
	pcall(function()
		AnalyticsService:LogCustomEvent(player, "RobuxPurchase", robux or 0, { [Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = key })
	end)
end

function AnalyticsHelper.funnel(player, step, name)
	pcall(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, step, name)
	end)
end

function AnalyticsHelper.init(registry)
	AnalyticsHelper.balance = function(player)
		local data = registry.PlayerDataService.get(player)
		return data and data.scrip or 0
	end
end

return AnalyticsHelper
