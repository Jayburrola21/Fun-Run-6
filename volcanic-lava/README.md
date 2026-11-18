# Volcanic Lava for Roblox Studio

Animated lava for flat pools, fissures, and racing channels. Charcoal basalt plates drift over a molten bed while orange and yellow currents ripple through the gaps. Bubbles brighten as they rise, then pop into sparks. Cinders, thin smoke, and warm local light add movement above the surface.

## Try the demo

Open [VolcanicLavaDemo.rbxlx](VolcanicLavaDemo.rbxlx) in Studio, then press **Play**. It includes two lava pools and a slow showcase camera. The main pool and the smaller pool use different flow settings. [Offline material preview](SurfacePreview.png)

## Add it to your racing map

1. In **Edit mode**, select the lava **Parts** in Explorer. Flat, rectangular Parts make good guides for the top surface. You can select several at once.
2. Open [InstallVolcanicLava.command.luau](InstallVolcanicLava.command.luau) in a text editor and copy the entire file. Paste it into Studio’s **Command Bar** and run it. Output reports how many selected Parts it tagged.
3. Press **Play** to preview the effect. To add more pools later, select their Parts and rerun the installer, or add the `VolcanicLava` tag in Properties.

Keep each Part at its intended size and position. The effect follows its local top face and adds a thin surface layer. The Part’s collision and existing gameplay scripts are preserved. The animation, lighting, and particles run on each client. Any existing damage logic belongs in your server scripts.

The installer places modules in **ReplicatedStorage → VolcanicLava** and the client script in **StarterPlayer → StarterPlayerScripts**. The [Rojo mapping](default.project.json) provides the same layout for projects already synced with Rojo.

## Tune a pool

Add these Number attributes to a tagged Part in Studio, or edit the defaults in **ReplicatedStorage → VolcanicLava → Config**. A Part attribute overrides the default for that pool.

| Attribute | Default | What it controls |
| --- | ---: | --- |
| `LavaFlowSpeed` | 0.72 | Directional flow speed in studs per second |
| `FlowAngle` | 16 | Degrees from local +X toward local +Z |
| `GlowIntensity` | 0.78 | Hot seam color and nearby light |
| `SparkEmissionRate` | 26 | Continuous cinders per second before distance scaling |
| `BubbleFrequency` | 0.48 | Average bubble starts per second |
| `LavaBrightness` | 0.96 | Molten bed and highlight brightness |
| `SmokeDensity` | 0.34 | Volcanic wisp rate, from zero to one |
| `AnimationQuality` | 0.85 | Surface detail and emission budget, from 0.25 to 1 |

Crust, flow, and bubbles use built-in geometry and materials. If the client and experience allow Roblox’s Mesh/Image APIs, the system adds a shared procedural heat texture under the crust. A Boolean `UseEditableTexture` attribute can disable that extra layer for a pool.

The default client budget prioritizes up to 6 nearby surfaces and 3 atmospheric effects at a time. Mobile defaults are 4 and 2. The surface update rate and particle density fall as the camera moves away. Pools return to the current flow phase when they come back into range. Adjust the distance and pool limits in `Config.Budget` if your track needs a different range.

## Build and verify

Run `python3 build_studio_package.py` after editing the source to regenerate the installer and the demo place. The Luau fixtures in `tests` exercise scheduling, surface coverage, and particle reuse. Check the lighting, texture permissions, and frame rate in Studio on your target devices.
