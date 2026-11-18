-- Run the complete file in the Roblox Studio Command Bar in Edit mode.
local RunService = game:GetService("RunService")
local Selection = game:GetService("Selection")
local Workspace = game:GetService("Workspace")

assert(RunService:IsStudio() and not RunService:IsRunning(), "Run the cave installer in Studio Edit mode.")

local function findBone(model, name)
	for _, instance in model:GetDescendants() do
		if instance:IsA("Bone") and (instance.Name == name or instance.Name:match("^" .. name .. "[%._]%d+$")) then
			return instance
		end
	end
end

local function findDragon()
	for _, selected in Selection:Get() do
		if selected:IsA("Model") and findBone(selected, "Dragon_Root") then
			return selected
		end
	end
	local found
	for _, instance in Workspace:GetDescendants() do
		if instance:IsA("Model") and instance.Name == "VolcanicDragon" then
			assert(not found, "Select the dragon model you want to fit the cave around.")
			found = instance
		end
	end
	assert(found, "Select the rigged VolcanicDragon model in Workspace.")
	return found
end

local dragon = findDragon()
assert(dragon:IsDescendantOf(Workspace), "Put the dragon model in Workspace before fitting the cave.")
for _, instance in Workspace:GetChildren() do
	local fittedDragon = instance:FindFirstChild("FittedDragon")
	if fittedDragon and fittedDragon:IsA("ObjectValue") and fittedDragon.Value == dragon then
		Selection:Set({instance})
		print("Selected the cave already fitted to " .. dragon.Name .. ".")
		return
	end
end

local root = assert(findBone(dragon, "Dragon_Root"), "The dragon rig is missing the Dragon_Root bone.")
local mouth = assert(findBone(dragon, "MouthOrigin"), "The dragon rig is missing the MouthOrigin bone.")
local head = mouth.Parent
assert(head and head:IsA("Bone"), "The MouthOrigin bone must sit below the Head bone.")
local up = Vector3.yAxis
local direction = mouth.WorldPosition - head.WorldPosition
local horizontal = direction - up * direction:Dot(up)
assert(horizontal.Magnitude > 0.01, "Stand the dragon upright so the cave can face forward.")
local forward = horizontal.Unit
-- Rest rig measurements in GLB units. Put the gate behind the snout and claw tips.
local scale = horizontal.Magnitude / 2.51
local gatePosition = root.WorldPosition + (forward * 4.94 - up * .70) * scale
local entrance = CFrame.lookAt(gatePosition, gatePosition + forward, up)

local cave = Instance.new("Model")
cave.Name = "Dragon Dungeon Cave"
local fittedDragon = Instance.new("ObjectValue")
fittedDragon.Name = "FittedDragon"
fittedDragon.Value = dragon
fittedDragon.Parent = cave

local function section(name)
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = cave
	return model
end

local stone = section("Stone Shell")
local masonry = section("Arch Stones")
local gate = section("Broken Iron Gate")
local debris = section("Fallen Gate Pieces")

local function surface(material, r, g, b, solid)
	return {material = material, color = Color3.fromRGB(r, g, b), solid = solid}
end

local rock = Enum.Material.Rock
local slate = Enum.Material.Slate
local basalt = Enum.Material.Basalt
local metal = Enum.Material.Metal
local shell = surface(rock, 63, 71, 83, true)
local shellShade = surface(rock, 55, 63, 74, true)
local inside = surface(basalt, 36, 40, 49, true)
local floor = surface(slate, 51, 55, 62, true)
local darkMortar = surface(slate, 40, 45, 54, false)
local archStone = surface(slate, 84, 93, 106, false)
local altStone = surface(slate, 73, 82, 96, false)
local faceStone = surface(rock, 70, 79, 90, false)
local faceShade = surface(rock, 62, 71, 84, false)
local forgedIron = surface(metal, 54, 59, 68, false)
local darkIron = surface(metal, 42, 45, 52, false)
local exposedIron = surface(metal, 113, 116, 121, false)
local rustIron = surface(metal, 86, 66, 58, false)

local function put(parent, class, name, size, frame, finish)
	local part = Instance.new(class)
	part.Name = name
	part.Size = size * scale
	part.CFrame = entrance * (frame.Rotation + frame.Position * scale)
	part.Material = finish.material
	part.Color = finish.color
	part.Anchored = true
	part.CanCollide = finish.solid
	part.CanTouch = false
	part.CanQuery = finish.solid
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function block(parent, name, size, position, finish)
	return put(parent, "Part", name, size, CFrame.new(position), finish)
