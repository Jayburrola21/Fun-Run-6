-- The importer can produce a skeleton per MeshPart. Move every matching bone
-- and use the mouth mesh's copy of MouthOrigin for the effect.
local DragonRig = {}
DragonRig.__index = DragonRig

local JOINTS = { "NeckBase", "NeckMid", "NeckUpper", "Head", "Jaw" }
local NAMES = {
	Dragon_Root = true, NeckBase = true, NeckMid = true, NeckUpper = true,
	Head = true, Jaw = true, MouthOrigin = true, Chest = false,
}
local UP = Vector3.yAxis
local HORN_TIP_PREFIX = "DragonHornHeat"
local WARM_RED = Color3.fromRGB(156, 5, 3)
local HOT_RED = Color3.fromRGB(255, 24, 9)

function DragonRig.isHornTip(instance)
	return instance:IsA("MeshPart") and instance.Name:sub(1, #HORN_TIP_PREFIX) == HORN_TIP_PREFIX
end

local function jointName(name)
	return name:match("^(.-)[%._]%d+$") or name
end

local function bindLidEdge(bone, groups)
	local lid, point = jointName(bone.Name):match("^(Lid[UL][LR])Edge([A-E])$")
	if not lid then
		return
	end

	-- Both bones share the Head as their parent. At rest the edge covers
	-- the eye; moving it to the matching rim folds the eyelid open.
	local rimName = lid .. "Rim" .. point
	local suffix = bone.Name:match("([%._]%d+)$") or ""
	local rim = bone.Parent:FindFirstChild(rimName .. suffix) or bone.Parent:FindFirstChild(rimName)
	if not rim or not rim:IsA("Bone") then
		return
	end

	local group = groups[lid]
	if not group then
		group = { all = {}, preferred = {} }
		groups[lid] = group
	end
	local edge = {
		bone = bone,
		rest = bone.Transform,
		openDelta = bone.CFrame:PointToObjectSpace(rim.Position),
	}
	table.insert(group.all, edge)
	local mesh = bone:FindFirstAncestorWhichIsA("MeshPart")
	local meshName = "Dragon" .. lid
	if mesh and mesh.Name:sub(1, #meshName) == meshName then
		table.insert(group.preferred, edge)
	end
end

function DragonRig.new(model)
	local groups = {}
	for name in pairs(NAMES) do
		groups[name] = {}
	end
	local lidGroups = {}
	local hornTips = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Bone") then
			local list = groups[jointName(descendant.Name)]
			if list then
				table.insert(list, descendant)
			else
				bindLidEdge(descendant, lidGroups)
			end
		elseif DragonRig.isHornTip(descendant) then
			table.insert(hornTips, descendant)
		end
	end
	for name, list in pairs(groups) do
		if #list == 0 and NAMES[name] then
			return nil, "missing imported bone " .. name
		end
	end

	local mouth
	for _, bone in groups.MouthOrigin do
		local owner = bone:FindFirstAncestorWhichIsA("MeshPart")
		if not mouth or (owner and owner.Name:find("ThroatGlow", 1, true)) then
			mouth = bone
		end
	end
	local head = mouth.Parent
	if not head or not head:IsA("Bone") or jointName(head.Name) ~= "Head" then
		return nil, "MouthOrigin must be a child of Head"
	end

	-- Derive north/right by the mouth position, so rotation of the Model or
	-- import-axis conversion does not depend on Bone.LookVector conventions.
	local direction = mouth.TransformedWorldCFrame.Position - head.TransformedWorldCFrame.Position
	local horizontal = direction - UP * direction:Dot(UP)
	if horizontal.Magnitude < 0.001 then
		return nil, "cannot derive forward from the head and mouth bones"
	end
	local forward = horizontal.Unit
	local right = forward:Cross(UP)
	local bind = {}
	for _, name in { "NeckBase", "NeckMid", "NeckUpper", "Head", "Jaw", "Chest" } do
		local group = {}
		for _, bone in groups[name] do
			local frame = bone.TransformedWorldCFrame
			table.insert(group, {
				bone = bone,
				rest = bone.Transform,
				yaw = frame:VectorToObjectSpace(UP),
				pitch = frame:VectorToObjectSpace(right),
				roll = frame:VectorToObjectSpace(forward),
			})
		end
		bind[name] = group
	end
	local lids = {}
	for _, group in pairs(lidGroups) do
		local edges = #group.preferred > 0 and group.preferred or group.all
		for _, edge in edges do
			table.insert(lids, edge)
		end
	end

	return setmetatable({
		bind = bind,
		lids = lids,
		hornTips = hornTips,
		scale = horizontal.Magnitude / 2.51, -- Head-to-mouth distance in the authored GLB.
		mouth = mouth,
		mouthForward = mouth.TransformedWorldCFrame:VectorToObjectSpace(forward),
		mouthUp = mouth.TransformedWorldCFrame:VectorToObjectSpace(UP),
	}, DragonRig)
end

local function pose(joints, yaw, pitch, roll)
	for _, joint in joints do
		local transform = joint.rest
		if yaw ~= 0 then
			transform *= CFrame.fromAxisAngle(joint.yaw, yaw)
		end
		if pitch ~= 0 then
			transform *= CFrame.fromAxisAngle(joint.pitch, pitch)
		end
		if roll and roll ~= 0 then
			transform *= CFrame.fromAxisAngle(joint.roll, roll)
		end
		joint.bone.Transform = transform
	end
end

local function raiseChest(joints, rise)
	for _, joint in joints do
		joint.bone.Transform = joint.rest * CFrame.new(joint.yaw * rise)
	end
end

function DragonRig:SetBlink(blink)
	if blink == self.blink then
		return
	end
	self.blink = blink
	for _, edge in self.lids do
		edge.bone.Transform = edge.rest * CFrame.new(edge.openDelta * (1 - blink))
	end
end

function DragonRig:SetHornHeat(heat)
	if heat == self.hornHeat or #self.hornTips == 0 then
		return
	end
	self.hornHeat = heat
	local color = WARM_RED:Lerp(HOT_RED, heat)
	for _, tip in self.hornTips do
		tip.Color = color
		tip.Transparency = 1 - heat
	end
end

function DragonRig:Apply(sample)
	local bind = self.bind
	raiseChest(bind.Chest, (sample.chestRise or 0) * self.scale)
	pose(bind.NeckBase, sample.baseYaw, sample.basePitch)
	pose(bind.NeckMid, sample.midYaw, sample.midPitch)
	pose(bind.NeckUpper, sample.upperYaw, sample.upperPitch)
	-- Counter the delayed neck contribution so the requested head heading
	-- arrives first, instead of building turn offsets from previous frames.
	local headYaw = sample.headYaw - sample.baseYaw - sample.midYaw - sample.upperYaw
	pose(bind.Head, headYaw, sample.headPitch, sample.headRoll)
	pose(bind.Jaw, 0, -sample.jawOpen)
	self:SetBlink(sample.blink or 0)
	self:SetHornHeat(sample.hornHeat or 0)
end

function DragonRig:GetMouth(depression)
	local frame = self.mouth.TransformedWorldCFrame
	local aim = self.mouthForward * math.cos(depression) - self.mouthUp * math.sin(depression)
	return frame.Position, frame:VectorToWorldSpace(aim).Unit
end

function DragonRig:Reset()
	for _, name in JOINTS do
		pose(self.bind[name], 0, 0)
	end
	raiseChest(self.bind.Chest, 0)
	self:SetBlink(0)
	self:SetHornHeat(0)
end

return DragonRig
