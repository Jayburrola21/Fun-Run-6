# Straight track kit

Six separate GLBs cut from the original `Track Straight.obj`. The five internal joins pass through the original cross-road bands of small stones. The halves meet when two neighboring pieces are assembled. The source's outer ends, walls, paving, UVs, and gentle slope are retained.

Import each GLB as a model with separate MeshParts at the same scale as the rest of your track. The approximate width across the wall caps is 60.60 studs. Orient the pieces in their original direction along local +X to reconstruct the original run.

| Piece | Length (studs) | Offset from the original entrance along +X (studs) |
| --- | ---: | ---: |
| `TrackStraight_01.glb` | 54.220 | 0.000 |
| `TrackStraight_02.glb` | 93.080 | 54.220 |
| `TrackStraight_03.glb` | 46.727 | 147.300 |
| `TrackStraight_04.glb` | 52.869 | 194.027 |
| `TrackStraight_05.glb` | 46.873 | 246.896 |
| `TrackStraight_06.glb` | 47.673 | 293.769 |

Offsets are measured between the GLB origins. Piece 02 spans two original runs so the other sections can end on the small-stone courses. For a different layout, align the deck height and wall profiles at each connection. The numbered order reproduces the original pattern exactly.

With Play stopped, select the kit models in Explorer. The command looks for the original straight’s slate, dark paving, and wall appearances in Workspace. You can also select the original straight to help identify those references. Paste all of `ApplyStraightKit.command.luau` into the Studio Command Bar and click **Run**. The script anchors the pieces and enables the three hidden collision meshes on each complete model. The GLBs and preview use placeholder colors until the original Studio appearances are copied.
