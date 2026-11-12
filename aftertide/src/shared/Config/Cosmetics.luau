--!nonstrict
-- The Wardrobe: cosmetic outfits (recolours of each crew member's clothing layers). They never
-- change stats. Unlocks:
--   default    everyone owns it
--   scrip      buy with Scrip (earned only by playing crossings)
--   product    Robux (Commerce.Products[product]) or Scrip (scrip > 0 means it can be earned too)
--   pack       comes with a bundle (the Starter Pack)
--   supporter  owned while you hold the Supporter game pass
-- colours: top (jacket/robe/sleeves), pants, boots, hat (hat/hood), pack, scarf, mask.
local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local Cosmetics = {}

Cosmetics.Outfits = {
	-- Mara ---------------------------------------------------------------------------------
	mara_default = { char = "mara", name = "Harbour Pilot", unlock = "default", colors = {} },
	mara_storm = { char = "mara", name = "Storm Watch", unlock = "scrip", scrip = 400, colors = { top = rgb(84, 92, 74), pants = rgb(40, 40, 38), hat = rgb(46, 50, 44), scarf = rgb(180, 160, 110) } },
	mara_pilot = { char = "mara", name = "Night Pilot", unlock = "product", product = "Outfit_mara_pilot", scrip = 1500, colors = { top = rgb(34, 42, 64), pants = rgb(30, 30, 34), hat = rgb(30, 34, 52), scarf = rgb(160, 40, 36), pack = rgb(70, 58, 40) } },
	mara_deckhand = { char = "mara", name = "Deckhand", unlock = "pack", colors = { top = rgb(190, 120, 50), pants = rgb(54, 60, 70), hat = rgb(40, 60, 70) } },
	mara_officer = { char = "mara", name = "Meridian Officer", unlock = "supporter", colors = { top = rgb(26, 30, 36), pants = rgb(26, 28, 30), hat = rgb(24, 26, 30), scarf = rgb(196, 160, 80), pack = rgb(60, 50, 40) } },
	-- Tobias -------------------------------------------------------------------------------
	tobias_default = { char = "tobias", name = "Ferry Engineer", unlock = "default", colors = {} },
	tobias_rust = { char = "tobias", name = "Rust Bucket", unlock = "scrip", scrip = 400, colors = { top = rgb(120, 60, 36), pants = rgb(70, 64, 54), hat = rgb(90, 50, 30) } },
	tobias_stoker = { char = "tobias", name = "Boiler Stoker", unlock = "product", product = "Outfit_tobias_stoker", scrip = 1500, colors = { top = rgb(34, 32, 30), pants = rgb(46, 40, 34), hat = rgb(70, 50, 34), pack = rgb(60, 44, 30), boots = rgb(26, 22, 20) } },
	tobias_deckhand = { char = "tobias", name = "Deckhand", unlock = "pack", colors = { top = rgb(190, 120, 50), pants = rgb(54, 60, 70), hat = rgb(40, 60, 70) } },
	tobias_officer = { char = "tobias", name = "Meridian Officer", unlock = "supporter", colors = { top = rgb(26, 30, 36), pants = rgb(26, 28, 30), hat = rgb(24, 26, 30), pack = rgb(60, 50, 40) } },
	-- Ines ---------------------------------------------------------------------------------
	ines_default = { char = "ines", name = "Ship's Medic", unlock = "default", colors = {} },
	ines_mourning = { char = "ines", name = "Mourning Grey", unlock = "scrip", scrip = 400, colors = { top = rgb(70, 72, 76), pants = rgb(36, 38, 42), pack = rgb(120, 116, 108) } },
	ines_field = { char = "ines", name = "Field Surgeon", unlock = "product", product = "Outfit_ines_field", scrip = 1500, colors = { top = rgb(214, 208, 194), pants = rgb(60, 66, 72), pack = rgb(150, 40, 36), mask = rgb(150, 40, 36) } },
	ines_deckhand = { char = "ines", name = "Deckhand", unlock = "pack", colors = { top = rgb(190, 120, 50), pants = rgb(54, 60, 70) } },
	ines_officer = { char = "ines", name = "Meridian Officer", unlock = "supporter", colors = { top = rgb(26, 30, 36), pants = rgb(26, 28, 30), pack = rgb(60, 50, 40), mask = rgb(196, 160, 80) } },
	-- Sefa ---------------------------------------------------------------------------------
	sefa_default = { char = "sefa", name = "Salvage Diver", unlock = "default", colors = {} },
	sefa_dune = { char = "sefa", name = "Dune Walker", unlock = "scrip", scrip = 400, colors = { top = rgb(170, 150, 110), hat = rgb(150, 130, 96), pants = rgb(90, 80, 64) } },
	sefa_reef = { char = "sefa", name = "Reef Diver", unlock = "product", product = "Outfit_sefa_reef", scrip = 1500, colors = { top = rgb(44, 70, 56), hat = rgb(150, 140, 110), pants = rgb(30, 40, 38), boots = rgb(20, 30, 30) } },
	sefa_deckhand = { char = "sefa", name = "Deckhand", unlock = "pack", colors = { top = rgb(190, 120, 50), pants = rgb(54, 60, 70), hat = rgb(40, 60, 70) } },
	sefa_officer = { char = "sefa", name = "Meridian Officer", unlock = "supporter", colors = { top = rgb(26, 30, 36), pants = rgb(26, 28, 30), hat = rgb(24, 26, 30), pack = rgb(60, 50, 40) } },
}

-- Wardrobe order per crew member.
Cosmetics.Order = {
	mara = { "mara_default", "mara_storm", "mara_pilot", "mara_deckhand", "mara_officer" },
	tobias = { "tobias_default", "tobias_rust", "tobias_stoker", "tobias_deckhand", "tobias_officer" },
	ines = { "ines_default", "ines_mourning", "ines_field", "ines_deckhand", "ines_officer" },
	sefa = { "sefa_default", "sefa_dune", "sefa_reef", "sefa_deckhand", "sefa_officer" },
}

-- Which sculpted mesh layers each colour slot repaints (see tools/sculpt/human.py layer names).
Cosmetics.Layers = {
	top = { "Jacket", "Sleeve", "JacketHem", "Robe" },
	pants = { "Pants" },
	boots = { "Boot" },
	hat = { "Hat", "Hood" },
	pack = { "Pack" },
	scarf = { "Scarf" },
	mask = { "Mask" },
}

function Cosmetics.defaultFor(charId)
	return charId .. "_default"
end

-- { [layerName] = Color3 } for MeshKit, from an outfit id.
function Cosmetics.layerColors(outfitId)
	local outfit = Cosmetics.Outfits[outfitId]
	local out = {}
	if outfit then
		for slot, color in outfit.colors do
			for _, layer in Cosmetics.Layers[slot] or {} do
				out[layer] = color
			end
		end
	end
	return out
end

return Cosmetics
