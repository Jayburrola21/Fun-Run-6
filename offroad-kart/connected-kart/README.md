# Connected off-road kart

Import [OffroadKart_Connected.glb](OffroadKart_Connected.glb) with Studio's **3D Importer**. Keep the named meshes separate. The GLB includes smaller wheels with black steel rims, black front and rear bumper rails, red side panels that curve upward near the rear, and lens colors.

[View the preview](OffroadKart_Connected_Preview.png) · [Open the Blender project](OffroadKart_Connected.blend)

## Lights in Roblox Studio

Use either setup method with a new import or the kart already in your place.

- **Set up the lights without pasting code.** Use Studio's **Insert from File** to insert [OffroadKartLights.rbxmx](OffroadKartLights.rbxmx). In Explorer, place the resulting **OffroadKartLights** Script directly inside the imported kart Model in Workspace. Save the place and press Play. The script installs the lights on startup.
- **See the lights in Edit mode.** Stop Play, select the kart's outer **Model** in Explorer, and paste the full contents of [SetupKartLights.command.luau](SetupKartLights.command.luau) into Studio's **Command Bar**. Press Enter and look for **Kart lights ready** with four lens names marked **on** in Output. Save the place to keep the lights and brake controller.

The setup clears imported finishes from the four lens meshes so they can render as Neon. It also mounts forward-facing headlights and rear-facing red SpotLights. For a quick visual check, look at the floor in front of the kart and just behind it. Imported lens colors alone are the static preview.

The rear lights glow red while running and brighten when an occupied **VehicleSeat** applies opposite throttle while the kart is moving. A custom chassis can set the Model's Boolean `Braking` attribute to drive the same effect. The optional Boolean `HeadlightsEnabled` and `TaillightsEnabled` attributes switch each bank in Play.

Both setup paths were compiled and exercised with Luau test doubles. Verify the result in Studio after setup.
