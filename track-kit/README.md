# Fun Run 6 modular track kit

For the corner in the original place, use the [fitted continuous bend](CONTINUOUS-BEND.md).

[Download the Roblox model](FunRun6-TrackKit.rbxm) · [Preview the six sections](TrackKitPreview.png)

The kit contains **64- and 128-stud straights** and **left and right 45° and 90° curves**. Each section is a separate model with a 63-stud driving width, a level deck, and stone walls on both sides. The curves use a 64-stud centerline radius.

The paving keeps the original mesh and shared texture references, both gray tints, the smaller border rows, and the staggered center. The walls use the original `Wall_Quarter_01` brick mesh. Fitted stock tiles make tapered grout joints at curves. A separate, flat collision deck runs below the visible stonework so the joints stay smooth to drive over.

## Place and connect sections in Studio

1. In Edit mode, insert **FunRun6-TrackKit.rbxm** through **Insert from File**. Expand **Fun Run 6 Track Kit** in Explorer to find the six models.
2. Duplicate the pieces you want to use. Place the first one where the track starts. Each model's pivot is the center of its entrance at road level. The uploaded track's usual floor height is about **Y 27.10**.
3. In Explorer, click the section already in place, then Ctrl-click or Cmd-click the next section. Paste the full [snap command](SnapTrackSection.command.luau) into the Command Bar and run it.
4. The new section's **TrackIn** snaps to the placed section's **TrackOut**. The new section stays selected so you can add the next one. A snap is a single undoable edit.

Studio uses the same Roblox asset references as the uploaded track when it renders the paving and brick walls.

## Rebuild the model

Run `python3 build_track_kit.py --output FunRun6-TrackKit.rbxmx` from this directory to generate a Studio-importable XML model. The distributed binary uses Rojo to serialize that model.
