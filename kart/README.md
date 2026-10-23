# Fun Run racing kart — compact auto-turbo update

This updates the existing kart system. The model is **84% of its former scale**, with a domed red fairing, curved red side pods/fenders, white trim and vented bumper, blue lower panels, yellow rims, a dark bucket seat and compact black/yellow exhausts. The seat was widened before scaling to preserve cockpit space. The avatar itself is never scaled.

![Actual generated Part geometry rendered in Blender](dist/KartPreview.png)

The preview uses the actual builder's exported Parts, with Blender studio lighting and softened rendering edges. It is not a Roblox Studio screenshot or evidence of avatar fit/physics behavior. No uploaded meshes, external textures, plugins, secrets or HTTP settings are required.

## Update the kart already in your game

1. Download/extract the latest **dist/KartRelease.zip**. Stop Play and save your place.
2. Insert **dist/KartPackage.rbxmx** into Workspace using **Insert from File**. Select the newly imported **KartPackage** folder.
3. Open Studio's **Command Bar**, paste all of **tools/Upgrade.command.luau**, and press Enter.
4. Wait for **“Kart installed/upgraded.”** Press Play to generate the new kart.

The command now handles first installations, complete upgrades, and partial installations. **Install.command.luau and Upgrade.command.luau are identical**, so neither produces the old “use first installation” dead end. Do not import a second driving system.

Existing installations are cloned and verified under **ServerStorage/KartBackups/BeforeUpgrade_…** before replacement. The installer replaces only the five named kart modules and two driving scripts; other custom modules and **Workspace/KartSpawns** remain. Compatible custom driving/camera tuning, palette and spawn position carry over. New coordinated model scale, wheel radius, wheelbase and suspension dimensions take the release defaults; old custom geometry values remain available in the backup. Retired drift tiers are not migrated. Custom modifications to the replaced script source are backed up, not automatically merged.

To roll back in Edit mode, replace KartSystem in ReplicatedStorage, KartServer in ServerScriptService, and KartController in StarterPlayer/StarterPlayerScripts using the corresponding backup objects.

For a standalone test, open **dist/KartDemo.rbxlx** directly in Studio. The place contains a flat floor, player spawn and this same system.

## Spawn and controls

Use **R15** in Avatar Settings. Create **Workspace/KartSpawns** with one anchored Part per kart, about four studs above collidable ground; each marker's front (-Z) is the kart's forward direction. Optional string attribute ColorName accepts Red, Blue, Green, Yellow, Purple or Black. Markers hide at runtime. With no markers, one red kart spawns at KartConfig.SpawnCFrame.

- Walk to the kart and use the existing **E** entry prompt.
- **WASD/arrows** accelerate, brake/reverse and steer.
- Hold either **Shift** while turning and moving forward to drift.
- After **1.5 seconds** of continuous eligible drifting, turbo starts automatically while Shift is still held. Releasing early cancels the partial charge.
- Turbo lasts **1.15 seconds**. Its **six-second cooldown starts at activation**. Charging is blocked during boost/cooldown and needs a fresh full 1.5 seconds afterward.
- There is **no manual turbo or voluntary exit action**. Space, E/F and gamepad exit/jump actions cannot unseat a living assigned driver. Death/reset, disconnect, character replacement and kart removal release the assignment.
- Gamepad: stick steers/throttles, R2/L2 accelerate/brake, A/X drift. Touch provides driving and drift buttons; no exit/manual turbo button.

These controls are documented here only. The in-game HUD has **no instruction lines and no speed-unit text**.

## HUD

KartHUD is an asset-free racing cluster: large speed numerals, cyan speed bars, dark gradient panels, racing slashes and a segmented charge/recovery meter. It switches between **READY**, **CHARGING**, **TURBO** and **RECHARGING**, with smooth fills, an activation pulse, limited speed streaks and server-time countdowns. Desktop positioning is bottom-right; touch positioning is top-center with viewport scaling.

Charge comes from the server's normalized DriftCharge attribute. BoostEnd and TurboCooldownEnd share workspace:GetServerTimeNow() timestamps. The client interpolates display values but cannot award a boost or declare readiness before the server. No local prediction fills an unfinished charge.

## Architecture and behavior

~~~text
ReplicatedStorage/KartSystem
  KartConfig      tuning, scale, palette and spawn
  KartDynamics    pure driving/drift/boost calculations
  KartBuilder     geometry, seat, motors and physics constraints
  KartSeatLock    server seat lifecycle and settings restoration
  KartHUD         client display
  Remotes/Input   created by server; throttle, steer, drift only
ServerScriptService/KartServer
StarterPlayer/StarterPlayerScripts/KartController
Workspace/RacingKarts/RacingKart
~~~

