# Foundry Highlands

A 3,577-stud closed stone track with a 59.625-stud road width. After the upper approach reaches about 156 studs, the wide right sweeper rolls up to a 60° bank. The cross-bank eases back to level before the road rejoins the original lower U. The rebuilt curve matches the curvature of the road at both connections.

The continuous opaque deck fills the joins beneath the source stone courses. The updated paving uses the original stone UVs and darker gray mortar. Native stone pieces fill the broad border gaps, and the walls follow the new sweep from the banked apex to the level exit.

Import `FoundryHighlands.glb` in Roblox Studio as one Model with separate MeshParts at the original track scale. If Studio shifts the model on import, line up `FoundryHighlandsPavingBase001` on the bottom straight with the same MeshPart in the previous model.

With Play stopped, run `ApplyFoundryHighlandsAppearance.command.luau` in the Command Bar. The command copies available paving and wall textures from an original track or a textured Foundry Switchbacks model in Workspace. It uses the original slate atlas for the grout when a suitable reference is available and a darker gray tint otherwise. You can select an original textured model to give it priority.
