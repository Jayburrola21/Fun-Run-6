-- Run in Studio Edit mode with the imported cliff model selected.
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local RunService = game:GetService("RunService")
local Selection = game:GetService("Selection")

local folderName = "VolcanicCliffTerrain"
local prefix = "VolcanicCliff_"

if RunService:IsRunning() then
    warn("Stop Play mode and select the imported cliff model.")
    return
end

local pieces, seen = {}, {}
local function collect(instance)
    if instance:IsA("MeshPart") and instance.Name:sub(1, #prefix) == prefix and not seen[instance] then
        seen[instance] = true
        table.insert(pieces, instance)
    end
end

for _, instance in Selection:Get() do
    collect(instance)
    for _, child in instance:GetDescendants() do
        collect(child)
    end
end

if #pieces == 0 then
    warn("Select the imported VolcanicCliff model or its VolcanicCliff_ MeshParts.")
    return
end

local folder = workspace:FindFirstChild(folderName)
if folder and not folder:IsA("Folder") then
    warn(folderName .. " is already in use by another Workspace instance.")
    return
end

local recording = ChangeHistoryService:TryBeginRecording("OrganizeVolcanicCliff", "Organize volcanic cliff terrain")
if not recording then
    warn("Studio could not start an undo recording. Finish the current edit and rerun the command.")
    return
end

if not folder then
    folder = Instance.new("Folder")
    folder.Name = folderName
    folder.Parent = workspace
end

for _, piece in pieces do
    piece.Anchored = true
    piece.Parent = folder
end

ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
Selection:Set({folder})
print(("Organized %d anchored cliff meshes under Workspace.%s"):format(#pieces, folderName))