- **Scale:** Model:ScaleTo applies once, including attachments/motors; returned wheel origins and steering metadata scale with it. Wheel radius, suspension rest/travel, wheelbase and follow-camera distance use the coordinated smaller values. The generated model has **223 connected Parts**. The body sits lower relative to the wheels.
- **Driving:** four PreSimulation raycast spring contacts, near-critical heave damping, separate inertia-scaled pitch/roll damping, COM traction and bounded yaw steering. Non-colliding visual wheels never compete with the hull. Normal and drift steering/grip transitions remain frame-rate independent. World velocity assignments are reserved for void recovery and extreme speed limiting.
- **Animation:** every observer animates wheel spin, steering and suspension at render rate from replicated steering/contact targets. Signed spin uses local wheel-point velocity and configured radius. R15 grip IK follows the steering wheel; torso lean remains replicated. Standard/large avatar reach and foot clearance still need Studio checks.
- **Seat lock:** the server retains the living driver's assignment and schedules a single bounded reseat attempt after involuntary/voluntary detachment. Engine refusals retry on later simulation updates. An intruder cannot replace the assigned driver. Jump and getting-up states are disabled on server/client. Death, removal or invalid assignment cancels pending work and restores original settings. Animated avatar parts temporarily become massless/non-colliding so they cannot disturb the vehicle or press against the road; original flags restore on legitimate cleanup.
- **Security:** server-owned physics; strict three-field remote schema; occupant checks, finite-number checks, input clamping/rate limit and a 0.5-second timeout. No client-supplied boost, charge, cooldown, velocity or exit flag. Cooldown survives driver cleanup; reset/reseat does not grant a fresh boost.
- **Boost rules:** charge requires forward motion above DriftMinSpeed, steering and ground contact. Airborne, stationary, straight, early-release, active-turbo and recharge conditions clear charge. Cooldown-boundary steps only credit their eligible tail; long frame stalls cannot instantly earn turbo. Power and duration never stack.
- **Lifecycle:** empty karts settle and park. A driver who falls near the destroy plane returns with the kart to its spawn without being unlocked. Markers are read at startup. Server ownership still adds input latency; no client physics prediction is implemented.
- **Effects/camera:** smooth independent camera position/height/heading filters, scaled distance, limited drift following, collision raycasts, gradual FOV and no shake. Smoke, charging sparks, acceleration exhaust, turbo flames and brake lamps remain bounded.

## Checks actually executed

The cloud checks compile all Luau sources using official Luau 0.726, execute the actual pure Dynamics and SeatLock modules, execute the actual builder in a geometry-only mock, and round-trip all **seven** source scripts through both Studio XML files.

- **136 dynamics assertions:** exact auto-trigger timing at 30/60/120 Hz, epoch-style server clocks, no early release reward, cooldown-boundary accounting, no precharging during boost/recharge, held-key behavior, no-driver cleanup, finite speed/boost, invalid charge conditions, steering and simplified suspension settling.
- **42 seat-lock assertions:** retained owner, single pending retry, takeover rejection, engine-refusal retry, death, replacement, seat destruction, removed characters, cancellation of stale callbacks, and exact restoration of prior jump/state flags.
- **Builder:** 223 connected parts, positive sizes, finite transforms, massless/non-colliding animated wheels, COM traction, uniform scale and agreement between tire radius, motors, attachments and configuration.
- **27 HUD assertions:** actual constructor/state/display code with test doubles validates readiness, charge, turbo, recharge, authoritative timer behavior, responsive scaling and hidden cleanup. A compact offline API-property fixture checks the GUI graph; optional --api-dump verifies it against the full Roblox API.
- **Nine installer scenarios:** the actual installer executes in offline service/instance mocks for fresh installation, custom-setting upgrade, partial repair, missing incoming modules, backup failure, wrong existing instance types, Play-mode rejection and two non-Archivable incoming-script failures. Source mutations require verified backups first; spawn markers/custom modules remain and no duplicate controllers are created.
- **Artifacts:** both XML files parse; each embedded source matches its repository source. Release ZIP includes source, installers, documentation, tests, demo and model preview.

**Roblox Studio is unavailable here.** No Studio import, actual driving, seat-lock behavior, R15 grip alignment, collision response, rendered HUD, mobile layout or multiplayer playtest is claimed as passed. Mocks and simplified numerical models do not simulate the Roblox physics solver.

## Studio acceptance checks

Use the demo flat floor first, then the real track. Watch Output throughout.

| Check | Expected result |
| --- | --- |
| Enter; try E/F, Space, gamepad/touch jump | Entry works; living driver remains seated; no exit button |
| Reset/death/disconnect; remove kart in server view | Assignment, IK, camera and input clean up; no stale reseat; original character flags restore |
| Flat straight drive, brake/reverse, small bumps | Stable motion, correct collisions and wheel spin, no sustained oscillation |
| Shift + turn for less than 1.5s; release | Partial charge clears; no boost |
| Hold Shift + turn for 1.5s | Automatic turbo without releasing; activation appears on HUD |
| Keep holding through cooldown | No charge during cooldown; fresh full charge before another turbo |
| Straight/slow/airborne drift, repeated key presses | No free charge, stacked boost or extended duration |
| HUD on desktop/phone emulator | Clear unit-free speed and charge/cooldown; no instructions or overlapping driving buttons |
| R15 and large avatars, both steering directions | Comfortable seat, hands near grips, feet do not disturb the chassis |
| Two clients/two markers, simulated latency | Independent karts, visible steering/effects, no takeover or timer disagreement |
| 10–20 degree ramps, curbs, walls, void fall | Proper contacts/collisions; bounded recovery with driver still assigned |

Run **tests/StudioSmoke.command.luau** in the server Command Bar during Play for assembly/lock assertions. Run **tests/StudioMeasurements.command.luau** while driving straight on flat ground to record ten seconds of vertical and roll/pitch velocity. These Studio commands have not been executed here.

## Rebuild

From kart/ with Python and the official Luau CLI installed:

~~~sh
python3 tools/test.py --luau /path/to/luau --compiler /path/to/luau-compile
~~~

This compiles scripts, executes calculation/lifecycle/geometry checks and rebuilds the artifacts. To regenerate only the package, run python3 tools/package.py. Regenerate dist after every source edit.

Optional geometry render: export using tools/check_geometry.py --luau /path/to/luau --output /tmp/kart-geometry.json, then run Blender with --python tools/render_preview.py -- /tmp/kart-geometry.json dist/KartPreview.png before packaging. Blender is needed only for this preview.
