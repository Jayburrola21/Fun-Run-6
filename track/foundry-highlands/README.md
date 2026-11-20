# Foundry Highlands

A 3,455-stud closed stone track with a 59.625-stud road width. The upper approach climbs to 156 studs, about 64 studs above the previous bench. The new 64° right turn banks up to 62.5° and rolls back to level across the road as it drops into the original infield sweep. The lower route, including the bottom straight and right-hand branch, keeps its original alignment.

The continuous opaque deck fills the joins beneath the source stone courses. The updated paving uses the original stone UVs and darker gray mortar. Native stone pieces fill the broad border gaps, and the center pattern flows through the rebuilt turns.

Import `FoundryHighlands.glb` in Roblox Studio as one Model with separate MeshParts at the original track scale. If Studio shifts the model on import, line up `FoundryHighlandsPavingBase001` on the bottom straight with the same MeshPart in the previous model.

With Play stopped, run `ApplyFoundryHighlandsAppearance.command.luau` in the Command Bar. The command copies available paving and wall textures from an original track or a textured Foundry Switchbacks model in Workspace. It uses the original slate atlas for the grout when a suitable reference is available and a darker gray tint otherwise. You can select an original textured model to give it priority.
