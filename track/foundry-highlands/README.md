# Foundry Highlands

A 3,299-stud closed stone track with a 59.625-stud road width. The bottom straight and the right-hand branch keep their original position and geometry. The left side climbs through six reworked bends. The high bench rises another 8–11 studs and eases into a 42.5° bank. The new infield route drops 65 studs into a wide sweep, then climbs 46 studs to reach the original right-hand bend.

The continuous opaque deck fills the joins beneath the source stone courses. The straight border lines use darker gray mortar and the original grout UVs. The walls continue through the slopes and turns.

Import `FoundryHighlands.glb` in Roblox Studio as one Model with separate MeshParts at the original track scale. If Studio shifts the model on import, line up `FoundryHighlandsPavingBase001` on the bottom straight with the same MeshPart in the previous model.

With Play stopped, run `ApplyFoundryHighlandsAppearance.command.luau` in the Command Bar. The command copies available paving and wall textures from an original track or a textured Foundry Switchbacks model in Workspace. It uses the original slate atlas for the grout when a suitable reference is available and a darker gray tint otherwise. You can select an original textured model to give it priority.
