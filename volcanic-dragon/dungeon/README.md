# Broken Dungeon Cave

A recessed stone cavern with a split iron gate, fitted around the existing Volcanic Dragon rig. Seven bent bar stubs hang from the arch. Two low stubs and fallen iron sit outside the opening where the dragon's claws rest.

[View the Blender preview.](DungeonCavePreview.png)

## Install in Roblox Studio

1. Open your test copy of the place in **Edit** mode. Move the old doorway and intact gate out of the way and position the dragon where you want its head to emerge.
2. Select the top-level dragon model. The installer also finds a single model named **VolcanicDragon** automatically.
3. Open [InstallBrokenDungeonCave.command.luau](InstallBrokenDungeonCave.command.luau) in a text editor. Copy the entire file into the Studio Command Bar and run it. The installer creates and selects **Dragon Dungeon Cave** in Workspace.
4. Press **Play** and watch the full fire sweep. The first attack starts at 20 seconds with the default dragon scripts.

The installer fits the doorway from the rig's bind pose, facing, and scale. All stone, arch, gate, and fallen iron pieces are editable Studio parts within the cave model. The entrance uses cool, faceted stone based on the supplied wall panel. You can keep that panel as a backdrop or extend the masonry around the new cave.

Move the cave and dragon together when repositioning the scene. Rerunning the installer selects the existing cave fitted to that dragon. After changing the dragon's scale, adjust the cave with Studio's Scale tool or move the old cave out of Workspace and run the installer again.

The default opening was checked against the shipped rig's head, horn, and claw motion through idle and the full fire sweep. Check clearance in Studio if your dragon uses a custom rig or a wider animation.
