-- Run with check_fire_effects.py to insert the ModuleScript into this Luau fixture.
local Vector3 = {}
local vectorMetatable = {
    __index = function(self, key)
        if key == "Magnitude" then
            return math.sqrt(self:Dot(self))
        end
        if key == "Unit" then
            return self / self.Magnitude
        end
        return Vector3[key]
    end,
    __add = function(a, b)
        return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
    end,
    __sub = function(a, b)
        return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
    end,
    __unm = function(a)
        return Vector3.new(-a.X, -a.Y, -a.Z)
    end,
    __div = function(a, b)
        return Vector3.new(a.X / b, a.Y / b, a.Z / b)
    end,
    __mul = function(a, b)
        return Vector3.new(a.X * b, a.Y * b, a.Z * b)
    end,
}

function Vector3.new(x, y, z)
    return setmetatable({X = x, Y = y, Z = z}, vectorMetatable)
end

function Vector3:Dot(other)
    return self.X * other.X + self.Y * other.Y + self.Z * other.Z
end

function Vector3:Cross(other)
    return Vector3.new(self.Y * other.Z - self.Z * other.Y,
        self.Z * other.X - self.X * other.Z, self.X * other.Y - self.Y * other.X)
end

Vector3.zero = Vector3.new(0, 0, 0)
Vector3.xAxis = Vector3.new(1, 0, 0)
Vector3.yAxis = Vector3.new(0, 1, 0)
Vector3.zAxis = Vector3.new(0, 0, 1)

local function tuple(...)
    return {...}
end

local Vector2 = {new = tuple}
local Color3 = {fromRGB = tuple}
local NumberSequence = {new = tuple}
local NumberRange = {new = tuple}
local ColorSequence = {new = tuple}
local NumberSequenceKeypoint = {new = tuple}
local ColorSequenceKeypoint = {new = tuple}
local TweenInfo = {new = tuple}
local RaycastParams = {new = function()
    return {}
end}
local CFrame = {
    fromMatrix = function(point, x, y)
        return {point = point, x = x, y = y}
    end,
    lookAt = function(point, target, up)
        return {point = point, target = target, up = up}
    end,
}
local Enum = {
    TextureMode = {Wrap = 1},
    NormalId = {Front = 1, Top = 2},
    PartType = {Cylinder = 1},
    Material = {Neon = 1},
    EasingStyle = {Quad = 1},
    EasingDirection = {Out = 1},
}

local createdCount = 0
local Instance = {}
function Instance.new(className)
    createdCount += 1
    return {
        className = className,
        Destroy = function(self)
            self.destroyed = true
        end,
    }
end

local nativeTypeof = typeof
local function typeof(object)
    if type(object) == "table" and object.className then
        return "Instance"
    end
    return nativeTypeof(object)
end

local track, lastCast
local forceMiss = false
local Workspace = {}
function Workspace:FindFirstChild(name)
    return if track and track.Name == name then track else nil
end

function Workspace:Raycast(origin, direction, filter)
    lastCast = {direction = direction, filter = filter}
    if forceMiss or (filter.IncludeInstances and #filter.IncludeInstances == 0) then
        return nil
    end
    local fractionToGround = -origin.Y / direction.Y
    if fractionToGround < 0 or fractionToGround > 1 then
        return nil
    end
    return {Position = origin + direction * fractionToGround, Normal = Vector3.yAxis}
end

local scheduledFades, canceledFades = 0, 0
local TweenService = {}
function TweenService:Create(_, info, properties)
    scheduledFades += 1
    assert(info[1] > 0 and info[1] <= 3 and properties.Transparency == 1)
    return {
        Play = function() end,
        Cancel = function()
            canceledFades += 1
        end,
    }
end

local services = {Workspace = Workspace, TweenService = TweenService}
local game = {GetService = function(_, name)
    return assert(services[name])
end}

local function loadEffects()
-- FIRE_EFFECTS_MODULE
end

local FireEffects = loadEffects()
local dragon = Instance.new("Model")
local effect = FireEffects.new(dragon, {FireRange = 90, TrackName = "Course", Effects = {
    Quality = .6,
    MinDownwardAngle = 12,
}})
local origin = Vector3.new(0, 6, 0)
local facing = Vector3.xAxis

assert(effect:Update(origin, facing, 1, 1 / 30) == nil, "Selected track is unavailable")
assert(lastCast.direction.Y < 0 and math.abs(lastCast.direction.Magnitude - 90) < .001)
assert(effect._bands[1].item.Enabled and not effect._impactLight.Enabled)
assert(effect._impact[1].item.Rate == 0)

track = Instance.new("Model")
track.Name = "Course"
track.Parent = Workspace
local hit = effect:Update(origin, facing, .9, 1 / 30)
assert(math.abs(hit.Position.Y) < .001, "Ray must touch the test floor")
assert(lastCast.filter.ExcludeInstances[1] == dragon and lastCast.filter.ExcludeInstances[2] == effect._group)
assert(lastCast.filter.IncludeInstances[1] == track, "A late track must be resolved")
assert(effect._mouthLight.Enabled and effect._impactLight.Enabled)
local strike = effect._impact[1]
assert(strike.item.Rate > 0 and strike.item.Rate < strike.rate, "Quality scales the particle rate")
assert(strike.item.Size[1][2][2] >= 3.5, "The track strike blooms into a larger plume")
assert(effect._endpoint.CFrame.point == hit.Position and effect._ground.CFrame.point.Y > 0)
assert(scheduledFades == 2)

local fringe = effect._bands[1].item
local core = effect._bands[3].item
assert(fringe.Width1 > 7 and fringe.Width0 < 1.7, "The jet grows beyond the narrow mouth")
assert(core.Width1 < fringe.Width1 / 2, "The jet retains its narrow hot core")
assert(effect._stream[3].item.SpreadAngle[1] <= 5, "Flame particles stay close to the ray")

local initialCount = createdCount
for index = 1, 30 do
    effect:Update(Vector3.new(index * 2, 6, 0), facing, .9, .12)
end
assert(createdCount == initialCount, "Sustained fire must reuse its effect instances")
assert(scheduledFades == 62 and canceledFades > 0 and effect._scorchIndex <= 12)

local closeHit = effect:Update(Vector3.new(0, 1, 0), facing, .9, 0)
assert(effect._endpoint.CFrame.point == closeHit.Position and fringe.Width1 < 6.1,
    "The beam stays focused at its actual hit point during a short strike")

forceMiss = true
effect:Update(origin, facing, .8, .03)
assert(not effect._impactLight.Enabled and effect._bands[1].item.Enabled)
effect:Update(origin, facing, 0, .03)
assert(not effect._bands[1].item.Enabled and effect._stream[1].item.Rate == 0)
assert(not effect._mouthLight.Enabled and not effect._impactLight.Enabled)

effect:Stop()
local group = effect._group
effect:Destroy()
assert(group.destroyed and effect._group == nil)
effect:Destroy()
assert(effect:Update(origin, facing, 1, 1 / 30) == nil)
print("PASS focused fire, larger strike, raycast, late track, scorch pool, stop, and destroy")
