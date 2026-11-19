-- Select the standalone wall MeshPart or its imported Model in Studio Edit mode.
local RunService = game:GetService("RunService")
local Selection = game:GetService("Selection")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

assert(RunService:IsStudio() and not RunService:IsRunning(), "Run the wall style command in Studio Edit mode.")
local selected = Selection:Get()
local selectionMessage = "Select the standalone wall MeshPart or its Model containing one MeshPart."
assert(#selected == 1, selectionMessage)
local item = selected[1]
local wall
if item:IsA("MeshPart") then
	wall = item
elseif item:IsA("Model") then
	for _, child in ipairs(item:GetDescendants()) do
		if child:IsA("MeshPart") then
			assert(not wall, selectionMessage)
			wall = child
		end
	end
end
assert(wall and wall.Name:lower():gsub("[^%w]", ""):sub(1, #"standalonetrackwall") == "standalonetrackwall",
	selectionMessage)

local texture = "rbxassetid://2913129928"
local changes = {
	{ "Anchored", true },
	{ "CanCollide", true },
	{ "CanQuery", true },
	{ "Material", Enum.Material.Concrete },
	{ "MaterialVariant", "" },
	{ "Reflectance", 0 },
	{ "TextureID", texture },
	{ "Color", Color3.fromRGB(163, 162, 165) },
}
local original = {}
for i, change in ipairs(changes) do
	original[i] = wall[change[1]]
end

local appearances = {}
for _, child in ipairs(wall:GetChildren()) do
	if child:IsA("SurfaceAppearance") then
		table.insert(appearances, child)
	end
end
local archiveName = "Imported Wall Appearance"
local archive = wall:FindFirstChild(archiveName)
assert(#appearances == 0 or not archive or archive:IsA("Folder"), "Rename the item called Imported Wall Appearance.")
local createdArchive

local historyOK, recording = pcall(function()
	return ChangeHistoryService:TryBeginRecording("StyleStandaloneTrackWall", "Style Fun Run 6 standalone wall")
end)
if not historyOK then
	recording = nil
end
local waypointOK = false
if not recording then
	waypointOK = pcall(function()
		ChangeHistoryService:SetWaypoint("Before styling standalone wall")
	end)
end

local success, message = pcall(function()
	for _, appearance in ipairs(appearances) do
		if not archive then
			archive = Instance.new("Folder")
			createdArchive = archive
			archive.Name = archiveName
			archive.Parent = wall
		end
		appearance.Parent = archive
	end
	for _, change in ipairs(changes) do
		wall[change[1]] = change[2]
	end
end)
if not success then
	for _, appearance in ipairs(appearances) do
		pcall(function()
			appearance.Parent = wall
		end)
	end
	if createdArchive and #createdArchive:GetChildren() == 0 then
		createdArchive:Destroy()
	end
	for i, change in ipairs(changes) do
		pcall(function()
			wall[change[1]] = original[i]
		end)
	end
end
if recording then
	pcall(function()
		ChangeHistoryService:FinishRecording(recording,
			if success then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
	end)
elseif waypointOK and success then
	pcall(function()
		ChangeHistoryService:SetWaypoint("Styled standalone wall")
	end)
end
assert(success, message)
print("Applied the original brick texture and anchored the standalone wall in place.")
