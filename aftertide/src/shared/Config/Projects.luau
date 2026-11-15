--!nonstrict
-- Meridian projects: permanent upgrades to the homebase, paid with Materials (earned at the end
-- of every mission; Scrip is for the Quartermaster store). Each one physically adds a room or fitting to the ferry,
-- and many unlock new mission types or maps. A Shipwright's Crew token (earned, or bought with
-- Robux) completes one project instantly without the materials.
--
-- Kept compatible with old saves: owned projects are stored with the old repair ids.
-- Bonuses are applied in HomebaseService.bonusesFor; unlocks in MatchService.
local Projects = {}

Projects.List = {
	{ id = "lights", name = "Deck Lights", desc = "Crew morale: +10% Scrip from every mission.", scrip = 0, materials = 20 },
	{ id = "generator", name = "Generator Room", desc = "Start every crossing with +20 Salvage for the workbench.", scrip = 0, materials = 45 },
	{ id = "workshop", name = "Workshop", desc = "Workbench upgrades 25% cheaper; +1 from every arrow, spike and salt bomb you craft.", scrip = 0, materials = 70, requires = "generator" },
	{ id = "sickbay", name = "Infirmary", desc = "+15 max health and an extra Field Dressing every crossing. Unlocks Medicine Run missions.", scrip = 0, materials = 90, unlocks = { missions = { "Medicine" } } },
	{ id = "radio", name = "Radio Room", desc = "The tide chart offers 3 routes. Unlocks Restore the Signal missions.", scrip = 0, materials = 110, requires = "generator", unlocks = { missions = { "Relay" } } },
	{ id = "armory", name = "Armory", desc = "+1 backpack gun slot and 15% off at the Quartermaster. Unlocks Burn the Nests missions.", scrip = 0, materials = 140, requires = "workshop", unlocks = { missions = { "Nests" } } },
	{ id = "chartroom", name = "Chart Room", desc = "Unlocks Hollow Pines and +15% Materials from every mission.", scrip = 0, materials = 170, requires = "radio", unlocks = { maps = { "HollowPines" } } },
	{ id = "lookout", name = "Lookout Tower", desc = "Every encounter opens with a Tide Sense pulse for the whole crew: you see the Hushed through walls.", scrip = 0, materials = 220, requires = "chartroom" },
}


-- Mission types / maps available without any project.
Projects.BaseMissions = { "Salvage", "LanternWatch", "Drift", "Hunt", "Rescue" }
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
