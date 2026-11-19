-- Select the imported standalone straight track Model in Studio Edit mode.
local RunService = game:GetService("RunService")
local Selection = game:GetService("Selection")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local texture = "rbxassetid://2913129928"
local materials = {
	{ "straightpavingslate", Color3.fromRGB(88, 92, 108) },
	{ "straightpavingdark", Color3.fromRGB(52, 54, 66) },
	{ "straightwallneutral", Color3.fromRGB(163, 162, 165), false },
}
local colliderPrefix = "straightwallcollider"
local snapshotFields = {
	"Anchored", "Material", "MaterialVariant", "CanTouch", "CanCollide", "CanQuery",
	"Transparency", "CastShadow", "Reflectance", "TextureID", "Color",
}

assert(RunService:IsStudio() and not RunService:IsRunning(), "Run the straight track style command in Studio Edit mode.")
local selected = Selection:Get()
assert(#selected == 1 and selected[1]:IsA("Model"), "Select only the imported standalone straight track Model in Explorer.")
local track = selected[1]
local targets, found, appearances = {}, {}, {}
local colliderCount = 0
local function addTarget(part, color, solid)
	local saved = {}
	for _, field in ipairs(snapshotFields) do
		saved[field] = part[field]
	end
	table.insert(targets, { part = part, color = color, solid = solid, saved = saved })
end

for _, part in ipairs(track:GetDescendants()) do
	if part:IsA("MeshPart") then
		local key = part.Name:lower():gsub("[^%w]", "")
		if key:sub(1, #colliderPrefix) == colliderPrefix then
			colliderCount += 1
			addTarget(part, nil, true)
		else
			for _, material in ipairs(materials) do
				local prefix, color, solid = table.unpack(material)
				if key:sub(1, #prefix) == prefix then
					addTarget(part, color, solid)
					found[prefix] = true
					for _, child in ipairs(part:GetChildren()) do
						if child:IsA("SurfaceAppearance") then
							appearances[child] = part
						end
					end
					break
				end
			end
		end
	end
end
assert(found.straightpavingslate and found.straightpavingdark and found.straightwallneutral,
	"Import the full standalone straight track with Merge Meshes off so its texture groups remain separate.")
assert(colliderCount == 2, "The standalone straight track needs both wall collision meshes. Reimport it with Merge Meshes off.")

local archiveName = "Imported Straight Appearance"
local existingArchive = track:FindFirstChild(archiveName)
assert(not existingArchive or existingArchive:IsA("Folder"), "Rename the item called Imported Straight Appearance.")
local createdArchive
local historyOK, recording = pcall(function()
	return ChangeHistoryService:TryBeginRecording("StyleStandaloneStraightTrack", "Style Fun Run 6 standalone straight track")
end)
if not historyOK then
	recording = nil
end
local waypointOK = false
if not recording then
	waypointOK = pcall(function()
		ChangeHistoryService:SetWaypoint("Before styling standalone straight track")
	end)
end

local success, message = pcall(function()
	for appearance in pairs(appearances) do
		if not existingArchive then
			existingArchive = Instance.new("Folder")
			createdArchive = existingArchive
			existingArchive.Name = archiveName
			existingArchive.Parent = track
		end
		appearance.Parent = existingArchive
	end
	for _, target in ipairs(targets) do
		local part = target.part
		local solid = target.solid
		part.Anchored = true
		part.Material = Enum.Material.Concrete
		part.MaterialVariant = ""
		-- Imported paving keeps the original collision and touch behavior.
		if solid ~= nil then
			part.CanTouch = false
			part.CanCollide = solid
			part.CanQuery = solid
		end
		if solid then
			part.Transparency = 1
			part.CastShadow = false
		else
			part.Reflectance = 0
			part.TextureID = texture
			part.Color = target.color
		end
	end
end)
if not success then
	for appearance, parent in pairs(appearances) do
		pcall(function()
			appearance.Parent = parent
		end)
	end
	if createdArchive and #createdArchive:GetChildren() == 0 then
		createdArchive:Destroy()
	end
	for _, target in ipairs(targets) do
		for _, field in ipairs(snapshotFields) do
			pcall(function()
				target.part[field] = target.saved[field]
			end)
		end
	end
end
if recording then
	pcall(function()
		ChangeHistoryService:FinishRecording(recording,
			if success then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
	end)
elseif waypointOK and success then
	pcall(function()
		ChangeHistoryService:SetWaypoint("Styled standalone straight track")
	end)
end
assert(success, message)
print("Applied the original track texture and enabled the straight track's hidden wall colliders in place.")
