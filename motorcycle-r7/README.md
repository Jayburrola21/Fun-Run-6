# Yamaha YZF-R7

Editable black Yamaha YZF-R7 model built from the supplied visual references. The bike measures **2,005 × 704 × 1,156 mm** (length × width × height) with a **1,395 mm wheelbase**. Model coordinates place the axles on X, the nose toward −Y, and up toward +Z in Blender.

## Geometry refinement

The symmetrical front cowl joins the nose and cheeks into one shell and retains separate recesses for the projector and running lights. The upper intake liner, curved radiator guides, and arched closeout back the fairing around the forks and lead the central opening into the radiator. A molded inner deck follows the windscreen and side cowl and supports the repositioned instrument pod.

The fuel tank crown is about 50 mm lower and the shoulders about 44 mm narrower than the previous mesh. The cap and badges seat on the revised crown, and the fitted lower trim follows the tank into the original saddle. The tank, nose, side fairings, front fender and tail use deep glossy metallic black paint. The recessed tail-tidy carrier holds the rear indicators close to the integrated taillight and pillion seat.

The front wheel is centered between parallel forks spaced 208 mm apart. The Blender verifier checks the repaired sightlines, open radiator inlet, outward-facing closed panels, and stationary clearance against the front wheel, fork and handlebar meshes. The assembly clears every tested position through ±15°. The first sampled contact is between the tank and upper triple clamp at 20°.

## Files

| File | Contents |
| --- | --- |
| [Yamaha_R7_Roblox.glb](dist/Yamaha_R7_Roblox.glb) | Recommended Roblox import. Embedded base color and metallic/roughness maps, seat and tire normal maps, and tinted lenses. |
| [ApplyR7Materials.command.luau](tools/ApplyR7Materials.command.luau) | Optional one-time Studio Command Bar fallback for meshes that come in without their finishes. |
| [Yamaha_R7_Detailed.blend](dist/Yamaha_R7_Detailed.blend) | Editable Blender project with 17 named assembly collections, separate component geometry, materials, and a studio preview scene. |
| [Yamaha_R7_Roblox.fbx](dist/Yamaha_R7_Roblox.fbx) | Motorcycle geometry in FBX with applied mesh modifiers, UVs and normals, one material per mesh, and separate front/rear wheel and steering groups. |
| [Preview sheet](dist/R7_Preview_Sheet.jpg) | Direct front and rear, both side profiles, front and rear three-quarter, cockpit, top and low-front underside. Full-resolution PNGs are in `dist/previews/`. |

The model includes physical tread grooves, perforated front and rear discs, separate calipers, a modeled chain and sprockets, CP2-style engine and covers, headers, clip-ons, a modeled instrument cluster, and geometric Yamaha and R7 graphics. Lighting elements are static lenses and material surfaces.

## Roblox Studio import

1. Download [Yamaha_R7_Roblox.glb](dist/Yamaha_R7_Roblox.glb). In Roblox Studio, open **File → Import 3D** and select it. Import it as a model with its named child meshes.
2. Check the scale. At 0.28 m per stud the assembled model is about **7.16 studs long**, **2.51 studs wide**, and **4.13 studs high**. The GLB uses meters, +Y up, and the nose facing −Z.
3. If the model still looks white, select the imported bike in **Explorer**. Open **View → Command Bar**, paste the contents of [ApplyR7Materials.command.luau](tools/ApplyR7Materials.command.luau), and press **Enter**. Use the Command Bar while editing the place. The command sets colors, Roblox materials and lens transparency on named MeshParts. It also works on the supplied FBX if you already imported it.

The GLB contains 103 meshes, 24 materials and 50 embedded PNG maps. Front and rear wheel and steering meshes retain separate names and pivots. The GLB passed geometry and texture checks and reimported in Blender. Visual appearance and texture handling in Roblox Studio still need an in-Studio check.

To update an existing place, import the revised asset alongside the original. Preserve the original model pivot and scale when positioning it, and transfer any place-specific attachments to their matching assembly before replacing the older import. The fallback command only assigns finishes to untextured named parts.

## Rebuild and verify

From `motorcycle-r7/` with Blender 4.3 or later:

```sh
blender -b --python-exit-code 1 --python tools/build_r7.py
blender -b --python-exit-code 1 --python tools/verify_r7.py
python3 tools/verify_glb.py
```

Add `-- --views` to the build command to generate the model files only. Add `-- --glb-only` to export from the existing Blender project and leave the previews and FBX in place. Use `-- --out /tmp/r7-draft --draft --views three-quarter front` for small comparison renders without changing the deliverable models. To reproduce the denoised previews, pass `-- --denoiser /path/to/oidnDenoise`, or omit the flag to render with Blender alone.
