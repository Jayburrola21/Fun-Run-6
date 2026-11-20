# Foundry Switchbacks

An original 1,597-stud closed course with eight wide bends, two changes of drift direction, and a 59.63-stud deck. The course uses all six original straight kit pieces twice and reuses the wide bend from commit `172fa58`. The source stone geometry and UVs are retained. Small vertical corrections level the joins, and two short end gaps in the original straight are filled with matching stone.

The preview shows the included start and finish markings in the circuit’s preview colors. The original OBJ exports carry UVs and material slots. Studio can copy the actual appearances from your textured source meshes. `MAINTRACK.obj` exceeded the workspace’s transfer limit, so this circuit was assembled from the earlier track exports.

## Studio setup

1. Import `FoundrySwitchbacks.glb` as one model with separate MeshParts at the original track scale. Position the model before installing the rig.
2. In Explorer, right-click **Workspace** and use **Insert from File** to insert `FoundrySwitchbacks_Rig.rbxmx`.
3. With Play stopped, select the imported track model. Paste all of `InstallDriftCircuit.command.luau` into the Command Bar and run it. The command fits the collision deck and guardrails to the mesh and registers the nine checkpoints, path, and six kart spawn positions for Fun-Run-6’s KartSystem. Existing `KartRace` and `KartSpawns` objects are moved into **ServerStorage → Before Foundry Switchbacks**.
4. With your original textured track in Workspace, run `ApplyDriftCircuitAppearance.command.luau` to apply its slate, dark paving, and wall materials. You can also select the original to give its appearances priority.

`Route.json` records the piece placements, racing direction, checkpoints, and drift entry and apex positions.
