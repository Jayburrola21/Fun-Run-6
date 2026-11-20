# Modular 90° track curve

Import `TrackCurve_Modular.glb` in Roblox Studio as one Model with separate MeshParts. Use the same import scale as the original track. The road is 59.63 studs wide, with a centerline radius of 68.01 studs. The entrance is at the model’s local origin, and the exit points 90° from the entrance.

1. With Play stopped, select the imported Model in Explorer. To copy the original track appearance, also select the original curve or straight Model in Workspace.
2. Paste all of the short `ApplyModularCurve.command.luau` into the Studio Command Bar and click **Run**. It anchors the model, enables the hidden deck and wall collision meshes, and applies the original appearance for each material it can match.
3. Check **Output** for 60 collision MeshParts, copied materials, and any missing material references. Use **Undo** to revert the setup when Studio supports it. The command still applies the setup if Studio declines the Undo recording.

The original square border modules measure approximately 12.13 × 12.13 studs. The wall panels and border modules are reproduced at their source scale. A continuous darker-gray grout bed fills the spaces between the square pavers on both borders. Low, rounded stones break up the wider gaps, and the setup commands keep the grout color separate from the original stone material. The interior paving is shaped to the new radius. The GLB includes preview colors and the source UVs. Its exact textures come from the original Studio MeshParts when the appearance is copied within the same place.

If the original meshes were renamed, the three `sourceNames` entries at the top of the full `SetupModularCurve.command.luau` command accept the exact Explorer names of the source MeshParts for slate, dark paving, and the wall. The OBJ is a geometry-only alternative in the original track’s scene coordinates.
