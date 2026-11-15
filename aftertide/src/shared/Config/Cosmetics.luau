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
	mara_storm = { char = "mara", name = "Storm Watch", unlock = "scrip", scrip = 400, colors = { top = rgb(80, 150, 90), pants = rgb(70, 70, 76), hat = rgb(240, 200, 70), scarf = rgb(240, 240, 232), boots = rgb(60, 50, 44) } },
	mara_pilot = { char = "mara", name = "Night Pilot", unlock = "product", product = "Outfit_mara_pilot", scrip = 1500, colors = { top = rgb(40, 70, 150), pants = rgb(46, 50, 66), hat = rgb(40, 70, 150), scarf = rgb(230, 60, 60), pack = rgb(180, 130, 70), boots = rgb(70, 46, 32) } },
	mara_sunset = { char = "mara", name = "Sunset Sail", unlock = "product", product = "Outfit_mara_sunset", scrip = 700, colors = { top = rgb(250, 140, 90), pants = rgb(240, 230, 210), hat = rgb(120, 70, 170), scarf = rgb(255, 210, 80), boots = rgb(150, 90, 60) } },
	mara_deckhand = { char = "mara", name = "Deckhand", unlock = "pack", colors = { top = rgb(240, 140, 50), pants = rgb(54, 80, 130), hat = rgb(40, 130, 150) } },
	mara_officer = { char = "mara", name = "Meridian Officer", unlock = "supporter", colors = { top = rgb(245, 245, 240), pants = rgb(30, 50, 90), hat = rgb(30, 50, 90), scarf = rgb(220, 180, 70), pack = rgb(150, 110, 70) } },
	-- Tobias -------------------------------------------------------------------------------
	tobias_default = { char = "tobias", name = "Ferry Engineer", unlock = "default", colors = {} },
	tobias_rust = { char = "tobias", name = "Rust Bucket", unlock = "scrip", scrip = 400, colors = { top = rgb(190, 80, 50), pants = rgb(90, 84, 70), hat = rgb(240, 190, 60) } },
	tobias_stoker = { char = "tobias", name = "Boiler Stoker", unlock = "product", product = "Outfit_tobias_stoker", scrip = 1500, colors = { top = rgb(60, 60, 66), pants = rgb(110, 70, 40), hat = rgb(220, 70, 50), pack = rgb(170, 120, 60), boots = rgb(40, 34, 30) } },
	tobias_sunset = { char = "tobias", name = "Lifeguard", unlock = "product", product = "Outfit_tobias_sunset", scrip = 700, colors = { top = rgb(230, 50, 50), pants = rgb(250, 220, 90), hat = rgb(250, 250, 245), boots = rgb(240, 240, 235) } },
	tobias_deckhand = { char = "tobias", name = "Deckhand", unlock = "pack", colors = { top = rgb(240, 140, 50), pants = rgb(54, 80, 130), hat = rgb(40, 130, 150) } },
	tobias_officer = { char = "tobias", name = "Meridian Officer", unlock = "supporter", colors = { top = rgb(245, 245, 240), pants = rgb(30, 50, 90), hat = rgb(30, 50, 90), pack = rgb(150, 110, 70) } },
	-- Ines ---------------------------------------------------------------------------------
	ines_default = { char = "ines", name = "Ship's Medic", unlock = "default", colors = {} },
	ines_mourning = { char = "ines", name = "Lavender Watch", unlock = "scrip", scrip = 400, colors = { top = rgb(170, 140, 220), pants = rgb(60, 64, 90), pack = rgb(240, 236, 226), boots = rgb(90, 70, 120) } },
	ines_field = { char = "ines", name = "Field Surgeon", unlock = "product", product = "Outfit_ines_field", scrip = 1500, colors = { top = rgb(245, 244, 238), pants = rgb(70, 140, 160), pack = rgb(220, 50, 50), boots = rgb(70, 140, 160) } },
	ines_sunset = { char = "ines", name = "Mint Medic", unlock = "product", product = "Outfit_ines_sunset", scrip = 700, colors = { top = rgb(120, 220, 180), pants = rgb(240, 240, 235), pack = rgb(250, 120, 140), boots = rgb(250, 250, 248) } },
	ines_deckhand = { char = "ines", name = "Deckhand", unlock = "pack", colors = { top = rgb(240, 140, 50), pants = rgb(54, 80, 130) } },
	ines_officer = { char = "ines", name = "Meridian Officer", unlock = "supporter", colors = { top = rgb(245, 245, 240), pants = rgb(30, 50, 90), pack = rgb(150, 110, 70), boots = rgb(30, 30, 34) } },
	-- Sefa ---------------------------------------------------------------------------------
	sefa_default = { char = "sefa", name = "Salvage Diver", unlock = "default", colors = {} },
	sefa_dune = { char = "sefa", name = "Dune Walker", unlock = "scrip", scrip = 400, colors = { top = rgb(230, 190, 130), hat = rgb(200, 90, 60), pants = rgb(120, 100, 76) } },
	sefa_reef = { char = "sefa", name = "Reef Diver", unlock = "product", product = "Outfit_sefa_reef", scrip = 1500, colors = { top = rgb(40, 160, 170), hat = rgb(250, 140, 60), pants = rgb(30, 60, 90), boots = rgb(250, 140, 60) } },
	sefa_sunset = { char = "sefa", name = "Coral Reefer", unlock = "product", product = "Outfit_sefa_sunset", scrip = 700, colors = { top = rgb(250, 110, 120), hat = rgb(250, 110, 120), pants = rgb(60, 150, 200), boots = rgb(255, 220, 90) } },
	sefa_deckhand = { char = "sefa", name = "Deckhand", unlock = "pack", colors = { top = rgb(240, 140, 50), pants = rgb(54, 80, 130), hat = rgb(40, 130, 150) } },
	sefa_officer = { char = "sefa", name = "Meridian Officer", unlock = "supporter", colors = { top = rgb(245, 245, 240), pants = rgb(30, 50, 90), hat = rgb(30, 50, 90), pack = rgb(150, 110, 70) } },
}

-- Wardrobe order per crew member.
Cosmetics.Order = {
	mara = { "mara_default", "mara_storm", "mara_sunset", "mara_pilot", "mara_deckhand", "mara_officer" },
	tobias = { "tobias_default", "tobias_rust", "tobias_sunset", "tobias_stoker", "tobias_deckhand", "tobias_officer" },
	ines = { "ines_default", "ines_mourning", "ines_sunset", "ines_field", "ines_deckhand", "ines_officer" },
	sefa = { "sefa_default", "sefa_dune", "sefa_sunset", "sefa_reef", "sefa_deckhand", "sefa_officer" },
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
