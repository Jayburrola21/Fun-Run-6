-- Select the bend Model in Edit mode. Also select the original Track Model to replace its corner.
local RunService = game:GetService("RunService")
local Selection = game:GetService("Selection")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local ServerStorage = game:GetService("ServerStorage")

local entryOrigin = Vector3.new(-849.23868, 27.10, -22.27966)
local entryTarget = CFrame.lookAt(entryOrigin, entryOrigin + Vector3.xAxis, Vector3.yAxis)
local markerDistance = 2
local radius = 47
local entryHalfWidth, exitHalfWidth = 31.47665, 31.57025
local wallWidth, wallHeight = .71, 3.95
local collisionName = "Track Bend Collision"
local markerRoles = {
	trackbendentry = "entry",
	trackbendforward = "forward",
	trackbendup = "up",
}
local visualStyles = {
	{ prefix = "bendpavingslate", color = Color3.fromRGB(88, 92, 108) },
	{ prefix = "bendpavingdark", color = Color3.fromRGB(52, 54, 66) },
	{ prefix = "bendwallneutral", color = Color3.fromRGB(163, 162, 165) },
	{ prefix = "bendpavingbase", color = Color3.fromRGB(50, 52, 61), plain = true },
}
local originalTexture = "rbxassetid://2913129928"

