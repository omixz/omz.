--!nonstrict
-- Combines a character's innate perk and chosen perk into one modifier table.
local Characters = require(script.Parent.Config.Characters)

local Stats = {}

local DEFAULTS = {
	noiseMult = 1,
	crouchNoiseMult = 1,
	waterNoiseMult = 1,
	takedownTimeMult = 1,
	shoveCooldownMult = 1,
	healMult = 1,
	throwCapBonus = 0,
	damageTakenMult = 1,
	abilityCooldownMult = 1,
	abilityRadiusMult = 1,
	abilityDurationMult = 1,
	sprintSpeedMult = 1,
	reviveHPBonus = 0,
	bleedOutBonus = 0,
	throwNoiseMult = 1,
	craftTimeMult = 1,
	craftYieldBonus = 0,
	ammoBonus = 0,
	aimSpreadMult = 1,
}

local ADDITIVE = {
	throwCapBonus = true,
	reviveHPBonus = true,
	bleedOutBonus = true,
	craftYieldBonus = true,
	ammoBonus = true,
}

local function apply(result, mods)
	for key, value in mods do
		if DEFAULTS[key] == nil then
			warn("[Stats] unknown perk modifier: " .. tostring(key))
		elseif ADDITIVE[key] then
			result[key] += value
		else
			result[key] *= value
		end
	end
end

function Stats.findPerk(charId, perkId)
	local def = Characters.List[charId]
	if not def then
		return nil
	end
	for _, perk in def.perks do
		if perk.id == perkId then
			return perk
		end
	end
	return nil
end

-- extraPerks: optional set { [perkId] = true } of perks bought at the workbench this run.
function Stats.compute(charId, perkId, extraPerks)
	local result = table.clone(DEFAULTS)
	local def = Characters.List[charId]
	if not def then
		return result
	end
	apply(result, def.innate.mods)
	local perk = Stats.findPerk(charId, perkId)
	if perk then
		apply(result, perk.mods)
	end
	if extraPerks then
		for _, p in def.perks do
			if extraPerks[p.id] and p.id ~= perkId then
				apply(result, p.mods)
			end
		end
	end
	return result
end

return Stats
