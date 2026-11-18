-- Select the cave shell or the full cave model in Studio Edit mode.
local RunService = game:GetService("RunService")
local Selection = game:GetService("Selection")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local shellColor = Color3.fromRGB(96, 96, 96)
local gateColor = Color3.fromRGB(61, 61, 61)
local roles = {
	dungeoncavegrayshell = "Shell",
	plaingraycavernshell = "Shell",
	gatearchframe = "Frame",
	gatesidelattice = "Sides",
	gatetornbars = "TornBars",
}

local function getRole(part)
	-- Studio may sanitize punctuation, use mesh names, or add a numeric suffix.
	local key = part.Name:lower():gsub("[^%w]", ""):gsub("%d+$", "")
	return roles[key]
end

local function thickness(part)
	local size = part.Size
	return math.min(size.X, size.Y, size.Z) / math.max(size.X, size.Y, size.Z)
end

local function modelColors(model)
	local meshes, matches, found = {}, {}, {}
	for _, part in model:GetDescendants() do
		if part:IsA("MeshPart") then
			table.insert(meshes, part)
			local role = getRole(part)
			if role then
				matches[part] = if role == "Shell" then shellColor else gateColor
				found[role] = true
			end
		end
	end
	if found.Shell and found.Frame and found.Sides and found.TornBars then
		return matches
	end

	local message = "Select the full cave with its four separate meshes. If import merged them, reimport with Merge Meshes turned off."
	assert(#meshes == 4, message)
	-- A renamed import has one deep shell and three thin iron assemblies.
	matches = {}
	local shellCount = 0
	for _, part in meshes do
		local ratio = thickness(part)
		if ratio > 0.5 then
			matches[part] = shellColor
			shellCount += 1
		else
			assert(ratio < 0.15, message)
			matches[part] = gateColor
		end
	end
	assert(shellCount == 1, message)
	return matches
end

assert(RunService:IsStudio() and not RunService:IsRunning(), "Run the cave color fix in Studio Edit mode.")
local selected = Selection:Get()
local message = "Select the cave shell MeshPart or the whole imported cave model in Explorer."
assert(#selected == 1, message)
local target = selected[1]
local matches
if target:IsA("MeshPart") then
	local role = getRole(target)
	assert(role == "Shell" or (not role and thickness(target) > 0.5), message)
	matches = {[target] = shellColor}
else
	assert(target:IsA("Model"), message)
	matches = modelColors(target)
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
print("Dungeon cave colors applied. Click off the selection to see the new shade.")
