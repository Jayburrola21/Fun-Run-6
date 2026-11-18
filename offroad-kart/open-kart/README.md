# Open off-road kart

[Preview the open kart](OffroadKart_Open_Preview.png) · [Import the GLB](OffroadKart_Open.glb) · [Edit the Blender model](OffroadKart_Open.blend)

If you already imported the polished kart, the Studio command below updates it in place.

## Roblox Studio setup

1. For a new import, open Studio's **3D Importer**, choose `OffroadKart_Open.glb`, and keep the named meshes as separate parts. For an existing import, start with the kart already in your place.
2. With Play stopped, select the kart's outer **Model** in Explorer. Open the **Command Bar**, paste all of [SetupKartLights.command.luau](SetupKartLights.command.luau), and run it.
3. Save the place. Start Play to check the forward headlights and the rear lamps. The rear lamps have a dim running glow and brighten when braking.

On the existing polished import, the command removes the named red cage tubes and roof lamp assemblies in place. It keeps the red bodywork, suspension coils, and spoiler. The four lens meshes receive Neon finishes and directed SpotLights. The command also installs a server Script in the kart Model and supports Studio Undo and repeated setup runs.

## Brake signal

With a Roblox **VehicleSeat** inside the kart Model, the rear lamps brighten when an occupied seat applies opposite throttle while the kart is moving. For a custom chassis, set the kart Model's Boolean **Braking** attribute from its server-side brake logic. Set it to `true` while braking and `false` on release. Clear that attribute to return to VehicleSeat detection.

The optional Boolean Model attributes **HeadlightsEnabled** and **TaillightsEnabled** let you switch each bank in Play. Both banks default to enabled.

The installation and brake logic were compiled and exercised with Luau test doubles. Verify the appearance and seat behavior in your Studio place after import.
