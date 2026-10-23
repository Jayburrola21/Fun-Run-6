# Blender mesh installation

The drivable package includes the compact native geometry fallback. The separately supplied Blender model is the detailed visual replacement: `dist/KartRemodel.blend` and `dist/KartRemodel.fbx`. The meshes attach to the existing chassis, four animated wheel carriers, and steering hub. They do not replace the seat or the driving controller.

Roblox must import/upload custom meshes under the experience owner's account before an experience can use them. No working Roblox mesh asset IDs can be manufactured by the cloud build. The supplied FBX and installation command make that Studio step concrete; the XML package does not pretend to contain uploaded Blender assets.

## Install the detailed model

1. Stop Play, save your place, and install the latest `KartPackage.rbxmx` using `tools/Upgrade.command.luau`.
2. Open Studio's **3D Importer** and select `dist/KartRemodel.fbx`. Import the complete model with separate mesh objects and the original relative placement. Use the experience owner's asset ownership settings. Do not merge every object into one mesh or discard the three small alignment meshes.
3. Select the complete imported Model in Explorer. Keep its `KartOrigin`, `KartForward`, and `KartUp` mesh objects present; the installation command uses them to normalize import units and axes.
4. Copy all of `tools/ImportBlender.command.luau` into Studio's **Command Bar** and run it in Edit mode.
5. Check Output for **“Blender kart meshes installed”**, then press Play. Inspect the generated kart's `VisualSource` attribute: **Blender** confirms the mesh template was applied. **Native** means the complete fallback is being used instead.

The command creates `ReplicatedStorage/KartSystem/KartMeshTemplate`. It retains the original imported Model and the previous template under `ServerStorage/KartBackups/BeforeBlenderImport_…`, keeping a spare static model off the track. Normal kart upgrades preserve this template alongside custom objects.

If an import is missing objects, has invalid alignment, or cannot be cloned, the command leaves the existing template unchanged. Runtime validation also prepares every mesh before hiding fallback geometry, so an incomplete template does not turn the kart into an invisible or broken rig.

To return to native presentation, stop Play and move `KartMeshTemplate` out of `ReplicatedStorage/KartSystem`. To restore an earlier mesh import, replace it with the corresponding backed-up template, then restart Play.

## Hierarchy and pivot contract

Each Blender mesh object uses a group prefix followed by `__`:

| Group | Runtime attachment |
| --- | --- |
| MainBody, FrontNose, LeftSidePod, RightSidePod, RearBody, RearBumper | Chassis |
| Seat, LeftExhaust, RightExhaust, Chassis | Chassis |
| FrontLeftWheel, FrontRightWheel, RearLeftWheel, RearRightWheel | Corresponding existing Tire carrier |
| SteeringWheel | Existing steering Hub |

Names containing `__Paint` or `__Red` identify primary paint meshes; the runtime matches their color to each kart's selected palette. Tire, trim, upholstery, rim, and exhaust colors remain independent.

The exported `__Mat…` suffixes also survive FBX import. The helper assigns native Metal to mechanical parts/springs/rims, Fabric to seat upholstery, Neon to lamps, Glass to glass, and SmoothPlastic to paint and rubber. This preserves a consistent presentation when the importer does not transfer Blender's metallic/roughness settings. Brake lenses are tagged for the existing brake-light controller rather than left as static decoration.

The authored canonical coordinates use Roblox forward **−Z** and up **+Y**. Alignment markers are `(0,0,0)`, `(0,0,−4)`, and `(0,4,0)`. The importer resolves arbitrary whole-model translation, rotation, and uniform import scale from these markers. Nonuniform scale and skewed axes are rejected.

Wheel pivots are `(−2.2,0.4,−2.16)`, `(2.2,0.4,−2.16)`, `(−2.2,0.4,2.16)`, and `(2.2,0.4,2.16)`. The steering pivot is `(0,1.95,−1.05)` tilted **−24° around X**. Templates keep canonical dimensions; `KartMeshVisuals` applies the configured model scale exactly once when attaching visuals. It computes each moving mesh's transform relative to its actual wheel or steering pivot, preserving steering and signed wheel spin.

Keep exported objects separate and preserve this naming/pivot contract when remodeling the `.blend`. The helper strips imported scripts, constraints, and attachments. Every runtime mesh is massless and non-colliding; contact forces and collision hulls remain the existing driving rig's responsibility.

## Studio checks still required

The cloud tests execute the real adapter/importer using geometry and instance doubles, including all four wheel attachments, steering, rotated world transforms, import-unit normalization, paint roles, safe rejection, and backup ordering. They do **not** upload an asset or run Roblox's importer/rendering/physics engine.

In Studio verify imported mesh ownership, front/back orientation, materials, normal shading, wheel spin in both directions, full left/right steering and suspension clearance, R15 seat/grip fit, camera framing, multiplayer visibility, and Output. Restart Play after replacing a template; live mesh swapping during a race is intentionally unnecessary.
