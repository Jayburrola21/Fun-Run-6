-- First install the updated KartPackage. Import KartRemodel.fbx with Studio's
-- 3D Importer, select its whole Model, and run this in the EDIT Command Bar.
assert(not game:GetService("RunService"):IsRunning(),"Stop Play before importing Blender meshes")
local selection=game:GetService("Selection"):Get()
assert(#selection==1 and selection[1]:IsA("Model"),"Select the complete imported KartRemodel Model")
local imported=selection[1]
local storage=game:GetService("ReplicatedStorage")
local system=assert(storage:FindFirstChild("KartSystem"),"Install the updated kart package first")
assert(system:FindFirstChild("KartMeshVisuals"),"Install the updated kart package with KartMeshVisuals first")
assert(not imported:IsDescendantOf(system),"Select the imported FBX model, not the installed template")
local names={"MainBody","FrontNose","LeftSidePod","RightSidePod","RearBody","RearBumper","Seat","SteeringWheel","FrontLeftWheel","FrontRightWheel","RearLeftWheel","RearRightWheel","LeftExhaust","RightExhaust","Chassis"}
local pivots={
	SteeringWheel=CFrame.new(0,1.95,-1.05)*CFrame.Angles(math.rad(-24),0,0),
	FrontLeftWheel=CFrame.new(-2.2,0.4,-2.16),FrontRightWheel=CFrame.new(2.2,0.4,-2.16),
	RearLeftWheel=CFrame.new(-2.2,0.4,2.16),RearRightWheel=CFrame.new(2.2,0.4,2.16),
}
local materials={Metal=Enum.Material.Metal,Spring=Enum.Material.Metal,Yellow=Enum.Material.Metal,Seat=Enum.Material.Fabric,Lamp=Enum.Material.Neon,Glass=Enum.Material.Glass}
local function finite(value) return type(value)=="number" and value==value and math.abs(value)<math.huge end
local function finiteVector(v) return finite(v.X) and finite(v.Y) and finite(v.Z) end
local markers={}
local meshes={}
for _,object in ipairs(imported:GetDescendants()) do
	assert(not object:IsA("LuaSourceContainer"),"The selected FBX model contains scripts; no changes made")
	if object:IsA("BasePart") then
		local marker=object.Name:match("^(KartOrigin)") or object.Name:match("^(KartForward)") or object.Name:match("^(KartUp)")
		if marker then assert(not markers[marker],"Duplicate alignment marker: "..marker); markers[marker]=object
		else assert(object:IsA("MeshPart"),"Import the FBX through 3D Importer; found non-mesh "..object.Name); table.insert(meshes,object) end
	end
end
local origin=assert(markers.KartOrigin,"Missing KartOrigin marker; import all FBX objects").Position
local forward=assert(markers.KartForward,"Missing KartForward marker; import all FBX objects").Position-origin
local up=assert(markers.KartUp,"Missing KartUp marker; import all FBX objects").Position-origin
assert(finiteVector(origin) and finiteVector(forward) and finiteVector(up),"Invalid marker transforms")
local length=forward.Magnitude
assert(length>0.001 and up.Magnitude>0.001,"Degenerate alignment markers")
assert(math.abs(up.Magnitude/length-1)<0.01,"Imported model has nonuniform scale; reimport with uniform scale")
assert(math.abs(forward.Unit:Dot(up.Unit))<0.01,"Imported model marker axes are not perpendicular")
local unitScale=length/4
local alignment=CFrame.lookAt(origin,origin+forward,up.Unit)
assert(#meshes>0 and #meshes<=256,"Missing meshes or model exceeds the 256-object budget")
local prepared=Instance.new("Model"); prepared.Name="KartMeshTemplate"
prepared:SetAttribute("KartMeshFormat",1)
prepared:SetAttribute("SourceFile","KartRemodel.fbx")
local groups={}
for _,name in ipairs(names) do
	local group=Instance.new("Folder"); group.Name=name; group:SetAttribute("KartGroupPivot",pivots[name] or CFrame.new()); group.Parent=prepared
	groups[name]=group
end
local ok,message=pcall(function()
	for _,part in ipairs(meshes) do
		local name=part.Name:match("^(.-)__")
		local group=assert(groups[name],"Unrecognized Blender object name: "..part.Name)
		assert(finiteVector(part.Size) and part.Size.X>0 and part.Size.Y>0 and part.Size.Z>0,"Invalid imported mesh size")
		local localFrame=alignment:ToObjectSpace(part.CFrame)
		assert(finiteVector(localFrame.Position),"Invalid imported mesh position")
		local copy=assert(part:Clone(),"Imported mesh is not Archivable: "..part.Name)
		for _,child in ipairs(copy:GetChildren()) do if not child:IsA("SurfaceAppearance") then child:Destroy() end end
		for key in pairs(copy:GetAttributes()) do copy:SetAttribute(key,nil) end
		copy.Size=part.Size/unitScale
		assert(math.max(copy.Size.X,copy.Size.Y,copy.Size.Z)<32,"Mesh units do not match alignment markers")
		copy.CFrame=CFrame.new(localFrame.Position/unitScale)*localFrame.Rotation
		copy.Anchored=true; copy.Massless=true; copy.CanCollide=false; copy.CanTouch=false; copy.CanQuery=false
		copy:SetAttribute("KartGroup",name)
		local label=part.Name:lower()
		copy:SetAttribute("KartPrimaryPaint",label:find("__paint")~=nil or label:find("__red")~=nil)
		local role=part.Name:match("__Mat([%a]+)") or "Paint"
		copy.Material=materials[role] or Enum.Material.SmoothPlastic
		copy.Reflectance=(role=="Metal" or role=="Spring" or role=="Yellow") and 0.12 or 0
		if role=="Glass" then copy.Transparency=math.max(copy.Transparency,0.12) end
		copy:SetAttribute("KartMaterialRole",role)
		copy:SetAttribute("KartBrakeLight",role=="Brake")
		copy.Parent=group
	end
	for _,name in ipairs(names) do assert(#groups[name]:GetChildren()>0,"Missing Blender group: "..name) end
end)
if not ok then prepared:Destroy(); error(tostring(message).."; installed template unchanged") end

local serverStorage=game:GetService("ServerStorage")
local backups=serverStorage:FindFirstChild("KartBackups")
if not backups then backups=Instance.new("Folder"); backups.Name="KartBackups"; backups.Parent=serverStorage end
local backup=Instance.new("Folder"); backup.Name="BeforeBlenderImport_"..os.date("!%Y%m%d_%H%M%S"); backup.Parent=backups
local previous=system:FindFirstChild("KartMeshTemplate")
if previous then previous.Parent=backup end
prepared.Parent=system
-- Keep the original import as a recoverable source and remove it from the road.
imported.Parent=backup
print("Blender kart meshes installed ("..#meshes.." objects). Restart Play; existing physics, wheels and seat remain active.")
print("Original import and prior template retained at "..backup:GetFullName())
