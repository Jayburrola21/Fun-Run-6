-- Place the imported GLB before running. Existing race folders go to ServerStorage.
assert(not game:GetService("RunService"):IsRunning(), "Stop Play before installing the circuit.")
local rig = assert(workspace:FindFirstChild("DriftCircuitRig"), "Insert FoundrySwitchbacks_Rig.rbxmx into Workspace first.")
local track
for _, item in game:GetService("Selection"):Get() do
    if item:IsA("Model") and item ~= rig and item:FindFirstChild("DriftCircuitAnchorOrigin", true) then
        track = item
        break
    end
end
track = track or workspace:FindFirstChild("Drift Circuit", true)
assert(track and track:IsA("Model"), "Select the imported Foundry Switchbacks GLB model.")

local function basis(model)
    local origin = assert(model:FindFirstChild("DriftCircuitAnchorOrigin", true), "Missing origin anchor.")
    local x = assert(model:FindFirstChild("DriftCircuitAnchorX", true), "Missing X anchor.")
    local z = assert(model:FindFirstChild("DriftCircuitAnchorZ", true), "Missing Z anchor.")
    local right, back = x.Position - origin.Position, z.Position - origin.Position
    assert(right.Magnitude > .01 and math.abs(right.Magnitude - back.Magnitude) < .01 * right.Magnitude,
        "The circuit needs a uniform import scale.")
    right = right.Unit
    local up = back:Cross(right).Unit
    local frame = CFrame.fromMatrix(origin.Position, right, up, right:Cross(up))
    return frame, (x.Position - origin.Position).Magnitude
end

local race = assert(rig:FindFirstChild("KartRace"), "The rig is missing its checkpoint data.")
local spawns = assert(rig:FindFirstChild("KartSpawns"), "The rig is missing its starting grid.")
local destination, referenceDistance = basis(track)
local _, rigDistance = basis(rig)
rig:ScaleTo(rig:GetScale() * referenceDistance / rigDistance)
local source = basis(rig)
rig:PivotTo(destination * source:ToObjectSpace(rig:GetPivot()))

local previousRace = workspace:FindFirstChild("KartRace")
local previousSpawns = workspace:FindFirstChild("KartSpawns")
if previousRace or previousSpawns then
    local backup = Instance.new("Folder")
    backup.Name = "Before Foundry Switchbacks"
    backup.Parent = game:GetService("ServerStorage")
    if previousRace then previousRace.Parent = backup end
    if previousSpawns then previousSpawns.Parent = backup end
end

for _, part in track:GetDescendants() do
    if part:IsA("BasePart") then
        part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
        if part.Name:find("DriftCircuitAnchor", 1, true) then
            part.Transparency, part.CastShadow = 1, false
        end
    end
end
race:SetAttribute("TotalLaps", 3)
race.Parent = workspace
spawns.Parent = workspace
rig.Parent = track
pcall(function() game:GetService("ChangeHistoryService"):SetWaypoint("Install Foundry Switchbacks") end)
print("Installed Foundry Switchbacks with 9 checkpoints and 6 kart spawns.")
