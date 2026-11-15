--!nonstrict
-- Fictional, stylised weapons (no real brands or real-world specs). Damage is against the
-- Hushed (Drifter = 100 HP). Gunshots are LOUD: every shot is a noise event, so going loud
-- is a choice with consequences. The bow is the quiet option.
-- spread values are degrees; noise is the radius (studs) Hushed hear the shot.
-- impact = how hard a hit shoves / staggers (and throws a ragdoll); recoilPattern = sideways
-- kick per shot in a repeating pattern (learnable, not random); adsTime = seconds to aim in;
-- perShell = reload one shell at a time (you can fire mid-reload).
return {
	List = {
		revolver = {
			name = "Service Revolver", slot = "sidearm", ammo = "pistolAmmo",
			mag = 6, damage = 38, headMult = 2.5, pellets = 1,
			fireDelay = 0.42, reload = 2.5, range = 180,
			spreadHip = 5.2, spreadAim = 0.7, moveSpread = 3.4, recoil = 3.7,
			impact = 1.2, recoilPattern = { 0.15, -0.2, 0.25, -0.1, 0.2, -0.25 }, adsTime = 0.24,
			noise = 75, aimFov = 52,
		},
		rifle = {
			name = "Bolt Rifle", slot = "long", ammo = "rifleAmmo",
			mag = 4, damage = 95, headMult = 2.2, pellets = 1,
			fireDelay = 1.25, reload = 3.4, range = 320,
			spreadHip = 9.1, spreadAim = 0.12, moveSpread = 5.4, recoil = 8.0,
			impact = 2.2, recoilPattern = { 0.1 }, adsTime = 0.38,
			noise = 115, aimFov = 42,
		},
		carbine = {
			name = "Lever Carbine", slot = "long", ammo = "rifleAmmo",
			mag = 6, damage = 55, headMult = 2.0, pellets = 1,
			fireDelay = 0.55, reload = 3.6, range = 240,
			spreadHip = 6.5, spreadAim = 0.4, moveSpread = 4.1, recoil = 5.2,
			impact = 1.4, recoilPattern = { 0.2, 0.3, -0.1, 0.35, 0.1, -0.2, 0.3 }, adsTime = 0.3,
			noise = 95, aimFov = 48,
		},
		shotgun = {
			name = "Pump Shotgun", slot = "long", ammo = "shells",
			mag = 4, damage = 16, headMult = 1.5, pellets = 9, falloff = true, perShell = true,
			fireDelay = 0.95, reload = 3.6, range = 55,
			spreadHip = 9.8, spreadAim = 5, moveSpread = 2.7, recoil = 9.2,
			impact = 2.6, recoilPattern = { -0.25, 0.3, -0.2, 0.25 }, adsTime = 0.32,
			noise = 100, aimFov = 56,
		},
		bow = {
			name = "Recurve Bow", slot = "long", ammo = "arrows",
			mag = 1, damage = 70, headMult = 2.2, pellets = 1, autoReload = true,
			fireDelay = 0.85, reload = 0.7, range = 220,
			spreadHip = 3.9, spreadAim = 0.35, moveSpread = 2.0, recoil = 1.7,
			impact = 1.6, recoilPattern = { 0 }, adsTime = 0.34,
			noise = 5, aimFov = 50, projectile = { speed = 170, gravityScale = 0.35 },
		},
	},
	Order = { "revolver", "carbine", "rifle", "shotgun", "bow" },
	LongGuns = { "carbine", "rifle", "shotgun", "bow" },
	SwapTime = 0.6, -- holster <-> hands
	PackSwapTime = 2.4, -- digging a gun out of the backpack (TLOU-style holster system)
	HeadshotNoiseMult = 1,
}
