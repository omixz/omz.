--!nonstrict
-- Realistic characters. Three ways to give a crew member a realistic body, best first:
--   1. Custom rig: put an R15-compatible Model named e.g. "Mara" in ServerStorage > Rigs
--      (made in Blender from a MakeHuman/your own mesh, then Studio's Avatar Setup tool).
--      It must contain a Humanoid + HumanoidRootPart. Put a copy of the default "Animate"
--      LocalScript inside it, or set the animation IDs below.
--   2. Body parts: Marketplace body-part asset IDs for a HumanoidDescription (Rthro-style
--      realistic bodies, FACS heads). Set them under BodyParts.
--   3. Neither: the faceless placeholder mannequin (Slice 0 default).
-- See docs/07-characters-and-graphics.md for the free pipeline. Never import models of
-- characters from other games (copyright).
return {
	Custom = {
		mara = "Mara",
		tobias = "Tobias",
		ines = "Ines",
		sefa = "Sefa",
	},
	BodyParts = {
		-- example: mara = { Head = 0, Torso = 0, LeftArm = 0, RightArm = 0, LeftLeg = 0, RightLeg = 0 },
	},
	-- Uploaded animation IDs ("rbxassetid://123"). Used for custom rigs without an Animate script.
	Animations = {
		idle = "",
		walk = "",
		run = "",
		crouchIdle = "",
		crouchWalk = "",
	},
}
