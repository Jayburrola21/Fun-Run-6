# Volcanic cliff terrain

## MAINTRACK fit

[VolcanicCliffTerrain.glb](VolcanicCliffTerrain.glb) is the terrain overlay for the supplied `MAINTRACK.obj`. Its two slate shoulders follow about 947 studs of surveyed edge along the three exported road sections. A solid subgrade foundation joins the cliff faces. The two original road-module gaps remain visible above the rock, and the exit lanes remain open. The preview uses a black platform whose top is at Y=0. The terrain toe reaches Y=−0.10 to seat into that platform.

The GLB includes [VolcanicSlate.png](VolcanicSlate.png), a tiled brownish-gray slate texture. The [fit preview](MAINTRACK_CliffPreview.jpg) shows the terrain from above and from the side. Its road uses a neutral preview tint since the OBJ archive supplied geometry only. Blender geometry checks found zero intersections between the cliff and the 37 original road and wall groups.

Import the GLB with the original course's scale and coordinate origin. With the imported cliff model selected in Edit mode, run [OrganizeVolcanicCliff.command.luau](OrganizeVolcanicCliff.command.luau) in the Studio Command Bar. It anchors the selected cliff MeshParts and moves them into `Workspace.VolcanicCliffTerrain`.

## Rebuild or fit a different course

The Blender builder takes surveyed road-edge coordinates and the top elevation of the existing platform, then exports a terrain-only GLB. It works in Roblox OBJ coordinates (X, Y-up, Z) and leaves the reference course files untouched.

Use the outer boundary of the actual road or curb as the input. Record points along bends, banking and grade changes. Include the starting vertex only once on a closed loop. Set `outward` to the side on which the rock should grow when walking the listed points. Viewed from above with −Z up, a path toward −Z has its left side toward −X. Supply separate edge paths for separate exposed boundaries.

```json
{
  "platform_y": 0,
  "edges": [
    {
      "outward": "right",
      "closed": false,
      "points": [[0, 22, 0], [0, 24, -20], [7, 27, -40], [25, 29, -52]]
    }
  ]
}
```

The values above illustrate the format. For a textured export, add a root-level `"texture": "mountain.png"` pointing to the existing diffuse tile relative to the JSON file. Adjust `--tile-size` in studs to match the existing texture repeat.

Rebuild the MAINTRACK fit from the repository root:

```sh
cd track/volcanic-cliff
blender -b --python-exit-code 1 --python build_cliff.py -- MAINTRACK_CliffEdges.json \
  -o VolcanicCliffTerrain.glb --spacing 4 --flare-scale 4.5 \
  --edge-clearance 0.12 --tile-size 10 --foundation-y 4.44
```

If your platform top differs from Y=0, update `platform_y` in [MAINTRACK_CliffEdges.json](MAINTRACK_CliffEdges.json) and rebuild. After import, check alignment at both road joins, both ends, and the platform contact.
