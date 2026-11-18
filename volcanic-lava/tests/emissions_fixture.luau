-- Run with check_emissions.py, which inserts the actual module below.
local nativeTypeof = typeof
local function typeof(value)
    return if type(value) == "table" and value.kind then value.kind else nativeTypeof(value)
end

local function vector(x, y, z)
    return {X = x, Y = y, Z = z}
end

local Vector3 = {new = vector}
local Vector2 = {new = function(x, y)
    return {kind = "Vector2", X = x, Y = y, Magnitude = 1, Unit = {X = x, Y = y}}
end}
local Color3 = {fromRGB = function(r, g, b)
    return {r = r, g = g, b = b, Lerp = function(self, other, fraction)
        return self.r + (other.r - self.r) * fraction
    end}
end}

local translation = {}
function translation.__mul(a, b)
    return setmetatable(vector(a.X + b.X, a.Y + b.Y, a.Z + b.Z), translation)
end

local CFrame = {
    new = function(x, y, z)
        return setmetatable(vector(x, y, z), translation)
    end,
    Angles = function()
        return setmetatable(vector(0, 0, 0), translation)
    end,
}

local function tuple(...)
    return {...}
end

local NumberSequence = {new = tuple}
local NumberSequenceKeypoint = {new = tuple}
local NumberRange = {new = tuple}
local ColorSequence = {new = tuple}
local ColorSequenceKeypoint = {new = tuple}
local Enum = {
    NormalId = {Top = 1},
    PartType = {Block = 2, Ball = 3, Cylinder = 4},
    Material = {SmoothPlastic = 5, Neon = 6},
    ParticleEmitterShape = {Box = 7},
    ParticleEmitterShapeStyle = {Volume = 8},
}

local createdCount, emittedCount = 0, 0
local Instance = {}
function Instance.new(className)
    createdCount += 1
    return {
        className = className,
        Destroy = function(self)
            self.destroyed = true
        end,
        Emit = function(_, amount)
            assert(amount >= 1 and amount <= 9, "Pop should stay within its particle budget")
            emittedCount += amount
        end,
    }
end

local Random = {}
function Random.new(seed)
    local state = seed
    return {NextNumber = function(_, low, high)
        state = (state * 48271) % 2147483647
        return low + (high - low) * state / 2147483647
    end}
end

local function loadEmissions()
-- EMISSIONS_MODULE
end

local Emissions = loadEmissions()
local source = {Parent = {}, Position = vector(3, 2, 4), CFrame = CFrame.new(3, 2, 4), Size = vector(32, 4, 18)}
local originalFrame, originalSize = source.CFrame, source.Size
local effects = Emissions.new(source, {}, {
    AnimationQuality = 1,
    BubbleFrequency = 2.1,
    SparkEmissionRate = 27,
    LavaFlowSpeed = 4,
    FlowDirection = Vector2.new(1, 0),
})
local allocationBudget = createdCount

effects:Update(0, 1 / 30, 1)
assert(math.abs(effects._carrier.CFrame.Y - 4.18) < .0001)
assert(source.CFrame == originalFrame and source.Size == originalSize)
assert(effects._cinders.Rate == 27 and effects._vapor.Rate > 0)
assert(#effects._lights == 2 and effects._lights[2].item.Enabled)
effects:SetLightsEnabled(false)
assert(not effects._lights[1].item.Enabled and not effects._lights[2].item.Enabled)
effects:SetLightsEnabled(true)

local sawBubble = false
for index = 1, 400 do
    effects:Update(index * .05, .05, 1)
    for _, bubble in ipairs(effects._bubbles) do
        if bubble.active then
            sawBubble = true
            assert(bubble.skin.Transparency >= 0 and bubble.skin.Transparency <= 1)
            assert(bubble.halo.CFrame.Y < effects._carrier.CFrame.Y)
        end
    end
end
assert(sawBubble and emittedCount > 0)
assert(createdCount == allocationBudget, "Repeated bubbling should reuse its instances")

for index = 1, 30 do
    effects:Update(20 + index * .05, .05, .4)
end
assert(effects._cinders.Rate > 10 and effects._cinders.Rate < 11)
assert(not effects._lights[1].item.Enabled)
effects:Update(23, 1 / 30, 0)
assert(effects._cinders.Rate == 0 and not effects._cinders.Enabled and effects._vapor.Rate == 0)
for _, bubble in ipairs(effects._bubbles) do
    assert(not bubble.active)
end

local container = effects._container
source.Parent = nil
effects:Update(24, .05, 1)
assert(container.destroyed and effects._container == nil)
effects:Destroy()
effects:SetLightsEnabled(false)
effects:Update(25, .05, 1)
print("PASS emissions pooling, distance reduction, light grants, and cleanup")
