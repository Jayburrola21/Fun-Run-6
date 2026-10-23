# Fun Run racing kart

A self-contained, procedurally assembled Roblox kart inspired by the supplied reference: red/white tapered nose, black bucket seat, front splitter and LED bars, side vents, tubular rails, thick treaded tires, six-spoke rims with blue rings, raised rear wing and twin turbo exhausts. Six paint colors are included. This is an original Parts-based interpretation, not an exact mesh replica of the reference render. No asset uploads, asset IDs, plugins, HTTP requests, or external textures are required; particle textures use Roblox's built-in resources.

## Try the included place

1. Open **dist/KartDemo.rbxlx** in Roblox Studio using **File → Open from File**. This is a separate flat test place; it does not modify your terrain/game.
2. In Avatar Settings, select **R15**. Press **Play**, walk to the kart, and press **E**.
3. Drive with **WASD / arrows**, hold **Space + a turn** to drift, release Space for a charged boost, and hold **Shift** for a rechargeable turbo. **E or F** exits. Space is reserved for drifting while driving, so use the exit key rather than jump.
4. Gamepad: left stick steers/throttles, R2 accelerates, L2 brakes/reverses, A drifts, X boosts, B exits. Touch buttons are supplied too; verify their layout on your target devices.

The kart is generated when the server starts. The avatar spawn is near it. No internet/security settings need to be enabled.

## Install into your existing game

Back up your place first. The installer rejects an existing KartSystem/KartServer/KartController instead of replacing your work.

1. Stop Play mode. In Explorer, right-click Workspace and choose **Insert from File**, then select **dist/KartPackage.rbxmx**. Some Studio versions expose this through the Model tab's **Advanced → Insert from File**. This is a script package, not a mesh; do not use the 3D importer.
2. Select the imported **KartPackage** folder. Open **View → Command Bar** and paste/run the contents of **tools/Install.command.luau**. The scripts are disabled inside the imported folder until installation places and enables them in their proper services.
3. Add a Folder named **KartSpawns** to Workspace. Inside it, place anchored Parts at the desired chassis spawn positions, about **4 studs above the ground**, oriented so their **front (-Z)** points down the track. The server hides these markers and disables their collisions. Use one marker per kart; optional string attribute **ColorName** accepts `Red`, `Blue`, `Green`, `Yellow`, `Purple`, or `Black`.
4. With no markers, one red kart spawns at `KartConfig.SpawnCFrame`, initially `(0, 5, 0)`. Change that setting for your map rather than assuming the terrain is at Y=0.
5. Select R15 in Avatar Settings and press Play. Save the place after successful tests. The terrain files in this repository are left unchanged.

Alternatively use **Rojo** with `default.project.json`, or create the five script instances manually from `src/` using the same names/services. Do not install twice. Rojo is optional and is not bundled.

```text
ReplicatedStorage/KartSystem
  KartConfig       ModuleScript: tuning and palette
  KartDynamics     ModuleScript: tested speed/braking/tier calculations
  KartBuilder      ModuleScript: complete geometry and constraint assembly
  Remotes/Input    RemoteEvent: created at server startup
ServerScriptService/KartServer
StarterPlayer/StarterPlayerScripts/KartController
Workspace/RacingKarts/RacingKart  (generated at runtime)
```

## Implementation and tuning