-- Original upload references: ref, mesh ID, position, size, and right-axis X/Z.
local originalReferences = {
	{ 40, 2915144046, -1060.29821777, 28.3127346, 15.04290009, 11.8218565, 5.98587275, 431.33911133, 0, -1 },
	{ 107, 2915144046, -839.49517822, 28.3127346, 57.31614685, 11.64654827, 5.98587275, 73.62819672, -1, 0 },
	{ 158, 2915568624, -834.16314697, 27.73142433, 27.95594978, 10.88413811, 4.54334784, 0.70845366, 0, 1 },
	{ 161, 2915568624, -834.16314697, 28.77562141, 21.27165985, 4.5730691, 4.54334784, 0.70845366, 0, 1 },
	{ 163, 2915142986, -827.53179932, 26.95718002, 26.62513924, 8.93600941, 0.6813482, 12.96804714, 0, 1 },
	{ 166, 2915144607, -839.4307251, 28.41451645, 14.92873573, 11.64641476, 6.54007769, 11.8217535, -1, 0 },
	{ 167, 2915568624, -848.40942383, 28.77562141, 9.55124855, 10.27560997, 4.58470821, 0.71490312, 1, 0 },
	{ 169, 2915568624, -834.16314697, 28.44315529, 14.45727539, 10.53352451, 4.54334784, 0.70845366, 0, 1 },
	{ 170, 2915144878, -827.52972412, 26.9616642, 15.87519169, 12.96805, 0.27238089, 13.31866646, 1, 0 },
	{ 173, 2915568624, -838.89648438, 28.77562141, 9.55124855, 10.18290901, 4.54334784, 0.70845366, 1, 0 },
	{ 174, 2915142986, -852.90826416, 26.85717964, 2.94163537, 12.96808147, 0.48134816, 12.96804714, 1, 0 },
	{ 175, 2915143648, -802.16650391, 26.93021774, 24.22665024, 14.09123993, 0.33527383, 40.50939941, 0, -1 },
	{ 176, 2915144878, -840.29772949, 26.9616642, 2.73286557, 12.96805, 0.27238089, 12.96805191, 1, 0 },
	{ 177, 2915143648, -814.81079102, 26.93021774, 11.46800327, 12.96973991, 0.33527383, 12.97049427, 0, -1 },
	{ 199, 2915144303, -827.52966309, 26.8809166, 4.0907464, 10.51006126, 0.4338747, 12.96804714, 0, 1 },
	{ 200, 2915143648, -789.69177246, 26.93021774, 12.09339333, 11.71101284, 0.33527383, 12.97049427, 0, -1 },
	{ 201, 2915143648, -802.17236328, 26.93021774, 8.24001217, 19.73565102, 0.33527383, 13.37049389, 0, -1 },
	{ 202, 2915144183, -840.17199707, 26.96683121, -9.98109627, 12.9706192, 0.26204541, 12.97090912, 0, -1 },
	{ 203, 2915143648, -814.81079102, 26.93021774, 1.9594835, 7.00000095, 0.33527383, 12.97049427, 0, -1 },
	{ 226, 2915568624, -770.31420898, 28.77562141, 28.45926476, 10.88413811, 4.54334784, 0.70845366, 0, -1 },
	{ 228, 2915142986, -777.065979, 26.85717964, 23.95580482, 13.11331177, 0.48134816, 12.96804714, 0, -1 },
	{ 229, 2915568624, -770.31420898, 28.57883453, 18.64204788, 10.88413811, 4.54334784, 0.70845366, 0, -1 },
	{ 230, 2915143648, -852.94000244, 26.93021774, -22.39203644, 14.09123993, 0.33527383, 40.13654709, -1, 0 },
	{ 232, 2915568624, -770.31420898, 28.53566933, 8.64951897, 10.88413811, 4.54334784, 0.70845366, 0, -1 },
	{ 233, 2915144878, -777.03027344, 26.9616642, 11.46490002, 12.96805, 0.27238089, 12.96805191, 1, 0 },
	{ 234, 2915144183, -840.17199707, 26.96683121, -22.42793846, 12.9706192, 0.26204541, 12.97090912, 0, -1 },
	{ 235, 2915144183, -826.89782715, 26.93969917, -7.16299105, 15.43151855, 0.31631017, 12.40264034, 1, 0 },
	{ 236, 2915144183, -813.95910645, 26.93969917, -7.25620031, 12.20776844, 0.31631017, 12.58906269, 1.00000107, 0 },
	{ 237, 2915144183, -789.71191406, 26.93969917, 1.2924937, 13.01857853, 0.31631017, 11.27917671, -1, 0 },
	{ 238, 2915144183, -802.06201172, 26.93969917, -7.76299047, 13.21199989, 0.31631017, 13.20264053, 1.00000107, 0 },
	{ 242, 2915144183, -840.17199707, 26.96683121, -35.0500412, 12.9706192, 0.26204541, 12.97090912, 0, -1 },
	{ 243, 2915143648, -821.58294678, 26.93021774, -21.70648575, 18.31757545, 0.33527383, 26.75828552, 0, -1 },
	{ 244, 2915144303, -777.0302124, 26.8809166, -1.1703217, 12.96805573, 0.4338747, 12.96804714, 0, 1 },
	{ 246, 2915142986, -853.2109375, 26.85717964, -47.73094177, 13.11331177, 0.48134816, 12.96804714, -1, 0 },
	{ 247, 2915144183, -828.42205811, 26.93969917, -37.24854279, 12.03246212, 0.31631017, 13.3779459, -1, 0 },
	{ 248, 2915568624, -770.31420898, 28.53073692, -0.99239016, 10.88413811, 4.54334784, 0.70845366, 0, -1 },
	{ 250, 2915568624, -845.23345947, 28.37587929, -54.11056137, 10.88413811, 4.54334784, 0.70845366, -1, 0 },
	{ 251, 2915144878, -840.29772949, 26.9616642, -47.73484421, 12.96805, 0.27238089, 12.96805191, 0, 1 },
	{ 252, 2915144183, -789.49615479, 26.93969917, -17.38890076, 28.80275536, 0.31631017, 12.66160107, 0, -1 },
	{ 253, 2915143648, -802.17449951, 26.93021774, -22.33460617, 17.57381248, 0.33527383, 14.38553238, 0, -1 },
	{ 254, 2915142986, -827.55456543, 26.85717964, -47.87213135, 12.51331139, 0.48134816, 12.96804714, 0, -1 },
	{ 255, 2915143223, -777.050354, 26.96633911, -13.71142864, 12.9697113, 0.26303095, 12.96804523, 1, 0 },
	{ 256, 2915568624, -835.4163208, 28.57269859, -54.11056137, 10.88413811, 4.54334784, 0.70845366, -1, 0 },
	{ 257, 2915144183, -809.4888916, 26.93969917, -37.05972672, 28.16074944, 0.31631017, 13.35092068, -1, 0 },
	{ 258, 2915568624, -770.31420898, 28.77562141, -10.98491573, 10.88413811, 4.54334784, 0.70845366, 0, -1 },
	{ 259, 2915568624, -825.24853516, 28.77562141, -54.11056137, 10.88413811, 4.54334784, 0.70845366, -1, 0 },
	{ 260, 2915144878, -814.74127197, 26.9616642, -47.64472198, 12.96805, 0.27238089, 12.96805191, -1, 0 },
	{ 261, 2915568624, -815.41168213, 28.77562141, -54.11056137, 10.88413811, 4.54334784, 0.70845366, -1, 0 },
	{ 262, 2915144303, -802.46881104, 26.8809166, -47.64473724, 12.96805573, 0.4338747, 12.96804714, 1, 0 },
	{ 263, 2915144807, -789.79534912, 26.93909264, -37.23220062, 13.9099102, 0.31752485, 14.60615635, 0, -1.00000107 },
	{ 264, 2915142986, -777.05303955, 26.85717964, -24.33704758, 8.75633717, 0.48134816, 12.96804714, 0, 1 },
	{ 265, 2915568624, -770.31420898, 28.77562141, -20.62683487, 10.88413811, 4.54334784, 0.70845366, 0, -1 },
	{ 266, 2915568624, -795.55859375, 28.77562141, -54.11056137, 10.88413811, 4.54334784, 0.70845366, -1, 0 },
	{ 267, 2915568624, -805.37573242, 28.77562141, -54.11056137, 10.88413811, 4.54334784, 0.70845366, -1, 0 },
	{ 268, 2915143223, -789.84039307, 26.96633911, -48.55060196, 12.9697113, 0.26303095, 10.96804523, 1, 0 },
	{ 269, 2915568624, -770.31420898, 28.77562141, -30.61936378, 10.88413811, 4.54334784, 0.70845366, 0, -1 },
	{ 270, 2915143499, -777.05615234, 26.96633911, -35.00946808, 12.96971416, 0.26303095, 12.96809006, 1, 0 },
	{ 271, 2915568624, -785.39068604, 28.77562141, -54.11056137, 10.88413811, 4.54334784, 0.70845366, -1, 0 },
	{ 272, 2915144303, -777.05303955, 26.8809166, -47.64473724, 12.96805573, 0.4338747, 12.96804714, 1, 0 },
	{ 273, 2915568624, -770.31420898, 28.77562141, -40.26126862, 10.88413811, 4.54334784, 0.70845366, 0, -1 },
	{ 274, 2915568624, -775.57348633, 28.77562141, -54.11056137, 10.88413811, 4.54334784, 0.70845366, -1, 0 },
	{ 275, 2915568624, -770.31420898, 28.77562141, -49.72787476, 9.83229351, 4.54334784, 0.70845366, 0, -1 },
}
local canalTrim = {
	[40] = { Vector3.new(-1062.60322672, 28.3127346, 15.04290009), Vector3.new(11.8218565, 5.98587275, 426.72909344) },
	[107] = { Vector3.new(-839.49517822, 28.3127346, 59.4252926), Vector3.new(11.64654827, 5.98587275, 69.40990521) },
}