end

-- Extrude a flat triangle as two right triangular prisms. The long side
-- is the baseline, so the altitude lands between its endpoints.
local function triangle(parent, name, frame, a, b, c, depth, finish)
	if (a - c).Magnitude > (b - c).Magnitude then
		a, b = b, a
	end
	if (a - b).Magnitude > (b - c).Magnitude then
		a, c = c, a
	end
	local base = c - b
	local along = base.Unit
	local foot = b + along * (a - b):Dot(along)
	local height = (a - foot).Magnitude
	if height < .008 then
		return
	end

	local rise = (a - foot).Unit
	for _, endPoint in {b, c} do
		local run = (foot - endPoint).Magnitude
		if run >= .008 then
			local back = (foot - endPoint).Unit
			local right = rise:Cross(back)
			local center = (a + endPoint) * .5
			put(parent, "WedgePart", name, Vector3.new(depth, height, run),
				frame * CFrame.fromMatrix(center, right, rise, back), finish)
		end
	end
end

local function quad(parent, name, frame, a, b, c, d, depth, finish)
	triangle(parent, name, frame, a, b, c, depth, finish)
	triangle(parent, name, frame, a, c, d, depth, finish)
end

local function point(x, y)
	return Vector3.new(x, y, 0)
end

-- The inner edge is the clear opening. The broad exterior, layered
-- stonework, and cold slate palette take their cue from the reference wall.
local opening = {
	point(-5.60, 0), point(-5.60, 5.55), point(-5.15, 6.95),
	point(-3.38, 8.50), point(-1.56, 9.24), point(1.56, 9.24),
	point(3.38, 8.50), point(5.15, 6.95), point(5.60, 5.55), point(5.60, 0),
}
local rim = {
	point(-6.38, 0), point(-6.37, 5.68), point(-5.93, 7.42),
	point(-3.90, 9.22), point(-1.74, 10.05), point(1.78, 10.03),
	point(3.97, 9.18), point(5.91, 7.47), point(6.34, 5.68), point(6.42, 0),
}
local crest = {
	point(-10.05, 0), point(-10.27, 5.65), point(-9.39, 8.46),
	point(-6.45, 10.67), point(-2.26, 11.68), point(2.60, 11.36),
	point(6.55, 10.56), point(9.67, 8.35), point(10.37, 5.65), point(10.18, 0),
}

local facade = CFrame.new(0, 0, .26)
local frontRim = CFrame.new(0, 0, -.56)
for index = 1, #opening - 1 do
	local nextIndex = index + 1
	local finish = if index % 2 == 0 then shellShade else shell
	quad(stone, "Carved rock face", facade, opening[index], opening[nextIndex],
		crest[nextIndex], crest[index], 1.52, finish)

	quad(masonry, "Mortar recess", frontRim, opening[index], opening[nextIndex],
		rim[nextIndex], rim[index], .24, darkMortar)
	local start = opening[index]
	local stop = opening[nextIndex]
	local outerStart = rim[index]
	local outerStop = rim[nextIndex]
	local count = if index == 1 or index == #opening - 1 then 5 elseif index == 5 then 3 else 1
	for segment = 1, count do
		local length = (stop - start).Magnitude
		local inset = .038 / length
		local from = (segment - 1) / count + inset
		local to = segment / count - inset
		local surfaceDepth = if (index + segment) % 3 == 0 then -.73 else -.69
		local trim = if (index + segment) % 2 == 0 then archStone else altStone
		quad(masonry, "Slate arch block", CFrame.new(0, 0, surfaceDepth),
			start:Lerp(stop, from), start:Lerp(stop, to),
			outerStart:Lerp(outerStop, to), outerStart:Lerp(outerStop, from), .31, trim)
	end
end

-- A deep, dark recess behind the arch leaves space for the dragon's body.
block(stone, "Cave floor", Vector3.new(15.82, .43, 10.28), Vector3.new(0, -.28, 5.12), floor)
block(stone, "Rear cave wall", Vector3.new(15.82, 9.67, 1.10), Vector3.new(0, 4.55, 10.27), inside)
local roof = {
	point(-7.91, 9.58), point(-5.85, 10.33), point(-1.98, 10.69),
	point(2.40, 10.56), point(5.48, 10.22), point(7.91, 9.61),
}
for index = 1, #roof - 1 do
	local a = roof[index]
	local b = roof[index + 1]
	quad(stone, "Faceted cave roof", CFrame.new(0, 0, 5.31),
		point(a.X, 9.265), a, b, point(b.X, 9.265), 10.02, inside)
