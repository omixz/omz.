--!nonstrict
-- Roblox asset IDs of the uploaded 3D packs (aftertide/assets/*.glb). Filled in by
-- tools/upload_assets.py (Open Cloud) or by hand after importing them in Studio.
-- 0 = not uploaded yet: the game falls back to its built-in part models.
--
-- Alternative to IDs: import a pack in Studio (File > Import 3D) and put the resulting
-- Model in ServerStorage > Assets, named exactly like the pack (e.g. "Crew").
return {
	Packs = {
		Crew = 0,
		Factions = 0,
		Hushed = 0,
		Weapons = 0,
		Nature = 0,
		Props = 0,
	},
	-- If imported meshes face backwards, set this to 180.
	YawFix = 0,
}
