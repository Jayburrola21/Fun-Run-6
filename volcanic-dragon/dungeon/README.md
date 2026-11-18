# Broken Dungeon Cave

A Blender-built stone cave that curves back to a rounded end. Weathered gray masonry covers the front arch, sides, roof, interior, and rear. The iron gate keeps its side bars and cross rails, with uneven torn bars pulled outward around the dragon's head.

[Download the GLB](DragonDungeonCave.glb) · [Front preview](DungeonCavePreview.png) · [Rear preview](DungeonCaveRear.png)

## Place it in Roblox Studio

1. In your test place, move the previous cave and gate aside. Open the **3D Importer** and import `DragonDungeonCave.glb` as a model. Keep the texture import enabled. The GLB contains the cave and gate assemblies.
2. Match the cave's scale to the Volcanic Dragon. Align the doorway behind the snout with the cave floor just below the claws. At the original rig scale, the doorway is about 4.4 studs forward of the dragon's authored origin. The preview shows this fit.
3. Anchor the imported cave pieces. For a decorative cave, set their `CanCollide` and `CanQuery` to false so Studio's generated collision shape stays clear of the opening and the dragon's fire ray. Press **Play** in your test copy and watch the first sweep.

The masonry was recreated from the supplied wall panel's style. The GLB embeds the stone color and normal maps and the weathered metal texture.

## Rebuild in Blender

Run `blender -b --python-exit-code 1 --python build_dungeon_cave.py` from this directory. The script builds the cave and calls `dungeon_gate.py` to model the ironwork.
