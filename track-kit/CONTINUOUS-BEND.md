# Fitted Fun Run 6 bend

[Download the bend](FunRun6-ContinuousTrackBend.glb) · [Preview the geometry](ContinuousBendPreview.png) · [Download the Studio placement command](PlaceTrackBend.command.luau)

This replacement connects the two straights in the original uploaded `Track` model. It matches their road heights and widths, roughly 63 studs at both ends. The paving and brick faces are deformed from the Studio OBJ export with their UVs. The wall bodies and beveled caps continue around the bend.

## Install in your test place

1. In Studio Edit mode, import **FunRun6-ContinuousTrackBend.glb** as a model through the **3D Importer**. Turn **Merge Meshes** off so the placement markers and material groups stay separate.
2. Select the imported bend model and the original **Track** model in Explorer.
3. Copy the full placement command into the **Command Bar** and run it. It checks the original corner against the uploaded placements, aligns the new section, applies the original stone texture and tints, and adds a level driving surface. It fits the clipped pieces at both joins and shortens the two adjoining inside canal ends to keep the driving area clear.

The command keeps the original corner parts in **ServerStorage → Fun Run 6 Original Bend**. Studio groups the installation in Undo when change history is available. Selecting only the imported bend runs placement and styling for a fit preview.

## Rebuild

With the original Studio export, run `blender -b --python-exit-code 1 --python build_track_bend.py -- Track.obj FunRun6-ContinuousTrackBend.glb` from this directory. The Studio command applies the existing texture asset `2913129928` to the preserved UVs.