end
for _, side in {-1, 1} do
	block(stone, "Cavern side", Vector3.new(2.12, 9.51, 10.07), Vector3.new(side * 6.72, 4.625, 5.12), inside)
	for row = 1, 4 do
		local width = 2.40 + row % 3 * .35
		local x = side * (8.03 + (row % 2) * .23)
		local y = row * 1.03 - .48
		local finish = if row % 2 == 1 then faceStone else faceShade
		block(masonry, "Recessed stone course", Vector3.new(width, .91, .22), Vector3.new(x, y, -.55), finish)
	end
	block(masonry, "Stone footing", Vector3.new(3.32, .38, .86), Vector3.new(side * 8.13, .16, -.49), altStone)
end

local function ceilingAt(x)
	for index = 2, #opening - 2 do
		local a = opening[index]
		local b = opening[index + 1]
		if a.X <= x and x <= b.X then
			return a.Y + (b.Y - a.Y) * (x - a.X) / (b.X - a.X)
		end
	end
	error("Gate bar is outside the arch.")
end

local function barFrame(top, endPoint)
	local axis = (top - endPoint).Unit
	local right = axis:Cross(Vector3.zAxis).Unit
	return CFrame.fromMatrix(endPoint, right, axis, right:Cross(axis))
end

local function tornEnd(parent, frame, width, depth, length, invert)
	local endFrame = frame * CFrame.Angles(0, 0, if invert then math.pi else 0)
	local notch = point(-width * .10, 0)
	triangle(parent, "Jagged iron break", endFrame, notch, point(width * .50, 0),
		point(width * .20, -length), depth, exposedIron)
	triangle(parent, "Torn edge", endFrame, point(-width * .50, 0), notch,
		point(-width * .32, -.09), depth, forgedIron)
end

for index, bar in {
	{x = -4.79, bottom = 5.99, bend = -.25, lean = -.18},
	{x = -3.20, bottom = 6.54, bend = -.48, lean = -.24},
	{x = -1.60, bottom = 7.12, bend = -.71, lean = -.32},
	{x = 0, bottom = 6.71, bend = -.79, lean = .28},
	{x = 1.60, bottom = 7.22, bend = -.60, lean = .41},
	{x = 3.20, bottom = 6.34, bend = -.39, lean = .21},
	{x = 4.79, bottom = 5.89, bend = -.22, lean = .17},
} do
	local topY = ceilingAt(bar.x)
	local top = Vector3.new(bar.x, topY + .20, -.09)
	local endPoint = Vector3.new(bar.x + bar.lean, bar.bottom, bar.bend)
	local frame = barFrame(top, endPoint)
	local width = if index % 2 == 1 then .23 else .26
	local depth = .28
	local length = (top - endPoint).Magnitude
	put(gate, "Part", "Bent overhead bar", Vector3.new(width, length, depth),
		frame * CFrame.new(0, length * .5, 0), forgedIron)
	block(gate, "Top iron socket", Vector3.new(.39, .38, .43), Vector3.new(bar.x, topY + .03, -.10), darkIron)
	tornEnd(gate, frame, width, depth, if index % 2 == 1 then .26 else .17, false)
end

for _, side in {-1, 1} do
	local socket = Vector3.new(side * 5.32, .03, -.19)
	local broken = Vector3.new(side * 5.44, if side < 0 then .84 else 1.05, -.49)
	local length = (broken - socket).Magnitude
	local frame = barFrame(broken, socket)
	put(gate, "Part", "Threshold bar stub", Vector3.new(.27, length, .31),
		frame * CFrame.new(0, length * .5, 0), darkIron)
	tornEnd(gate, frame * CFrame.new(0, length, 0), .27, .31, .18, true)
	block(gate, "Threshold iron socket", Vector3.new(.48, .23, .52), socket, rustIron)

	local fragment = CFrame.new(side * 5.68, .15, -1.16) * CFrame.Angles(math.rad(83), 0, side * math.rad(24))
	put(debris, "Part", "Fallen iron bar", Vector3.new(.23, 1.34, .25), fragment, forgedIron)
	tornEnd(debris, fragment * CFrame.new(0, -.67, 0), .23, .25, .19, false)
end

cave.WorldPivot = entrance
cave.Parent = Workspace
Selection:Set({cave})
print("Broken dungeon cave fitted to " .. dragon.Name .. ". Press Play to check the first sweep.")
