# Standalone straight track

[Download the straight-track GLB](FunRun6-StandaloneStraightTrack.glb) · [Blender preview](StandaloneStraightPreview.png) · [Studio styling command](StyleStandaloneStraightTrack.command.luau)

The model retains the uploaded `Trackmain.obj` paving groups, geometry, and UVs. Both long sides have the curve's double-sided brick detail and beveled caps. The clear width between the walls matches the curve at 62.95 studs. The entrance and exit are open.

1. In Studio Edit mode, import the GLB as a model with **Merge Meshes** off.
2. Select only the imported straight-track model and run the full styling command in the **Command Bar**. It applies the original stone atlas and tints and enables the two wall colliders.
3. Move or rotate the model to connect it to your curve.

The OBJ referenced an external material file. The Studio command uses the two corresponding material groups and shared atlas from the original track. The preview uses neutral gray materials to show the geometry.

## Single wall piece

[Download the wall GLB](FunRun6-StandaloneTrackWall.glb) · [Wall preview](StandaloneTrackWallPreview.png) · [Wall styling command](StyleStandaloneTrackWall.command.luau)

The wall imports as one mesh with brickwork on both faces and the same beveled cap as the track. Select the imported wall and run its styling command in Studio. Duplicate it and move the copy **10.168 studs along the wall's length** to place it end to end.

## Rebuild

From this directory, run `blender -b --python-exit-code 1 --python build_standalone_straight.py -- Trackmain.obj FunRun6-StandaloneStraightTrack.glb`.

To rebuild the single wall, run `blender -b --python-exit-code 1 --python build_standalone_wall.py -- Trackmain.obj FunRun6-StandaloneTrackWall.glb`.
