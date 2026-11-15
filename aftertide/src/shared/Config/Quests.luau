--!nonstrict
-- Quest board challenges on the Meridian. Three dailies and two weeklies, picked the same for
-- everyone each day / week. Progress counts from encounters; rewards pay out automatically.
-- stat: takedowns | kills | objectives | wins | unseenWins | crossings | breakwater
return {
	Daily = {
		{ id = "d_quiet", name = "Quiet Hands", desc = "Quiet %d Hushed.", stat = "takedowns", target = 5, scrip = 30, materials = 10 },
		{ id = "d_kills", name = "Clear the Way", desc = "Put down %d enemies.", stat = "kills", target = 15, scrip = 30, materials = 10 },
		{ id = "d_objectives", name = "Get It Done", desc = "Complete %d mission objectives (crates, caches, relays, nests).", stat = "objectives", target = 6, scrip = 35, materials = 12 },
		{ id = "d_wins", name = "Back Aboard", desc = "Win %d encounters.", stat = "wins", target = 2, scrip = 40, materials = 15 },
		{ id = "d_unseen", name = "Like Fog", desc = "Win %d encounter without being spotted.", stat = "unseenWins", target = 1, scrip = 50, materials = 20 },
		{ id = "d_crossing", name = "The Long Way", desc = "Finish %d crossing.", stat = "crossings", target = 1, scrip = 60, materials = 25 },
	},
	Weekly = {
		{ id = "w_wins", name = "Tide-Turner", desc = "Win %d encounters this week.", stat = "wins", target = 15, scrip = 200, materials = 80 },
		{ id = "w_quiet", name = "Silent Week", desc = "Quiet %d Hushed this week.", stat = "takedowns", target = 40, scrip = 180, materials = 70 },
		{ id = "w_breakwater", name = "Hold the Breakwater", desc = "Win %d finale (The Breakwater).", stat = "breakwater", target = 1, scrip = 250, materials = 100 },
		{ id = "w_objectives", name = "Salvager", desc = "Complete %d mission objectives this week.", stat = "objectives", target = 40, scrip = 200, materials = 80 },
	},
	DailyCount = 3,
	WeeklyCount = 2,
}
