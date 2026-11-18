-- Optional detail pass. The same editable image is shared by every local pool.
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
