local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local system = ReplicatedStorage:WaitForChild("VolcanicLava")
local Config = require(system.Config)
local Surface = require(system.Surface)
local MoltenTexture = require(system.MoltenTexture)
local Emissions = require(system.Emissions)

local budget = Config.Budget
local mobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local maxSurfaces = mobile and budget.MobileVisualPools or budget.MaxVisualPools
local maxAtmospheres = mobile and budget.MobileAtmospherePools or budget.MaxAtmospherePools
local poolRecords = {}
local seconds = 0
local nextScan = 0
local scanStep = .25
local root = Instance.new("Folder")
root.Name = "VolcanicLavaClientEffects"
root.Parent = Workspace

local function dropAtmosphere(record)
	if record.emissions then
		record.emissions:Destroy()
		record.emissions = nil
	end
end

local function clear(record)
	dropAtmosphere(record)
	if record.image then
		record.image:Destroy()
		record.image = nil
	end
	if record.surface then
		record.surface:Destroy()
		record.surface = nil
	end
	if record.folder then
		record.folder:Destroy()
		record.folder = nil
	end
end

local function track(part)
	if not part:IsA("BasePart") or poolRecords[part] then
		return
	end
	local record = {part = part, lod = 0, nextFrame = 0, lastUpdate = 0}
	local function changed(attribute)
		if not attribute or Config.Defaults[attribute] ~= nil then
			record.needsRefresh = true
			nextScan = 0
		end
	end
	record.attributes = part.AttributeChanged:Connect(changed)
	record.resized = part:GetPropertyChangedSignal("Size"):Connect(changed)
	poolRecords[part] = record
	nextScan = 0
end

local function untrack(part)
	local record = poolRecords[part]
	if record then
		record.attributes:Disconnect()
		record.resized:Disconnect()
		clear(record)
		poolRecords[part] = nil
		nextScan = 0
	end
end

local function create(record)
	local folder = Instance.new("Folder")
	folder.Name = record.part.Name .. "_LavaVisuals"
	folder.Parent = root
	record.folder = folder
	local settings = Config.forPart(record.part, mobile)
	record.settings = settings
	record.surface = Surface.new(record.part, folder, settings)
	if settings.UseEditableTexture then
		record.image = MoltenTexture.new(record.surface.TextureCarrier or record.part, folder, settings)
	end
	record.needsRefresh = nil
	record.nextFrame = 0
	record.lastUpdate = seconds
end

local function distanceToSurface(part, worldPoint)
	local point = part.CFrame:PointToObjectSpace(worldPoint)
	local half = part.Size * .5
	local x = math.max(0, math.abs(point.X) - half.X)
	local z = math.max(0, math.abs(point.Z) - half.Z)
	local height = point.Y - half.Y
	return math.sqrt(x * x + height * height + z * z)
end

local function rescan(camera)
	local candidates = {}
	for part, record in pairs(poolRecords) do
		if part:IsDescendantOf(Workspace) then
			local distance = distanceToSurface(part, camera.CFrame.Position)
			local heldRange = record.surface and 24 or 0
			if distance <= budget.MaxDistance + heldRange then
				record.distance = distance
				record.rank = distance - (record.surface and 12 or 0)
				table.insert(candidates, record)
			else
				clear(record)
			end
		else
			clear(record)
		end
	end
	table.sort(candidates, function(a, b)
		return a.rank < b.rank
	end)

	local remainingBuilds = 1
	local atmosphereSlots = maxAtmospheres
	for index, record in ipairs(candidates) do
		if index <= maxSurfaces then
			if remainingBuilds > 0 and (not record.surface or record.needsRefresh) then
				clear(record)
				create(record)
				remainingBuilds -= 1
			end
			if record.surface then
				local fade = math.clamp((record.distance - budget.NearDistance)
					/ (budget.MaxDistance - budget.NearDistance), 0, 1)
				record.lod = 1 - .82 * fade
				if atmosphereSlots > 0 and record.distance < budget.AtmosphereDistance + (record.emissions and 12 or 0) then
					atmosphereSlots -= 1
					if not record.emissions then
						record.emissions = Emissions.new(record.part, record.folder, record.settings)
					end
					record.atmosphereLOD = 1 - math.clamp((record.distance - budget.NearDistance)
						/ (budget.AtmosphereDistance - budget.NearDistance), 0, 1)
				else
					dropAtmosphere(record)
				end
			end
		else
			clear(record)
		end
	end
end

local added = CollectionService:GetInstanceAddedSignal(Config.Tag):Connect(track)
local removed = CollectionService:GetInstanceRemovedSignal(Config.Tag):Connect(untrack)
for _, part in ipairs(CollectionService:GetTagged(Config.Tag)) do
	track(part)
end

local heartbeat = RunService.Heartbeat:Connect(function(dt)
	seconds += dt
	local camera = Workspace.CurrentCamera
	if camera and seconds >= nextScan then
		nextScan = seconds + scanStep
		rescan(camera)
	end
	for _, record in pairs(poolRecords) do
		if record.surface and seconds >= record.nextFrame then
			local frameRate = 12 + (mobile and 20 or 36) * record.lod
			local interval = 1 / frameRate
			record.nextFrame = math.max(record.nextFrame + interval, seconds + .002)
			local delta = math.min(.25, seconds - record.lastUpdate)
			record.lastUpdate = seconds
			record.surface:Update(seconds, record.lod)
			if record.image then
				record.image:Update(seconds, record.lod)
			end
			if record.emissions then
				record.emissions:Update(seconds, delta, record.atmosphereLOD)
			end
		end
	end
end)

script.Destroying:Connect(function()
	added:Disconnect()
	removed:Disconnect()
	heartbeat:Disconnect()
	for part in pairs(poolRecords) do
		untrack(part)
	end
	root:Destroy()
end)
