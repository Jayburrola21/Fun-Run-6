# Fitted Fun Run 6 bend

[Download the bend](FunRun6-ContinuousTrackBend.glb) · [Preview the geometry](ContinuousBendPreview.png) · [Download the Studio placement command](PlaceTrackBend.command.luau)

This replacement connects the two straights in the uploaded `Track` model. It matches their driving heights and widths, roughly 63 studs at both ends. The paving and brick faces keep their original UVs. The gaps between the stones use the same gray grout sampled from the original slab joints. The wall bodies and beveled caps follow both sides of the bend and meet the straight wall lips.

## Install in your test place

1. In Studio Edit mode, import **FunRun6-ContinuousTrackBend.glb** as a model through the **3D Importer**. Turn **Merge Meshes** off so the placement markers and material groups stay separate.
2. Select the imported bend model and the original **Track** model in Explorer.
3. Copy the full updated placement command into the **Command Bar** and run it. It aligns the new section, applies the original stone texture and tints, and adds a level driving surface.

The same steps work for a fresh install and an update. On a fresh install, the command fits the paving and walls at both joins, trims the two inside canal ends, and saves the original corner in **ServerStorage → Fun Run 6 Original Bend**. To update an installed bend, leave it in place and select the new import and **Track**. The command moves the previous bend to **ServerStorage → Fun Run 6 Original Bend → Previous Bend Models**. Studio groups the installation in Undo when change history is available.

Selecting only the imported bend runs placement and styling for a fit preview. The Blender preview shows the geometry with gray materials. The Studio command applies the original Roblox atlas.

## Rebuild

With the original Studio export, run `blender -b --python-exit-code 1 --python build_track_bend.py -- Track.obj FunRun6-ContinuousTrackBend.glb` from this directory. The Studio command applies the existing texture asset `2913129928` to the preserved UVs.
