# Yamaha YZF-R7

Editable black Yamaha YZF-R7 model built from the supplied visual references. The bike measures **2,056 × 704 × 1,161 mm** (length × width × height) with a **1,395 mm wheelbase**. Model coordinates place the axles on X, the nose toward −Y, and up toward +Z in Blender.

## Files

| File | Contents |
| --- | --- |
| [Yamaha_R7_Detailed.blend](dist/Yamaha_R7_Detailed.blend) | Editable Blender project with 17 named assembly collections, separate component geometry, materials, and a studio preview scene. |
| [Yamaha_R7_Roblox.fbx](dist/Yamaha_R7_Roblox.fbx) | Motorcycle geometry in FBX with applied mesh modifiers, UVs and normals, one material per mesh, and separate front/rear wheel and steering groups. |
| [Preview sheet](dist/R7_Preview_Sheet.jpg) | Three-quarter, front, rear, rider-left, rider-right, and top views. Full-resolution PNGs are in `dist/previews/`. |

The model includes physical tread grooves, perforated front and rear discs, separate calipers, a modeled chain and sprockets, CP2-style engine and covers, headers, clip-ons, a modeled instrument cluster, and geometric Yamaha and R7 graphics. Lighting elements are static lenses and material surfaces.

## Roblox Studio import

1. Open **3D Importer** and select `Yamaha_R7_Roblox.fbx`. Import it as a model and keep the child meshes. The file uses meter units, +Y up, and a nose facing −Z in FBX coordinates.
2. Check the full assembly scale in the importer. At 0.28 m per stud, the model should be about **7.34 studs long**, **2.51 studs wide**, and **4.15 studs high**. If Studio applies a different unit convention, uniformly scale the assembled model against those dimensions.
3. Use the `R7_FrontWheel__*`, `R7_RearWheel__*`, and `R7_FrontForks__*` names to identify wheel and steering meshes. The FBX carries axle or steering origins for these groups. The side panels, lights, handlebars, and swingarm are also separately identified.
4. Compare the surfaces with the Blender previews after importing. The FBX includes named material colors. Match the smoke windshield with approximately 0.6 transparency if needed, and set metallic, roughness, or neon finishes in Studio to reproduce Blender's shading. Blender's procedural rubber and seat grain is in the editable project.

The full-detail mesh is intended for close viewing. The FBX contains 243,612 triangles across 103 meshes, with at most 9,500 triangles in any one mesh. It was round-tripped in Blender to check mesh counts, UVs, scale, pivots, and evaluated vertex positions. Roblox Studio import and its rendered appearance still need an in-Studio check.

## Rebuild and verify

From `motorcycle-r7/` with Blender 4.3 or later:

```sh
blender -b --python-exit-code 1 --python tools/build_r7.py
blender -b --python-exit-code 1 --python tools/verify_r7.py
```

Add `-- --views` to the build command to generate the model files only. Use `-- --out /tmp/r7-draft --draft --views three-quarter front` for small comparison renders without changing the deliverable models. To reproduce the denoised previews, pass `-- --denoiser /path/to/oidnDenoise`, or omit the flag to render with Blender alone.
