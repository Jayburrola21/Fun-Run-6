-- The caller supplies the locally animated mouth and nostril poses. These effects are visual only.
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local FireEffects = {}
FireEffects.__index = FireEffects

local FLAME = "rbxasset://textures/particles/fire_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local UP = Vector3.yAxis
local TAU = math.pi * 2
local FADE_STEPS = 16
local SCORCH_POOL_SIZE = 12
local VISUAL_SCALE = 2

local function color(r, g, b)
    return Color3.fromRGB(r, g, b)
end

local function numberSequence(pairs, scale)
    local keys = {}
    scale = scale or 1
    for _, pair in ipairs(pairs) do
        table.insert(keys, NumberSequenceKeypoint.new(pair[1], pair[2] * scale))
    end
    return NumberSequence.new(keys)
end

local function colorSequence(pairs)
    local keys = {}
    for _, pair in ipairs(pairs) do
        table.insert(keys, ColorSequenceKeypoint.new(pair[1], pair[2]))
    end
    return ColorSequence.new(keys)
end

local function containerPart(name, parent)
    local part = Instance.new("Part")
    part.Name = name
    part.Size = Vector3.new(.15, .15, .15)
    part.Anchored = true
    part.CanCollide = false
    part.CanTouch = false
    part.CanQuery = false
    part.CastShadow = false
    part.Transparency = 1
    part.Parent = parent
    return part
end

local function attachment(name, parent)
    local result = Instance.new("Attachment")
    result.Name = name
    result.Parent = parent
    return result
end

local function beam(parent, source, endpoint, spec)
    local ribbon = Instance.new("Beam")
    ribbon.Name = spec.name
    ribbon.Attachment0 = source
    ribbon.Attachment1 = endpoint
    ribbon.Enabled = false
    ribbon.FaceCamera = true
    ribbon.Segments = 16
    ribbon.Texture = FLAME
    ribbon.TextureMode = Enum.TextureMode.Wrap
    ribbon.TextureLength = spec.textureLength
    ribbon.TextureSpeed = spec.scroll
    ribbon.Color = colorSequence(spec.color)
    ribbon.LightEmission = 1
    ribbon.LightInfluence = 0
    ribbon.Brightness = spec.brightness
    ribbon.ZOffset = spec.offset
    ribbon.Parent = parent

    local fades = {}
    for bin = 0, FADE_STEPS do
        local points = {}
        for _, pair in ipairs(spec.transparency) do
            table.insert(points, {pair[1], 1 - (1 - pair[2]) * bin / FADE_STEPS})
        end
        fades[bin] = numberSequence(points)
    end
    return {item = ribbon, fades = fades, width0 = spec.width0, width1 = spec.width1, phase = spec.phase}
end

local function emitter(parent, spec)
    local particle = Instance.new("ParticleEmitter")
    particle.Name = spec.name
    particle.Texture = spec.texture
    particle.Rate = 0
    particle.Enabled = false
    particle.EmissionDirection = spec.direction
    particle.LightEmission = spec.emission
    particle.LightInfluence = spec.influence or 0
    particle.Lifetime = NumberRange.new(spec.life[1], spec.life[2])
    particle.Speed = NumberRange.new(spec.speed[1], spec.speed[2])
    particle.SpreadAngle = Vector2.new(spec.spread, spec.spread)
    particle.Acceleration = spec.acceleration or Vector3.zero
    particle.Drag = spec.drag or 0
    particle.Rotation = NumberRange.new(-180, 180)
    particle.RotSpeed = NumberRange.new(-spec.spin, spec.spin)
    particle.Size = numberSequence(spec.size, VISUAL_SCALE)
    particle.Transparency = numberSequence(spec.transparency)
    particle.Color = colorSequence(spec.color)
    particle.Parent = parent
    return {item = particle, rate = spec.rate, speedScale = spec.speedScale}
end

local function pointLight(name, parent, lightColor, range)
    local light = Instance.new("PointLight")
    light.Name = name
    light.Color = lightColor
    light.Range = range
    light.Brightness = 0
    light.Enabled = false
    light.Shadows = false
    light.Parent = parent
    return light
end

local function configure(value, default, minimum, maximum)
    if typeof(value) ~= "number" or value ~= value then
        return default
    end
    return math.clamp(value, minimum, maximum)
end

local function stableForward(forward, normal)
    local tangent = forward - normal * forward:Dot(normal)
    if tangent.Magnitude < .01 then
        local seed = math.abs(normal.X) < .8 and Vector3.xAxis or Vector3.zAxis
        tangent = seed - normal * seed:Dot(normal)
    end
    return tangent.Unit
