local function signal()
	local callbacks = {}
	return {
		Connect = function(_, callback)
			callbacks[callback] = true
			return {Disconnect = function() callbacks[callback] = nil end}
		end,
		Fire = function(_, ...)
			for callback in pairs(callbacks) do
				callback(...)
			end
		end,
	}
end

local Vector2 = {new = function(x, y) return {X = x, Y = y} end}
local vectorMeta = {__mul = function(a, b) return {X = a.X * b, Y = a.Y * b, Z = a.Z * b} end}
local parts = {}
local Workspace = {CurrentCamera = {CFrame = {Position = {X = 0, Y = 20, Z = 0}}}}
local added, removed, frames = signal(), signal(), signal()
local CollectionService = {
	GetInstanceAddedSignal = function() return added end,
	GetInstanceRemovedSignal = function() return removed end,
	GetTagged = function() return parts end,
}

local function makePart(index, x)
	local part = {
		Name = "Pool" .. index, attributes = {}, present = true,
		AttributeChanged = signal(), resized = signal(),
		Size = setmetatable({X = 24, Y = 2, Z = 18}, vectorMeta),
		CFrame = {PointToObjectSpace = function(_, world)
			return {X = world.X - x, Y = world.Y, Z = world.Z}
		end},
		IsA = function(_, class) return class == "BasePart" end,
		IsDescendantOf = function(self, world) return self.present and world == Workspace end,
		GetAttribute = function(self, field) return self.attributes[field] end,
		GetPropertyChangedSignal = function(self) return self.resized end,
	}
	table.insert(parts, part)
	return part
end

for i = 1, 8 do
	makePart(i, (i - 1) * 22)
end
local isolated = makePart(9, 802)
local Instance = {new = function(class)
	assert(class == "Folder")
	return {Destroy = function(self) self.destroyed = true end}
end}

local function loadConfig()
-- MODULE_CONFIG
end
local Config = loadConfig()
local mounted = {Surface = {}, Emissions = {}, MoltenTexture = {}}
local function visual(kind)
	return {
		new = function(part, _, settings)
			assert(not mounted[kind][part])
			local lastTime = 0
			local obj = {
				settings = settings,
				Update = function(self, time, first, lod)
					assert(time > lastTime)
					assert((lod or first) >= 0 and (lod or first) <= 1)
					lastTime = time
					self.updates = (self.updates or 0) + 1
				end,
				Destroy = function() mounted[kind][part] = nil end,
			}
			mounted[kind][part] = obj
			return obj
		end,
	}
end
local modules = {
	Config = Config, Surface = visual("Surface"),
	MoltenTexture = visual("MoltenTexture"), Emissions = visual("Emissions"),
}
local services = {
	CollectionService = CollectionService, Workspace = Workspace,
	ReplicatedStorage = {WaitForChild = function() return modules end},
	RunService = {Heartbeat = frames},
	UserInputService = {TouchEnabled = false, KeyboardEnabled = true},
}
local game = {GetService = function(_, name) return services[name] end}
local script = {Destroying = signal()}
local require = function(module) return module end

local function runClient()
-- MODULE_CLIENT
end
local function advance(seconds)
	for _ = 1, math.ceil(60 * seconds) do
		frames:Fire(1 / 60)
	end
end
local function count(records)
	local result = 0
	for _ in pairs(records) do
		result += 1
	end
	return result
end

parts[1].attributes.FlowAngle = 90
parts[1].attributes.LavaFlowSpeed = 80
parts[1].attributes.UseEditableTexture = false
local settings = Config.forPart(parts[1], false)
assert(math.abs(settings.FlowDirection.X) < .001 and settings.FlowDirection.Y == 1)
assert(settings.LavaFlowSpeed == 4 and settings.UseEditableTexture == false)
assert(Config.forPart(parts[1], true).AnimationQuality == .7)

runClient()
advance(2)
assert(count(mounted.Surface) == 6 and count(mounted.Emissions) == 3)
assert(count(mounted.MoltenTexture) == 5 and not mounted.MoltenTexture[parts[1]])
assert(mounted.Surface[parts[1]].updates > 30)
assert(not mounted.Surface[isolated])

parts[1].attributes.LavaBrightness = 1.4
parts[1].AttributeChanged:Fire("LavaBrightness")
advance(.3)
assert(mounted.Surface[parts[1]].settings.LavaBrightness == 1.4)
parts[1].present = false
removed:Fire(parts[1])
assert(not mounted.Surface[parts[1]] and not mounted.Emissions[parts[1]])

Workspace.CurrentCamera.CFrame.Position.X = 802
advance(2)
assert(count(mounted.Surface) == 1 and mounted.Surface[isolated])
assert(count(mounted.Emissions) == 1)
script.Destroying:Fire()
assert(count(mounted.Surface) == 0 and count(mounted.Emissions) == 0 and count(mounted.MoltenTexture) == 0)
print("PASS lava tag lifecycle, multiple pools, time-based updates, LOD limits, attributes, and cleanup")
