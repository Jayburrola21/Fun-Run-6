-- Generated Studio installer for Volcanic Lava. Paste the entire file in Studio's Edit-mode Command Bar.
local RunService = game:GetService("RunService")
assert(RunService:IsStudio() and not RunService:IsRunning(), "Run the Volcanic Lava installer before pressing Play.")

local entries = {
	{ name = "Config", kind = "ModuleScript", code = [[local Config = {}

Config.Tag = "VolcanicLava"

Config.Defaults = table.freeze({
	LavaFlowSpeed = .72,
	GlowIntensity = .78,
	SparkEmissionRate = 26,
	BubbleFrequency = .48,
	LavaBrightness = .96,
	SmokeDensity = .34,
	AnimationQuality = .85,
	FlowAngle = 16,
	UseEditableTexture = true,
})

Config.Budget = table.freeze({
	NearDistance = 80,
	AtmosphereDistance = 185,
	MaxDistance = 480,
	MaxVisualPools = 6,
	MaxAtmospherePools = 3,
	MobileVisualPools = 4,
	MobileAtmospherePools = 2,
})

local limits = {
	LavaFlowSpeed = {.05, 4},
	GlowIntensity = {0, 2},
	SparkEmissionRate = {0, 75},
	BubbleFrequency = {0, 2.5},
	LavaBrightness = {.26, 1.65},
	SmokeDensity = {0, 1},
	AnimationQuality = {.25, 1},
	FlowAngle = {-360, 360},
}

local function finite(value)
	return type(value) == "number" and math.abs(value) < math.huge
end

function Config.forPart(part, mobile)
	local settings = table.clone(Config.Defaults)
	for field, bounds in pairs(limits) do
		local value = part:GetAttribute(field)
		if finite(value) then
			settings[field] = math.clamp(value, bounds[1], bounds[2])
		end
	end

	local imagePreference = part:GetAttribute("UseEditableTexture")
	if type(imagePreference) == "boolean" then
		settings.UseEditableTexture = imagePreference
	end
	if mobile then
		settings.AnimationQuality = math.min(settings.AnimationQuality, .70)
	end

	local angle = math.rad(settings.FlowAngle)
	settings.FlowDirection = Vector2.new(math.cos(angle), math.sin(angle))
	return settings
end

return Config
]] },
	{ name = "Surface", kind = "ModuleScript", code = [[-- Client-only visual surface. It fits over the source without touching its
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
]] },
	{ name = "MoltenTexture", kind = "ModuleScript", code = [[-- Optional detail pass. The same editable image is shared by every local pool.
local AssetService = game:GetService("AssetService")

local MoltenTexture = {}
MoltenTexture.__index = MoltenTexture

local RESOLUTION = 192
local TAU = math.pi * 2
local COLOR_STOPS = {
    { 0.00, 55, 7, 4 },
    { 0.26, 107, 18, 5 },
    { 0.47, 186, 36, 4 },
    { 0.62, 236, 68, 8 },
    { 0.78, 255, 126, 16 },
    { 0.92, 255, 189, 37 },
    { 1.00, 255, 230, 116 },
}

local image
local whiteMask
local users = 0
local unavailable = false

local function smooth(t)
    return t * t * (3 - 2 * t)
end

local function mix(a, b, t)
    return a + (b - a) * t
end

local function grid(random, width, height)
    local values = table.create(width * height)
    for index = 1, width * height do
        values[index] = random:NextNumber()
    end
    return { width = width, height = height, values = values }
end

local function noise(field, u, v)
    -- Wrap both axes so the gradients meet exactly at every tile edge.
    local width, height, values = field.width, field.height, field.values
    local x, y = (u % 1) * width, (v % 1) * height
    local x0, y0 = math.floor(x), math.floor(y)
    local x1, y1 = (x0 + 1) % width, ((y0 + 1) % height) * width
    local tx, ty = smooth(x - x0), smooth(y - y0)
    y0 *= width
    return mix(
        mix(values[y0 + x0 + 1], values[y0 + x1 + 1], tx),
        mix(values[y1 + x0 + 1], values[y1 + x1 + 1], tx),
        ty
    )
end

local function byte(value)
    return math.clamp(math.floor(value + .5), 0, 255)
end

local function color(heat)
    for index = 2, #COLOR_STOPS do
        local a, b = COLOR_STOPS[index - 1], COLOR_STOPS[index]
        if heat <= b[1] then
            local t = (heat - a[1]) / (b[1] - a[1])
            return byte(mix(a[2], b[2], t)), byte(mix(a[3], b[3], t)), byte(mix(a[4], b[4], t))
        end
    end
    return 255, 230, 116
end

local function makePixels()
    local random = Random.new(745981)
    local warpU, warpV = grid(random, 4, 6), grid(random, 6, 4)
    local pools, streams = grid(random, 5, 6), grid(random, 5, 13)
    local detail, flecks = grid(random, 12, 21), grid(random, 36, 40)
    local pixels = buffer.create(RESOLUTION * RESOLUTION * 4)

    for y = 0, RESOLUTION - 1 do
        local v = (y + .5) / RESOLUTION
        for x = 0, RESOLUTION - 1 do
            local u = (x + .5) / RESOLUTION
            local a = u + .18 * (noise(warpU, u, v) - .5) + .033 * math.sin(TAU * (v + .3 * math.sin(TAU * u)))
            local b = v + .23 * (noise(warpV, u, v) - .5) + .055 * math.sin(TAU * (u + .14 * math.sin(TAU * v)))
            local broad = noise(pools, a, b)
            local stream = noise(streams, a, b)
            local core = math.max(0, 1 - math.abs(stream - .49) * 5.8) ^ 2
            local shoulder = math.max(0, 1 - math.abs(stream - .46) * 2.6)
            local grain = .62 * noise(detail, a, b) + .38 * noise(flecks, a, b)
            local heat = math.clamp(.075 + .57 * broad + .32 * core + .135 * shoulder + .11 * grain, 0, 1)
            local r, g, blue = color(heat)
            local opacity = byte(138 + 105 * math.min(1, broad * .57 + core * .43 + shoulder * .25))
            local pixel = (y * RESOLUTION + x) * 4
            buffer.writeu32(pixels, pixel, r + g * 256 + blue * 65536 + opacity * 16777216)
        end
    end

    return pixels
end

local function destroyImage(object)
    if object ~= nil then
        object:Destroy()
    end
end

local function ensureImage()
    if image or unavailable then
        return image
    end

    local created
    local ok, result = pcall(function()
        local size = Vector2.new(RESOLUTION, RESOLUTION)
        created = AssetService:CreateEditableImage({ Size = size })
        if created then
            created:WritePixelsBuffer(Vector2.zero, size, makePixels())
        end
        return created
    end)
    if not ok or not result then
        destroyImage(created)
        unavailable = true
        return nil
    end
    image = result

    -- Optional leased four-pixel emission mask. If no budget remains, color
    -- still scrolls over the illuminated molten bed.
    local createdMask
    local maskOk, mask = pcall(function()
        local size = Vector2.new(2, 2)
        createdMask = AssetService:CreateEditableImage({ Size = size })
        if createdMask then
            local pixels = buffer.create(16)
            buffer.fill(pixels, 0, 255)
            createdMask:WritePixelsBuffer(Vector2.zero, size, pixels)
        end
        return createdMask
    end)
    if maskOk then
        whiteMask = mask
    else
        destroyImage(createdMask)
    end
    return image
end

local function release()
    if users == 0 then
        destroyImage(image)
        destroyImage(whiteMask)
        image = nil
        whiteMask = nil
    end
end

local function amount(value, default, minimum, maximum)
    if type(value) ~= "number" or value ~= value then
        return default
    end
    return math.clamp(value, minimum, maximum)
end

-- carrier is the visible BasePart under the crust, so Texture clips
-- to its true top face with no extra overlay part.
function MoltenTexture.new(carrier, _folder, config)
    if config.UseEditableTexture == false or not ensureImage() then
        return nil
    end

    local detail = Instance.new("Texture")
    local studsU = math.clamp(carrier.Size.X * .64, 12, 30)
    local studsV = math.clamp(carrier.Size.Z * .71, 11, 24)
    local brightness = amount(config.LavaBrightness, .96, 0, 2)
    local glow = amount(config.GlowIntensity, .78, 0, 2)
    local strength = .5 + glow * .46
    local ok = pcall(function()
        detail.Name = "Molten Detail"
        detail.Face = Enum.NormalId.Top
        detail.AutoLocalize = false
        detail.StudsPerTileU = studsU
        detail.StudsPerTileV = studsV
        detail.Transparency = .39
        detail.ColorMapContent = Content.fromObject(image)
        detail.Parent = carrier
    end)
    if not ok then
        detail:Destroy()
        release()
        unavailable = true
        return nil
    end

    local emission = false
    if whiteMask then
        emission = pcall(function()
            detail.EmissiveStrength = strength
            detail.EmissiveMaskContent = Content.fromObject(whiteMask)
        end)
    end

    local flow = if typeof(config.FlowDirection) == "Vector2" then config.FlowDirection else Vector2.new(1, .25)
    if flow.Magnitude < .0001 then
        flow = Vector2.new(1, .25)
    end
    flow = flow.Unit
    local origin = carrier.Position
    local phase = (origin.X * .63 + origin.Z * .57) % TAU

    users += 1
    return setmetatable({
        _detail = detail,
        _flow = flow,
        _speed = amount(config.LavaFlowSpeed, .72, 0, 12) * 1.38,
        _studsU = studsU,
        _studsV = studsV,
        _phase = phase,
        _transparency = math.clamp(.38 + .08 * (1 - brightness), .23, .59),
        _emission = if emission then strength else nil,
    }, MoltenTexture)
end

function MoltenTexture:Update(time, lod)
    local detail = self._detail
    if not detail then
        return
    end

    local distance = time * self._speed + self._phase
    local drift = .42 * math.sin(time * .61 + self._phase)
    -- Top-face U and V follow local X and Z respectively.
    local flow = self._flow
    detail.OffsetStudsU = (flow.X * distance - flow.Y * drift) % self._studsU
    detail.OffsetStudsV = (flow.Y * distance + flow.X * drift) % self._studsV
    local quality = math.clamp(lod or 1, 0, 1)
    local flicker = math.sin(time * 1.33 + self._phase) * .036 + math.sin(time * .53) * .028
    detail.Transparency = math.clamp(self._transparency + (1 - quality) * .22 + flicker, .22, .82)
    if self._emission then
        detail.EmissiveStrength = self._emission * (.96 + flicker * 2)
    end
end

function MoltenTexture:Destroy()
    if self._detail then
        self._detail:Destroy()
        self._detail = nil
        users -= 1
        release()
    end
end

return MoltenTexture
]] },
	{ name = "Emissions", kind = "ModuleScript", code = [[-- Local particles, molten blisters, and surface lighting for a lava Part.
local Emissions = {}
Emissions.__index = Emissions

local COLUMN_OFFSET = .18
local MOLTEN_TOP = .038
local HALO_OFFSET = .065
local SPARKS = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local COOL_SKIN = Color3.fromRGB(48, 18, 11)
local HOT_SKIN = Color3.fromRGB(146, 53, 13)
local HALO_RED = Color3.fromRGB(218, 51, 6)
local HALO_GOLD = Color3.fromRGB(255, 142, 20)
local TAU = math.pi * 2

local function setting(value, fallback, low, high)
    if typeof(value) ~= "number" or value ~= value then
        return fallback
    end
    return math.clamp(value, low, high)
end

local function part(name, parent, shape, material)
    local result = Instance.new("Part")
    result.Name = name
    result.Shape = shape
    result.Material = material
    result.Transparency = 1
    result.Anchored = true
    result.CanCollide = false
    result.CanTouch = false
    result.CanQuery = false
    result.CastShadow = false
    result.Parent = parent
    return result
end

local function attach(name, parent)
    local attachment = Instance.new("Attachment")
    attachment.Name = name
    attachment.Parent = parent
    return attachment
end

local function values(points)
    local keys = {}
    for index, point in ipairs(points) do
        keys[index] = NumberSequenceKeypoint.new(point[1], point[2], point[3] or 0)
    end
    return NumberSequence.new(keys)
end

local function colors(points)
    local keys = {}
    for index, point in ipairs(points) do
        keys[index] = ColorSequenceKeypoint.new(point[1], Color3.fromRGB(point[2], point[3], point[4]))
    end
    return ColorSequence.new(keys)
end

local function emitter(parent, name, texture, spec)
    local object = Instance.new("ParticleEmitter")
    object.Name = name
    object.Texture = texture
    object.EmissionDirection = Enum.NormalId.Top
    object.Enabled = false
    object.Rate = 0
    object.Lifetime = NumberRange.new(spec.life[1], spec.life[2])
    object.Speed = NumberRange.new(spec.speed[1], spec.speed[2])
    object.SpreadAngle = Vector2.new(spec.spread, spec.spread)
    object.Drag = spec.drag
    object.Acceleration = spec.acceleration
    object.LightEmission = spec.emission
    object.LightInfluence = spec.influence
    object.Rotation = NumberRange.new(-180, 180)
    object.RotSpeed = NumberRange.new(-spec.spin, spec.spin)
    object.LockedToPart = false
    object.Size = values(spec.size)
    object.Transparency = values(spec.transparency)
    object.Color = colors(spec.color)
    object.Parent = parent
    return object
end

local function cinderSpec(burst)
    return {
        life = burst and {.48, 1.05} or {.65, 1.45},
        speed = burst and {4.8, 9.2} or {1.8, 4.5},
        spread = burst and 43 or 21,
        drag = burst and .72 or .44,
        acceleration = Vector3.new(0, burst and -9 or -3.4, 0),
        emission = .98,
        influence = .02,
        spin = 27,
        size = {{0, .103, .035}, {.26, .087, .025}, {1, .024}},
        transparency = {{0, .12}, {.35, .14}, {.78, .58}, {1, 1}},
        color = {{0, 255, 226, 121}, {.32, 255, 136, 39}, {1, 195, 28, 8}},
    }
end

local function smokeSpec()
    return {
        life = {1.45, 2.85}, speed = {.92, 2.2}, spread = 22, drag = .57,
        acceleration = Vector3.new(.24, .80, -.15), emission = 0, influence = .85, spin = 17,
        size = {{0, .28, .10}, {.52, 1.05, .34}, {1, 1.60, .38}},
        transparency = {{0, .97}, {.25, .79}, {.63, .86}, {1, 1}},
        color = {{0, 67, 46, 36}, {.5, 54, 46, 43}, {1, 44, 40, 41}},
    }
end

local function schedule(random, time, rate)
    return if rate > .001 then time + random:NextNumber(.58, 1.54) / rate else math.huge
end

local function rate(emitterObject, value)
    emitterObject.Enabled = value > .01
    emitterObject.Rate = value
end

local function lightMount(parent)
    local mount = attach("Heat light position", parent)
    local light = Instance.new("PointLight")
    light.Name = "Soft lava bounce"
    light.Color = Color3.fromRGB(255, 106, 35)
    light.Brightness = 0
    light.Enabled = false
    light.Shadows = false
    light.Parent = mount
    return {item = light, mount = mount}
end

local function blister(parent)
    local skin = part("Magma bubble", parent, Enum.PartType.Ball, Enum.Material.SmoothPlastic)
    local halo = part("Bubble disturbance", parent, Enum.PartType.Cylinder, Enum.Material.Neon)
    return {skin = skin, halo = halo, active = false}
end

function Emissions.new(source, folder, config)
    config = config or {}
    local self = setmetatable({}, Emissions)
    self._source = source
    self._quality = setting(config.AnimationQuality, .85, 0, 1)
    self._sparkRate = setting(config.SparkEmissionRate, 26, 0, 75)
    self._bubbleRate = setting(config.BubbleFrequency, .48, 0, 2.5)
    self._smoke = setting(config.SmokeDensity, .34, 0, 1)
    self._glow = setting(config.GlowIntensity, .78, 0, 2)
    self._brightness = setting(config.LavaBrightness, .96, 0, 2)
    self._flow = setting(config.LavaFlowSpeed, .72, 0, 5)
    local direction = config.FlowDirection
    self._flowDirection = if typeof(direction) == "Vector2" and direction.Magnitude > .001
        then direction.Unit else Vector2.new(.961, .276)
    self._lightGrant = true
    self._lights = {}
    self._bubbles = {}

    local container = Instance.new("Folder")
    container.Name = "LavaEmissions"
    container.Parent = folder
    self._container = container
    self._carrier = part("Surface emitter", container, Enum.PartType.Block, Enum.Material.SmoothPlastic)
    self._cinders = emitter(self._carrier, "Floating cinders", SPARKS, cinderSpec(false))
    self._cinders.Shape = Enum.ParticleEmitterShape.Box
    self._cinders.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
    self._vapor = emitter(self._carrier, "Volcanic wisps", SMOKE, smokeSpec())
    self._vapor.Shape = Enum.ParticleEmitterShape.Box
    self._vapor.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
    self._popAt = attach("Random lava pop", self._carrier)
    self._pop = emitter(self._popAt, "Molten droplets", SPARKS, cinderSpec(true))

    local size = source.Size
    local position = source.Position
    local seed = math.floor(position.X * 2971 + position.Y * 383 + position.Z * 733 + size.X * 47) % 2147483647
    self._random = Random.new(seed)
    self._phase = self._random:NextNumber(0, TAU)
    local area = size.X * size.Z
    local lightCount = if config.EnableLights ~= false and self._glow > 0 then (if area > 180 then 2 else 1) else 0
    for index = 1, lightCount do
        self._lights[index] = lightMount(self._carrier)
    end
    local capacity = if self._bubbleRate > 0 and self._quality > 0 then math.clamp(math.ceil(self._quality * 4), 1, 4) else 0
    for index = 1, capacity do
        self._bubbles[index] = blister(container)
    end
    return self
end

function Emissions:_align()
    local frame = self._source.CFrame
    local size = self._source.Size
    if self._frame == frame and self._size == size then
        return
    end
    self._frame, self._size = frame, size
    self._surface = frame * CFrame.new(0, size.Y * .5, 0)
    self._carrier.CFrame = self._surface * CFrame.new(0, COLUMN_OFFSET, 0)
    self._carrier.Size = Vector3.new(size.X * .91, .028, size.Z * .91)
    local range = math.clamp(math.sqrt(size.X * size.Z) * .88, 7, 19)
    for index, record in ipairs(self._lights) do
        local sign = if #self._lights == 1 then 0 elseif index == 1 then -1 else 1
        record.mount.Position = Vector3.new(sign * size.X * .23, .09, sign * -size.Z * .14)
        record.item.Range = range
    end
end

function Emissions:SetLightsEnabled(enabled)
    if not self._container then
        return
    end
    self._lightGrant = enabled
    if not enabled then
        for _, record in ipairs(self._lights) do
            record.item.Enabled = false
        end
    end
end

function Emissions:_spot(margin)
    local random = self._random
    local x = math.max(0, self._size.X * .5 - margin)
    local z = math.max(0, self._size.Z * .5 - margin)
    return random:NextNumber(-x, x), random:NextNumber(-z, z)
end

function Emissions:_burst(x, z, strength, density)
    if self._sparkRate <= 0 or density < .12 then
        return
    end
    self._popAt.Position = Vector3.new(x, 0, z)
    local count = math.clamp(math.floor(self._random:NextNumber(4, 8) * strength * density + .5), 1, 9)
    self._pop:Emit(count)
end

function Emissions:_formBubble(time)
    local random = self._random
    for _, bubble in ipairs(self._bubbles) do
        if not bubble.active then
            local limit = math.min(self._size.X, self._size.Z) * .13
            local radius = math.min(limit, random:NextNumber(.27, .71))
            if radius < .055 then
                return
            end
            bubble.x, bubble.z = self:_spot(radius * 1.6)
            bubble.radius = radius
            bubble.angle = random:NextNumber(0, TAU)
            bubble.start = time
            bubble.growth = random:NextNumber(.74, 1.86)
            bubble.popped = false
            bubble.active = true
            return
        end
    end
end

function Emissions:_animateBubble(bubble, time, density)
    local age = time - bubble.start
    local fade = (age - bubble.growth) / .27
    if fade >= 1 or density <= .01 then
        bubble.skin.Transparency = 1
        bubble.halo.Transparency = 1
        bubble.active = false
        return
    end
    local border = bubble.radius * 1.6
    local limitX = math.max(0, self._size.X * .5 - border)
    local limitZ = math.max(0, self._size.Z * .5 - border)
    local drift = self._flow * age * .035
    local x = math.clamp(bubble.x + drift * self._flowDirection.X, -limitX, limitX)
    local z = math.clamp(bubble.z + drift * self._flowDirection.Y, -limitZ, limitZ)
    if fade >= 0 and not bubble.popped then
        self:_burst(x, z, 1, density)
        bubble.popped = true
    end
    local progress = math.clamp(age / bubble.growth, 0, 1)
    local growth = progress * progress * (3 - 2 * progress)
    local collapse = 1 - math.max(0, fade)
    local radius = bubble.radius * (.17 + .83 * growth) * (.34 + .66 * collapse)
    local rise = MOLTEN_TOP - radius * (.91 - .39 * growth)
    bubble.skin.Size = Vector3.new(radius * 2, radius * 2, radius * 2)
    bubble.skin.CFrame = self._surface * CFrame.new(x, rise, z)
    bubble.skin.Color = COOL_SKIN:Lerp(HOT_SKIN, growth ^ 1.4)
    bubble.skin.Transparency = 1 - (.77 + .18 * growth) * collapse * density

    -- A slight orange puddle spreads from the pop under the crust.
    local spread = bubble.radius * (.54 + .92 * growth + math.max(0, fade) * .49)
    bubble.halo.Size = Vector3.new(.014, spread * 1.9, spread * 1.56)
    local patch = self._surface * CFrame.new(x, HALO_OFFSET, z)
    bubble.halo.CFrame = patch * CFrame.Angles(0, bubble.angle, math.pi * .5)
    bubble.halo.Color = HALO_RED:Lerp(HALO_GOLD, growth * .58)
    local heat = math.min(1, self._glow * self._brightness * .92)
    bubble.halo.Transparency = 1 - (.09 + .34 * growth) * collapse * density * heat
end

function Emissions:Update(time, dt, lod)
    if not self._container then
        return
    end
    if not self._source.Parent then
        self:Destroy()
        return
    end
    self:_align()

    local target = setting(lod, 1, 0, 1) * self._quality
    local alpha = 1 - math.exp(-setting(dt, 1 / 30, 0, .25) * 8)
    local density = if target <= .01 then 0 else (self._density or target)
    density += (target - density) * alpha
    self._density = density
    rate(self._cinders, self._sparkRate * density)
    rate(self._vapor, self._smoke * 7 * density * density)
    for index, record in ipairs(self._lights) do
        local enabled = self._lightGrant and target > .48
        record.item.Enabled = enabled
        if enabled then
            local wave = time * 2.3 + self._phase + index * 1.9
            local flicker = .86 + .10 * math.sin(wave) + .04 * math.sin(wave * 2.9)
            record.item.Brightness = self._glow * self._brightness * 1.12 * flicker * density
        end
    end

    local bubbleRate = self._bubbleRate * density ^ 1.4
    local popRate = self._sparkRate / 26 * .24 * density ^ 1.6
    if bubbleRate <= .001 or not self._nextBubble or self._nextBubble == math.huge then
        self._nextBubble = schedule(self._random, time, bubbleRate)
    elseif time >= self._nextBubble then
        self:_formBubble(time)
        self._nextBubble = schedule(self._random, time, bubbleRate)
    end
    if popRate <= .001 or not self._nextPop or self._nextPop == math.huge then
        self._nextPop = schedule(self._random, time, popRate)
    elseif time >= self._nextPop then
        local x, z = self:_spot(.16)
        self:_burst(x, z, .85, density)
        self._nextPop = schedule(self._random, time, popRate)
    end
    for _, bubble in ipairs(self._bubbles) do
        if bubble.active then
            self:_animateBubble(bubble, time, density)
        end
    end
end

function Emissions:Destroy()
    if self._container then
        self._container:Destroy()
        self._container = nil
    end
end

return Emissions
]] },
	{ name = "VolcanicLavaClient", kind = "LocalScript", code = [[local CollectionService = game:GetService("CollectionService")
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
]] },
}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayerScripts = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")
local owned = "VolcanicLavaPackage"
local folder = ReplicatedStorage:FindFirstChild("VolcanicLava")
if folder then
	assert(folder:IsA("Folder") and folder:GetAttribute(owned), "ReplicatedStorage.VolcanicLava already belongs to another installation.")
