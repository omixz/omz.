--!nonstrict
-- The crew. Each character has a signature ability, a starting loadout, an innate perk and a
-- choice of ONE starting perk. All characters are free to play (docs/03-monetisation.md).
--
-- Perk modifier keys (see Shared/Stats.luau for defaults):
--   noiseMult, crouchNoiseMult, waterNoiseMult, takedownTimeMult, shoveCooldownMult, healMult,
--   throwCapBonus (+n), damageTakenMult, abilityCooldownMult, abilityRadiusMult,
--   abilityDurationMult, sprintSpeedMult, reviveHPBonus (+n), bleedOutBonus (+s),
--   throwNoiseMult, craftTimeMult, craftYieldBonus (+n on traps/spikes/arrows),
--   ammoBonus (+n starting revolver rounds), aimSpreadMult
-- loadout.weapons = { long = <Weapons id>, sidearm = <Weapons id> }; loadout.items = reserve ammo + items.

local Characters = {}

Characters.Order = { "mara", "tobias", "ines", "sefa" }

Characters.List = {
	mara = {
		name = "Mara Kell",
		role = "Stealth & scouting",
		bio = "Former harbour pilot. Reads the fog like a tide chart.",
		height = 1.02,
		colors = {
			skin = Color3.fromRGB(198, 160, 130),
			torso = Color3.fromRGB(58, 76, 84), -- oilskin teal
			arms = Color3.fromRGB(58, 76, 84),
			legs = Color3.fromRGB(48, 46, 42),
		},
		ability = {
			id = "TideSense",
			name = "Tide Sense",
			desc = "Salt glints reveal every Hushed nearby, through walls, for a few seconds.",
			cooldown = 25,
			radius = 70,
			duration = 4,
		},
		loadout = {
			weapons = { long = "bow", sidearm = "revolver" },
			items = { arrows = 6, pistolAmmo = 6, bottle = 2, dressing = 1, cloth = 1 },
		},
		innate = {
			id = "ShallowStep",
			name = "Shallow Step",
			desc = "Wading makes no extra noise.",
			mods = { waterNoiseMult = 0 },
		},
		perks = {
			{ id = "QuietHands", name = "Quiet Hands", desc = "Quietings are 40% faster.", mods = { takedownTimeMult = 0.6 } },
			{ id = "LongSense", name = "Long Sense", desc = "Tide Sense reaches 50% further.", mods = { abilityRadiusMult = 1.5 } },
			{ id = "LightFoot", name = "Light Foot", desc = "Crouched movement is 30% quieter.", mods = { crouchNoiseMult = 0.7 } },
		},
	},

	tobias = {
		name = "Tobias Ruane",
		role = "Traps & distraction",
		bio = "Ferry engineer. Kept the Meridian's generator alive for eleven years.",
		height = 1.05,
		colors = {
			skin = Color3.fromRGB(150, 108, 82),
			torso = Color3.fromRGB(112, 74, 44), -- canvas work jacket
			arms = Color3.fromRGB(112, 74, 44),
			legs = Color3.fromRGB(52, 58, 66),
		},
		ability = {
			id = "RattleBox",
			name = "Rattle Box",
			desc = "Set down a clockwork noisemaker that pulls Hushed to it.",
			cooldown = 30,
			radius = 36,
			duration = 9,
		},
		loadout = {
			weapons = { long = "shotgun", sidearm = "revolver" },
			items = { shells = 4, pistolAmmo = 6, scrap = 2, tape = 1, saltBomb = 1, bottle = 1 },
		},
		innate = {
			id = "Tinkerer",
			name = "Tinkerer",
			desc = "Crafts twice as fast. Salt Bombs, Tide Spikes and arrows craft +1.",
			mods = { craftTimeMult = 0.5, craftYieldBonus = 1 },
		},
		perks = {
			{ id = "LoudDecoy", name = "Loud Decoy", desc = "Rattle Box is heard 40% further away.", mods = { abilityRadiusMult = 1.4 } },
			{ id = "ThickSkin", name = "Thick Skin", desc = "Take 15% less damage.", mods = { damageTakenMult = 0.85 } },
			{ id = "SpareRounds", name = "Spare Rounds", desc = "Start with 6 extra revolver rounds.", mods = { ammoBonus = 6 } },
		},
	},

	ines = {
		name = "Ines Okafor-Hale",
		role = "Sustain & co-op support",
		bio = "Paramedic. Runs the Meridian's sick bay out of a car deck.",
		height = 0.98,
		colors = {
			skin = Color3.fromRGB(110, 76, 58),
			torso = Color3.fromRGB(122, 40, 38), -- faded medic red
			arms = Color3.fromRGB(122, 40, 38),
			legs = Color3.fromRGB(40, 44, 50),
		},
		ability = {
			id = "SteadyHands",
			name = "Steady Hands",
			desc = "Heal yourself and nearby crew, and breathe quietly for a few seconds.",
			cooldown = 35,
			radius = 15,
			duration = 6,
		},
		loadout = {
			weapons = { long = "rifle", sidearm = "revolver" },
			items = { rifleAmmo = 4, pistolAmmo = 6, dressing = 2, cloth = 1, alcohol = 1 },
		},
		innate = {
			id = "FieldMedic",
			name = "Field Medic",
			desc = "Healing +25%. Crew you revive get up with +30 HP.",
			mods = { healMult = 1.25, reviveHPBonus = 30 },
		},
		perks = {
			{ id = "Marksman", name = "Marksman", desc = "Aimed shots are 40% steadier.", mods = { aimSpreadMult = 0.6 } },
			{ id = "SecondOpinion", name = "Second Opinion", desc = "You bleed out 15 seconds slower.", mods = { bleedOutBonus = 15 } },
			{ id = "Triage", name = "Triage", desc = "Steady Hands recharges 25% faster.", mods = { abilityCooldownMult = 0.75 } },
		},
	},

	sefa = {
		name = "Sefa Talataina",
		role = "Control & escapes",
		bio = "Fisher and net-maker. Has never once lost a catch.",
		height = 1.0,
		colors = {
			skin = Color3.fromRGB(134, 94, 66),
			torso = Color3.fromRGB(150, 118, 52), -- mustard fishing smock
			arms = Color3.fromRGB(150, 118, 52),
			legs = Color3.fromRGB(56, 62, 58),
		},
		ability = {
			id = "ThrowNet",
			name = "Throw Net",
			desc = "Pin the Hushed in front of you for a few seconds. Pinned Hushed can be Quieted from any side.",
			cooldown = 28,
			radius = 25,
			duration = 5,
		},
		loadout = {
			weapons = { long = "carbine", sidearm = "revolver" },
			items = { rifleAmmo = 7, pistolAmmo = 6, bottle = 3, fogPot = 1, dressing = 1 },
		},
		innate = {
			id = "DeepPockets",
			name = "Deep Pockets",
			desc = "Carry one extra of every throwable.",
			mods = { throwCapBonus = 1 },
		},
		perks = {
			{ id = "StrongArm", name = "Strong Arm", desc = "Thrown bottles are heard 30% further away.", mods = { throwNoiseMult = 1.3 } },
			{ id = "HeavyNet", name = "Heavy Net", desc = "Throw Net pins 50% longer.", mods = { abilityDurationMult = 1.5 } },
			{ id = "SeaLegs", name = "Sea Legs", desc = "Sprint 8% faster.", mods = { sprintSpeedMult = 1.08 } },
		},
	},
}

return Characters
