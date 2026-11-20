# Foundry Highlands

A 3,591-stud closed stone track with a 59.625-stud road width. The widened upper approach gives the road 77 more studs to roll into the 60° bank. The descent eases back to level across the road before rejoining the lower U. Both walls are half their previous height, measured from the local road surface.

The continuous opaque deck fills the joins beneath the source stone courses. The paving uses the original stone UVs and darker gray mortar. The shoulder inlay in the banked turn shares a MeshPart, material, and atlas range with the neighboring dark paving.

Import `FoundryHighlands.glb` in Roblox Studio as one Model with separate MeshParts at the original track scale. If Studio shifts the model on import, line up `FoundryHighlandsPavingBase001` on the bottom straight with the same MeshPart in the previous model.

Keep a textured previous Highlands model, original track, or Foundry Switchbacks model in Workspace. With Play stopped, select only the new Highlands model and run `ApplyFoundryHighlandsAppearance.command.luau` in the Command Bar. The previous Highlands model can have the same name as the new model. The command uses the slate atlas for grout when a suitable reference is available.