assert(RunService:IsStudio() and not RunService:IsRunning(), "Run the bend placement command in Studio Edit mode.")
local selected = Selection:Get()
assert((#selected == 1 or #selected == 2) and selected[1]:IsA("Model")
	and (#selected == 1 or selected[2]:IsA("Model")),
	"Select the imported bend Model. To replace the old corner, also select the original Track Model.")
local bend, track = selected[1], selected[2]
if track and bend.Name == "Track" then
	bend, track = track, bend
end
assert(not track or track ~= bend and not track:IsDescendantOf(bend), "Select the original Track separately from the bend.")
local markers, visuals, rolesSeen = {}, {}, {}
for _, child in ipairs(bend:GetDescendants()) do
	if child:IsA("BasePart") then
		-- Match names even when Studio strips punctuation or adds a numeric suffix.
		local key = child.Name:lower():gsub("[^%w]", ""):gsub("%d+$", "")
		local role = markerRoles[key]
		if role then
			assert(not markers[role], string.format("The imported bend contains duplicate %s markers.", role))
			markers[role] = child
		elseif child:IsA("MeshPart") then
			for _, style in ipairs(visualStyles) do
				if key:sub(1, #style.prefix) == style.prefix then
					visuals[child] = style
					rolesSeen[style.prefix] = true
					break
				end
			end
		end
	end
end
assert(markers.entry and markers.forward and markers.up,
	"Import the complete bend as a Model with Merge Meshes off so its three placement markers remain separate.")
assert(rolesSeen.bendpavingslate and rolesSeen.bendpavingdark and rolesSeen.bendwallneutral,
	"Import all the separate paving and wall meshes together with the bend markers.")
local oldCollision = bend:FindFirstChild(collisionName)
assert(not oldCollision or oldCollision:GetAttribute("GeneratedTrackBendCollision"),
	"Rename the existing Track Bend Collision folder before running the command.")

local function markerFrame()
	local origin = markers.entry.Position
	local forward = markers.forward.Position - origin
	local up = markers.up.Position - origin
	local forwardLength, upLength = forward.Magnitude, up.Magnitude
	local expectedLength = (forwardLength + upLength) / 2
	assert(math.min(forwardLength, upLength) > .0001
		and math.abs(forwardLength - upLength) <= .005 * expectedLength
		and math.abs(forward.Unit:Dot(up.Unit)) <= .005,
		"The bend markers have moved or were imported at different scales. Reimport the complete bend.")
	return CFrame.lookAt(origin, origin + forward, up), expectedLength / markerDistance
end

local function originalParts(model)
	local matched = {}
	local children = model:GetChildren()
	for _, reference in ipairs(originalReferences) do
		local id, mesh, x, y, z, sx, sy, sz, rx, rz = table.unpack(reference)
		local meshId = "rbxassetid://" .. mesh
		local position, size, right = Vector3.new(x, y, z), Vector3.new(sx, sy, sz), Vector3.new(rx, 0, rz)
		for _, part in ipairs(children) do
			if part:IsA("MeshPart") and part.MeshId == meshId
				and (part.Position - position).Magnitude < .01
				and (part.Size - size).Magnitude < .01
				and (part.CFrame.RightVector - right).Magnitude < .001
				and (part.CFrame.UpVector - Vector3.yAxis).Magnitude < .001 then
				assert(not matched[id], string.format("Original Track piece %d matches more than one part.", id))
				matched[id] = part
			end
		end
		assert(matched[id], string.format(
			"Could not verify original Track piece %d at its uploaded position. Select the unmodified Track or place the bend on its own.",
			id))
	end
	return matched
end

local rollback = {}

local function reparent(instance, parent)
	local original = instance.Parent
	table.insert(rollback, function()
		instance.Parent = original
	end)
	instance.Parent = parent
end

local function discardOnFailure(instance, holdsOriginals)
	table.insert(rollback, function()
		-- Keep a recovery folder intact if Studio refused to restore one
		-- of the original instances inside it.
		assert(not holdsOriginals or #instance:GetChildren() == 0, "Original instances remain in " .. instance.Name)
		instance:Destroy()
	end)
	return instance
end

local function rememberProperties(instance, names)
	local old = {}
	for _, name in ipairs(names) do
		old[name] = instance[name]
	end
	table.insert(rollback, function()
		for _, name in ipairs(names) do
			instance[name] = old[name]
		end
	end)
end

local function archiveCorner(parts)
	local backup = discardOnFailure(Instance.new("Folder"), true)
	backup.Name = "Fun Run 6 Original Bend"
	backup.Parent = ServerStorage

	for id, trim in pairs(canalTrim) do
		local part = parts[id]
		local clone = assert(part:Clone(), "Could not clone the original inner canal strip.")
		discardOnFailure(clone)
		local frame = part.CFrame
		clone.Size = trim[2]
		clone.CFrame = CFrame.fromMatrix(trim[1], frame.RightVector, frame.UpVector, frame.LookVector * -1)
		clone.Parent = track
	end
	for _, part in pairs(parts) do
		reparent(part, backup)
	end
	reparent(bend, track)
end

local function configureCollider(part, name, frame, size, parent)
	part.Name = name
	part.Size = size
	part.CFrame = frame
	part.Anchored = true
	part.Transparency = 1
	part.CastShadow = false
	part.CanCollide = true
	part.CanTouch = false
	part.CanQuery = true
	part.Material = Enum.Material.Concrete
	part.Parent = parent
end

local function makePrismPair(parent, name, thickness, a, b, c)
	-- Split a road-plane triangle along its altitude. Each native WedgePart
	-- lies on its side, with the local X dimension providing the thickness.
	if (a - c).Magnitude > (b - c).Magnitude then
		a, b = b, a
	end
	if (a - b).Magnitude > (b - c).Magnitude then
		a, c = c, a
	end
	local along = (c - b).Unit
	local foot = b + along * (a - b):Dot(along)
	local height = (a - foot).Magnitude
	local up = (a - foot).Unit
	for _, tip in ipairs({ b, c }) do
		local run = (foot - tip).Magnitude
		if run > .001 then
			local back = (foot - tip).Unit
			local frame = CFrame.fromMatrix((a + tip) * .5, up:Cross(back), up, back)
			configureCollider(Instance.new("WedgePart"), name, frame, Vector3.new(thickness, height, run), parent)
		end
	end
end

local function curvePoint(t, offset, height)
	local angle = t * math.pi / 2
	local distance = radius - offset
	return entryOrigin + Vector3.new(distance * math.sin(angle), height, radius - distance * math.cos(angle))
end

local function halfWidth(t)
	return entryHalfWidth + (exitHalfWidth - entryHalfWidth) * (t * t * (3 - 2 * t))
end

local function apron(parent, endpoint, direction, width, floorLength, wallLength)
	local right = direction:Cross(Vector3.yAxis)
	local center = endpoint + direction * (floorLength / 2) + Vector3.new(0, -.35, 0)
	configureCollider(Instance.new("Part"), "Driving apron", CFrame.lookAt(center, center + direction, Vector3.yAxis),
		Vector3.new(width * 2, .70, floorLength), parent)
	for _, side in ipairs({ -1, 1 }) do
		local wallCenter = endpoint + direction * (wallLength / 2) + right * ((width + wallWidth / 2) * side)
			+ Vector3.new(0, wallHeight / 2, 0)
		configureCollider(Instance.new("Part"), "Wall apron", CFrame.lookAt(wallCenter, wallCenter + direction, Vector3.yAxis),
			Vector3.new(wallWidth, wallHeight, wallLength), parent)
	end
end

local function colliders(parent)
	local subdivisions = 18
	for index = 0, subdivisions - 1 do
		local a, b = index / subdivisions, (index + 1) / subdivisions
		local wa, wb = halfWidth(a), halfWidth(b)
		for _, strip in ipairs({
			{ "Driving surface", -wa, wa, -wb, wb, 0, .70 },
			{ "Inside wall", wa, wa + wallWidth, wb, wb + wallWidth, wallHeight, wallHeight },
			{ "Outside wall", -wa - wallWidth, -wa, -wb - wallWidth, -wb, wallHeight, wallHeight },
		}) do
			local name, la, ra, lb, rb, top, thickness = table.unpack(strip)
			local y = top - thickness * .5
			local left0, right0 = curvePoint(a, la, y), curvePoint(a, ra, y)
			local left1, right1 = curvePoint(b, lb, y), curvePoint(b, rb, y)
			makePrismPair(parent, name, thickness, left0, right0, right1)
			makePrismPair(parent, name, thickness, left0, right1, left1)
		end
	end
	apron(parent, entryOrigin, Vector3.xAxis * -1, entryHalfWidth, entryOrigin.X + 859.986, entryOrigin.X + 853.547)
	local exit = curvePoint(1, 0, 0)
	apron(parent, exit, Vector3.zAxis, exitHalfWidth, 31.2723 - exit.Z, 33.9013 - exit.Z)
end

local function styleImportedMeshes()
	local savedAppearance
	for part, style in pairs(visuals) do
		-- Store the importer's PBR overrides so the original Roblox atlas
		-- and MeshPart color control the visible surface.
		for _, child in ipairs(part:GetChildren()) do
			if child:IsA("SurfaceAppearance") then
				if not savedAppearance then
					savedAppearance = discardOnFailure(Instance.new("Folder"), true)
					savedAppearance.Name = "Imported Bend Appearance"
					savedAppearance.Parent = bend
				end
				reparent(child, savedAppearance)
			end
		end
		rememberProperties(part, {
			"Anchored", "CanCollide", "CanTouch", "CanQuery", "Material", "MaterialVariant", "Reflectance", "Color", "TextureID",
		})
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Material = Enum.Material.Concrete
		part.MaterialVariant = ""
		part.Reflectance = 0
		part.Color = style.color
		part.TextureID = if style.plain then "" else originalTexture
	end
end

local frame, scale = markerFrame()
local partsToArchive = if track then originalParts(track) else nil
local initialScale, initialPivot = bend:GetScale(), bend:GetPivot()
local historyOk, recording = pcall(function()
	return ChangeHistoryService:TryBeginRecording("PlaceFunRun6Bend", "Place Fun Run 6 track bend")
end)
if not historyOk then
	recording = nil
end
local waypoints = false
if not recording then
	-- The Command Bar may run while a plugin holds the active recording.
	-- Try a legacy undo waypoint and preserve the original corner either way.
	waypoints = pcall(function()
		ChangeHistoryService:SetWaypoint("Before placing Fun Run 6 bend")
	end)
end

local success, message = pcall(function()
	local collision = discardOnFailure(Instance.new("Folder"))
	collision.Name = collisionName
	collision:SetAttribute("GeneratedTrackBendCollision", true)
	colliders(collision)

	table.insert(rollback, function()
		if math.abs(bend:GetScale() - initialScale) > .00001 then
			bend:ScaleTo(initialScale)
		end
		bend:PivotTo(initialPivot)
	end)
	if math.abs(scale - 1) > .00001 then
		bend:ScaleTo(bend:GetScale() / scale)
		frame, scale = markerFrame()
		assert(math.abs(scale - 1) < .001, "Studio could not scale the imported bend to the required width.")
	end
	bend:PivotTo(entryTarget * frame:ToObjectSpace(bend:GetPivot()))

	styleImportedMeshes()
	for _, marker in pairs(markers) do
		rememberProperties(marker, { "Anchored", "Transparency", "CanCollide", "CanTouch", "CanQuery", "CastShadow" })
		marker.Anchored = true
		marker.Transparency = 1
		marker.CanCollide = false
		marker.CanTouch = false
		marker.CanQuery = false
		marker.CastShadow = false
	end
	if oldCollision then
		reparent(oldCollision, nil)
	end
	collision.Parent = bend
	if partsToArchive then
		archiveCorner(partsToArchive)
	end
end)
if not success then
	for i = #rollback, 1, -1 do
		local restored, reason = pcall(rollback[i])
		if not restored then
			warn("Track bend recovery: " .. tostring(reason))
		end
	end
end

if recording then
	local finished = pcall(function()
		ChangeHistoryService:FinishRecording(recording,
			if success then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
	end)
	if success and not finished then
		warn("The bend was placed but Studio could not finish the undo recording.")
	end
elseif waypoints and success then
	pcall(function()
		ChangeHistoryService:SetWaypoint("Placed Fun Run 6 bend")
	end)
end
assert(success, message)
if partsToArchive then
	print("Installed the bend. Original corner parts are in ServerStorage under Fun Run 6 Original Bend.")
else
	print("Placed the bend at the original track entrance.")
end
