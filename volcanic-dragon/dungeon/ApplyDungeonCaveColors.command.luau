-- Select the imported DragonDungeonCave model and run this in Studio Edit mode.
local RunService = game:GetService("RunService")
local Selection = game:GetService("Selection")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

assert(RunService:IsStudio() and not RunService:IsRunning(), "Run the cave color fix in Studio Edit mode.")
local selected = Selection:Get()
assert(#selected == 1, "Select the whole imported cave model in Explorer.")
local model = selected[1]
if model:IsA("MeshPart") then
	model = model:FindFirstAncestorOfClass("Model")
end
assert(model and model:IsA("Model"), "Select the whole imported cave model in Explorer.")

local shellColor = Color3.fromRGB(121, 121, 121)
local gateColor = Color3.fromRGB(61, 61, 61)
local roles = {
	dungeoncavegrayshell = "Shell",
	plaingraycavernshell = "Shell",
	gatearchframe = "Frame",
	gatesidelattice = "Sides",
	gatetornbars = "TornBars",
}

local meshes, matches, found = {}, {}, {}
for _, part in model:GetDescendants() do
	if part:IsA("MeshPart") then
		table.insert(meshes, part)
		-- The importer can sanitize punctuation, use mesh names, or add
		-- a numeric suffix to names that already exist in the place.
		local key = part.Name:lower():gsub("[^%w]", ""):gsub("%d+$", "")
		local role = roles[key]
		if role then
			matches[part] = if role == "Shell" then shellColor else gateColor
			found[role] = true
		end
	end
end

if not (found.Shell and found.Frame and found.Sides and found.TornBars) then
	local message = "Select the full cave with its four separate meshes. If import merged them, reimport with Merge Meshes turned off."
	assert(#meshes == 4, message)
	-- A renamed import still has one deep cave shell and three thin iron
	-- assemblies. Check the proportions before editing any of the meshes.
	matches = {}
	local shellCount = 0
	for _, part in meshes do
		local size = part.Size
		local ratio = math.min(size.X, size.Y, size.Z) / math.max(size.X, size.Y, size.Z)
		if ratio > 0.5 then
			matches[part] = shellColor
			shellCount += 1
		else
			assert(ratio < 0.15, message)
			matches[part] = gateColor
		end
	end
	assert(shellCount == 1, message)
end

local recording = ChangeHistoryService:TryBeginRecording("DungeonCaveColors", "Apply dungeon cave colors")
for part, color in pairs(matches) do
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.MaterialVariant = ""
	part.Reflectance = 0
end
if recording then
	ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
end
print("Dungeon cave colors applied. Click off the model to see the gray shell and dark gray gate.")
