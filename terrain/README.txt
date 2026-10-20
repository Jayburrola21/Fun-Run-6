USE CandyTerrain.glb — this replaces the ZIP workflow.

In Roblox Studio choose File > Import (Ctrl+M), select CandyTerrain.glb, then import the entire scene as one model. All 24 mesh sections are already positioned relative to each other. Do not import the old individual OBJ tiles.

Keep the original imported positions and scale, and disable any option that inserts at the current camera or selection location if shown. Check the assembled model against the existing trail before removing old ground. Anchor the whole imported model. Replace only the large flat ground block Part1; keep all trail pieces. Save a backup first.

This is one self-contained GLB scene with embedded geometry and mint material; no external assets or MTL files are needed. It imports through the 3D importer, not Import Roblox Model. Geometry uses the original candy.obj coordinates, Y up. If Studio changes the unit conversion, match the assembled model to the original base footprint (880 by 1410.803 original units) as a whole.

The terrain follows the trail elevation and blends back into flat surrounding ground. Geometry and GLB structure were checked here; Roblox Studio import and playtesting have not been performed. This is mesh ground, not editable voxel Terrain.

source/candy.obj is the untouched source export. The ZIP is retained as an older alternative.
