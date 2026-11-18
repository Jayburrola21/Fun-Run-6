-- The importer can produce a skeleton per MeshPart. Move every matching bone
-- and use the mouth mesh's copy of MouthOrigin for the effect.
local DragonRig = {}
DragonRig.__index = DragonRig

local JOINTS = { "NeckBase", "NeckMid", "NeckUpper", "Head", "Jaw" }
local NAMES = {
	Dragon_Root = true, NeckBase = true, NeckMid = true, NeckUpper = true,
	Head = true, Jaw = true, MouthOrigin = true,
}
local UP = Vector3.yAxis

local function jointName(name)
	if NAMES[name] then
		return name
	end
	return name:match("^(.-)[%._]%d+$")
end

function DragonRig.new(model)
	local groups = {}
	for name in pairs(NAMES) do
		groups[name] = {}
	end
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Bone") then
			local list = groups[jointName(descendant.Name)]
			if list then
				table.insert(list, descendant)
			end
		end
	end
	for name, list in pairs(groups) do
		if #list == 0 then
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
	for _, name in JOINTS do
		local group = {}
		for _, bone in groups[name] do
			local frame = bone.TransformedWorldCFrame
			table.insert(group, {
				bone = bone,
				rest = bone.Transform,
				yaw = frame:VectorToObjectSpace(UP),
				pitch = frame:VectorToObjectSpace(right),
			})
		end
		bind[name] = group
	end

	return setmetatable({
		bind = bind,
		mouth = mouth,
		mouthForward = mouth.TransformedWorldCFrame:VectorToObjectSpace(forward),
		mouthUp = mouth.TransformedWorldCFrame:VectorToObjectSpace(UP),
	}, DragonRig)
end

local function pose(joints, yaw, pitch)
	for _, joint in joints do
		local transform = joint.rest
		if yaw ~= 0 then
			transform *= CFrame.fromAxisAngle(joint.yaw, yaw)
		end
		if pitch ~= 0 then
			transform *= CFrame.fromAxisAngle(joint.pitch, pitch)
		end
		joint.bone.Transform = transform
	end
end

function DragonRig:Apply(sample)
	local bind = self.bind
	pose(bind.NeckBase, sample.baseYaw, sample.basePitch)
	pose(bind.NeckMid, sample.midYaw, sample.midPitch)
	pose(bind.NeckUpper, sample.upperYaw, sample.upperPitch)
	-- Counter the delayed neck contribution so the requested head heading
	-- arrives first, instead of building turn offsets from previous frames.
	local headYaw = sample.headYaw - sample.baseYaw - sample.midYaw - sample.upperYaw
	pose(bind.Head, headYaw, sample.headPitch)
	pose(bind.Jaw, 0, -sample.jawOpen)
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
end

return DragonRig
