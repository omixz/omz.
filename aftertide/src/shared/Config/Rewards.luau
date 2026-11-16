--!nonstrict
-- Daily login streak and the Logbook (lore pages found on missions).
local Rewards = {}

-- Come back on consecutive days (UTC); miss a day and it starts again from day 1.
-- grant: scrip / materials / tokens = { kind = n } / kit = { kitId = n }
Rewards.Streak = {
	{ day = 1, text = "40 Scrip", grant = { scrip = 40 } },
	{ day = 2, text = "20 Materials", grant = { materials = 20 } },
	{ day = 3, text = "Pocket Rounds (next crossing)", grant = { kit = { pocketrounds = 1 } } },
	{ day = 4, text = "80 Scrip", grant = { scrip = 80 } },
	{ day = 5, text = "1 Lucky Spin", grant = { tokens = { spin = 1 } } },
	{ day = 6, text = "40 Materials", grant = { materials = 40 } },
	{ day = 7, text = "150 Scrip + Ammo Cache", grant = { scrip = 150, tokens = { ammo = 1 } } },
}

-- Torn logbook pages: one or two lie somewhere on every mission. Every 4 found pays out.
Rewards.PageReward = { every = 4, scrip = 100, materials = 25 }
Rewards.Pages = {
	{ id = "p01", title = "Harbourmaster's log, day 1", text = "Fog bank off the breakwater at dawn. Thick as wool and it doesn't move with the wind. Told the boats to stay in." },
	{ id = "p02", title = "Harbourmaster's log, day 4", text = "Three men walked out of the fog at the fish market. Didn't speak. Didn't blink. Salt crust on their lips. The constable called them hushed, and the name stuck." },
	{ id = "p03", title = "Notice, pinned to a door", text = "THE PALL IS IN THE WATER. BOIL EVERYTHING. DO NOT SLEEP BY AN OPEN WINDOW. - Larkspur Residents' Committee" },
	{ id = "p04", title = "A child's drawing", text = "A ferry with a smiling sun. Under it, in crayon: 'the boat that does not sink'. Someone has written MERIDIAN next to it in pencil." },
	{ id = "p05", title = "Harbour Watch orders", text = "All civilians to the cannery. Anyone carrying salt goes to the front of the line. Anyone who won't speak goes nowhere." },
	{ id = "p06", title = "Tidebound tract", text = "The Pall is not a sickness. It is the sea taking back its breath. Kneel at the tide line and be still, and you will be still forever." },
	{ id = "p07", title = "Tobias, engine room", text = "Generator's held eleven years on scrap and swearing. If anyone else reads this: the third valve sticks. Hit it with the wrench. Gently. Then not gently." },
	{ id = "p08", title = "Ines, sick bay notes", text = "The Hushed don't hear you breathe if you're behind glass. They hear footsteps through the deck. Crawl past the infirmary windows." },
	{ id = "p09", title = "Mara, tide chart margin", text = "Fog thins at the turn of the tide. Twenty minutes, maybe thirty. Enough to cross Cannery Row if nobody runs." },
	{ id = "p10", title = "Sefa, dive log", text = "Went under the Larkspur bridge. Cars on the bottom with their headlights still on. Didn't go back down." },
	{ id = "p11", title = "Ranger station radio transcript", text = "...repeat, the pines are clear above the ridge. The Pall sits in the low ground like water. Stay high, stay dry, stay quiet..." },
	{ id = "p12", title = "Watch captain's letter", text = "Mother, we hold the cannery. We are doing terrible things to keep it. If the ferry comes, let them pass. Tell no one I said so." },
	{ id = "p13", title = "Shopping list", text = "Bread. Batteries. Salt (lots). Tape. Something for the dog. Tell Dad the boat leaves Tuesday." },
	{ id = "p14", title = "Tidebound hymn", text = "Down where the bells ring under the waves, down where the quiet keeps, we will all be hushed in the end, we will all be held in the deep." },
	{ id = "p15", title = "The Breakwater", text = "Beyond the breakwater the fog ends. Everyone says so. Nobody has come back to say it twice." },
	{ id = "p16", title = "Unsigned", text = "If you found this, you are still talking. Keep talking. The Hushed stop talking first." },
}

function Rewards.page(id)
	for _, p in Rewards.Pages do
		if p.id == id then
			return p
		end
	end
	return nil
end

return Rewards
