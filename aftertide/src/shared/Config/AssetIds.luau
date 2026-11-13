--!nonstrict
-- Roblox asset IDs of the uploaded 3D packs (aftertide/assets/*.glb). Filled in by
-- tools/upload_assets.py (Open Cloud) or by hand after importing them in Studio.
-- 0 = not uploaded yet: the game falls back to its built-in part models.
--
-- Alternative to IDs: import a pack in Studio (File > Import 3D) and put the resulting
-- Model in ServerStorage > Assets, named exactly like the pack (e.g. "Crew").
return {
	Packs = {
		Crew = 76266761695416,
		Factions = 91251214178661,
		Hushed = 121889443135120,
		Weapons = 93917808586387,
		Nature = 73346481237318,
		Props = 126141441239944,
	},
	-- Roblox's importer treats +Z as the front of a glTF file (the glTF standard); our sculpts
	-- face -Z (Roblox's front), so every imported mesh comes in turned around. 180 fixes it.
	-- If models ever look backwards after re-importing in Studio by hand, set this to 0.
	YawFix = 180,
}
