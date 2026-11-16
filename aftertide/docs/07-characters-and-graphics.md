# 7. Realistic Characters & High-End Graphics (US$0)

## 7.1 What "realistic, not a Roblox game" really takes

Code can't create realistic human bodies; those are **3D art**. What the code now does:

- **Loads custom rigs automatically.** Put a realistic, R15-compatible character model in
  `ServerStorage > Rigs` named `Mara`, `Tobias`, `Ines` or `Sefa` (names set in
  `src/shared/Config/Rigs.luau`), and that crew member spawns with it instead of the
  placeholder mannequin. Weapons, poses, crouching, aiming and all gameplay keep working.
- **Plays your animations.** If a rig has no `Animate` script, `AnimationController`
  blends idle / walk / run / crouch animations from the IDs in `Config/Rigs.Animations`.
- **Body-part option.** `Config/Rigs.BodyParts` accepts Marketplace body-part asset IDs
  (realistic body bundles, FACS heads) as a quicker middle step.

> **IP line:** realistic proportions, grounded clothing and a believable face are fine.
> A model that looks like **Ellie, Abby, Joel or any TLOU character** (face, tattoo,
> hairstyle, outfit, silhouette) is not, even if you make it yourself. See doc 4 §4.3.
> Never download "TLOU models" from model sites: they are ripped, copyrighted assets.

## 7.2 Free pipeline for a realistic crew member

1. **Base body:** **MakeHuman** (free; models you export are CC0, so commercial use
   is fine). Set realistic proportions, age and build to match the character sheet in doc
   1 §1.5. Export as FBX, using the "game engine" skeleton or none.
2. **Sculpt & clothe:** **Blender** (free). Give each character a distinct silhouette:
   Mara's oilskin coat and wool scarf, Tobias's canvas work jacket and tool belt, Ines's
   faded medic jacket, Sefa's mustard smock and rolled sleeves. Bake textures (cloth and
   leather from **ambientCG / Poly Haven**, CC0). Keep each character under about 10k
   triangles with **2K textures**. Roblox has memory limits, especially on phones.
3. **Rig for Roblox:** in Studio, **Avatar tab → Import 3D** (FBX), then **Avatar Setup**.
   It auto-rigs and skins the mesh to the R15 skeleton, so our crouch, aim and arm
   poses work. Check the joint names (`RightShoulder`, `LeftHip`, `Waist` and so on) are R15.
4. **Face:** Avatar Setup can create a FACS face for expressions. Keep it subtle and
   grounded. Avoid stylised cartoon faces.
5. **Install:** name the model `Mara` and move it to **ServerStorage → Rigs** (create the
   folder). It needs a `Humanoid` and a `HumanoidRootPart`.
6. **Animations (free):**
   - Easiest: press Play, open Explorer → Workspace → your character → copy **Animate** →
     Stop → paste it inside your rig. Roblox's default animations will play on the rig.
   - Better: record your own movement with **Animation Capture** (Studio animation editor →
     capture from video/webcam), clean it up in the Animation Editor, publish, and paste the
     IDs into `Config/Rigs.Animations` (idle, walk, run, crouchIdle, crouchWalk). Remove
     `Animate` from the rig so ours are used.
   - Mixamo animations are free; check Adobe's current terms before using them.
7. **Log it** in the asset register (doc 4 §4.4): MakeHuman (CC0), texture sources,
   your own sculpt.

Weapons follow the same idea: the code builds placeholder guns from parts
(`src/shared/WeaponModels.luau`). Replace them with Blender meshes, keeping the grip at
the origin and the barrel along −Z, and keep each design fictional, never a copy of a
specific real gun or of a TLOU weapon.

## 7.3 Graphics presets (built in)

`GraphicsController` applies a preset on every client. Change it in-game with **P →
Settings**.

| Preset | Default on | What it adds |
|---|---|---|
| **Cinematic** | PC (high graphics), PlayStation and Xbox | Depth of field that **focuses on what you aim at**, sun rays, filmic grade, stronger bloom, shadows on every practical light, denser ground fog, local mist and dust motes around the camera, heavy rain in a *Squall* |
| **Balanced** | Mid-range PCs | Light mist, standard shadows, no depth of field |
| **Performance** | Phones and tablets | No extra effects, about a third of the fog particles, fewer shadow-casting lights |

**Honest limits:** Roblox sets the base render quality from each player's own graphics
slider and device. A game can't force higher quality, can't write custom shaders, and has
no ray tracing or real volumetric fog. The presets are the most a Roblox game can add.

To push visuals further (Stage 2 art pass, all free):

- **PBR everywhere:** `SurfaceAppearance` on meshes and **MaterialVariants** (MaterialService)
  using CC0 PBR textures for concrete, rust, wet wood and salt crust.
- **Real meshes** instead of grey-box parts: modular cannery, container and dock kits in
  Blender, sharing texture atlases.
- **Lighting:** keep `Technology = Future`. Use a few strong practical lights (lanterns,
  flares, ferry bulbs) and a lot of darkness. That contrast reads as "next-gen" more than
  brightness does.
- **Atmosphere:** the Pall *is* the look. Tune `Atmosphere.Density/Haze` per modifier.
- **Audio:** half of perceived quality. Use reverb zones and a muffled low-pass when behind
  walls (Roblox Audio API, doc 2 §2.12).

## 7.4 PlayStation & Xbox

Roblox runs on PlayStation and Xbox, and the gamepad controls are already bound. Each
menu puts the gamepad cursor on its first button.

1. Creator Hub → your experience → **Configure** → find **Playable devices** (or "Devices")
   → tick **Console**. Menu names change; check Roblox's current docs if it isn't there.
2. Console experiences have extra content and UI rules (readable text at TV distance,
   full gamepad navigation, no off-platform links). Test with a controller in Studio first.
3. Console players default to the **Cinematic** preset.
