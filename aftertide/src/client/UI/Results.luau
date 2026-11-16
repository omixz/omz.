--!nonstrict
-- End-of-encounter debrief.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Theme = require(script.Parent.Theme)
local State = require(script.Parent.Parent.State)

local Results = {}
local C = Theme.Colors
local backdrop, title, body

function Results.build(gui)
	local panel
	backdrop, panel = Theme.modal(gui, "Results", UDim2.new(0.9, 0, 0.7, 0), Vector2.new(580, 420))
	Theme.list(Enum.FillDirection.Vertical, 10).Parent = panel
	title = Theme.heading({ LayoutOrder = 1, Text = "", TextSize = 32, Size = UDim2.new(1, 0, 0, 38), Parent = panel })
	body = Theme.label({ LayoutOrder = 2, Text = "", TextSize = 15, Size = UDim2.new(1, 0, 0, 170), Parent = panel })
	local back = Theme.button({ LayoutOrder = 3, Text = "RETURN TO THE MERIDIAN", Size = UDim2.new(0, 280, 0, 40), Parent = panel })
	back.Activated:Connect(function()
		Net.event("ReturnToFerry"):FireServer()
		back.Text = "WAITING FOR CREW…"
	end)
	Results.backButton = back
end

function Results.show(data)
	if not backdrop then
		return
	end
	if data.runWon then
		title.Text = "THE BREAKWATER IS LIT"
		title.TextColor3 = C.lantern
	elseif data.win then
		title.Text = string.upper(tostring(data.name or "")) .. " CLEARED"
		title.TextColor3 = C.lantern
	else
		title.Text = "LOST TO THE PALL"
		title.TextColor3 = C.danger
	end
	local seconds = data.seconds or 0
	local lines = {
		("Stop %d  ·  Pall %d  ·  %d:%02d"):format(data.index or 1, data.pall or 1, math.floor(seconds / 60), seconds % 60),
		("Quietings %d  ·  Hushed dispersed %d  ·  Times spotted %d"):format(data.takedowns or 0, data.kills or 0, data.detections or 0),
	}
	if (data.crates or 0) > 0 then
		table.insert(lines, ("Supply crates %d"):format(data.crates))
	end
	if data.rewards and #data.rewards > 0 then
		table.insert(lines, "")
		table.insert(lines, "Earned: " .. table.concat(data.rewards, ", "))
	end
	table.insert(lines, "")
	if data.runOver then
		table.insert(lines, data.runWon and "Crossing complete. Scrip is yours to keep: repair the Meridian." or "The crossing is over. Scrip you earned is kept.")
	else
		table.insert(lines, "Back to the Meridian to upgrade and choose the next route.")
	end
	body.Text = table.concat(lines, "\n")
	Results.backButton.Text = "RETURN TO THE MERIDIAN"
	backdrop.Visible = true
	State.setModal("results", true)
end

function Results.close()
	if backdrop then
		backdrop.Visible = false
		State.setModal("results", false)
	end
end

return Results