end

local function pose(point, direction)
    local up = math.abs(direction:Dot(UP)) > .98 and Vector3.zAxis or UP
    return CFrame.lookAt(point, point + direction, up)
end

local function flameBands(parent, source, endpoint)
    return {
        beam(parent, source, endpoint, {
            name = "Crimson fringe", textureLength = 5.8, scroll = 12, brightness = 1.5,
            width0 = 1.48, width1 = 8.6, phase = 0, offset = -.05,
            color = {{0, color(255, 72, 18)}, {.38, color(234, 49, 5)}, {1, color(144, 12, 1)}},
            transparency = {{0, .73}, {.13, .48}, {.67, .54}, {1, .86}},
        }),
        beam(parent, source, endpoint, {
            name = "Orange flame body", textureLength = 6.2, scroll = 15, brightness = 2.1,
            width0 = 1.06, width1 = 5.65, phase = 2.2, offset = 0,
            color = {{0, color(255, 184, 70)}, {.50, color(255, 113, 18)}, {1, color(242, 52, 2)}},
            transparency = {{0, .48}, {.16, .24}, {.62, .35}, {1, .76}},
        }),
        beam(parent, source, endpoint, {
            name = "White-hot core", textureLength = 5.8, scroll = 17, brightness = 3,
            width0 = .62, width1 = 2.55, phase = 4.6, offset = .06,
            color = {{0, color(255, 250, 209)}, {.24, color(255, 212, 108)}, {1, color(255, 109, 14)}},
            transparency = {{0, .08}, {.22, .16}, {.70, .45}, {1, 1}},
        }),
    }
end

local function streamEmitters(mouth, wake)
    local front = Enum.NormalId.Front
    return {
        emitter(mouth, {
            name = "Nozzle flare", texture = FLAME, direction = front, emission = 1,
            rate = 84, life = {.12, .22}, speed = {12, 25}, speedScale = {2.5, 3.7}, spread = 3, spin = 90,
            size = {{0, .78}, {.35, 1.34}, {1, .82}},
            transparency = {{0, .05}, {.42, .14}, {1, 1}},
            color = {{0, color(255, 251, 216)}, {.35, color(255, 221, 110)}, {1, color(255, 112, 23)}},
        }),
        emitter(mouth, {
            name = "Forward flame tongues", texture = FLAME, direction = front, emission = .94,
            rate = 72, life = {.22, .31}, speed = {10, 21}, speedScale = {1.9, 2.8}, spread = 3, spin = 160,
            size = {{0, .93}, {.42, 2.7}, {1, 1.5}},
            transparency = {{0, .23}, {.6, .5}, {1, 1}},
            color = {{0, color(255, 194, 63)}, {.35, color(255, 109, 13)}, {1, color(219, 34, 2)}},
        }),
        emitter(wake, {
            name = "Turbulent flame edges", texture = FLAME, direction = front, emission = .89,
            rate = 42, life = {.18, .28}, speed = {7, 19}, speedScale = {1.15, 1.6}, spread = 5, spin = 180,
            size = {{0, 1.6}, {.5, 3.75}, {1, 2.75}},
            transparency = {{0, .39}, {.48, .58}, {1, 1}},
            color = {{0, color(246, 79, 6)}, {.67, color(197, 30, 2)}, {1, color(74, 10, 4)}},
        }),
        emitter(wake, {
            name = "Dark exhaust wisps", texture = SMOKE, direction = front, emission = 0, influence = .85,
            rate = 10, life = {.38, .72}, speed = {4, 8}, speedScale = {.21, .34}, spread = 13, spin = 28,
            acceleration = Vector3.new(0, 5, 0), drag = 1.5,
            size = {{0, 1.05}, {.48, 1.6}, {1, 2.1}},
            transparency = {{0, .95}, {.27, .78}, {1, 1}},
            color = {{0, color(55, 39, 37)}, {1, color(32, 27, 28)}},
        }),
    }
end

