# Standalone 90° track curve

[Download the curve GLB](FunRun6-StandaloneTrackCurve.glb) · [Blender preview](StandaloneCurvePreview.png) · [Studio styling command](StyleStandaloneTrackCurve.command.luau)

The model has a 62.95-stud driving width, a 47-stud centerline radius, and a 4-stud straight section at each end. The floor, brick walls, and top caps end on the same flat face at both connections. The inside border uses fewer repeats of the original chipped stones so their proportions stay close to the outside border. The preview uses gray materials to show the geometry.

## Import into Studio

1. In Edit mode, import **FunRun6-StandaloneTrackCurve.glb** as a model through the **3D Importer**. Turn **Merge Meshes** off to preserve the material groups and collision meshes.
2. Select only the imported curve model in Explorer and run the full **Studio styling command** in the Command Bar. It applies the original stone texture and enables the hidden driving and wall colliders.
3. Move and rotate the curve as one model. Connect your straight pieces at the flat ends of the walls and floor.

## Rebuild

From this directory, run `blender -b --python-exit-code 1 --python build_standalone_curve.py -- Track.obj FunRun6-StandaloneTrackCurve.glb` with the original Studio OBJ export.
