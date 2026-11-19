-- Select the imported standalone curve Model in Studio Edit mode.
local RunService = game:GetService("RunService")
local Selection = game:GetService("Selection")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local texture = "rbxassetid://2913129928"
local materials = {
	{ "bendpavingslate", Color3.fromRGB(88, 92, 108) },
	{ "bendpavingdark", Color3.fromRGB(52, 54, 66) },
	{ "bendpavingbase", Color3.fromRGB(88, 92, 108) },
	{ "bendwallneutral", Color3.fromRGB(163, 162, 165) },
}
local colliderPrefix = "bendcollider"
local snapshotFields = {
	"Anchored", "Material", "MaterialVariant", "CanTouch", "CanCollide", "CanQuery",
	"Transparency", "CastShadow", "Reflectance", "TextureID", "Color",
}

assert(RunService:IsStudio() and not RunService:IsRunning(), "Run the curve style command in Studio Edit mode.")
local selected = Selection:Get()
assert(#selected == 1 and selected[1]:IsA("Model"), "Select only the imported standalone curve Model in Explorer.")
local curve = selected[1]
local targets, found, appearances = {}, {}, {}
local colliderCount = 0
local function addTarget(part, color)
	local saved = {}
	for _, field in ipairs(snapshotFields) do
		saved[field] = part[field]
	end
	table.insert(targets, { part = part, color = color, saved = saved })
end

for _, part in ipairs(curve:GetDescendants()) do
	if part:IsA("MeshPart") then
		local key = part.Name:lower():gsub("[^%w]", "")
		if key:sub(1, #colliderPrefix) == colliderPrefix then
			colliderCount += 1
			addTarget(part)
		else
			for _, material in ipairs(materials) do
				local prefix, color = material[1], material[2]
				if key:sub(1, #prefix) == prefix then
					addTarget(part, color)
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
assert(found.bendpavingslate and found.bendpavingdark and found.bendpavingbase and found.bendwallneutral,
	"Import the full standalone curve with Merge Meshes off so its texture groups remain separate.")
assert(colliderCount == 27, "The standalone curve needs all 27 collision meshes. Reimport it with Merge Meshes off.")

local archiveName = "Imported Curve Appearance"
local existingArchive = curve:FindFirstChild(archiveName)
assert(not existingArchive or existingArchive:IsA("Folder"), "Rename the item called Imported Curve Appearance.")
local createdArchive
local historyOK, recording = pcall(function()
	return ChangeHistoryService:TryBeginRecording("StyleStandaloneTrackCurve", "Style Fun Run 6 standalone curve")
end)
if not historyOK then
	recording = nil
end
local waypointOK = false
if not recording then
	waypointOK = pcall(function()
		ChangeHistoryService:SetWaypoint("Before styling standalone curve")
	end)
end

local success, message = pcall(function()
	for appearance in pairs(appearances) do
		if not existingArchive then
			existingArchive = Instance.new("Folder")
			createdArchive = existingArchive
			existingArchive.Name = archiveName
			existingArchive.Parent = curve
		end
		appearance.Parent = existingArchive
	end
	for _, target in ipairs(targets) do
		local part = target.part
		local isCollider = target.color == nil
		part.Anchored = true
		part.Material = Enum.Material.Concrete
		part.MaterialVariant = ""
		part.CanTouch = false
		part.CanCollide = isCollider
		part.CanQuery = isCollider
		if isCollider then
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
		ChangeHistoryService:SetWaypoint("Styled standalone curve")
	end)
end
assert(success, message)
print("Applied the original track texture and enabled the standalone curve's hidden colliders in place.")