- **Driving:** four spring/damper raycast contacts feed modern `VectorForce` constraints. Physical wheel-contact shells and the chassis handle wall/curb collisions; the tire rotation is visual, not a HingeConstraint drivetrain. Wheel suspension position follows each ray, so all wheels compress independently. The tires do not individually collide like full rigid-body wheel assemblies. This arcade approach is intended to avoid constraint-wheel jitter.
- **Steering:** speed-sensitive bicycle-model yaw target, lateral tire grip, ground-normal stabilization torque, braking, reverse and coast drag. Contact forces are removed in the air; drifting cannot charge airborne. Most tuning lives in KartConfig. Very steep or vertical faces are not drivable ground.
- **Animation:** four wheel Motor6D `C0`s follow speed and front steering at 24 Hz. Steering wheel and torso lean also update server-side so observers see them. R15 IKControls target hand-grip attachments on the rotating wheel. Standard seated animation remains active for legs. R6 can drive, but has no hand IK. Nonstandard avatar scale/accessories may need seat/grip tuning in KartBuilder.
- **Boosts:** 0.65 / 1.5 / 2.7 seconds of a continuous grounded drift earn blue/orange/purple tiers. Release Space while grounded to redeem it. Stopping the turn, slowing down or losing ground contact clears the charge. Turbo has a six-second cooldown. Boost bonuses replace rather than add together, have finite duration, and are subject to a server speed ceiling.
- **Effects:** bounded smoke/spark emission, dual flames, brighter wheel rings at speed, brake lamps, turbo camera shake, speed-dependent FOV and screen-space boost lines. The camera raycasts for obstructions and restores the previous camera on exit. Effects have no audio dependency.
- **Multiplayer:** the server owns physics, seating, charge/cooldown and replicated animation. Remote inputs are occupant-checked, finite-checked, clamped, rate-limited and time out after 0.5 seconds. The client never supplies velocity, position, boost strength or charge time. Server ownership trades some input latency for consistent authority; no client prediction is implemented. General game anti-cheat still belongs to your game.
- **Lifecycle:** empty karts brake, settle and anchor; entering unanchors them. Grip controls, jump settings, camera and inputs are cleaned up on exit/death. Falling near the destroy plane returns the kart to its marker and ejects its driver. Markers are read at startup; restart Play after changing their count.
- **Cost:** four ground raycasts per kart per physics update; visual replication is limited to 24 Hz. Detailed tire treads/rings use Parts, so profile the intended kart count on mobile. Model streaming is atomic to keep assemblies complete.

## Validation status

Executed in the cloud: every Luau file compiled using official Luau **0.726**; **57 dynamics assertions passed** at 30/60/120 Hz covering acceleration, limits, braking/reverse, coasting, boost expiry, charge thresholds, cooldowns, airborne/stationary charge rejection and non-finite input rejection. XML artifacts were parsed and all five embedded sources checked against the originals. Enum references were checked against Roblox's public API dump.

**Roblox Studio is unavailable in this environment.** The generated place has not been opened or run here. Studio physics, import compatibility, avatar grip alignment, visual fidelity, device input and multiplayer behavior remain unverified. The engine-independent tests do not certify those behaviors. Use the following checks before including this in a live game.

## Studio acceptance checklist

Run `tests/StudioSmoke.command.luau` in the **server Command Bar during Play** to inspect the actual generated assembly. Then perform these behavioral checks; watch Output for errors throughout.

| Check | Expected result |
| --- | --- |
| E enter; E/F exit; enter again; reset character | One driver, normal seated pose, camera/input restored on exit, empty kart parks |
| W, release, S; hold S after stopping | Accelerates smoothly, coasts, brakes, then reverses; no unbounded speed |
| A/D at low and high speeds | Correct turning direction, front wheels steer, rear wheels remain aligned; wheel spin matches forward/reverse |
| R15 driver and observer | Hands stay near wheel grips through both turns; wheel centers smoothly; no detached avatar |
| Hold W + turn + Space for each threshold | Blue → orange → purple sparks; smoke only during drift; release earns a temporary boost |
| Tap/release Space, drift in air, stop turn, spam Shift | No free charge, no airborne charge, finite boost, six-second turbo recharge |
| Boost then release acceleration; brake | Flames/FOV/lines activate and clear; speed returns to normal; brake lamps respond |
| Add a 10–20° ramp, small bumps, a wall and a ledge | Individual suspension movement, uphill/downhill drive, collisions, no sustained rollover/jitter; verify your actual candy terrain too |
| Studio Test → Server & Clients, two clients, two markers | Both karts independent; second player cannot steal an occupied kart; observer sees wheels, grips, sparks |
| Simulated latency, minimize window, disconnect driver | Safe input timeout, no stuck accelerator, no stale IK; assess server-owned input latency |
| Gamepad and phone emulator | Steering/throttle, drift/boost/exit work; HUD/buttons do not obstruct necessary UI |

If contact is unstable, first ensure spawn markers are above collidable ground and no other script moves the kart or assigns it client ownership. Then adjust SpringFrequency / SpringDamping in small increments. Tune MaxSpeed, Grip and MaxSteer on your actual track. Do not use cloud tests as a substitute for the Studio acceptance checks.

## Rebuild artifacts and rerun cloud checks

From `kart/`:

```sh
python3 tools/package.py
python3 tools/test.py --luau /path/to/luau --compiler /path/to/luau-compile
```

Python uses only the standard library. The test runner requires the official Luau CLI and compiler; Roblox Studio supplies the actual runtime instead. Regenerate `dist/` whenever source scripts change. `dist/source-hashes.json` records the packaged source hashes. No environment secrets or onboarding configuration changes are needed for the kart itself.
