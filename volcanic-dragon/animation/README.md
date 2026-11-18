# Volcanic Dragon Fire Breath

A manually triggered Roblox Studio test for the existing volcanic dragon. The rigged GLB uses the latest dragon meshes and textures. Three weighted neck joints bend the neck while the torso and claws stay planted. The head turns first, followed by the upper, middle, and lower neck about 170, 280, and 390 milliseconds later.

## Test it in Roblox Studio

1. In Edit mode, use the **3D Importer** to bring in [VolcanicDragon_Rigged.glb](VolcanicDragon_Rigged.glb) as a skinned model. Put it in Workspace and name the top-level model **VolcanicDragon**. Keep the imported bones. Place it upright, facing the stretch of track you want it to sweep. Leave space above and alongside the head so it can lift and turn.
2. Open [InstallVolcanicDragon.command.luau](InstallVolcanicDragon.command.luau), copy the entire file into Studio's **Command Bar** while editing, and run it once. This installs six scripts in ReplicatedStorage, ServerScriptService, and StarterPlayerScripts. The [Rojo project](default.project.json) is an alternative if you already sync your game with Rojo.
3. Press **Play**, approach the dragon, and use **Test fire breath**. On the server Command Bar during Play, you can also run `game:GetService("ServerStorage").PlayVolcanicDragon:Fire()`. Trigger it again after recovery to check that it restarts from the original pose.

The animation does not start by itself. The Studio prompt is only installed during Studio testing. The server records the start time, and each client uses that clock for the pose and breath. Try a two-client Studio playtest to check synchronization in your place.

## Place it relative to the track

In the unscaled asset on level ground the default sweep lands roughly **5 studs in front of the mouth**. Mount the dragon higher for a longer throw, or adjust `FireDepression` as you line up the track. Increase `FireRange` if the track lies outside the ray's current reach. The stream stops at the first eligible surface, where it creates low flames, sparks, smoke, and short-lived molten marks. A missed ray produces no ground impact.

Set `TrackName` to the name of a direct Workspace child if you want to limit hits to a specific track model or part. Its track parts need `CanQuery` enabled. For the default sweep, the unscaled horns rise to about 6 studs above the dragon’s floor, and the widest part of the moving head reaches about 2.6 studs on either side of its centerline. With the default empty name the ray uses queryable world geometry, excluding the dragon and its effects.

## Configuration

Edit **ReplicatedStorage → VolcanicDragon → Config** before pressing Play, or change [Config.luau](src/ReplicatedStorage/VolcanicDragon/Config.luau) in a source-controlled setup and regenerate the installer.

| Setting | Default | Effect |
| --- | --- | --- |
| `Duration` | 10 seconds | Total wake, aim, attack and recovery duration |
| `FireDuration` | 5 seconds | Fire phase, including ignition and fade |
| `SweepAngle` | 27° | Head sweep to each side |
| `FireRange` | 105 studs | Maximum mouth ray distance |
| `FireDepression` | 13° | Extra downward aim relative to the head |
| `TrackName` | Empty | Optional direct Workspace child for impact raycasts |
| `Effects.Quality` | 1 | Particle rate multiplier. Try 0.65 for lower budgets |
| `Effects.WidthScale` | 1 | Width of the stream and scorch marks |
| `PreviewPrompt` | True | Show the manual prompt in Studio Play |

[Preview the poses sampled from the timeline.](DragonPoseStudy.png)

The underlying timeline, rig driver, and effects can be used separately. `build_studio_installer.py` rebuilds the Command Bar script after changes to the Luau sources. `build_dragon_rig.py` recreates the skin from the existing static GLB in Blender. The original `VolcanicDragon.glb` is still available.

Standalone Luau tests cover the timing, delayed turns, fire envelope and rest-pose reset. Blender checks cover the weighted model, current default sweep, and mouth clearance. Check the import, placement, visuals, and multiplayer timing in Studio on the target place.