local function impactEmitters(ground)
    local top = Enum.NormalId.Top
    return {
        emitter(ground, {
            name = "Track strike", texture = FLAME, direction = top, emission = 1,
            rate = 74, life = {.32, .64}, speed = {6, 15}, spread = 39, spin = 175,
            size = {{0, 1.35}, {.38, 3.85}, {1, 2.15}},
            transparency = {{0, .1}, {.60, .40}, {1, 1}},
            color = {{0, color(255, 232, 125)}, {.46, color(255, 110, 15)}, {1, color(191, 24, 3)}},
        }),
        emitter(ground, {
            name = "Hot scatter", texture = SPARK, direction = top, emission = 1,
            rate = 38, life = {.36, .78}, speed = {5, 13}, spread = 66, spin = 42,
            acceleration = Vector3.new(0, -12, 0), drag = 1.2,
            size = {{0, .24}, {.35, .18}, {1, .02}},
            transparency = {{0, 0}, {.75, .25}, {1, 1}},
            color = {{0, color(255, 214, 97)}, {.45, color(255, 110, 10)}, {1, color(219, 35, 5)}},
        }),
        emitter(ground, {
            name = "Rising strike smoke", texture = SMOKE, direction = top, emission = .03, influence = .88,
            rate = 14, life = {.64, 1.32}, speed = {1.9, 4.1}, spread = 30, spin = 34,
            acceleration = Vector3.new(0, 3.1, 0), drag = 1.4,
            size = {{0, 1.42}, {.43, 2.5}, {1, 3.4}},
            transparency = {{0, .96}, {.26, .68}, {.63, .82}, {1, 1}},
            color = {{0, color(56, 42, 40)}, {1, color(30, 27, 29)}},
        }),
    }
end

local function recoveryEmitters(group)
    local left = containerPart("Left nostril recovery", group)
    local right = containerPart("Right nostril recovery", group)
    local mouth = containerPart("Mouth recovery", group)
    local smokeColor = {{0, color(117, 109, 102)}, {1, color(78, 75, 74)}}
    local smokeFade = {{0, .82}, {.18, .41}, {.55, .67}, {1, 1}}
    local nostrilSpec = {
        name = "Nostril smoke", texture = SMOKE, direction = Enum.NormalId.Front, emission = .04, influence = .73,
        rate = 17, life = {.52, .94}, speed = {1.35, 2.35}, spread = 11, spin = 29,
        acceleration = Vector3.new(0, 4.4, 0), drag = 1.7,
        size = {{0, .085}, {.36, .42}, {1, .66}},
        transparency = smokeFade, color = smokeColor,
    }
    local mouthSpec = {
        name = "Mouth wisp", texture = SMOKE, direction = Enum.NormalId.Front, emission = .04, influence = .73,
        rate = 7, life = {.43, .76}, speed = {.75, 1.35}, spread = 16, spin = 34,
        acceleration = Vector3.new(0, 3.8, 0), drag = 1.5,
        size = {{0, .09}, {.36, .36}, {1, .58}},
        transparency = {{0, .87}, {.19, .52}, {.55, .76}, {1, 1}}, color = smokeColor,
    }
    return {left, right, mouth}, {
        emitter(attachment("Smoke source", left), nostrilSpec),
        emitter(attachment("Smoke source", right), nostrilSpec),
        emitter(attachment("Smoke source", mouth), mouthSpec),
    }
end

local function scorchPool(parent)
    local pool = {}
    for index = 1, SCORCH_POOL_SIZE do
        local rim = containerPart("Molten scorch outline", parent)
        rim.Shape = Enum.PartType.Cylinder
        rim.Material = Enum.Material.Neon
        rim.Color = color(157, 22, 3)
        local center = containerPart("Molten scorch center", parent)
        center.Shape = Enum.PartType.Cylinder
        center.Material = Enum.Material.Neon
        center.Color = color(244, 81, 4)
        pool[index] = {rim = rim, center = center}
    end
    return pool
end

local function tweenFade(part, lifetime)
    local tween = TweenService:Create(part, TweenInfo.new(lifetime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Transparency = 1,
    })
    tween:Play()
    return tween
end

local function setEmitters(emitters, level, distance)
    for _, spec in ipairs(emitters) do
        local item = spec.item
        item.Enabled = level > .004
        item.Rate = spec.rate * level
        if item.Enabled and spec.speedScale then
            item.Speed = NumberRange.new(distance * spec.speedScale[1], distance * spec.speedScale[2])
        end
    end
end

