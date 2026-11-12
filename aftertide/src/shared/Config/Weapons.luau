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
			fireDelay = 0.42, reload = 2.2, range = 180,
			spreadHip = 4, spreadAim = 0.7, moveSpread = 2.5, recoil = 3.2,
			impact = 1.2, recoilPattern = { 0.15, -0.2, 0.25, -0.1, 0.2, -0.25 }, adsTime = 0.16,
			noise = 75, aimFov = 52,
		},
		rifle = {
			name = "Bolt Rifle", slot = "long", ammo = "rifleAmmo",
			mag = 4, damage = 95, headMult = 2.2, pellets = 1,
			fireDelay = 1.25, reload = 3.0, range = 320,
			spreadHip = 7, spreadAim = 0.12, moveSpread = 4, recoil = 7,
			impact = 2.2, recoilPattern = { 0.1 }, adsTime = 0.3,
			noise = 115, aimFov = 42,
		},
		carbine = {
			name = "Lever Carbine", slot = "long", ammo = "rifleAmmo",
			mag = 7, damage = 55, headMult = 2.0, pellets = 1,
			fireDelay = 0.55, reload = 3.2, range = 240,
			spreadHip = 5, spreadAim = 0.4, moveSpread = 3, recoil = 4.5,
			impact = 1.4, recoilPattern = { 0.2, 0.3, -0.1, 0.35, 0.1, -0.2, 0.3 }, adsTime = 0.22,
			noise = 95, aimFov = 48,
		},
		shotgun = {
			name = "Pump Shotgun", slot = "long", ammo = "shells",
			mag = 4, damage = 16, headMult = 1.5, pellets = 9, falloff = true, perShell = true,
			fireDelay = 0.95, reload = 3.2, range = 55,
			spreadHip = 7.5, spreadAim = 5, moveSpread = 2, recoil = 8,
			impact = 2.6, recoilPattern = { -0.25, 0.3, -0.2, 0.25 }, adsTime = 0.24,
			noise = 100, aimFov = 56,
		},
		bow = {
			name = "Recurve Bow", slot = "long", ammo = "arrows",
			mag = 1, damage = 70, headMult = 2.2, pellets = 1, autoReload = true,
			fireDelay = 0.85, reload = 0.6, range = 220,
			spreadHip = 3, spreadAim = 0.35, moveSpread = 1.5, recoil = 1.5,
			impact = 1.6, recoilPattern = { 0 }, adsTime = 0.26,
			noise = 5, aimFov = 50, projectile = { speed = 170, gravityScale = 0.35 },
		},
	},
	Order = { "revolver", "carbine", "rifle", "shotgun", "bow" },
	LongGuns = { "carbine", "rifle", "shotgun", "bow" },
	SwapTime = 0.45,
	HeadshotNoiseMult = 1,
}
