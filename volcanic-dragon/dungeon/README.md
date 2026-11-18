# Broken Dungeon Cave

A plain charcoal-gray cave with a tall, angular opening, a beveled entrance, and a shallow shell that curves down into a rounded back. The dark gray gate has longer torn bars overhead and broken lower ends above both claws. The upper side bars and rails remain attached to the arch.

[Download the GLB](DragonDungeonCave.glb) · [Front preview](DungeonCavePreview.png) · [Rear preview](DungeonCaveRear.png)

## Place it in Roblox Studio

1. In your test place, move the previous cave and gate aside. Use Studio's **3D Importer** to import `DragonDungeonCave.glb` as a model with **Merge Meshes** turned off. The cave uses solid gray materials.
2. Match the cave's scale to the Volcanic Dragon. Set the floor just below the claws and slide the cave toward the dragon's body until both sets of claws project beneath the snapped side bars. At the original rig scale, the Blender preview places the doorway about 3.5 studs forward of the dragon's authored origin.
3. Anchor the imported cave pieces. For a decorative cave, set `CanCollide` and `CanQuery` to false so the generated collision shape stays clear of the opening and the dragon's fire ray. Press **Play** in your test copy and watch the first sweep.

### Apply the colors in Studio

Select the shell MeshPart in Explorer to darken just the cave, or select the full cave model to color the shell and gate. Copy the full [color fix](ApplyDungeonCaveColors.command.luau) into Studio's Command Bar in Edit mode and run it once. Click off the selection to see the new shade.

You can also set **Color** in Properties to RGB `84, 84, 84` for the shell and `61, 61, 61` for all three gate meshes. Use **SmoothPlastic** for a plain finish.

## Rebuild in Blender

Run `blender -b --python-exit-code 1 --python build_dungeon_cave.py` from this directory. The script builds the cave and calls `dungeon_gate.py` to model the gate.