function FireEffects.new(dragonModel, config, rigScale)
    config = config or {}
    local options = config.Effects or {}
    local self = setmetatable({}, FireEffects)

    local group = Instance.new("Folder")
    group.Name = "VolcanicDragonFireEffects"
    group.Parent = Workspace
    self._group = group
    self._source = containerPart("Breath origin", group)
    self._wake = containerPart("Breath wake", group)
    self._endpoint = containerPart("Breath end", group)
    self._ground = containerPart("Track contact", group)

    local source = attachment("Beam start", self._source)
    local endpoint = attachment("Beam end", self._endpoint)
    local axisForward = CFrame.fromMatrix(Vector3.zero, -Vector3.zAxis, UP)
    source.CFrame = axisForward
    endpoint.CFrame = axisForward
    local mouth = attachment("Mouth flames", self._source)
    local wake = attachment("Wake flames", self._wake)
    local ground = attachment("Ground effects", self._ground)

    self._bands = flameBands(group, source, endpoint)
    self._stream = streamEmitters(mouth, wake)
    self._impact = impactEmitters(ground)
    self._recoverySources, self._recoverySmoke = recoveryEmitters(group)
    self._mouthLight = pointLight("Mouth bounce", mouth, color(255, 142, 52), 19)
    self._impactLight = pointLight("Track bounce", ground, color(255, 88, 14), 24)
    self._leftEye = containerPart("Left eye light origin", group)
    self._rightEye = containerPart("Right eye light origin", group)
    local eyeRange = configure(rigScale, 1, .2, 8) * .96
    local eyeColor = color(255, 131, 41)
    self._leftEyeLight = pointLight("Left iris glow", self._leftEye, eyeColor, eyeRange)
    self._rightEyeLight = pointLight("Right iris glow", self._rightEye, eyeColor, eyeRange)
    self._scorch = scorchPool(group)
    self._scorchIndex = 0
    self._scorchWait = 0
    self._time = 0
    self._fadeBin = -1
    self._range = configure(config.FireRange, 65, 3, 200)
    self._quality = configure(options.Quality, 1, .15, 1)
    self._size = configure(options.WidthScale, 1, .25, 3)
    self._minAngle = math.rad(configure(options.MinDownwardAngle, 5, 0, 80))
    self._scorchLifetime = configure(options.ScorchLifetime, 1.25, .2, 3)

    local raycast = RaycastParams.new()
    raycast.IgnoreWater = true
    raycast.ExcludeInstances = {dragonModel, group}
    if typeof(options.Track) == "Instance" then
        raycast.IncludeInstances = {options.Track}
    elseif type(config.TrackName) == "string" and config.TrackName ~= "" then
        self._trackName = config.TrackName
        raycast.IncludeInstances = {}
    end
    self._raycast = raycast
    return self
end

function FireEffects:_setScorch(position, normal, forward, intensity)
    self._scorchIndex = self._scorchIndex % #self._scorch + 1
    local spot = self._scorch[self._scorchIndex]
    if spot.rimTween then
        spot.rimTween:Cancel()
        spot.centerTween:Cancel()
    end

    local angle = (self._scorchIndex * 1.27 + self._time * .7) % TAU
    local across = normal:Cross(forward).Unit
    local long = forward * math.cos(angle) + across * math.sin(angle)
    local size = VISUAL_SCALE * self._size * (.65 + .37 * intensity)
    local hotSize = size * (.45 + .09 * math.sin(self._scorchIndex * 2))
    spot.rim.Size = Vector3.new(.022, size * 1.68, size * .87)
    spot.rim.CFrame = CFrame.fromMatrix(position + normal * .030, normal, long)
    spot.rim.Transparency = .49
    spot.center.Size = Vector3.new(.018, hotSize * 1.5, hotSize * .95)
    spot.center.CFrame = CFrame.fromMatrix(position + normal * .047 + across * size * .19, normal, long)
    spot.center.Transparency = .21
    spot.rimTween = tweenFade(spot.rim, self._scorchLifetime)
    spot.centerTween = tweenFade(spot.center, self._scorchLifetime * .71)
end

function FireEffects:Stop()
    if not self._group then
        return
    end
    for _, layer in ipairs(self._bands) do
        layer.item.Enabled = false
    end
    setEmitters(self._stream, 0, 0)
    setEmitters(self._impact, 0, 0)
    self._mouthLight.Enabled = false
    self._impactLight.Enabled = false
    self._lastScorch = nil
    self._scorchWait = 0
end

