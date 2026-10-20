Candy terrain replacement for Roblox Studio

Import the terrain_*.obj files through Studio's 3D Importer, keeping candy_terrain.mtl alongside them. Each tile has at most 8,192 triangles. Keep all tiles at their original shared coordinates; do not individually center them. Use the importer preview to check scale and alignment against the existing trail before confirming. The OBJ uses the same coordinates and units as your exported candy.obj.

Replace only the large flat ground block named Part1. Keep Floor1, Dirt1 through Dirt55, Part2, and Part3. Keep a backup of Part1 until alignment is verified. Anchor imported ground meshes. Set their material/color to your preferred mint ground if the importer does not apply the MTL.

This is a surface mesh, not Roblox voxel Terrain. It follows the exported trail elevation, sits approximately 0.6 units below the trail top, and blends to the original flat ground over 36 units beyond a 10-unit centerline shoulder. Tile boundaries share exact coordinates. Ends use the nearest endpoint height. The missing original candy.mtl does not affect geometry extraction.

Geometry checks passed; Studio import, exact collision behavior, and playtesting have not been performed. Set appropriate collision fidelity and test the slopes in Studio. Original source OBJ was not edited.
