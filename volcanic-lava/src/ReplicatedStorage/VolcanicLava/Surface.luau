-- Client-only visual surface. It fits over the source without touching its
-- transform, visual properties, collisions, or gameplay scripts.
local Workspace = game:GetService("Workspace")

local Surface = {}
Surface.__index = Surface

local MOLTEN_LOW = Color3.fromRGB(143, 22, 8)
local MOLTEN_HIGH = Color3.fromRGB(218, 48, 8)
local CURRENT_EDGE = Color3.fromRGB(232, 50, 5)
local CURRENT_CORE = Color3.fromRGB(255, 142, 19)
local WHITE_HOT = Color3.fromRGB(255, 222, 101)
local CRUST_DARK = Color3.fromRGB(23, 22, 22)
local CRUST_LIGHT = Color3.fromRGB(56, 50, 47)
local TAU = 2 * math.pi
local BED_TOP = 0.034
local BED_DEPTH = 0.027

local function makePart(className, name, material, color, folder)
	local part = Instance.new(className)
	part.Name = name
	part.Material = material
	part.Color = color
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Massless = true
	part.Parent = folder
	return part
end

local function clipCell(polygon, site, neighbor)
	local direction = neighbor - site
	local threshold = ((site + neighbor) * 0.5):Dot(direction)
	local clipped = {}
	local previous = polygon[#polygon]
	local previousDistance = previous:Dot(direction) - threshold
	for _, point in polygon do
		local distance = point:Dot(direction) - threshold
		if (previousDistance <= 0) ~= (distance <= 0) then
			local t = previousDistance / (previousDistance - distance)
			table.insert(clipped, previous:Lerp(point, t))
		end
		if distance <= 0 then
			table.insert(clipped, point)
		end
		previous = point
		previousDistance = distance
	end
	return clipped
end

local function addTriangle(a, b, c, thickness, color, folder, wedges)
	local ab, ac, bc = b - a, c - a, c - b
	local ab2, ac2, bc2 = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	-- Put the longest edge across B–C so the two right wedges stay in
	-- the triangle. This works for both upward and downward sloping tops.
	if ab2 > ac2 and ab2 > bc2 then
		a, c = c, a
	elseif ac2 > bc2 and ac2 >= ab2 then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b
	local axis = ac:Cross(ab)
	if axis.Magnitude < 0.0002 or bc.Magnitude < 0.005 then
		return
	end
	local right = axis.Unit
	local back = bc.Unit
	local up = back:Cross(right).Unit
	local height = math.abs(ab:Dot(up))
	if height < 0.005 then
		return
	end

	local function wedge(length, position, x, z)
		if length < 0.005 then
			return
		end
		local part = makePart("WedgePart", "Basalt facet", Enum.Material.Basalt, color, folder)
		part.Size = Vector3.new(thickness, height, length)
		table.insert(wedges, {
			part = part,
			localFrame = CFrame.fromMatrix(position, x, up, z),
		})
	end
	wedge(math.abs(ab:Dot(back)), (a + b) * 0.5, right, back)
	wedge(math.abs(ac:Dot(back)), (a + c) * 0.5, -right, -back)
end

local function sitesFor(width, depth, quality, random)
	local target = math.floor(8 + 8 * quality)
	local columns = math.clamp(math.floor(math.sqrt(target * width / depth) + 0.5), 1, target)
	local rows = math.max(1, math.floor(target / columns))
	local tileX, tileZ = width / columns, depth / rows
	local sites = {}
	for row = 1, rows do
		for column = 1, columns do
			local x = (column - 0.5 + random:NextNumber(-0.28, 0.28)) * tileX - width * 0.5
			local z = (row - 0.5 + random:NextNumber(-0.28, 0.28)) * tileZ - depth * 0.5
			table.insert(sites, Vector2.new(x, z))
		end
	end
	return sites
end

local function makeCrust(width, depth, quality, relief, random, folder)
	local halfX, halfZ = width * 0.5, depth * 0.5
	local bounds = {
		Vector2.new(-halfX, -halfZ), Vector2.new(halfX, -halfZ),
		Vector2.new(halfX, halfZ), Vector2.new(-halfX, halfZ),
	}
	local sites = sitesFor(width, depth, quality, random)
	local plates = {}
	local scale = math.min(width, depth)
	local thickness = math.min(scale * .075, .043)
	local clearance = thickness * .51
	for index, site in sites do
		local polygon = bounds
		for neighborIndex, neighbor in sites do
			if index ~= neighborIndex then
				polygon = clipCell(polygon, site, neighbor)
			end
		end
		local center = Vector2.zero
		for _, point in polygon do
			center += point
		end
		center /= #polygon
		-- The dark plate contracts inside its Voronoi cell, leaving a
		-- branching bed visible between irregular, non-overlapping shards.
		local inset = random:NextNumber(0.83, 0.91)
		local altitude = (0.111 + random:NextNumber(-0.009, 0.012)) * relief
		local points = {}
		local edge = math.huge
		for _, point in polygon do
			local sample = center:Lerp(point, inset)
			local position = Vector2.new(
				math.clamp(sample.X, -halfX + clearance, halfX - clearance),
				math.clamp(sample.Y, -halfZ + clearance, halfZ - clearance)
			)
			edge = math.min(edge, halfX - math.abs(position.X), halfZ - math.abs(position.Y))
			table.insert(points, Vector3.new(
				position.X,
				altitude + random:NextNumber(-0.009, 0.011) * relief,
				position.Y
			))
		end
		local base = random:NextNumber(0.05, 0.82)
		local wedges = {}
		for i = 2, #points - 1 do
			local variation = math.clamp(base + random:NextNumber(-0.10, 0.15), 0, 1)
			local color = CRUST_DARK:Lerp(CRUST_LIGHT, variation)
			addTriangle(points[1], points[i], points[i + 1], thickness, color, folder, wedges)
		end
		table.insert(plates, {
			wedges = wedges,
			phase = random:NextNumber(0, TAU),
			period = random:NextNumber(9, 16),
			travel = math.min(math.max(0, edge - clearance), 0.32, scale * 0.020),
		})
	end
	return plates
end

local function lineBounds(crossPoint, direction, halfX, halfZ)
	local start, finish = -math.huge, math.huge
	local function cut(offset, rate, half)
		if math.abs(rate) < 0.0001 then
			return math.abs(offset) <= half
		end
		local a, b = (-half - offset) / rate, (half - offset) / rate
		start = math.max(start, math.min(a, b))
		finish = math.min(finish, math.max(a, b))
		return start < finish
	end
	if cut(crossPoint.X, direction.X, halfX) and cut(crossPoint.Y, direction.Y, halfZ) then
		return start, finish
	end
	return nil, nil
end

local function makeCurrent(width, depth, direction, quality, relief, random, folder)
	local halfX, halfZ = width * 0.5, depth * 0.5
	local perpendicular = Vector2.new(-direction.Y, direction.X)
	local crossHalf = math.abs(perpendicular.X) * halfX + math.abs(perpendicular.Y) * halfZ
	local size = math.min(width, depth)
	local count = math.floor(4 + 8 * quality)
	local streaks = {}
	for i = 1, count do
		local long = size * random:NextNumber(0.059, 0.142)
		local wide = size * random:NextNumber(0.012, 0.032)
		local paddingX = (math.abs(direction.X) * long + math.abs(perpendicular.X) * wide) * 0.5
		local paddingZ = (math.abs(direction.Y) * long + math.abs(perpendicular.Y) * wide) * 0.5
		local p = ((i - 0.5) / count * 2 - 1) * 0.82 + random:NextNumber(-0.07, 0.07)
		local origin = perpendicular * (p * crossHalf)
		local start, finish = lineBounds(origin, direction, halfX - paddingX, halfZ - paddingZ)
		if start == nil or finish == nil then
			continue
		end

		local band = makePart("Part", "Molten flow pulse", Enum.Material.Neon, CURRENT_EDGE, folder)
		band.Shape = Enum.PartType.Cylinder
		band.Size = Vector3.new(0.013 * relief, wide, long)
		local core
		if i % 2 == 1 then
			core = makePart("Part", "Hot vein", Enum.Material.Neon, CURRENT_CORE, folder)
			core.Shape = Enum.PartType.Cylinder
			core.Size = Vector3.new(0.010 * relief, wide * 0.46, long * 0.69)
		end
		table.insert(streaks, {
			band = band,
			core = core,
			origin = origin,
			start = start,
			distance = finish - start,
			phase = random:NextNumber(),
			speed = random:NextNumber(0.69, 1.67),
		})
	end
	return streaks
end

function Surface.new(part, parent, config)
	local width, depth = part.Size.X, part.Size.Z
	local quality = math.clamp(config.AnimationQuality or 0.85, 0.25, 1)
	local relief = math.clamp(math.min(width, depth) / .67, .06, 1)
	local direction = config.FlowDirection or Vector2.new(0.96, 0.28)
	direction = if direction.Magnitude > 0.0001 then direction.Unit else Vector2.new(1, 0)
	-- Repeatable across clients, with variation between pools.
	local seed = math.floor((part.Position.X * 197 + part.Position.Y * 73 + part.Position.Z * 133
		+ width * 157 + depth * 331) * 97) % 2147483647
	local random = Random.new(seed)
	local folder = Instance.new("Folder")
	folder.Name = "Animated lava surface"
	folder.Parent = parent

	local bed = makePart("Part", "Molten bed", Enum.Material.Neon, MOLTEN_LOW, folder)
	bed.Size = Vector3.new(width, BED_DEPTH * relief, depth)
	local plates = makeCrust(width, depth, quality, relief, random, folder)
	local flow = makeCurrent(width, depth, direction, quality, relief, random, folder)
	local parts = {}
	local frames = {}
	for _, plate in plates do
		for _, wedge in plate.wedges do
			table.insert(parts, wedge.part)
			table.insert(frames, CFrame.identity)
		end
	end
	local self = setmetatable({
		TextureCarrier = bed,
		relief = relief,
		source = part,
		folder = folder,
		plates = plates,
		flow = flow,
		direction = direction,
		cross = Vector2.new(-direction.Y, direction.X),
		speed = math.max(0, config.LavaFlowSpeed or 0.72),
		glow = math.clamp(config.GlowIntensity or 0.78, 0, 2),
		brightness = math.clamp(config.LavaBrightness or 0.96, 0, 2),
		phase = random:NextNumber(0, TAU),
		lastCrust = -math.huge,
		lastFrame = nil,
		parts = parts,
		frames = frames,
	}, Surface)
	self:Update(0, 1)
	return self
end

function Surface:Update(time, lod)
	local frame = self.source.CFrame * CFrame.new(0, self.source.Size.Y * 0.5, 0)
	local moved = frame ~= self.lastFrame
	local weight = math.clamp(lod, 0, 1)
	local shimmer = 0.5 + 0.25 * math.sin(time * 0.51 + self.phase)
		+ 0.17 * math.sin(time * 1.37 - self.phase)
	local heat = math.clamp(self.brightness * (0.18 + 0.34 * self.glow + shimmer * 0.14), 0, 1)
	self.TextureCarrier.Color = MOLTEN_LOW:Lerp(MOLTEN_HIGH, heat)
	if moved then
		self.TextureCarrier.CFrame = frame * CFrame.new(0, (BED_TOP - BED_DEPTH * 0.5) * self.relief, 0)
	end

	local minInterval = if weight < 0.22 then 0.19 else 0
	if moved or time < self.lastCrust or time - self.lastCrust >= minInterval then
		local index = 0
		for _, plate in self.plates do
			local phase = time * self.speed * TAU / plate.period + plate.phase
			local offset = self.direction * (plate.travel * 0.74 * math.sin(phase))
				+ self.cross * (plate.travel * 0.26 * math.sin(phase * 0.69 + 1.5))
			local base = frame * CFrame.new(offset.X, 0.007 * self.relief * math.sin(phase * 0.82), offset.Y)
			for _, wedge in plate.wedges do
				index += 1
				self.frames[index] = base * wedge.localFrame
			end
		end
		if #self.parts > 0 then
			Workspace:BulkMoveTo(self.parts, self.frames, Enum.BulkMoveMode.FireCFrameChanged)
		end
		self.lastCrust = time
	end

	local activity = 0.34 + weight * 0.66
	local pulseColor = CURRENT_EDGE:Lerp(CURRENT_CORE, math.clamp(self.glow * 0.43, 0, 0.78))
	local veinColor = CURRENT_CORE:Lerp(WHITE_HOT, math.clamp(self.glow * 0.36, 0, 1))
	local direction = Vector3.new(self.direction.X, 0, self.direction.Y)
	local cross = Vector3.new(self.cross.X, 0, self.cross.Y)
	for _, streak in self.flow do
		local progress = (time * self.speed * streak.speed / streak.distance + streak.phase) % 1
		local center = streak.origin + self.direction * (streak.start + progress * streak.distance)
		local fade = math.min(progress * 8, (1 - progress) * 8, 1)
		local turbulence = 0.78 + 0.22 * math.sin(time * 1.32 + streak.phase * TAU)
		local alpha = math.clamp(fade * turbulence * activity * self.brightness, 0, 1)
		-- Cylinder axis is local X; local Z follows the stream.
		local bedPosition = Vector3.new(center.X, (BED_TOP + 0.012) * self.relief, center.Y)
		local pose = CFrame.fromMatrix(bedPosition, Vector3.yAxis, cross, direction)
		streak.band.CFrame = frame * pose
		streak.band.Color = pulseColor
		streak.band.Transparency = 1 - alpha * 0.96
		if streak.core then
			streak.core.CFrame = frame * (pose + Vector3.new(0, 0.007 * self.relief, 0))
			streak.core.Color = veinColor
			streak.core.Transparency = 1 - alpha * math.clamp(self.glow * 0.82, 0, 0.98)
		end
	end
	self.lastFrame = frame
end

function Surface:Destroy()
	self.folder:Destroy()
end

return Surface
