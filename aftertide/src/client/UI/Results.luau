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
	backdrop, panel = Theme.modal(gui, "Results", UDim2.new(0.9, 0, 0.6, 0), Vector2.new(520, 380))
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
	title.Text = data.win and "CROSSING COMPLETE" or "LOST TO THE PALL"
	title.TextColor3 = data.win and C.lantern or C.danger
	local lines = {
		("Time  %d:%02d"):format(math.floor((data.seconds or 0) / 60), (data.seconds or 0) % 60),
		("Supply crates  %d"):format(data.crates or 0),
		("Quietings  %d"):format(data.takedowns or 0),
		("Times spotted  %d"):format(data.detections or 0),
	}
	if data.rewards and #data.rewards > 0 then
		table.insert(lines, "")
		table.insert(lines, "Earned: " .. table.concat(data.rewards, ", "))
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
