# TrackCC curve-to-straight repair

This is a replacement for the combined curve and straight from `trackcc.obj`. It replaces the small plain patch at the outside curb with fractured paving from the original straight and adds the two original-style walls along the straight. Their caps align with the curve at the joint.

Import `TrackCC_Repaired.glb` as one model with separate MeshParts, using the same scale as the original. The GLB origin is at the center of the curve-to-straight join. The alternate OBJ uses the original scene coordinates. Its join reference point is X −1041.55, Y 28.025, Z −23.6822.

With Play stopped, run `ApplyTrackCC.command.luau` in the Studio Command Bar to anchor the imported meshes and copy the available original paving and wall appearances. Keep the original textured track in Workspace as the reference, or select it together with the new model to choose which appearance to copy. The GLB contains the source UVs and preview colors.