-- Update the three smoke origins independently of the main flame. Frames may
-- be omitted when the level is zero so already emitted wisps can fade out.
function FireEffects:UpdateRecoverySmoke(leftNostrilFrame, rightNostrilFrame, mouthFrame, level)
    if not self._group then
        return
    end
    level = configure(level, 0, 0, 1) * self._quality
    if level > .004 then
        local sources = self._recoverySources
        sources[1].CFrame = leftNostrilFrame
        sources[2].CFrame = rightNostrilFrame
        sources[3].CFrame = mouthFrame
    end
    setEmitters(self._recoverySmoke, level, 0)
end

function FireEffects:UpdateEyeGlow(leftEye, rightEye, level)
    if not self._group then
        return
    end
    level = configure(level, 0, 0, 1)
    local enabled = level > .004
    if enabled then
        self._leftEye.Position = leftEye
        self._rightEye.Position = rightEye
    end
    self._leftEyeLight.Enabled = enabled
    self._rightEyeLight.Enabled = enabled
    self._leftEyeLight.Brightness = level * 2.7
    self._rightEyeLight.Brightness = level * 2.7
end

function FireEffects:Update(origin, direction, intensity, dt)
    if not self._group then
        return nil
    end
    intensity = configure(intensity, 0, 0, 1)
    if intensity <= .004 or direction.Magnitude <= .001 then
        self:Stop()
        return nil
    end
    dt = configure(dt, 1 / 60, 0, .12)
    self._time += dt
    self._scorchWait = math.max(0, self._scorchWait - dt)
    direction = direction.Unit
    if direction.Y > -math.sin(self._minAngle) then
        local flat = Vector3.new(direction.X, 0, direction.Z)
        direction = if flat.Magnitude > .001
            then flat.Unit * math.cos(self._minAngle) - UP * math.sin(self._minAngle)
            else -UP
    end

    if self._trackName and (not self._track or self._track.Parent ~= Workspace) then
        local track = Workspace:FindFirstChild(self._trackName)
        self._track = track
        self._raycast.IncludeInstances = track and {track} or {}
    end

    local shot = direction * self._range
    local hit = Workspace:Raycast(origin, shot, self._raycast)
    local tip = if hit then hit.Position else origin + shot
    local length = (tip - origin).Magnitude
    self._source.CFrame = pose(origin, direction)
    self._wake.CFrame = pose(origin + direction * (length * .51), direction)
    self._endpoint.CFrame = pose(tip, direction)

    local flicker = 1 + .065 * math.sin(self._time * 33) + .045 * math.sin(self._time * 57)
    local level = intensity * flicker
    local scale = VISUAL_SCALE * (.44 + .56 * intensity) * self._size
    -- Give longer jets room to flare without making close hits fan outward.
    local expansion = math.clamp(length / 18, .60, 1)
    local bin = math.clamp(math.floor(level * FADE_STEPS + .5), 0, FADE_STEPS)
    for _, layer in ipairs(self._bands) do
        local band = layer.item
        band.Enabled = length > .15 and bin > 0
        local pulse = 1 + .096 * math.sin(self._time * 22 + layer.phase)
        band.Width0 = layer.width0 * scale * pulse
        band.Width1 = (layer.width0 + (layer.width1 - layer.width0) * expansion) * scale * pulse
        if self._fadeBin ~= bin then
            band.Transparency = layer.fades[bin]
        end
    end
    self._fadeBin = bin
    local streamLevel = if length > .15 then level * self._quality else 0
    setEmitters(self._stream, streamLevel, length)
    self._mouthLight.Enabled = true
    self._mouthLight.Brightness = 2.65 * level

    if hit then
        local forward = stableForward(direction, hit.Normal)
        local contact = hit.Position + hit.Normal * .065
        self._ground.CFrame = CFrame.lookAt(contact, contact + forward, hit.Normal)
        setEmitters(self._impact, level * self._quality, 0)
        self._impactLight.Enabled = true
        self._impactLight.Brightness = 4.3 * level
        if intensity > .32 and self._scorchWait <= 0
            and (not self._lastScorch or (hit.Position - self._lastScorch).Magnitude > .82 * self._size) then
            self._lastScorch = hit.Position
            self._scorchWait = .12
            self:_setScorch(hit.Position, hit.Normal, forward, intensity)
        end
    else
        setEmitters(self._impact, 0, 0)
        self._impactLight.Enabled = false
        self._lastScorch = nil
    end
    return hit
end

function FireEffects:Destroy()
    if not self._group then
        return
    end
    for _, spot in ipairs(self._scorch) do
        if spot.rimTween then
            spot.rimTween:Cancel()
            spot.centerTween:Cancel()
        end
    end
    self._group:Destroy()
    self._group = nil
end

return FireEffects