end
for _, entry in entries do
	local parent = if entry.kind == "ModuleScript" then folder else StarterPlayerScripts
	local existing = parent and parent:FindFirstChild(entry.name)
	if existing then
		assert(existing.ClassName == entry.kind and existing:GetAttribute(owned),
			"Cannot overwrite existing " .. existing:GetFullName())
	end
end
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "VolcanicLava"
	folder:SetAttribute(owned, true)
	folder.Parent = ReplicatedStorage
end
for _, entry in entries do
	local parent = if entry.kind == "ModuleScript" then folder else StarterPlayerScripts
	local existing = parent:FindFirstChild(entry.name)
	local object = existing or Instance.new(entry.kind)
	object.Name = entry.name
	-- Keep local defaults edited in Studio when tagging another pool.
	if not existing or entry.name ~= "Config" then
		object.Source = entry.code
	end
	object:SetAttribute(owned, true)
	if entry.kind == "LocalScript" then
		object.Enabled = true
	end
	object.Parent = parent
end

local selected = 0
for _, instance in game:GetService("Selection"):Get() do
	if instance:IsA("BasePart") and instance:IsDescendantOf(Workspace) then
		CollectionService:AddTag(instance, "VolcanicLava")
		selected += 1
	end
end
print(("Volcanic Lava installed. Selected pools tagged: %d. Press Play to see the effect."):format(selected))
if selected == 0 then
	print("To add a pool, select its Part and add the VolcanicLava tag in Properties, or select it and rerun this installer.")
end
