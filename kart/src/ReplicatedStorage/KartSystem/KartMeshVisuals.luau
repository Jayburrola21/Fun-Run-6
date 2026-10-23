-- Imported Blender meshes replace presentation only. The existing raycast rig,
-- wheel carriers, steering motor, seat, hand targets and effects remain intact.
local MeshVisuals={}
local GROUPS={
	"MainBody","FrontNose","LeftSidePod","RightSidePod","RearBody","RearBumper",
	"Seat","SteeringWheel","FrontLeftWheel","FrontRightWheel","RearLeftWheel",
	"RearRightWheel","LeftExhaust","RightExhaust","Chassis",
}
local wheelNames={FrontLeftWheel="FrontLeft",FrontRightWheel="FrontRight",RearLeftWheel="RearLeft",RearRightWheel="RearRight"}

local function finite(value)
	return type(value)=="number" and value==value and math.abs(value)<math.huge
end
local function validFrame(cf)
	if typeof(cf)~="CFrame" then return false end
	for _,value in ipairs({cf:GetComponents()}) do if not finite(value) then return false end end
	return true
end
local function validSize(size)
	return typeof(size)=="Vector3" and finite(size.X) and finite(size.Y) and finite(size.Z)
		and size.X>0 and size.Y>0 and size.Z>0 and math.max(size.X,size.Y,size.Z)<32
end
local function scaledFrame(cf,scale)
	return CFrame.new(cf.Position*scale)*cf.Rotation
end
local function sanitize(part)
	for _,child in ipairs(part:GetChildren()) do
		-- Imported solid-color meshes need no scripts, constraints or attachments.
		if not child:IsA("SurfaceAppearance") then child:Destroy() end
	end
	part.Anchored=false; part.Massless=true
	part.CanCollide=false; part.CanTouch=false; part.CanQuery=false
	assert(finite(part.Transparency),"invalid mesh transparency")
	part.Transparency=math.clamp(part.Transparency,0,1)
end

function MeshVisuals.apply(rig,color,template)
	if not rig or not rig.model or not rig.chassis or not rig.hub or not rig.seat then return false,"invalid rig" end
	if rig.model:FindFirstChild("ImportedKartVisuals") then return true,"already applied" end
	-- The template is created by ImportBlender.command.luau after Studio uploads
	-- the FBX meshes to the experience owner's account. No asset IDs are invented.
	if not template then template=script.Parent:FindFirstChild("KartMeshTemplate") end
	if not template then rig.model:SetAttribute("VisualSource","Native"); return false,"no imported mesh template" end
	local holder
	local brakeLights={}
	local ok,result=pcall(function()
		assert(template:IsA("Model") and template:GetAttribute("KartMeshFormat")==1,"invalid mesh template format")
		local scale=rig.model:GetAttribute("ModelScale") or 1
		assert(finite(scale) and scale>0 and scale<=4,"invalid rig scale")
		local wheels=assert(rig.model:FindFirstChild("Wheels"),"missing wheel rig")
		local accepted={}
		for _,name in ipairs(GROUPS) do accepted[name]=true end
		for _,group in ipairs(template:GetChildren()) do assert(accepted[group.Name],"unexpected mesh group: "..group.Name) end
		holder=Instance.new("Folder"); holder.Name="ImportedKartVisuals"
		local count=0
		for _,name in ipairs(GROUPS) do
			local source=assert(template:FindFirstChild(name),"missing mesh group: "..name)
			assert(source:IsA("Folder") or source:IsA("Model"),"invalid mesh group: "..name)
			local pivot=source:GetAttribute("KartGroupPivot")
			assert(validFrame(pivot),"missing canonical group pivot: "..name)
			local carrier=rig.chassis
			if wheelNames[name] then
				local wheel=assert(wheels:FindFirstChild(wheelNames[name]),"missing wheel: "..name)
				carrier=assert(wheel:FindFirstChild("Tire"),"missing tire carrier: "..name)
			elseif name=="SteeringWheel" then carrier=rig.hub end
			local destination=Instance.new("Folder"); destination.Name=name; destination.Parent=holder
			local groupCount=0
			for _,part in ipairs(source:GetChildren()) do
				assert(part:IsA("MeshPart"),"template contains a non-mesh: "..part.Name)
				assert(validSize(part.Size) and validFrame(part.CFrame),"invalid mesh transform: "..part.Name)
				local copy=assert(part:Clone(),"mesh is not Archivable: "..part.Name)
				sanitize(copy)
				copy.Size=part.Size*scale
				-- Template CFrames are normalized chassis-local canonical units.
				-- Dynamic groups are expressed relative to their real motor pivot.
				local relative=carrier==rig.chassis and part.CFrame or pivot:ToObjectSpace(part.CFrame)
				copy.CFrame=carrier.CFrame*scaledFrame(relative,scale)
				if part:GetAttribute("KartPrimaryPaint")==true and color then copy.Color=color end
				if part:GetAttribute("KartBrakeLight")==true then table.insert(brakeLights,copy) end
				copy.Parent=destination
				local weld=Instance.new("WeldConstraint"); weld.Name="VisualWeld"
				weld.Part0=carrier; weld.Part1=copy; weld.Parent=copy
				groupCount+=1; count+=1
				assert(count<=256,"mesh object budget exceeded")
			end
			assert(groupCount>0,"empty mesh group: "..name)
		end
		return count
	end)
	if not ok then
		if holder then holder:Destroy() end
		rig.model:SetAttribute("VisualSource","Native")
		return false,tostring(result)
	end
	-- All clones and motor-relative transforms are valid before anything visible
	-- is hidden. A bad import leaves the complete native fallback drivable.
	local oldParts={}
	for _,part in ipairs(rig.model:GetDescendants()) do
		if part:IsA("BasePart") and part.Name~="BoostGlow" and part.Name~="BrakeLight" then table.insert(oldParts,part) end
	end
	holder.Parent=rig.model
	for _,part in ipairs(oldParts) do part.Transparency=1 end
	rig.model:SetAttribute("VisualSource","Blender")
	rig.model:SetAttribute("MeshObjectCount",result)
	rig.meshBrakeLights=brakeLights
	return true,"Blender meshes applied"
end

return table.freeze(MeshVisuals)
