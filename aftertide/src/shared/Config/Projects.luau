--!nonstrict
-- Meridian projects: permanent upgrades to the homebase, paid with Scrip and Materials
-- (both earned by playing missions). Each one physically adds a room or fitting to the ferry,
-- and many unlock new mission types or maps. A Shipwright's Crew token (earned, or bought with
-- Robux) completes one project instantly without the materials.
--
-- Kept compatible with old saves: owned projects are stored with the old repair ids.
-- Bonuses are applied in HomebaseService.bonusesFor; unlocks in MatchService.
local Projects = {}

Projects.List = {
	{ id = "lights", name = "Deck Lights", desc = "String the Meridian with lights again.", scrip = 20, materials = 10 },
	{ id = "generator", name = "Generator Room", desc = "Power below decks. Start every crossing with +15 Salvage.", scrip = 40, materials = 25 },
	{ id = "workshop", name = "Workshop", desc = "A proper shed for the workbench. Workbench upgrades cost 15% less.", scrip = 60, materials = 40, requires = "generator" },
	{ id = "sickbay", name = "Infirmary", desc = "Start every crossing with an extra Field Dressing. Unlocks Medicine Run missions.", scrip = 80, materials = 60, unlocks = { missions = { "Medicine" } } },
	{ id = "radio", name = "Radio Room", desc = "The tide chart offers 3 routes. Unlocks Restore the Signal missions.", scrip = 100, materials = 80, requires = "generator", unlocks = { missions = { "Relay" } } },
	{ id = "armory", name = "Armory", desc = "Choose your long gun before a crossing. Unlocks Burn the Nests missions.", scrip = 120, materials = 100, requires = "workshop", unlocks = { missions = { "Nests" } } },
	{ id = "chartroom", name = "Chart Room", desc = "Old survey charts. Unlocks Hollow Pines on the tide chart.", scrip = 150, materials = 120, requires = "radio", unlocks = { maps = { "HollowPines" } } },
	{ id = "lookout", name = "Lookout Tower", desc = "Spot trouble early: every encounter opens with a Tide Sense pulse for the whole crew.", scrip = 200, materials = 160, requires = "chartroom" },
}

-- Mission types / maps available without any project.
Projects.BaseMissions = { "Salvage", "LanternWatch", "Drift" }
Projects.BaseMaps = { "CanneryRow", "LarkspurStreet" }

-- How Materials are earned (MatchService).
Projects.Materials = {
	perWin = 8, -- + perPall per Pall level
	perPall = 4,
	runComplete = 30,
	lossShare = 0.5, -- a failed encounter still pays half
	salvageToMaterials = 0.5, -- leftover Salvage at the end of a crossing
}

function Projects.get(id)
	for _, p in Projects.List do
		if p.id == id then
			return p
		end
	end
	return nil
end

return Projects
