-- Local particles, molten blisters, and surface lighting for a lava Part.
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
